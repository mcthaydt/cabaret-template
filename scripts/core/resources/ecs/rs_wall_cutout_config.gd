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
@export var disc_radius: float = 0.12

## Soft-edge width as a fraction of viewport height. Larger values make the
## edge of the cutout fade more gradually.
@export var disc_falloff: float = 0.05

@export_group("Alpha")
## Alpha at the center of the disc. 0.0 = fully transparent (you see straight
## through). 0.1-0.2 leaves a faint silhouette of the wall.
@export var disc_min_alpha: float = 0.0
