extends GutTest

const U_VCAM_BLEND_MANAGER := preload("res://scripts/managers/helpers/u_vcam_blend_manager.gd")
const RS_VCAM_BLEND_HINT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")

func test_configure_transition_starts_live_blend_with_settings() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	var settings := {
		"duration_sec": 0.5,
		"trans_type": int(Tween.TRANS_CUBIC),
		"ease_type": int(Tween.EASE_OUT),
		"cut_on_distance_threshold": 2.5,
	}

	var result: Dictionary = helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		settings
	)

	assert_eq(result.get("status", ""), "started")
	assert_true(helper.is_active())
	assert_almost_eq(helper.get_progress(), 0.0, 0.0001)
	assert_eq(helper.get_transition_type(), int(Tween.TRANS_CUBIC))
	assert_eq(helper.get_ease_type(), int(Tween.EASE_OUT))
	assert_almost_eq(helper.get_cut_on_distance_threshold(), 2.5, 0.0001)

func test_configure_transition_with_zero_duration_clears_live_blend_and_reports_completion() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		{"duration_sec": 0.5}
	)

	var result: Dictionary = helper.configure_transition(
		StringName("cam_b"),
		StringName("cam_c"),
		{"duration_sec": 0.0}
	)

	assert_eq(result.get("status", ""), "completed")
	assert_false(helper.is_active())
	assert_almost_eq(helper.get_progress(), 1.0, 0.0001)

func test_advance_progresses_blend_and_completes_at_duration() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		{"duration_sec": 0.4}
	)

	var mid: Dictionary = helper.advance(0.2)
	assert_eq(mid.get("status", ""), "progress")
	assert_true(helper.is_active())
	assert_true(helper.get_progress() > 0.0 and helper.get_progress() < 1.0)

	var done: Dictionary = helper.advance(0.3)
	assert_eq(done.get("status", ""), "completed")
	assert_false(helper.is_active())
	assert_almost_eq(helper.get_progress(), 1.0, 0.0001)

func test_queue_startup_blend_only_on_first_activation() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.queue_startup_blend(StringName("cam_a"), StringName(""))
	assert_eq(helper.get_startup_pending_vcam_id(), StringName("cam_a"))

	helper.queue_startup_blend(StringName("cam_b"), StringName("cam_a"))
	assert_eq(helper.get_startup_pending_vcam_id(), StringName(""), "Only first activation should queue startup blend")

func test_startup_blend_interpolates_from_main_camera_transform() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.queue_startup_blend(StringName("cam_a"), StringName(""))
	var started: bool = helper.start_startup_blend_if_pending(
		StringName("cam_a"),
		Transform3D(Basis.IDENTITY, Vector3.ZERO),
		{
			"duration_sec": 0.5,
			"trans_type": int(Tween.TRANS_LINEAR),
			"ease_type": int(Tween.EASE_IN_OUT),
			"cut_on_distance_threshold": 0.0,
		}
	)
	assert_true(started)

	var blended: Transform3D = helper.resolve_startup_transform(
		StringName("cam_a"),
		Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)),
		0.1
	)
	assert_true(blended.origin.x > 0.0 and blended.origin.x < 10.0)

func test_startup_blend_cuts_when_distance_threshold_is_exceeded() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.queue_startup_blend(StringName("cam_a"), StringName(""))
	helper.start_startup_blend_if_pending(
		StringName("cam_a"),
		Transform3D(Basis.IDENTITY, Vector3.ZERO),
		{
			"duration_sec": 1.0,
			"cut_on_distance_threshold": 0.5,
		}
	)
	var target := Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 0.0))

	var resolved: Transform3D = helper.resolve_startup_transform(StringName("cam_a"), target, 0.1)

	assert_eq(resolved, target)
	assert_false(helper.is_startup_blending())

func test_recover_invalid_members_records_from_invalid_and_completes() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		{"duration_sec": 1.0}
	)

	var recovery: Dictionary = helper.recover_invalid_members(true, false)

	assert_eq(recovery.get("reason", ""), "blend_from_invalid")
	assert_eq(recovery.get("status", ""), "completed")
	assert_eq(recovery.get("publish_completed_event", false), true)
	assert_false(helper.is_active())

func test_recover_invalid_members_records_to_invalid_without_completed_event() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		{"duration_sec": 1.0}
	)

	var recovery: Dictionary = helper.recover_invalid_members(false, true)

	assert_eq(recovery.get("reason", ""), "blend_to_invalid")
	assert_eq(recovery.get("status", ""), "completed")
	assert_eq(recovery.get("publish_completed_event", true), false)
	assert_false(helper.is_active())

func test_recover_invalid_members_records_both_invalid() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		{"duration_sec": 1.0}
	)

	var recovery: Dictionary = helper.recover_invalid_members(false, false)

	assert_eq(recovery.get("reason", ""), "blend_both_invalid")
	assert_eq(recovery.get("status", ""), "completed")
	assert_eq(recovery.get("publish_completed_event", true), false)
	assert_false(helper.is_active())

func test_reentrant_snapshot_is_used_as_blend_source() -> void:
	var helper := U_VCAM_BLEND_MANAGER.new()
	var snapshot_result := {
		"transform": Transform3D(Basis.IDENTITY, Vector3(5.0, 0.0, 0.0)),
		"fov": 70.0,
	}
	helper.configure_transition(
		StringName("cam_a"),
		StringName("cam_b"),
		{
			"duration_sec": 1.0,
			"trans_type": int(Tween.TRANS_LINEAR),
			"ease_type": int(Tween.EASE_IN_OUT),
		},
		snapshot_result
	)
	helper.advance(0.5)

	var blended_result: Dictionary = helper.resolve_blend_result(
		{
			"transform": Transform3D(Basis.IDENTITY, Vector3(-100.0, 0.0, 0.0)),
			"fov": 70.0,
		},
		{
			"transform": Transform3D(Basis.IDENTITY, Vector3(20.0, 0.0, 0.0)),
			"fov": 70.0,
		}
	)
	var blended_transform: Transform3D = blended_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(blended_transform.origin.x, 12.5, 0.0001)
	assert_true(helper.has_from_snapshot_result())

