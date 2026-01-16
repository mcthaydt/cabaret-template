extends GutTest

const DAMAGE_FLASH_EVENT := preload("res://scripts/ecs/events/evn_damage_flash_request.gd")

const ENTITY_ID := StringName("player")
const INTENSITY := 1.0
const SOURCE := StringName("damage")


func _make_event():
	return DAMAGE_FLASH_EVENT.new(ENTITY_ID, INTENSITY, SOURCE)


func test_has_entity_id_field() -> void:
	var event = _make_event()
	assert_eq(event.entity_id, ENTITY_ID, "Event should expose entity_id field")


func test_has_intensity_field() -> void:
	var event = _make_event()
	assert_almost_eq(event.intensity, INTENSITY, 0.0001, "Event should expose intensity field")


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
