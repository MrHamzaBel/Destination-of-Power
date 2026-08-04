class_name VenomousFangEffect
extends ArtifactEffectBase
## Rat King's Fang: each attack has a chance to poison the target for
## residual damage over several turns (refreshes rather than stacks with
## itself if reapplied before the previous poison wears off).

func on_player_attacked(context: Dictionary, def: ArtifactDefinition, stacks: int) -> void:
	var target: CombatUnitState = context.get("target")
	var combat: CombatManager = context.get("combat")
	if target == null or combat == null or not target.is_alive():
		return
	var chance: float = float(def.effect_values.get("poison_chance", 0.1)) * stacks
	chance = clampf(chance, 0.0, 0.9)
	if combat.get_rng().randf() >= chance:
		return
	var damage: int = int(def.effect_values.get("poison_damage", 5))
	var duration: int = int(def.effect_values.get("poison_duration", 3))
	target.apply_poison(damage, duration)
	context["log_extra"] = context.get("log_extra", "") + " Rat King's Fang poisons %s!" % target.display_name
