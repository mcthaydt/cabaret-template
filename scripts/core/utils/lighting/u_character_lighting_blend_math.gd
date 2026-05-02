extends RefCounted
class_name U_CharacterLightingBlendMath

const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 8.0
const MIN_SMOOTHING := 0.0
const MAX_SMOOTHING := 1.0

static func blend_zone_profiles(zone_inputs: Array, default_profile: Dictionary) -> Dictionary:
	var fallback_profile: Dictionary = _sanitize_profile(default_profile)
	var valid_sources: Array[Dictionary] = _collect_valid_sources(zone_inputs)

	if valid_sources.is_empty():
		var fallback_result := fallback_profile.duplicate(true)
		fallback_result["sources"] = []
		return fallback_result

	valid_sources.sort_custom(_compare_sources)

	var zone_weight_total: float = 0.0
	for source in valid_sources:
		zone_weight_total += float(source.get("weight", 0.0))

	if zone_weight_total <= 0.0:
		var zero_result := fallback_profile.duplicate(true)
		zero_result["sources"] = []
		return zero_result

	var default_weight: float = clampf(1.0 - zone_weight_total, 0.0, 1.0)
	var total_weight: float = zone_weight_total + default_weight
	if total_weight <= 0.0:
		var fallback_result := fallback_profile.duplicate(true)
		fallback_result["sources"] = []
		return fallback_result

	var tint_accumulator := Color(0.0, 0.0, 0.0, 0.0)
	var intensity_accumulator: float = 0.0
	var smoothing_accumulator: float = 0.0
	var sources_snapshot: Array[Dictionary] = []

	if default_weight > 0.0:
		var normalized_default_weight: float = default_weight / total_weight
		var fallback_tint: Color = fallback_profile.get("tint", Color(1.0, 1.0, 1.0, 1.0))
		var fallback_intensity: float = float(fallback_profile.get("intensity", 1.0))
		var fallback_smoothing: float = float(fallback_profile.get("blend_smoothing", 0.15))

		tint_accumulator += fallback_tint * normalized_default_weight
		intensity_accumulator += fallback_intensity * normalized_default_weight
		smoothing_accumulator += fallback_smoothing * normalized_default_weight

	for source in valid_sources:
		var normalized_weight: float = float(source.get("weight", 0.0)) / total_weight
		var profile: Dictionary = source.get("profile", {})
		var tint: Color = profile.get("tint", Color(1.0, 1.0, 1.0, 1.0))
		var intensity: float = float(profile.get("intensity", 1.0))
		var blend_smoothing: float = float(profile.get("blend_smoothing", 0.15))

		tint_accumulator += tint * normalized_weight
		intensity_accumulator += intensity * normalized_weight
		smoothing_accumulator += blend_smoothing * normalized_weight
		sources_snapshot.append({
			"zone_id": source.get("zone_id", StringName("")),
			"priority": int(source.get("priority", 0)),
			"normalized_weight": normalized_weight,
		})

	return {
		"tint": tint_accumulator,
		"intensity": clampf(intensity_accumulator, MIN_INTENSITY, MAX_INTENSITY),
		"blend_smoothing": clampf(smoothing_accumulator, MIN_SMOOTHING, MAX_SMOOTHING),
		"sources": sources_snapshot.duplicate(true),
	}

static func _collect_valid_sources(zone_inputs: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_variant in zone_inputs:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary

		var weight_value: Variant = source.get("weight", source.get("blend_weight", 0.0))
		var weight: float = clampf(_to_float(weight_value, 0.0), 0.0, 1.0)
		if weight <= 0.0:
			continue

		var profile_variant: Variant = source.get("profile", {})
		var profile: Dictionary = {}
		if profile_variant is Dictionary:
			profile = _sanitize_profile(profile_variant as Dictionary)
		elif profile_variant != null and profile_variant.has_method("get_resolved_values"):
			var resolved_variant: Variant = profile_variant.call("get_resolved_values")
			if resolved_variant is Dictionary:
				profile = _sanitize_profile(resolved_variant as Dictionary)

		if profile.is_empty():
			continue

		result.append({
			"zone_id": _to_string_name(source.get("zone_id", StringName(""))),
			"priority": int(source.get("priority", 0)),
			"weight": weight,
			"profile": profile.duplicate(true),
		})
	return result

static func _sanitize_profile(input_profile: Dictionary) -> Dictionary:
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	var tint_variant: Variant = input_profile.get("tint", tint)
	if tint_variant is Color:
		tint = tint_variant

	var intensity: float = clampf(_to_float(input_profile.get("intensity", 1.0), 1.0), MIN_INTENSITY, MAX_INTENSITY)
	var blend_smoothing: float = clampf(
		_to_float(input_profile.get("blend_smoothing", 0.15), 0.15),
		MIN_SMOOTHING,
		MAX_SMOOTHING
	)
	return {
		"tint": tint,
		"intensity": intensity,
		"blend_smoothing": blend_smoothing,
	}

static func _compare_sources(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = int(a.get("priority", 0))
	var priority_b: int = int(b.get("priority", 0))
	if priority_a != priority_b:
		return priority_a > priority_b

	var weight_a: float = float(a.get("weight", 0.0))
	var weight_b: float = float(b.get("weight", 0.0))
	if not is_equal_approx(weight_a, weight_b):
		return weight_a > weight_b

	var zone_id_a: String = String(a.get("zone_id", StringName("")))
	var zone_id_b: String = String(b.get("zone_id", StringName("")))
	return zone_id_a < zone_id_b

static func _to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")
