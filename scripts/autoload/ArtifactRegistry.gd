extends Node
## Loads every ArtifactDefinition .tres under resources/artifacts/.

const ARTIFACTS_DIR: String = "res://resources/artifacts"

var _by_id: Dictionary = {} ## id(String) -> ArtifactDefinition

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	var dir := DirAccess.open(ARTIFACTS_DIR)
	if dir == null:
		push_warning("ArtifactRegistry: could not open %s" % ARTIFACTS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(ARTIFACTS_DIR + "/" + file_name)
			if res is ArtifactDefinition:
				if res.id == "":
					push_warning("ArtifactRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
			else:
				push_warning("ArtifactRegistry: %s is not an ArtifactDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("ArtifactRegistry: loaded %d artifacts." % _by_id.size())

func get_artifact(id: String) -> ArtifactDefinition:
	if not _by_id.has(id):
		push_warning("ArtifactRegistry: unknown artifact id '%s'" % id)
		return null
	return _by_id[id]

func get_all() -> Array:
	return _by_id.values()

func get_random(rng: RandomNumberGenerator, class_id: String = "") -> ArtifactDefinition:
	var eligible: Array = []
	for artifact in _by_id.values():
		var def: ArtifactDefinition = artifact
		if def.class_restrictions.is_empty() or class_id == "" or def.class_restrictions.has(class_id):
			eligible.append(def)
	if eligible.is_empty():
		return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]
