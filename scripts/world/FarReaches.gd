extends ExplorationArea
## The path south of the outskirts, past the forest and lake - a short
## connecting clearing between the outskirts and the sealed cavern entrance
## down into the Whispering Hollow.

func get_scene_path() -> String:
	return SceneManager.FAR_REACHES

func get_objective_text() -> String:
	return "A crack in the earth leads down, further south."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("far_reaches_intro_shown", false)):
		return
	RunManager.run.story_flags["far_reaches_intro_shown"] = true
	RunManager.save_current_run()
	hud.show_notification("The path trails off into open, untamed country - but a jagged crack in the ground nearby leads down into darkness.")
