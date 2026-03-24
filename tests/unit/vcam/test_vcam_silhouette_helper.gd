extends GutTest

const U_VCAM_SILHOUETTE_HELPER := preload(
	"res://scripts/managers/helpers/u_vcam_silhouette_helper.gd"
)

var _helper: U_VCamSilhouetteHelper = null

func before_each() -> void:
	_helper = U_VCAM_SILHOUETTE_HELPER.new()

# --- update_silhouettes tests ---

func test_update_silhouettes_empty_array_does_nothing() -> void:
	_helper.update_silhouettes([], true)
	assert_eq(_helper.get_active_count(), 0, "empty occluder array should produce no active silhouettes")

func test_update_silhouettes_disabled_removes_all() -> void:
	var mesh := MeshInstance3D.new()
	add_child_autofree(mesh)
	_helper.apply_silhouette(mesh)
	assert_eq(_helper.get_active_count(), 1, "should have 1 active after apply")
	_helper.update_silhouettes([], false)
	assert_eq(_helper.get_active_count(), 0, "disabled update should clear all silhouettes")

func test_apply_debounce_requires_two_frames() -> void:
	var mesh := MeshInstance3D.new()
	add_child_autofree(mesh)
	# Frame 1: first time seeing this occluder
	_helper.update_silhouettes([mesh], true)
	assert_eq(_helper.get_active_count(), 0, "should not apply on first frame (debounce)")
	# Frame 2: seen again, meets debounce threshold
	_helper.update_silhouettes([mesh], true)
	assert_eq(_helper.get_active_count(), 1, "should apply on second frame")

func test_remove_grace_period() -> void:
	var mesh := MeshInstance3D.new()
	add_child_autofree(mesh)
	# Apply silhouette (2 frames to debounce)
	_helper.update_silhouettes([mesh], true)
	_helper.update_silhouettes([mesh], true)
	assert_eq(_helper.get_active_count(), 1, "should be applied after debounce")
	# Frame without occluder — grace period
	_helper.update_silhouettes([], true)
	assert_eq(_helper.get_active_count(), 1, "should still be active during grace frame")
	# Second frame without — removed
	_helper.update_silhouettes([], true)
	assert_eq(_helper.get_active_count(), 0, "should be removed after grace period")

# --- has_same_targets tests ---

func test_has_same_targets_returns_true_when_identical() -> void:
	var mesh_a := MeshInstance3D.new()
	var mesh_b := MeshInstance3D.new()
	add_child_autofree(mesh_a)
	add_child_autofree(mesh_b)
	# Apply both through debounce
	_helper.update_silhouettes([mesh_a, mesh_b], true)
	_helper.update_silhouettes([mesh_a, mesh_b], true)
	assert_true(
		_helper.has_same_targets([mesh_a, mesh_b]),
		"should return true when occluder set matches tracked targets"
	)

func test_has_same_targets_returns_true_regardless_of_order() -> void:
	var mesh_a := MeshInstance3D.new()
	var mesh_b := MeshInstance3D.new()
	add_child_autofree(mesh_a)
	add_child_autofree(mesh_b)
	_helper.update_silhouettes([mesh_a, mesh_b], true)
	_helper.update_silhouettes([mesh_a, mesh_b], true)
	assert_true(
		_helper.has_same_targets([mesh_b, mesh_a]),
		"should return true regardless of array order"
	)

func test_has_same_targets_returns_false_when_different() -> void:
	var mesh_a := MeshInstance3D.new()
	var mesh_b := MeshInstance3D.new()
	var mesh_c := MeshInstance3D.new()
	add_child_autofree(mesh_a)
	add_child_autofree(mesh_b)
	add_child_autofree(mesh_c)
	_helper.update_silhouettes([mesh_a, mesh_b], true)
	_helper.update_silhouettes([mesh_a, mesh_b], true)
	assert_false(
		_helper.has_same_targets([mesh_a, mesh_c]),
		"should return false when occluder set differs"
	)

func test_has_same_targets_returns_false_when_empty_vs_nonempty() -> void:
	var mesh := MeshInstance3D.new()
	add_child_autofree(mesh)
	_helper.update_silhouettes([mesh], true)
	_helper.update_silhouettes([mesh], true)
	assert_false(
		_helper.has_same_targets([]),
		"should return false when incoming is empty but tracked is not"
	)

func test_has_same_targets_returns_true_when_both_empty() -> void:
	assert_true(
		_helper.has_same_targets([]),
		"should return true when both incoming and tracked are empty"
	)
