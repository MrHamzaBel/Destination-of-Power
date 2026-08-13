extends ExplorationArea
## The base of Nerax's inner wall, south side - a guarded checkpoint reached
## via the ward stairs above the Market. The gate itself (GateExit) is
## rank-gated at B-Rank and up, with a 100-gold toll as the alternative for
## anyone who hasn't earned the rank yet (see Interactable.toll_gold_amount /
## ExplorationArea._offer_toll()).

func get_scene_path() -> String:
	return SceneManager.INNER_WALL_SOUTH

func get_objective_text() -> String:
	return "Guards hold the gate north - B-Rank and up, or pay your way through."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if not bool(RunManager.run.story_flags.get("inner_wall_south_intro_shown", false)):
		RunManager.run.story_flags["inner_wall_south_intro_shown"] = true
		RunManager.save_current_run()
		hud.show_notification("The street ends at Nerax's inner wall - a real fortification, not the low brick of the outer city. Two guards watch the gate ahead, spears crossed.")
