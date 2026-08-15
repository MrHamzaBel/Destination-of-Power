class_name TraderScreen
extends Control
## Full trading interface, opened from any TRADE interactable - replaces the
## old flow where interacting silently sold the first sellable item in the
## player's pack (no visibility into what was being sold, no way to choose)
## before ever offering to buy anything. Two tabs: Buy (the vendor's own
## stock item, if any) and Sell (every sellable item in the player's pack,
## shown individually with its price, plus a Sell All button).
##
## Instantiated once at runtime per exploration scene by ExplorationArea
## itself (see ExplorationArea._ready()) rather than added to every scene's
## .tscn - one shared trader UI, reused by every vendor in the game.

signal closed

@onready var vendor_name_label: Label = %VendorNameLabel
@onready var gold_label: Label = %GoldLabel
@onready var close_button: Button = %CloseButton

@onready var buy_item_name: Label = %BuyItemName
@onready var buy_item_desc: Label = %BuyItemDesc
@onready var buy_item_price: Label = %BuyItemPrice
@onready var buy_empty_label: Label = %BuyEmptyLabel
@onready var buy_button: Button = %BuyButton

@onready var sell_list: VBoxContainer = %SellList
@onready var sell_all_button: Button = %SellAllButton
@onready var sell_empty_label: Label = %SellEmptyLabel

var _area: ExplorationArea
var _interactable: Interactable

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	visible = false

func open(area: ExplorationArea, interactable: Interactable) -> void:
	_area = area
	_interactable = interactable
	vendor_name_label.text = interactable.display_name
	_refresh()
	visible = true

func _on_close_pressed() -> void:
	closed.emit()

func _refresh() -> void:
	if RunManager.run != null:
		gold_label.text = "%d gold" % RunManager.run.currency
	_refresh_buy()
	_refresh_sell()

# --- Buy tab ------------------------------------------------------------------

func _refresh_buy() -> void:
	var item_def := ItemRegistry.get_item(_interactable.trade_item_id)
	if RunManager.run == null or item_def == null:
		_show_buy_empty("Nothing for sale here.")
		return
	if _interactable.purchase_flag_id != "" and bool(RunManager.run.story_flags.get(_interactable.purchase_flag_id, false)):
		_show_buy_empty("\"Already sold, I'm afraid - that one was one of a kind.\"")
		return

	buy_empty_label.visible = false
	buy_item_name.visible = true
	buy_item_desc.visible = true
	buy_item_price.visible = true
	buy_button.visible = true

	buy_item_name.text = item_def.display_name
	buy_item_name.add_theme_color_override("font_color", ItemDefinition.rarity_color(item_def.rarity))
	buy_item_desc.text = item_def.description
	var price := _area.compute_trade_price(_interactable)
	buy_item_price.text = "%d gold" % price
	buy_button.disabled = RunManager.run.currency < price
	buy_button.text = "Buy" if RunManager.run.currency >= price else "Not enough gold"

func _show_buy_empty(message: String) -> void:
	buy_empty_label.visible = true
	buy_empty_label.text = message
	buy_item_name.visible = false
	buy_item_desc.visible = false
	buy_item_price.visible = false
	buy_button.visible = false

func _on_buy_pressed() -> void:
	if RunManager.run == null:
		return
	var item_def := ItemRegistry.get_item(_interactable.trade_item_id)
	if item_def == null:
		return
	var price := _area.compute_trade_price(_interactable)
	if RunManager.run.currency < price:
		return
	RunManager.run.currency -= price
	RunManager.run.add_item(_interactable.trade_item_id, 1)
	if _interactable.purchase_flag_id != "":
		RunManager.run.story_flags[_interactable.purchase_flag_id] = true
	RunManager.save_current_run()
	_area.hud.refresh_stats()
	var notice := "Bought %s for %d gold. (%d gold left)" % [item_def.display_name, price, RunManager.run.currency]
	if _interactable.trade_flavor_text != "":
		notice += " " + _interactable.trade_flavor_text
	_area.hud.show_notification(notice)
	_refresh()

# --- Sell tab -----------------------------------------------------------------

## Sell price for one unit of item_id at the currently open vendor - the
## vendor's named specialty (Interactable.sell_bonus_item_ids/multiplier)
## always wins over the item's plain base price.
func _sell_price_for(item_id: String, item_def: ItemDefinition) -> int:
	var base_price := item_def.sell_price if item_def.sell_price > 0 else item_def.value
	if _interactable.sell_bonus_item_ids.has(item_id):
		return int(round(float(base_price) * _interactable.sell_bonus_multiplier))
	return base_price

func _refresh_sell() -> void:
	for child in sell_list.get_children():
		child.queue_free()
	if RunManager.run == null:
		return
	var equipped_ids: Array = RunManager.run.equipped.values()
	var any_sellable := false
	for stack in RunManager.run.inventory:
		var item_id: String = stack.get("item_id", "")
		if equipped_ids.has(item_id):
			continue
		var item_def := ItemRegistry.get_item(item_id)
		if item_def == null or not item_def.droppable:
			continue
		var price := _sell_price_for(item_id, item_def)
		if price <= 0:
			continue
		any_sellable = true
		var quantity: int = int(stack.get("quantity", 0))
		sell_list.add_child(_build_sell_row(item_def, item_id, quantity, price))
	sell_empty_label.visible = not any_sellable
	sell_all_button.disabled = not any_sellable

func _build_sell_row(item_def: ItemDefinition, item_id: String, quantity: int, price: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = "%s%s" % [item_def.display_name, (" x%d" % quantity if quantity > 1 else "")]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", ItemDefinition.rarity_color(item_def.rarity))
	row.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%d gold each" % price
	price_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(price_label)

	var btn := Button.new()
	btn.text = "Sell"
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(_on_sell_one.bind(item_id, item_def, price))
	row.add_child(btn)

	return row

func _on_sell_one(item_id: String, item_def: ItemDefinition, price: int) -> void:
	if RunManager.run == null or not RunManager.run.remove_item(item_id, 1):
		return
	RunManager.run.currency += price
	RunManager.save_current_run()
	_area.hud.refresh_stats()
	_area.hud.show_notification("Sold %s for %d gold. (%d gold now)" % [item_def.display_name, price, RunManager.run.currency])
	_refresh()

func _on_sell_all_pressed() -> void:
	if RunManager.run == null:
		return
	var equipped_ids: Array = RunManager.run.equipped.values()
	var total_gold := 0
	var total_items := 0
	for stack in RunManager.run.inventory.duplicate():
		var item_id: String = stack.get("item_id", "")
		if equipped_ids.has(item_id):
			continue
		var item_def := ItemRegistry.get_item(item_id)
		if item_def == null or not item_def.droppable:
			continue
		var price := _sell_price_for(item_id, item_def)
		if price <= 0:
			continue
		var quantity: int = int(stack.get("quantity", 0))
		total_gold += price * quantity
		total_items += quantity
		RunManager.run.remove_item(item_id, quantity)
	if total_items == 0:
		return
	RunManager.run.currency += total_gold
	RunManager.save_current_run()
	_area.hud.refresh_stats()
	_area.hud.show_notification("Sold %d item%s for %d gold total. (%d gold now)" % [total_items, "" if total_items == 1 else "s", total_gold, RunManager.run.currency])
	_refresh()
