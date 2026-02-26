extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_VictoryZone

const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_victory_interaction_config.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")
const U_OBJECTIVES_SELECTORS := preload("res://scripts/state/selectors/u_objectives_selectors.gd")
const OBJECTIVES_SLICE_NAME := StringName("objectives")

@export var component_name: StringName = StringName("C_VictoryTriggerComponent")

var component_factory: Callable

var _config: Resource = null
@export var config: Resource:
	get:
		return _config
	set(value):
		if value != null and not U_INTERACTION_CONFIG_RESOLVER.script_matches(value, RS_VICTORY_INTERACTION_CONFIG):
			return
		_config = value
		_apply_config_resource()
		_apply_component_config()
		if is_inside_tree():
			_refresh_visibility_gate()

var _component: C_VictoryTriggerComponent = null
var _store: I_StateStore = null
var _has_applied_visibility_state: bool = false
var _is_visibility_unlocked: bool = true

func _ready() -> void:
	_apply_config_resource()
	super._ready()
	trigger_area_ready.connect(_on_controller_area_ready)
	var area := get_trigger_area()
	if area != null:
		_on_controller_area_ready(area)
	await get_tree().process_frame
	_resolve_store()
	_connect_store()
	_refresh_visibility_gate()

func _exit_tree() -> void:
	_disconnect_store()
	super._exit_tree()

func _on_controller_area_ready(area: Area3D) -> void:
	if area == null:
		return
	_ensure_component(area)
	_apply_component_config()

func _ensure_component(area: Area3D) -> void:
	if _component != null and is_instance_valid(_component):
		return

	var instance := _instantiate_component()
	if instance == null:
		push_error("Inter_VictoryZone: Unable to instantiate C_VictoryTriggerComponent.")
		return

	instance.name = _resolve_component_name()
	var provisional_path := _build_provisional_area_path(area)
	if not provisional_path.is_empty():
		instance.area_path = provisional_path

	add_child(instance)
	_component = instance
	_update_component_area_path()
	_component._resolve_area()

func _instantiate_component() -> C_VictoryTriggerComponent:
	if component_factory != null and component_factory.is_valid():
		var created: Variant = component_factory.call()
		if created is C_VictoryTriggerComponent:
			return created as C_VictoryTriggerComponent
		push_warning("Inter_VictoryZone: component_factory returned incompatible instance.")
	return C_VictoryTriggerComponent.new()

func _resolve_component_name() -> String:
	if String(component_name).is_empty():
		return "C_VictoryTriggerComponent"
	return String(component_name)

func _build_provisional_area_path(area: Area3D) -> NodePath:
	if area == null:
		return NodePath("")
	return NodePath("../%s" % String(area.name))

func _update_component_area_path() -> void:
	if _component == null or not is_instance_valid(_component):
		return
	var area := get_trigger_area()
	if area == null:
		return
	var path := _component.get_path_to(area)
	if path.is_empty():
		return
	_component.area_path = path

func _apply_component_config() -> void:
	if _component == null or not is_instance_valid(_component):
		return
	var typed := _resolve_config()
	if typed == null:
		return

	_component.objective_id = typed.objective_id
	_component.area_id = typed.area_id
	_component.victory_type = typed.victory_type as C_VictoryTriggerComponent.VictoryType
	_component.trigger_once = typed.trigger_once
	if typed.trigger_settings != null:
		typed.trigger_settings.ignore_initial_overlap = false

	_update_component_area_path()

func refresh_volume_from_settings() -> void:
	super.refresh_volume_from_settings()
	_apply_component_config()

func _apply_config_resource() -> void:
	var typed := _resolve_config()
	if typed == null:
		return

	var trigger_settings: RS_SceneTriggerSettings = typed.get("trigger_settings") as RS_SceneTriggerSettings
	if trigger_settings != null:
		settings = trigger_settings

func _resolve_config() -> RS_VictoryInteractionConfig:
	if _config != null and U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_VICTORY_INTERACTION_CONFIG):
		return _config as RS_VictoryInteractionConfig
	return null

func _resolve_store() -> void:
	if _store != null and is_instance_valid(_store):
		return
	_store = U_StateUtils.try_get_store(self)

func _connect_store() -> void:
	if _store == null:
		return
	if not _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.connect(_on_slice_updated)

func _disconnect_store() -> void:
	if _store != null and is_instance_valid(_store):
		if _store.slice_updated.is_connected(_on_slice_updated):
			_store.slice_updated.disconnect(_on_slice_updated)
	_store = null

func _on_slice_updated(slice_name: StringName, __slice_state: Dictionary) -> void:
	if not _is_slice_relevant_for_visibility_gate(slice_name):
		return
	_refresh_visibility_gate()

func _is_slice_relevant_for_visibility_gate(slice_name: StringName) -> bool:
	return slice_name == OBJECTIVES_SLICE_NAME

func _refresh_visibility_gate() -> void:
	_resolve_store()
	var state := _build_visibility_state()
	var unlocked: bool = _compute_visibility_gate_unlocked(state)
	_apply_visibility_gate_state(unlocked)

func _apply_visibility_gate_state(unlocked: bool) -> void:
	if _has_applied_visibility_state and _is_visibility_unlocked == unlocked:
		return
	_has_applied_visibility_state = true
	_is_visibility_unlocked = unlocked
	set_enabled(unlocked)
	visible = unlocked

func _build_visibility_state() -> Dictionary:
	if _store == null:
		return {}
	return _store.get_state()

func _compute_visibility_gate_unlocked(state: Dictionary) -> bool:
	return _is_visibility_objective_active(state)

func _is_visibility_objective_active(state: Dictionary) -> bool:
	var objective_id: StringName = _get_effective_visibility_objective_id()
	if objective_id == StringName(""):
		return true
	if state.is_empty():
		return false
	var status: String = U_OBJECTIVES_SELECTORS.get_objective_status(state, objective_id)
	return status == U_OBJECTIVES_SELECTORS.STATUS_ACTIVE

func _get_effective_visibility_objective_id() -> StringName:
	var typed := _resolve_config()
	if typed == null:
		return StringName("")
	return typed.visibility_objective_id
