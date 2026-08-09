extends ExplorationArea
## The bigger forest beyond the portal encounter: a sleeping bear (a genuine
## tough fight, no special mechanics - just solid stats all around) west,
## and a hunter east who reacts differently once the bear's skin is in the
## player's pack.

@onready var hunter: Interactable = $HunterInteract

func get_scene_path() -> String:
	return SceneManager.DEEP_FOREST

func get_objective_text() -> String:
	return "A bear dozes to the west. A hunter watches the treeline to the east."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == hunter:
		_talk_to_hunter(interactable)
		return
	super._on_interactable_triggered(interactable)

## The hunter's "did you feel that" icebreaker always plays first, exactly
## once, regardless of whether the player already has the bear skin (killing
## the bear before ever talking to him shouldn't skip straight to the sell
## offer). After that one-time icebreaker, every later interaction offers to
## buy the skin for 50 gold if the player is still carrying one - worse than
## selling to any regular vendor (see ExplorationArea._try_sell_to_vendor(),
## which pays the skin's full value) - or an idle line if not. Selling to him
## specifically makes him leave for good (story_flag_id on the node itself) -
## which is exactly why Wolf Cull is no longer offered through him: it now
## lives with the Guild Receptionist instead (see AdventureCentrum.gd), an
## NPC who's never at risk of permanently disappearing mid-run.
func _talk_to_hunter(interactable: Interactable) -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	if not bool(RunManager.run.story_flags.get("hunter_greeted", false)):
		RunManager.run.story_flags["hunter_greeted"] = true
		RunManager.save_current_run()
		_open_dialogue(interactable)
		return

	if RunManager.run.get_item_quantity("bear_skin") > 0:
		dialogue_popup.show_prompt(
			"\"...You actually killed it?\" He whistles low. \"You're either an idiot or you're something else entirely.\" He nods at your pack. \"I'll give you 50 gold for that bear skin, right now, no questions asked.\"",
			"Sell for 50 gold", "Keep it", ""
		)
		dialogue_popup.choice_made.connect(_on_hunter_offer, CONNECT_ONE_SHOT)
		return

	hud.show_notification("The hunter gives you a small nod and goes back to watching the treeline.")

func _on_hunter_offer(choice_index: int) -> void:
	if choice_index != 0 or RunManager.run == null:
		return
	if not RunManager.run.remove_item("bear_skin", 1):
		return
	RunManager.run.currency += 50
	if hunter.story_flag_id != "":
		RunManager.run.story_flags[hunter.story_flag_id] = true
	RunManager.save_current_run()
	hud.refresh_stats()
	hud.show_notification("\"Pleasure doing business!\" The hunter snatches the skin and bolts into the trees before you can change your mind - that price was a steal, and he knows it.")
	hunter.visible = false
	hunter.monitorable = false
	hunter.set_deferred("monitoring", false)
