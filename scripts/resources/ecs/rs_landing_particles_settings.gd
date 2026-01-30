@icon("res://assets/editor_icons/icn_utility.svg")
extends Resource
class_name RS_LandingParticlesSettings

## Settings for landing particle effects

@export_group("General")
## Enable or disable particle spawning
@export var enabled: bool = true

@export_group("Particle Properties")
## Particle material (placeholder for now, can be assigned in inspector)
@export var particle_material: Material = null
## Number of particles to emit per landing
@export var emission_count: int = 15
## How long particles stay alive (seconds)
@export var particle_lifetime: float = 0.6
## Scale of individual particles
@export var particle_scale: float = 0.12

@export_group("Emission")
## Spread angle for particle emission (degrees)
@export_range(0.0, 180.0) var spread_angle: float = 60.0
## Initial velocity of particles
@export var initial_velocity: float = 2.5
## Offset from landing position where particles spawn (Vector3.DOWN spawns at feet)
@export var spawn_offset: Vector3 = Vector3.DOWN
