extends ExplorationArea
## The Adventure Centrum: Nerax's guild hall, where quests and missions get
## posted.

@onready var elin: Interactable = $GuildScoutElinInteract
@onready var receptionist: Interactable = $ReceptionistInteract

func get_scene_path() -> String:
	return SceneManager.ADVENTURE_CENTRUM

func get_objective_text() -> String:
	return "Look around the Adventure Centrum."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == elin:
		_talk_to_elin(interactable)
		return
	if interactable == receptionist:
		_talk_to_receptionist(interactable)
		return
	super._on_interactable_triggered(interactable)

## The Receptionist is a guaranteed-permanent NPC (unlike, say, the Deep
## Forest hunter, who can vanish for good once the bear skin's sold to him) -
## which is exactly why Wolf Cull lives here rather than out in the field: a
## repeatable bounty needs a source that can never go missing. Offered first,
## ahead of her usual enrollment/rank-up business, whenever it's available;
## declining just drops back to talking to her again for the normal flow.
func _talk_to_receptionist(interactable: Interactable) -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	var rank_def := RunManager.get_guild_rank_def()
	if rank_def != null and rank_def.order >= 1 and not RunManager.is_quest_active("wolf_cull"):
		dialogue_popup.show_prompt(
			"\"Before you head out,\" the receptionist says, glancing up from her ledger, \"there's a standing bounty on wolves along the forest road, if you're interested. Guild's put coin behind thinning them out.\"",
			"Accept", "Not now", ""
		)
		dialogue_popup.choice_made.connect(_on_receptionist_wolf_offer, CONNECT_ONE_SHOT)
		return
	_handle_guild_receptionist(interactable)

func _on_receptionist_wolf_offer(choice_index: int) -> void:
	if choice_index != 0:
		return
	RunManager.start_quest("wolf_cull")
	hud.show_notification("\"I'll mark it down,\" she says. \"Good hunting.\"")

## Elin runs a tiny two-quest chain through one NPC: she offers "Into the
## Hollow" first (using the interactable's own exported dialogue fields, same
## as any other DIALOGUE npc), then - once that's done - always offers the
## repeatable "Hollow Menace" follow-up instead.
func _talk_to_elin(interactable: Interactable) -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	if not RunManager.is_quest_completed("into_the_hollow"):
		_open_dialogue(interactable)
		return
	if RunManager.is_quest_active("hollow_menace"):
		hud.show_notification("\"Still hunting wisps? Good luck down there,\" Elin says.")
		return
	dialogue_popup.show_prompt(
		"\"Good work on the scouting,\" Elin says. \"The guild's put out a standing bounty on the wisps down there now - eight of them, if you're willing.\"",
		"Accept", "Not now", ""
	)
	dialogue_popup.choice_made.connect(_on_elin_followup_choice, CONNECT_ONE_SHOT)

func _on_elin_followup_choice(choice_index: int) -> void:
	if choice_index != 0:
		return
	RunManager.start_quest("hollow_menace")
	hud.show_notification("\"Good hunting,\" she says, marking it down.")
