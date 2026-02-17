extends GutTest

## Unit tests for U_LocalizationRoot helper node.

const U_LOCALIZATION_ROOT := preload("res://scripts/ui/helpers/u_localization_root.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

class LocalizationManagerStub extends Node:
	var roots: Array[Node] = []

	func register_ui_root(root: Node) -> void:
		if root == null:
			return
		if root not in roots:
			roots.append(root)

	func unregister_ui_root(root: Node) -> void:
		if root == null:
			return
		roots.erase(root)

var _manager: LocalizationManagerStub

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null

func test_registers_parent_with_manager() -> void:
	_manager = LocalizationManagerStub.new()
	add_child_autofree(_manager)
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _manager)

	var parent := Control.new()
	add_child_autofree(parent)

	var root_helper := U_LOCALIZATION_ROOT.new()
	parent.add_child(root_helper)

	# Wait for retry-polling to register (skip first frame + register frame)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		parent in _manager.roots,
		"U_LocalizationRoot should register its parent with the localization manager"
	)

func test_unregisters_parent_on_exit_tree() -> void:
	_manager = LocalizationManagerStub.new()
	add_child_autofree(_manager)
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), _manager)

	var parent := Control.new()
	add_child_autofree(parent)

	var root_helper := U_LOCALIZATION_ROOT.new()
	parent.add_child(root_helper)

	# Wait for registration
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify registered first
	assert_true(parent in _manager.roots, "Should be registered before removal")

	# Remove from tree
	parent.remove_child(root_helper)
	root_helper.queue_free()
	await get_tree().process_frame

	assert_false(parent in _manager.roots, "U_LocalizationRoot should unregister parent on _exit_tree")

func test_no_crash_without_manager() -> void:
	# No manager registered — should not crash
	var parent := Control.new()
	add_child_autofree(parent)

	var root_helper := U_LOCALIZATION_ROOT.new()
	parent.add_child(root_helper)

	# Wait past max register frames
	for i: int in 35:
		await get_tree().process_frame

	pass_test("U_LocalizationRoot should not crash when localization_manager is not available")
