extends GutTest
## Story 3.6 AC 5 (C1-C3, H3): VoiceService.say resolves a known id to its DuckLinesDef text,
## passes raw text through, emits EventBus.duck_line_requested exactly once and returns the text.
## Story 3.7 AC 4, 5, 7, 8 (C1-C6, F3, G1): backend resolution, the mumble backend through a fake
## speaker (say, per-character events, finished, stop, late events, the watchdog, the audio lock),
## the pre-render backend's timings, and the single warning on a failure.

const VoiceServiceScript := preload("res://src/autoloads/voice_service.gd")
## Story 4.4 (D-S44-2): T1 rewritten for the start nudge.
const T1 := "Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review."
const T3 := "J then K: Dash Strike. Two bits, one commit."
const B := VoiceServiceScript.Backend


## Stands in for MumbleSpeaker: records calls; _emit_* call the VoiceService callbacks directly.
class FakeSpeaker:
	extends RefCounted
	var service: Node
	var voice: Resource = null
	var said: Array[String] = []
	var stops: int = 0

	func say(text: String) -> void:
		said.append(text)

	func stop() -> void:
		stops += 1

	func _emit_char(i: int) -> void:
		service.call(&"_on_character_spoken", i)

	func _emit_finished() -> void:
		service.call(&"_on_finished")


var _vs: Node
var _fake: FakeSpeaker


func before_each() -> void:
	watch_signals(EventBus)
	_vs = VoiceServiceScript.new()
	add_child_autofree(_vs)
	_vs.set(&"audio_unlocked", func() -> bool: return true)
	_vs.set(&"warn_count", 0)
	_fake = FakeSpeaker.new()
	_fake.service = _vs
	_vs.call(&"use_speaker", _fake)


# --- say (3.6) ---

func test_say_a_known_id_returns_and_emits_its_text() -> void:
	var text: String = VoiceService.say("t1_shift")
	assert_eq(text, T1)
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"t1_shift", T1])


func test_say_raw_text_passes_through_with_an_empty_id() -> void:
	var raw := "Try shifting. Q or E."
	assert_eq(VoiceService.say(raw), raw)
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"", raw])


func test_one_emit_per_call() -> void:
	VoiceService.say("t2_semicolon")
	VoiceService.say("t3_dash_strike")
	VoiceService.say("anything")
	assert_signal_emit_count(EventBus, "duck_line_requested", 3)


func test_say_does_not_start_the_voice() -> void:
	_vs.call(&"say", "t3_dash_strike")
	assert_eq(_fake.said.size(), 0, "the bubble starts the voice after the squeak lead")
	assert_false(_vs.call(&"is_speaking"))


func test_stop_with_nothing_speaking_emits_nothing() -> void:
	VoiceService.stop()
	_vs.call(&"stop")
	assert_signal_emit_count(EventBus, "duck_line_requested", 0)
	assert_signal_emit_count(EventBus, "duck_line_finished", 0)
	assert_eq(_fake.stops, 0)


func test_voice_service_declares_no_signal() -> void:
	var script := VoiceService.get_script() as Script
	assert_eq(script.get_script_signal_list().size(), 0, "signals live in event_bus.gd only")


func test_event_bus_declares_the_duck_signals() -> void:
	assert_true(EventBus.has_signal(&"duck_line_requested"))
	assert_true(EventBus.has_signal(&"duck_character_spoken"))
	assert_true(EventBus.has_signal(&"duck_line_finished"))


# --- backend resolution (C2, D-S37-2) ---

func test_resolve_backend() -> void:
	assert_eq(VoiceServiceScript.resolve_backend(B.AUTO, true, true, true), B.MUMBLE)
	assert_eq(VoiceServiceScript.resolve_backend(B.AUTO, false, false, true), B.PRERENDER, "no addon")
	assert_eq(VoiceServiceScript.resolve_backend(B.AUTO, true, false, true), B.PRERENDER, "speaker did not instantiate")
	assert_eq(VoiceServiceScript.resolve_backend(B.AUTO, false, false, false), B.TEXT)
	assert_eq(VoiceServiceScript.resolve_backend(B.MUMBLE, false, false, true), B.TEXT, "forced mumble never falls to clips")
	assert_eq(VoiceServiceScript.resolve_backend(B.PRERENDER, true, true, true), B.PRERENDER, "forced pre-render (D-S37-8/9)")
	assert_eq(VoiceServiceScript.resolve_backend(B.PRERENDER, true, true, false), B.TEXT)
	assert_eq(VoiceServiceScript.resolve_backend(B.TEXT, true, true, true), B.TEXT)


func test_is_downgrade() -> void:
	assert_false(VoiceServiceScript.is_downgrade(B.AUTO, B.MUMBLE))
	assert_true(VoiceServiceScript.is_downgrade(B.AUTO, B.PRERENDER))
	assert_true(VoiceServiceScript.is_downgrade(B.AUTO, B.TEXT))
	assert_false(VoiceServiceScript.is_downgrade(B.PRERENDER, B.PRERENDER))
	assert_true(VoiceServiceScript.is_downgrade(B.MUMBLE, B.TEXT))
	assert_false(VoiceServiceScript.is_downgrade(B.TEXT, B.TEXT))


func test_the_backend_const_is_auto() -> void:
	assert_eq(VoiceServiceScript.BACKEND, B.AUTO)


func test_the_autoload_uses_one_mumble_speaker_on_the_voice_bus_when_the_addon_loads() -> void:
	if not ClassDB.class_exists(&"MumbleSpeaker"):
		assert_ne(VoiceService.backend, B.MUMBLE)
		pending("mumble_speech addon not loaded on this machine; MUMBLE path not checked")
		return
	assert_eq(VoiceService.backend, B.MUMBLE)
	var speaker: Node = VoiceService.get_node_or_null(^"MumbleSpeaker")
	assert_not_null(speaker)
	assert_eq(speaker.get_class(), "MumbleSpeaker")
	assert_eq(speaker.get(&"bus"), &"Voice")
	assert_eq(speaker.get(&"volume_db"), 0.0)
	assert_not_null(speaker.get(&"voice"))
	assert_eq(VoiceService.warn_count, 0, "no downgrade warning")


# --- mumble backend through the fake (C3, C4, C6) ---

func test_speak_pending_says_the_text_once() -> void:
	assert_true(_vs.call(&"speak_pending", &"t3_dash_strike", T3))
	assert_eq(_fake.said, [T3] as Array[String])
	assert_true(_vs.call(&"is_speaking"))
	assert_eq(_vs.call(&"active_id"), &"t3_dash_strike")


func test_empty_text_is_never_spoken() -> void:
	assert_false(_vs.call(&"speak_pending", &"", ""))
	assert_eq(_fake.said.size(), 0)
	assert_false(_vs.call(&"is_speaking"))


func test_audio_lock_keeps_the_voice_silent() -> void:
	_vs.set(&"audio_unlocked", func() -> bool: return false)
	assert_false(_vs.call(&"can_speak"))
	assert_false(_vs.call(&"speak_pending", &"t3_dash_strike", T3))
	assert_eq(_fake.said.size(), 0, "no speak call before the title press (D-S37-11)")


func test_the_real_autoload_is_locked_before_the_title_press() -> void:
	if AudioManager.is_unlocked():
		pending("AudioManager already unlocked in this run")
		return
	assert_false(VoiceService.can_speak())


func test_characters_are_re_emitted_on_the_event_bus() -> void:
	_vs.call(&"speak_pending", &"t3_dash_strike", T3)
	_fake._emit_char(0)
	_fake._emit_char(2)
	assert_signal_emit_count(EventBus, "duck_character_spoken", 2)
	assert_signal_emitted_with_parameters(EventBus, "duck_character_spoken", [2])


func test_finished_emits_completed_once() -> void:
	_vs.call(&"speak_pending", &"t3_dash_strike", T3)
	_fake._emit_finished()
	_fake._emit_finished()
	assert_signal_emit_count(EventBus, "duck_line_finished", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_finished", [&"t3_dash_strike", true])
	assert_false(_vs.call(&"is_speaking"))


func test_stop_cuts_once_and_late_events_are_ignored() -> void:
	_vs.call(&"speak_pending", &"t3_dash_strike", T3)
	_vs.call(&"stop")
	assert_eq(_fake.stops, 1)
	assert_signal_emit_count(EventBus, "duck_line_finished", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_finished", [&"t3_dash_strike", false])
	_vs.call(&"stop")
	_fake._emit_char(5)
	_fake._emit_finished()
	assert_eq(_fake.stops, 1, "a second stop does nothing")
	assert_signal_emit_count(EventBus, "duck_line_finished", 1, "a late finished after stop is ignored")
	assert_signal_emit_count(EventBus, "duck_character_spoken", 0, "a late character after stop is ignored")


func test_a_new_line_cuts_the_one_speaking() -> void:
	_vs.call(&"speak_pending", &"a", "first line")
	_vs.call(&"speak_pending", &"b", "second line")
	assert_signal_emit_count(EventBus, "duck_line_finished", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_finished", [&"a", false])
	assert_eq(_vs.call(&"active_id"), &"b")


func test_watchdog_cuts_a_line_that_never_ends() -> void:
	_vs.call(&"speak_pending", &"t3_dash_strike", T3)
	var expected: float = float(T3.length()) / VoiceServiceScript.DEFAULT_CPS + VoiceServiceScript.WATCHDOG_SLACK_S
	_vs.call(&"step", expected - 0.1)
	assert_true(_vs.call(&"is_speaking"), "still inside the watchdog")
	_vs.call(&"step", 0.2)
	assert_false(_vs.call(&"is_speaking"))
	assert_signal_emitted_with_parameters(EventBus, "duck_line_finished", [&"t3_dash_strike", false])
	assert_eq(_fake.stops, 1)


func test_the_watchdog_follows_the_voice_speed() -> void:
	_vs.set(&"_voice_cps", 10.0) # use_speaker reads MumbleVoice.speed; the fake has no voice
	_vs.call(&"speak_pending", &"x", "abcdefghij") # 1 s at 10 chars/s + 3 s slack
	_vs.call(&"step", 3.9)
	assert_true(_vs.call(&"is_speaking"))
	_vs.call(&"step", 0.2)
	assert_false(_vs.call(&"is_speaking"))


func test_a_runtime_failure_falls_back_to_text_with_one_warning() -> void:
	var broken := RefCounted.new() # no say(): unusable
	_vs.call(&"use_speaker", broken)
	assert_false(_vs.call(&"speak_pending", &"x", "hello"))
	assert_eq(_vs.get(&"backend"), B.TEXT)
	assert_eq(_vs.get(&"warn_count"), 1)
	assert_false(_vs.call(&"speak_pending", &"x", "hello"))
	_vs.call(&"warn_once", "again")
	assert_eq(_vs.get(&"warn_count"), 1, "one warning for the whole run (D-S37-12)")


func test_text_backend_never_speaks() -> void:
	_vs.set(&"backend", B.TEXT)
	assert_false(_vs.call(&"can_speak"))
	assert_false(_vs.call(&"speak_pending", &"t3_dash_strike", T3))
	assert_eq(_fake.said.size(), 0)


# --- pre-render backend (F3) ---

func _use_prerender() -> DuckClipDef:
	_vs.call(&"use_prerender")
	return VoiceServiceScript.CLIPS.find(&"t3_dash_strike")


func test_prerender_plays_the_clip_on_the_voice_bus() -> void:
	_use_prerender()
	assert_true(_vs.call(&"speak_pending", &"t3_dash_strike", T3))
	var player := _vs.get_node_or_null(^"PrerenderPlayer") as AudioStreamPlayer
	assert_not_null(player)
	assert_eq(player.bus, &"Voice")
	assert_not_null(player.stream)
	assert_eq(_fake.said.size(), 0, "the speaker is not used")


func test_prerender_emits_each_character_at_its_time_then_finishes() -> void:
	var clip: DuckClipDef = _use_prerender()
	_vs.call(&"speak_pending", &"t3_dash_strike", T3)
	_vs.call(&"step", 0.0)
	var at_zero: int = 0
	for t: float in clip.char_times:
		if t <= 0.0:
			at_zero += 1
	assert_signal_emit_count(EventBus, "duck_character_spoken", at_zero)
	var almost: float = clip.stream.get_length() - 0.01
	_vs.call(&"step", almost)
	var shown: int = 0
	for t: float in clip.char_times:
		if t <= almost:
			shown += 1
	assert_lt(shown, T3.length(), "the final full stop shows at the clip's end")
	assert_signal_emit_count(EventBus, "duck_character_spoken", shown)
	assert_signal_emit_count(EventBus, "duck_line_finished", 0)
	_vs.call(&"step", 0.02)
	assert_signal_emit_count(EventBus, "duck_character_spoken", T3.length(), "every character by the end")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_finished", [&"t3_dash_strike", true])
	assert_false(_vs.call(&"is_speaking"))


func test_prerender_has_no_clip_for_raw_text_or_changed_text() -> void:
	_use_prerender()
	assert_false(_vs.call(&"speak_pending", &"", "raw text"))
	assert_false(_vs.call(&"speak_pending", &"t3_dash_strike", "different text"))
	assert_false(_vs.call(&"is_speaking"))


func test_prerender_stop_cuts_the_clip() -> void:
	_use_prerender()
	_vs.call(&"speak_pending", &"t3_dash_strike", T3)
	_vs.call(&"stop")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_finished", [&"t3_dash_strike", false])
	var player := _vs.get_node_or_null(^"PrerenderPlayer") as AudioStreamPlayer
	assert_false(player.playing)


func test_say_empty_requests_nothing() -> void:
	watch_signals(EventBus)
	assert_eq(_vs.call(&"say", ""), "")
	assert_signal_not_emitted(EventBus, "duck_line_requested")
