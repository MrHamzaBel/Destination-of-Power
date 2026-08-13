extends ExplorationArea
## The raised ward above Southside's market: three beggars lining the old
## wall, and a stairway up to the guarded gate at Nerax's inner wall. Two of
## the three beggars are flavor-only; the third is a retired adventurer whose
## gratitude is worth more than the coin he asks for.

const BEGGAR_GOLD_ASK: int = 10

@onready var hollow_eyed_beggar: Interactable = $HollowEyedBeggarInteract
@onready var shivering_beggar: Interactable = $ShiveringBeggarInteract
@onready var old_soldier_beggar: Interactable = $OldSoldierBeggarInteract

func get_scene_path() -> String:
	return SceneManager.NERAX_UPPER_WARD

func get_objective_text() -> String:
	return "A few beggars shelter along the wall. Steps lead further up toward the inner wall."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == hollow_eyed_beggar:
		_ask_for_coin(
			"\"Spare a coin, friend? Anything helps.\"",
			"\"Bless you. Truly.\" The beggar presses your hand between both of theirs."
		)
		return
	if interactable == shivering_beggar:
		_ask_for_coin(
			"\"C-cold out here... could you spare something?\"",
			"\"Th-thank you... you didn't have to.\" They pull a thin blanket tighter around themselves."
		)
		return
	if interactable == old_soldier_beggar:
		_talk_to_old_soldier()
		return
	super._on_interactable_triggered(interactable)

## Shared "spare a coin" flow for the two ordinary beggars - flavor only, no
## mechanical reward, which is exactly what makes the third beggar's gift a
## surprise instead of an obvious pattern.
func _ask_for_coin(prompt: String, thanks: String) -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	dialogue_popup.show_prompt(prompt, "Give %d gold" % BEGGAR_GOLD_ASK, "Walk away", "")
	dialogue_popup.choice_made.connect(func(choice_index: int):
		if choice_index != 0:
			return
		if RunManager.run.currency < BEGGAR_GOLD_ASK:
			hud.show_notification("You don't have %d gold to spare." % BEGGAR_GOLD_ASK)
			return
		RunManager.run.currency -= BEGGAR_GOLD_ASK
		RunManager.save_current_run()
		hud.refresh_stats()
		hud.show_notification(thanks)
	, CONNECT_ONE_SHOT)

## The one beggar who's more than he looks - a retired adventurer down on his
## luck. Giving him coin unlocks a short reveal and his own artifact from his
## adventuring days, once (guarded by story_flags, same as any other one-shot
## reward), and never again on later visits.
func _talk_to_old_soldier() -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	if bool(RunManager.run.story_flags.get("old_soldier_gifted", false)):
		hud.show_notification("\"Those boots still serve you well, I hope,\" the old man says, with a faint smile.")
		return
	dialogue_popup.show_prompt(
		"\"Spare a coin? Used to earn my own, once,\" the old man says, not quite meeting your eyes.",
		"Give %d gold" % BEGGAR_GOLD_ASK, "Walk away", ""
	)
	dialogue_popup.choice_made.connect(_on_old_soldier_choice, CONNECT_ONE_SHOT)

func _on_old_soldier_choice(choice_index: int) -> void:
	if choice_index != 0:
		hud.show_notification("The old man nods, unbothered, and goes back to watching the street.")
		return
	if RunManager.run == null:
		return
	if RunManager.run.currency < BEGGAR_GOLD_ASK:
		hud.show_notification("You don't have %d gold to spare." % BEGGAR_GOLD_ASK)
		return
	RunManager.run.currency -= BEGGAR_GOLD_ASK
	RunManager.run.story_flags["old_soldier_gifted"] = true
	RunManager.run.add_artifact("swiftie_boots")
	RunManager.save_current_run()
	hud.refresh_stats()
	hud.show_notification(
		"\"...First kindness anyone's shown me in months.\" He studies you a moment, then unstraps a pair of scuffed boots from his pack. \"Name's not important anymore. But these got me out of more fights than I can count - faster than anything chasing me ever was. Swiftie Boots, I called them. They're yours now.\"" +
		ExplorationHUD.NOTIFICATION_PAGE_BREAK +
		"He watches you lace them up, something like pride flickering across his face before he waves you on. \"Use them well - run when you're faster, fight when you're not.\""
	)
