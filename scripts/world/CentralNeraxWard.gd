extends ExplorationArea
## The checkpoint at Central Nerax's own wall - where the highborn and
## royals live, one district deeper than the inner market. More guards than
## anywhere else in the city, all of them rushing, and smoke visible over the
## wall behind them. A deliberately minimal dead-end for now (same "real,
## reachable place, not built out yet" convention InnerNerax/UndergroundNerax
## started from) - the Senior Guard's lockdown line is the in-fiction reason
## nothing continues north yet.

func get_scene_path() -> String:
	return SceneManager.CENTRAL_NERAX_WARD

func get_objective_text() -> String:
	return "The central wall. Guards rush everywhere - nothing further for now."
