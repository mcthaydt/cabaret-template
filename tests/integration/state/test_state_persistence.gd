extends GutTest

## Verifies gameplay slice persistence across simulated area transitions via StateHandoff.
## Covers core fields: health, checkpoints, settings, completed areas, and entity snapshots.

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_EntityActions := preload("res://scripts/state/actions/u_entity_actions.gd")

var _root: Node

func before_each() -> void:
    _root = Node.new()
    add_child_autofree(_root)
    U_StateHandoff.clear_all()

func after_each() -> void:
    U_StateHandoff.clear_all()
    _root = null

func _make_store() -> M_StateStore:
    var store := M_STATE_STORE.new()
    store.name = "M_StateStore"
    store.settings = RS_STATE_STORE_SETTINGS.new()
    store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
    store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
    _root.add_child(store)
    return store

func _simulate_transition_replace_store() -> M_StateStore:
    # Remove current store to trigger _exit_tree() -> preserve to StateHandoff
    var old_store := _root.get_node_or_null("M_StateStore") as M_StateStore
    if old_store != null:
        _root.remove_child(old_store)
        old_store.queue_free()

    # Add a fresh store that will restore from StateHandoff in _ready()
    var new_store := _make_store()
    return new_store

func test_gameplay_state_persists_across_state_handoff_transition() -> void:
    var store := _make_store()
    await get_tree().process_frame

    # Seed gameplay state with representative values
    store.dispatch(U_GameplayActions.set_gravity_scale(0.75))
    store.dispatch(U_GameplayActions.set_show_landing_indicator(false))
    store.dispatch(U_GameplayActions.set_particle_settings({"jump_particles_enabled": false, "landing_particles_enabled": true}))
    store.dispatch(U_GameplayActions.set_audio_settings({"jump_sound_enabled": true, "volume": 0.6, "pitch_scale": 0.9}))
    store.dispatch(U_GameplayActions.set_last_checkpoint(StringName("cp_safe_zone")))
    store.dispatch(U_GameplayActions.set_target_spawn_point(StringName("sp_exit_from_house")))
    store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))
    # Reduce health to a non-trivial value
    store.dispatch(U_GameplayActions.take_damage("E_Player", 25.0))

    await get_tree().process_frame
    var before: Dictionary = store.get_state().duplicate(true)

    # Simulate area transition (store exit/enter)
    var restored_store := _simulate_transition_replace_store()
    await get_tree().process_frame

    var after: Dictionary = restored_store.get_state()
    var g_before: Dictionary = before.get("gameplay", {})
    var g_after: Dictionary = after.get("gameplay", {})

    assert_almost_eq(float(g_after.get("gravity_scale", -1)), float(g_before.get("gravity_scale", 0.0)), 0.0001, "gravity_scale should persist")
    assert_eq(bool(g_after.get("show_landing_indicator", true)), bool(g_before.get("show_landing_indicator", false)), "landing indicator setting should persist")
    assert_eq(g_after.get("particle_settings", {}), g_before.get("particle_settings", {}), "particle settings should persist")
    assert_eq(g_after.get("audio_settings", {}), g_before.get("audio_settings", {}), "audio settings should persist")
    assert_eq(StringName(g_after.get("last_checkpoint", StringName())).to_string(), StringName(g_before.get("last_checkpoint", StringName())).to_string(), "last_checkpoint should persist")
    assert_eq(StringName(g_after.get("target_spawn_point", StringName())).to_string(), StringName(g_before.get("target_spawn_point", StringName())).to_string(), "target_spawn_point should persist")
    var areas_after: Array = g_after.get("completed_areas", [])
    assert_true(areas_after.has("interior_house"), "completed_areas should persist")
    assert_almost_eq(float(g_after.get("player_health", -1)), float(g_before.get("player_health", 0)), 0.0001, "player_health should persist")

func test_entity_snapshots_persist_across_state_handoff_transition() -> void:
    var store := _make_store()
    await get_tree().process_frame

    # Seed an entity snapshot for the player and a dummy enemy
    store.dispatch(U_EntityActions.update_entity_snapshot("E_Player", {
        "entity_type": "player",
        "position": Vector3(1, 2, 3),
        "velocity": Vector3(0, 0, 0),
        "rotation": Vector3(0, 45, 0),
        "is_on_floor": true,
        "is_moving": false,
        "health": 55.0,
        "max_health": 100.0
    }))
    store.dispatch(U_EntityActions.update_entity_snapshot("E_Enemy_1", {
        "entity_type": "enemy",
        "position": Vector3(-2, 0, 5)
    }))

    await get_tree().process_frame
    var before: Dictionary = store.get_state().duplicate(true)

    var restored_store := _simulate_transition_replace_store()
    await get_tree().process_frame
    var after: Dictionary = restored_store.get_state()

    var ents_before: Dictionary = before.get("gameplay", {}).get("entities", {})
    var ents_after: Dictionary = after.get("gameplay", {}).get("entities", {})

    assert_true(ents_after.has("E_Player"), "Player entity snapshot should persist")
    assert_true(ents_after.has("E_Enemy_1"), "Enemy snapshot should persist")
    assert_eq(ents_after.get("E_Player", {}), ents_before.get("E_Player", {}), "Player snapshot should match before transition")
    assert_eq(ents_after.get("E_Enemy_1", {}), ents_before.get("E_Enemy_1", {}), "Enemy snapshot should match before transition")
