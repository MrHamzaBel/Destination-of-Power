extends ExplorationArea
## The market square just past the guarded inner wall gate: four vendors
## selling consumables found nowhere in the outer city, two guards keeping
## order, and a fountain at its center. Reached only by rank or toll (see
## InnerWallSouth.gd) - the district's prices assume that exclusivity.
##
## The fountain is a real hub, not just a centerpiece - a way leads off in
## every direction. South goes back through the gate (the only way in). West
## and east are both locked-off flavor stubs, reserved for later. North is
## the real way onward, into the shopping street - the first time, that
## triggers a one-time cinematic (GuardsRushCutscene.tscn, a column of
## soldiers rushing to the Royal Castle); every visit after goes straight to
## InnerNeraxShops.tscn, same "seen it once" gating NeraxOutskirts.gd already
## uses for the masked man encounter.

@onready var road_north: Interactable = $RoadNorthInteract

func get_scene_path() -> String:
	return SceneManager.INNER_NERAX

func get_objective_text() -> String:
	return "The inner market. Soldiers rush north - or head back south through the gate."

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == road_north:
		var seen := RunManager.run != null and bool(RunManager.run.story_flags.get("guards_rush_seen", false))
		SceneManager.goto_scene(SceneManager.INNER_NERAX_SHOPS if seen else SceneManager.GUARDS_RUSH_CUTSCENE)
		return
	super._on_interactable_triggered(interactable)

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
