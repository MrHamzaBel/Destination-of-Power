class_name InventoryScreen
extends Control
## Full inventory/equipment manager. Reusable overlay opened from exploration
## (pause menu / hotkey). Combat has its own lightweight consumable popup.

signal closed

const CAPACITY: int = 20 ## Raise this (or make it a run-tracked value) to expand storage later.
const EQUIP_SLOTS: Array[String] = ["weapon", "offhand", "armor"]

@onready var item_list: VBoxContainer = %ItemList
@onready var equipped_list: VBoxContainer = %EquippedList
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_rarity: Label = %DetailRarity
@onready var detail_compare: Label = %DetailCompare
@onready var equip_button: Button = %EquipButton
@onready var use_button: Button = %UseButton
@onready var drop_button: Button = %DropButton
@onready var close_button: Button = %CloseButton
@onready var capacity_label: Label = %CapacityLabel

var _selected_item_id: String = ""

func _ready() -> void:
	close_button.pressed.connect(func(): closed.emit())
	equip_button.pressed.connect(_on_equip_pressed)
	use_button.pressed.connect(_on_use_pressed)
	drop_button.pressed.connect(_on_drop_pressed)
	refresh()

func refresh() -> void:
	_populate_equipped()
	_populate_inventory()
	_select_item("")

func _populate_equipped() -> void:
	for child in equipped_list.get_children():
		child.queue_free()
	if RunManager.run == null:
		return
	for slot in EQUIP_SLOTS:
		var item_id: String = RunManager.run.equipped.get(slot, "")
		var item_def := ItemRegistry.get_item(item_id) if item_id != "" else null
		var btn := Button.new()
		btn.text = "%s: %s" % [slot.capitalize(), (item_def.display_name if item_def != null else "(empty)")]
		btn.focus_mode = Control.FOCUS_ALL
		btn.disabled = item_def == null
		if item_def != null:
			btn.pressed.connect(_select_item.bind(item_id))
		equipped_list.add_child(btn)

func _populate_inventory() -> void:
	for child in item_list.get_children():
		child.queue_free()
	if RunManager.run == null:
		capacity_label.text = "0 / %d" % CAPACITY
		return
	var used := 0
	for stack in RunManager.run.inventory:
		var quantity: int = int(stack.get("quantity", 0))
		used += quantity
		var item_def := ItemRegistry.get_item(stack.get("item_id", ""))
		if item_def == null:
			continue
		item_list.add_child(_build_item_row(item_def, quantity))
	capacity_label.text = "%d / %d" % [used, CAPACITY]

func _build_item_row(item_def: ItemDefinition, quantity: int) -> Button:
	var btn := Button.new()
	btn.text = "%s%s" % [item_def.display_name, (" x%d" % quantity if quantity > 1 else "")]
	btn.focus_mode = Control.FOCUS_ALL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", ItemDefinition.rarity_color(item_def.rarity))
	btn.pressed.connect(_select_item.bind(item_def.id))
	return btn

func _select_item(item_id: String) -> void:
	_selected_item_id = item_id
	if item_id == "" or ItemRegistry.get_item(item_id) == null:
		detail_name.text = "Select an item"
		detail_desc.text = ""
		detail_rarity.text = ""
		detail_compare.text = ""
		equip_button.disabled = true
		use_button.disabled = true
		drop_button.disabled = true
		return

	var item_def := ItemRegistry.get_item(item_id)
	detail_name.text = item_def.display_name
	detail_desc.text = item_def.description
	detail_rarity.text = "Rarity: %s" % ItemDefinition.rarity_name(item_def.rarity)
	detail_rarity.add_theme_color_override("font_color", ItemDefinition.rarity_color(item_def.rarity))

	var is_equipped: bool = RunManager.run.equipped.values().has(item_id)
	equip_button.text = "Unequip" if is_equipped else "Equip"
	equip_button.disabled = item_def.equip_slot == ""
	use_button.disabled = item_def.category != ItemDefinition.Category.CONSUMABLE
	drop_button.disabled = not item_def.droppable

	if item_def.equip_slot != "" and not is_equipped:
		var current_id: String = RunManager.run.equipped.get(item_def.equip_slot, "")
		var current_def := ItemRegistry.get_item(current_id) if current_id != "" else null
		detail_compare.text = _build_comparison(current_def, item_def)
	elif item_def.stat_modifiers != null:
		detail_compare.text = _stat_summary(item_def.stat_modifiers)
	else:
		detail_compare.text = ""

func _stat_summary(stats: StatBlock) -> String:
	if stats == null:
		return ""
	var parts: Array[String] = []
	if stats.attack != 0: parts.append("Attack %+d" % stats.attack)
	if stats.intelligence != 0: parts.append("Intelligence %+d" % stats.intelligence)
	if stats.defense != 0: parts.append("Defense %+d" % stats.defense)
	if stats.speed != 0: parts.append("Speed %+d" % stats.speed)
	if stats.max_health != 0: parts.append("Health %+d" % stats.max_health)
	if stats.max_resource != 0: parts.append("Resource %+d" % stats.max_resource)
	return ", ".join(parts)

func _build_comparison(current_def: ItemDefinition, candidate_def: ItemDefinition) -> String:
	var current_stats := current_def.stat_modifiers if current_def != null and current_def.stat_modifiers != null else StatBlock.new()
	var new_stats := candidate_def.stat_modifiers if candidate_def.stat_modifiers != null else StatBlock.new()
	var lines: Array[String] = ["Compared to %s:" % (current_def.display_name if current_def != null else "nothing equipped")]
	lines.append_array(_diff_lines(current_stats, new_stats))
	if lines.size() == 1:
		lines.append("No stat difference.")
	return "\n".join(lines)

func _diff_lines(current_stats: StatBlock, new_stats: StatBlock) -> Array[String]:
	var lines: Array[String] = []
	var pairs := {
		"Attack": [current_stats.attack, new_stats.attack],
		"Intelligence": [current_stats.intelligence, new_stats.intelligence],
		"Defense": [current_stats.defense, new_stats.defense],
		"Speed": [current_stats.speed, new_stats.speed],
	}
	for label in pairs.keys():
		var old_v: int = pairs[label][0]
		var new_v: int = pairs[label][1]
		var delta := new_v - old_v
		if delta != 0:
			lines.append("%s: %s%d" % [label, "+" if delta > 0 else "", delta])
	return lines

func _on_equip_pressed() -> void:
	if _selected_item_id == "":
		return
	var item_def := ItemRegistry.get_item(_selected_item_id)
	if item_def == null or item_def.equip_slot == "":
		return
	var is_equipped: bool = RunManager.run.equipped.get(item_def.equip_slot, "") == _selected_item_id
	if is_equipped:
		RunManager.run.equipped.erase(item_def.equip_slot)
	else:
		RunManager.run.equipped[item_def.equip_slot] = _selected_item_id
	EventBus.equipment_changed.emit()
	RunManager.save_current_run()
	refresh()
	_select_item(_selected_item_id)

func _on_use_pressed() -> void:
	if _selected_item_id == "":
		return
	var item_def := ItemRegistry.get_item(_selected_item_id)
	if item_def == null or item_def.category != ItemDefinition.Category.CONSUMABLE:
		return
	var stats := RunManager.compute_current_stats()
	RunManager.run.current_health = min(stats.max_health, RunManager.run.current_health + item_def.heal_amount)
	RunManager.run.current_resource = min(stats.max_resource, RunManager.run.current_resource + item_def.resource_amount)
	RunManager.run.remove_item(_selected_item_id, 1)
	EventBus.item_used.emit({"item_id": _selected_item_id, "combat": null})
	EventBus.inventory_changed.emit()
	RunManager.save_current_run()
	refresh()

func _on_drop_pressed() -> void:
	if _selected_item_id == "":
		return
	var item_def := ItemRegistry.get_item(_selected_item_id)
	if item_def == null or not item_def.droppable:
		return
	if item_def.equip_slot != "" and RunManager.run.equipped.get(item_def.equip_slot, "") == _selected_item_id:
		RunManager.run.equipped.erase(item_def.equip_slot)
	RunManager.run.remove_item(_selected_item_id, 1)
	EventBus.inventory_changed.emit()
	RunManager.save_current_run()
	refresh()
