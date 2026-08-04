extends Node
## Loads every AbilityDefinition .tres under resources/abilities/ and exposes
## lookup by id. Referenced by ClassDefinition and EnemyDefinition ability lists.

const ABILITIES_DIR: String = "res://resources/abilities"

var _by_id: Dictionary = {} ## id(String) -> AbilityDefinition

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	var dir := DirAccess.open(ABILITIES_DIR)
	if dir == null:
		push_warning("AbilityRegistry: could not open %s" % ABILITIES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(ABILITIES_DIR + "/" + file_name)
			if res is AbilityDefinition:
				if res.id == "":
					push_warning("AbilityRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
			else:
				push_warning("AbilityRegistry: %s is not an AbilityDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("AbilityRegistry: loaded %d abilities." % _by_id.size())

func get_ability(id: String) -> AbilityDefinition:
	if not _by_id.has(id):
		push_warning("AbilityRegistry: unknown ability id '%s'" % id)
		return null
	return _by_id[id]

func get_all() -> Array:
	return _by_id.values()
