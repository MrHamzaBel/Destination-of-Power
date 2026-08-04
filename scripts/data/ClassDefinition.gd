class_name ClassDefinition
extends Resource
## Data-driven definition for a playable class. Adding a new class means adding a
## new .tres file in resources/classes/ - ClassSelection.tscn reads this list at
## runtime and needs no changes.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var base_stats: StatBlock = null
@export var impact_stat: String = "" ## Display-only label of the one core stat this class raises by +5 (e.g. "Speed").
@export var resource_label: String = "Mana" ## Display label: "Mana", "Energy", etc.
@export var starting_equipment: Array[String] = [] ## Item ids granted at run start (unequipped extras).
@export var starting_equipped: Dictionary = {} ## slot(String) -> item_id(String), equipped immediately.
@export var abilities: Array[String] = [] ## Ability ids available from the start.
@export var strengths: Array[String] = []
@export var weaknesses: Array[String] = []
@export var portrait_color: Color = Color.GRAY ## Placeholder illustration tint.
