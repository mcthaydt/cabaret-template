extends GutTest

const U_VCAM_SILHOUETTE_HELPER := preload(
	"res://scripts/core/managers/helpers/u_vcam_silhouette_helper.gd"
)

# These tests validate the occlusion throttle constants and the silhouette
# set-equality early-out that M_VCamManager uses to skip redundant detection.

const M_VCAM_MANAGER := preload("res://scripts/core/managers/m_vcam_manager.gd")

# --- Throttle constant tests ---

func test_occlusion_detect_interval_is_2() -> void:
	assert_eq(
		M_VCAM_MANAGER.OCCLUSION_DETECT_INTERVAL_FRAMES, 2,
		"detection should run every 2nd physics frame"
	)

func test_occlusion_position_threshold_is_positive() -> void:
	assert_gt(
		M_VCAM_MANAGER.OCCLUSION_POSITION_THRESHOLD, 0.0,
		"position threshold must be positive"
	)

func test_occlusion_position_threshold_is_small() -> void:
	assert_lt(
		M_VCAM_MANAGER.OCCLUSION_POSITION_THRESHOLD, 1.0,
		"position threshold should be sub-unit for responsiveness"
	)

# --- Frame-skip logic tests ---

func test_should_skip_returns_true_on_non_interval_frame() -> void:
	# Frame counter 1 with interval 2 → skip
	var should_skip: bool = (1 % M_VCAM_MANAGER.OCCLUSION_DETECT_INTERVAL_FRAMES) != 0
	assert_true(should_skip, "odd frame should be skipped with interval=2")

func test_should_skip_returns_false_on_interval_frame() -> void:
	# Frame counter 0 with interval 2 → detect
	var should_skip: bool = (0 % M_VCAM_MANAGER.OCCLUSION_DETECT_INTERVAL_FRAMES) != 0
	assert_false(should_skip, "frame 0 should detect with interval=2")

func test_should_skip_returns_false_on_second_interval_frame() -> void:
	# Frame counter 2 with interval 2 → detect
	var should_skip: bool = (2 % M_VCAM_MANAGER.OCCLUSION_DETECT_INTERVAL_FRAMES) != 0
	assert_false(should_skip, "frame 2 should detect with interval=2")

# --- Position cache-diff logic tests ---

func test_positions_unchanged_below_threshold() -> void:
	var threshold: float = M_VCAM_MANAGER.OCCLUSION_POSITION_THRESHOLD
	var last_cam := Vector3(1.0, 2.0, 3.0)
	var last_tgt := Vector3(4.0, 5.0, 6.0)
	var curr_cam := last_cam + Vector3(0.01, 0.0, 0.0)
	var curr_tgt := last_tgt + Vector3(0.0, 0.01, 0.0)
	var cam_moved: bool = last_cam.distance_to(curr_cam) >= threshold
	var tgt_moved: bool = last_tgt.distance_to(curr_tgt) >= threshold
	assert_false(cam_moved or tgt_moved, "small movements should not trigger re-detection")

func test_camera_moved_beyond_threshold() -> void:
	var threshold: float = M_VCAM_MANAGER.OCCLUSION_POSITION_THRESHOLD
	var last_cam := Vector3.ZERO
	var curr_cam := Vector3(threshold + 0.01, 0.0, 0.0)
	var moved: bool = last_cam.distance_to(curr_cam) >= threshold
	assert_true(moved, "camera movement beyond threshold should trigger detection")

func test_target_moved_beyond_threshold() -> void:
	var threshold: float = M_VCAM_MANAGER.OCCLUSION_POSITION_THRESHOLD
	var last_tgt := Vector3.ZERO
	var curr_tgt := Vector3(0.0, threshold + 0.01, 0.0)
	var moved: bool = last_tgt.distance_to(curr_tgt) >= threshold
	assert_true(moved, "target movement beyond threshold should trigger detection")

# --- Silhouette set-equality early-out tests ---

func test_silhouette_set_equality_skips_publish_when_unchanged() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var mesh_a := MeshInstance3D.new()
	var mesh_b := MeshInstance3D.new()
	add_child_autofree(mesh_a)
	add_child_autofree(mesh_b)
	# Debounce in
	helper.update_silhouettes([mesh_a, mesh_b], true)
	helper.update_silhouettes([mesh_a, mesh_b], true)
	# Same set → should skip publish
	assert_true(
		helper.has_same_targets([mesh_a, mesh_b]),
		"same occluder set should be detected as unchanged"
	)

func test_silhouette_set_equality_detects_change() -> void:
	var helper := U_VCAM_SILHOUETTE_HELPER.new()
	var mesh_a := MeshInstance3D.new()
	var mesh_b := MeshInstance3D.new()
	add_child_autofree(mesh_a)
	add_child_autofree(mesh_b)
	helper.update_silhouettes([mesh_a], true)
	helper.update_silhouettes([mesh_a], true)
	assert_false(
		helper.has_same_targets([mesh_a, mesh_b]),
		"different occluder set should be detected as changed"
	)
