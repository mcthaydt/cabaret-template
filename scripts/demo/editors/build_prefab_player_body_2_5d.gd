@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/prefabs/prefab_player_body_2_5d.tscn"

const _SHADOW_BLOB := preload("res://assets/core/textures/tex_shadow_blob.png")
const _SPRITE_PLACEHOLDER := preload("res://assets/core/textures/prototype_grids/tex_texture_01.png")

func _run() -> void:
	var root := Node3D.new()
	root.name = "PlayerBodyVisualRoot"

	var sprite := Sprite3D.new()
	sprite.name = "DirectionalSprite"
	sprite.pixel_size = 1.0 / 128.0
	sprite.texture = _SPRITE_PLACEHOLDER
	sprite.modulate = Color(0.08627451, 0.3529412, 0.29803923, 1)
	sprite.position = Vector3(0, 0.8, 0)
	sprite.scale = Vector3(1.0, 1.6, 1.0)
	root.add_child(sprite)
	sprite.set_owner(root)

	var ground_indicator := Sprite3D.new()
	ground_indicator.name = "GroundIndicator"
	ground_indicator.texture = _SHADOW_BLOB
	ground_indicator.modulate = Color(1, 1, 1, 0.49803922)
	ground_indicator.position = Vector3(0, -0.02, 0)
	ground_indicator.rotation_degrees = Vector3(-90, 0, 0)
	ground_indicator.scale = Vector3(0.2, 0.2, 0.2)
	root.add_child(ground_indicator)
	ground_indicator.set_owner(root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("Failed to pack prefab_player_body_2_5d")
		return
	if ResourceSaver.save(packed, OUTPUT_PATH) != OK:
		printerr("Failed to save prefab_player_body_2_5d")
	else:
		print("prefab_player_body_2_5d built: %s" % OUTPUT_PATH)
