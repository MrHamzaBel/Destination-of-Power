class_name ThornedCoinEffect
extends ArtifactEffectBase
## Thorned Coin: a usable relic, not a passive one - once per run, spend it
## for an immediate burst of gold. Simple and direct by design, unlike the
## conditional/event-driven artifacts: pick it up, cash it in whenever you
## want the gold more than you want to keep holding it.

func on_manually_used(context: Dictionary, def: ArtifactDefinition, stacks: int) -> void:
	var run: RunData = context.get("run")
	if run == null:
		return
	var amount: int = int(def.effect_values.get("gold_amount", 40)) * stacks
	run.currency += amount
