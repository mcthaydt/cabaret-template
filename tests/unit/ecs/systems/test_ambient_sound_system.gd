extends GutTest

const AMBIENT_SOUND_SYSTEM_SCRIPT := preload("res://scripts/ecs/systems/s_ambient_sound_system.gd")
const AMBIENT_SOUND_SETTINGS_SCRIPT := preload("res://scripts/resources/ecs/rs_ambient_sound_settings.gd")
const MOCK_STATE_STORE_SCRIPT := preload("res://tests/mocks/mock_state_store.gd")

var system
var settings
var mock_store

func before_each() -> void:
	# Ensure Ambient bus exists
	_ensure_ambient_bus_exists()

	# Create settings
	settings = AMBIENT_SOUND_SETTINGS_SCRIPT.new()
	settings.enabled = true

	# Create mock state store
	mock_store = MOCK_STATE_STORE_SCRIPT.new()
	autofree(mock_store)  # Register with GUT for automatic cleanup

	# Register mock store with ServiceLocator
	const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")
	U_ServiceLocator.register(StringName("state_store"), mock_store)

	# Create system
	system = AMBIENT_SOUND_SYSTEM_SCRIPT.new()
	system.settings = settings
	add_child(system)
	await get_tree().process_frame

func after_each() -> void:
	# Clean up system and its children (AudioStreamPlayer nodes)
	if system and is_instance_valid(system):
		# Stop all audio and free children before freeing system
		for child in system.get_children():
			if child is AudioStreamPlayer:
				child.stop()
			child.queue_free()
		system.queue_free()
		await get_tree().process_frame  # Wait for queue_free to execute

	system = null
	mock_store = null
	settings = null

	# Clear ServiceLocator to prevent "already registered" warnings
	const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")
	U_ServiceLocator.clear()

	_reset_audio_buses()

func _ensure_ambient_bus_exists() -> void:
	if AudioServer.get_bus_index("Ambient") != -1:
		return
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Ambient")
	AudioServer.set_bus_send(1, "Master")

func _reset_audio_buses() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

# Test 1: System extends BaseECSSystem
func test_extends_base_ecs_system() -> void:
	var base_class: Script = system.get_script().get_base_script()
	assert_eq(base_class.resource_path, "res://scripts/ecs/base_ecs_system.gd",
		"S_AmbientSoundSystem should extend BaseECSSystem")

# Test 2: Dual-player initialization
func test_dual_player_initialization() -> void:
	var player_a := system.get_node_or_null("AmbientPlayerA") as AudioStreamPlayer
	var player_b := system.get_node_or_null("AmbientPlayerB") as AudioStreamPlayer

	assert_not_null(player_a, "AmbientPlayerA should be created")
	assert_not_null(player_b, "AmbientPlayerB should be created")
	assert_eq(player_a.bus, "Ambient", "Player A should be on Ambient bus")
	assert_eq(player_b.bus, "Ambient", "Player B should be on Ambient bus")

# Test 3: Ambient registry exists
func test_ambient_registry_exists() -> void:
	# Access private registry via reflection (for testing)
	var registry: Dictionary = system.get("_AMBIENT_REGISTRY")
	assert_not_null(registry, "Ambient registry should exist")
	assert_true(registry.has(StringName("exterior")), "Registry should have exterior ambient")
	assert_true(registry.has(StringName("interior")), "Registry should have interior ambient")

# Test 4: Scene-based ambient selection (exterior)
func test_scene_based_ambient_selection_exterior() -> void:
	# Simulate scene transition to gameplay_base (should trigger exterior ambient)
	var action := {
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("gameplay_base")}
	}
	system._on_state_changed(action, {})
	await get_tree().process_frame

	var current_id: StringName = system.get("_current_ambient_id")
	assert_eq(current_id, StringName("exterior"), "Should play exterior ambient for gameplay_base")

# Test 5: Scene-based ambient selection (interior)
func test_scene_based_ambient_selection_interior() -> void:
	# Simulate scene transition to interior_test (should trigger interior ambient)
	var action := {
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("interior_test")}
	}
	system._on_state_changed(action, {})
	await get_tree().process_frame

	var current_id: StringName = system.get("_current_ambient_id")
	assert_eq(current_id, StringName("interior"), "Should play interior ambient for interior_test")

# Test 6: Crossfade between ambients
func test_crossfade_between_ambients() -> void:
	# Start with exterior
	system._play_ambient(StringName("exterior"), 0.05)
	await get_tree().process_frame

	var player_before := system.get("_active_ambient_player") as AudioStreamPlayer
	assert_true(player_before.playing, "First ambient should be playing")

	# Crossfade to interior (very short duration for test speed)
	system._play_ambient(StringName("interior"), 0.05)
	await get_tree().create_timer(0.1).timeout

	var player_after := system.get("_active_ambient_player") as AudioStreamPlayer
	assert_true(player_after.playing, "Second ambient should be playing")
	assert_ne(player_before, player_after, "Active player should have swapped")

# Test 7: Loop verification
func test_loop_verification() -> void:
	# Play exterior ambient
	system._play_ambient(StringName("exterior"), 0.05)
	await get_tree().process_frame

	var active_player := system.get("_active_ambient_player") as AudioStreamPlayer
	assert_not_null(active_player.stream, "Player should have stream")

	# Check if stream is AudioStreamWAV with loop enabled
	if active_player.stream is AudioStreamWAV:
		var wav_stream := active_player.stream as AudioStreamWAV
		assert_ne(wav_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED,
			"Ambient stream should have looping enabled")

# Test 8: Volume independent of music bus
func test_volume_independent_of_music() -> void:
	# Play ambient
	system._play_ambient(StringName("exterior"), 0.05)
	await get_tree().process_frame

	var active_player := system.get("_active_ambient_player") as AudioStreamPlayer
	assert_eq(active_player.bus, "Ambient", "Ambient should be on Ambient bus, not Music bus")

# Test 9: Stop ambient when no scene match
func test_stop_ambient_when_no_scene_match() -> void:
	# Start with exterior
	system._play_ambient(StringName("exterior"), 0.05)
	await get_tree().process_frame
	assert_ne(system.get("_current_ambient_id"), StringName(""), "Should have current ambient")

	# Transition to scene with no ambient
	var action := {
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("unknown_scene")}
	}
	system._on_state_changed(action, {})
	await get_tree().create_timer(0.1).timeout

	assert_eq(system.get("_current_ambient_id"), StringName(""), "Should have no current ambient")

# Test 10: Disabled setting prevents playback
func test_disabled_setting_prevents_playback() -> void:
	settings.enabled = false
	await get_tree().process_frame

	# Try to play ambient with disabled setting
	var action := {
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("gameplay_base")}
	}
	system._on_state_changed(action, {})
	await get_tree().process_frame

	var current_id: StringName = system.get("_current_ambient_id")
	assert_eq(current_id, StringName(""), "Should not play ambient when disabled")
