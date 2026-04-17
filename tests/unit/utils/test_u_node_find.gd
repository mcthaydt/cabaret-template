extends GutTest

const U_NODE_FIND := preload("res://scripts/utils/ecs/u_node_find.gd")


func test_find_character_body_recursive_returns_direct_body() -> void:
	var body := CharacterBody3D.new()
	autofree(body)

	var found: CharacterBody3D = U_NODE_FIND.find_character_body_recursive(body)
	assert_same(found, body)


func test_find_character_body_recursive_returns_nested_body() -> void:
	var root := Node3D.new()
	autofree(root)
	var child := Node3D.new()
	autofree(child)
	var body := CharacterBody3D.new()
	autofree(body)
	root.add_child(child)
	child.add_child(body)

	var found: CharacterBody3D = U_NODE_FIND.find_character_body_recursive(root)
	assert_same(found, body)


func test_find_character_body_recursive_returns_null_when_missing() -> void:
	var root := Node3D.new()
	autofree(root)
	var child := Node3D.new()
	autofree(child)
	root.add_child(child)

	var found: CharacterBody3D = U_NODE_FIND.find_character_body_recursive(root)
	assert_null(found)
