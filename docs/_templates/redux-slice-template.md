# Redux Slice Template

Template for generating Redux-style state slices in the Godot 4.7 project.

## File Structure Overview

```
scripts/core/state/
├── actions/
│   └── u_<slice>_actions.gd      # Action creators
├── reducers/
│   └── u_<slice>_reducer.gd      # Reducer logic
├── selectors/
│   └── u_<slice>_selectors.gd    # Query functions
└── utils/
    └── ...                       # Shared utilities

resources/core/state/
└── cfg_default_<slice>_initial_state.tres  # Initial state resource

scripts/core/resources/state/
└── rs_<slice>_initial_state.gd   # Initial state script
```

---

## Step 1: Define Initial State

Create a Resource that defines default state values. This involves two files:

**File 1:** `resources/core/state/cfg_default_<slice>_initial_state.tres`

```gdscript
[gd_resource type="Resource" script_class="RS_<Slice>InitialState" format=3 uid="uid://<generated>"]

[ext_resource type="Script" uid="uid://<script_uid>" path="res://scripts/core/resources/state/rs_<slice>_initial_state.gd" id="1_default"]

[resource]
script = ExtResource("1_default")
```

**File 2:** `scripts/core/resources/state/rs_<slice>_initial_state.gd`

```gdscript
@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_<Slice>InitialState

## Initial state for <slice> slice
## Defines default values for state fields.

@export var field_one: Type = default_value
@export var field_two: Type = default_value

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"field_one": field_one,
		"field_two": field_two,
	}
```

---

## Step 2: Create Actions (Action Creator Functions)

**File:** `scripts/core/state/actions/u_<slice>_actions.gd`

```gdscript
extends RefCounted
class_name U_<Slice>Actions

## Action creators for <slice> state slice
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_EXAMPLE := StringName("<slice>/example_action")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_EXAMPLE)

## Create an example action
static func example_action(payload: Type) -> Dictionary:
	return {
		"type": ACTION_EXAMPLE,
		"payload": payload
	}
```

**Key Patterns:**
- Action types are `StringName` constants with format: `<slice>/action_name`
- Each action creator returns a Dictionary with `type` and `payload` keys
- All actions are registered in `_static_init()` via `U_ActionRegistry.register_action()`
- For Dictionary payloads, use `.duplicate(true)` for immutability

---

## Step 3: Create Reducer (Handle Function with Match Cases)

**File:** `scripts/core/state/reducers/u_<slice>_reducer.gd`

```gdscript
extends RefCounted
class_name U_<Slice>Reducer

## <Slice> state slice reducer
## All reducers are pure functions. NEVER mutate state directly.
## Always use .duplicate(true). Unrecognized actions return state unchanged.

## Reduce <slice> state based on dispatched action
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: Variant = action.get("type")
	
	match action_type:
		U_<Slice>Actions.ACTION_EXAMPLE:
			var new_state: Dictionary = state.duplicate(true)
			new_state.field_one = action.get("payload", default_value)
			return new_state
		
		_:
			# Unknown action - return state unchanged
			return state
```

**Key Patterns:**
- Reducers are **pure functions**: same inputs = same outputs
- **NEVER mutate state directly** - always use `.duplicate(true)`
- Match on `action.get("type")`
- Return new state for handled actions
- Return state unchanged for unknown actions (`_` case)
- Use `action.get("key", default_value)` for safe payload access

---

## Step 4: Create Selectors (Query Functions)

**File:** `scripts/core/state/selectors/u_<slice>_selectors.gd`

```gdscript
extends RefCounted
class_name U_<Slice>Selectors

## <Slice> state slice selectors
## Selectors are pure functions that compute derived state.
## Pass full state from M_StateStore.get_state() or a <slice> slice.
## Selectors should never mutate state - they only read and compute.

## Get field one value
static func get_field_one(state: Dictionary) -> Type:
	return _get_<slice>_slice(state).get("field_one", default_value)

## Get field two value
static func get_field_two(state: Dictionary) -> Type:
	return _get_<slice>_slice(state).get("field_two", default_value)

## Private: extract <slice> slice from full state
static func _get_<slice>_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var <slice>: Variant = state.get("<slice>", null)
	if <slice> is Dictionary:
		return <slice> as Dictionary
	return {}
```

**Key Patterns:**
- Selectors are **pure read-only functions**
- Accept full state Dictionary as parameter
- Use `_get_<slice>_slice()` helper to extract slice from full state
- Provide default values for missing fields
- Never mutate state

---

## Step 5: Register Slice (in M_StateStore)

The slice is registered automatically via export variables in `M_StateStore`:

```gdscript
# In M_StateStore.gd (already configured)
@export var <slice>_initial_state: RS_<Slice>InitialState

func _initialize_slices() -> void:
	U_STATE_SLICE_MANAGER.initialize_slices(
		_slice_configs,
		_state,
		# ... other initial states
		<slice>_initial_state,
		# ...
	)
```

**Reducer registration** happens in `U_StateSliceManager`:

```gdscript
# The slice config is created with:
var <slice>_config := RS_StateSliceConfig.new(StringName("<slice>"))
<slice>_config.reducer = Callable(U_<Slice>Reducer, "reduce")
<slice>_config.initial_state = <slice>_initial_state.to_dictionary()
<slice>_config.dependencies = []  # Other slices this depends on
```

---

## Step 6: Write Tests (GUT Test Examples)

**File:** `tests/unit/state/test_u_<slice>_actions.gd`

```gdscript
extends GutTest

## Tests for U_<Slice>Actions action creators

func test_example_action_returns_correct_structure() -> void:
	var action: Dictionary = U_<Slice>Actions.example_action(test_value)
	
	assert_true(action.has("type"), "Action should have type")
	assert_true(action.has("payload"), "Action should have payload")
	assert_eq(action.get("type"), U_<Slice>Actions.ACTION_EXAMPLE, "Type should match constant")

func test_action_type_is_string_name() -> void:
	var action: Dictionary = U_<Slice>Actions.example_action(test_value)
	var action_type: Variant = action.get("type")
	
	assert_true(action_type is StringName, "Action type should be StringName")

func test_created_actions_validate_successfully() -> void:
	var action: Dictionary = U_<Slice>Actions.example_action(test_value)
	
	assert_true(U_ActionRegistry.validate_action(action), "Action should validate")
```

**File:** `tests/unit/state/test_<slice>_slice_reducers.gd`

```gdscript
extends GutTest

## Tests for U_<Slice>Reducer pure functions

func before_each() -> void:
	U_StateEventBus.reset()

func test_reducer_is_pure_function() -> void:
	var state: Dictionary = {"field_one": initial_value}
	var action: Dictionary = U_<Slice>Actions.example_action(test_value)
	
	var result1: Dictionary = U_<Slice>Reducer.reduce(state, action)
	var result2: Dictionary = U_<Slice>Reducer.reduce(state, action)
	
	assert_eq(result1, result2, "Same inputs should produce same outputs")

func test_reducer_does_not_mutate_original_state() -> void:
	var original_state: Dictionary = {"field_one": initial_value}
	var action: Dictionary = U_<Slice>Actions.example_action(test_value)
	
	var _new_state: Dictionary = U_<Slice>Reducer.reduce(original_state, action)
	
	assert_eq(original_state["field_one"], initial_value, "Original state should remain unchanged")

func test_example_action_updates_field() -> void:
	var state: Dictionary = {"field_one": old_value}
	var action: Dictionary = U_<Slice>Actions.example_action(new_value)
	
	var result: Dictionary = U_<Slice>Reducer.reduce(state, action)
	
	assert_eq(result["field_one"], new_value, "Field should be updated")

func test_unknown_action_returns_state_unchanged() -> void:
	var state: Dictionary = {"field_one": value}
	var unknown_action: Dictionary = {"type": StringName("unknown/action"), "payload": null}
	
	var result: Dictionary = U_<Slice>Reducer.reduce(state, unknown_action)
	
	assert_eq(result, state, "Unknown action should return state unchanged")
```

---

## Usage Example

### Dispatching Actions

```gdscript
# Get store reference
var store := U_StateUtils.get_store(self)

# Dispatch an action
store.dispatch(U_<Slice>Actions.example_action(payload_value))

# Access state
var state: Dictionary = store.get_state()
var slice_state: Dictionary = store.get_slice(StringName("<slice>"))

# Use selectors
var field_value = U_<Slice>Selectors.get_field_one(state)
```

### Subscribing to State Changes

```gdscript
var unsubscribe: Callable = store.subscribe(func(action: Dictionary, state: Dictionary) -> void:
	var <slice>_slice: Dictionary = state.get("<slice>", {})
	# React to state changes
)

# Later, unsubscribe
unsubscribe.call()
```

---

## Key Conventions

1. **Immutability**: Never mutate state. Always use `.duplicate(true)` for deep copies.
2. **Pure Functions**: Reducers and selectors must be pure (no side effects).
3. **StringName Types**: Action types use `StringName` for performance.
4. **Auto-Registration**: Actions register themselves via `_static_init()`.
5. **Type Safety**: Use typed variables and return types where possible.
6. **Default Values**: Always provide defaults in `action.get()` and selector access.
7. **Immutability for Payloads**: Use `.duplicate(true)` for Dictionary/Array payloads.

---

## See Also

- `docs/systems/state_management/redux-state-store-overview.md`
- `scripts/core/state/m_state_store.gd`
- `scripts/core/state/utils/u_state_slice_manager.gd`
- `scripts/core/state/utils/u_action_registry.gd`
