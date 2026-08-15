extends ExplorationArea
## An old campsite west of the Plaza (a second exit carved into its west
## wall, alongside the existing Two-Way Alley door), still within sight of
## the city's outer wall to the south. Three mercenaries - "the Flankers" -
## camp here between jobs and call out looking for work.
##
## Their dialogue branches on run state, checked in priority order every time
## they're talked to:
## 1. Dead (fought and lost - "Mind your own business" below) - idle line.
## 2. Retired (recruited and already used for a mission - see below) - idle line.
## 3. A recruitable mission is active (unlock_east_side / snake_slaying) and
##    they haven't been recruited for it yet - offers to bring them along,
##    finally giving the original "sorry, nothing for now" placeholder from
##    below somewhere to actually plug into.
## 4. Otherwise, the original pitch: Yes (still nothing to offer - honest
##    placeholder), No (flavor, they're resting up), or "Mind your own
##    business" (starts a fight against all three at once).
##
## Recruiting doesn't teleport them anywhere - it just sets a
## flankers_recruited_for_<mission> flag that the relevant scene
## (EastCheckpoint.gd / DeepForest.gd) reads when it starts that one fight.
## Whichever mission fight they're brought into, they're a one-time resource:
## _check_flanker_retirement() below resolves the outcome (retire-with-gift if
## any died, thank-you-and-leave if all three made it) the next time the
## player is back here, and hides them for good either way.

const FLANKER_ENEMY_IDS: Array[String] = ["flanker_tank", "flanker_mage", "flanker_healer"]

@onready var flankers: Interactable = $FlankersInteract

func get_scene_path() -> String:
	return SceneManager.MERCENARY_CAMP

func get_objective_text() -> String:
	return "An old campsite. Three mercenaries are looking for work - or a fight."

func _on_area_ready() -> void:
	_check_flanker_retirement()
	if RunManager.run != null and (bool(RunManager.run.story_flags.get("flankers_defeated", false)) or bool(RunManager.run.story_flags.get("flankers_retired", false))):
		_hide_flankers()

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == flankers:
		_talk_to_flankers()
		return
	super._on_interactable_triggered(interactable)

func _talk_to_flankers() -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	if bool(RunManager.run.story_flags.get("flankers_defeated", false)):
		hud.show_notification("The campsite is quiet. Whatever happened here, it's over.")
		return
	if bool(RunManager.run.story_flags.get("flankers_retired", false)):
		hud.show_notification("The campsite sits empty - bedrolls gone, fire long cold. The Flankers moved on.")
		return
	if RunManager.is_quest_active("unlock_east_side") and not bool(RunManager.run.story_flags.get("flankers_recruited_for_east_side", false)):
		_offer_recruitment("flankers_recruited_for_east_side", "\"Heard there's a checkpoint shaking down travelers east of the Plaza,\" you say. \"Could use the help.\"")
		return
	if RunManager.is_quest_active("snake_slaying") and not bool(RunManager.run.story_flags.get("flankers_recruited_for_snake", false)):
		_offer_recruitment("flankers_recruited_for_snake", "\"There's a snake the size of a wagon heading for the city,\" you say. \"Guild wants it dead. Interested?\"")
		return
	dialogue_popup.show_prompt(
		"\"You there!\" the biggest of the three calls out, thumbing over one shoulder at his companions. \"The Flankers - we're between contracts. Got any work for us?\"",
		"Yes", "No", "Mind your own business"
	)
	dialogue_popup.choice_made.connect(_on_flankers_choice, CONNECT_ONE_SHOT)

func _offer_recruitment(recruit_flag: String, pitch: String) -> void:
	dialogue_popup.show_prompt(
		pitch + " \"Now you're talking,\" the tank grins. \"One job, then we're square. Deal?\"",
		"Recruit them", "Not yet", ""
	)
	dialogue_popup.choice_made.connect(_on_recruit_choice.bind(recruit_flag), CONNECT_ONE_SHOT)

func _on_recruit_choice(choice_index: int, recruit_flag: String) -> void:
	if choice_index != 0 or RunManager.run == null:
		return
	RunManager.run.story_flags[recruit_flag] = true
	RunManager.save_current_run()
	hud.show_notification("\"We'll be there,\" the tank says. \"Try not to get us all killed.\"")

func _on_flankers_choice(choice_index: int) -> void:
	match choice_index:
		0:
			hud.show_notification("\"Wish I did,\" you admit. \"Ah - sorry, nothing for now,\" the mercenary shrugs, unbothered. \"No shame in asking. Come find us again if that changes - we're not going anywhere.\"")
		1:
			hud.show_notification("\"No work, no,\" you say. \"Fair enough,\" she says, rolling her shoulders. \"Just got back from a big job ourselves - resting up before the next one. Keep us in the loop if something big comes together. We don't sit still long.\"")
		_:
			hud.show_notification("\"Careful,\" the tank says, already stepping between you and the other two. \"That's not the answer we were hoping for.\"")
			hud.notification_finished.connect(_start_flankers_fight, CONNECT_ONE_SHOT)

func _start_flankers_fight() -> void:
	start_combat(FLANKER_ENEMY_IDS, get_scene_path())

## "Return here implies it happened," same convention every other multi-scene
## resolution beat in the game uses - checks whether a recruited mission fight
## has actually concluded (its own on_defeat_story_flag_id is set) rather than
## just whether recruitment happened, so wandering back to camp mid-mission
## doesn't retire them early.
func _check_flanker_retirement() -> void:
	if RunManager.run == null or bool(RunManager.run.story_flags.get("flankers_retired", false)):
		return
	var used_for_east := bool(RunManager.run.story_flags.get("flankers_recruited_for_east_side", false)) and bool(RunManager.run.story_flags.get("east_mercenaries_defeated", false))
	var used_for_snake := bool(RunManager.run.story_flags.get("flankers_recruited_for_snake", false)) and bool(RunManager.run.story_flags.get("forest_snake_defeated", false))
	if not used_for_east and not used_for_snake:
		return
	RunManager.run.story_flags["flankers_retired"] = true
	var lost_any := false
	for id in FLANKER_ENEMY_IDS:
		if RunManager.run.last_combat_ally_casualty_ids.has(id):
			lost_any = true
			break
	if lost_any:
		RunManager.run.add_artifact("flankers_signet")
	RunManager.save_current_run()
	hud.refresh_stats()
	_hide_flankers()
	if lost_any:
		hud.show_notification("The campsite is different - quieter. \"We lost people out there,\" one of the survivors says, voice flat. \"We're done. This is yours now - you earned it more than we did.\" They press a signet ring into your hand before the last of them leaves for good.||Whatever's left of the Flankers is gone.")
	else:
		hud.show_notification("\"Hell of a job,\" the tank says, already packing up the last of the camp. \"Best work we've had in a long while - and we walked away in one piece, all three of us. That's rare enough we're calling it a good note to end on.\" They clasp your hand, and then they're gone - moved on to wherever mercenaries go next.")

func _hide_flankers() -> void:
	for path in ["FlankersInteract", "TankVisual", "MageVisual", "HealerVisual"]:
		var node := get_node_or_null(path)
		if node != null:
			node.visible = false
	if flankers != null:
		flankers.monitorable = false
		flankers.set_deferred("monitoring", false)
