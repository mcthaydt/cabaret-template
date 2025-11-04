extends GutTest

## Integration test: spawn_at_last_spawn falls back from missing checkpoint to sp_default and clears target_spawn_point

const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

var _spawn: M_SpawnManager
var _store: M_StateStore
var _scene: Node3D

func before_each() -> void:
    _store = M_StateStore.new()
    _store.gameplay_initial_state = RS_GAMEPLAY_INITIAL.new()
    add_child_autofree(_store)
    await get_tree().process_frame

    _spawn = M_SPAWN_MANAGER.new()
    add_child_autofree(_spawn)
    await get_tree().process_frame

    _scene = Node3D.new()
    _scene.name = "TestScene"
    add_child_autofree(_scene)

    # Player and sp_default only (no checkpoint spawn exists)
    var player := Node3D.new()
    player.name = "E_Player"
    _scene.add_child(player)

    var sp_default := Node3D.new()
    sp_default.name = "sp_default"
    sp_default.position = Vector3(10, 0, 0)
    _scene.add_child(sp_default)

func after_each() -> void:
    _spawn = null
    _store = null
    _scene = null

func test_fallback_from_missing_checkpoint_clears_target_and_spawns_at_default() -> void:
    # Set last_checkpoint to a missing marker; target_spawn_point empty
    _store.dispatch(U_GAMEPLAY_ACTIONS.set_last_checkpoint(StringName("sp_missing_checkpoint")))
    _store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("")))
    await get_tree().physics_frame

    var ok := _spawn.spawn_at_last_spawn(_scene)
    await get_tree().physics_frame

    # Expect an error for missing checkpoint, then fallback succeeds
    assert_push_error("M_SpawnManager: Spawn point 'sp_missing_checkpoint' not found")
    assert_true(ok, "Should fallback to sp_default when checkpoint missing")

    # target_spawn_point should be cleared after call
    var gameplay: Dictionary = _store.get_slice(StringName("gameplay"))
    assert_eq(gameplay.get("target_spawn_point", StringName("x")), StringName(""))

    # Player positioned at sp_default
    var player: Node3D = _scene.get_node("E_Player")
    var sp_default: Node3D = _scene.get_node("sp_default")
    assert_almost_eq(player.global_position, sp_default.global_position, Vector3(0.01, 0.01, 0.01))
