class_name U_LocalizationUtils
extends RefCounted

## Static helper for localized string lookup.
##
## CRITICAL: Never call bare tr(key) — that invokes Godot's built-in Object.tr() system.
## Always use U_LocalizationUtils.localize(key) instead.
## NOTE: The method is named "localize" (not "tr") because Godot 4.6 will not resolve
## "tr" as an external class member — it conflicts with the built-in Object.tr().

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

## Return the translated string for the given key.
## Falls back to String(key) if manager unavailable or key not found.
static func localize(key: StringName) -> String:
	var manager := _get_manager()
	if manager == null:
		return String(key)
	return manager.translate(key)

## Return translated string with positional arg substitution.
## Replaces {0}, {1}, {2}, etc. with args[0], args[1], args[2], etc.
## Missing args leave the placeholder unchanged.
static func localize_fmt(key: StringName, args: Array) -> String:
	var base: String = localize(key)
	for i: int in args.size():
		base = base.replace("{%d}" % i, str(args[i]))
	return base

## Register a UI root with the localization manager for font overrides.
static func register_ui_root(root: Node) -> void:
	var manager := _get_manager()
	if manager != null:
		manager.register_ui_root(root)

static func _get_manager() -> Object:
	return U_SERVICE_LOCATOR.try_get_service(StringName("localization_manager"))
