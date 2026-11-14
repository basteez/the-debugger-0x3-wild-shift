extends GutTest
## Story 7.5 (FR61, AC 1-16): gamepad support. The pad events in the InputMap reach every action,
## the title classifier, the "any button" rule on the Intro / Harvest / Ending / DEAD screens, the
## pause screen's Select (mute) and B (assist), and Start as the pause press. No RNG here.
## Seam rule (7.3): SaveService runs with an empty path under GUT, so no test writes the real save.

const GameScript := preload("res://src/autoloads/game.gd")
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const S := GameScript.FlowState

## Gameplay actions (AC 1): every one needs at least one pad event.
const GAMEPLAY_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down",
		&"action_1", &"action_2", &"shift_left", &"shift_right", &"breakpoint", &"watch", &"pause"]

var _saved_paused: bool
var _saved_assist: bool
var _saved_muted: bool
var _saved_highest: int
var _saved_flow: int
var _saved_unlocked: bool


func before_each() -> void:
	_saved_paused = SimClock.paused
	_saved_assist = SaveService.assist
	_saved_muted = AudioManager.is_master_muted()
	_saved_highest = SaveService.highest_boss
	_saved_flow = Game.flow_state
	_saved_unlocked = AudioManager.is_unlocked()
	SimClock.paused = false


func after_each() -> void:
	SimClock.paused = _saved_paused
	SaveService.assist = _saved_assist
	SaveService.highest_boss = _saved_highest
	AudioManager.set_master_muted(_saved_muted)
	Game.flow_state = _saved_flow as GameScript.FlowState
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false)


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func _title(highest_boss: int = 1) -> TitleScreen:
	Game.flow_state = S.TITLE
	var title: TitleScreen = autofree(TitleScreenScript.new())
	title.set_saved_progress(highest_boss)
	title.set_assist_shown(SaveService.assist)
	return title


# --- Bindings (AC 1, 2, 5.6) ------------------------------------------------------------------

func test_every_gameplay_action_has_a_pad_event_that_matches_it() -> void:
	for action: StringName in GAMEPLAY_ACTIONS:
		var pads: int = 0
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				pads += 1
				assert_true(InputMap.event_is_action(ev, action, true), "%s pad event matches" % action)
		assert_gt(pads, 0, "%s has a pad event" % action)


func test_gdd_buttons_drive_their_actions() -> void:
	var cases: Dictionary = {
		JOY_BUTTON_X: &"action_1", JOY_BUTTON_A: &"action_2",
		JOY_BUTTON_LEFT_SHOULDER: &"shift_left", JOY_BUTTON_RIGHT_SHOULDER: &"shift_right",
		JOY_BUTTON_Y: &"watch", JOY_BUTTON_START: &"pause",
		JOY_BUTTON_DPAD_LEFT: &"move_left", JOY_BUTTON_DPAD_RIGHT: &"move_right",
		JOY_BUTTON_DPAD_UP: &"move_up", JOY_BUTTON_DPAD_DOWN: &"move_down",
		JOY_BUTTON_BACK: &"mute", JOY_BUTTON_B: &"title_option_debug_build",
		JOY_BUTTON_RIGHT_STICK: &"title_option_fullscreen", JOY_BUTTON_LEFT_STICK: &"title_option_practice",
	}
	for button: JoyButton in cases:
		assert_true(_pad(button).is_action_pressed(cases[button]), "button %d -> %s" % [button, cases[button]])
	assert_true(_pad(JOY_BUTTON_BACK).is_action_pressed(&"title_option_new_run"), "Select is also new run")


func test_sticks_and_trigger_drive_their_actions() -> void:
	assert_true(_axis(JOY_AXIS_LEFT_X, -1.0).is_action_pressed(&"move_left"))
	assert_true(_axis(JOY_AXIS_LEFT_X, 1.0).is_action_pressed(&"move_right"))
	assert_true(_axis(JOY_AXIS_LEFT_Y, -1.0).is_action_pressed(&"move_up"))
	assert_true(_axis(JOY_AXIS_LEFT_Y, 1.0).is_action_pressed(&"move_down"))
	assert_true(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0).is_action_pressed(&"breakpoint"))
	assert_false(_axis(JOY_AXIS_LEFT_X, 0.1).is_action_pressed(&"move_left"), "inside the 0.2 deadzone")
	assert_false(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.1).is_action_pressed(&"breakpoint"), "inside the deadzone")
	assert_false(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0).is_action_pressed(&"breakpoint"), "LT is not Breakpoint")


func test_no_two_gameplay_actions_share_a_pad_event() -> void:
	for a: StringName in GAMEPLAY_ACTIONS:
		for ev: InputEvent in InputMap.action_get_events(a):
			if not (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
				continue
			for b: StringName in GAMEPLAY_ACTIONS:
				if b != a:
					assert_false(InputMap.event_is_action(ev, b, true), "%s pad event also hits %s" % [a, b])


# --- Title (AC 5-8) ---------------------------------------------------------------------------

func test_title_pad_buttons_start_the_run() -> void:
	var title := _title()
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_START,
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_Y]:
		assert_eq(title.resolve(_pad(button)), TitleScreenScript.Action.START, "button %d starts" % button)


func test_title_option_buttons() -> void:
	assert_eq(TitleScreenScript.option_of(_pad(JOY_BUTTON_BACK)), &"new_run")
	assert_eq(TitleScreenScript.option_of(_pad(JOY_BUTTON_B)), &"debug_build")
	assert_eq(TitleScreenScript.option_of(_pad(JOY_BUTTON_RIGHT_STICK)), &"fullscreen")
	assert_eq(TitleScreenScript.option_of(_pad(JOY_BUTTON_LEFT_STICK)), &"practice")
	assert_eq(TitleScreenScript.option_of(_pad(JOY_BUTTON_A)), &"")
	var title := _title()
	assert_eq(title.resolve(_pad(JOY_BUTTON_B)), TitleScreenScript.Action.OPTION, "B never starts")
	assert_eq(title.resolve(_pad(JOY_BUTTON_RIGHT_STICK)), TitleScreenScript.Action.OPTION, "Story 7.7: R3 is the fullscreen option")
	assert_eq(title.resolve(_pad(JOY_BUTTON_LEFT_STICK)), TitleScreenScript.Action.OPTION, "L3 is practice (7.6)")


func test_title_select_follows_the_new_run_rule() -> void:
	assert_eq(_title(1).resolve(_pad(JOY_BUTTON_BACK)), TitleScreenScript.Action.START, "no save: plain start")
	assert_eq(_title(2).resolve(_pad(JOY_BUTTON_BACK)), TitleScreenScript.Action.OPTION, "save: new run")


func test_title_pad_b_toggles_the_assist_in_place() -> void:
	SaveService.assist = false
	var title := _title()
	assert_eq(title.handle_input(_pad(JOY_BUTTON_B)), TitleScreenScript.Action.OPTION)
	assert_true(SaveService.assist, "B flips the assist")
	assert_eq(Game.flow_state, S.TITLE, "B never starts the run")
	assert_true(AudioManager.is_unlocked(), "a counted pad press unlocks audio")


func test_title_ignores_axes_and_releases() -> void:
	for ev: InputEvent in [_axis(JOY_AXIS_LEFT_X, 1.0), _axis(JOY_AXIS_LEFT_Y, -1.0),
			_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _pad(JOY_BUTTON_A, false)]:
		assert_eq(TitleScreenScript.classify(ev), TitleScreenScript.Action.IGNORE, str(ev))
	var title := _title()
	assert_eq(title.handle_input(_axis(JOY_AXIS_LEFT_X, 1.0)), TitleScreenScript.Action.IGNORE)
	assert_eq(Game.flow_state, S.TITLE)


# --- Intro, Harvest, Ending, DEAD (AC 9, 10) --------------------------------------------------

func test_pad_press_rule() -> void:
	assert_true(PlaceholderScreen.is_pad_press(_pad(JOY_BUTTON_A)))
	assert_true(PlaceholderScreen.is_pad_press(_pad(JOY_BUTTON_BACK)))
	assert_false(PlaceholderScreen.is_pad_press(_pad(JOY_BUTTON_START)), "Start is the pause press")
	assert_false(PlaceholderScreen.is_pad_press(_pad(JOY_BUTTON_A, false)), "release")
	assert_false(PlaceholderScreen.is_pad_press(_axis(JOY_AXIS_LEFT_X, 1.0)), "stick")
	assert_false(PlaceholderScreen.is_pad_press(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)), "trigger")


func test_any_button_advances_skips_leaves_and_retries_except_start() -> void:
	var rules: Dictionary = {
		"harvest": PlaceholderScreen.is_advance,
		"intro": IntroScreen.skip_allowed,
		"ending": EndingScreen.leave_allowed,
		"dead": DeadScreen.is_retry_press,
	}
	for screen: String in rules:
		var rule: Callable = rules[screen]
		for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER]:
			assert_true(rule.call(_pad(button)), "%s: button %d" % [screen, button])
		assert_false(rule.call(_pad(JOY_BUTTON_START)), "%s: Start is the pause" % screen)
		assert_false(rule.call(_pad(JOY_BUTTON_A, false)), "%s: release" % screen)
		assert_false(rule.call(_axis(JOY_AXIS_LEFT_Y, 1.0)), "%s: stick" % screen)
		assert_false(rule.call(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)), "%s: trigger" % screen)


# --- Pause (AC 11-14) -------------------------------------------------------------------------

func _game(state: S) -> Node:
	var game: Node = autofree(GameScript.new())
	game.flow_state = state
	return game


func test_start_pauses_and_resumes_in_a_fight() -> void:
	var game := _game(S.FIGHT)
	assert_true(GameScript.is_pause_press(_pad(JOY_BUTTON_START)))
	assert_true(game.handle_pause_input(_pad(JOY_BUTTON_START)))
	assert_true(SimClock.paused)
	assert_true(game.handle_pause_input(_pad(JOY_BUTTON_START)), "no click guard on Start")
	assert_false(SimClock.paused, "Start again resumes")


func test_start_is_refused_where_esc_is() -> void:
	for state: S in [S.TITLE, S.HARVEST, S.DEAD]:
		var game := _game(state)
		assert_false(game.handle_pause_input(_pad(JOY_BUTTON_START)), "refused in %s" % S.keys()[state])
		assert_false(SimClock.paused)


func test_other_pad_input_does_not_pause_or_resume() -> void:
	var game := _game(S.FIGHT)
	for ev: InputEvent in [_pad(JOY_BUTTON_A), _pad(JOY_BUTTON_BACK), _axis(JOY_AXIS_LEFT_X, 1.0)]:
		assert_false(game.handle_pause_input(ev), str(ev))
		assert_false(game.handle_resume_click(ev, 100000), str(ev))
	assert_false(SimClock.paused)


func test_pause_screen_select_mutes_and_b_toggles_assist() -> void:
	assert_true(PauseScreen.is_mute_toggle(_pad(JOY_BUTTON_BACK), false))
	assert_true(PauseScreen.is_assist_toggle(_pad(JOY_BUTTON_B), false))
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_X]:
		assert_false(PauseScreen.is_mute_toggle(_pad(button), false), "button %d is not mute" % button)
		assert_false(PauseScreen.is_assist_toggle(_pad(button), false), "button %d is not assist" % button)
	assert_false(PauseScreen.is_mute_toggle(_pad(JOY_BUTTON_BACK, false), false), "release")
	assert_false(PauseScreen.is_mute_toggle(_axis(JOY_AXIS_LEFT_X, 1.0), false), "stick")


func test_pause_screen_pad_input_toggles_and_stays_paused() -> void:
	SimClock.paused = true
	SaveService.assist = false
	AudioManager.set_master_muted(false)
	var pause: Node2D = PauseScreen.new()
	add_child_autofree(pause)
	pause._input(_pad(JOY_BUTTON_BACK))
	assert_true(AudioManager.is_master_muted(), "Select mutes")
	assert_true(SaveService.muted, "saved through set_muted")
	pause._input(_pad(JOY_BUTTON_B))
	assert_true(SaveService.assist, "B flips the assist")
	pause._input(_pad(JOY_BUTTON_A))
	assert_true(AudioManager.is_master_muted(), "A does nothing")
	assert_true(SaveService.assist, "A does nothing")
	assert_true(SimClock.paused, "the game stays paused")


# --- Pause layout (AC 15) ---------------------------------------------------------------------

func test_pad_hint_row_sits_between_the_controls_and_resume() -> void:
	var lines: PackedStringArray = PauseScreen.lines_for(false)
	var tops: PackedInt32Array = PauseScreen.row_tops()
	var i: int = lines.find(PauseScreen.PAD_HINT_TEXT)
	assert_gt(i, 0, "the hint row is listed")
	assert_eq(tops[i], 216)
	assert_eq(lines[i - 1], PauseScreen.CONTROLS[-1])
	assert_eq(lines[i + 1], PauseScreen.RESUME_TEXT)
	var h: int = GlyphFont.size_for(PauseScreen.TEXT_SCALE)
	assert_true(tops[i - 1] + h <= tops[i] and tops[i] + h <= tops[i + 1], "no overlap")
	assert_true(GlyphFont.text_width(PauseScreen.PAD_HINT_TEXT, PauseScreen.TEXT_SCALE) <= Const.BASE_RES.x - 32)
