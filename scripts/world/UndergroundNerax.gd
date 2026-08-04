extends ExplorationArea
## The entrance chamber to Nerax's underground, reached via the Deeper Alley.
## Intentionally minimal for now (a single connected room with a way back) -
## a placeholder for future underground content, not a dead end.

func get_scene_path() -> String:
	return SceneManager.UNDERGROUND_NERAX

func get_objective_text() -> String:
	return "You've reached the underground. There's nothing more down here - yet."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("underground_nerax_intro_shown", false)):
		return
	RunManager.run.story_flags["underground_nerax_intro_shown"] = true
	RunManager.save_current_run()
	hud.show_notification("The passage opens into a damp, torchlit chamber beneath Nerax. Whatever built this is long gone - or is it?")
