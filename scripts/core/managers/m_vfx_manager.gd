@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/core/interfaces/i_vfx_manager.gd"
class_name M_VFXManager

## VFX Manager - Coordinates visual feedback effects (screen shake, damage flash)

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const U_VFX_SELECTORS := preload("res://scripts/core/state/selectors/u_vfx_selectors.gd")
const U_VCAM_ACTIONS := preload("res://scripts/core/state/actions/u_vcam_actions.gd")
const U_SCENE_SELECTORS := preload("res://scripts/core/state/selectors/u_scene_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/core/state/selectors/u_entity_selectors.gd")
const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const U_VCAM_SILHOUETTE_HELPER := preload("res://scripts/core/managers/helpers/u_vcam_silhouette_helper.gd")
const DAMAGE_FLASH_SCENE := preload("res://scenes/ui/overlays/ui_damage_flash_overlay.tscn")
const SCREEN_SHAKE_TUNING := preload("res://resources/vfx/cfg_screen_shake_tuning.tres")
const SCREEN_SHAKE_CONFIG := preload("res://resources/vfx/cfg_screen_shake_config.tres")
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
## - Registered with ServiceLocator via scene bootstrap (root.gd)
## - Discovers M_StateStore dependency for settings access
## - Uses U_ScreenShake helper for shake calculations (quadratic falloff, noise-based)
## - Uses U_DamageFlash helper for flash tween animations

## Injected dependencies (for testing)
@export var state_store: I_StateStore = null
@export var camera_manager: I_CAMERA_MANAGER = null

## StateStore dependency for accessing VFX settings
var _state_store: I_StateStore = null

## Camera Manager dependency for applying screen shake
var _camera_manager: I_CAMERA_MANAGER = null

## Screen shake helper for calculating shake offset/rotation
var _screen_shake: U_ScreenShake = null

## Damage flash helper for triggering red flash overlay
var _damage_flash: U_DamageFlash = null

## Current trauma level (0.0 = no shake, 1.0 = maximum shake)
## Trauma accumulates from damage/impacts and decays over time
var _trauma: float = 0.0

## Trauma decay rate (units per second)
## Trauma decays from 1.0 to 0.0 over 0.5 seconds at this rate
var _trauma_decay_rate: float = 2.0

## Request queues for deterministic processing
var _shake_requests: Array = []
var _flash_requests: Array = []
var _silhouette_requests: Array = []

## Unsubscribe callables for ECS event subscriptions
var _event_unsubscribes: Array[Callable] = []

## State store subscription for detecting shell changes
var _store_unsubscribe: Callable = Callable()
var _last_shell: StringName = StringName("")

## Preview settings overrides (used by settings UI)
var _preview_settings: Dictionary = {}
var _is_previewing: bool = false
var _effects_container: Node = null
var _silhouette_helper: U_VCamSilhouetteHelper = null
var _last_silhouette_count: int = 0

func _ready() -> void:
	# Run even when game is paused (VFX should be visible in pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Discover StateStore dependency (injection first)
	if state_store != null:
		_state_store = state_store
	else:
		_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self)
	if _state_store == null:
		print_verbose("M_VFXManager: StateStore not found. VFX settings will not be applied.")
	else:
		_last_silhouette_count = _resolve_state_silhouette_count(_state_store.get_state())

	# Discover Camera Manager dependency (VFX Phase 3: T3.2, injection first)
	if camera_manager != null:
		_camera_manager = camera_manager
	else:
		_camera_manager = U_SERVICE_LOCATOR.try_get_service(U_ECS_EVENT_NAMES.SERVICE_CAMERA_MANAGER)
	if _camera_manager == null:
		print_verbose("M_VFXManager: Camera Manager not found. Screen shake will not be applied.")

	# Initialize screen shake helper (VFX Phase 3: T3.2)
	var shake_config = SCREEN_SHAKE_CONFIG
	_screen_shake = U_ScreenShake.new(shake_config)
	var shake_tuning = SCREEN_SHAKE_TUNING
	_trauma_decay_rate = float(shake_tuning.trauma_decay_rate)

	# Load and initialize damage flash overlay (VFX Phase 4: T4.4)
	var flash_scene: PackedScene = DAMAGE_FLASH_SCENE
	if flash_scene != null:
			var flash_instance: CanvasLayer = flash_scene.instantiate()
			add_child(flash_instance)
			var flash_rect: ColorRect = flash_instance.get_node("FlashRect") as ColorRect
			if flash_rect != null:
				_damage_flash = U_DamageFlash.new(flash_rect, flash_instance)
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
	# Channel taxonomy: silhouette updates arrive via Redux dispatch (managers dispatch to Redux)
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		_state_store.action_dispatched.connect(_on_action_dispatched)

	_silhouette_helper = U_VCAM_SILHOUETTE_HELPER.new()

	# Subscribe to state changes to cancel flash when leaving gameplay
	if _state_store != null:
		_store_unsubscribe = _state_store.subscribe(_on_state_changed)

func _exit_tree() -> void:
	# Unsubscribe from all ECS events to prevent memory leaks
	for unsubscribe in _event_unsubscribes:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()

	# Disconnect from Redux action_dispatched (channel taxonomy)
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		if _state_store.action_dispatched.is_connected(_on_action_dispatched):
			_state_store.action_dispatched.disconnect(_on_action_dispatched)
	if _silhouette_helper != null:
		_silhouette_helper.remove_all_silhouettes()
	_dispatch_silhouette_count_if_changed(0)

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

## Apply temporary preview settings (for UI testing)
func set_vfx_settings_preview(settings: Dictionary) -> void:
	_preview_settings = settings.duplicate(true)
	_is_previewing = true

## Clear preview and revert to Redux state
func clear_vfx_settings_preview() -> void:
	_preview_settings.clear()
	_is_previewing = false

func set_effects_container(container: Node) -> void:
	_effects_container = container

func get_effects_container() -> Node:
	if _effects_container != null and is_instance_valid(_effects_container):
		return _effects_container
	_effects_container = null
	return null

## Trigger a test shake for preview purposes
func trigger_test_shake(intensity: float = 1.0) -> void:
	if not _get_screen_shake_enabled():
		return
	add_trauma(0.3 * intensity)

## Get effective screen shake enabled (preview or state)
func _get_screen_shake_enabled() -> bool:
	if _is_previewing and _preview_settings.has("screen_shake_enabled"):
		return bool(_preview_settings.get("screen_shake_enabled", true))
	if _state_store == null:
		return true
	return U_VFX_SELECTORS.is_screen_shake_enabled(_state_store.get_state())

## Get effective screen shake intensity (preview or state)
func _get_screen_shake_intensity() -> float:
	if _is_previewing and _preview_settings.has("screen_shake_intensity"):
		return float(_preview_settings.get("screen_shake_intensity", 1.0))
	if _state_store == null:
		return 1.0
	return U_VFX_SELECTORS.get_screen_shake_intensity(_state_store.get_state())

## Get effective damage flash enabled (preview or state)
func _get_damage_flash_enabled() -> bool:
	if _is_previewing and _preview_settings.has("damage_flash_enabled"):
		return bool(_preview_settings.get("damage_flash_enabled", true))
	if _state_store == null:
		return true
	return U_VFX_SELECTORS.is_damage_flash_enabled(_state_store.get_state())

## Check if entity_id matches the player entity
func _is_player_entity(entity_id: StringName) -> bool:
	if _state_store == null:
		return false # Fallback: BLOCK VFX if no store (safer)
	var state: Dictionary = _state_store.get_state()
	var player_entity_id: StringName = StringName(U_EntitySelectors.get_player_entity_id(state))
	if player_entity_id.is_empty():
		return false # Fallback: BLOCK VFX if no player registered (safer)
	var matches: bool = entity_id == player_entity_id
	return matches

## Check if VFX should be blocked due to transitions or non-gameplay state
func _is_transition_blocked() -> bool:
	if _state_store == null:
		return false
	var state: Dictionary = _state_store.get_state()

	# Block during scene transitions
	if U_SCENE_SELECTORS.is_transitioning(state):
		return true

	# Block if scene stack is not empty (loading/overlay scenes)
	var scene_stack: Array = U_SCENE_SELECTORS.get_scene_stack(state)
	if not scene_stack.is_empty():
		return true

	# Block if not in gameplay shell
	var shell: StringName = U_NAVIGATION_SELECTORS.get_shell(state)
	if shell != StringName("gameplay"):
		return true

	return false

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	var shell: StringName = U_NAVIGATION_SELECTORS.get_shell(state)
	if _last_shell == StringName("gameplay") and shell != StringName("gameplay"):
		if _damage_flash != null:
			_damage_flash.cancel_flash()
	_last_shell = shell

## Physics process - handles trauma decay and screen shake application (VFX Phase 3: T3.2)
func _physics_process(delta: float) -> void:
	# Process queued requests (deterministic ordering)
	for request in _shake_requests:
		_process_shake_request(request)
	_shake_requests.clear()

	for request in _flash_requests:
		_process_flash_request(request)
	_flash_requests.clear()

	for request in _silhouette_requests:
		_process_silhouette_request(request)
	_silhouette_requests.clear()

	# Decay trauma over time (2.0/sec rate)
	_trauma = maxf(_trauma - _trauma_decay_rate * delta, 0.0)

	# Apply screen shake if camera manager available and shake enabled in settings/preview
	if _camera_manager != null and _state_store != null and _screen_shake != null:
		if _get_screen_shake_enabled():
			var intensity: float = _get_screen_shake_intensity()
			var shake_result = _screen_shake.calculate_shake(_trauma, intensity, delta)
			_camera_manager.apply_shake_offset(shake_result.offset, shake_result.rotation)
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

## Event handler for silhouette update request events
## Channel taxonomy: silhouette updates arrive via Redux dispatch (managers dispatch to Redux)
func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	if action_type != U_VCAM_ACTIONS.ACTION_SILHOUETTE_UPDATE_REQUEST:
		return
	# Reconstruct ECS-compatible event_data for existing handler
	var event_data: Dictionary = {
		"payload": {
			"entity_id": action.get("entity_id", StringName("")),
			"occluders": action.get("occluders", []),
			"enabled": action.get("enabled", true),
		},
	}
	_on_silhouette_update_request(event_data)

func _on_silhouette_update_request(event_data: Dictionary) -> void:
	if _state_store == null or _silhouette_helper == null:
		return

	var payload: Dictionary = event_data.get("payload", {})
	var enabled: bool = bool(payload.get("enabled", true))
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	# Keep player-only ownership for all silhouette requests.
	if not _is_player_entity(entity_id):
		return

	# Explicit clear requests must always pass through so stale silhouettes are removed
	# even if gameplay is currently transition-blocked.
	if not enabled:
		_silhouette_requests.append(event_data)
		return

	# Gating: player-only and transition check
	if _is_transition_blocked():
		return

	_silhouette_requests.append(event_data)

func _process_shake_request(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var trauma_amount: float = float(payload.get("trauma_amount", 0.0))
	add_trauma(trauma_amount)

func _process_flash_request(event_data: Dictionary) -> void:
	if _state_store == null or _damage_flash == null:
		return
	if not _get_damage_flash_enabled():
		return
	var payload: Dictionary = event_data.get("payload", {})
	var intensity: float = float(payload.get("intensity", 1.0))
	_damage_flash.trigger_flash(intensity)

func _process_silhouette_request(event_data: Dictionary) -> void:
	if _silhouette_helper == null:
		return

	var payload: Dictionary = event_data.get("payload", {})
	var enabled: bool = bool(payload.get("enabled", true))

	var occluders_variant: Variant = payload.get("occluders", [])
	_silhouette_helper.update_silhouettes(occluders_variant, enabled)
	_dispatch_silhouette_count_if_changed(_silhouette_helper.get_active_count())

func _resolve_state_silhouette_count(state: Dictionary) -> int:
	return maxi(U_VCAM_SELECTORS.get_silhouette_active_count(state), 0)

func _dispatch_silhouette_count_if_changed(next_count: int) -> void:
	if _state_store == null:
		return
	var normalized_count: int = maxi(next_count, 0)
	if normalized_count == _last_silhouette_count:
		return
	_last_silhouette_count = normalized_count
	_state_store.dispatch(U_VCAM_ACTIONS.update_silhouette_count(normalized_count))
