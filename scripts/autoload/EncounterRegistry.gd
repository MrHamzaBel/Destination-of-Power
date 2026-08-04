extends Node
## Loads every EncounterEntry .tres under resources/encounters/ and generates
## randomized run sequences from their relative weights.

const ENCOUNTERS_DIR: String = "res://resources/encounters"
const SEQUENCE_LENGTH: int = 6

var _entries: Array[EncounterEntry] = []

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_entries.clear()
	var dir := DirAccess.open(ENCOUNTERS_DIR)
	if dir == null:
		push_warning("EncounterRegistry: could not open %s" % ENCOUNTERS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(ENCOUNTERS_DIR + "/" + file_name)
			if res is EncounterEntry:
				_entries.append(res)
			else:
				push_warning("EncounterRegistry: %s is not an EncounterEntry." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("EncounterRegistry: loaded %d encounter types." % _entries.size())

func get_entry(kind: EncounterEntry.Kind) -> EncounterEntry:
	for entry in _entries:
		if entry.kind == kind:
			return entry
	return null

func get_entry_by_name(kind_name: String) -> EncounterEntry:
	for entry in _entries:
		if EncounterEntry.Kind.keys()[entry.kind] == kind_name:
			return entry
	return null

## Builds a fixed-length sequence of encounter kind names using weighted random
## picks. The final slot is always a combat encounter to give the run a clear
## end point; the rest are shuffled from the weighted pool.
func generate_sequence(rng: RandomNumberGenerator) -> Array[String]:
	var sequence: Array[String] = []
	if _entries.is_empty():
		return sequence
	var total_weight := 0.0
	for entry in _entries:
		total_weight += entry.weight
	for i in range(SEQUENCE_LENGTH):
		var roll := rng.randf() * total_weight
		var accumulated := 0.0
		var chosen: EncounterEntry = _entries[0]
		for entry in _entries:
			accumulated += entry.weight
			if roll <= accumulated:
				chosen = entry
				break
		sequence.append(EncounterEntry.Kind.keys()[chosen.kind])
	sequence[sequence.size() - 1] = EncounterEntry.Kind.keys()[EncounterEntry.Kind.COMBAT]
	return sequence
