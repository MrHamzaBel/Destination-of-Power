class_name ExplorationArea
extends Node2D
## Shared wiring for exploration scenes (spawn area, alleys, plaza, ...):
## player/HUD/pause-menu/inventory setup, interactable connection, and the
## common interactable-trigger handling (message/combat/exit/heal/item/trade).
##
## Concrete scenes extend this and override get_scene_path(),
## get_objective_text() and, optionally, _on_area_ready() for one-time
## scene-specific setup (e.g. an intro notification). No other duplication
## is needed - a new area is a new .tscn plus a tiny script like BackAlley.gd.

@onready var player: PlayerCharacter = %Player
@onready var hud: ExplorationHUD = %HUD
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var inventory_screen: InventoryScreen = %InventoryScreen
@onready var dialogue_popup: DialogueChoicePopup = get_node_or_null("%DialoguePopup") ## Optional - only scenes with a DIALOGUE interactable need one.

func _ready() -> void:
	if RunManager.run != null:
		RunManager.run.current_scene_path = get_scene_path()
		RunManager.save_current_run()

	hud.setup(player)
	hud.set_objective(get_objective_text())

	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_screen.visible = false
	pause_menu.inventory_requested.connect(_open_inventory)
	inventory_screen.closed.connect(_close_inventory)

	_connect_interactables()
	_on_area_ready()

## --- Overridable hooks ---------------------------------------------------

func get_scene_path() -> String:
	return ""

func get_objective_text() -> String:
	return ""

func _on_area_ready() -> void:
	pass # Optional per-scene one-time setup, e.g. an intro notification.

## --- Interactables ---------------------------------------------------------

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
	if interactable.story_flag_id != "" and RunManager.run != null and bool(RunManager.run.story_flags.get(interactable.story_flag_id, false)):
		hud.show_notification("Nothing more to do here.")
		return
	if interactable.story_flag_id != "" and RunManager.run != null:
		RunManager.run.story_flags[interactable.story_flag_id] = true
		RunManager.save_current_run()

	match interactable.kind:
		Interactable.Kind.MESSAGE:
			hud.show_notification(interactable.message)
		Interactable.Kind.COMBAT:
			var return_scene := interactable.victory_return_scene if interactable.victory_return_scene != "" else get_scene_path()
			SceneManager.start_combat(interactable.enemy_ids, return_scene)
		Interactable.Kind.EXIT:
			var target := interactable.exit_target_scene if interactable.exit_target_scene != "" else SceneManager.ENCOUNTER_SCREEN
			SceneManager.goto_scene(target)
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
		Interactable.Kind.TRADE:
			_handle_trade(interactable)
		Interactable.Kind.DIALOGUE:
			_open_dialogue(interactable)

## Sells trade_item_id for trade_price gold, adjusted by Thorned Coin's price
## multiplier if the player holds it - exercises the multiplier hook that
## artifact has always defined but nothing previously called.
func _handle_trade(interactable: Interactable) -> void:
	if RunManager.run == null:
		return
	var item_def := ItemRegistry.get_item(interactable.trade_item_id)
	if item_def == null:
		return

	var price := interactable.trade_price
	if RunManager.run.has_artifact("thorned_coin"):
		var effect := ArtifactSystem.get_effect("thorned_coin")
		var artifact_def := ArtifactRegistry.get_artifact("thorned_coin")
		if effect != null and artifact_def != null and effect.has_method("get_shop_price_multiplier"):
			var stacks: int = int(RunManager.run.artifacts.get("thorned_coin", 1))
			price = int(round(float(price) * effect.get_shop_price_multiplier(artifact_def, stacks)))

	if RunManager.run.currency < price:
		hud.show_notification("Not enough gold - %s costs %d gold." % [item_def.display_name, price])
		return

	RunManager.run.currency -= price
	RunManager.run.add_item(interactable.trade_item_id, 1)
	RunManager.save_current_run()
	hud.refresh_stats()
	var notice := "Bought %s for %d gold. (%d gold left)" % [item_def.display_name, price, RunManager.run.currency]
	if interactable.trade_flavor_text != "":
		notice += " " + interactable.trade_flavor_text
	hud.show_notification(notice)

## Shows the yes/no/decline popup for a DIALOGUE interactable. If quest_id is
## set and already active/completed, a status line is shown instead of
## re-running the same pitch.
func _open_dialogue(interactable: Interactable) -> void:
	if interactable.quest_id != "" and RunManager.is_quest_completed(interactable.quest_id):
		if interactable.dialogue_quest_done_text != "":
			hud.show_notification(interactable.dialogue_quest_done_text)
		return
	if interactable.quest_id != "" and RunManager.is_quest_active(interactable.quest_id):
		if interactable.dialogue_quest_active_text != "":
			hud.show_notification(interactable.dialogue_quest_active_text)
		return
	if dialogue_popup == null:
		push_warning("ExplorationArea: %s is a DIALOGUE interactable but this scene has no DialoguePopup." % interactable.display_name)
		return
	dialogue_popup.show_prompt(interactable.dialogue_prompt)
	dialogue_popup.choice_made.connect(_on_dialogue_choice.bind(interactable), CONNECT_ONE_SHOT)

func _on_dialogue_choice(choice_index: int, interactable: Interactable) -> void:
	match choice_index:
		0: # Yes
			hud.show_notification(interactable.dialogue_yes_text)
			if interactable.quest_id != "":
				RunManager.start_quest(interactable.quest_id)
		1: # No
			hud.show_notification(interactable.dialogue_no_text)
		_: # Mind your own business
			hud.show_notification(interactable.dialogue_decline_text)

## --- Pause / inventory overlay ---------------------------------------------

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
