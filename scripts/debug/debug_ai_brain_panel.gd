extends Control
class_name DebugAIBrainPanel

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

@export var ecs_manager: I_ECSManager = null
@export_range(0.05, 5.0, 0.05, "or_greater") var refresh_interval_sec: float = 0.25

@onready var _rows: VBoxContainer = get_node_or_null("Rows") as VBoxContainer
@onready var _refresh_timer: Timer = get_node_or_null("RefreshTimer") as Timer

func _ready() -> void:
	_ensure_required_children()
	if _refresh_timer != null:
		_refresh_timer.wait_time = maxf(refresh_interval_sec, 0.05)
		if not _refresh_timer.timeout.is_connected(_on_refresh_timeout):
			_refresh_timer.timeout.connect(_on_refresh_timeout)
	refresh_rows()

func refresh_rows() -> void:
	if _rows == null:
		return

	_clear_rows()

	var manager: I_ECSManager = _resolve_manager()
	if manager == null:
		return

	var brain_components: Array = manager.get_components(C_AI_BRAIN_COMPONENT.COMPONENT_TYPE)
	for component_variant in brain_components:
		var brain: C_AIBrainComponent = component_variant as C_AIBrainComponent
		if brain == null:
			continue
		var row_label: Label = Label.new()
		row_label.text = _build_row_text(brain)
		_rows.add_child(row_label)

func _on_refresh_timeout() -> void:
	refresh_rows()

func _clear_rows() -> void:
	while _rows.get_child_count() > 0:
		var child: Node = _rows.get_child(0)
		_rows.remove_child(child)
		child.queue_free()

func _resolve_manager() -> I_ECSManager:
	if ecs_manager != null and is_instance_valid(ecs_manager):
		return ecs_manager
	return U_ECS_UTILS.get_manager(self) as I_ECSManager

func _ensure_required_children() -> void:
	if _rows == null:
		var rows: VBoxContainer = VBoxContainer.new()
		rows.name = "Rows"
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(rows)
		_rows = rows

	if _refresh_timer == null:
		var timer: Timer = Timer.new()
		timer.name = "RefreshTimer"
		timer.autostart = true
		add_child(timer)
		_refresh_timer = timer

func _build_row_text(brain: C_AIBrainComponent) -> String:
	var snapshot: Dictionary = brain.get_debug_snapshot()
	var entity_id_value: String = _resolve_entity_id(snapshot, brain)
	var goal_id_value: String = _resolve_snapshot_string(snapshot, "goal_id")
	var task_id_value: String = _resolve_snapshot_string(snapshot, "task_id")
	var detect_value: String = str(snapshot.get("is_player_in_range", "?"))
	var exit_radius_value: String = ""
	if snapshot.has("detection_exit_radius"):
		var er: float = float(snapshot.get("detection_exit_radius", 0.0))
		var dr: float = float(snapshot.get("detection_radius", 8.0))
		if er > dr:
			exit_radius_value = " exit=%.1f" % er
	return "%s | goal=%s | task=%s | detect=%s%s" % [entity_id_value, goal_id_value, task_id_value, detect_value, exit_radius_value]

func _resolve_entity_id(snapshot: Dictionary, brain: C_AIBrainComponent) -> String:
	var from_snapshot: String = _resolve_snapshot_string(snapshot, "entity_id")
	if not from_snapshot.is_empty():
		return from_snapshot

	var entity_root: Node = U_ECS_UTILS.find_entity_root(brain)
	if entity_root == null:
		return "<unknown_entity>"

	var resolved_entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
	if resolved_entity_id == StringName(""):
		return "<unknown_entity>"
	return str(resolved_entity_id)

func _resolve_snapshot_string(snapshot: Dictionary, key: String) -> String:
	if not snapshot.has(key):
		return ""
	var value: Variant = snapshot.get(key, "")
	if value == null:
		return ""
	if value is StringName:
		return str(value)
	if value is String:
		return value as String
	return str(value)
