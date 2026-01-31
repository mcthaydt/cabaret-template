extends BaseTest

const U_SAVE_TEST_UTILS := preload("res://tests/unit/save/u_save_test_utils.gd")
const U_SCREENSHOT_CAPTURE := preload("res://scripts/managers/helpers/u_screenshot_capture.gd")

const TEST_DIR := U_SAVE_TEST_UTILS.TEST_DIR

func before_each() -> void:
	U_SAVE_TEST_UTILS.setup(TEST_DIR)
	await get_tree().process_frame

func after_each() -> void:
	U_SAVE_TEST_UTILS.teardown(TEST_DIR)

func test_capture_viewport_returns_image_with_expected_dimensions() -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pending("Skipped: Viewport capture not supported in headless renderer")
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	get_tree().root.add_child(viewport)
	autofree(viewport)

	await get_tree().process_frame
	await get_tree().process_frame

	var capture: Variant = _create_capture_helper()
	var image: Image = capture.call("capture_viewport", viewport)

	assert_not_null(image, "capture_viewport should return an Image for a valid viewport")
	if image != null:
		assert_eq(image.get_width(), 320, "capture_viewport should preserve viewport width")
		assert_eq(image.get_height(), 180, "capture_viewport should preserve viewport height")

func test_capture_viewport_returns_null_for_null_viewport() -> void:
	var capture: Variant = _create_capture_helper()
	var image: Image = capture.call("capture_viewport", null)

	assert_null(image, "capture_viewport should return null for a null viewport")

func test_resize_to_thumbnail_uses_default_dimensions() -> void:
	var capture: Variant = _create_capture_helper()
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	var resized: Image = capture.call("resize_to_thumbnail", image)

	assert_not_null(resized, "resize_to_thumbnail should return an Image for valid input")
	assert_eq(resized.get_width(), 320, "resize_to_thumbnail should resize to default width")
	assert_eq(resized.get_height(), 180, "resize_to_thumbnail should resize to default height")

func test_resize_to_thumbnail_uses_lanczos_interpolation() -> void:
	assert_eq(U_SCREENSHOT_CAPTURE.RESIZE_INTERPOLATION, Image.INTERPOLATE_LANCZOS, "resize_to_thumbnail should use LANCZOS interpolation")

func test_save_to_file_creates_valid_png() -> void:
	var capture: Variant = _create_capture_helper()
	var image := Image.create(32, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.5, 0.75))

	var file_path := TEST_DIR + "test_thumb.png"
	var error: Error = capture.call("save_to_file", image, file_path)

	assert_eq(error, OK, "save_to_file should return OK on success")
	assert_true(FileAccess.file_exists(file_path), "save_to_file should create a PNG file")

	var loaded := Image.new()
	var load_error: Error = loaded.load(file_path)
	assert_eq(load_error, OK, "Saved PNG should be readable by Godot")
	assert_eq(loaded.get_width(), 32, "Loaded PNG should preserve width")
	assert_eq(loaded.get_height(), 18, "Loaded PNG should preserve height")

func test_save_to_file_returns_error_on_null_image() -> void:
	var capture: Variant = _create_capture_helper()
	var file_path := TEST_DIR + "invalid_thumb.png"
	var error: Error = capture.call("save_to_file", null, file_path)

	assert_eq(error, ERR_INVALID_PARAMETER, "save_to_file should return ERR_INVALID_PARAMETER for null image")
	assert_false(FileAccess.file_exists(file_path), "save_to_file should not create a file for null image")

func _create_capture_helper() -> Variant:
	return U_SCREENSHOT_CAPTURE.new()
