@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_HealthSystem

## Core health management system.
## Applies queued damage/heal events, handles regeneration and death flow,
## dispatches state actions, and coordinates delayed death transitions.
## System remains tick-driven; health/victory subscribers should listen to
## U_ECSEventBus events emitted by components instead of direct signals.

const COMPONENT_TYPE := StringName("C_HealthComponent")
const DEATH_HANDLER_SYSTEM_SCRIPT := preload("res://scripts/ecs/systems/s_death_handler_system.gd")

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null

var _store: I_StateStore = null
var _death_logged: Dictionary = {}          # entity_id -> bool
var _transition_triggered: Dictionary = {}  # entity_id -> bool (death-requested published)
var _synced_from_state: Dictionary = {}  # entity_id -> bool

func _init() -> void:
	execution_priority = 200

func process_tick(delta: float) -> void:
	if not _ensure_dependencies_ready():
		return

	var components: Array = get_components(COMPONENT_TYPE)
	if components.is_empty():
		return

	for entry in components:
		var component: C_HealthComponent = entry as C_HealthComponent
		if component == null or not is_instance_valid(component):
			continue

		var entity_id := _get_entity_id(component)
		if entity_id.is_empty():
			continue

		_process_component(component, entity_id, delta)

func _process_component(component: C_HealthComponent, entity_id: String, delta: float) -> void:
	if component.settings == null:
		return

	# One-time sync: initialize component health from persisted gameplay state
	# This prevents health resetting to max when changing gameplay scenes.
	if not _synced_from_state.get(entity_id, false):
		var desired_health: float = -1.0
		if _store != null:
			var gameplay: Dictionary = _store.get_slice(StringName("gameplay"))
			var player_id: String = String(gameplay.get("player_entity_id", "player"))
			if entity_id == player_id:
				desired_health = float(gameplay.get("player_health", -1.0))
		if desired_health >= 0.0:
			var current: float = component.get_current_health()
			var diff: float = desired_health - current
			if diff > 0.0:
				component.apply_heal(diff)
			elif diff < 0.0:
				component.apply_damage(-diff)
		_synced_from_state[entity_id] = true

	# Update timers
	component.consume_invincibility(delta)
	if not component.is_dead():
		component.time_since_last_damage += delta
	else:
		component.death_timer = max(component.death_timer - delta, 0.0)

	# Apply queued damage/heal events
	_apply_damage(component, entity_id)
	_apply_heal(component, entity_id)
	_apply_regeneration(component, entity_id, delta)

	# Dispatch snapshot for coordination
	_update_entity_snapshot(component, entity_id)

	# Handle delayed death transition
	if component.is_dead():
		_handle_death_sequence(component, entity_id)
	else:
		_reset_death_flags(entity_id)

func _apply_damage(component: C_HealthComponent, entity_id: String) -> void:
	var instant_death := component.consume_instant_death_flag()
	var pending_damage: float = component.dequeue_total_damage()

	if instant_death and not component.is_dead():
		var previous_health: float = component.get_current_health()
		component.reset_invincibility()
		component.apply_damage(component.get_current_health())
		component.mark_dead()
		component.death_timer = component.settings.death_animation_duration
		if previous_health > 0.0:
			_dispatch_damage_state(entity_id, previous_health)
		_dispatch_death_state(entity_id, component)
		return

	if pending_damage <= 0.0 or component.is_dead():
		return

	if component.is_invincible:
		return  # Ignore damage during invincibility window

	var previous := component.get_current_health()
	component.apply_damage(pending_damage)
	component.trigger_invincibility()

	var damage_amount: float = previous - component.get_current_health()
	if damage_amount > 0.0:
		_dispatch_damage_state(entity_id, damage_amount)

	if component.get_current_health() <= 0.0 and not component.is_dead():
		component.mark_dead()
		component.death_timer = component.settings.death_animation_duration
		_dispatch_death_state(entity_id, component)

func _apply_heal(component: C_HealthComponent, entity_id: String) -> void:
	if component.is_dead():
		component.dequeue_total_heal()  # Clear pending heals while dead
		return

	var pending_heal: float = component.dequeue_total_heal()
	if pending_heal <= 0.0:
		return

	var previous := component.get_current_health()
	component.apply_heal(pending_heal)

	var heal_amount: float = component.get_current_health() - previous
	if heal_amount > 0.0:
		_dispatch_heal_state(entity_id, heal_amount)

func _apply_regeneration(component: C_HealthComponent, entity_id: String, delta: float) -> void:
	if component.is_dead():
		return
	if component.settings == null or not component.settings.regen_enabled:
		return
	if component.get_current_health() >= component.get_max_health():
		return
	if component.time_since_last_damage < component.settings.regen_delay:
		return

	var regen_amount: float = component.settings.regen_rate * delta
	if regen_amount <= 0.0:
		return

	var previous := component.get_current_health()
	component.apply_heal(regen_amount)

	if not is_equal_approx(previous, component.get_current_health()):
		var healed_amount: float = component.get_current_health() - previous
		if healed_amount > 0.0:
			_dispatch_heal_state(entity_id, healed_amount)

func _handle_death_sequence(component: C_HealthComponent, entity_id: String) -> void:
	if not _transition_triggered.get(entity_id, false):
		_publish_death_requested(component, entity_id)
		_transition_triggered[entity_id] = true

	# Death timer and transition are now handled by entity_death event
	# M_SceneManager subscribes to entity_death and handles game over transition

func _reset_death_flags(entity_id: String) -> void:
	if _transition_triggered.get(entity_id, false):
		_publish_respawn_requested(entity_id)
	_death_logged.erase(entity_id)
	_transition_triggered.erase(entity_id)
	_synced_from_state.erase(entity_id)

func _dispatch_damage_state(entity_id: String, damage_amount: float) -> void:
	if _store == null:
		return
	_store.dispatch(U_GameplayActions.take_damage(entity_id, damage_amount))

func _dispatch_heal_state(entity_id: String, heal_amount: float) -> void:
	if _store == null:
		return
	_store.dispatch(U_GameplayActions.heal(entity_id, heal_amount))

func _dispatch_death_state(entity_id: String, _component: C_HealthComponent) -> void:
	if _store == null:
		return

	if not _death_logged.get(entity_id, false):
		_store.dispatch(U_GameplayActions.increment_death_count())
		_death_logged[entity_id] = true

	_store.dispatch(U_GameplayActions.trigger_death(entity_id))

func _update_entity_snapshot(component: C_HealthComponent, entity_id: String) -> void:
	if _store == null:
		return
	var snapshot := {
		"health": component.get_current_health(),
		"max_health": component.get_max_health(),
		"is_dead": component.is_dead()
	}
	_store.dispatch(U_EntityActions.update_entity_snapshot(entity_id, snapshot))

func _publish_death_requested(component: C_HealthComponent, entity_id: String) -> void:
	var payload: Dictionary = {
		"entity_id": entity_id,
		"health_component": component,
	}
	var entity_root := U_ECSUtils.find_entity_root(component) as Node3D
	if entity_root == null:
		entity_root = component.get_parent() as Node3D
	if entity_root != null:
		payload["entity_root"] = entity_root
	var body := component.get_character_body()
	if body != null and is_instance_valid(body):
		payload["body"] = body

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH_REQUESTED, payload)

func _publish_respawn_requested(entity_id: String) -> void:
	var payload: Dictionary = {
		"entity_id": entity_id,
	}
	var entity := _find_entity_root_by_id(entity_id)
	if entity != null:
		payload["entity_root"] = entity

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_RESPAWN_REQUESTED, payload)

func _find_entity_root_by_id(entity_id: String) -> Node3D:
	var manager: I_ECSManager = get_manager()
	if manager == null or not manager.has_method("get_entity_by_id"):
		return null
	var entity_variant: Variant = manager.call("get_entity_by_id", StringName(entity_id))
	return entity_variant as Node3D

func get_ragdoll_for_entity(entity_id: StringName) -> RigidBody3D:
	var handler: Variant = _find_death_handler()
	if handler == null:
		return null
	if not handler.has_method("get_ragdoll_for_entity"):
		return null
	return handler.call("get_ragdoll_for_entity", entity_id) as RigidBody3D

func _find_death_handler() -> Variant:
	var parent_node: Node = get_parent()
	if parent_node != null:
		var in_parent: Variant = parent_node.find_child("S_DeathHandlerSystem", true, false)
		if in_parent != null and in_parent.get_script() == DEATH_HANDLER_SYSTEM_SCRIPT:
			return in_parent
		if in_parent != null:
			return in_parent

	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null
	var found: Variant = current_scene.find_child("S_DeathHandlerSystem", true, false)
	if found != null and found.get_script() == DEATH_HANDLER_SYSTEM_SCRIPT:
		return found
	return null

func _ensure_dependencies_ready() -> bool:
	if _store == null:
		# Use injected store if available (Phase 10B-8)
		if state_store != null:
			_store = state_store
		else:
			_store = U_StateUtils.get_store(self)
	return _store != null

func _get_entity_id(component: C_HealthComponent) -> String:
	var entity := U_ECSUtils.find_entity_root(component)
	if entity != null:
		return String(U_ECSUtils.get_entity_id(entity))

	var body := component.get_character_body()
	if body != null:
		return String(U_ECSUtils.get_entity_id(body))

	var entity_node := component.get_parent()
	if entity_node != null:
		return String(U_ECSUtils.get_entity_id(entity_node))
	return ""
