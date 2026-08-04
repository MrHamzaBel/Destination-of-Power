extends ExplorationArea
## The path south of the outskirts, past the forest and lake. Intentionally
## minimal for now (a single connected clearing with a way back) - not
## locked, not a dead end, just not built out yet.

func get_scene_path() -> String:
	return SceneManager.FAR_REACHES

func get_objective_text() -> String:
	return "The road continues, but there's nothing out here yet."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("far_reaches_intro_shown", false)):
		return
	RunManager.run.story_flags["far_reaches_intro_shown"] = true
	RunManager.save_current_run()
	hud.show_notification("The path trails off into open, untamed country. Whatever lies further south hasn't been mapped yet.")
