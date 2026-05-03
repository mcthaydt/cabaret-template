extends RefCounted

## Scene Manifest
##
## Data-driven scene registration via RS_SceneManifestConfig resources.
## Replaces hardcoded string paths with resource-based entries.
##
## Core entries ship in:
##   res://resources/core/scene_registry/cfg_core_scene_entries.tres
##
## Additional entries (e.g. demo) can be injected by providing their own
## RS_SceneManifestConfig resource path.
##
## Called by U_SceneRegistryLoader._load_entries_from_manifest().

const RS_SCENE_MANIFEST_CONFIG := preload("res://scripts/core/resources/scene_management/rs_scene_manifest_config.gd")

const CORE_CONFIG_PATH := "res://resources/core/scene_registry/cfg_core_scene_entries.tres"
const DEMO_CONFIG_PATH := "res://resources/demo/scene_registry/cfg_demo_scene_entries.tres"

## Build scene entries dictionary.
## Loads CORE_CONFIG_PATH and, if present, DEMO_CONFIG_PATH. If
## `additional_config_path` is provided and exists, those entries are merged
## in last (they can override earlier entries).
func build(additional_config_path: String = "") -> Dictionary:
	var entries: Dictionary = {}
	_load_config_into(CORE_CONFIG_PATH, entries)
	_load_config_into(DEMO_CONFIG_PATH, entries)
	_load_config_into(additional_config_path, entries)
	return entries

func _load_config_into(config_path: String, out_entries: Dictionary) -> void:
	if not FileAccess.file_exists(config_path):
		return
	var res: Resource = load(config_path)
	if res == null:
		return
	if not (res is RS_SCENE_MANIFEST_CONFIG):
		return
	var config: RS_SCENE_MANIFEST_CONFIG = res as RS_SCENE_MANIFEST_CONFIG
	var built: Dictionary = config.build_entries()
	for key: StringName in built.keys():
		out_entries[key] = built[key]
