extends GutTest
## Story 3.5 AC 1-11, 15, 16 (P1-P10, Q1-Q3): phase 3 of the Infinite Loop on the real def. The Nested
## Loop (once per fight), the two-ring split, the timed `;` openings and their alternation, the
## per-ring weak windows, the `;` Spit and its projectile pool, Constrict / Head Rush on the split
## ring, the phase-3 cut (fallback) and the presentation helpers. No scene tree except the draw test:
## the body is ticked directly with an ArenaContext whose aim, contact position and shift count the
## test drives (as in test_infinite_loop_attacks.gd).

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")
const HEAD_RUSH: AttackDef = preload("res://data/bosses/infinite_loop/attack_head_rush.tres")
const CONSTRICT: AttackDef = preload("res://data/bosses/infinite_loop/attack_constrict.tres")
const NESTED: AttackDef = preload("res://data/bosses/infinite_loop/attack_nested_loop.tres")
const SpitScript := preload("res://src/bosses/infinite_loop/attacks/semicolon_spit.gd")
const TILE := Const.TILE_PX
const S := BossController.BossState
## Holds the FSM in GAP for motion-only tests.
const HOLD := 1000000


class FakeActions:
	extends ActionStateMachine
	var invuln: bool = false

	func invulnerable() -> bool:
		return invuln


var _ctx: SimContext
var _arena: ArenaContext
var _player_px: Vector2
var _target_px: Vector2
var _shifts: int = 0
var _saved_state: int


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal contact never records a death
	_ctx = SimContext.new()
	_ctx.reseed(3535)
	_shifts = 0
	_arena = ArenaContext.new()
	_arena.target_source = func() -> Vector2: return _target_px
	_arena.contact_source = func() -> Vector2: return _player_px
	_arena.shift_count = func() -> int: return _shifts
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


func _health(invuln: bool = false) -> PlayerHealth:
	var actions := FakeActions.new()
	actions.invuln = invuln
	var h := PlayerHealth.new(PLAYER_DEF, actions)
	h.reset_for_fight()
	h.set_active(true)
	return h


## A reset, started body on `def` with the player and the aim on the ring centre.
func _body(health: PlayerHealth = null, def: BossDef = IL_DEF) -> InfiniteLoopBody:
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(def, health, _arena), "setup accepts the def")
	b.reset_for_fight()
	_player_px = b.body_center_px
	_target_px = b.body_center_px
	_shifts += 1
	b.tick(_ctx) # the gate tick: the loop starts
	assert_true(b.started)
	return b


func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)


func _run_until(b: BossController, state: BossController.BossState, limit: int = 3000) -> bool:
	var guard: int = 0
	while b.state != state and guard < limit:
		b.tick(_ctx)
		guard += 1
	return b.state == state


## Debug-skips to phase 3 (Shift+F6 twice, D-S34-19); the boss is in phase 3's ROAR.
func _phase3(b: InfiniteLoopBody) -> void:
	assert_true(b.debug_skip_phase())
	assert_true(b.debug_skip_phase())
	assert_eq(b.phase_index, InfiniteLoopBody.PHASE_3)
	assert_eq(b.state, S.ROAR)


## Phase 3, the Nested Loop told and completed: the body is split and in GAP.
func _split(b: InfiniteLoopBody) -> void:
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, NESTED, "the first phase-3 pick is the Nested Loop")
	assert_true(_run_until(b, S.GAP))
	assert_true(b.split)


func _circle(r_tiles: float) -> HitCircle:
	var c := HitCircle.new()
	c.radius_tiles = r_tiles
	return c


func _ids_of(pool: Array[AttackDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: AttackDef in pool:
		out.append(a.id)
	return out


## A deep copy of the def without its last phase (the epic fallback, AC 11).
static func two_phase_def() -> BossDef:
	var def: BossDef = IL_DEF.duplicate(true)
	var phases: Array[PhaseDef] = [def.phases[0], def.phases[1]]
	def.phases = phases
	return def


# --- AC 1: data ---

func test_nested_loop_data_and_the_phase_3_pool() -> void:
	assert_eq([NESTED.id, NESTED.tell, NESTED.active, NESTED.recovery, NESTED.tell_sfx], [&"nested_loop", 40, 1, 0, &"tell_infinite_loop"])
	assert_eq(NESTED.validate(), PackedStringArray())
	assert_eq(NESTED.attack_script, preload("res://src/bosses/infinite_loop/attacks/nested_loop.gd"))
	assert_eq(IL_DEF.validate(), PackedStringArray())
	assert_eq(_ids_of(IL_DEF.phases[0].attack_pool), [&"head_rush"] as Array[StringName])
	assert_eq(_ids_of(IL_DEF.phases[1].attack_pool), [&"head_rush", &"constrict"] as Array[StringName])
	assert_eq(_ids_of(IL_DEF.phases[2].attack_pool), [&"head_rush", &"constrict", &"nested_loop"] as Array[StringName])
	for p: PhaseDef in IL_DEF.phases:
		assert_false(_ids_of(p.attack_pool).has(&"semicolon_spit"), "the Spit is not a pool attack (D-S35-8)")


# --- AC 2: once per fight ---

func test_nested_loop_is_the_first_phase_3_pick_without_an_rng_draw() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	_ctx.rng.randi() # off the seed, so a draw would show
	assert_true(_run_until(b, S.GAP))
	var before: int = _ctx.rng.state
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current.id, &"nested_loop")
	assert_eq(_ctx.rng.state, before, "forced pick: no RNG (D-S35-3)")
	assert_true(b.nested_done)


func test_nested_loop_never_comes_back_and_later_picks_never_triple() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	var ids: Array[StringName] = []
	while ids.size() < 40:
		assert_true(_run_until(b, S.TELL, 5000))
		ids.append(b.current.id)
		b.hp = 132 # stay in phase 3
		assert_true(_run_until(b, S.GAP, 5000))
	assert_eq(ids[0], &"nested_loop")
	assert_eq(ids.count(&"nested_loop"), 1, "once per fight")
	for i: int in range(3, ids.size()):
		assert_false(ids[i] == ids[i - 1] and ids[i] == ids[i - 2], "no triple at %d" % i)
	assert_true(ids.has(&"head_rush") and ids.has(&"constrict"))
	# 1000 more seeded picks from the candidate list: never the Nested Loop, never three in a row.
	var nested: int = b.get(&"_defs").find(NESTED)
	var prev := PackedInt32Array([-1, -1])
	for i: int in 1000:
		var p: int = b.pick_next(_ctx.rng)
		assert_ne(p, nested)
		assert_false(p == prev[0] and p == prev[1], "triple at %d" % i)
		prev = PackedInt32Array([p, prev[0]])


func test_a_retry_makes_the_nested_loop_available_again() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.reset_for_fight()
	assert_false(b.nested_done)
	assert_false(b.split)
	_shifts += 1
	_tick(b)
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current.id, &"nested_loop")


# --- AC 3: the split ---

func test_the_split_makes_two_concentric_rings_of_16_and_8() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	assert_false(b.split, "the TELL does not split")
	assert_eq(b.inner_segment_count(), 0)
	var angle: float = b.junction_angle()
	assert_true(_run_until(b, S.GAP))
	assert_true(b.split)
	assert_eq(b.outer_segments(), 16)
	assert_eq(b.inner_segment_count(), 8)
	assert_eq(b.nominal_radius_mtiles(), 2546)
	assert_almost_eq(b.junction_angle(), angle, 0.01, "the lap angle is kept")
	for k: int in 16:
		assert_almost_eq(b.segment_px(k).distance_to(b.body_center_px), 16.0 / TAU * TILE, 0.01)
		assert_true(ArenaContext.inside_play_area(b.segment_px(k)))
	for k: int in 8:
		assert_almost_eq(b.inner_segment_px(k).distance_to(b.body_center_px), 8.0 / TAU * TILE, 0.01)
		assert_true(ArenaContext.inside_play_area(b.inner_segment_px(k)))


func test_the_split_opens_the_outer_semicolon_and_starts_the_schedule() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	var i_before: int = b.iteration
	assert_true(_run_until(b, S.GAP))
	assert_eq(b.iteration, i_before + 1)
	assert_eq(b.open_ring, InfiniteLoopBody.OUTER)
	assert_eq(b.open_left, 90)
	assert_eq(b.next_ring, InfiniteLoopBody.INNER)
	assert_eq(b.ring_timer, 180)
	b.split_rings()
	assert_eq(b.iteration, i_before + 1, "idempotent")


func test_the_split_centre_is_clamped_with_the_outer_radius() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	b.body_center_px = Vector2(1, 1)
	b.split_rings()
	var r: float = b.nominal_radius_px()
	assert_eq(b.body_center_px, InfiniteLoopBody.clamp_centre(Vector2(1, 1), r))
	assert_almost_eq(b.body_center_px.x, r + 0.5 * TILE, 0.001)


func test_a_cut_nested_loop_does_not_split() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	b.debug_kill()
	assert_false(b.split)


# --- AC 4: speeds and freezes ---

func test_the_inner_ring_runs_at_150_percent_capped() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	assert_eq(b.speed_mtps, 8000)
	assert_eq(b.inner_speed_mtps(), 12000, "8 x 1.5 = 12, the cap")
	b.speed_mtps = 6000
	assert_eq(b.inner_speed_mtps(), 9000)
	b.speed_mtps = 12000
	assert_eq(b.inner_speed_mtps(), 12000)
	b.speed_mtps = 8000
	b.frames_left = HOLD
	var inner: int = b.inner_travel_mtiles
	_tick(b, 10)
	assert_eq(b.inner_travel_mtiles, (inner + 2000) % 8000, "12 tiles/s = 200 milli-tiles per tick")


func test_outer_laps_ramp_but_do_not_open_the_semicolon() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	var i_before: int = b.iteration
	var speed: int = b.speed_mtps
	var laps: int = 0
	var last: int = b.travel_mtiles
	for t: int in 170: # < 180: no timed opening yet
		_tick(b)
		if b.travel_mtiles < last:
			laps += 1
		last = b.travel_mtiles
	assert_between(laps, 1, 2, "16 tiles at 8 tiles/s: a lap in at most 120 ticks")
	var expected: int = speed
	for l: int in laps:
		@warning_ignore("integer_division")
		expected = mini(expected * 105 / 100, 12000)
	assert_eq(b.speed_mtps, expected, "+5% per outer lap")
	assert_eq(b.iteration, i_before, "a lap start does not open the `;` after the split")


func test_both_rings_freeze_and_the_timer_runs_during_an_attack() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	_target_px = b.body_center_px + Vector2(6 * TILE, 0)
	assert_true(_run_until(b, S.TELL))
	var frozen: Array = [b.travel_mtiles, b.inner_travel_mtiles, b.body_center_px]
	var timer: int = b.ring_timer
	while b.state == S.TELL or (b.state == S.ACTIVE and b.current == HEAD_RUSH):
		_tick(b)
		if b.state == S.TELL or b.state == S.ACTIVE:
			if b.current == HEAD_RUSH:
				assert_eq([b.travel_mtiles, b.inner_travel_mtiles, b.body_center_px], frozen)
				assert_eq(b.ring_timer, maxi(timer - 1, 0), "the timer runs during TELL and ACTIVE (D-S35-24)")
				timer = b.ring_timer
	assert_true(_run_until(b, S.GAP))
	var travel: int = b.inner_travel_mtiles
	_tick(b)
	assert_ne(b.inner_travel_mtiles, travel, "drift and spin resume in GAP")


# --- AC 5: timed openings ---

func test_timed_openings_alternate_every_180_ticks_for_90() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	var open_ticks: Array[int] = [0, 0]
	var openings: Array[int] = [1, 0] # the split opened the outer one
	var order: Array[int] = [InfiniteLoopBody.OUTER]
	var last_i: int = b.iteration
	if b.is_open():
		open_ticks[b.open_ring] += 1
	for t: int in 1000:
		_tick(b)
		if b.iteration != last_i:
			assert_eq(b.iteration, last_i + 1, "each opening is i + 1")
			openings[b.open_ring] += 1
			order.append(b.open_ring)
			assert_eq(b.open_left, 90)
			assert_eq(t % 180, 179, "every 180 ticks")
			last_i = b.iteration
		if b.is_open():
			open_ticks[b.open_ring] += 1
	assert_eq(order, [0, 1, 0, 1, 0, 1] as Array[int], "outer, inner, outer, ...")
	assert_eq(openings, [3, 3])
	assert_eq(open_ticks, [270, 270], "90 ticks each, never two at once")


func test_an_attack_recovery_opening_takes_the_next_turn() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	_target_px = b.body_center_px + Vector2(6 * TILE, 0)
	assert_true(_run_until(b, S.TELL))
	var expected_ring: int = b.next_ring
	var i_before: int = b.iteration
	assert_false(b.is_open(), "TELL closes the `;`")
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(b.open_ring, expected_ring)
	assert_eq(b.next_ring, 1 - expected_ring, "the alternation flipped")
	assert_lt(b.ring_timer, 180, "the recovery opening does not restart the timer (D-S35-24)")
	assert_eq(b.open_left, b.current.recovery)
	assert_eq(b.iteration, i_before + 1)
	var timer: int = b.ring_timer
	while b.state == S.RECOVERY and timer > 0:
		_tick(b)
		assert_eq(b.ring_timer, maxi(timer - 1, 0), "keeps counting down during recovery")
		timer = b.ring_timer


func test_an_expired_timer_waits_for_an_open_semicolon_then_fires() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	b.ring_timer = 1
	b.open_semicolon(30) # a recovery-style opening: takes the next turn, no restart
	assert_eq(b.ring_timer, 1, "not restarted")
	var flipped: int = b.next_ring
	var i_before: int = b.iteration
	for t: int in 29:
		_tick(b)
		assert_eq(b.ring_timer, 0, "the expired timer waits")
		assert_eq(b.iteration, i_before, "no second opening while one is open")
	_tick(b) # open_left reaches 0 on this tick: the timed opening fires at once
	assert_eq(b.iteration, i_before + 1)
	assert_eq(b.open_ring, flipped, "alternation continues across both kinds")
	assert_eq(b.ring_timer, 180)
	assert_eq(b.timed_openings, 1)


func test_the_timer_is_frozen_in_roar_and_waits_in_tell() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.ring_timer = 0
	b.open_left = 0
	b.open_ring = -1
	b.state = S.TELL
	b.frames_left = 5
	_tick(b)
	assert_false(b.is_open(), "no timed opening in TELL")
	assert_eq(b.timed_openings, 0)
	b.state = S.ROAR
	b.frames_left = 5
	_tick(b)
	assert_false(b.is_open(), "no timed opening in ROAR")


# --- AC 6: weak windows ---

func test_weak_window_follows_the_open_or_next_ring() -> void:
	var a := Register.Bit.ATTACK
	var d := Register.Bit.DASH
	var b: InfiniteLoopBody = _body()
	assert_eq(b.current_weak_window(), Vector2i(a, d), "phase 1 data")
	assert_true(b.debug_skip_phase())
	assert_eq(b.current_weak_window(), Vector2i(d, a), "phase 2 data")
	assert_true(b.debug_skip_phase())
	assert_eq(b.current_weak_window(), Vector2i(a, d), "phase 3 before the split: data")
	assert_true(_run_until(b, S.GAP))
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current_weak_window(), Vector2i(a, d), "still whole during the TELL")
	assert_true(_run_until(b, S.GAP))
	b.frames_left = HOLD
	assert_eq(b.open_ring, InfiniteLoopBody.OUTER)
	assert_eq(b.current_weak_window(), Vector2i(a, d), "outer open: A>D")
	_tick(b, 90)
	assert_false(b.is_open())
	assert_eq(b.next_ring, InfiniteLoopBody.INNER)
	assert_eq(b.current_weak_window(), Vector2i(d, a), "inner next: D>A")
	_tick(b, 90)
	assert_eq(b.open_ring, InfiniteLoopBody.INNER)
	assert_eq(b.current_weak_window(), Vector2i(d, a), "inner open: D>A")
	_tick(b, 90)
	assert_eq(b.next_ring, InfiniteLoopBody.OUTER)
	assert_eq(b.current_weak_window(), Vector2i(a, d), "outer next: A>D")
	assert_eq(IL_DEF.phases[2].weak_window, Vector2i(a, d), "the data window is unchanged")


# --- AC 7: only the open `;` is a hurtbox ---

func test_only_the_open_ring_semicolon_takes_hits() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	var c: HitCircle = _circle(0.25)
	assert_true(b.overlaps_shape(c, b.junction_px(InfiniteLoopBody.OUTER), Vector2.RIGHT), "outer open")
	assert_eq(b.hit_position(), b.junction_px(InfiniteLoopBody.OUTER))
	assert_false(b.overlaps_shape(c, b.junction_px(InfiniteLoopBody.INNER), Vector2.RIGHT), "inner closed")
	assert_false(b.overlaps_shape(c, b.inner_segment_px(3), Vector2.RIGHT))
	_tick(b, 180)
	assert_eq(b.open_ring, InfiniteLoopBody.INNER)
	assert_eq(b.semicolon_px(), b.junction_px(InfiniteLoopBody.INNER))
	assert_true(b.overlaps_shape(c, b.junction_px(InfiniteLoopBody.INNER), Vector2.RIGHT), "inner open")
	assert_false(b.overlaps_shape(c, b.junction_px(InfiniteLoopBody.OUTER), Vector2.RIGHT), "outer closed")
	assert_eq(b.hit_position(), b.junction_px(InfiniteLoopBody.INNER))
	_tick(b, 90)
	assert_false(b.is_open())
	assert_eq(b.semicolon_px(), b.junction_px(InfiniteLoopBody.OUTER), "outer junction when none is open")


func test_both_rings_are_contact_hazards_and_the_gap_between_is_not() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	for k: int in 16:
		assert_true(b.touches_player(b.segment_px(k)), "outer %d" % k)
	for k: int in 8:
		assert_true(b.touches_player(b.inner_segment_px(k)), "inner %d" % k)
	assert_false(b.touches_player(b.body_center_px), "the centre is safe")
	var between: Vector2 = b.body_center_px + Vector2.from_angle(b.junction_angle() + 0.2) * (1.91 * TILE)
	assert_false(b.touches_player(between), "between the rings is safe")


# --- AC 8, 9: the Spit ---

func test_spit_fires_every_360_ticks_after_the_roar_with_a_20_tick_glow() -> void:
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	assert_false(b.spit.glowing())
	while b.state == S.ROAR:
		assert_eq(b.spit.shots, 0)
		_tick(b)
	_player_px = Vector2(-100, -100) # out of the way of the shot
	var fire_ticks: Array[int] = []
	var glow_ticks: int = 0
	for t: int in range(1, 800):
		var before: int = b.spit.shots
		_tick(b)
		if b.spit.glowing():
			glow_ticks += 1
		if b.spit.shots != before:
			fire_ticks.append(t)
	assert_eq(fire_ticks, [360, 720] as Array[int], "every 360 ticks from the ROAR end, attacks or not")
	assert_eq(glow_ticks, 40, "20 ticks before each shot")


func test_spit_projectiles_move_100_milli_tiles_per_tick_and_leave_at_the_edge() -> void:
	var spit: SpitScript = SpitScript.new()
	spit.configure(_ring_def())
	spit.start()
	var origin := Vector2(10 * TILE, 9 * TILE)
	assert_true(spit.fire(origin, Vector2(30 * TILE, 9 * TILE)))
	assert_eq(spit.slot_step_mtiles[0], Vector2i(100, 0), "6 tiles/s = 100 milli-tiles per tick")
	assert_eq(spit.slot_pos_mtiles[0], Vector2i(10000, 9000))
	var ticks: int = 0
	while spit.live_count() > 0 and ticks < 1000:
		spit.tick(origin, _arena)
		ticks += 1
		for p: Vector2 in spit.projectile_positions():
			assert_true(ArenaContext.inside_play_area(p))
	assert_eq(ticks, 221, "from 10 tiles to past 32 tiles at 0.1 tile per tick")
	var diag: Vector2i = SpitScript.step_for(Vector2.ZERO, Vector2(TILE, TILE), 100)
	assert_eq(diag, Vector2i(71, 71), "the direction is rounded once to whole milli-tiles")


func test_a_full_pool_skips_the_shot() -> void:
	var spit: SpitScript = SpitScript.new()
	spit.configure(_ring_def())
	for i: int in 16:
		assert_true(spit.fire(Vector2(100, 100), Vector2(200, 100)))
	assert_eq(spit.live_count(), 16)
	assert_false(spit.fire(Vector2(100, 100), Vector2(200, 100)), "no free slot")
	assert_eq(spit.skipped, 1)
	assert_eq(spit.live_count(), 16)


func test_spit_aims_at_the_clamped_target_from_the_next_ring_junction() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	_player_px = Vector2(-100, -100)
	_target_px = Vector2(-500, b.body_center_px.y) # clamped into the play area
	var origin: Vector2 = Vector2.ZERO
	var guard: int = 0
	while b.spit.shots == 0 and guard < 400:
		origin = b.spit_origin_px()
		_tick(b)
		guard += 1
	assert_eq(b.spit.shots, 1)
	var aim: Vector2 = Arena.clamp_to_play_area(_target_px)
	assert_eq(b.spit.slot_pos_mtiles[0], SpitScript.px_to_mtiles(origin))
	assert_eq(b.spit.slot_step_mtiles[0], SpitScript.step_for(origin, aim, 100))


func test_the_spit_draws_no_rng() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	b.frames_left = HOLD
	_player_px = Vector2(-100, -100)
	var before: int = _ctx.rng.state
	_tick(b, 800)
	assert_eq(b.spit.shots, 2)
	assert_eq(_ctx.rng.state, before, "Spit and split draw nothing (D-S35-8)")


func test_a_projectile_queues_one_contact_hit_and_cannot_be_hit() -> void:
	var health: PlayerHealth = _health()
	var b: InfiniteLoopBody = _body(health)
	_split(b)
	b.frames_left = HOLD
	_player_px = Vector2(-100, -100)
	b.spit.fire(Vector2(2 * TILE, 2 * TILE), Vector2(2 * TILE, 10 * TILE))
	var p: Vector2 = b.spit.projectile_positions()[0]
	assert_true(b.touches_player(p))
	assert_true(b.touches_player(p + Vector2(0.45 * TILE, 0)), "0.5-tile circle")
	assert_false(b.touches_player(p + Vector2(0.55 * TILE, 0)))
	assert_false(b.overlaps_shape(_circle(0.25), p, Vector2.RIGHT), "a hit on a projectile does nothing")
	var hp: int = health.hp
	_player_px = p + Vector2(0, 0.1 * TILE) # where it is after the next step
	_tick(b)
	health.tick(_ctx)
	assert_eq(health.hp, hp - 1, "one contact hit through PlayerHealth")


func test_an_invulnerable_player_ignores_projectiles() -> void:
	var health: PlayerHealth = _health(true)
	var b: InfiniteLoopBody = _body(health)
	_split(b)
	b.frames_left = HOLD
	b.spit.fire(Vector2(2 * TILE, 2 * TILE), Vector2(2 * TILE, 10 * TILE))
	var hp: int = health.hp
	_player_px = b.spit.projectile_positions()[0] + Vector2(0, 0.1 * TILE)
	_tick(b)
	health.tick(_ctx)
	assert_eq(health.hp, hp)


func test_projectiles_clear_at_phase_change_and_defeat() -> void:
	var b: InfiniteLoopBody = _body()
	assert_true(b.debug_skip_phase())
	b.spit.fire(Vector2(100, 100), Vector2(200, 100))
	assert_eq(b.spit.live_count(), 1)
	assert_false(b.spit.is_running(), "no cycle outside phase 3")
	assert_true(b.debug_skip_phase())
	assert_eq(b.spit.live_count(), 0, "cleared at the phase-3 ROAR")
	assert_true(b.spit.is_running())
	b.spit.fire(Vector2(100, 100), Vector2(200, 100))
	b.debug_kill()
	assert_eq(b.spit.live_count(), 0, "cleared at defeat")
	assert_false(b.spit.is_running())


# --- AC 10: Constrict and Head Rush on the split ring ---

func test_constrict_shrinks_from_the_outer_nominal_radius_and_returns_to_it() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	var constrict: int = b.get(&"_defs").find(CONSTRICT)
	var head: int = b.get(&"_defs").find(HEAD_RUSH)
	b.last_pick = head
	b.second_last_pick = head
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, CONSTRICT)
	assert_almost_eq(b.current_attack().outline_circle().z, 2.546 * TILE, 0.01, "tell outline at 2546")
	assert_true(_run_until(b, S.ACTIVE))
	var area: Rect2 = Arena.play_area()
	var radii: Array[int] = []
	while b.state == S.ACTIVE:
		_tick(b)
		radii.append(b.attack_radius_mtiles if b.attack_radius_mtiles > 0 else b.nominal_radius_mtiles())
		# AC 15: the real disc the body uses stays inside the play area
		var r: float = b.radius_px()
		var c: Vector2 = b.body_center_px
		assert_true(c.x - r >= area.position.x and c.x + r <= area.end.x and c.y - r >= area.position.y and c.y + r <= area.end.y)
	assert_eq(radii[0], _constrict_radius(1), "starts from 2546")
	assert_eq(b.state, S.RECOVERY)
	assert_eq(b.attack_radius_mtiles, 0)
	assert_eq(b.outer_radius_mtiles(), 2546, "RECOVERY returns to the outer nominal radius")
	assert_eq(constrict, b.get(&"_current_index"))


func _constrict_radius(tick: int) -> int:
	return load("res://src/bosses/infinite_loop/attacks/constrict.gd").radius_for(tick, 60, 2546, 2000)


func test_head_rush_origin_sits_on_the_outer_nominal_ring() -> void:
	var b: InfiniteLoopBody = _body()
	_split(b)
	_target_px = b.body_center_px + Vector2(6 * TILE, 0)
	var head: int = b.get(&"_defs").find(HEAD_RUSH)
	var constrict: int = b.get(&"_defs").find(CONSTRICT)
	b.last_pick = constrict
	b.second_last_pick = constrict
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, HEAD_RUSH)
	var origin: Vector2 = b.current_attack().get(&"origin_px")
	assert_almost_eq(origin.distance_to(b.body_center_px), 16.0 / TAU * TILE, 0.01)
	assert_eq(head, b.get(&"_current_index"))


# --- AC 15: real positions inside the play area ---

func test_split_and_spit_positions_are_inside_the_play_area() -> void:
	var b: InfiniteLoopBody = _body()
	var area: Rect2 = Arena.play_area()
	var nested: BossAttack = b.attack_for(NESTED)
	for c: Vector2 in [Vector2.ZERO, area.end, area.get_center(), Vector2(0, area.end.y), Vector2(area.end.x, 0)]:
		b.body_center_px = InfiniteLoopBody.clamp_centre(c, b.radius_px())
		var positions: PackedVector2Array = nested.declared_positions(_arena)
		assert_eq(positions.size(), 24)
		for p: Vector2 in positions:
			assert_true(ArenaContext.inside_play_area(p), "nested %s from %s" % [p, c])
	# the real split from a corner, and real Spit shots toward every corner and beyond
	_split(b)
	b.frames_left = HOLD
	_player_px = Vector2(-1000, -1000)
	for k: int in 16:
		assert_true(ArenaContext.inside_play_area(b.segment_px(k)))
	for k: int in 8:
		assert_true(ArenaContext.inside_play_area(b.inner_segment_px(k)))
	for t: Vector2 in [Vector2(-100, -100), area.end + Vector2(50, 50), Vector2(0, area.end.y), Vector2(area.end.x, -40)]:
		_target_px = t
		var decl: PackedVector2Array = b.spit.declared_positions(b.spit_origin_px(), _arena)
		for p: Vector2 in decl:
			assert_true(ArenaContext.inside_play_area(p), "spit path %s" % p)
	_target_px = Vector2(-100, area.end.y + 100)
	for t: int in 1500:
		_tick(b)
		for p: Vector2 in b.spit.projectile_positions():
			assert_true(ArenaContext.inside_play_area(p), "live projectile %s" % p)
	assert_gt(b.spit.shots, 3)


# --- AC 11: the phase-3 cut ---

func test_the_two_phase_fallback_runs_with_no_split_and_no_spit() -> void:
	var def: BossDef = two_phase_def()
	assert_eq(def.validate(), PackedStringArray(), "valid without phase 3")
	assert_eq(def.phases.size(), 2)
	var b: InfiniteLoopBody = _body(null, def)
	assert_true(b.debug_skip_phase())
	assert_false(b.debug_skip_phase(), "no phase 3 to skip to")
	var told: Dictionary[StringName, int] = {}
	for t: int in 3000:
		_tick(b)
		if b.state == S.TELL and b.frames_left == b.current.tell - 1:
			told[b.current.id] = told.get(b.current.id, 0) + 1
		b.hp = maxi(b.hp, 2)
		assert_false(b.split)
		assert_false(b.spit.is_running())
		assert_eq(b.current_weak_window(), def.phases[1].weak_window)
	assert_false(told.has(&"nested_loop"))
	assert_true(told.has(&"head_rush") and told.has(&"constrict"))
	b.debug_kill()
	assert_eq(b.state, S.DEFEATED)


# --- AC 16: presentation ---

func test_nested_flash_and_spit_glow_helpers() -> void:
	assert_false(BossView.nested_flash_hidden(false, 7))
	var hidden: int = 0
	for f: int in range(40, 0, -1):
		if BossView.nested_flash_hidden(true, f):
			hidden += 1
	assert_gt(hidden, 0)
	assert_lt(hidden, 40, "a blink, not a blank")
	var b: InfiniteLoopBody = _body()
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	assert_true(BossView.nested_telling(b))
	assert_true(_run_until(b, S.GAP))
	assert_false(BossView.nested_telling(b))
	b.frames_left = HOLD
	_player_px = Vector2(-100, -100)
	var glow: int = 0
	for t: int in 360:
		_tick(b)
		if BossView.spit_glow_on(b):
			glow += 1
	assert_eq(glow, 20)


func test_boss_view_draws_the_split_without_writing() -> void:
	var b: InfiniteLoopBody = _body()
	var view := BossView.new()
	add_child_autofree(view)
	view.boss = b
	_phase3(b)
	assert_true(_run_until(b, S.TELL))
	var snap: Array = [b.state, b.frames_left, b.split, b.travel_mtiles]
	view.queue_redraw()
	await get_tree().process_frame
	assert_eq([b.state, b.frames_left, b.split, b.travel_mtiles], snap)
	assert_true(_run_until(b, S.GAP))
	b.frames_left = HOLD
	_player_px = Vector2(-100, -100)
	b.spit.fire(Vector2(100, 100), Vector2(200, 100))
	_tick(b, 345) # into the Spit glow
	var snapshot: Array = [b.inner_travel_mtiles, b.travel_mtiles, b.open_ring, b.next_ring, b.ring_timer, b.spit.timer, b.spit.live_count(), b.body_center_px]
	view.queue_redraw()
	await get_tree().process_frame
	assert_eq([b.inner_travel_mtiles, b.travel_mtiles, b.open_ring, b.next_ring, b.ring_timer, b.spit.timer, b.spit.live_count(), b.body_center_px], snapshot)


static func _ring_def() -> RingDef:
	return load("res://data/bosses/infinite_loop/ring_def.tres")
