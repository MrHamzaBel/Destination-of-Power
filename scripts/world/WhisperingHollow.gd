extends ExplorationArea
## The Whispering Hollow: a sealed crystal cavern south of the outskirts,
## finally giving FarReaches somewhere to lead. Crystal Wisps roam freely
## (repeatable pack fight), an old inscription hints at why the Hollow
## Warden was left to guard it, and the Warden itself waits at the back -
## a one-time boss fight guaranteeing Heart of the Hollow and two Crystal
## Shards. Simply arriving resolves the guild's "Into the Hollow" scouting
## mission, the same "explore this place" pattern Find Wassim already uses.

func get_scene_path() -> String:
	return SceneManager.WHISPERING_HOLLOW

func get_objective_text() -> String:
	return "Crystal Wisps drift through the dark. Something far larger waits deeper in."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return

	if not bool(RunManager.run.story_flags.get("whispering_hollow_intro_shown", false)):
		RunManager.run.story_flags["whispering_hollow_intro_shown"] = true
		RunManager.save_current_run()
		hud.show_notification("The tunnel opens into a vast cavern, walls studded with softly glowing crystal. Faint, wordless whispers seem to drift from every direction at once.")

	if RunManager.is_quest_active("into_the_hollow"):
		var quest_def := QuestRegistry.get_quest("into_the_hollow")
		var levels_gained := RunManager.complete_quest("into_the_hollow")
		var reward_desc := quest_def.describe_reward() if quest_def != null else ""
		var message := "You send word back to the guild describing the cavern. Scouting complete! Reward: %s." % reward_desc
		for lvl in levels_gained:
			message += " Level up! You reached level %d." % lvl
		hud.show_notification(message)
