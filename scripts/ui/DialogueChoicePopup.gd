class_name DialogueChoicePopup
extends Control
## Reusable Yes / No / "mind your own business" prompt for NPC dialogue.
## Any exploration area can show it via show_prompt() and listen for
## choice_made (0 = yes, 1 = no, 2 = decline).

signal choice_made(choice_index: int)

@onready var prompt_label: Label = %PromptLabel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton
@onready var decline_button: Button = %DeclineButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	yes_button.pressed.connect(func(): _choose(0))
	no_button.pressed.connect(func(): _choose(1))
	decline_button.pressed.connect(func(): _choose(2))

func show_prompt(text: String) -> void:
	prompt_label.text = text
	visible = true
	get_tree().paused = true

func _choose(choice_index: int) -> void:
	visible = false
	get_tree().paused = false
	choice_made.emit(choice_index)
