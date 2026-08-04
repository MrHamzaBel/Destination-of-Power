extends ExplorationArea
## The other path out of the Back Alley: a narrower, darker passage that
## keeps going down into Nerax's underground. Home to the Sticky-Fingered
## Thug, a fast RushingEnemy that ambushes the player on sight instead of
## waiting to be interacted with (see RushingEnemy.gd).
##
## The thug always appears on the player's first visit; after that, as long
## as he's still alive (RunData.story_flags["deep_alley_robber_defeated"]
## isn't set - see EnemyDefinition.on_defeat_story_flag_id), each return
## visit has a 20% chance of him showing up again. Once he's actually killed
## (as opposed to fleeing combat - see EnemyDefinition.flees_after_turns),
## he's gone from this alley for the rest of the run.

const ROBBER_RESPAWN_CHANCE: float = 0.20

@onready var robber: RushingEnemy = $Robber

func get_scene_path() -> String:
	return SceneManager.DEEPER_ALLEY

func get_objective_text() -> String:
	return "A narrower passage leads further down - stay alert."

func _on_area_ready() -> void:
	var robber_visual := robber.get_node_or_null("RobberVisual") as EnemyCharacter
	if robber_visual != null:
		robber_visual.setup(EnemyRegistry.get_enemy("alley_robber"))

	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("deep_alley_robber_defeated", false)):
		robber.queue_free()
		return

	var first_visit := not bool(RunManager.run.story_flags.get("deep_alley_robber_seen", false))
	RunManager.run.story_flags["deep_alley_robber_seen"] = true
	RunManager.save_current_run()

	if not first_visit and randf() >= ROBBER_RESPAWN_CHANCE:
		robber.queue_free()
