extends GutTest
## Story 6.8 (D4, D5; AC 1-9, 14-17): Main, the Arena, the real last boss, the autoload Game and
## SimClock. The last fight's defeat opens the real EndingScreen with no arena and a duck-only HUD;
## duck line 9 is requested once at timeline frame 300 and not before; a press before the leave gate
## does nothing, one after it returns to TITLE with a fresh run. Both the full run (Segfault) and the
## cut #4 path (Null Pointer last) play the same beats. The stretch summary card follows
## FeatureFlags.ending_summary and hides on a debug-jumped run (closes the deferred 5.6 Main-level
## ENDING route item).

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState
const B := EndingScreen.Beat
const ENDING_TEXT := "Quack. Works on your machine now."

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_first: int
var _saved_intro: int
var _saved_source: InputSource
var _saved_stats: RunStats
var _main: Node2D


## The ScreenFX shader compiles on its first instance in the process, and the headless dummy renderer
## reports an engine error for it; absorb it here so no test of this script sees it.
func before_all() -> void:
	ScreenFX.new().free()


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_first = Game.first_input_frame
	_saved_intro = Game.intro_start_frame
	_saved_source = SimClock.input_source
	_saved_stats = Game.stats
	SimClock.input_source = null # headless: no presses
	SimClock.paused = false
	Game.run = RunState.new()
	Game.stats = RunStats.new()
	Game.flow_state = S.TITLE
	Game.first_input_frame = -1
	Game.intro_start_frame = -1


func after_each() -> void:
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


## Main with the given cut-ladder flags (null = the shipped flags), swapped before it enters the tree.
func _make_main(summary_on: bool = true) -> void:
	_main = MainScene.instantiate()
	var flags: FeatureFlags = Defs.FEATURE_FLAGS.duplicate()
	flags.ending_summary = summary_on
	_main.feature_flags = flags
	add_child_autofree(_main)
	_main.apply_flow_state(S.TITLE, 0)


func _tick(times: int) -> void:
	for i: int in times:
		SimClock.tick()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


## Kills the arena's boss (`index`, entered by debug jump) and lets Main route the defeat.
func _defeat_last_fight(index: int) -> void:
	Debug.enabled = true
	Game.debug_jump(S.FIGHT, index)
	var boss: BossController = _main.arena.boss
	assert_not_null(boss, "the real boss %d" % index)
	boss.debug_kill()
	_tick(1 + BossController.DEFEAT_HITSTOP_FRAMES + BossController.DEFEAT_FRAMES)
	assert_true(boss.defeat_finished())
	assert_true(_main.poll_defeat(), "Main routes the defeat after the tick")


## The Ending screen Main built, stepped by hand.
func _ending() -> EndingScreen:
	assert_eq(Game.flow_state, S.ENDING)
	var screen := _main.current_screen as EndingScreen
	assert_not_null(screen, "Main builds the real EndingScreen (AC 2)")
	if screen != null:
		screen.set_physics_process(false)
	return screen


## Ticks the sim to timeline frame `frame` of the ending, polling the screen every tick.
func _run_to(screen: EndingScreen, frame: int) -> void:
	while SimClock.sim_frame - Game.ending_start_frame < frame:
		SimClock.tick()
		screen.poll(SimClock.sim_frame)


## The shared beats of every ending path: line 9 at 300 once, the gated leave, the reset.
func _play_and_leave(screen: EndingScreen) -> void:
	assert_false(_main.arena.visible, "AC 3: no arena")
	assert_true(_main.hud.visible, "AC 3: the HUD carries the bubble")
	assert_true(_main.hud.is_duck_only(), "duck-only HUD")
	assert_false(_main.hud.register_panel.visible, "no register HUD")
	assert_eq(Game.ending_start_frame, SimClock.sim_frame, "AC 1: the timeline starts on entry")
	watch_signals(EventBus)
	screen.poll(SimClock.sim_frame)
	assert_eq(screen.shown_beat, B.FADE)
	screen._unhandled_input(_key(KEY_X))
	assert_eq(Game.flow_state, S.ENDING, "AC 6: the press that ended the fight never leaves")
	_run_to(screen, 299)
	assert_signal_not_emitted(EventBus, "duck_line_requested", "no line before frame 300")
	assert_eq(screen.shown_beat, B.COMMIT)
	_run_to(screen, 300)
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"ending", ENDING_TEXT])
	_run_to(screen, 900)
	assert_eq(screen.shown_beat, B.HOLD)
	_tick(120)
	screen.poll(SimClock.sim_frame)
	assert_eq(Game.flow_state, S.ENDING, "AC 5: the ending never times out to TITLE")
	assert_signal_emit_count(EventBus, "duck_line_requested", 1, "line 9 once per ending")
	screen._unhandled_input(_key(KEY_X))
	assert_eq(Game.flow_state, S.TITLE, "a key after the gate leaves")
	assert_true(_main.current_screen is TitleScreen)
	assert_eq(Game.first_input_frame, -1, "the run is reset")
	assert_eq(Game.run.boss_index, 0)
	assert_eq(Game.run.run_seed, 0, "a fresh RunState")
	assert_eq(Game.ending_summary, {}, "AC 15: the snapshot is cleared")


func test_segfault_defeat_plays_the_ending_and_returns_to_title() -> void:
	_make_main()
	Game.segfault_enabled = true
	_defeat_last_fight(2)
	_play_and_leave(_ending())


func test_null_pointer_last_with_segfault_cut_plays_the_same_ending() -> void:
	_make_main()
	Game.segfault_enabled = false # cut ladder #4
	_defeat_last_fight(1)
	assert_false(Game.run.fight_start_ring.has(Register.Bit.NULL_BIT), "NULL is never dropped")
	_play_and_leave(_ending())


func test_pause_freezes_the_timeline_and_blocks_the_leave() -> void:
	_make_main()
	Game.segfault_enabled = true
	_defeat_last_fight(2)
	var screen: EndingScreen = _ending()
	_run_to(screen, 100)
	assert_true(Game.handle_pause_input(_esc()), "AC 8: Esc pauses the ending")
	var frame: int = SimClock.sim_frame
	_tick(200)
	screen.poll(SimClock.sim_frame)
	assert_eq(SimClock.sim_frame, frame, "the timeline freezes")
	assert_eq(screen.timeline_frame, 100)
	screen._unhandled_input(_key(KEY_X))
	assert_eq(Game.flow_state, S.ENDING, "a press while paused does nothing")
	Game.set_paused(false, &"esc")
	screen._unhandled_input(_key(KEY_X))
	assert_eq(Game.flow_state, S.TITLE)


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ESCAPE
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


## A clean run (no debug key): title, Intro skip, fights left through advance(), one landed hit.
func _clean_run_to_ending() -> void:
	Debug.enabled = false
	Game.segfault_enabled = true
	SimClock.sim_frame += 1
	Game.start_run_from_title(SimClock.sim_frame)
	_tick(30) # Intro time is not counted (D-S68-4)
	assert_true(Game.finish_intro(SimClock.sim_frame, true))
	var fight_start: int = SimClock.sim_frame
	EventBus.player_damaged.emit(4)
	_tick(60)
	Game.advance() # HARVEST
	assert_true(Game.finish_harvest(SimClock.sim_frame)) # FIGHT 2
	Game.advance() # HARVEST
	assert_true(Game.finish_harvest(SimClock.sim_frame)) # FIGHT 3
	_tick(60)
	Game.advance() # ENDING
	assert_eq(Game.flow_state, S.ENDING)
	assert_eq(Game.ending_summary[&"clear_frames"], SimClock.sim_frame - fight_start)
	assert_eq(Game.ending_summary[&"hits"], 1)
	assert_false(Game.ending_summary[&"debug_jumped"])


func test_summary_card_on_a_clean_run() -> void:
	_make_main(true)
	_clean_run_to_ending()
	var screen: EndingScreen = _ending()
	assert_true(screen.summary_enabled, "Main wires the flag")
	assert_true(screen.summary_shown(), "AC 14")
	_run_to(screen, 360)
	assert_eq(screen.shown_beat, B.SUMMARY)
	screen.queue_redraw()
	await get_tree().process_frame # the card draws without errors
	_run_to(screen, 539)
	assert_eq(screen.shown_beat, B.SUMMARY)
	_run_to(screen, 540)
	assert_eq(screen.shown_beat, B.CREDITS, "credits at 540 after the card")
	screen.queue_redraw()
	await get_tree().process_frame


func test_summary_flag_off_has_no_card() -> void:
	_make_main(false)
	_clean_run_to_ending()
	var screen: EndingScreen = _ending()
	assert_false(screen.summary_enabled)
	assert_false(screen.summary_shown(), "AC 17: no card")
	_run_to(screen, 360)
	assert_eq(screen.shown_beat, B.CREDITS, "credits at 360")
	screen.queue_redraw()
	await get_tree().process_frame
	_run_to(screen, 300 + 600)
	assert_eq(screen.shown_beat, B.HOLD, "the timeline is otherwise identical")


func test_debug_jumped_run_has_no_card() -> void:
	_make_main(true)
	Game.segfault_enabled = true
	_defeat_last_fight(2)
	var screen: EndingScreen = _ending()
	assert_true(Game.ending_summary[&"debug_jumped"])
	assert_false(screen.summary_shown(), "AC 16: a debug-jumped run is not a clear")
	_run_to(screen, 360)
	assert_eq(screen.shown_beat, B.CREDITS, "credits at 360")
