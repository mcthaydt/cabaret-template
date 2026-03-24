extends GutTest

const U_VCAM_COLLISION_DETECTOR := preload("res://scripts/managers/helpers/u_vcam_collision_detector.gd")
const OCCLUDABLE_LAYER_MASK: int = 1 << 5
const NON_OCCLUDABLE_LAYER_MASK: int = 1 << 0

class FakeSpaceState extends RefCounted:
	var _hits: Array[Dictionary] = []

	func queue_hit(hit: Dictionary) -> void:
		_hits.append(hit.duplicate(true))

	func intersect_ray(_query: PhysicsRayQueryParameters3D) -> Dictionary:
		if _hits.is_empty():
			return {}
		var next_hit_variant: Variant = _hits.pop_front()
		if next_hit_variant is Dictionary:
			return (next_hit_variant as Dictionary).duplicate(true)
		return {}

func _queue_collider_hit(space_state: FakeSpaceState, collider: Object) -> void:
	var hit: Dictionary = {
		"collider": collider,
	}
	if collider != null and is_instance_valid(collider) and collider is CollisionObject3D:
		hit["rid"] = (collider as CollisionObject3D).get_rid()
	space_state.queue_hit(hit)

func _create_mesh_occluder(layer_mask: int) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = layer_mask
	var mesh := MeshInstance3D.new()
	body.add_child(mesh)
	autofree(body)
	autofree(mesh)
	return {
		"collider": body,
		"occluder": mesh,
	}

func _create_csg_occluder(layer_mask: int) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = layer_mask
	var csg := CSGBox3D.new()
	body.add_child(csg)
	autofree(body)
	autofree(csg)
	return {
		"collider": body,
		"occluder": csg,
	}

func test_detect_occluders_returns_empty_when_no_occluders_hit() -> void:
	var space_state := FakeSpaceState.new()

	var occluders: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0),
		OCCLUDABLE_LAYER_MASK
	)

	assert_eq(occluders.size(), 0)

func test_detect_occluders_finds_mesh_instance_occluder_on_layer_six() -> void:
	var space_state := FakeSpaceState.new()
	var setup: Dictionary = _create_mesh_occluder(OCCLUDABLE_LAYER_MASK)
	_queue_collider_hit(space_state, setup["collider"] as Object)

	var occluders: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0),
		OCCLUDABLE_LAYER_MASK
	)

	assert_eq(occluders.size(), 1)
	assert_eq(occluders[0], setup["occluder"])

func test_detect_occluders_finds_csg_shape_occluder_on_layer_six() -> void:
	var space_state := FakeSpaceState.new()
	var setup: Dictionary = _create_csg_occluder(OCCLUDABLE_LAYER_MASK)
	_queue_collider_hit(space_state, setup["collider"] as Object)

	var occluders: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0),
		OCCLUDABLE_LAYER_MASK
	)

	assert_eq(occluders.size(), 1)
	assert_eq(occluders[0], setup["occluder"])

func test_detect_occluders_ignores_colliders_on_wrong_layer() -> void:
	var space_state := FakeSpaceState.new()
	var setup: Dictionary = _create_mesh_occluder(NON_OCCLUDABLE_LAYER_MASK)
	_queue_collider_hit(space_state, setup["collider"] as Object)

	var occluders: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0),
		OCCLUDABLE_LAYER_MASK
	)

	assert_eq(occluders.size(), 0)

func test_detect_occluders_skips_invalid_or_freed_colliders_safely() -> void:
	var space_state := FakeSpaceState.new()
	var stale_collider := StaticBody3D.new()
	stale_collider.free()
	space_state.queue_hit({"collider": stale_collider})

	var setup: Dictionary = _create_mesh_occluder(OCCLUDABLE_LAYER_MASK)
	_queue_collider_hit(space_state, setup["collider"] as Object)

	var occluders: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0),
		OCCLUDABLE_LAYER_MASK
	)

	assert_eq(occluders.size(), 1)
	assert_eq(occluders[0], setup["occluder"])

func test_detect_occluders_returns_all_occluders_along_ray() -> void:
	var space_state := FakeSpaceState.new()
	var first: Dictionary = _create_mesh_occluder(OCCLUDABLE_LAYER_MASK)
	var second: Dictionary = _create_csg_occluder(OCCLUDABLE_LAYER_MASK)
	_queue_collider_hit(space_state, first["collider"] as Object)
	_queue_collider_hit(space_state, second["collider"] as Object)

	var occluders: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0),
		OCCLUDABLE_LAYER_MASK
	)

	assert_eq(occluders.size(), 2)
	assert_true(occluders.has(first["occluder"]))
	assert_true(occluders.has(second["occluder"]))
