extends GutTest
## Story 6.9 (E2, AC 4; D-S69-5): every duck line fires in a full run driven through the real Main,
## Game and SimClock: Title -> Intro (line 1) -> Fight 1 (T1-T4) -> Harvest (line 8) -> Fight 2 (the
## Breakpoint and Watch lines, a Breakpoint hint) -> Harvest -> Fight 3 (the 3rd-death hint) ->
## Ending (line 9); and the same flow lines with the Segfault cut (Null Pointer last).
## Seams (said where used): the director's bubble is detached so a line never waits for the previous
## one to finish (the D-S44-4 queue is covered by test_duck_director.gd); the director is polled by
## hand after each tick (no `_process` in a headless test); the Breakpoint hint is triggered by the
## EventBus signal the real skill emits (the skill's input path is test_breakpoint_skill.gd); the 3rd
## death uses the retry-snapshot route (queued hits, Game.retry), as test_retry_snapshot.gd does.
## Deterministic: the run seed is fixed right after the title press (RUN_SEED), so every fight seed
## (RunState.fight_seed_for) is the same on every run; nothing else reads an RNG.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")
## Upper bound of sim ticks to wait for the Infinite Loop's first `;` (iteration 1).
const MAX_TICKS_TO_FIRST_SEMICOLON := 3000
## The fixed run seed (Game._begin_fight seeds from the clock only when it is 0).
const RUN_SEED := 69069

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_first: int
var _saved_intro: int
var _saved_source: InputSource
var _saved_stats: RunStats
var _saved_unlocked: bool
var _main: Node2D
## Every line id requested, in order.
var _said: Array[StringName] = []


func before_all() -> void:
	ScreenFX.new().free() # absorbs the headless shader compile error (test_ending_flow.gd pattern)


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_first = Game.first_input_frame
	_saved_intro = Game.intro_start_frame
	_saved_source = SimClock.input_source
	_saved_stats = Game.stats
	_saved_unlocked = AudioManager.is_unlocked()
	SimClock.input_source = null # headless: no presses
	SimClock.paused = false
	Game.run = RunState.new()
	Game.stats = RunStats.new()
	Game.flow_state = S.TITLE
	Game.first_input_frame = -1
	Game.intro_start_frame = -1
	_said.clear()
	EventBus.duck_line_requested.connect(_on_line)


func after_each() -> void:
	if EventBus.duck_line_requested.is_connected(_on_line):
		EventBus.duck_line_requested.disconnect(_on_line)
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Game.stats = _saved_stats
	Game.first_input_frame = _saved_first
	Game.intro_start_frame = _saved_intro
	Game.ending_start_frame = -1
	Game.ending_summary = {}
	Game.harvest_start_frame = -1
	Debug.enabled = _saved_enabled
	SimClock.input_source = _saved_source
	SimClock.begin_fight(0)
	SimClock.paused = false
	Game.segfault_enabled = Defs.FEATURE_FLAGS.segfault
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false) # the title press unlocked audio (test_intro_flow.gd)


func _on_line(line_id: StringName, _text: String) -> void:
	_said.append(line_id)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


## One sim tick, then the director's poll (its `_process` does not run headless).
func _tick(times: int = 1) -> void:
	for i: int in times:
		SimClock.tick()
		_main.duck_director.poll()


func _make_main() -> void:
	_main = MainScene.instantiate()
	add_child_autofree(_main)
	_main.apply_flow_state(S.TITLE, 0)
	_main.duck_director.bubble = null # seam: no wait on the previous line (header)


## Title press -> Intro -> panel 3 (line 1) -> skip into Fight 1.
func _intro_to_fight_1() -> void:
	(_main.current_screen as TitleScreen).handle_input(_key(KEY_X))
	assert_eq(Game.flow_state, S.INTRO)
	Game.run.run_seed = RUN_SEED # determinism: the title press made a fresh RunState
	var intro := _main.current_screen as IntroScreen
	intro.squeak = func() -> void: pass
	intro.set_physics_process(false)
	while SimClock.sim_frame < Game.intro_start_frame + IntroScreen.PANEL_FRAMES * 2 + 1:
		SimClock.tick()
		intro.poll(SimClock.sim_frame)
	assert_true(_said.has(IntroScreen.LINE_ID), "line 1 on panel 3")
	assert_true(intro.try_skip(SimClock.sim_frame))
	assert_eq(Game.flow_state, S.FIGHT)
	assert_eq(Game.run.boss_index, 0)


## Fight 1: T1 at control start, T2 at the first `;`, T3 on the Dash Strike window, T4 in phase 2.
func _fight_1_beats() -> void:
	var boss := _main.arena.boss as InfiniteLoopBody
	assert_not_null(boss, "the real Infinite Loop")
	_tick()
	assert_eq(_said[-1], &"t1_shift", "T1 as soon as control starts")
	var ticks: int = 0
	while not _said.has(&"t2_semicolon") and ticks < MAX_TICKS_TO_FIRST_SEMICOLON and Game.flow_state == S.FIGHT:
		_main.arena.health.hp = Arena.PLAYER_DEF.max_hp # keep the idle player alive while waiting
		_tick()
		ticks += 1
	assert_true(_said.has(&"t2_semicolon"), "T2 at the first `;` (iteration %d)" % boss.iteration)
	_main.arena.register.shift(Register.LEFT) # [D, A] -> [A, D]: Dash Strike
	_tick()
	assert_eq(_said[-1], &"t3_dash_strike", "T3 on the Dash Strike window")
	assert_true(boss.debug_skip_phase(), "phase 2")
	_tick()
	assert_eq(_said[-1], &"t4_phase_two", "T4 at phase 2")


## Kills the arena's boss and lets Main route the defeat.
func _defeat_boss() -> void:
	var boss: BossController = _main.arena.boss
	assert_not_null(boss)
	boss.debug_kill()
	for i: int in 1 + BossController.DEFEAT_HITSTOP_FRAMES + BossController.DEFEAT_FRAMES:
		SimClock.tick()
	assert_true(boss.defeat_finished())
	assert_true(_main.poll_defeat(), "Main routes the defeat")


## Harvest (line 8, requested deferred) -> the next fight.
func _harvest_to_next_fight() -> void:
	assert_eq(Game.flow_state, S.HARVEST)
	var before: int = _said.count(HarvestScreen.LINE_ID)
	await get_tree().process_frame # the deferred line request (test_harvest_flow.gd)
	assert_eq(_said.count(HarvestScreen.LINE_ID), before + 1, "line 8 on each harvest")
	assert_true(Game.finish_harvest(SimClock.sim_frame))
	assert_eq(Game.flow_state, S.FIGHT)


## Fight 2: the Breakpoint line, then the Watch line, then a Breakpoint hint of the current window.
func _fight_2_beats() -> void:
	assert_true(_main.arena.boss is NullPointerBody, "the real Null Pointer")
	_tick()
	assert_eq(_said[-1], &"n1_breakpoint", "line 6 at Boss 2 start")
	_tick()
	assert_eq(_said[-1], &"n2_hold_r", "line 7 after line 6")
	EventBus.breakpoint_started.emit() # seam: the real skill's signal (header)
	_tick()
	assert_eq(_said[-1], DuckHint.line_id_for(_main.arena.boss.current_weak_window()), "line 10 on Breakpoint")


## Three deaths on the current boss; the retry after the third says the hint of the death window.
func _third_death_hint() -> void:
	var boss_id: StringName = _main.arena.boss.def.boss_id
	for death: int in DuckDirector.DEATHS_PER_HINT:
		for hit: int in Arena.PLAYER_DEF.max_hp:
			_main.arena.health.queue_hit()
			SimClock.tick()
			if Game.flow_state == S.DEAD:
				break
			for i: int in HitFeedback.PLAYER_HITSTOP + Arena.PLAYER_DEF.invuln_frames:
				SimClock.tick()
		assert_eq(Game.flow_state, S.DEAD, "death %d" % (death + 1))
		# The death hit-stop holds sim frames, so wait for the gate itself (RETRY_DELAY_FRAMES after it).
		var waited: int = 0
		while not GameScript.retry_open(Game.death_frame, SimClock.sim_frame) and waited < 600:
			SimClock.tick()
			waited += 1
		var count: int = _said.size()
		assert_true(Game.retry(SimClock.sim_frame), "retry %d" % (death + 1))
		_main.duck_director.poll()
		if death + 1 < DuckDirector.DEATHS_PER_HINT:
			assert_eq(_said.size(), count, "no hint before the 3rd death")
	assert_eq(Game.run.deaths_on_boss, DuckDirector.DEATHS_PER_HINT)
	assert_true(DuckHint.is_hint_id(_said[-1]), "line 10 on the retry after the 3rd death on %s" % boss_id)


## Ending: line 9 at timeline frame 300.
func _ending_line() -> void:
	assert_eq(Game.flow_state, S.ENDING)
	var screen := _main.current_screen as EndingScreen
	screen.set_physics_process(false)
	while SimClock.sim_frame - Game.ending_start_frame < EndingScreen.LINE_FRAME:
		SimClock.tick()
		screen.poll(SimClock.sim_frame)
	assert_eq(_said[-1], EndingScreen.LINE_ID, "line 9 at the ending")


## Every hand-written duck line and the hint template were requested in this run.
func _assert_every_line_said(expect_watch: bool) -> void:
	var hints: int = 0
	for entry: DuckLineDef in LINES.entries:
		if DuckHint.is_hint_id(entry.id):
			continue
		if entry.id == DuckDirector.N2 and not expect_watch:
			continue
		assert_true(_said.has(entry.id), "%s fires in the run" % entry.id)
	for id: StringName in _said:
		assert_not_null(LINES.find(id), "%s is a catalogue line (a clip exists)" % id)
		if DuckHint.is_hint_id(id):
			hints += 1
	assert_gt(hints, 0, "the hint template fires")


func test_full_run_with_the_segfault_requests_every_duck_line() -> void:
	_make_main()
	Game.segfault_enabled = true
	_intro_to_fight_1()
	_fight_1_beats()
	_defeat_boss()
	await _harvest_to_next_fight()
	_fight_2_beats()
	_defeat_boss()
	await _harvest_to_next_fight()
	assert_eq(_main.arena.boss.def.boss_id, &"segfault")
	_third_death_hint()
	_defeat_boss()
	_ending_line()
	_assert_every_line_said(true)


func test_run_with_the_segfault_cut_still_ends_with_line_9() -> void:
	_make_main() # Main applies the shipped flags on entry: flip the cut after it
	Game.segfault_enabled = false # cut ladder #4: Null Pointer last
	_intro_to_fight_1()
	_fight_1_beats()
	_defeat_boss()
	await _harvest_to_next_fight()
	_fight_2_beats()
	_third_death_hint()
	_defeat_boss()
	_ending_line()
	_assert_every_line_said(true)
