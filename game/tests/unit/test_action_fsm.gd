extends GutTest
## Story 2.5 AC2-AC6, AC8: the ActionStateMachine ticked directly, in SimClock phase order
## (Register SHIFTS, FSM ACTIONS, Player PLAYER), with a SimContext whose poll_frame is the tick.
## Tick 0 is the first press tick; a press pushed at tick t is live through t + 8.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const J := &"action_1"
const K := &"action_2"
const S := ActionStateMachine.ActionState
const SPAWN := Vector2(256, 144)
const EPS := 0.0001

var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _t: int = 0


func before_each() -> void:
	_buf = InputBuffer.new()
	_ctx = SimContext.new()
	_player = Player.new(load("res://data/player/player_def.tres") as PlayerDef, Arena.player_bounds())
	_player.reset_for_fight(SPAWN)
	_player.set_active(true)
	_reg = Register.new(_buf)
	_reg.set_active(true)
	_fsm = ActionStateMachine.new(_buf, _player, _reg)
	_fsm.reset_for_fight()
	_fsm.set_active(true)
	_t = 0


func after_each() -> void:
	_fsm = null
	_player = null
	_reg = null
	_buf = null
	_ctx = null


func _ring(bits: Array) -> void:
	assert_true(_reg.set_fight_start(PackedInt32Array(bits)))


## One world tick at poll frame _t, in phase order.
func _tick() -> void:
	_ctx.poll_frame = _t
	_reg.tick(_ctx)
	_fsm.tick(_ctx)
	_player.tick(_ctx)
	_t += 1


## Ticks until _t == `until` (exclusive).
func _run_to(until: int) -> void:
	while _t < until:
		_tick()


func _press(key: StringName) -> void:
	_buf.push(key, _t)


func test_phase_and_initial_state() -> void:
	assert_eq(_fsm.phase, SimSystem.SimPhase.ACTIONS)
	assert_eq(_fsm.state, S.IDLE_MOVE)
	assert_null(_fsm.action)
	assert_false(_fsm.invulnerable())


func test_inactive_fsm_does_nothing() -> void:
	_fsm.set_active(false)
	_ring([A, D])
	_press(J)
	_tick()
	assert_null(_fsm.action)


func test_slash_frame_counts() -> void:
	_ring([A, D])
	_press(J)
	var states: Array = []
	for i: int in 22:
		_tick()
		states.append(_fsm.state)
		assert_eq(_fsm.action_frame, i + 1)
	assert_eq(states.count(S.STARTUP), 6)
	assert_eq(states.count(S.ACTIVE), 4)
	assert_eq(states.count(S.RECOVERY), 12)
	assert_eq(states.slice(0, 6), [S.STARTUP, S.STARTUP, S.STARTUP, S.STARTUP, S.STARTUP, S.STARTUP])
	assert_eq(states[6], S.ACTIVE)
	assert_eq(states[10], S.RECOVERY)
	_tick()
	assert_eq(_fsm.state, S.IDLE_MOVE, "slash occupies exactly 22 ticks")
	assert_null(_fsm.action)


func test_dash_frame_counts() -> void:
	_ring([D, A])
	_press(J)
	var states: Array = []
	for i: int in 16:
		_tick()
		states.append(_fsm.state)
	assert_eq(states.count(S.ACTIVE), 10)
	assert_eq(states.count(S.RECOVERY), 6)
	assert_eq(states.count(S.STARTUP), 0)
	assert_eq(states[0], S.ACTIVE, "S=0: frame 1 is ACTIVE on the press tick")
	_tick()
	assert_eq(_fsm.state, S.IDLE_MOVE)


func test_next_press_starts_on_the_tick_after_the_last_frame() -> void:
	_ring([D, A])
	_press(J)
	_run_to(16) # dash frames 1-16 on ticks 0-15
	assert_eq(_fsm.action_frame, 16)
	_press(K)
	_tick() # tick 16
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.state, S.STARTUP)


func test_frame_in_state() -> void:
	_ring([A, D])
	_press(J)
	_run_to(8) # frame 8 = ACTIVE 2
	assert_eq(_fsm.state, S.ACTIVE)
	assert_eq(_fsm.frame_in_state(), 2)
	_run_to(13) # frame 13 = RECOVERY 3
	assert_eq(_fsm.frame_in_state(), 3)


func test_facing_captured_and_slash_locks_player_until_recovery() -> void:
	_ring([A, D])
	_player.facing = Vector2i(0, 1)
	_press(J)
	_ctx.move_dir = Vector2i(1, 0)
	for i: int in 10:
		_tick()
		assert_true(_player.locked, "tick %d locked" % i)
		assert_eq(_player.velocity_px, Vector2.ZERO)
		assert_eq(_player.position_px, SPAWN)
		assert_eq(_player.facing, Vector2i(0, 1), "the @ does not turn")
		assert_eq(_fsm.facing, Vector2i(0, 1))
	_tick() # frame 11, RECOVERY
	assert_false(_player.locked)
	assert_gt(_player.position_px.x, SPAWN.x, "RECOVERY moves normally")
	assert_eq(_player.facing, Vector2i(1, 0))
	assert_eq(_fsm.facing, Vector2i(0, 1), "action facing held")


func test_dash_moves_four_tiles_in_ten_ticks() -> void:
	_ring([D, A])
	_press(J)
	_run_to(10)
	assert_almost_eq(_player.position_px.x, SPAWN.x + 64.0, EPS)
	assert_almost_eq(_player.position_px.y, SPAWN.y, EPS)
	assert_true(_player.locked)
	_tick() # RECOVERY: unlocked, decelerates from walking top speed at most
	assert_false(_player.locked)
	assert_lte(_player.velocity_px.length(), Const.tiles_per_s_to_px_per_frame(7.0) + EPS)
	_run_to(30)
	assert_almost_eq(_player.velocity_px.length(), 0.0, EPS, "stopped")
	assert_lt(_player.position_px.x, SPAWN.x + 64.0 + 8.0, "short slide after the dash")


func test_dash_diagonal_is_four_tiles() -> void:
	_ring([D, A])
	_player.facing = Vector2i(-1, -1)
	_press(J)
	_run_to(10)
	assert_almost_eq(_player.position_px.distance_to(SPAWN), 64.0, EPS)


func test_dash_clamped_at_arena_bounds() -> void:
	_ring([D, A])
	_player.reset_for_fight(Vector2(490, 144))
	_press(J)
	_run_to(10)
	assert_eq(_player.position_px.x, Arena.player_bounds().end.x)


func test_dash_invulnerable_on_frames_1_to_8() -> void:
	_ring([D, A])
	_press(J)
	for i: int in 16:
		_tick()
		assert_eq(_fsm.invulnerable(), i < 8, "dash frame %d" % (i + 1))
	_tick()
	assert_false(_fsm.invulnerable())


func test_slash_never_invulnerable() -> void:
	_ring([A, D])
	_press(J)
	for i: int in 22:
		_tick()
		assert_false(_fsm.invulnerable())


func test_dash_cooldown_blocks_second_press() -> void:
	_ring([D, A])
	_press(J)
	_tick() # tick 0: dash starts
	assert_eq(_fsm.cooldowns.remaining(D), 24)
	_run_to(15)
	_press(J) # live 15-23: cooldown ready at 24, so it expires
	_run_to(24)
	assert_null(_fsm.action)
	_tick()
	assert_null(_fsm.action, "expired press never fires")


func test_dash_press_fires_on_the_first_ready_tick() -> void:
	_ring([D, A])
	_press(J)
	_tick()
	_run_to(12)
	_press(J) # during dash recovery, cooldown running: cancel refused, stays buffered
	_run_to(16)
	_press(J) # live 16-24
	_run_to(24)
	assert_null(_fsm.action, "ticks 16-23: cooldown still running")
	_tick() # tick 24
	assert_eq(_fsm.action, Defs.DASH)
	assert_eq(_fsm.action_frame, 1)


func test_chain_press_at_tick_6_expires() -> void:
	_ring([A, D])
	_press(J)
	_run_to(6)
	_press(J)
	_run_to(22)
	assert_eq(_fsm.action, Defs.SLASH_1, "no chain")
	assert_eq(_fsm.action_frame, 22)
	_tick()
	assert_null(_fsm.action)


func test_chain_press_at_tick_7_chains_on_tick_15() -> void:
	_ring([A, D])
	_press(J)
	_run_to(7)
	_press(J)
	_run_to(15)
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 15)
	_tick() # tick 15
	assert_eq(_fsm.action, Defs.SLASH_2)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.action.base_damage, 10)
	# hit 2 runs frame f on tick 14 + f: its chain window opens on tick 30.
	_run_to(22)
	_press(J) # live 22-30
	_run_to(30)
	assert_eq(_fsm.action, Defs.SLASH_2)
	_tick() # tick 30
	assert_eq(_fsm.action, Defs.SLASH_3)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.action.base_damage, 15)
	# hit 3 runs frame f on tick 29 + f: frames 15-22 are resolved on ticks 45-52.
	_run_to(44)
	_press(J) # live 44-52
	_run_to(52)
	assert_eq(_fsm.action, Defs.SLASH_3, "hit 3 never chains")
	assert_eq(_fsm.action_frame, 22)
	_tick() # tick 52: hit 3 has ended, so the press is a fresh solo slash
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 1)


func test_shift_between_hits_cancels_the_chain() -> void:
	_ring([A, D])
	_press(J)
	_run_to(10)
	_reg.shift(Register.LEFT)
	_reg.shift(Register.LEFT) # back to [A, D], but the serial changed
	_run_to(16)
	_press(J)
	_run_to(22)
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 22)
	_tick() # tick 22: hit 1 has ended; the press starts a fresh slash_1, not hit 2
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.chain_serial, _reg.shift_serial, "a new chain starts at the current serial")


func test_cancel_slash_recovery_into_dash() -> void:
	_ring([A, D])
	_press(J)
	_run_to(12)
	_press(K)
	_tick() # tick 12
	assert_eq(_fsm.action, Defs.DASH)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.cooldowns.remaining(D), 24)
	assert_true(_fsm.invulnerable())
	assert_eq(_fsm.chain_serial, -1, "the dash ends the chain")


func test_cancel_refused_in_startup() -> void:
	_ring([D, A])
	_press(K)
	_tick() # slash on K
	_press(J) # tick 1, live to 9: the slash is in STARTUP/ACTIVE until frame 10
	_run_to(12)
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 12)


func test_reset_for_fight_clears_everything() -> void:
	_ring([A, D])
	_press(J)
	_run_to(3)
	assert_true(_player.locked)
	_fsm.cooldowns.start(D, 10)
	_fsm.reset_for_fight()
	assert_eq(_fsm.state, S.IDLE_MOVE)
	assert_null(_fsm.action)
	assert_eq(_fsm.action_frame, 0)
	assert_true(_fsm.cooldowns.ready(D))
	assert_eq(_fsm.chain_serial, -1)
	assert_false(_player.locked)


func test_set_active_false_unlocks_player() -> void:
	_ring([A, D])
	_press(J)
	_tick()
	assert_true(_player.locked)
	_fsm.set_active(false)
	assert_false(_player.locked)


func test_state_for_is_pure() -> void:
	assert_eq(ActionStateMachine.state_for(null, 3), S.IDLE_MOVE)
	assert_eq(ActionStateMachine.state_for(Defs.SLASH_1, 6), S.STARTUP)
	assert_eq(ActionStateMachine.state_for(Defs.SLASH_1, 7), S.ACTIVE)
	assert_eq(ActionStateMachine.state_for(Defs.SLASH_1, 11), S.RECOVERY)
	assert_eq(ActionStateMachine.state_for(Defs.DASH, 1), S.ACTIVE)


## Review 2.5: leaving FIGHT mid-dash clears the action (no ghost invulnerability).
func test_set_active_false_clears_action_and_invulnerability() -> void:
	_ring([D, A])
	_press(J)
	_tick()
	_tick()
	assert_true(_fsm.invulnerable())
	_fsm.set_active(false)
	assert_false(_fsm.invulnerable())
	assert_null(_fsm.action)
	assert_eq(_fsm.state, S.IDLE_MOVE)

