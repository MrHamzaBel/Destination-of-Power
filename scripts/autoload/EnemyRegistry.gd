extends Node
## Loads every EnemyDefinition .tres under resources/enemies/.

const ENEMIES_DIR: String = "res://resources/enemies"

var _by_id: Dictionary = {} ## id(String) -> EnemyDefinition
var _ordered_ids: Array[String] = []

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	_ordered_ids.clear()
	var dir := DirAccess.open(ENEMIES_DIR)
	if dir == null:
		push_warning("EnemyRegistry: could not open %s" % ENEMIES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(ENEMIES_DIR + "/" + file_name)
			if res is EnemyDefinition:
				if res.id == "":
					push_warning("EnemyRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
					_ordered_ids.append(res.id)
			else:
				push_warning("EnemyRegistry: %s is not an EnemyDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("EnemyRegistry: loaded %d enemies." % _by_id.size())

func get_enemy(id: String) -> EnemyDefinition:
	if not _by_id.has(id):
		push_warning("EnemyRegistry: unknown enemy id '%s'" % id)
		return null
	return _by_id[id]

func get_all_ids() -> Array[String]:
	return _ordered_ids.duplicate()

func get_random_id(rng: RandomNumberGenerator) -> String:
	if _ordered_ids.is_empty():
		return ""
	return _ordered_ids[rng.randi_range(0, _ordered_ids.size() - 1)]
