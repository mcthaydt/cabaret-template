extends RefCounted
class_name U_VCamRuntimeServices

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_VCAM_MANAGER := preload("res://scripts/core/interfaces/i_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/core/ecs/components/c_vcam_component.gd")

var _owner: Node = null
var _exported_state_store: I_StateStore = null
var _exported_vcam_manager: I_VCAM_MANAGER = null
var _state_store: I_StateStore = null
var _vcam_manager: Node = null

func configure(owner: Node, state_store: I_StateStore, vcam_manager: I_VCAM_MANAGER) -> void:
	_owner = owner
	_exported_state_store = state_store
	_exported_vcam_manager = vcam_manager

func resolve_vcam_manager() -> I_VCAM_MANAGER:
	if _vcam_manager != null and is_instance_valid(_vcam_manager):
		return _vcam_manager as I_VCAM_MANAGER

	if _exported_vcam_manager != null and is_instance_valid(_exported_vcam_manager):
		_vcam_manager = _exported_vcam_manager
		return _vcam_manager as I_VCAM_MANAGER

	var service: Node = U_SERVICE_LOCATOR.try_get_service(StringName("vcam_manager"))
	if service == null or not is_instance_valid(service):
		return null
	if not (service is I_VCAM_MANAGER):
		return null

	_vcam_manager = service
	return _vcam_manager as I_VCAM_MANAGER

func resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, _exported_state_store, _owner)
	return _state_store

func build_vcam_index(components: Array) -> Dictionary:
	var index: Dictionary = {}
	for entry in components:
		var component := entry as C_VCamComponent
		if component == null:
			continue
		var vcam_id: StringName = resolve_component_vcam_id(component)
		if vcam_id == StringName(""):
			continue
		if index.has(vcam_id):
			continue
		index[vcam_id] = component
	return index

func resolve_component_vcam_id(component: C_VCamComponent) -> StringName:
	if component == null:
		return StringName("")
	if component.vcam_id != StringName(""):
		return component.vcam_id
	var fallback_id := String(component.name)
	if fallback_id.is_empty():
		return StringName("")
	return StringName(fallback_id.to_snake_case())

func get_node_instance_id(node: Node) -> int:
	if node == null:
		return 0
	if not is_instance_valid(node):
		return 0
	return node.get_instance_id()

func is_follow_target_required(mode: Resource, orbit_mode_script: Script) -> bool:
	if mode == null:
		return false
	var mode_script := mode.get_script() as Script
	return mode_script == orbit_mode_script
