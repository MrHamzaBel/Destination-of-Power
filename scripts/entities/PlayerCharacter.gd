class_name PlayerCharacter
extends CharacterBody2D
## Top-down exploration controller. Renders the saved appearance via
## CharacterAppearanceRenderer and tracks nearby Interactable objects.

const SPEED: float = 150.0

@onready var appearance: CharacterAppearanceRenderer = %Appearance
@onready var interaction_area: Area2D = %InteractionArea

var _nearby_interactables: Array[Interactable] = []

func _ready() -> void:
	appearance.apply_profile(RunManager.character_profile)
	appearance.scale = Vector2(0.6, 0.6)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	velocity = input_dir.normalized() * SPEED if input_dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

func try_interact() -> void:
	var target := get_current_interactable()
	if target != null:
		target.trigger()

func get_current_interactable() -> Interactable:
	return _nearby_interactables[0] if _nearby_interactables.size() > 0 else null

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		_nearby_interactables.append(area)

func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_nearby_interactables.erase(area)
