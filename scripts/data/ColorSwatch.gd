class_name ColorSwatch
extends Resource
## A single named color choice for skin or hair palettes. Add a new swatch by
## creating a new .tres file in the matching resources/appearance/ colors folder.

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
