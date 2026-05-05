class_name U_DemoSceneRegistryLoader
extends RefCounted

## Demo Scene Registry Loader
##
## Registers demo scene entries via U_SceneRegistryLoader.add_extension_loader().
## Call U_SceneRegistryLoader.add_extension_loader(U_DemoSceneRegistryLoader.initialize)
## before M_SceneManager initializes.

const SCENE_REGISTRY_LOADER := preload("res://scripts/core/scene_management/helpers/u_scene_registry_loader.gd")


static func initialize() -> void:
	for demo_path: String in _DEMO_PATHS:
		SCENE_REGISTRY_LOADER.register_extra_entry(load(demo_path))

static var _DEMO_PATHS: PackedStringArray = [
	"res://resources/demo/scene_registry/cfg_demo_scene_entries.tres",
]
