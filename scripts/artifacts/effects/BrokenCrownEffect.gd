class_name BrokenCrownEffect
extends ArtifactEffectBase
## Broken Crown: increases maximum health but reduces defense. Purely passive,
## so it only needs to implement the stat modifier hook.

func get_passive_stat_modifier(def: ArtifactDefinition) -> StatBlock:
	var modifier := StatBlock.new()
	modifier.max_health = int(def.effect_values.get("health_bonus", 20))
	modifier.defense = -int(def.effect_values.get("defense_penalty", 4))
	return modifier
