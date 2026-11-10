extends GutTest
## Story 4.4 AC 12-14 (D-S44-1): the Infinite Loop's 5 s start nudge in a real Arena on the SimClock
## autoload. With no input the ring starts after exactly START_NUDGE_TICKS world ticks; pause and the
## Breakpoint freeze do not advance the count (SimClock does not tick the boss); a retry
## (reset_for_fight) restarts it; two runs from the same seed start on the same tick with the same
## state.

const GameScript := preload("res://src/autoloads/game.gd")
const SEED := 44044

var _saved_source: InputSource
var _saved_state: int
var _arena: Arena


func before_each() -> void:
	_saved_source = SimClock.input_source
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal hit never records a death
	SimClock.paused = false
	SimClock.input_source = null # no presses: nobody shifts


func after_each() -> void:
	SimClock.paused = false
	SimClock.breakpoint_gate_active = false
	if is_instance_valid(_arena):
		remove_child(_arena)
		_arena.free()
	SimClock.input_source = _saved_source
	SimClock.begin_fight(0)
	Game.flow_state = _saved_state as GameScript.FlowState


func _enter() -> InfiniteLoopBody:
	_arena = Arena.new()
	add_child(_arena)
	SimClock.begin_fight(SEED)
	_arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.INFINITE_LOOP_DEF_PATH)
	return _arena.boss as InfiniteLoopBody


func _ticks(n: int) -> void:
	for i: int in n:
		SimClock.tick()


## World ticks until the ring starts (or `limit`).
func _ticks_to_start(body: InfiniteLoopBody, limit: int = 1000) -> int:
	for i: int in limit:
		SimClock.tick()
		if body.started:
			return i + 1
	return -1


func test_no_input_starts_the_ring_on_world_tick_300() -> void:
	var body: InfiniteLoopBody = _enter()
	assert_not_null(body)
	assert_eq(_ticks_to_start(body), InfiniteLoopBody.START_NUDGE_TICKS)
	assert_eq(body.iteration, 1)
	assert_true(body.is_open(), "the `;` opens on the start tick")
	assert_eq(_arena.register.active_window(), Vector2i(Register.Bit.DASH, Register.Bit.ATTACK), "the register stays [D, A]")


func test_pause_and_the_breakpoint_freeze_do_not_count() -> void:
	var body: InfiniteLoopBody = _enter()
	_ticks(100)
	assert_eq(body.waiting_ticks, 100)
	SimClock.paused = true
	_ticks(500)
	assert_eq(body.waiting_ticks, 100, "pause: no world tick")
	SimClock.paused = false
	SimClock.breakpoint_gate_active = true
	_ticks(500)
	assert_eq(body.waiting_ticks, 100, "Breakpoint freeze: the boss is not ticked")
	assert_false(body.started)
	SimClock.breakpoint_gate_active = false
	assert_eq(_ticks_to_start(body), InfiniteLoopBody.START_NUDGE_TICKS - 100)


func test_a_retry_restarts_the_count() -> void:
	var body: InfiniteLoopBody = _enter()
	_ticks(250)
	_arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.INFINITE_LOOP_DEF_PATH) # the retry path
	assert_eq(_arena.boss, body, "a retry reuses the controller")
	assert_eq(body.waiting_ticks, 0)
	assert_eq(_ticks_to_start(body), InfiniteLoopBody.START_NUDGE_TICKS)


func test_the_nudge_is_deterministic() -> void:
	var runs: Array[Array] = []
	for r: int in 2:
		var body: InfiniteLoopBody = _enter()
		var at: int = _ticks_to_start(body)
		_ticks(200)
		runs.append([at, body.travel_mtiles, body.travel_rem, body.speed_mtps, body.iteration, body.open_left, int(body.state), SimClock.ctx.rng.state])
		remove_child(_arena)
		_arena.free()
	assert_eq(runs[0], runs[1])
