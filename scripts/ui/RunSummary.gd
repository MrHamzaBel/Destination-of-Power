extends Control
## Shown after a run ends (victory or defeat). Reads the snapshot RunManager
## captured in end_run() - the saved character appearance is untouched.

@onready var panel: PanelContainer = %Panel
@onready var impact_flash: ColorRect = %ImpactFlash
@onready var title_label: Label = %TitleLabel
@onready var killed_by_panel: PanelContainer = %KilledByPanel
@onready var killed_by_label: Label = %KilledByLabel
@onready var killed_by_detail_label: Label = %KilledByDetailLabel
@onready var stats_label: Label = %StatsLabel
@onready var artifacts_label: Label = %ArtifactsLabel
@onready var return_button: Button = %ReturnButton

func _ready() -> void:
	var data := RunManager.last_run_summary
	var victory: bool = data.get("victory", false)

	title_label.text = "Victory!" if victory else "You Have Fallen"
	title_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1) if victory else Color(0.85, 0.35, 0.35, 1))

	if victory:
		killed_by_panel.visible = false
	else:
		_populate_killed_by(data.get("death_info", {}))

	var class_def := ClassRegistry.get_class_definition(data.get("class_id", ""))
	var stats_lines: Array[String] = []
	stats_lines.append("Class: %s" % (class_def.display_name if class_def != null else "Unknown"))
	stats_lines.append("Level reached: %d" % int(data.get("level", 1)))
	stats_lines.append("Encounters completed: %d" % int(data.get("encounters_completed", 0)))
	stats_lines.append("Gold collected: %d" % int(data.get("currency", 0)))
	var defeated: Array = data.get("defeated_enemy_names", [])
	stats_lines.append("Enemies defeated: %d" % defeated.size())
	stats_label.text = "\n".join(stats_lines)

	var artifacts: Dictionary = data.get("artifacts", {})
	var artifact_lines: Array[String] = []
	artifact_lines.append("Artifacts found (%d):" % artifacts.size())
	if artifacts.is_empty():
		artifact_lines.append("  None")
	else:
		for artifact_id in artifacts.keys():
			var artifact_def := ArtifactRegistry.get_artifact(artifact_id)
			artifact_lines.append("  - %s x%d" % [(artifact_def.display_name if artifact_def != null else artifact_id), int(artifacts[artifact_id])])
	artifacts_label.text = "\n".join(artifact_lines)

	return_button.pressed.connect(func(): SceneManager.goto_scene(SceneManager.MAIN_MENU))

	_play_entrance_animation(victory)

## Fills in the "Slain by X (Level N), killed with Y" card. Hidden entirely
## if there's no death_info (e.g. an older save, or some future non-combat
## way to end a run) rather than showing a blank/broken card.
func _populate_killed_by(death_info: Dictionary) -> void:
	var attacker_name: String = death_info.get("attacker_name", "")
	if attacker_name == "":
		killed_by_panel.visible = false
		return
	killed_by_panel.visible = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.06, 0.07, 0.85)
	style.border_color = Color(0.75, 0.25, 0.25, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	killed_by_panel.add_theme_stylebox_override("panel", style)

	var level: int = int(death_info.get("attacker_level", 1))
	killed_by_label.text = "Slain by %s (Level %d)" % [attacker_name, level]
	killed_by_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.6, 1))
	killed_by_detail_label.text = "Killed with %s." % str(death_info.get("attack_label", "an attack"))

## A red screen-flash and fade-in for defeat (a plain fade-in for victory) -
## and, for defeat only, a slow ongoing pulse on the title so the screen
## doesn't feel static while the player reads it.
func _play_entrance_animation(victory: bool) -> void:
	panel.modulate.a = 0.0
	var tween := create_tween()
	if not victory:
		impact_flash.color = Color(0.6, 0.05, 0.05, 0.6)
		var flash_tween := create_tween()
		flash_tween.tween_property(impact_flash, "color:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.15)
	tween.tween_property(panel, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)

	if not victory:
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(title_label, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
