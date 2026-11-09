extends GutTest
## Story 3.6 AC 5 (C1-C3, H3): VoiceService.say resolves a known id to its DuckLinesDef text,
## passes raw text through, emits EventBus.duck_line_requested exactly once and returns the text.

const T1 := "Q and E shift your bits. Only the two on the left are live; the rest are in code review."


func before_each() -> void:
	watch_signals(EventBus)


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


func test_stop_is_a_no_op() -> void:
	VoiceService.stop()
	assert_signal_emit_count(EventBus, "duck_line_requested", 0)


func test_voice_service_declares_no_signal() -> void:
	var script := VoiceService.get_script() as Script
	assert_eq(script.get_script_signal_list().size(), 0, "signals live in event_bus.gd only")


func test_event_bus_declares_duck_line_requested() -> void:
	assert_true(EventBus.has_signal(&"duck_line_requested"))
