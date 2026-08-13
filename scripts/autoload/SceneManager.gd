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
const MARKET: String = "res://scenes/world/Market.tscn"
const NERAX_OUTSKIRTS: String = "res://scenes/world/NeraxOutskirts.tscn"
const FAR_REACHES: String = "res://scenes/world/FarReaches.tscn"
const MASKED_MAN_ENCOUNTER: String = "res://scenes/world/MaskedManEncounter.tscn"
const DEEP_FOREST: String = "res://scenes/world/DeepForest.tscn"
const WHISPERING_HOLLOW: String = "res://scenes/world/WhisperingHollow.tscn"
const GARRISON_WARD: String = "res://scenes/world/GarrisonWard.tscn"
const BUG_CATCHERS_GROVE: String = "res://scenes/world/BugCatchersGrove.tscn"
const NERAX_UPPER_WARD: String = "res://scenes/world/NeraxUpperWard.tscn"
const INNER_WALL_SOUTH: String = "res://scenes/world/InnerWallSouth.tscn"
const INNER_NERAX: String = "res://scenes/world/InnerNerax.tscn"
const INNER_NERAX_SHOPS: String = "res://scenes/world/InnerNeraxShops.tscn"
const BUTCHER_SHOP: String = "res://scenes/world/ButcherShop.tscn"
const ALCHEMIST_SHOP: String = "res://scenes/world/AlchemistShop.tscn"
const CLOTHING_SHOP: String = "res://scenes/world/ClothingShop.tscn"
const RELIC_SHOP: String = "res://scenes/world/RelicShop.tscn"

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var pending_combat_enemy_ids: Array[String] = [] ## Read by CombatScene on _ready().
var pending_combat_ally_ids: Array[String] = [] ## Read by CombatScene on _ready().
var return_scene_after_combat: String = BACK_ALLEY
var advances_encounter_on_victory: bool = false ## True when this fight is the current run encounter slot.
var arriving_from_scene_path: String = "" ## Read by ExplorationArea to spawn near the entrance actually used, not a fixed point.
var pending_combat_return_position: Vector2 = Vector2.ZERO ## Set by ExplorationArea.start_combat() to the player's position the instant a fight begins - read (and cleared) by ExplorationArea._apply_arrival_spawn() so returning from combat puts the player back exactly where they were standing, not the scene's default entry point.
var has_pending_combat_return_position: bool = false
var pending_appearance_return_scene: String = "" ## Set by start_appearance_edit() - read by CharacterCreator._ready() so Save/Back return here instead of the Main Menu, and the name field is locked, when it's reached mid-run from a clothing shop rather than the main menu flow.

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

## instant = true skips the fade entirely - used when a cutscene's own
## _finish() (LoreIntro, CityGuardArrival/Farewell, MaskedManEncounter) hands
## off to the next scene, so the cut lands right as the text closes instead
## of flashing to black first. With the real background art placeholder now
## behind the text (see CutsceneBackground), that flash reads as a visible
## black screen rather than the near-invisible black-to-black fade it used
## to be back when the cutscene background was itself just flat black.
func goto_scene(path: String, instant: bool = false) -> void:
	print("SceneManager: switching to ", path)
	arriving_from_scene_path = RunManager.run.current_scene_path if RunManager.run != null else ""
	# Defensive: a lingering paused tree (e.g. a notification dismissed by an
	# unusual path) has no business surviving into a fresh scene.
	get_tree().paused = false
	if instant:
		# Deferred, not immediate: goto_scene() is typically called from
		# inside a signal callback (a button press, _unhandled_input), and
		# swapping the tree's current_scene mid-callback is unsafe - Godot
		# errors with "Parent node is busy adding/removing children" since
		# the caller's own node is usually still partway through being
		# processed by that same signal. call_deferred() runs it once the
		# tree is done with whatever's currently in flight instead.
		call_deferred("_change_scene_deferred", path)
		return
	var tween := create_tween()
	# The new scene's own _ready() can show a notification immediately (e.g.
	# UndergroundNerax's first-visit line), which pauses the tree - without
	# this, that pause would freeze this tween mid-fade, leaving the fade
	# rect stuck fully opaque (a black screen) until something unrelated
	# happened to unpause it.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.15)
	tween.tween_callback(func():
		var err := get_tree().change_scene_to_file(path)
		if err != OK:
			push_error("SceneManager: failed to load scene '%s' (%s)" % [path, err])
	)
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.2)

func _change_scene_deferred(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: failed to load scene '%s' (%s)" % [path, err])

func start_combat(enemy_ids: Array[String], return_scene: String = BACK_ALLEY, advances_encounter: bool = false, ally_ids: Array[String] = [], instant: bool = false) -> void:
	pending_combat_enemy_ids = enemy_ids
	pending_combat_ally_ids = ally_ids
	return_scene_after_combat = return_scene
	advances_encounter_on_victory = advances_encounter
	goto_scene(COMBAT_SCENE, instant)

## Opens CharacterCreator mid-run to restyle the player's appearance (e.g. the
## Inner Nerax clothing shop) instead of the normal main-menu character
## creation flow - CharacterCreator._ready() checks pending_appearance_return_scene
## to lock the name field and route Save/Back back to return_scene instead of
## the Main Menu.
func start_appearance_edit(return_scene: String) -> void:
	pending_appearance_return_scene = return_scene
	goto_scene(CHARACTER_CREATOR)
