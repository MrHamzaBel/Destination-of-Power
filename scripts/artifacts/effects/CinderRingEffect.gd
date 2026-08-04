class_name CinderRingEffect
extends ArtifactEffectBase
## Cinder Ring: after the player takes damage, their next attack deals bonus damage.

var _primed: bool = false

func on_combat_started(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	_primed = false

func on_player_took_damage(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	_primed = true

func on_player_attacked(context: Dictionary, def: ArtifactDefinition, stacks: int) -> void:
	if not _primed:
		return
	var bonus: float = float(def.effect_values.get("bonus_damage", 4)) * stacks
	context["damage"] = int(context.get("damage", 0)) + int(bonus)
	context["log_extra"] = context.get("log_extra", "") + " Cinder Ring flares for +%d damage!" % int(bonus)
	_primed = false
