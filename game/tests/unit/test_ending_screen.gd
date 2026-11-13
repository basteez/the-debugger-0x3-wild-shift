extends GutTest
## Story 6.8 (D1, AC 4-6, 9, 12-14, 16-19): EndingScreen's pure timeline helpers, the leave rule, the
## line latch and the ending text data.

const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const B := EndingScreen.Beat
const TEXT_PATH := "res://data/ending/ending_text.tres"

var _saved_state: int
var _saved_start: int
var _saved_summary: Dictionary
var _saved_frame: int
var _saved_paused: bool


func before_each() -> void:
	_saved_state = Game.flow_state
	_saved_start = Game.ending_start_frame
	_saved_summary = Game.ending_summary
	_saved_frame = SimClock.sim_frame
	_saved_paused = SimClock.paused
	SimClock.paused = false


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.ending_start_frame = _saved_start
	Game.ending_summary = _saved_summary
	SimClock.sim_frame = _saved_frame
	SimClock.paused = _saved_paused


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func _click(button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


## An EndingScreen in the tree with Game in ENDING since `start`, the line request recorded.
func _screen(start: int, summary: Dictionary = {&"clear_frames": 0, &"hits": 0, &"debug_jumped": false}) -> EndingScreen:
	Game.flow_state = S.ENDING
	Game.ending_start_frame = start
	Game.ending_summary = summary
	var screen := EndingScreen.new()
	screen.set_physics_process(false) # the test drives poll()
	add_child_autofree(screen)
	return screen


func test_beat_boundaries() -> void:
	assert_eq(EndingScreen.beat_at(-1), -1)
	assert_eq(EndingScreen.beat_at(0), B.FADE)
	assert_eq(EndingScreen.beat_at(29), B.FADE)
	assert_eq(EndingScreen.beat_at(30), B.NIBBLE)
	assert_eq(EndingScreen.beat_at(75), B.NIBBLE)
	assert_eq(EndingScreen.beat_at(89), B.NIBBLE)
	assert_eq(EndingScreen.beat_at(90), B.COMMIT)
	assert_eq(EndingScreen.beat_at(299), B.COMMIT)
	assert_eq(EndingScreen.beat_at(300), B.LINE)
	assert_eq(EndingScreen.beat_at(359), B.LINE)
	assert_eq(EndingScreen.beat_at(360), B.CREDITS, "no summary: the credits at 360")
	assert_eq(EndingScreen.beat_at(360, true), B.SUMMARY, "summary card 360-539")
	assert_eq(EndingScreen.beat_at(539, true), B.SUMMARY)
	assert_eq(EndingScreen.beat_at(540, true), B.CREDITS, "credits at 540 after the card")
	assert_eq(EndingScreen.beat_at(899), B.CREDITS)
	assert_eq(EndingScreen.beat_at(900), B.HOLD, "the hold at 900 (30 s)")
	assert_eq(EndingScreen.beat_at(5000), B.HOLD)


func test_no_beat_reads_a_frame_past_the_hold() -> void:
	assert_eq(EndingScreen.HOLD_FRAME, 900)
	assert_eq(EndingScreen.clamp_frames(5000), 900)
	assert_eq(EndingScreen.clamp_frames(-5), 0)
	for frame: int in [EndingScreen.NIBBLE_START_FRAME, EndingScreen.FULL_FRAME, EndingScreen.COMMIT_START_FRAME,
			EndingScreen.LINE_FRAME, EndingScreen.SUMMARY_FRAME, EndingScreen.CREDITS_AFTER_SUMMARY_FRAME]:
		assert_lt(frame, EndingScreen.HOLD_FRAME)


func test_nibble_cells_light_one_at_a_time() -> void:
	assert_eq(EndingScreen.nibble_cells_lit(0), 0)
	assert_eq(EndingScreen.nibble_cells_lit(29), 0)
	assert_eq(EndingScreen.nibble_cells_lit(30), 1)
	assert_eq(EndingScreen.nibble_cells_lit(44), 1)
	assert_eq(EndingScreen.nibble_cells_lit(45), 2)
	assert_eq(EndingScreen.nibble_cells_lit(60), 3)
	assert_eq(EndingScreen.nibble_cells_lit(75), 4)
	assert_eq(EndingScreen.nibble_cells_lit(900), 4, "never more than the nibble")
	assert_false(EndingScreen.full_shown(74))
	assert_true(EndingScreen.full_shown(75), "0xFF from frame 75")


func test_register_row_lights_the_reserved_nibble() -> void:
	assert_eq(EndingScreen.register_row(0), "00001111", "the owned nibble is full, the reserved one dark")
	assert_eq(EndingScreen.register_row(2), "11001111")
	assert_eq(EndingScreen.register_row(4), "11111111", "1111: a full byte")


func test_commit_is_typed_at_twenty_characters_per_second() -> void:
	assert_eq(EndingScreen.TEXT.commit_message.length(), 15)
	assert_eq(EndingScreen.typed_chars(89), 0)
	assert_eq(EndingScreen.typed_chars(90), 0)
	assert_eq(EndingScreen.typed_chars(93), 1, "one character every 3 frames")
	assert_eq(EndingScreen.typed_chars(90 + 44), 14)
	assert_eq(EndingScreen.typed_chars(90 + 45), 15, "15 characters in 0.75 s")
	assert_eq(EndingScreen.typed_chars(299), 15, "stops at the message length")
	assert_eq(EndingScreen.typed_chars(900), 15)


func test_credits_and_summary_frames() -> void:
	assert_eq(EndingScreen.credits_start_frame(false), 360)
	assert_eq(EndingScreen.credits_start_frame(true), 540)
	assert_false(EndingScreen.credits_visible(359, false))
	assert_true(EndingScreen.credits_visible(360, false))
	assert_false(EndingScreen.credits_visible(539, true))
	assert_true(EndingScreen.credits_visible(540, true))


func test_summary_visible_rule() -> void:
	assert_false(EndingScreen.summary_visible(359, true, false), "not before 360")
	assert_true(EndingScreen.summary_visible(360, true, false), "flag on, no debug jump")
	assert_true(EndingScreen.summary_visible(900, true, false), "stays with the credits")
	assert_false(EndingScreen.summary_visible(400, false, false), "flag off: no card")
	assert_false(EndingScreen.summary_visible(400, true, true), "a debug-jumped run: no card")


func test_format_clear() -> void:
	assert_eq(EndingScreen.format_clear(0), "0:00")
	assert_eq(EndingScreen.format_clear(59), "0:00", "floored")
	assert_eq(EndingScreen.format_clear(60), "0:01")
	assert_eq(EndingScreen.format_clear(3599), "0:59")
	assert_eq(EndingScreen.format_clear(3600), "1:00")
	assert_eq(EndingScreen.format_clear(59 * 3600 + 59 * 60), "59:59")
	assert_eq(EndingScreen.format_clear(-10), "0:00")


func test_summary_rows() -> void:
	var rows: PackedStringArray = EndingScreen.summary_rows({&"clear_frames": 125 * 60, &"hits": 7})
	assert_eq(rows, PackedStringArray(["CLEAR 2:05", "HITS 7"]))


func test_leave_rule() -> void:
	assert_true(EndingScreen.leave_allowed(_key(KEY_A)))
	assert_true(EndingScreen.leave_allowed(_key(KEY_SPACE)))
	assert_true(EndingScreen.leave_allowed(_click()), "a left click leaves")
	for code: Key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_ESCAPE, KEY_F1, KEY_F5, KEY_F12]:
		assert_false(EndingScreen.leave_allowed(_key(code)), "rejected: %s" % OS.get_keycode_string(code))
	assert_false(EndingScreen.leave_allowed(_key(KEY_P)), "P pauses (D-FIX-FS-1)")
	assert_false(EndingScreen.leave_allowed(_key(KEY_A, false)), "key-up")
	assert_false(EndingScreen.leave_allowed(_key(KEY_A, true, true)), "echo")
	assert_false(EndingScreen.leave_allowed(_click(MOUSE_BUTTON_RIGHT)))


func test_line_is_requested_once_at_frame_300() -> void:
	var screen: EndingScreen = _screen(1000)
	var requested: Array[StringName] = []
	screen.say_line = func(id: StringName) -> void: requested.append(id)
	assert_true(screen.poll(1000))
	assert_true(screen.poll(1299))
	assert_eq(requested.size(), 0, "not before frame 300")
	screen.poll(1300)
	assert_eq(requested, [&"ending"] as Array[StringName])
	screen.poll(1301)
	screen.poll(1900)
	screen.poll(5000)
	assert_eq(requested.size(), 1, "requested once per ending")


func test_poll_never_leaves_the_ending() -> void:
	var screen: EndingScreen = _screen(1000)
	screen.say_line = func(_id: StringName) -> void: pass
	assert_true(screen.poll(1000 + 900))
	assert_true(screen.poll(1000 + 100000), "the hold waits for the player (D-S68-1)")
	assert_eq(Game.flow_state, S.ENDING)
	assert_eq(screen.shown_beat, B.HOLD)
	assert_eq(screen.timeline_frame, 900, "clamped at the hold")


func test_fade_in() -> void:
	var screen: EndingScreen = _screen(1000)
	screen.poll(1000)
	assert_eq(screen.modulate.a, 0.0)
	screen.poll(1015)
	assert_almost_eq(screen.modulate.a, 0.5, 0.001)
	screen.poll(1030)
	assert_eq(screen.modulate.a, 1.0)


func test_summary_shown_follows_the_flag_and_the_debug_flag() -> void:
	var screen: EndingScreen = _screen(0)
	assert_false(screen.summary_shown(), "the default is off; Main sets it from the flag")
	screen.summary_enabled = true
	assert_true(screen.summary_shown())
	Game.ending_summary = {&"clear_frames": 10, &"hits": 1, &"debug_jumped": true}
	assert_false(screen.summary_shown(), "a debug-jumped run shows no card")
	Game.ending_summary = {}
	assert_false(screen.summary_shown(), "no snapshot: no card")


func test_try_leave_respects_the_gate() -> void:
	var screen: EndingScreen = _screen(SimClock.sim_frame)
	var start: int = Game.ending_start_frame
	assert_false(screen.try_leave(start), "the entry frame")
	assert_false(screen.try_leave(start + 60), "the gate")
	assert_eq(Game.flow_state, S.ENDING)


func test_screen_name_and_no_game_text_literal() -> void:
	assert_eq(EndingScreen.new().name, &"EndingScreen")
	var src: String = FileAccess.get_file_as_string("res://src/ui/screens/ending/ending_screen.gd")
	var text: EndingText = load(TEXT_PATH)
	for t: String in text.all_text():
		if t.length() < 2:
			continue # single glyphs ("1", "0", "_") match too much code to be meaningful
		assert_false(src.contains("\"%s\"" % t), "AC 18: '%s' is data, not a literal" % t)


func test_ending_text_data() -> void:
	var text: EndingText = load(TEXT_PATH)
	assert_not_null(text)
	assert_eq(text.validate(), PackedStringArray())
	assert_eq(text.commit_message, "fix: wild shift", "GDD Ending row")
	assert_eq(text.full_caption, "0xFF")
	assert_eq(text.prompt, "press any key")
	assert_eq(text.credit_lines.size(), 4, "font, voice, code licence, audio placeholder")
	var credits: String = "\n".join(text.credit_lines)
	assert_string_contains(credits, "Wildshift8 by Tiziano Basile")
	assert_string_contains(credits, "mumble-speech by basteez (MIT / Apache-2.0)")
	assert_string_contains(credits, "MIT")
	assert_string_contains(credits, "audio:")
	for line: String in text.credit_lines:
		var x: int = EndingScreen.centred_x(line, EndingScreen.SMALL_SCALE)
		assert_gte(x, 96, "right of the HUD duck region: %s" % line)
		assert_lte(x + GlyphFont.text_width(line, EndingScreen.SMALL_SCALE), Const.BASE_RES.x, "fits 640: %s" % line)
	assert_lte(EndingScreen.CREDITS_Y + text.credit_lines.size() * EndingScreen.CREDITS_ROW_STEP, EndingScreen.PROMPT_Y)
	assert_lte(EndingScreen.PROMPT_Y + GlyphFont.size_for(EndingScreen.TEXT_SCALE), Const.BASE_RES.y, "fits 360")


func test_ending_text_validation_reports_bad_values() -> void:
	var text := EndingText.new()
	assert_gt(text.validate().size(), 0, "no credit lines")
	text.credit_lines = PackedStringArray(["x"])
	assert_eq(text.validate().size(), 0)
	text.commit_message = ""
	assert_gt(text.validate().size(), 0, "empty commit message")
	text.commit_message = "ok"
	text.credit_lines = PackedStringArray(["x".repeat(57)])
	assert_gt(text.validate().size(), 0, "credit line too wide")
	text.credit_lines = PackedStringArray(["café"])
	assert_gt(text.validate().size(), 0, "non-ASCII")


func test_draw_is_ink_only() -> void:
	# AC 19: the screen only ever uses the two glyph colours (the ink rule of GlyphFont).
	var src: String = FileAccess.get_file_as_string("res://src/ui/screens/ending/ending_screen.gd")
	assert_false(src.contains("Palette.WARN"), "red is reserved for warnings")
