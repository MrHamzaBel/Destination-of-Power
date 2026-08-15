class_name SerpentsFangEffect
extends ArtifactEffectBase
## Serpent's Fang: heals the player for a fraction of every hit they land,
## torn from the forest snake it once belonged to.

func on_player_dealt_damage(context: Dictionary, def: ArtifactDefinition, stacks: int) -> void:
	var damage := int(context.get("damage", 0))
	if damage <= 0:
		return
	var percent: float = float(def.effect_values.get("lifesteal_percent", 0.1))
	var heal_amount := maxi(1, int(round(float(damage) * percent * stacks)))
	var combat = context.get("combat")
	if combat != null:
		combat.heal_player(heal_amount, "Serpent's Fang")
