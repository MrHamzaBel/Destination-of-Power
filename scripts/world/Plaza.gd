extends ExplorationArea
## The central plaza of Nerax, capital of Hamia. Connects the alleys (west)
## to the wider city streets (east), where the run's randomized encounters
## begin in earnest.

func get_scene_path() -> String:
	return SceneManager.PLAZA

func get_objective_text() -> String:
	return "Explore the plaza, or head into the city streets to continue your journey."
