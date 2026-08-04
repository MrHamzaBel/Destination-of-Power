extends Node
## Bridges collected artifacts to the EventBus. Keeps one persistent
## ArtifactEffectBase instance per held artifact (so effects like Cinder Ring
## can remember "primed" state between events) and fans out each combat event
## to every held artifact's matching hook.

var _instances: Dictionary = {} ## artifact_id(String) -> ArtifactEffectBase

func _ready() -> void:
	EventBus.combat_started.connect(_on_event.bind("on_combat_started"))
	EventBus.turn_started.connect(_on_event.bind("on_turn_started"))
	EventBus.player_attacked.connect(_on_event.bind("on_player_attacked"))
	EventBus.player_took_damage.connect(_on_event.bind("on_player_took_damage"))
	EventBus.enemy_defeated.connect(_on_event.bind("on_enemy_defeated"))
	EventBus.combat_ended.connect(_on_event.bind("on_combat_ended"))
	EventBus.item_used.connect(_on_event.bind("on_item_used"))
	EventBus.health_low.connect(_on_event.bind("on_health_low"))

func _on_event(context: Dictionary, hook_name: String) -> void:
	if RunManager.run == null:
		return
	_sync_instances()
	for artifact_id in RunManager.run.artifacts.keys():
		var effect: ArtifactEffectBase = _instances.get(artifact_id)
		var def := ArtifactRegistry.get_artifact(artifact_id)
		if effect == null or def == null:
			continue
		var stacks: int = RunManager.run.artifacts[artifact_id]
		effect.call(hook_name, context, def, stacks)

## Ensures exactly one effect instance exists per artifact currently held by
## the active run, creating new ones and dropping stale ones as needed.
func _sync_instances() -> void:
	if RunManager.run == null:
		_instances.clear()
		return
	for artifact_id in RunManager.run.artifacts.keys():
		if not _instances.has(artifact_id):
			var def := ArtifactRegistry.get_artifact(artifact_id)
			if def != null:
				_instances[artifact_id] = ArtifactEffectFactory.create(def.effect_id)
	for artifact_id in _instances.keys().duplicate():
		if not RunManager.run.artifacts.has(artifact_id):
			_instances.erase(artifact_id)

func get_effect(artifact_id: String) -> ArtifactEffectBase:
	_sync_instances()
	return _instances.get(artifact_id)
