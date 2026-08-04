extends Control
## Hub screen for the run's randomized encounter sequence. Resolves treasure,
## empty, event and healing encounters inline; hands combat encounters off to
## CombatScene and returns here afterwards to advance the sequence.

@onready var status_label: Label = %StatusLabel
@onready var progress_label: Label = %ProgressLabel
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var reward_label: Label = %RewardLabel
@onready var continue_button: Button = %ContinueButton
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var inventory_screen: InventoryScreen = %InventoryScreen
@onready var inventory_button: Button = %InventoryButton

func _ready() -> void:
	if RunManager.run == null:
		SceneManager.goto_scene(SceneManager.MAIN_MENU)
		return
	RunManager.run.current_scene_path = SceneManager.ENCOUNTER_SCREEN
	RunManager.save_current_run()
	continue_button.pressed.connect(_on_continue_pressed)
	inventory_button.pressed.connect(_open_inventory)

	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_screen.visible = false
	pause_menu.inventory_requested.connect(_open_inventory)
	inventory_screen.closed.connect(_close_inventory)

	_load_encounter()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if inventory_screen.visible:
			_close_inventory()
		else:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()

func _open_inventory() -> void:
	pause_menu.close()
	inventory_screen.refresh()
	inventory_screen.visible = true
	get_tree().paused = true

func _close_inventory() -> void:
	inventory_screen.visible = false
	get_tree().paused = false

func _load_encounter() -> void:
	var run := RunManager.run
	if run == null:
		return
	if run.current_encounter_index >= run.encounter_sequence.size():
		RunManager.end_run(true)
		SceneManager.goto_scene(SceneManager.RUN_SUMMARY)
		return

	_refresh_status()
	var kind_name: String = run.encounter_sequence[run.current_encounter_index]
	progress_label.text = "Encounter %d / %d" % [run.current_encounter_index + 1, run.encounter_sequence.size()]

	var entry := EncounterRegistry.get_entry_by_name(kind_name)
	title_label.text = entry.display_name if entry != null else kind_name
	description_label.text = entry.flavor_text if entry != null else ""
	reward_label.text = ""
	continue_button.text = "Continue"

	match kind_name:
		"COMBAT":
			continue_button.text = "Face the Enemy"
		"TREASURE":
			_resolve_treasure()
		"EVENT":
			_resolve_event()
		"HEALING":
			_resolve_healing()
		_:
			pass # EMPTY needs no resolution.

func _resolve_treasure() -> void:
	var rng := _make_rng()
	var currency := rng.randi_range(5, 15)
	RunManager.run.currency += currency
	var lines: Array[String] = ["You find %d gold." % currency]
	if rng.randf() < 0.5:
		var candidates: Array = ItemRegistry.get_all()
		if not candidates.is_empty():
			var item: ItemDefinition = candidates[rng.randi_range(0, candidates.size() - 1)]
			RunManager.run.add_item(item.id, 1)
			lines.append("You also find: %s" % item.display_name)
	reward_label.text = "\n".join(lines)
	RunManager.save_current_run()
	_refresh_status()

func _resolve_event() -> void:
	var rng := _make_rng()
	var roll := rng.randf()
	var stats := RunManager.compute_current_stats()
	if roll < 0.4:
		var amount := rng.randi_range(3, 8)
		RunManager.run.current_health = min(stats.max_health, RunManager.run.current_health + amount)
		reward_label.text = "A strange calm washes over you. You recover %d health." % amount
	elif roll < 0.7:
		var amount := rng.randi_range(3, 10)
		RunManager.run.currency += amount
		reward_label.text = "You find a dropped coin purse worth %d gold." % amount
	else:
		var amount: int = max(0, min(RunManager.run.current_health - 1, rng.randi_range(2, 6)))
		RunManager.run.current_health -= amount
		reward_label.text = "A stray hazard catches you off guard. You lose %d health." % amount
	RunManager.save_current_run()
	_refresh_status()

func _resolve_healing() -> void:
	var stats := RunManager.compute_current_stats()
	RunManager.run.current_health = stats.max_health
	RunManager.run.current_resource = stats.max_resource
	var class_def := RunManager.get_class_def()
	reward_label.text = "You rest safely. Health and %s fully restored." % (class_def.resource_label if class_def != null else "resource")
	RunManager.save_current_run()
	_refresh_status()

func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunManager.run.run_seed + RunManager.run.current_encounter_index
	return rng

func _refresh_status() -> void:
	if RunManager.run == null:
		return
	var stats := RunManager.compute_current_stats()
	var class_def := RunManager.get_class_def()
	status_label.text = "Health: %d/%d   %s: %d/%d   Gold: %d" % [
		RunManager.run.current_health, stats.max_health,
		(class_def.resource_label if class_def != null else "Resource"), RunManager.run.current_resource, stats.max_resource,
		RunManager.run.currency
	]

func _on_continue_pressed() -> void:
	var run := RunManager.run
	if run == null:
		return
	var kind_name: String = run.encounter_sequence[run.current_encounter_index]
	if kind_name == "COMBAT":
		var rng := _make_rng()
		var enemy_id := EnemyRegistry.get_random_id(rng)
		SceneManager.start_combat([enemy_id], SceneManager.ENCOUNTER_SCREEN, true)
	else:
		run.current_encounter_index += 1
		RunManager.save_current_run()
		_load_encounter()
