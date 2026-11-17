extends GutTest
## Story 9.1 (AC 1-6, D-S91-1..3): the title entry gate. A non-TITLE -> TITLE entry (tutorial
## replay end, Ending end, practice leave) ignores every counted title press for
## TITLE_ENTRY_GATE_FRAMES sim frames (options too), still unlocks audio, and never gates the boot
## title. The DEAD, INTRO and ENDING gates are pinned unchanged (554a).

const GameScript := preload("res://src/autoloads/game.gd")
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const S := GameScript.FlowState
const IGNORE := TitleScreenScript.Action.IGNORE

var _saved_game: Dictionary = {}
var _saved_frame: int
var _saved_paused: bool
var _saved_unlocked: bool
var _saved_get: Callable
var _saved_set: Callable
var _saved_save: Dictionary = {}
var _saved_source: InputSource
var _mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var _set_calls: int = 0


func before_each() -> void:
	_saved_game = {}
	for key: String in ["flow_state", "run", "stats", "first_input_frame", "intro_start_frame", "death_frame",
			"title_entry_frame", "tutorial_replay", "practice_run", "practice_loadouts_offered",
			"practice_loadout_index", "practice_start_frame", "tutorial_routing_enabled"]:
		_saved_game[key] = Game.get(key)
	_saved_save = {"path": SaveService.path, "highest_boss": SaveService.highest_boss, "assist": SaveService.assist,
			"tutorial_done": SaveService.tutorial_done, "track_fights": SaveService.track_fights,
			"completed": SaveService.completed} # Story 9.3
	SaveService.path = ""
	SaveService.track_fights = false
	_saved_frame = SimClock.sim_frame
	_saved_paused = SimClock.paused
	_saved_unlocked = AudioManager.is_unlocked()
	_saved_source = SimClock.input_source
	_saved_get = Fullscreen.get_mode_fn
	_saved_set = Fullscreen.set_mode_fn
	_mode = DisplayServer.WINDOW_MODE_WINDOWED
	_set_calls = 0
	Fullscreen.get_mode_fn = func() -> DisplayServer.WindowMode: return _mode
	Fullscreen.set_mode_fn = func(m: DisplayServer.WindowMode) -> void:
		_set_calls += 1
		_mode = m
	SimClock.paused = false
	Game.tutorial_routing_enabled = false
	AudioManager.set("_unlocked", false)


func after_each() -> void:
	for key: String in _saved_game:
		Game.set(key, _saved_game[key])
	for key: String in _saved_save:
		SaveService.set(key, _saved_save[key])
	SimClock.sim_frame = _saved_frame
	SimClock.paused = _saved_paused
	SimClock.input_source = _saved_source
	SimClock.set(&"_swallow_presses", false)
	Fullscreen.get_mode_fn = _saved_get
	Fullscreen.set_mode_fn = _saved_set
	AudioManager.set("_unlocked", _saved_unlocked)


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(4, 4) # a corner: no option label there
	return ev


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _title() -> TitleScreen:
	var title: TitleScreen = autofree(TitleScreenScript.new())
	title.set_saved_progress(1)
	title.set_assist_shown(SaveService.assist)
	return title


## Enters TITLE from `from` at sim frame `frame`, through the real _set_flow_state.
func _enter_title_from(from: S, frame: int) -> void:
	SimClock.sim_frame = frame
	Game.flow_state = from
	Game._set_flow_state(S.TITLE)


# --- A3: the pure gate --------------------------------------------------------------------------


func test_gate_length_and_pure_table() -> void:
	assert_eq(GameScript.TITLE_ENTRY_GATE_FRAMES, 30)
	assert_true(GameScript.title_gate_open_at(-1, 0), "the boot title is never gated")
	assert_false(GameScript.title_gate_open_at(10, 10), "the entry frame is gated")
	assert_false(GameScript.title_gate_open_at(10, 39), "29 frames after: closed")
	assert_true(GameScript.title_gate_open_at(10, 40), "30 frames after: open")
	assert_true(GameScript.title_gate_open_at(10, 5000))
	assert_true(GameScript.title_gate_open_at(100, 50), "a clock behind the entry (stale frame) is open")


# --- A2: what arms it ----------------------------------------------------------------------------


func test_every_non_title_entry_arms_the_gate() -> void:
	for from: S in [S.TUTORIAL, S.ENDING, S.FIGHT, S.DEAD, S.INTRO, S.HARVEST]:
		Game.title_entry_frame = -1
		_enter_title_from(from, 700)
		assert_eq(Game.title_entry_frame, 700, "%s -> TITLE arms the gate" % S.keys()[from])
		assert_false(Game.title_input_open(700))
		assert_false(Game.title_input_open(729))
		assert_true(Game.title_input_open(730))


func test_title_to_title_and_other_entries_leave_it() -> void:
	Game.title_entry_frame = -1
	SimClock.sim_frame = 900
	Game.flow_state = S.TITLE
	Game._set_flow_state(S.TITLE) # debug_jump(TITLE) while on the title: not an entry
	assert_eq(Game.title_entry_frame, -1)
	Game._set_flow_state(S.INTRO)
	assert_eq(Game.title_entry_frame, -1, "leaving the title never arms it")


func test_practice_leave_arms_the_gate() -> void:
	SimClock.sim_frame = 300
	Game.flow_state = S.TITLE
	Game.start_practice_from_title(300, 1)
	assert_eq(Game.flow_state, S.FIGHT)
	SimClock.sim_frame = 420
	assert_true(Game.leave_practice_to_title(420))
	assert_eq(Game.title_entry_frame, 420)
	assert_false(Game.title_input_open(420))


## Dev Notes check (D-S91-2): the sim clock is not paused in TITLE and keeps counting world ticks, so
## the gate opens on its own after TITLE_ENTRY_GATE_FRAMES ticks.
func test_sim_frame_advances_on_the_title() -> void:
	_enter_title_from(S.TUTORIAL, 100)
	assert_false(SimClock.paused, "_set_flow_state never leaves the game paused")
	assert_false(Game.set_paused(true, &"test"), "TITLE is not pausable")
	SimClock.input_source = null
	var start: int = SimClock.sim_frame
	for i: int in GameScript.TITLE_ENTRY_GATE_FRAMES:
		SimClock.tick()
	assert_eq(SimClock.sim_frame, start + GameScript.TITLE_ENTRY_GATE_FRAMES, "one world tick per physics frame")
	assert_true(Game.title_input_open(SimClock.sim_frame))


# --- A4: the title ignores presses inside the gate ------------------------------------------------


func test_gated_presses_do_nothing_but_unlock_audio() -> void:
	_enter_title_from(S.TUTORIAL, 1000)
	var title := _title()
	assert_eq(title.handle_input(_key(KEY_J)), IGNORE, "a key never starts the run")
	assert_true(AudioManager.is_unlocked(), "the gated press still unlocks audio")
	assert_eq(title.handle_input(_click()), IGNORE, "nor a click")
	assert_eq(title.handle_input(_pad(JOY_BUTTON_A)), IGNORE, "nor pad A")
	assert_eq(title.handle_input(_pad(JOY_BUTTON_RIGHT_STICK)), IGNORE, "577: a held R3")
	assert_eq(title.handle_input(_key(KEY_F)), IGNORE)
	assert_eq(_set_calls, 0, "fullscreen never toggled")
	var assist: bool = SaveService.assist
	assert_eq(title.handle_input(_key(KEY_B)), IGNORE)
	assert_eq(title.handle_input(_pad(JOY_BUTTON_B)), IGNORE)
	assert_eq(SaveService.assist, assist, "the assist never toggled")
	assert_eq(title.handle_input(_key(KEY_P)), IGNORE, "practice never starts")
	assert_eq(title.handle_input(_pad(JOY_BUTTON_LEFT_STICK)), IGNORE)
	assert_eq(title.handle_input(_key(KEY_T)), IGNORE, "the tutorial never starts")
	assert_eq(Game.flow_state, S.TITLE, "still on the title")
	assert_false(Game.practice_run)
	assert_false(Game.tutorial_replay)
	SimClock.sim_frame = 1029
	assert_eq(title.handle_input(_key(KEY_J)), IGNORE, "the last gated frame")
	assert_eq(Game.flow_state, S.TITLE)


func test_after_the_gate_the_same_key_starts_the_run() -> void:
	_enter_title_from(S.ENDING, 1000)
	var title := _title()
	SimClock.sim_frame = 1030
	assert_eq(title.handle_input(_key(KEY_J)), TitleScreenScript.Action.START)
	assert_eq(Game.flow_state, S.INTRO)


func test_after_the_gate_an_option_acts() -> void:
	_enter_title_from(S.DEAD, 1000)
	var title := _title()
	SimClock.sim_frame = 1030
	assert_eq(title.handle_input(_pad(JOY_BUTTON_RIGHT_STICK)), TitleScreenScript.Action.OPTION)
	assert_eq(_set_calls, 1, "R3 toggles fullscreen once the gate has passed")
	assert_eq(Game.flow_state, S.TITLE)


func test_boot_title_is_never_gated() -> void:
	Game.title_entry_frame = -1
	Game.flow_state = S.TITLE
	SimClock.sim_frame = 0
	var title := _title()
	assert_eq(title.handle_input(_key(KEY_J)), TitleScreenScript.Action.START, "the first key starts the run")
	assert_eq(Game.flow_state, S.INTRO)


func test_ignored_inputs_stay_ignored_and_do_not_unlock() -> void:
	_enter_title_from(S.TUTORIAL, 1000)
	var title := _title()
	var release := _key(KEY_J)
	release.pressed = false
	assert_eq(title.handle_input(release), IGNORE)
	assert_false(AudioManager.is_unlocked(), "a release is not a counted press")


# --- A7: the existing DEAD, INTRO and ENDING gates are unchanged (554a) ----------------------------


func test_existing_screen_gates_are_pinned() -> void:
	assert_eq(GameScript.RETRY_DELAY_FRAMES, 20, "DEAD retry gate")
	assert_false(GameScript.retry_open(100, 119))
	assert_true(GameScript.retry_open(100, 120))
	assert_eq(GameScript.ENDING_LEAVE_GATE_FRAMES, 60, "ENDING leave gate")
	assert_false(GameScript.ending_leave_open_at(100, 160))
	assert_true(GameScript.ending_leave_open_at(100, 161))
	var game: Node = autofree(GameScript.new())
	game.start_run_from_title(100)
	assert_false(game.can_skip_intro(100), "INTRO skip needs a press after the title input frame")
	assert_true(game.can_skip_intro(101))
	var held := _pad(JOY_BUTTON_A)
	assert_true(DeadScreen.is_retry_press(held), "a fresh pad press retries (after the gate)")
	var echo := _key(KEY_J)
	echo.echo = true
	assert_false(DeadScreen.is_retry_press(echo), "a held key (echo) never retries")
