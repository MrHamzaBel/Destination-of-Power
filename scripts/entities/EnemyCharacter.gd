class_name EnemyCharacter
extends Node2D
## Visual for a combatant that isn't the player: real art if the definition
## has a texture, otherwise a colored placeholder polygon - plus a name
## label. Used both as a standing encounter marker in exploration scenes and
## as the enemy/ally combatant visual in CombatScene.

## Real art comes in at whatever resolution the artist exported (source
## images so far range from ~1024x1536 to 1254x1254) - every texture is
## scaled to this same on-screen height, aspect ratio preserved, so a new
## piece of art never needs a per-enemy scale tweak to look consistent next
## to everything else. Per-instance scene "scale" overrides (already tuned
## against the placeholder polygons' size) keep applying on top of this.
const SPRITE_TARGET_HEIGHT: float = 64.0

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
		var tex_height := float(tex.get_height())
		var s := SPRITE_TARGET_HEIGHT / tex_height if tex_height > 0.0 else 1.0
		sprite.scale = Vector2(s, s)
	else:
		if shape_points.size() >= 3:
			polygon.polygon = shape_points
		polygon.color = color
		polygon.visible = true
		sprite.visible = false
	name_label.text = display_name

## Clear "this one's out" feedback for a multi-combatant fight: fades and
## grays the whole visual and appends a tag to the name label, instead of
## either vanishing instantly or (the old behavior) staying fully rendered
## as if still alive after its HP hits zero.
func mark_defeated() -> void:
	name_label.text += " (Defeated)"
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0.45, 0.42, 0.42, 0.45), 0.5)
