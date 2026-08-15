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

## While this enemy is alive, CombatManager.get_current_target()/set_target()
## force every single-target action (player basic attack, player ATTACK-type
## ability, ally auto-attack) onto it - a "taunt." This only touches the
## single-target resolution path: a future AOE ability
## (AbilityDefinition.target_type == ALL_ENEMIES) would hit every enemy
## directly via CombatManager.get_alive_enemies() rather than calling
## get_current_target() at all, so it bypasses taunt automatically once that
## resolution logic exists - no taunt-side change needed when it's added.
@export var taunts_all_attacks: bool = false

## --- Fire spell (mage special: bonus damage, no status effect - the offensive counterpart to the ice/poison spells above) ---
@export var fire_spell_chance: float = 0.0 ## Chance per turn to cast instead of attacking normally. 0 = never.
@export var fire_damage_bonus_percent: float = 0.0 ## Extra damage over a normal attack, e.g. 50.0 = +50%.

## --- Ally healing (support enemy special: heals its most-injured living ally on a fixed schedule instead of attacking) ---
@export var heals_allies_every_turns: int = 0 ## Every Nth of this unit's own actions, it heals instead of attacking. 0 = never.
@export var heal_allies_percent: float = 0.0 ## Fraction of the healed ally's max health restored.

## --- Counter (East Checkpoint "Parry Counter" special: instantly reflects a
## fraction of any hit landed on this enemy back at whoever landed it) ---
@export var counters_damage_percent: float = 0.0 ## 0 = no counter. Reflected amount is always at least 1.

## --- Gambler blast (East Checkpoint special: a spell whose damage is fully
## random each cast, from a total whiff up to a big hit - the swinginess is
## the point, unlike every other spell's fixed damage-vs-chance shape) ---
@export var gambler_blast_chance: float = 0.0 ## Chance per turn to cast instead of attacking normally. 0 = never.

## --- Lucky Shot (East Checkpoint special: every normal attack has a flat
## chance to immediately strike again for a fraction of the first hit) ---
@export var lucky_shot_chance: float = 0.0 ## 0 = never triggers.
@export var lucky_shot_bonus_percent: float = 50.0 ## Second hit's damage, as a fraction of the first hit's.

## --- Ward (East Checkpoint "Defender" special: casts a re-appliable, no-
## turn-limit shield on one living ally - CombatUnitState.shielded, checked
## by _rolls_shield() alongside the existing one-time absorbs_first_hit) ---
@export var wards_allies_chance: float = 0.0 ## Chance per turn to cast instead of attacking normally. 0 = never.

## --- AOE slam (boss special: hits every living player-side combatant at once) ---
@export var aoe_slam_chance: float = 0.0 ## Chance per turn to cast instead of attacking normally. 0 = never.
@export var aoe_slam_damage_multiplier: float = 1.0 ## Per-target damage, relative to a normal attack.

## --- Piercing stun (boss special: a one-time party-wide stun once health
## drops to/below this fraction - CombatUnitState.stun_turns_remaining, same
## one-time-guard shape as the enrage phase above) ---
@export var stuns_at_health_percent: float = 0.0 ## 0 = never triggers, else the health fraction (0-1) that triggers it.
