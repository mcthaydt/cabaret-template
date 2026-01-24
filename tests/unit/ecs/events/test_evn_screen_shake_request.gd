extends GutTest

const SCREEN_SHAKE_EVENT := preload("res://scripts/events/ecs/evn_screen_shake_request.gd")

const ENTITY_ID := StringName("player")
const TRAUMA_AMOUNT := 0.45
const SOURCE := StringName("damage")


func _make_event():
	return SCREEN_SHAKE_EVENT.new(ENTITY_ID, TRAUMA_AMOUNT, SOURCE)


func test_has_entity_id_field() -> void:
	var event = _make_event()
	assert_eq(event.entity_id, ENTITY_ID, "Event should expose entity_id field")


func test_has_trauma_amount_field() -> void:
	var event = _make_event()
	assert_almost_eq(event.trauma_amount, TRAUMA_AMOUNT, 0.0001, "Event should expose trauma_amount field")


func test_has_source_field() -> void:
	var event = _make_event()
	assert_eq(event.source, SOURCE, "Event should expose source field")


func test_timestamp_auto_populated() -> void:
	var event = _make_event()
	assert_true(event.timestamp is float, "Timestamp should be a float")
	assert_true(event.timestamp > 0.0, "Timestamp should be populated")


func test_payload_structure() -> void:
	var event = _make_event()
	var payload := event.get_payload()
	assert_true(payload is Dictionary, "Payload should be a Dictionary")


func test_payload_contains_all_fields() -> void:
	var event = _make_event()
	var payload := event.get_payload()
	assert_eq(payload.get("entity_id"), ENTITY_ID, "Payload should include entity_id")
	assert_almost_eq(float(payload.get("trauma_amount", 0.0)), TRAUMA_AMOUNT, 0.0001, "Payload should include trauma_amount")
	assert_eq(payload.get("source"), SOURCE, "Payload should include source")
