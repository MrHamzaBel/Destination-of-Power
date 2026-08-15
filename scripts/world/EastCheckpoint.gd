extends ExplorationArea
## The road east of the Plaza: a citizen shaken down in view of the entrance,
## and a four-mercenary checkpoint further in demanding a toll no honest
## traveler could pay. The ultimatum only plays once - after that, the
## checkpoint just offers to settle it, optionally with the Flankers along
## (see MercenaryCamp.gd for how they get recruited for this specific job).

const CHECKPOINT_ENEMY_IDS: Array[String] = ["checkpoint_brute", "checkpoint_gambler", "checkpoint_marksman", "checkpoint_defender"]
const FLANKER_ALLY_IDS: Array[String] = ["flanker_tank", "flanker_mage", "flanker_healer"]

@onready var checkpoint: Interactable = $CheckpointInteract
@onready var east_exit: Interactable = $ExitFurtherEast

func get_scene_path() -> String:
	return SceneManager.EAST_CHECKPOINT

func get_objective_text() -> String:
	return "A checkpoint blocks the road east. Deal with them, one way or another."

func _on_area_ready() -> void:
	if RunManager.run == null:
		return
	if not bool(RunManager.run.story_flags.get("east_checkpoint_intro_shown", false)):
		RunManager.run.story_flags["east_checkpoint_intro_shown"] = true
		RunManager.save_current_run()
		hud.show_notification("A citizen stumbles backward and hits the ground hard, scrambling after a dropped basket. \"Please, I just need to get through -\"||\"Being poor and stubborn is a choice,\" the mercenary standing over him says, almost bored. \"Don't let it be your last one.\" He doesn't even look up as you approach.")
	_check_east_side_unlock()

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == checkpoint:
		_talk_to_checkpoint()
		return
	if interactable == east_exit:
		if RunManager.run == null or not bool(RunManager.run.story_flags.get("east_mercenaries_defeated", false)):
			hud.show_notification("The mercenaries block the way - you'll have to deal with them first.")
			return
		SceneManager.goto_scene(SceneManager.EASTERN_ROAD)
		return
	super._on_interactable_triggered(interactable)

func _talk_to_checkpoint() -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	if bool(RunManager.run.story_flags.get("east_mercenaries_defeated", false)):
		hud.show_notification("The checkpoint stands empty now - the road east is clear.")
		return
	if RunManager.is_quest_active("unlock_east_side"):
		var ally_ids: Array[String] = FLANKER_ALLY_IDS if bool(RunManager.run.story_flags.get("flankers_recruited_for_east_side", false)) else []
		dialogue_popup.show_prompt(
			"\"Back again?\" the marksman drawls. \"Changed your mind about paying, or did you bring friends this time?\"",
			"Fight them", "Not yet", ""
		)
		dialogue_popup.choice_made.connect(_on_ready_to_fight_choice.bind(ally_ids), CONNECT_ONE_SHOT)
		return
	dialogue_popup.show_prompt(
		"\"You can't even pay,\" the marksman sneers, looking you up and down. \"So here's the deal - hand over everything, every item, every relic you're carrying, and maybe we let you through.\"",
		"Yes", "No, I guess I'll head back", ""
	)
	dialogue_popup.choice_made.connect(_on_ultimatum_choice, CONNECT_ONE_SHOT)

func _on_ready_to_fight_choice(choice_index: int, ally_ids: Array[String]) -> void:
	if choice_index != 0:
		hud.show_notification("\"Your call,\" the marksman shrugs.")
		return
	hud.show_notification("\"Have it your way, then,\" the marksman says, already reaching for his bow.")
	hud.notification_finished.connect(_start_checkpoint_fight.bind(ally_ids), CONNECT_ONE_SHOT)

func _on_ultimatum_choice(choice_index: int) -> void:
	if choice_index == 0:
		if RunManager.run != null:
			RunManager.run.inventory.clear()
			RunManager.run.equipped.clear()
			RunManager.run.artifacts.clear()
			RunManager.save_current_run()
			hud.refresh_stats()
		hud.show_notification("You hand over everything - every last item, every relic. The marksman counts it with a satisfied nod, then draws his bow anyway. \"Poor and stubborn,\" he says. \"Should've just fought us to begin with.\"")
		hud.notification_finished.connect(_start_checkpoint_fight.bind([] as Array[String]), CONNECT_ONE_SHOT)
	else:
		hud.show_notification("\"No - I guess I'll head back,\" you say, backing away. The mercenaries laugh. \"Smart,\" the marksman calls after you. \"Come back if you grow a spine - or find some friends.\"")
		hud.notification_finished.connect(_start_unlock_quest, CONNECT_ONE_SHOT)

func _start_checkpoint_fight(ally_ids: Array[String]) -> void:
	start_combat(CHECKPOINT_ENEMY_IDS, get_scene_path(), false, ally_ids)

func _start_unlock_quest() -> void:
	RunManager.start_quest("unlock_east_side")

## "Return here implies it happened" - same convention GarrisonWard/UndergroundNerax
## already use. Works regardless of which path led to the mercenaries' defeat
## (the immediate stripped-bare fight, or the quest fight later), since both
## set the same on_defeat_story_flag_id on all four enemies.
func _check_east_side_unlock() -> void:
	if RunManager.run == null:
		return
	if not bool(RunManager.run.story_flags.get("east_mercenaries_defeated", false)):
		return
	if bool(RunManager.run.story_flags.get("east_side_unlock_granted", false)):
		return
	RunManager.run.story_flags["east_side_unlock_granted"] = true
	if RunManager.is_quest_active("unlock_east_side"):
		RunManager.complete_quest("unlock_east_side")
	for stat_name in RunManager.STAT_NAMES:
		RunManager.grant_stat_bonus(stat_name, 1)
	RunManager.save_current_run()
	hud.refresh_stats()
	hud.show_notification("With the checkpoint cleared, the road east lies open. You feel stronger for it - every one of your stats has permanently increased.")
