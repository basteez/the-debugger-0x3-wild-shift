extends GutTest
## Story 6.6 AC 1-19: Reserved Write on the real Segfault def. Phase 3 only, 45 / 600 / 30 timings,
## one PlayerEffects InsertTemporaryBit(GARBAGE, 600) applied in the same tick, the garbage bit
## present exactly 600 ticks, the fired latch, cut / defeat / retry leaving no `?`, the reserved
## tell read by the HUD, the flag-off pool, 10 seeded runs of phase 3 and replay determinism.
## RwBody narrows the candidates to Reserved Write (cache index 4) for the focused cases.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const RW: AttackDef = preload("res://data/bosses/segfault/attack_reserved_write.tres")
const SIG: AttackDef = preload("res://data/bosses/segfault/attack_sigsegv.tres")
const S := BossController.BossState
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const G := Register.Bit.GARBAGE
## Phase 2 starts at 660 HP (66%), phase 3 at 330 (33%).
const TO_PHASE_2 := 340
const TO_PHASE_3 := 340
const START := [A, D, L, N]

var _ctx: SimContext
var _arena: ArenaContext
var _reg: Register
var _link: LinkState
var _health: PlayerHealth
var _saved_state: int


class RwBody:
	extends SegfaultBody

	var only := PackedInt32Array([4])

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
	_ctx.reseed(6600)
	_arena = ArenaContext.new()
	_arena.target_source = func() -> Vector2: return Vector2(256, 200)
	_arena.contact_source = func() -> Vector2: return Vector2(-1000, -1000)
	_reg = Register.new()
	_reg.set_fight_start(PackedInt32Array(START))
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
func _setup(b: BossController, phase: int = 2, excluded: Array[StringName] = []) -> BossController:
	_health = _health_new()
	b.excluded_attack_ids = excluded
	assert_true(b.setup(SF_DEF, _health, _arena))
	b.reset_for_fight()
	if phase >= 1:
		b.take_hit(TO_PHASE_2)
	if phase >= 2:
		b.take_hit(TO_PHASE_3)
	assert_eq(b.phase_index, phase)
	return b


func _rw_body() -> RwBody:
	var b := RwBody.new()
	_setup(b)
	assert_eq(b.attack_for(RW), b._attacks[4], "Reserved Write is cache index 4")
	return b


## One sim tick in phase order: BOSS_HAZARDS, PLAYER_EFFECTS, COMBAT.
func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)
		_arena.player_effects.tick(_ctx)
		_health.tick(_ctx)


func _run_until(b: BossController, state: S, limit: int = 2000) -> bool:
	for i: int in limit:
		if b.state == state:
			return true
		_tick(b)
	return b.state == state


func _rw(b: BossController) -> BossAttack:
	return b.attack_for(RW)


func _ring(bits: Array) -> PackedInt32Array:
	return PackedInt32Array(bits)


# --- AC 1, 3: pools and the flag ---

func test_reserved_write_is_only_in_the_phase_3_pool() -> void:
	var b := SegfaultBody.new()
	assert_true(b.setup(SF_DEF, null, null))
	var rw: int = b._attacks.find(b.attack_for(RW))
	assert_eq(rw, 4)
	assert_false(b._pick_candidates(0).has(rw), "phase 1")
	assert_false(b._pick_candidates(1).has(rw), "phase 2")
	assert_true(b._pick_candidates(2).has(rw), "phase 3")
	assert_eq(b._pick_candidates(2).size(), 5)


func test_flag_off_drops_the_attack_before_any_instance_is_built() -> void:
	var b := SegfaultBody.new()
	b.excluded_attack_ids = Arena.excluded_attack_ids(false)
	assert_true(b.setup(SF_DEF, null, null))
	assert_null(b.attack_for(RW), "no Reserved Write instance")
	for attack: BossAttack in b._attacks:
		assert_false(attack.has_method(&"reserved_tell"), "no ReservedWrite object exists")
	var ids: Array[StringName] = []
	for i: int in b._pick_candidates(2):
		ids.append(b._defs[i].id)
	assert_eq(ids, [&"access_violation", &"corrupt_memory", &"core_dump", &"sigsegv"] as Array[StringName])
	assert_eq(b._pick_candidates(0).size(), 2, "phase 1 unchanged")
	assert_eq(b._pick_candidates(1).size(), 3, "phase 2 unchanged")
	assert_same(b.attack_for(SIG), b._attacks[2], "6.5 cache indices unchanged")
	assert_eq(SF_DEF.phases[2].attack_pool.size(), 5, "the shared def is never modified")


func test_excluded_ids_follow_the_flag() -> void:
	assert_eq(Arena.excluded_attack_ids(true), [] as Array[StringName])
	assert_eq(Arena.excluded_attack_ids(false), [&"reserved_write"] as Array[StringName])
	assert_eq(BossController.new().excluded_attack_ids, [] as Array[StringName], "default: nothing cut")


func test_flag_off_phase_3_never_writes_garbage() -> void:
	var b: BossController = _setup(SegfaultBody.new(), 2, Arena.excluded_attack_ids(false))
	for i: int in 6000:
		var was: S = b.state
		_tick(b)
		if b.state == S.TELL and was != S.TELL:
			assert_ne(b.current.id, &"reserved_write")
		assert_false(_reg.has_temporary())


func test_the_real_fsm_never_picks_reserved_write_before_phase_3() -> void:
	for phase: int in 2:
		_reg.set_fight_start(PackedInt32Array(START))
		var b: BossController = _setup(SegfaultBody.new(), phase)
		for i: int in 4000:
			var was: S = b.state
			_tick(b)
			if b.state == S.TELL and was != S.TELL:
				assert_ne(b.current.id, &"reserved_write", "phase %d pick" % (phase + 1))
			assert_false(_reg.has_temporary())


# --- AC 4, 6, 7, 12: timings, the insertion, the tell, the expiry ---

func test_tell_45_active_600_recovery_30_and_the_garbage_lifetime() -> void:
	watch_signals(EventBus)
	var b := _rw_body()
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, RW)
	assert_eq(b.frames_left, 45)
	var rw: BossAttack = _rw(b)
	var serial: int = _reg.shift_serial
	for i: int in 45:
		assert_true(rw.call(&"reserved_tell"), "reserved tell for the whole tell (frame %d)" % i)
		assert_true(Hud.reserved_tell_on(b))
		assert_false(Hud.warning_tell_on(b), "no red warning (GDD: red is Breakpoint and SIGSEGV only)")
		@warning_ignore("integer_division")
		assert_eq(Hud.reserved_flash_on(b), (i / 8) % 2 == 0, "8-frame toggle at %d" % i)
		assert_eq(_reg.ring, _ring(START), "no change during the tell")
		_tick(b)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(b.frames_left, 600)
	assert_false(rw.call(&"reserved_tell"))
	assert_false(Hud.reserved_flash_on(b))
	_link.open(Vector2i(A, D), _reg.shift_serial)
	_tick(b) # first ACTIVE tick: on_active pushes, PLAYER_EFFECTS applies it this tick
	assert_eq(_reg.ring, _ring([A, D, L, N, G]), "`?` appended to the right end")
	assert_false(_link.is_open(), "NP-1: the insertion closes the link")
	assert_eq(_reg.shift_serial, serial, "the ATTACK chain is not reset by a boss effect")
	assert_signal_emit_count(EventBus, "register_changed", 1)
	assert_signal_emitted_with_parameters(EventBus, "register_changed",
		[Vector2i(A, D), _ring([A, D, L, N, G]), &"garbage_in"])
	assert_eq(_arena.player_effects.pending(), 0)
	var present: int = 1
	while _reg.has_temporary():
		_tick(b)
		if _reg.has_temporary():
			present += 1
		assert_lt(present, 700, "the garbage bit expires")
	assert_eq(present, 600, "present for exactly 600 PLAYER_EFFECTS ticks")
	assert_eq(_reg.ring, _ring(START), "owned bits and order unchanged")
	assert_signal_emit_count(EventBus, "register_changed", 2)
	assert_signal_emitted_with_parameters(EventBus, "register_changed",
		[Vector2i(A, D), _ring(START), &"garbage_out"])
	assert_eq(b.state, S.RECOVERY, "the bit ends on the first recovery tick")
	assert_eq(b.frames_left, 29)
	_tick(b, 28)
	assert_eq(b.state, S.RECOVERY, "recovery is never shortened")
	_tick(b)
	assert_eq(b.state, S.GAP)
	assert_signal_emit_count(EventBus, "register_changed", 2, "one insertion per attack")


func test_expiry_closes_the_link_and_keeps_a_rotated_owned_order() -> void:
	var b := _rw_body()
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b)
	_reg.shift(Register.RIGHT) # [?, A, D, L, N]
	_reg.shift(Register.RIGHT) # [N, ?, A, D, L]
	assert_eq(_reg.active_window(), Vector2i(N, G))
	_link.open(Vector2i(N, G), _reg.shift_serial)
	_tick(b, 599)
	assert_true(_reg.has_temporary(), "still present after 600 ticks")
	_tick(b) # the 601st tick ends it
	assert_eq(_reg.ring, _ring([N, A, D, L]), "removed where it sits")
	assert_eq(_reg.active_window(), Vector2i(N, A), "window recomputed")
	assert_false(_link.is_open())


func test_garbage_window_runs_nop_and_no_combo() -> void:
	for x: int in [A, D, L, N, G]:
		assert_null(Defs.COMBOS.get_combo(x, G))
		assert_null(Defs.COMBOS.get_combo(G, x))
	assert_same(Defs.solo_action(G), Defs.NOP)
	assert_false(Defs.NOP.echoable, "never stored as Echo's last action")


# --- AC 10: the fired latch ---

func test_a_second_on_active_queues_nothing() -> void:
	var b := _rw_body()
	assert_true(_run_until(b, S.ACTIVE))
	var rw: BossAttack = _rw(b)
	rw.on_active(_arena)
	rw.on_active(_arena)
	assert_eq(_arena.player_effects.pending(), 1, "one insertion per attack")
	rw.on_recovery(_arena)
	rw.on_active(_arena)
	assert_eq(_arena.player_effects.pending(), 1, "the latch holds through RECOVERY")
	rw.reset()
	assert_false(rw.get(&"fired"), "reset() clears the latch")
	rw.on_active(_arena)
	rw.on_cancel(_arena)
	assert_false(rw.get(&"fired"), "on_cancel clears the latch")
	assert_eq(_arena.player_effects.pending(), 0, "on_cancel drops the queued insertion of the garbage bit")


# --- AC 13, 14, 15: cut, defeat, retry ---

## Phase 3 is the last phase, so only a defeat can cut Reserved Write in a real fight; the hook
## contract for a cut during TELL is driven directly.
func test_a_cut_during_the_tell_writes_nothing() -> void:
	var rw: BossAttack = _rw(_rw_body())
	rw.on_tell(_arena)
	rw.on_cancel(_arena)
	assert_false(rw.call(&"reserved_tell"))
	_arena.player_effects.tick(_ctx)
	assert_eq(_reg.ring, _ring(START))


func test_a_defeat_during_the_tell_writes_nothing() -> void:
	var b := _rw_body()
	assert_true(_run_until(b, S.TELL))
	_tick(b, 20)
	b.take_hit(b.hp)
	assert_eq(b.state, S.DEFEATED)
	assert_false(Hud.reserved_tell_on(b))
	_tick(b, 70)
	assert_eq(_reg.ring, _ring(START))
	assert_eq(_arena.player_effects.pending(), 0)
	assert_false(_rw(b).get(&"fired"))


func test_a_defeat_during_active_removes_the_garbage_at_once() -> void:
	watch_signals(EventBus)
	var b := _rw_body()
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 100)
	assert_true(_reg.has_temporary())
	b.take_hit(b.hp) # COMBAT phase: the cut runs on_cancel, not on_recovery
	assert_eq(b.state, S.DEFEATED)
	assert_eq(_reg.ring, _ring(START), "D-S66-6: no `?` after DEFEATED")
	assert_eq(_arena.player_effects.temporary_bit(), 0)
	assert_signal_emitted_with_parameters(EventBus, "register_changed",
		[Vector2i(A, D), _ring(START), &"garbage_out"])
	_tick(b, 700)
	assert_eq(_reg.ring, _ring(START))
	assert_signal_emit_count(EventBus, "register_changed", 2)


func test_a_defeat_during_recovery_needs_nothing_more() -> void:
	var b := _rw_body()
	assert_true(_run_until(b, S.RECOVERY))
	_tick(b) # the bit expires on the first recovery tick
	assert_false(_reg.has_temporary())
	b.take_hit(b.hp)
	_tick(b, 70)
	assert_eq(_reg.ring, _ring(START))


func test_retry_restores_the_fight_start_ring_without_garbage() -> void:
	var b := _rw_body()
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 10)
	assert_true(_reg.has_temporary())
	# The Arena's retry path: set_fight_start, then the queue clear, then reset_for_fight.
	_reg.set_fight_start(PackedInt32Array(START))
	_arena.player_effects.clear()
	b.reset_for_fight()
	assert_eq(_reg.ring, _ring(START))
	assert_false(_reg.has_temporary())
	assert_eq(_arena.player_effects.pending(), 0)
	assert_eq(_arena.player_effects.temporary_bit(), 0)
	for i: int in 50: # the new fight's first gap: no garbage carried over
		_tick(b)
		assert_false(_reg.has_temporary())


func test_reset_for_fight_alone_removes_a_live_garbage_bit() -> void:
	var b := _rw_body()
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b)
	assert_true(_reg.has_temporary())
	b.reset_for_fight()
	assert_eq(_reg.ring, _ring(START), "PlayerEffects.clear() never leaves a `?`")


# --- AC 11: isolation ---

func test_the_attack_file_passes_isolation() -> void:
	var iso: GDScript = load("res://tests/unit/test_attack_isolation.gd")
	var path := "res://src/bosses/segfault/attacks/reserved_write.gd"
	assert_true(iso.attack_files().has(path))
	assert_eq(iso.violations(iso.code_of(path)), PackedStringArray())
	var code: String = iso.code_of(path)
	for word: String in ["LinkState", "PlayerHealth", "Defs", "Register.", "rng"]:
		assert_false(code.contains(word), word)
	assert_true(code.contains("PlayerEffects.GARBAGE_BIT"))
	var rw: BossAttack = _rw(_rw_body())
	assert_eq(rw.declared_positions(_arena), PackedVector2Array(), "no ground hazard")
	assert_false(rw.hazard_hit(Vector2(256, 200)))


# --- AC 16, 17: 10 seeded runs of phase 3, determinism ---

## One run of phase 3 for `frames` ticks. Returns the pick log and the register timeline; asserts
## the fairness rules for every Reserved Write.
func _seeded_run(run_seed: int, frames: int) -> Dictionary:
	_ctx = SimContext.new()
	_ctx.reseed(run_seed)
	_reg.set_fight_start(PackedInt32Array(START))
	_arena.player_effects.clear()
	var b: BossController = _setup(SegfaultBody.new(), 2)
	var tiles: CorruptedTiles = b.get(&"tiles")
	var picks: Array = []
	var timeline: Array = []
	var writes: int = 0
	var i: int = 0
	while i < frames:
		var was: S = b.state
		_tick(b)
		i += 1
		if b.state == S.TELL and was != S.TELL:
			picks.append(b.current.id)
			if b.current == RW:
				writes += 1
				var tell: int = 0
				while b.state == S.TELL:
					assert_true(tiles.is_empty(), "no tile hazard beside the tell")
					_tick(b)
					tell += 1
				assert_eq(tell, 45, "run_seed %d: one 45-frame tell" % run_seed)
				assert_eq([b.state, b.current], [S.ACTIVE, RW])
				var present: int = 0
				while b.state == S.ACTIVE:
					assert_true(tiles.is_empty(), "no other attack live during the garbage window")
					_tick(b)
					if _reg.has_temporary():
						present += 1
						if present == 1:
							timeline.append([i + tell + present, _reg.ring.duplicate()])
				assert_eq(b.state, S.RECOVERY)
				var rec: int = 0
				while b.state == S.RECOVERY:
					assert_eq(b.current, RW, "no new attack before the recovery ends")
					_tick(b)
					rec += 1
					if _reg.has_temporary():
						present += 1
				assert_eq(present, 600, "run_seed %d: the bit is present 600 ticks" % run_seed)
				assert_eq(rec, 30, "run_seed %d: full recovery" % run_seed)
				assert_false(_reg.has_temporary())
				i += tell + 600 + rec
	return {"picks": picks, "timeline": timeline, "writes": writes}


func test_ten_seeded_runs_of_phase_3_are_fair() -> void:
	var total: int = 0
	for run_seed: int in range(1, 11):
		var run: Dictionary = _seeded_run(run_seed, 4000)
		total += run["writes"]
	assert_gt(total, 5, "Reserved Write is drawn across the runs")


func test_the_same_seed_replays_the_same_picks_and_register_timeline() -> void:
	var first: Dictionary = _seeded_run(66, 4000)
	var second: Dictionary = _seeded_run(66, 4000)
	assert_gt(first["writes"], 0)
	assert_eq(first["picks"], second["picks"])
	assert_eq(first["timeline"], second["timeline"])
