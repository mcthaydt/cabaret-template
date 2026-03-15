extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")
const OTS_MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const C_VCAM_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_vcam_component.gd")

class ReticleECSManagerStub extends I_ECSManager:
	var components_by_type: Dictionary = {}

	func get_components(component_type: StringName) -> Array:
		var components_variant: Variant = components_by_type.get(component_type, [])
		if components_variant is Array:
			return (components_variant as Array).duplicate()
		return []

var _store: M_StateStore = null
var _hud: CanvasLayer = null
var _ecs_manager_stub: ReticleECSManagerStub = null

func before_each() -> void:
	U_ServiceLocator.clear()
	U_StateHandoff.clear_all()
	U_ECSEventBus.reset()

	_store = M_STATE_STORE.new()
	_store.settings = RS_STATE_STORE_SETTINGS.new()
	_store.settings.enable_persistence = false
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	_ecs_manager_stub = ReticleECSManagerStub.new()
	add_child_autofree(_ecs_manager_stub)
	U_ServiceLocator.register(StringName("ecs_manager"), _ecs_manager_stub)

	_store.dispatch(U_NavigationActions.start_game(StringName("alleyway")))
	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)

	await _wait_frames(3)

func after_each() -> void:
	U_ServiceLocator.clear()
	U_StateHandoff.clear_all()
	_store = null
	_hud = null
	_ecs_manager_stub = null

func _wait_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	var timer := get_tree().create_timer(seconds, true, false, true)
	await timer.timeout

func _configure_active_ots_vcam(vcam_id: StringName, aim_blend_duration: float) -> void:
	var mode: Resource = OTS_MODE_SCRIPT.new()
	mode.set("aim_blend_duration", aim_blend_duration)

	var vcam_component: C_VCamComponent = C_VCAM_COMPONENT_SCRIPT.new()
	vcam_component.vcam_id = vcam_id
	vcam_component.mode = mode
	add_child_autofree(vcam_component)

	_ecs_manager_stub.components_by_type[C_VCamComponent.COMPONENT_TYPE] = [vcam_component]

func _get_reticle() -> Control:
	return _hud.get_node("OTSReticleContainer") as Control

func test_reticle_hidden_when_active_mode_is_not_ots() -> void:
	_store.dispatch(U_VCAM_ACTIONS.set_active_runtime(StringName("cam_orbit"), "orbit"))
	await _wait_frames(2)

	var reticle: Control = _get_reticle()
	assert_not_null(reticle, "OTS reticle container should exist")
	assert_false(reticle.visible, "Reticle should stay hidden outside OTS mode")
	assert_almost_eq(reticle.modulate.a, 0.0, 0.01)

func test_reticle_fades_in_using_ots_aim_blend_duration() -> void:
	var blend_duration_sec: float = 0.2
	_configure_active_ots_vcam(StringName("cam_ots"), blend_duration_sec)
	_store.dispatch(U_VCAM_ACTIONS.set_active_runtime(StringName("cam_ots"), "ots"))
	await _wait_frames(1)

	var reticle: Control = _get_reticle()
	assert_true(reticle.visible, "Reticle should become visible when OTS mode is active")

	await _wait_seconds(blend_duration_sec * 0.5)
	assert_true(reticle.modulate.a > 0.0 and reticle.modulate.a < 1.0, "Reticle alpha should be mid-fade")

	await _wait_seconds(blend_duration_sec * 0.75)
	assert_almost_eq(reticle.modulate.a, 1.0, 0.05)

func test_reticle_fades_out_using_last_ots_aim_blend_duration() -> void:
	var blend_duration_sec: float = 0.18
	_configure_active_ots_vcam(StringName("cam_ots"), blend_duration_sec)
	_store.dispatch(U_VCAM_ACTIONS.set_active_runtime(StringName("cam_ots"), "ots"))
	await _wait_seconds(blend_duration_sec * 1.1)

	var reticle: Control = _get_reticle()
	assert_true(reticle.visible, "Reticle should be visible after OTS fade-in completes")
	assert_almost_eq(reticle.modulate.a, 1.0, 0.05)

	_store.dispatch(U_VCAM_ACTIONS.set_active_runtime(StringName("cam_orbit"), "orbit"))
	await _wait_frames(1)
	assert_true(reticle.visible, "Reticle should stay visible while fading out")

	await _wait_seconds(blend_duration_sec * 0.5)
	assert_true(reticle.modulate.a > 0.0 and reticle.modulate.a < 1.0, "Reticle alpha should be mid-fade-out")

	await _wait_seconds(blend_duration_sec * 0.75)
	assert_false(reticle.visible, "Reticle should hide after fade-out completes")
	assert_almost_eq(reticle.modulate.a, 0.0, 0.05)

func test_reticle_is_centered_on_screen() -> void:
	var reticle: Control = _get_reticle()
	assert_not_null(reticle, "OTS reticle container should exist")

	await _wait_frames(1)
	var viewport_center: Vector2 = _hud.get_viewport().get_visible_rect().size * 0.5
	var reticle_center: Vector2 = reticle.get_global_rect().get_center()
	assert_true(
		reticle_center.distance_to(viewport_center) <= 1.0,
		"Reticle should be centered in the viewport"
	)
