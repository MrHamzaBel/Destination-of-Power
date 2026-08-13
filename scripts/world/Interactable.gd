class_name Interactable
extends Area2D
## Generic interactable object placed in exploration scenes: a message
## notification, a combat trigger, a scene exit, or a healing spot.
## Configure per-instance in the editor/scene file - no subclassing needed.

enum Kind { MESSAGE, COMBAT, EXIT, HEAL, ITEM, TRADE, DIALOGUE, GUILD_RECEPTIONIST }

@export var display_name: String = "Object"
@export var kind: Kind = Kind.MESSAGE
@export_multiline var message: String = ""
@export var enemy_ids: Array[String] = []
@export var item_id: String = "" ## Used when kind == ITEM.
@export var item_quantity: int = 1
@export var one_shot: bool = false ## If true, disables itself after one trigger.
@export var victory_return_scene: String = "" ## COMBAT only: scene to load after victory instead of the default.
@export var exit_target_scene: String = "" ## EXIT only: scene to load. Falls back to the encounter screen if unset.
@export var required_guild_rank_order: int = -1 ## EXIT only: -1 = unrestricted, else minimum GuildRankDefinition.order needed.
@export_multiline var locked_message: String = "" ## EXIT only: shown instead of transitioning when the rank requirement isn't met.
@export var toll_gold_amount: int = 0 ## EXIT only: if the rank requirement isn't met, offers to pay this much gold to pass anyway instead of just blocking. 0 = no toll option.
@export var trade_item_id: String = "" ## TRADE only: item sold.
@export var trade_price: int = 0 ## TRADE only: gold cost (before any guild price discount).
@export var lounge_pricing: bool = false ## TRADE only: also apply the player's guild rank discount to the price.
@export_multiline var trade_flavor_text: String = "" ## TRADE only: optional line appended to the purchase notification.
@export var sell_bonus_item_ids: Array[String] = [] ## TRADE only: item ids this vendor pays a premium for (see sell_bonus_multiplier) - e.g. a curio trader paying extra for trophies. Empty = no specialty, this vendor just pays the base price like any other.
@export var sell_bonus_multiplier: float = 1.5 ## TRADE only: price multiplier applied when selling one of sell_bonus_item_ids to this vendor.
@export_multiline var dialogue_prompt: String = "" ## DIALOGUE only: the yes/no/decline question.
@export_multiline var dialogue_yes_text: String = ""
@export_multiline var dialogue_no_text: String = ""
@export_multiline var dialogue_decline_text: String = ""
@export_multiline var dialogue_quest_active_text: String = "" ## Shown instead of the prompt while quest_id is active.
@export_multiline var dialogue_quest_done_text: String = "" ## Shown instead of the prompt once quest_id is completed.
@export var quest_id: String = "" ## DIALOGUE only: quest started if the player picks "Yes".
@export var story_flag_id: String = "" ## If set, this interactable only fires once per run (persisted in RunData.story_flags).

signal interacted(source: Interactable)

var _used: bool = false

func _ready() -> void:
	add_to_group("interactables")

func trigger() -> void:
	if _used and one_shot:
		return
	_used = true
	interacted.emit(self)
	if one_shot:
		monitorable = false
		set_deferred("monitoring", false)
