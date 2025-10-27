@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_HealthSystem

## Health System - Manages player health via State Store (PoC)
##
## Applies damage over time for proof-of-concept integration testing.
## In real game, this would react to combat events, collisions, etc.

signal player_died()

var _store: M_StateStore = null
var _damage_timer: Timer = null
var _is_alive: bool = true

# Damage configuration
const DAMAGE_INTERVAL: float = 5.0  # Seconds between damage ticks
const DAMAGE_AMOUNT: int = 10       # HP lost per tick

func _ready() -> void:
	super._ready()
	
	# Wait for tree to be fully ready (M_StateStore needs to add itself to group)
	await get_tree().process_frame
	
	# Get reference to state store
	_store = U_StateUtils.get_store(self)
	
	if not _store:
		push_error("S_HealthSystem: Could not find M_StateStore")
		return
	
	# Subscribe to gameplay slice updates
	_store.slice_updated.connect(_on_slice_updated)
	
	# Create damage timer
	_damage_timer = Timer.new()
	_damage_timer.wait_time = DAMAGE_INTERVAL
	_damage_timer.one_shot = false
	_damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(_damage_timer)
	_damage_timer.start()
	
	# NOTE: Health state removed - initialization disabled until Phase 16
	_is_alive = true

func _exit_tree() -> void:
	# Clean up subscriptions
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

## Timer callback - apply periodic damage
func _on_damage_timer_timeout() -> void:
	# NOTE: Health state removed - this system is now a placeholder for Phase 16 integration
	# When health is re-added in Phase 16, restore damage logic here
	pass

## Handle state store slice updates
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	# NOTE: Health state removed - this handler is now a placeholder for Phase 16 integration
	pass

## Handle player death
func _on_player_died(gameplay_state: Dictionary) -> void:
	# NOTE: Health state removed - death detection disabled until Phase 16
	pass
