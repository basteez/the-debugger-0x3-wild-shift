extends GutTest
## Story 8.2 (G1, G2; AC 1, 11-16): the tutorial's flow on the Game autoload. INTRO -> TUTORIAL ->
## FIGHT 1 on a fresh save; the 60-frame Esc hold skips (a tap does not, Esc never pauses there, P
## does); the outro beat; the title replay ends at TITLE; tutorial_done is written and keeps a later
## run, a resume and a retry out of the tutorial; route_after_intro's table; the first-shift metric
## counts the tutorial's shift and NFR10's budget holds on a scripted route (injected frame counts).
## This is the only test file that turns Game.tutorial_routing_enabled on (off by default under GUT).

const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH

var _saved_game: Dictionary = {}
var _saved_save: Dictionary = {}
var _saved_frame: int
var _saved_paused: bool


func before_each() -> void:
	_saved_game = {}
	for key: String in ["flow_state", "run", "stats", "first_input_frame", "intro_start_frame", "death_frame",
			"tutorial_routing_enabled", "tutorial_replay", "practice_run", "segfault_enabled"]:
		_saved_game[key] = Game.get(key)
	_saved_save = {
		"path": SaveService.path, "highest_boss": SaveService.highest_boss,
		"tutorial_done": SaveService.tutorial_done, "track_fights": SaveService.track_fights,
	}
	_saved_frame = SimClock.sim_frame
	_saved_paused = SimClock.paused
	SaveService.path = ""
	SaveService.highest_boss = 1
	SaveService.tutorial_done = false
	SimClock.paused = false
	Game.flow_state = S.TITLE
	Game.tutorial_routing_enabled = true
	Game.tutorial_replay = false
	Game.practice_run = false


func after_each() -> void:
	for key: String in _saved_game:
		Game.set(key, _saved_game[key])
	for key: String in _saved_save:
		SaveService.set(key, _saved_save[key])
	SimClock.sim_frame = _saved_frame
	SimClock.paused = _saved_paused
	SimClock.set(&"_swallow_presses", false)


func _esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


func _p() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_P
	ev.physical_keycode = KEY_P
	ev.pressed = true
	return ev


## Title input at 100, Intro skipped at 160.
func _to_intro_end() -> void:
	SimClock.sim_frame = 100
	Game.start_run_from_title(100)
	SimClock.sim_frame = 160
	assert_true(Game.finish_intro(160, true))


func test_route_after_intro_table() -> void:
	assert_eq(GameScript.route_after_intro(false, true), S.TUTORIAL)
	assert_eq(GameScript.route_after_intro(true, true), S.FIGHT)
	assert_eq(GameScript.route_after_intro(false, false), S.FIGHT)
	assert_eq(GameScript.route_after_intro(true, false), S.FIGHT)


func test_routing_is_off_by_default_under_gut() -> void:
	var fresh: Node = autofree(GameScript.new())
	assert_false(fresh.tutorial_routing_enabled, "the GUT seam: existing INTRO -> FIGHT tests keep their meaning")
	assert_true(S.TUTORIAL in GameScript.PAUSABLE_STATES)
	assert_eq(S.TUTORIAL, 6, "appended: the existing FlowState ints are unchanged")


func test_intro_to_tutorial_to_fight_one() -> void:
	_to_intro_end()
	assert_eq(Game.flow_state, S.TUTORIAL, "a fresh save goes to the tutorial")
	assert_eq(Game.run.boss_index, 0)
	assert_eq(Game.stats.fight_start_frame, -1, "the tutorial is not the fight: no clear-time start")
	SimClock.sim_frame = 700
	assert_true(Game.finish_tutorial(700, false))
	assert_eq(Game.flow_state, S.FIGHT, "then Boss 1 exactly as before")
	assert_eq(Game.run.boss_index, 0)
	assert_eq(Game.run.fight_start_ring, PackedInt32Array([D, A]), "Boss 1's start set")
	assert_eq(Game.stats.fight_start_frame, 700)
	assert_true(SaveService.tutorial_done, "completing writes the flag")
	assert_true(SimClock.get(&"_swallow_presses"), "the last press never fires in FIGHT 1")


func test_finish_tutorial_is_refused_outside_tutorial_and_while_paused() -> void:
	assert_false(Game.finish_tutorial(10, false), "TITLE")
	_to_intro_end()
	SimClock.paused = true
	assert_false(Game.finish_tutorial(200, true), "paused")
	assert_eq(Game.flow_state, S.TUTORIAL)
	assert_false(SaveService.tutorial_done)


func test_done_flag_skips_the_tutorial_on_the_next_run() -> void:
	SaveService.tutorial_done = true
	_to_intro_end()
	assert_eq(Game.flow_state, S.FIGHT)


func test_routing_off_goes_straight_to_fight() -> void:
	Game.tutorial_routing_enabled = false
	_to_intro_end()
	assert_eq(Game.flow_state, S.FIGHT)


func test_intro_cap_also_routes_to_the_tutorial() -> void:
	SimClock.sim_frame = 100
	Game.start_run_from_title(100)
	assert_false(Game.finish_intro(579))
	assert_true(Game.finish_intro(580))
	assert_eq(Game.flow_state, S.TUTORIAL)


func test_esc_hold_of_60_frames_skips_to_fight_one() -> void:
	_to_intro_end()
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	for i: int in TutorialScreen.SKIP_HOLD_FRAMES - 1:
		assert_false(screen.poll(200 + i, true))
	assert_eq(Game.flow_state, S.TUTORIAL, "59 held frames: still on")
	assert_true(TutorialScreen.hold_hint_visible(screen.hold_frames))
	assert_true(screen.poll(300, true), "the 60th frame skips")
	assert_eq(Game.flow_state, S.FIGHT)
	assert_true(SaveService.tutorial_done, "skipping writes the flag too")


func test_a_tap_or_a_broken_hold_never_skips() -> void:
	_to_intro_end()
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	for i: int in 50:
		screen.poll(200 + i, true)
	screen.poll(250, false)
	assert_eq(screen.hold_frames, 0, "a release resets the hold")
	for i: int in 20:
		screen.poll(260 + i, true)
	assert_eq(Game.flow_state, S.TUTORIAL)


func test_the_hold_does_not_count_while_paused() -> void:
	_to_intro_end()
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	SimClock.paused = true
	for i: int in 100:
		screen.poll(200, true)
	assert_eq(screen.hold_frames, 0)
	assert_eq(Game.flow_state, S.TUTORIAL)


func test_a_hold_straddling_a_pause_starts_over() -> void:
	_to_intro_end()
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	for i: int in 50:
		screen.poll(200, true)
	assert_eq(screen.hold_frames, 50)
	SimClock.paused = true
	screen.poll(300, true)
	SimClock.paused = false
	assert_eq(screen.hold_frames, 0, "reset by the pause")
	for i: int in 20:
		screen.poll(400, true)
	assert_eq(Game.flow_state, S.TUTORIAL, "20 frames after the resume is not a skip")


func test_esc_never_pauses_in_tutorial_but_p_does() -> void:
	_to_intro_end()
	assert_false(Game.handle_pause_input(_esc()), "a bare Esc is the skip hold, never a pause")
	assert_false(SimClock.paused)
	assert_true(Game.handle_pause_input(_p()), "P pauses")
	assert_true(SimClock.paused)
	assert_true(Game.handle_pause_input(_esc()), "Esc still resumes")
	assert_false(SimClock.paused)
	assert_true(GameScript.esc_is_tutorial_skip(S.TUTORIAL, false, _esc()))
	assert_false(GameScript.esc_is_tutorial_skip(S.FIGHT, false, _esc()))
	assert_false(GameScript.esc_is_tutorial_skip(S.TUTORIAL, false, _p()))


func test_outro_beat_then_fight_one() -> void:
	_to_intro_end()
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	screen.steps.step = TutorialSteps.STEP_COUNT # every test passed
	for i: int in TutorialScreen.TUTORIAL_OUTRO_FRAMES - 1:
		assert_false(screen.poll(200 + i, false))
	assert_eq(Game.flow_state, S.TUTORIAL, "ALL TESTS PASSED. is held for the beat")
	assert_true(screen.poll(400, false))
	assert_eq(Game.flow_state, S.FIGHT)


func test_replay_from_title_ends_at_title() -> void:
	SaveService.tutorial_done = true
	SimClock.sim_frame = 50
	Game.start_tutorial_from_title(50)
	assert_eq(Game.flow_state, S.TUTORIAL, "the replay runs whatever the flag says")
	assert_true(Game.tutorial_replay)
	assert_eq(Game.first_input_frame, -1, "no first-shift clock")
	assert_eq(Game.intro_start_frame, -1, "no Intro")
	var screen: TutorialScreen = autofree(TutorialScreen.new())
	for i: int in TutorialScreen.SKIP_HOLD_FRAMES:
		screen.poll(60 + i, true)
	assert_eq(Game.flow_state, S.TITLE, "the replay's hold goes back to the title")
	assert_false(Game.tutorial_replay)
	assert_eq(Game.stats.fight_start_frame, -1, "no run stats")
	assert_eq(Game.first_input_frame, -1)


func test_replay_completion_sets_the_flag_and_ends_at_title() -> void:
	Game.start_tutorial_from_title(50)
	assert_true(Game.finish_tutorial(400, false))
	assert_eq(Game.flow_state, S.TITLE)
	assert_true(SaveService.tutorial_done)


func test_replay_outside_title_is_ignored() -> void:
	_to_intro_end()
	Game.start_tutorial_from_title(200)
	assert_false(Game.tutorial_replay)
	assert_eq(Game.flow_state, S.TUTORIAL)


func test_resume_never_shows_the_tutorial() -> void:
	Game.resume_run_from_title(100, 2)
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(Game.run.boss_index, 1)


func test_dead_retry_never_shows_the_tutorial() -> void:
	_to_intro_end()
	Game.finish_tutorial(300, true)
	SimClock.sim_frame = 400
	assert_true(Game.record_death(400))
	SimClock.sim_frame = 500
	assert_true(Game.retry(500))
	assert_eq(Game.flow_state, S.FIGHT)


func test_new_run_after_the_tutorial_keeps_the_intro_and_skips_the_tutorial() -> void:
	SaveService.tutorial_done = true
	SaveService.highest_boss = 3
	SimClock.sim_frame = 100
	Game.start_new_run_from_title(100)
	assert_eq(Game.flow_state, S.INTRO, "D-S82-9: the Intro stays")
	assert_true(SaveService.tutorial_done, "a new run never clears the flag")
	SimClock.sim_frame = 160
	Game.finish_intro(160, true)
	assert_eq(Game.flow_state, S.FIGHT)


func test_first_shift_metric_counts_the_tutorial_shift() -> void:
	_to_intro_end()
	SimClock.sim_frame = 400
	Game._on_register_shifted(1, Vector2i(A, D), PackedInt32Array(), &"player")
	assert_eq(Game.stats.first_shift_frame, 400)


func test_replay_never_logs_a_first_shift() -> void:
	Game.start_tutorial_from_title(50)
	SimClock.sim_frame = 100
	Game._on_register_shifted(1, Vector2i(A, D), PackedInt32Array(), &"player")
	assert_eq(Game.stats.first_shift_frame, -1)


## G2 (AC 16, D-S82-11, NFR10): the Intro runs its full 480-frame cap, then the player walks 3 tiles
## over 90 frames, uses J and K over 60 frames and shifts once: the shift lands well inside 1800
## frames (30 s) of the title input, and it is the run's first-shift metric.
func test_nfr10_first_shift_within_30_s_on_a_scripted_route() -> void:
	var f: int = 1000
	SimClock.sim_frame = f
	Game.start_run_from_title(f)
	f += GameScript.INTRO_MAX_FRAMES
	SimClock.sim_frame = f
	assert_true(Game.finish_intro(f))
	assert_eq(Game.flow_state, S.TUTORIAL)
	var steps := TutorialSteps.new()
	var step_px: float = 3.0 * Const.TILE_PX / 90.0
	for i: int in 90:
		f += 1
		steps.observe_move(step_px + 0.001)
	assert_true(steps.passed(TutorialSteps.Step.MOVE))
	f += 30
	steps.observe_action(TutorialSteps.ACTION_J)
	f += 30
	steps.observe_action(TutorialSteps.ACTION_K)
	assert_true(steps.passed(TutorialSteps.Step.ACTIONS))
	f += 1 # one Q / E press
	SimClock.sim_frame = f
	Game._on_register_shifted(1, Vector2i(A, D), PackedInt32Array([A, D]), &"player")
	steps.observe_window(Vector2i(A, D))
	assert_true(steps.passed(TutorialSteps.Step.SHIFT))
	assert_eq(Game.stats.first_shift_frame, f, "the tutorial's shift is the run's first shift")
	assert_lte(Game.stats.first_shift_frame - Game.first_input_frame, 1800, "NFR10: within 30 s")
