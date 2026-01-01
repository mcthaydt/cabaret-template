extends Node
class_name U_DebugVisualAids

const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DEBUG_SELECTORS := preload("res://scripts/state/selectors/u_debug_selectors.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const BASE_VOLUME_CONTROLLER := preload("res://scripts/gameplay/base_volume_controller.gd")

const FEATURE_COLLISION_SHAPES := StringName("collision_shapes")
const FEATURE_SPAWN_POINTS := StringName("spawn_points")
const FEATURE_TRIGGER_ZONES := StringName("trigger_zones")
const FEATURE_ENTITY_LABELS := StringName("entity_labels")

const META_DEBUG_VISUAL_AIDS := StringName("_debug_visual_aids")

const SPAWN_POINT_CONTAINER_NAME := "SP_SpawnPoints"

const COLOR_COLLISION := Color(0.25, 0.85, 1.0, 0.9)
const COLOR_SPAWN := Color(0.25, 1.0, 0.35, 0.9)
const COLOR_TRIGGER := Color(1.0, 0.9, 0.25, 0.9)
const COLOR_LABEL := Color(1.0, 1.0, 1.0, 1.0)

const LABEL_OFFSET := Vector3(0.0, 2.0, 0.0)
const SPAWN_MARKER_OFFSET := Vector3(0.0, 0.5, 0.0)

const ENTITY_LABEL_REFRESH_INTERVAL_SEC := 0.5

@export var state_store: I_StateStore = null

var _store: I_StateStore = null
var _is_transitioning: bool = false
var _materials: Dictionary = {}
var _entity_label_time_accum: float = 0.0
var _entity_labels_by_id: Dictionary = {}
var _feature_root: Node3D = null

var _feature_enabled: Dictionary = {
	FEATURE_COLLISION_SHAPES: false,
	FEATURE_SPAWN_POINTS: false,
	FEATURE_TRIGGER_ZONES: false,
	FEATURE_ENTITY_LABELS: false,
}

var _tracked_nodes: Dictionary = {
	FEATURE_COLLISION_SHAPES: [],
	FEATURE_SPAWN_POINTS: [],
	FEATURE_TRIGGER_ZONES: [],
	FEATURE_ENTITY_LABELS: [],
}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS

	await get_tree().process_frame
	_store = state_store if state_store != null else U_STATE_UTILS.get_store(self)
	if _store == null:
		push_warning("U_DebugVisualAids: No state store found; visual aids disabled")
		return

	if _store.has_signal("slice_updated"):
		_store.slice_updated.connect(_on_slice_updated)
	if _store.has_signal("action_dispatched"):
		_store.action_dispatched.connect(_on_action_dispatched)

	_refresh_from_state(_store.get_state())


func _exit_tree() -> void:
	_clear_all_tracked_nodes(true)
	_entity_labels_by_id.clear()
	_feature_root = null

func _process(delta: float) -> void:
	if not bool(_feature_enabled.get(FEATURE_ENTITY_LABELS, false)):
		_entity_label_time_accum = 0.0
		return
	if _is_transitioning:
		return

	_entity_label_time_accum += delta
	if _entity_label_time_accum < ENTITY_LABEL_REFRESH_INTERVAL_SEC:
		return
	_entity_label_time_accum = 0.0
	_sync_entity_id_labels()


func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("debug") or _store == null:
		return
	_refresh_from_state(_store.get_state())


func _on_action_dispatched(action: Dictionary) -> void:
	var raw_type: Variant = action.get("type", StringName(""))
	var action_type: StringName = raw_type if raw_type is StringName else StringName(str(raw_type))

	if action_type == U_SCENE_ACTIONS.ACTION_TRANSITION_STARTED:
		_is_transitioning = true
		_clear_all_tracked_nodes(false)
		_entity_labels_by_id.clear()
		_feature_root = null
	elif action_type == U_SCENE_ACTIONS.ACTION_TRANSITION_COMPLETED:
		_is_transitioning = false
		_rebuild_enabled_features()


func _refresh_from_state(state: Dictionary) -> void:
	_set_feature_enabled(FEATURE_COLLISION_SHAPES, U_DEBUG_SELECTORS.is_showing_collision_shapes(state))
	_set_feature_enabled(FEATURE_SPAWN_POINTS, U_DEBUG_SELECTORS.is_showing_spawn_points(state))
	_set_feature_enabled(FEATURE_TRIGGER_ZONES, U_DEBUG_SELECTORS.is_showing_trigger_zones(state))
	_set_feature_enabled(FEATURE_ENTITY_LABELS, U_DEBUG_SELECTORS.is_showing_entity_labels(state))


func _set_feature_enabled(feature_id: StringName, enabled: bool) -> void:
	var previous: bool = bool(_feature_enabled.get(feature_id, false))
	if previous == enabled:
		return

	_feature_enabled[feature_id] = enabled

	if not enabled:
		_clear_feature_nodes(feature_id, true)
		return

	if _is_transitioning:
		return

	_rebuild_feature(feature_id)


func _rebuild_enabled_features() -> void:
	for feature_id in _feature_enabled.keys():
		if bool(_feature_enabled.get(feature_id, false)):
			_rebuild_feature(feature_id)


func _rebuild_feature(feature_id: StringName) -> void:
	match feature_id:
		FEATURE_COLLISION_SHAPES:
			_clear_feature_nodes(feature_id, true)
			_build_collision_shape_visuals()
		FEATURE_SPAWN_POINTS:
			_clear_feature_nodes(feature_id, true)
			_build_spawn_point_markers()
		FEATURE_TRIGGER_ZONES:
			_clear_feature_nodes(feature_id, true)
			_build_trigger_zone_outlines()
		FEATURE_ENTITY_LABELS:
			_sync_entity_id_labels()
		_:
			return


func track_node(feature_id: StringName, node: Node) -> void:
	if node == null:
		return
	if not _tracked_nodes.has(feature_id):
		_tracked_nodes[feature_id] = []
	_tracked_nodes[feature_id].append(node)


func _clear_all_tracked_nodes(should_queue_free: bool) -> void:
	for feature_id in _tracked_nodes.keys():
		_clear_feature_nodes(feature_id, should_queue_free)


func _clear_feature_nodes(feature_id: StringName, should_queue_free: bool) -> void:
	var nodes: Array = _tracked_nodes.get(feature_id, [])
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if should_queue_free and node.is_inside_tree():
			node.queue_free()
	_tracked_nodes[feature_id] = []
	if feature_id == FEATURE_ENTITY_LABELS:
		_entity_labels_by_id.clear()
	if feature_id == FEATURE_SPAWN_POINTS:
		_maybe_cleanup_feature_root()


func _build_collision_shape_visuals() -> void:
	var root := _get_active_scene_root()
	if root == null:
		return

	var collision_shapes: Array = root.find_children("", "CollisionShape3D", true, false)
	for entry in collision_shapes:
		var collision_shape := entry as CollisionShape3D
		if collision_shape == null:
			continue
		# Area3D shapes are treated as "trigger zones" and should be controlled by the
		# dedicated trigger toggle instead of the general collision toggle.
		if collision_shape.get_parent() is Area3D:
			continue
		if _has_child_named(collision_shape, "MI_DebugCollisionShape"):
			continue

		var shape: Shape3D = collision_shape.shape
		if shape == null:
			continue

		var line_points := _build_wireframe_points_for_shape(shape)
		if line_points.is_empty():
			continue

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MI_DebugCollisionShape"
		mesh_instance.mesh = _build_line_mesh(line_points, _get_material(FEATURE_COLLISION_SHAPES))
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.set_meta(META_DEBUG_VISUAL_AIDS, true)
		collision_shape.add_child(mesh_instance)
		track_node(FEATURE_COLLISION_SHAPES, mesh_instance)


func _build_spawn_point_markers() -> void:
	var root := _get_active_scene_root()
	if root == null:
		return

	var spawn_container := root.get_node_or_null("Entities/%s" % SPAWN_POINT_CONTAINER_NAME) as Node3D
	if spawn_container == null:
		spawn_container = root.find_child(SPAWN_POINT_CONTAINER_NAME, true, false) as Node3D
	if spawn_container == null:
		return

	var feature_root := _get_or_create_feature_root()
	if feature_root == null:
		return

	for child in spawn_container.get_children():
		var spawn_point := child as Node3D
		if spawn_point == null:
			continue
		if not String(spawn_point.name).begins_with("sp_"):
			continue

		var marker_root := Node3D.new()
		marker_root.name = "SO_DebugSpawnPoint_%s" % String(spawn_point.name)
		marker_root.set_meta(META_DEBUG_VISUAL_AIDS, true)
		feature_root.add_child(marker_root)
		marker_root.global_position = spawn_point.global_position + SPAWN_MARKER_OFFSET
		track_node(FEATURE_SPAWN_POINTS, marker_root)

		var sphere := MeshInstance3D.new()
		sphere.name = "MI_DebugSpawnSphere"
		var mesh := SphereMesh.new()
		mesh.radius = 0.15
		mesh.height = 0.3
		sphere.mesh = mesh
		sphere.material_override = _get_material(FEATURE_SPAWN_POINTS)
		sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sphere.set_meta(META_DEBUG_VISUAL_AIDS, true)
		marker_root.add_child(sphere)

		var label := Label3D.new()
		label.name = "Label3D_DebugSpawnId"
		label.text = String(spawn_point.name)
		label.font_size = 20
		label.outline_size = 4
		label.modulate = COLOR_LABEL
		label.position = Vector3(0.0, 0.35, 0.0)
		label.set_meta(META_DEBUG_VISUAL_AIDS, true)
		marker_root.add_child(label)


func _build_trigger_zone_outlines() -> void:
	var root := _get_active_scene_root()
	if root == null:
		return

	var controllers: Array = root.find_children("", "BaseVolumeController", true, false)
	for entry in controllers:
		var controller := entry as BaseVolumeController
		if controller == null:
			continue

		var area := controller.get_trigger_area()
		if area == null:
			if controller.has_signal("trigger_area_ready"):
				var call := Callable(self, "_on_trigger_controller_area_ready").bind(controller)
				if not controller.trigger_area_ready.is_connected(call):
					controller.trigger_area_ready.connect(call)
			continue

		_create_trigger_outline_for_area(area)


func _on_trigger_controller_area_ready(_area: Area3D, controller: BaseVolumeController) -> void:
	if controller == null or not is_instance_valid(controller):
		return
	if not bool(_feature_enabled.get(FEATURE_TRIGGER_ZONES, false)):
		return
	if _is_transitioning:
		return

	var area := controller.get_trigger_area()
	if area == null:
		return
	_create_trigger_outline_for_area(area)


func _create_trigger_outline_for_area(area: Area3D) -> void:
	if area == null or not is_instance_valid(area):
		return

	var collision_shape: CollisionShape3D = null
	for child in area.get_children():
		if child is CollisionShape3D:
			collision_shape = child as CollisionShape3D
			break

	if collision_shape == null:
		return
	if _has_child_named(collision_shape, "MI_DebugTriggerZone"):
		return

	var shape: Shape3D = collision_shape.shape
	if shape == null:
		return

	var line_points := _build_wireframe_points_for_shape(shape)
	if line_points.is_empty():
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MI_DebugTriggerZone"
	mesh_instance.mesh = _build_line_mesh(line_points, _get_material(FEATURE_TRIGGER_ZONES))
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta(META_DEBUG_VISUAL_AIDS, true)
	collision_shape.add_child(mesh_instance)
	track_node(FEATURE_TRIGGER_ZONES, mesh_instance)


func _sync_entity_id_labels() -> void:
	var root := _get_active_scene_root()
	if root == null:
		return

	var manager := U_ECS_UTILS.get_manager(root)
	if manager == null:
		return
	if not manager.has_method("get_all_entity_ids") or not manager.has_method("get_entity_by_id"):
		return

	var active_ids: Dictionary = {}
	var entity_ids: Array = manager.get_all_entity_ids()
	for id_variant in entity_ids:
		var entity_id := id_variant as StringName
		if entity_id == null:
			continue
		active_ids[entity_id] = true

		var entity := manager.get_entity_by_id(entity_id) as Node3D
		if entity == null or not is_instance_valid(entity):
			continue

		var existing_label: Label3D = _entity_labels_by_id.get(entity_id, null) as Label3D
		if existing_label != null and is_instance_valid(existing_label):
			if existing_label.get_parent() != entity:
				existing_label.reparent(entity)
			existing_label.position = LABEL_OFFSET
			continue

		var child_existing := entity.get_node_or_null("Label3D_DebugEntityId") as Label3D
		if child_existing != null and is_instance_valid(child_existing):
			child_existing.text = String(entity_id)
			child_existing.position = LABEL_OFFSET
			_entity_labels_by_id[entity_id] = child_existing
			if not _tracked_nodes.has(FEATURE_ENTITY_LABELS) or not _tracked_nodes[FEATURE_ENTITY_LABELS].has(child_existing):
				track_node(FEATURE_ENTITY_LABELS, child_existing)
			continue

		var label := Label3D.new()
		label.name = "Label3D_DebugEntityId"
		label.text = String(entity_id)
		label.font_size = 18
		label.outline_size = 4
		label.modulate = COLOR_LABEL
		label.position = LABEL_OFFSET
		label.set_meta(META_DEBUG_VISUAL_AIDS, true)
		entity.add_child(label)
		_entity_labels_by_id[entity_id] = label
		track_node(FEATURE_ENTITY_LABELS, label)

	var tracked_ids: Array = _entity_labels_by_id.keys()
	for tracked_id in tracked_ids:
		if active_ids.has(tracked_id):
			continue
		var label_node: Label3D = _entity_labels_by_id[tracked_id] as Label3D
		if label_node != null and is_instance_valid(label_node) and label_node.is_inside_tree():
			label_node.queue_free()
		_entity_labels_by_id.erase(tracked_id)


func _get_active_scene_root() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var current: Node = tree.current_scene
	if current == null:
		return null

	var container := current.find_child("ActiveSceneContainer", true, false)
	if container != null:
		if container.get_child_count() > 0:
			return container.get_child(0)
		return container

	if current.name == "ActiveSceneContainer":
		if current.get_child_count() > 0:
			return current.get_child(0)
		return current

	return current


func _get_or_create_feature_root() -> Node3D:
	var root := _get_active_scene_root()
	if root == null:
		return null

	if _feature_root != null and is_instance_valid(_feature_root):
		return _feature_root

	var existing := root.get_node_or_null("SO_DebugVisualAids") as Node3D
	if existing != null and is_instance_valid(existing):
		_feature_root = existing
		return _feature_root

	var created := Node3D.new()
	created.name = "SO_DebugVisualAids"
	created.set_meta(META_DEBUG_VISUAL_AIDS, true)
	root.add_child(created)
	_feature_root = created
	return _feature_root


func _maybe_cleanup_feature_root() -> void:
	if _feature_root == null or not is_instance_valid(_feature_root):
		_feature_root = null
		return
	if _feature_root.get_child_count() > 0:
		return
	_feature_root.queue_free()
	_feature_root = null


func _has_child_named(parent: Node, child_name: String) -> bool:
	if parent == null:
		return false
	for child in parent.get_children():
		if child != null and String(child.name) == child_name:
			return true
	return false


func _get_material(feature_id: StringName) -> StandardMaterial3D:
	if _materials.has(feature_id):
		return _materials[feature_id] as StandardMaterial3D

	var color := COLOR_COLLISION
	match feature_id:
		FEATURE_COLLISION_SHAPES:
			color = COLOR_COLLISION
		FEATURE_SPAWN_POINTS:
			color = COLOR_SPAWN
		FEATURE_TRIGGER_ZONES:
			color = COLOR_TRIGGER
		_:
			color = COLOR_COLLISION

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	_materials[feature_id] = material
	return material


func _build_line_mesh(points: PackedVector3Array, material: Material) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for point in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh


func _build_wireframe_points_for_shape(shape: Shape3D) -> PackedVector3Array:
	if shape is BoxShape3D:
		return _wireframe_box(shape as BoxShape3D)
	if shape is SphereShape3D:
		return _wireframe_sphere(shape as SphereShape3D)
	if shape is CylinderShape3D:
		return _wireframe_cylinder(shape as CylinderShape3D)
	if shape is CapsuleShape3D:
		return _wireframe_capsule(shape as CapsuleShape3D)
	return PackedVector3Array()


func _wireframe_box(shape: BoxShape3D) -> PackedVector3Array:
	var half: Vector3 = shape.size * 0.5
	var corners := [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(half.x, half.y, half.z),
		Vector3(-half.x, half.y, half.z),
	]

	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]

	var points := PackedVector3Array()
	for e in edges:
		points.append(corners[e[0]])
		points.append(corners[e[1]])
	return points


func _wireframe_sphere(shape: SphereShape3D, segments: int = 16) -> PackedVector3Array:
	var points := PackedVector3Array()
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.FORWARD, segments) # XZ
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.UP, segments) # XY
	_append_circle(points, shape.radius, Vector3.UP, Vector3.FORWARD, segments) # YZ
	return points


func _wireframe_cylinder(shape: CylinderShape3D, segments: int = 16) -> PackedVector3Array:
	var points := PackedVector3Array()
	var half_h := shape.height * 0.5
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.FORWARD, segments, half_h) # top
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.FORWARD, segments, -half_h) # bottom

	var spoke_segments := 8
	for i in range(spoke_segments):
		var t: float = float(i) / float(spoke_segments)
		var ang: float = t * TAU
		var x := cos(ang) * shape.radius
		var z := sin(ang) * shape.radius
		points.append(Vector3(x, -half_h, z))
		points.append(Vector3(x, half_h, z))

	return points


func _wireframe_capsule(shape: CapsuleShape3D, segments: int = 16) -> PackedVector3Array:
	var points := PackedVector3Array()
	var half_h := shape.height * 0.5
	var cylinder_half := maxf(0.0, half_h - shape.radius)
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.FORWARD, segments, cylinder_half)
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.FORWARD, segments, -cylinder_half)
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.UP, segments, cylinder_half)
	_append_circle(points, shape.radius, Vector3.RIGHT, Vector3.UP, segments, -cylinder_half)
	_append_circle(points, shape.radius, Vector3.UP, Vector3.FORWARD, segments, cylinder_half)
	_append_circle(points, shape.radius, Vector3.UP, Vector3.FORWARD, segments, -cylinder_half)
	return points


func _append_circle(points: PackedVector3Array, radius: float, axis_a: Vector3, axis_b: Vector3, segments: int, y_offset: float = 0.0) -> void:
	var prev: Vector3 = Vector3.ZERO
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var ang: float = t * TAU
		var p := axis_a * (cos(ang) * radius) + axis_b * (sin(ang) * radius)
		p.y += y_offset
		if i > 0:
			points.append(prev)
			points.append(p)
		prev = p
