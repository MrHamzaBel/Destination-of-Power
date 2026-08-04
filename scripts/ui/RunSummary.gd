extends Control
## Shown after a run ends (victory or defeat). Reads the snapshot RunManager
## captured in end_run() - the saved character appearance is untouched.

@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var return_button: Button = %ReturnButton

func _ready() -> void:
	var data := RunManager.last_run_summary
	var victory: bool = data.get("victory", false)
	title_label.text = "Victory!" if victory else "You Have Fallen"
	title_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1) if victory else Color(0.85, 0.35, 0.35, 1))

	var class_def := ClassRegistry.get_class_definition(data.get("class_id", ""))
	var lines: Array[String] = []
	lines.append("Class: %s" % (class_def.display_name if class_def != null else "Unknown"))
	lines.append("Level reached: %d" % int(data.get("level", 1)))
	lines.append("Encounters completed: %d" % int(data.get("encounters_completed", 0)))
	lines.append("Gold collected: %d" % int(data.get("currency", 0)))
	lines.append("")

	var defeated: Array = data.get("defeated_enemy_names", [])
	lines.append("Enemies defeated (%d):" % defeated.size())
	if defeated.is_empty():
		lines.append("  None")
	else:
		for enemy_name in defeated:
			lines.append("  - %s" % enemy_name)
	lines.append("")

	var artifacts: Dictionary = data.get("artifacts", {})
	lines.append("Artifacts found (%d):" % artifacts.size())
	if artifacts.is_empty():
		lines.append("  None")
	else:
		for artifact_id in artifacts.keys():
			var artifact_def := ArtifactRegistry.get_artifact(artifact_id)
			lines.append("  - %s x%d" % [(artifact_def.display_name if artifact_def != null else artifact_id), int(artifacts[artifact_id])])

	summary_label.text = "\n".join(lines)
	return_button.pressed.connect(func(): SceneManager.goto_scene(SceneManager.MAIN_MENU))
