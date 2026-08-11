class_name ArtifactDefinition
extends Resource
## Data-driven definition for a passive artifact. The actual behaviour lives in a
## reusable ArtifactEffectBase subclass identified by effect_id (see
## scripts/artifacts/), keeping this resource pure data.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.RARE
@export var icon_color: Color = Color.WHITE
@export var effect_id: String = "" ## Key into ArtifactEffectFactory.
@export var effect_values: Dictionary = {} ## Free-form tuning values read by the effect class.
@export var stacking_allowed: bool = false
@export var class_restrictions: Array[String] = [] ## Empty = usable by any class.
@export var random_drop_eligible: bool = true ## False = never granted by the normal post-victory random-artifact roll (ArtifactRegistry.get_random()) - reserved for a specific guaranteed source instead (e.g. EnemyDefinition.guaranteed_artifact_id).
@export var usable: bool = false ## True = this artifact isn't (just) a passive/event-driven effect - the player can manually trigger it (RunManager.use_artifact()), once per run, via InventoryScreen's Artifacts tab. Its effect class implements on_manually_used().

static func rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
	return "Rare"

static func rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.8, 0.8, 0.8)
		Rarity.UNCOMMON: return Color(0.35, 0.85, 0.35)
		Rarity.RARE: return Color(0.35, 0.55, 0.95)
		Rarity.EPIC: return Color(0.7, 0.35, 0.9)
		Rarity.LEGENDARY: return Color(0.95, 0.65, 0.15)
	return Color.WHITE
