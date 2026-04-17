extends RefCounted
class_name U_DependencyResolution

## Shared dependency resolution utility.
##
## Extracts the "check private cache → check @export → fallback to ServiceLocator"
## pattern that is duplicated across 17 methods in 13 files. Systems and managers
## delegate to this utility instead of implementing their own resolve methods.
##
## Usage:
##   _camera_manager = U_DependencyResolution.resolve(&"camera_manager", _camera_manager, camera_manager) as I_CameraManager
##   _state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self) as I_StateStore

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

## Resolves a service using the standard 3-step dependency resolution pattern:
## 1. Check cached value (private cache, already resolved)
## 2. Check exported value (@export property, injected dependency)
## 3. Fall back to ServiceLocator lookup by service name
##
## Returns the resolved value, or null if unavailable.
## The caller should assign the return value to their private cache variable.
##
## Example:
##   _camera_manager = U_DependencyResolution.resolve(&"camera_manager", _camera_manager, camera_manager) as I_CameraManager
static func resolve(service_name: StringName, cached_value: Variant, exported_value: Variant) -> Variant:
	if cached_value != null and is_instance_valid(cached_value):
		return cached_value
	if exported_value != null and is_instance_valid(exported_value):
		return exported_value
	return U_SERVICE_LOCATOR.try_get_service(service_name)

## Resolves a state store using the standard 3-step pattern with
## U_StateUtils.try_get_store() as the final fallback.
##
## Parameters:
##   cached_value: Private cache variable (e.g., _state_store)
##   exported_value: @export property (e.g., state_store), or null if no @export
##   owner: Node to pass to U_StateUtils.try_get_store() for property/ServiceLocator lookup
##
## Returns the resolved I_StateStore, or null if unavailable.
##
## Example:
##   _state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self) as I_StateStore
static func resolve_state_store(cached_value: Variant, exported_value: Variant, owner: Variant) -> I_StateStore:
	if cached_value != null and is_instance_valid(cached_value):
		return cached_value as I_StateStore
	if exported_value != null and is_instance_valid(exported_value):
		return exported_value as I_StateStore
	if owner != null and is_instance_valid(owner) and owner is Node:
		return U_STATE_UTILS.try_get_store(owner as Node)
	return null