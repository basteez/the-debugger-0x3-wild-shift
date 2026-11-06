extends GutTest
## Story 1.3 AC8: the audio panning smoke scene, its URL gate and its generated tone.

const MainScript := preload("res://src/main/main.gd")
const SmokeAudio := preload("res://src/debug/smoke_audio/smoke_audio.gd")


func test_gate_opens_with_debug_and_smoke_audio() -> void:
	assert_true(MainScript.wants_audio_smoke("?debug&smoke=audio"))
	assert_true(MainScript.wants_audio_smoke("?smoke=audio&debug"))
	assert_true(MainScript.wants_audio_smoke("?debug=1&smoke=audio"))


func test_gate_closed_without_debug() -> void:
	assert_false(MainScript.wants_audio_smoke("?smoke=audio"))
	assert_false(MainScript.wants_audio_smoke("?nodebug&smoke=audio"))
	assert_false(MainScript.wants_audio_smoke("?debugger&smoke=audio"))


func test_gate_closed_without_smoke_audio() -> void:
	assert_false(MainScript.wants_audio_smoke(""))
	assert_false(MainScript.wants_audio_smoke("?debug"))
	assert_false(MainScript.wants_audio_smoke("?debug&smoke=audiox"))
	assert_false(MainScript.wants_audio_smoke("?debug&smoke=video"))


func test_tone_is_16bit_mono_looping_one_second() -> void:
	var tone: AudioStreamWAV = SmokeAudio.make_tone(440.0, 1.0, 22050)
	assert_eq(tone.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(tone.stereo)
	assert_eq(tone.mix_rate, 22050)
	assert_eq(tone.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(tone.data.size(), 22050 * 2, "1 s of 16-bit mono samples")
	assert_eq(tone.loop_end, 22050)


func test_tone_is_not_silent() -> void:
	var tone: AudioStreamWAV = SmokeAudio.make_tone(440.0, 1.0, 22050)
	var peak: int = 0
	for i: int in range(0, tone.data.size(), 2):
		peak = maxi(peak, absi(tone.data.decode_s16(i)))
	assert_gt(peak, 10000, "sine peak should be loud enough to hear")


func test_pan_sequence_alternates_left_right() -> void:
	assert_eq(SmokeAudio.side_for_step(0), "L")
	assert_eq(SmokeAudio.side_for_step(1), "R")
	assert_eq(SmokeAudio.side_for_step(2), "L")
	assert_lt(SmokeAudio.position_for_step(0).x, 0.0)
	assert_gt(SmokeAudio.position_for_step(1).x, 0.0)
