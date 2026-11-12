extends GutTest
## Story 6.7 (D3; AC 1-5, 8, 9, 11, 13): Main, the title screen, the Intro screen, the autoload Game
## and SimClock. The title press opens the real IntroScreen with no arena and a duck-only HUD; a
## skip leads to FIGHT 1 at once, the cap at 480 sim frames without one; the panel 2 squeak and the
## panel 3 duck line are requested once each, and a skip before panel 3 never requests the line.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const INTRO_TEXT := "Quack. Explain the bug to me. Use these."

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_first: int
var _saved_start: int
var _saved_source: InputSource
var _saved_unlocked: bool
var _main: Node2D
var _squeaks: int


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_first = Game.first_input_frame
	_saved_start = Game.intro_start_frame
	_saved_source = SimClock.input_source
	_saved_unlocked = AudioManager.is_unlocked()
	SimClock.input_source = null # headless: no presses
	Debug.enabled = false # the flag-on, debug-off configuration
	SimClock.paused = false
	Game.run = RunState.new()
	Game.flow_state = S.TITLE
	Game.first_input_frame = -1
	Game.intro_start_frame = -1
	_squeaks = 0
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.apply_flow_state(S.TITLE, 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Game.first_input_frame = _saved_first
	Game.intro_start_frame = _saved_start
	Debug.enabled = _saved_enabled
	SimClock.input_source = _saved_source
	SimClock.begin_fight(0)
	SimClock.paused = false
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false)


func _tick(times: int) -> void:
	for i: int in times:
		SimClock.tick()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


## The title press (the only route into INTRO): returns the Intro screen Main built for it, with
## the squeak counted through its seam (the line goes through the real VoiceService).
func _press_title() -> IntroScreen:
	var title := _main.current_screen as TitleScreen
	assert_not_null(title, "the title screen")
	title.handle_input(_key(KEY_X))
	assert_eq(Game.flow_state, S.INTRO)
	var intro := _main.current_screen as IntroScreen
	assert_not_null(intro, "Main builds the real IntroScreen (AC 11)")
	intro.squeak = func() -> void: _squeaks += 1
	intro.set_physics_process(false) # stepped by hand after each tick
	return intro


## Ticks the sim to `frames` frames after the Intro start, polling the screen after each tick.
func _run_to(intro: IntroScreen, frames: int) -> void:
	while SimClock.sim_frame < Game.intro_start_frame + frames and Game.flow_state == S.INTRO:
		_tick(1)
		intro.poll(SimClock.sim_frame)


func test_title_press_intro_then_skip_to_fight_1() -> void:
	watch_signals(EventBus)
	var intro: IntroScreen = _press_title()
	assert_eq(intro.name, &"IntroScreen")
	assert_eq(intro.get_parent(), _main.get_node(^"Screens"))
	assert_false(_main.arena.visible, "no arena in INTRO (AC 3)")
	assert_true(_main.hud.visible)
	assert_true(_main.hud.is_duck_only(), "only the duck bubble of the HUD (D-S67-2)")
	assert_null(_main.arena.boss, "no boss in INTRO")
	# The title press frame never skips (AC 5).
	assert_false(intro.try_skip(Game.first_input_frame))
	assert_eq(Game.flow_state, S.INTRO)
	_run_to(intro, 320) # into panel 3
	assert_eq(intro.shown_panel, 2)
	assert_eq(_squeaks, 1, "the panel 2 squeak, once")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"intro_handover", INTRO_TEXT])
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)
	assert_true(_main.hud.duck_bubble.is_showing(), "the bubble shows line 1")
	# A skip during the line cuts it (AC 5).
	assert_true(intro.try_skip(SimClock.sim_frame))
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(Game.run.boss_index, 0)
	assert_true(_main.arena.visible, "Fight 1 shows the arena")
	assert_false(_main.hud.is_duck_only())
	assert_true(_main.current_screen is PlaceholderScreen, "FIGHT keeps the placeholder")
	assert_false(_main.hud.duck_bubble.is_showing(), "the intro line never finishes into Fight 1")
	assert_signal_emit_count(EventBus, "duck_line_requested", 1, "never again")


func test_title_press_intro_then_cap_to_fight_1() -> void:
	watch_signals(EventBus)
	var intro: IntroScreen = _press_title()
	var start: int = Game.intro_start_frame
	_run_to(intro, GameScript.INTRO_MAX_FRAMES - 1)
	assert_eq(Game.flow_state, S.INTRO, "479 frames: still on")
	assert_eq(intro.shown_panel, 2, "the hold shows panel 3")
	_run_to(intro, GameScript.INTRO_MAX_FRAMES)
	assert_eq(SimClock.sim_frame - start, GameScript.INTRO_MAX_FRAMES)
	assert_eq(Game.flow_state, S.FIGHT, "the 8 s cap (AC 2)")
	assert_true(_main.arena.visible)
	assert_eq(_squeaks, 1)
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"intro_handover", INTRO_TEXT])


func test_a_skip_before_panel_3_never_requests_the_line() -> void:
	watch_signals(EventBus)
	var intro: IntroScreen = _press_title()
	_run_to(intro, 1) # the first frame after the title press: the skip is open
	assert_true(intro.try_skip(SimClock.sim_frame), "skippable from its first frame")
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(_squeaks, 0)
	assert_signal_not_emitted(EventBus, "duck_line_requested")


func test_a_paused_intro_freezes_the_panels() -> void:
	var intro: IntroScreen = _press_title()
	_run_to(intro, 100)
	assert_true(Game.set_paused(true, &"esc"))
	var frame: int = SimClock.sim_frame
	_tick(400)
	intro.poll(SimClock.sim_frame)
	assert_eq(SimClock.sim_frame, frame, "no sim frame while paused")
	assert_eq(intro.shown_panel, 0)
	assert_false(intro.try_skip(frame + 1), "no skip while paused (AC 6)")
	assert_eq(Game.flow_state, S.INTRO)
	assert_true(Game.set_paused(false, &"esc"))
