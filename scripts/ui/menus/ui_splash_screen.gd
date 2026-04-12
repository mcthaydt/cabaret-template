@icon("res://assets/editor_icons/icn_utility.svg")
extends Control
class_name UI_SplashScreen

## Boot splash screen with background scene preloading.
##
## Shows Crispy Cabaret logo then Godot Engine logo (2s min each).
## During display, preloads the default gameplay scene in the background
## so it's cached by the time the player reaches the main menu.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_DEBUG_SELECTORS := preload("res://scripts/state/selectors/u_debug_selectors.gd")

enum Phase { CRISPY_CABARET, GODOT_ENGINE, DONE }

const MIN_DISPLAY_TIME := 2.0
const DEFAULT_GAMEPLAY_SCENE_ID := StringName("ai_showcase")

@onready var _crispy_panel: Control = %CrispyCabaretPanel
@onready var _godot_panel: Control = %GodotEnginePanel
@onready var _skip_label: Label = %SkipLabel

var _current_phase: Phase = Phase.CRISPY_CABARET
var _phase_timer: float = 0.0
var _can_skip: bool = false
var _preload_started: bool = false
var _gameplay_scene_path: String = ""

func _ready() -> void:
	_start_gameplay_preload()
	var store: Variant = U_DependencyResolution.resolve_state_store(null, null, self)
	if store != null:
		var state: Dictionary = store.get_state()
		if U_DEBUG_SELECTORS.should_skip_splash(state):
			_current_phase = Phase.DONE
			_finalize_preload()
			_transition_to_next_scene()
			return
	_show_phase(Phase.CRISPY_CABARET)

func _process(delta: float) -> void:
	if _current_phase == Phase.DONE:
		return
	_phase_timer += delta
	var was_skippable := _can_skip
	_can_skip = _phase_timer >= MIN_DISPLAY_TIME
	if _can_skip and not was_skippable:
		_update_skip_hint(true)
	if _phase_timer >= MIN_DISPLAY_TIME * 2.0:
		_advance_phase()

func _input(event: InputEvent) -> void:
	if _current_phase == Phase.DONE:
		return
	if not _can_skip:
		return
	if event.is_pressed() and not event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		_advance_phase()

func get_current_phase() -> Phase:
	return _current_phase

func get_phase_timer() -> float:
	return _phase_timer

func is_skip_allowed() -> bool:
	return _can_skip

func _advance_phase() -> void:
	match _current_phase:
		Phase.CRISPY_CABARET:
			_current_phase = Phase.GODOT_ENGINE
			_phase_timer = 0.0
			_can_skip = false
			_show_phase(Phase.GODOT_ENGINE)
		Phase.GODOT_ENGINE:
			_current_phase = Phase.DONE
			_finalize_preload()
			_transition_to_next_scene()

func _show_phase(phase: Phase) -> void:
	if _crispy_panel != null:
		_crispy_panel.visible = (phase == Phase.CRISPY_CABARET)
	if _godot_panel != null:
		_godot_panel.visible = (phase == Phase.GODOT_ENGINE)
	_update_skip_hint(false)

func _update_skip_hint(visible_flag: bool) -> void:
	if _skip_label != null:
		_skip_label.visible = visible_flag

func _start_gameplay_preload() -> void:
	if _preload_started:
		return
	_gameplay_scene_path = _resolve_gameplay_scene_path()
	if _gameplay_scene_path.is_empty():
		return
	var err: int = ResourceLoader.load_threaded_request(_gameplay_scene_path, "PackedScene")
	if err == OK:
		_preload_started = true

func _finalize_preload() -> void:
	if not _preload_started or _gameplay_scene_path.is_empty():
		return
	var status: int = ResourceLoader.load_threaded_get_status(_gameplay_scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed: PackedScene = ResourceLoader.load_threaded_get(_gameplay_scene_path) as PackedScene
		if packed != null:
			var cache: Variant = _resolve_scene_cache()
			if cache != null:
				cache.add_to_cache(_gameplay_scene_path, packed)

func _resolve_gameplay_scene_path() -> String:
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(DEFAULT_GAMEPLAY_SCENE_ID)
	if scene_data.is_empty():
		return ""
	return str(scene_data.get("path", ""))

func _resolve_scene_cache() -> Variant:
	var scene_manager: Variant = U_SERVICE_LOCATOR.try_get_service(StringName("scene_manager"))
	if scene_manager == null:
		return null
	if scene_manager.has_method("get_scene_cache"):
		return scene_manager.call("get_scene_cache")
	return null

func _transition_to_next_scene() -> void:
	var scene_manager: Variant = U_SERVICE_LOCATOR.try_get_service(StringName("scene_manager"))
	if scene_manager == null:
		return
	var store: Variant = U_DependencyResolution.resolve_state_store(null, null, self)
	var next_scene := StringName("main_menu")
	if store != null:
		var state: Dictionary = store.get_state()
		if not U_LOCALIZATION_SELECTORS.has_selected_language(state):
			next_scene = StringName("language_selector")
	# Update navigation state so the reconciler doesn't conflict
	if store != null:
		var nav_actions_script: GDScript = preload("res://scripts/state/actions/u_navigation_actions.gd")
		var shell := StringName("main_menu") if next_scene == StringName("main_menu") else StringName("boot")
		store.dispatch(nav_actions_script.set_shell(shell, next_scene))
	if scene_manager.has_method("transition_to_scene"):
		scene_manager.call("transition_to_scene", next_scene, "fade", 2)
