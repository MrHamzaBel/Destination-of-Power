class_name BugCatchersNetEffect
extends ArtifactEffectBase
## Bug Catcher's Net: flat Speed bonus while held. Purely passive, like
## Broken Crown and Heart of the Hollow, so it only needs the stat modifier hook.

func get_passive_stat_modifier(def: ArtifactDefinition) -> StatBlock:
	var modifier := StatBlock.new()
	modifier.speed = int(def.effect_values.get("speed_bonus", 6))
	return modifier
