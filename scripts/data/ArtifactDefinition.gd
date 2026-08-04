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
