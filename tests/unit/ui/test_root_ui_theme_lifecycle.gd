extends GutTest

const ROOT_SCRIPT := preload("res://scripts/core/root.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_UI_THEME_BUILDER.active_config = null

func test_non_persistent_root_exit_does_not_clear_active_theme_config() -> void:
	var root := _create_scripted_root()
	add_child_autofree(root)
	await wait_process_frames(2)

	var sentinel_config := RS_UI_THEME_CONFIG.new()
	sentinel_config.bg_base = Color(0.11, 0.21, 0.31, 1.0)
	U_UI_THEME_BUILDER.active_config = sentinel_config

	root.queue_free()
	await wait_process_frames(2)

	assert_eq(
		U_UI_THEME_BUILDER.active_config,
		sentinel_config,
		"Gameplay-scene roots should not clear global UI theme config on _exit_tree"
	)

func test_persistent_root_exit_clears_active_theme_config() -> void:
	var root := _create_scripted_root()
	add_child_autofree(root)
	await wait_process_frames(2)

	var managers := Node.new()
	managers.name = "Managers"
	root.add_child(managers)
	var state_store := Node.new()
	state_store.name = "M_StateStore"
	managers.add_child(state_store)

	var sentinel_config := RS_UI_THEME_CONFIG.new()
	sentinel_config.bg_base = Color(0.31, 0.21, 0.11, 1.0)
	U_UI_THEME_BUILDER.active_config = sentinel_config

	root.queue_free()
	await wait_process_frames(2)

	assert_null(
		U_UI_THEME_BUILDER.active_config,
		"Persistent app root should clear global UI theme config on _exit_tree"
	)

func _create_scripted_root() -> Node:
	var root := Node.new()
	root.set_script(ROOT_SCRIPT)
	return root
