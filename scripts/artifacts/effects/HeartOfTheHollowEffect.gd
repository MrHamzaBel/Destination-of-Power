class_name HeartOfTheHollowEffect
extends ArtifactEffectBase
## Heart of the Hollow: a shard of crystallized resilience and insight -
## flat Defense and Intelligence while held. Purely passive, like Broken
## Crown, so it only needs the stat modifier hook.

func get_passive_stat_modifier(def: ArtifactDefinition) -> StatBlock:
	var modifier := StatBlock.new()
	modifier.defense = int(def.effect_values.get("defense_bonus", 8))
	modifier.intelligence = int(def.effect_values.get("intelligence_bonus", 6))
	return modifier
