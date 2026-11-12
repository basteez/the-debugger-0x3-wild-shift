extends GutTest
## Story 3.6 AC 7-11 (B3, F1-F4, H4): due_beat for every case and ordering, and the director's
## poll on a real Arena with the Infinite Loop: T1 at once, T2 at iteration 1, T3 on the Dash
## Strike window, T4 at phase 1, each once; TITLE resets, a retry does not.
## Story 4.4 (D-S44-3, D-S44-10): `requested` is a bitmask; each beat fires on its own trigger, an
## unfired earlier beat never blocks a later one and is skipped for good once a later beat fired.
## The strict-order cases of 3.6 were rewritten to that rule.

const GameScript := preload("res://src/autoloads/game.gd")
const IL := &"infinite_loop"
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH

var _saved_state: int
var _arena: Arena
var _director: DuckDirector


func before_each() -> void:
	_saved_state = Game.flow_state
	watch_signals(EventBus)


func after_each() -> void:
	SimClock.paused = false
	Game.flow_state = _saved_state as GameScript.FlowState
	if is_instance_valid(_director):
		_director.free()
	if is_instance_valid(_arena):
		_arena.free()


# --- due_beat (pure) ---

func test_t1_needs_a_fight_of_the_infinite_loop() -> void:
	assert_eq(DuckDirector.due_beat(0, true, IL, 0, false, 0), 0)
	assert_eq(DuckDirector.due_beat(0, false, IL, 0, false, 0), -1, "not in FIGHT")
	assert_eq(DuckDirector.due_beat(0, true, &"", 0, false, 0), -1, "no boss (practice, bosses 1-2 today)")
	assert_eq(DuckDirector.due_beat(0, true, &"test_boss", 0, false, 0), -1, "framework test boss")
	assert_eq(DuckDirector.due_beat(0, true, &"null_pointer", 0, false, 0), -1, "another boss")


## Bitmask of beats 0..n-1 requested.
static func _first(n: int) -> int:
	return (1 << n) - 1


func test_t2_waits_for_the_first_opening() -> void:
	assert_eq(DuckDirector.due_beat(_first(1), true, IL, 0, false, 0), -1)
	assert_eq(DuckDirector.due_beat(_first(1), true, IL, 1, false, 0), 1)
	assert_eq(DuckDirector.due_beat(_first(1), true, IL, 5, false, 0), 1)
	assert_eq(DuckDirector.due_beat(_first(1), true, &"test_boss", 1, false, 0), -1)


func test_t3_waits_for_the_dash_strike_window() -> void:
	assert_eq(DuckDirector.due_beat(_first(2), true, IL, 1, false, 0), -1)
	assert_eq(DuckDirector.due_beat(_first(2), true, IL, 1, true, 0), 2)
	assert_true(DuckDirector.window_is_dash_strike(Vector2i(A, D)))
	assert_false(DuckDirector.window_is_dash_strike(Vector2i(D, A)), "[D,A] is not a combo")
	assert_false(DuckDirector.window_is_dash_strike(Vector2i(A, Register.Bit.LOOP)))


func test_t4_waits_for_phase_two() -> void:
	assert_eq(DuckDirector.due_beat(_first(3), true, IL, 1, true, 0), -1)
	assert_eq(DuckDirector.due_beat(_first(3), true, IL, 1, true, 1), 3)
	assert_eq(DuckDirector.due_beat(_first(3), true, IL, 1, true, 2), 3)


func test_all_requested_or_bad_mask_is_never_due() -> void:
	assert_eq(DuckDirector.due_beat(_first(4), true, IL, 9, true, 2), -1)
	assert_eq(DuckDirector.due_beat(-1, true, IL, 9, true, 2), -1)


func test_lowest_due_beat_first() -> void:
	# D-S44-3: every trigger holds; one beat per poll, lowest index first.
	assert_eq(DuckDirector.due_beat(0, true, IL, 1, true, 1), 0)
	assert_eq(DuckDirector.due_beat(_first(1), true, IL, 1, true, 1), 1)
	assert_eq(DuckDirector.due_beat(_first(2), true, IL, 1, true, 1), 2)


func test_an_unfired_beat_does_not_block_a_later_one() -> void:
	# AC 8: T2 not yet due (no opening), T3 and T4 hold: T3 comes first, T2 does not block it.
	assert_eq(DuckDirector.due_beat(_first(1), true, IL, 0, true, 1), 2, "T3 does not wait for T2")
	assert_eq(DuckDirector.due_beat(_first(2), true, IL, 1, false, 1), 3, "T4 does not wait for T3")


func test_a_skipped_beat_never_fires_after_a_later_one() -> void:
	# D-S44-10: T4 fired while T3 was never due; T3 is skipped for good, even on the Dash Strike window.
	var mask: int = _first(2) | (1 << 3)
	assert_eq(DuckDirector.due_beat(mask, true, IL, 1, true, 1), -1)
	assert_eq(DuckDirector.due_beat(1 | (1 << 2), true, IL, 1, true, 0), -1, "T2 skipped once T3 fired")


func test_duck_ids_match_the_data() -> void:
	assert_eq(DuckDirector.DUCK_IDS, [&"t1_shift", &"t2_semicolon", &"t3_dash_strike", &"t4_phase_two"] as Array[StringName])
	for id: StringName in DuckDirector.DUCK_IDS:
		assert_not_null(VoiceService.LINES.find(id), String(id))


# --- poll on a real arena ---

func _fight(ring: PackedInt32Array, boss_path: String = Arena.INFINITE_LOOP_DEF_PATH) -> void:
	_arena = Arena.new()
	_arena.enter_fight(ring, false, boss_path)
	_director = DuckDirector.new()
	_director.arena = _arena
	add_child(_director)
	Game.flow_state = GameScript.FlowState.FIGHT


func _loop() -> InfiniteLoopBody:
	return _arena.boss as InfiniteLoopBody


func test_poll_requests_the_beats_in_order_once() -> void:
	_fight(Register.fight_start_for_boss(0))
	assert_not_null(_loop())
	assert_eq(_director.poll(), 0, "T1 on the first frame")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"t1_shift", VoiceService.LINES.find(&"t1_shift").text])
	assert_eq(_director.poll(), -1, "T1 once")
	_loop().iteration = 1
	assert_eq(_director.poll(), 1, "T2 on the first opening")
	assert_eq(_director.poll(), -1, "[D,A] window: no T3")
	_arena.register.set_fight_start(PackedInt32Array([A, D]))
	assert_eq(_director.poll(), 2, "T3 on the Dash Strike window")
	_loop().phase_index = 1
	assert_eq(_director.poll(), 3, "T4 at phase 2")
	assert_eq(_director.poll(), -1)
	assert_eq(_director.requested, _first(4))
	assert_signal_emit_count(EventBus, "duck_line_requested", 4)


func test_poll_outside_fight_or_without_the_loop_requests_nothing() -> void:
	_fight(Register.fight_start_for_boss(0), Arena.TEST_BOSS_DEF_PATH)
	assert_eq(_director.poll(), -1, "test boss")
	Game.flow_state = GameScript.FlowState.TITLE
	assert_eq(_director.poll(), -1)
	assert_signal_emit_count(EventBus, "duck_line_requested", 0)


func test_poll_without_an_arena_is_safe() -> void:
	_director = DuckDirector.new()
	add_child(_director)
	assert_eq(_director.poll(), -1)


func test_title_resets_and_retry_keeps_the_record() -> void:
	_fight(Register.fight_start_for_boss(0))
	assert_eq(_director.poll(), 0)
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.DEAD)
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.FIGHT)
	assert_eq(_director.requested, _first(1), "a retry keeps the record")
	assert_eq(_director.poll(), -1, "a retry does not replay T1")
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.TITLE)
	assert_eq(_director.requested, 0, "a new run may fire every beat again")
	assert_eq(_director.poll(), 0)


func test_director_disconnects_on_exit() -> void:
	_director = DuckDirector.new()
	add_child(_director)
	assert_true(EventBus.flow_state_changed.is_connected(_director._on_flow_state_changed))
	remove_child(_director)
	assert_false(EventBus.flow_state_changed.is_connected(_director._on_flow_state_changed))


# --- Story 4.4: beats without blocking (AC 8), pause (AC 10) ---

func test_t4_at_phase_two_without_dash_strike_skips_t3_for_good() -> void:
	_fight(Register.fight_start_for_boss(0))
	assert_eq(_director.poll(), 0)
	_loop().iteration = 1
	assert_eq(_director.poll(), 1)
	_loop().phase_index = 1 # [D,A] window throughout: Dash Strike never active
	assert_eq(_director.poll(), 3, "T4 is not blocked by T3")
	_arena.register.set_fight_start(PackedInt32Array([A, D]))
	assert_eq(_director.poll(), -1, "T3 is skipped for good once T4 fired")
	assert_signal_emit_count(EventBus, "duck_line_requested", 3)


func test_poll_requests_nothing_while_paused() -> void:
	_fight(Register.fight_start_for_boss(0))
	SimClock.paused = true
	assert_eq(_director.poll(), -1)
	_director.pending_hints.append(Vector2i(A, D))
	assert_eq(_director.poll(), -1, "a pending hint waits too")
	SimClock.paused = false
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED)
	assert_eq(_director.poll(), 0, "T1 after the pause")


# --- Story 4.4: the Breakpoint hint (AC 3, 4) ---

func test_breakpoint_hints_once_per_phase() -> void:
	_fight(Register.fight_start_for_boss(0))
	_director.requested = (1 << 4) - 1 # beats out of the way
	EventBus.breakpoint_started.emit()
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"hint_a_d", "Quack. Weak window: A→D."])
	EventBus.breakpoint_started.emit()
	assert_eq(_director.poll(), -1, "a second Breakpoint in the same phase says nothing (D-S44-5)")
	_loop().phase_index = 1
	EventBus.breakpoint_started.emit()
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED, "a new phase hints again")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"hint_d_a", "Quack. Weak window: D→A."])
	assert_signal_emit_count(EventBus, "duck_line_requested", 2)


func test_breakpoint_record_is_per_fight_attempt() -> void:
	_fight(Register.fight_start_for_boss(0))
	_director.requested = (1 << 4) - 1
	EventBus.breakpoint_started.emit()
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED)
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.DEAD)
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.FIGHT)
	EventBus.breakpoint_started.emit()
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED, "the retry may hint the phase again")


func test_breakpoint_while_defeated_says_nothing_and_marks_nothing() -> void:
	_fight(Register.fight_start_for_boss(0))
	_director.requested = (1 << 4) - 1
	_loop().state = BossController.BossState.DEFEATED
	EventBus.breakpoint_started.emit()
	assert_eq(_director.poll(), -1)
	assert_true(_director.hinted.is_empty(), "the phase is not marked")
	assert_signal_emit_count(EventBus, "duck_line_requested", 0)


func test_breakpoint_outside_fight_says_nothing() -> void:
	_fight(Register.fight_start_for_boss(0))
	Game.flow_state = GameScript.FlowState.HARVEST
	EventBus.breakpoint_started.emit()
	assert_true(_director.pending_hints.is_empty())


# --- Story 4.4: the third-death hint (AC 5-7) ---

func test_is_death_hint_due() -> void:
	for n: int in [0, 1, 2, 4, 5, 7]:
		assert_false(DuckDirector.is_death_hint_due(n), str(n))
	for n: int in [3, 6, 9]:
		assert_true(DuckDirector.is_death_hint_due(n), str(n))


func _die(deaths: int) -> void:
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.DEAD)
	EventBus.player_died.emit(IL, deaths)


func _retry() -> void:
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.FIGHT)


func test_third_death_window_is_captured_at_death_and_said_at_retry() -> void:
	_fight(Register.fight_start_for_boss(0))
	_director.requested = (1 << 4) - 1
	for n: int in [1, 2]:
		_die(n)
		_retry()
		assert_eq(_director.poll(), -1, "death %d: no hint" % n)
	_loop().phase_index = 1 # dies in phase 2 (D→A)
	_die(3)
	assert_true(_director.has_death_hint)
	assert_eq(_director.death_hint, Vector2i(D, A))
	assert_signal_emit_count(EventBus, "duck_line_requested", 0, "not at the death itself")
	_loop().phase_index = 0 # the retry resets the boss to phase 1
	_retry()
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"hint_d_a", "Quack. Weak window: D→A."])
	assert_eq(_director.poll(), -1, "once")


func test_captured_death_hint_is_dropped_on_title() -> void:
	_fight(Register.fight_start_for_boss(0))
	_die(3)
	assert_true(_director.has_death_hint)
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.TITLE)
	assert_false(_director.has_death_hint)
	EventBus.flow_state_changed.emit(GameScript.FlowState.TITLE, GameScript.FlowState.INTRO)
	EventBus.flow_state_changed.emit(GameScript.FlowState.INTRO, GameScript.FlowState.FIGHT)
	_director.requested = (1 << 4) - 1
	assert_eq(_director.poll(), -1, "nothing said later")


func test_death_hint_is_not_said_in_another_boss_fight() -> void:
	_fight(Register.fight_start_for_boss(0))
	_director.requested = (1 << 4) - 1
	_die(3)
	assert_eq(_director.death_hint_boss, IL, "captured with the boss id")
	_director.death_hint_boss = &"other_boss" # a debug jump to another boss during DEAD
	_retry()
	assert_eq(_director.pending_hints.size(), 0, "the other boss's fight does not get this hint")
	assert_false(_director.has_death_hint)


func test_third_death_through_the_real_game_flow() -> void:
	_fight(Register.fight_start_for_boss(0))
	_director.requested = (1 << 4) - 1
	var game: Node = autofree(GameScript.new())
	game.start_run_from_title(0)
	game.advance() # INTRO -> FIGHT
	for n: int in 3:
		assert_true(game.record_death(100 + n * 1000))
		if n < 2:
			assert_true(game.retry(200 + n * 1000))
	assert_eq(game.run.deaths_on_boss, 3)
	assert_true(_director.has_death_hint)
	assert_true(game.retry(3000))
	Game.flow_state = GameScript.FlowState.FIGHT
	assert_eq(_director.poll(), DuckDirector.HINT_REQUESTED)
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"hint_a_d", "Quack. Weak window: A→D."])


# --- Story 4.4: queue room (AC 9, D-S44-4) ---

func test_six_due_lines_are_all_shown_in_order() -> void:
	_fight(Register.fight_start_for_boss(0))
	var bubble := DuckBubble.new()
	add_child_autofree(bubble)
	_director.bubble = bubble
	_director.pending_hints.append(Vector2i(A, D))
	_director.pending_hints.append(Vector2i(D, A))
	_loop().iteration = 1
	_arena.register.set_fight_start(PackedInt32Array([A, D]))
	_loop().phase_index = 1
	for i: int in 6:
		_director.poll()
	assert_eq(bubble.pending().size(), DuckBubble.MAX_PENDING, "the bubble is full")
	assert_false(bubble.has_room())
	assert_signal_emit_count(EventBus, "duck_line_requested", 5, "the sixth waits, not dropped")
	var shown: Array[StringName] = [bubble.current_id()]
	for i: int in 400:
		bubble.step(0.25)
		_director.poll()
		if bubble.is_showing() and bubble.current_id() != shown[shown.size() - 1]:
			shown.append(bubble.current_id())
	assert_eq(shown, [&"hint_a_d", &"hint_d_a", &"t1_shift", &"t2_semicolon", &"t3_dash_strike", &"t4_phase_two"] as Array[StringName])
	assert_signal_emit_count(EventBus, "duck_line_requested", 6)


func test_director_disconnects_the_hint_signals_on_exit() -> void:
	_director = DuckDirector.new()
	add_child(_director)
	assert_true(EventBus.breakpoint_started.is_connected(_director._on_breakpoint_started))
	assert_true(EventBus.player_died.is_connected(_director._on_player_died))
	remove_child(_director)
	assert_false(EventBus.breakpoint_started.is_connected(_director._on_breakpoint_started))
	assert_false(EventBus.player_died.is_connected(_director._on_player_died))


# --- Story 5.6: the Null Pointer beats (AC 1, 2, 3, 9; D-S56-1, D-S56-2) ---

const NP := &"null_pointer"
const N1_MASK := 1 << DuckDirector.N1_BIT
const N2_MASK := 1 << DuckDirector.N2_BIT


func test_null_pointer_ids_stay_out_of_duck_ids_and_exist_in_the_data() -> void:
	assert_false(DuckDirector.DUCK_IDS.has(DuckDirector.N1))
	assert_false(DuckDirector.DUCK_IDS.has(DuckDirector.N2))
	assert_eq(DuckDirector.N1, &"n1_breakpoint")
	assert_eq(DuckDirector.N2, &"n2_hold_r")
	assert_eq(DuckDirector.N1_BIT, DuckDirector.DUCK_IDS.size(), "bits follow the Infinite Loop beats")
	assert_not_null(VoiceService.LINES.find(DuckDirector.N1))
	assert_not_null(VoiceService.LINES.find(DuckDirector.N2))


func test_due_null_pointer_beat_n1_then_n2() -> void:
	assert_eq(DuckDirector.due_null_pointer_beat(0, true, NP, true), DuckDirector.N1_BIT)
	assert_eq(DuckDirector.due_null_pointer_beat(N1_MASK, true, NP, true), DuckDirector.N2_BIT, "N2 after N1")
	assert_eq(DuckDirector.due_null_pointer_beat(N1_MASK | N2_MASK, true, NP, true), -1, "each once per run")
	assert_eq(DuckDirector.due_null_pointer_beat(N2_MASK, true, NP, true), DuckDirector.N1_BIT, "N1 is never skipped")
	assert_eq(DuckDirector.due_null_pointer_beat(_first(4), true, NP, true), DuckDirector.N1_BIT, "the Infinite Loop beats do not block")


func test_due_null_pointer_beat_needs_a_live_null_pointer_fight() -> void:
	assert_eq(DuckDirector.due_null_pointer_beat(0, false, NP, true), -1, "not in FIGHT or DEFEATED")
	for id: StringName in [IL, &"test_boss", &"segfault", &""]:
		assert_eq(DuckDirector.due_null_pointer_beat(0, true, id, true), -1, String(id))
	assert_eq(DuckDirector.due_null_pointer_beat(-1, true, NP, true), -1, "bad mask")


func test_watch_off_never_requests_n2_but_keeps_n1() -> void:
	# AC 3 (cut ladder #2): the Breakpoint line does not depend on Watch.
	assert_eq(DuckDirector.due_null_pointer_beat(0, true, NP, false), DuckDirector.N1_BIT)
	assert_eq(DuckDirector.due_null_pointer_beat(N1_MASK, true, NP, false), -1)


func test_null_pointer_bits_do_not_skip_the_infinite_loop_beats() -> void:
	# D-S56-10: a debug jump to Fight 2 before Fight 1 must not mark T1-T4 as skipped.
	assert_eq(DuckDirector.due_beat(N1_MASK | N2_MASK, true, IL, 0, false, 0), 0)
	assert_eq(DuckDirector.due_beat(_first(1) | N1_MASK, true, IL, 1, false, 0), 1)


func test_poll_says_both_null_pointer_lines_once() -> void:
	_fight(Register.fight_start_for_boss(1), Arena.NULL_POINTER_DEF_PATH)
	assert_eq(_director.poll(), DuckDirector.N1_BIT, "the Breakpoint line when control begins")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"n1_breakpoint", "Space: Breakpoint. Time stops, you shift. Finally, a debugger that works."])
	assert_eq(_director.poll(), DuckDirector.N2_BIT, "then the Watch line (no bubble: always room)")
	assert_signal_emitted_with_parameters(EventBus, "duck_line_requested", [&"n2_hold_r", "Hold R. Pointers point *somewhere*."])
	assert_eq(_director.poll(), -1)
	assert_signal_emit_count(EventBus, "duck_line_requested", 2)


func test_poll_with_watch_off_says_only_the_breakpoint_line() -> void:
	_fight(Register.fight_start_for_boss(1), Arena.NULL_POINTER_DEF_PATH)
	_director.watch_enabled = false
	assert_eq(_director.poll(), DuckDirector.N1_BIT)
	assert_eq(_director.poll(), -1, "AC 3: line 2 is never requested")
	assert_eq(_director.requested & N2_MASK, 0)
	assert_signal_emit_count(EventBus, "duck_line_requested", 1)


func test_poll_on_a_defeated_null_pointer_says_nothing() -> void:
	_fight(Register.fight_start_for_boss(1), Arena.NULL_POINTER_DEF_PATH)
	_arena.boss.state = BossController.BossState.DEFEATED
	assert_eq(_director.poll(), -1)
	assert_eq(_director.requested, 0)


func test_null_pointer_beats_wait_for_bubble_room() -> void:
	_fight(Register.fight_start_for_boss(1), Arena.NULL_POINTER_DEF_PATH)
	var bubble := DuckBubble.new()
	add_child_autofree(bubble)
	_director.bubble = bubble
	assert_eq(_director.poll(), DuckDirector.N1_BIT)
	assert_true(bubble.is_showing(), "line 1 on screen")
	for i: int in DuckBubble.MAX_PENDING:
		if bubble.has_room():
			VoiceService.say("hint_a_d") # fill the queue behind line 1
	assert_false(bubble.has_room())
	assert_eq(_director.poll(), -1, "D-S56-2: N2 waits while the bubble has no room")
	assert_eq(_director.requested & N2_MASK, 0, "still due")
	for i: int in 400:
		if bubble.has_room():
			break
		bubble.step(0.25)
	assert_true(bubble.has_room())
	assert_eq(_director.poll(), DuckDirector.N2_BIT, "then line 2")


func test_null_pointer_beats_kept_on_retry_reset_on_title() -> void:
	_fight(Register.fight_start_for_boss(1), Arena.NULL_POINTER_DEF_PATH)
	assert_eq(_director.poll(), DuckDirector.N1_BIT)
	assert_eq(_director.poll(), DuckDirector.N2_BIT)
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.DEAD)
	EventBus.flow_state_changed.emit(GameScript.FlowState.DEAD, GameScript.FlowState.FIGHT)
	assert_eq(_director.poll(), -1, "AC 9: a retry does not repeat the beats")
	EventBus.flow_state_changed.emit(GameScript.FlowState.FIGHT, GameScript.FlowState.TITLE)
	assert_eq(_director.requested, 0)
	Game.flow_state = GameScript.FlowState.FIGHT
	assert_eq(_director.poll(), DuckDirector.N1_BIT, "a new run says them again")
