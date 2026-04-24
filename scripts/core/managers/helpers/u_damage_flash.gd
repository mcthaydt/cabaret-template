class_name U_DamageFlash
extends RefCounted

const FADE_DURATION := 0.4
const MAX_ALPHA := 0.3
const U_TWEEN_MANAGER := preload("res://scripts/core/scene_management/u_tween_manager.gd")

var _flash_rect: ColorRect
var _tween: Tween
var _owner_node: Node


func _init(flash_rect: ColorRect, owner_node: Node) -> void:
	_flash_rect = flash_rect
	_owner_node = owner_node


func trigger_flash(intensity: float = 1.0) -> void:
	if _flash_rect == null or _owner_node == null:
		return

	# Kill existing tween
	U_TWEEN_MANAGER.kill_tween(_tween)

	# Instant jump to max alpha
	_flash_rect.modulate.a = MAX_ALPHA * intensity

	# Fade to 0 over FADE_DURATION
	var config := U_TWEEN_MANAGER.TweenConfig.new()
	config.process_mode = Tween.TWEEN_PROCESS_IDLE
	_tween = U_TWEEN_MANAGER.create_transition_tween(_owner_node, config)
	if _tween == null:
		return
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_flash_rect, "modulate:a", 0.0, FADE_DURATION)


func cancel_flash() -> void:
	U_TWEEN_MANAGER.kill_tween(_tween)
	if _flash_rect != null:
		_flash_rect.modulate.a = 0.0
