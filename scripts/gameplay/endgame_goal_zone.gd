extends Node3D

## Exterior final goal controller
##
## Keeps the GAME_COMPLETE goal zone hidden/disabled until the
## required area has been completed. Subscribes to the gameplay state
## and toggles visuals + Area3D monitoring accordingly.

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")

@export var required_area: String = "interior_house"
@export var victory_component_path: NodePath = NodePath("C_VictoryTriggerComponent")
@export var visual_paths: Array[NodePath] = [
	NodePath("Visual"),
	NodePath("Sparkles"),
	NodePath("GlowLight")
]

var _store: M_StateStore = null
var _victory_component: C_VictoryTriggerComponent = null
var _trigger_area: Area3D = null
var _is_unlocked: bool = false
var _has_applied_state: bool = false

func _ready() -> void:
	await get_tree().process_frame

	_store = U_StateUtils.get_store(self)
	if not victory_component_path.is_empty():
		_victory_component = get_node_or_null(victory_component_path) as C_VictoryTriggerComponent
		if _victory_component != null:
			_trigger_area = _victory_component.get_trigger_area()

	if _store != null:
		_store.slice_updated.connect(_on_slice_updated)

	_refresh_lock_state()

func _exit_tree() -> void:
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	_refresh_lock_state()

func _refresh_lock_state() -> void:
	var unlocked: bool = false
	if _store != null:
		var state: Dictionary = _store.get_state()
		var gameplay: Dictionary = state.get("gameplay", {})
		var completed_raw: Variant = gameplay.get("completed_areas", [])
		if completed_raw is Array:
			var completed: Array = completed_raw
			unlocked = completed.has(required_area)

	_apply_lock_state(unlocked)

func _apply_lock_state(unlocked: bool) -> void:
	if _has_applied_state and _is_unlocked == unlocked:
		return

	_has_applied_state = true
	_is_unlocked = unlocked

	visible = unlocked

	if _trigger_area != null:
		_trigger_area.monitoring = unlocked
		_trigger_area.monitorable = unlocked

	for path in visual_paths:
		if path.is_empty():
			continue
		var visual_node: Node = get_node_or_null(path)
		if visual_node == null:
			continue

		if visual_node is Node3D:
			(visual_node as Node3D).visible = unlocked
		elif visual_node is CanvasItem:
			(visual_node as CanvasItem).visible = unlocked

		if visual_node is GPUParticles3D:
			(visual_node as GPUParticles3D).emitting = unlocked
		elif visual_node is CPUParticles3D:
			(visual_node as CPUParticles3D).emitting = unlocked
