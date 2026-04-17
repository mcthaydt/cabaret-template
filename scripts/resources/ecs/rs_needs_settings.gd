@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_NeedsSettings

@export_range(0.0, 1.0, 0.01) var initial_hunger: float = 1.0
@export_range(0.0, 10.0, 0.01, "or_greater") var decay_per_second: float = 0.05
@export_range(0.0, 1.0, 0.01) var sated_threshold: float = 0.7
@export_range(0.0, 1.0, 0.01) var starving_threshold: float = 0.25
@export_range(0.0, 1.0, 0.01) var gain_on_feed: float = 0.35
