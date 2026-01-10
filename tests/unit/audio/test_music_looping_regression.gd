extends GutTest

## Regression test: Music files should have loop enabled
## Verifies that all music tracks loop properly

func test_main_menu_music_loops() -> void:
	var stream: AudioStream = load("res://resources/audio/music/main_menu.mp3")
	assert_not_null(stream, "Main menu music should load")

	if stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		assert_true(mp3_stream.loop, "Main menu music should have loop enabled")
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		assert_true(ogg_stream.loop, "Main menu music should have loop enabled")

func test_exterior_music_loops() -> void:
	var stream: AudioStream = load("res://resources/audio/music/exterior.mp3")
	assert_not_null(stream, "Exterior music should load")

	if stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		assert_true(mp3_stream.loop, "Exterior music should have loop enabled")
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		assert_true(ogg_stream.loop, "Exterior music should have loop enabled")

func test_interior_music_loops() -> void:
	var stream: AudioStream = load("res://resources/audio/music/interior.mp3")
	assert_not_null(stream, "Interior music should load")

	if stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		assert_true(mp3_stream.loop, "Interior music should have loop enabled")
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		assert_true(ogg_stream.loop, "Interior music should have loop enabled")

func test_pause_music_loops() -> void:
	var stream: AudioStream = load("res://resources/audio/music/pause.mp3")
	assert_not_null(stream, "Pause music should load")

	if stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		assert_true(mp3_stream.loop, "Pause music should have loop enabled")
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		assert_true(ogg_stream.loop, "Pause music should have loop enabled")

func test_credits_music_loops() -> void:
	var stream: AudioStream = load("res://resources/audio/music/credits.mp3")
	assert_not_null(stream, "Credits music should load")

	if stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		assert_true(mp3_stream.loop, "Credits music should have loop enabled")
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		assert_true(ogg_stream.loop, "Credits music should have loop enabled")
