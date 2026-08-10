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
## Optional real artwork. If set, EnemyCharacter renders this Sprite2D instead
## of the shape_points placeholder polygon - drop in a texture and the enemy
## instantly upgrades from a colored blob to real art with no other changes.
@export var texture: Texture2D = null

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

## If true, every attack against this enemy first rolls a dodge chance based
## on its Speed vs the attacker's Speed (see CombatManager.dodge_chance()) -
## the same attack-vs-defense formula shape, just Speed instead of
## Attack/Defense, and a complete miss instead of a damage reduction.
@export var dodge_uses_speed: bool = false

## --- Ice spell (miniboss special: like the poison attack, but debuffs Speed instead of dealing residual damage) ---
@export var ice_spell_chance: float = 0.0 ## Chance per turn to cast instead of attacking normally. 0 = never.
@export var ice_freeze_chance: float = 0.5 ## Chance the cast actually freezes (independent of whether it hits).
@export var ice_freeze_multiplier: float = 0.5 ## Speed multiplier while frozen, e.g. 0.5 = half Speed.
@export var ice_freeze_duration_rounds: int = 3

## --- Charge attack (boss special: needs this many of its own turns to land one hit) ---
@export var charges_before_attack: int = 0 ## 0 or 1 = attacks normally every turn; 2+ = winds up first.

## --- Enrage phase (boss special: a one-time self-heal + reinforcements once health drops low enough) ---
@export var enrages_below_health_percent: float = 0.0 ## 0 = never enrages, else the health fraction (0-1) that triggers it.
@export var enrage_heal_percent: float = 0.0 ## Fraction of max health restored when enraging.
@export var enrage_summon_id: String = "" ## Enemy id freshly spawned as reinforcements when enraging.
@export var enrage_summon_count: int = 0

## If true, a random artifact (from the normal drop pool, class-filtered) is
## granted on defeat regardless of the normal random-drop chance roll -
## unlike guaranteed_artifact_id, it isn't always the same one.
@export var guarantees_random_artifact: bool = false

## If set, increments this key in RunData.counters the moment this enemy is
## defeated - lets several different enemy types contribute to one shared
## tally (e.g. "how many of this room's guards are dead") without any of
## them needing to know about each other.
@export var on_defeat_counter_id: String = ""

## If true, the very first hit this enemy would take each combat is negated
## entirely (a shimmering shield that shatters instead) - a one-time guard,
## same shape as dodge but unconditional on the first hit rather than a
## per-hit Speed roll.
@export var absorbs_first_hit: bool = false

## --- Self-haste (an assassin's speed-up spell: the inverse of the ice spell's freeze) ---
@export var haste_spell_chance: float = 0.0 ## Chance per turn to buff its own Speed instead of attacking, while not already hasted. 0 = never.
@export var haste_multiplier: float = 2.0 ## Speed multiplier while hasted, e.g. 2.0 = double Speed.
@export var haste_duration_rounds: int = 4

## --- Heal seal (Bug Catcher Joe's special: turns hostile once its swarm is
## gone) - true means this unit permanently seals the player's healing (no
## items, abilities or artifact heals) for the rest of combat the moment it
## becomes the last enemy still standing in the fight, i.e. every other enemy
## present at combat start has been defeated. Checked in
## CombatManager._check_heal_seal(), called from _on_enemy_defeated(). ---
@export var seals_healing_when_alone: bool = false
@export_multiline var heal_seal_message: String = "" ## Shown when the seal triggers. Falls back to a generic line if empty.
