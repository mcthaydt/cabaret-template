@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_WallCutoutConfig

## Tuning for the screen-space wall cutout.
##
## A circular cutout is drawn around the player's screen position. Walls that
## are between the camera and the player (occluding the player) fade inside
## that circle. Sizes are normalized to viewport height so the visual is
## resolution-independent.

@export_group("Disc Shape")
## Radius of the cutout disc as a fraction of viewport height (0..1).
@export var disc_radius: float = 0.5

## Maximum radius after runtime projected-player scaling.
@export var disc_max_radius: float = 0.55

## Soft-edge width as a fraction of viewport height. Larger values make the
## edge of the cutout fade more gradually.
@export var disc_falloff: float = 0.05

## Vertical offset from the player root to the intended visual cutout center.
@export var disc_center_height_offset: float = 0.5

## Approximate player visual height used for projected screen-space scaling.
@export var disc_player_height_meters: float = 1.0

## Desired disc diameter as a multiple of projected player height.
@export var disc_target_height_coverage: float = 2.2

## XZ footprint margin for treating a wall as intersecting camera-to-player line of sight.
@export var occlusion_segment_margin: float = 0.05

@export_group("Alpha")
## Alpha at the center of the disc. 0.0 = fully transparent (you see straight
## through). 0.1-0.2 leaves a faint silhouette of the wall.
@export var disc_min_alpha: float = 0.18
