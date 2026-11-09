extends GutTest
## Story 3.7 AC 2 (B2): the voice smoke scene's URL gate and the T1 text it speaks.

const MainScript := preload("res://src/main/main.gd")
const SmokeVoice := preload("res://src/debug/smoke_voice/smoke_voice.gd")


func test_gate_opens_with_debug_and_smoke_voice() -> void:
	assert_true(MainScript.wants_voice_smoke("?debug&smoke=voice"))
	assert_true(MainScript.wants_voice_smoke("?smoke=voice&debug=1"))


func test_gate_closed_otherwise() -> void:
	assert_false(MainScript.wants_voice_smoke("?smoke=voice"))
	assert_false(MainScript.wants_voice_smoke("?debug"))
	assert_false(MainScript.wants_voice_smoke("?debug&smoke=audio"))
	assert_false(MainScript.wants_audio_smoke("?debug&smoke=voice"))


func test_the_smoke_speaks_the_t1_line() -> void:
	assert_eq(SmokeVoice.line_text(), "Q and E shift your bits. Only the two on the left are live; the rest are in code review.")
	assert_eq(SmokeVoice.LINE_ID, &"t1_shift")


func test_the_scene_loads() -> void:
	var scene := load(MainScript.SMOKE_VOICE_SCENE) as PackedScene
	assert_not_null(scene)
