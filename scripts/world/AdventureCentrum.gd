extends ExplorationArea
## The Adventure Centrum: Nerax's guild hall, where quests and missions get
## posted. Simply arriving here resolves the "Find Wassim" quest if it's
## currently active.

func get_scene_path() -> String:
	return SceneManager.ADVENTURE_CENTRUM

func get_objective_text() -> String:
	return "Look around the Adventure Centrum."

func _on_area_ready() -> void:
	if RunManager.run == null or not RunManager.is_quest_active("find_wassim"):
		return
	var quest_def := QuestRegistry.get_quest("find_wassim")
	var levels_gained := RunManager.complete_quest("find_wassim")
	var reward_desc := quest_def.describe_reward() if quest_def != null else ""
	var message := "Among the request boards, a young man matching Wassim's description is arguing with a clerk about a delayed bounty payment. He's fine - just stubborn about getting paid. Quest complete! Reward: %s." % reward_desc
	for lvl in levels_gained:
		message += " Level up! You reached level %d." % lvl
	hud.show_notification(message)
