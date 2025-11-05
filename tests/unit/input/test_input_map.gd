extends GutTest

func test_interact_action_exists_in_input_map() -> void:
	assert_true(InputMap.has_action("interact"),
		"InputMap should define the 'interact' action for triggered interactables.")
