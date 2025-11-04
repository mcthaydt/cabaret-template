@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_HealthSystem

## Core health management system.
## Applies queued damage/heal events, handles regeneration and death flow,
## dispatches state actions, and coordinates delayed death transitions.

const COMPONENT_TYPE := StringName("C_HealthComponent")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_EntityActions := preload("res://scripts/state/actions/u_entity_actions.gd")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const U_ECSUtils := preload("res://scripts/utils/u_ecs_utils.gd")
const PLAYER_RAGDOLL := preload("res://templates/player_ragdoll.tscn")

var _store: M_StateStore = null
var _scene_manager: M_SceneManager = null
var _death_logged: Dictionary = {}          # entity_id -> bool
var _transition_triggered: Dictionary = {}  # entity_id -> bool
var _ragdoll_spawned: Dictionary = {}       # entity_id -> bool
var _ragdoll_instances: Dictionary = {}     # entity_id -> WeakRef
var _entity_refs: Dictionary = {}           # entity_id -> WeakRef
var _entity_original_visibility: Dictionary = {}  # entity_id -> bool
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	execution_priority = 200
	_rng.randomize()

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
	if not _ragdoll_spawned.get(entity_id, false):
		_spawn_ragdoll(component, entity_id)
		_ragdoll_spawned[entity_id] = true

	if component.death_timer > 0.0:
		return
	if _transition_triggered.get(entity_id, false):
		return

	_transition_triggered[entity_id] = true

	if _scene_manager != null and is_instance_valid(_scene_manager):
		_scene_manager.transition_to_scene(
			StringName("game_over"),
			"fade",
			M_SceneManager.Priority.CRITICAL
		)

func _reset_death_flags(entity_id: String) -> void:
	_restore_entity_state(entity_id)
	_death_logged.erase(entity_id)
	_transition_triggered.erase(entity_id)

func _dispatch_damage_state(entity_id: String, damage_amount: float) -> void:
	if _store == null:
		return
	_store.dispatch(U_GameplayActions.take_damage(entity_id, damage_amount))

func _dispatch_heal_state(entity_id: String, heal_amount: float) -> void:
	if _store == null:
		return
	_store.dispatch(U_GameplayActions.heal(entity_id, heal_amount))

func _dispatch_death_state(entity_id: String, component: C_HealthComponent) -> void:
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

func _spawn_ragdoll(component: C_HealthComponent, entity_id: String) -> void:
	if PLAYER_RAGDOLL == null:
		return

	var entity_root := U_ECSUtils.find_entity_root(component) as Node3D
	if entity_root == null:
		entity_root = component.get_parent() as Node3D
	if entity_root == null:
		return

	var parent := entity_root.get_parent()
	if parent == null:
		return

	var ragdoll_scene := PLAYER_RAGDOLL as PackedScene
	if ragdoll_scene == null:
		return

	var ragdoll := ragdoll_scene.instantiate() as RigidBody3D
	if ragdoll == null:
		return

	var source_transform: Transform3D = entity_root.global_transform
	var body := component.get_character_body()
	if body != null and is_instance_valid(body):
		source_transform = body.global_transform

	parent.add_child(ragdoll)
	ragdoll.global_transform = source_transform
	ragdoll.linear_velocity = Vector3(
		_rng.randf_range(-4.0, 4.0),
		_rng.randf_range(4.0, 6.0),
		_rng.randf_range(-4.0, 4.0)
	)
	ragdoll.angular_velocity = Vector3(
		_rng.randf_range(-6.0, 6.0),
		_rng.randf_range(-3.0, 3.0),
		_rng.randf_range(-6.0, 6.0)
	)
	ragdoll.set_meta("player_ragdoll", true)

	_entity_refs[entity_id] = weakref(entity_root)
	_entity_original_visibility[entity_id] = entity_root.visible
	entity_root.visible = false
	_ragdoll_instances[entity_id] = weakref(ragdoll)

func _restore_entity_state(entity_id: String) -> void:
	var ragdoll_ref_candidate: Variant = _ragdoll_instances.get(entity_id)
	if ragdoll_ref_candidate is WeakRef:
		var ragdoll_ref: WeakRef = ragdoll_ref_candidate
		var ragdoll := ragdoll_ref.get_ref() as RigidBody3D
		if ragdoll != null and is_instance_valid(ragdoll):
			ragdoll.queue_free()
	_ragdoll_instances.erase(entity_id)

	var entity_ref_candidate: Variant = _entity_refs.get(entity_id)
	if entity_ref_candidate is WeakRef:
		var entity_ref: WeakRef = entity_ref_candidate
		var entity := entity_ref.get_ref() as Node3D
		if entity != null and is_instance_valid(entity):
			var was_visible: bool = bool(_entity_original_visibility.get(entity_id, true))
			entity.visible = was_visible
	_entity_refs.erase(entity_id)
	_entity_original_visibility.erase(entity_id)
	_ragdoll_spawned.erase(entity_id)

func _ensure_dependencies_ready() -> bool:
	if _store == null:
		_store = U_StateUtils.get_store(self)
	if _scene_manager == null:
		var managers := get_tree().get_nodes_in_group("scene_manager")
		if managers.size() > 0:
			_scene_manager = managers[0] as M_SceneManager
	return _store != null

func _get_entity_id(component: C_HealthComponent) -> String:
	var entity := U_ECSUtils.find_entity_root(component)
	if entity != null:
		if entity.has_meta("entity_id"):
			return String(entity.get_meta("entity_id"))
		return String(entity.name)

	var body := component.get_character_body()
	if body != null:
		if body.has_meta("entity_id"):
			return String(body.get_meta("entity_id"))
		return String(body.name)

	var entity_node := component.get_parent()
	if entity_node != null:
		return String(entity_node.name)
	return ""
