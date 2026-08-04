extends Node
## Loads every GuildRankDefinition .tres under resources/guild_ranks/ and
## exposes the F->S rank ladder in order.

const RANKS_DIR: String = "res://resources/guild_ranks"

var _by_id: Dictionary = {} ## id(String) -> GuildRankDefinition
var _ordered: Array[GuildRankDefinition] = [] ## Sorted by `order` ascending.

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_by_id.clear()
	_ordered.clear()
	var dir := DirAccess.open(RANKS_DIR)
	if dir == null:
		push_warning("GuildRegistry: could not open %s" % RANKS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(RANKS_DIR + "/" + file_name)
			if res is GuildRankDefinition:
				if res.id == "":
					push_warning("GuildRegistry: %s has no id, skipping." % file_name)
				else:
					_by_id[res.id] = res
					_ordered.append(res)
			else:
				push_warning("GuildRegistry: %s is not a GuildRankDefinition." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_ordered.sort_custom(func(a, b): return a.order < b.order)
	print("GuildRegistry: loaded %d guild ranks." % _ordered.size())

func get_rank(id: String) -> GuildRankDefinition:
	return _by_id.get(id)

## Rank at ladder position `order` (0 = first rank, i.e. F).
func get_rank_by_order(order: int) -> GuildRankDefinition:
	for rank in _ordered:
		if rank.order == order:
			return rank
	return null

## The rank one step above `current_id`, or null if already at the top (or
## if "" is passed, returns the first rank - useful for "not enrolled yet").
func get_next_rank(current_id: String) -> GuildRankDefinition:
	if current_id == "":
		return get_rank_by_order(0)
	var current := get_rank(current_id)
	if current == null:
		return get_rank_by_order(0)
	return get_rank_by_order(current.order + 1)

func get_all_ordered() -> Array[GuildRankDefinition]:
	return _ordered.duplicate()
