extends GutTest
## Story 2.7 AC1, AC4: CombatResolver shape math (hits_for) and the real FSM ticked by hand in
## SimClock phase order (Register SHIFTS, FSM ACTIONS, Player PLAYER, CombatResolver COMBAT).
## Tick 0 is the first press tick; slash frame f executes on tick f - 1.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const RIGHT := Vector2(1, 0)

var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _combat: CombatResolver
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
	_combat = CombatResolver.new(_fsm, _player)
	_t = 0
	watch_signals(EventBus)


func after_each() -> void:
	_combat = null
	_fsm = null
	_player = null
	_reg = null
	_buf = null
	_ctx = null


func _ring(bits: Array) -> void:
	assert_true(_reg.set_fight_start(PackedInt32Array(bits)))


func _target(pos: Vector2) -> PracticeTarget:
	var t := PracticeTarget.new(pos)
	_combat.targets.append(t)
	return t


func _tick() -> void:
	_ctx.poll_frame = _t
	_reg.tick(_ctx)
	_fsm.tick(_ctx)
	_player.tick(_ctx)
	_combat.tick(_ctx)
	_t += 1


func _run_to(until: int) -> void:
	while _t < until:
		_tick()


func _arc() -> HitArc:
	return Defs.SLASH_1.hit_shape as HitArc


# --- hits_for (pure) ---

func test_phase_is_combat_after_actions_and_player() -> void:
	assert_eq(_combat.phase, SimSystem.SimPhase.COMBAT)
	assert_gt(SimSystem.SimPhase.COMBAT, SimSystem.SimPhase.ACTIONS)
	assert_gt(SimSystem.SimPhase.COMBAT, SimSystem.SimPhase.PLAYER)


func test_hits_for_circle_in_and_out_of_range() -> void:
	var c := HitCircle.new()
	c.radius_tiles = 1.0
	var near := PracticeTarget.new(SPAWN + Vector2(40, 0)) # 16 + 24 = 40: tangent
	var far := PracticeTarget.new(SPAWN + Vector2(41, 0))
	var all: Array[PracticeTarget] = [near, far]
	var expected: Array[PracticeTarget] = [near]
	assert_eq(CombatResolver.hits_for(c, SPAWN, RIGHT, all, 1), expected)
	assert_true(CombatResolver.hits_for(null, SPAWN, RIGHT, all, 1).is_empty())


func test_hits_for_skips_a_target_already_hit_by_the_serial() -> void:
	var t := PracticeTarget.new(SPAWN + Vector2(20, 0))
	var all: Array[PracticeTarget] = [t]
	assert_eq(CombatResolver.hits_for(_arc(), SPAWN, RIGHT, all, 5).size(), 1)
	t.register_hit(5, 0, &"slash_1", 10)
	assert_true(CombatResolver.hits_for(_arc(), SPAWN, RIGHT, all, 5).is_empty(), "once per serial")
	assert_eq(CombatResolver.hits_for(_arc(), SPAWN, RIGHT, all, 6).size(), 1, "a new action hits again")


func test_no_action_or_no_shape_does_nothing() -> void:
	var t: PracticeTarget = _target(SPAWN)
	_tick()
	assert_eq(t.hits, 0)
	_ring([D, A])
	_buf.push(J, _t)
	_run_to(16) # the solo dash: hit_shape null
	assert_eq(_fsm.action, Defs.DASH)
	assert_eq(t.hits, 0, "a solo dash never hits")
	assert_signal_emit_count(EventBus, "hit_landed", 0)


# --- through the real FSM ---

func test_slash_hits_on_its_first_active_frame_only() -> void:
	_ring([A, D])
	var t: PracticeTarget = _target(SPAWN + Vector2(32, 0))
	_buf.push(J, 0)
	for i: int in 6:
		_tick()
		assert_eq(t.hits, 0, "STARTUP tick %d" % i)
	_tick() # tick 6: frame 7, first ACTIVE
	assert_eq(_fsm.state, ActionStateMachine.ActionState.ACTIVE)
	assert_eq(t.hits, 1)
	_run_to(22)
	assert_eq(t.hits, 1, "once per action, not once per frame")
	assert_signal_emit_count(EventBus, "hit_landed", 1)
	assert_eq(get_signal_parameters(EventBus, "hit_landed"), [&"practice_target", 10, DamageCalc.STATE_BASE, false, t.position_px])


func test_slash_does_not_hit_during_recovery() -> void:
	_ring([A, D])
	_buf.push(J, 0)
	_run_to(11) # frame 11: first RECOVERY frame
	assert_eq(_fsm.state, ActionStateMachine.ActionState.RECOVERY)
	var t: PracticeTarget = _target(SPAWN + Vector2(16, 0))
	_run_to(22)
	assert_eq(t.hits, 0)


func test_slash_chain_damage_10_10_15() -> void:
	_ring([A, D])
	var t: PracticeTarget = _target(SPAWN + Vector2(32, 0))
	_buf.push(J, 0)
	for def: ActionDef in [Defs.SLASH_1, Defs.SLASH_2]:
		while not (_fsm.action == def and _fsm.action_frame == 16):
			_tick()
		_buf.push(J, _t) # inside the chain window
		_tick()
	while _fsm.action != null:
		_tick()
	assert_eq(t.hits, 3)
	var dmg: Array = t.records().map(func(r: Dictionary) -> int: return r[&"damage"])
	var ids: Array = t.records().map(func(r: Dictionary) -> StringName: return r[&"action"])
	assert_eq(ids, [&"slash_1", &"slash_2", &"slash_3"])
	assert_eq(dmg, [10, 10, 15])
	assert_signal_emit_count(EventBus, "hit_landed", 3)


func test_dash_strike_from_spawn_hits_4_tiles_ahead_once_and_never_behind() -> void:
	_ring([A, D])
	var ahead: PracticeTarget = _target(SPAWN + Vector2(64, 0))
	var behind: PracticeTarget = _target(SPAWN - Vector2(192, 0))
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t) # held by the link, Dash Strike starts on tick 11
	_run_to(11)
	assert_eq(ahead.hits, 0, "the slash arc does not reach 4 tiles")
	_tick() # tick 11: Dash Strike frame 1, first ACTIVE
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(ahead.hits, 1)
	assert_eq(ahead.records()[0][&"damage"], 20)
	while _fsm.action != null:
		_tick()
	assert_eq(ahead.hits, 1, "once per dash")
	assert_eq(behind.hits, 0)
	assert_signal_emit_count(EventBus, "hit_landed", 1)
	var params: Array = get_signal_parameters(EventBus, "hit_landed")
	assert_eq(params[1], 20)
	assert_true(params[3], "Dash Strike is a combo hit (D-S27-14)")


func test_dash_strike_reach_is_anchored_at_the_start() -> void:
	# Reach from the start point: 5 + 0.75 + 1.5 = 7.25 tiles (H3).
	_ring([A, D])
	var seven: PracticeTarget = _target(SPAWN + Vector2(7 * 16, 0))
	var eight: PracticeTarget = _target(SPAWN + Vector2(8 * 16, 0))
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t)
	_run_to(40)
	assert_eq(seven.hits, 1)
	assert_eq(eight.hits, 0, "the capsule does not travel with the player")


func test_link_second_hit_is_not_a_combo() -> void:
	_ring([D, A])
	_buf.push(J, 0) # solo dash, opens the link
	_run_to(16)
	var t: PracticeTarget = _target(_player.position_px + Vector2(32, 0))
	_buf.push(K, _t)
	_run_to(_t + 10)
	assert_true(_fsm.link_second)
	assert_eq(t.hits, 1)
	var params: Array = get_signal_parameters(EventBus, "hit_landed")
	assert_eq(params[1], 10)
	assert_false(params[3])


func test_a_new_action_hits_the_same_target_again() -> void:
	_ring([A, D])
	var t: PracticeTarget = _target(SPAWN + Vector2(20, 0))
	_buf.push(J, 0)
	_run_to(23) # slash_1 done (22 frames), idle on tick 22
	assert_null(_fsm.action)
	_buf.push(J, _t)
	_run_to(_t + 8)
	assert_eq(t.hits, 2)
	assert_eq(t.last_hit_serial, _fsm.action_serial)


func test_facing_left_hits_the_left_target_and_never_the_right() -> void:
	_ring([A, D])
	_player.facing = Vector2i(-1, 0)
	var left: PracticeTarget = _target(SPAWN - Vector2(32, 0))
	var right: PracticeTarget = _target(SPAWN + Vector2(32, 0))
	_buf.push(J, 0)
	_run_to(24)
	assert_eq(left.hits, 1)
	assert_eq(right.hits, 0)
