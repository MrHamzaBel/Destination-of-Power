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
signal roster_changed ## Emitted when enemies are added mid-combat (e.g. an enrage summon) - CombatScene re-spawns visuals in response.
signal enemy_visual_defeated(enemy: CombatUnitState) ## Emitted the moment one specific enemy dies - CombatScene marks its visual so a multi-enemy fight always shows which one just fell instead of leaving a dead enemy rendered as if still standing.

const CRIT_MULTIPLIER: float = 1.5
## Damage-formula safety bounds: attack-over-defense can boost damage up to
## +300%, defense-over-attack can cut it by at most 90% (a 1-damage floor
## still applies on top of this in CombatUnitState.apply_damage).
const MAX_DAMAGE_BONUS_PERCENT: float = 300.0
const MAX_DAMAGE_REDUCTION_PERCENT: float = 90.0
const MAX_DODGE_CHANCE_PERCENT: float = 90.0
const MINION_SUMMON_CHANCE: float = 0.5 ## Chance a boss uses its turn to call back a fallen minion, when eligible.

var player_unit: CombatUnitState
var enemy_units: Array[CombatUnitState] = []
var ally_units: Array[CombatUnitState] = [] ## AI-controlled allies fighting on the player's side.
var current_unit: CombatUnitState = null
var awaiting_player_input: bool = false
var last_rewards: Dictionary = {}
var last_death_info: Dictionary = {} ## {"attacker_name", "attacker_level", "attack_label"} - the most recent hit the player took, shown on the defeat screen if it turns out to be the killing blow.
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
	last_rewards = {"items": [], "artifact": "", "guaranteed_artifacts": [], "exp_gained": 0, "levels_gained": [], "fled_enemies": [], "gold_stolen": 0}
	last_death_info = {}

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

	for e in enemy_units:
		if e.enemy_def != null and e.enemy_def.intro_quote != "":
			_log(e.enemy_def.intro_quote)
			break
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

## Exposed so reusable systems outside CombatManager (e.g. artifact effects)
## can roll against this combat's own seeded RNG instead of the engine-global one.
func get_rng() -> RandomNumberGenerator:
	return _rng

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
			if player_unit.heal_sealed:
				player_unit.current_resource += ability.resource_cost # Refund - the seal blocks the heal outright, not just its effect.
				_log("The seal on your wounds flares - %s does nothing!" % ability.display_name)
				_finish_action()
				return
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
	if not item_def.combat_usable:
		_log("%s isn't something you can use mid-fight." % item_def.display_name)
		return
	if item_def.heal_amount > 0 and player_unit.heal_sealed:
		_log("The seal on your wounds flares - %s won't help you here." % item_def.display_name)
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

## Swiftie Boots' signature mechanic: only offered while the player is
## strictly faster (effective Speed, so freeze/haste debuffs count) than
## every living enemy in the fight - a slower or evenly-matched party can't
## outrun anyone, mirroring how the dodge/damage formulas never let the
## weaker side "win."
func player_can_flee() -> bool:
	if not is_player_turn():
		return false
	if RunManager.run == null or not RunManager.run.has_artifact("swiftie_boots"):
		return false
	var enemies := get_alive_enemies()
	if enemies.is_empty():
		return false
	var player_speed := player_unit.get_effective_speed()
	for e in enemies:
		if player_speed <= e.get_effective_speed():
			return false
	return true

## Ends combat as a clean escape instead of a win/loss - no loot, no exp, no
## artifact roll (see _finish_combat's fled param), but current health/resource
## still carries forward same as any other combat exit.
func player_attempt_flee() -> void:
	if not player_can_flee():
		return
	_log("%s is faster than every foe here and slips away from the fight!" % player_unit.display_name)
	last_rewards["player_fled"] = true
	_finish_combat(true, true)

func heal_player(amount: int, source_label: String = "") -> void:
	if player_unit == null:
		return
	if player_unit.heal_sealed:
		var suffix_blocked := " (%s)" % source_label if source_label != "" else ""
		_log("The seal on your wounds flares - the healing%s has no effect!" % suffix_blocked)
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

## Same formula shape as damage_multiplier() (half a percent of chance per 1%
## stat gap, halving convention preserved) but for Speed vs Speed, and
## reinterpreted as a complete-miss probability instead of a damage
## multiplier: only the defender's Speed advantage matters, and it never
## produces a "bonus" the other way - a slower defender simply can't dodge.
static func dodge_chance(attacker_speed: int, defender_speed: int) -> float:
	var atk: float = maxf(0.01, float(attacker_speed))
	var def: float = maxf(0.0, float(defender_speed))
	if def > atk:
		var percent: float = (def - atk) / atk * 100.0
		return clampf(percent / 2.0, 0.0, MAX_DODGE_CHANCE_PERCENT) / 100.0
	return 0.0

## True (and logs the miss) if `defender` has a speed-based dodge passive
## and rolls a successful dodge against `attacker` this hit.
func _rolls_dodge(attacker: CombatUnitState, defender: CombatUnitState) -> bool:
	if defender.enemy_def == null or not defender.enemy_def.dodge_uses_speed:
		return false
	if _rng.randf() >= dodge_chance(attacker.get_effective_speed(), defender.get_effective_speed()):
		return false
	_log("%s is too quick - %s's attack whiffs completely!" % [defender.display_name, attacker.display_name])
	return true

## True (and logs the shatter) exactly once per combat if `defender` has a
## shimmering shield that absorbs its very first hit - after that it behaves
## like a normal defender for the rest of the fight.
func _rolls_shield(attacker: CombatUnitState, defender: CombatUnitState) -> bool:
	if defender.enemy_def == null or not defender.enemy_def.absorbs_first_hit or defender.has_absorbed_hit:
		return false
	defender.has_absorbed_hit = true
	_log("%s's shimmering shield absorbs %s's attack completely, then shatters!" % [defender.display_name, attacker.display_name])
	return true

## Records the most recent hit the player took - not necessarily fatal, but
## if it turns out to be, this is exactly the info the defeat screen wants
## (who, what level, what kind of attack). Cheap to overwrite every hit
## rather than track "was this the killing blow" explicitly.
func _record_death_info(attacker_name: String, attacker_level: int, attack_label: String) -> void:
	last_death_info = {
		"attacker_name": attacker_name,
		"attacker_level": attacker_level,
		"attack_label": attack_label,
	}

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
	if _rolls_dodge(player_unit, target) or _rolls_shield(player_unit, target):
		stats_changed.emit()
		_finish_action()
		return

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
	else:
		_check_enrage(target)
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

	# Speed debuffs (e.g. a mage's freeze) last a number of rounds, not turns -
	# tick them here, before this round's order is computed, so an expiring
	# freeze is already gone by the round it wears off.
	for c in combatants:
		c.tick_speed_debuff()

	_round_queue = _compute_round_order(combatants)
	round_stage = 0
	_advance_round_action()

## Pure computation of one round's action order from a set of combatants -
## the speed-ratio algorithm described in the class doc comment. Factored out
## of _begin_new_round() so get_upcoming_turn_order() can preview a round
## without committing to it (used by the turn-order UI).
func _compute_round_order(combatants: Array[CombatUnitState]) -> Array[CombatUnitState]:
	var queue: Array[CombatUnitState] = []
	if combatants.is_empty():
		return queue

	var slowest_speed: float = INF
	for c in combatants:
		slowest_speed = minf(slowest_speed, float(maxi(1, c.get_effective_speed())))

	# One entry per combatant: how many actions it gets this round.
	var entries: Array[Dictionary] = []
	for c in combatants:
		var speed: float = float(maxi(1, c.get_effective_speed()))
		var actions: int = maxi(1, int(floor(speed / slowest_speed)))
		entries.append({"unit": c, "actions": actions})
	entries.sort_custom(func(a, b) -> bool:
		if a["actions"] != b["actions"]:
			return a["actions"] > b["actions"]
		return a["unit"].get_effective_speed() > b["unit"].get_effective_speed()
	)

	for entry in entries:
		var unit: CombatUnitState = entry["unit"]
		var actions: int = entry["actions"]
		for i in range(actions):
			queue.append(unit)
	return queue

## Upcoming actors in order, current turn first, for the turn-order UI.
## Reads the rest of this round straight from _round_queue (skipping anyone
## who has since died), then - if more entries are still wanted - previews a
## hypothetical next round computed from currently-alive combatants. That
## preview is a best-effort approximation (it assumes nobody's speed or
## alive-state changes before the round actually starts), same as the "always
## recalculated fresh" convention described in the class doc comment.
func get_upcoming_turn_order(max_count: int = 8) -> Array[CombatUnitState]:
	var result: Array[CombatUnitState] = []
	var i := round_stage
	while result.size() < max_count and i < _round_queue.size():
		if _round_queue[i].is_alive():
			result.append(_round_queue[i])
		i += 1

	if result.size() < max_count:
		var combatants: Array[CombatUnitState] = [player_unit]
		combatants.append_array(get_alive_allies())
		combatants.append_array(get_alive_enemies())
		var next_round := _compute_round_order(combatants)
		var j := 0
		while result.size() < max_count and j < next_round.size():
			result.append(next_round[j])
			j += 1
	return result

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

	# Poison ticks at the start of the poisoned unit's own turn, before they act.
	if acting_unit.is_poisoned():
		_apply_poison_tick(acting_unit)
		if not acting_unit.is_alive():
			if _check_combat_end():
				return
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

## Deals this unit's residual poison damage (bypassing defense entirely) and
## ticks the duration down. Grants enemy-defeat rewards if poison finishes them off.
func _apply_poison_tick(unit: CombatUnitState) -> void:
	var damage := unit.poison_damage_per_turn
	unit.current_health = maxi(0, unit.current_health - damage)
	unit.poison_turns_remaining -= 1
	_log("%s takes %d poison damage. (%d turn%s left)" % [
		unit.display_name, damage, unit.poison_turns_remaining,
		"" if unit.poison_turns_remaining == 1 else "s"
	])
	stats_changed.emit()
	if unit.is_player and unit.poison_source_name != "":
		_record_death_info(unit.poison_source_name, unit.poison_source_level, "poison")
	if not unit.is_alive():
		_log("%s succumbs to the poison!" % unit.display_name)
		if not unit.is_player and not unit.is_ally:
			_on_enemy_defeated(unit)
	else:
		_check_enrage(unit)
		_check_health_low(unit)

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
	if _rolls_dodge(ally, target) or _rolls_shield(ally, target):
		stats_changed.emit()
		_finish_action()
		return
	var multiplier := _resolve_damage_multiplier(ally, target)
	var raw_damage := int(round(float(ally.attack) * multiplier))
	var dealt := target.apply_damage(raw_damage)
	_log("%s attacks %s for %d damage." % [ally.display_name, target.display_name, dealt])
	stats_changed.emit()
	if not target.is_alive():
		_on_enemy_defeated(target)
	else:
		_check_enrage(target)
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
	var def := enemy.enemy_def
	enemy.actions_taken += 1

	# Fleeing enemy: once it's used up its allotted turns, it bolts instead of
	# acting again - takes priority over every other action type.
	if def != null and def.flees_after_turns > 0 and enemy.actions_taken >= def.flees_after_turns:
		_perform_flee(enemy)
		_finish_action()
		return

	# Miniboss special: call a fallen minion back into the fight instead of attacking.
	if def != null and def.can_summon_minions and _has_defeated_minion(def) and _rng.randf() < MINION_SUMMON_CHANCE:
		_perform_summon_minion(enemy, def)
		_finish_action()
		return

	# Assassin special: a self-buff that spends the whole turn instead of attacking -
	# only recast once the previous haste has actually worn off, not every eligible turn.
	if def != null and def.haste_spell_chance > 0.0 and enemy.speed_debuff_turns_remaining <= 0 and _rng.randf() < def.haste_spell_chance:
		_perform_haste_spell(enemy, def)
		_finish_action()
		return

	var party := _get_alive_party_members()
	if party.is_empty():
		_finish_action()
		return
	var target: CombatUnitState = party[_rng.randi_range(0, party.size() - 1)]

	# Miniboss special: a weaker direct hit that also poisons for residual damage.
	if def != null and def.poison_attack_chance > 0.0 and _rng.randf() < def.poison_attack_chance:
		_perform_enemy_poison_attack(enemy, target, def)
		_finish_action()
		return

	# Miniboss special: a low-damage spell with a chance to halve the target's Speed for a few rounds.
	if def != null and def.ice_spell_chance > 0.0 and _rng.randf() < def.ice_spell_chance:
		_perform_ice_spell(enemy, target, def)
		_finish_action()
		return

	# Boss special: needs several of its own turns to wind up before it actually lands a hit.
	if def != null and def.charges_before_attack > 1:
		enemy.charge_progress += 1
		if enemy.charge_progress < def.charges_before_attack:
			_log("%s winds up for a devastating blow..." % enemy.display_name)
			_finish_action()
			return
		enemy.charge_progress = 0

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
			_record_death_info(enemy.display_name, enemy.enemy_def.level if enemy.enemy_def != null else 1, "a basic attack")
		_check_health_low(target)
		if not target.is_alive() and not target.is_player:
			_log("%s has fallen!" % target.display_name)
	_finish_action()

## Removes a fleeing enemy from the fight without granting any of the normal
## defeat rewards - it steals a cut of the player's current gold on the way
## out (nothing if the player is broke) and is tracked separately in
## last_rewards so CombatHUD can report the theft instead of a kill.
func _perform_flee(enemy: CombatUnitState) -> void:
	var stolen := 0
	if enemy.enemy_def != null and RunManager.run != null and RunManager.run.currency > 0:
		stolen = int(round(float(RunManager.run.currency) * enemy.enemy_def.flee_steal_percent))
		if stolen > 0:
			RunManager.run.currency -= stolen
	enemy.current_health = 0
	if stolen > 0:
		_log("%s snatches %d gold and bolts away!" % [enemy.display_name, stolen])
	else:
		_log("%s bolts away!" % enemy.display_name)
	var fled: Array = last_rewards.get("fled_enemies", [])
	fled.append(enemy.display_name)
	last_rewards["fled_enemies"] = fled
	last_rewards["gold_stolen"] = int(last_rewards.get("gold_stolen", 0)) + stolen
	stats_changed.emit()

func _has_defeated_minion(boss_def: EnemyDefinition) -> bool:
	for e in enemy_units:
		if not e.is_alive() and e.enemy_def != null and e.enemy_def.id == boss_def.summon_minion_id:
			return true
	return false

func _perform_summon_minion(boss: CombatUnitState, boss_def: EnemyDefinition) -> void:
	for e in enemy_units:
		if not e.is_alive() and e.enemy_def != null and e.enemy_def.id == boss_def.summon_minion_id:
			e.current_health = e.max_health
			e.health_low_triggered = false
			_log("%s calls %s back into the fight!" % [boss.display_name, e.display_name])
			stats_changed.emit()
			return

func _perform_enemy_poison_attack(attacker: CombatUnitState, target: CombatUnitState, def: EnemyDefinition) -> void:
	var multiplier := _resolve_damage_multiplier(attacker, target)
	var raw_damage := int(round(float(attacker.attack) * 0.6 * multiplier))
	var dealt := target.apply_damage(raw_damage)
	target.apply_poison(def.poison_damage_per_turn, def.poison_duration_turns, attacker.display_name, def.level)
	_log("%s lands a debilitating strike on %s for %d damage - poisoned for %d turns!" % [
		attacker.display_name, target.display_name, dealt, def.poison_duration_turns
	])
	stats_changed.emit()
	if target.is_player:
		EventBus.player_took_damage.emit({"combat": self, "amount": dealt})
		_record_death_info(attacker.display_name, def.level, "a debilitating strike")
	_check_health_low(target)

## Low direct damage, but a chance to halve the target's Speed for a few
## rounds - unlike poison, this never deals residual damage, it just makes
## the target act less often (see CombatUnitState.get_effective_speed()).
func _perform_ice_spell(attacker: CombatUnitState, target: CombatUnitState, def: EnemyDefinition) -> void:
	var multiplier := _resolve_damage_multiplier(attacker, target)
	var raw_damage := int(round(float(attacker.attack) * 0.4 * multiplier))
	var dealt := target.apply_damage(raw_damage)
	var froze := _rng.randf() < def.ice_freeze_chance
	if froze:
		target.apply_speed_debuff(def.ice_freeze_multiplier, def.ice_freeze_duration_rounds)
	_log("%s casts a freezing spell on %s for %d damage%s" % [
		attacker.display_name, target.display_name, dealt,
		" - their Speed is frozen!" if froze else "."
	])
	stats_changed.emit()
	if target.is_player:
		EventBus.player_took_damage.emit({"combat": self, "amount": dealt})
		_record_death_info(attacker.display_name, def.level, "an ice spell")
	_check_health_low(target)

## Assassin special: buffs its own Speed for several rounds instead of
## attacking this turn - the exact same mechanism as the ice spell's freeze
## (CombatUnitState.apply_speed_debuff()), just with a multiplier above 1.0
## instead of below it, so no new state needed on the unit at all.
func _perform_haste_spell(caster: CombatUnitState, def: EnemyDefinition) -> void:
	caster.apply_speed_debuff(def.haste_multiplier, def.haste_duration_rounds)
	_log("%s murmurs a quickening word and blurs with sudden speed!" % caster.display_name)
	stats_changed.emit()

## Boss special: a one-time self-heal plus fresh reinforcements once this
## unit's health drops to/below EnemyDefinition.enrages_below_health_percent.
## Checked alongside _check_health_low() at every place an enemy takes damage.
func _check_enrage(unit: CombatUnitState) -> void:
	if unit.is_player or unit.is_ally or unit.enemy_def == null or not unit.is_alive():
		return
	var def := unit.enemy_def
	if def.enrages_below_health_percent <= 0.0 or unit.has_enraged:
		return
	if float(unit.current_health) / float(unit.max_health) > def.enrages_below_health_percent:
		return
	unit.has_enraged = true
	var heal_amount := int(round(float(unit.max_health) * def.enrage_heal_percent))
	unit.current_health = mini(unit.max_health, unit.current_health + heal_amount)
	_log("%s roars and tears its wounds shut, recovering %d health!" % [unit.display_name, heal_amount])
	if def.enrage_summon_id != "" and def.enrage_summon_count > 0:
		_summon_fresh_enemies(def.enrage_summon_id, def.enrage_summon_count)
		_log("%s calls for reinforcements!" % unit.display_name)
	stats_changed.emit()

## Adds brand-new, full-health enemies to an ongoing fight (e.g. an enrage
## summon). enemy_units is read fresh by _begin_new_round() every round, so
## the newcomers are automatically included in the very next round's turn
## order with no further wiring - only the visuals need telling (roster_changed).
func _summon_fresh_enemies(enemy_id: String, count: int) -> void:
	var summon_def := EnemyRegistry.get_enemy(enemy_id)
	if summon_def == null:
		return
	for i in range(count):
		enemy_units.append(CombatUnitState.from_enemy(summon_def))
	roster_changed.emit()

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
	enemy_visual_defeated.emit(enemy)
	if RunManager.run == null:
		return
	RunManager.run.defeated_enemy_names.append(enemy.display_name)

	var currency_reward := enemy.enemy_def.currency_reward if enemy.enemy_def != null else 0
	var context := {"combat": self, "enemy": enemy, "currency_reward": currency_reward}
	EventBus.enemy_defeated.emit(context)
	RunManager.run.currency += int(context.get("currency_reward", 0))

	if enemy.enemy_def != null and enemy.enemy_def.guaranteed_artifact_id != "":
		var guaranteed_id := enemy.enemy_def.guaranteed_artifact_id
		RunManager.run.add_artifact(guaranteed_id)
		(last_rewards["guaranteed_artifacts"] as Array).append(guaranteed_id)

	if enemy.enemy_def != null and enemy.enemy_def.guarantees_random_artifact:
		var random_artifact := ArtifactRegistry.get_random(_rng, RunManager.run.class_id)
		if random_artifact != null:
			RunManager.run.add_artifact(random_artifact.id)
			(last_rewards["guaranteed_artifacts"] as Array).append(random_artifact.id)

	if enemy.enemy_def != null and enemy.enemy_def.on_defeat_story_flag_id != "":
		RunManager.run.story_flags[enemy.enemy_def.on_defeat_story_flag_id] = true

	if enemy.enemy_def != null and enemy.enemy_def.on_defeat_counter_id != "":
		RunManager.increment_counter(enemy.enemy_def.on_defeat_counter_id)

	if enemy.enemy_def != null:
		var completed_quests := RunManager.register_enemy_kill_for_quests(enemy.enemy_def.id)
		for quest_id in completed_quests:
			var quest_def := QuestRegistry.get_quest(quest_id)
			if quest_def != null:
				_log("Mission complete: %s! Reward: %s." % [quest_def.display_name, quest_def.describe_reward()])

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

	_check_heal_seal()

## Bug Catcher Joe's special: the moment its whole swarm is gone and it's the
## only enemy left standing in the fight, EnemyDefinition.seals_healing_when_alone
## seals the player's healing for the rest of combat (see player_use_item(),
## the HEAL branch of player_use_ability(), and heal_player()). Checked after
## every defeat rather than tied to a specific enemy dying, since it doesn't
## matter which of the minions falls last.
func _check_heal_seal() -> void:
	var alive := get_alive_enemies()
	if alive.size() != 1:
		return
	var last_standing := alive[0]
	if last_standing.enemy_def == null or not last_standing.enemy_def.seals_healing_when_alone:
		return
	if player_unit.heal_sealed:
		return
	player_unit.heal_sealed = true
	var msg := last_standing.enemy_def.heal_seal_message
	if msg == "":
		msg = "%s snarls, and a stifling pressure settles over your wounds - your healing is sealed for the rest of this fight!" % last_standing.display_name
	_log(msg)

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

func _finish_combat(victory: bool, fled: bool = false) -> void:
	awaiting_player_input = false
	if RunManager.run != null:
		RunManager.run.current_health = player_unit.current_health
		RunManager.run.current_resource = player_unit.current_resource
	var context := {"combat": self, "victory": victory, "fled": fled}
	EventBus.combat_ended.emit(context)
	if victory and not fled:
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
	# Nothing was actually defeated (e.g. every enemy fled) - no surprise loot either.
	if not _defeated_this_combat.is_empty() and _rng.randf() < 0.15:
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
