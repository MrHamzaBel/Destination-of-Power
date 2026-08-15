extends Control
## One-time story beat the first time the player pushes north from the
## shopping street: the wall guarding Central Nerax, guards still rushing
## through its gate, and smoke on the horizon. Same minimal cutscene template
## as GuardsRushCutscene.gd - InnerNeraxShops.gd checks story_flags
## ["central_wall_smoke_seen"] (set here) to route straight to
## CentralNeraxWard.tscn on every visit after.

const LORE_PATH: String = "res://resources/lore/central_wall_smoke.tres"

@onready var text_label: Label = %TextLabel
@onready var hint_label: Label = %HintLabel
@onready var skip_button: Button = %SkipButton
@onready var advance_area: Button = %AdvanceArea
@onready var background: CutsceneBackground = %Background

var _lore: LoreScript
var _index: int = -1
var _finished: bool = false

func _ready() -> void:
	if RunManager.run != null:
		RunManager.run.story_flags["central_wall_smoke_seen"] = true
		RunManager.save_current_run()
	_lore = load(LORE_PATH)
	background.set_texture(_lore.background_texture if _lore != null else null)
	skip_button.pressed.connect(_on_skip_pressed)
	advance_area.pressed.connect(_advance)
	_advance()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_advance") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	if _finished:
		return
	_index += 1
	if _lore == null or _index >= _lore.sections.size():
		_finish()
		return
	text_label.text = _lore.sections[_index]
	text_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(text_label, "modulate:a", 1.0, 0.4)
	hint_label.text = "Click, press Space/Enter to continue..."

func _on_skip_pressed() -> void:
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	SceneManager.goto_scene(SceneManager.CENTRAL_NERAX_WARD, true)
