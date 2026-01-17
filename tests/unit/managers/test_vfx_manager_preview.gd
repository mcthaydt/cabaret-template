extends GutTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

func test_set_preview_overrides_redux_state() -> void:
	var manager := await _create_manager_with_vfx_state({
		"screen_shake_enabled": true,
		"screen_shake_intensity": 1.0,
		"damage_flash_enabled": true,
	})
	manager.set_vfx_settings_preview({
		"screen_shake_enabled": false,
		"screen_shake_intensity": 0.5,
		"damage_flash_enabled": false,
	})

	assert_false(manager._get_screen_shake_enabled(), "Preview should override shake enabled")
	assert_almost_eq(manager._get_screen_shake_intensity(), 0.5, 0.001,
		"Preview should override shake intensity")
	assert_false(manager._get_damage_flash_enabled(), "Preview should override flash enabled")

func test_clear_preview_reverts_to_redux_state() -> void:
	var manager := await _create_manager_with_vfx_state({
		"screen_shake_enabled": false,
		"screen_shake_intensity": 1.4,
		"damage_flash_enabled": false,
	})
	manager.set_vfx_settings_preview({
		"screen_shake_enabled": true,
		"screen_shake_intensity": 0.6,
		"damage_flash_enabled": true,
	})
	manager.clear_vfx_settings_preview()

	assert_false(manager._get_screen_shake_enabled(), "Clear preview should restore shake enabled from state")
	assert_almost_eq(manager._get_screen_shake_intensity(), 1.4, 0.001,
		"Clear preview should restore shake intensity from state")
	assert_false(manager._get_damage_flash_enabled(), "Clear preview should restore flash enabled from state")

func test_preview_affects_shake_enabled() -> void:
	var manager := await _create_manager_with_vfx_state({
		"screen_shake_enabled": true,
		"screen_shake_intensity": 1.0,
		"damage_flash_enabled": true,
	})
	manager.set_vfx_settings_preview({
		"screen_shake_enabled": false,
	})

	assert_false(manager._get_screen_shake_enabled(), "Preview should override shake enabled")

func test_preview_affects_shake_intensity() -> void:
	var manager := await _create_manager_with_vfx_state({
		"screen_shake_enabled": true,
		"screen_shake_intensity": 1.0,
		"damage_flash_enabled": true,
	})
	manager.set_vfx_settings_preview({
		"screen_shake_intensity": 0.25,
	})

	assert_almost_eq(manager._get_screen_shake_intensity(), 0.25, 0.001,
		"Preview should override shake intensity")

func test_preview_affects_flash_enabled() -> void:
	var manager := await _create_manager_with_vfx_state({
		"screen_shake_enabled": true,
		"screen_shake_intensity": 1.0,
		"damage_flash_enabled": true,
	})
	manager.set_vfx_settings_preview({
		"damage_flash_enabled": false,
	})

	assert_false(manager._get_damage_flash_enabled(), "Preview should override flash enabled")

func _create_manager_with_vfx_state(vfx_state: Dictionary) -> M_VFXManager:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("vfx"), vfx_state)
	add_child_autofree(store)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = store
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager
