extends Node
## Loads every ClassDefinition .tres under resources/classes/. ClassSelection.tscn
## reads get_all() and needs no changes when a new class file is added.

const CLASSES_DIR: String = "res://resources/classes"

var _by_id: Dictionary = {} ## id(String) -> ClassDefinition
var _ordered_ids: Array[String] = []

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	_ordered_ids.clear()
	var dir := DirAccess.open(CLASSES_DIR)
	if dir == null:
		push_warning("ClassRegistry: could not open %s" % CLASSES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(CLASSES_DIR + "/" + file_name)
			if res is ClassDefinition:
				if res.id == "":
					push_warning("ClassRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
					_ordered_ids.append(res.id)
			else:
				push_warning("ClassRegistry: %s is not a ClassDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_ordered_ids.sort()
	print("ClassRegistry: loaded %d classes." % _by_id.size())

func get_class_definition(id: String) -> ClassDefinition:
	return _by_id.get(id)

func get_all() -> Array[ClassDefinition]:
	var result: Array[ClassDefinition] = []
	for id in _ordered_ids:
		result.append(_by_id[id])
	return result
