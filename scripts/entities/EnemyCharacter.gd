class_name EnemyCharacter
extends Node2D
## Visual for a combatant that isn't the player: real art if the definition
## has a texture, otherwise a colored placeholder polygon - plus a name
## label. Used both as a standing encounter marker in exploration scenes and
## as the enemy/ally combatant visual in CombatScene.

@onready var polygon: Polygon2D = %Polygon
@onready var sprite: Sprite2D = %Sprite
@onready var name_label: Label = %NameLabel

var enemy_def: EnemyDefinition
var ally_def: AllyDefinition

func setup(def: EnemyDefinition) -> void:
	enemy_def = def
	if def == null:
		return
	_apply_visual(def.shape_points, def.body_color, def.display_name, def.texture)

func setup_ally(def: AllyDefinition) -> void:
	ally_def = def
	if def == null:
		return
	_apply_visual(def.shape_points, def.body_color, def.display_name, def.texture)

func _apply_visual(shape_points: PackedVector2Array, color: Color, display_name: String, tex: Texture2D = null) -> void:
	if tex != null:
		sprite.texture = tex
		sprite.visible = true
		polygon.visible = false
	else:
		if shape_points.size() >= 3:
			polygon.polygon = shape_points
		polygon.color = color
		polygon.visible = true
		sprite.visible = false
	name_label.text = display_name
