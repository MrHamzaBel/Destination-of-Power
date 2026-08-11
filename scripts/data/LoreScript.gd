class_name LoreScript
extends Resource
## A sequence of lore text sections shown one at a time by LoreIntro.tscn.
## Kept as data so the introduction text can be replaced without touching code.

@export var sections: Array[String] = []
## Optional real background art for this cutscene. Unset (the default) shows
## CutsceneBackground's procedural gradient-and-skyline placeholder instead -
## drop a texture in here later and it takes over automatically, no script
## changes needed, same "texture overrides placeholder" convention
## EnemyDefinition/AppearanceOption already use.
@export var background_texture: Texture2D = null
