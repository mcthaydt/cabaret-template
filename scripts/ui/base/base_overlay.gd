@icon("res://resources/editor_icons/utility.svg")
extends BaseMenuScreen
class_name BaseOverlay

## Base class for overlay scenes that stack on top of gameplay/menus.
##
## Ensures overlays keep processing even when the tree is paused.
## Inherits analog stick repeat behavior from BaseMenuScreen.
## Automatically creates an opaque/dimmed background panel to prevent
## visual bleed-through when overlays are stacked.

## Background panel color (default: semi-transparent black for dimming effect)
@export var background_color: Color = Color(0, 0, 0, 0.7)

## Whether to create the background panel automatically
@export var auto_create_background: bool = true

## Optional: reference to existing background panel (if you want custom control)
@export var custom_background_panel: ColorRect = null
var overlay_scene_id: StringName = StringName("")

var _background_panel: ColorRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Setup background panel before super._ready() so it's behind all content
	if custom_background_panel != null:
		# Use explicitly assigned custom panel
		_background_panel = custom_background_panel
		_configure_existing_background(_background_panel)
		if _background_panel.get_parent() == self:
			move_child(_background_panel, 0)
	elif auto_create_background:
		# Try to reuse existing ColorRect as first child (backward compatibility)
		var first_child: Node = get_child(0) if get_child_count() > 0 else null
		if first_child is ColorRect:
			_background_panel = first_child as ColorRect
			_configure_existing_background(_background_panel)
		else:
			# Create new background panel
			_create_background_panel()

	await super._ready()

func set_overlay_scene_id(scene_id: StringName) -> void:
	overlay_scene_id = scene_id

func get_overlay_scene_id() -> StringName:
	return overlay_scene_id

func _create_background_panel() -> void:
	_background_panel = ColorRect.new()
	_background_panel.name = "OverlayBackground"
	_configure_new_background(_background_panel)

	# Add as first child (bottom of z-order)
	add_child(_background_panel)
	move_child(_background_panel, 0)

func _configure_new_background(panel: ColorRect) -> void:
	"""Configure a newly created background panel with all properties."""
	panel.color = background_color
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_fullscreen_anchors(panel)

func _configure_existing_background(panel: ColorRect) -> void:
	"""Configure an existing background panel - preserve color, ensure input blocking."""
	# Preserve existing color customization
	# Only ensure critical properties for overlay stacking
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_fullscreen_anchors(panel)

func _ensure_fullscreen_anchors(panel: ColorRect) -> void:
	"""Ensure panel covers full viewport."""
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
