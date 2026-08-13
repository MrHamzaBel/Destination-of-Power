extends ExplorationArea
## Silks & Seams: the one interactable that matters is the Tailor, who offers
## to restyle the player's appearance for 30 gold - reuses CharacterCreator
## itself (via SceneManager.start_appearance_edit()) rather than building a
## second appearance-picking UI, just with the name field locked and Save/Back
## returning here instead of the Main Menu.

const RESTYLE_COST: int = 30

@onready var tailor: Interactable = $TailorInteract

func get_scene_path() -> String:
	return SceneManager.CLOTHING_SHOP

func get_objective_text() -> String:
	return "Silks & Seams. The tailor can restyle your look for %d gold." % RESTYLE_COST

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == tailor:
		_offer_restyle()
		return
	super._on_interactable_triggered(interactable)

func _offer_restyle() -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	dialogue_popup.show_prompt(
		"\"A new look? Hair, skin, clothes, the works - whatever you fancy, except the name, that's yours to keep.\" %d gold, paid up front." % RESTYLE_COST,
		"Restyle (%d gold)" % RESTYLE_COST, "Not today", ""
	)
	dialogue_popup.choice_made.connect(_on_restyle_choice, CONNECT_ONE_SHOT)

func _on_restyle_choice(choice_index: int) -> void:
	if choice_index != 0 or RunManager.run == null:
		return
	if RunManager.run.currency < RESTYLE_COST:
		hud.show_notification("\"Come back when you've got %d gold,\" the tailor says." % RESTYLE_COST)
		return
	RunManager.run.currency -= RESTYLE_COST
	RunManager.save_current_run()
	hud.refresh_stats()
	SceneManager.start_appearance_edit(get_scene_path())
