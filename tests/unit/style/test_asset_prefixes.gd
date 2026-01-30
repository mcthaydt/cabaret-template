extends GutTest

## Asset prefix validation test
## Enforces naming conventions for production assets as documented in STYLE_GUIDE.md

# Asset directories and their required prefixes
const ASSET_PREFIX_RULES := {
	"res://assets/textures": {
		"prefix": "tex_",
		"extensions": [".png", ".svg", ".jpg"],
		"description": "Textures"
	},
	"res://assets/audio/music": {
		"prefix": "mus_",
		"extensions": [".mp3", ".ogg", ".wav"],
		"description": "Music"
	},
	"res://assets/editor_icons": {
		"prefix": "icn_",
		"extensions": [".svg", ".png"],
		"description": "Editor icons"
	}
}

# Exceptions that don't need to follow prefix rules
const EXCEPTIONS := [
	".gitkeep",
	".DS_Store"
]


func test_asset_files_follow_prefix_conventions() -> void:
	var violations: Array[String] = []

	for dir_path in ASSET_PREFIX_RULES.keys():
		var rule: Dictionary = ASSET_PREFIX_RULES[dir_path]
		_check_asset_directory(dir_path, rule, violations)

	var message := "Production asset files must follow documented prefix conventions"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md for complete asset prefix rules."
	else:
		message += " - all assets compliant!"

	assert_eq(violations.size(), 0, message)


func _check_asset_directory(dir_path: String, rule: Dictionary, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# Directory doesn't exist - this is fine (e.g., sfx/ambient moved to tests/)
		return

	var required_prefix: String = rule["prefix"]
	var allowed_extensions: Array = rule["extensions"]
	var description: String = rule["description"]

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			# Recursively check subdirectories
			if not entry.begins_with("."):
				_check_asset_directory("%s/%s" % [dir_path, entry], rule, violations)
		else:
			# Check if file is an allowed asset type
			var is_asset := false
			for ext in allowed_extensions:
				if entry.ends_with(ext):
					is_asset = true
					break

			# Skip .import files and exceptions
			if entry.ends_with(".import") or _is_exception(entry):
				entry = dir.get_next()
				continue

			# Validate prefix for asset files
			if is_asset:
				if not entry.begins_with(required_prefix):
					violations.append("%s/%s - %s must start with '%s'" % [
						dir_path, entry, description, required_prefix
					])

		entry = dir.get_next()
	dir.list_dir_end()


func _is_exception(filename: String) -> bool:
	return filename in EXCEPTIONS
