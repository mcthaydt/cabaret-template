@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_CheckpointComponent

const COMPONENT_TYPE := StringName("C_CheckpointComponent")
const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")

## Checkpoint Component (Phase 12.3b - T265)
##
## Marks a location as a checkpoint where the player can respawn after death.
## Unlike spawn points linked to doors, checkpoints are independent mid-scene markers.
##
## Usage:
## 1. Add C_CheckpointComponent to a Node3D in your scene (entity root E_* preferred)
## 2. Set checkpoint_id (unique ID) and spawn_point_id (where to spawn)
## 3. Optional: Assign `area_path` to an existing Area3D, otherwise this
##    component will auto-create an Area3D + CollisionShape3D using `settings`.
## 4. S_CheckpointSystem will detect player entry and update last_checkpoint
##
## Example (no authored children required):
##   CheckpointNode (Node3D)
##   └─ C_CheckpointComponent (checkpoint_id="cp_safe_room", spawn_point_id="sp_safe_room")
##      └─ (auto) Area3D + CollisionShape3D
##
## Integration:
## - S_CheckpointSystem queries for C_CheckpointComponent
## - On player collision: updates gameplay.last_checkpoint
## - M_SpawnManager.spawn_at_last_spawn() uses last_checkpoint > target_spawn_point > sp_default

## Unique identifier for this checkpoint (for debugging/save data)
@export var checkpoint_id: StringName = StringName("")

## Spawn point ID where player should respawn when using this checkpoint
@export var spawn_point_id: StringName = StringName("")

## Whether this checkpoint has been activated by the player
@export var is_activated: bool = false

## Timestamp when checkpoint was last activated (for debugging)
@export var last_activated_time: float = 0.0

## Optional: Provide an existing Area3D via node path. If empty, a new Area3D is created.
@export_node_path("Area3D") var area_path: NodePath

## Settings used to create/configure the trigger Area3D when not provided.
## Reused from scene triggers to keep volume configuration consistent.
@export var settings: RS_SceneTriggerSettings

var _area: Area3D = null
var _cached_settings: RS_SceneTriggerSettings = null

func _init() -> void:
	# Ensure consistent component type for ECS queries/registration
	component_type = COMPONENT_TYPE

func _ready() -> void:
	super._ready()

	# Validate configuration
	if checkpoint_id.is_empty():
		push_warning("C_CheckpointComponent: checkpoint_id is empty. Set a unique ID for this checkpoint.")

	if spawn_point_id.is_empty():
		push_error("C_CheckpointComponent: spawn_point_id is required. Player won't know where to spawn!")

	# Resolve or create Area3D so systems/controllers can rely on it.
	_resolve_or_create_area()

## Find Area3D child node (for validation)
func _find_area3d_child() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child as Area3D
	return null

## Find Area3D sibling node (alternative to child structure)
func _find_area3d_sibling() -> Area3D:
	var parent_node := get_parent()
	if parent_node == null:
		return null

	for sibling in parent_node.get_children():
		if sibling != self and sibling is Area3D:
			return sibling as Area3D
	return null

## Activate this checkpoint (called by S_CheckpointSystem)
func activate() -> void:
	is_activated = true
	last_activated_time = Time.get_ticks_msec() / 1000.0

## Public: Return the Area3D used for checkpoint detection (may be null early in _ready)
func get_trigger_area() -> Area3D:
	return _area

## Public: Enable/disable monitoring for this checkpoint's Area3D
func set_enabled(enabled: bool) -> void:
	if _area == null:
		return
	_area.monitoring = enabled
	_area.monitorable = enabled

## Internal: Resolve settings with defaults and cache
func _get_settings() -> RS_SceneTriggerSettings:
	if _cached_settings != null:
		return _cached_settings
	if settings == null:
		settings = RS_SceneTriggerSettings.new()
		settings.shape_type = RS_SceneTriggerSettings.ShapeType.CYLINDER
		settings.cyl_radius = 1.0
		settings.cyl_height = 2.0
		settings.box_size = Vector3(1.0, 2.0, 1.0)
		settings.local_offset = Vector3(0, 1.0, 0)
		settings.player_mask = 1
	_cached_settings = settings
	return _cached_settings

## Internal: Resolve or create the Area3D used by this checkpoint
func _resolve_or_create_area() -> void:
	# 1) Respect explicit path
	if not area_path.is_empty():
		_area = get_node_or_null(area_path) as Area3D
		if _area != null:
			_configure_area_geometry()
			return

	# 2) Look for authored child/sibling areas for backwards compatibility
	_area = _find_area3d_child()
	if _area == null:
		_area = _find_area3d_sibling()
	if _area != null:
		_configure_area_geometry()
		return

	# 3) Create a new Area3D as a sibling under the entity root (preferred)
	var parent_node := get_parent() as Node3D
	var host: Node
	if parent_node != null:
		host = parent_node
	else:
		host = self
	_area = Area3D.new()
	_area.name = "CheckpointArea"
	_area.collision_layer = 0
	_area.collision_mask = max(1, _get_settings().player_mask)
	host.call_deferred("add_child", _area)

	# Create collision shape based on settings
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.position = _get_settings().local_offset

	match _get_settings().shape_type:
		RS_SceneTriggerSettings.ShapeType.CYLINDER:
			var cyl := CylinderShape3D.new()
			cyl.radius = max(0.001, _get_settings().cyl_radius)
			cyl.height = max(0.001, _get_settings().cyl_height)
			shape.shape = cyl
		RS_SceneTriggerSettings.ShapeType.BOX:
			var box := BoxShape3D.new()
			box.size = _get_settings().box_size
			shape.shape = box
		_:
			var cyl_fallback := CylinderShape3D.new()
			cyl_fallback.radius = 1.0
			cyl_fallback.height = 2.0
			shape.shape = cyl_fallback

	_area.add_child(shape)
	# Ensure monitoring defaults
	_area.monitoring = true
	_area.monitorable = true
	_connect_area_signals()

## Internal: Adopt/normalize authored areas if present
func _configure_area_geometry() -> void:
	if _area == null:
		return
	_area.monitoring = true
	_area.monitorable = true
	# Respect authored shapes; only ensure mask if left at default
	if _area.collision_mask == 0:
		_area.collision_mask = max(1, _get_settings().player_mask)
	_connect_area_signals()

func _connect_area_signals() -> void:
	if _area == null:
		return
	if not _area.body_entered.is_connected(_on_area_body_entered):
		_area.body_entered.connect(_on_area_body_entered)
	if not _area.body_exited.is_connected(_on_area_body_exited):
		_area.body_exited.connect(_on_area_body_exited)

func _on_area_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_publish_zone_entered(body)

func _on_area_body_exited(__body: Node3D) -> void:
	pass

func _is_player(body: Node3D) -> bool:
	if body == null:
		return false
	var entity := ECS_UTILS.find_entity_root(body)
	if entity == null:
		return false
	var manager := get_manager()
	if manager == null:
		return false
	var comps: Dictionary = manager.get_components_for_entity(entity)
	return comps.has(PLAYER_TAG_COMPONENT) and comps.get(PLAYER_TAG_COMPONENT) != null

func _publish_zone_entered(body: Node3D) -> void:
	var entity_id := ECS_UTILS.get_entity_id(body)
	U_ECSEventBus.publish(U_ECSEventNames.EVENT_CHECKPOINT_ZONE_ENTERED, {
		"entity_id": entity_id,
		"checkpoint": self,
		"body": body,
		"spawn_point_id": spawn_point_id,
	})

## Cleanup: Disconnect Area3D signals to prevent leaks
func _exit_tree() -> void:
	if _area != null and is_instance_valid(_area):
		if _area.body_entered.is_connected(_on_area_body_entered):
			_area.body_entered.disconnect(_on_area_body_entered)
		if _area.body_exited.is_connected(_on_area_body_exited):
			_area.body_exited.disconnect(_on_area_body_exited)
