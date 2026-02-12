@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_RotateToInputSystem

## Phase 16: Dispatches rotation to state store

const ROTATE_TYPE := StringName("C_RotateToInputComponent")
const INPUT_TYPE := StringName("C_InputComponent")

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null

@export var debug_rotation_logging: bool = false
@export var debug_rotation_log_interval_frames: int = 30
@export var debug_rotation_log_entity_id: StringName = StringName("player")

var _last_debug_log_frame: int = -9999

func process_tick(delta: float) -> void:
	# Skip processing if game is paused
	# Use injected store if available (Phase 10B-8)
	var store: I_StateStore = null
	if state_store != null:
		store = state_store
	else:
		store = U_StateUtils.get_store(self)

	if store:
		var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
		if U_GameplaySelectors.get_is_paused(gameplay_state):
			return
	
	var manager := get_manager()
	if manager == null:
		return

	var entities := manager.query_entities(
		[
			ROTATE_TYPE,
			INPUT_TYPE,
		]
	)

	for entity_query in entities:
		var entity_id: StringName = entity_query.get_entity_id()
		var can_log := _can_debug_log(entity_id)

		var component: C_RotateToInputComponent = entity_query.get_component(ROTATE_TYPE)
		if component == null:
			continue

		var target := component.get_target_node()
		if target == null:
			if can_log:
				print("S_RotateToInputSystem: target missing. entity=%s path=%s" % [
					"%s" % [entity_id],
					"%s" % [component.target_node_path],
				])
			continue

		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if input_component == null:
			if can_log:
				print("S_RotateToInputSystem: input component missing. entity=%s" % ["%s" % [entity_id]])
			continue

		var move_vector := input_component.move_vector
		if move_vector.length() == 0.0:
			if can_log:
				print("S_RotateToInputSystem: move_vector zero. entity=%s yaw=%.2f" % [
					"%s" % [entity_id],
					rad_to_deg(target.global_rotation.y),
				])
			component.reset_rotation_state()
			continue

		var desired_direction := _get_desired_direction(move_vector, target)
		if desired_direction.length() == 0.0:
			continue

		var desired_yaw := atan2(-desired_direction.x, -desired_direction.z)
		var current_rotation := target.global_rotation
		if can_log:
			var velocity_yaw: float = 0.0
			var has_velocity: bool = false
			var body := target as CharacterBody3D
			if body != null:
				var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z)
				if horizontal.length() > 0.0:
					has_velocity = true
					var velocity_dir := horizontal.normalized()
					velocity_yaw = atan2(-velocity_dir.x, -velocity_dir.z)

			var camera_yaw: float = 0.0
			var has_camera: bool = false
			var camera: Camera3D = ECS_UTILS.get_active_camera(self)
			if camera != null:
				var cam_forward := -camera.global_transform.basis.z
				if cam_forward.length() > 0.0:
					has_camera = true
					camera_yaw = atan2(-cam_forward.x, -cam_forward.z)

			var velocity_label := "n/a"
			if has_velocity:
				velocity_label = "%.2f" % rad_to_deg(velocity_yaw)

			var camera_label := "n/a"
			if has_camera:
				camera_label = "%.2f" % rad_to_deg(camera_yaw)

			print("S_RotateToInputSystem: entity=%s move=%s desired_yaw=%.2f current_yaw=%.2f vel_yaw=%s cam_yaw=%s" % [
				"%s" % [entity_id],
				"%s" % [move_vector],
				rad_to_deg(desired_yaw),
				rad_to_deg(current_rotation.y),
				velocity_label,
				camera_label,
			])
		var max_turn: float = component.settings.max_turn_speed_degrees
		if max_turn <= 0.0:
			max_turn = component.settings.turn_speed_degrees
		var max_delta := deg_to_rad(max_turn) * delta

		if component.settings.use_second_order and component.settings.rotation_frequency > 0.0:
			_apply_second_order_rotation(component, target, desired_yaw, delta, max_delta)
		else:
			current_rotation.y = _move_toward_angle(current_rotation.y, desired_yaw, max_delta)
			target.global_rotation = current_rotation
			component.reset_rotation_state()
		
		# Phase 16: Update entity snapshot with rotation (Entity Coordination Pattern)
		if store:
			var snapshot_entity_id: String = _get_entity_id(target)
			if not snapshot_entity_id.is_empty():
				store.dispatch(U_EntityActions.update_entity_snapshot(snapshot_entity_id, {
					"rotation": target.rotation
				}))

func _move_toward_angle(current: float, target: float, max_delta: float) -> float:
	var difference = wrapf(target - current, -PI, PI)
	if abs(difference) <= max_delta:
		return target
	return current + clamp(difference, -max_delta, max_delta)

func _apply_second_order_rotation(component: C_RotateToInputComponent, target: Node3D, desired_yaw: float, delta: float, max_delta: float) -> void:
	var current_rotation := target.global_rotation
	var current_yaw := current_rotation.y
	var error := wrapf(desired_yaw - current_yaw, -PI, PI)
	var omega: float = TAU * component.settings.rotation_frequency
	if omega <= 0.0:
		component.reset_rotation_state()
		return

	var damping: float = max(component.settings.rotation_damping, 0.0)
	var velocity: float = component.get_rotation_velocity()
	var accel: float = (omega * omega * error) - (2.0 * damping * omega * velocity)
	velocity += accel * delta
	var max_speed := INF
	if max_delta > 0.0 and delta > 0.0:
		max_speed = max_delta / delta
	if max_speed != INF:
		velocity = clamp(velocity, -max_speed, max_speed)
	var delta_yaw := velocity * delta
	if sign(delta_yaw) == sign(error) and abs(delta_yaw) > abs(error) and delta > 0.0:
		delta_yaw = error
		velocity = delta_yaw / delta
	current_yaw += delta_yaw
	component.set_rotation_velocity(velocity)
	current_rotation.y = wrapf(current_yaw, -PI, PI)
	target.global_rotation = current_rotation

func _get_desired_direction(move_vector: Vector2, target: Node3D) -> Vector3:
	if move_vector.length() == 0.0:
		return Vector3.ZERO

	var camera: Camera3D = ECS_UTILS.get_active_camera(self)
	if camera == null:
		var raw_direction := Vector3(move_vector.x, 0.0, move_vector.y)
		if raw_direction.length() == 0.0:
			return Vector3.ZERO
		return raw_direction.normalized()

	var up_dir := Vector3.UP
	var body := target as CharacterBody3D
	if body != null:
		up_dir = body.up_direction
		if up_dir.length() == 0.0:
			up_dir = Vector3.UP

	var cam_forward := -camera.global_transform.basis.z
	cam_forward = _project_onto_plane(cam_forward, up_dir)
	if cam_forward.length() == 0.0:
		cam_forward = _project_onto_plane(Vector3.FORWARD, up_dir)
	cam_forward = cam_forward.normalized()

	var cam_right := camera.global_transform.basis.x
	cam_right = _project_onto_plane(cam_right, up_dir)
	if cam_right.length() == 0.0:
		cam_right = cam_forward.cross(up_dir)
	cam_right = cam_right.normalized()

	var forward_input: float = -move_vector.y
	var desired_dir: Vector3 = (cam_right * move_vector.x) + (cam_forward * forward_input)
	if desired_dir.length() == 0.0:
		return Vector3.ZERO
	return desired_dir.normalized()

func _project_onto_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	var normal := plane_normal.normalized()
	if normal.length() == 0.0:
		return Vector3.ZERO
	return vector - normal * vector.dot(normal)

## Phase 16: Get entity ID from node for state coordination
func _get_entity_id(node: Node) -> String:
	if node == null:
		return ""
	var entity_root: Node = ECS_UTILS.find_entity_root(node, true)
	if entity_root != null:
		return String(ECS_UTILS.get_entity_id(entity_root))
	return ""

func _can_debug_log(entity_id: StringName) -> bool:
	if not debug_rotation_logging:
		return false
	if debug_rotation_log_entity_id != StringName() and entity_id != debug_rotation_log_entity_id:
		return false
	if debug_rotation_log_interval_frames <= 0:
		return true
	var frame: int = Engine.get_physics_frames()
	if frame - _last_debug_log_frame < debug_rotation_log_interval_frames:
		return false
	_last_debug_log_frame = frame
	return true
