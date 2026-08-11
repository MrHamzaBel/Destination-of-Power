class_name FlatStatBonusEffect
extends ArtifactEffectBase
## Generic flat single-stat bonus, parameterized by effect_values ("stat":
## one of attack/defense/speed/intelligence/max_health/max_resource, "amount":
## int) - the basic common-rarity artifacts all reuse this one class instead
## of each needing their own near-identical effect script.

func get_passive_stat_modifier(def: ArtifactDefinition) -> StatBlock:
	var modifier := StatBlock.new()
	var amount: int = int(def.effect_values.get("amount", 0))
	match String(def.effect_values.get("stat", "attack")):
		"attack":
			modifier.attack = amount
		"defense":
			modifier.defense = amount
		"speed":
			modifier.speed = amount
		"intelligence":
			modifier.intelligence = amount
		"max_health":
			modifier.max_health = amount
		"max_resource":
			modifier.max_resource = amount
	return modifier
