@icon("res://assets/core/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_VCamComponent

const COMPONENT_TYPE := StringName("VCamComponent")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_VCAM_MANAGER := preload("res://scripts/core/interfaces/i_vcam_manager.gd")
const RS_VCAM_RESPONSE_SCRIPT := preload("res://scripts/core/resources/display/vcam/rs_vcam_response.gd")

@export var vcam_id: StringName = StringName("")
@export var priority: int = 0
@export var mode: Resource = null
@export_node_path("Node3D") var follow_target_path: NodePath
@export var follow_target_entity_id: StringName = StringName("")
@export var follow_target_tag: StringName = StringName("")
@export_node_path("Node3D") var look_at_target_path: NodePath
@export var soft_zone: Resource = null
@export var blend_hint: Resource = null
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RS_VCamResponse") var response: Resource:
	set(value):
		if value == null:
			_response = null
			return
		if value.get_script() == RS_VCAM_RESPONSE_SCRIPT:
			_response = value
			return
		push_warning("C_VCamComponent.response expects RS_VCamResponse")
	get:
		return _response
@export var is_active: bool = true

var runtime_yaw: float = 0.0
var runtime_pitch: float = 0.0

var _vcam_manager: Node = null
var _response: Resource = null

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	super._ready()
	call_deferred("_register_with_vcam_manager")

func on_registered(manager: M_ECSManager) -> void:
	super.on_registered(manager)
	call_deferred("_register_with_vcam_manager")

func _exit_tree() -> void:
	_unregister_from_vcam_manager()

func get_follow_target() -> Node3D:
	if follow_target_path.is_empty():
		return null
	return get_node_or_null(follow_target_path) as Node3D

func get_look_at_target() -> Node3D:
	if look_at_target_path.is_empty():
		return null
	return get_node_or_null(look_at_target_path) as Node3D

## C10: resource_name/metadata primary, prefix-stripping fallback.
func get_mode_name() -> String:
	if mode == null:
		return ""

	if not mode.resource_name.is_empty():
		return mode.resource_name

	if mode.has_meta("mode_name"):
		return str(mode.get_meta("mode_name"))

	var mode_script := mode.get_script() as Script
	if mode_script == null:
		return ""
	var global_name := mode_script.get_global_name()
	if not global_name.is_empty():
		if global_name.begins_with("RS_VCamMode"):
			return global_name.trim_prefix("RS_VCamMode").to_snake_case()
		return global_name.to_snake_case()
	var file_name := mode_script.resource_path.get_file().get_basename()
	if file_name.begins_with("rs_vcam_mode_"):
		return file_name.trim_prefix("rs_vcam_mode_")
	return file_name

func _register_with_vcam_manager() -> void:
	if not is_inside_tree():
		return
	var manager := _resolve_vcam_manager()
	if manager == null:
		return
	manager.register_vcam(self)

func _unregister_from_vcam_manager() -> void:
	var manager := _resolve_vcam_manager()
	if manager == null:
		return
	manager.unregister_vcam(self)
	_vcam_manager = null

func _resolve_vcam_manager() -> Node:
	if _vcam_manager != null and is_instance_valid(_vcam_manager):
		return _vcam_manager
	var service := U_SERVICE_LOCATOR.try_get_service(StringName("vcam_manager"))
	if service == null:
		return null
	if not is_instance_valid(service):
		return null
	if not (service is I_VCAM_MANAGER):
		return null
	_vcam_manager = service
	return _vcam_manager
