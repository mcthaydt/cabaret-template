extends RefCounted
class_name U_StateSliceManager

## Helper for managing state slices and reducers for M_StateStore.
##
## Extracted as part of Phase 9C (T092b) to keep M_StateStore focused on
## orchestration while this helper owns slice registration, dependency
## validation, and reducer application.

const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")
const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")
const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")
const U_LOCALIZATION_REDUCER := preload("res://scripts/state/reducers/u_localization_reducer.gd")
const U_TIME_REDUCER := preload("res://scripts/state/reducers/u_time_reducer.gd")

## Initialize core slices based on the provided initial state resources.
##
## Populates the given slice_configs and state dictionaries.
static func initialize_slices(
	slice_configs: Dictionary,
	state: Dictionary,
	boot_initial_state: RS_BootInitialState,
	menu_initial_state: RS_MenuInitialState,
	navigation_initial_state: Resource,
	settings_initial_state: RS_SettingsInitialState,
	gameplay_initial_state: RS_GameplayInitialState,
	scene_initial_state: RS_SceneInitialState,
	debug_initial_state: RS_DebugInitialState,
	vfx_initial_state: RS_VFXInitialState,
	audio_initial_state: RS_AudioInitialState,
	display_initial_state: Resource,
	localization_initial_state: Resource = null,
	time_initial_state: Resource = null
) -> void:
	# Boot slice
	if boot_initial_state != null:
		var boot_config := RS_StateSliceConfig.new(StringName("boot"))
		boot_config.reducer = Callable(U_BootReducer, "reduce")
		boot_config.initial_state = boot_initial_state.to_dictionary()
		boot_config.dependencies = []
		boot_config.transient_fields = []
		register_slice(slice_configs, state, boot_config)

	# Menu slice
	if menu_initial_state != null:
		var menu_config := RS_StateSliceConfig.new(StringName("menu"))
		menu_config.reducer = Callable(U_MenuReducer, "reduce")
		menu_config.initial_state = menu_initial_state.to_dictionary()
		menu_config.dependencies = []
		menu_config.transient_fields = []
		register_slice(slice_configs, state, menu_config)

	# Navigation slice (transient)
	if navigation_initial_state == null:
		navigation_initial_state = RS_NavigationInitialState.new()
	if navigation_initial_state != null:
		var navigation_config := RS_StateSliceConfig.new(StringName("navigation"))
		navigation_config.reducer = Callable(U_NavigationReducer, "reduce")
		navigation_config.initial_state = navigation_initial_state.to_dictionary()
		navigation_config.dependencies = []
		navigation_config.transient_fields = []
		navigation_config.is_transient = true
		register_slice(slice_configs, state, navigation_config)

	# Settings slice
	if settings_initial_state == null:
		settings_initial_state = RS_SettingsInitialState.new()
	if settings_initial_state != null:
		var settings_config := RS_StateSliceConfig.new(StringName("settings"))
		settings_config.reducer = Callable(U_SettingsReducer, "reduce")
		settings_config.initial_state = settings_initial_state.to_dictionary()
		settings_config.dependencies = []
		settings_config.transient_fields = []
		register_slice(slice_configs, state, settings_config)

	# Gameplay slice
	if gameplay_initial_state != null:
		var gameplay_config := RS_StateSliceConfig.new(StringName("gameplay"))
		gameplay_config.reducer = Callable(U_GameplayReducer, "reduce")
		gameplay_config.initial_state = gameplay_initial_state.to_dictionary()
		gameplay_config.dependencies = []
		gameplay_config.transient_fields = [
			StringName("input"),
			StringName("move_input"),
			StringName("look_input"),
			StringName("jump_pressed"),
			StringName("jump_just_pressed"),
			StringName("sprint_pressed"),
		]
		register_slice(slice_configs, state, gameplay_config)

	# Scene slice
	if scene_initial_state != null:
		var scene_config := RS_StateSliceConfig.new(StringName("scene"))
		scene_config.reducer = Callable(U_SceneReducer, "reduce")
		scene_config.initial_state = scene_initial_state.to_dictionary()
		scene_config.dependencies = []
		scene_config.transient_fields = ["is_transitioning", "transition_type", "scene_stack"]
		register_slice(slice_configs, state, scene_config)

	# Debug slice
	if debug_initial_state != null:
		var debug_config := RS_StateSliceConfig.new(StringName("debug"))
		debug_config.reducer = Callable(U_DebugReducer, "reduce")
		debug_config.initial_state = debug_initial_state.to_dictionary()
		debug_config.dependencies = []
		debug_config.transient_fields = []
		register_slice(slice_configs, state, debug_config)

	# VFX slice
	if vfx_initial_state != null:
		var vfx_config := RS_StateSliceConfig.new(StringName("vfx"))
		vfx_config.reducer = Callable(U_VFX_REDUCER, "reduce")
		vfx_config.initial_state = vfx_initial_state.to_dictionary()
		vfx_config.dependencies = []
		vfx_config.transient_fields = []
		register_slice(slice_configs, state, vfx_config)

	# Audio slice
	if audio_initial_state != null:
		var audio_config := RS_StateSliceConfig.new(StringName("audio"))
		audio_config.reducer = Callable(U_AUDIO_REDUCER, "reduce")
		audio_config.initial_state = audio_initial_state.to_dictionary()
		audio_config.dependencies = []
		audio_config.transient_fields = []
		register_slice(slice_configs, state, audio_config)

	# Display slice
	if display_initial_state != null:
		var display_config := RS_StateSliceConfig.new(StringName("display"))
		display_config.reducer = Callable(U_DISPLAY_REDUCER, "reduce")
		display_config.initial_state = display_initial_state.to_dictionary()
		display_config.dependencies = []
		display_config.transient_fields = []
		register_slice(slice_configs, state, display_config)

	# Localization slice
	if localization_initial_state != null:
		var loc_config := RS_StateSliceConfig.new(StringName("localization"))
		loc_config.reducer = Callable(U_LOCALIZATION_REDUCER, "reduce")
		loc_config.initial_state = localization_initial_state.to_dictionary()
		loc_config.dependencies = []
		loc_config.transient_fields = []
		register_slice(slice_configs, state, loc_config)

	# Time slice
	if time_initial_state != null:
		var time_config := RS_StateSliceConfig.new(StringName("time"))
		time_config.reducer = Callable(U_TIME_REDUCER, "reduce")
		time_config.initial_state = time_initial_state.to_dictionary()
		time_config.dependencies = []
		time_config.transient_fields = [
			StringName("is_paused"),
			StringName("active_channels"),
			StringName("timescale"),
		]
		register_slice(slice_configs, state, time_config)

## Register a single slice config into the given dictionaries.
static func register_slice(
	slice_configs: Dictionary,
	state: Dictionary,
	config: RS_StateSliceConfig
) -> void:
	if config == null:
		push_error("U_StateSliceManager.register_slice: Config is null")
		return

	if config.slice_name == StringName():
		push_error("U_StateSliceManager.register_slice: Slice name is empty")
		return

	if _has_circular_dependency(slice_configs, config.slice_name, config.dependencies):
		push_error(
			"U_StateSliceManager.register_slice: Circular dependency detected for slice '%s'"
			% String(config.slice_name)
		)
		return

	slice_configs[config.slice_name] = config
	state[config.slice_name] = config.initial_state.duplicate(true)

## Validate that all declared slice dependencies exist and are valid.
static func validate_slice_dependencies(slice_configs: Dictionary) -> bool:
	var all_valid := true

	for slice_name in slice_configs:
		var config: RS_StateSliceConfig = slice_configs[slice_name]
		for dep in config.dependencies:
			if not slice_configs.has(dep):
				push_error(
					"U_StateSliceManager: Slice '%s' declares dependency on unregistered slice '%s'"
					% [String(slice_name), String(dep)]
				)
				all_valid = false

	return all_valid

## Apply reducers for all slices to produce the next state.
##
## Mutates the provided state dictionary and returns true if any slice changed.
static func apply_reducers(
	state: Dictionary,
	slice_configs: Dictionary,
	action: Dictionary,
	signal_batcher: U_SignalBatcher,
	pending_immediate_updates: Dictionary
) -> bool:
	var any_changed: bool = false

	for slice_name in slice_configs:
		var config: RS_StateSliceConfig = slice_configs[slice_name]
		if config == null:
			continue

		var current_slice: Dictionary = state.get(slice_name, {})
		var next_slice: Dictionary = current_slice.duplicate(true)

		if config.reducer != Callable():
			var args: Array = [current_slice, action]
			var reduced: Variant = config.reducer.callv(args)
			if reduced is Dictionary:
				next_slice = reduced as Dictionary

		if not _dictionaries_equal(current_slice, next_slice):
			state[slice_name] = next_slice.duplicate(true)
			any_changed = true

			if signal_batcher != null:
				signal_batcher.mark_slice_dirty(slice_name, next_slice)
			else:
				pending_immediate_updates[slice_name] = next_slice.duplicate(true)

	return any_changed

static func _has_circular_dependency(
	slice_configs: Dictionary,
	slice_name: StringName,
	dependencies: Array[StringName],
	visited: Dictionary = {},
	rec_stack: Dictionary = {}
) -> bool:
	visited[slice_name] = true
	rec_stack[slice_name] = true

	for dep in dependencies:
		if not visited.get(dep, false):
			var dep_config: RS_StateSliceConfig = slice_configs.get(dep)
			if dep_config != null:
				if _has_circular_dependency(slice_configs, dep, dep_config.dependencies, visited, rec_stack):
					return true
		elif rec_stack.get(dep, false):
			return true

	rec_stack[slice_name] = false
	return false

static func _dictionaries_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
		if a[key] != b[key]:
			return false
	return true
