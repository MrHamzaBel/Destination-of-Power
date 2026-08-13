extends ExplorationArea
## The Curious Case: a general store selling basic starter-tier gear
## (previously only obtainable as starting_equipment, never purchasable
## anywhere) plus two exclusive artifacts - Ironclad Signet and Phantom Step
## Charm, both random_drop_eligible = false, so the only way to ever get them
## is to pay the price here.

func get_scene_path() -> String:
	return SceneManager.RELIC_SHOP

func get_objective_text() -> String:
	return "The Curious Case. Basic gear up front, a couple of expensive relics in the back."
