class_name AllyDefinition
extends Resource
## Data-driven definition for a friendly NPC that can join combat on the
## player's side (e.g. an NPC recruited by a story event). Allies are always
## AI-controlled: each turn they attack whichever enemy is currently
## targeted (see CombatManager.get_current_target()).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stats: StatBlock = null
@export var body_color: Color = Color(0.3, 0.45, 0.7)
@export var shape_points: PackedVector2Array = PackedVector2Array()
## Optional real artwork - see EnemyDefinition.texture for how this is used.
@export var texture: Texture2D = null
