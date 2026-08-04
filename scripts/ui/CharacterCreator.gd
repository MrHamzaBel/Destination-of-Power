extends Control
## Character creation screen: layered live preview built from AppearanceRegistry
## data, category tabs with prev/next style pickers and color swatches,
## randomize/reset, and name validation before saving.

@onready var preview_root: Node2D = %PreviewRoot
@onready var name_edit: LineEdit = %NameEdit
@onready var name_error_label: Label = %NameErrorLabel

@onready var body_label: Label = %BodyLabel
@onready var hair_label: Label = %HairLabel
@onready var shirt_label: Label = %ShirtLabel
@onready var pants_label: Label = %PantsLabel
@onready var footwear_label: Label = %FootwearLabel

@onready var skin_color_row: HBoxContainer = %SkinColorRow
@onready var hair_color_row: HBoxContainer = %HairColorRow

@onready var randomize_button: Button = %RandomizeButton
@onready var reset_button: Button = %ResetButton
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

var _renderer: CharacterAppearanceRenderer

var _body_index: int = 0
var _hair_index: int = 0
var _shirt_index: int = 0
var _pants_index: int = 0
var _footwear_index: int = 0
var _skin_color_index: int = 0
var _hair_color_index: int = 0
var _character_name: String = ""

var _saved_profile: CharacterProfile = null ## Snapshot used by Reset.

func _ready() -> void:
	_renderer = CharacterAppearanceRenderer.new()
	preview_root.add_child(_renderer)

	_saved_profile = RunManager.character_profile
	_load_from_profile(_saved_profile)

	_build_color_row(skin_color_row, AppearanceRegistry.skin_colors, _skin_color_index, func(i): _skin_color_index = i; _refresh())
	_build_color_row(hair_color_row, AppearanceRegistry.hair_colors, _hair_color_index, func(i): _hair_color_index = i; _refresh())

	name_edit.text_changed.connect(_on_name_changed)
	randomize_button.pressed.connect(_on_randomize_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_connect_prev_next("%BodyPrev", "%BodyNext", func(): _step_body(-1), func(): _step_body(1))
	_connect_prev_next("%HairPrev", "%HairNext", func(): _step_hair(-1), func(): _step_hair(1))
	_connect_prev_next("%ShirtPrev", "%ShirtNext", func(): _step_shirt(-1), func(): _step_shirt(1))
	_connect_prev_next("%PantsPrev", "%PantsNext", func(): _step_pants(-1), func(): _step_pants(1))
	_connect_prev_next("%FootwearPrev", "%FootwearNext", func(): _step_footwear(-1), func(): _step_footwear(1))

	_refresh()

func _connect_prev_next(prev_path: String, next_path: String, on_prev: Callable, on_next: Callable) -> void:
	(get_node(prev_path) as Button).pressed.connect(on_prev)
	(get_node(next_path) as Button).pressed.connect(on_next)

func _load_from_profile(profile: CharacterProfile) -> void:
	if profile == null:
		_character_name = ""
		_body_index = 0
		_hair_index = 0
		_shirt_index = 0
		_pants_index = 0
		_footwear_index = 0
		_skin_color_index = 0
		_hair_color_index = 0
		return
	_character_name = profile.character_name
	_body_index = _index_of_id(AppearanceRegistry.body_types, profile.body_type)
	_hair_index = _index_of_id(AppearanceRegistry.hairstyles, profile.hairstyle)
	_shirt_index = _index_of_id(AppearanceRegistry.shirts, profile.shirt)
	_pants_index = _index_of_id(AppearanceRegistry.pants, profile.pants)
	_footwear_index = _index_of_id(AppearanceRegistry.footwear, profile.footwear)
	_skin_color_index = _index_of_color(AppearanceRegistry.skin_colors, profile.skin_color)
	_hair_color_index = _index_of_color(AppearanceRegistry.hair_colors, profile.hair_color)
	name_edit.text = _character_name

func _index_of_id(list: Array[AppearanceOption], id: String) -> int:
	for i in range(list.size()):
		if list[i].id == id:
			return i
	return 0

func _index_of_color(list: Array[ColorSwatch], color: Color) -> int:
	for i in range(list.size()):
		if list[i].color.is_equal_approx(color):
			return i
	return 0

func _build_color_row(row: HBoxContainer, swatches: Array[ColorSwatch], _current: int, on_pick: Callable) -> void:
	for child in row.get_children():
		child.queue_free()
	for i in range(swatches.size()):
		var swatch: ColorSwatch = swatches[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(28, 28)
		button.tooltip_text = swatch.display_name
		button.focus_mode = Control.FOCUS_ALL
		var style := StyleBoxFlat.new()
		style.bg_color = swatch.color
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.9, 0.9, 0.9, 0.6)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)
		var index := i
		button.pressed.connect(func(): on_pick.call(index))
		row.add_child(button)

func _step_body(delta: int) -> void:
	_body_index = _wrap(_body_index + delta, AppearanceRegistry.body_types.size())
	_refresh()

func _step_hair(delta: int) -> void:
	_hair_index = _wrap(_hair_index + delta, AppearanceRegistry.hairstyles.size())
	_refresh()

func _step_shirt(delta: int) -> void:
	_shirt_index = _wrap(_shirt_index + delta, AppearanceRegistry.shirts.size())
	_refresh()

func _step_pants(delta: int) -> void:
	_pants_index = _wrap(_pants_index + delta, AppearanceRegistry.pants.size())
	_refresh()

func _step_footwear(delta: int) -> void:
	_footwear_index = _wrap(_footwear_index + delta, AppearanceRegistry.footwear.size())
	_refresh()

func _wrap(value: int, size: int) -> int:
	if size <= 0:
		return 0
	return ((value % size) + size) % size

func _build_current_profile() -> CharacterProfile:
	var profile := CharacterProfile.new()
	profile.character_name = _character_name
	profile.body_type = _get_id(AppearanceRegistry.body_types, _body_index)
	profile.hairstyle = _get_id(AppearanceRegistry.hairstyles, _hair_index)
	profile.shirt = _get_id(AppearanceRegistry.shirts, _shirt_index)
	profile.pants = _get_id(AppearanceRegistry.pants, _pants_index)
	profile.footwear = _get_id(AppearanceRegistry.footwear, _footwear_index)
	profile.skin_color = _get_color(AppearanceRegistry.skin_colors, _skin_color_index)
	profile.hair_color = _get_color(AppearanceRegistry.hair_colors, _hair_color_index)
	return profile

func _get_id(list: Array[AppearanceOption], index: int) -> String:
	if list.is_empty():
		return ""
	return list[_wrap(index, list.size())].id

func _get_color(list: Array[ColorSwatch], index: int) -> Color:
	if list.is_empty():
		return Color.WHITE
	return list[_wrap(index, list.size())].color

func _refresh() -> void:
	body_label.text = _display_name(AppearanceRegistry.body_types, _body_index)
	hair_label.text = _display_name(AppearanceRegistry.hairstyles, _hair_index)
	shirt_label.text = _display_name(AppearanceRegistry.shirts, _shirt_index)
	pants_label.text = _display_name(AppearanceRegistry.pants, _pants_index)
	footwear_label.text = _display_name(AppearanceRegistry.footwear, _footwear_index)
	_renderer.apply_profile(_build_current_profile())

func _display_name(list: Array[AppearanceOption], index: int) -> String:
	if list.is_empty():
		return "(none)"
	return list[_wrap(index, list.size())].display_name

func _on_name_changed(new_text: String) -> void:
	_character_name = new_text
	if new_text.strip_edges() != "":
		name_error_label.visible = false

func _on_randomize_pressed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_body_index = rng.randi_range(0, max(0, AppearanceRegistry.body_types.size() - 1))
	_hair_index = rng.randi_range(0, max(0, AppearanceRegistry.hairstyles.size() - 1))
	_shirt_index = rng.randi_range(0, max(0, AppearanceRegistry.shirts.size() - 1))
	_pants_index = rng.randi_range(0, max(0, AppearanceRegistry.pants.size() - 1))
	_footwear_index = rng.randi_range(0, max(0, AppearanceRegistry.footwear.size() - 1))
	_skin_color_index = rng.randi_range(0, max(0, AppearanceRegistry.skin_colors.size() - 1))
	_hair_color_index = rng.randi_range(0, max(0, AppearanceRegistry.hair_colors.size() - 1))
	_refresh()

func _on_reset_pressed() -> void:
	_load_from_profile(_saved_profile)
	_refresh()

func _on_save_pressed() -> void:
	if _character_name.strip_edges() == "":
		name_error_label.visible = true
		name_edit.grab_focus()
		return
	var profile := _build_current_profile()
	RunManager.save_character(profile)
	_saved_profile = profile
	SceneManager.goto_scene(SceneManager.MAIN_MENU)

func _on_back_pressed() -> void:
	SceneManager.goto_scene(SceneManager.MAIN_MENU)
