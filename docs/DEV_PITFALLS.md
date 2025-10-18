# Dev Pitfalls — Godot 4 + GUT

Quick reference of small mistakes to avoid. Keeps the TDD loop fast and green.

GUT tests
- Don’t use `class_name` in test scripts. Extend `res://addons/gut/test.gd` and keep tests anonymous.
- Avoid type inference from dynamically loaded scripts. When doing `var s = load(path)` and `var obj = s.new()`, annotate variable types for values returned by dynamic calls (e.g., `var id: int = obj.create_entity()`).
- Use bracket access for Dictionary fields. Prefer `dict["key"]` or `dict.get("key")` over `dict.key` in reducers/tests.
- Avoid indexing into arrays in assertion arguments without a preceding size check; GUT evaluates arguments before failing. Guard or split assertions.
 - Closures capture outer variables at creation time. If you assign the variable after creating the closure (e.g., `var h=-1; h = subscribe(func(): unsubscribe(h))`), the closure may still see the original value. Prefer APIs that support unsubscribing the "current" listener or pass the handle as a parameter to the closure.
 - When mutating counters/flags inside a callback, use a shared container (e.g., `var state := {"calls": 0}` and `state["calls"] += 1`) to avoid scalar capture surprises.
 - Free Nodes to avoid GUT orphans. In tests, extend `res://tests/helpers/BaseTest.gd` and wrap instances in `track(...)`; the helper frees tracked Nodes in `after_each()`.
 - For scene integration tests, instantiate and add the scene to the tree, then `await get_tree().process_frame` so `_ready()` wiring runs before assertions.

Typed GDScript basics
- Be explicit when the compiler can’t infer types (dynamic calls, untyped collections). Example: `var result: PackedInt32Array = ecs.query([...])`.
- Prefer typed arrays/collections: `Array[int]`, `Array[String]`, `PackedInt32Array`.
- Use `StringName` for identifiers and literals (`&"Type"`) to reduce allocations and ensure consistent keys.
 - Don’t rely on `:=` when the right side may be `Variant`/`null` (warnings-as-errors). Annotate and cast explicitly, e.g., `var script: Script = comp.get_script() as Script`.
 - Keep indentation consistent within a file. Do not mix tabs and spaces; Godot can treat this as an error under strict settings.
 - When interacting with `Array[int]`, ensure you append `int` values (e.g., `var handle: int = ...`) to avoid Variant leakage that can break iteration.
 - Object vs Dictionary `get()`: `Object.get("prop")` takes one argument; only `Dictionary.get("key", default)` supports a default. Use the single-arg form on Objects/Nodes/Resources.

GDScript warnings hygiene
- Avoid parameter names that shadow Node properties. Using `name` as a function parameter in scripts that extend `Node` triggers shadowing warnings. Prefer `slice_name`, `system_name`, `type_name`, etc.
- Prefix unused parameters with `_`. Example: `func run(_delta: float) -> void:` to silence UNUSED_PARAMETER while documenting intent.

Scenes & structure

General testing tips
- Fail fast in tests with `assert_not_null(load(path))` before instantiation.
- Keep one concern per test; name tests with incremental numbering for quick ordering (e.g., `test_010_*`).
 - Remove temporary debug prints once tests are green to keep output clean.

Last updated: 2025-10-17
