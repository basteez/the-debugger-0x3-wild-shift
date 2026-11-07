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


## Link closed (a K action never opens it): J's DASH cancels a K slash's RECOVERY (2.5 rule).
func test_cancel_slash_recovery_into_dash() -> void:
	_ring([D, A])
	_press(K)
	_run_to(12)
	assert_false(_fsm.link.is_open(), "a K action never opens the link")
	_press(J)
	_tick() # tick 12
	assert_eq(_fsm.action, Defs.DASH)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.cooldowns.remaining(D), 24)
	assert_true(_fsm.invulnerable())
	assert_eq(_fsm.chain_serial, -1, "the dash ends the chain")
	assert_null(_fsm.combo)


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



# --- Story 2.6: combo link, Dash Strike, link_second (AC2-AC7) ---
# Slash J at tick 0: frame f executes on tick f - 1; frame 7 (first ACTIVE) on tick 6, frame 10
# (last ACTIVE, k = 0) on tick 9, so the link is open for presses resolved on ticks 7-27.


func test_link_opens_on_slash_frame_7_and_closes_at_k_19() -> void:
	_ring([A, D])
	_press(J)
	_run_to(6)
	assert_false(_fsm.link.is_open(), "STARTUP: no link yet")
	_tick() # tick 6, frame 7
	assert_true(_fsm.link.is_open())
	assert_eq(_fsm.link.pair, Vector2i(A, D))
	assert_false(_fsm.link.counting, "the count waits for the last ACTIVE frame")
	_run_to(10) # tick 9, frame 10
	assert_true(_fsm.link.counting)
	assert_eq(_fsm.link.frames_left, 18, "k = 0")
	_run_to(28) # tick 27 resolved with k = 18
	assert_true(_fsm.link.is_open())
	assert_eq(_fsm.link.frames_left, 0)
	_tick() # tick 28: k = 19
	assert_false(_fsm.link.is_open())


func test_slash_link_accepts_k_at_18_and_refuses_at_19() -> void:
	_ring([A, D])
	_press(J)
	_run_to(27)
	_press(K)
	_tick() # tick 27, k = 18
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	assert_eq(_fsm.combo, Defs.COMBOS.get_combo(A, D))
	before_each()
	_ring([A, D])
	_press(J)
	_run_to(28)
	_press(K)
	_tick() # tick 28, k = 19
	assert_eq(_fsm.action, Defs.DASH, "link closed: K's solo action")
	assert_null(_fsm.combo)


func test_dash_link_accepts_k_at_18_and_refuses_at_19() -> void:
	# Dash: frames 1-10 ACTIVE on ticks 0-9, so k = 18 is tick 27 as for the slash.
	_ring([D, A])
	_press(J)
	_tick()
	assert_true(_fsm.link.is_open(), "S = 0: the link opens on the press tick")
	_run_to(27)
	_press(K)
	_tick()
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_true(_fsm.link_second)
	before_each()
	_ring([D, A])
	_press(J)
	_run_to(28)
	_press(K)
	_tick()
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_false(_fsm.link_second, "link closed: plain solo slash")


func test_k_during_slash_startup_becomes_dash_strike_at_first_cancel_tick() -> void:
	_ring([A, D])
	_press(J)
	_run_to(3)
	_press(K) # STARTUP: stays in the buffer (live to tick 11)
	_run_to(7)
	assert_false(_fsm.link.held)
	_tick() # tick 7: the link is open, the press is held
	assert_true(_fsm.link.held)
	assert_eq(_fsm.link.held_frame, 3, "keeps its push frame")
	_run_to(11)
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 11, "the first RECOVERY frame executes")
	_tick() # tick 11: RECOVERY cancel into the combo
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.cooldowns.remaining(D), 24, "the replaced DASH cooldown applies (D-S26-3)")
	assert_false(_fsm.link.is_open(), "the follow-up closes the link (D-S26-13)")
	assert_false(_fsm.link.held)
	assert_true(_fsm.invulnerable())


func test_dash_strike_moves_five_tiles_and_is_invulnerable_on_1_to_10() -> void:
	_ring([A, D])
	_press(J)
	_run_to(12)
	var start: Vector2 = _player.position_px
	_press(K)
	_tick() # tick 12: Dash Strike frame 1 (moves on its first ACTIVE frame)
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	for i: int in 11:
		assert_eq(_fsm.invulnerable(), _fsm.action_frame <= 10, "frame %d" % _fsm.action_frame)
		_tick()
	assert_eq(_fsm.action_frame, 12, "last ACTIVE frame")
	assert_almost_eq(_player.position_px.distance_to(start), Const.TILE_PX * 5.0, 0.01, "5 tiles in 12 frames")
	for i: int in 8:
		_tick()
		assert_false(_fsm.invulnerable())
	assert_eq(_fsm.action_frame, 20, "20 frames in all")
	_tick()
	assert_null(_fsm.action)


func test_no_combo_window_holds_k_until_the_dash_ends() -> void:
	_ring([D, A])
	_press(J)
	_tick() # tick 0: dash, link open
	_run_to(3)
	_press(K)
	_tick() # tick 3: held (dash cannot cancel into ATTACK)
	assert_true(_fsm.link.held)
	_run_to(16)
	assert_eq(_fsm.action, Defs.DASH)
	assert_eq(_fsm.action_frame, 16)
	_tick() # tick 16: the dash has ended
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.action_frame, 1)
	assert_true(_fsm.link_second)
	assert_null(_fsm.combo)
	assert_eq(_fsm.action_slot, 1)


func test_same_frame_j_and_k_on_a_no_combo_window() -> void:
	_ring([D, A])
	_press(J)
	_press(K)
	_tick() # tick 0: J first
	assert_eq(_fsm.action, Defs.DASH)
	assert_false(_fsm.link.held, "K is evaluated on the next tick")
	_tick() # tick 1: against the newly opened link
	assert_true(_fsm.link.held)
	_run_to(17)
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_true(_fsm.link_second)


func test_same_frame_j_and_k_on_dash_strike_window() -> void:
	_ring([A, D])
	_press(J)
	_press(K)
	_tick()
	assert_eq(_fsm.action, Defs.SLASH_1)
	_run_to(12)
	assert_eq(_fsm.action, Defs.DASH_STRIKE, "held from tick 7, started on tick 11")
	assert_eq(_fsm.action_frame, 1)


func test_shift_between_j_and_k_discards_the_held_press() -> void:
	_ring([A, D])
	_press(J)
	_run_to(7)
	_press(K)
	_tick() # tick 7: held
	assert_true(_fsm.link.held)
	_press(&"shift_left")
	_tick() # tick 8: [D, A], link closed, held press discarded
	assert_eq(_reg.active_window(), Vector2i(D, A))
	assert_false(_fsm.link.is_open())
	assert_false(_fsm.link.held)
	_run_to(22)
	assert_eq(_fsm.action, Defs.SLASH_1, "nothing executed from the discarded press")
	assert_eq(_fsm.action_frame, 22)


func test_shift_back_to_the_same_window_still_gives_the_solo_action() -> void:
	_ring([A, D])
	_press(J)
	_run_to(8)
	_reg.shift(Register.LEFT)
	_reg.shift(Register.LEFT) # [A, D] again, but the serial changed
	_run_to(12)
	assert_false(_fsm.link.is_open())
	_press(K)
	_tick() # tick 12: plain RECOVERY cancel into DASH (NP-1 #1)
	assert_eq(_fsm.action, Defs.DASH)
	assert_null(_fsm.combo)


func test_cooldown_block_drops_the_press_after_8_frames() -> void:
	_ring([A, D])
	_press(J)
	_tick()
	_fsm.cooldowns.start(D, 16) # ready on tick 16
	_run_to(7)
	_press(K) # live 7-15, DASH cooling down throughout
	_run_to(16)
	assert_false(_fsm.link.held, "a blocked press is never held")
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.cooldowns.remaining(D), 1, "ready on tick 16, after the press expired")
	_run_to(23)
	assert_null(_fsm.action, "the press expired: no partial execution, no late combo")


func test_chain_hit_reopens_the_link() -> void:
	_ring([A, D])
	_press(J)
	_run_to(7)
	_press(J)
	_run_to(16) # hit 2 starts on tick 15
	assert_eq(_fsm.action, Defs.SLASH_2)
	assert_true(_fsm.link.counting, "hit 1's count still runs")
	_run_to(22) # tick 21: hit 2 frame 7
	assert_true(_fsm.link.is_open())
	assert_false(_fsm.link.counting, "reopened on hit 2's first ACTIVE frame")
	assert_eq(_fsm.link.frames_left, 18)


func test_reset_for_fight_and_set_active_false_clear_the_link() -> void:
	_ring([A, D])
	_press(J)
	_run_to(7)
	_press(K)
	_tick()
	assert_true(_fsm.link.held)
	_fsm.reset_for_fight()
	assert_false(_fsm.link.is_open())
	assert_false(_fsm.link.held)
	_fsm.set_active(true)
	_press(J)
	_run_to(_t + 8)
	assert_true(_fsm.link.is_open())
	_fsm.set_active(false)
	assert_false(_fsm.link.is_open())
	assert_null(_fsm.combo)
	assert_false(_fsm.link_second)


## Review: a shift during J's STARTUP must not open the link on the new window.
func test_shift_during_j_startup_does_not_open_the_link() -> void:
	_ring([A, D])
	_press(J)
	_run_to(3)
	_reg.shift(Register.LEFT)
	_run_to(9)
	assert_eq(_fsm.action, Defs.SLASH_1)
	assert_false(_fsm.link.is_open())


## Review: ending J before its last ACTIVE frame never leaves an uncounted link behind.
func test_finish_during_active_starts_the_link_count() -> void:
	_ring([A, D])
	_press(J)
	_run_to(7)
	assert_true(_fsm.link.is_open())
	assert_false(_fsm.link.counting)
	_fsm._finish()
	assert_true(_fsm.link.counting)
