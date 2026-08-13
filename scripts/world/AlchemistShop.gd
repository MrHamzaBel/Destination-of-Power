extends ExplorationArea
## The Gilded Retort: repeatable Minor Healing/Mana Potions at an inner-market
## markup, plus the one-of-a-kind All-Stat Elixir - a plain TRADE interactable
## with Interactable.purchase_flag_id set, so ExplorationArea's generic
## one-time-purchase gating handles the "only one bottle, ever" framing
## without any custom script logic here.

func get_scene_path() -> String:
	return SceneManager.ALCHEMIST_SHOP

func get_objective_text() -> String:
	return "The Gilded Retort. Potions as usual - and one bottle you'll only ever see once."
