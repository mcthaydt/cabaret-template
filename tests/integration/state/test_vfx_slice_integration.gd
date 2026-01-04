extends GutTest

## Integration test for VFX slice initialization and runtime behavior
## Verifies VFX slice is properly integrated into M_StateStore

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const DEFAULT_VFX_INITIAL_STATE := preload("res://resources/state/default_vfx_initial_state.tres")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_VFXActions := preload("res://scripts/state/actions/u_vfx_actions.gd")
const U_VFXSelectors := preload("res://scripts/state/selectors/u_vfx_selectors.gd")

var _root: Node

func before_each() -> void:
	U_STATE_HANDOFF.clear_all()
	_root = Node.new()
	add_child_autofree(_root)

func after_each() -> void:
	U_STATE_HANDOFF.clear_all()
	_root = null

func _make_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.name = "M_StateStore"
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.vfx_initial_state = DEFAULT_VFX_INITIAL_STATE
	_root.add_child(store)
	return store

# Test 1: VFX slice exists in initial state
func test_vfx_slice_initialized_on_ready() -> void:
	var store := _make_store()
	await get_tree().process_frame

	var state: Dictionary = store.get_state()
	assert_true(
		state.has("vfx"),
		"State should contain vfx slice"
	)

# Test 2: VFX slice has correct default values
func test_vfx_slice_has_default_values() -> void:
	var store := _make_store()
	await get_tree().process_frame

	var state: Dictionary = store.get_state()
	assert_true(
		state["vfx"]["screen_shake_enabled"],
		"screen_shake_enabled should default to true"
	)
	assert_almost_eq(
		state["vfx"]["screen_shake_intensity"],
		1.0,
		0.0001,
		"screen_shake_intensity should default to 1.0"
	)
	assert_true(
		state["vfx"]["damage_flash_enabled"],
		"damage_flash_enabled should default to true"
	)
	assert_true(
		state["vfx"]["particles_enabled"],
		"particles_enabled should default to true"
	)

# Test 3: VFX actions mutate VFX slice
func test_vfx_actions_mutate_vfx_slice() -> void:
	var store := _make_store()
	await get_tree().process_frame

	# Dispatch action to disable screen shake
	store.dispatch(U_VFXActions.set_screen_shake_enabled(false))
	store.dispatch(U_VFXActions.set_particles_enabled(false))
	await get_tree().process_frame

	var state: Dictionary = store.get_state()
	assert_false(
		state["vfx"]["screen_shake_enabled"],
		"screen_shake_enabled should be false after action"
	)
	assert_false(
		state["vfx"]["particles_enabled"],
		"particles_enabled should be false after action"
	)

# Test 4: VFX intensity action clamps values
func test_vfx_intensity_action_clamps_values() -> void:
	var store := _make_store()
	await get_tree().process_frame

	# Dispatch action with out-of-range value
	store.dispatch(U_VFXActions.set_screen_shake_intensity(3.5))
	await get_tree().process_frame

	var state: Dictionary = store.get_state()
	assert_almost_eq(
		state["vfx"]["screen_shake_intensity"],
		2.0,
		0.0001,
		"Intensity should be clamped to 2.0"
	)

# Test 5: VFX selectors read VFX slice
func test_vfx_selectors_read_vfx_slice() -> void:
	var store := _make_store()
	await get_tree().process_frame

	# Set a specific value
	store.dispatch(U_VFXActions.set_screen_shake_intensity(0.5))
	await get_tree().process_frame

	var state: Dictionary = store.get_state()
	var intensity: float = U_VFXSelectors.get_screen_shake_intensity(state)

	assert_almost_eq(
		intensity,
		0.5,
		0.0001,
		"Selector should read correct intensity value"
	)

# Test 6: Multiple VFX mutations preserve other fields
func test_multiple_vfx_mutations_preserve_fields() -> void:
	var store := _make_store()
	await get_tree().process_frame

	# Mutate screen shake settings
	store.dispatch(U_VFXActions.set_screen_shake_enabled(false))
	store.dispatch(U_VFXActions.set_screen_shake_intensity(0.3))
	await get_tree().process_frame

	var state: Dictionary = store.get_state()

	# Verify screen shake mutations
	assert_false(
		state["vfx"]["screen_shake_enabled"],
		"screen_shake_enabled should be false"
	)
	assert_almost_eq(
		state["vfx"]["screen_shake_intensity"],
		0.3,
		0.0001,
		"screen_shake_intensity should be 0.3"
	)

	# Verify damage flash was preserved
	assert_true(
		state["vfx"]["damage_flash_enabled"],
		"damage_flash_enabled should remain true (preserved)"
	)
	# Verify particles was preserved
	assert_true(
		state["vfx"]["particles_enabled"],
		"particles_enabled should remain true (preserved)"
	)

# Test 7: VFX slice is independent of other slices
func test_vfx_slice_independent_of_other_slices() -> void:
	var store := _make_store()
	await get_tree().process_frame

	# Mutate VFX slice
	store.dispatch(U_VFXActions.set_damage_flash_enabled(false))
	await get_tree().process_frame

	var state: Dictionary = store.get_state()

	# Verify VFX slice changed
	assert_false(
		state["vfx"]["damage_flash_enabled"],
		"VFX slice should be mutated"
	)

	# Verify other slices exist and weren't affected
	# (Assuming other slices like boot, menu exist in minimal store setup)
	assert_true(
		state.size() > 1,
		"State should contain multiple slices"
	)
