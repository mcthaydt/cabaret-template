class_name I_SCENE_CONTRACT
extends RefCounted

## Scene Contract Validator (Phase 12.5 - T303)
##
## Validates that scenes meet required contracts before gameplay starts.
## Catches configuration errors at load time rather than runtime.
##
## Validation Rules:
## - GAMEPLAY scenes require: player entity, camera, sp_default spawn point
## - UI scenes forbid: player entities, spawn points
##
## Returns:
##   Dictionary with structure:
##     { valid: bool, errors: Array[String], warnings: Array[String] }

## Scene type enumeration
enum SceneType {
	GAMEPLAY,  ## 3D gameplay scenes (require player, camera, spawns)
	UI,        ## 2D UI scenes (no player/spawns allowed)
}

## Validate a scene meets its contract requirements (T304)
##
## Checks that the scene has all required nodes and no forbidden nodes
## based on its SceneType. Collects ALL errors before returning.
##
## Parameters:
##   scene: Root node of the scene to validate
##   scene_type: Type of scene (GAMEPLAY or UI)
##
## Returns:
##   Dictionary with structure:
##     {
##       valid: bool,           # True if all validations pass
##       errors: Array[String], # List of error messages
##       warnings: Array[String] # List of warning messages (future use)
##     }
func validate_scene(scene: Node, scene_type: SceneType) -> Dictionary:
	var result: Dictionary = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Validate scene is not null
	if scene == null:
		result.errors.append("Scene is null - cannot validate")
		result.valid = false
		return result

	# Validate based on scene type
	match scene_type:
		SceneType.GAMEPLAY:
			_validate_gameplay_scene(scene, result)
		SceneType.UI:
			_validate_ui_scene(scene, result)
		_:
			result.errors.append("Unknown scene type: %s" % scene_type)
			result.valid = false

	# Set overall validity based on errors
	result.valid = result.errors.is_empty()

	return result

## Validate gameplay scene contract (T305)
##
## Gameplay scenes MUST have:
## - Player entity (node name starting with "E_Player")
## - Camera in "main_camera" group
## - sp_default spawn point
func _validate_gameplay_scene(scene: Node, result: Dictionary) -> void:
	# Check for player entity
	var player: Node = _find_node_by_prefix(scene, "E_Player")
	if player == null:
		result.errors.append("Gameplay scene missing player entity (expected node name starting with 'E_Player')")

	# Check for camera in main_camera group (search within scene, not tree)
	var camera: Node = _find_node_in_group(scene, "main_camera")
	if camera == null:
		result.errors.append("Gameplay scene missing camera (expected camera in 'main_camera' group)")

	# Check for sp_default spawn point
	var sp_default: Node = _find_node_by_name(scene, "sp_default")
	if sp_default == null:
		result.errors.append("Gameplay scene missing sp_default spawn point (required for respawning)")

## Validate UI scene contract (T305)
##
## UI scenes MUST NOT have:
## - Player entities (no nodes starting with "E_Player")
## - Spawn points (no nodes starting with "sp_")
func _validate_ui_scene(scene: Node, result: Dictionary) -> void:
	# Check that no player entity exists
	var player: Node = _find_node_by_prefix(scene, "E_Player")
	if player != null:
		result.errors.append("UI scene should not contain player entity (found: %s)" % player.name)

	# Check that no spawn points exist
	var spawn_point: Node = _find_node_by_prefix(scene, "sp_")
	if spawn_point != null:
		result.errors.append("UI scene should not contain spawn points (found: %s)" % spawn_point.name)

## Find first node with name starting with prefix
##
## Recursively searches scene tree for node matching prefix.
##
## Parameters:
##   node: Current node to check
##   prefix: Name prefix to search for
##
## Returns:
##   First matching Node, or null if not found
func _find_node_by_prefix(node: Node, prefix: String) -> Node:
	if node.name.begins_with(prefix):
		return node

	for child in node.get_children():
		var found: Node = _find_node_by_prefix(child, prefix)
		if found != null:
			return found

	return null

## Find first node with exact name
##
## Recursively searches scene tree for node with matching name.
##
## Parameters:
##   node: Current node to check
##   target_name: Name to search for
##
## Returns:
##   First matching Node, or null if not found
func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node

	for child in node.get_children():
		var found: Node = _find_node_by_name(child, target_name)
		if found != null:
			return found

	return null

## Find first node in group
##
## Recursively searches scene tree for node in specified group.
##
## Parameters:
##   node: Current node to check
##   group_name: Group to search for
##
## Returns:
##   First matching Node, or null if not found
func _find_node_in_group(node: Node, group_name: String) -> Node:
	if node.is_in_group(group_name):
		return node

	for child in node.get_children():
		var found: Node = _find_node_in_group(child, group_name)
		if found != null:
			return found

	return null
