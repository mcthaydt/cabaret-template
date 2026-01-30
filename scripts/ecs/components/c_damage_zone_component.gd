@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_DamageZoneComponent

## Damage zone component using Area3D volumes.
## Tracks overlapping bodies so S_DamageSystem can apply damage ticks.

const COMPONENT_TYPE := StringName("C_DamageZoneComponent")
const EVENT_DAMAGE_ZONE_ENTERED := StringName("damage_zone_entered")
const EVENT_DAMAGE_ZONE_EXITED := StringName("damage_zone_exited")

@export var damage_amount: float = 25.0
@export var is_instant_death: bool = false
@export var damage_cooldown: float = 1.0
@export var collision_layer_mask: int = 1
@export_node_path("Area3D") var area_path: NodePath

var _area: Area3D = null
var _bodies_in_zone: Array[Node3D] = []

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	super._ready()
	_resolve_area()

func _exit_tree() -> void:
	if _area != null and is_instance_valid(_area):
		if _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.disconnect(_on_body_entered)
		if _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.disconnect(_on_body_exited)
	_area = null
	_bodies_in_zone.clear()

func _resolve_area() -> void:
	if not area_path.is_empty():
		_area = get_node_or_null(area_path) as Area3D

	if _area == null:
		_area = _find_area_child()

	if _area == null:
		_area = Area3D.new()
		_area.name = "DamageArea"
		add_child(_area)

	_configure_area()

func _find_area_child() -> Area3D:
	for child in get_children():
		var area := child as Area3D
		if area != null:
			return area
	return null

func _configure_area() -> void:
	if _area == null:
		return
	_area.monitoring = true
	_area.monitorable = true
	_area.collision_layer = 0
	_area.collision_mask = collision_layer_mask
	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)
	if not _area.body_exited.is_connected(_on_body_exited):
		_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body == null:
		return
	if not _bodies_in_zone.has(body):
		_bodies_in_zone.append(body)
		_publish_entered(body)

func _on_body_exited(body: Node3D) -> void:
	if body == null:
		return
	if _bodies_in_zone.has(body):
		_bodies_in_zone.erase(body)
		_publish_exited(body)

func get_damage_area() -> Area3D:
	return _area

func get_bodies_in_zone() -> Array:
	return _bodies_in_zone.duplicate()

func set_area_path(path: NodePath) -> void:
	area_path = path
	if is_inside_tree():
		_resolve_area()

func _publish_entered(body: Node3D) -> void:
	U_ECSEventBus.publish(EVENT_DAMAGE_ZONE_ENTERED, {
		"zone": self,
		"zone_id": _get_zone_id(),
		"body": body,
		"damage_per_second": damage_amount,
		"is_instant_death": is_instant_death,
	})

func _publish_exited(body: Node3D) -> void:
	U_ECSEventBus.publish(EVENT_DAMAGE_ZONE_EXITED, {
		"zone": self,
		"zone_id": _get_zone_id(),
		"body": body,
		"is_instant_death": is_instant_death,
	})

func _get_zone_id() -> StringName:
	return ECS_UTILS.get_entity_id(self)
