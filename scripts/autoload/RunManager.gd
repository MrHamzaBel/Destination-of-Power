extends Node
## Owns the current character profile and active run state. Exploration,
## combat and UI screens all read/write run state through this singleton
## instead of passing data directly between scenes.

const STAT_NAMES: Array[String] = ["hp", "attack", "defense", "speed", "intelligence"]
const EXP_BASE_REQUIREMENT: int = 100
const EXP_GROWTH_PER_LEVEL: float = 1.1 ## Each level requires 10% more exp than the previous one.
const STAT_POINTS_PER_LEVEL: int = 2
const MANA_PER_INTELLIGENCE: int = 10 ## Class resource pool (mana/stamina/energy) = intelligence * this.
const GUILD_PROGRESS_BASE: float = 20.0
const GUILD_PROGRESS_GROWTH: float = 1.25 ## Each guild rank needs 25% more standing than the previous one.

var character_profile: CharacterProfile = null
var run: RunData = null
var last_run_summary: Dictionary = {} ## Populated by end_run(), read by RunSummary.tscn.

func _ready() -> void:
	character_profile = SaveManager.load_character_profile()
	if SaveManager.has_active_run():
		run = SaveManager.load_run()

# --- Character profile --------------------------------------------------------

func has_character() -> bool:
	return character_profile != null and character_profile.is_valid()

func save_character(profile: CharacterProfile) -> void:
	character_profile = profile
	SaveManager.save_character_profile(profile)
	EventBus.character_saved.emit(profile)

# --- Run lifecycle --------------------------------------------------------------

func has_active_run() -> bool:
	return run != null and run.is_active

func start_new_run(class_id: String) -> void:
	var class_def := ClassRegistry.get_class_definition(class_id)
	if class_def == null:
		push_error("RunManager: cannot start run, unknown class '%s'" % class_id)
		return

	var new_run := RunData.new()
	new_run.run_seed = randi()
	new_run.class_id = class_id
	new_run.currency = 10
	new_run.is_active = true
	new_run.current_scene_path = SceneManager.BACK_ALLEY
	new_run.defeated_enemy_names = []

	for item_id in class_def.starting_equipment:
		new_run.add_item(item_id, 1)
	for slot in class_def.starting_equipped.keys():
		var item_id: String = class_def.starting_equipped[slot]
		new_run.add_item(item_id, 1)
		new_run.equipped[slot] = item_id

	var rng := RandomNumberGenerator.new()
	rng.seed = new_run.run_seed
	new_run.encounter_sequence = EncounterRegistry.generate_sequence(rng)
	new_run.current_encounter_index = 0

	run = new_run
	# Derive starting health/resource from the fully-assembled stat block
	# (base stats + starting equipment + the intelligence->mana formula).
	var starting_stats := compute_current_stats()
	run.current_health = starting_stats.max_health
	run.current_resource = starting_stats.max_resource

	SaveManager.save_run(run)
	EventBus.run_started.emit()
	print("RunManager: started new run as %s (seed %d)" % [class_id, run.run_seed])

func save_current_run() -> void:
	if run != null:
		SaveManager.save_run(run)

## death_info (only meaningful when victory is false) is CombatManager's
## last_death_info - {"attacker_name", "attacker_level", "attack_label"} for
## whichever hit actually finished the player off, read by RunSummary.
func end_run(victory: bool, death_info: Dictionary = {}) -> void:
	if run == null:
		return
	last_run_summary = {
		"victory": victory,
		"class_id": run.class_id,
		"level": run.level,
		"defeated_enemy_names": run.defeated_enemy_names.duplicate(),
		"artifacts": run.artifacts.duplicate(),
		"currency": run.currency,
		"encounters_completed": run.current_encounter_index,
		"death_info": death_info.duplicate(),
	}
	run.is_active = false
	SaveManager.delete_run()
	run = null
	EventBus.run_ended.emit(victory)

func abandon_run() -> void:
	if run != null:
		run.is_active = false
	SaveManager.delete_run()
	run = null

# --- Derived stats ---------------------------------------------------------------

func get_class_def() -> ClassDefinition:
	if run == null:
		return null
	return ClassRegistry.get_class_definition(run.class_id)

## Combines class base stats, equipped item modifiers, passive artifact
## modifiers and allocated level-up points into the character's current
## effective stat block. The class resource pool (mana/stamina/energy) is
## always derived from the final Intelligence value, not stored directly.
func compute_current_stats() -> StatBlock:
	var class_def := get_class_def()
	var stats := StatBlock.new()
	if class_def == null:
		return stats
	stats = class_def.base_stats.duplicate_stats()

	for slot in run.equipped.keys():
		var item_id: String = run.equipped[slot]
		var item_def := ItemRegistry.get_item(item_id)
		if item_def != null and item_def.stat_modifiers != null:
			stats = stats.add(item_def.stat_modifiers)

	for artifact_id in run.artifacts.keys():
		var artifact_def := ArtifactRegistry.get_artifact(artifact_id)
		if artifact_def == null:
			continue
		var effect := ArtifactSystem.get_effect(artifact_id)
		if effect == null:
			continue
		var stacks: int = run.artifacts[artifact_id]
		var modifier := effect.get_passive_stat_modifier(artifact_def)
		if modifier != null:
			for i in range(stacks if artifact_def.stacking_allowed else 1):
				stats = stats.add(modifier)

	stats.max_health += int(run.allocated_stats.get("hp", 0)) * StatBlock.HP_STAT_MULTIPLIER
	stats.attack += int(run.allocated_stats.get("attack", 0))
	stats.defense += int(run.allocated_stats.get("defense", 0))
	stats.speed += int(run.allocated_stats.get("speed", 0))
	stats.intelligence += int(run.allocated_stats.get("intelligence", 0))

	stats.max_resource += stats.intelligence * MANA_PER_INTELLIGENCE

	return stats

# --- Leveling & experience ---------------------------------------------------------

## Total experience needed to advance from `level` to `level + 1`. Grows by
## EXP_GROWTH_PER_LEVEL (10%) compounding every level.
func exp_required_for_level(level: int) -> int:
	return int(round(EXP_BASE_REQUIREMENT * pow(EXP_GROWTH_PER_LEVEL, level - 1)))

## Adds experience to the run, applying every level-up it triggers (each
## worth STAT_POINTS_PER_LEVEL free stat points). Returns the list of new
## levels reached, in order, for the caller to report to the player.
func grant_experience(amount: int) -> Array[int]:
	var levels_gained: Array[int] = []
	if run == null or amount <= 0:
		return levels_gained
	run.current_exp += amount
	var required := exp_required_for_level(run.level)
	while run.current_exp >= required:
		run.current_exp -= required
		run.level += 1
		run.unspent_stat_points += STAT_POINTS_PER_LEVEL
		levels_gained.append(run.level)
		required = exp_required_for_level(run.level)
	return levels_gained

## Experience reward for defeating an enemy, scaled by both the enemy's
## level and how far above/below the player's own level it is - stronger
## enemies relative to the player are worth more, weaker ones worth less.
## Floored so grinding weak enemies never yields nothing.
func compute_exp_reward(enemy_def: EnemyDefinition) -> int:
	if enemy_def == null or run == null:
		return 0
	var level_factor: float = 1.0 + float(enemy_def.level - run.level) * 0.15
	level_factor = clampf(level_factor, 0.2, 3.0)
	return max(1, int(round(float(enemy_def.xp_reward) * float(enemy_def.level) * level_factor)))

## Spends one unspent stat point on the given stat ("hp", "attack",
## "defense", "speed" or "intelligence"). Returns false if there were no
## points to spend or the stat name is invalid.
func allocate_stat_point(stat_name: String) -> bool:
	if run == null or run.unspent_stat_points <= 0 or not STAT_NAMES.has(stat_name):
		return false
	run.unspent_stat_points -= 1
	run.allocated_stats[stat_name] = int(run.allocated_stats.get(stat_name, 0)) + 1
	save_current_run()
	return true

# --- Quests -----------------------------------------------------------------

func is_quest_active(quest_id: String) -> bool:
	return run != null and run.active_quests.has(quest_id)

func is_quest_completed(quest_id: String) -> bool:
	return run != null and run.completed_quests.has(quest_id)

func start_quest(quest_id: String) -> void:
	if run == null or is_quest_active(quest_id) or is_quest_completed(quest_id):
		return
	run.active_quests.append(quest_id)
	var quest_def := QuestRegistry.get_quest(quest_id)
	if quest_def != null and quest_def.objective_enemy_id != "":
		run.counters["quest_kills_%s" % quest_id] = 0
	save_current_run()

## Grants a quest's reward (any combination of gold/exp/stat points/items/an
## artifact - see QuestDefinition) and moves it from active to completed.
## Returns the list of levels gained (same shape as grant_experience()) so
## a level-up from quest exp can still be reported to the player.
func complete_quest(quest_id: String) -> Array[int]:
	var levels_gained: Array[int] = []
	if run == null or not run.active_quests.has(quest_id):
		return levels_gained
	var quest_def := QuestRegistry.get_quest(quest_id)
	if quest_def == null:
		return levels_gained

	run.active_quests.erase(quest_id)
	if quest_def.repeatable:
		run.counters.erase("quest_kills_%s" % quest_id)
	else:
		run.completed_quests.append(quest_id)

	# Guild members pay less "guild tax" on mission gold - i.e. they keep a
	# rank-scaled bonus percentage of it - and higher ranks add a free potion.
	var gold_reward := quest_def.reward_gold
	var rank_def := get_guild_rank_def()
	if rank_def != null:
		gold_reward = int(round(float(gold_reward) * (1.0 + rank_def.tax_discount_percent / 100.0)))
		if rank_def.free_potion_per_mission:
			run.add_item("minor_healing_potion", 1)

	run.currency += gold_reward
	run.unspent_stat_points += quest_def.reward_stat_points
	for item_id in quest_def.reward_item_ids:
		run.add_item(item_id, 1)
	if quest_def.reward_artifact_id != "":
		run.add_artifact(quest_def.reward_artifact_id)
	if quest_def.reward_guild_progress > 0:
		run.guild_progress += quest_def.reward_guild_progress
	if quest_def.reward_exp > 0:
		levels_gained = grant_experience(quest_def.reward_exp)

	save_current_run()
	return levels_gained

## Call whenever an enemy is defeated in combat. Advances the kill-count
## progress of every active quest whose objective_enemy_id matches, and
## auto-completes any that just hit their target - a "kill 9 bees" mission
## needs no separate turn-in step. Returns the ids of quests that just
## completed (possibly empty) so the caller can report rewards.
func register_enemy_kill_for_quests(enemy_id: String) -> Array[String]:
	var completed: Array[String] = []
	if run == null or enemy_id == "":
		return completed
	for quest_id in run.active_quests.duplicate():
		var quest_def := QuestRegistry.get_quest(quest_id)
		if quest_def == null or quest_def.objective_enemy_id != enemy_id:
			continue
		var counter_key := "quest_kills_%s" % quest_id
		var kills := increment_counter(counter_key)
		if kills >= quest_def.objective_kill_count:
			complete_quest(quest_id)
			completed.append(quest_id)
	return completed

# --- Adventurers' Guild --------------------------------------------------------

func get_guild_rank_def() -> GuildRankDefinition:
	if run == null or run.guild_rank == "":
		return null
	return GuildRegistry.get_rank(run.guild_rank)

## Guild standing (RunData.guild_progress) needed to be eligible to test for
## the rank at ladder position `order`, mirroring exp_required_for_level()'s
## shape but compounding 25% per rank instead of 10% per level. Enrollment
## (order 0, i.e. F-Rank) never requires standing - there's nothing to have
## proven yet.
func guild_progress_required(order: int) -> int:
	if order <= 0:
		return 0
	return int(round(GUILD_PROGRESS_BASE * pow(GUILD_PROGRESS_GROWTH, order)))

# --- Generic run counters -----------------------------------------------------

func get_counter(key: String) -> int:
	if run == null:
		return 0
	return int(run.counters.get(key, 0))

func increment_counter(key: String, amount: int = 1) -> int:
	if run == null:
		return 0
	var value := get_counter(key) + amount
	run.counters[key] = value
	return value
