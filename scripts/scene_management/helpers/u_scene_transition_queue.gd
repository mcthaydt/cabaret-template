class_name U_SceneTransitionQueue

## Transition Queue Helper for M_SceneManager
##
## Responsibilities:
## - Manage transition request queue with priority ordering
## - Deduplicate requests (same scene_id + transition_type → keep higher priority)
## - Track processing state
##
## Priority levels:
## - NORMAL = 0: Standard transitions
## - HIGH = 1: User-initiated (back button)
## - CRITICAL = 2: System-critical (error, death)

## Priority enum for transition queue
enum Priority {
	NORMAL = 0,   # Standard transitions
	HIGH = 1,     # User-initiated transitions (back button)
	CRITICAL = 2  # System-critical transitions (error, death)
}

## Transition request structure
class TransitionRequest:
	var scene_id: StringName
	var transition_type: String
	var priority: int

	func _init(p_scene_id: StringName, p_transition_type: String, p_priority: int) -> void:
		scene_id = p_scene_id
		transition_type = p_transition_type
		priority = p_priority

## Internal queue storage
var _queue: Array[TransitionRequest] = []

## Processing state flag
var _is_processing: bool = false

## Get processing state
func is_processing() -> bool:
	return _is_processing

## Set processing state
func set_processing(processing: bool) -> void:
	_is_processing = processing

## Get queue size
func size() -> int:
	return _queue.size()

## Check if queue is empty
func is_empty() -> bool:
	return _queue.is_empty()

## Enqueue transition with priority-based ordering and deduplication
##
## Deduplication rules:
## - If request for same (scene_id, transition_type) exists in queue:
##   - Keep the higher-priority request
##   - Discard the lower-priority request
## - Priority ordering: Higher priority requests are earlier in queue
##
## Parameters:
##   scene_id: Target scene identifier
##   transition_type: Transition effect type ("instant", "fade", "loading")
##   priority: Priority level (NORMAL, HIGH, CRITICAL)
func enqueue(scene_id: StringName, transition_type: String, priority: int) -> void:
	var request := TransitionRequest.new(scene_id, transition_type, priority)

	# Drop duplicate requests for the same target already in the queue
	for existing in _queue:
		if existing.scene_id == request.scene_id and existing.transition_type == request.transition_type:
			# Keep the higher-priority one
			if existing.priority >= request.priority:
				return
			# Replace existing lower-priority with the new one
			_queue.erase(existing)
			break

	# Insert based on priority (higher priority = earlier in queue)
	var insert_index: int = _queue.size()

	for i in range(_queue.size()):
		if request.priority > _queue[i].priority:
			insert_index = i
			break

	_queue.insert(insert_index, request)

## Pop next transition from queue
##
## Returns null if queue is empty.
func pop_front() -> TransitionRequest:
	if _queue.is_empty():
		return null
	return _queue.pop_front()

## Check if scene_id is already in queue
##
## Used to avoid enqueueing duplicate transitions.
func contains_scene(scene_id: StringName) -> bool:
	for request in _queue:
		if request is TransitionRequest and request.scene_id == scene_id:
			return true
	return false

## Clear all queued transitions
func clear() -> void:
	_queue.clear()
	_is_processing = false
