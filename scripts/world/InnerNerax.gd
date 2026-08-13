extends ExplorationArea
## The market square just past the guarded inner wall gate: four vendors
## selling consumables found nowhere in the outer city, two guards keeping
## order, and a fountain at its center. Reached only by rank or toll (see
## InnerWallSouth.gd) - the district's prices assume that exclusivity.

func get_scene_path() -> String:
	return SceneManager.INNER_NERAX

func get_objective_text() -> String:
	return "The inner market. Browse the stalls, or head back through the gate."

func _on_area_ready() -> void:
	_tint_vendor("ApothecaryInteract/ApothecaryVisual", Color(0.95, 0.55, 0.15, 1), "Apothecary")
	_tint_vendor("AlchemistInteract/AlchemistVisual", Color(0.55, 0.4, 0.75, 1), "Alchemist")
	_tint_vendor("WineMerchantInteract/WineMerchantVisual", Color(0.55, 0.15, 0.2, 1), "Wine Merchant")
	_tint_vendor("StreetVendorInteract/StreetVendorVisual", Color(0.7, 0.5, 0.25, 1), "Vendor")

func _tint_vendor(path: String, color: Color, label: String) -> void:
	var visual := get_node_or_null(path) as EnemyCharacter
	if visual == null:
		return
	visual.polygon.color = color
	visual.name_label.text = label
