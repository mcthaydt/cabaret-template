extends GutTest

# Test suite for M_DisplayManager scaffolding and lifecycle (Phase 1B)

const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const I_DISPLAY_MANAGER := preload("res://scripts/interfaces/i_display_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _manager: Node
var _store: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null
	_store = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null
	_store = null

func test_manager_extends_interface() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is I_DISPLAY_MANAGER, "M_DisplayManager should extend I_DisplayManager")

func test_manager_added_to_group() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_true(_manager.is_in_group("display_manager"), "M_DisplayManager should add itself to display_manager group")

func test_manager_registers_with_service_locator() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.try_get_service(StringName("display_manager"))
	assert_not_null(service, "Display manager should register with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the display manager instance")

func test_manager_discovers_state_store() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var resolved_store: Node = _manager.get("_state_store") as Node
	assert_eq(resolved_store, _store, "Manager should discover StateStore via U_StateUtils.try_get_store()")

func test_manager_subscribes_to_slice_updated() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var handler := Callable(_manager, "_on_slice_updated")
	assert_true(_store.slice_updated.is_connected(handler), "Manager should connect to StateStore slice_updated signal")

func test_manager_applies_settings_on_ready() -> void:
	await _setup_manager_with_store({"window_mode": "windowed", "ui_scale": 1.0})

	assert_eq(int(_manager.get("_apply_count")), 1, "Manager should apply display settings on ready")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("window_mode"), "windowed", "Initial apply should read settings from state")

func test_manager_applies_settings_on_slice_change() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	_store.set_slice(StringName("display"), {"window_mode": "fullscreen"})
	_store.slice_updated.emit(StringName("display"), {"window_mode": "fullscreen"})

	assert_eq(int(_manager.get("_apply_count")), 2, "Manager should apply settings on display slice updates")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("window_mode"), "fullscreen", "Apply should reflect updated state")

func test_manager_hash_prevents_redundant_applies() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var apply_count := int(_manager.get("_apply_count"))
	_store.slice_updated.emit(StringName("display"), {"window_mode": "windowed"})

	assert_eq(int(_manager.get("_apply_count")), apply_count, "Hash should prevent redundant apply calls")

func test_preview_sets_flag() -> void:
	await _setup_manager_with_store({"ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	assert_true(bool(_manager.get("_display_settings_preview_active")), "Preview should set active flag")

func test_preview_overrides_state() -> void:
	await _setup_manager_with_store({"window_mode": "windowed", "ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("ui_scale"), 1.5, "Preview should override ui_scale")
	assert_eq(applied.get("window_mode"), "windowed", "Preview should retain base state values")

func test_clear_preview_restores_state_and_clears_flag() -> void:
	await _setup_manager_with_store({"ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	_manager.clear_display_settings_preview()

	assert_false(bool(_manager.get("_display_settings_preview_active")), "Clear preview should reset active flag")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("ui_scale"), 1.0, "Clear preview should restore ui_scale from state")

func _setup_manager_with_store(display_state: Dictionary) -> void:
	_store = MOCK_STATE_STORE.new()
	_store.set_slice(StringName("display"), display_state)
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame
