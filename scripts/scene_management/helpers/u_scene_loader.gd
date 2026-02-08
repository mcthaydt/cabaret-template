extends RefCounted
class_name U_SceneLoader

## Scene loading helper for M_SceneManager (Phase 9A - T090b).
##
## Responsibilities:
## - Synchronous scene loading via ResourceLoader
## - Async threaded loading with progress callback
## - Adding/removing scenes from ActiveSceneContainer
## - Scene contract validation
## - Player lookup and physics unfreeze after transitions

const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")

## Load scene via ResourceLoader (sync)
func load_scene(scene_path: String) -> Node:
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("U_SceneLoader: Failed to load PackedScene at '%s'" % scene_path)
		return null

	var instance: Node = packed_scene.instantiate()
	return instance

## Load scene asynchronously with progress callback.
##
## Parameters:
##   scene_path: Resource path to .tscn file
##   progress_callback: Callable(progress: float) called with 0.0-1.0 progress
##   background_loads: Dictionary tracking threaded loads (shared with manager)
##
## Returns: Instantiated Node or null on failure
func load_scene_async(scene_path: String, progress_callback: Callable, background_loads: Dictionary) -> Node:
	var main_loop := Engine.get_main_loop()
	var tree := main_loop as SceneTree

	# Fallback to sync loading in headless mode (async may not work)
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if progress_callback.is_valid():
			progress_callback.call(1.0)  # Fake instant completion
		if packed_scene:
			return packed_scene.instantiate()
		return null

	# Attach to existing background load if present
	if background_loads.has(scene_path):
		while true:
			var progress: Array = [0.0]
			var status: int = ResourceLoader.load_threaded_get_status(scene_path, progress)

			if progress_callback.is_valid():
				progress_callback.call(progress[0])

			if status == ResourceLoader.THREAD_LOAD_LOADED:
				break
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				push_error("U_SceneLoader: Async load failed for '%s'" % scene_path)
				return null
			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("U_SceneLoader: Invalid resource path '%s'" % scene_path)
				return null

			if tree != null:
				await tree.process_frame
			else:
				await Engine.get_main_loop().process_frame

		background_loads.erase(scene_path)

		var packed_scene_existing: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
		if packed_scene_existing:
			return packed_scene_existing.instantiate()
		return null

	# Start new async load
	var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		push_error("U_SceneLoader: Failed to start async load for '%s' (error %d)" % [scene_path, err])
		return null

	var progress_array: Array = [0.0]
	var timeout_time: float = Time.get_ticks_msec() / 1000.0 + 30.0  # 30s timeout
	while true:
		var current_time: float = Time.get_ticks_msec() / 1000.0
		if current_time > timeout_time:
			push_error("U_SceneLoader: Async load timeout for '%s'" % scene_path)
			return null

		var status: int = ResourceLoader.load_threaded_get_status(scene_path, progress_array)

		if progress_callback.is_valid():
			progress_callback.call(progress_array[0])

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("U_SceneLoader: Async load failed for '%s'" % scene_path)
			return null
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("U_SceneLoader: Invalid resource path '%s'" % scene_path)
			return null

		if tree != null:
			await tree.process_frame
		else:
			await Engine.get_main_loop().process_frame

	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene == null:
		push_error("U_SceneLoader: Failed to get loaded PackedScene for '%s'" % scene_path)
		return null

	return packed_scene.instantiate()

## Add scene to ActiveSceneContainer
func add_scene(active_scene_container: Node, scene: Node) -> void:
	if active_scene_container == null or scene == null:
		return

	active_scene_container.add_child(scene)

## Remove all children from ActiveSceneContainer
func remove_current_scene(active_scene_container: Node) -> void:
	if active_scene_container == null:
		return

	for child in active_scene_container.get_children():
		active_scene_container.remove_child(child)
		child.queue_free()

## Validate scene contract based on registry SceneType.
##
## Logs warnings but does not block loading (fail-safe design).
func validate_scene_contract(scene: Node, scene_id: StringName) -> void:
	if scene == null:
		return

	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(scene_id)
	if scene_path.begins_with("res://tests/"):
		return

	var registry_type: int = U_SCENE_REGISTRY.get_scene_type(scene_id)

	var contract_type: I_SCENE_CONTRACT.SceneType
	match registry_type:
		U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			contract_type = I_SCENE_CONTRACT.SceneType.GAMEPLAY
		U_SCENE_REGISTRY.SceneType.UI, U_SCENE_REGISTRY.SceneType.MENU, U_SCENE_REGISTRY.SceneType.END_GAME:
			contract_type = I_SCENE_CONTRACT.SceneType.UI
		_:
			return

	var validator := I_SCENE_CONTRACT.new()
	var result: Dictionary = validator.validate_scene(scene, contract_type)

	if not result.get("valid", true):
		push_warning("Scene '%s' failed contract validation:" % scene_id)
		var errors: Array = result.get("errors", [])
		for error in errors:
			push_warning("  - %s" % error)

	var warnings: Array = result.get("warnings", [])
	for warning in warnings:
		push_warning("Scene '%s' validation warning: %s" % [scene_id, warning])

## Re-enable player physics after transition completes
func unfreeze_player_physics(scene: Node) -> bool:
	if scene == null:
		return false

	var player: Node3D = find_player_in_scene(scene)
	if player == null:
		return false

	var player_body: CharacterBody3D = player as CharacterBody3D
	if player_body == null:
		player_body = _find_character_body_in(player)

	var spawn_state: C_SpawnStateComponent = _find_spawn_state_component(player)
	if player_body == null and spawn_state != null:
		player_body = spawn_state.get_character_body()

	if spawn_state == null or not spawn_state.is_physics_frozen:
		return false

	if player_body != null:
		player_body.set_physics_process(true)
	if spawn_state != null:
		spawn_state.clear_spawn_state()

	return player_body != null

## Find player in scene tree
func find_player_in_scene(scene: Node) -> Node3D:
	if scene == null:
		return null

	if scene.name.begins_with("E_Player"):
		return scene as Node3D

	for child in scene.get_children():
		var found_player: Node3D = find_player_in_scene(child)
		if found_player != null:
			return found_player

	return null

func _find_character_body_in(node: Node) -> CharacterBody3D:
	if node == null:
		return null
	var body := node as CharacterBody3D
	if body != null:
		return body

	for child in node.get_children():
		var found: CharacterBody3D = _find_character_body_in(child)
		if found != null:
			return found
	return null

func _find_spawn_state_component(node: Node) -> C_SpawnStateComponent:
	if node == null:
		return null

	if node is C_SpawnStateComponent:
		return node as C_SpawnStateComponent

	for child in node.get_children():
		var found: C_SpawnStateComponent = _find_spawn_state_component(child)
		if found != null:
			return found

	return null
