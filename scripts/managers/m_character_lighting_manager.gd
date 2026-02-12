@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_character_lighting_manager.gd"
class_name M_CharacterLightingManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const SERVICE_NAME := StringName("character_lighting_manager")

var _scene_default_profile: Resource = null
var _zones: Array[Node] = []
var _is_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)

func _exit_tree() -> void:
	_zones.clear()

func set_scene_default_profile(profile: Resource) -> void:
	_scene_default_profile = profile

func register_zone(zone: Node) -> void:
	if zone == null:
		return
	if _zones.has(zone):
		return
	_zones.append(zone)

func unregister_zone(zone: Node) -> void:
	if zone == null:
		return
	_zones.erase(zone)

func refresh_scene_bindings() -> void:
	_prune_invalid_zones()

func set_character_lighting_enabled(enabled: bool) -> void:
	_is_enabled = enabled

func _physics_process(_delta: float) -> void:
	if not _is_enabled:
		return
	_prune_invalid_zones()

func _prune_invalid_zones() -> void:
	var active: Array[Node] = []
	for zone in _zones:
		if zone == null:
			continue
		if not is_instance_valid(zone):
			continue
		active.append(zone)
	_zones = active
