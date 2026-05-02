extends Node

## Debug script to extract touchscreen settings from Redux store or savegame and print them.
## Run this on your phone to see the current touchscreen configuration.
##
## Usage:
## 1. Add this script to a Node in your scene
## 2. Call print_current_touchscreen_settings() from _ready() or console
## 3. Copy the output and use it to update default resources


func _ready() -> void:
	await get_tree().process_frame
	print_current_touchscreen_settings()

func print_current_touchscreen_settings() -> void:
	print("\n=== Touchscreen Settings Extractor ===")

	# Try to get settings from Redux store first (live state)
	var store = U_StateUtils.get_store(self)
	var ts: Dictionary = {}

	if store != null:
		print("✅ Found Redux store")
		var state: Dictionary = store.get_state()
		print("State keys: ", state.keys())

		# Navigate to settings.input_settings.touchscreen_settings
		if state.has("settings"):
			print("✅ Found settings slice")
			var settings: Dictionary = state["settings"]
			print("Settings keys: ", settings.keys())

			if settings.has("input_settings"):
				print("✅ Found input_settings")
				var input_settings: Dictionary = settings["input_settings"]
				print("Input settings keys: ", input_settings.keys())

				if input_settings.has("touchscreen_settings"):
					print("✅ Found touchscreen_settings")
					ts = input_settings["touchscreen_settings"]
					print("Touchscreen settings keys: ", ts.keys())
				else:
					print("❌ No touchscreen_settings key")
			else:
				print("❌ No input_settings in settings slice")
		else:
			print("❌ No settings slice in state")
	else:
		print("❌ Redux store not found")

	# If Redux failed, try savegame file
	if ts.is_empty():
		print("📁 Trying to read from savegame file...")
		var savegame_path := "user://savegame.json"
		print("Checking: ", ProjectSettings.globalize_path(savegame_path))

		if not FileAccess.file_exists(savegame_path):
			print("❌ No save file found and no Redux store available.")
			print("   Play the game and adjust controls first, then try again.")
			return

		var file := FileAccess.open(savegame_path, FileAccess.READ)
		if file == null:
			print("❌ Failed to open save file: ", FileAccess.get_open_error())
			return

		var json_string := file.get_as_text()
		file.close()

		var parsed: Variant = JSON.parse_string(json_string)
		if parsed == null or not parsed is Dictionary:
			print("❌ Failed to parse JSON")
			return

		var state: Dictionary = parsed as Dictionary
		if not state.has("input_settings"):
			print("❌ No input_settings found in save file")
			return

		var input_settings: Dictionary = state["input_settings"]
		if not input_settings.has("touchscreen_settings"):
			print("❌ No touchscreen_settings found")
			return

		ts = input_settings["touchscreen_settings"]

	if ts.is_empty():
		print("❌ No touchscreen settings found")
		return

	print("\n✅ Current Touchscreen Settings:")
	print("─────────────────────────────────")

	# Size settings
	print("\n[SIZE SETTINGS]")
	print("virtual_joystick_size: ", ts.get("virtual_joystick_size", 1.0))
	print("button_size: ", ts.get("button_size", 1.0))
	print("joystick_deadzone: ", ts.get("joystick_deadzone", 0.15))
	print("virtual_joystick_opacity: ", ts.get("virtual_joystick_opacity", 0.7))
	print("button_opacity: ", ts.get("button_opacity", 0.8))

	# Position settings
	print("\n[POSITION SETTINGS]")
	var joystick_pos: Variant = ts.get("custom_joystick_position", {"x": -1, "y": -1})
	if joystick_pos is Dictionary:
		print("custom_joystick_position: Vector2(", joystick_pos.get("x", -1), ", ", joystick_pos.get("y", -1), ")")
	else:
		print("custom_joystick_position: ", joystick_pos)

	var button_positions: Variant = ts.get("custom_button_positions", {})
	if button_positions is Dictionary and not button_positions.is_empty():
		print("\ncustom_button_positions:")
		for button_name in button_positions:
			var pos: Variant = button_positions[button_name]
			if pos is Dictionary:
				print("  ", button_name, ": Vector2(", pos.get("x", 0), ", ", pos.get("y", 0), ")")
			else:
				print("  ", button_name, ": ", pos)
	else:
		print("custom_button_positions: {} (using defaults)")

	# Generate .tres file content for cfg_default_touchscreen_settings.tres
	print("\n[UPDATE cfg_default_touchscreen_settings.tres WITH:]")
	print("─────────────────────────────────")
	print("virtual_joystick_size = ", ts.get("virtual_joystick_size", 1.0))
	print("button_size = ", ts.get("button_size", 1.0))
	print("joystick_deadzone = ", ts.get("joystick_deadzone", 0.15))
	print("virtual_joystick_opacity = ", ts.get("virtual_joystick_opacity", 0.7))
	print("button_opacity = ", ts.get("button_opacity", 0.8))

	# Generate dictionary for cfg_default_touchscreen.tres virtual_buttons
	if button_positions is Dictionary and not button_positions.is_empty():
		print("\n[UPDATE cfg_default_touchscreen.tres WITH:]")
		print("─────────────────────────────────")
		print("virtual_buttons = Array[Dictionary]([")
		for button_name in button_positions:
			var pos: Variant = button_positions[button_name]
			if pos is Dictionary:
				var x: float = pos.get("x", 0)
				var y: float = pos.get("y", 0)
				print('{"action": "', button_name, '", "position": Vector2(', x, ', ', y, ')},')
			elif pos is Vector2:
				print('{"action": "', button_name, '", "position": Vector2(', pos.x, ', ', pos.y, ')},')
		print("])")

	if joystick_pos is Dictionary:
		var x: float = joystick_pos.get("x", -1)
		var y: float = joystick_pos.get("y", -1)
		print("virtual_joystick_position = Vector2(", x, ", ", y, ")")
	elif joystick_pos is Vector2:
		print("virtual_joystick_position = Vector2(", joystick_pos.x, ", ", joystick_pos.y, ")")

	print("\n=== End of Settings ===\n")
