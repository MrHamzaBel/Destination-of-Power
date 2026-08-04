class_name MoonstoneCharmEffect
extends ArtifactEffectBase
## Moonstone Charm: restore a small amount of health after winning combat.

func on_combat_ended(context: Dictionary, def: ArtifactDefinition, stacks: int) -> void:
	if not context.get("victory", false):
		return
	var heal_amount: int = int(def.effect_values.get("heal_amount", 6)) * stacks
	var combat = context.get("combat")
	if combat != null:
		combat.heal_player(heal_amount, "Moonstone Charm")
