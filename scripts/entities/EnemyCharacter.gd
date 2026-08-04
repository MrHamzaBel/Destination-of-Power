class_name EnemyCharacter
extends Node2D
## Placeholder visual for a combatant that isn't the player: a colored
## polygon plus a name label. Used both as a standing encounter marker in
## exploration scenes and as the enemy/ally combatant visual in CombatScene.

@onready var polygon: Polygon2D = %Polygon
@onready var name_label: Label = %NameLabel

var enemy_def: EnemyDefinition
var ally_def: AllyDefinition

func setup(def: EnemyDefinition) -> void:
	enemy_def = def
	if def == null:
		return
	_apply_visual(def.shape_points, def.body_color, def.display_name)

func setup_ally(def: AllyDefinition) -> void:
	ally_def = def
	if def == null:
		return
	_apply_visual(def.shape_points, def.body_color, def.display_name)

func _apply_visual(shape_points: PackedVector2Array, color: Color, display_name: String) -> void:
	if shape_points.size() >= 3:
		polygon.polygon = shape_points
	polygon.color = color
	name_label.text = display_name
