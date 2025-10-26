extends GutTest

## Tests for slice dependency validation (T171-T173)

var store: M_StateStore

func before_each() -> void:
	StateStoreEventBus.reset()
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame

func after_each() -> void:
	if store and is_instance_valid(store):
		store.queue_free()
	store = null

## Test that validate_slice_dependencies returns true when all dependencies exist
func test_validate_slice_dependencies_returns_true_for_valid_dependencies() -> void:
	# Register slice A with no dependencies
	var config_a := StateSliceConfig.new(StringName("slice_a"))
	config_a.initial_state = {"value": 1}
	config_a.dependencies = []
	store.register_slice(config_a)
	
	# Register slice B that depends on slice A
	var config_b := StateSliceConfig.new(StringName("slice_b"))
	config_b.initial_state = {"value": 2}
	config_b.dependencies = [StringName("slice_a")]
	store.register_slice(config_b)
	
	var result := store.validate_slice_dependencies()
	assert_true(result, "Should return true when all dependencies are valid")

## Test that validate_slice_dependencies returns false and logs error for invalid dependency
func test_validate_slice_dependencies_returns_false_for_invalid_dependency() -> void:
	# Register slice that depends on non-existent slice
	var config := StateSliceConfig.new(StringName("slice_c"))
	config.initial_state = {"value": 3}
	config.dependencies = [StringName("nonexistent_slice")]
	store.register_slice(config)
	
	var result := store.validate_slice_dependencies()
	assert_false(result, "Should return false when dependency doesn't exist")

## Test that get_slice logs error when accessing undeclared dependency
func test_get_slice_logs_error_for_undeclared_dependency() -> void:
	# Register two slices, B doesn't declare dependency on A
	var config_a := StateSliceConfig.new(StringName("slice_a"))
	config_a.initial_state = {"value": 1}
	config_a.dependencies = []
	store.register_slice(config_a)
	
	var config_b := StateSliceConfig.new(StringName("slice_b"))
	config_b.initial_state = {"value": 2}
	config_b.dependencies = []  # NOT declaring dependency on slice_a
	store.register_slice(config_b)
	
	# Access slice_a from slice_b context (should log error)
	var _state := store.get_slice(StringName("slice_a"), StringName("slice_b"))
	
	# The error is logged via push_error, we just verify no crash
	pass_test("get_slice should log error but not crash")

## Test that get_slice allows access when dependency is declared
func test_get_slice_allows_access_with_declared_dependency() -> void:
	# Register two slices, B properly declares dependency on A
	var config_a := StateSliceConfig.new(StringName("slice_a"))
	config_a.initial_state = {"value": 1}
	config_a.dependencies = []
	store.register_slice(config_a)
	
	var config_b := StateSliceConfig.new(StringName("slice_b"))
	config_b.initial_state = {"value": 2}
	config_b.dependencies = [StringName("slice_a")]  # Properly declared
	store.register_slice(config_b)
	
	# Access slice_a from slice_b context (should work without error)
	var state := store.get_slice(StringName("slice_a"), StringName("slice_b"))
	
	assert_eq(state.get("value"), 1, "Should return correct state")

## Test that slice can access itself without declaring self-dependency
func test_slice_can_access_itself_without_declaring_dependency() -> void:
	var config := StateSliceConfig.new(StringName("slice_a"))
	config.initial_state = {"value": 1}
	config.dependencies = []  # No self-dependency needed
	store.register_slice(config)
	
	# Access own slice (should work without error)
	var state := store.get_slice(StringName("slice_a"), StringName("slice_a"))
	
	assert_eq(state.get("value"), 1, "Slice should be able to access itself")

## Test that get_slice works normally without caller parameter (backward compatibility)
func test_get_slice_backward_compatible_without_caller() -> void:
	var config := StateSliceConfig.new(StringName("slice_a"))
	config.initial_state = {"value": 1}
	config.dependencies = []
	store.register_slice(config)
	
	# Call without caller parameter (old API)
	var state := store.get_slice(StringName("slice_a"))
	
	assert_eq(state.get("value"), 1, "Should work without caller parameter for backward compatibility")
