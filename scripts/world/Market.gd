extends ExplorationArea
## Southside's market way: a long street lined with houses connecting the
## Plaza (north) to the southern gate out of Nerax (south).

func get_scene_path() -> String:
	return SceneManager.MARKET

func get_objective_text() -> String:
	return "Head south through the market to the gate, back north to the plaza, or up the ward stairs to the east."

func _on_area_ready() -> void:
	var vendor_visual := get_node_or_null("MarketVendorInteract/MarketVendorVisual") as EnemyCharacter
	if vendor_visual != null:
		vendor_visual.polygon.color = Color(0.55, 0.45, 0.28, 1)
		vendor_visual.name_label.text = "Vendor"

	var resident_visual := get_node_or_null("GossipingResidentInteract/GossipingResidentVisual") as EnemyCharacter
	if resident_visual != null:
		resident_visual.polygon.color = Color(0.4, 0.38, 0.42, 1)
		resident_visual.name_label.text = "Resident"
