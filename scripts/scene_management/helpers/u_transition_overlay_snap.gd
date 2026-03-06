extends RefCounted
class_name U_TransitionOverlaySnap

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

## Hide a screen immediately and snap TransitionColorRect to opaque black.
## Used by endgame button flows before dispatching navigation actions.
static func hide_screen_and_snap_transition_overlay(screen: CanvasItem) -> void:
	if screen != null:
		screen.visible = false

	var overlay := U_SERVICE_LOCATOR.try_get_service(StringName("transition_overlay")) as CanvasLayer
	if overlay == null:
		return

	for child in overlay.get_children():
		if child is ColorRect and child.name == "TransitionColorRect":
			(child as ColorRect).modulate.a = 1.0
			break
