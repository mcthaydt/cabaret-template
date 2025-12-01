extends Control
class_name GamepadStickPreview

## Simple visualization for left/right stick vectors.

@export var circle_radius: float = 50.0
@export var active_border_color: Color = Color(0.4, 0.9, 1.0, 0.9)
@export var hover_border_color: Color = Color(0.6, 0.8, 1.0, 0.9)
@export var inactive_border_color: Color = Color(0.25, 0.25, 0.25, 1.0)

var _is_active: bool = false

var _left_vector: Vector2 = Vector2.ZERO
var _right_vector: Vector2 = Vector2.ZERO
var _left_raw: Vector2 = Vector2.ZERO
var _right_raw: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(320, 200)

func set_left_vector(value: Vector2) -> void:
	_left_vector = value
	queue_redraw()

func set_right_vector(value: Vector2) -> void:
	_right_vector = value
	queue_redraw()

func update_vectors(left: Vector2, right: Vector2, left_raw: Vector2 = Vector2.ZERO, right_raw: Vector2 = Vector2.ZERO) -> void:
	_left_vector = left
	_right_vector = right
	_left_raw = left_raw
	_right_raw = right_raw
	queue_redraw()

func set_active(active: bool) -> void:
	_is_active = active
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_size()
	var left_center: Vector2 = Vector2(size.x * 0.25, size.y * 0.4)
	var right_center: Vector2 = Vector2(size.x * 0.75, size.y * 0.4)

	var border_color: Color = inactive_border_color
	if has_focus():
		border_color = hover_border_color
	if _is_active:
		border_color = active_border_color
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)

	# Draw stick visualizations
	_draw_stick_circle(left_center, _left_vector, Color(0.2, 0.7, 1.0))
	_draw_stick_circle(right_center, _right_vector, Color(1.0, 0.6, 0.2))

	# Draw text labels
	var font := get_theme_default_font()
	var font_size := 12

	# Left stick values
	var left_text := "Raw: (%.2f, %.2f)" % [_left_raw.x, _left_raw.y]
	var left_processed := "Post: (%.2f, %.2f)" % [_left_vector.x, _left_vector.y]
	draw_string(font, Vector2(left_center.x - 60, size.y * 0.75), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(left_center.x - 60, size.y * 0.85), left_processed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.2, 0.7, 1.0))

	# Right stick values
	var right_text := "Raw: (%.2f, %.2f)" % [_right_raw.x, _right_raw.y]
	var right_processed := "Post: (%.2f, %.2f)" % [_right_vector.x, _right_vector.y]
	draw_string(font, Vector2(right_center.x - 60, size.y * 0.75), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(right_center.x - 60, size.y * 0.85), right_processed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.6, 0.2))

func _draw_stick_circle(center: Vector2, vector: Vector2, color: Color) -> void:
	var radius: float = min(circle_radius, min(get_size().x, get_size().y) * 0.35)
	draw_circle(center, radius, Color(0.1, 0.1, 0.1, 0.8))
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.3, 0.3, 0.3), 1.0)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), Color(0.2, 0.2, 0.2), 1.0)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), Color(0.2, 0.2, 0.2), 1.0)

	var clamped: Vector2 = vector
	if clamped.length() > 1.0:
		clamped = clamped.normalized()
	var indicator: Vector2 = center + Vector2(clamped.x, -clamped.y) * radius
	draw_circle(indicator, 6.0, color)
