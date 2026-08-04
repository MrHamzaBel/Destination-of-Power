class_name ThornedCoinEffect
extends ArtifactEffectBase
## Thorned Coin: gain more gold from combat rewards, but shop prices are also
## increased (price multiplier is exposed for a future shop system).

func on_enemy_defeated(context: Dictionary, def: ArtifactDefinition, stacks: int) -> void:
	var multiplier: float = 1.0 + float(def.effect_values.get("gold_bonus_percent", 0.25)) * stacks
	if context.has("currency_reward"):
		context["currency_reward"] = int(round(float(context["currency_reward"]) * multiplier))

func get_shop_price_multiplier(def: ArtifactDefinition, stacks: int) -> float:
	return 1.0 + float(def.effect_values.get("price_increase_percent", 0.15)) * stacks
