class_name U_TweenManager
extends RefCounted

## Centralized tween factory for scene transitions
##
## Provides standardized tween creation with consistent configuration
## and automatic process mode management for pause-safe transitions.
##
## Features:
## - Default physics process mode for test compatibility
## - Default ease/transition settings matching project style
## - Automatic process mode save/restore via TweenContext
## - Lifecycle management (kill, is_running checks)
##
## Usage:
##   # Simple transition tween
##   var tween := U_TweenManager.create_transition_tween(overlay)
##   tween.tween_property(color_rect, "modulate:a", 1.0, 0.5)
##
##   # Pausable tween with automatic process mode management
##   var context := U_TweenManager.create_pausable_tween(overlay, [overlay, color_rect])
##   context.tween.tween_property(...)
##   context.tween.finished.connect(func(): context.restore_process_modes())


## Configuration for creating managed tweens
##
## Default values match the project's transition style:
## - PHYSICS process mode for test compatibility (wait_physics_frames works)
## - EASE_IN_OUT for smooth acceleration/deceleration
## - TRANS_CUBIC for natural motion curves
class TweenConfig:
	extends RefCounted

	## Tween process mode (default: PHYSICS for test compatibility)
	var process_mode: Tween.TweenProcessMode = Tween.TWEEN_PROCESS_PHYSICS

	## Easing type (default: EASE_IN_OUT for smooth transitions)
	var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

	## Transition type (default: TRANS_CUBIC for natural motion)
	var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC


## Context object for managing tween lifecycle with process mode save/restore
##
## Wraps a Tween with saved process modes for the target nodes.
## Call restore_process_modes() when the tween completes to restore
## original modes (typically in the finished signal handler).
##
## Usage:
##   var context := U_TweenManager.create_pausable_tween(overlay, [overlay, child])
##   context.tween.tween_property(...)
##   context.tween.finished.connect(func():
##       context.restore_process_modes()
##   )
class TweenContext:
	extends RefCounted

	## The managed tween
	var tween: Tween = null

	## Saved process modes: int (instance_id) -> { node: WeakRef, mode: ProcessMode }
	## Using instance_id as key to avoid Dictionary issues with freed Node references
	var _saved_modes: Dictionary = {}

	func _init(t: Tween, saved: Dictionary) -> void:
		tween = t
		_saved_modes = saved

	## Restore all saved process modes to their original values
	##
	## Safe to call even if nodes have been freed - freed nodes
	## are silently skipped.
	func restore_process_modes() -> void:
		for instance_id: int in _saved_modes:
			var entry: Dictionary = _saved_modes[instance_id]
			var weak_ref: WeakRef = entry.get("node")
			if weak_ref == null:
				continue
			var node: Node = weak_ref.get_ref() as Node
			if node != null and is_instance_valid(node):
				node.process_mode = entry.get("mode", Node.PROCESS_MODE_INHERIT)
		_saved_modes.clear()

	## Kill the tween and restore all process modes
	##
	## Use this when you need to abort a transition early
	## (e.g., another transition interrupts, or cleanup on exit).
	func kill_and_restore() -> void:
		if tween != null and tween.is_valid():
			tween.kill()
		restore_process_modes()

	## Check if the tween is currently running
	##
	## Returns false if tween is null, invalid, or not running.
	func is_running() -> bool:
		return tween != null and tween.is_valid() and tween.is_running()


## Create a configured tween with standard transition settings
##
## Creates a tween on the owner node with the project's standard
## configuration for scene transitions:
## - PHYSICS process mode (advances with physics frames for test compatibility)
## - EASE_IN_OUT easing
## - TRANS_CUBIC transition
##
## Parameters:
##   owner: Node - The node that owns the tween (required)
##   config: TweenConfig - Optional custom configuration
##
## Returns: Tween or null if owner is null
##
## Usage:
##   var tween := U_TweenManager.create_transition_tween(overlay)
##   tween.tween_property(color_rect, "modulate:a", 1.0, 0.5)
static func create_transition_tween(owner: Node, config: TweenConfig = null) -> Tween:
	if owner == null:
		push_error("U_TweenManager: Cannot create tween with null owner")
		return null

	var cfg := config if config != null else TweenConfig.new()

	var tween := owner.create_tween()
	tween.set_process_mode(cfg.process_mode)
	tween.set_ease(cfg.ease_type)
	tween.set_trans(cfg.trans_type)

	return tween


## Create a pausable tween with automatic process mode management
##
## Creates a TweenContext that:
## 1. Saves the current process modes of all target nodes
## 2. Sets all target nodes to PROCESS_MODE_ALWAYS (pause-safe)
## 3. Creates a configured transition tween
##
## Call context.restore_process_modes() when done (typically in
## the tween's finished signal handler).
##
## Parameters:
##   owner: Node - The node that owns the tween
##   targets: Array[Node] - Nodes whose process modes should be saved/set
##   config: TweenConfig - Optional custom configuration
##
## Returns: TweenContext with tween and saved modes
##
## Usage:
##   var context := U_TweenManager.create_pausable_tween(overlay, [overlay, color_rect])
##   context.tween.tween_property(...)
##   context.tween.finished.connect(func():
##       color_rect.mouse_filter = Control.MOUSE_FILTER_PASS
##       context.restore_process_modes()
##   )
static func create_pausable_tween(owner: Node, targets: Array[Node], config: TweenConfig = null) -> TweenContext:
	var saved_modes: Dictionary = {}

	# Save and update process modes to ALWAYS for all targets
	# Use instance_id as key with WeakRef to node, avoiding issues with freed references
	for node: Node in targets:
		if is_instance_valid(node):
			var instance_id: int = node.get_instance_id()
			saved_modes[instance_id] = {
				"node": weakref(node),
				"mode": node.process_mode
			}
			node.process_mode = Node.PROCESS_MODE_ALWAYS

	var tween := create_transition_tween(owner, config)

	return TweenContext.new(tween, saved_modes)
