class_name EncounterEntry
extends Resource
## A single weighted encounter type used by the run's randomized sequence generator.

enum Kind { COMBAT, TREASURE, EMPTY, EVENT, HEALING }

@export var kind: Kind = Kind.COMBAT
@export var weight: float = 1.0 ## Relative chance of being picked for a sequence slot.
@export var display_name: String = ""
@export_multiline var flavor_text: String = ""
