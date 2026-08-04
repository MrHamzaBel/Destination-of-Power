class_name HuntersEyeEffect
extends ArtifactEffectBase
## Hunter's Eye: the first ranged attack in each combat has increased crit chance.

var _used_this_combat: bool = false

func on_combat_started(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	_used_this_combat = false

func on_player_attacked(context: Dictionary, def: ArtifactDefinition, _stacks: int) -> void:
	if _used_this_combat or not context.get("is_ranged", false):
		return
	var bonus: float = float(def.effect_values.get("crit_chance_bonus", 0.5))
	context["crit_chance_bonus"] = float(context.get("crit_chance_bonus", 0.0)) + bonus
	context["log_extra"] = context.get("log_extra", "") + " Hunter's Eye sharpens the shot!"
	_used_this_combat = true
