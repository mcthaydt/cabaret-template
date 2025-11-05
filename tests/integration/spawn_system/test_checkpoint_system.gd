extends GutTest

## Integration tests for S_CheckpointSystem (Phase 12.3b)

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const S_CHECKPOINT_SYSTEM := preload("res://scripts/ecs/systems/s_checkpoint_system.gd")
const C_CHECKPOINT_COMPONENT := preload("res://scripts/ecs/components/c_checkpoint_component.gd")
const C_PLAYER_TAG := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

var _manager: M_ECSManager
var _store: M_StateStore

func before_each() -> void:
    U_ECS_EVENT_BUS.reset()

    _store = M_STATE_STORE.new()
    _store.gameplay_initial_state = RS_GAMEPLAY_INITIAL.new()
    add_child_autofree(_store)
    await get_tree().process_frame

    _manager = M_ECS_MANAGER.new()
    add_child_autofree(_manager)
    await get_tree().process_frame

    var system := S_CHECKPOINT_SYSTEM.new()
    _manager.add_child(system)
    autofree(system)
    await get_tree().process_frame

func after_each() -> void:
    _manager = null
    _store = null
    U_ECS_EVENT_BUS.reset()

func _create_player_entity(parent: Node) -> Dictionary:
    var entity := Node3D.new()
    entity.name = "E_Player"
    parent.add_child(entity)
    autofree(entity)

    var body := CharacterBody3D.new()
    entity.add_child(body)
    autofree(body)

    var tag := C_PLAYER_TAG.new()
    entity.add_child(tag)
    autofree(tag)

    return {"entity": entity, "body": body}

func _create_checkpoint_with_area_as_child(parent: Node, spawn_point_id: StringName) -> Dictionary:
    var container := Node3D.new()
    container.name = "E_Checkpoint"
    parent.add_child(container)
    autofree(container)

    # Create component and area BEFORE adding to scene tree to avoid warnings in _ready()
    var comp := C_CHECKPOINT_COMPONENT.new()
    comp.checkpoint_id = StringName("cp_test_child")
    comp.spawn_point_id = spawn_point_id

    var area := Area3D.new()
    area.name = "CheckpointArea"
    comp.add_child(area)
    autofree(area)

    # Now add component (with child Area3D already present) to container
    container.add_child(comp)
    autofree(comp)

    return {"component": comp, "area": area}

func _create_checkpoint_with_area_as_sibling(parent: Node, spawn_point_id: StringName) -> Dictionary:
    var container := Node3D.new()
    container.name = "E_CheckpointSibling"
    parent.add_child(container)
    autofree(container)

    # Create Area3D SIBLING first so component sees it in _ready()
    var area := Area3D.new()
    area.name = "CheckpointAreaSibling"
    container.add_child(area)
    autofree(area)

    var comp := C_CHECKPOINT_COMPONENT.new()
    comp.checkpoint_id = StringName("cp_test_sibling")
    comp.spawn_point_id = spawn_point_id
    container.add_child(comp)
    autofree(comp)

    return {"component": comp, "area": area}

## Check that entering a checkpoint updates last_checkpoint and publishes event
func test_checkpoint_activation_updates_state_and_publishes_event_child_area() -> void:
    var scene_root := Node3D.new()
    add_child_autofree(scene_root)

    var player := _create_player_entity(scene_root)
    var body: CharacterBody3D = player.body

    var checkpoint := _create_checkpoint_with_area_as_child(scene_root, StringName("sp_safe_room"))
    await wait_physics_frames(2) # allow ECS registration and signal wiring

    # Simulate player entering checkpoint area
    var area: Area3D = checkpoint.area
    area.body_entered.emit(body)
    await wait_physics_frames(1)

    # Assert gameplay.last_checkpoint updated
    var gameplay: Dictionary = _store.get_slice(StringName("gameplay"))
    assert_eq(gameplay.get("last_checkpoint", StringName("")), StringName("sp_safe_room"))

    # Assert event published
    var history: Array = U_ECS_EVENT_BUS.get_event_history()
    var found := false
    for ev in history:
        if ev.get("name") == StringName("checkpoint_activated"):
            var payload: Dictionary = ev.get("payload", {})
            found = payload.get("spawn_point_id", StringName("")) == StringName("sp_safe_room")
            if found:
                break
    assert_true(found, "Should publish checkpoint_activated event with spawn_point_id")

## Area3D as sibling also works and connection occurs once
func test_checkpoint_area_as_sibling_connects_once() -> void:
    var scene_root := Node3D.new()
    add_child_autofree(scene_root)

    var player := _create_player_entity(scene_root)
    var body: CharacterBody3D = player.body

    var chk := _create_checkpoint_with_area_as_sibling(scene_root, StringName("sp_mid"))
    await wait_physics_frames(2) # let system connect signals

    # Emit twice; last_checkpoint should be set and remain stable
    var area: Area3D = chk.area
    area.body_entered.emit(body)
    area.body_entered.emit(body)
    await wait_physics_frames(1)

    var gameplay: Dictionary = _store.get_slice(StringName("gameplay"))
    assert_eq(gameplay.get("last_checkpoint", StringName("")), StringName("sp_mid"))

    # Ensure system tracked connection once
    var systems: Array = _manager.get_systems()
    var filtered: Array = systems.filter(func(s): return s is S_CheckpointSystem)
    var sys: S_CheckpointSystem = (filtered[0] as S_CheckpointSystem)
    var connected: Dictionary = sys.get("_connected_checkpoints") as Dictionary
    assert_eq(connected.size(), 1, "Should connect each checkpoint once")
