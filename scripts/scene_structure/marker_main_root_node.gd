@icon("res://resources/editor_icons/main_root.svg")
extends Node

## Marker script that gives the Main scene root a dedicated editor icon.
## Also initializes the U_ServiceLocator with all manager instances.

func _ready() -> void:
	_initialize_service_locator()

## Register all managers with the service locator for fast, centralized access
func _initialize_service_locator() -> void:
	# Get references to all manager nodes
	var managers_node := $Managers
	if managers_node == null:
		push_error("Root: Managers node not found")
		return

	# Register all services
	U_ServiceLocator.register(StringName("state_store"), managers_node.get_node("M_StateStore"))
	U_ServiceLocator.register(StringName("cursor_manager"), managers_node.get_node("M_CursorManager"))
	U_ServiceLocator.register(StringName("scene_manager"), managers_node.get_node("M_SceneManager"))
	U_ServiceLocator.register(StringName("pause_manager"), managers_node.get_node("M_PauseManager"))
	U_ServiceLocator.register(StringName("spawn_manager"), managers_node.get_node("M_SpawnManager"))
	U_ServiceLocator.register(StringName("camera_manager"), managers_node.get_node("M_CameraManager"))
	U_ServiceLocator.register(StringName("input_profile_manager"), managers_node.get_node("M_InputProfileManager"))
	U_ServiceLocator.register(StringName("input_device_manager"), managers_node.get_node("M_InputDeviceManager"))
	U_ServiceLocator.register(StringName("ui_input_handler"), managers_node.get_node("M_UIInputHandler"))

	# Register dependencies for validation
	U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("cursor_manager"))
	U_ServiceLocator.register_dependency(StringName("spawn_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("scene_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("camera_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("input_profile_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("input_device_manager"), StringName("state_store"))

	# Validate all dependencies
	if not U_ServiceLocator.validate_all():
		push_error("Root: Service dependency validation failed")

	# Print dependency graph in verbose mode
	print_verbose(U_ServiceLocator.get_dependency_graph())
