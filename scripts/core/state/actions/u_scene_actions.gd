extends RefCounted
class_name U_SceneActions

## Action creators for scene management slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.
##
## Actions:
## - TRANSITION_STARTED: Marks start of scene transition
## - TRANSITION_COMPLETED: Marks completion of scene transition
## - PUSH_OVERLAY: Adds overlay scene to stack (pause, settings, etc.)
## - POP_OVERLAY: Removes top overlay scene from stack

# Action type constants
const ACTION_TRANSITION_STARTED := StringName("scene/transition_started")
const ACTION_TRANSITION_COMPLETED := StringName("scene/transition_completed")
const ACTION_SCENE_SWAPPED := StringName("scene/swapped")
const ACTION_PUSH_OVERLAY := StringName("scene/push_overlay")
const ACTION_POP_OVERLAY := StringName("scene/pop_overlay")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_TRANSITION_STARTED, {
		"required_fields": ["target_scene_id", "transition_type"]
	})
	U_ActionRegistry.register_action(ACTION_TRANSITION_COMPLETED, {
		"required_fields": ["scene_id"]
	})
	U_ActionRegistry.register_action(ACTION_SCENE_SWAPPED, {
		"required_fields": ["scene_id"]
	})
	U_ActionRegistry.register_action(ACTION_PUSH_OVERLAY, {
		"required_fields": ["scene_id"]
	})
	U_ActionRegistry.register_action(ACTION_POP_OVERLAY)

## Mark start of scene transition
##
## Payload:
## - target_scene_id: StringName - Scene being transitioned to
## - transition_type: String - Type of transition effect (instant, fade, loading)
static func transition_started(target_scene_id: StringName, transition_type: String) -> Dictionary:
	return {
		"type": ACTION_TRANSITION_STARTED,
		"payload": {
			"target_scene_id": target_scene_id,
			"transition_type": transition_type
		}
	}

## Mark scene content swap (mid-transition)
##
## Dispatched when the new scene has been instantiated and added to the tree,
## but the visual transition (fade-in) has not yet completed.
## Use this for updating visual effects (Cinema Grade) while the screen is obscured.
##
## Payload:
## - scene_id: StringName - Scene that was loaded
static func scene_swapped(scene_id: StringName) -> Dictionary:
	return {
		"type": ACTION_SCENE_SWAPPED,
		"payload": {
			"scene_id": scene_id
		}
	}

## Mark completion of scene transition
##
## Payload:
## - scene_id: StringName - Scene that was loaded
static func transition_completed(scene_id: StringName) -> Dictionary:
	return {
		"type": ACTION_TRANSITION_COMPLETED,
		"payload": {
			"scene_id": scene_id
		}
	}

## Add overlay scene to stack
##
## Payload:
## - scene_id: StringName - Overlay scene to push (pause_menu, settings_menu, etc.)
static func push_overlay(scene_id: StringName) -> Dictionary:
	return {
		"type": ACTION_PUSH_OVERLAY,
		"payload": {
			"scene_id": scene_id
		}
	}

## Remove top overlay scene from stack
##
## No payload required - always pops top of stack
static func pop_overlay() -> Dictionary:
	return {
		"type": ACTION_POP_OVERLAY,
		"payload": {}
	}
