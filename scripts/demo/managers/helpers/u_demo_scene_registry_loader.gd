class_name U_DemoSceneRegistryLoader
extends RefCounted

const SCENE_REGISTRY_LOADER := preload("res://scripts/core/scene_management/helpers/u_scene_registry_loader.gd")


static func _static_init() -> void:
	SCENE_REGISTRY_LOADER.register_extra_entry(preload("res://resources/demo/scene_registry/cfg_demo_scene_entries.tres"))
