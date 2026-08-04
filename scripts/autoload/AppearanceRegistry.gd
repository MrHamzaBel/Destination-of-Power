extends Node
## Loads all character customization data (body types, hairstyles, clothing,
## footwear, and color palettes) from resources/appearance/. Every category is
## a plain directory scan, so new options never require touching this script
## or the CharacterCreator scene.

const ROOT: String = "res://resources/appearance"

var body_types: Array[AppearanceOption] = []
var hairstyles: Array[AppearanceOption] = []
var shirts: Array[AppearanceOption] = []
var pants: Array[AppearanceOption] = []
var footwear: Array[AppearanceOption] = []
var skin_colors: Array[ColorSwatch] = []
var hair_colors: Array[ColorSwatch] = []

func _ready() -> void:
	body_types = _load_options(ROOT + "/body")
	hairstyles = _load_options(ROOT + "/hair")
	shirts = _load_options(ROOT + "/shirts")
	pants = _load_options(ROOT + "/pants")
	footwear = _load_options(ROOT + "/footwear")
	skin_colors = _load_swatches(ROOT + "/skin_colors")
	hair_colors = _load_swatches(ROOT + "/hair_colors")
	print("AppearanceRegistry: bodies=%d hair=%d shirts=%d pants=%d shoes=%d skin_colors=%d hair_colors=%d" % [
		body_types.size(), hairstyles.size(), shirts.size(), pants.size(), footwear.size(),
		skin_colors.size(), hair_colors.size()
	])

func _load_options(path: String) -> Array[AppearanceOption]:
	var result: Array[AppearanceOption] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("AppearanceRegistry: could not open %s" % path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(path + "/" + file_name)
			if res is AppearanceOption:
				result.append(res)
			else:
				push_warning("AppearanceRegistry: %s is not an AppearanceOption." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func _load_swatches(path: String) -> Array[ColorSwatch]:
	var result: Array[ColorSwatch] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("AppearanceRegistry: could not open %s" % path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(path + "/" + file_name)
			if res is ColorSwatch:
				result.append(res)
			else:
				push_warning("AppearanceRegistry: %s is not a ColorSwatch." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func find_option(list: Array[AppearanceOption], id: String) -> AppearanceOption:
	for option in list:
		if option.id == id:
			return option
	return list[0] if list.size() > 0 else null
