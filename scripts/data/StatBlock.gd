class_name StatBlock
extends Resource
## Core combat statistics shared by classes, enemies and equipment modifiers.
##
## The five core stats are HP, Attack, Defense, Speed and Intelligence.
## Every character starts with 5 in each; a class raises exactly one of them
## by +5 (see ClassDefinition.impact_stat). HP is the odd one out: its raw
## stat value is multiplied by HP_STAT_MULTIPLIER before being stored in
## max_health so a "5" stat translates into a survivable health pool instead
## of 5 literal hit points. max_resource (mana/stamina/energy) is a separate,
## per-class pool and not one of the five core stats.
## Add a new core stat later by adding a field here and touching whatever
## combat/UI code should read it - everything else (items, artifacts,
## classes) already flows through this same resource.

const HP_STAT_MULTIPLIER: int = 10

@export var max_health: int = 50
@export var max_resource: int = 0 ## Mana / energy / class resource pool.
@export var attack: int = 5 ## Physical power, used by weapon attacks.
@export var intelligence: int = 5 ## Magical power, used by spell-like abilities.
@export var defense: int = 5 ## Flat damage reduction.
@export var speed: int = 5 ## Determines turn order.

func duplicate_stats() -> StatBlock:
	var copy := StatBlock.new()
	copy.max_health = max_health
	copy.max_resource = max_resource
	copy.attack = attack
	copy.intelligence = intelligence
	copy.defense = defense
	copy.speed = speed
	return copy

func add(other: StatBlock) -> StatBlock:
	var result := duplicate_stats()
	if other == null:
		return result
	result.max_health += other.max_health
	result.max_resource += other.max_resource
	result.attack += other.attack
	result.intelligence += other.intelligence
	result.defense += other.defense
	result.speed += other.speed
	return result
