extends Control
## One-time story beat the first time the player pushes north from the inner
## fountain: a column of soldiers rushing to the Royal Castle, an officer
## driving them on. Plays out like CityGuardFarewell/MaskedManEncounter
## (click/Space/Enter to advance, Skip to jump ahead), then hands off to the
## inner market's shopping street - InnerNerax.gd checks story_flags
## ["guards_rush_seen"] (set here, mirroring MaskedManEncounter's own
## flag-in-_ready() convention) to route straight there on every visit after.

const LORE_PATH: String = "res://resources/lore/guards_rush_north.tres"

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
		RunManager.run.story_flags["guards_rush_seen"] = true
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
	SceneManager.goto_scene(SceneManager.INNER_NERAX_SHOPS, true)
