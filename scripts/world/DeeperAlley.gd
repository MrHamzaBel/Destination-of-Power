extends ExplorationArea
## The other path out of the Back Alley: a narrower, darker passage that
## keeps going down into Nerax's underground. Home to the Sticky-Fingered
## Thug - a guaranteed ambush on arrival rather than a roaming RushingEnemy.
## He used to be a live chase-on-sight enemy, but detection/chase relied on
## the player walking into range on their own, and a paused-tree-freeze
## regression (his own aggro notification could pause his chase mid-pursuit,
## since notifications now pause until dismissed - see ExplorationHUD) made
## him feel like he was "waiting" for the player to move. A guaranteed
## on-arrival trigger has no detection radius or chase logic to go wrong.
##
## He always ambushes on the player's first visit; after that, as long as
## he's still alive (RunData.story_flags["deep_alley_robber_defeated"] isn't
## set - see EnemyDefinition.on_defeat_story_flag_id), each return visit has
## a 20% chance of the ambush happening again. Once he's actually killed (as
## opposed to fleeing combat - see EnemyDefinition.flees_after_turns), he's
## gone from this alley for the rest of the run.

const ROBBER_RESPAWN_CHANCE: float = 0.20

func get_scene_path() -> String:
	return SceneManager.DEEPER_ALLEY

func get_objective_text() -> String:
	return "A narrower passage leads further down - stay alert."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("deep_alley_robber_defeated", false)):
		return

	var first_visit := not bool(RunManager.run.story_flags.get("deep_alley_robber_seen", false))
	RunManager.run.story_flags["deep_alley_robber_seen"] = true
	RunManager.save_current_run()

	if not first_visit and randf() >= ROBBER_RESPAWN_CHANCE:
		return

	hud.show_notification("A shape detaches from the shadows between the crates, blocking your path deeper into the alley.||\"Sorry about this - nothing personal, just business!\" the thug grins, already reaching for your coin purse.")
	hud.notification_finished.connect(_start_robber_ambush, CONNECT_ONE_SHOT)

func _start_robber_ambush() -> void:
	start_combat(["alley_robber"], get_scene_path())
