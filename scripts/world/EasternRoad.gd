extends ExplorationArea
## The road past the East Checkpoint - a deliberately minimal stub, same
## "real, reachable place, not built out yet" convention as UndergroundNerax
## originally was. Only reachable once the checkpoint mercenaries are dealt
## with (see EastCheckpoint.gd).

func get_scene_path() -> String:
	return SceneManager.EASTERN_ROAD

func get_objective_text() -> String:
	return "The road continues east. Nothing more to do here yet."
