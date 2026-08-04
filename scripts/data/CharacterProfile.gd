class_name CharacterProfile
extends Resource
## Persistent player appearance data. Saved independently from run data so a
## character's look survives across runs and app restarts.

const SAVE_VERSION: int = 1

@export var save_version: int = SAVE_VERSION
@export var character_name: String = ""
@export var body_type: String = ""
@export var skin_color: Color = Color(0.87, 0.72, 0.56)
@export var hairstyle: String = ""
@export var hair_color: Color = Color(0.25, 0.16, 0.08)
@export var shirt: String = ""
@export var pants: String = ""
@export var footwear: String = ""

func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"character_name": character_name,
		"body_type": body_type,
		"skin_color": skin_color.to_html(),
		"hairstyle": hairstyle,
		"hair_color": hair_color.to_html(),
		"shirt": shirt,
		"pants": pants,
		"footwear": footwear,
	}

static func from_dict(data: Dictionary) -> CharacterProfile:
	var profile := CharacterProfile.new()
	profile.save_version = data.get("save_version", SAVE_VERSION)
	profile.character_name = data.get("character_name", "")
	profile.body_type = data.get("body_type", "")
	profile.skin_color = Color(data.get("skin_color", "#deb88f"))
	profile.hairstyle = data.get("hairstyle", "")
	profile.hair_color = Color(data.get("hair_color", "#402910"))
	profile.shirt = data.get("shirt", "")
	profile.pants = data.get("pants", "")
	profile.footwear = data.get("footwear", "")
	return profile

func is_valid() -> bool:
	return character_name.strip_edges() != ""
