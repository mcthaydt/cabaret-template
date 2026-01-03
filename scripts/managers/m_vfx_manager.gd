@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_VFXManager

## VFX Manager - Coordinates visual feedback effects (screen shake, damage flash)

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
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

## Physics process - handles trauma decay
func _physics_process(delta: float) -> void:
	# Decay trauma over time (2.0/sec rate)
	_trauma = maxf(_trauma - TRAUMA_DECAY_RATE * delta, 0.0)

## Event handler for health_changed events
##
## Maps damage amount to trauma in 0.3-0.6 range
func _on_health_changed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var damage: float = payload.get("damage", 0.0)

	# Map damage (0-100) to trauma (0.3-0.6)
	# Using lerpf: lerp between 0.3 and 0.6 based on damage/100
	var damage_ratio: float = clampf(damage / 100.0, 0.0, 1.0)
	var trauma_amount: float = lerpf(0.3, 0.6, damage_ratio)
	add_trauma(trauma_amount)

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
