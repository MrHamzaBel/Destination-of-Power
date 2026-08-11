extends Control
## One-time story beat when the player first pushes deeper into the forest:
## a masked man steps through a portal, taunts the player, and leaves after
## one of three player responses. Plays out like LoreIntro/CityGuardArrival
## (click/Space/Enter to advance, Skip to jump ahead) with a three-choice
## prompt inserted between the intro and the epilogue.
##
## "What?" and "Who are you?" both lead to the same calm dismissal; "Shut
## up" costs the player half their current health but is otherwise the same
## outcome (he leaves either way) - the choice only changes the flavor and
## whether it hurts, not where the story goes next.

const INTRO_LORE_PATH: String = "res://resources/lore/masked_man_intro.tres"
const LEAVES_LORE_PATH: String = "res://resources/lore/masked_man_leaves.tres"
const SHUTUP_LORE_PATH: String = "res://resources/lore/masked_man_shutup.tres"

@onready var text_label: Label = %TextLabel
@onready var hint_label: Label = %HintLabel
@onready var skip_button: Button = %SkipButton
@onready var advance_area: Button = %AdvanceArea
@onready var choice_popup: DialogueChoicePopup = %ChoicePopup
@onready var background: CutsceneBackground = %Background

var _lore: LoreScript
var _index: int = -1
var _finished: bool = false
var _awaiting_choice: bool = false
var _epilogue_started: bool = false

func _ready() -> void:
	if RunManager.run != null:
		RunManager.run.story_flags["forest_portal_seen"] = true
		RunManager.save_current_run()
	_lore = load(INTRO_LORE_PATH)
	background.set_texture(_lore.background_texture if _lore != null else null)
	skip_button.pressed.connect(_on_skip_pressed)
	advance_area.pressed.connect(_advance)
	_advance()

func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_choice:
		return
	if event.is_action_pressed("ui_advance") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	if _finished or _awaiting_choice:
		return
	_index += 1
	if _lore == null or _index >= _lore.sections.size():
		if _epilogue_started:
			_finish()
		else:
			_show_choice()
		return
	text_label.text = _lore.sections[_index]
	text_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(text_label, "modulate:a", 1.0, 0.4)
	hint_label.text = "Click, press Space/Enter to continue..."

func _on_skip_pressed() -> void:
	if _awaiting_choice:
		return
	if _epilogue_started:
		_finish()
	else:
		_show_choice()

func _show_choice() -> void:
	_awaiting_choice = true
	hint_label.text = ""
	choice_popup.show_prompt("How do you respond?", "What?", "Who are you?", "Shut up.")
	choice_popup.choice_made.connect(_on_choice_made, CONNECT_ONE_SHOT)

func _on_choice_made(choice_index: int) -> void:
	_awaiting_choice = false
	_epilogue_started = true
	_index = -1
	if choice_index == 2:
		if RunManager.run != null:
			var damage := RunManager.run.current_health / 2
			RunManager.run.current_health -= damage
			RunManager.save_current_run()
		_lore = load(SHUTUP_LORE_PATH)
	else:
		_lore = load(LEAVES_LORE_PATH)
	background.set_texture(_lore.background_texture if _lore != null else null)
	_advance()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	SceneManager.goto_scene(SceneManager.DEEP_FOREST, true)
