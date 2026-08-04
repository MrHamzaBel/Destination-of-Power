class_name SettingsData
extends Resource
## Persistent user settings: audio volumes and display mode.

const SAVE_VERSION: int = 1

@export var save_version: int = SAVE_VERSION
@export var master_volume: float = 0.8
@export var music_volume: float = 0.6
@export var sfx_volume: float = 0.8
@export var fullscreen: bool = false

func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
	}

static func from_dict(data: Dictionary) -> SettingsData:
	var settings := SettingsData.new()
	settings.save_version = data.get("save_version", SAVE_VERSION)
	settings.master_volume = data.get("master_volume", 0.8)
	settings.music_volume = data.get("music_volume", 0.6)
	settings.sfx_volume = data.get("sfx_volume", 0.8)
	settings.fullscreen = data.get("fullscreen", false)
	return settings
