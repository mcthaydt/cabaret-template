extends BaseTest

const M_SCREENSHOT_CACHE := preload("res://scripts/managers/m_screenshot_cache.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")

class TestScreenshotCache extends M_SCREENSHOT_CACHE:
	var override_image: Image = null
	var capture_calls: int = 0

	func _capture_image_from_viewport(_viewport: Viewport) -> Image:
		capture_calls += 1
		return override_image

var _mock_store: MockStateStore
var _cache_manager: TestScreenshotCache

func before_each() -> void:
	U_ServiceLocator.clear()

	_mock_store = MOCK_STATE_STORE.new()
	_mock_store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	add_child(_mock_store)
	autofree(_mock_store)

	U_ServiceLocator.register(StringName("state_store"), _mock_store)

	await get_tree().process_frame

func test_manager_registers_with_service_locator() -> void:
	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	var service: Node = U_ServiceLocator.get_service(StringName("screenshot_cache"))
	assert_not_null(service, "Screenshot cache should register with ServiceLocator")
	assert_eq(service, _cache_manager, "ServiceLocator should return the cache manager instance")

func test_cache_current_frame_stores_image() -> void:
	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	_cache_manager.cache_current_frame()

	assert_true(_cache_manager.has_cached_screenshot(), "cache_current_frame should store a screenshot")
	var image: Image = _cache_manager.get_cached_screenshot()
	assert_not_null(image, "get_cached_screenshot should return cached image")
	assert_eq(_cache_manager.capture_calls, 1, "cache_current_frame should capture once")

func test_get_cached_screenshot_returns_null_when_empty() -> void:
	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	var image: Image = _cache_manager.get_cached_screenshot()
	assert_null(image, "get_cached_screenshot should return null when cache is empty")
	assert_false(_cache_manager.has_cached_screenshot(), "has_cached_screenshot should be false when empty")

func test_clear_cache_resets_state() -> void:
	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	_cache_manager.cache_current_frame()
	assert_true(_cache_manager.has_cached_screenshot(), "cache should be populated before clear")

	_cache_manager.clear_cache()

	assert_false(_cache_manager.has_cached_screenshot(), "clear_cache should reset cached state")
	assert_null(_cache_manager.get_cached_screenshot(), "clear_cache should remove cached image")

func test_cache_current_frame_skips_when_not_in_gameplay_shell() -> void:
	_mock_store.set_slice(StringName("navigation"), {"shell": "main_menu"})

	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	_cache_manager.cache_current_frame()

	assert_eq(_cache_manager.capture_calls, 0, "cache_current_frame should skip capture when not in gameplay shell")
	assert_false(_cache_manager.has_cached_screenshot(), "cache should remain empty when not in gameplay shell")

func test_action_open_pause_triggers_cache_in_gameplay() -> void:
	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	_mock_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())

	assert_eq(_cache_manager.capture_calls, 1, "ACTION_OPEN_PAUSE should trigger a cache capture")
	assert_true(_cache_manager.has_cached_screenshot(), "ACTION_OPEN_PAUSE should populate cache")

func test_action_open_pause_skips_when_not_in_gameplay_shell() -> void:
	_mock_store.set_slice(StringName("navigation"), {"shell": "main_menu"})

	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	_mock_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())

	assert_eq(_cache_manager.capture_calls, 0, "ACTION_OPEN_PAUSE should skip capture outside gameplay")
	assert_false(_cache_manager.has_cached_screenshot(), "Cache should remain empty when not in gameplay shell")

func test_cache_survives_pause_unpause_cycles_until_cleared() -> void:
	_cache_manager = _create_cache_manager()
	add_child(_cache_manager)
	autofree(_cache_manager)

	await get_tree().process_frame

	_mock_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	assert_true(_cache_manager.has_cached_screenshot(), "Cache should be populated after pause")

	_mock_store.dispatch(U_NAVIGATION_ACTIONS.close_pause())

	assert_true(_cache_manager.has_cached_screenshot(), "Cache should persist after unpausing")

func _create_cache_manager() -> TestScreenshotCache:
	var manager := TestScreenshotCache.new()
	manager.override_image = Image.create(16, 9, false, Image.FORMAT_RGBA8)
	return manager
