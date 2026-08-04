class_name QuestDefinition
extends Resource
## Data-driven quest definition. Rewards can freely combine gold, experience,
## free stat points, items and a single artifact - a quest just sets
## whichever reward_* fields it wants, unset ones simply grant nothing.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var objective_text: String = ""

@export var reward_gold: int = 0
@export var reward_exp: int = 0
@export var reward_stat_points: int = 0
@export var reward_item_ids: Array[String] = []
@export var reward_artifact_id: String = ""

## Human-readable summary of the reward, e.g. "15 gold, 20 exp, Minor
## Healing Potion" - used by quest-completion notifications.
func describe_reward() -> String:
	var parts: Array[String] = []
	if reward_gold > 0:
		parts.append("%d gold" % reward_gold)
	if reward_exp > 0:
		parts.append("%d exp" % reward_exp)
	if reward_stat_points > 0:
		parts.append("%d stat point%s" % [reward_stat_points, "" if reward_stat_points == 1 else "s"])
	for item_id in reward_item_ids:
		var item_def := ItemRegistry.get_item(item_id)
		parts.append(item_def.display_name if item_def != null else item_id)
	if reward_artifact_id != "":
		var artifact_def := ArtifactRegistry.get_artifact(reward_artifact_id)
		parts.append(artifact_def.display_name if artifact_def != null else reward_artifact_id)
	return ", ".join(parts)
