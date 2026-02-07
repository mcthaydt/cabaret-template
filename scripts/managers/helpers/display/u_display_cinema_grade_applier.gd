extends RefCounted
class_name U_DisplayCinemaGradeApplier

## Applies per-scene cinema grade settings via a shader overlay.
##
## Creates a CinemaGradeLayer (CanvasLayer 1) inside PostProcessOverlay and
## listens for scene/transition_completed to swap cinema grades automatically.

const U_CinemaGradeRegistry := preload("res://scripts/managers/helpers/display/u_cinema_grade_registry.gd")
const U_CinemaGradeActions := preload("res://scripts/state/actions/u_cinema_grade_actions.gd")
const U_CinemaGradeSelectors := preload("res://scripts/state/selectors/u_cinema_grade_selectors.gd")
const CINEMA_GRADE_SHADER := preload("res://assets/shaders/sh_cinema_grade_shader.gdshader")

const SCENE_TRANSITION_COMPLETED := StringName("scene/transition_completed")

var _owner: Node = null
var _state_store: I_StateStore = null
var _cinema_grade_layer: CanvasLayer = null
var _cinema_grade_rect: ColorRect = null
var _shader_material: ShaderMaterial = null

func initialize(owner: Node, state_store: I_StateStore) -> void:
	_owner = owner
	_state_store = state_store
	U_CinemaGradeRegistry.initialize()

	if _state_store != null and _state_store.has_signal("action_dispatched"):
		_state_store.action_dispatched.connect(_on_action_dispatched)

func apply_settings(display_settings: Dictionary) -> void:
	if not _ensure_cinema_grade_layer():
		return
	var state := {"display": display_settings}
	_apply_cinema_grade_uniforms(state)

func update_visibility(should_show: bool) -> void:
	if _cinema_grade_layer != null and is_instance_valid(_cinema_grade_layer):
		_cinema_grade_layer.visible = should_show

func cleanup() -> void:
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		if _state_store.action_dispatched.is_connected(_on_action_dispatched):
			_state_store.action_dispatched.disconnect(_on_action_dispatched)
	_state_store = null

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: Variant = action.get("type", "")
	if action_type != SCENE_TRANSITION_COMPLETED:
		return
	var payload: Dictionary = action.get("payload", {})
	var scene_id: Variant = payload.get("scene_id", "")
	if scene_id is StringName or scene_id is String:
		_load_grade_for_scene(StringName(str(scene_id)))

func _load_grade_for_scene(scene_id: StringName) -> void:
	if _state_store == null:
		return
	var grade := U_CinemaGradeRegistry.get_cinema_grade_for_scene(scene_id)
	_state_store.dispatch(U_CinemaGradeActions.load_scene_grade(grade.to_dictionary()))

func _apply_cinema_grade_uniforms(state: Dictionary) -> void:
	if _shader_material == null:
		return

	_shader_material.set_shader_parameter("filter_mode", U_CinemaGradeSelectors.get_filter_mode(state))
	_shader_material.set_shader_parameter("filter_intensity", U_CinemaGradeSelectors.get_filter_intensity(state))
	_shader_material.set_shader_parameter("exposure", U_CinemaGradeSelectors.get_exposure(state))
	_shader_material.set_shader_parameter("brightness", U_CinemaGradeSelectors.get_brightness(state))
	_shader_material.set_shader_parameter("contrast", U_CinemaGradeSelectors.get_contrast(state))
	_shader_material.set_shader_parameter("brilliance", U_CinemaGradeSelectors.get_brilliance(state))
	_shader_material.set_shader_parameter("highlights", U_CinemaGradeSelectors.get_highlights(state))
	_shader_material.set_shader_parameter("shadows", U_CinemaGradeSelectors.get_shadows(state))
	_shader_material.set_shader_parameter("saturation", U_CinemaGradeSelectors.get_saturation(state))
	_shader_material.set_shader_parameter("vibrance", U_CinemaGradeSelectors.get_vibrance(state))
	_shader_material.set_shader_parameter("warmth", U_CinemaGradeSelectors.get_warmth(state))
	_shader_material.set_shader_parameter("tint", U_CinemaGradeSelectors.get_tint(state))
	_shader_material.set_shader_parameter("sharpness", U_CinemaGradeSelectors.get_sharpness(state))

func _ensure_cinema_grade_layer() -> bool:
	if _cinema_grade_layer != null and is_instance_valid(_cinema_grade_layer):
		return true
	_setup_cinema_grade_layer()
	return _cinema_grade_layer != null

func _setup_cinema_grade_layer() -> void:
	var tree := _get_tree()
	if tree == null or tree.root == null:
		return

	var post_process_overlay := tree.root.find_child("PostProcessOverlay", true, false)
	if post_process_overlay == null:
		return

	# Check if already exists
	var existing := post_process_overlay.find_child("CinemaGradeLayer", false, false)
	if existing is CanvasLayer:
		_cinema_grade_layer = existing as CanvasLayer
		var rect := _cinema_grade_layer.find_child("CinemaGradeRect", false, false)
		if rect is ColorRect:
			_cinema_grade_rect = rect as ColorRect
			_shader_material = _cinema_grade_rect.material as ShaderMaterial
		return

	# Create CinemaGradeLayer at layer 1 (below FilmGrain=2, Dither=3, CRT=4, ColorBlind=5)
	_cinema_grade_layer = CanvasLayer.new()
	_cinema_grade_layer.name = "CinemaGradeLayer"
	_cinema_grade_layer.layer = 1
	_cinema_grade_layer.follow_viewport_enabled = true

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = CINEMA_GRADE_SHADER

	_cinema_grade_rect = ColorRect.new()
	_cinema_grade_rect.name = "CinemaGradeRect"
	_cinema_grade_rect.material = _shader_material
	_cinema_grade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_cinema_grade_rect.anchor_right = 1.0
	_cinema_grade_rect.anchor_bottom = 1.0
	_cinema_grade_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cinema_grade_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cinema_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_cinema_grade_layer.add_child(_cinema_grade_rect)
	post_process_overlay.add_child(_cinema_grade_layer)

func _get_tree() -> SceneTree:
	if _owner != null:
		return _owner.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null
