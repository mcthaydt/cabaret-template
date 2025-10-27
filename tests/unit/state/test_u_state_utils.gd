extends GutTest

## Tests for U_StateUtils helper functions

var store: M_StateStore
var benchmark_ran: bool = false

func before_each() -> void:
	store = M_StateStore.new()
	add_child(store)
	autofree(store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	benchmark_ran = false

func after_each() -> void:
	# Cleanup handled by autofree
	store = null

func test_get_store_finds_store_in_tree() -> void:
	var found_store: M_StateStore = U_StateUtils.get_store(self)

	assert_not_null(found_store, "Should find store in tree")
	assert_eq(found_store, store, "Should return the correct store")

func test_get_store_errors_if_no_store() -> void:
	# Remove store from group to simulate absence (don't queue_free as it's autofreed)
	store.remove_from_group("state_store")
	await get_tree().process_frame

	var found_store: M_StateStore = U_StateUtils.get_store(self)
	assert_push_error("No M_StateStore")
	assert_null(found_store, "Should return null if no store")

func test_get_store_errors_if_node_invalid() -> void:
	var found_store: M_StateStore = U_StateUtils.get_store(null)
	assert_push_error("Invalid node")
	assert_null(found_store, "Should return null for invalid node")

func test_benchmark_measures_time() -> void:
	var elapsed: float = U_StateUtils.benchmark("test", func() -> void:
		benchmark_ran = true
		# Simulate some work
		for i in 100:
			var _dummy: int = i * i
	)

	assert_true(benchmark_ran, "Callable should run")
	assert_gt(elapsed, 0.0, "Should measure elapsed time")
	assert_lt(elapsed, 100.0, "Should complete in reasonable time")

func test_benchmark_returns_milliseconds() -> void:
	var elapsed: float = U_StateUtils.benchmark("quick_op", func() -> void:
		pass  # No-op
	)

	# Even a no-op should take some time (microseconds converted to ms)
	assert_true(elapsed >= 0.0, "Should return non-negative time")
