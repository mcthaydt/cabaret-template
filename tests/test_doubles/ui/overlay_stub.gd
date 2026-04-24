extends "res://scripts/core/ui/base/base_overlay.gd"

var back_pressed: bool = false

func _on_back_pressed() -> void:
	back_pressed = true
