extends BaseTest

const ACTION_FEED_PATH := "res://scripts/resources/ai/actions/rs_ai_action_feed.gd"
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _build_context(hunger: float, gain_on_feed: float) -> Dictionary:
	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	settings.initial_hunger = hunger
	settings.gain_on_feed = gain_on_feed
	needs.settings = settings
	needs.hunger = hunger
	add_child_autofree(needs)
	return {
		"needs": needs,
		"context": {
			"components": {
				C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
			},
		},
	}

func test_feed_action_increases_hunger_and_completes() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var fixture: Dictionary = _build_context(0.25, 0.35)
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var context: Dictionary = fixture.get("context", {})
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_almost_eq(needs.hunger, 0.6, 0.0001)
	assert_true(action.is_complete(context, task_state))
	assert_true(bool(task_state.get(U_AI_TASK_STATE_KEYS.COMPLETED, false)))

func test_feed_action_clamps_hunger_to_one() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var fixture: Dictionary = _build_context(0.9, 0.5)
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var context: Dictionary = fixture.get("context", {})
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_eq(needs.hunger, 1.0)
	assert_true(action.is_complete(context, task_state))

func test_feed_action_missing_needs_component_pushes_error_and_completes() -> void:
	var action_script: Script = _load_script(ACTION_FEED_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var context: Dictionary = {}
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_push_error("RS_AIActionFeed.start: missing C_NeedsComponent in context.")
	assert_true(action.is_complete(context, task_state))
