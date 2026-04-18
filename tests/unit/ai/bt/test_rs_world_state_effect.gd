extends GutTest

const RS_WORLD_STATE_EFFECT_PATH := "res://scripts/resources/ai/bt/rs_world_state_effect.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_effect() -> Resource:
	var effect_script: Script = _load_script(RS_WORLD_STATE_EFFECT_PATH)
	if effect_script == null:
		return null
	var effect_variant: Variant = effect_script.new()
	assert_not_null(effect_variant, "Expected RS_WorldStateEffect.new() to succeed")
	if effect_variant == null:
		return null
	return effect_variant as Resource

func _op_value(effect: Resource, name: String) -> int:
	var op_enum: Variant = effect.get("Op")
	if not (op_enum is Dictionary):
		return -1
	return int((op_enum as Dictionary).get(name, -1))

func test_set_overwrites_key_with_value() -> void:
	var effect: Resource = _new_effect()
	if effect == null:
		return
	effect.set("key", &"hunger")
	effect.set("value", 0)
	effect.set("op", _op_value(effect, "SET"))

	var state: Dictionary = {&"hunger": 8}
	var result_variant: Variant = effect.call("apply_to", state)
	assert_true(result_variant is Dictionary, "apply_to should return a Dictionary")
	if not (result_variant is Dictionary):
		return
	var result: Dictionary = result_variant as Dictionary
	assert_eq(result.get(&"hunger"), 0, "SET should overwrite the target key")

func test_add_numeric_adds_to_existing_value_and_missing_defaults_to_zero() -> void:
	var effect: Resource = _new_effect()
	if effect == null:
		return
	effect.set("key", &"hunger")
	effect.set("value", -2)
	effect.set("op", _op_value(effect, "ADD"))

	var existing_state: Dictionary = {&"hunger": 8}
	var existing_result_variant: Variant = effect.call("apply_to", existing_state)
	assert_true(existing_result_variant is Dictionary, "apply_to should return a Dictionary")
	if not (existing_result_variant is Dictionary):
		return
	var existing_result: Dictionary = existing_result_variant as Dictionary
	assert_eq(existing_result.get(&"hunger"), 6, "ADD should numeric-add against existing values")

	var missing_state: Dictionary = {}
	var missing_result_variant: Variant = effect.call("apply_to", missing_state)
	assert_true(missing_result_variant is Dictionary, "apply_to should return a Dictionary")
	if not (missing_result_variant is Dictionary):
		return
	var missing_result: Dictionary = missing_result_variant as Dictionary
	assert_eq(missing_result.get(&"hunger"), -2, "ADD should treat missing keys as 0")

func test_remove_deletes_key() -> void:
	var effect: Resource = _new_effect()
	if effect == null:
		return
	effect.set("key", &"hunger")
	effect.set("op", _op_value(effect, "REMOVE"))

	var state: Dictionary = {
		&"hunger": 5,
		&"thirst": 2,
	}
	var result_variant: Variant = effect.call("apply_to", state)
	assert_true(result_variant is Dictionary, "apply_to should return a Dictionary")
	if not (result_variant is Dictionary):
		return
	var result: Dictionary = result_variant as Dictionary
	assert_false(result.has(&"hunger"), "REMOVE should delete the configured key")
	assert_true(result.has(&"thirst"), "REMOVE should not delete unrelated keys")

func test_apply_all_returns_new_dictionary_without_mutating_input() -> void:
	var set_effect: Resource = _new_effect()
	var add_effect: Resource = _new_effect()
	var remove_effect: Resource = _new_effect()
	if set_effect == null or add_effect == null or remove_effect == null:
		return

	set_effect.set("key", &"has_line_of_sight")
	set_effect.set("value", true)
	set_effect.set("op", _op_value(set_effect, "SET"))

	add_effect.set("key", &"hunger")
	add_effect.set("value", -3)
	add_effect.set("op", _op_value(add_effect, "ADD"))

	remove_effect.set("key", &"prey_alerted")
	remove_effect.set("op", _op_value(remove_effect, "REMOVE"))

	var initial_state: Dictionary = {
		&"has_line_of_sight": false,
		&"hunger": 9,
		&"prey_alerted": true,
	}
	var effect_script: Script = _load_script(RS_WORLD_STATE_EFFECT_PATH)
	if effect_script == null:
		return
	var effects: Array = Array([], TYPE_OBJECT, "Resource", effect_script)
	effects.append(set_effect)
	effects.append(add_effect)
	effects.append(remove_effect)

	var result_variant: Variant = effect_script.call("apply_all", initial_state, effects)
	assert_true(result_variant is Dictionary, "apply_all should return a Dictionary")
	if not (result_variant is Dictionary):
		return
	var result: Dictionary = result_variant as Dictionary

	assert_eq(result.get(&"has_line_of_sight"), true, "SET should apply through apply_all")
	assert_eq(result.get(&"hunger"), 6, "ADD should apply through apply_all")
	assert_false(result.has(&"prey_alerted"), "REMOVE should apply through apply_all")

	assert_eq(initial_state.get(&"has_line_of_sight"), false, "apply_all must not mutate input state")
	assert_eq(initial_state.get(&"hunger"), 9, "apply_all must not mutate input state")
	assert_true(initial_state.has(&"prey_alerted"), "apply_all must not mutate input state")
