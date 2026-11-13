extends GutTest
## Story 6.2: Dereference (N->A combo). The gate (Null Dodge's ACTIVE frames), the immediate start
## that replaces Null Dodge, the link_second solo-slash fallback, the intangible frames, the damage
## cases, the combo hit-stop, the piercing capsule and the untouched Ghost decoy. The real FSM,
## Player, Register, PlayerHealth and CombatResolver are ticked by hand in SimClock phase order.

const GameScript := preload("res://src/autoloads/game.gd")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const TILE := Const.TILE_PX
const PULSE: AttackDef = preload("res://data/bosses/test_boss/attack_pulse.tres")
const SWEEP: AttackDef = preload("res://data/bosses/test_boss/attack_sweep.tres")

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


## J (Null Dodge) on [N, A], then ticks until Null Dodge's last executed frame is `dodge_frame`.
func _dodge_to(dodge_frame: int) -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_tick()
	assert_eq(_fsm.action, Defs.NULL_DODGE, "Null Dodge runs")
	while _fsm.action_frame < dodge_frame:
		_tick()
	assert_eq(_fsm.action_frame, dodge_frame)
	assert_true(_fsm.link.is_open(), "the link is open")


## Null Dodge, then K on its frame 1 (ACTIVE): Dereference starts on that tick.
func _dereference() -> void:
	_dodge_to(1)
	_buf.push(K, _t)
	_tick()
	assert_eq(_fsm.action, Defs.DEREFERENCE, "Dereference started on the press tick")


func _target(pos: Vector2) -> PracticeTarget:
	var t := PracticeTarget.new(pos)
	_combat.targets.append(t)
	return t


func _boss(pos: Vector2) -> BossController:
	var p := PhaseDef.new()
	p.hp_threshold = 100
	p.weak_window = Vector2i(D, L)
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


func _last_hit_damage() -> int:
	var n: int = get_signal_emit_count(EventBus, "hit_landed")
	assert_gt(n, 0, "a hit landed")
	return get_signal_parameters(EventBus, "hit_landed", n - 1)[1] if n > 0 else -1


## Runs Dereference to its end, collecting the hit-stop requested per tick (max).
func _run_dereference() -> int:
	var max_stop: int = 0
	var guard: int = 0
	while _fsm.action == Defs.DEREFERENCE and guard < 40:
		_tick()
		max_stop = maxi(max_stop, SimClock._pending_hitstop)
		SimClock._pending_hitstop = 0
		guard += 1
	return max_stop


# --- AC 1, 2: data ---

func test_dereference_def_data() -> void:
	var def: ActionDef = Defs.DEREFERENCE
	assert_eq(def.id, &"dereference")
	assert_eq([def.startup_frames, def.active_frames, def.recovery_frames], [2, 8, 14])
	assert_eq([def.invuln_from, def.invuln_to], [1, 10])
	assert_true(def.hit_shape is HitCapsule)
	var cap := def.hit_shape as HitCapsule
	assert_eq([cap.length_tiles, cap.radius_tiles], [3.0, 0.5])
	assert_eq(def.base_damage, 30)
	assert_eq(def.cooldown_frames, 0)
	assert_eq(def.move_tiles, 3.0)
	assert_eq(def.cancel_into, PackedInt32Array())
	assert_eq(def.hitstop_frames, 8)
	assert_false(def.echoable or def.echo_action or def.redirectable or def.pass_through)
	assert_false(def.slows_move or def.arms_clean_catch)
	assert_eq(def.decoy_frames, 0)
	assert_eq(def.validate(), PackedStringArray())


func test_dereference_combo_data() -> void:
	var c: ComboDef = Defs.COMBOS.get_combo(N, A)
	assert_not_null(c)
	assert_eq(c.action, Defs.DEREFERENCE)
	assert_eq(c.display_name, "Dereference")
	assert_false(c.gap_free)
	assert_true(c.requires_first_active)
	assert_eq(c.validate(), PackedStringArray())
	assert_eq(Defs.COMBOS.validate(), PackedStringArray())


func test_gate_rejected_when_first_solo_has_no_active_frames() -> void:
	# NULL's solo has 30 active frames, so the gate passes; with 0 active frames (temporarily set on
	# the shared def, restored at once) the validator rejects it.
	var c := ComboDef.new()
	c.first = N
	c.second = A
	c.action = Defs.DEREFERENCE
	c.display_name = "Dereference"
	c.requires_first_active = true
	assert_eq(c.validate(), PackedStringArray())
	var dodge: ActionDef = Defs.solo_action(N)
	var saved: int = dodge.active_frames
	dodge.active_frames = 0
	var out: PackedStringArray = c.validate()
	dodge.active_frames = saved
	assert_true(Array(out).any(func(m: String) -> bool: return m.begins_with("requires_first_active")), "%s" % out)


func test_gate_and_gap_free_are_mutually_exclusive() -> void:
	var c := ComboDef.new()
	c.first = Register.Bit.NULL_BIT
	c.second = Register.Bit.ATTACK
	c.action = Defs.DEREFERENCE
	c.display_name = "Dereference"
	c.requires_first_active = true
	c.gap_free = true
	assert_true(Array(c.validate()).any(func(m: String) -> bool: return m.begins_with("requires_first_active and gap_free")), "%s" % c.validate())


func test_first_active_ok_is_the_active_range() -> void:
	var dodge: ActionDef = Defs.NULL_DODGE
	assert_false(ActionResolver.first_active_ok(null, 1))
	assert_false(ActionResolver.first_active_ok(dodge, 0))
	assert_true(ActionResolver.first_active_ok(dodge, 1))
	assert_true(ActionResolver.first_active_ok(dodge, 30))
	assert_false(ActionResolver.first_active_ok(dodge, 31))
	assert_false(ActionResolver.first_active_ok(Defs.DEREFERENCE, 2), "startup is not ACTIVE")
	assert_true(ActionResolver.first_active_ok(Defs.DEREFERENCE, 3))
	assert_true(ActionResolver.first_active_ok(Defs.DEREFERENCE, 10))
	assert_false(ActionResolver.first_active_ok(Defs.DEREFERENCE, 11))


# --- AC 3: trigger ---

func test_k_in_dodge_active_starts_dereference_at_once() -> void:
	_dereference()
	assert_eq(_fsm.action_frame, 1)
	assert_not_null(_fsm.combo)
	assert_eq(_fsm.combo.display_name, "Dereference")
	assert_false(_fsm.link_second)
	assert_false(_fsm.link.is_open(), "the combo closed the link")
	assert_false(_fsm.link.held, "no held press")
	assert_false(_buf.consume(K, _t), "the press was consumed")


func test_k_on_the_last_active_frame_still_starts() -> void:
	_dodge_to(30)
	_buf.push(K, _t)
	_tick()
	assert_eq(_fsm.action, Defs.DEREFERENCE)


func test_no_echo_write_and_no_dodge_cooldown_restart() -> void:
	_dodge_to(5)
	var before: int = _fsm.cooldowns.remaining(N)
	assert_gt(before, 0, "Null Dodge's cooldown started on the J press")
	_buf.push(K, _t)
	_tick()
	assert_eq(_fsm.action, Defs.DEREFERENCE)
	assert_eq(_fsm.cooldowns.remaining(N), before - 1, "not restarted, it keeps counting")
	assert_eq(_fsm.cooldowns.remaining(A), 0, "ATTACK's cooldown is 0")
	assert_eq(_fsm.echo.last, Defs.NULL_DODGE, "combos never enter Echo memory")


# --- AC 4: fallback ---

func _assert_fallback(press_frame: int) -> void:
	_dodge_to(press_frame)
	_buf.push(K, _t)
	var guard: int = 0
	while _fsm.action == Defs.NULL_DODGE and guard < 40:
		_tick()
		guard += 1
	assert_eq(_fsm.action, Defs.solo_action(A), "ATTACK's solo slash")
	assert_true(_fsm.link_second, "flagged link_second")
	assert_null(_fsm.combo)


func test_k_just_after_active_falls_back_to_the_slash() -> void:
	_assert_fallback(31)


func test_k_in_dodge_recovery_falls_back_to_the_slash() -> void:
	_assert_fallback(35)


func test_k_after_dodge_in_link_count_falls_back_to_the_slash() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_tick()
	while _fsm.action != null:
		_tick()
	assert_true(_fsm.link.is_open(), "still in the 18-frame count")
	_buf.push(K, _t)
	_tick()
	assert_eq(_fsm.action, Defs.solo_action(A))
	assert_true(_fsm.link_second)
	assert_null(_fsm.combo)


# --- AC 5: intangibility ---

func test_invulnerable_on_frames_1_to_10_only() -> void:
	_dereference()
	for f: int in range(1, 25):
		assert_eq(_fsm.action_frame, f)
		assert_eq(_fsm.invulnerable(), f <= 10, "frame %d" % f)
		_tick()
		if _fsm.action != Defs.DEREFERENCE:
			break


func test_a_hit_on_frame_5_is_ignored_and_does_not_arm() -> void:
	_dereference()
	_run(4)
	assert_eq(_fsm.action_frame, 5)
	_health.queue_hit()
	_tick()
	assert_eq(_health.hp, _health.def.max_hp)
	assert_false(_fsm.clean_catch_armed, "Dereference does not arm Clean Catch")


# --- AC 6, 7, 8: damage, hit-stop, piercing ---

func test_practice_target_takes_30_and_8_frames_of_hitstop() -> void:
	_target(SPAWN + Vector2(TILE, 0))
	_dereference()
	var stop: int = _run_dereference()
	assert_eq(_last_hit_damage(), 30)
	assert_eq(stop, 8, "combo hit-stop 8")
	assert_eq(HitFeedback.hitstop_for(true, Defs.DEREFERENCE.hitstop_frames), 8)


func test_clean_catch_alone_deals_45() -> void:
	_target(SPAWN + Vector2(TILE, 0))
	_fsm.arm_clean_catch()
	_dereference()
	_run_dereference()
	assert_eq(_last_hit_damage(), 45)
	assert_false(_fsm.clean_catch_armed, "consumed by the damaging hit")


func test_unpatched_boss_takes_the_unpatched_multiplier() -> void:
	var boss: BossController = _boss(SPAWN + Vector2(2 * TILE, 0))
	_dereference()
	_run_dereference()
	var expected: int = DamageCalc.compute(30, DamageState.multiplier(DamageState.Kind.UNPATCHED), false, 1.0)
	assert_eq(_last_hit_damage(), expected)
	assert_eq(boss.hp, 100 - expected)


func test_patched_boss_takes_45() -> void:
	var boss: BossController = _boss(SPAWN + Vector2(2 * TILE, 0))
	boss.weak_window.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
	_dereference()
	_run_dereference()
	assert_eq(_last_hit_damage(), 45)
	assert_eq(boss.hp, 55)


func test_patched_boss_with_clean_catch_takes_68() -> void:
	var boss: BossController = _boss(SPAWN + Vector2(2 * TILE, 0))
	boss.weak_window.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
	_fsm.arm_clean_catch()
	_dereference()
	_run_dereference()
	assert_eq(_last_hit_damage(), 68)
	assert_eq(boss.hp, 32)
	assert_false(_fsm.clean_catch_armed)


func test_two_targets_in_the_capsule_are_both_hit_once() -> void:
	var near: PracticeTarget = _target(SPAWN + Vector2(TILE, 0))
	var far: PracticeTarget = _target(SPAWN + Vector2(2 * TILE + 8, 0))
	_dereference()
	_run_dereference()
	assert_eq(near.records().size(), 1, "near target hit once")
	assert_eq(far.records().size(), 1, "far target hit once: the thrust pierces")


# --- AC 10: the Ghost decoy is untouched ---

func test_a_live_ghost_decoy_is_not_struck_or_dispelled() -> void:
	var decoy := GhostDecoy.new()
	decoy.spawn(SPAWN + Vector2(TILE, 0), Vector2i(L, N), 120)
	_combat.ghost = decoy
	_dereference()
	_run_dereference()
	assert_true(decoy.is_live())
	assert_eq(decoy.frames_left, 120)
	assert_signal_emit_count(EventBus, "hit_landed", 0)
