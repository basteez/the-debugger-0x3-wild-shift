extends GutTest
## Story 1.7 AC2/AC4 (DC1-DC5, DC9): Game owns SimClock.paused; Esc and focus loss pause only in
## INTRO and FIGHT, focus return never resumes, nothing advances while paused.

const GameScript := preload("res://src/autoloads/game.gd")
const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const S := GameScript.FlowState

var _saved_paused: bool
var _saved_frame: int
var _saved_enabled: bool


func before_each() -> void:
	_saved_paused = SimClock.paused
	_saved_frame = SimClock.sim_frame
	_saved_enabled = Debug.enabled
	SimClock.paused = false


func after_each() -> void:
	SimClock.paused = _saved_paused
	SimClock.sim_frame = _saved_frame
	Debug.enabled = _saved_enabled


func _game(state: S = S.FIGHT) -> Node:
	var game: Node = autofree(GameScript.new())
	game.flow_state = state
	return game


func _esc(pressed: bool = true, echo: bool = false) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = pressed
	key.echo = echo
	return key


func test_pause_in_fight_and_intro_sets_the_clock_and_emits_once() -> void:
	watch_signals(EventBus)
	var expected: int = 0
	for state: S in [S.FIGHT, S.INTRO]:
		SimClock.paused = false
		var game: Node = _game(state)
		assert_true(game.set_paused(true, &"esc"))
		assert_true(SimClock.paused, "paused in %s" % S.keys()[state])
		assert_true(game.set_paused(true, &"focus"), "already paused is accepted")
		expected += 1
		assert_signal_emit_count(EventBus, "pause_toggled", expected, "one emit in %s" % S.keys()[state])
	assert_signal_emitted_with_parameters(EventBus, "pause_toggled", [true])


func test_pause_refused_outside_intro_and_fight() -> void:
	for state: S in [S.TITLE, S.HARVEST, S.ENDING, S.DEAD]:
		var game: Node = _game(state)
		watch_signals(EventBus)
		assert_false(game.set_paused(true, &"esc"), "refused in %s" % S.keys()[state])
		assert_false(SimClock.paused)
		assert_signal_not_emitted(EventBus, "pause_toggled")


func test_esc_press_toggles_pause() -> void:
	var game: Node = _game()
	assert_true(GameScript.is_pause_press(_esc()))
	assert_false(GameScript.is_pause_press(_esc(false)), "release is not a press")
	assert_false(GameScript.is_pause_press(_esc(true, true)), "echo is not a press")
	assert_true(game.handle_pause_input(_esc()))
	assert_true(SimClock.paused)
	assert_true(game.handle_pause_input(_esc()))
	assert_false(SimClock.paused, "Esc again resumes")


func test_esc_is_not_consumed_outside_pausable_states() -> void:
	var game: Node = _game(S.TITLE)
	assert_false(game.handle_pause_input(_esc()), "title sees Esc and ignores it")
	assert_false(SimClock.paused)


func test_other_keys_do_not_pause() -> void:
	var game: Node = _game()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	assert_false(game.handle_pause_input(key))
	assert_false(SimClock.paused)


func test_focus_out_pauses_and_focus_in_does_not_resume() -> void:
	var game: Node = _game()
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(SimClock.paused)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_true(SimClock.paused, "focus return never resumes")


func test_web_window_focus_out_pauses() -> void:
	# On web the engine sends only WM_WINDOW_FOCUS_OUT (canvas blur), never APPLICATION_FOCUS_OUT.
	var game: Node = _game()
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_true(SimClock.paused)


func test_focus_loss_notifications() -> void:
	assert_true(GameScript.is_focus_lost_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT))
	assert_true(GameScript.is_focus_lost_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT))
	assert_false(GameScript.is_focus_lost_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN))
	assert_false(GameScript.is_focus_lost_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN))


func test_web_focus_loss_rule() -> void:
	assert_true(GameScript.is_web_focus_loss("blur", false))
	assert_true(GameScript.is_web_focus_loss("visibilitychange", true))
	assert_false(GameScript.is_web_focus_loss("visibilitychange", false), "tab shown again never resumes or pauses")
	assert_false(GameScript.is_web_focus_loss("focus", false))


func test_focus_loss_outside_pausable_state_is_ignored() -> void:
	var game: Node = _game(S.TITLE)
	game.on_focus_lost()
	assert_false(SimClock.paused)


func test_advance_and_finish_intro_do_nothing_while_paused() -> void:
	var game: Node = _game()
	game.set_paused(true, &"esc")
	watch_signals(EventBus)
	game.advance()
	assert_eq(game.flow_state, S.FIGHT)
	var intro: Node = _game(S.INTRO)
	intro.first_input_frame = 0
	intro.intro_start_frame = 0
	assert_false(intro.finish_intro(10, true), "skip refused while paused")
	assert_false(intro.finish_intro(GameScript.INTRO_MAX_FRAMES + 1), "timeout refused while paused")
	assert_eq(intro.flow_state, S.INTRO)
	assert_signal_not_emitted(EventBus, "flow_state_changed")


func test_flow_change_clears_pause() -> void:
	Debug.enabled = true
	var game: Node = _game()
	game.set_paused(true, &"esc")
	watch_signals(EventBus)
	game.debug_jump(S.ENDING, 0)
	assert_false(SimClock.paused)
	assert_eq(game.flow_state, S.ENDING)
	assert_signal_emitted_with_parameters(EventBus, "pause_toggled", [false])
	assert_signal_emit_count(EventBus, "pause_toggled", 1)


func test_flow_change_without_pause_does_not_emit_pause() -> void:
	var game: Node = _game()
	watch_signals(EventBus)
	game.advance()
	assert_signal_not_emitted(EventBus, "pause_toggled")


func test_sim_frame_frozen_while_paused() -> void:
	var game: Node = _game()
	var clock: Node = SimClockScript.new()
	game.set_paused(true, &"esc")
	clock.paused = SimClock.paused
	for i: int in 120:
		clock.call(&"_physics_process", 1.0 / 60.0)
	assert_eq(clock.get("sim_frame"), 0, "no advance while paused")
	game.set_paused(false, &"esc")
	clock.paused = SimClock.paused
	for i: int in 60:
		clock.call(&"_physics_process", 1.0 / 60.0)
	assert_eq(clock.get("sim_frame"), 60)
	clock.free()
