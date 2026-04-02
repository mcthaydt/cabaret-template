@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AINavigationSystem

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

const BRAIN_COMPONENT_TYPE := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
const INPUT_COMPONENT_TYPE := C_INPUT_COMPONENT.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const TARGET_STATE_KEY := "ai_move_target"
const TARGET_REACHED_EPSILON := 0.05

func _init() -> void:
	execution_priority = -5

func process_tick(_delta: float) -> void:
	var entities: Array = query_entities([
		BRAIN_COMPONENT_TYPE,
		INPUT_COMPONENT_TYPE,
		MOVEMENT_COMPONENT_TYPE,
	])
	if entities.is_empty():
		return

	var camera: Camera3D = U_ECS_UTILS.get_active_camera(self)
	var has_camera_basis: bool = camera != null and is_instance_valid(camera)
	var camera_right: Vector3 = Vector3.ZERO
	var camera_forward: Vector3 = Vector3.ZERO
	if has_camera_basis:
		camera_right = _project_onto_plane(camera.global_transform.basis.x, Vector3.UP)
		camera_forward = _project_onto_plane(-camera.global_transform.basis.z, Vector3.UP)
		if camera_right.length() > 0.0:
			camera_right = camera_right.normalized()
		if camera_forward.length() > 0.0:
			camera_forward = camera_forward.normalized()
		has_camera_basis = camera_right.length() > 0.0 and camera_forward.length() > 0.0

	for entity_query_variant in entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue

		var input_component_variant: Variant = entity_query.call("get_component", INPUT_COMPONENT_TYPE)
		if not (input_component_variant is C_InputComponent):
			continue
		var input_component: C_InputComponent = input_component_variant as C_InputComponent

		var brain_component_variant: Variant = entity_query.call("get_component", BRAIN_COMPONENT_TYPE)
		if brain_component_variant == null or not (brain_component_variant is Object):
			input_component.set_move_vector(Vector2.ZERO)
			continue

		var task_state_variant: Variant = (brain_component_variant as Object).get("task_state")
		if not (task_state_variant is Dictionary):
			input_component.set_move_vector(Vector2.ZERO)
			continue
		var task_state: Dictionary = task_state_variant as Dictionary

		var target_variant: Variant = task_state.get(TARGET_STATE_KEY, null)
		if not (target_variant is Vector3):
			input_component.set_move_vector(Vector2.ZERO)
			continue
		var target_position: Vector3 = target_variant as Vector3

		var movement_component_variant: Variant = entity_query.call("get_component", MOVEMENT_COMPONENT_TYPE)
		if not (movement_component_variant is C_MovementComponent):
			input_component.set_move_vector(Vector2.ZERO)
			continue
		var movement_component: C_MovementComponent = movement_component_variant as C_MovementComponent

		var body: CharacterBody3D = movement_component.get_character_body()
		if body == null:
			continue

		var current_position: Vector3 = body.global_position
		var delta_xz := Vector2(target_position.x - current_position.x, target_position.z - current_position.z)
		if delta_xz.length() <= TARGET_REACHED_EPSILON:
			input_component.set_move_vector(Vector2.ZERO)
			continue

		var world_direction := Vector3(delta_xz.x, 0.0, delta_xz.y).normalized()
		var move_vector: Vector2 = _world_direction_to_input(world_direction, has_camera_basis, camera_right, camera_forward)
		input_component.set_move_vector(move_vector)

func _world_direction_to_input(
	world_direction: Vector3,
	has_camera_basis: bool,
	camera_right: Vector3,
	camera_forward: Vector3
) -> Vector2:
	if has_camera_basis:
		var camera_relative := Vector2(
			world_direction.dot(camera_right),
			-world_direction.dot(camera_forward)
		)
		if camera_relative.length() > 1.0:
			camera_relative = camera_relative.normalized()
		return camera_relative

	var direct_mapping := Vector2(world_direction.x, world_direction.z)
	if direct_mapping.length() > 1.0:
		direct_mapping = direct_mapping.normalized()
	return direct_mapping

func _project_onto_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	var normal: Vector3 = plane_normal
	if normal.length() == 0.0:
		return Vector3.ZERO
	normal = normal.normalized()
	return vector - normal * vector.dot(normal)
