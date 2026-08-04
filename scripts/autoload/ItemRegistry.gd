extends Node
## Loads every ItemDefinition .tres under resources/items/.

const ITEMS_DIR: String = "res://resources/items"

var _by_id: Dictionary = {} ## id(String) -> ItemDefinition

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("ItemRegistry: could not open %s" % ITEMS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(ITEMS_DIR + "/" + file_name)
			if res is ItemDefinition:
				if res.id == "":
					push_warning("ItemRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
			else:
				push_warning("ItemRegistry: %s is not an ItemDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("ItemRegistry: loaded %d items." % _by_id.size())

func get_item(id: String) -> ItemDefinition:
	if not _by_id.has(id):
		push_warning("ItemRegistry: unknown item id '%s'" % id)
		return null
	return _by_id[id]

func get_all() -> Array:
	return _by_id.values()
