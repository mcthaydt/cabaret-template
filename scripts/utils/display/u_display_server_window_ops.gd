extends I_WindowOps
class_name U_DisplayServerWindowOps

## DisplayServer-backed window operations for production.

func is_real_window_backend() -> bool:
	return true

func is_available() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	return not (OS.has_feature("headless") or OS.has_feature("server") or display_name == "headless" or display_name == "dummy")

func get_backend_name() -> String:
	return DisplayServer.get_name()

func get_os_name() -> String:
	return OS.get_name()

func window_get_mode() -> int:
	return DisplayServer.window_get_mode()

func window_set_mode(mode: int) -> void:
	DisplayServer.window_set_mode(mode)

func window_get_flag(flag: int) -> bool:
	return DisplayServer.window_get_flag(flag)

func window_set_flag(flag: int, enabled: bool) -> void:
	DisplayServer.window_set_flag(flag, enabled)

func window_get_size() -> Vector2i:
	return DisplayServer.window_get_size()

func window_set_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)

func window_set_position(position: Vector2i) -> void:
	DisplayServer.window_set_position(position)

func screen_get_size(screen: int = -1) -> Vector2i:
	return DisplayServer.screen_get_size(screen)

func window_get_vsync_mode() -> int:
	return DisplayServer.window_get_vsync_mode()

func window_set_vsync_mode(mode: int) -> void:
	DisplayServer.window_set_vsync_mode(mode)

func window_get_current_screen() -> int:
	return DisplayServer.window_get_current_screen()

func screen_get_usable_rect(screen: int) -> Rect2i:
	return DisplayServer.screen_get_usable_rect(screen)

