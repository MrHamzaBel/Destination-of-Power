class_name ExplorationHUD
extends Control
## Heads-up display for exploration scenes: health/resource bars, objective
## text, interaction prompts and transient notifications.

@onready var health_bar: ProgressBar = %HealthBar
@onready var resource_bar: ProgressBar = %ResourceBar
@onready var resource_label: Label = %ResourceLabel
@onready var level_gold_label: Label = %LevelGoldLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var prompt_label: Label = %PromptLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel

var _player: PlayerCharacter

func setup(player: PlayerCharacter) -> void:
	_player = player
	notification_panel.visible = false
	prompt_label.visible = false
	refresh_stats()

func _process(_delta: float) -> void:
	if _player == null:
		return
	var interactable := _player.get_current_interactable()
	prompt_label.visible = interactable != null
	if interactable != null:
		prompt_label.text = "Press E to interact with %s" % interactable.display_name

func refresh_stats() -> void:
	if RunManager.run == null:
		return
	var stats := RunManager.compute_current_stats()
	health_bar.max_value = max(1, stats.max_health)
	health_bar.value = RunManager.run.current_health
	resource_bar.max_value = max(1, stats.max_resource)
	resource_bar.value = RunManager.run.current_resource
	var class_def := RunManager.get_class_def()
	resource_label.text = (class_def.resource_label if class_def != null else "Resource")
	level_gold_label.text = "Level %d   Gold: %d" % [RunManager.run.level, RunManager.run.currency]

func set_objective(text: String) -> void:
	objective_label.text = text

func show_notification(text: String) -> void:
	notification_label.text = text
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_property(notification_panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): notification_panel.visible = false)
