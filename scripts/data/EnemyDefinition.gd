class_name EnemyDefinition
extends Resource
## Data-driven definition for an enemy encountered in combat.

enum BehaviorType { AGGRESSIVE, DEFENSIVE, RANDOM }

@export var id: String = ""
@export var display_name: String = ""
@export var stats: StatBlock = null
@export var abilities: Array[String] = [] ## Ability ids this enemy can use in addition to a basic attack.
@export var loot_table: Array[Dictionary] = [] ## [{"item_id": String, "chance": float}]
@export var behavior_type: BehaviorType = BehaviorType.AGGRESSIVE
@export var level: int = 1 ## Used to scale experience rewards against the player's level.
@export var xp_reward: int = 0
@export var currency_reward: int = 0
@export var body_color: Color = Color(0.6, 0.2, 0.2)
@export var shape_points: PackedVector2Array = PackedVector2Array()
