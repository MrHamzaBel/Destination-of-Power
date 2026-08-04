extends Control
## Basic audio/display settings. Persists through SaveManager/AudioManager.

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var back_button: Button = %BackButton

func _ready() -> void:
	var settings := AudioManager.settings
	master_slider.value = settings.master_volume
	music_slider.value = settings.music_volume
	sfx_slider.value = settings.sfx_volume
	fullscreen_check.button_pressed = settings.fullscreen

	master_slider.value_changed.connect(_on_setting_changed)
	music_slider.value_changed.connect(_on_setting_changed)
	sfx_slider.value_changed.connect(_on_setting_changed)
	fullscreen_check.toggled.connect(_on_setting_changed)
	back_button.pressed.connect(_on_back_pressed)

func _on_setting_changed(_value = null) -> void:
	var settings := SettingsData.new()
	settings.master_volume = master_slider.value
	settings.music_volume = music_slider.value
	settings.sfx_volume = sfx_slider.value
	settings.fullscreen = fullscreen_check.button_pressed
	AudioManager.apply_settings(settings)
	SaveManager.save_settings(settings)

func _on_back_pressed() -> void:
	SceneManager.goto_scene(SceneManager.MAIN_MENU)
