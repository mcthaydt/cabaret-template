extends RefCounted
class_name U_VCamRuntimeContext

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")
const U_NODE_FIND := preload("res://scripts/utils/ecs/u_node_find.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const C_MOVEMENT_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_CHARACTER_STATE_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_character_state_component.gd")

func resolve_follow_target(component: C_VCamComponent, ecs_manager: I_ECSManager, report_issue: Callable = Callable()) -> Node3D:
	if component == null:
		return null

	var node_target: Node3D = component.get_follow_target()
	if node_target != null and is_instance_valid(node_target):
		return node_target

	if ecs_manager == null:
		return null

	if component.follow_target_entity_id != StringName(""):
		var entity_target: Node = ecs_manager.get_entity_by_id(component.follow_target_entity_id)
		var resolved_entity_target: Node3D = _resolve_entity_target(entity_target)
		if resolved_entity_target != null:
			return resolved_entity_target

	if component.follow_target_tag == StringName(""):
		return null

	var tagged_entities: Array[Node] = ecs_manager.get_entities_by_tag(component.follow_target_tag)
	if tagged_entities.is_empty():
		return null

	var valid_targets: Array[Node3D] = []
	for entity in tagged_entities:
		var resolved: Node3D = _resolve_entity_target(entity)
		if resolved == null:
			continue
		valid_targets.append(resolved)

	if valid_targets.is_empty():
		return null
	if valid_targets.size() > 1 and report_issue.is_valid():
		report_issue.call(
			"follow_target_tag '%s' resolved multiple entities; using first match" % String(component.follow_target_tag)
		)
	return valid_targets[0]

func resolve_look_ahead_movement_velocity(follow_target: Node3D, store: I_StateStore) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var entity: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity != null and is_instance_valid(entity):
		var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity)
		var state_velocity: Dictionary = _read_gameplay_entity_velocity(entity_id, store)
		if bool(state_velocity.get("has_velocity", false)):
			return state_velocity

		var movement_velocity: Dictionary = _read_entity_movement_component_velocity(entity)
		if bool(movement_velocity.get("has_velocity", false)):
			return movement_velocity

		var body_velocity: Dictionary = _read_entity_character_body_velocity(entity)
		if bool(body_velocity.get("has_velocity", false)):
			return body_velocity

	return _read_character_body_velocity(follow_target)

func resolve_follow_target_grounded_state(
	follow_target: Node3D,
	store: I_StateStore
) -> bool:
	if follow_target == null or not is_instance_valid(follow_target):
		return false

	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity_root != null and is_instance_valid(entity_root):
		var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
		var state_grounded: Dictionary = _read_gameplay_entity_is_on_floor(entity_id, store)
		if bool(state_grounded.get("has_value", false)):
			return bool(state_grounded.get("is_on_floor", false))

		var character_state: Node = _find_node_with_script(entity_root, C_CHARACTER_STATE_COMPONENT_SCRIPT)
		if character_state != null and U_RuleUtils.object_has_property(character_state, "is_grounded"):
			var grounded_variant: Variant = character_state.get("is_grounded")
			if grounded_variant is bool:
				return grounded_variant as bool
			if grounded_variant is int:
				return int(grounded_variant) != 0

	var body: CharacterBody3D = U_NODE_FIND.find_character_body_recursive(follow_target)
	if body == null or not is_instance_valid(body):
		return false
	return body.is_on_floor()

func probe_ground_reference_height(follow_target: Node3D, max_distance: float) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {"valid": false, "height": 0.0}
	if max_distance <= 0.0:
		return {"valid": false, "height": follow_target.global_position.y}

	var fallback_height: float = follow_target.global_position.y
	var world: World3D = follow_target.get_world_3d()
	if world == null:
		return {"valid": true, "height": fallback_height}
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		return {"valid": true, "height": fallback_height}

	var ray_from: Vector3 = follow_target.global_position + (Vector3.UP * 0.1)
	var ray_to: Vector3 = ray_from + (Vector3.DOWN * max_distance)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	var exclude_rids: Array[RID] = []
	if entity_root != null and is_instance_valid(entity_root):
		var entity_collision := entity_root as CollisionObject3D
		if entity_collision != null:
			exclude_rids.append(entity_collision.get_rid())
	var follow_collision := follow_target as CollisionObject3D
	if follow_collision != null:
		var follow_rid: RID = follow_collision.get_rid()
		if not exclude_rids.has(follow_rid):
			exclude_rids.append(follow_rid)
	if exclude_rids.is_empty():
		var follow_body: CharacterBody3D = U_NODE_FIND.find_character_body_recursive(follow_target)
		if follow_body != null and is_instance_valid(follow_body):
			exclude_rids.append(follow_body.get_rid())
	query.exclude = exclude_rids

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {"valid": true, "height": fallback_height}
	var hit_position_variant: Variant = hit.get("position", Vector3.ZERO)
	if not (hit_position_variant is Vector3):
		return {"valid": true, "height": fallback_height}
	var hit_position := hit_position_variant as Vector3
	return {"valid": true, "height": hit_position.y}

func resolve_projection_camera(owner: Node) -> Camera3D:
	var camera_manager_service := U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager")) as I_CAMERA_MANAGER
	if camera_manager_service != null and is_instance_valid(camera_manager_service):
		var main_camera: Camera3D = camera_manager_service.get_main_camera()
		if main_camera != null and is_instance_valid(main_camera):
			return main_camera

	if owner == null:
		return null
	var viewport: Viewport = owner.get_viewport()
	if viewport == null:
		return null
	var viewport_camera: Camera3D = viewport.get_camera_3d()
	if viewport_camera == null or not is_instance_valid(viewport_camera):
		return null
	return viewport_camera

func resolve_primary_camera_state_component(
	queries: Array,
	camera_state_type: StringName,
	primary_camera_entity_id: StringName
) -> Object:
	var fallback: Object = null
	for query_variant in queries:
		if query_variant == null or not (query_variant is Object):
			continue
		var query: Object = query_variant as Object
		if not query.has_method("get_component"):
			continue
		var camera_state_variant: Variant = query.call("get_component", camera_state_type)
		if not (camera_state_variant is Object):
			continue
		var camera_state: Object = camera_state_variant as Object
		if fallback == null:
			fallback = camera_state
		if _is_primary_camera_query(query, primary_camera_entity_id):
			return camera_state
	return fallback

func write_active_camera_base_fov_from_result(result: Dictionary, camera_state: Object) -> void:
	if result.is_empty():
		return

	var fov_variant: Variant = result.get("fov", null)
	if not (fov_variant is float or fov_variant is int):
		return

	var fov_value: float = float(fov_variant)
	if is_nan(fov_value) or is_inf(fov_value):
		return
	if camera_state == null:
		return
	if not U_RuleUtils.object_has_property(camera_state, "base_fov"):
		return
	camera_state.set("base_fov", clampf(fov_value, 1.0, 179.0))

func get_camera_state_float(camera_state: Object, property_name: String, fallback: float) -> float:
	if camera_state == null:
		return fallback
	if not U_RuleUtils.object_has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func read_camera_state_vector3(camera_state: Object, property_name: String, fallback: Vector3) -> Vector3:
	if camera_state == null:
		return fallback
	if not U_RuleUtils.object_has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is Vector3:
		return value as Vector3
	return fallback

func write_camera_state_vector3(camera_state: Object, property_name: String, value: Vector3) -> void:
	if camera_state == null:
		return
	if not U_RuleUtils.object_has_property(camera_state, property_name):
		return
	camera_state.set(property_name, value)

func _resolve_entity_target(entity: Node) -> Node3D:
	if entity == null or not is_instance_valid(entity):
		return null
	if entity is Node3D:
		return entity as Node3D
	var body_target := entity.get_node_or_null("Body") as Node3D
	if body_target != null and is_instance_valid(body_target):
		return body_target
	return null

func _read_gameplay_entity_velocity(entity_id: StringName, store: I_StateStore, state_snapshot: Dictionary = {}) -> Dictionary:
	if entity_id == StringName(""):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	if store == null and state_snapshot.is_empty():
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var state: Dictionary = state_snapshot
	if state.is_empty() and store != null:
		state = store.get_state()

	var entity_state: Dictionary = U_EntitySelectors.get_entity(state, entity_id)
	if not entity_state.has("velocity"):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var velocity_variant: Variant = entity_state.get("velocity", Vector3.ZERO)
	if velocity_variant is Vector3:
		return {
			"has_velocity": true,
			"velocity": velocity_variant as Vector3,
		}
	if velocity_variant is Vector2:
		var velocity_2d := velocity_variant as Vector2
		return {
			"has_velocity": true,
			"velocity": Vector3(velocity_2d.x, 0.0, velocity_2d.y),
		}
	return {"has_velocity": false, "velocity": Vector3.ZERO}

func _read_entity_movement_component_velocity(entity: Node) -> Dictionary:
	var movement_component: Node = _find_node_with_script(entity, C_MOVEMENT_COMPONENT_SCRIPT)
	if movement_component == null:
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	if not movement_component.has_method("get_horizontal_dynamics_velocity"):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var velocity_variant: Variant = movement_component.call("get_horizontal_dynamics_velocity")
	if not (velocity_variant is Vector2):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var velocity_2d := velocity_variant as Vector2
	return {
		"has_velocity": true,
		"velocity": Vector3(velocity_2d.x, 0.0, velocity_2d.y),
	}

func _read_entity_character_body_velocity(entity: Node) -> Dictionary:
	var character_body: CharacterBody3D = U_NODE_FIND.find_character_body_recursive(entity)
	if character_body == null or not is_instance_valid(character_body):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	return {
		"has_velocity": true,
		"velocity": character_body.velocity,
	}

func _read_character_body_velocity(node: Node) -> Dictionary:
	if not (node is CharacterBody3D):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var body := node as CharacterBody3D
	return {
		"has_velocity": true,
		"velocity": body.velocity,
	}

func _read_gameplay_entity_is_on_floor(entity_id: StringName, store: I_StateStore, state_snapshot: Dictionary = {}) -> Dictionary:
	if entity_id == StringName(""):
		return {"has_value": false, "is_on_floor": false}
	if store == null and state_snapshot.is_empty():
		return {"has_value": false, "is_on_floor": false}

	var state: Dictionary = state_snapshot
	if state.is_empty() and store != null:
		state = store.get_state()

	var entity_state: Dictionary = U_EntitySelectors.get_entity(state, entity_id)
	if not entity_state.has("is_on_floor"):
		return {"has_value": false, "is_on_floor": false}

	var on_floor_variant: Variant = entity_state.get("is_on_floor", false)
	if on_floor_variant is bool:
		return {"has_value": true, "is_on_floor": on_floor_variant as bool}
	if on_floor_variant is int:
		return {"has_value": true, "is_on_floor": int(on_floor_variant) != 0}
	return {"has_value": false, "is_on_floor": false}

func _is_primary_camera_query(query: Object, primary_camera_entity_id: StringName) -> bool:
	if query.has_method("get_entity_id"):
		var entity_id: StringName = U_RuleUtils.variant_to_string_name(query.call("get_entity_id"))
		if entity_id == primary_camera_entity_id:
			return true
	if query.has_method("get_tags"):
		var tags_variant: Variant = query.call("get_tags")
		if tags_variant is Array:
			var tags: Array = tags_variant as Array
			return tags.has(primary_camera_entity_id) or tags.has(String(primary_camera_entity_id))
	return false

func _find_node_with_script(root: Node, script: Script) -> Node:
	if root == null or script == null:
		return null
	if root.get_script() == script:
		return root

	for child_variant in root.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: Node = _find_node_with_script(child, script)
		if found != null:
			return found
	return null
