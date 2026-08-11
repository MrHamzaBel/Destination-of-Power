extends Node2D
## Combat scene controller: builds the player/ally/enemy visuals from data,
## starts the CombatManager with the combatants queued by SceneManager, and
## binds the CombatHUD to it.

const ENEMY_VISUAL_SCENE: PackedScene = preload("res://scenes/entities/EnemyCharacter.tscn")

@onready var combat_manager: CombatManager = %CombatManager
@onready var hud: CombatHUD = %CombatHUD
@onready var player_appearance_root: Node2D = %PlayerAppearanceRoot
@onready var ally_container: Node2D = %AllyContainer
@onready var enemy_container: Node2D = %EnemyContainer

func _ready() -> void:
	if RunManager.run == null:
		SceneManager.goto_scene(SceneManager.MAIN_MENU)
		return

	var appearance := CharacterAppearanceRenderer.new()
	player_appearance_root.add_child(appearance)
	appearance.apply_profile(RunManager.character_profile)

	hud.bind(combat_manager)
	combat_manager.roster_changed.connect(_spawn_enemy_visuals)
	combat_manager.enemy_visual_defeated.connect(_on_enemy_visual_defeated)

	combat_manager.start(SceneManager.pending_combat_enemy_ids, SceneManager.pending_combat_ally_ids)
	_spawn_enemy_visuals()
	_spawn_ally_visuals()

func _spawn_enemy_visuals() -> void:
	for child in enemy_container.get_children():
		child.queue_free()
	var i := 0
	for enemy in combat_manager.enemy_units:
		var visual := ENEMY_VISUAL_SCENE.instantiate() as EnemyCharacter
		enemy_container.add_child(visual)
		visual.position = Vector2(i * 100, 0)
		visual.setup(enemy.enemy_def)
		if not enemy.is_alive():
			visual.mark_defeated()
		i += 1

## enemy_units keeps a stable index order all combat long (dead units stay in
## the array, just with current_health == 0 - see get_alive_enemies()), and
## _spawn_enemy_visuals() builds enemy_container's children in that same
## order, so the two stay 1:1 lined up outside of a roster_changed rebuild
## (which already reapplies mark_defeated() to anyone already dead above).
func _on_enemy_visual_defeated(enemy: CombatUnitState) -> void:
	var index := combat_manager.enemy_units.find(enemy)
	if index < 0 or index >= enemy_container.get_child_count():
		return
	var visual := enemy_container.get_child(index) as EnemyCharacter
	if visual != null:
		visual.mark_defeated()

func _spawn_ally_visuals() -> void:
	for child in ally_container.get_children():
		child.queue_free()
	var i := 0
	for ally in combat_manager.ally_units:
		var visual := ENEMY_VISUAL_SCENE.instantiate() as EnemyCharacter
		ally_container.add_child(visual)
		visual.position = Vector2(i * 90, 0)
		visual.setup_ally(ally.ally_def)
		i += 1
