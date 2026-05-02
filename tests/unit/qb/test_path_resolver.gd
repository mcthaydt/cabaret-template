extends BaseTest

const PATH_RESOLVER := preload("res://scripts/core/utils/qb/u_path_resolver.gd")

class MockObject extends RefCounted:
	var nested: Dictionary = {
		"value": 7
	}
	var child: Variant = null

	func _init() -> void:
		child = MockChild.new()

	func do_not_call() -> int:
		return 99

class MockChild extends RefCounted:
	var payload: Dictionary = {
		"answer": 42
	}

func test_resolve_single_key_dictionary_path() -> void:
	var root: Dictionary = {
		"health": 100
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "health")
	assert_eq(value, 100)

func test_resolve_nested_dictionary_path() -> void:
	var root: Dictionary = {
		"a": {
			"b": 5
		}
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "a.b")
	assert_eq(value, 5)

func test_resolve_dictionary_key_string_and_string_name_duality() -> void:
	var string_name_root: Dictionary = {
		StringName("health"): 80
	}
	var string_root: Dictionary = {
		"stamina": 40
	}

	var from_string_path: Variant = PATH_RESOLVER.resolve(string_name_root, "health")
	assert_eq(from_string_path, 80)

	var from_string_name_path: Variant = PATH_RESOLVER.resolve(string_root, StringName("stamina"))
	assert_eq(from_string_name_path, 40)

func test_resolve_array_index_from_string_segment() -> void:
	var root: Dictionary = {
		"items": [10, 20]
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "items.1")
	assert_eq(value, 20)

func test_resolve_object_property() -> void:
	var node: Node = Node.new()
	node.name = "ResolverNode"
	autoqfree(node)

	var value: Variant = PATH_RESOLVER.resolve(node, "name")
	assert_eq(value, "ResolverNode")

func test_resolve_mixed_nesting_dictionary_object_dictionary() -> void:
	var object_value := MockObject.new()
	var root: Dictionary = {
		"container": object_value
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "container.child.payload.answer")
	assert_eq(value, 42)

func test_resolve_returns_null_for_missing_dictionary_key() -> void:
	var root: Dictionary = {
		"health": 100
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "mana")
	assert_null(value)

func test_resolve_returns_null_for_out_of_bounds_array_index() -> void:
	var root: Dictionary = {
		"items": [10, 20]
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "items.2")
	assert_null(value)

func test_resolve_returns_null_for_missing_object_property_without_method_fallback() -> void:
	var object_value := MockObject.new()

	var missing_property_value: Variant = PATH_RESOLVER.resolve(object_value, "missing_field")
	assert_null(missing_property_value)

	var method_name_value: Variant = PATH_RESOLVER.resolve(object_value, "do_not_call")
	assert_null(method_name_value)

func test_resolve_returns_root_value_for_empty_path() -> void:
	var root: Dictionary = {
		"health": 100
	}

	var value: Variant = PATH_RESOLVER.resolve(root, "")
	assert_eq(value, root)
