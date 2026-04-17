extends GutTest

## Tests for M_StateStore slice dependency strict mode (F4)
##
## Commit 1 (RED): These tests fail until RS_StateStoreSettings gains
## strict_slice_dependencies and get_slice enforces it.

var store: M_StateStore

func before_each() -> void:
	U_StateEventBus.reset()
	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame


func after_each() -> void:
	if store and is_instance_valid(store):
		store.queue_free()
	store = null


func _register_two_slices(b_declares_dep_on_a: bool) -> void:
	var config_a := RS_StateSliceConfig.new(StringName("slice_a"))
	config_a.initial_state = {"value": 1}
	store.register_slice(config_a)

	var config_b := RS_StateSliceConfig.new(StringName("slice_b"))
	config_b.initial_state = {"value": 2}
	if b_declares_dep_on_a:
		config_b.dependencies.append(StringName("slice_a"))
	store.register_slice(config_b)


## --- Strict mode = false (default) ---

## With strict off: undeclared access still returns data (fail-open)
func test_non_strict_undeclared_access_returns_data() -> void:
	store.settings.strict_slice_dependencies = false
	_register_two_slices(false)

	var result := store.get_slice(StringName("slice_a"), StringName("slice_b"))

	assert_push_error("without declaring dependency")
	assert_eq(result.get("value"), 1, "Non-strict mode should return data even for undeclared access")


## With strict off: undeclared access pushes an error
func test_non_strict_undeclared_access_pushes_error() -> void:
	store.settings.strict_slice_dependencies = false
	_register_two_slices(false)

	var _result := store.get_slice(StringName("slice_a"), StringName("slice_b"))

	assert_push_error("without declaring dependency")


## --- Strict mode = true ---

## With strict on: undeclared access returns empty dict
func test_strict_undeclared_access_returns_empty() -> void:
	store.settings.strict_slice_dependencies = true
	_register_two_slices(false)

	var result := store.get_slice(StringName("slice_a"), StringName("slice_b"))

	assert_push_error("without declaring dependency")
	assert_eq(result, {}, "Strict mode should return {} for undeclared access")


## With strict on: undeclared access pushes an error
func test_strict_undeclared_access_pushes_error() -> void:
	store.settings.strict_slice_dependencies = true
	_register_two_slices(false)

	var _result := store.get_slice(StringName("slice_a"), StringName("slice_b"))

	assert_push_error("without declaring dependency")


## --- Declared access (both modes) ---

## Declared access in non-strict mode returns data without error
func test_non_strict_declared_access_returns_data() -> void:
	store.settings.strict_slice_dependencies = false
	_register_two_slices(true)

	var result := store.get_slice(StringName("slice_a"), StringName("slice_b"))

	assert_eq(result.get("value"), 1, "Declared access should return data in non-strict mode")


## Declared access in strict mode returns data without error
func test_strict_declared_access_returns_data() -> void:
	store.settings.strict_slice_dependencies = true
	_register_two_slices(true)

	var result := store.get_slice(StringName("slice_a"), StringName("slice_b"))

	assert_eq(result.get("value"), 1, "Declared access should return data in strict mode")


## Self-access is allowed in strict mode (no self-dependency declaration needed)
func test_strict_self_access_returns_data() -> void:
	store.settings.strict_slice_dependencies = true
	_register_two_slices(false)

	var result := store.get_slice(StringName("slice_a"), StringName("slice_a"))

	assert_eq(result.get("value"), 1, "Self-access should always be allowed")


## Access without caller parameter is always allowed in strict mode
func test_strict_no_caller_returns_data() -> void:
	store.settings.strict_slice_dependencies = true
	_register_two_slices(false)

	var result := store.get_slice(StringName("slice_a"))

	assert_eq(result.get("value"), 1, "No-caller access should always succeed")
