class_name ExplorationHUD
extends Control
## Heads-up display for exploration scenes: health/resource bars, objective
## text, interaction prompts and transient notifications.
##
## Notifications are reader-paced, not timer-paced: showing one pauses the
## tree (same mechanism PauseMenu/InventoryScreen/DialogueChoicePopup already
## use) and waits for the player to press Space/Enter (ui_advance) or click,
## same as the LoreIntro-style cinematics. A single show_notification() call
## can carry multiple pages - split on NOTIFICATION_PAGE_BREAK - so a long
## block of text (e.g. a quest pitch) can be broken into a couple of shorter
## screens instead of one wall of text.

const NOTIFICATION_PAGE_BREAK: String = "||"

signal notification_finished ## Emitted once the last queued page is dismissed - lets a caller sequence something (e.g. starting combat) after the player has actually read the text, instead of racing ahead while it's still on screen.

@onready var health_bar: ProgressBar = %HealthBar
@onready var resource_bar: ProgressBar = %ResourceBar
@onready var resource_label: Label = %ResourceLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var level_gold_label: Label = %LevelGoldLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var prompt_label: Label = %PromptLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel
@onready var notification_hint_label: Label = %NotificationHintLabel
@onready var notification_advance_area: Button = %NotificationAdvanceArea

var _player: PlayerCharacter
var _notification_queue: Array[String] = []
var _notification_active: bool = false

func setup(player: PlayerCharacter) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS # Needed while the tree's paused for a notification.
	notification_panel.visible = false
	prompt_label.visible = false
	notification_advance_area.pressed.connect(_advance_notification)
	refresh_stats()

func _process(_delta: float) -> void:
	if _player == null or _notification_active:
		return
	var interactable := _player.get_current_interactable()
	prompt_label.visible = interactable != null
	if interactable != null:
		prompt_label.text = "Press E to interact with %s" % interactable.display_name

func _unhandled_input(event: InputEvent) -> void:
	if _notification_active and event.is_action_pressed("ui_advance"):
		_advance_notification()
		get_viewport().set_input_as_handled()

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

	exp_bar.max_value = max(1, RunManager.exp_required_for_level(RunManager.run.level))
	exp_bar.value = RunManager.run.current_exp

func set_objective(text: String) -> void:
	objective_label.text = text

## Shows text and pauses until the player presses Space/Enter or clicks -
## never a fixed timer, so nothing scrolls past faster than it can be read.
## Pass NOTIFICATION_PAGE_BREAK-separated text (or call multiple times in a
## row - queued pages just chain) to split a long message into several
## shorter screens instead of one dense block.
func show_notification(text: String) -> void:
	if text == "":
		return
	_notification_queue.append_array(text.split(NOTIFICATION_PAGE_BREAK))
	if not _notification_active:
		_advance_notification()

func _advance_notification() -> void:
	if _notification_queue.is_empty():
		notification_panel.visible = false
		notification_hint_label.visible = false
		notification_advance_area.visible = false
		_notification_active = false
		get_tree().paused = false
		notification_finished.emit()
		return
	_notification_active = true
	get_tree().paused = true
	notification_label.text = _notification_queue.pop_front()
	notification_hint_label.visible = true
	notification_hint_label.text = "Click, press Space/Enter to continue..." if not _notification_queue.is_empty() else "Click, press Space/Enter to close..."
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0
	notification_advance_area.visible = true
