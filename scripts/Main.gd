extends Node
## Boot scene. Immediately hands off to the main menu.

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(SceneManager.MAIN_MENU)
