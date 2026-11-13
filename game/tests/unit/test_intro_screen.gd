extends GutTest
## Story 6.7 (D1; AC 1, 2, 5, 6, 8, 9, 13): the Intro panels by sim frame, the 480-frame total, the
## skip rule and the title-frame gate, the panel 2 squeak and panel 3 line latches, and the screen's
## presentation-only rule. The full TITLE -> INTRO -> FIGHT flow is tests/integration/test_intro_flow.gd.

const GameScript := preload("res://src/autoloads/game.gd")
const IntroScript := preload("res://src/ui/screens/intro/intro_screen.gd")
const IsolationScript := preload("res://tests/unit/test_attack_isolation.gd")
const S := GameScript.FlowState

var _saved_state: int
var _saved_run: RunState
var _saved_first: int
var _saved_start: int
var _saved_paused: bool
var _squeaks: int
var _lines: Array[StringName]


func before_each() -> void:
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_first = Game.first_input_frame
	_saved_start = Game.intro_start_frame
	_saved_paused = SimClock.paused
	SimClock.paused = false
	_squeaks = 0
	_lines = []


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Game.first_input_frame = _saved_first
	Game.intro_start_frame = _saved_start
	SimClock.paused = _saved_paused


## An Intro screen with counting seams, Game put in INTRO started at `start` (no flow signal).
func _screen(start: int) -> IntroScreen:
	Game.flow_state = S.INTRO
	Game.run = RunState.new()
	Game.first_input_frame = start
	Game.intro_start_frame = start
	var screen: IntroScreen = IntroScript.new()
	screen.squeak = func() -> void: _squeaks += 1
	screen.say_line = func(id: StringName) -> void: _lines.append(id)
	screen.set_physics_process(false) # driven by poll(frame) here
	add_child_autofree(screen)
	return screen


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	return e


func _click(button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


# --- panels and timing (AC 1, 2) ---

func test_panel_boundaries() -> void:
	assert_eq(IntroScreen.PANEL_FRAMES, 150, "2.5 s at 60 Hz")
	assert_eq(IntroScreen.PANELS_END_FRAMES, 450)
	var cases: Dictionary[int, int] = {-1: -1, 0: 0, 149: 0, 150: 1, 299: 1, 300: 2, 449: 2, 450: -1, 479: -1}
	for f: int in cases:
		assert_eq(IntroScreen.panel_at(f), cases[f], "panel at f=%d" % f)


func test_panels_fit_inside_the_cap_and_the_hold_shows_panel_3() -> void:
	assert_eq(GameScript.INTRO_MAX_FRAMES, 480, "the cap is unchanged (D-S67-1)")
	for f: int in GameScript.INTRO_MAX_FRAMES:
		assert_lte(IntroScreen.panel_at(f), 2)
	assert_false(IntroScreen.hold_started(449))
	assert_true(IntroScreen.hold_started(450))
	assert_eq(GameScript.INTRO_MAX_FRAMES - IntroScreen.PANELS_END_FRAMES, 30, "a 30-frame hold")
	assert_eq(IntroScreen.display_panel(0), 0)
	assert_eq(IntroScreen.display_panel(450), 2, "panel 3 stays up through the hold")
	assert_eq(IntroScreen.display_panel(479), 2)


func test_captions_are_three_panels_of_ink_text() -> void:
	for p: int in IntroScreen.PANEL_COUNT:
		assert_gt(IntroScreen.caption_for(p).size(), 0, "panel %d has a caption" % p)
	assert_eq(IntroScreen.caption_for(3).size(), 0)
	assert_true(IntroScreen.text_rows().has("The Clearing"))


func test_tear_offset_is_bounded_and_moves() -> void:
	var seen: Dictionary[int, bool] = {}
	for f: int in 24:
		var x: int = IntroScreen.tear_offset(f)
		assert_lte(absi(x), IntroScreen.TEAR_JITTER_PX)
		seen[x] = true
	assert_eq(seen.size(), 3, "0, +jitter, -jitter")


# --- skip rule (AC 5, 6, D-S67-4) ---

func test_skip_rule() -> void:
	assert_true(IntroScreen.skip_allowed(_key(KEY_SPACE)))
	assert_true(IntroScreen.skip_allowed(_key(KEY_J)))
	assert_true(IntroScreen.skip_allowed(_click()), "a left click skips")
	for code: Key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_ESCAPE, KEY_F1, KEY_F9, KEY_P]:
		assert_false(IntroScreen.skip_allowed(_key(code)), "key %d never skips" % code)
	assert_false(IntroScreen.skip_allowed(_key(KEY_SPACE, false)), "key-up")
	assert_false(IntroScreen.skip_allowed(_key(KEY_SPACE, true, true)), "echo")
	assert_false(IntroScreen.skip_allowed(_click(MOUSE_BUTTON_RIGHT)), "right click")
	assert_false(IntroScreen.skip_allowed(_click(MOUSE_BUTTON_LEFT, false)), "button release")


func test_title_frame_never_skips_and_the_next_frame_does() -> void:
	var screen: IntroScreen = _screen(100)
	assert_false(Game.can_skip_intro(100))
	assert_false(screen.try_skip(100), "the title input frame is never a skip")
	assert_eq(Game.flow_state, S.INTRO)
	assert_true(Game.can_skip_intro(101))
	assert_true(screen.try_skip(101))
	assert_eq(Game.flow_state, S.FIGHT)


func test_a_paused_intro_never_skips_advances_or_times_out() -> void:
	var screen: IntroScreen = _screen(100)
	SimClock.paused = true
	assert_false(screen.try_skip(150), "no skip while paused")
	assert_true(screen.poll(100 + GameScript.INTRO_MAX_FRAMES + 50), "no timeout while paused")
	assert_eq(Game.flow_state, S.INTRO)


# --- squeak and duck line 1 (AC 8, 9) ---

func test_squeak_on_panel_2_and_the_line_on_panel_3_once_each() -> void:
	var screen: IntroScreen = _screen(0)
	for f: int in 150:
		assert_true(screen.poll(f))
	assert_eq(screen.shown_panel, 0)
	assert_eq(_squeaks, 0, "no squeak on panel 1")
	assert_true(screen.poll(150))
	assert_eq(screen.shown_panel, 1)
	assert_eq(_squeaks, 1, "the squeeze quacks at the start of panel 2")
	for f: int in range(151, 300):
		screen.poll(f)
	assert_eq(_lines.size(), 0, "no line before panel 3")
	assert_true(screen.poll(300))
	assert_eq(_lines, [IntroScreen.LINE_ID] as Array[StringName], "line 1 at frame 300")
	for f: int in range(301, 480):
		assert_true(screen.poll(f))
	assert_eq(_squeaks, 1, "once")
	assert_eq(_lines.size(), 1, "once")
	assert_false(screen.poll(480), "the cap ends the Intro at 480")
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(Game.run.boss_index, 0)


func test_a_skip_before_panel_3_never_requests_the_line() -> void:
	var screen: IntroScreen = _screen(0)
	for f: int in 200:
		screen.poll(f)
	assert_true(screen.try_skip(200))
	assert_false(screen.poll(300))
	assert_eq(_lines.size(), 0, "never requested")


# --- presentation only (AC 13) ---

func test_intro_screen_never_writes_sim_or_flow_state() -> void:
	var code: String = IsolationScript.code_of("res://src/ui/screens/intro/intro_screen.gd")
	for banned: String in ["flow_state =", "_set_flow_state", "SimClock.tick", "buffer.push", "sim_frame =", "SimClock.paused =", "run.start_boss", "FeatureFlags"]:
		assert_false(code.contains(banned), "intro_screen.gd must not contain %s" % banned)
