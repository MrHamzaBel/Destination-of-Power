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

## Optional taunt line logged when combat starts against this enemy.
@export_multiline var intro_quote: String = ""
## Guaranteed artifact granted on defeat, in addition to the normal random
## artifact-drop roll. "" = none.
@export var guaranteed_artifact_id: String = ""

## --- Miniboss special actions (all optional; a plain enemy leaves these at defaults) ---
@export var can_summon_minions: bool = false
@export var summon_minion_id: String = "" ## Enemy id of the minions this boss can call back when one has died.
@export var poison_attack_chance: float = 0.0 ## Chance per turn to use a poisoning attack instead of a normal one.
@export var poison_damage_per_turn: int = 0
@export var poison_duration_turns: int = 0

## --- Fleeing enemies (all optional; 0 = this enemy never flees) ---
@export var flees_after_turns: int = 0 ## On this many of its own actions, it flees instead of acting again.
@export var flee_steal_percent: float = 0.0 ## Fraction of the player's current gold stolen on a successful flee.

## If set, permanently marked true in RunData.story_flags the moment this
## enemy is defeated (not fled) - lets an exploration scene react to "this
## specific enemy is dead for good" without any pending-state bookkeeping.
@export var on_defeat_story_flag_id: String = ""
