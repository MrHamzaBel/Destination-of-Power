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
@onready var turn_order_row: HBoxContainer = %TurnOrderRow
@onready var log_label: RichTextLabel = %LogLabel
@onready var log_scroll: ScrollContainer = %LogScroll

const TURN_ORDER_LOOKAHEAD: int = 7
const TURN_ORDER_CURRENT_SIZE: int = 52
const TURN_ORDER_FUTURE_SIZE: int = 36

@onready var action_row: HBoxContainer = %ActionRow
@onready var attack_button: Button = %AttackButton
@onready var abilities_button: Button = %AbilitiesButton
@onready var items_button: Button = %ItemsButton
@onready var defend_button: Button = %DefendButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var run_button: Button = %RunButton

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
	run_button.pressed.connect(func(): _combat.player_attempt_flee())
	abilities_close.pressed.connect(func(): abilities_panel.visible = false)
	items_close.pressed.connect(func(): items_panel.visible = false)

	run_button.visible = false
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
	run_button.visible = _combat.player_can_flee()
	_refresh_turn_order()

## Rebuilds the "speed wheel" - the upcoming turn order, current actor first,
## each token shrinking and fading the further out it is so the strip reads
## as "soon -> later" at a glance. Only called on turn_changed (not every
## stats_changed) so it doesn't replay its pop-in animation on every single
## damage tick - once per actual turn is frequent enough to feel alive
## without being distracting.
func _refresh_turn_order() -> void:
	for child in turn_order_row.get_children():
		child.queue_free()
	var upcoming := _combat.get_upcoming_turn_order(TURN_ORDER_LOOKAHEAD)
	for i in range(upcoming.size()):
		var is_current := i == 0
		var token := _build_turn_icon(upcoming[i], is_current)
		turn_order_row.add_child(token)

		var target_alpha := 1.0 if is_current else clampf(1.0 - float(i) * 0.12, 0.35, 1.0)
		token.modulate.a = 0.0
		token.pivot_offset = token.custom_minimum_size / 2.0
		token.scale = Vector2(0.7, 0.7)
		var tween := create_tween()
		tween.tween_interval(i * 0.035)
		tween.set_parallel(true)
		tween.tween_property(token, "modulate:a", target_alpha, 0.25)
		tween.tween_property(token, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## One "speed wheel" token: a colored circular badge (real artwork if the
## unit has a texture, otherwise its initial letter on its team color),
## bigger and gold-bordered for whoever's acting right now.
func _build_turn_icon(unit: CombatUnitState, is_current: bool) -> Control:
	var size := TURN_ORDER_CURRENT_SIZE if is_current else TURN_ORDER_FUTURE_SIZE
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(size, size)
	root.tooltip_text = unit.display_name

	var style := StyleBoxFlat.new()
	style.bg_color = _turn_icon_color(unit)
	style.set_corner_radius_all(size)
	if is_current:
		style.border_color = Color(1.0, 0.9, 0.5, 1)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0, 0, 0, 0.35)
		style.set_border_width_all(1)
	root.add_theme_stylebox_override("panel", style)

	var tex := _turn_icon_texture(unit)
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(rect)
	else:
		var label := Label.new()
		label.text = unit.display_name.substr(0, 1).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22 if is_current else 15)
		label.add_theme_color_override("font_color", Color.WHITE)
		root.add_child(label)

	return root

func _turn_icon_color(unit: CombatUnitState) -> Color:
	if unit.is_player:
		var class_def := RunManager.get_class_def()
		return class_def.portrait_color if class_def != null else Color(0.8, 0.7, 0.3)
	if unit.is_ally:
		return unit.ally_def.body_color if unit.ally_def != null else Color(0.3, 0.45, 0.7)
	return unit.enemy_def.body_color if unit.enemy_def != null else Color(0.6, 0.2, 0.2)

func _turn_icon_texture(unit: CombatUnitState) -> Texture2D:
	if unit.is_ally:
		return unit.ally_def.texture if unit.ally_def != null else null
	if not unit.is_player:
		return unit.enemy_def.texture if unit.enemy_def != null else null
	return null

func _set_actions_enabled(enabled: bool) -> void:
	for button in [attack_button, abilities_button, items_button, defend_button, end_turn_button, run_button]:
		button.disabled = not enabled

## Card-based skill list, one self-contained clickable panel per ability -
## color-coded left accent + cost badge by AbilityDefinition.AbilityType, so
## any new ability/spell a class picks up later slots into the same visual
## language automatically instead of needing per-ability styling.
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
		abilities_list.add_child(_build_ability_card(ability))
	abilities_panel.visible = true

func _build_ability_card(ability: AbilityDefinition) -> Control:
	var affordable := ability.resource_cost <= _combat.player_unit.current_resource
	var accent := _ability_type_color(ability.ability_type)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.15, 0.2, 1) if affordable else Color(0.13, 0.12, 0.14, 1)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = accent if affordable else Color(0.32, 0.3, 0.34, 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if affordable else Control.CURSOR_FORBIDDEN
	card.tooltip_text = ability.description

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(6, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = accent if affordable else Color(0.4, 0.38, 0.42, 1)
	icon_style.set_corner_radius_all(3)
	icon.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	var name_label := Label.new()
	name_label.text = ability.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 17)
	if not affordable:
		name_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.56, 1))
	title_row.add_child(name_label)

	var cost_badge := Label.new()
	cost_badge.text = "%d %s" % [ability.resource_cost, _combat.resource_name()]
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_theme_font_size_override("font_size", 13)
	cost_badge.add_theme_color_override("font_color", accent if affordable else Color(0.55, 0.52, 0.56, 1))
	title_row.add_child(cost_badge)

	var desc := Label.new()
	desc.text = ability.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.68, 0.78, 1) if affordable else Color(0.5, 0.48, 0.52, 1))
	vbox.add_child(desc)

	if affordable:
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_combat.player_use_ability(ability.id)
				abilities_panel.visible = false
		)
	return card

func _ability_type_color(ability_type: AbilityDefinition.AbilityType) -> Color:
	match ability_type:
		AbilityDefinition.AbilityType.ATTACK:
			return Color(0.85, 0.4, 0.32, 1)
		AbilityDefinition.AbilityType.HEAL:
			return Color(0.4, 0.8, 0.45, 1)
		AbilityDefinition.AbilityType.BUFF:
			return Color(0.4, 0.62, 0.95, 1)
		AbilityDefinition.AbilityType.DEFEND:
			return Color(0.75, 0.68, 0.35, 1)
		AbilityDefinition.AbilityType.UTILITY:
			return Color(0.72, 0.42, 0.88, 1)
	return Color(0.6, 0.6, 0.62, 1)

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
	run_button.visible = false
	result_panel.visible = true
	var fled := bool(_combat.last_rewards.get("player_fled", false))

	if fled:
		result_title.text = "Got Away!"
		result_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35, 1))
		result_summary.text = "Faster than every foe there, you slip away from the fight before it can finish."
		result_button.text = "Continue"
		for connection in result_button.pressed.get_connections():
			result_button.pressed.disconnect(connection["callable"])
		result_button.pressed.connect(func(): _on_result_confirmed(victory, true))
		return

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

func _on_result_confirmed(victory: bool, fled: bool = false) -> void:
	if victory:
		if not fled and SceneManager.advances_encounter_on_victory and RunManager.run != null:
			RunManager.run.current_encounter_index += 1
			RunManager.save_current_run()
		SceneManager.goto_scene(SceneManager.return_scene_after_combat)
	else:
		RunManager.end_run(false, _combat.last_death_info)
		SceneManager.goto_scene(SceneManager.RUN_SUMMARY)
