extends ExplorationArea
## Starting exploration area: a dead-end back alley with a single way out
## (east, into the Two-Way Alley). Scene-specific bits only - shared
## wiring/interactable handling lives in ExplorationArea.

func get_scene_path() -> String:
	return SceneManager.BACK_ALLEY

func get_objective_text() -> String:
	return "Explore the alley and find a way out to the streets."

## Only shown the first time the player spawns into the alley for a run -
## not on every return trip (e.g. after a combat encounter sends them back here).
func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("back_alley_intro_shown", false)):
		return
	RunManager.run.story_flags["back_alley_intro_shown"] = true
	RunManager.save_current_run()

	var lore: LoreScript = load("res://resources/lore/back_alley_intro.tres")
	if lore != null and lore.sections.size() > 0:
		hud.show_notification(lore.sections[0])
