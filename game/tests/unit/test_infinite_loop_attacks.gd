extends GutTest
## Story 3.4 AC 2-10, 13, 14 (E5, F5, D1-D5, G3): Head Rush and Constrict on the real Infinite Loop
## def. No scene tree: the body is ticked directly with an ArenaContext whose aim, contact position
## and shift count the test drives. The aim (target_source) and the real player (contact_source)
## are separate so the tests can tell which one each read uses (D-S34-9, D-S34-10).

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")
const HEAD_RUSH: AttackDef = preload("res://data/bosses/infinite_loop/attack_head_rush.tres")
const CONSTRICT: AttackDef = preload("res://data/bosses/infinite_loop/attack_constrict.tres")
const TILE := Const.TILE_PX
const S := BossController.BossState


## Test-only FSM whose dash invulnerability is set by the test.
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
	_ctx.reseed(3434)
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


## A reset, started body with the player (and the aim) on the ring centre, so nothing drifts and no
## segment touches the player.
func _body(health: PlayerHealth = null) -> InfiniteLoopBody:
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(IL_DEF, health, _arena), "setup accepts the Infinite Loop def")
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


## Ticks until the boss is in `state` (at most `limit` ticks). True when reached.
func _run_until(b: BossController, state: BossController.BossState, limit: int = 2000) -> bool:
	var guard: int = 0
	while b.state != state and guard < limit:
		b.tick(_ctx)
		guard += 1
	return b.state == state


## Phase 2 with Constrict forced as the next pick (two Head Rushes in a row as history, D-S31-6),
## stopped on Constrict's TELL entry.
func _constrict_tell(b: InfiniteLoopBody) -> void:
	assert_true(b.debug_skip_phase())
	assert_true(_run_until(b, S.GAP))
	var head: int = b.get(&"_defs").find(HEAD_RUSH)
	b.last_pick = head
	b.second_last_pick = head
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, CONSTRICT)


func _circle(r_tiles: float) -> HitCircle:
	var c := HitCircle.new()
	c.radius_tiles = r_tiles
	return c


# --- AC 1 (data), AC 10: pools and picks ---

func test_attack_data_matches_the_gdd() -> void:
	assert_eq([HEAD_RUSH.id, HEAD_RUSH.tell, HEAD_RUSH.active, HEAD_RUSH.recovery], [&"head_rush", 30, 40, 45])
	assert_eq([CONSTRICT.id, CONSTRICT.tell, CONSTRICT.active, CONSTRICT.recovery], [&"constrict", 40, 60, 120])
	assert_ne(HEAD_RUSH.tell_sfx, &"")
	assert_ne(CONSTRICT.tell_sfx, &"")
	assert_eq(HEAD_RUSH.validate(), PackedStringArray())
	assert_eq(CONSTRICT.validate(), PackedStringArray())


func test_phase_1_draws_head_rush_every_time_without_a_redraw() -> void:
	var b: InfiniteLoopBody = _body()
	var ids: Array[StringName] = []
	watch_signals(EventBus)
	while ids.size() < 4:
		assert_true(_run_until(b, S.TELL))
		ids.append(b.current.id)
		assert_true(_run_until(b, S.GAP))
	assert_eq(ids, [&"head_rush", &"head_rush", &"head_rush", &"head_rush"] as Array[StringName], "one-attack pool repeats (D-S34-3)")
	assert_signal_emit_count(EventBus, "boss_tell_started", 4)
	assert_signal_emitted_with_parameters(EventBus, "boss_tell_started", [&"head_rush", &"tell_head_rush"])


func test_phase_2_never_draws_the_same_attack_three_times_in_a_row() -> void:
	var b: InfiniteLoopBody = _body()
	assert_true(b.debug_skip_phase())
	var ids: Array[StringName] = []
	while ids.size() < 30:
		assert_true(_run_until(b, S.TELL, 5000))
		ids.append(b.current.id)
		b.hp = 264 # keep phase 2 whatever happens
		assert_true(_run_until(b, S.GAP, 5000))
	for i: int in range(2, ids.size()):
		assert_false(ids[i] == ids[i - 1] and ids[i] == ids[i - 2], "no triple at %d" % i)
	assert_true(ids.has(&"head_rush") and ids.has(&"constrict"), "both attacks drawn")


func test_no_attack_before_the_loop_starts() -> void:
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(IL_DEF, null, _arena))
	b.reset_for_fight()
	_player_px = b.body_center_px
	var before: int = _ctx.rng.state
	watch_signals(EventBus)
	# Story 4.4 (D-S44-1): 299 ticks (was 600); the ring now starts on its own at tick 300.
	_tick(b, InfiniteLoopBody.START_NUDGE_TICKS - 1)
	assert_eq(b.state, S.GAP, "D-S34-23: the FSM waits for the first shift (or the nudge)")
	assert_signal_emit_count(EventBus, "boss_tell_started", 0)
	assert_eq(_ctx.rng.state, before, "no pick, no RNG")


func test_rng_is_drawn_only_on_pick_ticks() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(0, 5 * TILE)
	var tells: Array[int] = [0]
	var on_tell: Callable = func(_id: StringName, _sfx: StringName) -> void: tells[0] += 1
	EventBus.boss_tell_started.connect(on_tell)
	for i: int in 1500:
		if i == 400:
			b.debug_skip_phase()
		var before: int = _ctx.rng.state
		var tells_before: int = tells[0]
		b.tick(_ctx)
		if _ctx.rng.state != before:
			assert_eq(tells[0], tells_before + 1, "an RNG draw only on a tell tick (D-S34-14), tick %d" % i)
	EventBus.boss_tell_started.disconnect(on_tell)
	assert_gt(tells[0], 3)


# --- AC 2, 9: Head Rush TELL, ring frozen ---

func test_head_rush_tell_aims_from_the_ring_side_facing_the_target() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(6 * TILE, 0)
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, HEAD_RUSH)
	assert_eq(b.frames_left, 30)
	var attack: BossAttack = b.current_attack()
	var origin: Vector2 = attack.get(&"origin_px")
	assert_almost_eq(origin.distance_to(b.body_center_px), b.nominal_radius_px(), 0.01, "origin on the nominal ring")
	assert_almost_eq(origin.y, b.body_center_px.y, 0.01, "on the side facing the aim")
	assert_gt(origin.x, b.body_center_px.x)
	assert_eq(attack.get(&"direction"), Vector2.RIGHT, "fixed toward the aim")
	assert_eq(attack.tell_marks(), PackedVector2Array([origin]), "the `!` hangs over the origin")
	assert_false(b.is_open(), "the `;` is closed in TELL (D-S34-22)")
	_target_px = b.body_center_px + Vector2(0, 6 * TILE) # the aim moves: the direction does not
	_tick(b, 10)
	assert_eq(attack.get(&"direction"), Vector2.RIGHT)


func test_head_rush_aim_is_clamped_into_the_play_area() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = Vector2(-500, b.body_center_px.y)
	assert_true(_run_until(b, S.TELL))
	var origin: Vector2 = b.current_attack().get(&"origin_px")
	assert_true(ArenaContext.inside_play_area(origin))
	assert_eq(b.current_attack().get(&"direction"), Vector2.LEFT, "toward the clamped aim (x = 0)")


func test_the_ring_does_not_spin_or_drift_during_an_attack() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(0, 6 * TILE)
	assert_true(_run_until(b, S.TELL))
	var travel: int = b.travel_mtiles
	var rem: int = b.travel_rem
	var centre: Vector2 = b.body_center_px
	_player_px = b.body_center_px + Vector2(0, 2 * TILE) # drift would show
	var ticks: int = 0
	while b.state != S.GAP:
		_tick(b)
		ticks += 1
		assert_eq(b.travel_mtiles, travel, "lap clock frozen (D-S34-5)")
		assert_eq(b.travel_rem, rem)
		assert_eq(b.body_center_px, centre, "no drift during Head Rush (D-S34-13)")
	assert_eq(ticks, 30 + 40 + 45, "tell + active + recovery")
	_tick(b)
	assert_ne(b.travel_mtiles, travel, "spins again in GAP")


# --- AC 3: Head Rush ACTIVE ---

func test_head_rush_charges_10_tiles_in_40_ticks_of_250_milli_tiles() -> void:
	var b: InfiniteLoopBody = _body()
	b.body_center_px = InfiniteLoopBody.clamp_centre(Vector2(0, 144), b.radius_px()) # left edge: room to the right
	_player_px = b.body_center_px
	_target_px = b.body_center_px + Vector2(20 * TILE, 0)
	assert_true(_run_until(b, S.ACTIVE))
	var attack: BossAttack = b.current_attack()
	assert_eq(attack.get(&"step_mtiles"), 250, "10 tiles / 40 frames (D-S34-6)")
	assert_eq(attack.get(&"travelled_mtiles"), 0, "ACTIVE entry: the head at the origin")
	var seen: Array[int] = []
	while b.state == S.ACTIVE:
		_tick(b)
		seen.append(attack.get(&"travelled_mtiles"))
	assert_eq(seen.size(), 40)
	for k: int in seen.size():
		assert_eq(seen[k], mini((k + 1) * 250, attack.get(&"max_travel_mtiles")), "tick %d" % (k + 1))
	var origin: Vector2 = attack.get(&"origin_px")
	assert_eq(attack.get(&"max_travel_mtiles"), 10000, "room for the whole charge")
	assert_almost_eq(attack.call(&"head_px").distance_to(origin), 10.0 * TILE, 0.001, "exactly 10 tiles")


func test_head_rush_endpoint_is_clamped_to_the_play_area() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = Vector2(b.body_center_px.x, Arena.play_area().end.y + 100) # down; less than 10 tiles of room
	assert_true(_run_until(b, S.ACTIVE))
	var attack: BossAttack = b.current_attack()
	assert_lt(attack.get(&"max_travel_mtiles"), 10000)
	while b.state == S.ACTIVE:
		assert_true(ArenaContext.inside_play_area(attack.call(&"head_px")), "the head never leaves the play area")
		_tick(b)
	for p: Vector2 in attack.declared_positions(_arena):
		assert_true(ArenaContext.inside_play_area(p))


func test_head_is_a_contact_hazard_only_while_active() -> void:
	var health: PlayerHealth = _health()
	var b: InfiniteLoopBody = _body(health)
	_target_px = b.body_center_px + Vector2(8 * TILE, 0)
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	var origin: Vector2 = attack.get(&"origin_px")
	var off_ring: Vector2 = origin + Vector2(3 * TILE, 0)
	assert_false(b.touches_player(off_ring), "nothing out there in TELL")
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 12) # head at 3 tiles
	var head: Vector2 = attack.call(&"head_px")
	assert_almost_eq(head.distance_to(off_ring), 0.0, 0.01)
	assert_true(b.touches_player(head), "the head's cell")
	assert_true(b.touches_player(head + Vector2(0, 7.9)), "inside 0.5 tile")
	assert_false(b.touches_player(head + Vector2(0, 8.5)), "outside 0.5 tile")
	assert_eq(attack.hazard_positions(), PackedVector2Array([head]))
	_player_px = head + Vector2(TILE / 4.0, 0) # just ahead: the next tick's head covers it
	_tick(b)
	assert_true(health.get(&"_pending"), "one contact hit queued through PlayerHealth")
	assert_true(_run_until(b, S.RECOVERY))
	assert_false(attack.hazard_hit(attack.call(&"head_px")), "retracted in RECOVERY")
	assert_eq(attack.hazard_positions().size(), 0)


func test_a_hit_on_the_head_does_nothing() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(8 * TILE, 0)
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 20)
	var head: Vector2 = b.current_attack().call(&"head_px")
	assert_false(b.overlaps_shape(_circle(0.5), head, Vector2.RIGHT), "only the `;` is a hurtbox (D-S33-5)")
	assert_false(CombatResolver.boss_overlapped(_circle(0.5), head, Vector2.RIGHT, b, 1))


func test_a_dash_through_the_head_takes_no_damage() -> void:
	var health: PlayerHealth = _health(true)
	var b: InfiniteLoopBody = _body(health)
	_target_px = b.body_center_px + Vector2(8 * TILE, 0)
	assert_true(_run_until(b, S.ACTIVE))
	for i: int in 39:
		_player_px = b.current_attack().call(&"head_px")
		_tick(b)
		health.tick(_ctx)
	assert_eq(health.hp, PLAYER_DEF.max_hp, "invulnerability honoured")


# --- AC 4: Head Rush RECOVERY opens the `;` ---

func test_head_rush_recovery_opens_the_semicolon_for_45_ticks_and_counts_once() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(0, 6 * TILE)
	assert_true(_run_until(b, S.TELL))
	var i_before: int = b.iteration
	while b.state != S.RECOVERY:
		assert_false(b.is_open(), "closed in TELL and ACTIVE")
		_tick(b)
	assert_eq(b.iteration, i_before + 1, "one opening, i + 1")
	var open_ticks: int = 0
	while b.state == S.RECOVERY:
		if b.is_semicolon_hittable():
			open_ticks += 1
			assert_true(CombatResolver.boss_overlapped(_circle(0.25), b.semicolon_px(), Vector2.RIGHT, b, 7), "hittable through the boss path")
		_tick(b)
	assert_eq(open_ticks, 45, "open for the whole recovery")
	assert_false(b.is_open(), "closed when the attack ends")
	assert_eq(b.iteration, i_before + 1)


# --- AC 5-7: Constrict ---

func test_constrict_tell_shows_the_final_outline_at_exact_size_and_the_ring_stays() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = Vector2(2, 2) # a corner: the outline is clamped
	_constrict_tell(b)
	assert_eq(b.frames_left, 40)
	var attack: BossAttack = b.current_attack()
	var outline: Vector3 = attack.outline_circle()
	assert_almost_eq(outline.z, 3.8197 * TILE, 0.01, "24 / 2π tiles (D-S34-7)")
	var c := Vector2(outline.x, outline.y)
	assert_eq(c, InfiniteLoopBody.clamp_centre(Vector2(2, 2), b.nominal_radius_px()))
	for p: Vector2 in attack.declared_positions(_arena):
		assert_true(ArenaContext.inside_play_area(p), "outline inside the play area")
	var centre: Vector2 = b.body_center_px
	var travel: int = b.travel_mtiles
	_tick(b, 39)
	assert_eq(b.state, S.TELL)
	assert_eq(b.body_center_px, centre, "the ring waits in TELL")
	assert_eq(b.travel_mtiles, travel)
	assert_eq(b.attack_radius_mtiles, 0)


func test_constrict_radius_shrinks_in_integer_milli_tiles_to_2000() -> void:
	var b: InfiniteLoopBody = _body()
	_constrict_tell(b)
	assert_true(_run_until(b, S.ACTIVE))
	var attack: BossAttack = b.current_attack()
	assert_eq(b.nominal_radius_mtiles(), 3820)
	var radii: Array[int] = []
	while b.state == S.ACTIVE:
		_tick(b)
		radii.append(b.attack_radius_mtiles if b.state == S.ACTIVE else -1)
	assert_eq(radii.size(), 60)
	for k: int in 59:
		@warning_ignore("integer_division")
		assert_eq(radii[k], 3820 - 1820 * (k + 1) / 60, "tick %d" % (k + 1))
	assert_eq(attack.get(&"elapsed"), 60)
	assert_eq(attack.call(&"radius_for", 60, 60, 3820, 2000), 2000, "ends at 2000")
	assert_eq(b.attack_radius_mtiles, 0, "RECOVERY: back to nominal")
	assert_almost_eq(b.radius_px(), b.nominal_radius_px(), 0.0001)


func test_constrict_chases_the_aim_at_8_tiles_per_second_and_never_overshoots() -> void:
	var b: InfiniteLoopBody = _body()
	_constrict_tell(b)
	var aim: Vector2 = Arena.play_area().get_center() + Vector2(5 * TILE, 0)
	_target_px = aim
	b.body_center_px = Arena.play_area().get_center()
	_player_px = b.body_center_px + Vector2(0, TILE) # inside, off the aim
	assert_true(_run_until(b, S.ACTIVE))
	var last: float = b.body_center_px.distance_to(aim)
	_tick(b)
	assert_almost_eq(last - b.body_center_px.distance_to(aim), 8.0 * TILE / 60.0, 0.001, "8 tiles/s")
	var reached: int = -1
	for i: int in 58:
		var d: float = b.body_center_px.distance_to(aim)
		assert_lte(d, last + 0.0001, "never moves away")
		last = d
		if d < 0.001 and reached < 0:
			reached = i
		_tick(b)
	assert_gte(reached, 0, "reaches the aim within the 60 ticks")
	assert_almost_eq(b.body_center_px.distance_to(aim), 0.0, 0.001, "and stays there (never past)")


func test_constrict_disc_uses_the_real_player_not_the_aim() -> void:
	var b: InfiniteLoopBody = _body()
	_constrict_tell(b)
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b)
	_target_px = b.body_center_px + Vector2(9 * TILE, 0)
	assert_true(b.touches_player(b.body_center_px), "the centre is lethal: the disc replaced the segments")
	assert_true(b.touches_player(b.body_center_px + Vector2(b.radius_px() - 0.5, 0)))
	assert_false(b.touches_player(b.body_center_px + Vector2(b.radius_px() + 0.5, 0)), "a segment's outer half is not the disc")
	assert_false(b.touches_player(_target_px), "the aim is not the contact point")


func test_walking_away_cannot_escape_the_constrict() -> void:
	var health: PlayerHealth = _health()
	var b: InfiniteLoopBody = _body(health)
	_constrict_tell(b)
	assert_true(_run_until(b, S.ACTIVE))
	assert_gt(float(b.ring.constrict_chase_tps), PLAYER_DEF.speed_tiles_s, "the chase beats the walk (D-S34-16)")
	_player_px = b.body_center_px
	var walk: float = PLAYER_DEF.speed_tiles_s * TILE / 60.0
	var caught: int = 0
	var ticks: int = 0
	while b.state == S.ACTIVE:
		_player_px = Arena.clamp_to_play_area(_player_px + Vector2(walk, 0))
		_target_px = _player_px # the aim is the player (no decoy)
		_tick(b)
		if b.state == S.ACTIVE:
			ticks += 1
			if b.touches_player(_player_px):
				caught += 1
	assert_eq(caught, ticks, "inside the disc on every ACTIVE tick")
	assert_true(health.get(&"_pending") or health.hp < PLAYER_DEF.max_hp, "a contact hit was queued")


func test_a_player_inside_the_ring_cannot_walk_out_during_the_tell() -> void:
	var health: PlayerHealth = _health()
	var b: InfiniteLoopBody = _body(health)
	_constrict_tell(b)
	_player_px = b.body_center_px
	var walk: float = PLAYER_DEF.speed_tiles_s * TILE / 60.0
	while b.state == S.TELL or b.state == S.ACTIVE:
		_player_px = Arena.clamp_to_play_area(_player_px + Vector2(0, -walk))
		_target_px = _player_px
		_tick(b)
		health.tick(_ctx)
	assert_lt(health.hp, PLAYER_DEF.max_hp, "walking out crosses the body (segments in TELL, the disc in ACTIVE)")


func test_an_invulnerable_move_through_the_constrict_takes_no_damage() -> void:
	var health: PlayerHealth = _health(true)
	var b: InfiniteLoopBody = _body(health)
	_constrict_tell(b)
	assert_true(_run_until(b, S.ACTIVE))
	while b.state == S.ACTIVE:
		_player_px = b.body_center_px
		_tick(b)
		health.tick(_ctx)
	assert_eq(health.hp, PLAYER_DEF.max_hp)


func test_constrict_recovery_restores_the_ring_and_opens_the_semicolon_120_ticks() -> void:
	var b: InfiniteLoopBody = _body()
	_constrict_tell(b)
	var i_before: int = b.iteration
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(b.iteration, i_before + 1, "one opening, i + 1")
	assert_eq(b.attack_radius_mtiles, 0)
	var k: int = 5
	assert_true(b.touches_player(b.segment_px(k)), "the segments are back")
	assert_false(b.touches_player(b.body_center_px), "the inside is safe again")
	var open_ticks: int = 0
	while b.state == S.RECOVERY:
		if b.is_semicolon_hittable():
			open_ticks += 1
		_tick(b)
	assert_eq(open_ticks, 120)
	assert_eq(b.iteration, i_before + 1)


# --- AC 8: cancel on ROAR and defeat ---

func test_a_phase_change_cuts_head_rush_cleanly() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(8 * TILE, 0)
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 10)
	var attack: BossAttack = b.current_attack()
	var i_before: int = b.iteration
	b.take_hit(136) # phase 2
	assert_eq(b.state, S.ROAR)
	assert_null(b.current_attack())
	assert_eq(attack.get(&"travelled_mtiles"), 0, "on_cancel cleared the head")
	assert_eq(attack.hazard_positions().size(), 0)
	assert_eq(b.iteration, i_before, "no on_recovery, no opening")
	assert_false(b.is_open(), "the `;` is closed")
	var travel: int = b.travel_mtiles
	_tick(b)
	assert_ne(b.travel_mtiles, travel, "spins again in ROAR (3.3)")


func test_a_phase_change_during_recovery_closes_the_semicolon() -> void:
	var b: InfiniteLoopBody = _body()
	assert_true(_run_until(b, S.RECOVERY))
	assert_true(b.is_open())
	b.take_hit(136)
	assert_eq(b.state, S.ROAR)
	assert_false(b.is_open())


func test_defeat_during_constrict_restores_the_ring_and_stops() -> void:
	var b: InfiniteLoopBody = _body()
	_constrict_tell(b)
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 20)
	assert_gt(b.attack_radius_mtiles, 0)
	var attack: BossAttack = b.current_attack()
	b.debug_kill()
	assert_eq(b.state, S.DEFEATED)
	assert_eq(b.attack_radius_mtiles, 0, "nominal radius")
	assert_eq(attack.get(&"elapsed"), 0)
	assert_eq(attack.outline_circle(), Vector3.ZERO)
	var travel: int = b.travel_mtiles
	var centre: Vector2 = b.body_center_px
	_tick(b, 30)
	assert_eq(b.travel_mtiles, travel)
	assert_eq(b.body_center_px, centre)


func test_retry_resets_the_attacks() -> void:
	var b: InfiniteLoopBody = _body()
	_constrict_tell(b)
	assert_true(_run_until(b, S.ACTIVE))
	_tick(b, 10)
	b.reset_for_fight()
	assert_eq(b.attack_radius_mtiles, 0)
	assert_null(b.current_attack())
	assert_eq(b.get(&"_attacks")[1].get(&"elapsed"), 0)


# --- AC 13: declared positions inside the play area ---

func test_every_declared_position_is_inside_the_play_area() -> void:
	var b: InfiniteLoopBody = _body()
	var area: Rect2 = Arena.play_area()
	var targets: Array[Vector2] = [Vector2(-100, -100), area.end + Vector2(50, 50), Vector2(0, area.end.y), area.get_center(), Vector2(area.end.x, 0)]
	var centres: Array[Vector2] = [Vector2.ZERO, area.end, area.get_center(), Vector2(0, area.end.y)]
	for c: Vector2 in centres:
		b.body_center_px = InfiniteLoopBody.clamp_centre(c, b.radius_px())
		for t: Vector2 in targets:
			_target_px = t
			for def: AttackDef in [HEAD_RUSH, CONSTRICT]:
				var positions: PackedVector2Array = b.attack_for(def).declared_positions(_arena)
				assert_gt(positions.size(), 0)
				for p: Vector2 in positions:
					assert_true(ArenaContext.inside_play_area(p), "%s at %s from %s: %s" % [def.id, t, c, p])


# --- AC 14, G3: presentation helpers ---

func test_tell_mark_sits_one_cell_above_and_is_clamped() -> void:
	var p := Vector2(100, 100)
	assert_eq(BossView.tell_mark_centre(p), Vector2(100, 100 - TILE))
	var half: float = GlyphFont.CELL * BossView.GLYPH_SCALE / 2.0
	assert_eq(BossView.tell_mark_centre(Vector2(0, 0)), Vector2(half, half), "clamped into the arena")
	var area: Rect2 = Arena.play_area()
	assert_eq(BossView.tell_mark_centre(area.end), Vector2(area.end.x - half, area.end.y - TILE))


func test_constrict_outline_centre_is_clamped() -> void:
	var r: float = 3.82 * TILE
	var area: Rect2 = Arena.play_area()
	for t: Vector2 in [Vector2(-50, -50), area.end + Vector2(10, 10), area.get_center()]:
		var c: Vector2 = load("res://src/bosses/infinite_loop/attacks/constrict.gd").tell_outline_centre(t, r)
		assert_true(c.x - r >= area.position.x and c.x + r <= area.end.x and c.y - r >= area.position.y and c.y + r <= area.end.y, "outline fits for %s" % t)


func test_boss_view_draws_attacks_without_writing() -> void:
	var b: InfiniteLoopBody = _body()
	_target_px = b.body_center_px + Vector2(8 * TILE, 0)
	var view := BossView.new()
	add_child_autofree(view)
	view.boss = b
	for state: BossController.BossState in [S.TELL, S.ACTIVE]:
		assert_true(_run_until(b, state))
		var snapshot: Array = [b.state, b.frames_left, b.travel_mtiles, b.body_center_px, b.current_attack().get(&"travelled_mtiles")]
		view.queue_redraw()
		await get_tree().process_frame
		assert_eq([b.state, b.frames_left, b.travel_mtiles, b.body_center_px, b.current_attack().get(&"travelled_mtiles")], snapshot)
	_constrict_tell(b)
	for state: BossController.BossState in [S.TELL, S.ACTIVE]:
		assert_true(_run_until(b, state))
		var snap: Array = [b.state, b.attack_radius_mtiles, b.body_center_px]
		view.queue_redraw()
		await get_tree().process_frame
		assert_eq([b.state, b.attack_radius_mtiles, b.body_center_px], snap)
