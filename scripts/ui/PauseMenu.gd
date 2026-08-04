class_name PauseMenu
extends Control
## Exploration pause overlay. Pauses the scene tree while open and unpauses
## before handing off to any other scene. Also doubles as the character
## information screen (stats/equipment readout).

signal inventory_requested

@onready var main_view: VBoxContainer = %MainView
@onready var info_view: VBoxContainer = %InfoView
@onready var resume_button: Button = %ResumeButton
@onready var inventory_button: Button = %InventoryButton
@onready var character_button: Button = %CharacterButton
@onready var settings_button: Button = %SettingsButton
@onready var abandon_button: Button = %AbandonButton
@onready var info_back_button: Button = %InfoBackButton
@onready var info_label: Label = %InfoLabel
@onready var abandon_confirm: ConfirmationDialog = %AbandonConfirmDialog
@onready var stat_points_label: Label = %StatPointsLabel
@onready var stat_points_row: HBoxContainer = %StatPointsRow
@onready var hp_point_button: Button = %HpPointButton
@onready var attack_point_button: Button = %AttackPointButton
@onready var defense_point_button: Button = %DefensePointButton
@onready var speed_point_button: Button = %SpeedPointButton
@onready var intelligence_point_button: Button = %IntelligencePointButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	inventory_button.pressed.connect(func(): inventory_requested.emit())
	character_button.pressed.connect(_show_info_view)
	info_back_button.pressed.connect(_show_main_view)
	settings_button.pressed.connect(_on_settings_pressed)
	abandon_button.pressed.connect(func(): abandon_confirm.popup_centered())
	abandon_confirm.confirmed.connect(_on_abandon_confirmed)
	hp_point_button.pressed.connect(_on_stat_point_pressed.bind("hp"))
	attack_point_button.pressed.connect(_on_stat_point_pressed.bind("attack"))
	defense_point_button.pressed.connect(_on_stat_point_pressed.bind("defense"))
	speed_point_button.pressed.connect(_on_stat_point_pressed.bind("speed"))
	intelligence_point_button.pressed.connect(_on_stat_point_pressed.bind("intelligence"))

func open() -> void:
	_show_main_view()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _show_main_view() -> void:
	main_view.visible = true
	info_view.visible = false

func _show_info_view() -> void:
	main_view.visible = false
	info_view.visible = true
	_populate_info()

func _populate_info() -> void:
	if RunManager.run == null:
		info_label.text = "No active run."
		stat_points_row.visible = false
		stat_points_label.visible = false
		return
	var class_def := RunManager.get_class_def()
	var stats := RunManager.compute_current_stats()
	var run := RunManager.run
	var lines: Array[String] = []
	lines.append("Name: %s" % RunManager.character_profile.character_name)
	lines.append("Class: %s" % (class_def.display_name if class_def else "?"))
	lines.append("Level: %d   Exp: %d / %d" % [run.level, run.current_exp, RunManager.exp_required_for_level(run.level)])
	lines.append("Gold: %d" % run.currency)
	lines.append("")
	lines.append("Health: %d / %d" % [run.current_health, stats.max_health])
	lines.append("%s: %d / %d" % [class_def.resource_label if class_def else "Resource", run.current_resource, stats.max_resource])
	lines.append("Attack: %d   Intelligence: %d" % [stats.attack, stats.intelligence])
	lines.append("Defense: %d   Speed: %d" % [stats.defense, stats.speed])
	lines.append("")
	lines.append("Equipped:")
	for slot in run.equipped.keys():
		var item_def := ItemRegistry.get_item(run.equipped[slot])
		lines.append("  %s: %s" % [slot.capitalize(), item_def.display_name if item_def else "?"])
	lines.append("")
	lines.append("Artifacts:")
	if run.artifacts.is_empty():
		lines.append("  None yet")
	for artifact_id in run.artifacts.keys():
		var artifact_def := ArtifactRegistry.get_artifact(artifact_id)
		if artifact_def != null:
			lines.append("  %s x%d" % [artifact_def.display_name, run.artifacts[artifact_id]])
	lines.append("")
	lines.append("Quests:")
	if run.active_quests.is_empty() and run.completed_quests.is_empty():
		lines.append("  None yet")
	for quest_id in run.active_quests:
		var quest_def := QuestRegistry.get_quest(quest_id)
		if quest_def != null:
			lines.append("  [In Progress] %s - %s" % [quest_def.display_name, quest_def.objective_text])
	for quest_id in run.completed_quests:
		var quest_def := QuestRegistry.get_quest(quest_id)
		if quest_def != null:
			lines.append("  [Complete] %s" % quest_def.display_name)
	info_label.text = "\n".join(lines)

	var unspent := run.unspent_stat_points
	stat_points_label.visible = true
	stat_points_row.visible = unspent > 0
	stat_points_label.text = (
		"You have %d unspent stat point%s - choose where to put them:" % [unspent, "" if unspent == 1 else "s"]
		if unspent > 0 else "No unspent stat points."
	)

func _on_stat_point_pressed(stat_name: String) -> void:
	if RunManager.allocate_stat_point(stat_name):
		_populate_info()

func _on_settings_pressed() -> void:
	get_tree().paused = false
	SceneManager.goto_scene("res://scenes/ui/SettingsMenu.tscn")

func _on_abandon_confirmed() -> void:
	get_tree().paused = false
	RunManager.abandon_run()
	SceneManager.goto_scene(SceneManager.MAIN_MENU)
