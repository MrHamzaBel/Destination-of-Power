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
	_apply_arrival_spawn()

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
	_connect_rushing_enemies()
	_on_area_ready()

## --- Overridable hooks ---------------------------------------------------

func get_scene_path() -> String:
	return ""

func get_objective_text() -> String:
	return ""

func _on_area_ready() -> void:
	pass # Optional per-scene one-time setup, e.g. an intro notification.

## Repositions the player near whichever EXIT actually leads back to the
## scene they just came from, instead of always using this scene's single
## fixed Player position regardless of which door was used. Works for every
## existing scene pair automatically - it just looks for an EXIT interactable
## whose exit_target_scene matches where the player arrived from, no new
## per-scene data needed. Falls back to the scene's authored Player position
## (the default, used when arriving from anywhere without such a match - the
## very start of a run, etc.) when nothing matches.
##
## Returning from combat takes priority over all of that: start_combat()
## below records exactly where the player was standing the instant the fight
## began, so win or flee, they end up back on that exact spot instead of
## wherever this scene's nearest matching EXIT happens to be.
func _apply_arrival_spawn() -> void:
	if SceneManager.has_pending_combat_return_position:
		SceneManager.has_pending_combat_return_position = false
		player.global_position = SceneManager.pending_combat_return_position
		return

	var from_path := SceneManager.arriving_from_scene_path
	if from_path == "":
		return
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Interactable:
			var interactable := node as Interactable
			if interactable.kind == Interactable.Kind.EXIT and interactable.exit_target_scene == from_path:
				var inward := (Vector2.ZERO - interactable.position).normalized()
				if inward == Vector2.ZERO:
					inward = Vector2.DOWN
				player.global_position = interactable.global_position + inward * 70.0
				return

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
			start_combat(interactable.enemy_ids, return_scene)
		Interactable.Kind.EXIT:
			if interactable.required_guild_rank_order >= 0:
				var rank_def := RunManager.get_guild_rank_def()
				if rank_def == null or rank_def.order < interactable.required_guild_rank_order:
					if interactable.toll_gold_amount > 0:
						_offer_toll(interactable)
					else:
						hud.show_notification(interactable.locked_message if interactable.locked_message != "" else "You don't have the rank for this yet.")
					return
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
		Interactable.Kind.GUILD_RECEPTIONIST:
			_handle_guild_receptionist(interactable)

## An EXIT gated by guild rank can also name a gold toll (Interactable.
## toll_gold_amount) as a second way through for anyone who hasn't reached
## the required rank yet - e.g. the guarded gate into Nerax's inner wall,
## passable at B-Rank or by paying 100 gold each time. Declining just leaves
## the player on this side, same as any other locked door.
func _offer_toll(interactable: Interactable) -> void:
	if dialogue_popup == null:
		hud.show_notification(interactable.locked_message if interactable.locked_message != "" else "You don't have the rank for this yet.")
		return
	var base_message := interactable.locked_message if interactable.locked_message != "" else "You don't have the rank for this yet."
	dialogue_popup.show_prompt(
		"%s Pay %d gold to pass anyway?" % [base_message, interactable.toll_gold_amount],
		"Pay %d gold" % interactable.toll_gold_amount, "Turn back", ""
	)
	dialogue_popup.choice_made.connect(_on_toll_choice.bind(interactable), CONNECT_ONE_SHOT)

func _on_toll_choice(choice_index: int, interactable: Interactable) -> void:
	if choice_index != 0 or RunManager.run == null:
		return
	if RunManager.run.currency < interactable.toll_gold_amount:
		hud.show_notification("You don't have %d gold." % interactable.toll_gold_amount)
		return
	RunManager.run.currency -= interactable.toll_gold_amount
	RunManager.save_current_run()
	hud.refresh_stats()
	var target := interactable.exit_target_scene if interactable.exit_target_scene != "" else SceneManager.ENCOUNTER_SCREEN
	SceneManager.goto_scene(target)

## Never buys on the spot: shows a Yes/No confirm first (same
## DialogueChoicePopup every other prompt uses) so browsing a vendor and
## walking away costs nothing.
func _handle_trade(interactable: Interactable) -> void:
	if RunManager.run == null:
		return
	if _try_sell_to_vendor(interactable):
		return
	var item_def := ItemRegistry.get_item(interactable.trade_item_id)
	if item_def == null:
		return
	if dialogue_popup == null:
		push_warning("ExplorationArea: %s is a TRADE interactable but this scene has no DialoguePopup." % interactable.display_name)
		return

	var price := _compute_trade_price(interactable)
	dialogue_popup.show_prompt(
		"%s - %d gold. Buy it?" % [item_def.display_name, price],
		"Buy", "Not now", ""
	)
	dialogue_popup.choice_made.connect(_on_trade_confirmed.bind(interactable, price), CONNECT_ONE_SHOT)

## The Lounge's rank-discount applies the same way regardless of when it's
## read, so the confirm prompt and the actual purchase always show/charge
## the identical number.
func _compute_trade_price(interactable: Interactable) -> int:
	var price := interactable.trade_price
	if interactable.lounge_pricing:
		var rank_def := RunManager.get_guild_rank_def()
		if rank_def != null:
			price = int(round(float(price) * (1.0 - rank_def.tax_discount_percent / 100.0)))
	return price

func _on_trade_confirmed(choice_index: int, interactable: Interactable, price: int) -> void:
	if choice_index != 0 or RunManager.run == null:
		return
	var item_def := ItemRegistry.get_item(interactable.trade_item_id)
	if item_def == null:
		return

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

## Any TRADE-kind vendor doubles as a generic buyer: every droppable,
## non-equipped item in the player's pack is sellable somewhere, for a base
## price (ItemDefinition.sell_price if explicitly set - e.g. a trophy like
## the bear skin - otherwise its plain ItemDefinition.value). A vendor can
## also name specific items it pays a premium for via
## Interactable.sell_bonus_item_ids/sell_bonus_multiplier (e.g. the
## Underground Trader paying extra for curios) - if the player is carrying
## one of those, it's sold first; otherwise whatever's sellable is sold in
## inventory order, same as before. Equipped gear is never touched, so
## interacting with a vendor can never quietly sell your only weapon.
func _try_sell_to_vendor(interactable: Interactable) -> bool:
	var equipped_ids: Array = RunManager.run.equipped.values()
	var fallback_id := ""
	var fallback_def: ItemDefinition = null
	var fallback_price := 0
	for stack in RunManager.run.inventory:
		var item_id: String = stack.get("item_id", "")
		if equipped_ids.has(item_id):
			continue
		var item_def := ItemRegistry.get_item(item_id)
		if item_def == null or not item_def.droppable:
			continue
		var base_price := item_def.sell_price if item_def.sell_price > 0 else item_def.value
		if base_price <= 0:
			continue
		# A vendor's specialty item, if the player has one, always sells first.
		if interactable.sell_bonus_item_ids.has(item_id):
			return _sell_item_to_vendor(interactable, item_id, item_def, base_price)
		if fallback_id == "":
			fallback_id = item_id
			fallback_def = item_def
			fallback_price = base_price
	if fallback_id != "":
		return _sell_item_to_vendor(interactable, fallback_id, fallback_def, fallback_price)
	return false

func _sell_item_to_vendor(interactable: Interactable, item_id: String, item_def: ItemDefinition, base_price: int) -> bool:
	var price := base_price
	if interactable.sell_bonus_item_ids.has(item_id):
		price = int(round(float(base_price) * interactable.sell_bonus_multiplier))
	RunManager.run.remove_item(item_id, 1)
	RunManager.run.currency += price
	RunManager.save_current_run()
	hud.refresh_stats()
	hud.show_notification("Sold %s for %d gold. (%d gold now)" % [item_def.display_name, price, RunManager.run.currency])
	return true

## Shows the yes/no/decline popup for a DIALOGUE interactable. If quest_id is
## set and already active/completed, a status line is shown instead of
## re-running the same pitch. required_guild_rank_order/locked_message (the
## same fields EXIT already uses) let a DIALOGUE quest-giver be rank-gated
## too - blocked before the prompt ever shows, not just before the reward.
func _open_dialogue(interactable: Interactable) -> void:
	if interactable.required_guild_rank_order >= 0:
		var rank_def := RunManager.get_guild_rank_def()
		if rank_def == null or rank_def.order < interactable.required_guild_rank_order:
			hud.show_notification(interactable.locked_message if interactable.locked_message != "" else "You don't have the rank for this yet.")
			return
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

## Guild receptionist: offers enrollment (if not a member) or an upgrade to
## the next rank (if already a member and not at the top). Reuses
## DialogueChoicePopup with a hidden third button since this is a yes/no
## transaction, not a three-way conversation.
func _handle_guild_receptionist(_interactable: Interactable) -> void:
	if RunManager.run == null or dialogue_popup == null:
		return
	var current_rank := RunManager.run.guild_rank
	var next_rank := GuildRegistry.get_next_rank(current_rank)
	if next_rank == null:
		hud.show_notification("\"You're already S-Rank,\" she says. \"That's as high as the guild goes - for now.\"")
		return

	if current_rank == "":
		dialogue_popup.show_prompt(
			"\"Looking to join the Adventurers' Guild? Enrollment is %d gold. It gets you F-Rank and a standing discount on guild tax for every mission you take.\"" % next_rank.upgrade_cost,
			"Enroll (%d gold)" % next_rank.upgrade_cost, "Not right now", ""
		)
		dialogue_popup.choice_made.connect(_on_guild_choice.bind(next_rank, true), CONNECT_ONE_SHOT)
		return

	var required := RunManager.guild_progress_required(next_rank.order)
	if RunManager.run.guild_progress < required:
		hud.show_notification("\"You're %s-Rank right now,\" she says, checking your standing. \"%d/%d - not quite enough to test for %s-Rank yet. Take on some guild missions.\"" % [current_rank, RunManager.run.guild_progress, required, next_rank.id])
		return

	dialogue_popup.show_prompt(
		"\"You're %s-Rank right now. Ready to test for %s-Rank? It'll cost %d gold.\"" % [current_rank, next_rank.id, next_rank.upgrade_cost],
		"Upgrade (%d gold)" % next_rank.upgrade_cost, "Not yet", ""
	)
	dialogue_popup.choice_made.connect(_on_guild_choice.bind(next_rank, false), CONNECT_ONE_SHOT)

func _on_guild_choice(choice_index: int, next_rank: GuildRankDefinition, is_enrolling: bool) -> void:
	if choice_index != 0 or RunManager.run == null:
		return
	if RunManager.run.currency < next_rank.upgrade_cost:
		hud.show_notification("\"Come back when you've got %d gold,\" she says." % next_rank.upgrade_cost)
		return

	RunManager.run.currency -= next_rank.upgrade_cost
	RunManager.run.guild_rank = next_rank.id
	if is_enrolling:
		RunManager.run.add_item("guild_membership_badge", 1)
	else:
		# Carry any overflow standing forward, same as exp does past a level-up.
		RunManager.run.guild_progress -= RunManager.guild_progress_required(next_rank.order)
	RunManager.save_current_run()
	hud.refresh_stats()

	if is_enrolling:
		hud.show_notification("\"Welcome to the guild, %s-Rank!\" She hands you a membership badge. \"%d%% less guild tax on every mission from here on.\"" % [next_rank.id, int(next_rank.tax_discount_percent)])
	else:
		hud.show_notification("\"Congratulations, %s-Rank!\" %s" % [next_rank.id, next_rank.description])

## --- Rushing enemies ---------------------------------------------------------

func _connect_rushing_enemies() -> void:
	for node in get_tree().get_nodes_in_group("rushing_enemies"):
		if node is RushingEnemy:
			node.setup_target(player)
			node.aggroed.connect(_on_rush_aggroed)
			node.rushed.connect(_on_rush_triggered)

func _on_rush_aggroed(enemy: RushingEnemy) -> void:
	if enemy.rush_notification != "":
		hud.show_notification(enemy.rush_notification)

func _on_rush_triggered(enemy: RushingEnemy) -> void:
	var return_scene := enemy.victory_return_scene if enemy.victory_return_scene != "" else get_scene_path()
	start_combat(enemy.enemy_ids, return_scene)

## Every combat trigger should route through here instead of calling
## SceneManager.start_combat() directly, so "return to exactly where you
## were standing" (see _apply_arrival_spawn()) works everywhere without each
## call site needing to remember to record the player's position itself.
func start_combat(enemy_ids: Array[String], return_scene: String = "", advances_encounter: bool = false, ally_ids: Array[String] = []) -> void:
	SceneManager.pending_combat_return_position = player.global_position
	SceneManager.has_pending_combat_return_position = true
	SceneManager.start_combat(enemy_ids, return_scene if return_scene != "" else get_scene_path(), advances_encounter, ally_ids)

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
	hud.refresh_stats() # Using a consumable (or equipping/unequipping) while the panel was open doesn't touch the HUD directly.
