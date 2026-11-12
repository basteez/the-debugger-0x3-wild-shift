extends GutTest
## Story 6.5 AC 1-15: SIGSEGV on the real Segfault def. Phases 2-3 only, 60 / 1 / 90 (150 without
## Breakpoint) timings, one PlayerEffects rotation by +2 applied in the same tick, the fired latch,
## cut / defeat / retry leaving no rotation, the exclusive refusal, the warning tell read by the HUD,
## 10 seeded runs of phases 2-3 (no overlap, full recovery, one tell each) and replay determinism.
## SigBody narrows the candidates to SIGSEGV (cache index 2) for the focused cases.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const SIG: AttackDef = preload("res://data/bosses/segfault/attack_sigsegv.tres")
const S := BossController.BossState
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
## Phase 2 starts at 660 HP (66%), phase 3 at 330 (33%).
const TO_PHASE_2 := 340
const TO_PHASE_3 := 340

var _ctx: SimContext
var _arena: ArenaContext
var _reg: Register
var _link: LinkState
var _health: PlayerHealth
var _saved_state: int


class SigBody:
	extends SegfaultBody

	var only := PackedInt32Array([2])

	func _pick_candidates(_phase: int) -> PackedInt32Array:
		return only


class FakeActions:
	extends ActionStateMachine

	func invulnerable() -> bool:
		return false


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE
	_ctx = SimContext.new()
	_ctx.reseed(6500)
	_arena = ArenaContext.new()
	_arena.target_source = func() -> Vector2: return Vector2(256, 200)
	_arena.contact_source = func() -> Vector2: return Vector2(-1000, -1000)
	_reg = Register.new()
	_reg.set_fight_start(PackedInt32Array([A, D, L, N]))
	_link = LinkState.new()
	_arena.player_effects.bind(_reg, _link)
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


func _health_new() -> PlayerHealth:
	var h := PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	h.reset_for_fight()
	h.set_active(true)
	return h


## A body set up on the real def, reset, taken to `phase` (0-based) by damage.
func _setup(b: BossController, phase: int = 1, breakpoint_on: bool = true) -> BossController:
	_health = _health_new()
	b.breakpoint_on = breakpoint_on
	assert_true(b.setup(SF_DEF, _health, _arena))
	b.reset_for_fight()
	if phase >= 1:
		b.take_hit(TO_PHASE_2)
	if phase >= 2:
		b.take_hit(TO_PHASE_3)
	assert_eq(b.phase_index, phase)
	return b


func _sig_body(phase: int = 1, breakpoint_on: bool = true) -> SigBody:
	var b := SigBody.new()
	_setup(b, phase, breakpoint_on)
	assert_eq(b.attack_for(SIG), b._attacks[2], "SIGSEGV is cache index 2")
	return b


## One sim tick in phase order: BOSS_HAZARDS, PLAYER_EFFECTS, COMBAT.
func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)
		_arena.player_effects.tick(_ctx)
		_health.tick(_ctx)


func _run_until(b: BossController, state: S, limit: int = 1000) -> bool:
	for i: int in limit:
		if b.state == state:
			return true
		_tick(b)
	return b.state == state


func _sig(b: BossController) -> BossAttack:
	return b.attack_for(SIG)


# --- AC 1: pools ---

func test_sigsegv_is_only_in_the_phase_2_and_3_pools() -> void:
	var b := SegfaultBody.new()
	assert_true(b.setup(SF_DEF, null, null))
	var sig: int = b._attacks.find(b.attack_for(SIG))
	assert_eq(sig, 2)
	assert_false(b._pick_candidates(0).has(sig), "phase 1")
	assert_true(b._pick_candidates(1).has(sig), "phase 2")
	assert_true(b._pick_candidates(2).has(sig), "phase 3")


func test_the_real_fsm_never_picks_sigsegv_in_phase_1() -> void:
	var b: BossController = _setup(SegfaultBody.new(), 0)
	for i: int in 6000:
		var was: S = b.state
		_tick(b)
		if b.state == S.TELL and was != S.TELL:
			assert_ne(b.current.id, &"sigsegv", "phase 1 pick")
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "no rotation in phase 1")


# --- AC 3, 5, 9: timings, the rotation, the warning ---

func test_tell_60_active_1_recovery_90_and_one_rotation() -> void:
	watch_signals(EventBus)
	var b := _sig_body()
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, SIG)
	assert_eq(b.frames_left, 60)
	var sig: BossAttack = _sig(b)
	for i: int in 60:
		assert_true(sig.call(&"warning_tell"), "warning for the whole tell (frame %d)" % i)
		assert_true(Hud.warning_tell_on(b))
		assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "no change during the tell")
		assert_eq(b.state, S.TELL)
		_tick(b)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(b.frames_left, 1)
	assert_false(sig.call(&"warning_tell"), "the tell is over")
	_tick(b) # the single ACTIVE frame: on_active pushes, PLAYER_EFFECTS applies it this tick
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D]), "rotated by +2 in the same tick")
	assert_eq(_arena.player_effects.pending(), 0)
	assert_signal_emit_count(EventBus, "register_shifted", 1)
	assert_signal_emitted_with_parameters(EventBus, "register_shifted",
		[Register.RIGHT, Vector2i(L, N), PackedInt32Array([L, N, A, D]), &"sigsegv"])
	assert_eq(b.state, S.RECOVERY)
	assert_eq(b.frames_left, 90)
	_tick(b, 89)
	assert_eq(b.state, S.RECOVERY, "recovery is never shortened")
	_tick(b)
	assert_eq(b.state, S.GAP)
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D]), "one rotation per attack")
	assert_false(Hud.warning_tell_on(b))


func test_recovery_is_150_with_breakpoint_off() -> void:
	var b := _sig_body(1, false)
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(b.current, SIG)
	assert_eq(b.frames_left, 150)


func test_the_rotation_closes_the_link() -> void:
	var b := _sig_body()
	assert_true(_run_until(b, S.ACTIVE))
	_link.open(Vector2i(A, D), _reg.shift_serial)
	_link.hold(&"action_2", 1, 0)
	_tick(b)
	assert_false(_link.is_open(), "NP-1: the rotation closes the link")
	assert_false(_link.held, "and discards a held K")


# --- AC 7: the fired latch ---

func test_a_second_on_active_queues_nothing() -> void:
	var b := _sig_body()
	assert_true(_run_until(b, S.ACTIVE))
	var sig: BossAttack = _sig(b)
	sig.on_active(_arena)
	sig.on_active(_arena)
	assert_eq(_arena.player_effects.pending(), 1, "one rotation per attack")
	sig.on_recovery(_arena)
	sig.on_active(_arena)
	assert_eq(_arena.player_effects.pending(), 1, "the latch holds through RECOVERY")
	sig.reset()
	assert_false(sig.get(&"fired"), "reset() clears the latch")
	sig.on_active(_arena)
	sig.on_cancel(_arena)
	assert_false(sig.get(&"fired"), "on_cancel clears the latch")


# --- AC 11, 12: cut, defeat, retry ---

func test_a_phase_change_during_the_tell_rotates_nothing() -> void:
	var b := _sig_body(1)
	assert_true(_run_until(b, S.TELL))
	_tick(b, 30)
	b.take_hit(TO_PHASE_3)
	assert_eq(b.state, S.ROAR)
	assert_false(_sig(b).call(&"warning_tell"), "the warning ends with the cut")
	assert_false(Hud.warning_tell_on(b))
	_tick(b, 60)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "no rotation")
	assert_eq(_arena.player_effects.pending(), 0)


func test_a_defeat_during_the_tell_rotates_nothing() -> void:
	var b := _sig_body(2)
	assert_true(_run_until(b, S.TELL))
	b.take_hit(b.hp)
	assert_eq(b.state, S.DEFEATED)
	_tick(b, 70)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]))
	assert_eq(_arena.player_effects.pending(), 0)
	assert_false(_sig(b).get(&"fired"))


func test_a_defeat_during_recovery_keeps_the_one_rotation() -> void:
	var b := _sig_body(2)
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D]))
	b.take_hit(b.hp)
	_tick(b, 70)
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D]), "D-S65-11: nothing lost or repeated")
	assert_eq(_arena.player_effects.pending(), 0)


func test_retry_clears_a_queued_rotation() -> void:
	var b := _sig_body()
	assert_true(_run_until(b, S.ACTIVE))
	b.tick(_ctx) # BOSS_HAZARDS only: the rotation is queued, not applied
	assert_eq(_arena.player_effects.pending(), 1)
	b.reset_for_fight()
	assert_eq(_arena.player_effects.pending(), 0, "reset_for_fight clears the queue")
	assert_false(_sig(b).get(&"fired"))
	_arena.player_effects.tick(_ctx)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "no effect carries into the next fight")


# --- AC 10: exclusive ---

func test_an_exclusive_pick_is_refused_while_another_attack_is_current() -> void:
	var b := _sig_body()
	assert_true(b.can_start(2), "nothing current: SIGSEGV may start")
	assert_true(b.can_start(0))
	b._current_index = 0 # defensive case only: the serial FSM never gets here
	assert_false(b.can_start(2), "exclusive refused beside another attack")
	assert_true(b.can_start(1), "a non-exclusive pick keeps the serial rule")
	assert_false(b.can_start(-1))
	assert_false(b.can_start(99))
	b._current_index = -1


# --- AC 8: isolation ---

func test_the_attack_file_passes_isolation() -> void:
	var iso: GDScript = load("res://tests/unit/test_attack_isolation.gd")
	var path := "res://src/bosses/segfault/attacks/sigsegv.gd"
	assert_true(iso.attack_files().has(path))
	assert_eq(iso.violations(iso.code_of(path)), PackedStringArray())
	var code: String = iso.code_of(path)
	for word: String in ["LinkState", "PlayerHealth"]:
		assert_false(code.contains(word), word)
	assert_eq(_sig(_sig_body()).declared_positions(_arena), PackedVector2Array(), "no ground hazard")
	assert_false(_sig(_sig_body()).hazard_hit(Vector2(256, 200)))


# --- AC 14, 15: 10 seeded runs of phases 2-3, determinism ---

## One run: phase 2 for `frames`, then (entered from GAP) phase 3 for `frames`. Returns the pick
## log and the ring after every rotation; asserts the fairness rules for every SIGSEGV.
func _seeded_run(run_seed: int, frames: int, breakpoint_on: bool) -> Dictionary:
	_ctx = SimContext.new()
	_ctx.reseed(run_seed)
	_reg.set_fight_start(PackedInt32Array([A, D, L, N]))
	var b: BossController = _setup(SegfaultBody.new(), 1, breakpoint_on)
	var tiles: CorruptedTiles = b.get(&"tiles")
	var picks: Array = []
	var rings: Array = []
	var sigs: int = 0
	for half: int in 2:
		if half == 1:
			assert_true(_run_until(b, S.GAP))
			b.take_hit(TO_PHASE_3)
			assert_eq(b.phase_index, 2)
		var i: int = 0
		while i < frames:
			var was: S = b.state
			_tick(b)
			i += 1
			if b.state == S.TELL and was != S.TELL:
				picks.append(b.current.id)
				if b.current == SIG:
					sigs += 1
					# Exactly one 60-frame TELL, nothing else live, one rotation, full recovery.
					var tell: int = 0
					while b.state == S.TELL:
						assert_true(tiles.is_empty(), "no tile hazard beside the SIGSEGV tell")
						_tick(b)
						tell += 1
					assert_eq(tell, 60, "run_seed %d: one 60-frame tell" % run_seed)
					assert_eq([b.state, b.current], [S.ACTIVE, SIG], "run_seed %d: ACTIVE follows the tell" % run_seed)
					var before: PackedInt32Array = _reg.ring.duplicate()
					assert_true(tiles.is_empty(), "no other hazard in ACTIVE")
					_tick(b)
					assert_eq(_reg.ring, Register.rotated(Register.rotated(before, Register.RIGHT), Register.RIGHT))
					rings.append(_reg.ring.duplicate())
					assert_eq(b.state, S.RECOVERY)
					var rec: int = 0
					while b.state == S.RECOVERY:
						assert_eq(b.current, SIG, "no new attack before the recovery ends")
						_tick(b)
						rec += 1
					assert_eq(rec, 90 if breakpoint_on else 150, "run_seed %d: full recovery" % run_seed)
					i += tell + 1 + rec
	return {"picks": picks, "rings": rings, "sigs": sigs}


func test_ten_seeded_runs_of_phases_2_and_3_are_fair() -> void:
	var total: int = 0
	for run_seed: int in range(1, 11):
		var run: Dictionary = _seeded_run(run_seed, 3000, run_seed % 2 == 0)
		total += run["sigs"]
	assert_gt(total, 10, "SIGSEGV is drawn across the runs")


func test_the_same_seed_replays_the_same_picks_and_rotations() -> void:
	var first: Dictionary = _seeded_run(65, 3000, true)
	var second: Dictionary = _seeded_run(65, 3000, true)
	assert_gt(first["sigs"], 0)
	assert_eq(first["picks"], second["picks"])
	assert_eq(first["rings"], second["rings"])
