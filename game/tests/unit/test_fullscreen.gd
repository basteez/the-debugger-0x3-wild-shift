extends GutTest
## Story 7.7 (FR55, AC 1-7, D-S77-1): the fullscreen helper, the title row and the pause row.
## A fake display (Fullscreen.get_mode_fn / set_mode_fn) stands in for the headless DisplayServer.

const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const GameScript := preload("res://src/autoloads/game.gd")
const W := DisplayServer.WINDOW_MODE_WINDOWED
const FS := DisplayServer.WINDOW_MODE_FULLSCREEN

var _saved_get: Callable
var _saved_set: Callable
var _saved_warned: bool
var _saved_paused: bool
var _saved_flow: int
var _saved_save: Dictionary = {}
var _saved_unlocked: bool
## The fake window mode; `honour` false makes every request a no-op (a refused request).
var _mode: DisplayServer.WindowMode = W
var _honour: bool = true
var _set_calls: int = 0


func before_each() -> void:
	_saved_get = Fullscreen.get_mode_fn
	_saved_set = Fullscreen.set_mode_fn
	_saved_warned = Fullscreen.warned
	_saved_paused = SimClock.paused
	_saved_flow = Game.flow_state
	_saved_save = {"path": SaveService.path, "highest_boss": SaveService.highest_boss, "assist": SaveService.assist, "muted": SaveService.muted}
	_saved_unlocked = AudioManager.is_unlocked()
	SaveService.path = ""
	_mode = W
	_honour = true
	_set_calls = 0
	Fullscreen.get_mode_fn = func() -> DisplayServer.WindowMode: return _mode
	Fullscreen.set_mode_fn = func(m: DisplayServer.WindowMode) -> void:
		_set_calls += 1
		if _honour:
			_mode = m


func after_each() -> void:
	Fullscreen.get_mode_fn = _saved_get
	Fullscreen.set_mode_fn = _saved_set
	Fullscreen.warned = _saved_warned
	SimClock.paused = _saved_paused
	Game.flow_state = _saved_flow as GameScript.FlowState
	for key: String in _saved_save:
		SaveService.set(key, _saved_save[key])
	if not _saved_unlocked: # the title press unlocks audio; later suites expect it locked
		AudioManager.set("_unlocked", false)


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _click(pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	return ev


# --- Helper (AC 1, 5) -----------------------------------------------------------------------------

func test_mode_mapping() -> void:
	assert_true(Fullscreen.is_fullscreen(FS))
	assert_true(Fullscreen.is_fullscreen(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN))
	assert_false(Fullscreen.is_fullscreen(W))
	assert_false(Fullscreen.is_fullscreen(DisplayServer.WINDOW_MODE_MAXIMIZED))
	assert_eq(Fullscreen.toggle_mode(W), FS)
	assert_eq(Fullscreen.toggle_mode(DisplayServer.WINDOW_MODE_MAXIMIZED), FS)
	assert_eq(Fullscreen.toggle_mode(FS), W)
	assert_eq(Fullscreen.toggle_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN), W)


func test_toggle_twice_returns_to_windowed() -> void:
	assert_eq(Fullscreen.toggle(), FS)
	assert_true(Fullscreen.is_on())
	assert_eq(Fullscreen.toggle(), W)
	assert_false(Fullscreen.is_on())


func test_refused_request_warns_once_and_stays_windowed() -> void:
	_honour = false
	Fullscreen.warned = false
	Fullscreen.toggle()
	assert_false(Fullscreen.is_on(), "stays windowed")
	assert_true(Fullscreen.check_request(FS), "refusal detected")
	assert_true(Fullscreen.warned, "one Log.warn")
	assert_true(Fullscreen.check_request(FS), "still refused, no second warning (flag stays set)")
	_honour = true
	Fullscreen.toggle()
	assert_false(Fullscreen.check_request(FS), "an honoured request is not a refusal")
	assert_true(Fullscreen.is_refused(FS, W))
	assert_true(Fullscreen.is_refused(W, FS))
	assert_false(Fullscreen.is_refused(W, DisplayServer.WINDOW_MODE_MAXIMIZED))


# --- Title row (AC 1-3, 6, 7) ---------------------------------------------------------------------

func test_title_row_text_and_rect() -> void:
	assert_eq(TitleScreenScript.FULLSCREEN_TOP_Y, 336)
	assert_eq(TitleScreenScript.fullscreen_text(false), "[F] fullscreen")
	assert_eq(TitleScreenScript.fullscreen_text(true), "[F] windowed")
	for on: bool in [false, true]:
		var rect: Rect2 = TitleScreenScript.fullscreen_label_rect(on)
		assert_true(rect.end.y <= Const.BASE_RES.y, "on screen")
		assert_false(rect.intersects(TitleScreenScript.practice_label_rect()), "below the practice row")
		assert_true(rect.has_point(Vector2(TitleScreenScript.centred_x(TitleScreenScript.fullscreen_text(on)) + 4, 340)))


func test_title_f_r3_and_click_toggle_without_leaving_title() -> void:
	Game.flow_state = Game.FlowState.TITLE
	var paused_before: bool = SimClock.paused
	var hb_before: int = SaveService.highest_boss
	var title: TitleScreen = autofree(TitleScreenScript.new())
	assert_true(title.is_option_available(&"fullscreen"))
	var events: Array[InputEvent] = [
		_key(KEY_F), _key(KEY_F), _pad(JOY_BUTTON_RIGHT_STICK), _pad(JOY_BUTTON_RIGHT_STICK),
		_click(TitleScreenScript.fullscreen_label_rect(false).get_center()),
	]
	var expected: Array[bool] = [true, false, true, false, true]
	for i: int in events.size():
		assert_eq(title.handle_input(events[i]), TitleScreenScript.Action.OPTION, "event %d is the option" % i)
		assert_eq(Fullscreen.is_on(), expected[i], "event %d toggles" % i)
		assert_eq(Game.flow_state, Game.FlowState.TITLE, "never starts the run")
	assert_eq(SimClock.paused, paused_before, "never touches the pause")
	assert_eq(SaveService.highest_boss, hb_before, "never touches the save")
	assert_eq(_set_calls, 5)


func test_title_label_follows_the_real_mode() -> void:
	var title: TitleScreen = autofree(TitleScreenScript.new())
	title.set_fullscreen_shown(false)
	_mode = FS # e.g. the request completed, or the browser left fullscreen on Esc in reverse
	title._process(0.0)
	assert_true(title.fullscreen_shown)
	assert_eq(title.label_rects[&"fullscreen"], TitleScreenScript.fullscreen_label_rect(true))
	_mode = W
	title._process(0.0)
	assert_false(title.fullscreen_shown)


func test_f_is_not_a_function_key_and_has_no_other_binding() -> void:
	assert_false(TitleScreenScript.is_function_key(KEY_F))
	for action: StringName in InputMap.get_actions():
		if action == &"title_option_fullscreen":
			continue
		assert_false(InputMap.event_is_action(_key(KEY_F), action, true), "F is bound to %s" % action)
		assert_false(InputMap.event_is_action(_pad(JOY_BUTTON_RIGHT_STICK), action, true), "R3 is bound to %s" % action)


# --- Pause row (AC 4, 7) --------------------------------------------------------------------------

func test_pause_row_layout() -> void:
	assert_eq(PauseScreen.lines_for(false, false, false)[-1], "[F] FULLSCREEN OFF")
	assert_eq(PauseScreen.lines_for(false, false, true)[-1], "[F] FULLSCREEN ON")
	assert_eq(PauseScreen.row_tops()[-1], PauseScreen.FULLSCREEN_TOP_Y)
	assert_eq(PauseScreen.lines_for(false).size(), PauseScreen.row_tops().size())
	var rect: Rect2 = PauseScreen.fullscreen_label_rect(false)
	assert_false(rect.intersects(PauseScreen.assist_label_rect(false)), "does not overlap the assist row")
	assert_true(rect.end.y <= Const.BASE_RES.y)


func test_pause_is_fullscreen_toggle() -> void:
	assert_true(PauseScreen.is_fullscreen_toggle(_key(KEY_F), false))
	assert_true(PauseScreen.is_fullscreen_toggle(_pad(JOY_BUTTON_RIGHT_STICK), false))
	assert_false(PauseScreen.is_fullscreen_toggle(_key(KEY_F, true, true), false), "echo ignored")
	assert_false(PauseScreen.is_fullscreen_toggle(_key(KEY_B), false), "B is the assist")
	assert_false(PauseScreen.is_fullscreen_toggle(_key(KEY_ESCAPE), false), "Esc belongs to Game")
	assert_true(PauseScreen.is_fullscreen_toggle(_click(PauseScreen.fullscreen_label_rect(true).get_center()), true))
	assert_false(PauseScreen.is_fullscreen_toggle(_click(PauseScreen.assist_label_rect(false).get_center()), false))
	assert_false(PauseScreen.is_assist_toggle(_key(KEY_F), false), "F is not the assist")
	assert_false(PauseScreen.is_mute_toggle(_key(KEY_F), false), "F is not the mute")


func test_pause_f_toggles_and_stays_paused() -> void:
	SimClock.paused = true
	var assist_before: bool = SaveService.assist
	var pause: Node2D = PauseScreen.new()
	add_child_autofree(pause)
	pause._input(_key(KEY_F))
	assert_true(Fullscreen.is_on())
	assert_true(SimClock.paused, "never resumes")
	pause._input(_pad(JOY_BUTTON_RIGHT_STICK))
	assert_false(Fullscreen.is_on())
	pause._input(_click(PauseScreen.fullscreen_label_rect(false).get_center()))
	assert_true(Fullscreen.is_on())
	assert_true(SimClock.paused)
	assert_eq(SaveService.assist, assist_before, "the save is untouched")


func test_stale_check_is_superseded() -> void:
	Fullscreen.warned = false
	Fullscreen.request_id = 5
	# An older request (id 4) must not warn even though the mode "was refused".
	Fullscreen.get_mode_fn = func() -> DisplayServer.WindowMode: return DisplayServer.WINDOW_MODE_WINDOWED
	Fullscreen._check_if_latest(DisplayServer.WINDOW_MODE_FULLSCREEN, 4)
	assert_false(Fullscreen.warned, "stale check dropped")
