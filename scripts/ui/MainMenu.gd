extends Control
## Top-level menu. Continue Run / New Game are disabled with an explanatory
## tooltip when their prerequisites (saved character / active run) are missing.

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var character_creation_button: Button = %CharacterCreationButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var abandon_confirm: ConfirmationDialog = %AbandonConfirmDialog
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	character_creation_button.pressed.connect(_on_character_creation_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	abandon_confirm.confirmed.connect(_on_abandon_confirmed)
	_refresh_state()

func _refresh_state() -> void:
	var has_character := RunManager.has_character()
	var has_run := RunManager.has_active_run()

	continue_button.disabled = not has_run
	continue_button.tooltip_text = (
		"Resume your current run." if has_run
		else "No active run yet. Start a New Game to begin one."
	)

	new_game_button.disabled = not has_character
	new_game_button.tooltip_text = (
		"Choose a class and start a new run." if has_character
		else "Create and save a character first."
	)

	if not has_character:
		status_label.text = "Create a character to unlock New Game."
	elif has_run:
		status_label.text = "A run is in progress - Continue Run to pick up where you left off."
	else:
		status_label.text = "Ready for a new run."

func _on_continue_pressed() -> void:
	if not RunManager.has_active_run():
		return
	var target := RunManager.run.current_scene_path
	if target == "":
		target = SceneManager.BACK_ALLEY
	SceneManager.goto_scene(target)

func _on_new_game_pressed() -> void:
	if not RunManager.has_character():
		return
	if RunManager.has_active_run():
		abandon_confirm.popup_centered()
	else:
		SceneManager.goto_scene(SceneManager.CLASS_SELECTION)

func _on_abandon_confirmed() -> void:
	RunManager.abandon_run()
	SceneManager.goto_scene(SceneManager.CLASS_SELECTION)

func _on_character_creation_pressed() -> void:
	SceneManager.goto_scene(SceneManager.CHARACTER_CREATOR)

func _on_settings_pressed() -> void:
	SceneManager.goto_scene("res://scenes/ui/SettingsMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
