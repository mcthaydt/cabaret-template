extends Node
class_name I_ScreenshotCacheManager

## Interface for M_ScreenshotCacheManager
##
## Implementations:
## - M_ScreenshotCacheManager (production)

func cache_current_frame() -> void:
	push_error("I_ScreenshotCacheManager.cache_current_frame not implemented")

func get_cached_screenshot() -> Image:
	push_error("I_ScreenshotCacheManager.get_cached_screenshot not implemented")
	return null

func clear_cache() -> void:
	push_error("I_ScreenshotCacheManager.clear_cache not implemented")

func has_cached_screenshot() -> bool:
	push_error("I_ScreenshotCacheManager.has_cached_screenshot not implemented")
	return false
