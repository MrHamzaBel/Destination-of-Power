extends ExplorationArea
## The inner market's shopping street: four small shop-front doors (each its
## own tiny interior scene, same GuildHallDoor-style facade+door pattern
## Plaza uses for the Adventure Centrum), and a way back to the fountain.

func get_scene_path() -> String:
	return SceneManager.INNER_NERAX_SHOPS

func get_objective_text() -> String:
	return "Four shopfronts line the street. The fountain plaza is back west."
