@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_VFXManager

## VFX Manager - Coordinates visual feedback effects (screen shake, damage flash)

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const M_ScreenShake := preload("res://scripts/managers/helpers/m_screen_shake.gd")
const M_DamageFlash := preload("res://scripts/managers/helpers/m_damage_flash.gd")
##
## Responsibilities:
## - Manages trauma system for screen shake (accumulates from damage/impacts, decays over time)
## - Coordinates with M_CameraManager to apply shake offsets
## - Triggers damage flash overlay on health changes
## - Subscribes to ECS events (health_changed, entity_landed, entity_death)
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

## StateStore dependency for accessing VFX settings
var _state_store: Node = null  # Type: I_StateStore (using Node for now)

## Camera Manager dependency for applying screen shake
var _camera_manager: M_CameraManager = null

## Screen shake helper for calculating shake offset/rotation
var _screen_shake: M_ScreenShake = null

## Damage flash helper for triggering red flash overlay
var _damage_flash: M_DamageFlash = null

## Current trauma level (0.0 = no shake, 1.0 = maximum shake)
## Trauma accumulates from damage/impacts and decays over time
var _trauma: float = 0.0

## Unsubscribe callables for ECS event subscriptions
var _unsubscribe_health: Callable
var _unsubscribe_landed: Callable
var _unsubscribe_death: Callable

func _ready() -> void:
	# Run even when game is paused (VFX should be visible in pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Add to group for discoverability
	add_to_group("vfx_manager")

	# Register with ServiceLocator
	U_SERVICE_LOCATOR.register(StringName("vfx_manager"), self)

	# Discover StateStore dependency
	_state_store = U_SERVICE_LOCATOR.try_get_service(StringName("state_store"))
	if _state_store == null:
		print_verbose("M_VFXManager: StateStore not found. VFX settings will not be applied.")

	# Discover Camera Manager dependency (VFX Phase 3: T3.2)
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

	# Subscribe to ECS events for trauma triggers
	_unsubscribe_health = U_ECS_EVENT_BUS.subscribe(StringName("health_changed"), _on_health_changed)
	_unsubscribe_landed = U_ECS_EVENT_BUS.subscribe(StringName("entity_landed"), _on_landed)
	_unsubscribe_death = U_ECS_EVENT_BUS.subscribe(StringName("entity_death"), _on_death)

func _exit_tree() -> void:
	# Unsubscribe from all ECS events to prevent memory leaks
	if _unsubscribe_health.is_valid():
		_unsubscribe_health.call()
	if _unsubscribe_landed.is_valid():
		_unsubscribe_landed.call()
	if _unsubscribe_death.is_valid():
		_unsubscribe_death.call()

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

## Event handler for health_changed events
##
## Maps damage amount to trauma in 0.3-0.6 range and triggers damage flash
func _on_health_changed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var damage: float = payload.get("damage", 0.0)

	# Map damage (0-100) to trauma (0.3-0.6)
	# Using lerpf: lerp between 0.3 and 0.6 based on damage/100
	var damage_ratio: float = clampf(damage / 100.0, 0.0, 1.0)
	var trauma_amount: float = lerpf(0.3, 0.6, damage_ratio)
	add_trauma(trauma_amount)

	# Trigger damage flash if enabled (VFX Phase 4: T4.4)
	if _state_store != null and _damage_flash != null:
		var state: Dictionary = _state_store.get_state()
		if U_VFX_SELECTORS.is_damage_flash_enabled(state):
			_damage_flash.trigger_flash(1.0)

## Event handler for entity_landed events
##
## Adds trauma for high-speed impacts (fall speed > 15.0)
func _on_landed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var fall_speed: float = payload.get("fall_speed", 0.0)

	# Only add trauma if fall speed exceeds threshold
	if fall_speed > 15.0:
		# Map fall speed (15-30) to trauma (0.2-0.4)
		# Using lerpf: lerp between 0.2 and 0.4 based on (fall_speed - 15) / (30 - 15)
		var speed_ratio: float = clampf((fall_speed - 15.0) / 15.0, 0.0, 1.0)
		var trauma_amount: float = lerpf(0.2, 0.4, speed_ratio)
		add_trauma(trauma_amount)

## Event handler for entity_death events
##
## Adds fixed trauma amount of 0.5
func _on_death(event_data: Dictionary) -> void:
	add_trauma(0.5)
