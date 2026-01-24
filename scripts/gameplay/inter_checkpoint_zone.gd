extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_CheckpointZone

const C_CheckpointComponent := preload("res://scripts/ecs/components/c_checkpoint_component.gd")

@export var component_name: StringName = StringName("C_CheckpointComponent")

var component_factory: Callable

var _checkpoint_id: StringName = StringName("")
@export var checkpoint_id: StringName:
	get:
		return _checkpoint_id
	set(value):
		_checkpoint_id = value
		_apply_component_config()

var _spawn_point_id: StringName = StringName("")
@export var spawn_point_id: StringName:
	get:
		return _spawn_point_id
	set(value):
		_spawn_point_id = value
		_apply_component_config()

var _component: C_CheckpointComponent = null

func _ready() -> void:
	super._ready()
	trigger_area_ready.connect(_on_controller_area_ready)
	var area := get_trigger_area()
	if area != null:
		_on_controller_area_ready(area)

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
		push_error("Inter_CheckpointZone: Unable to instantiate C_CheckpointComponent.")
		return

	instance.name = _resolve_component_name()
	var provisional_path := _build_provisional_area_path(area)
	if not provisional_path.is_empty():
		instance.area_path = provisional_path
	instance.checkpoint_id = _checkpoint_id
	instance.spawn_point_id = _spawn_point_id
	if settings != null:
		settings.ignore_initial_overlap = false
		instance.settings = settings

	add_child(instance)
	_component = instance
	_update_component_area_path()
	_component._resolve_or_create_area()

func _instantiate_component() -> C_CheckpointComponent:
	if component_factory != null and component_factory.is_valid():
		var created: Variant = component_factory.call()
		if created is C_CheckpointComponent:
			return created as C_CheckpointComponent
		push_warning("Inter_CheckpointZone: component_factory returned incompatible instance.")
	return C_CheckpointComponent.new()

func _resolve_component_name() -> String:
	if String(component_name).is_empty():
		return "C_CheckpointComponent"
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

	_component.checkpoint_id = _checkpoint_id
	_component.spawn_point_id = _spawn_point_id
	if settings != null:
		settings.ignore_initial_overlap = false
		_component.settings = settings

	_update_component_area_path()
	_component.set_enabled(is_enabled())

func refresh_volume_from_settings() -> void:
	super.refresh_volume_from_settings()
	_apply_component_config()

func _on_enabled_state_changed(enabled: bool) -> void:
	super._on_enabled_state_changed(enabled)
	if _component != null and is_instance_valid(_component):
		_component.set_enabled(enabled)
