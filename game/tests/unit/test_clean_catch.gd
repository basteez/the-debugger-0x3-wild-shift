extends GutTest
## Story 5.5 (AC 3, 5-10): Clean Catch armed by a hit passing through Null Dodge (live or echoed),
## consumed by the next damaging hit (x1.5 on top of the state), kept by whiffs, decoy dispels,
## pass-throughs and 0-damage hits, cleared at fight reset. The real FSM, Player, Register,
## PlayerHealth and CombatResolver are ticked by hand in SimClock phase order.

const GameScript := preload("res://src/autoloads/game.gd")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const PULSE: AttackDef = preload("res://data/bosses/test_boss/attack_pulse.tres")
const SWEEP: AttackDef = preload("res://data/bosses/test_boss/attack_sweep.tres")


## A boss whose every overlapped action dispels one decoy (the decoy path without the Null Pointer).
class DecoyBoss:
	extends BossController
	var dispels: int = 0

	func decoy_hit(_shape: HitShape, _origin: Vector2, _facing: Vector2) -> int:
		dispels += 1
		return 1


var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _health: PlayerHealth
var _combat: CombatResolver
var _t: int = 0
var _saved_state: int


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE
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
	_health = PlayerHealth.new(_player.def, _fsm)
	_health.reset_for_fight()
	_health.set_active(true)
	_combat = CombatResolver.new(_fsm, _player)
	_t = 0
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	watch_signals(EventBus)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func _ring(bits: Array) -> void:
	assert_true(_reg.set_fight_start(PackedInt32Array(bits)))


func _tick() -> void:
	_ctx.poll_frame = _t
	_reg.tick(_ctx)
	_fsm.tick(_ctx)
	_player.tick(_ctx)
	_combat.tick(_ctx)
	_health.tick(_ctx)
	_t += 1


func _run(n: int) -> void:
	for i: int in n:
		_tick()


func _settle() -> void:
	var guard: int = 0
	while (_fsm.action != null or _fsm.link.is_open()) and guard < 200:
		_tick()
		guard += 1


func _target(pos: Vector2) -> PracticeTarget:
	var t := PracticeTarget.new(pos)
	_combat.targets.append(t)
	return t


func _boss(pos: Vector2, weak: Vector2i = Vector2i(D, L), boss: BossController = null) -> BossController:
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
	var c: BossController = boss if boss != null else BossController.new()
	assert_true(c.setup(d, null, null))
	c.reset_for_fight()
	c.body_center_px = pos
	_combat.boss = c
	return c


func _last_hit_damage() -> int:
	var n: int = get_signal_emit_count(EventBus, "hit_landed")
	assert_gt(n, 0, "a hit landed")
	return get_signal_parameters(EventBus, "hit_landed", n - 1)[1] if n > 0 else -1


## Starts a live Null Dodge on [N, A] and passes one hit through it.
func _dodge_through_a_hit() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_tick()
	_health.queue_hit()
	_tick()


## A K = A slash (solo, no link) on whatever is in front of the player; runs its 22 frames.
func _slash_k() -> void:
	_buf.push(K, _t)
	_run(22)
	SimClock._pending_hitstop = 0


# --- AC 3, 5: arming ---

func test_a_hit_through_the_dodge_arms_without_damage() -> void:
	_dodge_through_a_hit()
	assert_eq(_health.hp, _health.def.max_hp, "no HP lost")
	assert_eq(_health.invuln_left, 0, "no post-hit invulnerability")
	assert_signal_emit_count(EventBus, "player_damaged", 0)
	assert_true(_fsm.clean_catch_armed)


func test_arming_is_idempotent() -> void:
	_dodge_through_a_hit()
	_health.queue_hit()
	_tick()
	_fsm.arm_clean_catch()
	assert_true(_fsm.clean_catch_armed)
	assert_eq(_health.hp, _health.def.max_hp)


func test_no_hit_no_arm() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_run(38)
	assert_false(_fsm.clean_catch_armed)


func test_dash_invulnerability_does_not_arm() -> void:
	_ring([D, A])
	_buf.push(J, _t)
	_tick()
	_health.queue_hit()
	_tick()
	assert_eq(_health.hp, _health.def.max_hp, "the dash still ignores the hit")
	assert_false(_fsm.clean_catch_armed, "only arms_clean_catch arms")


func test_a_hit_in_the_dodge_recovery_lands_and_does_not_arm() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_run(31) # frame 31: recovery
	_health.queue_hit()
	_tick()
	assert_eq(_health.hp, _health.def.max_hp - 1)
	assert_false(_fsm.clean_catch_armed)


func test_post_hit_invulnerability_rejects_first_and_does_not_arm() -> void:
	_ring([N, A])
	_health.queue_hit()
	_tick() # a plain hit: 60 frames of post-hit invulnerability
	assert_eq(_health.hp, _health.def.max_hp - 1)
	_buf.push(J, _t)
	_tick()
	_health.queue_hit()
	_tick()
	assert_eq(_health.hp, _health.def.max_hp - 1)
	assert_false(_fsm.clean_catch_armed, "[design call] D-S55-14: only a rejection by the dodge arms")


# --- AC 6, 10: consumption with the damage state ---

func test_practice_target_takes_x1_5_and_consumes() -> void:
	_dodge_through_a_hit()
	_settle()
	_target(SPAWN + Vector2(16, 0))
	_slash_k()
	assert_eq(_last_hit_damage(), 15, "slash 10 x1 x1.5")
	assert_false(_fsm.clean_catch_armed, "consumed")
	_slash_k()
	assert_eq(_last_hit_damage(), 10, "the next hit is plain")


func test_unpatched_boss_hit_takes_x0_75() -> void:
	var boss: BossController = _boss(SPAWN + Vector2(24, 0))
	_dodge_through_a_hit()
	_settle()
	_slash_k()
	assert_eq(_last_hit_damage(), 8, "slash 10 x0.5 x1.5 = 7.5 -> 8")
	assert_eq(boss.hp, 92)
	assert_false(_fsm.clean_catch_armed)


func test_patched_boss_hit_takes_x2_25() -> void:
	var boss: BossController = _boss(SPAWN + Vector2(24, 0))
	_dodge_through_a_hit()
	_settle()
	boss.weak_window.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
	_slash_k()
	assert_eq(_last_hit_damage(), 23, "slash 10 x1.5 x1.5 = 22.5 -> 23 (D-S55-6)")
	assert_eq(boss.hp, 77)
	assert_false(_fsm.clean_catch_armed)


# --- AC 7: kept when the action does not deal damage ---

func test_a_whiff_keeps_it() -> void:
	_dodge_through_a_hit()
	_settle()
	_slash_k()
	assert_signal_emit_count(EventBus, "hit_landed", 0)
	assert_true(_fsm.clean_catch_armed)


func test_a_decoy_dispel_keeps_it() -> void:
	var boss := _boss(Vector2(40, 40), Vector2i(D, L), DecoyBoss.new()) as DecoyBoss
	_dodge_through_a_hit()
	_settle()
	_slash_k()
	assert_gt(boss.dispels, 0, "the slash dispelled")
	assert_signal_emit_count(EventBus, "hit_landed", 0)
	assert_true(_fsm.clean_catch_armed)


func test_a_pass_through_keeps_it() -> void:
	var boss: BossController = _boss(SPAWN + Vector2(56, 0))
	_dodge_through_a_hit()
	_settle()
	_ring([D, L])
	_buf.push(J, _t)
	_run(3)
	_buf.push(K, _t)
	_run(20)
	SimClock._pending_hitstop = 0
	assert_true(boss.weak_window.is_patched(), "Echo Dash passed through")
	assert_signal_emit_count(EventBus, "hit_landed", 0)
	assert_true(_fsm.clean_catch_armed)


func test_a_zero_damage_hit_keeps_it() -> void:
	_dodge_through_a_hit()
	_settle()
	var zero: ActionDef = Defs.SLASH_1.duplicate()
	zero.base_damage = 0
	zero.chain_next = null
	_ring([L, A])
	_fsm.echo.remember(zero)
	var target: PracticeTarget = _target(SPAWN + Vector2(16, 0))
	_buf.push(J, _t)
	_run(22)
	SimClock._pending_hitstop = 0
	assert_eq(target.records().size(), 1, "the 0-damage echo landed")
	assert_eq(_last_hit_damage(), 0)
	assert_true(_fsm.clean_catch_armed, "damage 0 does not consume")


# --- AC 9: reset ---

func test_fight_reset_disarms() -> void:
	_dodge_through_a_hit()
	assert_true(_fsm.clean_catch_armed)
	_fsm.reset_for_fight()
	assert_false(_fsm.clean_catch_armed)


func test_consume_returns_the_old_value() -> void:
	assert_false(_fsm.consume_clean_catch())
	_fsm.arm_clean_catch()
	assert_true(_fsm.consume_clean_catch())
	assert_false(_fsm.clean_catch_armed)


# --- AC 8, 10: Echo of Null Dodge arms, then the next hit triggers ---

func test_echo_of_null_dodge_arms_and_then_triggers() -> void:
	_ring([L, A])
	_fsm.echo.remember(Defs.NULL_DODGE)
	_buf.push(J, _t)
	_tick()
	assert_true(_fsm.echoing)
	_health.queue_hit()
	_tick()
	assert_eq(_health.hp, _health.def.max_hp)
	assert_true(_fsm.clean_catch_armed, "the echoed dodge arms like the live one")
	_settle()
	_target(SPAWN + Vector2(16, 0))
	_slash_k()
	assert_eq(_last_hit_damage(), 15)
	assert_false(_fsm.clean_catch_armed)
