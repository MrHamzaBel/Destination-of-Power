class_name CombatHUD
extends Control
## Combat interface: stat bars, turn indicator, log, action buttons and the
## victory/defeat result overlay. Talks only to the CombatManager it is bound
## to - it has no gameplay logic of its own.

@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var player_health_value_label: Label = %PlayerHealthValueLabel
@onready var player_resource_bar: ProgressBar = %PlayerResourceBar
@onready var player_resource_value_label: Label = %PlayerResourceValueLabel
@onready var player_resource_label: Label = %PlayerResourceLabel
@onready var enemy_target_list: VBoxContainer = %EnemyTargetList
@onready var ally_list: VBoxContainer = %AllyList
@onready var ally_panel: PanelContainer = %AllyPanel
@onready var turn_label: Label = %TurnLabel
@onready var log_label: RichTextLabel = %LogLabel
@onready var log_scroll: ScrollContainer = %LogScroll

@onready var action_row: HBoxContainer = %ActionRow
@onready var attack_button: Button = %AttackButton
@onready var abilities_button: Button = %AbilitiesButton
@onready var items_button: Button = %ItemsButton
@onready var defend_button: Button = %DefendButton
@onready var end_turn_button: Button = %EndTurnButton

@onready var abilities_panel: PanelContainer = %AbilitiesPanel
@onready var abilities_list: VBoxContainer = %AbilitiesList
@onready var abilities_close: Button = %AbilitiesClose

@onready var items_panel: PanelContainer = %ItemsPanel
@onready var items_list: VBoxContainer = %ItemsList
@onready var items_close: Button = %ItemsClose

@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_summary: Label = %ResultSummary
@onready var result_button: Button = %ResultButton

var _combat: CombatManager

func bind(combat: CombatManager) -> void:
	_combat = combat
	_combat.log_message.connect(_on_log_message)
	_combat.stats_changed.connect(_refresh_bars)
	_combat.turn_changed.connect(_on_turn_changed)
	_combat.combat_finished.connect(_on_combat_finished)

	attack_button.pressed.connect(func(): _combat.player_basic_attack())
	abilities_button.pressed.connect(_open_abilities)
	items_button.pressed.connect(_open_items)
	defend_button.pressed.connect(func(): _combat.player_defend())
	end_turn_button.pressed.connect(func(): _combat.end_turn())
	abilities_close.pressed.connect(func(): abilities_panel.visible = false)
	items_close.pressed.connect(func(): items_panel.visible = false)

	result_panel.visible = false
	abilities_panel.visible = false
	items_panel.visible = false
	_refresh_bars()

func _refresh_bars() -> void:
	if _combat == null or _combat.player_unit == null:
		return
	player_health_bar.max_value = max(1, _combat.player_unit.max_health)
	player_health_bar.value = _combat.player_unit.current_health
	player_health_value_label.text = "%d/%d" % [_combat.player_unit.current_health, _combat.player_unit.max_health]
	player_resource_bar.max_value = max(1, _combat.player_unit.max_resource)
	player_resource_bar.value = _combat.player_unit.current_resource
	player_resource_value_label.text = "%d/%d" % [_combat.player_unit.current_resource, _combat.player_unit.max_resource]
	player_resource_label.text = _combat.resource_name()

	_refresh_enemy_target_list()
	_refresh_ally_list()

## Rebuilds the clickable enemy list used to pick a target. The currently
## targeted enemy (CombatManager.get_current_target()) is highlighted; with
## only one enemy alive this still shows (as a single, already-selected row).
func _refresh_enemy_target_list() -> void:
	for child in enemy_target_list.get_children():
		child.queue_free()
	var current_target := _combat.get_current_target()
	for enemy in _combat.get_alive_enemies():
		var is_selected := enemy == current_target
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.focus_mode = Control.FOCUS_ALL
		btn.toggle_mode = true
		btn.button_pressed = is_selected
		btn.text = "%s%s   %d/%d HP" % ["> " if is_selected else "", enemy.display_name, enemy.current_health, enemy.max_health]
		btn.tooltip_text = "Target this enemy."
		btn.pressed.connect(func():
			_combat.set_target(enemy)
			_refresh_enemy_target_list()
		)
		enemy_target_list.add_child(btn)

func _refresh_ally_list() -> void:
	var allies := _combat.ally_units
	ally_panel.visible = not allies.is_empty()
	for child in ally_list.get_children():
		child.queue_free()
	for ally in allies:
		var label := Label.new()
		var status := "" if ally.is_alive() else " (down)"
		label.text = "%s   %d/%d HP%s" % [ally.display_name, ally.current_health, ally.max_health, status]
		if not ally.is_alive():
			label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.55, 1))
		ally_list.add_child(label)

func _on_log_message(text: String) -> void:
	log_label.append_text(text + "\n")
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

func _on_turn_changed(unit: CombatUnitState) -> void:
	_refresh_bars()
	var burst := ""
	var progress := _combat.get_current_block_progress()
	if progress.y > 1:
		burst = " (%d/%d)" % [progress.x, progress.y]
	if unit.is_player:
		turn_label.text = "Your Turn%s" % burst
		_set_actions_enabled(true)
	else:
		turn_label.text = "%s is acting...%s" % [unit.display_name, burst]
		_set_actions_enabled(false)

func _set_actions_enabled(enabled: bool) -> void:
	for button in [attack_button, abilities_button, items_button, defend_button, end_turn_button]:
		button.disabled = not enabled

func _open_abilities() -> void:
	for child in abilities_list.get_children():
		child.queue_free()
	var class_def := RunManager.get_class_def()
	if class_def == null:
		return
	for ability_id in class_def.abilities:
		var ability := AbilityRegistry.get_ability(ability_id)
		if ability == null:
			continue
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.text = "%s (%d %s)" % [ability.display_name, ability.resource_cost, _combat.resource_name()]
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = ability.resource_cost > _combat.player_unit.current_resource
		btn.tooltip_text = ability.description
		btn.pressed.connect(func():
			_combat.player_use_ability(ability.id)
			abilities_panel.visible = false
		)
		row.add_child(btn)
		var desc := Label.new()
		desc.text = ability.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(260, 0)
		desc.add_theme_color_override("font_color", Color(0.7, 0.68, 0.78, 1))
		abilities_list.add_child(row)
		abilities_list.add_child(desc)
	abilities_panel.visible = true

func _open_items() -> void:
	for child in items_list.get_children():
		child.queue_free()
	if RunManager.run == null:
		return
	var any_consumable := false
	for stack in RunManager.run.inventory:
		var item_def := ItemRegistry.get_item(stack.get("item_id", ""))
		if item_def == null or item_def.category != ItemDefinition.Category.CONSUMABLE:
			continue
		any_consumable = true
		var quantity: int = int(stack.get("quantity", 0))
		var btn := Button.new()
		btn.text = "%s x%d - %s" % [item_def.display_name, quantity, item_def.description]
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(func():
			_combat.player_use_item(item_def.id)
			items_panel.visible = false
		)
		items_list.add_child(btn)
	if not any_consumable:
		var label := Label.new()
		label.text = "No usable items."
		items_list.add_child(label)
	items_panel.visible = true

func _on_combat_finished(victory: bool) -> void:
	_set_actions_enabled(false)
	result_panel.visible = true
	result_title.text = "Victory!" if victory else "Defeated..."
	result_title.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1) if victory else Color(0.85, 0.3, 0.3, 1))

	if victory:
		var lines: Array[String] = ["You won the fight."]
		var fled_enemies: Array = _combat.last_rewards.get("fled_enemies", [])
		for enemy_name in fled_enemies:
			lines.append("%s got away." % enemy_name)
		var gold_stolen := int(_combat.last_rewards.get("gold_stolen", 0))
		if gold_stolen > 0:
			lines.append("They made off with %d gold." % gold_stolen)
		var exp_gained := int(_combat.last_rewards.get("exp_gained", 0))
		if exp_gained > 0:
			lines.append("Experience gained: %d" % exp_gained)
		var levels_gained: Array = _combat.last_rewards.get("levels_gained", [])
		for lvl in levels_gained:
			lines.append("Level up! You reached level %d (+%d stat points)." % [lvl, RunManager.STAT_POINTS_PER_LEVEL])
		var items: Array = _combat.last_rewards.get("items", [])
		for item_id in items:
			var item_def := ItemRegistry.get_item(item_id)
			if item_def != null:
				lines.append("Found: %s" % item_def.display_name)
		var artifact_id: String = _combat.last_rewards.get("artifact", "")
		if artifact_id != "":
			var artifact_def := ArtifactRegistry.get_artifact(artifact_id)
			if artifact_def != null:
				lines.append("Artifact acquired: %s - %s" % [artifact_def.display_name, artifact_def.description])
		result_summary.text = "\n".join(lines)
		result_button.text = "Continue"
	else:
		result_summary.text = "Your run has come to an end."
		result_button.text = "View Run Summary"

	for connection in result_button.pressed.get_connections():
		result_button.pressed.disconnect(connection["callable"])
	result_button.pressed.connect(func(): _on_result_confirmed(victory))

func _on_result_confirmed(victory: bool) -> void:
	if victory:
		if SceneManager.advances_encounter_on_victory and RunManager.run != null:
			RunManager.run.current_encounter_index += 1
			RunManager.save_current_run()
		SceneManager.goto_scene(SceneManager.return_scene_after_combat)
	else:
		RunManager.end_run(false)
		SceneManager.goto_scene(SceneManager.RUN_SUMMARY)
