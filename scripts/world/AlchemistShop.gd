extends ExplorationArea
## The Gilded Retort: repeatable Minor Healing/Mana Potions at an inner-market
## markup, plus five one-of-a-kind elixirs - Might/Warding/Swiftness/Insight
## (Attack/Defense/Speed/Intelligence) and Vitality (HP), each a plain TRADE
## interactable with its own Interactable.purchase_flag_id, so
## ExplorationArea's generic one-time-purchase gating handles "only one
## bottle, ever" per elixir without any custom script logic here.

func get_scene_path() -> String:
	return SceneManager.ALCHEMIST_SHOP

func get_objective_text() -> String:
	return "The Gilded Retort. Potions as usual - and five bottles you'll only ever see once."
