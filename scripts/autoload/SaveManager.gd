extends Node
## Handles all disk persistence: character profile, active run, and settings.
## Each save lives in its own JSON file under user://saves/ so they can be
## created, overwritten or removed independently.

const SAVE_DIR: String = "user://saves"
const PROFILE_PATH: String = SAVE_DIR + "/character_profile.json"
const RUN_PATH: String = SAVE_DIR + "/active_run.json"
const SETTINGS_PATH: String = SAVE_DIR + "/settings.json"

func _ready() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("SaveManager: failed to create save directory (%s)" % dir_err)

# --- Generic helpers ---------------------------------------------------------

func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open '%s' for writing (%s)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open '%s' for reading (%s)" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: '%s' did not contain a valid JSON object, ignoring." % path)
		return {}
	return parsed

# --- Character profile --------------------------------------------------------

func has_character_profile() -> bool:
	return FileAccess.file_exists(PROFILE_PATH)

func save_character_profile(profile: CharacterProfile) -> bool:
	var ok := _write_json(PROFILE_PATH, profile.to_dict())
	if ok:
		print("SaveManager: character profile saved -> ", PROFILE_PATH)
	return ok

func load_character_profile() -> CharacterProfile:
	var data := _read_json(PROFILE_PATH)
	if data.is_empty():
		return null
	return CharacterProfile.from_dict(data)

# --- Active run ---------------------------------------------------------------

func has_active_run() -> bool:
	if not FileAccess.file_exists(RUN_PATH):
		return false
	var data := _read_json(RUN_PATH)
	return data.get("is_active", false)

func save_run(run: RunData) -> bool:
	return _write_json(RUN_PATH, run.to_dict())

func load_run() -> RunData:
	var data := _read_json(RUN_PATH)
	if data.is_empty():
		return null
	return RunData.from_dict(data)

func delete_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		var err := DirAccess.remove_absolute(RUN_PATH)
		if err != OK:
			push_warning("SaveManager: failed to remove run save (%s)" % err)
		else:
			print("SaveManager: active run archived/removed.")

# --- Settings -------------------------------------------------------------------

func save_settings(settings: SettingsData) -> bool:
	return _write_json(SETTINGS_PATH, settings.to_dict())

func load_settings() -> SettingsData:
	var data := _read_json(SETTINGS_PATH)
	if data.is_empty():
		return SettingsData.new()
	return SettingsData.from_dict(data)
