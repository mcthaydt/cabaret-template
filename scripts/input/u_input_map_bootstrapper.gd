class_name U_InputMapBootstrapper
extends RefCounted

## Centralized InputMap validation/bootstrapping.
##
## Phase 3 (Hotspot Simplification): gameplay ECS systems must not mutate InputMap at runtime.
## This helper provides a single place to:
## - define the baseline required actions
## - optionally patch missing actions in dev/test environments (adds action only; no events)

const REQUIRED_ACTIONS: Array[StringName] = [
	StringName("move_left"),
	StringName("move_right"),
	StringName("move_forward"),
	StringName("move_backward"),
	StringName("jump"),
	StringName("sprint"),
	StringName("interact"),
	StringName("pause"),
	StringName("ui_accept"),
	StringName("ui_select"),
	StringName("ui_cancel"),
	StringName("ui_left"),
	StringName("ui_right"),
	StringName("ui_up"),
	StringName("ui_down"),
	StringName("ui_pause"),
	StringName("ui_focus_next"),
	StringName("ui_focus_prev"),
]

static func should_patch_missing_actions() -> bool:
	# Keep runtime behavior deterministic in release builds.
	# Dev/test builds may patch missing actions to avoid log spam and brittle unit tests.
	return OS.has_feature("editor") or OS.has_feature("debug")

static func validate_required_actions(required_actions: Array[StringName] = REQUIRED_ACTIONS) -> bool:
	for action in required_actions:
		if action == StringName():
			continue
		if not InputMap.has_action(action):
			return false
	return true

static func ensure_required_actions(required_actions: Array[StringName] = REQUIRED_ACTIONS, patch_missing: bool = false) -> bool:
	var patched_any := false
	for action in required_actions:
		if action == StringName():
			continue
		if InputMap.has_action(action):
			continue
		if not patch_missing:
			continue
		InputMap.add_action(action)
		patched_any = true

	if patched_any:
		push_warning("U_InputMapBootstrapper: Patched missing InputMap actions (dev/test only). Update project.godot to keep bindings deterministic.")

	return validate_required_actions(required_actions)

