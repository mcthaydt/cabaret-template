extends BaseTest

const M_VCAM_MANAGER := preload("res://scripts/core/managers/m_vcam_manager.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload(
	"res://scripts/ecs/components/c_room_fade_group_component.gd"
)

func _create_manager() -> Node:
	var manager := M_VCAM_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame
	return manager

func test_occluder_without_room_fade_sibling_is_not_filtered() -> void:
	var manager := await _create_manager()
	var parent := Node3D.new()
	add_child(parent)
	autofree(parent)

	var occluder := CSGBox3D.new()
	parent.add_child(occluder)
	autofree(occluder)

	var result: bool = manager._is_occluder_room_faded(occluder)
	assert_false(result, "Occluder without room fade sibling should not be filtered")

func test_occluder_with_opaque_room_fade_sibling_is_not_filtered() -> void:
	var manager := await _create_manager()
	var parent := Node3D.new()
	add_child(parent)
	autofree(parent)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.current_alpha = 1.0
	parent.add_child(component)
	autofree(component)

	var occluder := CSGBox3D.new()
	parent.add_child(occluder)
	autofree(occluder)

	var result: bool = manager._is_occluder_room_faded(occluder)
	assert_false(result, "Occluder with opaque room fade sibling should not be filtered")

func test_occluder_with_fading_room_fade_sibling_is_filtered() -> void:
	var manager := await _create_manager()
	var parent := Node3D.new()
	add_child(parent)
	autofree(parent)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.current_alpha = 0.3
	parent.add_child(component)
	autofree(component)

	var occluder := CSGBox3D.new()
	parent.add_child(occluder)
	autofree(occluder)

	var result: bool = manager._is_occluder_room_faded(occluder)
	assert_true(result, "Occluder with fading room fade sibling should be filtered")

func test_sanitize_occluders_excludes_room_faded_meshes() -> void:
	var manager := await _create_manager()

	var fading_parent := Node3D.new()
	add_child(fading_parent)
	autofree(fading_parent)
	var fading_component := C_ROOM_FADE_GROUP_COMPONENT.new()
	fading_component.current_alpha = 0.3
	fading_parent.add_child(fading_component)
	autofree(fading_component)
	var fading_mesh := CSGBox3D.new()
	fading_parent.add_child(fading_mesh)
	autofree(fading_mesh)

	var normal_parent := Node3D.new()
	add_child(normal_parent)
	autofree(normal_parent)
	var normal_mesh := CSGBox3D.new()
	normal_parent.add_child(normal_mesh)
	autofree(normal_mesh)

	var result: Array = manager._sanitize_occluders([fading_mesh, normal_mesh])
	assert_eq(result.size(), 1, "Should exclude room-faded mesh")
	assert_eq(result[0], normal_mesh, "Should keep normal mesh")
