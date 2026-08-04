class_name AbilityDefinition
extends Resource
## Data-driven definition for a combat ability usable by the player or an enemy.

enum AbilityType { ATTACK, HEAL, BUFF, DEFEND, UTILITY }
enum TargetType { ENEMY_SINGLE, SELF, ALL_ENEMIES }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var resource_cost: int = 0
@export var cooldown: int = 0
@export var power: float = 1.0 ## Multiplier applied to the relevant attack/intelligence stat.
@export var ability_type: AbilityType = AbilityType.ATTACK
@export var target_type: TargetType = TargetType.ENEMY_SINGLE
@export var uses_intelligence: bool = false ## If true scales off "intelligence" stat instead of "attack".
@export var is_ranged: bool = false ## Used by artifacts like Hunter's Eye that react to ranged attacks.
@export var defense_bonus_percent: float = 0.0 ## Used by DEFEND-type abilities.
@export var resource_restore_amount: int = 0 ## Used by UTILITY abilities like Focus.
@export var heal_amount: int = 0 ## Used by HEAL-type abilities.
