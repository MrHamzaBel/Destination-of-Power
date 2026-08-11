extends ExplorationArea
## The heart of Nerax's underground, reached via the Deeper Alley: four
## separate thugs (three regular, one mage miniboss) who can be fought in
## any order, an underground trader selling mana potions, and a boss that
## ambushes the player the instant the last of the four thugs falls -
## tracked purely by a shared counter (RunData.counters via
## EnemyDefinition.on_defeat_counter_id), so it genuinely doesn't matter
## which one is fought last.

const BOSS_TRIGGER_COUNT: int = 4

func get_scene_path() -> String:
	return SceneManager.UNDERGROUND_NERAX

func get_objective_text() -> String:
	return "Four thugs guard this chamber. A trader lurks between them."

func _on_area_ready() -> void:
	var trader_visual := get_node_or_null("ManaTraderInteract/ManaTraderVisual") as EnemyCharacter
	if trader_visual != null:
		trader_visual.polygon.color = Color(0.5, 0.45, 0.3, 1)
		trader_visual.name_label.text = "Trader"

	if RunManager.run == null:
		return
	if not bool(RunManager.run.story_flags.get("underground_nerax_intro_shown", false)):
		RunManager.run.story_flags["underground_nerax_intro_shown"] = true
		RunManager.save_current_run()
		hud.show_notification("The passage opens into a damp, torchlit chamber beneath Nerax. Rough voices echo from the shadows - this place is not empty.")

	_check_grudge_quest_completion()
	_check_boss_trigger()

## "The Guild's Grudge" completes the instant the Warlord's death flag is
## set - checked here (every time this scene loads) rather than at the kill
## itself, same "return here implies it happened" pattern _check_boss_trigger()
## already uses.
func _check_grudge_quest_completion() -> void:
	if not RunManager.is_quest_active("guild_grudge"):
		return
	if not bool(RunManager.run.story_flags.get("underground_boss_defeated", false)):
		return
	var quest_def := QuestRegistry.get_quest("guild_grudge")
	var levels_gained := RunManager.complete_quest("guild_grudge")
	var reward_desc := quest_def.describe_reward() if quest_def != null else ""
	var message := "Word of the Warlord's defeat will reach the guild soon. Bounty claimed! Reward: %s." % reward_desc
	for lvl in levels_gained:
		message += " Level up! You reached level %d." % lvl
	hud.show_notification(message)

## The boss doesn't have its own interactable - it ambushes automatically
## the moment the fourth thug (in any order) is confirmed dead, checked every
## time this scene loads (including the instant we return here after winning
## the fight that happened to be the last one).
func _check_boss_trigger() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("underground_boss_defeated", false)):
		return
	if RunManager.get_counter("underground_thugs_defeated") < BOSS_TRIGGER_COUNT:
		return
	start_combat(["underground_boss"], get_scene_path())
