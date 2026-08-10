extends ExplorationArea
## A hidden clearing tucked past a trail in the Deep Forest: Bug Catcher
## Joe's camp. His swarm (3 weak forest_bug minions) fights alongside him -
## once all three are dead he flies into a rage and seals the player's
## healing for the rest of the fight (EnemyDefinition.seals_healing_when_alone,
## resolved entirely in CombatManager, no scene-specific logic needed here).

func get_scene_path() -> String:
	return SceneManager.BUG_CATCHERS_GROVE

func get_objective_text() -> String:
	return "Someone's been living out here - and they don't look happy to see you."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if not bool(RunManager.run.story_flags.get("bug_catchers_grove_intro_shown", false)):
		RunManager.run.story_flags["bug_catchers_grove_intro_shown"] = true
		RunManager.save_current_run()
		hud.show_notification("The trail opens into a cramped clearing, thick with the smell of crushed leaves. Jars, nets, and cages are scattered everywhere - and someone just noticed you.")
