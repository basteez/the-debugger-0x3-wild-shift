extends GutTest
## Story 7.6 (FR59, AC 1-19): the title's practice target. Loadout list per highest_boss, Game practice
## start / cycle / leave transitions (no save write, no clear), Esc / P / pad routing in practice, the
## title option (P, L3, click), the release-build wiring (Debug.enabled false) and the frame counter.
## No random picks: the dummy has no attacks and no boss is placed.

const GameScript := preload("res://src/autoloads/game.gd")
const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")
const MainScene := preload("res://src/main/main.tscn")
const S := GameScript.FlowState
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT

var _saved_save: Dictionary = {}
var _saved_enabled: bool
var _saved_frame: int
var _saved_paused: bool
var _saved_flow: int
var _saved_run: RunState
var _saved_stats: RunStats
var _saved_first_input: int
var _saved_unlocked: bool
var _saved_death_frame: int


func before_each() -> void:
	_saved_save = {
		"path": SaveService.path, "highest_boss": SaveService.highest_boss, "assist": SaveService.assist,
		"muted": SaveService.muted, "track_fights": SaveService.track_fights,
	}
	_saved_enabled = Debug.enabled
	_saved_frame = SimClock.sim_frame
	_saved_paused = SimClock.paused
	_saved_flow = Game.flow_state
	_saved_run = Game.run
	_saved_stats = Game.stats
	_saved_first_input = Game.first_input_frame
	_saved_unlocked = AudioManager.is_unlocked()
	_saved_death_frame = Game.death_frame
	SaveService.path = "" # in-memory only
	SimClock.paused = false


func after_each() -> void:
	for key: String in _saved_save:
		SaveService.set(key, _saved_save[key])
	Debug.enabled = _saved_enabled
	SimClock.sim_frame = _saved_frame
	SimClock.paused = _saved_paused
	Game.practice_run = false
	Game.practice_loadouts_offered = []
	Game.practice_loadout_index = 0
	Game.practice_start_frame = -1
	Game.flow_state = _saved_flow as GameScript.FlowState
	Game.run = _saved_run
	Game.stats = _saved_stats
	Game.first_input_frame = _saved_first_input
	Game.death_frame = _saved_death_frame
	if not _saved_unlocked:
		AudioManager.set("_unlocked", false)


func _game(state: S = S.TITLE) -> Node:
	var game: Node = autofree(GameScript.new())
	game.flow_state = state
	return game


func _practice(highest_boss: int = 1) -> Node:
	var game: Node = _game()
	game.start_practice_from_title(100, highest_boss)
	return game


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	return ev


func _click(pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	return ev


func _ring(bits: Array) -> PackedInt32Array:
	return PackedInt32Array(bits)


# --- Loadouts (AC 9, 10) --------------------------------------------------------------------------

func test_loadouts_match_the_gdd_fight_start_sets() -> void:
	# The bits the boss defs drop (Infinite Loop drops LOOP, Null Pointer drops NULL) build these sets.
	assert_eq(Register.fight_start_for_boss(0), _ring([D, A]))
	assert_eq(Register.fight_start_for_boss(1), _ring([A, D, L]))
	assert_eq(Register.fight_start_for_boss(2), _ring([A, D, L, N]))
	assert_eq((load("res://data/bosses/infinite_loop/boss_def.tres") as BossDef).drop_bit, L)
	assert_eq((load("res://data/bosses/null_pointer/boss_def.tres") as BossDef).drop_bit, N)


func test_loadout_list_per_highest_boss() -> void:
	assert_eq(GameScript.practice_loadouts(1), [_ring([D, A]), _ring([A, D, L, N])] as Array[PackedInt32Array],
			"fresh save: [D, A] plus the full set")
	assert_eq(GameScript.practice_loadouts(2), [_ring([D, A]), _ring([A, D, L]), _ring([A, D, L, N])] as Array[PackedInt32Array])
	assert_eq(GameScript.practice_loadouts(3), [_ring([D, A]), _ring([A, D, L]), _ring([A, D, L, N])] as Array[PackedInt32Array],
			"Boss 3 reached: its set is the full set, listed once")
	assert_eq(GameScript.practice_loadout_bosses(0), [0, 2] as Array[int], "clamped low")
	assert_eq(GameScript.practice_loadout_bosses(9), [0, 1, 2] as Array[int], "clamped high")


func test_start_index_is_the_highest_reached_never_the_extra_full_set() -> void:
	assert_eq(GameScript.practice_start_index(1), 0)
	assert_eq(GameScript.practice_start_index(2), 1)
	assert_eq(GameScript.practice_start_index(3), 2)


# --- Game start / cycle / leave (AC 1, 6, 9, 11-14) -----------------------------------------------

func test_practice_start_enters_fight_with_the_highest_loadout() -> void:
	for hb: int in [1, 2, 3]:
		var game: Node = _practice(hb)
		assert_eq(game.flow_state, S.FIGHT, "no Intro (hb %d)" % hb)
		assert_true(game.practice_run)
		assert_eq(game.run.fight_start_ring, Register.fight_start_for_boss(hb - 1), "hb %d ring" % hb)
		assert_eq(game.run.boss_index, hb - 1)
		assert_eq(game.first_input_frame, -1, "the 30-s first-shift clock is not started")
		assert_eq(game.practice_start_frame, SimClock.sim_frame)


func test_practice_start_refused_outside_title() -> void:
	var game: Node = _game(S.FIGHT)
	game.start_practice_from_title(1, 3)
	assert_false(game.practice_run)


func test_practice_never_writes_the_save() -> void:
	SaveService.track_fights = true
	SaveService.highest_boss = 3
	SaveService.assist = true
	SaveService.muted = true
	var game: Node = _practice(3)
	game.cycle_practice_loadout(101)
	game.cycle_practice_loadout(102)
	game.leave_practice_to_title(103)
	assert_eq(SaveService.highest_boss, 3, "a save with highest_boss 3 is unchanged")
	assert_true(SaveService.assist)
	assert_true(SaveService.muted)


func test_practice_full_set_never_raises_a_fresh_save() -> void:
	SaveService.track_fights = true
	SaveService.highest_boss = 1
	var game: Node = _practice(1)
	assert_true(game.cycle_practice_loadout(101))
	assert_eq(game.run.fight_start_ring, _ring([A, D, L, N]), "the full set")
	assert_eq(game.run.boss_index, 2)
	assert_eq(SaveService.highest_boss, 1, "practice with the full set never raises highest_boss")


func test_cycle_restarts_the_fight_through_the_offered_loadouts() -> void:
	var game: Node = _practice(2)
	var attempt: int = game.run.fight_attempt
	watch_signals(EventBus)
	assert_true(game.cycle_practice_loadout(101))
	assert_eq(game.run.fight_start_ring, _ring([A, D, L, N]))
	assert_eq(game.run.fight_attempt, attempt + 1, "a new attempt")
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [S.FIGHT, S.FIGHT])
	assert_true(game.cycle_practice_loadout(102))
	assert_eq(game.run.fight_start_ring, _ring([D, A]), "wraps to the first")
	assert_true(game.cycle_practice_loadout(103))
	assert_eq(game.run.fight_start_ring, _ring([A, D, L]))


func test_cycle_refused_paused_or_outside_practice() -> void:
	var game: Node = _practice(2)
	SimClock.paused = true
	assert_false(game.cycle_practice_loadout(101), "never from the pause screen")
	SimClock.paused = false
	var normal: Node = _game(S.FIGHT)
	assert_false(normal.cycle_practice_loadout(101))


func test_retry_after_a_death_keeps_the_chosen_loadout() -> void:
	var game: Node = _practice(1)
	game.cycle_practice_loadout(101)
	assert_true(game.record_death(110))
	assert_true(game.retry(110 + GameScript.RETRY_DELAY_FRAMES))
	assert_eq(game.run.fight_start_ring, _ring([A, D, L, N]))
	assert_true(game.practice_run)


func test_leave_resets_run_stats_and_practice() -> void:
	var game: Node = _practice(2)
	game.stats.hits = 4
	assert_true(game.leave_practice_to_title(150))
	assert_eq(game.flow_state, S.TITLE)
	assert_false(game.practice_run)
	assert_eq(game.stats.hits, 0, "fresh stats: practice never counts")
	assert_eq(game.stats.fight_start_frame, -1)
	assert_eq(game.run.fight_attempt, 0, "fresh run")
	assert_eq(game.first_input_frame, -1)
	assert_true(game.practice_loadouts_offered.is_empty(), "the chosen loadout is not kept")


func test_leave_refused_outside_practice() -> void:
	var game: Node = _game(S.FIGHT)
	assert_false(game.leave_practice_to_title(1))
	assert_eq(game.flow_state, S.FIGHT)


func test_next_practice_starts_from_the_highest_loadout_again() -> void:
	var game: Node = _practice(2)
	game.cycle_practice_loadout(101)
	game.leave_practice_to_title(102)
	game.start_practice_from_title(103, 2)
	assert_eq(game.run.fight_start_ring, _ring([A, D, L]))


func test_debug_jump_leaves_practice() -> void:
	Debug.enabled = true
	var game: Node = _practice(1)
	game.debug_jump(S.FIGHT, 1)
	assert_false(game.practice_run, "a debug jump is a normal (debug) fight again")
	assert_eq(game.run.fight_start_ring, Register.fight_start_for_boss(1))


# --- Input routing (AC 11, 13, 16) ----------------------------------------------------------------

func test_esc_in_practice_leaves_to_title_without_pausing() -> void:
	var game: Node = _practice(1)
	assert_true(game.handle_pause_input(_key(KEY_ESCAPE)))
	assert_eq(game.flow_state, S.TITLE)
	assert_false(SimClock.paused)


func test_p_pauses_in_practice_and_esc_resumes() -> void:
	var game: Node = _practice(1)
	assert_true(game.handle_pause_input(_key(KEY_P)))
	assert_true(SimClock.paused)
	assert_eq(game.flow_state, S.FIGHT)
	assert_true(game.handle_pause_input(_key(KEY_ESCAPE)), "Esc while paused resumes")
	assert_false(SimClock.paused)
	assert_eq(game.flow_state, S.FIGHT, "and never leaves")


func test_pad_start_pauses_and_l3_leaves_in_practice() -> void:
	var game: Node = _practice(1)
	assert_true(game.handle_pause_input(_pad(JOY_BUTTON_START)))
	assert_true(SimClock.paused)
	assert_true(game.handle_pause_input(_pad(JOY_BUTTON_START)))
	assert_true(game.handle_pause_input(_pad(JOY_BUTTON_LEFT_STICK)))
	assert_eq(game.flow_state, S.TITLE)


func test_esc_in_a_normal_fight_still_pauses() -> void:
	var game: Node = _game(S.FIGHT)
	assert_true(game.handle_pause_input(_key(KEY_ESCAPE)))
	assert_true(SimClock.paused)
	assert_eq(game.flow_state, S.FIGHT)


func test_l_and_select_cycle_only_in_practice() -> void:
	var game: Node = _practice(1)
	assert_true(game.handle_pause_input(_key(KEY_L)))
	assert_eq(game.practice_loadout_index, 1)
	assert_true(game.handle_pause_input(_pad(JOY_BUTTON_BACK)))
	assert_eq(game.practice_loadout_index, 0)
	assert_false(game.handle_pause_input(_key(KEY_L, true, true)), "echo ignored")
	SimClock.paused = true
	assert_false(game.handle_practice_input(_pad(JOY_BUTTON_BACK)), "Select stays mute while paused")
	SimClock.paused = false
	var normal: Node = _game(S.FIGHT)
	assert_false(normal.handle_pause_input(_key(KEY_L)), "L is nothing in a normal fight")
	assert_false(normal.handle_pause_input(_pad(JOY_BUTTON_LEFT_STICK)))
	assert_eq(normal.flow_state, S.FIGHT)


func test_cycle_key_is_not_an_input_map_action() -> void:
	for action: StringName in InputMap.get_actions():
		assert_false(InputMap.event_is_action(_key(GameScript.PRACTICE_CYCLE_KEY), action, true),
				"L is bound to %s" % action)


# --- Title option (AC 1-4) ------------------------------------------------------------------------

func _title(highest_boss: int = 1) -> TitleScreen:
	Game.flow_state = S.TITLE
	var title: TitleScreen = autofree(TitleScreenScript.new())
	title.set_saved_progress(highest_boss)
	return title


func test_practice_is_available_with_a_label_rect_below_debug_build() -> void:
	var title := _title()
	assert_true(title.is_option_available(&"practice"))
	assert_eq(title.label_rects[&"practice"], TitleScreenScript.practice_label_rect())
	assert_eq(TitleScreenScript.PRACTICE_TOP_Y, 304)
	assert_gt(TitleScreenScript.PRACTICE_TOP_Y, TitleScreenScript.DEBUG_BUILD_TOP_Y)
	assert_eq(TitleScreenScript.PRACTICE_TEXT, "[P] practice")
	var rect: Rect2 = TitleScreenScript.practice_label_rect()
	assert_true(rect.end.y <= Const.BASE_RES.y, "on screen")
	assert_false(rect.intersects(TitleScreenScript.debug_build_label_rect(false)), "no overlap with [B]")


func test_p_l3_and_click_resolve_to_the_practice_option() -> void:
	var title := _title()
	for ev: InputEvent in [_key(KEY_P), _pad(JOY_BUTTON_LEFT_STICK), _click(TitleScreenScript.practice_label_rect().get_center())]:
		assert_eq(title.resolve(ev), TitleScreenScript.Action.OPTION)
		assert_eq(TitleScreenScript.option_of(ev, title.label_rects), &"practice")


func test_title_p_starts_practice_with_the_saved_loadout() -> void:
	SaveService.track_fights = true
	SaveService.highest_boss = 2
	var title := _title(2)
	assert_eq(title.handle_input(_key(KEY_P)), TitleScreenScript.Action.OPTION)
	assert_eq(Game.flow_state, S.FIGHT)
	assert_true(Game.practice_run)
	assert_eq(Game.run.fight_start_ring, _ring([A, D, L]))
	assert_eq(SaveService.highest_boss, 2)


func test_title_l3_starts_practice() -> void:
	var title := _title()
	title.handle_input(_pad(JOY_BUTTON_LEFT_STICK))
	assert_true(Game.practice_run)
	assert_eq(Game.flow_state, S.FIGHT)


func test_title_click_on_practice_label_starts_practice() -> void:
	var title := _title()
	title.handle_input(_click(TitleScreenScript.practice_label_rect().get_center()))
	assert_true(Game.practice_run)


# --- Main wiring in a release build (AC 5, 7, 8, 17) ----------------------------------------------

func test_release_build_practice_has_target_view_counter_and_no_boss() -> void:
	Debug.enabled = false
	var main: Node2D = MainScene.instantiate()
	add_child_autofree(main)
	assert_null(main.get_node_or_null(^"DebugKeys"), "no debug tools in release")
	assert_null(main.frame_overlay, "the F9 overlay stays debug-only")
	assert_null(main.perf_overlay)
	assert_false(main.wants_practice(), "not without the title's practice")
	Game.flow_state = S.TITLE
	Game.start_practice_from_title(SimClock.sim_frame, 1)
	assert_true(main.wants_practice())
	assert_not_null(main.arena.practice_target, "the dummy in release")
	assert_eq(main.arena.practice_target.position_px, Arena.PRACTICE_TARGET_PX)
	assert_eq(main.arena.combat.targets, [main.arena.practice_target])
	assert_null(main.arena.boss, "no boss in practice")
	assert_eq(main.practice_view.target, main.arena.practice_target)
	assert_true(main.practice_counter.active, "the frame counter shows")
	main.arena.practice_target.hits = 3
	Game.cycle_practice_loadout(SimClock.sim_frame)
	assert_eq(main.arena.practice_target.hits, 0, "the dummy is reset on a loadout change")
	assert_eq(main.arena.register.ring, _ring([A, D, L, N]), "the register follows the loadout")
	Game.leave_practice_to_title(SimClock.sim_frame)
	assert_null(main.arena.practice_target)
	assert_false(main.practice_counter.active)


func test_shift_f2_sandbox_still_debug_only() -> void:
	Debug.enabled = true
	var main: Node2D = MainScene.instantiate()
	add_child_autofree(main)
	assert_false(main.wants_practice())
	main.debug_keys.practice_requested = true
	assert_true(main.wants_practice())
	assert_eq(main.boss_def_path_for(false, 0, true), "", "practice: no boss")


# --- Frame counter (AC 5, D-S76-2) ----------------------------------------------------------------

func test_frame_counter_counts_from_the_practice_start() -> void:
	assert_eq(PracticeFrameCounter.frames_since(100, 160), 60)
	assert_eq(PracticeFrameCounter.frames_since(100, 90), 0)
	assert_eq(PracticeFrameCounter.frames_since(-1, 90), 0)
	assert_eq(PracticeFrameCounter.lines_for(42)[0], "frames 42")
	assert_false(PracticeFrameCounter.lines_for(0)[1].is_empty(), "the key hint")


# --- Story 7.7: practice follow-ups (AC 14-19, D-S77-3, D-S77-4) ----------------------------------

func test_practice_death_enters_dead_but_counts_nothing() -> void:
	SaveService.track_fights = true
	SaveService.highest_boss = 2
	var game: Node = _practice(2)
	watch_signals(EventBus)
	assert_true(game.record_death(110))
	assert_eq(game.flow_state, S.DEAD, "the DEAD screen and its retry stay")
	assert_eq(game.death_frame, 110)
	assert_eq(game.run.deaths_on_boss, 0, "no deaths_on_boss in practice")
	assert_signal_not_emitted(EventBus, "player_died", "no duck death hint for the dummy")
	assert_eq(SaveService.highest_boss, 2, "no save write")
	assert_true(game.retry(110 + GameScript.RETRY_DELAY_FRAMES), "the retry still works")
	assert_true(game.practice_run)


func test_normal_death_still_counts_and_emits() -> void:
	var game: Node = _game(S.FIGHT)
	watch_signals(EventBus)
	assert_true(game.record_death(110))
	assert_eq(game.run.deaths_on_boss, 1)
	assert_signal_emitted(EventBus, "player_died")


func test_practice_hits_are_not_counted() -> void:
	var game: Node = _practice(1)
	game.on_player_damaged(3)
	game.on_player_damaged(2)
	assert_eq(game.stats.hits, 0, "run stats are never touched by practice")
	var normal: Node = _game(S.FIGHT)
	normal.on_player_damaged(3)
	assert_eq(normal.stats.hits, 1, "a normal fight still counts")


func test_lethal_practice_hit_enters_dead_without_counting() -> void:
	var game: Node = _practice(1)
	watch_signals(EventBus)
	game.on_player_damaged(0)
	assert_eq(game.flow_state, S.DEAD)
	assert_eq(game.stats.hits, 0)
	assert_eq(game.run.deaths_on_boss, 0)
	assert_signal_not_emitted(EventBus, "player_died")


func test_leave_from_practice_dead_is_immediate() -> void:
	SaveService.track_fights = true
	SaveService.highest_boss = 3
	var game: Node = _practice(3)
	game.record_death(110)
	assert_true(game.leave_practice_to_title(111), "no retry gate")
	assert_eq(game.flow_state, S.TITLE)
	assert_false(game.practice_run)
	assert_eq(SaveService.highest_boss, 3, "no save write")


func test_leave_refused_from_a_normal_dead_and_other_states() -> void:
	for state: S in [S.DEAD, S.TITLE, S.INTRO, S.HARVEST, S.ENDING]:
		var game: Node = _game(state)
		assert_false(game.leave_practice_to_title(1), "not practice, state %d" % state)
		assert_eq(game.flow_state, state)
	for state: S in [S.TITLE, S.INTRO, S.HARVEST, S.ENDING]:
		var game: Node = _game(state)
		game.practice_run = true # a stale flag never leaves from a non-practice state
		assert_false(game.leave_practice_to_title(1), "practice flag, state %d" % state)


func _practice_dead_screen() -> DeadScreen:
	Game.flow_state = S.TITLE
	Game.start_practice_from_title(SimClock.sim_frame, 1)
	Game.record_death(SimClock.sim_frame)
	var dead: DeadScreen = DeadScreen.new()
	add_child_autofree(dead)
	return dead


func test_esc_and_l3_leave_a_practice_dead_screen() -> void:
	for ev: InputEvent in [_key(KEY_ESCAPE), _pad(JOY_BUTTON_LEFT_STICK)]:
		var dead: DeadScreen = _practice_dead_screen()
		assert_eq(Game.flow_state, S.DEAD)
		dead._unhandled_input(ev)
		assert_eq(Game.flow_state, S.TITLE, "%s leaves at once" % ev)
		assert_false(Game.practice_run)


func test_other_presses_on_a_practice_dead_screen_follow_the_retry_rule() -> void:
	var dead: DeadScreen = _practice_dead_screen()
	dead._unhandled_input(_key(KEY_J))
	assert_eq(Game.flow_state, S.DEAD, "before the retry gate a press does nothing")
	SimClock.sim_frame = Game.death_frame + GameScript.RETRY_DELAY_FRAMES
	dead._unhandled_input(_key(KEY_J))
	assert_eq(Game.flow_state, S.FIGHT, "a retry of the dummy")
	assert_true(Game.practice_run)


func test_normal_dead_esc_does_nothing_and_l3_retries() -> void:
	Game.flow_state = S.FIGHT
	Game.run = RunState.new()
	Game.record_death(SimClock.sim_frame)
	var dead: DeadScreen = DeadScreen.new()
	add_child_autofree(dead)
	SimClock.sim_frame = Game.death_frame + GameScript.RETRY_DELAY_FRAMES
	dead._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(Game.flow_state, S.DEAD, "Esc does nothing on a normal DEAD")
	dead._unhandled_input(_pad(JOY_BUTTON_LEFT_STICK))
	assert_eq(Game.flow_state, S.FIGHT, "L3 retries (7.5 AC 9)")


func test_loadout_list_with_the_segfault_cut() -> void:
	assert_eq(GameScript.practice_loadout_bosses(1, false), [0, 1] as Array[int])
	assert_eq(GameScript.practice_loadout_bosses(2, false), [0, 1] as Array[int])
	assert_eq(GameScript.practice_loadout_bosses(3, false), [0, 1] as Array[int], "never the unreachable N set")
	assert_eq(GameScript.practice_loadouts(1, false), [_ring([D, A]), _ring([A, D, L])] as Array[PackedInt32Array])
	assert_eq(GameScript.practice_loadouts(2, false), [_ring([D, A]), _ring([A, D, L])] as Array[PackedInt32Array])
	assert_eq(GameScript.practice_loadouts(3, false), [_ring([D, A]), _ring([A, D, L])] as Array[PackedInt32Array])
	assert_eq(GameScript.practice_start_index(1, false), 0)
	assert_eq(GameScript.practice_start_index(2, false), 1)
	assert_eq(GameScript.practice_start_index(3, false), 1, "capped at the last fight")
	assert_eq(GameScript.practice_loadout_bosses(2, true), GameScript.practice_loadout_bosses(2), "flag on: unchanged")


func test_practice_start_reads_the_segfault_flag() -> void:
	var game: Node = _game()
	game.segfault_enabled = false
	game.start_practice_from_title(100, 3)
	assert_eq(game.practice_loadouts_offered, [0, 1] as Array[int])
	assert_eq(game.run.fight_start_ring, _ring([A, D, L]), "starts at the last existing fight's set")
	assert_true(game.cycle_practice_loadout(101))
	assert_eq(game.run.fight_start_ring, _ring([D, A]), "wraps without an N set")
