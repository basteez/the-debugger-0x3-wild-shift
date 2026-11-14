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
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	watch_signals(EventBus)


func after_each() -> void:
	for system: SimSystem in [_reg, _fsm, _player, _combat]:
		SimClock.unregister_system(system)
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
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


# --- Story 2.8: hit-stop requests (AC1) ---

func test_slash_hit_requests_normal_hitstop_3() -> void:
	_ring([A, D])
	_target(SPAWN + Vector2(32, 0))
	_buf.push(J, 0)
	_run_to(6)
	assert_eq(SimClock._pending_hitstop, 0, "no hit, no request")
	_tick() # first ACTIVE frame: the hit
	assert_eq(SimClock._pending_hitstop, HitFeedback.NORMAL_HITSTOP)


func test_dash_strike_hit_requests_its_own_6() -> void:
	_ring([A, D])
	_target(SPAWN + Vector2(64, 0))
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t)
	_run_to(11)
	SimClock._pending_hitstop = 0 # nothing earlier hit (the arc does not reach 4 tiles)
	_tick()
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	assert_eq(Defs.DASH_STRIKE.hitstop_frames, 6)
	assert_eq(SimClock._pending_hitstop, 6)


func test_a_tick_with_no_hit_requests_nothing() -> void:
	_ring([A, D])
	_target(SPAWN + Vector2(200, 0)) # out of reach
	_buf.push(J, 0)
	_run_to(22)
	assert_eq(SimClock._pending_hitstop, 0)
	assert_signal_emit_count(EventBus, "hit_landed", 0)


func test_two_hits_in_one_tick_request_once_with_the_max() -> void:
	_ring([A, D])
	_target(SPAWN + Vector2(32, 0))
	_target(SPAWN + Vector2(24, 8))
	_buf.push(J, 0)
	_run_to(7)
	assert_signal_emit_count(EventBus, "hit_landed", 2)
	assert_eq(SimClock._pending_hitstop, HitFeedback.NORMAL_HITSTOP)


func test_through_simclock_slash_freezes_the_world_for_3_frames() -> void:
	# Integration (G3): the real autoload SimClock ticks the systems; hit-stop lands after the tick.
	_buf = SimClock.buffer
	_buf.clear()
	_reg = Register.new(_buf)
	_reg.set_active(true)
	_fsm = ActionStateMachine.new(_buf, _player, _reg)
	_fsm.reset_for_fight()
	_fsm.set_active(true)
	_combat = CombatResolver.new(_fsm, _player)
	_ring([A, D])
	var t: PracticeTarget = _target(SPAWN + Vector2(32, 0))
	var saved_source: InputSource = SimClock.input_source
	var saved_paused: bool = SimClock.paused
	SimClock.input_source = null
	SimClock.paused = false
	for system: SimSystem in [_reg, _fsm, _player, _combat]:
		SimClock.register_system(system)
	_buf.push(J, SimClock.poll_frame)
	var guard: int = 0
	while t.hits == 0 and guard < 30:
		SimClock.tick()
		guard += 1
	assert_eq(t.hits, 1)
	assert_eq(SimClock.hitstop_frames, 3, "the hit tick sets 3 frames of hit-stop")
	var frame: int = SimClock.sim_frame
	var action_frame: int = _fsm.action_frame
	for i: int in 3:
		SimClock.tick()
		assert_eq(SimClock.sim_frame, frame, "frozen on hit-stop frame %d" % i)
		assert_eq(_fsm.action_frame, action_frame)
	SimClock.tick()
	assert_eq(SimClock.sim_frame, frame + 1, "the world resumes")
	SimClock.input_source = saved_source
	SimClock.paused = saved_paused


# --- Story 3.2: boss hits, weak window, Patched (AC 1-4, 6, 7; D-S32-8..12) ---

const PULSE: AttackDef = preload("res://data/bosses/test_boss/attack_pulse.tres")
const SWEEP: AttackDef = preload("res://data/bosses/test_boss/attack_sweep.tres")


## A one-phase boss with `weak` as its window, 100 HP (no phase change in these tests), at `pos`.
func _boss(weak: Vector2i, pos: Vector2, max_hp: int = 100) -> BossController:
	var p := PhaseDef.new()
	p.hp_threshold = 100
	p.weak_window = weak
	p.gap_frames = 40
	p.attack_pool = [PULSE, SWEEP]
	var d := BossDef.new()
	d.boss_id = &"unit_boss"
	d.name_signature = "unitBoss"
	d.max_hp = max_hp
	d.phases = [p]
	d.body_radius_tiles = 1.0
	var c := BossController.new()
	assert_true(c.setup(d, null, null))
	c.reset_for_fight()
	c.body_center_px = pos
	_combat.boss = c
	return c


## Dash Strike from spawn on [A, D]: J at 0, K held by the link, the strike hits on tick 11.
func _dash_strike() -> void:
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t)
	_run_to(11)
	SimClock._pending_hitstop = 0
	_tick()
	assert_eq(_fsm.action, Defs.DASH_STRIKE)


func _boss_hits() -> Array:
	var out: Array = []
	for i: int in get_signal_emit_count(EventBus, "hit_landed"):
		var params: Array = get_signal_parameters(EventBus, "hit_landed", i)
		if params[0] == &"boss":
			out.append(params)
	return out


func test_dash_strike_on_the_a_d_window_patches_first_and_deals_30() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(A, D), SPAWN + Vector2(64, 0))
	_dash_strike()
	assert_eq(_fsm.action_window, Vector2i(A, D))
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_signal_emitted_with_parameters(EventBus, "patched_applied", [&"unit_boss", 180])
	assert_eq(boss.weak_window.frames_left, 180)
	assert_eq(boss.hp, 70, "20 x 1.5 = 30, the patching hit is already Patched")
	assert_signal_emitted_with_parameters(EventBus, "hit_landed", [&"boss", 30, DamageState.Kind.PATCHED, true, boss.body_center_px])
	assert_eq(SimClock._pending_hitstop, HitFeedback.PATCHED_APPLIED_HITSTOP, "patching hit: 4 (D-S32-8)")
	while _fsm.action != null:
		_tick()
	assert_eq(_boss_hits().size(), 1, "one boss hit per action serial")
	assert_signal_emit_count(EventBus, "patched_applied", 1)


func test_dash_strike_on_a_d_against_a_d_to_a_boss_is_resisted() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(D, A), SPAWN + Vector2(64, 0))
	_dash_strike()
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_false(boss.weak_window.is_patched())
	assert_eq(boss.hp, 90, "20 x 0.5 = 10")
	assert_signal_emitted_with_parameters(EventBus, "hit_landed", [&"boss", 10, DamageState.Kind.UNPATCHED, true, boss.body_center_px])
	assert_eq(SimClock._pending_hitstop, 6, "unpatched combo keeps its own value")


## Story 7.4 (AC 8): the assist never touches the damage multipliers (x0.5 unpatched, x1.5 Patched).
func test_assisted_boss_keeps_the_unpatched_and_patched_multipliers() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(D, A), SPAWN + Vector2(64, 0))
	boss.assist = true
	_dash_strike()
	assert_eq(boss.hp, 90, "assisted: 20 x 0.5 = 10, unchanged")
	assert_signal_emitted_with_parameters(EventBus, "hit_landed", [&"boss", 10, DamageState.Kind.UNPATCHED, true, boss.body_center_px])


func test_assisted_boss_keeps_the_patched_multiplier() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(A, D), SPAWN + Vector2(64, 0))
	boss.assist = true
	_dash_strike()
	assert_eq(boss.hp, 70, "assisted: 20 x 1.5 = 30, unchanged")


func test_link_second_slash_on_d_a_patches_and_deals_15() -> void:
	_ring([D, A])
	_buf.push(J, 0) # solo dash, opens the link
	_run_to(16)
	var boss: BossController = _boss(Vector2i(D, A), _player.position_px + Vector2(32, 0))
	_buf.push(K, _t)
	var guard: int = 0
	while _boss_hits().is_empty() and guard < 20:
		SimClock._pending_hitstop = 0
		_tick()
		guard += 1
	assert_true(_fsm.link_second)
	assert_eq(_fsm.action_window, Vector2i(D, A))
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_eq(boss.hp, 85)
	assert_eq(_boss_hits()[0], [&"boss", 15, DamageState.Kind.PATCHED, false, boss.body_center_px])
	assert_eq(SimClock._pending_hitstop, HitFeedback.PATCHED_APPLIED_HITSTOP, "the patching slash takes 4 (D-S32-8)")


func test_solo_slash_on_the_right_bits_never_patches() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(A, D), SPAWN + Vector2(32, 0))
	_buf.push(J, 0)
	_run_to(6)
	SimClock._pending_hitstop = 0
	_tick()
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_eq(boss.hp, 95, "slash 10 x 0.5 = 5")
	assert_eq(_boss_hits()[0], [&"boss", 5, DamageState.Kind.UNPATCHED, false, boss.body_center_px])
	assert_eq(SimClock._pending_hitstop, HitFeedback.NORMAL_HITSTOP)


func test_a_patched_boss_takes_crits_with_8_frames_of_hitstop() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(D, A), SPAWN + Vector2(32, 0))
	boss.weak_window.apply_patched(100)
	_buf.push(J, 0)
	_run_to(6)
	SimClock._pending_hitstop = 0
	_tick()
	assert_signal_emit_count(EventBus, "patched_applied", 0, "a plain hit does not refresh")
	assert_eq(boss.weak_window.frames_left, 100)
	assert_eq(_boss_hits()[0], [&"boss", 15, DamageState.Kind.PATCHED, false, boss.body_center_px])
	assert_eq(SimClock._pending_hitstop, HitFeedback.CRIT_HITSTOP)


func test_reapplying_patched_while_active_refreshes_to_180() -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(A, D), SPAWN + Vector2(64, 0))
	boss.weak_window.apply_patched(20)
	_dash_strike()
	assert_eq(boss.weak_window.frames_left, 180)
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_eq(SimClock._pending_hitstop, HitFeedback.PATCHED_APPLIED_HITSTOP)


func test_practice_target_on_a_matching_window_is_never_patched() -> void:
	_ring([D, A])
	_buf.push(J, 0)
	_run_to(16)
	var t: PracticeTarget = _target(_player.position_px + Vector2(32, 0))
	_buf.push(K, _t)
	_run_to(_t + 10)
	assert_true(_fsm.link_second)
	assert_eq(t.hits, 1)
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_eq(get_signal_parameters(EventBus, "hit_landed"), [&"practice_target", 10, DamageState.Kind.BASE, false, t.position_px])


## D-S32-9 / AC 7: a Dash Strike through a boss in `mode` has no effect at all.
func _assert_never_hit(mode: String) -> void:
	_ring([A, D])
	var boss: BossController = _boss(Vector2i(A, D), SPAWN + Vector2(64, 0))
	match mode:
		"roar":
			boss.state = BossController.BossState.ROAR
		"defeated":
			boss.debug_kill()
		"inactive":
			boss.set_active(false)
	var hp: int = boss.hp
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t)
	_run_to(11)
	SimClock._pending_hitstop = 0
	_run_to(30)
	assert_false(boss.is_hittable(), mode)
	assert_eq(boss.hp, hp, mode)
	assert_false(boss.weak_window.is_patched(), mode)
	assert_eq(_boss_hits().size(), 0, mode)
	assert_signal_emit_count(EventBus, "patched_applied", 0, mode)
	assert_eq(SimClock._pending_hitstop, 0, "%s: no hit-stop" % mode)


func test_a_roaring_boss_is_never_hit() -> void:
	_assert_never_hit("roar")


func test_a_defeated_boss_is_never_hit() -> void:
	_assert_never_hit("defeated")


func test_an_inactive_boss_is_never_hit() -> void:
	_assert_never_hit("inactive")


func test_a_combo_hits_a_boss_and_a_practice_target_in_the_same_tick() -> void:
	_ring([A, D])
	var t: PracticeTarget = _target(SPAWN + Vector2(64, 0))
	var boss: BossController = _boss(Vector2i(A, D), SPAWN + Vector2(96, 0))
	_dash_strike()
	assert_signal_emit_count(EventBus, "hit_landed", 2)
	assert_eq(boss.hp, 70)
	assert_eq(t.hits, 1)
	assert_eq(t.records()[0][&"damage"], 20, "the practice target stays x1")
	assert_eq(SimClock._pending_hitstop, 6, "max of the patching 4 and the practice combo 6")


func test_hits_for_dedupes_a_target_listed_twice() -> void:
	var t := PracticeTarget.new(SPAWN + Vector2(20, 0))
	var all: Array[PracticeTarget] = [t, t]
	assert_eq(CombatResolver.hits_for(_arc(), SPAWN, RIGHT, all, 1).size(), 1)


func test_target_ids() -> void:
	assert_eq(PracticeTarget.new().hit_target_id(), &"practice_target")
	assert_eq(BossController.new().hit_target_id(), &"boss")


# --- Story 3.3: the Infinite Loop's `;` through overlaps_shape (AC 4, D-S33-4, D-S33-5, D-S33-14) ---

const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")

var _il_shifts: int = 0


## The real Infinite Loop, started (first shift seen, `;` open at angle 0, i.e. right of the centre)
## unless `open` is false, with segment `k` placed at `at`. The resolver test never ticks the boss,
## so the ring stays put during the action.
func _loop(at: Vector2, k: int = 0, open: bool = true, skip_phase: bool = false) -> InfiniteLoopBody:
	_il_shifts = 0
	var ctx := ArenaContext.new()
	ctx.shift_count = func() -> int: return _il_shifts
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(IL_DEF, null, ctx))
	b.reset_for_fight()
	var centre: Vector2 = b.body_center_px
	ctx.contact_source = func() -> Vector2: return centre # no drift (never capture b: a ref cycle)
	var sim := SimContext.new()
	if skip_phase:
		b.debug_skip_phase()
		for i: int in BossController.ROAR_FRAMES:
			b.tick(sim)
		assert_eq(b.state, BossController.BossState.GAP)
	if open:
		_il_shifts = 1
		b.tick(sim)
		assert_true(b.is_open())
	b.body_center_px += at - b.segment_px(k)
	_combat.boss = b
	return b


func test_dash_strike_into_the_open_semicolon_on_a_d_patches_and_deals_30() -> void:
	_ring([A, D])
	var b: InfiniteLoopBody = _loop(SPAWN + Vector2(64, 0))
	_dash_strike()
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_signal_emitted_with_parameters(EventBus, "patched_applied", [&"infinite_loop", 180])
	assert_eq(b.hp, 370, "P1 A>D: 20 x 1.5 = 30")
	assert_eq(_boss_hits()[0], [&"boss", 30, DamageState.Kind.PATCHED, true, b.semicolon_px()], "lands on the `;`")
	assert_eq(SimClock._pending_hitstop, HitFeedback.PATCHED_APPLIED_HITSTOP)


func test_link_second_slash_on_d_a_patches_the_loop_in_phase_2() -> void:
	_ring([D, A])
	_buf.push(J, 0) # solo dash, opens the link
	_run_to(16)
	var b: InfiniteLoopBody = _loop(_player.position_px + Vector2(32, 0), 0, true, true)
	assert_eq(b.phase_index, 1)
	assert_eq(b.current_weak_window(), Vector2i(D, A))
	var hp: int = b.hp
	_buf.push(K, _t)
	var guard: int = 0
	while _boss_hits().is_empty() and guard < 20:
		SimClock._pending_hitstop = 0
		_tick()
		guard += 1
	assert_true(_fsm.link_second)
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_eq(b.hp, hp - 15, "slash 10 x 1.5")


func test_a_hit_on_a_segment_does_nothing_and_does_not_mark_the_action() -> void:
	_ring([A, D])
	var b: InfiniteLoopBody = _loop(SPAWN + Vector2(64, 0), 12) # the far side of the ring on the path
	assert_gt(b.semicolon_px().distance_to(SPAWN), 8.0 * Const.TILE_PX, "the `;` is out of reach")
	_dash_strike()
	_assert_loop_untouched(b)


func test_a_hit_on_a_closed_semicolon_does_nothing() -> void:
	_ring([A, D])
	var b: InfiniteLoopBody = _loop(SPAWN + Vector2(64, 0), 0, false)
	assert_false(b.is_open())
	_dash_strike()
	_assert_loop_untouched(b)


func _assert_loop_untouched(b: InfiniteLoopBody) -> void:
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	while _fsm.action != null:
		_tick()
	assert_eq(b.hp, 400)
	assert_false(b.weak_window.is_patched())
	assert_eq(_boss_hits().size(), 0, "no hit_landed")
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_eq(SimClock._pending_hitstop, 0, "no hit-stop")
	assert_eq(b.last_hit_serial, -1, "the action is not marked (D-S33-5)")


func test_a_dash_through_the_closed_semicolon_lands_when_it_opens_mid_action() -> void:
	_ring([A, D])
	var b: InfiniteLoopBody = _loop(SPAWN + Vector2(64, 0), 0, false)
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t)
	_run_to(11)
	SimClock._pending_hitstop = 0
	_tick() # first strike frame on the closed `;`
	assert_eq(_boss_hits().size(), 0)
	var seg0: Vector2 = b.segment_px(0)
	_il_shifts = 1
	b.tick(SimContext.new()) # the `;` opens (no motion on the start tick)
	assert_eq(b.segment_px(0), seg0)
	_tick()
	assert_eq(_boss_hits().size(), 1, "the same action lands once the `;` opens")
	assert_eq(b.hp, 370)
