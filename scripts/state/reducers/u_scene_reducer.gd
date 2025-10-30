extends RefCounted
class_name U_SceneReducer

## Scene state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.
##
## Handles:
## - Scene transitions (TRANSITION_STARTED, TRANSITION_COMPLETED)
## - Overlay management (PUSH_OVERLAY, POP_OVERLAY)

const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")

## Reduce scene state based on dispatched action
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: Variant = action.get("type")

	match action_type:
		U_SceneActions.ACTION_TRANSITION_STARTED:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})

			# Store current scene as previous
			new_state["previous_scene_id"] = state.get("current_scene_id", StringName(""))

			# Mark transition in progress
			new_state["is_transitioning"] = true
			new_state["transition_type"] = payload.get("transition_type", "instant")

			return new_state

		U_SceneActions.ACTION_TRANSITION_COMPLETED:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})

			# Update current scene
			new_state["current_scene_id"] = payload.get("scene_id", StringName(""))

			# Clear transition state
			new_state["is_transitioning"] = false
			new_state["transition_type"] = ""

			return new_state

		U_SceneActions.ACTION_PUSH_OVERLAY:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})

			var scene_id: StringName = payload.get("scene_id", StringName(""))
			if scene_id != StringName(""):
				# Duplicate scene_stack to maintain immutability
				var new_stack: Array = new_state.get("scene_stack", []).duplicate(true)
				new_stack.append(scene_id)
				new_state["scene_stack"] = new_stack

			return new_state

		U_SceneActions.ACTION_POP_OVERLAY:
			var new_state: Dictionary = state.duplicate(true)

			# Duplicate scene_stack to maintain immutability
			var current_stack: Array = new_state.get("scene_stack", [])
			if current_stack.size() > 0:
				var new_stack: Array = current_stack.duplicate(true)
				new_stack.pop_back()  # Remove top overlay
				new_state["scene_stack"] = new_stack

			return new_state

		_:
			# Unrecognized action - return state unchanged
			return state
