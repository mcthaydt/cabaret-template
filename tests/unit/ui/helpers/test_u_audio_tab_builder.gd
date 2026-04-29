extends GutTest

const U_AUDIO_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_audio_tab_builder.gd")

func test_audio_builder_creates_all_sliders() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_AUDIO_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_eq(built_tab, tab)
	assert_not_null(_find_first(tab, "MasterVolumeSlider"))
	assert_not_null(_find_first(tab, "MusicVolumeSlider"))
	assert_not_null(_find_first(tab, "SFXVolumeSlider"))
	assert_not_null(_find_first(tab, "AmbientVolumeSlider"))
	assert_not_null(_find_first(tab, "MasterMuteToggle"))
	assert_not_null(_find_first(tab, "SpatialAudioToggle"))
	assert_not_null(_find_first(tab, "ApplyButton"))

func test_audio_builder_creates_all_mute_toggles() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_AUDIO_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_not_null(_find_first(tab, "MasterMuteToggle"))
	assert_not_null(_find_first(tab, "MusicMuteToggle"))
	assert_not_null(_find_first(tab, "SFXMuteToggle"))
	assert_not_null(_find_first(tab, "AmbientMuteToggle"))

func test_audio_builder_has_heading() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_AUDIO_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_not_null(_find_first(tab, "HeadingLabel"))

func test_audio_builder_has_action_buttons() -> void:
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = U_AUDIO_TAB_BUILDER.new(tab)
	var built_tab = builder.build()
	
	assert_not_null(_find_first(tab, "ApplyButton"))
	assert_not_null(_find_first(tab, "CancelButton"))
	assert_not_null(_find_first(tab, "ResetButton"))

func _find_first(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result := _find_first(child, name)
		if result != null:
			return result
	return null
