class_name CharacterAppearanceRenderer
extends Node2D
## Builds the layered placeholder character visual from a CharacterProfile.
## Shared by the character creator preview, exploration player sprite and the
## combat scene so the same appearance shows everywhere. Layer order follows
## the spec: body, lower clothing, upper clothing, footwear, hair.

func apply_profile(profile: CharacterProfile) -> void:
	for child in get_children():
		child.queue_free()
	if profile == null:
		return

	var body_opt := AppearanceRegistry.find_option(AppearanceRegistry.body_types, profile.body_type)
	var hair_opt := AppearanceRegistry.find_option(AppearanceRegistry.hairstyles, profile.hairstyle)
	var shirt_opt := AppearanceRegistry.find_option(AppearanceRegistry.shirts, profile.shirt)
	var pants_opt := AppearanceRegistry.find_option(AppearanceRegistry.pants, profile.pants)
	var shoes_opt := AppearanceRegistry.find_option(AppearanceRegistry.footwear, profile.footwear)

	_add_layer(body_opt, profile, "Body")
	_add_layer(pants_opt, profile, "LowerClothing")
	_add_layer(shirt_opt, profile, "UpperClothing")
	_add_layer(shoes_opt, profile, "Footwear")
	_add_layer(hair_opt, profile, "Hair")

func _add_layer(option: AppearanceOption, profile: CharacterProfile, node_name: String) -> void:
	if option == null:
		return
	var color := option.tint_color
	if option.uses_skin_color:
		color = profile.skin_color
	elif option.uses_hair_color:
		color = profile.hair_color

	if option.texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = option.texture
		sprite.modulate = color
		sprite.name = node_name
		add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.polygon = option.shape_points
		poly.color = color
		poly.name = node_name
		add_child(poly)
