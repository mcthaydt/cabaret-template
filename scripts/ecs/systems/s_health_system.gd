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
	
	# Read initial health state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	_is_alive = GameplaySelectors.get_is_player_alive(gameplay_state)

func _exit_tree() -> void:
	# Clean up subscriptions
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

## Timer callback - apply periodic damage
func _on_damage_timer_timeout() -> void:
	if not _store or not _is_alive:
		return
	
	# Don't apply damage if paused
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	if GameplaySelectors.get_is_paused(gameplay_state):
		return
	
	# Apply damage
	_store.dispatch(U_GameplayActions.take_damage(DAMAGE_AMOUNT))

## Handle state store slice updates
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	
	var was_alive: bool = _is_alive
	_is_alive = GameplaySelectors.get_is_player_alive(slice_state)
	
	# Detect death transition
	if was_alive and not _is_alive:
		_on_player_died(slice_state)

## Handle player death
func _on_player_died(gameplay_state: Dictionary) -> void:
	# Stop damage timer
	if _damage_timer:
		_damage_timer.stop()
	
	# Emit death signal
	player_died.emit()
