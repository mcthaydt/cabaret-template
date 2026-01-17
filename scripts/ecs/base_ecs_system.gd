@icon("res://resources/editor_icons/system.svg")
extends Node

class_name BaseECSSystem

const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
static var _missing_manager_method_warnings: Dictionary = {}

var _manager: I_ECSManager
var _execution_priority: int = 0
var _debug_disabled: bool = false

## Injected ECS manager (for testing)
## If set via @export, system uses this instead of auto-discovery
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var ecs_manager: I_ECSManager = null

@export var execution_priority: int:
	get:
		return _execution_priority
	set(value):
		var clamped := clampi(value, 0, 1000)
		if _execution_priority == clamped:
			return
		_execution_priority = clamped
		_notify_manager_priority_changed()

func _ready() -> void:
	call_deferred("_register_with_manager")

func configure(manager: I_ECSManager) -> void:
	_manager = manager
	_notify_manager_priority_changed()
	on_configured()

func on_configured() -> void:
	pass

func get_manager() -> I_ECSManager:
	# Prioritize injected manager for tests (Phase 10B-8)
	if ecs_manager != null:
		return ecs_manager
	return _manager

func get_components(component_type: StringName) -> Array:
	if _manager == null:
		return []
	if not _manager.has_method("get_components"):
		_warn_missing_manager_method("get_components")
		return []
	var components: Array = _manager.get_components(component_type)
	return components.duplicate()

func query_entities(required: Array[StringName], optional: Array[StringName] = []) -> Array:
	if _manager == null:
		return []
	if not _manager.has_method("query_entities"):
		_warn_missing_manager_method("query_entities")
		return []
	return _manager.query_entities(required, optional)

func set_debug_disabled(disabled: bool) -> void:
	_debug_disabled = disabled

func is_debug_disabled() -> bool:
	return _debug_disabled

func process_tick(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	# Allow manual invocation when the system is not managed.
	if _manager == null:
		process_tick(delta)

func _register_with_manager() -> void:
	# Use injected manager if available (Phase 10B-8)
	if ecs_manager != null:
		if ecs_manager.has_method("register_system"):
			ecs_manager.register_system(self)
		return

	# Otherwise, auto-discover
	var manager := ECS_UTILS.get_manager(self) as I_ECSManager
	if manager == null:
		return
	manager.register_system(self)

func _notify_manager_priority_changed() -> void:
	if _manager == null:
		return
	if not _manager.has_method("mark_systems_dirty"):
		return
	_manager.mark_systems_dirty()

func _warn_missing_manager_method(method_name: String) -> void:
	if _manager == null:
		return
	if not is_instance_valid(_manager):
		return
	if not OS.is_debug_build() and not Engine.is_editor_hint():
		return

	var key := "%s:%d" % [method_name, _manager.get_instance_id()]
	if _missing_manager_method_warnings.has(key):
		return
	_missing_manager_method_warnings[key] = true

	var identifier := String(_manager.name)
	if _manager.is_inside_tree():
		identifier = String(_manager.get_path())

	push_warning("BaseECSSystem: Manager '%s' is missing required method '%s' (requested by system '%s')." % [
		String(identifier),
		method_name,
		String(name),
	])
