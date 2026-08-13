extends ExplorationArea
## The Fatted Cleaver: sells four cuts of meat, each a different flat heal
## amount, all combat_usable = false (see ItemDefinition) - real food, meant
## to be eaten sitting down between fights, not mid-battle rations.

func get_scene_path() -> String:
	return SceneManager.BUTCHER_SHOP

func get_objective_text() -> String:
	return "The Fatted Cleaver. Meat by the cut - none of it any use mid-fight."
