extends GutTest

const StateUtils := preload("res://scripts/state/u_state_utils.gd")

func test_safe_duplicate_returns_dictionary_deep_copy():
	var original: Dictionary = {"a": 1, "b": {"c": 2}}
	var copied: Variant = StateUtils.safe_duplicate(original)

	assert_eq(copied, original, "Copy should equal original")

	# Modify nested value to verify it's a deep copy (different object)
	copied["b"]["c"] = 999

	assert_eq(original["b"]["c"], 2, "Original should be unchanged (deep copy)")
	assert_eq(copied["b"]["c"], 999, "Copy should reflect changes")

func test_safe_duplicate_returns_array_deep_copy():
	var original: Array = [1, 2, [3, 4]]
	var copied: Variant = StateUtils.safe_duplicate(original)

	assert_eq(copied, original, "Copy should equal original")

	# Modify nested array to verify it's a deep copy (different object)
	copied[2][0] = 999

	assert_eq(original[2][0], 3, "Original should be unchanged (deep copy)")
	assert_eq(copied[2][0], 999, "Copy should reflect changes")

func test_safe_duplicate_returns_primitives_as_is():
	assert_eq(StateUtils.safe_duplicate(42), 42, "Int should be returned as-is")
	assert_eq(StateUtils.safe_duplicate(3.14), 3.14, "Float should be returned as-is")
	assert_eq(StateUtils.safe_duplicate(true), true, "Bool should be returned as-is")
	assert_eq(StateUtils.safe_duplicate("test"), "test", "String should be returned as-is")
	assert_eq(StateUtils.safe_duplicate(StringName("test")), StringName("test"), "StringName should be returned as-is")
	assert_eq(StateUtils.safe_duplicate(null), null, "Null should be returned as-is")

func test_safe_duplicate_shallow_mode():
	var original: Dictionary = {"a": 1, "b": {"c": 2}}
	var copied: Variant = StateUtils.safe_duplicate(original, false)

	assert_eq(copied, original, "Shallow copy should equal original")

	# With shallow copy, nested dict is same reference
	copied["b"]["c"] = 999

	assert_eq(original["b"]["c"], 999, "Original should change (shallow copy)")
	assert_eq(copied["b"]["c"], 999, "Copy should reflect changes")

func test_safe_duplicate_handles_empty_dict():
	var original: Dictionary = {}
	var copied: Variant = StateUtils.safe_duplicate(original)

	assert_eq(copied, {}, "Empty dict should be copied")
	# Note: Can't test reference inequality for built-in types with ==
	# The fact that duplicate() returns without error is sufficient

func test_safe_duplicate_handles_empty_array():
	var original: Array = []
	var copied: Variant = StateUtils.safe_duplicate(original)

	assert_eq(copied, [], "Empty array should be copied")
	# Note: Can't test reference inequality for built-in types with ==
	# The fact that duplicate() returns without error is sufficient
