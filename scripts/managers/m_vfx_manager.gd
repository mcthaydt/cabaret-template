@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_VFXManager

## VFX Manager - Coordinates visual feedback effects (screen shake, damage flash)

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/ecs/u_ecs_event_names.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const U_GAMEPLAY_SELECTORS := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
const U_SCENE_SELECTORS := preload("res://scripts/state/selectors/u_scene_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const M_ScreenShake := preload("res://scripts/managers/helpers/m_screen_shake.gd")
const M_DamageFlash := preload("res://scripts/managers/helpers/m_damage_flash.gd")
const SCREEN_SHAKE_TUNING := preload("res://resources/vfx/rs_screen_shake_tuning.tres")
const SCREEN_SHAKE_CONFIG := preload("res://resources/vfx/rs_screen_shake_config.tres")
##
## Responsibilities:
## - Manages trauma system for screen shake (accumulates from damage/impacts, decays over time)
## - Coordinates with M_CameraManager to apply shake offsets
## - Triggers damage flash overlay on request events
## - Subscribes to ECS request events (screen_shake_request, damage_flash_request)
## - Respects VFX settings from Redux state (enable toggles, intensity multipliers)
##
## Architecture:
## - Extends Node with PROCESS_MODE_ALWAYS (runs even when paused)
## - Registered with ServiceLocator via scene bootstrap (main.gd)
## - Discovers M_StateStore dependency for settings access
## - Uses M_ScreenShake helper for shake calculations (quadratic falloff, noise-based)
## - Uses M_DamageFlash helper for flash tween animations

## Injected dependencies (for testing)
@export var state_store: I_StateStore = null
@export var camera_manager: M_CameraManager = null

## StateStore dependency for accessing VFX settings
var _state_store: I_StateStore = null

## Camera Manager dependency for applying screen shake
var _camera_manager: M_CameraManager = null

## Screen shake helper for calculating shake offset/rotation
var _screen_shake: M_ScreenShake = null

## Damage flash helper for triggering red flash overlay
var _damage_flash: M_DamageFlash = null

## Current trauma level (0.0 = no shake, 1.0 = maximum shake)
## Trauma accumulates from damage/impacts and decays over time
var _trauma: float = 0.0

## Trauma decay rate (units per second)
## Trauma decays from 1.0 to 0.0 over 0.5 seconds at this rate
var _trauma_decay_rate: float = 2.0

## Request queues for deterministic processing
var _shake_requests: Array = []
var _flash_requests: Array = []

## Unsubscribe callables for ECS event subscriptions
var _event_unsubscribes: Array[Callable] = []

func _ready() -> void:
	# Run even when game is paused (VFX should be visible in pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Add to group for discoverability
	add_to_group("vfx_manager")

	# Discover StateStore dependency (injection first)
	if state_store != null:
		_state_store = state_store
	else:
		_state_store = U_STATE_UTILS.try_get_store(self)
	if _state_store == null:
		print_verbose("M_VFXManager: StateStore not found. VFX settings will not be applied.")

	# Discover Camera Manager dependency (VFX Phase 3: T3.2, injection first)
	if camera_manager != null:
		_camera_manager = camera_manager
	else:
		_camera_manager = U_SERVICE_LOCATOR.try_get_service(U_ECS_EVENT_NAMES.SERVICE_CAMERA_MANAGER)
	if _camera_manager == null:
		print_verbose("M_VFXManager: Camera Manager not found. Screen shake will not be applied.")

	# Initialize screen shake helper (VFX Phase 3: T3.2)
	var shake_config = SCREEN_SHAKE_CONFIG
	_screen_shake = M_ScreenShake.new(shake_config)
	var shake_tuning = SCREEN_SHAKE_TUNING
	_trauma_decay_rate = float(shake_tuning.trauma_decay_rate)

	# Load and initialize damage flash overlay (VFX Phase 4: T4.4)
	var flash_scene: PackedScene = load("res://scenes/ui/ui_damage_flash_overlay.tscn")
	if flash_scene != null:
		var flash_instance: CanvasLayer = flash_scene.instantiate()
		add_child(flash_instance)
		var flash_rect: ColorRect = flash_instance.get_node("FlashRect") as ColorRect
		if flash_rect != null:
			_damage_flash = M_DamageFlash.new(flash_rect, get_tree())
		else:
			push_error("M_VFXManager: Failed to find FlashRect in damage flash overlay scene")
	else:
		push_error("M_VFXManager: Failed to load damage flash overlay scene")

	# Subscribe to ECS request events
	_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST,
		_on_screen_shake_request
	))
	_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_DAMAGE_FLASH_REQUEST,
		_on_damage_flash_request
	))

func _exit_tree() -> void:
	# Unsubscribe from all ECS events to prevent memory leaks
	for unsubscribe in _event_unsubscribes:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()

## Add trauma to the current trauma level
##
## Trauma accumulates from damage, impacts, and other jarring events.
## The trauma value is clamped to a maximum of 1.0.
##
## Parameters:
##   amount: The amount of trauma to add (0.0-1.0 range recommended)
##
## Example:
##   vfx_manager.add_trauma(0.5)  # Add moderate trauma from damage
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

## Get the current trauma level
##
## Returns:
##   Current trauma value (0.0 = no shake, 1.0 = maximum shake)
func get_trauma() -> float:
	return _trauma

## Check if entity_id matches the player entity
func _is_player_entity(entity_id: StringName) -> bool:
	if _state_store == null:
		return false  # Fallback: BLOCK VFX if no store (safer)
	var state: Dictionary = _state_store.get_state()
	var gameplay: Dictionary = state.get("gameplay", {})
	var player_entity_id: StringName = StringName(str(gameplay.get("player_entity_id", "")))
	if player_entity_id.is_empty():
		return false  # Fallback: BLOCK VFX if no player registered (safer)
	return entity_id == player_entity_id

## Check if VFX should be blocked due to transitions or non-gameplay state
func _is_transition_blocked() -> bool:
	if _state_store == null:
		return false
	var state: Dictionary = _state_store.get_state()

	# Block during scene transitions
	var scene_slice: Dictionary = state.get("scene", {})
	if U_SCENE_SELECTORS.is_transitioning(scene_slice):
		return true

	# Block if scene stack is not empty (loading/overlay scenes)
	var scene_stack: Array = U_SCENE_SELECTORS.get_scene_stack(scene_slice)
	if not scene_stack.is_empty():
		return true

	# Block if not in gameplay shell
	var nav_slice: Dictionary = state.get("navigation", {})
	var shell: StringName = U_NAVIGATION_SELECTORS.get_shell(nav_slice)
	if shell != StringName("gameplay"):
		return true

	return false

## Physics process - handles trauma decay and screen shake application (VFX Phase 3: T3.2)
func _physics_process(delta: float) -> void:
	# Process queued requests (deterministic ordering)
	for request in _shake_requests:
		_process_shake_request(request)
	_shake_requests.clear()

	for request in _flash_requests:
		_process_flash_request(request)
	_flash_requests.clear()

	# Decay trauma over time (2.0/sec rate)
	_trauma = maxf(_trauma - _trauma_decay_rate * delta, 0.0)

	# Apply screen shake if camera manager available and shake enabled in settings
	if _camera_manager != null and _state_store != null and _screen_shake != null:
		var state: Dictionary = _state_store.get_state()
		if U_VFX_SELECTORS.is_screen_shake_enabled(state):
			var intensity: float = U_VFX_SELECTORS.get_screen_shake_intensity(state)
			var shake_data: Dictionary = _screen_shake.calculate_shake(_trauma, intensity, delta)
			_camera_manager.apply_shake_offset(shake_data["offset"], shake_data["rotation"])
		else:
			# Reset shake when disabled (prevents lingering offset)
			_camera_manager.apply_shake_offset(Vector2.ZERO, 0.0)

## Event handler for screen shake request events
func _on_screen_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	# Gating: player-only and transition check
	if not _is_player_entity(entity_id):
		return
	if _is_transition_blocked():
		return

	_shake_requests.append(event_data)

## Event handler for damage flash request events
func _on_damage_flash_request(event_data: Dictionary) -> void:
	if _state_store == null or _damage_flash == null:
		return

	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	# Gating: player-only and transition check
	if not _is_player_entity(entity_id):
		return
	if _is_transition_blocked():
		return

	_flash_requests.append(event_data)

func _process_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var trauma_amount: float = float(payload.get("trauma_amount", 0.0))
	add_trauma(trauma_amount)

func _process_flash_request(event_data: Dictionary) -> void:
	if _state_store == null or _damage_flash == null:
		return
	var state: Dictionary = _state_store.get_state()
	if not U_VFX_SELECTORS.is_damage_flash_enabled(state):
		return
	var payload: Dictionary = event_data.get("payload", {})
	var intensity: float = float(payload.get("intensity", 1.0))
	_damage_flash.trigger_flash(intensity)
