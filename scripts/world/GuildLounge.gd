extends ExplorationArea
## The guild's back lounge, unlocked at C-Rank and above. Its shop discounts
## with the same percentage the player's rank gives on guild tax.

func get_scene_path() -> String:
	return SceneManager.GUILD_LOUNGE

func get_objective_text() -> String:
	return "Browse the lounge shop."
