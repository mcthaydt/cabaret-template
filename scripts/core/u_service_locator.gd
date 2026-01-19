extends RefCounted
class_name U_ServiceLocator

## Central service registry for manager dependencies
##
## Replaces scattered group lookups with explicit service registration.
## Provides faster lookups (Dictionary vs tree traversal) and makes
## dependencies visible at startup.
##
## Usage:
##   # Registration (typically in root.tscn _ready()):
##   U_ServiceLocator.register(StringName("state_store"), state_store_node)
##
##   # Retrieval (instead of get_tree().get_nodes_in_group("state_store")):
##   var store := U_ServiceLocator.get_service(StringName("state_store")) as M_StateStore
##
## Benefits:
##   - Explicit dependencies (no hidden group lookups)
##   - Faster lookups (O(1) Dictionary vs O(n) tree traversal)
##   - Compile-time visibility of required services
##   - Startup validation ensures all required services exist

## Registry of all registered services
## Key: service_name (StringName)
## Value: service instance (Node)
static var _services: Dictionary = {}

## Dependency requirements per service
## Key: service_name (StringName)
## Value: Array of required service names (Array[StringName])
static var _dependencies: Dictionary = {}

## Track whether the service locator has been initialized
static var _initialized: bool = false

## Register a service instance with the given name
##
## Parameters:
##   service_name: Unique identifier for the service (e.g., "state_store")
##   instance: The service instance (typically a manager node)
##
## Example:
##   U_ServiceLocator.register(StringName("state_store"), $M_StateStore)
static func register(service_name: StringName, instance: Node) -> void:
	if service_name.is_empty():
		push_error("U_ServiceLocator.register: service_name cannot be empty")
		return

	if instance == null or not is_instance_valid(instance):
		push_error("U_ServiceLocator.register: instance is null or invalid for '%s'" % service_name)
		return

	var existing := try_get_service(service_name)
	if existing != null:
		if existing == instance:
			return
		print_verbose("U_ServiceLocator.register: Replacing existing service '%s' (%s -> %s)" % [
			service_name,
			existing.name if existing != null else "",
			instance.name
		])

	_services[service_name] = instance
	print_verbose("U_ServiceLocator: Registered '%s' -> %s" % [service_name, instance.name])

## Retrieve a registered service by name
##
## Parameters:
##   service_name: The service identifier
##
## Returns:
##   The service instance (Node) or null if not found
##
## Example:
##   var store := U_ServiceLocator.get_service(StringName("state_store")) as M_StateStore
static func get_service(service_name: StringName) -> Node:
	if not _services.has(service_name):
		push_error("U_ServiceLocator.get_service: Service '%s' not registered. Available services: %s" % [service_name, _services.keys()])
		return null

	# Get as Variant first to avoid "invalid previously freed instance" error on assignment
	var instance_variant: Variant = _services.get(service_name)
	if instance_variant == null:
		push_error("U_ServiceLocator.get_service: Service '%s' is null" % service_name)
		_services.erase(service_name)
		return null

	# Now check if it's a valid Node instance
	if not is_instance_valid(instance_variant):
		push_error("U_ServiceLocator.get_service: Service '%s' was freed" % service_name)
		_services.erase(service_name)
		return null

	return instance_variant as Node

## Try to retrieve a service by name without logging errors
##
## Use this for optional dependencies where the service may not exist
## (e.g., in test environments or when graceful degradation is acceptable)
##
## Parameters:
##   service_name: The service identifier
##
## Returns:
##   The service instance (Node) or null if not found (silent failure)
##
## Example:
##   var manager := U_ServiceLocator.try_get_service(StringName("input_device_manager"))
##   if manager:
##       # Use manager
##   else:
##       # Fallback behavior
static func try_get_service(service_name: StringName) -> Node:
	if not _services.has(service_name):
		return null

	# Get as Variant first to avoid "invalid previously freed instance" error on assignment
	var instance_variant: Variant = _services.get(service_name)
	if instance_variant == null:
		_services.erase(service_name)
		return null

	# Now check if it's a valid Node instance
	if not is_instance_valid(instance_variant):
		_services.erase(service_name)
		return null

	return instance_variant as Node

## Check if a service is registered
##
## Parameters:
##   service_name: The service identifier
##
## Returns:
##   true if the service is registered and valid, false otherwise
static func has(service_name: StringName) -> bool:
	if not _services.has(service_name):
		return false

	# Get as Variant first to avoid "invalid previously freed instance" error on assignment
	var instance_variant: Variant = _services.get(service_name)
	if instance_variant == null:
		_services.erase(service_name)
		return false

	# Now check if it's a valid instance
	if not is_instance_valid(instance_variant):
		_services.erase(service_name)
		return false

	return true

## Register a dependency relationship
##
## Call this to declare that a service requires another service.
## Used for validation and dependency graph visualization.
##
## Parameters:
##   service_name: The service that has dependencies
##   required_service: A service that must exist for this service to function
##
## Example:
##   U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("state_store"))
static func register_dependency(service_name: StringName, required_service: StringName) -> void:
	if not _dependencies.has(service_name):
		_dependencies[service_name] = []

	var deps: Array = _dependencies[service_name]
	if not deps.has(required_service):
		deps.append(required_service)

## Validate that all registered dependencies are satisfied
##
## Checks that every service's required dependencies are registered.
## Call this after all services are registered (typically at the end of root scene _ready()).
##
## Returns:
##   true if all dependencies are satisfied, false otherwise
static func validate_all() -> bool:
	var all_valid := true

	for service_name in _dependencies:
		var deps: Array = _dependencies[service_name]
		for required_service in deps:
			if not has(required_service):
				push_error("U_ServiceLocator.validate_all: Service '%s' requires '%s' but it is not registered" % [service_name, required_service])
				all_valid = false

	if all_valid:
		print_verbose("U_ServiceLocator: All service dependencies validated successfully")

	return all_valid

## Initialize the service locator with standard services
##
## Called by root scene to register all manager nodes.
## This is a convenience method to centralize all registrations.
##
## Parameters:
##   services: Dictionary mapping service names to node instances
##
## Example:
##   U_ServiceLocator.initialize({
##       StringName("state_store"): $M_StateStore,
##       StringName("scene_manager"): $M_SceneManager,
##       StringName("pause_manager"): $M_PauseManager,
##   })
static func initialize(services: Dictionary) -> void:
	if _initialized:
		push_warning("U_ServiceLocator.initialize: Already initialized, skipping")
		return

	for service_name in services:
		register(service_name, services[service_name])

	_initialized = true
	print_verbose("U_ServiceLocator: Initialized with %d services" % _services.size())

## Get a list of all registered service names
##
## Returns:
##   Array of service names (Array[StringName])
static func get_registered_services() -> Array:
	return _services.keys()

## Clear all registered services
##
## Primarily for testing. Clears the registry and resets initialization state.
static func clear() -> void:
	_services.clear()
	_dependencies.clear()
	_initialized = false
	print_verbose("U_ServiceLocator: Cleared all services")

## Get the dependency graph as a readable string
##
## Returns:
##   String describing all registered services and their dependencies
static func get_dependency_graph() -> String:
	var lines: Array[String] = []
	lines.append("U_ServiceLocator Dependency Graph:")
	lines.append("Registered Services (%d):" % _services.size())

	for service_name in _services:
		var instance: Node = _services[service_name]
		var instance_name: String = "null"
		if instance != null:
			instance_name = instance.name
		lines.append("  - %s -> %s" % [service_name, instance_name])

	lines.append("")
	lines.append("Dependencies:")

	if _dependencies.is_empty():
		lines.append("  (none declared)")
	else:
		for service_name in _dependencies:
			var deps: Array = _dependencies[service_name]
			if deps.is_empty():
				continue
			lines.append("  - %s requires:" % service_name)
			for dep in deps:
				var satisfied := has(dep)
				var status := "✓" if satisfied else "✗"
				lines.append("      %s %s" % [status, dep])

	return "\n".join(lines)
