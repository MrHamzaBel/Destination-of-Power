extends Node
## Loads every QuestDefinition .tres under resources/quests/.

const QUESTS_DIR: String = "res://resources/quests"

var _by_id: Dictionary = {} ## id(String) -> QuestDefinition

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	var dir := DirAccess.open(QUESTS_DIR)
	if dir == null:
		push_warning("QuestRegistry: could not open %s" % QUESTS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(QUESTS_DIR + "/" + file_name)
			if res is QuestDefinition:
				if res.id == "":
					push_warning("QuestRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
			else:
				push_warning("QuestRegistry: %s is not a QuestDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("QuestRegistry: loaded %d quests." % _by_id.size())

func get_quest(id: String) -> QuestDefinition:
	if not _by_id.has(id):
		push_warning("QuestRegistry: unknown quest id '%s'" % id)
		return null
	return _by_id[id]
