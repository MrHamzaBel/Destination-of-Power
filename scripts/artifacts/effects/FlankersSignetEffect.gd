class_name FlankersSignetEffect
extends ArtifactEffectBase
## Flanker's Signet: the mercenary group's own signet ring, taken off their
## leader. Flat Defense, Speed and Intelligence while held - purely passive,
## like Heart of the Hollow, so it only needs the stat modifier hook.

func get_passive_stat_modifier(def: ArtifactDefinition) -> StatBlock:
	var modifier := StatBlock.new()
	modifier.defense = int(def.effect_values.get("defense_bonus", 2))
	modifier.speed = int(def.effect_values.get("speed_bonus", 2))
	modifier.intelligence = int(def.effect_values.get("intelligence_bonus", 4))
	return modifier
