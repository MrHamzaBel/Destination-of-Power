class_name ArtifactEffectBase
extends RefCounted
## Base class for a reusable artifact passive effect. One subclass per artifact
## behaviour (see scripts/artifacts/effects/) - concrete effects override only
## the hooks they care about instead of living inside one giant conditional.
##
## Each hook receives the ArtifactDefinition (for its effect_values) and the
## current stack count, plus a context Dictionary describing the triggering
## event. Dictionaries are passed by reference in GDScript, so mutating
## context fields (e.g. "damage") is how an effect changes combat outcomes.

func on_combat_started(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_turn_started(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_player_attacked(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_player_took_damage(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_enemy_defeated(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_combat_ended(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_item_used(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

func on_health_low(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

## Only called for ArtifactDefinition.usable == true artifacts, via
## RunManager.use_artifact() - the player manually triggering the effect
## (e.g. Thorned Coin's gold burst) rather than it firing off a combat hook.
func on_manually_used(_context: Dictionary, _def: ArtifactDefinition, _stacks: int) -> void:
	pass

## Optional constant stat modifier applied while the artifact is held
## (e.g. Broken Crown's max health/defense trade-off). Return null for
## purely event-driven artifacts.
func get_passive_stat_modifier(_def: ArtifactDefinition) -> StatBlock:
	return null
