class_name ItemDefinition
extends Resource
## Data-driven definition for weapons, armor, consumables and quest items.
## Artifacts are defined separately in ArtifactDefinition since they behave
## as passive event-driven items rather than equipment.

enum Category { WEAPON, ARMOR, CONSUMABLE, QUEST }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var icon_color: Color = Color.WHITE
@export var equip_slot: String = "" ## "weapon", "offhand", "armor" or "" for non-equippable.
@export var is_ranged: bool = false ## Weapons only: marks basic attacks as ranged for artifacts like Hunter's Eye.
@export var stat_modifiers: StatBlock = null ## Added to the wearer's stats while equipped.
@export var heal_amount: int = 0 ## Consumable: flat health restored.
@export var resource_amount: int = 0 ## Consumable: flat resource restored.
@export var combat_usable: bool = true ## Consumable: false = only usable from the Inventory screen while exploring, not from CombatHUD's Items panel (e.g. the Butcher's meats - real food, not battle rations).
@export var grants_stat_bonus_type: String = "" ## Consumable: one of "hp"/"attack"/"defense"/"speed"/"intelligence" - which stat grants_stat_bonus_amount is added to when used. "" = no effect.
@export var grants_stat_bonus_amount: int = 0 ## Consumable: permanently adds this many points to grants_stat_bonus_type when used - see RunManager.grant_stat_bonus(). "hp" points are worth StatBlock.HP_STAT_MULTIPLIER raw health each, same convention as allocate_stat_point("hp").
@export var value: int = 0 ## Gold value, used for shops/selling.
@export var droppable: bool = true
@export var sell_price: int = 0 ## If > 0, any TRADE-kind vendor buys this item for this much gold from TraderScreen's Sell tab. 0 = not generically sellable (the default for equipment/consumables the player needs to keep).

static func rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
	return "Common"

static func rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.8, 0.8, 0.8)
		Rarity.UNCOMMON: return Color(0.35, 0.85, 0.35)
		Rarity.RARE: return Color(0.35, 0.55, 0.95)
		Rarity.EPIC: return Color(0.7, 0.35, 0.9)
		Rarity.LEGENDARY: return Color(0.95, 0.65, 0.15)
	return Color.WHITE
