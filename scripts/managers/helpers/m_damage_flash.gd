class_name M_DamageFlash
extends RefCounted

const FADE_DURATION := 0.4
const MAX_ALPHA := 0.3

var _flash_rect: ColorRect
var _tween: Tween
var _tween_pause_mode: int = -1
var _scene_tree: SceneTree


func _init(flash_rect: ColorRect, scene_tree: SceneTree) -> void:
	_flash_rect = flash_rect
	_scene_tree = scene_tree


func trigger_flash(intensity: float = 1.0) -> void:
	if _flash_rect == null or _scene_tree == null:
		return

	# Kill existing tween
	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Instant jump to max alpha
	_flash_rect.modulate.a = MAX_ALPHA * intensity

	# Fade to 0 over FADE_DURATION
	_tween = _scene_tree.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_pause_mode = Tween.TWEEN_PAUSE_PROCESS
	_tween.tween_property(_flash_rect, "modulate:a", 0.0, FADE_DURATION)
