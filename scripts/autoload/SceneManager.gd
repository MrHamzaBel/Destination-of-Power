extends Node
## Centralizes scene transitions so no other script needs to know file paths or
## juggle change_scene_to_file() directly. A simple fade covers the swap.

const MAIN_MENU: String = "res://scenes/ui/MainMenu.tscn"
const CHARACTER_CREATOR: String = "res://scenes/ui/CharacterCreator.tscn"
const CLASS_SELECTION: String = "res://scenes/ui/ClassSelection.tscn"
const LORE_INTRO: String = "res://scenes/ui/LoreIntro.tscn"
const BACK_ALLEY: String = "res://scenes/world/BackAlley.tscn"
const ENCOUNTER_SCREEN: String = "res://scenes/world/EncounterScreen.tscn"
const COMBAT_SCENE: String = "res://scenes/combat/CombatScene.tscn"
const RUN_SUMMARY: String = "res://scenes/ui/RunSummary.tscn"
const CITY_GUARD_ARRIVAL: String = "res://scenes/world/CityGuardArrival.tscn"
const CITY_GUARD_FAREWELL: String = "res://scenes/world/CityGuardFarewell.tscn"
const TWO_WAY_ALLEY: String = "res://scenes/world/TwoWayAlley.tscn"
const PLAZA: String = "res://scenes/world/Plaza.tscn"
const ADVENTURE_CENTRUM: String = "res://scenes/world/AdventureCentrum.tscn"
const GUILD_LOUNGE: String = "res://scenes/world/GuildLounge.tscn"
const DEEPER_ALLEY: String = "res://scenes/world/DeeperAlley.tscn"
const UNDERGROUND_NERAX: String = "res://scenes/world/UndergroundNerax.tscn"

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var pending_combat_enemy_ids: Array[String] = [] ## Read by CombatScene on _ready().
var pending_combat_ally_ids: Array[String] = [] ## Read by CombatScene on _ready().
var return_scene_after_combat: String = BACK_ALLEY
var advances_encounter_on_victory: bool = false ## True when this fight is the current run encounter slot.

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
	call_deferred("_attach_fade_layer")

func _attach_fade_layer() -> void:
	get_tree().root.add_child.call_deferred(_fade_layer)

func goto_scene(path: String) -> void:
	print("SceneManager: switching to ", path)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.15)
	tween.tween_callback(func():
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			push_error("SceneManager: failed to load scene '%s' (%s)" % [path, err])
	)
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.2)

func start_combat(enemy_ids: Array[String], return_scene: String = BACK_ALLEY, advances_encounter: bool = false, ally_ids: Array[String] = []) -> void:
	pending_combat_enemy_ids = enemy_ids
	pending_combat_ally_ids = ally_ids
	return_scene_after_combat = return_scene
	advances_encounter_on_victory = advances_encounter
	goto_scene(COMBAT_SCENE)
