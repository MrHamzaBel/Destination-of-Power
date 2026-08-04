class_name GuildRankDefinition
extends Resource
## One tier of the Adventurers' Guild rank ladder (F through A). A run's
## current rank is stored as RunData.guild_rank (the id string, or "" if
## never enrolled). Ranks are ordered by `order` (0 = first/lowest).

@export var id: String = "" ## "F", "E", "D", "C", "B", "A"
@export var order: int = 0
@export var display_name: String = "" ## e.g. "F-Rank Adventurer"
@export_multiline var description: String = ""
@export var upgrade_cost: int = 0 ## Gold to reach this rank from the previous one (or to enroll, for rank 0).
@export var tax_discount_percent: float = 0.0 ## Applied to quest/mission gold rewards, and to lounge shop prices.
@export var free_potion_per_mission: bool = false ## Grants a Minor Healing Potion on every completed quest.
@export var unlocks_lounge: bool = false
@export var unlocks_special_missions: bool = false
