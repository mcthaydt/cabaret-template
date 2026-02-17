extends GutTest

const U_LOCALIZATION_ROOT_REGISTRY := preload("res://scripts/managers/helpers/localization/u_localization_root_registry.gd")

class MockLocalizedRoot extends Control:
	var locales_seen: Array[StringName] = []

	func _on_locale_changed(locale: StringName) -> void:
		locales_seen.append(locale)

func test_register_root_prevents_duplicates() -> void:
	var registry := U_LOCALIZATION_ROOT_REGISTRY.new()
	var root := Control.new()
	add_child_autofree(root)

	assert_true(registry.register_root(root), "First register should succeed")
	assert_false(registry.register_root(root), "Duplicate register should be ignored")
	var roots: Array[Node] = registry.get_live_roots()
	assert_eq(roots.size(), 1, "Registry should only keep one copy of a root")

func test_unregister_root_removes_registered_root() -> void:
	var registry := U_LOCALIZATION_ROOT_REGISTRY.new()
	var root := Control.new()
	add_child_autofree(root)
	registry.register_root(root)

	assert_true(registry.unregister_root(root), "Unregister should return true when root existed")
	var roots: Array[Node] = registry.get_live_roots()
	assert_eq(roots.size(), 0, "Registry should be empty after unregister")

func test_get_live_roots_prunes_dead_nodes() -> void:
	var registry := U_LOCALIZATION_ROOT_REGISTRY.new()
	var root := Control.new()
	add_child_autofree(root)
	registry.register_root(root)
	root.queue_free()
	await get_tree().process_frame

	var roots: Array[Node] = registry.get_live_roots()
	assert_eq(roots.size(), 0, "Dead nodes should be pruned from registry")

func test_notify_locale_changed_calls_localized_roots_only() -> void:
	var registry := U_LOCALIZATION_ROOT_REGISTRY.new()
	var localized_root := MockLocalizedRoot.new()
	add_child_autofree(localized_root)
	var plain_root := Control.new()
	add_child_autofree(plain_root)
	registry.register_root(localized_root)
	registry.register_root(plain_root)

	registry.notify_locale_changed(&"es")

	assert_eq(localized_root.locales_seen, [&"es"], "Localized root should receive locale notification")
