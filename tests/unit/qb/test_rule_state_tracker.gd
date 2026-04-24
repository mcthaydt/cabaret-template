extends BaseTest

const RULE_STATE_TRACKER := preload("res://scripts/core/utils/qb/u_rule_state_tracker.gd")

func test_tick_cooldowns_decrements_active_cooldowns() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.mark_fired(StringName("rule_a"), StringName("ctx_a"), 2.0)

	tracker.tick_cooldowns(0.5)
	assert_almost_eq(tracker.get_cooldown_remaining(StringName("rule_a"), StringName("ctx_a")), 1.5, 0.0001)

func test_is_on_cooldown_true_during_cooldown_false_after_expiry() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.mark_fired(StringName("rule_a"), StringName("ctx_a"), 1.0)
	assert_true(tracker.is_on_cooldown(StringName("rule_a"), StringName("ctx_a")))

	tracker.tick_cooldowns(1.0)
	assert_false(tracker.is_on_cooldown(StringName("rule_a"), StringName("ctx_a")))

func test_mark_fired_sets_cooldown_for_rule_and_context() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.mark_fired(StringName("rule_a"), StringName("ctx_a"), 3.0)

	assert_true(tracker.is_on_cooldown(StringName("rule_a"), StringName("ctx_a")))
	assert_almost_eq(tracker.get_cooldown_remaining(StringName("rule_a"), StringName("ctx_a")), 3.0, 0.0001)

func test_per_context_cooldown_isolation() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.mark_fired(StringName("rule_a"), StringName("ctx_a"), 2.0)

	assert_true(tracker.is_on_cooldown(StringName("rule_a"), StringName("ctx_a")))
	assert_false(tracker.is_on_cooldown(StringName("rule_a"), StringName("ctx_b")))

func test_check_rising_edge_true_on_false_to_true_transition() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	var triggered: bool = tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), true)
	assert_true(triggered)

func test_check_rising_edge_false_on_true_to_true() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), true)
	var triggered: bool = tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), true)
	assert_false(triggered)

func test_check_rising_edge_false_on_false_to_false() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), false)
	var triggered: bool = tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), false)
	assert_false(triggered)

func test_rising_edge_resets_after_true_false_true_cycle() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), true)
	tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), false)
	var triggered: bool = tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_a"), true)
	assert_true(triggered)

func test_mark_one_shot_spent_prevents_future_firing() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.mark_one_shot_spent(StringName("rule_a"))
	assert_true(tracker.is_one_shot_spent(StringName("rule_a")))

func test_is_one_shot_spent_false_for_unfired_rules() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	assert_false(tracker.is_one_shot_spent(StringName("rule_a")))

func test_cleanup_stale_contexts_removes_contexts_not_in_active_set() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.check_rising_edge(StringName("rule_a"), StringName("ctx_old"), true)
	tracker.cleanup_stale_contexts([StringName("ctx_active")])

	assert_false(tracker.has_rising_edge_state(StringName("rule_a"), StringName("ctx_old")))

func test_cleanup_stale_contexts_preserves_contexts_with_active_cooldowns() -> void:
	var tracker: Variant = RULE_STATE_TRACKER.new()
	tracker.mark_fired(StringName("rule_a"), StringName("ctx_old"), 2.0)
	tracker.cleanup_stale_contexts([StringName("ctx_active")])

	assert_true(tracker.is_on_cooldown(StringName("rule_a"), StringName("ctx_old")))
