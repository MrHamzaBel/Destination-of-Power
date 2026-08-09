extends ExplorationArea
## A military district reached via a new west exit from the Market -
## freely explorable (no rank gate on the area itself), home to a knight and
## a mercenary discussing the sudden redeployment north, and a Masked
## Assassin lurking as a genuine ambush threat (RushingEnemy, not a
## walk-up-and-interact fight). Defeating him resolves "A Blade in the
## Dark" if it's active - offered back in the Market, D-Rank and up.

func get_scene_path() -> String:
	return SceneManager.GARRISON_WARD

func get_objective_text() -> String:
	return "Knights and mercenaries linger here - but something faster is watching too."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return

	if not bool(RunManager.run.story_flags.get("garrison_ward_intro_shown", false)):
		RunManager.run.story_flags["garrison_ward_intro_shown"] = true
		RunManager.save_current_run()
		hud.show_notification("Banners snap overhead as you step into the Garrison Ward. Soldiers move with clipped, urgent purpose - something has them on edge.")

	var assassin := get_node_or_null("AssassinRusher")
	if assassin != null and bool(RunManager.run.story_flags.get("city_assassin_defeated", false)):
		assassin.queue_free()

	_check_blade_quest_completion()

## Same "return here implies it happened" pattern as _check_boss_trigger()
## in UndergroundNerax.gd and _check_grudge_quest_completion() there too -
## the assassin's own on_defeat_story_flag_id is the source of truth.
func _check_blade_quest_completion() -> void:
	if not RunManager.is_quest_active("blade_in_the_dark"):
		return
	if not bool(RunManager.run.story_flags.get("city_assassin_defeated", false)):
		return
	var quest_def := QuestRegistry.get_quest("blade_in_the_dark")
	var levels_gained := RunManager.complete_quest("blade_in_the_dark")
	var reward_desc := quest_def.describe_reward() if quest_def != null else ""
	var message := "The assassin won't threaten anyone else. Bounty claimed! Reward: %s." % reward_desc
	for lvl in levels_gained:
		message += " Level up! You reached level %d." % lvl
	hud.show_notification(message)
