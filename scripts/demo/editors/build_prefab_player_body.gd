@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/prefabs/prefab_player_body.tscn"
const PLAYER_SPRITE_PATH := "res://assets/core/textures/characters/tex_player_sprite_sheet.png"

const _SHADOW_BLOB := preload("res://assets/core/textures/tex_shadow_blob.png")

func _run() -> void:
	var sprite_texture: Texture2D = load(PLAYER_SPRITE_PATH) as Texture2D
	if sprite_texture == null:
		printerr("Sprite texture not found at %s" % PLAYER_SPRITE_PATH)
		return

	var builder := U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "PlayerBodyVisualRoot")

	var sprite := Sprite3D.new()
	sprite.name = "DirectionalSprite"
	sprite.pixel_size = 0.01
	sprite.hframes = 3
	sprite.vframes = 3
	sprite.texture = sprite_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(0, 0.64, 0)
	builder.add_child_to(".", sprite)

	var ground_indicator := Sprite3D.new()
	ground_indicator.name = "GroundIndicator"
	ground_indicator.texture = _SHADOW_BLOB
	ground_indicator.modulate = Color(1, 1, 1, 0.49803922)
	ground_indicator.position = Vector3(0, -0.01, 0)
	ground_indicator.rotation_degrees = Vector3(-90, 0, 0)
	ground_indicator.scale = Vector3(0.08, 0.08, 0.08)
	builder.add_child_to(".", ground_indicator)

	if builder.save(OUTPUT_PATH):
		print("prefab_player_body built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build prefab_player_body")
