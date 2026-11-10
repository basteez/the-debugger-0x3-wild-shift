extends GutTest
## Story 4.1 (F2-F6, AC2-AC7): Echo through the real ActionStateMachine, CombatResolver and Arena,
## ticked by hand in SimClock phase order (Register SHIFTS, FSM ACTIONS, Player PLAYER,
## CombatResolver COMBAT). Tick 0 is the first press tick; a press pushed at tick t is live through t + 8.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)

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


func _press(key: StringName) -> void:
	_buf.push(key, _t)


## Ticks until no action runs and the link is closed (so a K press is a plain solo).
func _settle() -> void:
	var guard: int = 0
	while (_fsm.action != null or _fsm.link.is_open()) and guard < 200:
		_tick()
		guard += 1


## The 3-hit ATTACK chain from the J slot (presses inside each chain window).
func _chain_to_slash_3() -> void:
	_press(J)
	for def: ActionDef in [Defs.SLASH_1, Defs.SLASH_2]:
		while not (_fsm.action == def and _fsm.action_frame == 16):
			_tick()
		_press(J)
		_tick()
	assert_eq(_fsm.action, Defs.SLASH_3)


# --- AC1: data ---

func test_echo_def_validates_and_is_loops_solo_action() -> void:
	var echo := load("res://data/actions/echo.tres") as ActionDef
	assert_eq(echo.validate(), PackedStringArray())
	assert_eq(echo.id, &"echo")
	assert_true(echo.echo_action)
	assert_false(echo.echoable)
	assert_eq(echo.cooldown_frames, 90)
	assert_eq(echo.echo_damage_pct, 70)
	assert_null(echo.hit_shape)
	assert_eq(echo.base_damage, 0)
	assert_same(Defs.ECHO, echo)
	assert_same(Defs.solo_action(L), Defs.ECHO)
	assert_false(Defs.NOP.echoable, "NOP stays, never echoable")
	assert_eq(Defs.NOP.validate(), PackedStringArray())


func test_echo_validation_rules() -> void:
	var bad := ActionDef.new()
	bad.echo_action = true
	bad.echo_damage_pct = 0
	bad.base_damage = 5
	bad.hit_shape = HitCircle.new()
	bad.echoable = false
	bad.cooldown_frames = 90
	assert_eq(bad.validate().size(), 3, "pct range, no hit shape, base_damage 0")
	bad.echoable = true
	bad.cooldown_frames = 0
	assert_eq(bad.validate().size(), 5, "plus echoable must be false, cooldown >= 1 (review)")
	bad.echoable = false
	bad.cooldown_frames = 90
	bad.echo_damage_pct = 201
	bad.base_damage = 0
	bad.hit_shape = null
	assert_eq(bad.validate().size(), 1)
	var plain := ActionDef.new()
	plain.echo_damage_pct = 0
	assert_eq(plain.validate(), PackedStringArray(), "pct is only checked on an echo_action")


# --- AC2: storage through the FSM ---

func test_solo_start_stores_even_on_a_whiff_and_chain_hits_store() -> void:
	_ring([A, L])
	_press(J)
	_tick()
	assert_same(_fsm.echo.last, Defs.SLASH_1, "stored at start, no target to hit")
	_settle()
	_chain_to_slash_3()
	assert_same(_fsm.echo.last, Defs.SLASH_3, "a chain hit is a solo ATTACK action (D-S41-10)")


func test_combo_never_stores() -> void:
	_ring([A, D])
	_press(J)
	_run_to(3)
	_press(K) # held by the link: Dash Strike on tick 11
	_run_to(12)
	assert_eq(_fsm.action, Defs.DASH_STRIKE)
	assert_same(_fsm.echo.last, Defs.SLASH_1, "the combo did not replace the J solo")


func test_link_second_solo_is_stored() -> void:
	_ring([D, A])
	_press(J) # dash, opens the link
	_run_to(16)
	_press(K)
	_run_to(_t + 2)
	assert_true(_fsm.link_second)
	assert_same(_fsm.echo.last, Defs.SLASH_1)


# --- AC3: empty memory ---

func test_empty_memory_l_press_does_nothing_on_either_slot() -> void:
	_ring([L, A])
	_press(J)
	_tick()
	assert_null(_fsm.action, "J on L with empty memory starts nothing")
	assert_eq(_fsm.cooldowns.remaining(L), 0)
	assert_eq(_buf.size(), 1, "the press stays buffered")
	_run_to(_t + 10)
	assert_null(_fsm.action)
	assert_false(_buf.consume(J, _t), "and expired after 8 frames")
	_ring([A, L])
	_press(K)
	_tick()
	assert_null(_fsm.action, "K on L with empty memory starts nothing")
	assert_eq(_fsm.cooldowns.remaining(L), 0)


func test_empty_memory_other_slot_still_starts() -> void:
	_ring([L, A])
	_press(J)
	_press(K)
	_tick()
	assert_eq(_fsm.action, Defs.SLASH_1, "K's slash starts from the same press set")
	assert_eq(_fsm.action_slot, 1)


func test_resolver_gate_reads_only_echo_ready() -> void:
	var cd := Cooldowns.new()
	var buf := InputBuffer.new()
	buf.push(J, 0)
	var input := ResolveInput.new()
	input.buffer = buf
	input.window = Vector2i(L, A)
	input.cooldowns = cd
	assert_null(ActionResolver.resolve(input), "echo_ready false: no action")
	assert_eq(buf.size(), 1)
	input.echo_ready = true
	var r: ActionRequest = ActionResolver.resolve(input)
	assert_not_null(r)
	assert_same(r.def, Defs.ECHO)
	assert_eq(r.bit, L)


## Review: a held K press on an Echo link target with empty memory never starts and drops by the
## normal 8-frame lifetime rule (AC3, Task C2).
func test_held_link_press_with_empty_memory_is_dropped_by_lifetime() -> void:
	var link := LinkState.new()
	link.open(Vector2i(D, L), 0)
	link.hold(K, 1, 4)
	var input := ResolveInput.new()
	input.buffer = InputBuffer.new()
	input.window = Vector2i(D, L)
	input.cooldowns = Cooldowns.new()
	input.link = link
	input.combos = ComboTable.new()
	input.frame = 8
	assert_null(ActionResolver.resolve(input), "inside the lifetime: nothing, no start")
	input.frame = 4 + InputBuffer.PRESS_LIFETIME_FRAMES + 1
	var r: ActionRequest = ActionResolver.resolve(input)
	assert_not_null(r)
	assert_null(r.def, "an instruction, not a start")
	assert_eq(r.link_op, ActionRequest.LinkOp.DROP)


# --- AC4: Echo ---

func test_echo_replays_slash_3_with_loop_cooldown_only() -> void:
	_ring([A, L])
	_chain_to_slash_3()
	_settle()
	_press(K)
	_tick()
	assert_same(_fsm.action, Defs.SLASH_3)
	assert_true(_fsm.echoing)
	assert_false(_fsm.link_second)
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.cooldowns.remaining(L), 90)
	assert_eq(_fsm.cooldowns.remaining(A), 0)
	assert_same(_fsm.echo.last, Defs.SLASH_3, "Echo never changes memory")
	assert_almost_eq(_fsm.echo_scale(), 0.7, 0.0001)
	_settle()
	assert_false(_fsm.echoing, "cleared when the action ends")
	assert_almost_eq(_fsm.echo_scale(), 1.0, 0.0001)
	_press(K)
	_tick()
	assert_null(_fsm.action, "LOOP still cooling down")
	assert_eq(_buf.size(), 1, "blocked press stays buffered")


func test_echo_runs_at_current_position_and_facing() -> void:
	_ring([A, L])
	_press(J)
	_tick()
	_settle()
	_player.position_px = SPAWN + Vector2(-40, 10)
	_player.facing = Vector2i(-1, 0)
	_press(K)
	_tick()
	assert_true(_fsm.echoing)
	assert_eq(_fsm.action_origin_px, SPAWN + Vector2(-40, 10))
	assert_eq(_fsm.facing, Vector2i(-1, 0))


func test_echo_does_not_start_a_chain() -> void:
	_ring([A, L])
	_press(J)
	_tick()
	_settle()
	_press(K)
	_tick()
	assert_true(_fsm.echoing)
	assert_eq(_fsm.chain_serial, -1, "D-S41-7")
	while _fsm.action_frame < 16:
		_tick()
	_press(J)
	_tick()
	assert_ne(_fsm.action, Defs.SLASH_2, "no chain from an echoed slash_1")


## Story 4.2 (AC 8c): rewritten from 4.1's "Echo of DASH as link_second on [D, L]" (D-S41-11). The
## shipped table now holds the D->L combo, so K on [D, L] fires Echo Dash instead of Echo. The intent
## is kept: a second 4-tile dash that neither checks nor restarts DASH's cooldown.
func test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown() -> void:
	_ring([D, L])
	_press(J)
	_tick()
	assert_eq(_fsm.action, Defs.DASH)
	while _fsm.action_frame < 4:
		_tick()
	var dash_cd: int = _fsm.cooldowns.remaining(D)
	assert_gt(dash_cd, 0, "DASH cooling down")
	_press(K) # link open on [D, L], dash frame 4 invulnerable: Echo Dash replaces the dash
	_tick()
	assert_same(_fsm.action, Defs.ECHO_DASH)
	assert_false(_fsm.echoing, "a combo, not an Echo")
	assert_false(_fsm.link_second)
	assert_eq(_fsm.cooldowns.remaining(L), 90)
	assert_eq(_fsm.cooldowns.remaining(D), dash_cd - 1, "Echo Dash neither checks nor restarts DASH")
	var origin: Vector2 = _fsm.action_origin_px
	while _fsm.action_frame < 10:
		assert_true(_fsm.invulnerable(), "Echo Dash frame %d" % _fsm.action_frame)
		_tick()
	assert_true(_fsm.invulnerable(), "Echo Dash frame 10")
	assert_almost_eq(_player.position_px.x, origin.x + 4.0 * Const.TILE_PX, 0.001, "4 tiles over the ACTIVE frames")
	assert_almost_eq(_player.position_px.y, origin.y, 0.001)


# --- AC5: damage ---

func test_echo_of_slash_3_deals_11_and_slash_1_deals_7() -> void:
	_ring([A, L])
	var t: PracticeTarget = _target(SPAWN + Vector2(32, 0))
	_chain_to_slash_3()
	_settle()
	_press(K)
	_run_to(_t + 10)
	var dmg: Array = t.records().map(func(r: Dictionary) -> int: return r[&"damage"])
	var ids: Array = t.records().map(func(r: Dictionary) -> StringName: return r[&"action"])
	assert_eq(ids, [&"slash_1", &"slash_2", &"slash_3", &"slash_3"])
	assert_eq(dmg, [10, 10, 15, 11])
	var params: Array = get_signal_parameters(EventBus, "hit_landed")
	assert_eq(params[1], 11)
	assert_false(params[3], "an Echo hit is not a combo")


func test_echo_of_slash_1_deals_7() -> void:
	_ring([A, L])
	var t: PracticeTarget = _target(SPAWN + Vector2(32, 0))
	_press(J)
	_tick()
	_settle()
	_press(K)
	_run_to(_t + 10)
	var dmg: Array = t.records().map(func(r: Dictionary) -> int: return r[&"damage"])
	assert_eq(dmg, [10, 7])


func test_damage_calc_echo_cases() -> void:
	assert_eq(DamageCalc.to_pct(Defs.ECHO.echo_damage_pct / 100.0), 70)
	assert_eq(DamageCalc.compute(15, 1.0, false, 0.7), 11)
	assert_eq(DamageCalc.compute(10, 1.0, false, 0.7), 7)
	assert_eq(DamageCalc.compute(15, 1.5, false, 0.7), 16, "Patched Echo of 15")
	assert_eq(DamageCalc.compute(0, 1.0, false, 0.7), 0, "Echo of DASH: movement only")


# --- AC6: boss ---

const PULSE: AttackDef = preload("res://data/bosses/test_boss/attack_pulse.tres")
const SWEEP: AttackDef = preload("res://data/bosses/test_boss/attack_sweep.tres")


func _boss(weak: Vector2i, pos: Vector2) -> BossController:
	var p := PhaseDef.new()
	p.hp_threshold = 100
	p.weak_window = weak
	p.gap_frames = 40
	p.attack_pool = [PULSE, SWEEP]
	var d := BossDef.new()
	d.boss_id = &"unit_boss"
	d.name_signature = "unitBoss"
	d.max_hp = 100
	d.phases = [p]
	d.body_radius_tiles = 1.0
	var c := BossController.new()
	assert_true(c.setup(d, null, null))
	c.reset_for_fight()
	c.body_center_px = pos
	_combat.boss = c
	return c


func test_solo_echo_hit_never_completes_a_weak_window() -> void:
	var solo := BossInteraction.new(BossInteraction.Kind.HIT, Vector2i(A, L), false, false)
	assert_false(BossInteraction.completes_weak_window(solo, Vector2i(A, L)))


func test_solo_echo_on_boss_is_unpatched_and_does_not_patch() -> void:
	_ring([A, L])
	_press(J)
	_tick()
	_settle()
	var boss: BossController = _boss(Vector2i(A, L), SPAWN + Vector2(40, 0))
	_press(K)
	_run_to(_t + 10)
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_false(boss.weak_window.is_patched())
	var expected: int = DamageCalc.compute(10, 0.5, false, 0.7)
	assert_eq(boss.hp, 100 - expected, "10 x 0.5 x 0.7")


# --- AC7: reset ---

func test_reset_for_fight_clears_memory_and_echoing() -> void:
	_ring([A, L])
	_press(J)
	_tick()
	_settle()
	_press(K)
	_tick()
	assert_true(_fsm.echoing)
	_fsm.reset_for_fight()
	assert_false(_fsm.echo.has_last())
	assert_false(_fsm.echoing)


func test_arena_fight_start_and_retry_clear_memory() -> void:
	var arena := Arena.new()
	arena.actions.echo.remember(Defs.SLASH_3)
	arena.enter_fight(Register.fight_start_for_boss(1))
	assert_false(arena.actions.echo.has_last(), "fight start")
	arena.actions.echo.remember(Defs.DASH)
	arena.enter_fight(Register.fight_start_for_boss(1)) # retry takes the same route
	assert_false(arena.actions.echo.has_last(), "retry")
	arena.leave_fight()
	arena.free()
