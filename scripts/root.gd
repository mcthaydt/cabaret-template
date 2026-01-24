@icon("res://resources/editor_icons/main_root.svg")
extends Node

## Root scene script (dedicated editor icon + ServiceLocator bootstrap).

func _ready() -> void:
	_initialize_service_locator()

## Register all managers with the service locator for fast, centralized access
func _initialize_service_locator() -> void:
	# Get references to all manager nodes
	var managers_node := get_node_or_null("Managers")
	if managers_node == null:
		# Managers node doesn't exist - likely running in test environment
		# Skip ServiceLocator initialization (tests handle their own setup)
		return

	# Check if the critical manager exists (state_store is required for all others)
	# If state_store doesn't exist, we're probably a gameplay scene loaded under root.tscn
	# which already initialized ServiceLocator, or we're in a test environment
	var state_store_node := managers_node.get_node_or_null("M_StateStore")
	if state_store_node == null:
		# No state store in this scene - skip ServiceLocator initialization
		# Tests or root.tscn handle their own ServiceLocator setup
		return

	# Register all services (use get_node_or_null to be defensive)
	_register_if_exists(managers_node, "M_StateStore", StringName("state_store"))
	_register_if_exists(managers_node, "M_CursorManager", StringName("cursor_manager"))
	_register_if_exists(managers_node, "M_SceneManager", StringName("scene_manager"))
	_register_if_exists(managers_node, "M_PauseManager", StringName("pause_manager"))
	_register_if_exists(managers_node, "M_SpawnManager", StringName("spawn_manager"))
	_register_if_exists(managers_node, "M_CameraManager", StringName("camera_manager"))
	_register_if_exists(managers_node, "M_VFXManager", StringName("vfx_manager"))
	_register_if_exists(managers_node, "M_AudioManager", StringName("audio_manager"))
	_register_if_exists(managers_node, "M_InputProfileManager", StringName("input_profile_manager"))
	_register_if_exists(managers_node, "M_InputDeviceManager", StringName("input_device_manager"))
	_register_if_exists(managers_node, "M_UIInputHandler", StringName("ui_input_handler"))
	_register_if_exists(managers_node, "M_SaveManager", StringName("save_manager"))

	# Register dependencies for validation
	U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("cursor_manager"))
	U_ServiceLocator.register_dependency(StringName("spawn_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("scene_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("camera_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("vfx_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("vfx_manager"), StringName("camera_manager"))
	U_ServiceLocator.register_dependency(StringName("audio_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("input_profile_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("input_device_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("save_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("save_manager"), StringName("scene_manager"))

	# Validate all dependencies
	if not U_ServiceLocator.validate_all():
		push_error("Root: Service dependency validation failed")

	# Print dependency graph in verbose mode
	print_verbose(U_ServiceLocator.get_dependency_graph())

## Helper to register a service only if the node exists
func _register_if_exists(parent: Node, node_name: String, service_name: StringName) -> void:
	var node := parent.get_node_or_null(node_name)
	if node != null:
		U_ServiceLocator.register(service_name, node)
