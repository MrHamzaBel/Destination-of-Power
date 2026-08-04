class_name RunData
extends Resource
## Persistent state for a single active roguelike run. Saved to its own slot so it
## can be removed on death/victory without touching the character profile.

const SAVE_VERSION: int = 6 ## v6 adds guild_progress.

@export var save_version: int = SAVE_VERSION
@export var run_seed: int = 0
@export var class_id: String = ""
@export var current_health: int = 0
@export var current_resource: int = 0
@export var level: int = 1
@export var current_exp: int = 0
@export var unspent_stat_points: int = 0
@export var allocated_stats: Dictionary = {} ## stat_name("hp"/"attack"/"defense"/"speed"/"intelligence") -> points spent
@export var inventory: Array[Dictionary] = [] ## [{"item_id": String, "quantity": int}]
@export var equipped: Dictionary = {} ## slot(String) -> item_id(String)
@export var artifacts: Dictionary = {} ## artifact_id(String) -> stack_count(int)
@export var currency: int = 0
@export var encounter_sequence: Array[String] = [] ## EncounterEntry.Kind names, in order.
@export var current_encounter_index: int = 0
@export var defeated_enemy_names: Array[String] = [] ## For the run summary screen.
@export var current_scene_path: String = ""
@export var is_active: bool = false
@export var story_flags: Dictionary = {} ## flag_id(String) -> bool, tracks one-shot narrative beats.
@export var active_quests: Array[String] = [] ## Quest ids accepted but not yet completed.
@export var completed_quests: Array[String] = [] ## Quest ids already rewarded.
@export var guild_rank: String = "" ## "" = not enrolled, else "F".."S" (see GuildRegistry).
@export var counters: Dictionary = {} ## Generic key(String) -> int counter bag (e.g. "alley_rat_kills").
@export var guild_progress: int = 0 ## Standing accumulated toward the next guild rank (see RunManager.guild_progress_required()).

func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"run_seed": run_seed,
		"class_id": class_id,
		"current_health": current_health,
		"current_resource": current_resource,
		"level": level,
		"current_exp": current_exp,
		"unspent_stat_points": unspent_stat_points,
		"allocated_stats": allocated_stats,
		"inventory": inventory,
		"equipped": equipped,
		"artifacts": artifacts,
		"currency": currency,
		"encounter_sequence": encounter_sequence,
		"current_encounter_index": current_encounter_index,
		"defeated_enemy_names": defeated_enemy_names,
		"current_scene_path": current_scene_path,
		"is_active": is_active,
		"story_flags": story_flags,
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"guild_rank": guild_rank,
		"counters": counters,
	}

static func from_dict(data: Dictionary) -> RunData:
	var run := RunData.new()
	run.save_version = data.get("save_version", SAVE_VERSION)
	run.run_seed = data.get("run_seed", 0)
	run.class_id = data.get("class_id", "")
	run.current_health = data.get("current_health", 0)
	run.current_resource = data.get("current_resource", 0)
	run.level = data.get("level", 1)
	run.current_exp = data.get("current_exp", 0)
	run.unspent_stat_points = data.get("unspent_stat_points", 0)
	run.allocated_stats = data.get("allocated_stats", {})
	run.inventory.assign(data.get("inventory", []))
	run.equipped = data.get("equipped", {})
	run.artifacts = data.get("artifacts", {})
	run.currency = data.get("currency", 0)
	run.encounter_sequence.assign(data.get("encounter_sequence", []))
	run.current_encounter_index = data.get("current_encounter_index", 0)
	run.defeated_enemy_names.assign(data.get("defeated_enemy_names", []))
	run.current_scene_path = data.get("current_scene_path", "")
	run.is_active = data.get("is_active", false)
	run.story_flags = data.get("story_flags", {})
	run.active_quests.assign(data.get("active_quests", []))
	run.completed_quests.assign(data.get("completed_quests", []))
	run.guild_rank = data.get("guild_rank", "")
	run.counters = data.get("counters", {})
	return run

func add_item(item_id: String, quantity: int = 1) -> void:
	for stack in inventory:
		if stack.get("item_id") == item_id:
			stack["quantity"] = int(stack.get("quantity", 0)) + quantity
			return
	inventory.append({"item_id": item_id, "quantity": quantity})

func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(inventory.size()):
		var stack: Dictionary = inventory[i]
		if stack.get("item_id") == item_id:
			var remaining: int = int(stack.get("quantity", 0)) - quantity
			if remaining <= 0:
				inventory.remove_at(i)
			else:
				stack["quantity"] = remaining
			return true
	return false

func get_item_quantity(item_id: String) -> int:
	for stack in inventory:
		if stack.get("item_id") == item_id:
			return int(stack.get("quantity", 0))
	return 0

func add_artifact(artifact_id: String) -> void:
	artifacts[artifact_id] = int(artifacts.get(artifact_id, 0)) + 1

func has_artifact(artifact_id: String) -> bool:
	return artifacts.has(artifact_id)
