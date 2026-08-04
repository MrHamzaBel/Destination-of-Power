class_name AppearanceOption
extends Resource
## A single selectable appearance entry (hairstyle, shirt, pants, footwear, body type).
## New options are added by dropping a new .tres file in the matching resources/appearance/
## subfolder - no script changes required.

@export var id: String = ""
@export var display_name: String = ""
## Placeholder polygon used when no texture is supplied. Local-space points.
@export var shape_points: PackedVector2Array = PackedVector2Array()
## Fixed tint for items that don't use the skin/hair color palettes (clothing, shoes).
@export var tint_color: Color = Color.WHITE
## When true the renderer colors this shape using the character's skin color.
@export var uses_skin_color: bool = false
## When true the renderer colors this shape using the character's hair color.
@export var uses_hair_color: bool = false
## Optional real artwork. When set, a Sprite2D with this texture replaces the placeholder polygon.
@export var texture: Texture2D = null
