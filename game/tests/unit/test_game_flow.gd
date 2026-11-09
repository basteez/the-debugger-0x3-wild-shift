extends GutTest
## Story 1.6 AC1/AC3/AC4: Game flow transitions, RunState.boss_index, Intro skip/timeout, debug jumps.

const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState

var _saved_enabled: bool


func before_each() -> void:
	_saved_enabled = Debug.enabled


func after_each() -> void:
	Debug.enabled = _saved_enabled


func _game() -> Node:
	return autofree(GameScript.new())


func test_run_state_starts_at_boss_zero() -> void:
	var run := RunState.new()
	assert_eq(run.boss_index, 0)
	assert_eq(_game().run.boss_index, 0)


func test_full_sequence_and_boss_index() -> void:
	var game: Node = _game()
	watch_signals(EventBus)
	game.start_run_from_title(10)
	assert_eq(game.flow_state, S.INTRO)
	var expected: Array = [
		[S.FIGHT, 0], [S.HARVEST, 0], [S.FIGHT, 1], [S.HARVEST, 1], [S.FIGHT, 2], [S.ENDING, 2], [S.TITLE, 0],
	]
	for step: Array in expected:
		game.advance()
		assert_eq(game.flow_state, step[0], "state after advance")
		assert_eq(game.run.boss_index, step[1], "boss_index in %d" % step[0])
	assert_eq(game.first_input_frame, -1, "Ending -> Title resets the first input frame")
	assert_signal_emit_count(EventBus, "flow_state_changed", 8)
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [S.ENDING, S.TITLE])


func test_ending_to_title_gives_a_fresh_run_state() -> void:
	var game: Node = _game()
	var old: RunState = game.run
	game.start_run_from_title(1)
	for i: int in 7:
		game.advance()
	assert_eq(game.flow_state, S.TITLE)
	assert_ne(game.run, old)
	assert_eq(game.run.boss_index, 0)


func test_advance_is_a_no_op_on_title_and_dead() -> void:
	var game: Node = _game()
	watch_signals(EventBus)
	game.advance()
	assert_eq(game.flow_state, S.TITLE)
	game.flow_state = S.DEAD
	game.advance()
	assert_eq(game.flow_state, S.DEAD)
	assert_signal_emit_count(EventBus, "flow_state_changed", 0)


func test_intro_not_skipped_on_the_title_frame() -> void:
	var game: Node = _game()
	game.start_run_from_title(100)
	assert_false(game.can_skip_intro(100))
	assert_false(game.finish_intro(100, true), "the title input frame is never a skip")
	assert_eq(game.flow_state, S.INTRO)
	assert_true(game.can_skip_intro(101))
	assert_true(game.finish_intro(101, true))
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(game.run.boss_index, 0)


func test_intro_stays_without_input_until_the_cap() -> void:
	# The Intro screen polls finish_intro every physics frame without a skip request.
	var game: Node = _game()
	game.start_run_from_title(100)
	for frame: int in range(101, 580):
		assert_false(game.finish_intro(frame), "no skip input at f=%d" % frame)
	assert_eq(game.flow_state, S.INTRO)
	assert_true(game.finish_intro(580))
	assert_eq(game.flow_state, S.FIGHT)


func test_intro_times_out_after_480_frames() -> void:
	assert_eq(GameScript.INTRO_MAX_FRAMES, 480)
	var game: Node = _game()
	game.start_run_from_title(100)
	assert_eq(game.intro_start_frame, 100)
	assert_false(game.intro_timed_out(579))
	assert_true(game.intro_timed_out(580))
	# The timeout alone moves the flow, independent of the skip rule.
	game.first_input_frame = 10_000
	assert_false(game.finish_intro(579))
	assert_eq(game.flow_state, S.INTRO)
	assert_true(game.finish_intro(580))
	assert_eq(game.flow_state, S.FIGHT)


func test_finish_intro_outside_intro_does_nothing() -> void:
	var game: Node = _game()
	watch_signals(EventBus)
	assert_false(game.finish_intro(10_000, true))
	assert_eq(game.flow_state, S.TITLE)
	assert_signal_emit_count(EventBus, "flow_state_changed", 0)


func test_debug_jump_ignored_when_debug_disabled() -> void:
	Debug.enabled = false
	var game: Node = _game()
	watch_signals(EventBus)
	game.debug_jump(S.FIGHT, 2)
	assert_eq(game.flow_state, S.TITLE)
	assert_eq(game.run.boss_index, 0)
	assert_signal_emit_count(EventBus, "flow_state_changed", 0)


func test_debug_jump_targets() -> void:
	Debug.enabled = true
	var game: Node = _game()
	watch_signals(EventBus)
	game.debug_jump(S.FIGHT, 1)
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(game.run.boss_index, 1)
	game.debug_jump(S.ENDING, 0)
	assert_eq(game.flow_state, S.ENDING)
	assert_eq(game.run.boss_index, 0)
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [S.FIGHT, S.ENDING])


func test_debug_jump_to_title_clears_first_input_frame() -> void:
	Debug.enabled = true
	var game: Node = _game()
	game.start_run_from_title(42)
	game.debug_jump(S.TITLE, 0)
	assert_eq(game.flow_state, S.TITLE)
	assert_eq(game.first_input_frame, -1)
	assert_false(game.can_skip_intro(43))


func test_debug_jump_into_fight_starts_the_first_shift_clock() -> void:
	Debug.enabled = true
	var game: Node = _game()
	game.debug_jump(S.FIGHT, 1)
	assert_true(game.first_input_frame >= 0, "a debug-entered run still starts the clock")
	assert_eq(game.intro_start_frame, -1)


func test_debug_jump_rejects_other_targets_and_bad_boss() -> void:
	Debug.enabled = true
	var game: Node = _game()
	watch_signals(EventBus)
	game.debug_jump(S.HARVEST, 0)
	game.debug_jump(S.DEAD, 0)
	game.debug_jump(S.INTRO, 0)
	game.debug_jump(S.FIGHT, 3)
	game.debug_jump(S.FIGHT, -1)
	assert_eq(game.flow_state, S.TITLE)
	assert_signal_emit_count(EventBus, "flow_state_changed", 0)


# --- Story 2.1 D1: fight seed on every FIGHT entry ---

func _assert_clock_seeded_with(seed_value: int) -> void:
	var expected := SimContext.new()
	expected.reseed(seed_value)
	assert_eq(SimClock.ctx.rng.randi(), expected.rng.randi(), "SimClock.ctx reseeded with run.fight_seed")


func test_run_state_fight_seed_defaults_to_zero() -> void:
	assert_eq(RunState.new().fight_seed, 0)


func test_intro_to_fight_seeds_the_fight() -> void:
	var game: Node = _game()
	game.start_run_from_title(0)
	SimClock.buffer.push(&"action_1", SimClock.sim_frame)
	game.advance()
	assert_eq(game.flow_state, S.FIGHT)
	assert_gt(game.run.fight_seed, 0)
	assert_eq(SimClock.buffer.size(), 0, "begin_fight cleared the buffer")
	_assert_clock_seeded_with(game.run.fight_seed)


func test_each_fight_entry_takes_a_new_seed() -> void:
	var game: Node = _game()
	game.start_run_from_title(0)
	game.advance() # FIGHT 1
	var first: int = game.run.fight_seed
	game.advance() # HARVEST
	game.advance() # FIGHT 2
	assert_ne(game.run.fight_seed, first)
	_assert_clock_seeded_with(game.run.fight_seed)


func test_debug_jump_into_fight_seeds_the_fight() -> void:
	Debug.enabled = true
	var game: Node = _game()
	game.debug_jump(S.FIGHT, 1)
	assert_gt(game.run.fight_seed, 0)
	_assert_clock_seeded_with(game.run.fight_seed)


# --- Story 2.9: death, retry gate, deaths_on_boss and the fight-start snapshot ---

func _fight(game: Node, boss: int = 0) -> void:
	Debug.enabled = true
	game.debug_jump(S.FIGHT, boss)
	assert_eq(game.flow_state, S.FIGHT)


func test_retry_open_boundary() -> void:
	assert_eq(GameScript.RETRY_DELAY_FRAMES, 20)
	assert_false(GameScript.retry_open(100, 119), "19 frames after: closed")
	assert_true(GameScript.retry_open(100, 120), "20 frames after: open")
	assert_true(GameScript.retry_open(100, 500))
	assert_false(GameScript.retry_open(-1, 500), "no death: closed")


func test_record_death_counts_enters_dead_and_emits() -> void:
	var game: Node = _game()
	_fight(game, 1)
	watch_signals(EventBus)
	assert_true(game.record_death(200))
	assert_eq(game.flow_state, S.DEAD)
	assert_eq(game.run.deaths_on_boss, 1)
	assert_eq(game.death_frame, 200)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"null_pointer", 1])
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [S.FIGHT, S.DEAD])


func test_record_death_ignored_outside_fight() -> void:
	var game: Node = _game()
	watch_signals(EventBus)
	assert_false(game.record_death(10))
	assert_eq(game.flow_state, S.TITLE)
	assert_eq(game.run.deaths_on_boss, 0)
	assert_signal_not_emitted(EventBus, "player_died")


func test_lethal_damage_signal_records_the_death() -> void:
	var game: Node = _game()
	_fight(game)
	game.on_player_damaged(3)
	assert_eq(game.flow_state, S.FIGHT, "a non-lethal hit is not a death")
	game.on_player_damaged(0)
	assert_eq(game.flow_state, S.DEAD)
	assert_eq(game.run.deaths_on_boss, 1)


func test_retry_refused_outside_dead_and_before_the_gate() -> void:
	var game: Node = _game()
	assert_false(game.retry(1000), "refused on TITLE")
	_fight(game)
	assert_false(game.retry(1000), "refused in FIGHT")
	game.record_death(100)
	assert_false(game.retry(100), "same frame")
	assert_false(game.retry(119), "19 frames")
	assert_eq(game.flow_state, S.DEAD)


func test_retry_after_the_gate_returns_to_fight() -> void:
	var game: Node = _game()
	_fight(game)
	game.record_death(100)
	watch_signals(EventBus)
	assert_true(game.retry(120))
	assert_eq(game.flow_state, S.FIGHT)
	assert_eq(game.death_frame, -1)
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [S.DEAD, S.FIGHT])
	assert_true(SimClock.get(&"_swallow_presses"), "the retry press never fires an action")
	SimClock.set(&"_swallow_presses", false)


func test_deaths_on_boss_kept_by_retry_and_reset_by_a_new_boss() -> void:
	var game: Node = _game()
	_fight(game, 0)
	for i: int in 3:
		game.record_death(100 * (i + 1))
		assert_true(game.retry(100 * (i + 1) + 20))
	SimClock.set(&"_swallow_presses", false)
	assert_eq(game.run.deaths_on_boss, 3, "retries keep the count")
	game.debug_jump(S.FIGHT, 1)
	assert_eq(game.run.deaths_on_boss, 0, "a new boss resets it")
	var run := RunState.new()
	run.deaths_on_boss = 2
	run.start_boss(2)
	assert_eq(run.boss_index, 2)
	assert_eq(run.deaths_on_boss, 0)


func test_harvest_to_fight_resets_deaths() -> void:
	var game: Node = _game()
	game.start_run_from_title(1)
	game.advance() # INTRO -> FIGHT 0
	game.record_death(50)
	assert_eq(game.run.deaths_on_boss, 1)
	game.retry(70)
	game.advance() # FIGHT -> HARVEST
	game.advance() # HARVEST -> FIGHT 1
	SimClock.set(&"_swallow_presses", false)
	assert_eq(game.run.boss_index, 1)
	assert_eq(game.run.deaths_on_boss, 0)


func test_snapshot_captured_on_fight_entry_not_on_retry() -> void:
	var game: Node = _game()
	_fight(game, 1)
	assert_eq(game.run.fight_start_ring, Register.fight_start_for_boss(1))
	game.run.fight_start_ring = PackedInt32Array([Register.Bit.DASH, Register.Bit.ATTACK, Register.Bit.LOOP])
	var marker: PackedInt32Array = game.run.fight_start_ring
	game.record_death(10)
	game.retry(30)
	SimClock.set(&"_swallow_presses", false)
	assert_eq(game.run.fight_start_ring, marker, "a retry restores, never re-captures")
	game.record_death(40)
	game.debug_jump(S.FIGHT, 0) # a debug jump out of DEAD is a new fight
	assert_eq(game.run.fight_start_ring, Register.fight_start_for_boss(0))


func test_boss_ids() -> void:
	assert_eq(GameScript.boss_id(0), &"infinite_loop")
	assert_eq(GameScript.boss_id(1), &"null_pointer")
	assert_eq(GameScript.boss_id(2), &"segfault")
	assert_eq(GameScript.boss_id(3), &"")


func test_dead_is_not_pausable() -> void:
	var game: Node = _game()
	_fight(game)
	game.record_death(10)
	assert_false(game.set_paused(true, &"esc"))
	assert_false(SimClock.paused)
