extends GutTest
## Story 7.2 (AC 1, 2, 9): every SFX the code references loads and has the generator's format:
## 16-bit mono 22050 Hz PCM, no loop, non-empty, shorter than 1 s, peak <= 0.8, ends near silence.
## The byte-for-byte determinism of tools/gen_sfx.py is checked outside GUT (story notes, AC 10).

const AudioManagerScript := preload("res://src/autoloads/audio_manager.gd")
const MIX_RATE := 22050
const MAX_SECONDS := 1.0
const PEAK_MAX := 0.8
## The last sample of every clip is the end of a fade to zero (no click).
const END_MAX := 0.01
## D-S72-2: the final list (15 one-shots).
const FINAL_FILES: PackedStringArray = [
	"shift_left", "shift_right", "hit", "hit_resisted", "patched_chime", "duck_squeak",
	"tell_infinite_loop", "tell_null_pointer", "tell_segfault",
	"glitch_infinite_loop", "glitch_null_pointer", "glitch_segfault",
	"phase_roar", "defeat", "player_hit",
]


## Every stream the code plays: the AudioManager registry plus the two shift clicks.
func _streams() -> Dictionary[String, AudioStream]:
	var out: Dictionary[String, AudioStream] = {}
	for id: StringName in AudioManagerScript.CUES:
		out[String(id)] = AudioManagerScript.CUES[id]
	out["shift_left"] = JuiceDirector.CLICK_LEFT
	out["shift_right"] = JuiceDirector.CLICK_RIGHT
	return out


func test_registry_covers_the_final_file_list() -> void:
	var streams: Dictionary[String, AudioStream] = _streams()
	assert_eq(streams.size(), FINAL_FILES.size())
	for file: String in FINAL_FILES:
		assert_true(streams.has(file), file)
		if streams.has(file):
			assert_eq(streams[file].resource_path, "res://assets/audio/sfx/%s.wav" % file)


func test_every_sfx_is_16bit_mono_22050_short_and_not_looping() -> void:
	var streams: Dictionary[String, AudioStream] = _streams()
	for id: String in streams:
		var wav := streams[id] as AudioStreamWAV
		assert_not_null(wav, "%s is an AudioStreamWAV" % id)
		if wav == null:
			continue
		assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, "%s: 16-bit PCM (import compress Disabled)" % id)
		assert_false(wav.stereo, "%s: mono" % id)
		assert_eq(wav.mix_rate, MIX_RATE, "%s: 22050 Hz" % id)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s: one-shot" % id)
		assert_gt(wav.data.size(), 0, "%s: non-empty" % id)
		assert_lt(wav.get_length(), MAX_SECONDS, "%s: shorter than 1 s" % id)


func test_every_sfx_peaks_at_most_0_8_and_ends_without_a_click() -> void:
	var streams: Dictionary[String, AudioStream] = _streams()
	for id: String in streams:
		var wav := streams[id] as AudioStreamWAV
		if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
			continue
		var data: PackedByteArray = wav.data
		var count: int = data.size() / 2
		var peak: float = 0.0
		for i: int in count:
			peak = maxf(peak, absf(float(data.decode_s16(i * 2)) / 32767.0))
		assert_gt(peak, 0.1, "%s: audible" % id)
		assert_lte(peak, PEAK_MAX + 0.0001, "%s: peak <= 0.8" % id)
		assert_lte(absf(float(data.decode_s16((count - 1) * 2)) / 32767.0), END_MAX, "%s: fades out" % id)


## D-S72-7: a tell cue is audible at tell start and never outlasts the shortest tell (20 frames).
func test_tells_are_shorter_than_the_minimum_tell() -> void:
	for id: StringName in AudioManagerScript.BOSS_TELL_CUES:
		var stream: AudioStream = AudioManagerScript.CUES[id]
		assert_lt(stream.get_length(), float(AttackDef.MIN_TELL_FRAMES) / 60.0, String(id))


func test_shift_clicks_are_distinct() -> void:
	var left := JuiceDirector.CLICK_LEFT as AudioStreamWAV
	var right := JuiceDirector.CLICK_RIGHT as AudioStreamWAV
	assert_ne(left.data, right.data, "<< and >> are different sounds")
