extends GutTest
## Story 3.7 AC 8, 10 (E1-E2, F2, G3): the duck voice resource and the pre-rendered clips load,
## every clip validates and matches its line, and the reveal times follow the render events.

const VOICE_PATH := "res://data/duck/duck_voice.tres"
const CLIPS: DuckClipsDef = preload("res://data/duck/duck_clips.tres")
const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")


func test_duck_voice_loads_with_a_fixed_seed() -> void:
	if not ClassDB.class_exists(&"MumbleVoice"):
		pending("mumble_speech addon not loaded on this machine; duck_voice.tres not checked")
		return
	var voice: Resource = load(VOICE_PATH)
	assert_not_null(voice)
	assert_eq(voice.get_class(), "MumbleVoice")
	assert_eq(voice.get(&"style"), 0, "BEEP")
	assert_eq(voice.get(&"seed"), 20261101, "fixed seed (D-S37-10)")
	assert_gt(float(voice.get(&"speed")), 0.0)
	assert_eq(voice.get(&"variation"), 0.0, "addon default")


func test_every_line_has_a_valid_clip() -> void:
	assert_eq(CLIPS.validate(), PackedStringArray())
	assert_eq(CLIPS.entries.size(), LINES.entries.size())
	for line: DuckLineDef in LINES.entries:
		var clip: DuckClipDef = CLIPS.find(line.id)
		assert_not_null(clip, "clip for %s" % line.id)
		if clip == null:
			continue
		assert_eq(clip.validate(), PackedStringArray(), String(line.id))
		var spoken: String = " ".join(DuckBubble.wrap(line.text))
		assert_true(clip.matches_text(spoken), "char_times count equals the line length (%s)" % line.id)
		assert_lte(clip.char_times[clip.char_times.size() - 1], clip.stream.get_length() + 0.001)


func test_clip_validate_reports_bad_values() -> void:
	var clip := DuckClipDef.new()
	var messages: PackedStringArray = clip.validate()
	assert_eq(messages.size(), 3, "empty id, no stream, no char_times: %s" % ", ".join(messages))
	clip.id = &"x"
	clip.stream = CLIPS.entries[0].stream
	clip.char_times = PackedFloat32Array([0.0, 0.2, 0.1])
	assert_eq(clip.validate().size(), 1, "decreasing times")
	clip.char_times = PackedFloat32Array([0.0, 0.1, 0.1])
	assert_eq(clip.validate().size(), 0)


func test_char_times_from_events() -> void:
	# "Hi, ab c!" spoken by mumble: events for the letters only (0, 1, 4, 5, 7).
	var events: Array = [
		{"char_index": 0, "start": 0.0}, {"char_index": 1, "start": 0.1}, {"char_index": 4, "start": 0.3},
		{"char_index": 5, "start": 0.4}, {"char_index": 7, "start": 0.5},
	]
	var times: PackedFloat32Array = DuckClipDef.char_times_from_events(9, events, 0.6)
	assert_eq(times.size(), 9)
	var want: Array[float] = [0.0, 0.1, 0.3, 0.3, 0.3, 0.4, 0.5, 0.5, 0.6]
	for i: int in 9:
		assert_almost_eq(times[i], want[i], 0.0001, "index %d" % i)
	assert_eq(DuckClipDef.char_times_from_events(0, events, 0.6).size(), 0)
