extends Node
## Global signal bus. Combat, artifacts and UI communicate through here instead of
## holding direct references to each other, keeping systems decoupled.

# --- Combat lifecycle -------------------------------------------------------
signal combat_started(context: Dictionary)
signal turn_started(context: Dictionary)
signal player_attacked(context: Dictionary)
signal player_dealt_damage(context: Dictionary) ## Emitted after a player attack's final damage is applied (context: "damage", "target") - unlike player_attacked (pre-mitigation, for artifacts that modify the hit), this is the actual dealt amount, for artifacts that react to it instead (e.g. lifesteal).
signal player_took_damage(context: Dictionary)
signal enemy_defeated(context: Dictionary)
signal combat_ended(context: Dictionary)
signal item_used(context: Dictionary)
signal health_low(context: Dictionary)

# --- Meta / run lifecycle ---------------------------------------------------
signal run_started
signal run_ended(victory: bool)
signal character_saved(profile: CharacterProfile)
signal inventory_changed
signal equipment_changed
