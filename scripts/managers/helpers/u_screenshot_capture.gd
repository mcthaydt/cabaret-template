class_name U_ScreenshotCapture
extends RefCounted

const THUMBNAIL_WIDTH: int = 320
const THUMBNAIL_HEIGHT: int = 180
const RESIZE_INTERPOLATION := Image.INTERPOLATE_LANCZOS

func capture_viewport(viewport: Viewport) -> Image:
	if viewport == null:
		return null
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return null

	var texture: Texture2D = viewport.get_texture()
	if texture == null:
		return null

	var image: Image = texture.get_image()
	if image == null:
		return null

	return image

func resize_to_thumbnail(image: Image, width: int = THUMBNAIL_WIDTH, height: int = THUMBNAIL_HEIGHT) -> Image:
	if image == null:
		return null

	image.resize(width, height, RESIZE_INTERPOLATION)
	return image

func save_to_file(image: Image, path: String) -> Error:
	if image == null or path.is_empty():
		return ERR_INVALID_PARAMETER

	return image.save_png(path)
