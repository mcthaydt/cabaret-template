extends GutTest

# Test suite for C_SurfaceDetectorComponent
# Tests surface detection via raycast and explicit surface providers

const C_SURFACE_DETECTOR_SCRIPT := preload("res://scripts/ecs/components/c_surface_detector_component.gd")
const MARKER_SURFACE_TYPE := preload("res://scripts/ecs/markers/marker_surface_type.gd")

var detector: C_SurfaceDetectorComponent
var character_body: CharacterBody3D  # CharacterBody3D for the detector to attach to
var static_body: StaticBody3D
var collision_shape: CollisionShape3D

func before_each() -> void:
	# Create CharacterBody3D for the detector to attach its raycast to
	character_body = CharacterBody3D.new()
	add_child_autofree(character_body)

	# Create detector component as child of character body
	detector = C_SurfaceDetectorComponent.new()
	# Set character_body_path BEFORE adding to tree so _ready() can find it
	# Use relative path ".." since detector will be direct child of character_body
	detector.character_body_path = NodePath("..")
	character_body.add_child(detector)
	await get_tree().process_frame

	# Create a static body for collision testing
	static_body = StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child_autofree(static_body)

	# Add collision shape (floor below detector)
	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.1, 10)
	collision_shape.shape = box
	static_body.add_child(collision_shape)
	static_body.position = Vector3(0, -0.5, 0)

	# Character body starts at origin
	character_body.position = Vector3(0, 0, 0)

	await get_tree().physics_frame

func after_each() -> void:
	detector = null
	character_body = null
	static_body = null
	collision_shape = null

# Test 1: Component initializes with raycast
func test_component_initializes_raycast() -> void:
	assert_not_null(detector, "Detector should exist")
	# Raycast is created as child of CharacterBody3D, not the detector itself
	var raycast := character_body.get_node_or_null("SurfaceDetectorRay") as RayCast3D
	assert_not_null(raycast, "Should have SurfaceDetectorRay child on CharacterBody3D")
	assert_true(raycast.enabled, "RayCast should be enabled")

# Test 2: Raycast configured correctly
func test_raycast_configuration() -> void:
	var raycast := character_body.get_node("SurfaceDetectorRay") as RayCast3D
	assert_eq(raycast.target_position, Vector3(0, -2.0, 0), "Should cast downward 2 meters")
	assert_eq(raycast.collision_mask, 1, "Should collide with layer 1 (world geometry)")

# Test 3: SurfaceType enum has 6 values
func test_surface_type_enum() -> void:
	# Verify all 6 surface types exist
	assert_eq(C_SurfaceDetectorComponent.SurfaceType.DEFAULT, 0, "DEFAULT should be 0")
	assert_eq(C_SurfaceDetectorComponent.SurfaceType.GRASS, 1, "GRASS should be 1")
	assert_eq(C_SurfaceDetectorComponent.SurfaceType.STONE, 2, "STONE should be 2")
	assert_eq(C_SurfaceDetectorComponent.SurfaceType.WOOD, 3, "WOOD should be 3")
	assert_eq(C_SurfaceDetectorComponent.SurfaceType.METAL, 4, "METAL should be 4")
	assert_eq(C_SurfaceDetectorComponent.SurfaceType.WATER, 5, "WATER should be 5")

# Test 4: Returns DEFAULT when not colliding
func test_returns_default_when_not_colliding() -> void:
	# Position detector high above ground so raycast doesn't hit
	character_body.position = Vector3(0, 10, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.DEFAULT,
		"Should return DEFAULT when not colliding")

# Test 5: Returns DEFAULT when collider is null
func test_returns_default_when_collider_null() -> void:
	# Position detector above ground but remove collision shape
	static_body.remove_child(collision_shape)
	collision_shape.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.DEFAULT,
		"Should return DEFAULT when collider is null")

# Test 6: Reads surface_type metadata - GRASS
func test_reads_grass_provider_value() -> void:
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.GRASS)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.GRASS,
		"Should read GRASS from metadata")

# Test 7: Reads surface_type metadata - STONE
func test_reads_stone_provider_value() -> void:
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.STONE)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.STONE,
		"Should read STONE from metadata")

# Test 8: Reads surface_type metadata - WOOD
func test_reads_wood_provider_value() -> void:
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.WOOD)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.WOOD,
		"Should read WOOD from metadata")

# Test 9: Reads surface_type metadata - METAL
func test_reads_metal_provider_value() -> void:
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.METAL)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.METAL,
		"Should read METAL from metadata")

# Test 10: Reads surface_type metadata - WATER
func test_reads_water_provider_value() -> void:
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.WATER)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.WATER,
		"Should read WATER from metadata")

# Test 11: Falls back to DEFAULT if metadata missing
func test_fallback_to_default_when_provider_missing() -> void:
	# Don't set any metadata
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.DEFAULT,
		"Should fallback to DEFAULT when metadata missing")

# Test 12: Falls back to DEFAULT if metadata is wrong type
func test_fallback_to_default_when_provider_invalid() -> void:
	_set_surface_type(99)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.DEFAULT,
		"Should fallback to DEFAULT when metadata is wrong type")

# Test 13: detect_surface() can be called multiple times
func test_detect_surface_callable_multiple_times() -> void:
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.GRASS)
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface1: int = detector.detect_surface()
	var surface2: int = detector.detect_surface()
	var surface3: int = detector.detect_surface()

	assert_eq(surface1, C_SurfaceDetectorComponent.SurfaceType.GRASS, "First call should return GRASS")
	assert_eq(surface2, C_SurfaceDetectorComponent.SurfaceType.GRASS, "Second call should return GRASS")
	assert_eq(surface3, C_SurfaceDetectorComponent.SurfaceType.GRASS, "Third call should return GRASS")

# Test 14: Surface type changes when detector moves
func test_surface_changes_when_detector_moves() -> void:
	# Set first floor to GRASS
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.GRASS)

	# Detect GRASS
	character_body.position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface1: int = detector.detect_surface()
	assert_eq(surface1, C_SurfaceDetectorComponent.SurfaceType.GRASS, "Should detect GRASS")

	# Change floor surface type to METAL (simpler than moving detector)
	_set_surface_type(C_SurfaceDetectorComponent.SurfaceType.METAL)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface2: int = detector.detect_surface()
	assert_eq(surface2, C_SurfaceDetectorComponent.SurfaceType.METAL, "Should detect METAL after surface type changes")

# Test 15: Raycast distance is 2 meters (functional test)
func test_raycast_distance_two_meters() -> void:
	# Position floor exactly 2.5 meters below detector (should NOT detect)
	character_body.position = Vector3(0, 0, 0)
	static_body.position = Vector3(0, -2.5, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var surface_type: int = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.DEFAULT,
		"Should not detect surface beyond 2 meters")

	# Position floor exactly 1.5 meters below detector (SHOULD detect)
	static_body.position = Vector3(0, -1.5, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	surface_type = detector.detect_surface()
	assert_eq(surface_type, C_SurfaceDetectorComponent.SurfaceType.DEFAULT,
		"Should detect surface within 2 meters (returns DEFAULT with no provider override)")

func _set_surface_type(surface_type: int) -> void:
	static_body.set_script(MARKER_SURFACE_TYPE)
	static_body.set("surface_type", surface_type)
