extends Control
## Story beat triggered after winning the scripted Back Alley Thug fight: a
## City Guard arrives and a revenge wave of thugs shows up. Plays out like
## LoreIntro (click/Space/Enter to advance, Skip to jump ahead) and then
## starts the follow-up combat with the guard fighting as an ally.

const LORE_PATH: String = "res://resources/lore/city_guard_arrival.tres"
const REVENGE_ENEMY_IDS: Array[String] = ["back_alley_thug", "back_alley_thug"]
const REVENGE_ALLY_IDS: Array[String] = ["city_guard"]

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
		RunManager.run.story_flags["met_city_guard"] = true
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
	hint_label.text = "Click, press Space/Enter to continue..." if _index < _lore.sections.size() - 1 else "Click, press Space/Enter to fight..."

func _on_skip_pressed() -> void:
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	SceneManager.start_combat(REVENGE_ENEMY_IDS, SceneManager.CITY_GUARD_FAREWELL, false, REVENGE_ALLY_IDS, true)
