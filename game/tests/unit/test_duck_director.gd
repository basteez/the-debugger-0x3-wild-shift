extends GutTest
## Story 3.6 AC 7-11 (B3, F1-F4, H4): due_beat for every case and ordering, and the director's
## poll on a real Arena with the Infinite Loop: T1 at once, T2 at iteration 1, T3 on the Dash
## Strike window, T4 at phase 1, each once; TITLE resets, a retry does not.

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


func test_t2_waits_for_the_first_opening() -> void:
	assert_eq(DuckDirector.due_beat(1, true, IL, 0, false, 0), -1)
	assert_eq(DuckDirector.due_beat(1, true, IL, 1, false, 0), 1)
	assert_eq(DuckDirector.due_beat(1, true, IL, 5, false, 0), 1)
	assert_eq(DuckDirector.due_beat(1, true, &"test_boss", 1, false, 0), -1)


func test_t3_waits_for_the_dash_strike_window() -> void:
	assert_eq(DuckDirector.due_beat(2, true, IL, 1, false, 0), -1)
	assert_eq(DuckDirector.due_beat(2, true, IL, 1, true, 0), 2)
	assert_true(DuckDirector.window_is_dash_strike(Vector2i(A, D)))
	assert_false(DuckDirector.window_is_dash_strike(Vector2i(D, A)), "[D,A] is not a combo")
	assert_false(DuckDirector.window_is_dash_strike(Vector2i(A, Register.Bit.LOOP)))


func test_t4_waits_for_phase_two() -> void:
	assert_eq(DuckDirector.due_beat(3, true, IL, 1, true, 0), -1)
	assert_eq(DuckDirector.due_beat(3, true, IL, 1, true, 1), 3)
	assert_eq(DuckDirector.due_beat(3, true, IL, 1, true, 2), 3)


func test_all_requested_or_bad_index_is_never_due() -> void:
	assert_eq(DuckDirector.due_beat(4, true, IL, 9, true, 2), -1)
	assert_eq(DuckDirector.due_beat(9, true, IL, 9, true, 2), -1)
	assert_eq(DuckDirector.due_beat(-1, true, IL, 9, true, 2), -1)


func test_beats_fire_strictly_in_order() -> void:
	# Every later trigger holds, but only the beat at `requested` can be due.
	assert_eq(DuckDirector.due_beat(0, true, IL, 1, true, 1), 0)
	assert_eq(DuckDirector.due_beat(1, true, IL, 0, true, 1), -1, "T3/T4 do not jump ahead of T2")
	assert_eq(DuckDirector.due_beat(1, true, IL, 1, true, 1), 1)
	assert_eq(DuckDirector.due_beat(2, true, IL, 1, false, 1), -1, "T4 does not jump ahead of T3")


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
	assert_eq(_director.requested, 4)
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
	assert_eq(_director.requested, 1, "a retry keeps the record")
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
