extends RefCounted
class_name U_SceneRegistryLoader

const RS_SceneRegistryEntry := preload("res://scripts/resources/scene_management/rs_scene_registry_entry.gd")

func load_resource_entries(scenes: Dictionary, register_scene_callable: Callable) -> void:
	if register_scene_callable == Callable() or not register_scene_callable.is_valid():
		return

	var res_result: Dictionary = _load_entries_from_dir("res://resources/scene_registry", scenes, register_scene_callable, true)
	# tests/scene_registry is optional; don't warn if it's missing.
	var test_result: Dictionary = _load_entries_from_dir("res://tests/scene_registry", scenes, register_scene_callable, false)

	# Keep totals available for potential debugging, even if unused by callers.
	var _total_loaded: int = int(res_result.get("loaded", 0)) + int(test_result.get("loaded", 0))
	var _total_skipped: int = int(res_result.get("skipped", 0)) + int(test_result.get("skipped", 0))
	_total_loaded = _total_loaded # silence unused variable warning until needed
	_total_skipped = _total_skipped

func backfill_default_gameplay_scenes(scenes: Dictionary, register_scene_callable: Callable) -> void:
	if register_scene_callable == Callable() or not register_scene_callable.is_valid():
		return

	# NOTE: These backfills are a safety net for exports where resource-based registry
	# entries might be excluded by filters. Prefer "loading" for gameplay scenes so
	# missing resources don't silently downgrade large-scene transitions to "fade".
	if not scenes.has(StringName("gameplay_base")):
		register_scene_callable.call(
			StringName("gameplay_base"),
			"res://scenes/gameplay/gameplay_base.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			8
		)

	if not scenes.has(StringName("exterior")):
		register_scene_callable.call(
			StringName("exterior"),
			"res://scenes/gameplay/gameplay_exterior.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("interior_house")):
		register_scene_callable.call(
			StringName("interior_house"),
			"res://scenes/gameplay/gameplay_interior_house.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("gamepad_settings")):
		register_scene_callable.call(
			StringName("gamepad_settings"),
			"res://scenes/ui/overlays/ui_gamepad_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("touchscreen_settings")):
		register_scene_callable.call(
			StringName("touchscreen_settings"),
			"res://scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("vfx_settings")):
		register_scene_callable.call(
			StringName("vfx_settings"),
			"res://scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("audio_settings")):
		register_scene_callable.call(
			StringName("audio_settings"),
			"res://scenes/ui/overlays/settings/ui_audio_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("edit_touch_controls")):
		register_scene_callable.call(
			StringName("edit_touch_controls"),
			"res://scenes/ui/overlays/ui_edit_touch_controls_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("input_profile_selector")):
		register_scene_callable.call(
			StringName("input_profile_selector"),
			"res://scenes/ui/overlays/ui_input_profile_selector.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("input_rebinding")):
		register_scene_callable.call(
			StringName("input_rebinding"),
			"res://scenes/ui/overlays/ui_input_rebinding_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("game_over")):
		register_scene_callable.call(
			StringName("game_over"),
			"res://scenes/ui/menus/ui_game_over.tscn",
			U_SceneRegistry.SceneType.END_GAME,
			"fade",
			8
		)

	if not scenes.has(StringName("victory")):
		register_scene_callable.call(
			StringName("victory"),
			"res://scenes/ui/menus/ui_victory.tscn",
			U_SceneRegistry.SceneType.END_GAME,
			"fade",
			5
		)

	if not scenes.has(StringName("credits")):
		register_scene_callable.call(
			StringName("credits"),
			"res://scenes/ui/menus/ui_credits.tscn",
			U_SceneRegistry.SceneType.END_GAME,
			"fade",
			0
		)

func _load_entries_from_dir(
	dir_path: String,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_missing_dir: bool = true
) -> Dictionary:
	var loaded_count: int = 0
	var skipped_count: int = 0

	var dir := _open_dir(dir_path)
	if dir == null:
		# In exports (especially mobile/web), relying on directory iteration can fail due to
		# path normalization quirks or export filters. Backfill provides a safety net, but
		# warn so missing entries don't silently downgrade transitions (e.g., "loading" → "fade").
		if warn_on_missing_dir and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
			push_warning("U_SceneRegistryLoader: Could not open dir '%s' for scene registry entries" % dir_path)
		return {"loaded": 0, "skipped": 0}

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path: String = _join_path(dir_path, file_name)
			var resource: Resource = load(resource_path)

			if not (resource is RS_SceneRegistryEntry):
				push_warning("U_SceneRegistryLoader: Resource at %s is not RS_SceneRegistryEntry (found %s), skipping" % [resource_path, resource.get_class()])
				skipped_count += 1
				file_name = dir.get_next()
				continue

			var entry := resource as RS_SceneRegistryEntry
			if not entry.is_valid():
				push_warning("U_SceneRegistryLoader: Scene entry in %s is invalid (scene_id or scene_path empty), skipping" % resource_path)
				skipped_count += 1
				file_name = dir.get_next()
				continue

			if scenes.has(entry.scene_id):
				push_warning("U_SceneRegistryLoader: Scene '%s' from %s already registered (hardcoded or duplicate), skipping" % [entry.scene_id, resource_path])
				skipped_count += 1
				file_name = dir.get_next()
				continue

			register_scene_callable.call(
				entry.scene_id,
				entry.scene_path,
				entry.scene_type,
				entry.default_transition,
				entry.preload_priority
			)
			loaded_count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	if loaded_count == 0 and skipped_count == 0 and warn_on_missing_dir and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
		push_warning("U_SceneRegistryLoader: No .tres entries found under '%s' (exports may be missing resources/scene_registry files)" % dir_path)
	return {"loaded": loaded_count, "skipped": skipped_count}

func _open_dir(dir_path: String) -> DirAccess:
	var normalized: String = dir_path.trim_suffix("/")

	var dir := DirAccess.open(normalized)
	if dir != null:
		return dir

	# Some platforms are picky about trailing slashes; try both forms.
	dir = DirAccess.open(normalized + "/")
	return dir

func _join_path(dir_path: String, file_name: String) -> String:
	if dir_path.ends_with("/"):
		return dir_path + file_name
	return dir_path + "/" + file_name
