class_name CombatUnitState
extends RefCounted
## Runtime combat state for one participant (player, ally or enemy). Built
## fresh each time combat starts from the player's current stats/run data,
## an EnemyDefinition, or an AllyDefinition - never persisted directly.

var display_name: String = ""
var is_player: bool = false
var is_ally: bool = false
var enemy_def: EnemyDefinition = null
var ally_def: AllyDefinition = null

var max_health: int = 1
var current_health: int = 1
var max_resource: int = 0
var current_resource: int = 0
var attack: int = 0
var intelligence: int = 0
var defense: int = 0
var speed: int = 0

var abilities: Array[String] = []
var is_defending: bool = false
var defense_bonus_percent: float = 0.0 ## Active until this unit's next turn starts.
var health_low_triggered: bool = false ## Ensures the health_low event fires once per combat.

var poison_turns_remaining: int = 0
var poison_damage_per_turn: int = 0
var poison_source_name: String = "" ## Who inflicted the active poison - used to credit poison-tick deaths correctly.
var poison_source_level: int = 0
var actions_taken: int = 0 ## Counts this unit's own resolved actions this combat - used by e.g. fleeing enemies.

func is_alive() -> bool:
	return current_health > 0

## Refreshes (not stacks) this unit's poison - applying poison again just
## resets the duration/damage rather than accumulating multiple instances.
func apply_poison(damage_per_turn: int, duration_turns: int, source_name: String = "", source_level: int = 0) -> void:
	poison_damage_per_turn = damage_per_turn
	poison_turns_remaining = duration_turns
	poison_source_name = source_name
	poison_source_level = source_level

func is_poisoned() -> bool:
	return poison_turns_remaining > 0

## Defense used for the attack-vs-defense damage formula. Defending/Guard-type
## abilities temporarily raise this via defense_bonus_percent until this
## unit's next turn (cleared in clear_turn_effects()).
func get_effective_defense() -> float:
	return float(defense) * (1.0 + defense_bonus_percent)

## Applies a final, already-formula-resolved damage amount (see
## CombatManager's damage formula) and returns how much was actually dealt.
func apply_damage(amount: int) -> int:
	var dealt := maxi(1, amount)
	current_health = maxi(0, current_health - dealt)
	return dealt

func clear_turn_effects() -> void:
	is_defending = false
	defense_bonus_percent = 0.0

static func from_player() -> CombatUnitState:
	var unit := CombatUnitState.new()
	var stats := RunManager.compute_current_stats()
	var class_def := RunManager.get_class_def()
	unit.display_name = RunManager.character_profile.character_name if RunManager.character_profile != null else "Hero"
	unit.is_player = true
	unit.max_health = max(1, stats.max_health)
	unit.current_health = clampi(RunManager.run.current_health, 0, unit.max_health)
	unit.max_resource = stats.max_resource
	unit.current_resource = clampi(RunManager.run.current_resource, 0, unit.max_resource)
	unit.attack = stats.attack
	unit.intelligence = stats.intelligence
	unit.defense = stats.defense
	unit.speed = stats.speed
	unit.abilities = class_def.abilities.duplicate() if class_def != null else []
	return unit

static func from_enemy(def: EnemyDefinition) -> CombatUnitState:
	var unit := CombatUnitState.new()
	unit.display_name = def.display_name
	unit.is_player = false
	unit.enemy_def = def
	unit.max_health = max(1, def.stats.max_health)
	unit.current_health = unit.max_health
	unit.max_resource = def.stats.max_resource
	unit.current_resource = unit.max_resource
	unit.attack = def.stats.attack
	unit.intelligence = def.stats.intelligence
	unit.defense = def.stats.defense
	unit.speed = def.stats.speed
	unit.abilities = def.abilities.duplicate()
	return unit

static func from_ally(def: AllyDefinition) -> CombatUnitState:
	var unit := CombatUnitState.new()
	unit.display_name = def.display_name
	unit.is_player = false
	unit.is_ally = true
	unit.ally_def = def
	unit.max_health = max(1, def.stats.max_health)
	unit.current_health = unit.max_health
	unit.max_resource = def.stats.max_resource
	unit.current_resource = unit.max_resource
	unit.attack = def.stats.attack
	unit.intelligence = def.stats.intelligence
	unit.defense = def.stats.defense
	unit.speed = def.stats.speed
	unit.abilities = []
	return unit
