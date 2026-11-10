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


func test_blur_in_title_pauses_on_entering_intro() -> void:
	var game: Node = _game(S.TITLE)
	game.on_focus_lost()
	assert_false(SimClock.paused, "TITLE is not pausable")
	game.start_run_from_title(0)
	assert_true(SimClock.paused, "the remembered blur pauses on INTRO")


func test_focus_return_forgets_a_blur_seen_in_title() -> void:
	var game: Node = _game(S.TITLE)
	game.on_focus_lost()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.start_run_from_title(0)
	assert_false(SimClock.paused)


func test_focus_gained_notifications() -> void:
	assert_true(GameScript.is_focus_gained_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN))
	assert_true(GameScript.is_focus_gained_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN))
	assert_false(GameScript.is_focus_gained_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT))


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


# --- D-FIX-FS-1: resume with P or a click (fullscreen Esc lock) ---

func _p() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = true
	return key


func _click(button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	click.position = Vector2(320, 180)
	return click


func test_p_press_toggles_pause_like_esc() -> void:
	var game: Node = _game()
	assert_true(GameScript.is_pause_press(_p()))
	assert_true(game.handle_pause_input(_p()))
	assert_true(SimClock.paused)
	assert_true(game.handle_pause_input(_p()))
	assert_false(SimClock.paused, "P again resumes")


func test_p_is_not_consumed_in_title_so_practice_still_works() -> void:
	var game: Node = _game(S.TITLE)
	assert_false(game.handle_pause_input(_p()))
	assert_false(SimClock.paused)


func test_left_click_rule() -> void:
	assert_true(GameScript.is_left_click(_click()))
	assert_false(GameScript.is_left_click(_click(MOUSE_BUTTON_LEFT, false)), "release is not a click")
	assert_false(GameScript.is_left_click(_click(MOUSE_BUTTON_RIGHT)))
	assert_false(GameScript.is_left_click(_p()))


func test_click_resume_guard_rule() -> void:
	var guard: int = GameScript.CLICK_RESUME_GUARD_MSEC
	assert_false(GameScript.click_resume_allowed(1000, 1000), "the click that came with the pause")
	assert_false(GameScript.click_resume_allowed(1000, 1000 + guard - 1))
	assert_true(GameScript.click_resume_allowed(1000, 1000 + guard))
	assert_true(GameScript.click_resume_allowed(-1, 0), "unknown start never locks the game")


func test_click_resumes_after_the_guard() -> void:
	var game: Node = _game()
	game.on_focus_lost()
	assert_true(SimClock.paused)
	var at: int = game._paused_at_msec
	assert_gte(at, 0, "the pause start is recorded")
	assert_false(game.handle_resume_click(_click(), at + 10), "a click moments after the pause is ignored")
	assert_true(SimClock.paused)
	assert_false(game.handle_resume_click(_click(MOUSE_BUTTON_RIGHT), at + 1000), "right click never resumes")
	assert_true(game.handle_resume_click(_click(), at + 1000))
	assert_false(SimClock.paused, "a later click resumes")
	assert_eq(game._paused_at_msec, -1)


func test_click_clears_a_remembered_blur() -> void:
	var game: Node = _game()
	game.on_focus_lost()
	game.handle_resume_click(_click(), game._paused_at_msec + 1000)
	assert_false(game._focus_lost, "a click on the game proves focus")


func test_click_does_nothing_when_not_paused() -> void:
	for state: S in [S.FIGHT, S.INTRO, S.TITLE, S.DEAD, S.HARVEST, S.ENDING]:
		var game: Node = _game(state)
		assert_false(game.handle_resume_click(_click(), 100000), "not consumed in %s" % S.keys()[state])
		assert_false(SimClock.paused)


func test_no_gameplay_action_binds_a_mouse_button() -> void:
	# The resume click is consumed and a paused tick never polls (D-S21-9); this keeps it that way.
	for action: StringName in LiveInput.BUFFERED_ACTIONS:
		for ev: InputEvent in InputMap.action_get_events(action):
			assert_false(ev is InputEventMouseButton, "%s binds a mouse button" % action)


func test_resumed_tick_never_fires_the_resume_press() -> void:
	# D-S21-9: a paused tick does not poll, so the press seen while paused is dropped.
	var game: Node = _game()
	game.set_paused(true, &"esc")
	var poll: int = SimClock.poll_frame
	SimClock.tick()
	assert_eq(SimClock.poll_frame, poll, "a paused tick never polls input")
	game.handle_resume_click(_click(), game._paused_at_msec + 1000)
	assert_false(SimClock.paused)


## D-FIX-FS-2 helper: swaps Game's web eval for a recorder; returns the list it appends to.
func _record_js(game: Node) -> Array[String]:
	var calls: Array[String] = []
	game._web_eval = func(code: String) -> void: calls.append(code)
	return calls


func test_every_left_click_refocuses_the_game_window() -> void:
	# Fix: after itch.io's fullscreen exit the parent page holds the focus while the canvas stays the
	# iframe's activeElement, so canvas.focus() alone was a no-op and the resumed game got no keys.
	for paused: bool in [true, false]:
		for state: S in [S.FIGHT, S.INTRO, S.TITLE, S.DEAD, S.HARVEST, S.ENDING]:
			var game: Node = _game(state)
			SimClock.paused = paused
			var calls: Array[String] = _record_js(game)
			assert_true(game.handle_click_refocus(_click()), "left click in %s" % S.keys()[state])
			assert_eq(calls.size(), 1)
			assert_true(calls[0].begins_with("window.focus();"), "the iframe window is focused first")
			assert_string_contains(calls[0], "c.focus()")
	SimClock.paused = false


func test_refocus_ignores_other_buttons_and_releases() -> void:
	var game: Node = _game()
	var calls: Array[String] = _record_js(game)
	assert_false(game.handle_click_refocus(_click(MOUSE_BUTTON_RIGHT)))
	assert_false(game.handle_click_refocus(_click(MOUSE_BUTTON_LEFT, false)))
	assert_false(game.handle_click_refocus(_p()))
	assert_eq(calls.size(), 0)


func test_refocus_never_consumes_or_resumes_by_itself() -> void:
	var game: Node = _game()
	game.set_paused(true, &"esc")
	_record_js(game)
	game.handle_click_refocus(_click())
	assert_true(SimClock.paused, "only handle_resume_click resumes")


func test_focus_loss_never_takes_focus_back_from_the_parent_page() -> void:
	var game: Node = _game()
	var calls: Array[String] = _record_js(game)
	game.on_focus_lost()
	assert_true(SimClock.paused)
	assert_eq(calls.size(), 1, "the canvas is still focused inside its own document")
	assert_false(calls[0].contains("window.focus"), "a blur never steals the focus back")
