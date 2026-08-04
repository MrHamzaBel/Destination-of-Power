extends ExplorationArea
## The guild's back lounge, unlocked at C-Rank and above. Its shop discounts
## with the same percentage the player's rank gives on guild tax.
##
## Also where the "Find Wassim" quest resolves: reaching the lounge at all
## already proves the player has the rank for it (the Lounge Door EXIT is
## rank-gated), so no extra check is needed here - just talking to Wassim.

@onready var wassim: Interactable = $WassimInteract

func get_scene_path() -> String:
	return SceneManager.GUILD_LOUNGE

func get_objective_text() -> String:
	return "Browse the lounge shop."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == wassim:
		_talk_to_wassim()
		return
	super._on_interactable_triggered(interactable)

func _talk_to_wassim() -> void:
	if RunManager.run == null:
		return
	if RunManager.is_quest_active("find_wassim"):
		var quest_def := QuestRegistry.get_quest("find_wassim")
		var levels_gained := RunManager.complete_quest("find_wassim")
		var message := "\"Oh, thank the Crown-\" Wassim slumps against the wall. \"I just wanted to see the lounge, I didn't know you needed rank for it, I swear.\" You have a quiet word with the guild staff and the matter is dropped. Reward: %s." % (quest_def.describe_reward() if quest_def != null else "")
		for lvl in levels_gained:
			message += " Level up! You reached level %d." % lvl
		hud.show_notification(message)
	elif RunManager.is_quest_completed("find_wassim"):
		hud.show_notification("Wassim gives you a sheepish nod from across the lounge. \"Still can't believe they let me stay,\" he mutters.")
	else:
		hud.show_notification("A guild member pointedly ignores the disheveled young man muttering apologies in the corner.")
