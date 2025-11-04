extends BaseSpawnEffect
class_name SpawnParticleEffect

## Spawn Particle Effect (Phase 12.4 - T272)
##
## Instantiates a particle effect at spawn point with auto-cleanup.
## Uses GPUParticles3D for spawn visual feedback.

## Path to particle scene (can be overridden)
var particle_scene_path: String = ""

func _init() -> void:
	duration = 1.0  # Particle lifetime

## Execute particle effect at target position
##
## Creates a GPUParticles3D burst at the target's global position.
## Particles auto-cleanup after duration.
func execute(target: Node, completion_callback: Callable) -> void:
	if target == null:
		if completion_callback.is_valid():
			completion_callback.call()
		return

	# Create simple particle effect
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = duration
	particles.global_position = target.global_position

	# Add to target so it inherits scene tree
	target.add_child(particles)

	# Start emission
	particles.emitting = true

	# Schedule cleanup
	await target.get_tree().create_timer(duration).timeout

	particles.queue_free()

	if completion_callback.is_valid():
		completion_callback.call()
