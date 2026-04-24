extends Label3D
class_name DebugWoodsAgentLabel

const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const C_INVENTORY_COMPONENT := preload("res://scripts/demo/ecs/components/c_inventory_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")

@export var brain_component_path: NodePath = NodePath("../Components/C_AIBrainComponent")

var _brain: C_AIBrainComponent = null
var _body: CharacterBody3D = null
var _y_offset: float = 2.2

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fixed_size = true
	no_depth_test = true
	pixel_size = 0.002
	font_size = 16
	_y_offset = position.y
	_resolve_brain_component()
	_resolve_body()
	_update_label_text()

func _process(_delta: float) -> void:
	if _brain == null or not is_instance_valid(_brain):
		_resolve_brain_component()
	_follow_body()
	_update_label_text()

func _resolve_body() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is CharacterBody3D:
			_body = child as CharacterBody3D
			return

func _follow_body() -> void:
	if _body == null or not is_instance_valid(_body):
		_resolve_body()
		if _body == null:
			return
	global_position = Vector3(_body.global_position.x, _body.global_position.y + _y_offset, _body.global_position.z)

func _resolve_brain_component() -> void:
	if not brain_component_path.is_empty():
		_brain = get_node_or_null(brain_component_path) as C_AIBrainComponent
		if _brain != null:
			return
	var entity_root: Node = U_ECS_UTILS.find_entity_root(self)
	if entity_root == null:
		_brain = null
		return
	_brain = entity_root.get_node_or_null("Components/C_AIBrainComponent") as C_AIBrainComponent

func _update_label_text() -> void:
	if _brain == null:
		text = "<no_brain>"
		return
	var snapshot: Dictionary = _brain.get_debug_snapshot()
	var entity_id_text: String = _resolve_entity_id(snapshot)
	var goal_id_text: String = _resolve_snapshot_text(snapshot, "goal_id")
	var task_id_text: String = _resolve_snapshot_text(snapshot, "task_id")
	var needs: Dictionary = _resolve_needs_values(snapshot)
	var hunger: float = float(needs.get("hunger", 1.0))
	var thirst: float = float(needs.get("thirst", 1.0))
	var inventory_text: String = _resolve_inventory_text()
	modulate = _resolve_hunger_color(needs)
	text = "%s\ngoal: %s\ntask: %s\nhunger: %.2f | thirst: %.2f\n%s" % [entity_id_text, goal_id_text, task_id_text, hunger, thirst, inventory_text]

func _resolve_needs_values(snapshot: Dictionary) -> Dictionary:
	var hunger: float = clampf(float(snapshot.get("hunger", 1.0)), 0.0, 1.0)
	var thirst: float = clampf(float(snapshot.get("thirst", 1.0)), 0.0, 1.0)
	var sated_threshold: float = clampf(float(snapshot.get("sated_threshold", 0.7)), 0.0, 1.0)
	var starving_threshold: float = clampf(float(snapshot.get("starving_threshold", 0.25)), 0.0, 1.0)
	var entity_root: Node = U_ECS_UTILS.find_entity_root(self)
	if entity_root != null:
		var needs: C_NeedsComponent = entity_root.get_node_or_null("Components/C_NeedsComponent") as C_NeedsComponent
		if needs != null:
			hunger = clampf(needs.hunger, 0.0, 1.0)
			thirst = clampf(needs.thirst, 0.0, 1.0)
			if needs.settings != null:
				sated_threshold = clampf(needs.settings.sated_threshold, 0.0, 1.0)
				starving_threshold = clampf(needs.settings.starving_threshold, 0.0, 1.0)
	return {
		"hunger": hunger,
		"thirst": thirst,
		"sated_threshold": sated_threshold,
		"starving_threshold": starving_threshold,
	}

func _resolve_inventory_text() -> String:
	var entity_root: Node = U_ECS_UTILS.find_entity_root(self)
	if entity_root == null:
		return ""
	var inv: C_InventoryComponent = entity_root.get_node_or_null("Components/C_InventoryComponent") as C_InventoryComponent
	if inv == null:
		return ""
	return "inv:%d/%d" % [inv.total(), inv.settings.capacity]

func _resolve_entity_id(snapshot: Dictionary) -> String:
	var entity_id_text: String = _resolve_snapshot_text(snapshot, "entity_id")
	if not entity_id_text.is_empty():
		return entity_id_text
	var entity_root: Node = U_ECS_UTILS.find_entity_root(self)
	if entity_root == null:
		return "<entity>"
	var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
	if entity_id == StringName(""):
		return "<entity>"
	return str(entity_id)

func _resolve_snapshot_text(snapshot: Dictionary, key: String) -> String:
	if not snapshot.has(key):
		return ""
	var value: Variant = snapshot.get(key, "")
	if value == null:
		return ""
	if value is String:
		return value as String
	if value is StringName:
		return str(value)
	return str(value)

func _resolve_hunger_color(snapshot: Dictionary) -> Color:
	var hunger: float = clampf(float(snapshot.get("hunger", 1.0)), 0.0, 1.0)
	var sated_threshold: float = clampf(float(snapshot.get("sated_threshold", 0.7)), 0.0, 1.0)
	var starving_threshold: float = clampf(float(snapshot.get("starving_threshold", 0.25)), 0.0, 1.0)
	if hunger >= sated_threshold:
		return Color(0.5, 0.95, 0.5, 1.0)
	if hunger <= starving_threshold:
		return Color(1.0, 0.45, 0.45, 1.0)
	return Color(1.0, 0.9, 0.35, 1.0)
