extends GutTest
## Story 3.1 AC 1-3, 5, 6, 8, 9: the boss framework. BossController FSM timings and hooks, the
## no-triple-repeat pick rule, phases, ROAR, jitter, def validation, target injection, the
## play-area helper and body contact. No scene tree: the controller is ticked directly.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const TEST_BOSS: BossDef = preload("res://data/bosses/test_boss/boss_def.tres")
const PULSE: AttackDef = preload("res://data/bosses/test_boss/attack_pulse.tres")
const SWEEP: AttackDef = preload("res://data/bosses/test_boss/attack_sweep.tres")
const PulseScript := preload("res://src/bosses/test_boss/attacks/pulse.gd")
const SweepScript := preload("res://src/bosses/test_boss/attacks/sweep.gd")
const FAR_PX := Vector2(10, 10)


## Records every hook call in order: "tell:<id>", "active:<id>", "recovery:<id>".
class RecordingAttack:
	extends BossAttack
	var calls: PackedStringArray = PackedStringArray()
	var aim: Vector2 = Vector2.ZERO
	var cancels: int = 0

	func on_tell(ctx: ArenaContext) -> void:
		aim = ctx.target_position()
		calls.append("tell")

	func on_active(_ctx: ArenaContext) -> void:
		calls.append("active")

	func on_recovery(_ctx: ArenaContext) -> void:
		calls.append("recovery")

	func on_cancel(_ctx: ArenaContext) -> void:
		cancels += 1


## Counts the speed-ramp hook.
class RampBoss:
	extends BossController
	var resets: int = 0

	func _on_phase_reset() -> void:
		resets += 1


## Story 3.5 (B1): a boss whose candidate list the test sets (null = the default pool).
class CandidateBoss:
	extends BossController
	var forced: Variant = null
	var defeats: int = 0

	func _pick_candidates(phase: int) -> PackedInt32Array:
		return super(phase) if forced == null else forced

	func _on_defeated() -> void:
		defeats += 1


## Test-only FSM whose dash invulnerability is set by the test.
class FakeActions:
	extends ActionStateMachine
	var invuln: bool = false

	func invulnerable() -> bool:
		return invuln


var _ctx: SimContext
var _arena: ArenaContext
var _player_px: Vector2 = FAR_PX
var _saved_state: int


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal contact never records a death
	_ctx = SimContext.new()
	_ctx.reseed(1234)
	_player_px = FAR_PX
	_arena = ArenaContext.new()
	_arena.contact_source = func() -> Vector2: return _player_px
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)
	SimClock.hitstop_frames = 0 # Story 3.8: a defeat requests 20 frames; never leak into the next suite


func _attack(id: StringName, tell: int, active: int, recovery: int, attack_script: Script = RecordingAttack) -> AttackDef:
	var a := AttackDef.new()
	a.id = id
	a.tell = tell
	a.active = active
	a.recovery = recovery
	a.tell_sfx = &"tell_test"
	a.attack_script = attack_script
	return a


func _phase(threshold: int, gap: int, pool: Array[AttackDef]) -> PhaseDef:
	var p := PhaseDef.new()
	p.hp_threshold = threshold
	p.weak_window = Vector2i(Register.Bit.ATTACK, Register.Bit.DASH) # Story 3.2: validate requires one
	p.gap_frames = gap
	p.attack_pool = pool
	return p


func _boss_def(phases: Array[PhaseDef], max_hp: int = 100) -> BossDef:
	var d := BossDef.new()
	d.boss_id = &"unit_boss"
	d.name_signature = "unitBoss"
	d.max_hp = max_hp
	d.phases = phases
	d.body_radius_tiles = 1.0
	return d


func _controller(def: BossDef, health: PlayerHealth = null, boss: BossController = null) -> BossController:
	var c: BossController = boss if boss != null else BossController.new()
	assert_true(c.setup(def, health, _arena), "setup accepts a valid def")
	c.reset_for_fight()
	return c


func _tick(c: BossController, times: int = 1) -> void:
	for i: int in times:
		c.tick(_ctx)


## A single-attack-per-phase pool cannot pass validate, so timing tests use two identical-timing
## attacks and read whichever was picked.
func _timing_def() -> BossDef:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 5, 7), _attack(&"b", 20, 5, 7)]
	return _boss_def([_phase(100, 10, pool)])


func _health() -> PlayerHealth:
	var h := PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	h.reset_for_fight()
	h.set_active(true)
	return h


# --- AC 2: state timings and hooks (D-S31-5) ---

func test_phase_is_boss_hazards_and_effects_follow() -> void:
	assert_eq(BossController.new().phase, SimSystem.SimPhase.BOSS_HAZARDS)
	assert_eq(PlayerEffects.new().phase, SimSystem.SimPhase.PLAYER_EFFECTS)
	assert_lt(SimSystem.SimPhase.BOSS_HAZARDS, SimSystem.SimPhase.PLAYER_EFFECTS)
	assert_lt(SimSystem.SimPhase.PLAYER_EFFECTS, SimSystem.SimPhase.COMBAT)


func test_states_last_exactly_their_frames() -> void:
	var c: BossController = _controller(_timing_def())
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(c.frames_left, 10)
	_tick(c, 9)
	assert_eq(c.state, BossController.BossState.GAP, "GAP lasts 10 ticks")
	_tick(c)
	assert_eq(c.state, BossController.BossState.TELL)
	_tick(c, 19)
	assert_eq(c.state, BossController.BossState.TELL, "TELL lasts 20 ticks")
	_tick(c)
	assert_eq(c.state, BossController.BossState.ACTIVE)
	_tick(c, 4)
	assert_eq(c.state, BossController.BossState.ACTIVE, "ACTIVE lasts 5 ticks")
	_tick(c)
	assert_eq(c.state, BossController.BossState.RECOVERY)
	_tick(c, 6)
	assert_eq(c.state, BossController.BossState.RECOVERY, "RECOVERY lasts 7 ticks")
	_tick(c)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(c.frames_left, 10, "back to the phase's gap")
	assert_null(c.current)


func test_hooks_run_at_their_entries() -> void:
	var c: BossController = _controller(_timing_def())
	_tick(c, 10) # TELL entry
	var attack := c.attack_for(c.current) as RecordingAttack
	assert_eq(attack.calls, PackedStringArray(["tell"]), "on_tell at TELL entry")
	_tick(c, 20) # ACTIVE entry: no on_active yet
	assert_eq(attack.calls, PackedStringArray(["tell"]))
	_tick(c, 5) # 5 ACTIVE ticks, then RECOVERY entry
	assert_eq(attack.calls, PackedStringArray(["tell", "active", "active", "active", "active", "active", "recovery"]))
	_tick(c, 7)
	assert_eq(attack.calls.size(), 7, "nothing during RECOVERY or on GAP entry")


func test_tell_emits_the_event_with_id_and_sfx() -> void:
	var c: BossController = _controller(TEST_BOSS)
	watch_signals(EventBus)
	_tick(c, 40)
	assert_signal_emit_count(EventBus, "boss_tell_started", 1)
	var params: Array = get_signal_parameters(EventBus, "boss_tell_started")
	assert_eq(params[0], c.current.id)
	assert_eq(params[1], &"tell_test")


func test_zero_recovery_still_calls_on_recovery_and_returns_to_gap() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 2, 0), _attack(&"b", 20, 2, 0)]
	var c: BossController = _controller(_boss_def([_phase(100, 3, pool)]))
	_tick(c, 3 + 20)
	var attack := c.attack_for(c.current) as RecordingAttack
	_tick(c, 2)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(attack.calls, PackedStringArray(["tell", "active", "active", "recovery"]))


# --- AC 2: pick rule (D-S31-6) ---

func test_no_attack_three_times_in_a_row_over_1000_seeded_picks() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 1, 0), _attack(&"b", 20, 1, 0)]
	var c: BossController = _controller(_boss_def([_phase(100, 1, pool)]))
	var picks := PackedInt32Array()
	for i: int in 1000:
		picks.append(c.pick_next(_ctx.rng))
	var counts: Array[int] = [0, 0]
	for i: int in picks.size():
		counts[picks[i]] += 1
		if i >= 2:
			assert_false(picks[i] == picks[i - 1] and picks[i] == picks[i - 2], "triple at %d" % i)
	assert_gt(counts[0], 300, "both attacks are drawn")
	assert_gt(counts[1], 300, "both attacks are drawn")


func test_picks_are_deterministic_for_a_seed() -> void:
	var a: BossController = _controller(TEST_BOSS)
	var b: BossController = _controller(TEST_BOSS)
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 99
	rng_b.seed = 99
	for i: int in 200:
		assert_eq(a.pick_next(rng_a), b.pick_next(rng_b))


func test_three_attack_pool_never_triples_and_uses_all() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 1, 0), _attack(&"b", 20, 1, 0), _attack(&"c", 20, 1, 0)]
	var c: BossController = _controller(_boss_def([_phase(100, 1, pool)]))
	var seen: Dictionary[int, bool] = {}
	var prev := PackedInt32Array([-1, -1])
	for i: int in 1000:
		var p: int = c.pick_next(_ctx.rng)
		assert_false(p == prev[0] and p == prev[1], "triple at %d" % i)
		prev = PackedInt32Array([p, prev[0]])
		seen[p] = true
	assert_eq(seen.size(), 3)


func test_history_resets_on_fight_start() -> void:
	var c: BossController = _controller(TEST_BOSS)
	c.pick_next(_ctx.rng)
	c.pick_next(_ctx.rng)
	assert_ne(c.last_pick, -1)
	c.reset_for_fight()
	assert_eq(c.last_pick, -1)
	assert_eq(c.second_last_pick, -1)


# --- Story 3.5 B1, B2: the candidate hook (D-S35-3) ---

func test_default_candidates_are_the_phase_pool_for_every_phase() -> void:
	var c: BossController = _controller(TEST_BOSS)
	var pools: Array = c.get(&"_pools")
	assert_eq(pools.size(), TEST_BOSS.phases.size())
	for i: int in pools.size():
		assert_eq(c._pick_candidates(i), pools[i], "phase %d" % i)


func test_a_single_candidate_is_picked_without_an_rng_draw() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 1, 0), _attack(&"b", 20, 1, 0)]
	var c := CandidateBoss.new()
	_controller(_boss_def([_phase(100, 1, pool)]), null, c)
	c.forced = PackedInt32Array([1])
	_ctx.rng.randi() # move off the seed so a draw would show
	var before: int = _ctx.rng.state
	for i: int in 5:
		assert_eq(c.pick_next(_ctx.rng), 1)
	assert_eq(_ctx.rng.state, before, "one candidate: no RNG draw")
	assert_eq([c.last_pick, c.second_last_pick], [1, 1])


func test_picks_come_only_from_the_candidates_without_triples() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 1, 0), _attack(&"b", 20, 1, 0), _attack(&"c", 20, 1, 0)]
	var c := CandidateBoss.new()
	_controller(_boss_def([_phase(100, 1, pool)]), null, c)
	c.forced = PackedInt32Array([0, 2])
	var prev := PackedInt32Array([-1, -1])
	var seen: Dictionary[int, bool] = {}
	for i: int in 1000:
		var p: int = c.pick_next(_ctx.rng)
		assert_true(p == 0 or p == 2, "candidate only")
		assert_false(p == prev[0] and p == prev[1], "triple at %d" % i)
		prev = PackedInt32Array([p, prev[0]])
		seen[p] = true
	assert_eq(seen.size(), 2)


func test_an_empty_candidate_list_keeps_the_fsm_in_gap() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 1, 0), _attack(&"b", 20, 1, 0)]
	var c := CandidateBoss.new()
	_controller(_boss_def([_phase(100, 3, pool)]), null, c)
	c.forced = PackedInt32Array()
	var before: int = _ctx.rng.state
	watch_signals(EventBus)
	_tick(c, 30)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(c.pick_next(_ctx.rng), -1)
	assert_eq(_ctx.rng.state, before)
	assert_signal_not_emitted(EventBus, "boss_tell_started")
	c.forced = null
	_tick(c, 3)
	assert_eq(c.state, BossController.BossState.TELL, "the pool is back")


func test_defeat_calls_the_defeated_hook_once() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 1, 0), _attack(&"b", 20, 1, 0)]
	var c := CandidateBoss.new()
	_controller(_boss_def([_phase(100, 3, pool)]), null, c)
	c.debug_kill()
	c.debug_kill()
	assert_eq(c.defeats, 1)


# --- AC 3: phases, roar, hook, jitter (D-S31-4, D-S31-8, D-S31-9) ---

func _three_phase_def() -> BossDef:
	var pool: Array[AttackDef] = [_attack(&"a", 20, 5, 5), _attack(&"b", 20, 5, 5)]
	return _boss_def([_phase(100, 10, pool), _phase(66, 8, pool), _phase(33, 6, pool)])


func test_phase_for_hp_thresholds() -> void:
	var phases: Array[PhaseDef] = _three_phase_def().phases
	assert_eq(BossController.phase_for_hp(100, 100, phases), 0)
	assert_eq(BossController.phase_for_hp(67, 100, phases), 0)
	assert_eq(BossController.phase_for_hp(66, 100, phases), 1)
	assert_eq(BossController.phase_for_hp(34, 100, phases), 1)
	assert_eq(BossController.phase_for_hp(33, 100, phases), 2)
	assert_eq(BossController.phase_for_hp(0, 100, phases), 2)
	# Integer math at a non-round max: 66% of 20 is 13.2, so 13 is phase 1 and 14 is not.
	assert_eq(BossController.phase_for_hp(14, 20, phases), 0)
	assert_eq(BossController.phase_for_hp(13, 20, phases), 1)


func test_phase_change_roars_60_ticks_with_no_attack_and_calls_the_hook() -> void:
	var boss := RampBoss.new()
	var c: BossController = _controller(_three_phase_def(), null, boss)
	_tick(c, 10 + 20 + 2) # mid-ACTIVE
	var attack := c.attack_for(c.current) as RecordingAttack
	var hooks_before: int = attack.calls.size()
	watch_signals(EventBus)
	c.take_hit(34)
	assert_eq(c.phase_index, 1)
	assert_eq(c.state, BossController.BossState.ROAR)
	assert_null(c.current, "the attack is dropped")
	assert_eq(boss.resets, 1, "_on_phase_reset called")
	assert_signal_emitted_with_parameters(EventBus, "boss_phase_changed", [1])
	assert_signal_emitted_with_parameters(EventBus, "boss_roar_started", [1])
	_tick(c, 59)
	assert_eq(c.state, BossController.BossState.ROAR, "ROAR lasts 60 ticks")
	assert_signal_emit_count(EventBus, "boss_tell_started", 0, "no attack starts in ROAR")
	assert_eq(attack.calls.size(), hooks_before, "no hook (not even on_recovery) after the cut")
	_tick(c)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(c.frames_left, 8, "the new phase's gap")


func test_phase_change_and_defeat_cancel_the_running_attack() -> void:
	var c: BossController = _controller(_three_phase_def())
	_tick(c, 10 + 20 + 2)
	var attack := c.attack_for(c.current) as RecordingAttack
	c.take_hit(34)
	assert_eq(attack.cancels, 1, "phase change calls on_cancel once")
	_tick(c, 60 + 8 + 12) # ROAR, gap, into the next attack's tell
	assert_not_null(c.current)
	var next := c.attack_for(c.current) as RecordingAttack
	var before: int = next.cancels
	c.debug_kill()
	assert_eq(next.cancels, before + 1, "defeat cancels too")


func test_debug_skip_phase_never_kills_and_reports_the_change() -> void:
	var c: BossController = _controller(_three_phase_def())
	assert_true(c.debug_skip_phase())
	assert_ne(c.state, BossController.BossState.DEFEATED)
	assert_true(c.hp >= 1)


func test_multi_phase_jump_in_one_hit_roars_once() -> void:
	var boss := RampBoss.new()
	var c: BossController = _controller(_three_phase_def(), null, boss)
	watch_signals(EventBus)
	c.take_hit(70)
	assert_eq(c.phase_index, 2, "jumps to the latest phase")
	assert_eq(boss.resets, 1)
	assert_signal_emit_count(EventBus, "boss_roar_started", 1)
	assert_signal_emit_count(EventBus, "boss_phase_changed", 1)
	assert_signal_emitted_with_parameters(EventBus, "boss_phase_changed", [2])


func test_a_hit_inside_the_same_phase_does_not_roar() -> void:
	var c: BossController = _controller(_three_phase_def())
	watch_signals(EventBus)
	c.take_hit(10)
	assert_eq(c.phase_index, 0)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_signal_emitted_with_parameters(EventBus, "boss_hp_changed", [90, 100])
	assert_signal_emit_count(EventBus, "boss_roar_started", 0)


func test_jitter_levels() -> void:
	assert_eq(BossController.jitter_for_hp(100, 100), 0)
	assert_eq(BossController.jitter_for_hp(67, 100), 0)
	assert_eq(BossController.jitter_for_hp(66, 100), 1)
	assert_eq(BossController.jitter_for_hp(34, 100), 1)
	assert_eq(BossController.jitter_for_hp(33, 100), 2)
	assert_eq(BossController.jitter_for_hp(0, 100), 2)
	var c: BossController = _controller(_three_phase_def())
	assert_eq(c.jitter_level(), 0)
	c.take_hit(34)
	assert_eq(c.jitter_level(), 1)
	c.take_hit(33)
	assert_eq(c.jitter_level(), 2)


func test_jitter_offset_is_deterministic_and_bounded() -> void:
	for frame: int in 100:
		for level: int in 3:
			var off: float = BossView.jitter_offset(level, frame)
			assert_lte(absf(off), float(level))
			assert_eq(off, BossView.jitter_offset(level, frame))
	assert_eq(BossView.jitter_offset(0, 7), 0.0)


# --- AC 3 / AC 7: defeat and debug wrappers (D-S31-19) ---

func test_defeat_emits_once_and_stops_the_boss() -> void:
	var c: BossController = _controller(_three_phase_def())
	watch_signals(EventBus)
	c.take_hit(500)
	assert_eq(c.hp, 0)
	assert_eq(c.state, BossController.BossState.DEFEATED)
	assert_false(c.active)
	assert_signal_emit_count(EventBus, "boss_roar_started", 0, "death does not roar")
	c.take_hit(5)
	c.debug_kill()
	_tick(c, 10)
	assert_signal_emit_count(EventBus, "boss_defeated", 1)
	assert_signal_emitted_with_parameters(EventBus, "boss_defeated", [&"unit_boss"])


func test_debug_skip_phase_lands_on_each_threshold() -> void:
	var c: BossController = _controller(_three_phase_def())
	assert_true(c.debug_skip_phase())
	assert_eq(c.phase_index, 1)
	assert_eq(c.hp, 66)
	assert_true(c.debug_skip_phase())
	assert_eq(c.phase_index, 2)
	assert_eq(c.hp, 33)
	assert_false(c.debug_skip_phase(), "no phase after the last")
	assert_eq(c.hp, 33)
	c.debug_kill()
	assert_eq(c.state, BossController.BossState.DEFEATED)


func test_test_boss_skip_phase_lands_on_hp_10() -> void:
	var c: BossController = _controller(TEST_BOSS)
	assert_true(c.debug_skip_phase())
	assert_eq(c.hp, 10)
	assert_eq(c.phase_index, 1)


# --- AC 8: fight-start reset ---

func test_reset_for_fight_restores_everything_and_keeps_the_cache() -> void:
	var c: BossController = _controller(TEST_BOSS, _health())
	var pulse_attack: BossAttack = c.attack_for(PULSE)
	assert_not_null(pulse_attack)
	_tick(c, 45)
	c.take_hit(15)
	c.debug_kill()
	c.reset_for_fight()
	assert_eq(c.hp, 20)
	assert_eq(c.phase_index, 0)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(c.frames_left, 40)
	assert_null(c.current)
	assert_true(c.active)
	assert_same(c.attack_for(PULSE), pulse_attack, "cached attack scripts persist")
	assert_eq((pulse_attack as PulseScript).tells, 0, "and are reset")


func test_setup_rejects_an_invalid_def() -> void:
	var pool: Array[AttackDef] = [_attack(&"a", 19, 1, 0), _attack(&"b", 20, 1, 0)]
	var c := BossController.new()
	assert_false(c.setup(_boss_def([_phase(100, 1, pool)]), null, _arena))
	assert_push_error("invalid BossDef")
	c.reset_for_fight()
	assert_false(c.active, "an invalid boss stays inactive")
	assert_false(c.setup(null, null, _arena))
	assert_push_error("no BossDef")


func test_inactive_boss_does_not_tick() -> void:
	var c: BossController = _controller(_timing_def())
	c.set_active(false)
	_tick(c, 50)
	assert_eq(c.state, BossController.BossState.GAP)
	assert_eq(c.frames_left, 10)


# --- AC 1: validate() rules (D-S31-4, D-S31-7) ---

func test_test_boss_data_is_valid() -> void:
	assert_eq(TEST_BOSS.validate(), PackedStringArray())
	assert_eq(PULSE.validate(), PackedStringArray())
	assert_eq(SWEEP.validate(), PackedStringArray())
	assert_eq(TEST_BOSS.name_signature, "testBoss")
	assert_eq(TEST_BOSS.max_hp, 20)
	assert_eq(TEST_BOSS.phases.size(), 2)
	assert_eq(TEST_BOSS.phases[0].gap_frames, 40)
	assert_eq(TEST_BOSS.phases[1].hp_threshold, 50)
	assert_eq(PULSE.tell, 20)
	assert_eq(SWEEP.tell, 30)


func _has_message(messages: PackedStringArray, needle: String) -> bool:
	for m: String in messages:
		if m.contains(needle):
			return true
	return false


func test_attack_def_rules() -> void:
	assert_eq(_attack(&"ok", 20, 1, 0).validate().size(), 0, "tell 20 is the minimum")
	assert_true(_has_message(_attack(&"t", 19, 1, 0).validate(), "tell"), "tell 19")
	assert_true(_has_message(_attack(&"t", 20, 0, 0).validate(), "active"))
	assert_true(_has_message(_attack(&"t", 20, 1, -1).validate(), "recovery"))
	assert_true(_has_message(_attack(&"", 20, 1, 0).validate(), "id"))
	var no_sfx: AttackDef = _attack(&"t", 20, 1, 0)
	no_sfx.tell_sfx = &""
	assert_true(_has_message(no_sfx.validate(), "tell_sfx"), "empty tell_sfx")
	var wrong_script: AttackDef = _attack(&"t", 20, 1, 0, GDScript.new())
	assert_true(_has_message(wrong_script.validate(), "BossAttack"), "script not a BossAttack")
	var no_script: AttackDef = _attack(&"t", 20, 1, 0)
	no_script.attack_script = null
	assert_true(_has_message(no_script.validate(), "BossAttack"))
	assert_true(AttackDef.is_boss_attack_script(PulseScript))
	assert_true(AttackDef.is_boss_attack_script(SweepScript))
	assert_true(AttackDef.is_boss_attack_script(BossAttack))
	assert_false(AttackDef.is_boss_attack_script(BossController))


func test_phase_def_rules() -> void:
	var a: AttackDef = _attack(&"a", 20, 1, 0)
	var b: AttackDef = _attack(&"b", 20, 1, 0)
	assert_eq(_phase(100, 1, [a, b]).validate().size(), 0)
	assert_eq(_phase(100, 1, [a]).validate().size(), 0, "Story 3.4 (D-S34-4): a pool of one is valid")
	assert_eq(_phase(100, 1, []).validate().size(), 0, "Story 3.3 (D-S33-9): an empty pool is valid")
	assert_true(_has_message(_phase(100, 1, [a, a]).validate(), "twice"), "same attack twice")
	assert_true(_has_message(_phase(100, 0, [a, b]).validate(), "gap_frames"))
	assert_true(_has_message(_phase(0, 1, [a, b]).validate(), "hp_threshold"))
	assert_true(_has_message(_phase(101, 1, [a, b]).validate(), "hp_threshold"))
	var bad_attack: AttackDef = _attack(&"c", 10, 1, 0)
	assert_true(_has_message(_phase(100, 1, [a, bad_attack]).validate(), "tell"), "attack rules surface")


func test_boss_def_rules() -> void:
	var a: AttackDef = _attack(&"a", 20, 1, 0)
	var b: AttackDef = _attack(&"b", 20, 1, 0)
	assert_eq(_boss_def([_phase(100, 1, [a, b]), _phase(50, 1, [a, b])]).validate().size(), 0, "shared attacks across phases are fine")
	assert_true(_has_message(_boss_def([]).validate(), "at least one phase"))
	assert_true(_has_message(_boss_def([_phase(90, 1, [a, b])]).validate(), "phases[0] hp_threshold must be 100"))
	assert_true(_has_message(_boss_def([_phase(100, 1, [a, b]), _phase(50, 1, [a, b]), _phase(60, 1, [a, b])]).validate(), "lower than the previous"), "unordered thresholds")
	assert_true(_has_message(_boss_def([_phase(100, 1, [a, b]), _phase(100, 1, [a, b])]).validate(), "lower than the previous"), "equal thresholds")
	var a_twin: AttackDef = _attack(&"a", 20, 1, 0)
	assert_true(_has_message(_boss_def([_phase(100, 1, [a, b]), _phase(50, 1, [a_twin, b])]).validate(), "two different attacks"), "duplicate ids")
	var bad := _boss_def([_phase(100, 1, [a, b])], 0)
	bad.boss_id = &""
	bad.name_signature = " "
	bad.body_radius_tiles = 0.0
	var messages: PackedStringArray = bad.validate()
	for needle: String in ["max_hp", "boss_id", "name_signature", "body_radius_tiles"]:
		assert_true(_has_message(messages, needle), needle)
	assert_true(_has_message(_boss_def([_phase(100, 1, [a, a])]).validate(), "phases[0]: phase attack_pool lists a twice"), "phase rules surface")


# --- AC 5: target injection and play-area bounds (D-S31-10) ---

func test_attacks_aim_at_the_injected_target() -> void:
	var fixed := Vector2(123, 45)
	_arena.target_source = func() -> Vector2: return fixed
	_player_px = Vector2(400, 200)
	var c: BossController = _controller(_timing_def())
	_tick(c, 10)
	var attack := c.attack_for(c.current) as RecordingAttack
	assert_eq(attack.aim, fixed, "aims at the injected target, not the player")
	assert_eq(_arena.target_position(), fixed)
	assert_eq(_arena.body_contact_position(), Vector2(400, 200))


func test_test_boss_attacks_aim_at_the_target() -> void:
	var fixed := Vector2(200, 100)
	_arena.target_source = func() -> Vector2: return fixed
	var c: BossController = _controller(TEST_BOSS)
	var pulse := c.attack_for(PULSE) as PulseScript
	var sweep := c.attack_for(SWEEP) as SweepScript
	pulse.on_tell(_arena)
	sweep.on_tell(_arena)
	assert_eq(pulse.aim_px, fixed)
	assert_eq(sweep.row_y, fixed.y)


func test_arena_default_target_is_the_player() -> void:
	var arena := Arena.new()
	arena.player.position_px = Vector2(77, 88)
	assert_eq(arena.arena_context.target_position(), Vector2(77, 88))
	assert_eq(arena.arena_context.body_contact_position(), Vector2(77, 88))
	arena.free()


func test_inside_play_area_helper() -> void:
	var area: Rect2 = Arena.play_area()
	assert_true(ArenaContext.inside_play_area(area.position))
	assert_true(ArenaContext.inside_play_area(area.end))
	assert_true(ArenaContext.inside_play_area(area.get_center()))
	assert_false(ArenaContext.inside_play_area(area.position - Vector2(1, 0)))
	assert_false(ArenaContext.inside_play_area(area.end + Vector2(0, 1)))
	assert_false(ArenaContext.inside_play_area(Vector2(-50, 100)))


func test_every_test_boss_position_is_inside_the_play_area() -> void:
	var c: BossController = _controller(TEST_BOSS)
	assert_true(ArenaContext.inside_play_area(Arena.TEST_BOSS_PX), "boss body")
	var area: Rect2 = Arena.play_area()
	var targets: Array[Vector2] = [
		area.position, area.end, area.get_center(), Vector2(-100, -100), Vector2(9999, 9999),
		Vector2(area.end.x + 30, area.position.y - 30), Arena.SPAWN_PX,
	]
	for target: Vector2 in targets:
		_arena.target_source = func() -> Vector2: return target
		for attack_def: AttackDef in [PULSE, SWEEP]:
			var positions: PackedVector2Array = c.attack_for(attack_def).declared_positions(_arena)
			assert_gt(positions.size(), 0, "%s declares positions" % attack_def.id)
			for p: Vector2 in positions:
				assert_true(ArenaContext.inside_play_area(p), "%s at %s for target %s" % [attack_def.id, p, target])


# --- AC 6: body contact (D-S31-12) ---

func test_contact_costs_one_hp_through_the_hit_pipeline() -> void:
	var health: PlayerHealth = _health()
	var c: BossController = _controller(TEST_BOSS, health)
	c.body_center_px = Vector2(200, 100)
	_player_px = Vector2(200 + 15, 100) # inside the 16-px (1 tile) body circle
	watch_signals(EventBus)
	_tick(c)
	assert_eq(health.hp, 5, "a request, applied on the PlayerHealth tick")
	health.tick(_ctx)
	assert_eq(health.hp, 4)
	assert_gt(health.invuln_left, 0)
	assert_signal_emitted_with_parameters(EventBus, "player_damaged", [4])
	assert_eq(SimClock.get(&"_pending_hitstop"), HitFeedback.PLAYER_HITSTOP, "hit-stop requested")


func test_contact_during_invulnerability_does_nothing() -> void:
	var health: PlayerHealth = _health()
	var c: BossController = _controller(TEST_BOSS, health)
	c.body_center_px = Vector2(200, 100)
	_player_px = Vector2(200, 100)
	for i: int in 30: # stay in contact through the post-hit invulnerability
		_tick(c)
		health.tick(_ctx)
	assert_eq(health.hp, 4, "one hit, then invulnerable")
	health.reset_for_fight()
	(health.get(&"_actions") as FakeActions).invuln = true # dash invulnerability
	for i: int in 10:
		_tick(c)
		health.tick(_ctx)
	assert_eq(health.hp, 5, "no damage while dashing")


func test_no_contact_outside_the_body_circle_or_after_defeat() -> void:
	var health: PlayerHealth = _health()
	var c: BossController = _controller(TEST_BOSS, health)
	c.body_center_px = Vector2(200, 100)
	_player_px = Vector2(200 + 17, 100)
	_tick(c)
	assert_false(health.get(&"_pending"), "17 px from the centre is outside a 1-tile circle")
	_player_px = Vector2(200, 100)
	c.debug_kill()
	_tick(c)
	assert_false(health.get(&"_pending"), "a defeated boss has no contact")


func test_contact_is_live_during_roar() -> void:
	var health: PlayerHealth = _health()
	var c: BossController = _controller(TEST_BOSS, health)
	c.body_center_px = Vector2(200, 100)
	c.debug_skip_phase()
	assert_eq(c.state, BossController.BossState.ROAR)
	_player_px = Vector2(200, 100)
	_tick(c)
	assert_true(health.get(&"_pending"))


# --- D-S31-11: PlayerEffects slot ---

func test_player_effects_drains_its_queue() -> void:
	var fx := PlayerEffects.new()
	assert_eq(fx.pending(), 0)
	fx.push(RefCounted.new())
	fx.push(RefCounted.new())
	assert_eq(fx.pending(), 2)
	fx.tick(_ctx)
	assert_eq(fx.pending(), 0)
	fx.push(RefCounted.new())
	fx.clear()
	assert_eq(fx.pending(), 0)


# --- Presentation helpers (AC 7, E3) ---

func test_boss_header_text() -> void:
	assert_eq(Hud.boss_header("testBoss", 20), "void testBoss() // hp 20")
	assert_eq(Hud.boss_header("loop", 0), "void loop() // hp 0")


func test_roar_flash_alternates_only_while_roaring() -> void:
	assert_false(BossView.roar_flash_on(false, 0))
	assert_true(BossView.roar_flash_on(true, 0))
	assert_false(BossView.roar_flash_on(true, BossView.FLASH_BLOCK))
	assert_true(BossView.roar_flash_on(true, BossView.FLASH_BLOCK * 2))


# --- Story 3.2: take_hit guard, Patched lifetime, weak window per phase (AC 4, 7, 8) ---

func test_take_hit_before_reset_does_nothing() -> void:
	var c := BossController.new()
	assert_true(c.setup(_timing_def(), null, _arena))
	watch_signals(EventBus)
	c.take_hit(5)
	assert_eq(c.hp, 0, "never reset: HP untouched")
	assert_signal_emit_count(EventBus, "boss_hp_changed", 0)
	assert_signal_emit_count(EventBus, "boss_defeated", 0)


func test_take_hit_while_inactive_does_nothing() -> void:
	var c: BossController = _controller(_timing_def())
	c.set_active(false)
	watch_signals(EventBus)
	c.take_hit(5)
	assert_eq(c.hp, 100)
	assert_signal_emit_count(EventBus, "boss_hp_changed", 0)


func test_take_hit_after_defeat_does_nothing() -> void:
	var c: BossController = _controller(_timing_def())
	c.take_hit(100)
	watch_signals(EventBus)
	c.take_hit(5)
	assert_eq(c.hp, 0)
	assert_signal_emit_count(EventBus, "boss_hp_changed", 0)
	assert_signal_emit_count(EventBus, "boss_defeated", 0)


func test_take_hit_with_zero_damage_does_nothing() -> void:
	var c: BossController = _controller(_timing_def())
	watch_signals(EventBus)
	c.take_hit(0)
	assert_signal_emit_count(EventBus, "boss_hp_changed", 0)


func test_patched_survives_a_phase_change_and_counts_down_through_roar() -> void:
	var c: BossController = _controller(_three_phase_def())
	c.weak_window.apply_patched()
	c.take_hit(34)
	assert_eq(c.state, BossController.BossState.ROAR)
	assert_true(c.weak_window.is_patched(), "the bug stays patched (D-S32-14)")
	assert_false(c.is_hittable(), "no damage window in ROAR (D-S32-9)")
	_tick(c, 60)
	assert_eq(c.weak_window.frames_left, 120, "Patched counts every live tick, ROAR included")


func test_patched_is_cleared_on_reset_and_on_defeat() -> void:
	var c: BossController = _controller(_three_phase_def())
	c.weak_window.apply_patched()
	c.mark_hit(7)
	c.reset_for_fight()
	assert_false(c.weak_window.is_patched())
	assert_false(c.was_hit_by(7), "hit serial reset with the fight")
	c.weak_window.apply_patched()
	c.debug_kill()
	assert_false(c.weak_window.is_patched())


func test_patched_does_not_count_while_inactive() -> void:
	var c: BossController = _controller(_timing_def())
	c.weak_window.apply_patched()
	c.set_active(false)
	_tick(c, 30)
	assert_eq(c.weak_window.frames_left, 180)
	c.set_active(true)
	_tick(c, 30)
	assert_eq(c.weak_window.frames_left, 150)


func test_current_weak_window_per_phase() -> void:
	var c: BossController = _controller(TEST_BOSS)
	assert_eq(c.current_weak_window(), Vector2i(Register.Bit.ATTACK, Register.Bit.DASH))
	assert_true(c.debug_skip_phase())
	assert_eq(c.current_weak_window(), Vector2i(Register.Bit.DASH, Register.Bit.ATTACK))
	assert_eq(BossController.new().current_weak_window(), Vector2i.ZERO, "no def")


func test_is_hittable_by_state() -> void:
	var c: BossController = _controller(_timing_def())
	for s: BossController.BossState in [BossController.BossState.GAP, BossController.BossState.TELL, BossController.BossState.ACTIVE, BossController.BossState.RECOVERY]:
		c.state = s
		assert_true(c.is_hittable(), BossController.BossState.keys()[s])
	for s: BossController.BossState in [BossController.BossState.ROAR, BossController.BossState.DEFEATED]:
		c.state = s
		assert_false(c.is_hittable(), BossController.BossState.keys()[s])
	c.state = BossController.BossState.GAP
	c.set_active(false)
	assert_false(c.is_hittable(), "inactive")


func test_one_hit_per_action_serial() -> void:
	var c: BossController = _controller(_timing_def())
	assert_false(c.was_hit_by(3))
	c.mark_hit(3)
	assert_true(c.was_hit_by(3))
	assert_false(c.was_hit_by(4))


func test_patched_view_helpers() -> void:
	assert_eq(BossView.bar_fraction(180), 1.0)
	assert_eq(BossView.bar_fraction(90), 0.5)
	assert_eq(BossView.bar_fraction(0), 0.0)
	assert_eq(BossView.bar_fraction(500), 1.0, "clamped")
	assert_eq(BossView.damage_number_scale(DamageState.Kind.PATCHED), 2)
	assert_eq(BossView.damage_number_scale(DamageState.Kind.UNPATCHED), 1)


func test_boss_view_shows_the_last_boss_hit_number_only() -> void:
	var view: BossView = add_child_autofree(BossView.new())
	EventBus.hit_landed.emit(&"practice_target", 10, DamageState.Kind.BASE, false, Vector2.ZERO)
	assert_eq(view.damage_number(), "", "practice hits are not drawn on the boss")
	EventBus.hit_landed.emit(&"boss", 30, DamageState.Kind.PATCHED, true, Vector2.ZERO)
	assert_eq(view.damage_number(), "30")
	for i: int in BossView.DAMAGE_NUMBER_FRAMES:
		view._process(0.0)
	assert_eq(view.damage_number(), "", "gone after its presentation frames")


func test_boss_view_number_clears_on_fight_restart() -> void:
	var view := BossView.new()
	add_child_autofree(view)
	EventBus.hit_landed.emit(&"boss", 7, 0, false, Vector2.ZERO)
	assert_eq(view.damage_number(), "7")
	EventBus.boss_hp_changed.emit(100, 100)
	assert_eq(view.damage_number(), "")


# --- Story 3.8 (G1, AC 1, 7, 8): the defeat sequence in the simulation ---

func test_defeat_requests_20_frames_of_hitstop_once() -> void:
	var c: BossController = _controller(_timing_def())
	SimClock.set(&"_pending_hitstop", 0)
	watch_signals(EventBus)
	c.take_hit(100)
	assert_eq(SimClock.get(&"_pending_hitstop"), BossController.DEFEAT_HITSTOP_FRAMES)
	assert_eq(BossController.DEFEAT_HITSTOP_FRAMES, 20)
	SimClock.set(&"_pending_hitstop", 0)
	c.take_hit(5)
	c.debug_kill()
	assert_eq(SimClock.get(&"_pending_hitstop"), 0, "no second hit-stop after the defeat")
	assert_signal_emit_count(EventBus, "boss_defeated", 1)


func test_defeat_counter_reaches_60_and_finished_flips_exactly_then() -> void:
	var c: BossController = _controller(_timing_def())
	assert_false(c.defeat_finished(), "a live boss is not finished")
	c.take_hit(100)
	assert_eq(c.defeat_frames_elapsed, 0)
	assert_false(c.active, "inactive, yet the counter runs")
	for i: int in BossController.DEFEAT_FRAMES - 1:
		_tick(c)
		assert_false(c.defeat_finished(), "tick %d" % (i + 1))
	assert_eq(c.defeat_frames_elapsed, BossController.DEFEAT_FRAMES - 1)
	_tick(c)
	assert_true(c.defeat_finished(), "finished on tick 60")
	_tick(c, 30)
	assert_eq(c.defeat_frames_elapsed, BossController.DEFEAT_FRAMES, "clamped")
	assert_eq(c.state, BossController.BossState.DEFEATED, "no transition out of DEFEATED")
	assert_false(c.is_hittable())


func test_a_hit_after_defeat_changes_nothing_and_reset_clears_the_counter() -> void:
	var c: BossController = _controller(_timing_def())
	c.take_hit(100)
	_tick(c, 10)
	watch_signals(EventBus)
	c.take_hit(40)
	assert_eq(c.hp, 0)
	assert_eq(c.defeat_frames_elapsed, 10, "a late hit does not restart the animation")
	assert_signal_emit_count(EventBus, "boss_defeated", 0)
	assert_signal_emit_count(EventBus, "boss_hp_changed", 0)
	c.reset_for_fight()
	assert_eq(c.defeat_frames_elapsed, 0)
	assert_false(c.defeat_finished())
	assert_eq(c.state, BossController.BossState.GAP)
