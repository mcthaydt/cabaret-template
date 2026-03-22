@tool
@icon("res://assets/editor_icons/icn_utility.svg")
extends Node
class_name U_VCamRuleOfThirdsPreview

const U_CANVAS_LAYERS := preload("res://scripts/ui/u_canvas_layers.gd")
const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const GRID_LINE_WIDTH := 1.5

class RuleOfThirdsGrid extends Control:
	var line_color: Color = Color(1.0, 1.0, 1.0, 0.35)
	var line_width: float = 1.5

	func _ready() -> void:
		anchors_preset = PRESET_FULL_RECT
		anchor_right = 1.0
		anchor_bottom = 1.0
		grow_horizontal = GROW_DIRECTION_BOTH
		grow_vertical = GROW_DIRECTION_BOTH
		mouse_filter = MOUSE_FILTER_IGNORE
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return

		var x_step: float = size.x / 3.0
		var y_step: float = size.y / 3.0

		draw_line(Vector2(x_step, 0.0), Vector2(x_step, size.y), line_color, line_width, true)
		draw_line(Vector2(x_step * 2.0, 0.0), Vector2(x_step * 2.0, size.y), line_color, line_width, true)
		draw_line(Vector2(0.0, y_step), Vector2(size.x, y_step), line_color, line_width, true)
		draw_line(Vector2(0.0, y_step * 2.0), Vector2(size.x, y_step * 2.0), line_color, line_width, true)

var _preview_layer: CanvasLayer = null
var _preview_grid: RuleOfThirdsGrid = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_setup_preview()

func _setup_preview() -> void:
	if _preview_layer != null:
		return

	_preview_layer = CanvasLayer.new()
	_preview_layer.name = "VCamRuleOfThirdsPreviewLayer"
	_preview_layer.layer = U_CANVAS_LAYERS.DEBUG_OVERLAY

	_preview_grid = RuleOfThirdsGrid.new()
	_preview_grid.name = "VCamRuleOfThirdsGrid"
	_preview_grid.line_color = GRID_LINE_COLOR
	_preview_grid.line_width = GRID_LINE_WIDTH

	_preview_layer.add_child(_preview_grid)
	add_child(_preview_layer)

