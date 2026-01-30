extends GutTest

const VFX_MANAGER_SCRIPT_PATH := "res://scripts/managers/m_vfx_manager.gd"

func _get_manager_source() -> String:
	return FileAccess.get_file_as_string(VFX_MANAGER_SCRIPT_PATH)

func test_damage_flash_scene_preloaded() -> void:
	var source := _get_manager_source()
	var regex := RegEx.new()
	regex.compile("const\\s+DAMAGE_FLASH_SCENE\\s*:=\\s*preload\\(\"res://scenes/ui/overlays/ui_damage_flash_overlay\\.tscn\"\\)")
	var match := regex.search(source)
	assert_true(match != null, "M_VFXManager should preload the damage flash overlay scene")

func test_no_load_calls_at_runtime() -> void:
	var source := _get_manager_source()
	var regex := RegEx.new()
	regex.compile("(^|[^A-Za-z_])load\\(")
	var match := regex.search(source)
	assert_true(match == null, "M_VFXManager should avoid runtime load() calls")
