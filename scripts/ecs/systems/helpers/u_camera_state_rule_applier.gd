extends RefCounted
class_name U_CameraStateRuleApplier
## FOV, trauma, and camera-state rule application extracted from S_CameraStateSystem.

const U_RULE_UTILS := preload("res://scripts/utils/ecs/u_rule_utils.gd")
const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const RSRuleContext := preload("res://scripts/resources/ecs/rs_rule_context.gd")
const RS_CAMERA_STATE_CONFIG_SCRIPT := preload("res://scripts/resources/ecs/rs_camera_state_config.gd")
const DEFAULT_CAMERA_STATE_CONFIG := preload("res://resources/base_settings/gameplay/cfg_camera_state_config_default.tres")

const CAMERA_SHAKE_SOURCE := StringName("qb_camera_rule")
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")

var _camera_state_config: Resource = null
var _shake_time: float = 0.0


func configure(camera_state_config: Resource) -> void:
	_camera_state_config = camera_state_config


func apply_camera_state(contexts: Array, delta: float, manager: I_CAMERA_MANAGER) -> void:
	if manager == null:
		return

	var context: Dictionary = select_primary_camera_context(contexts)
	var primary_camera_state: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CAMERA_STATE_COMPONENT)
	decay_non_primary_trauma(contexts, primary_camera_state, delta)
	if context.is_empty():
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	if primary_camera_state == null or not (primary_camera_state is Object):
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		return

	var main_camera: Camera3D = manager.get_main_camera()
	if main_camera != null:
		apply_fov_to_camera(main_camera, primary_camera_state, context, delta)

	apply_trauma_shake(manager, primary_camera_state, delta)


func decay_non_primary_trauma(contexts: Array, primary_camera_state: Variant, delta: float) -> void:
	if delta <= 0.0:
		return

	var config: Dictionary = resolve_camera_state_config_values()
	var processed_states: Dictionary = {}
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant as Dictionary
		var camera_state: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CAMERA_STATE_COMPONENT)
		if camera_state == null or not (camera_state is Object):
			continue
		if primary_camera_state != null and camera_state == primary_camera_state:
			continue

		var camera_state_object: Object = camera_state as Object
		var state_id: int = camera_state_object.get_instance_id()
		if processed_states.has(state_id):
			continue
		processed_states[state_id] = true
		decay_trauma(camera_state_object, delta, config)


func select_primary_camera_context(contexts: Array) -> Dictionary:
	var fallback: Dictionary = {}
	for context_variant in contexts:
		if not (context_variant is Dictionary):
			continue
		var context: Dictionary = context_variant as Dictionary
		if fallback.is_empty():
			fallback = context
		if is_primary_camera_context(context):
			return context
	return fallback


func is_primary_camera_context(context: Dictionary) -> bool:
	var id_variant: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CAMERA_ENTITY_ID)
	if id_variant == null:
		id_variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_ENTITY_ID)
	var entity_id: StringName = U_RuleUtils.variant_to_string_name(id_variant)
	if entity_id == PRIMARY_CAMERA_ENTITY_ID:
		return true

	var tags_variant: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_CAMERA_ENTITY_TAGS)
	if tags_variant == null:
		tags_variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_ENTITY_TAGS)
	if tags_variant is Array:
		var tags: Array = tags_variant as Array
		return tags.has(PRIMARY_CAMERA_ENTITY_ID) or tags.has(String(PRIMARY_CAMERA_ENTITY_ID))
	return false


func resolve_camera_state_config_values() -> Dictionary:
	var defaults := {
		"trauma_decay_rate": 2.0,
		"max_offset_x": 10.0,
		"max_offset_y": 10.0,
		"max_rotation_rad": 0.03,
		"shake_frequency": Vector3(17.0, 21.0, 13.0),
		"shake_phase": Vector3(1.1, 2.3, 0.7),
		"fov_min": 1.0,
		"fov_max": 179.0,
	}
	var config_variant: Variant = _camera_state_config
	if config_variant == null:
		config_variant = DEFAULT_CAMERA_STATE_CONFIG
	if config_variant == null or not (config_variant is Resource):
		return defaults

	var config_resource: Resource = config_variant as Resource
	if config_resource.get_script() != RS_CAMERA_STATE_CONFIG_SCRIPT:
		return defaults

	var fov_min: float = float(config_resource.get("fov_min"))
	var fov_max: float = maxf(float(config_resource.get("fov_max")), fov_min)
	return {
		"trauma_decay_rate": maxf(float(config_resource.get("trauma_decay_rate")), 0.0),
		"max_offset_x": maxf(float(config_resource.get("max_offset_x")), 0.0),
		"max_offset_y": maxf(float(config_resource.get("max_offset_y")), 0.0),
		"max_rotation_rad": maxf(float(config_resource.get("max_rotation_rad")), 0.0),
		"shake_frequency": config_resource.get("shake_frequency") as Vector3,
		"shake_phase": config_resource.get("shake_phase") as Vector3,
		"fov_min": fov_min,
		"fov_max": fov_max,
	}


func clamp_fov(value: float, config: Dictionary) -> float:
	var fov_min: float = float(config.get("fov_min", 1.0))
	var fov_max: float = maxf(float(config.get("fov_max", 179.0)), fov_min)
	return clampf(value, fov_min, fov_max)


func apply_fov_to_camera(camera: Camera3D, camera_state: Variant, context: Dictionary, delta: float) -> void:
	var config: Dictionary = resolve_camera_state_config_values()
	var baseline_fov: float = ensure_baseline_fov(camera_state, camera.fov, config)
	var target_fov: float = resolve_target_fov(camera_state, context, baseline_fov, config)
	write_target_fov(camera_state, target_fov, config)

	var blend_speed: float = maxf(
		get_camera_state_float(camera_state, "fov_blend_speed", C_CAMERA_STATE_COMPONENT.DEFAULT_FOV_BLEND_SPEED),
		0.0
	)
	if blend_speed <= 0.0:
		camera.fov = target_fov
		return

	var alpha: float = clampf(blend_speed * maxf(delta, 0.0), 0.0, 1.0)
	if alpha <= 0.0:
		return
	camera.fov = lerpf(camera.fov, target_fov, alpha)


func resolve_target_fov(
	camera_state: Variant,
	context: Dictionary,
	baseline_fov: float,
	config: Dictionary
) -> float:
	var base_target_fov: float = baseline_fov
	if is_fov_zone_active(context):
		base_target_fov = get_camera_state_float(
			camera_state,
			"target_fov",
			C_CAMERA_STATE_COMPONENT.DEFAULT_TARGET_FOV
		)
	var resolved_base_target_fov: float = clamp_fov(base_target_fov, config)
	var speed_fov_bonus: float = resolve_speed_fov_bonus(camera_state)
	return clamp_fov(resolved_base_target_fov + speed_fov_bonus, config)


func ensure_baseline_fov(camera_state: Variant, fallback_fov: float, config: Dictionary) -> float:
	var existing_baseline: float = get_camera_state_float(
		camera_state,
		"base_fov",
		C_CAMERA_STATE_COMPONENT.UNSET_BASE_FOV
	)
	if existing_baseline > 1.0:
		return clamp_fov(existing_baseline, config)

	var resolved_baseline: float = clamp_fov(fallback_fov, config)
	write_baseline_fov(camera_state, resolved_baseline, config)
	return resolved_baseline


func is_fov_zone_active(context: Dictionary) -> bool:
	var state_variant: Variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_STATE)
	if state_variant == null:
		state_variant = U_RuleUtils.get_context_value(context, RSRuleContext.KEY_REDUX_STATE)
	if not (state_variant is Dictionary):
		return false
	return U_VCAM_SELECTORS.is_in_fov_zone(state_variant as Dictionary)


func write_target_fov(camera_state: Variant, value: float, config: Dictionary) -> void:
	var clamped: float = clamp_fov(value, config)
	if camera_state is Object and (camera_state as Object).has_method("set_target_fov"):
		(camera_state as Object).call("set_target_fov", clamped)
		return
	if camera_state is Object:
		(camera_state as Object).set("target_fov", clamped)


func write_baseline_fov(camera_state: Variant, value: float, config: Dictionary) -> void:
	var clamped: float = clamp_fov(value, config)
	if camera_state is Object and (camera_state as Object).has_method("set_base_fov"):
		(camera_state as Object).call("set_base_fov", clamped)
		return
	if camera_state is Object:
		(camera_state as Object).set("base_fov", clamped)


func resolve_speed_fov_bonus(camera_state: Variant) -> float:
	var raw_bonus: float = get_camera_state_float(
		camera_state,
		"speed_fov_bonus",
		C_CAMERA_STATE_COMPONENT.DEFAULT_SPEED_FOV_BONUS
	)
	var max_bonus: float = maxf(
		get_camera_state_float(
			camera_state,
			"speed_fov_max_bonus",
			C_CAMERA_STATE_COMPONENT.DEFAULT_SPEED_FOV_MAX_BONUS
		),
		0.0
	)
	var clamped_bonus: float = clampf(raw_bonus, 0.0, max_bonus)
	if not is_equal_approx(clamped_bonus, raw_bonus):
		write_speed_fov_bonus(camera_state, clamped_bonus)
	return clamped_bonus


func write_speed_fov_bonus(camera_state: Variant, value: float) -> void:
	if camera_state == null or not (camera_state is Object):
		return
	var object_value: Object = camera_state as Object
	if not U_RuleUtils.object_has_property(object_value, "speed_fov_bonus"):
		return
	object_value.set("speed_fov_bonus", maxf(value, 0.0))


func apply_trauma_shake(manager: I_CAMERA_MANAGER, camera_state: Variant, delta: float) -> void:
	var config: Dictionary = resolve_camera_state_config_values()
	var trauma: float = clampf(get_camera_state_float(camera_state, "shake_trauma", 0.0), 0.0, 1.0)
	if trauma <= 0.0:
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)
		write_shake_trauma(camera_state, 0.0)
		return

	_shake_time += maxf(delta, 0.0)
	var shake_strength: float = trauma * trauma
	var shake_frequency: Vector3 = config.get("shake_frequency", Vector3(17.0, 21.0, 13.0)) as Vector3
	var shake_phase: Vector3 = config.get("shake_phase", Vector3(1.1, 2.3, 0.7)) as Vector3
	var max_offset_x: float = maxf(float(config.get("max_offset_x", 10.0)), 0.0)
	var max_offset_y: float = maxf(float(config.get("max_offset_y", 10.0)), 0.0)
	var max_rotation_rad: float = maxf(float(config.get("max_rotation_rad", 0.03)), 0.0)
	var offset: Vector2 = Vector2(
		sin(_shake_time * shake_frequency.x + shake_phase.x) * max_offset_x * shake_strength,
		cos(_shake_time * shake_frequency.y + shake_phase.y) * max_offset_y * shake_strength
	)
	var rotation: float = sin(
		_shake_time * shake_frequency.z + shake_phase.z
	) * max_rotation_rad * shake_strength
	manager.set_shake_source(CAMERA_SHAKE_SOURCE, offset, rotation)

	var decayed_trauma: float = decay_trauma(camera_state, delta, config)
	if decayed_trauma <= 0.0:
		manager.clear_shake_source(CAMERA_SHAKE_SOURCE)


func decay_trauma(camera_state: Variant, delta: float, config: Dictionary = {}) -> float:
	var trauma: float = clampf(get_camera_state_float(camera_state, "shake_trauma", 0.0), 0.0, 1.0)
	if delta <= 0.0:
		return trauma

	var trauma_decay_rate: float = maxf(float(config.get("trauma_decay_rate", 2.0)), 0.0)
	var decayed_trauma: float = maxf(trauma - trauma_decay_rate * delta, 0.0)
	write_shake_trauma(camera_state, decayed_trauma)
	return decayed_trauma


func write_shake_trauma(camera_state: Variant, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if camera_state is Object and (camera_state as Object).has_method("set_shake_trauma"):
		(camera_state as Object).call("set_shake_trauma", clamped)
		return
	if camera_state is Object:
		(camera_state as Object).set("shake_trauma", clamped)


func get_camera_state_float(camera_state: Variant, property_name: String, fallback: float) -> float:
	if camera_state == null or not (camera_state is Object):
		return fallback
	var object_value: Object = camera_state as Object
	if not U_RuleUtils.object_has_property(object_value, property_name):
		return fallback
	return U_RuleUtils.read_float_property(object_value, property_name, fallback)