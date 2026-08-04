extends Node
## Thin wrapper around the audio bus layout. No sound assets ship with the MVP;
## this exists so UI and gameplay code have a stable place to call into once
## real sound effects/music are added.

var settings: SettingsData = SettingsData.new()

func _ready() -> void:
	settings = SaveManager.load_settings()
	apply_settings(settings)

func apply_settings(new_settings: SettingsData) -> void:
	settings = new_settings
	_set_bus_volume("Master", settings.master_volume)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)

func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_volume, 0.0, 1.0)))

func play_sfx(_id: String) -> void:
	pass # Placeholder hook for future sound effects.

func play_music(_id: String) -> void:
	pass # Placeholder hook for future music tracks.
