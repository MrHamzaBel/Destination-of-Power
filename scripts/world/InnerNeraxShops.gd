extends ExplorationArea
## The inner market's shopping street: four small shop-front doors (each its
## own tiny interior scene, same GuildHallDoor-style facade+door pattern
## Plaza uses for the Adventure Centrum), a way back south to the fountain,
## and a way further north to Central Nerax - the walled district where the
## highborn and royals live. The first time the player pushes north, that
## triggers a one-time cinematic (CentralWallSmokeCutscene.tscn: guards still
## rushing the gate, smoke on the horizon); every visit after goes straight
## to CentralNeraxWard.tscn, same "seen it once" gating InnerNerax.gd already
## uses for the guards-rush cinematic one street back.

@onready var road_to_central_ward: Interactable = $ExitToCentralWard

func get_scene_path() -> String:
	return SceneManager.INNER_NERAX_SHOPS

func get_objective_text() -> String:
	return "Four shopfronts line the street. The fountain is back south; the central wall lies north."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == road_to_central_ward:
		var seen := RunManager.run != null and bool(RunManager.run.story_flags.get("central_wall_smoke_seen", false))
		SceneManager.goto_scene(SceneManager.CENTRAL_NERAX_WARD if seen else SceneManager.CENTRAL_WALL_SMOKE_CUTSCENE)
		return
	super._on_interactable_triggered(interactable)
