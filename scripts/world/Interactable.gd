class_name Interactable
extends Area2D
## Generic interactable object placed in exploration scenes: a message
## notification, a combat trigger, a scene exit, or a healing spot.
## Configure per-instance in the editor/scene file - no subclassing needed.

enum Kind { MESSAGE, COMBAT, EXIT, HEAL, ITEM }

@export var display_name: String = "Object"
@export var kind: Kind = Kind.MESSAGE
@export_multiline var message: String = ""
@export var enemy_ids: Array[String] = []
@export var item_id: String = "" ## Used when kind == ITEM.
@export var item_quantity: int = 1
@export var one_shot: bool = false ## If true, disables itself after one trigger.
@export var victory_return_scene: String = "" ## COMBAT only: scene to load after victory instead of the default.
@export var story_flag_id: String = "" ## If set, this interactable only fires once per run (persisted in RunData.story_flags).

signal interacted(source: Interactable)

var _used: bool = false

func _ready() -> void:
	add_to_group("interactables")

func trigger() -> void:
	if _used and one_shot:
		return
	_used = true
	interacted.emit(self)
	if one_shot:
		monitorable = false
		set_deferred("monitoring", false)
