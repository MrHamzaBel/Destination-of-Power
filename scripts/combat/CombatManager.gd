class_name CombatManager
extends Node
## Drives one turn-based encounter: builds combatants (player + any number of
## enemies), resolves speed-based turn order, executes player/enemy actions
## and reports results through signals so CombatScene/CombatHUD stay purely
## presentational.
##
## Turn order is not a simple alternating queue. At the start of each round,
## every living combatant's action count for that round is
## floor(their_speed / slowest_alive_speed) (minimum 1) - so a unit twice as
## fast as the slowest combatant acts twice, three times as fast acts three
## times, and so on. Combatants then act in descending action-count order,
## each one using up its whole block of actions consecutively before the
## next combatant's block starts, and the ratio is recalculated fresh at the
## start of every round - so future speed buffs/debuffs are always picked up
## immediately. With exactly one enemy this reduces to "faster side bursts,
## slower side gets one hit, repeat."

signal log_message(text: String)
signal stats_changed
signal turn_changed(unit: CombatUnitState)
signal combat_finished(victory: bool)

const CRIT_MULTIPLIER: float = 1.5
## Damage-formula safety bounds: attack-over-defense can boost damage up to
## +300%, defense-over-attack can cut it by at most 90% (a 1-damage floor
## still applies on top of this in CombatUnitState.apply_damage).
const MAX_DAMAGE_BONUS_PERCENT: float = 300.0
const MAX_DAMAGE_REDUCTION_PERCENT: float = 90.0

var player_unit: CombatUnitState
var enemy_units: Array[CombatUnitState] = []
var ally_units: Array[CombatUnitState] = [] ## AI-controlled allies fighting on the player's side.
var current_unit: CombatUnitState = null
var awaiting_player_input: bool = false
var last_rewards: Dictionary = {}
var selected_enemy_target: CombatUnitState = null ## Set via set_target(); used by player attacks/abilities.

var _rng: RandomNumberGenerator
var _defeated_this_combat: Array[CombatUnitState] = []
var _round_queue: Array[CombatUnitState] = [] ## This round's action order, one entry per action.
var round_stage: int = 0 ## Index into _round_queue of the action currently resolving.

func start(enemy_ids: Array[String], ally_ids: Array[String] = []) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	player_unit = CombatUnitState.from_player()
	enemy_units.clear()
	ally_units.clear()
	selected_enemy_target = null
	_defeated_this_combat.clear()
	last_rewards = {"items": [], "artifact": "", "exp_gained": 0, "levels_gained": []}

	for id in enemy_ids:
		var def := EnemyRegistry.get_enemy(id)
		if def != null:
			enemy_units.append(CombatUnitState.from_enemy(def))
	if enemy_units.is_empty():
		push_warning("CombatManager: no valid enemies for ids %s" % [enemy_ids])

	for id in ally_ids:
		var ally_def := AllyRegistry.get_ally(id)
		if ally_def != null:
			ally_units.append(CombatUnitState.from_ally(ally_def))

	var names: Array[String] = []
	for e in enemy_units:
		names.append(e.display_name)
	var intro := "Combat begins against %s!" % ", ".join(names)
	if not ally_units.is_empty():
		var ally_names: Array[String] = []
		for a in ally_units:
			ally_names.append(a.display_name)
		intro += " %s fights at your side!" % ", ".join(ally_names)
	_log(intro)
	EventBus.combat_started.emit({"combat": self})
	_begin_new_round()

func get_alive_enemies() -> Array[CombatUnitState]:
	var result: Array[CombatUnitState] = []
	for e in enemy_units:
		if e.is_alive():
			result.append(e)
	return result

func get_alive_allies() -> Array[CombatUnitState]:
	var result: Array[CombatUnitState] = []
	for a in ally_units:
		if a.is_alive():
			result.append(a)
	return result

## The enemy currently targeted by the player (and by allies, who focus the
## same target). Falls back to the first alive enemy if nothing is selected
## or the selected enemy has since died.
func get_current_target() -> CombatUnitState:
	if selected_enemy_target != null and selected_enemy_target.is_alive():
		return selected_enemy_target
	selected_enemy_target = get_primary_enemy_target()
	return selected_enemy_target

func set_target(enemy: CombatUnitState) -> void:
	if enemy != null and enemy.is_alive() and not enemy.is_player and not enemy.is_ally:
		selected_enemy_target = enemy

func is_player_turn() -> bool:
	return awaiting_player_input and current_unit != null and current_unit.is_player

func resource_name() -> String:
	var class_def := RunManager.get_class_def()
	return class_def.resource_label if class_def != null else "Resource"

# --- Player actions ----------------------------------------------------------

func player_basic_attack() -> void:
	if not is_player_turn():
		return
	var weapon := _get_equipped_weapon()
	var is_ranged := weapon != null and weapon.is_ranged
	_perform_player_attack(1.0, false, is_ranged)

func player_use_ability(ability_id: String) -> void:
	if not is_player_turn():
		return
	var ability := AbilityRegistry.get_ability(ability_id)
	if ability == null:
		return
	if ability.resource_cost > player_unit.current_resource:
		_log("Not enough %s to use %s." % [resource_name(), ability.display_name])
		return
	player_unit.current_resource -= ability.resource_cost
	match ability.ability_type:
		AbilityDefinition.AbilityType.ATTACK:
			_perform_player_attack(ability.power, ability.uses_intelligence, ability.is_ranged)
		AbilityDefinition.AbilityType.DEFEND:
			_perform_player_defend(ability.defense_bonus_percent)
		AbilityDefinition.AbilityType.HEAL:
			player_unit.current_health = min(player_unit.max_health, player_unit.current_health + ability.heal_amount)
			_log("%s uses %s and heals %d." % [player_unit.display_name, ability.display_name, ability.heal_amount])
			_finish_action()
		AbilityDefinition.AbilityType.BUFF, AbilityDefinition.AbilityType.UTILITY:
			_perform_player_utility(ability)
	stats_changed.emit()

func player_defend() -> void:
	if not is_player_turn():
		return
	_perform_player_defend(0.5)

func player_use_item(item_id: String) -> void:
	if not is_player_turn():
		return
	var item_def := ItemRegistry.get_item(item_id)
	if item_def == null or item_def.category != ItemDefinition.Category.CONSUMABLE:
		return
	if RunManager.run == null or not RunManager.run.remove_item(item_id, 1):
		return
	player_unit.current_health = min(player_unit.max_health, player_unit.current_health + item_def.heal_amount)
	player_unit.current_resource = min(player_unit.max_resource, player_unit.current_resource + item_def.resource_amount)
	_log("%s uses %s." % [player_unit.display_name, item_def.display_name])
	EventBus.item_used.emit({"item_id": item_id, "combat": self})
	stats_changed.emit()
	_finish_action()

func end_turn() -> void:
	if not is_player_turn():
		return
	_log("%s passes the turn." % player_unit.display_name)
	_finish_action()

func heal_player(amount: int, source_label: String = "") -> void:
	if player_unit == null:
		return
	player_unit.current_health = min(player_unit.max_health, player_unit.current_health + amount)
	var suffix := " (%s)" % source_label if source_label != "" else ""
	_log("%s restores %d health%s." % [player_unit.display_name, amount, suffix])
	stats_changed.emit()

# --- Damage formula ------------------------------------------------------------

## Attack-vs-defense damage multiplier: equal stats = no change; every
## percent the attacker's Attack exceeds the defender's effective Defense
## adds half a percent of bonus damage, and vice versa for the defender.
static func damage_multiplier(attacker_attack: int, defender_effective_defense: float) -> float:
	var atk: float = maxf(0.0, float(attacker_attack))
	var def: float = maxf(0.01, defender_effective_defense)
	if atk > def:
		var percent: float = (atk - def) / def * 100.0
		var bonus: float = clampf(percent / 2.0, 0.0, MAX_DAMAGE_BONUS_PERCENT) / 100.0
		return 1.0 + bonus
	elif def > atk:
		var percent: float = (def - atk) / maxf(0.01, atk) * 100.0
		var reduction: float = clampf(percent / 2.0, 0.0, MAX_DAMAGE_REDUCTION_PERCENT) / 100.0
		return 1.0 - reduction
	return 1.0

func _resolve_damage_multiplier(attacker: CombatUnitState, defender: CombatUnitState) -> float:
	return damage_multiplier(attacker.attack, defender.get_effective_defense())

# --- Internal resolution -------------------------------------------------------

func _perform_player_attack(power: float, uses_intelligence: bool, is_ranged: bool) -> void:
	var target := get_current_target()
	if target == null:
		return
	# Attack drives weapon attacks fully; spells blend 50% Attack + 25% Intelligence.
	var base_stat: float = (float(player_unit.attack) * 0.5 + float(player_unit.intelligence) * 0.25) if uses_intelligence else float(player_unit.attack)
	var raw_damage := int(round(base_stat * power))
	var context := {
		"combat": self,
		"damage": raw_damage,
		"target": target,
		"is_ranged": is_ranged,
		"crit_chance_bonus": 0.0,
		"log_extra": "",
	}
	EventBus.player_attacked.emit(context)
	var post_artifact_damage: int = int(context.get("damage", raw_damage))
	var crit_chance: float = float(context.get("crit_chance_bonus", 0.0))
	var is_crit := crit_chance > 0.0 and _rng.randf() < crit_chance
	if is_crit:
		post_artifact_damage = int(round(float(post_artifact_damage) * CRIT_MULTIPLIER))
	var multiplier := _resolve_damage_multiplier(player_unit, target)
	var final_damage := int(round(float(post_artifact_damage) * multiplier))
	var dealt := target.apply_damage(final_damage)
	_log("%s attacks %s for %d damage.%s%s" % [
		player_unit.display_name, target.display_name, dealt,
		(" Critical hit!" if is_crit else ""), str(context.get("log_extra", ""))
	])
	stats_changed.emit()
	if not target.is_alive():
		_on_enemy_defeated(target)
	_check_health_low(target)
	_finish_action()

func _perform_player_defend(bonus: float) -> void:
	player_unit.is_defending = true
	player_unit.defense_bonus_percent = bonus
	_log("%s braces for the next attack." % player_unit.display_name)
	_finish_action()

func _perform_player_utility(ability: AbilityDefinition) -> void:
	if ability.resource_restore_amount > 0:
		player_unit.current_resource = min(player_unit.max_resource, player_unit.current_resource + ability.resource_restore_amount)
		_log("%s uses %s and recovers %d %s." % [player_unit.display_name, ability.display_name, ability.resource_restore_amount, resource_name()])
	if ability.defense_bonus_percent > 0.0:
		player_unit.is_defending = true
		player_unit.defense_bonus_percent = max(player_unit.defense_bonus_percent, ability.defense_bonus_percent)
		_log("%s uses %s, becoming harder to hit." % [player_unit.display_name, ability.display_name])
	_finish_action()

## Called after any player or enemy action resolves. Advances to the next
## action within the current speed-ratio round, or starts a new round.
func _finish_action() -> void:
	if _check_combat_end():
		return
	round_stage += 1
	_advance_round_action()

## Builds this round's full action order (see the class doc comment for the
## algorithm) and starts resolving it.
func _begin_new_round() -> void:
	if _check_combat_end():
		return
	var combatants: Array[CombatUnitState] = [player_unit]
	combatants.append_array(get_alive_allies())
	combatants.append_array(get_alive_enemies())
	if combatants.is_empty():
		return

	var slowest_speed: float = INF
	for c in combatants:
		slowest_speed = minf(slowest_speed, float(maxi(1, c.speed)))

	# One entry per combatant: how many actions it gets this round.
	var entries: Array[Dictionary] = []
	for c in combatants:
		var speed: float = float(maxi(1, c.speed))
		var actions: int = maxi(1, int(floor(speed / slowest_speed)))
		entries.append({"unit": c, "actions": actions})
	entries.sort_custom(func(a, b) -> bool:
		if a["actions"] != b["actions"]:
			return a["actions"] > b["actions"]
		return a["unit"].speed > b["unit"].speed
	)

	_round_queue.clear()
	for entry in entries:
		var unit: CombatUnitState = entry["unit"]
		var actions: int = entry["actions"]
		for i in range(actions):
			_round_queue.append(unit)

	round_stage = 0
	_advance_round_action()

func _advance_round_action() -> void:
	if _check_combat_end():
		return
	if round_stage >= _round_queue.size():
		_begin_new_round()
		return

	var acting_unit: CombatUnitState = _round_queue[round_stage]
	if not acting_unit.is_alive():
		round_stage += 1
		_advance_round_action()
		return

	current_unit = acting_unit
	current_unit.clear_turn_effects()
	# Set this before emitting so anything reacting to turn_changed/turn_started
	# (including code that immediately calls player_basic_attack() etc.) sees
	# the correct state instead of racing the signal.
	awaiting_player_input = acting_unit.is_player
	turn_changed.emit(current_unit)
	EventBus.turn_started.emit({"combat": self, "unit": current_unit, "is_player": acting_unit.is_player})

	if acting_unit.is_player:
		return
	await get_tree().create_timer(0.6).timeout
	if acting_unit.is_ally:
		_ally_take_single_action(acting_unit)
	else:
		_enemy_take_single_action(acting_unit)

## Position/size of the current unit's consecutive action block this round,
## e.g. (2, 4) for "2nd of 4 actions in a row." Used by CombatHUD to show a
## burst counter; (1, 1) when the current action isn't part of a multi-action block.
func get_current_block_progress() -> Vector2i:
	if round_stage < 0 or round_stage >= _round_queue.size():
		return Vector2i(1, 1)
	var unit := _round_queue[round_stage]
	var block_start := round_stage
	while block_start > 0 and _round_queue[block_start - 1] == unit:
		block_start -= 1
	var block_end := round_stage
	while block_end < _round_queue.size() - 1 and _round_queue[block_end + 1] == unit:
		block_end += 1
	return Vector2i(round_stage - block_start + 1, block_end - block_start + 1)

## Allies are always AI-controlled: they focus whatever enemy the player has
## targeted (see get_current_target()).
func _ally_take_single_action(ally: CombatUnitState) -> void:
	if not ally.is_alive():
		_finish_action()
		return
	var target := get_current_target()
	if target == null or not target.is_alive():
		_finish_action()
		return
	var multiplier := _resolve_damage_multiplier(ally, target)
	var raw_damage := int(round(float(ally.attack) * multiplier))
	var dealt := target.apply_damage(raw_damage)
	_log("%s attacks %s for %d damage." % [ally.display_name, target.display_name, dealt])
	stats_changed.emit()
	if not target.is_alive():
		_on_enemy_defeated(target)
	_check_health_low(target)
	_finish_action()

## Living player-side combatants an enemy can attack: the player plus any allies.
func _get_alive_party_members() -> Array[CombatUnitState]:
	var result: Array[CombatUnitState] = []
	if player_unit != null and player_unit.is_alive():
		result.append(player_unit)
	result.append_array(get_alive_allies())
	return result

func _enemy_take_single_action(enemy: CombatUnitState) -> void:
	if not enemy.is_alive():
		_finish_action()
		return
	var party := _get_alive_party_members()
	if party.is_empty():
		_finish_action()
		return
	var target: CombatUnitState = party[_rng.randi_range(0, party.size() - 1)]

	if _decide_enemy_defends(enemy):
		enemy.is_defending = true
		enemy.defense_bonus_percent = 0.5
		_log("%s braces for impact." % enemy.display_name)
	else:
		var multiplier := _resolve_damage_multiplier(enemy, target)
		var raw_damage := int(round(float(enemy.attack) * multiplier))
		var dealt := target.apply_damage(raw_damage)
		_log("%s attacks %s for %d damage." % [enemy.display_name, target.display_name, dealt])
		stats_changed.emit()
		if target.is_player:
			EventBus.player_took_damage.emit({"combat": self, "amount": dealt})
		_check_health_low(target)
		if not target.is_alive() and not target.is_player:
			_log("%s has fallen!" % target.display_name)
	_finish_action()

func _decide_enemy_defends(enemy: CombatUnitState) -> bool:
	var def := enemy.enemy_def
	if def == null:
		return false
	match def.behavior_type:
		EnemyDefinition.BehaviorType.DEFENSIVE:
			return _rng.randf() < 0.3
		EnemyDefinition.BehaviorType.RANDOM:
			return _rng.randf() < 0.5
		_:
			return false

func _on_enemy_defeated(enemy: CombatUnitState) -> void:
	_log("%s is defeated!" % enemy.display_name)
	_defeated_this_combat.append(enemy)
	if RunManager.run == null:
		return
	RunManager.run.defeated_enemy_names.append(enemy.display_name)

	var currency_reward := enemy.enemy_def.currency_reward if enemy.enemy_def != null else 0
	var context := {"combat": self, "enemy": enemy, "currency_reward": currency_reward}
	EventBus.enemy_defeated.emit(context)
	RunManager.run.currency += int(context.get("currency_reward", 0))

	if enemy.enemy_def != null:
		var exp_gained := RunManager.compute_exp_reward(enemy.enemy_def)
		var levels_gained := RunManager.grant_experience(exp_gained)
		_log("%s gains %d experience." % [player_unit.display_name, exp_gained])
		last_rewards["exp_gained"] = int(last_rewards.get("exp_gained", 0)) + exp_gained
		if not levels_gained.is_empty():
			var gained: Array = last_rewards.get("levels_gained", [])
			gained.append_array(levels_gained)
			last_rewards["levels_gained"] = gained
			for lvl in levels_gained:
				_log("Level up! %s reached level %d and gained %d stat points." % [player_unit.display_name, lvl, RunManager.STAT_POINTS_PER_LEVEL])

func _check_health_low(unit: CombatUnitState) -> void:
	if unit.max_health <= 0 or unit.health_low_triggered:
		return
	if float(unit.current_health) / float(unit.max_health) <= 0.3:
		unit.health_low_triggered = true
		EventBus.health_low.emit({"combat": self, "unit": unit})

func _check_combat_end() -> bool:
	if player_unit == null:
		return false
	if not player_unit.is_alive():
		_finish_combat(false)
		return true
	if get_alive_enemies().is_empty() and not enemy_units.is_empty():
		_finish_combat(true)
		return true
	return false

func _finish_combat(victory: bool) -> void:
	awaiting_player_input = false
	if RunManager.run != null:
		RunManager.run.current_health = player_unit.current_health
		RunManager.run.current_resource = player_unit.current_resource
	var context := {"combat": self, "victory": victory}
	EventBus.combat_ended.emit(context)
	if victory:
		_grant_rewards()
	if RunManager.run != null:
		RunManager.save_current_run()
	combat_finished.emit(victory)

func _grant_rewards() -> void:
	if RunManager.run == null:
		return
	for enemy in _defeated_this_combat:
		if enemy.enemy_def == null:
			continue
		for entry in enemy.enemy_def.loot_table:
			if _rng.randf() < float(entry.get("chance", 0.0)):
				var item_id: String = entry.get("item_id", "")
				if item_id != "":
					RunManager.run.add_item(item_id, 1)
					(last_rewards["items"] as Array).append(item_id)
	if _rng.randf() < 0.35:
		var artifact := ArtifactRegistry.get_random(_rng, RunManager.run.class_id)
		if artifact != null and (artifact.stacking_allowed or not RunManager.run.has_artifact(artifact.id)):
			RunManager.run.add_artifact(artifact.id)
			last_rewards["artifact"] = artifact.id

func get_primary_enemy_target() -> CombatUnitState:
	for e in enemy_units:
		if e.is_alive():
			return e
	return null

func _get_equipped_weapon() -> ItemDefinition:
	if RunManager.run == null:
		return null
	var weapon_id: String = RunManager.run.equipped.get("weapon", "")
	return ItemRegistry.get_item(weapon_id) if weapon_id != "" else null

func _log(text: String) -> void:
	log_message.emit(text)
	print("[Combat] ", text)
