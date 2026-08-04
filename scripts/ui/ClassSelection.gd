extends Control
## Data-driven class picker. Reads every ClassDefinition from ClassRegistry, so
## a new class only requires a new .tres file - this script needs no changes.

@onready var class_list: VBoxContainer = %ClassList
@onready var portrait_rect: ColorRect = %PortraitRect
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var stats_label: Label = %StatsLabel
@onready var equipment_label: Label = %EquipmentLabel
@onready var abilities_label: Label = %AbilitiesLabel
@onready var strengths_label: Label = %StrengthsLabel
@onready var weaknesses_label: Label = %WeaknessesLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton

var _classes: Array[ClassDefinition] = []
var _selected_id: String = ""

func _ready() -> void:
	_classes = ClassRegistry.get_all()
	for child in class_list.get_children():
		child.queue_free()
	for class_def in _classes:
		var button := Button.new()
		button.text = class_def.display_name
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.button_group = _shared_group()
		button.pressed.connect(_on_class_button_pressed.bind(class_def.id))
		class_list.add_child(button)

	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	if not _classes.is_empty():
		(class_list.get_child(0) as Button).button_pressed = true
		_select_class(_classes[0].id)

var _group: ButtonGroup = null
func _shared_group() -> ButtonGroup:
	if _group == null:
		_group = ButtonGroup.new()
	return _group

func _on_class_button_pressed(class_id: String) -> void:
	_select_class(class_id)

func _select_class(class_id: String) -> void:
	var class_def := ClassRegistry.get_class_definition(class_id)
	if class_def == null:
		return
	_selected_id = class_id

	portrait_rect.color = class_def.portrait_color
	name_label.text = class_def.display_name
	description_label.text = class_def.description

	var stats := class_def.base_stats
	var signature_line := "Signature Stat: %s (+5)\n" % class_def.impact_stat if class_def.impact_stat != "" else ""
	stats_label.text = "%sHealth: %d   %s: %d\nAttack: %d   Intelligence: %d\nDefense: %d   Speed: %d" % [
		signature_line, stats.max_health, class_def.resource_label, stats.max_resource,
		stats.attack, stats.intelligence, stats.defense, stats.speed
	]

	var equipment_names: Array[String] = []
	for slot in class_def.starting_equipped.keys():
		var item_def := ItemRegistry.get_item(class_def.starting_equipped[slot])
		if item_def != null:
			equipment_names.append(item_def.display_name)
	for item_id in class_def.starting_equipment:
		var item_def := ItemRegistry.get_item(item_id)
		if item_def != null:
			equipment_names.append(item_def.display_name)
	equipment_label.text = "Starting Equipment:\n- " + "\n- ".join(equipment_names)

	var ability_names: Array[String] = []
	for ability_id in class_def.abilities:
		var ability_def := AbilityRegistry.get_ability(ability_id)
		if ability_def != null:
			ability_names.append("%s - %s" % [ability_def.display_name, ability_def.description])
	abilities_label.text = "Abilities:\n- " + "\n- ".join(ability_names)

	strengths_label.text = "Strengths: " + ", ".join(class_def.strengths)
	weaknesses_label.text = "Weaknesses: " + ", ".join(class_def.weaknesses)

func _on_confirm_pressed() -> void:
	if _selected_id == "":
		return
	RunManager.start_new_run(_selected_id)
	SceneManager.goto_scene(SceneManager.LORE_INTRO)

func _on_back_pressed() -> void:
	SceneManager.goto_scene(SceneManager.MAIN_MENU)
