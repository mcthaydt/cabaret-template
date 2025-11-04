@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_DamageSystem

## Applies damage from C_DamageZoneComponent overlaps to entities with health.

const DAMAGE_COMPONENT_TYPE := StringName("C_DamageZoneComponent")
const HEALTH_COMPONENT_TYPE := StringName("C_HealthComponent")
const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")
const U_ECSUtils := preload("res://scripts/utils/u_ecs_utils.gd")

var _cooldowns: Dictionary = {}  # zone_instance_id -> Dictionary(entity_id -> remaining_time)

func _init() -> void:
	execution_priority = 250

func process_tick(delta: float) -> void:
	var zones: Array = get_components(DAMAGE_COMPONENT_TYPE)
	if zones.is_empty():
		return

	var health_by_entity := _map_health_components()

	for zone_entry in zones:
		var zone: C_DamageZoneComponent = zone_entry as C_DamageZoneComponent
		if zone == null or not is_instance_valid(zone):
			continue

		var zone_id: int = zone.get_instance_id()
		var cooldowns: Dictionary = _tick_cooldowns(zone_id, delta)
		var manager: M_ECSManager = zone.get_manager()
		if manager == null:
			_cooldowns[zone_id] = cooldowns
			continue

		var bodies: Array = zone.get_bodies_in_zone()
		for body_entry in bodies:
			var body: Node3D = body_entry as Node3D
			if body == null:
				continue

			var entity := U_ECSUtils.find_entity_root(body)
			if entity == null:
				continue

			var comps: Dictionary = manager.get_components_for_entity(entity)
			if not comps.has(PLAYER_TAG_COMPONENT) or comps.get(PLAYER_TAG_COMPONENT) == null:
				continue

			var entity_id := _get_entity_id(body)
			if entity_id.is_empty():
				continue

			var remaining: float = float(cooldowns.get(entity_id, 0.0))
			if remaining > 0.0:
				cooldowns[entity_id] = remaining
				continue

			var health_component: C_HealthComponent = null
			if health_by_entity.has(entity):
				health_component = health_by_entity[entity]
			if health_component == null:
				continue

			if zone.is_instant_death:
				health_component.queue_instant_death()
			else:
				health_component.queue_damage(zone.damage_amount)
				cooldowns[entity_id] = max(zone.damage_cooldown, 0.0)
		_cooldowns[zone_id] = cooldowns

	_cleanup_stale_zones(zones)

func _map_health_components() -> Dictionary:
	var result: Dictionary = {}
	var manager: M_ECSManager = get_manager()
	if manager == null:
		return result

	var health_components: Array = manager.get_components(HEALTH_COMPONENT_TYPE)
	for entry in health_components:
		var health_component: C_HealthComponent = entry as C_HealthComponent
		if health_component == null or not is_instance_valid(health_component):
			continue
		var entity := U_ECSUtils.find_entity_root(health_component)
		if entity != null:
			result[entity] = health_component
	return result

func _tick_cooldowns(zone_id: int, delta: float) -> Dictionary:
	var cooldowns: Dictionary = _cooldowns.get(zone_id, {}).duplicate()
	if cooldowns.is_empty():
		return cooldowns

	var to_remove: Array = []
	for entity_id in cooldowns.keys():
		var remaining: float = max(float(cooldowns.get(entity_id, 0.0)) - delta, 0.0)
		if remaining <= 0.0:
			to_remove.append(entity_id)
		else:
			cooldowns[entity_id] = remaining

	for entity_id in to_remove:
		cooldowns.erase(entity_id)

	return cooldowns

func _get_entity_id(body: Node) -> String:
	var entity := U_ECSUtils.find_entity_root(body)
	if entity != null:
		if entity.has_meta("entity_id"):
			return String(entity.get_meta("entity_id"))
		return String(entity.name)
	if body.has_meta("entity_id"):
		return String(body.get_meta("entity_id"))
	return String(body.name)

func _cleanup_stale_zones(zones: Array) -> void:
	var valid_ids: Array[int] = []
	for zone_entry in zones:
		var zone: C_DamageZoneComponent = zone_entry as C_DamageZoneComponent
		if zone != null and is_instance_valid(zone):
			valid_ids.append(zone.get_instance_id())

	var keys := _cooldowns.keys()
	for key in keys:
		var zone_id: int = int(key)
		if not valid_ids.has(zone_id):
			_cooldowns.erase(zone_id)
