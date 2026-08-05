extends ExplorationArea
## Beyond Nerax's southern gate: forest to the east (bees nest near the old
## tree - see the Kill the Bees mission), a lake to the west, and an open
## path south that continues on, unlocked, to whatever comes next.
##
## The forest also hides a way to push deeper in - the first time, that
## triggers the one-time masked man cinematic (MaskedManEncounter.tscn);
## every visit after that goes straight to the bigger forest beyond
## (DeepForest.tscn), same "seen it once" gating as every other one-time
## story beat (RunData.story_flags).

@onready var deeper_forest_path: Interactable = $DeeperForestPathInteract

func get_scene_path() -> String:
	return SceneManager.NERAX_OUTSKIRTS

func get_objective_text() -> String:
	return "Forest to the east, lake to the west - or follow the path further south."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == deeper_forest_path:
		var seen := RunManager.run != null and bool(RunManager.run.story_flags.get("forest_portal_seen", false))
		SceneManager.goto_scene(SceneManager.DEEP_FOREST if seen else SceneManager.MASKED_MAN_ENCOUNTER)
		return
	super._on_interactable_triggered(interactable)
