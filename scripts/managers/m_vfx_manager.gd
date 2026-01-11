@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_VFXManager

## VFX Manager - Coordinates visual feedback effects (screen shake, damage flash)

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const U_GameplaySelectors := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
const M_ScreenShake := preload("res://scripts/managers/helpers/m_screen_shake.gd")
const M_DamageFlash := preload("res://scripts/managers/helpers/m_damage_flash.gd")

## VFX request event names
const EVENT_SCREEN_SHAKE_REQUEST := StringName("screen_shake_request")
const EVENT_DAMAGE_FLASH_REQUEST := StringName("damage_flash_request")
##
## Responsibilities:
## - Executes visual feedback effects based on VFX requests
## - Manages trauma system for screen shake (accumulates from requests, decays over time)
## - Coordinates with M_CameraManager to apply shake offsets
## - Triggers damage flash overlay on flash requests
## - Subscribes to VFX request events (screen_shake_request, damage_flash_request)
## - Respects VFX settings from Redux state (enable toggles, intensity multipliers)
##
## Architecture:
## - Extends Node with PROCESS_MODE_ALWAYS (runs even when paused)
## - Registers with ServiceLocator as "vfx_manager"
## - Discovers M_StateStore dependency for settings access
## - Uses M_ScreenShake helper for shake calculations (quadratic falloff, noise-based)
## - Uses M_DamageFlash helper for flash tween animations

## Trauma decay rate (units per second)
## Trauma decays from 1.0 to 0.0 over 0.5 seconds at this rate
const TRAUMA_DECAY_RATE := 2.0

## Injected StateStore dependency (for testing)
## If set, manager uses this instead of auto-discovery
@export var state_store: I_StateStore = null

## Injected Camera Manager dependency (for testing)
## If set, manager uses this instead of auto-discovery
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

## Player entity ID for gating effects to player only
var _player_entity_id: StringName = StringName("")

## Unsubscribe callables for VFX request event subscriptions
var _unsubscribe_shake: Callable
var _unsubscribe_flash: Callable

func _ready() -> void:
	# Run even when game is paused (VFX should be visible in pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Add to group for discoverability
	add_to_group("vfx_manager")

	# Note: ServiceLocator registration is now handled by main.gd (Phase 2)

	# Use injected StateStore if available, otherwise discover
	if state_store != null:
		_state_store = state_store
	else:
		_state_store = U_STATE_UTILS.try_get_store(self)
	if _state_store == null:
		print_verbose("M_VFXManager: StateStore not found. VFX settings will not be applied.")

	# Use injected Camera Manager if available, otherwise discover
	if camera_manager != null:
		_camera_manager = camera_manager
	else:
		_camera_manager = U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager"))
	if _camera_manager == null:
		print_verbose("M_VFXManager: Camera Manager not found. Screen shake will not be applied.")

	# Initialize screen shake helper (VFX Phase 3: T3.2)
	_screen_shake = M_ScreenShake.new()

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

	# Subscribe to VFX request events
	_unsubscribe_shake = U_ECS_EVENT_BUS.subscribe(EVENT_SCREEN_SHAKE_REQUEST, _on_screen_shake_request)
	_unsubscribe_flash = U_ECS_EVENT_BUS.subscribe(EVENT_DAMAGE_FLASH_REQUEST, _on_damage_flash_request)

func _exit_tree() -> void:
	# Unsubscribe from all VFX request events to prevent memory leaks
	if _unsubscribe_shake.is_valid():
		_unsubscribe_shake.call()
	if _unsubscribe_flash.is_valid():
		_unsubscribe_flash.call()

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

## Check if the given entity is the player entity
##
## Returns true if entity_id matches the current player entity ID
func _is_player_entity(entity_id: StringName) -> bool:
	_update_player_entity_id()

	if _player_entity_id.is_empty():
		return false

	return entity_id == _player_entity_id

## Check if VFX should be blocked due to transitions or UI overlays
##
## Returns true if effects should be suppressed (during transitions, menus, non-gameplay shells)
func _is_transition_blocked() -> bool:
	if _state_store == null:
		return false

	var state: Dictionary = _state_store.get_state()

	# Check scene transition state
	var scene_slice: Dictionary = state.get("scene", {})
	if scene_slice.get("is_transitioning", false):
		return true

	# Check if any UI overlay is active (scene_stack)
	var stack: Array = scene_slice.get("scene_stack", [])
	if stack.size() > 0:
		return true

	# Check navigation shell (block in non-gameplay shells)
	var nav_slice: Dictionary = state.get("navigation", {})
	var shell: StringName = nav_slice.get("shell", StringName(""))
	if shell != StringName("gameplay"):
		return true

	return false

## Update the cached player entity ID from state
func _update_player_entity_id() -> void:
	if _state_store == null:
		# Default to "E_Player" when no state store available (for testing)
		if _player_entity_id.is_empty():
			_player_entity_id = StringName("E_Player")
		return

	var state: Dictionary = _state_store.get_state()
	var gameplay_slice: Dictionary = state.get("gameplay", {})
	_player_entity_id = StringName(gameplay_slice.get("player_entity_id", "E_Player"))

## Physics process - handles trauma decay and screen shake application (VFX Phase 3: T3.2)
func _physics_process(delta: float) -> void:
	# Decay trauma over time (2.0/sec rate)
	_trauma = maxf(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)

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
##
## Adds trauma based on the request payload (with player-only and transition gating)
func _on_screen_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id := StringName(payload.get("entity_id", ""))

	# Player-only gating
	if not _is_player_entity(entity_id):
		return

	# Transition gating
	if _is_transition_blocked():
		return

	var trauma_amount: float = float(payload.get("trauma_amount", 0.0))

	if trauma_amount <= 0.0:
		return

	add_trauma(trauma_amount)

## Event handler for damage flash request events
##
## Triggers damage flash with specified intensity if enabled in settings (with player-only and transition gating)
func _on_damage_flash_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id := StringName(payload.get("entity_id", ""))

	# Player-only gating
	if not _is_player_entity(entity_id):
		return

	# Transition gating
	if _is_transition_blocked():
		return

	var intensity: float = float(payload.get("intensity", 1.0))

	# Check if damage flash is enabled in settings
	if _state_store != null and _damage_flash != null:
		var state: Dictionary = _state_store.get_state()
		if U_VFX_SELECTORS.is_damage_flash_enabled(state):
			_damage_flash.trigger_flash(intensity)
