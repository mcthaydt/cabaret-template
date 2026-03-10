@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamModeOrbit

@export_range(0.01, 1000.0, 0.01) var distance: float = 5.0
@export_range(-90.0, 90.0, 0.01) var authored_pitch: float = -20.0
@export_range(-360.0, 360.0, 0.01) var authored_yaw: float = 0.0
@export var allow_player_rotation: bool = true
@export_range(0.0, 20.0, 0.01) var rotation_speed: float = 2.0
@export_range(1.0, 179.0, 0.01) var fov: float = 75.0
