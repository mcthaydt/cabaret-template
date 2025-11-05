extends GutTest

## Unit tests for C_CheckpointComponent (Phase 12.3b - T262)
##
## Tests checkpoint component for marking mid-scene spawn points
## independent of door transitions.

const C_CHECKPOINT_COMPONENT := preload("res://scripts/ecs/components/c_checkpoint_component.gd")

var checkpoint: C_CHECKPOINT_COMPONENT

func before_each() -> void:
	checkpoint = C_CHECKPOINT_COMPONENT.new()
	add_child_autofree(checkpoint)
	# Allow deferred child creation in component _ready() to complete
	await get_tree().process_frame

func after_each() -> void:
	checkpoint = null

## T262: Test checkpoint component has required properties
func test_checkpoint_has_checkpoint_id() -> void:
	assert_has_method(checkpoint, "get", "Should have property accessors")

	# Should have checkpoint_id property
	checkpoint.checkpoint_id = StringName("cp_safe_room")
	assert_eq(checkpoint.checkpoint_id, StringName("cp_safe_room"),
		"Should store checkpoint_id")

## T262: Test checkpoint component has spawn_point_id property
func test_checkpoint_has_spawn_point_id() -> void:
	# Should have spawn_point_id property (where to respawn)
	checkpoint.spawn_point_id = StringName("sp_safe_room")
	assert_eq(checkpoint.spawn_point_id, StringName("sp_safe_room"),
		"Should store spawn_point_id")

## T263: Test checkpoint component requires Area3D child for collision
func test_checkpoint_validates_area3d_child() -> void:
	# Checkpoint should work with Area3D for player collision detection
	var area := Area3D.new()
	area.name = "CheckpointArea"
	checkpoint.add_child(area)

	# Should be able to find Area3D child
	var found_area := checkpoint.get_node_or_null("CheckpointArea")
	assert_not_null(found_area, "Should find Area3D child")
	assert_true(found_area is Area3D, "Child should be Area3D")

## T263: Test checkpoint stores last activated timestamp
func test_checkpoint_tracks_activation_time() -> void:
	# Should track when checkpoint was activated
	checkpoint.last_activated_time = 12345.0
	assert_eq(checkpoint.last_activated_time, 12345.0,
		"Should store last activation time")

## T263: Test checkpoint has activated flag
func test_checkpoint_has_activated_flag() -> void:
	# Should track if checkpoint has been activated
	assert_false(checkpoint.is_activated, "Should start as not activated")

	checkpoint.is_activated = true
	assert_true(checkpoint.is_activated, "Should be able to set activated")
