class_name WarlordsRenewalEffect
extends ArtifactEffectBase
## Warlord's Renewal: once per combat, the moment the player's health drops
## low, the relic surges and heals them - a toned-down echo of the
## Underground Warlord's own 50% self-heal (25% for the player, once, not
## repeatable within the same fight).

var _used: bool = false

func on_combat_started(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	_used = false

func on_health_low(context: Dictionary, def: ArtifactDefinition, _stacks: int) -> void:
	if _used:
		return
	var combat: CombatManager = context.get("combat")
	var unit: CombatUnitState = context.get("unit")
	if combat == null or unit == null or unit != combat.player_unit:
		return
	_used = true
	var heal_amount := int(round(float(def.effect_values.get("heal_percent", 0.25)) * float(unit.max_health)))
	combat.heal_player(heal_amount, "Warlord's Renewal")
