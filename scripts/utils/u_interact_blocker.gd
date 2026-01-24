@icon("res://assets/editor_icons/utility.svg")
class_name U_InteractBlocker
extends RefCounted

## Centralized utility to manage interact input blocking during UI feedback (toasts)
## Prevents player from triggering interactions while toasts are visible + cooldown period

static var _is_blocked: bool = false
static var _cooldown_timer: Timer = null
static var _cooldown_node: Node = null

## Check if interact input should be blocked
static func is_blocked() -> bool:
	return _is_blocked

## Block interact input (call when toast shows)
static func block() -> void:
	_is_blocked = true
	# Cancel any pending cooldown when a new block is requested
	_cancel_cooldown()

## Unblock interact input with cooldown (call when toast hides)
## @param cooldown_duration: Time in seconds before interact is re-enabled (default 0.3s)
static func unblock_with_cooldown(cooldown_duration: float = 0.3) -> void:
	if cooldown_duration <= 0.0:
		_is_blocked = false
		return

	# Create cooldown timer if needed
	if _cooldown_timer == null or not is_instance_valid(_cooldown_timer):
		_setup_cooldown_timer()

	if _cooldown_timer == null:
		# Fallback if timer setup fails
		_is_blocked = false
		return

	# Start cooldown
	_cooldown_timer.start(cooldown_duration)

## Immediately unblock without cooldown (emergency use only)
static func force_unblock() -> void:
	_is_blocked = false
	_cancel_cooldown()

static func _setup_cooldown_timer() -> void:
	# Find or create a persistent node to host the timer
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_warning("U_InteractBlocker: Cannot access SceneTree")
		return

	var root := tree.root
	if root == null:
		push_warning("U_InteractBlocker: Cannot access root node")
		return

	# Try to find existing blocker node
	_cooldown_node = root.get_node_or_null("InteractBlockerTimer")

	if _cooldown_node == null or not is_instance_valid(_cooldown_node):
		# Create persistent node for timer
		_cooldown_node = Node.new()
		_cooldown_node.name = "InteractBlockerTimer"
		_cooldown_node.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(_cooldown_node)

	# Check if timer already exists as child
	if _cooldown_node.get_child_count() > 0:
		_cooldown_timer = _cooldown_node.get_child(0) as Timer
		if _cooldown_timer != null:
			return  # Reuse existing timer

	# Create timer
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	_cooldown_node.add_child(_cooldown_timer)

static func _cancel_cooldown() -> void:
	if _cooldown_timer != null and is_instance_valid(_cooldown_timer) and not _cooldown_timer.is_stopped():
		_cooldown_timer.stop()

static func _on_cooldown_timeout() -> void:
	_is_blocked = false

## Cleanup method (call on game exit or between tests)
static func cleanup() -> void:
	_cancel_cooldown()

	# Free timer first
	if _cooldown_timer != null and is_instance_valid(_cooldown_timer):
		_cooldown_timer.free()
		_cooldown_timer = null

	# Then free the container node
	if _cooldown_node != null and is_instance_valid(_cooldown_node):
		_cooldown_node.free()  # Use immediate free for tests
		_cooldown_node = null

	_is_blocked = false
