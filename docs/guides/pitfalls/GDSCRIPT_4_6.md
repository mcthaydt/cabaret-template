# GDScript 4.6 Pitfalls

Type system, inference, and language-level gotchas specific to GDScript 4.6.

---

## GDScript Typing Pitfalls

- **Headless import and GUT treat some warnings as errors**: Both headless `--import` runs and GUT's `warnings_manager` treat "variable type inferred from Variant" as a parse error that prevents the script from loading. Prefer explicit types when a value is `Variant`-typed at the source (e.g., `var result: Variant = helper()` instead of `var result := helper()` when `helper()` returns `Variant`). This applies equally to production scripts and test files.

- **`Script.new()` return values need explicit annotation in tests**: When loading helper scripts dynamically in GUT (`var script_obj := load(path) as Script`), `var helper := script_obj.new()` can fail parse/type inference in headless runs. Use an explicit annotation for the new instance (`var helper: Variant = script_obj.new()`) unless you can safely type it to a known loaded class.

- **String(enum_value) parse error**: GDScript does not accept `String(enum_value)` for enum values (e.g., `C_SurfaceDetectorComponent.SurfaceType`). Use `str(enum_value)` or cast to `int` first (`String(int(enum_value))`).

- **Avoid `String(...)` as a generic cast in debug logs**: `String(some_variant)` can throw at runtime for some types (e.g., `NodePath`). Prefer `str(...)` for debug prints unless you know the Variant type is safe for `String()`.

- **`Object.get()` only accepts one argument in GDScript**: Unlike dictionary `get(key, default)`, calling `some_object.get("prop", fallback)` is a parse error (`Too many arguments for "get()" call`). For `Object`/`Resource` properties, either:
  - check property existence via `get_property_list()` first, then call `get("prop")`, or
  - call `get("prop")` and handle `null`/missing cases explicitly.

- **Do not rely on `field` in property setters for this runtime**: In this project/runtime combo, using `field = ...` inside exported property setters can parse-fail (`Identifier "field" not declared in the current scope`) during headless GUT loads.
  - **Fix pattern**: prefer explicit backing variables or expose a `get_resolved_values()` method that clamps/sanitizes exported values at read time.

- **New `class_name` types can break type hints in headless tests**: When adding a brand-new helper script with `class_name Foo`, using `Foo` as a member variable annotation in an existing script can fail to parse under headless GUT runs (`Parse Error: Could not find type "Foo" in the current scope`). Prefer untyped members (or a base type like `RefCounted`) and instantiate via a script preload alias (for example `const FOO_SCRIPT := preload("res://path/foo.gd")`) until the class is reliably discovered/loaded.

- **New `class_name` base scripts can fail in `extends` during headless runs**: Creating a fresh base script (for example `class_name RS_BaseCondition`) and immediately extending it with `extends RS_BaseCondition` in sibling scripts can fail under headless GUT parsing (`Parse Error: Could not find base class ...`) before the global class cache catches up. Prefer explicit path-based inheritance for new stacks (`extends "res://scripts/resources/qb/rs_base_condition.gd"`) during active refactors; keep `class_name` for inspector/type usage.

- **Typed Array annotations can fail to resolve fresh `class_name` symbols in headless**: Exported typed arrays like `@export var conditions: Array[I_Condition]` can parse-fail in headless (`Could not find type ... in the current scope`) immediately after introducing new script classes. The AI system proved `Array[I_Condition]`/`Array[I_Effect]` work in `@export` once the class cache is warm. If a fresh class fails, prefer explicit path-based inheritance (`extends "res://..."`) during the refactor window, then switch to `class_name`-based typed arrays once stable.

- **Typed Array constructor syntax can parse-fail (`Cannot call on an expression`)**: Expressions like `Array[Resource]([value])` are not valid constructor calls in GDScript. Build typed arrays via annotated locals (`var values: Array[Resource] = [value]`) and assign that variable instead.

- **Assigning typed exported arrays via `Object.set(...)` with untyped array literals can silently coerce to empty/invalid data in headless runs**: This can make rule/goal condition lists appear unset during tests even when authored values look correct.
  - **Fix pattern**: build an explicitly typed local first (`var conditions: Array[Resource] = [condition]`) and assign that typed array to the exported property.

- **Changing parent classes can surface inherited-helper parse errors**: If a script relied on helper methods inherited from a previous base class and you change `extends`, headless parse can fail with `Function "...()" not found in base self` even when those call sites are not hit in tests. Add local replacements in the same patch that changes inheritance so scripts remain loadable.

- **Child scripts cannot redeclare parent members (incl. `const`)**: If a base class defines a member like `const U_Foo := preload("...")`, declaring another `const U_Foo := ...` in a derived script causes a parse error (`The member "U_Foo" already exists in parent class ...`). Prefer inheriting the constant, or use a different name in the child.

- **`tr` cannot be used as a static method name on external classes (Godot 4.6)**: Calling `.tr()` on a preloaded Script variable or class reference triggers a parse-time error `"Could not resolve external class member 'tr'"` because `tr()` is a built-in `Object` method. This means `U_SomeClass.tr(key)` will **not compile**. Name translation helper methods `localize()` or any non-colliding name instead. Never call bare `tr(key)` either (invokes Godot's built-in `Object.tr()`).

- **`log` cannot be used as a static method name (Godot 4.6)**: `log(x)` is a GDScript global built-in (natural logarithm). Declaring `static func log(message: String)` in a class body produces a parse error `"Invalid argument for log() function: argument 1 should be float but is String"`. Use `debug_log`, `trace`, or any non-colliding name instead.

- **Inner class names must start with a capital letter**: Defining an inner class with an underscore-prefixed name (e.g. `class _MockFoo extends Node:`) causes a GDScript 4 parse error. Use `class MockFoo extends Node:` instead.

- **Test inner class names can collide with global `class_name` symbols**: Even when declared inside a test file, an inner class name that matches an existing global `class_name` (for example `MockSaveManager`) can trigger parser/load conflicts in headless runs. Use distinct stub names (for example `SaveManagerStub`) to avoid global class table collisions.

---

## GDScript Language Pitfalls

- **Don't shadow `class_name` symbols with preload constants**: When a script defines `class_name MyClass`, avoid using the same identifier for a script preload (`const MyClass := preload("res://path/to/my_class.gd")`). This can create type conflicts where Godot resolves the symbol as a generic `Resource` script instead of the intended typed class.

  **Problem**: Type checking fails when passing preloaded `.tres` resources to functions expecting the class type:
  ```gdscript
  # WRONG - shadows class_name symbol with preload constant:
  const RS_UIScreenDefinition := preload("res://scripts/ui/resources/rs_ui_screen_definition.gd")
  const MAIN_MENU := preload("res://resources/ui_screens/cfg_main_menu_screen.tres")

  static func register(definition: RS_UIScreenDefinition) -> void:
      # ...

  register(MAIN_MENU)  # ERROR: Resource is not a subclass of expected argument class
  ```

  **Solution**: Do not shadow the class symbol. Either remove the preload constant entirely, or rename it to a non-type alias:
  ```gdscript
  # CORRECT - class_name stays available for typing:
  const RS_UI_SCREEN_DEFINITION_SCRIPT := preload("res://scripts/ui/resources/rs_ui_screen_definition.gd")
  const MAIN_MENU := preload("res://resources/ui_screens/cfg_main_menu_screen.tres")

  static func register(definition: RS_UIScreenDefinition) -> void:
      # ...

  register(MAIN_MENU)  # Works correctly
  ```

  **Real example**: `U_UIRegistry.gd` had `const RS_UIScreenDefinition := preload(...)` which conflicted with the `class_name RS_UIScreenDefinition` in the resource script. Removing/renaming the preload constant fixed the type checking error.

- **Lambda closures cannot reassign primitive variables**: GDScript lambdas capture variables but **cannot reassign primitive types** (bool, int, float). Writing `var completed = false; var callback = func(): completed = true` will NOT modify the outer `completed` variable - the callback will set a local copy instead. **Solution**: Wrap primitives in mutable containers like Arrays. Example:
  ```gdscript
  # WRONG - closure doesn't modify outer variable:
  var completed: bool = false
  var callback := func() -> void:
      completed = true  # Sets local copy, NOT outer variable
  callback.call()
  assert_true(completed)  # FAILS - still false!

  # CORRECT - use Array wrapper:
  var completed: Array = [false]
  var callback := func() -> void:
      completed[0] = true  # Modifies array element
  callback.call()
  assert_true(completed[0])  # PASSES
  ```
  This commonly occurs in:
  - Test callbacks waiting for async operations to complete
  - Transition effects with completion callbacks
  - Action result capture in subscriber callbacks
  - Signal handlers needing to set flags

  See `test_transitions.gd` for examples where all boolean flags use `Array = [false]` pattern to work with closures.

  **Parser warnings indicate this issue**: GDScript 4.5+ emits `CONFUSABLE_CAPTURE_REASSIGNMENT` warnings when lambdas reassign captured primitives. If you see "Reassigning lambda capture does not modify the outer local variable" in diagnostics, switch to Array wrapper pattern immediately to prevent silent test failures.

- **Always add explicit types when pulling Variants**: Helpers such as `C_InputComponent.get_move_vector()` or `Time.get_ticks_msec()` return Variants. Define locals with `: Vector2`, `: float`, etc., instead of relying on inference, otherwise the parser fails with "typed as Variant" errors.

- **Annotate Callable results**: `Callable.call()` and similar helpers also return Variants. When reducers or action handlers return dictionaries, capture them with explicit types (e.g., `var next_state: Dictionary = root.call(...)`) so tests load without Variant inference errors.

- **Respect tab indentation in scripts**: Godot scripts under `res://` expect tabs. Mixing spaces causes parse errors that look unrelated to the actual change, so configure your editor accordingly before editing `.gd` files.

- **Typed return functions must guard `Dictionary.get()` Variant results**: When a function has a typed return (e.g., `-> Vector3`), `Dictionary.get("key", Vector3.ZERO)` still returns `Variant`. If the stored value is the wrong type (e.g., a `String` instead of `Vector3`), Godot errors at runtime: `Trying to return value of type "String" from a function whose return type is "Vector3"`. **Solution**: Always validate before returning:
  ```gdscript
  # WRONG - crashes if "position" holds a non-Vector3 value:
  static func get_entity_position(state: Dictionary, entity_id: Variant) -> Vector3:
      return get_entity(state, entity_id).get("position", Vector3.ZERO)

  # CORRECT - type-check the Variant before returning:
  static func get_entity_position(state: Dictionary, entity_id: Variant) -> Vector3:
      var value: Variant = get_entity(state, entity_id).get("position", Vector3.ZERO)
      return value as Vector3 if value is Vector3 else Vector3.ZERO
  ```
  This applies to any selector or accessor that reads Variant values from Redux state dictionaries and returns a typed value. The `Dictionary.get()` default parameter does NOT enforce the return type — it only provides a fallback when the key is missing, not when the key exists with the wrong type.

- **Don't call `super._exit_tree()` unless the parent script defines it**: Calling `super._exit_tree()` only works when the parent script implements `_exit_tree()`. If the parent script does not define it, Godot fails to compile with `Cannot call the parent class' virtual function "_exit_tree()" because it hasn't been defined.` Prefer omitting the `super` call or adding an `_exit_tree()` stub to the parent script.
