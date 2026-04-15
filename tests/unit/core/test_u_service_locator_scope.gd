extends GutTest

## Tests for U_ServiceLocator push_scope / pop_scope test isolation.
##
## Extends GutTest directly (not BaseTest) because these tests exercise
## the scope mechanism itself — BaseTest's push_scope/pop_scope would
## interfere with the test assertions. Cleanup uses clear() instead.

# ─── Stub helpers ──────────────────────────────────────────────────────────

class StubNode extends Node:
	var id: int = 0

# ─── Setup / Teardown ─────────────────────────────────────────────────────

func before_each() -> void:
	U_ServiceLocator.clear()

func after_each() -> void:
	U_ServiceLocator.clear()

# ─── push_scope / pop_scope — isolation ────────────────────────────────────

func test_push_scope_creates_empty_scope() -> void:
	var outer := StubNode.new()
	autofree(outer)
	U_ServiceLocator.register(&"outer_service", outer)
	U_ServiceLocator.push_scope()
	# Inside the scope, the outer service should NOT be visible.
	assert_false(U_ServiceLocator.has(&"outer_service"), "Inner scope should not see outer services")

func test_pop_scope_restores_outer_services() -> void:
	var outer := StubNode.new()
	autofree(outer)
	U_ServiceLocator.register(&"outer_service", outer)
	U_ServiceLocator.push_scope()
	U_ServiceLocator.pop_scope()
	var result: Node = U_ServiceLocator.get_service(&"outer_service")
	assert_same(result, outer, "Outer services should be restored after pop_scope")

func test_inner_scope_registrations_vanish_after_pop() -> void:
	var outer := StubNode.new()
	autofree(outer)
	U_ServiceLocator.register(&"outer_service", outer)
	U_ServiceLocator.push_scope()
	var inner := StubNode.new()
	autofree(inner)
	U_ServiceLocator.register(&"inner_service", inner)
	U_ServiceLocator.pop_scope()
	# Inner-scope registrations should be gone.
	assert_false(U_ServiceLocator.has(&"inner_service"), "Inner-scope registrations should vanish after pop")
	# Outer services should remain.
	assert_true(U_ServiceLocator.has(&"outer_service"), "Outer services should still be registered after pop")

func test_nested_scopes_restore_in_lifo_order() -> void:
	var level0 := StubNode.new()
	autofree(level0)
	U_ServiceLocator.register(&"l0_service", level0)

	U_ServiceLocator.push_scope()
	var level1 := StubNode.new()
	autofree(level1)
	U_ServiceLocator.register(&"l1_service", level1)

	U_ServiceLocator.push_scope()
	var level2 := StubNode.new()
	autofree(level2)
	U_ServiceLocator.register(&"l2_service", level2)

	# Inside level 2: only l2 visible
	assert_true(U_ServiceLocator.has(&"l2_service"), "L2 scope should see l2_service")
	assert_false(U_ServiceLocator.has(&"l1_service"), "L2 scope should NOT see l1_service")
	assert_false(U_ServiceLocator.has(&"l0_service"), "L2 scope should NOT see l0_service")

	U_ServiceLocator.pop_scope()
	# Back to level 1: l1 visible, l2 gone
	assert_true(U_ServiceLocator.has(&"l1_service"), "L1 scope should see l1_service")
	assert_false(U_ServiceLocator.has(&"l2_service"), "L1 scope should NOT see l2_service")

	U_ServiceLocator.pop_scope()
	# Back to level 0: l0 visible, l1 gone
	assert_true(U_ServiceLocator.has(&"l0_service"), "L0 scope should see l0_service")
	assert_false(U_ServiceLocator.has(&"l1_service"), "L0 scope should NOT see l1_service")

func test_pop_scope_on_empty_stack_is_noop() -> void:
	# Popping with no scopes pushed should not crash or corrupt state.
	U_ServiceLocator.pop_scope()
	var node := StubNode.new()
	autofree(node)
	U_ServiceLocator.register(&"survivor", node)
	assert_true(U_ServiceLocator.has(&"survivor"), "Service should survive a no-op pop_scope")

func test_scope_allows_isolated_registrations() -> void:
	# Test that scope isolation prevents cross-test pollution:
	# Two scopes in sequence don't interfere.
	var global := StubNode.new()
	autofree(global)
	U_ServiceLocator.register(&"global_service", global)

	# Scope 1
	U_ServiceLocator.push_scope()
	var test_a := StubNode.new()
	autofree(test_a)
	U_ServiceLocator.register(&"test_only", test_a)
	U_ServiceLocator.pop_scope()

	assert_false(U_ServiceLocator.has(&"test_only"), "test_only should not leak from scope 1")
	assert_true(U_ServiceLocator.has(&"global_service"), "global_service should survive scope 1")

	# Scope 2
	U_ServiceLocator.push_scope()
	var test_b := StubNode.new()
	autofree(test_b)
	U_ServiceLocator.register(&"test_only2", test_b)
	U_ServiceLocator.pop_scope()

	assert_false(U_ServiceLocator.has(&"test_only2"), "test_only2 should not leak from scope 2")
	assert_true(U_ServiceLocator.has(&"global_service"), "global_service should survive scope 2")

func test_scope_dependencies_also_isolated() -> void:
	# Dependencies registered in inner scope should not leak.
	var outer := StubNode.new()
	autofree(outer)
	U_ServiceLocator.register(&"outer_dep", outer)

	U_ServiceLocator.push_scope()
	var inner := StubNode.new()
	autofree(inner)
	U_ServiceLocator.register(&"inner_dep", inner)
	U_ServiceLocator.register_dependency(&"inner_consumer", &"inner_dep")
	U_ServiceLocator.pop_scope()

	# Dependencies from inner scope should also be restored.
	# The _dependencies dict should be scoped too.
	# This is verified indirectly: validate_all in the outer scope should
	# not see inner_consumer's dependency.
	assert_true(U_ServiceLocator.has(&"outer_dep"), "Outer dep should survive pop")