extends ExplorationArea
## A wider junction alley connecting the dead-end Back Alley (west) to the
## Nerax plaza (east). Home to a small trader testing the gold-for-item
## exchange mechanic.

func get_scene_path() -> String:
	return SceneManager.TWO_WAY_ALLEY

func get_objective_text() -> String:
	return "Head east toward the plaza, or trade with the alley trader."

func _on_area_ready() -> void:
	var trader_visual := get_node_or_null("TraderInteract/TraderVisual") as EnemyCharacter
	if trader_visual != null:
		trader_visual.polygon.color = Color(0.55, 0.42, 0.25, 1)
		trader_visual.name_label.text = "Trader"
