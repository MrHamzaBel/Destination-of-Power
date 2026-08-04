extends ExplorationArea
## Starting exploration area: a dead-end back alley with a single way out
## (east, into the Two-Way Alley). Scene-specific bits only - shared
## wiring/interactable handling lives in ExplorationArea.
##
## The rat den (RatEncounter) is special-cased here instead of using the
## default COMBAT handling: each trigger spawns 1-2 regular rats, and once
## RunData.counters["alley_rat_kills"] reaches 5, every subsequent trigger
## rolls a chance to spawn the Rat Boss instead (10% at 5 kills, +10% for
## every additional 5 kills the player racks up without fighting him). Which
## fight was sent into combat is recorded in RunData just before the scene
## switch (story_flags["rat_den_pending_boss"] / counters["rat_den_pending_kills"])
## and resolved on return in _on_area_ready() - returning here at all implies
## victory, since a loss routes to RunSummary instead.

@onready var rat_encounter: Interactable = $RatEncounter

func get_scene_path() -> String:
	return SceneManager.BACK_ALLEY

func get_objective_text() -> String:
	return "Explore the alley and find a way out to the streets."

func _on_area_ready() -> void:
	_resolve_pending_rat_fight()

	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("back_alley_intro_shown", false)):
		return
	RunManager.run.story_flags["back_alley_intro_shown"] = true
	RunManager.save_current_run()

	var lore: LoreScript = load("res://resources/lore/back_alley_intro.tres")
	if lore != null and lore.sections.size() > 0:
		hud.show_notification(lore.sections[0])

func _on_interactable_triggered(interactable: Interactable) -> void:
	if interactable == rat_encounter:
		_trigger_rat_den()
		return
	super._on_interactable_triggered(interactable)

func _trigger_rat_den() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("rat_boss_defeated", false)):
		hud.show_notification("The alley is quiet now - the rats haven't come back since their boss fell.")
		return

	var kills := RunManager.get_counter("alley_rat_kills")
	var boss_chance: float = 0.0
	if kills >= 5:
		boss_chance = clampf(float(kills / 5) * 0.10, 0.0, 1.0)

	if boss_chance > 0.0 and randf() < boss_chance:
		RunManager.run.story_flags["rat_den_pending_boss"] = true
		RunManager.run.counters.erase("rat_den_pending_kills")
		RunManager.save_current_run()
		SceneManager.start_combat(["rat_boss", "alley_rat", "alley_rat"], get_scene_path())
		return

	var rat_count := 2 if randf() < 0.5 else 1
	var ids: Array[String] = []
	for i in range(rat_count):
		ids.append("alley_rat")
	RunManager.run.story_flags["rat_den_pending_boss"] = false
	RunManager.run.counters["rat_den_pending_kills"] = rat_count
	RunManager.save_current_run()
	SceneManager.start_combat(ids, get_scene_path())

func _resolve_pending_rat_fight() -> void:
	if RunManager.run == null:
		return
	if bool(RunManager.run.story_flags.get("rat_den_pending_boss", false)):
		RunManager.run.story_flags["rat_den_pending_boss"] = false
		RunManager.run.story_flags["rat_boss_defeated"] = true
		RunManager.save_current_run()
		hud.show_notification("With the Rat Boss slain, the rats have scattered for good.")
		return

	var pending_kills := RunManager.get_counter("rat_den_pending_kills")
	if pending_kills > 0:
		RunManager.run.counters.erase("rat_den_pending_kills")
		RunManager.increment_counter("alley_rat_kills", pending_kills)
		RunManager.save_current_run()
