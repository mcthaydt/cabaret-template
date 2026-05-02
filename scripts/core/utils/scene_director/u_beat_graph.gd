extends RefCounted
class_name U_BeatGraph

const WHITE: int = 0
const GRAY: int = 1
const BLACK: int = 2

static func validate(beats: Array[Resource]) -> Dictionary:
	var errors: Array[String] = []
	var id_to_index: Dictionary = {}

	for index in range(beats.size()):
		var beat: Resource = beats[index]
		var beat_id: StringName = _read_beat_id(beat)
		if beat_id == StringName(""):
			errors.append("beats[%d].beat_id must be non-empty" % index)
			continue
		if id_to_index.has(beat_id):
			errors.append("duplicate beat_id '%s'" % String(beat_id))
			continue
		id_to_index[beat_id] = index

	for index in range(beats.size()):
		var beat: Resource = beats[index]
		if beat == null:
			continue
		var beat_id: StringName = _read_beat_id(beat)
		if beat_id == StringName(""):
			continue

		var next_id: StringName = _to_string_name(_resource_get(beat, "next_beat_id", StringName("")))
		var failure_id: StringName = _to_string_name(
			_resource_get(beat, "next_beat_id_on_failure", StringName(""))
		)
		var lane_ids: Array[StringName] = _to_string_name_array(
			_resource_get(beat, "parallel_beat_ids", [])
		)
		var join_id: StringName = _to_string_name(
			_resource_get(beat, "parallel_join_beat_id", StringName(""))
		)

		_validate_target_ref(id_to_index, next_id, "next_beat_id", beat_id, errors)
		_validate_target_ref(id_to_index, failure_id, "next_beat_id_on_failure", beat_id, errors)

		if lane_ids.is_empty() and join_id != StringName(""):
			errors.append(
				"beat '%s' sets parallel_join_beat_id but has no parallel_beat_ids"
				% String(beat_id)
			)
		elif not lane_ids.is_empty() and join_id == StringName(""):
			errors.append(
				"beat '%s' sets parallel_beat_ids but missing parallel_join_beat_id"
				% String(beat_id)
			)

		_validate_target_ref(id_to_index, join_id, "parallel_join_beat_id", beat_id, errors)
		for lane_id in lane_ids:
			_validate_target_ref(id_to_index, lane_id, "parallel_beat_ids", beat_id, errors)
			if lane_id == StringName(""):
				continue
			var lane_beat: Resource = _resource_by_id(beats, id_to_index, lane_id)
			var lane_parallel: Array[StringName] = _to_string_name_array(
				_resource_get(lane_beat, "parallel_beat_ids", [])
			)
			if not lane_parallel.is_empty():
				errors.append(
					"lane beat '%s' cannot define parallel_beat_ids (single-hop lanes only)"
					% String(lane_id)
				)

	var adjacency: Dictionary = _build_adjacency(beats, id_to_index)
	errors.append_array(_detect_cycles(adjacency))

	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}

static func build_id_to_index_map(beats: Array[Resource]) -> Dictionary:
	var map: Dictionary = {}
	for index in range(beats.size()):
		var beat: Resource = beats[index]
		var beat_id: StringName = _read_beat_id(beat)
		if beat_id == StringName(""):
			continue
		if map.has(beat_id):
			continue
		map[beat_id] = index
	return map

static func _build_adjacency(beats: Array[Resource], id_to_index: Dictionary) -> Dictionary:
	var adjacency: Dictionary = {}
	for beat_id_variant in id_to_index.keys():
		var beat_id: StringName = _to_string_name(beat_id_variant)
		if beat_id == StringName(""):
			continue
		adjacency[beat_id] = []

	for beat_id_variant in id_to_index.keys():
		var beat_id: StringName = _to_string_name(beat_id_variant)
		if beat_id == StringName(""):
			continue

		var beat: Resource = _resource_by_id(beats, id_to_index, beat_id)
		var next_id: StringName = _to_string_name(_resource_get(beat, "next_beat_id", StringName("")))
		var failure_id: StringName = _to_string_name(
			_resource_get(beat, "next_beat_id_on_failure", StringName(""))
		)
		var join_id: StringName = _to_string_name(
			_resource_get(beat, "parallel_join_beat_id", StringName(""))
		)
		var lane_ids: Array[StringName] = _to_string_name_array(
			_resource_get(beat, "parallel_beat_ids", [])
		)

		var edges: Array[StringName] = []
		_append_edge(edges, next_id)
		_append_edge(edges, failure_id)
		_append_edge(edges, join_id)
		for lane_id in lane_ids:
			_append_edge(edges, lane_id)

		adjacency[beat_id] = edges

	return adjacency

static func _detect_cycles(adjacency: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var states: Dictionary = {}
	var stack: Array[StringName] = []

	for node_variant in adjacency.keys():
		var node: StringName = _to_string_name(node_variant)
		if node == StringName(""):
			continue
		states[node] = WHITE

	for node_variant in adjacency.keys():
		var node: StringName = _to_string_name(node_variant)
		if node == StringName(""):
			continue
		if int(states.get(node, WHITE)) != WHITE:
			continue
		_dfs_cycle(node, adjacency, states, stack, errors)

	return errors

static func _dfs_cycle(
	node: StringName,
	adjacency: Dictionary,
	states: Dictionary,
	stack: Array[StringName],
	errors: Array[String]
) -> void:
	states[node] = GRAY
	stack.append(node)

	var neighbors: Array[StringName] = _to_string_name_array(adjacency.get(node, []))
	for neighbor in neighbors:
		if not adjacency.has(neighbor):
			continue
		var state: int = int(states.get(neighbor, WHITE))
		if state == WHITE:
			_dfs_cycle(neighbor, adjacency, states, stack, errors)
			continue
		if state == GRAY:
			var cycle_text: String = _build_cycle_text(stack, neighbor)
			if cycle_text != "" and not errors.has(cycle_text):
				errors.append(cycle_text)

	stack.pop_back()
	states[node] = BLACK

static func _build_cycle_text(stack: Array[StringName], repeated: StringName) -> String:
	var start_index: int = stack.find(repeated)
	if start_index < 0:
		return ""

	var tokens: PackedStringArray = PackedStringArray()
	for index in range(start_index, stack.size()):
		tokens.append(String(stack[index]))
	tokens.append(String(repeated))
	return "cycle detected: %s" % " -> ".join(tokens)

static func _append_edge(edges: Array[StringName], candidate: StringName) -> void:
	if candidate == StringName(""):
		return
	if edges.has(candidate):
		return
	edges.append(candidate)

static func _validate_target_ref(
	id_to_index: Dictionary,
	target_id: StringName,
	field_name: String,
	beat_id: StringName,
	errors: Array[String]
) -> void:
	if target_id == StringName(""):
		return
	if id_to_index.has(target_id):
		return
	errors.append(
		"beat '%s' has unknown %s '%s'" % [String(beat_id), field_name, String(target_id)]
	)

static func _resource_by_id(beats: Array[Resource], id_to_index: Dictionary, beat_id: StringName) -> Resource:
	if beat_id == StringName(""):
		return null
	if not id_to_index.has(beat_id):
		return null

	var index_variant: Variant = id_to_index.get(beat_id, -1)
	if not (index_variant is int):
		return null
	var index: int = index_variant
	if index < 0 or index >= beats.size():
		return null
	return beats[index] as Resource

static func _read_beat_id(beat: Resource) -> StringName:
	return _to_string_name(_resource_get(beat, "beat_id", StringName("")))

static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return value if value != null else fallback

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

static func _to_string_name_array(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if value is Array:
		for entry in value:
			var name: StringName = _to_string_name(entry)
			if name == StringName(""):
				continue
			names.append(name)
	elif value is PackedStringArray:
		for entry in value:
			var name: StringName = _to_string_name(entry)
			if name == StringName(""):
				continue
			names.append(name)
	return names
