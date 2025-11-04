extends BaseSpawnEffect
class_name SpawnFadeEffect

## Spawn Fade Effect (Phase 12.4 - T271)
##
## Fades player from transparent to opaque when spawning.
## Looks for MeshInstance3D children and tweens their modulate alpha.

func _init() -> void:
	duration = 0.3

## Execute fade effect on player
##
## Finds all MeshInstance3D children and fades them from alpha 0 → 1.
func execute(target: Node, completion_callback: Callable) -> void:
	if target == null:
		if completion_callback.is_valid():
			completion_callback.call()
		return

	# Find all MeshInstance3D children
	var meshes: Array[MeshInstance3D] = []
	_find_meshes_recursive(target, meshes)

	if meshes.is_empty():
		# No meshes to fade, just complete immediately
		if completion_callback.is_valid():
			completion_callback.call()
		return

	# Set all meshes to transparent
	for mesh in meshes:
		mesh.modulate = Color(1, 1, 1, 0)

	# Create tween to fade in
	var tween := target.create_tween()
	tween.set_parallel(true)

	for mesh in meshes:
		tween.tween_property(mesh, "modulate:a", 1.0, duration)

	# Call completion callback when tween finishes
	tween.finished.connect(func() -> void:
		if completion_callback.is_valid():
			completion_callback.call()
	)

## Recursively find all MeshInstance3D nodes
func _find_meshes_recursive(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)

	for child in node.get_children():
		_find_meshes_recursive(child, result)
