extends BaseTest

## Tests for U_ServiceLocator fail-on-conflict register() behavior.
##
## TDD RED phase: these tests define the expected behavior before the
## implementation exists. They should FAIL until register() is changed
## to push_error on conflict (Commit 2) and register_or_replace() is added.

# ─── Stub helpers ──────────────────────────────────────────────────────────

class StubNode extends Node:
	var id: int = 0

# ─── Setup / Teardown ─────────────────────────────────────────────────────

func before_each() -> void:
	super.before_each()
	U_ServiceLocator.clear()

func after_each() -> void:
	super.after_each()

# ─── register() — idempotent same-instance ─────────────────────────────────

func test_register_same_instance_is_idempotent() -> void:
	var node := StubNode.new()
	autofree(node)
	U_ServiceLocator.register(&"test_service", node)
	# Re-registering the same instance should succeed silently.
	U_ServiceLocator.register(&"test_service", node)
	var result: Node = U_ServiceLocator.get_service(&"test_service")
	assert_same(result, node, "Same instance should remain registered after idempotent re-register")

# ─── register() — conflict detection ──────────────────────────────────────

func test_register_conflict_pushes_error_and_keeps_first() -> void:
	var first := StubNode.new()
	autofree(first)
	var second := StubNode.new()
	autofree(second)
	U_ServiceLocator.register(&"conflict_service", first)
	# Re-registering a DIFFERENT instance should push_error and keep the first.
	U_ServiceLocator.register(&"conflict_service", second)
	assert_push_error("already registered")
	var result: Node = U_ServiceLocator.get_service(&"conflict_service")
	assert_same(result, first, "First registration should win on conflict")

func test_register_conflict_returns_early_without_replacing() -> void:
	var first := StubNode.new()
	autofree(first)
	var second := StubNode.new()
	autofree(second)
	U_ServiceLocator.register(&"conflict_service2", first)
	U_ServiceLocator.register(&"conflict_service2", second)
	# Verify the dictionary still holds the first instance.
	var has_first: bool = U_ServiceLocator.has(&"conflict_service2")
	assert_true(has_first, "Service should still be registered after conflict")

# ─── register_or_replace() — intentional replacement ───────────────────────

func test_register_or_replace_succeeds_with_new_instance() -> void:
	var first := StubNode.new()
	autofree(first)
	var second := StubNode.new()
	autofree(second)
	U_ServiceLocator.register(&"replace_service", first)
	U_ServiceLocator.register_or_replace(&"replace_service", second)
	var result: Node = U_ServiceLocator.get_service(&"replace_service")
	assert_same(result, second, "register_or_replace should replace the first instance")

func test_register_or_replace_works_on_empty_slot() -> void:
	var node := StubNode.new()
	autofree(node)
	U_ServiceLocator.register_or_replace(&"fresh_service", node)
	var result: Node = U_ServiceLocator.get_service(&"fresh_service")
	assert_same(result, node, "register_or_replace should work on empty slot")

func test_register_or_replace_same_instance_is_noop() -> void:
	var node := StubNode.new()
	autofree(node)
	U_ServiceLocator.register(&"noop_service", node)
	U_ServiceLocator.register_or_replace(&"noop_service", node)
	var result: Node = U_ServiceLocator.get_service(&"noop_service")
	assert_same(result, node, "register_or_replace with same instance should be no-op")

# ─── register() — null / empty-name guards ──────────────────────────────────

func test_register_null_instance_pushes_error() -> void:
	U_ServiceLocator.register(&"null_service", null)
	assert_push_error("null or invalid")
	assert_false(U_ServiceLocator.has(&"null_service"), "Null instance should not be registered")

func test_register_empty_name_pushes_error() -> void:
	var node := StubNode.new()
	autofree(node)
	U_ServiceLocator.register(&"", node)
	assert_push_error("cannot be empty")
	# Empty-name service should not appear in the registry.
	assert_false(U_ServiceLocator.has(&""), "Empty-name service should not be registered")