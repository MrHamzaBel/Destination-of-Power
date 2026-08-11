class_name RushingEnemy
extends CharacterBody2D
## A mobile enemy placed directly in an exploration scene that charges the
## player on sight and forces combat on contact - no interact key needed.
## A reusable alternative to the standard interact-to-fight
## Interactable(kind=COMBAT) for "ambush" style threats. Configure entirely
## per-instance in the editor; ExplorationArea wires up every node in the
## "rushing_enemies" group automatically (see _connect_rushing_enemies()).

signal rushed(source: RushingEnemy)
signal aggroed(source: RushingEnemy)

@export var display_name: String = "Enemy"
@export var enemy_ids: Array[String] = []
@export var chase_speed: float = 110.0
@export var detection_radius: float = 220.0
@export var catch_radius: float = 30.0
@export var victory_return_scene: String = "" ## Falls back to the current scene if unset.
@export_multiline var rush_notification: String = "" ## Shown once, the moment this enemy spots the player.

var _player: Node2D = null
var _aggroed: bool = false
var _triggered: bool = false

func _ready() -> void:
	add_to_group("rushing_enemies")
	# Notifications (e.g. the aggro rush_notification below) now pause the
	# tree until dismissed - without this, a chasing enemy would freeze
	# mid-pursuit the instant it spots the player, only resuming once the
	# player dismisses a message they may not even have noticed yet.
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_target(player: Node2D) -> void:
	_player = player

func _physics_process(_delta: float) -> void:
	if _triggered or _player == null or not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	var distance := to_player.length()

	if not _aggroed and distance <= detection_radius:
		_aggroed = true
		aggroed.emit(self)

	if not _aggroed:
		return
	if distance <= catch_radius:
		_triggered = true
		velocity = Vector2.ZERO
		rushed.emit(self)
		return

	velocity = to_player.normalized() * chase_speed
	move_and_slide()
