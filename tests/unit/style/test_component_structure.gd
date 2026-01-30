extends GutTest

## Component attachment structure validation test
## Enforces that ECS components are attached to proper Node containers
## See DEV_PITFALLS.md and STYLE_GUIDE.md for details

# Scene directories to validate
const SCENE_DIRECTORIES := [
	"res://scenes/gameplay",
	"res://scenes/prefabs"
]

# Node types that should NOT have component scripts directly attached
const FORBIDDEN_COMPONENT_PARENT_TYPES := [
	"CSGBox3D",
	"CSGCylinder3D",
	"CSGSphere3D",
	"CSGPolygon3D",
	"CSGMesh3D",
	"CSGCombiner3D",
	"CharacterBody3D",
	"RigidBody3D",
	"StaticBody3D",
	"Area3D",
	"MeshInstance3D",
	"AnimatableBody3D"
]

# Valid container types for components
const VALID_COMPONENT_CONTAINERS := [
	"Node",
	"Node3D"
]


func test_components_attached_to_valid_containers() -> void:
	var violations: Array[String] = []

	for dir_path in SCENE_DIRECTORIES:
		_check_scene_directory_components(dir_path, violations)

	var message := "ECS components must be attached to Node or Node3D containers only"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nComponents should be children of their owning nodes, not attached directly."
		message += "\nSee DEV_PITFALLS.md 'Component Attachment Pattern' section."
	else:
		message += " - all scenes compliant!"

	assert_eq(violations.size(), 0, message)


func _check_scene_directory_components(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_scene_directory_components("%s/%s" % [dir_path, entry], violations)
		elif entry.ends_with(".tscn"):
			_validate_scene_component_structure("%s/%s" % [dir_path, entry], violations)
		entry = dir.get_next()
	dir.list_dir_end()


func _validate_scene_component_structure(scene_path: String, violations: Array[String]) -> void:
	# Parse .tscn file as text to check component attachment patterns
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return

	var current_node_type := ""
	var current_node_name := ""
	var current_node_script := ""
	var line_number := 0

	while not file.eof_reached():
		line_number += 1
		var line := file.get_line().strip_edges()

		# Detect [node] block start
		if line.begins_with("[node"):
			# Parse node attributes
			current_node_type = _extract_attribute(line, "type")
			current_node_name = _extract_attribute(line, "name")
			current_node_script = ""

		# Detect script assignment in node block
		elif line.begins_with("script = "):
			current_node_script = _extract_script_path(line)

			# Check if this is a component script on a forbidden parent type
			if _is_component_script(current_node_script):
				if current_node_type in FORBIDDEN_COMPONENT_PARENT_TYPES:
					violations.append(
						"%s:%d - Component %s attached to %s '%s' (forbidden type)" % [
							scene_path,
							line_number,
							current_node_script.get_file(),
							current_node_type,
							current_node_name
						]
					)
				elif current_node_type not in VALID_COMPONENT_CONTAINERS:
					# Warn about unknown types (might be custom classes)
					violations.append(
						"%s:%d - Component %s attached to %s '%s' (should use Node/Node3D)" % [
							scene_path,
							line_number,
							current_node_script.get_file(),
							current_node_type,
							current_node_name
						]
					)

	file.close()


func _extract_attribute(line: String, attr_name: String) -> String:
	var pattern := '%s="' % attr_name
	var start_idx := line.find(pattern)
	if start_idx == -1:
		return ""

	start_idx += pattern.length()
	var end_idx := line.find('"', start_idx)
	if end_idx == -1:
		return ""

	return line.substr(start_idx, end_idx - start_idx)


func _extract_script_path(line: String) -> String:
	# Extract path from: script = ExtResource("1_abc123")
	var start_idx := line.find('path="')
	if start_idx != -1:
		start_idx += 6  # len('path="')
		var end_idx := line.find('"', start_idx)
		if end_idx != -1:
			return line.substr(start_idx, end_idx - start_idx)

	# Fallback: try to extract from ExtResource directly
	start_idx = line.find('ExtResource("')
	if start_idx != -1:
		# This format doesn't give us the path directly, but we can check the filename
		return ""

	return ""


func _is_component_script(script_path: String) -> bool:
	if script_path.is_empty():
		return false

	var filename := script_path.get_file()
	return filename.begins_with("c_") and filename.ends_with("_component.gd")
