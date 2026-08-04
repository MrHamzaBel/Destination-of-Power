extends ExplorationArea
## Beyond Nerax's southern gate: forest to the east (bees nest near the old
## tree - see the Kill the Bees mission), a lake to the west, and an open
## path south that continues on, unlocked, to whatever comes next.

func get_scene_path() -> String:
	return SceneManager.NERAX_OUTSKIRTS

func get_objective_text() -> String:
	return "Forest to the east, lake to the west - or follow the path further south."
