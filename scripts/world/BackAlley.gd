extends Node2D
## Starting exploration area. Wires the player, HUD, pause menu and inventory
## overlay together and reacts to Interactable triggers placed in the scene.

@onready var player: PlayerCharacter = %Player
@onready var hud: ExplorationHUD = %HUD
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var inventory_screen: InventoryScreen = %InventoryScreen

func _ready() -> void:
	if RunManager.run != null:
		RunManager.run.current_scene_path = SceneManager.BACK_ALLEY
		RunManager.save_current_run()

	hud.setup(player)
	hud.set_objective("Explore the alley and find a way out to the streets.")

	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_screen.visible = false
	pause_menu.inventory_requested.connect(_open_inventory)
	inventory_screen.closed.connect(_close_inventory)

	_connect_interactables()
	_show_intro()

func _show_intro() -> void:
	var lore: LoreScript = load("res://resources/lore/back_alley_intro.tres")
	if lore != null and lore.sections.size() > 0:
		hud.show_notification(lore.sections[0])

func _connect_interactables() -> void:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Interactable:
			var already_resolved: bool = node.story_flag_id != "" and RunManager.run != null and bool(RunManager.run.story_flags.get(node.story_flag_id, false))
			if already_resolved:
				node.visible = false
				node.monitorable = false
				continue
			node.interacted.connect(_on_interactable_triggered)
			if node.kind == Interactable.Kind.COMBAT and not node.enemy_ids.is_empty():
				for child in node.get_children():
					if child is EnemyCharacter:
						child.setup(EnemyRegistry.get_enemy(node.enemy_ids[0]))

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable.story_flag_id != "" and RunManager.run != null and RunManager.run.story_flags.get(interactable.story_flag_id, false):
		hud.show_notification("The alley is quiet now.")
		return
	if interactable.story_flag_id != "" and RunManager.run != null:
		RunManager.run.story_flags[interactable.story_flag_id] = true
		RunManager.save_current_run()

	match interactable.kind:
		Interactable.Kind.MESSAGE:
			hud.show_notification(interactable.message)
		Interactable.Kind.COMBAT:
			var return_scene := interactable.victory_return_scene if interactable.victory_return_scene != "" else SceneManager.BACK_ALLEY
			SceneManager.start_combat(interactable.enemy_ids, return_scene)
		Interactable.Kind.EXIT:
			SceneManager.goto_scene(SceneManager.ENCOUNTER_SCREEN)
		Interactable.Kind.HEAL:
			if RunManager.run != null:
				var stats := RunManager.compute_current_stats()
				RunManager.run.current_health = stats.max_health
				RunManager.save_current_run()
				hud.refresh_stats()
			hud.show_notification("You feel restored.")
		Interactable.Kind.ITEM:
			if RunManager.run != null and interactable.item_id != "":
				RunManager.run.add_item(interactable.item_id, interactable.item_quantity)
				RunManager.save_current_run()
				var item_def := ItemRegistry.get_item(interactable.item_id)
				hud.show_notification("Found: %s" % (item_def.display_name if item_def != null else interactable.item_id))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if inventory_screen.visible:
			_close_inventory()
		else:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory_toggle"):
		if not pause_menu.visible:
			if inventory_screen.visible:
				_close_inventory()
			else:
				_open_inventory()
			get_viewport().set_input_as_handled()

func _open_inventory() -> void:
	pause_menu.close()
	inventory_screen.refresh()
	inventory_screen.visible = true
	get_tree().paused = true

func _close_inventory() -> void:
	inventory_screen.visible = false
	get_tree().paused = false
