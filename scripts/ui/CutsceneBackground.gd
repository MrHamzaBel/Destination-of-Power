class_name CutsceneBackground
extends Control
## Placeholder backdrop for cutscene-style scenes (LoreIntro,
## CityGuardArrival/Farewell, MaskedManEncounter) - a simple procedural
## gradient-and-skyline placeholder shown behind the text until a scene
## supplies real artwork via LoreScript.background_texture. set_texture()
## then swaps it in and hides the placeholder shapes - the same
## "texture overrides placeholder" convention EnemyDefinition/AppearanceOption
## already use, so dropping in real art later needs no code changes here.

@onready var gradient_rect: TextureRect = %GradientRect
@onready var placeholder_shapes: Node2D = %PlaceholderShapes
@onready var art_rect: TextureRect = %ArtRect

func set_texture(tex: Texture2D) -> void:
	if tex != null:
		art_rect.texture = tex
		art_rect.visible = true
		gradient_rect.visible = false
		placeholder_shapes.visible = false
	else:
		art_rect.visible = false
		gradient_rect.visible = true
		placeholder_shapes.visible = true
