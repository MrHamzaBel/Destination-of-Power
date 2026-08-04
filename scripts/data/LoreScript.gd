class_name LoreScript
extends Resource
## A sequence of lore text sections shown one at a time by LoreIntro.tscn.
## Kept as data so the introduction text can be replaced without touching code.

@export var sections: Array[String] = []
