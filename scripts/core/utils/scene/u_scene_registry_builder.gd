extends RefCounted
class_name U_SceneRegistryBuilder

var _entries: Dictionary = {}
var _last_id: StringName = StringName("")

func register(scene_id: StringName, path: String) -> U_SceneRegistryBuilder:
	_last_id = scene_id
	_entries[scene_id] = {
		"scene_id": scene_id,
		"path": path,
		"scene_type": 1,
		"default_transition": "fade",
		"preload_priority": 0
	}
	return self

func with_type(scene_type: int) -> U_SceneRegistryBuilder:
	if _entries.has(_last_id):
		_entries[_last_id]["scene_type"] = scene_type
	return self

func with_transition(transition: String) -> U_SceneRegistryBuilder:
	if _entries.has(_last_id):
		_entries[_last_id]["default_transition"] = transition
	return self

func with_preload(priority: int) -> U_SceneRegistryBuilder:
	if _entries.has(_last_id):
		_entries[_last_id]["preload_priority"] = priority
	return self

func build() -> Dictionary:
	return _entries.duplicate(true)
