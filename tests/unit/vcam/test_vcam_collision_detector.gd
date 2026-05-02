extends GutTest

const U_VCAM_COLLISION_DETECTOR := preload(
	"res://scripts/core/managers/helpers/u_vcam_collision_detector.gd"
)

# --- Guard tests ---

func test_returns_empty_when_space_state_null() -> void:
	var result: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		null, Vector3.ZERO, Vector3.FORWARD, 1
	)
	assert_eq(result.size(), 0, "should return empty array when space_state is null")

func test_returns_empty_when_mask_invalid() -> void:
	var mock_space := RefCounted.new()
	var result: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		mock_space, Vector3.ZERO, Vector3.FORWARD, 0
	)
	assert_eq(result.size(), 0, "should return empty array when collision_mask is 0")

func test_returns_empty_when_mask_negative() -> void:
	var mock_space := RefCounted.new()
	var result: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		mock_space, Vector3.ZERO, Vector3.FORWARD, -1
	)
	assert_eq(result.size(), 0, "should return empty array when collision_mask is negative")

func test_returns_empty_when_from_equals_to() -> void:
	var mock_space := RefCounted.new()
	var result: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		mock_space, Vector3.ONE, Vector3.ONE, 1
	)
	assert_eq(result.size(), 0, "should return empty array when from == to")

func test_returns_empty_when_no_intersect_ray_method() -> void:
	var mock_space := RefCounted.new()
	var result: Array = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		mock_space, Vector3.ZERO, Vector3.FORWARD, 1
	)
	assert_eq(result.size(), 0, "should return empty when space_state lacks intersect_ray")

# --- Constant tests ---

func test_max_raycast_hits_is_8() -> void:
	assert_eq(
		U_VCAM_COLLISION_DETECTOR.MAX_RAYCAST_HITS, 8,
		"MAX_RAYCAST_HITS should be 8 for performance"
	)

# --- Geometry descendant depth cap tests ---

func test_find_geometry_descendant_returns_direct_geometry() -> void:
	var mesh := MeshInstance3D.new()
	add_child_autofree(mesh)
	var result: GeometryInstance3D = U_VCAM_COLLISION_DETECTOR.find_geometry_descendant(mesh)
	assert_eq(result, mesh, "should return node itself when it is GeometryInstance3D")

func test_find_geometry_descendant_finds_child() -> void:
	var parent := Node3D.new()
	var mesh := MeshInstance3D.new()
	parent.add_child(mesh)
	add_child_autofree(parent)
	var result: GeometryInstance3D = U_VCAM_COLLISION_DETECTOR.find_geometry_descendant(parent)
	assert_eq(result, mesh, "should find GeometryInstance3D one level deep")

func test_find_geometry_descendant_finds_within_max_depth() -> void:
	# Build chain: root -> child1 -> child2 -> mesh (depth 3 from root)
	var root := Node3D.new()
	var child1 := Node3D.new()
	var child2 := Node3D.new()
	var mesh := MeshInstance3D.new()
	root.add_child(child1)
	child1.add_child(child2)
	child2.add_child(mesh)
	add_child_autofree(root)
	var result: GeometryInstance3D = U_VCAM_COLLISION_DETECTOR.find_geometry_descendant(root, 3)
	assert_eq(result, mesh, "should find geometry at exactly max_depth")

func test_find_geometry_descendant_returns_null_beyond_max_depth() -> void:
	# Build chain: root -> c1 -> c2 -> c3 -> mesh (depth 4 from root)
	var root := Node3D.new()
	var c1 := Node3D.new()
	var c2 := Node3D.new()
	var c3 := Node3D.new()
	var mesh := MeshInstance3D.new()
	root.add_child(c1)
	c1.add_child(c2)
	c2.add_child(c3)
	c3.add_child(mesh)
	add_child_autofree(root)
	var result: GeometryInstance3D = U_VCAM_COLLISION_DETECTOR.find_geometry_descendant(root, 3)
	assert_null(result, "should return null when geometry is deeper than max_depth")

func test_find_geometry_descendant_null_node_returns_null() -> void:
	var result: GeometryInstance3D = U_VCAM_COLLISION_DETECTOR.find_geometry_descendant(null)
	assert_null(result, "should return null for null input")

func test_find_geometry_descendant_default_max_depth_is_3() -> void:
	# Build chain: root -> c1 -> c2 -> mesh (depth 3, should work with default)
	var root := Node3D.new()
	var c1 := Node3D.new()
	var c2 := Node3D.new()
	var mesh := MeshInstance3D.new()
	root.add_child(c1)
	c1.add_child(c2)
	c2.add_child(mesh)
	add_child_autofree(root)
	var result: GeometryInstance3D = U_VCAM_COLLISION_DETECTOR.find_geometry_descendant(root)
	assert_eq(result, mesh, "default max_depth should allow depth 3")
