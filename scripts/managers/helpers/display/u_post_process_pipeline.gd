extends RefCounted
class_name U_PostProcessPipeline

## Two-pass post-processing coordinator for gl_compatibility mode.
##
## Owns an ordered list of passes (color_grading first, grain_dither second).
## Each pass is a ColorRect + ShaderMaterial pair registered against the
## PostProcessOverlay node tree.
##
## Responsibilities:
## - Deterministic ordered evaluation (registration order preserved)
## - Per-pass enable/disable via set_pass_visible (applier-driven)
## - Per-pass enable/disable via apply_settings for simple {pass_id}_enabled keys
## - Unified fg_time frame counter for time-based shader uniforms
## - Clean teardown via unregister_pass / clear
##
## Usage:
##   pipeline.register_pass(&"color_grading", rect, shader)
##   pipeline.register_pass(&"grain_dither", rect, shader)
##   pipeline.set_pass_visible(&"color_grading", true)   # applier delegates visibility
##   pipeline.apply_settings(display)    # or: drive visibility from display state keys
##   pipeline.update_per_frame()         # advances fg_time on all passes
##   pipeline.clear()                   # teardown

var _passes: Dictionary = {}      # StringName → {rect, shader, material}
var _pass_order: Array = []       # Array of StringName, registration order
var _last_fg_time: float = 0.0    # Monotonic fg_time for frame-counter uniform

## Register a pass. If the pass_id already exists, the rect and shader are
## updated in-place and the position in the evaluation order is preserved.
func register_pass(pass_id: StringName, rect: ColorRect, shader: Shader) -> void:
	var material := rect.material as ShaderMaterial
	var is_new := not _passes.has(pass_id)
	_passes[pass_id] = {"rect": rect, "shader": shader, "material": material}
	if is_new:
		_pass_order.append(pass_id)

## Return the pass data Dictionary for pass_id, or null if not registered.
func get_pass(pass_id: StringName) -> Variant:
	if not _passes.has(pass_id):
		return null
	return _passes[pass_id]

## Return the ordered list of registered pass IDs (copy).
func get_pass_order() -> Array:
	return _pass_order.duplicate()

## Set visibility for a single pass by pass_id.
## This is the preferred way for appliers to control their pass visibility —
## all visibility changes flow through the pipeline rather than being set
## directly on the ColorRect.
func set_pass_visible(pass_id: StringName, visible: bool) -> void:
	if not _passes.has(pass_id):
		return
	var pass_data: Dictionary = _passes[pass_id]
	pass_data["rect"].visible = visible

## Drive per-pass visibility from the display sub-slice.
## Convention: display[str(pass_id) + "_enabled"] → bool.
## If the key is absent the pass visibility is left unchanged.
## Callers are responsible for extracting the display slice via selectors before calling.
func apply_settings(display: Dictionary) -> void:
	for pass_id in _pass_order:
		var enabled_key: String = str(pass_id) + "_enabled"
		if not display.has(enabled_key):
			continue
		var pass_data: Dictionary = _passes[pass_id]
		pass_data["rect"].visible = bool(display[enabled_key])

## Advance the fg_time shader uniform on all registered passes.
## Called once per frame from M_DisplayManager._process.
## Uses wall-clock time with a monotonic guard so two consecutive calls
## (e.g. in unit tests) always produce strictly increasing values.
func update_per_frame() -> void:
	var wall_time: float = float(Time.get_ticks_usec()) / 1_000_000.0
	var time_seconds: float = maxf(wall_time, _last_fg_time + 0.0001)
	_last_fg_time = time_seconds
	for pass_id in _pass_order:
		var pass_data: Dictionary = _passes[pass_id]
		var material: ShaderMaterial = pass_data.get("material") as ShaderMaterial
		if material != null:
			material.set_shader_parameter(StringName("fg_time"), time_seconds)

## Remove a single pass from the pipeline.
func unregister_pass(pass_id: StringName) -> void:
	if _passes.has(pass_id):
		_passes.erase(pass_id)
		_pass_order.erase(pass_id)

## Remove all registered passes.
func clear() -> void:
	_passes.clear()
	_pass_order.clear()