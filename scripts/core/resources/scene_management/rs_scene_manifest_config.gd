extends Resource
class_name RS_SceneManifestConfig

## Scene manifest configuration resource.
##
## Replaces hardcoded string paths in U_SceneManifest with data-driven entries.
## Core scenes ship in resources/core/scene_registry/cfg_core_scene_entries.tres.
## Projects can override by providing their own RS_SceneManifestConfig.
##
## Usage:
##   var config := preload("res://resources/core/scene_registry/cfg_core_scene_entries.tres")
##   var entries: Dictionary = config.build_entries()

const U_SCENE_REGISTRY_BUILDER := preload("res://scripts/core/utils/scene/u_scene_registry_builder.gd")

@export_group("Scenes")
@export var entries: Array[Dictionary] = []

## Build a scene registration Dictionary using U_SceneRegistryBuilder.
func build_entries() -> Dictionary:
	var builder := U_SCENE_REGISTRY_BUILDER.new()
	for data in entries:
		if not _is_valid_entry_dict(data):
			continue
		var scene_id := StringName(data.get("scene_id", ""))
		var scene_path: String = data.get("scene_path", "")
		var scene_type: int = int(data.get("scene_type", 2))
		var transition: String = data.get("default_transition", "fade")
		var priority: int = int(data.get("preload_priority", 0))
		builder.register(scene_id, scene_path) \
			.with_type(scene_type) \
			.with_transition(transition) \
			.with_preload(priority)
	return builder.build()

func _is_valid_entry_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var scene_id := StringName(data.get("scene_id", ""))
	var scene_path: String = data.get("scene_path", "")
	return scene_id != StringName("") and scene_path != ""
