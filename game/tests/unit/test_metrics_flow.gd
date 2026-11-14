extends GutTest
## Story 7.8 (AC 5-10): Game writes the playtest metric record on the flow side. A real run through
## FIGHT 1 -> DEAD -> retry -> defeat -> HARVEST -> FIGHT 2 records both boss starts (the retry keeps
## the clock), the death on boss 1 and boss 1's clear; only the first player shift counts, boss
## rotations never; practice records nothing; a new run starts a fresh record. No random picks (the
## defeat uses the deterministic test boss), so no seed is needed.

const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const TEST_BOSS: BossDef = preload("res://data/bosses/test_boss/boss_def.tres")

var _saved_save: Dictionary = {}
var _saved_enabled: bool
var _saved_frame: int
var _saved_paused: bool


func before_each() -> void:
	_saved_save = {
		"path": SaveService.path, "highest_boss": SaveService.highest_boss, "assist": SaveService.assist,
		"muted": SaveService.muted, "track_fights": SaveService.track_fights,
	}
	_saved_enabled = Debug.enabled
	_saved_frame = SimClock.sim_frame
	_saved_paused = SimClock.paused
	SaveService.path = "" # in-memory only: a counted run writes fight starts
	SimClock.paused = false


func after_each() -> void:
	for key: String in _saved_save:
		SaveService.set(key, _saved_save[key])
	Debug.enabled = _saved_enabled
	SimClock.sim_frame = _saved_frame
	SimClock.paused = _saved_paused
	SimClock.set(&"_swallow_presses", false)


func _game() -> Node:
	return autofree(GameScript.new())


## A real controller killed and ticked through its whole defeat animation.
func _dead_boss() -> BossController:
	var c := BossController.new()
	assert_true(c.setup(TEST_BOSS, null, ArenaContext.new()))
	c.reset_for_fight()
	c.debug_kill()
	SimClock.set(&"_pending_hitstop", 0)
	var ctx := SimContext.new()
	for i: int in BossController.DEFEAT_FRAMES:
		c.tick(ctx)
	return c


func _shift(game: Node, source: StringName = &"player") -> void:
	game._on_register_shifted(1, Vector2i.ZERO, PackedInt32Array(), source)


## Title input at 100, Intro skipped at 160: FIGHT 1 at 160.
func _start(game: Node) -> void:
	game.segfault_enabled = true
	SimClock.sim_frame = 100
	game.start_run_from_title(100)
	SimClock.sim_frame = 160
	assert_true(game.finish_intro(160, true))
	assert_eq(game.flow_state, S.FIGHT)


func test_first_player_shift_is_recorded_from_the_title_input() -> void:
	var game: Node = _game()
	_start(game)
	SimClock.sim_frame = 200
	_shift(game, &"sigsegv")
	assert_eq(game.stats.first_shift_frame, -1, "a boss rotation is not the player's shift")
	SimClock.sim_frame = 844
	_shift(game)
	assert_eq(game.stats.first_shift_frame, 844)
	assert_almost_eq(RunStats.seconds(game.stats.first_shift_frame - game.first_input_frame), 12.4, 0.0001)
	SimClock.sim_frame = 900
	_shift(game)
	assert_eq(game.stats.first_shift_frame, 844, "only the first shift of the run")


func test_a_shift_outside_fight_is_not_recorded() -> void:
	var game: Node = _game()
	game.segfault_enabled = true
	game.start_run_from_title(100)
	_shift(game) # INTRO
	assert_eq(game.stats.first_shift_frame, -1)


func test_boss_clock_survives_a_retry_and_harvest_is_excluded() -> void:
	var game: Node = _game()
	_start(game)
	assert_eq(game.stats.boss_start_frames, {0: 160})
	SimClock.sim_frame = 1000
	assert_true(game.record_death(1000))
	SimClock.sim_frame = 1000 + GameScript.RETRY_DELAY_FRAMES
	assert_true(game.retry(SimClock.sim_frame))
	SimClock.set(&"_swallow_presses", false)
	assert_eq(game.stats.boss_start_frames, {0: 160}, "a retry never restarts the clock")
	SimClock.sim_frame = 5400
	assert_true(game.finish_defeat(_dead_boss()))
	assert_eq(game.flow_state, S.HARVEST)
	assert_eq(game.stats.boss_clear_frames, {0: 5240})
	assert_eq(game.stats.deaths_on(0), 1)
	SimClock.sim_frame = 5800 # 400 frames of HARVEST
	assert_true(game.finish_harvest(5800))
	SimClock.set(&"_swallow_presses", false)
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(game.stats.boss_start_frames, {0: 160, 1: 5800}, "boss 2's clock starts at its FIGHT entry")
	assert_eq(game.stats.deaths_on(1), 0)


func test_ending_summary_snapshot_is_unchanged_and_full_run_spans_from_the_title_input() -> void:
	var game: Node = _game()
	_start(game)
	game.segfault_enabled = false # cut #4: the Null Pointer is the last fight
	SimClock.sim_frame = 1000
	assert_true(game.finish_defeat(_dead_boss()))
	SimClock.sim_frame = 1200
	assert_true(game.finish_harvest(1200))
	SimClock.set(&"_swallow_presses", false)
	SimClock.sim_frame = 3000
	assert_true(game.finish_defeat(_dead_boss()))
	assert_eq(game.flow_state, S.ENDING)
	assert_eq(game.ending_summary.keys().size(), 3, "6.8 snapshot shape unchanged")
	assert_eq(game.stats.metrics_summary(game.first_input_frame, 3000, false, false),
		"run full_run_s=48.3 hits=0 assist=false debug_jumped=false bosses=[1:14.0/0, 2:30.0/0]")


func test_practice_records_nothing() -> void:
	var game: Node = _game()
	SimClock.sim_frame = 100
	game.start_practice_from_title(100, 1)
	assert_eq(game.flow_state, S.FIGHT)
	_shift(game)
	game.on_player_damaged(0) # lethal: a practice death
	assert_eq(game.flow_state, S.DEAD)
	var s: RunStats = game.stats
	assert_eq(s.first_shift_frame, -1)
	assert_eq(s.boss_start_frames, {})
	assert_eq(s.boss_deaths, {})
	assert_eq(s.boss_clear_frames, {})
	game._clear_practice()


func test_a_debug_jumped_run_is_still_recorded_and_flagged() -> void:
	var game: Node = _game()
	Debug.enabled = true
	SimClock.sim_frame = 50
	game.debug_jump(S.FIGHT, 1)
	assert_true(game.stats.debug_jumped)
	assert_eq(game.stats.boss_start_frames, {1: 50})


func test_a_new_run_starts_a_fresh_record() -> void:
	var game: Node = _game()
	_start(game)
	SimClock.sim_frame = 300
	_shift(game)
	game.record_death(300)
	var old: RunStats = game.stats
	Debug.enabled = true
	game.debug_jump(S.TITLE, 0)
	assert_ne(game.stats, old)
	assert_eq(game.stats.first_shift_frame, -1)
	assert_eq(game.stats.boss_deaths, {})
	game.start_run_from_title(400)
	assert_eq(game.stats.boss_start_frames, {})
