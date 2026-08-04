extends Node
## Loads every AllyDefinition .tres under resources/allies/.

const ALLIES_DIR: String = "res://resources/allies"

var _by_id: Dictionary = {} ## id(String) -> AllyDefinition

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	var dir := DirAccess.open(ALLIES_DIR)
	if dir == null:
		push_warning("AllyRegistry: could not open %s" % ALLIES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(ALLIES_DIR + "/" + file_name)
			if res is AllyDefinition:
				if res.id == "":
					push_warning("AllyRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
			else:
				push_warning("AllyRegistry: %s is not an AllyDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("AllyRegistry: loaded %d allies." % _by_id.size())

func get_ally(id: String) -> AllyDefinition:
	if not _by_id.has(id):
		push_warning("AllyRegistry: unknown ally id '%s'" % id)
		return null
	return _by_id[id]
