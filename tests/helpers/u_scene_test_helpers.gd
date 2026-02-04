extends RefCounted
class_name U_SceneTestHelpers

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_CAMERA_MANAGER := preload("res://scripts/managers/m_camera_manager.gd")

static func create_root_with_containers(register_overlays: bool = false) -> Dictionary:
	var root := Node.new()
	root.name = "Root"

	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	root.add_child(game_viewport)

	var active_scene_container := Node.new()
	active_scene_container.name = "ActiveSceneContainer"
	game_viewport.add_child(active_scene_container)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	root.add_child(hud_layer)

	var ui_overlay_stack := CanvasLayer.new()
	ui_overlay_stack.name = "UIOverlayStack"
	ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(ui_overlay_stack)

	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	transition_overlay.add_child(color_rect)
	root.add_child(transition_overlay)

	var loading_overlay := CanvasLayer.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.visible = false
	loading_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(loading_overlay)

	if register_overlays:
		U_SERVICE_LOCATOR.register(StringName("transition_overlay"), transition_overlay)
		U_SERVICE_LOCATOR.register(StringName("loading_overlay"), loading_overlay)

	return {
		"root": root,
		"game_viewport": game_viewport,
		"active_scene_container": active_scene_container,
		"hud_layer": hud_layer,
		"ui_overlay_stack": ui_overlay_stack,
		"transition_overlay": transition_overlay,
		"loading_overlay": loading_overlay,
	}

static func register_scene_manager_dependencies(root: Node, include_cursor: bool = true, include_spawn: bool = true, include_camera: bool = true) -> Dictionary:
	var result: Dictionary = {}
	if root == null:
		return result

	# Register optional managers to avoid warnings during M_SceneManager._ready().
	if include_cursor:
		var cursor_manager := M_CURSOR_MANAGER.new()
		root.add_child(cursor_manager)
		U_SERVICE_LOCATOR.register(StringName("cursor_manager"), cursor_manager)
		result["cursor_manager"] = cursor_manager

	if include_spawn:
		var spawn_manager := M_SPAWN_MANAGER.new()
		root.add_child(spawn_manager)
		U_SERVICE_LOCATOR.register(StringName("spawn_manager"), spawn_manager)
		result["spawn_manager"] = spawn_manager

	if include_camera:
		var camera_manager := M_CAMERA_MANAGER.new()
		root.add_child(camera_manager)
		U_SERVICE_LOCATOR.register(StringName("camera_manager"), camera_manager)
		result["camera_manager"] = camera_manager

	return result

static func wait_for_transition_idle(manager: Node, max_frames: int = 120) -> void:
	if manager == null or not is_instance_valid(manager):
		return
	var tree := manager.get_tree()
	if tree == null:
		return

	var frames := 0
	while frames < max_frames and is_instance_valid(manager):
		var queue_helper: Variant = manager.get("_transition_queue_helper")
		var processing := false
		if queue_helper != null and queue_helper.has_method("is_processing"):
			processing = queue_helper.is_processing()

		var scheduled := false
		var scheduled_variant: Variant = manager.get("_queue_processing_scheduled")
		if scheduled_variant is bool:
			scheduled = scheduled_variant

		if not processing and not scheduled:
			break

		await tree.physics_frame
		frames += 1
