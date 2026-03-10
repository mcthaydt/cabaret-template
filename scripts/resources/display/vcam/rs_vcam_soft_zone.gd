@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamSoftZone

@export_range(0.0, 1.0, 0.01) var dead_zone_width: float = 0.1
@export_range(0.0, 1.0, 0.01) var dead_zone_height: float = 0.1
@export_range(0.0, 1.0, 0.01) var soft_zone_width: float = 0.4
@export_range(0.0, 1.0, 0.01) var soft_zone_height: float = 0.4
@export_range(0.0, 20.0, 0.01) var damping: float = 2.0

