extends BaseTest

const EFFECT_DISPATCH_ACTION := preload("res://scripts/core/resources/qb/effects/rs_effect_dispatch_action.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

func test_dispatches_action_with_correct_type_and_payload() -> void:
	var effect: Variant = EFFECT_DISPATCH_ACTION.new()
	effect.action_type = StringName("set_last_checkpoint")
	effect.payload = {
		"checkpoint_id": "cp_lobby",
		"spawn_point": "sp_front"
	}

	var store: Variant = MOCK_STATE_STORE.new()
	if store is Node:
		autoqfree(store as Node)
	var context: Dictionary = {
		"state_store": store
	}

	effect.execute(context)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1)
	assert_eq(actions[0].get("type"), StringName("set_last_checkpoint"))
	assert_eq(actions[0].get("checkpoint_id"), "cp_lobby")
	assert_eq(actions[0].get("spawn_point"), "sp_front")

func test_missing_state_store_in_context_is_no_op() -> void:
	var effect: Variant = EFFECT_DISPATCH_ACTION.new()
	effect.action_type = StringName("set_last_checkpoint")
	effect.payload = {
		"checkpoint_id": "cp_lobby"
	}

	var context: Dictionary = {}
	effect.execute(context)

	assert_true(true)
