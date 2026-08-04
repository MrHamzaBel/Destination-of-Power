extends ExplorationArea
## Southside's market way: a long street lined with houses connecting the
## Plaza (north) to the southern gate out of Nerax (south).

func get_scene_path() -> String:
	return SceneManager.MARKET

func get_objective_text() -> String:
	return "Head south through the market to the gate, or back north to the plaza."
