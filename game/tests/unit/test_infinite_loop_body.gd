extends GutTest
## Story 3.3 AC 1-8, 10 (F1): the Infinite Loop's ring. Still until the first shift, integer spin
## (180 ticks per lap at 8 tiles/s), the +5% ramp and its cap, the `;` open 90 ticks per lap, `i`,
## drift and clamp, per-segment contact, the `;`-only hurtbox, ROAR, defeat, phases, zero RNG. No
## scene tree: the body is ticked directly with an ArenaContext whose shift count the test drives.
## Story 3.4: the real def now has attack pools; these ring tests run on a copy with empty pools
## (the 3.3 ring alone, D-S33-9). The attacks are covered by test_infinite_loop_attacks.gd.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")
const TILE := Const.TILE_PX
const RAMP: Array[int] = [8000, 8400, 8820, 9261, 9724, 10210, 10720, 11256, 11818, 12000]


## Test-only FSM whose dash invulnerability is set by the test.
class FakeActions:
	extends ActionStateMachine
	var invuln: bool = false

	func invulnerable() -> bool:
		return invuln


var _ctx: SimContext
## IL_DEF with every attack pool emptied (the 3.3 ring alone).
var _ring_only: BossDef
var _arena: ArenaContext
var _player_px: Vector2
var _shifts: int = 0
var _saved_state: int


func before_all() -> void:
	_ring_only = ring_only_def()


## A deep copy of the Infinite Loop def with empty attack pools.
static func ring_only_def() -> BossDef:
	var def: BossDef = IL_DEF.duplicate(true)
	var phases: Array[PhaseDef] = []
	for p: PhaseDef in def.phases:
		var copy: PhaseDef = p.duplicate()
		copy.attack_pool = []
		phases.append(copy)
	def.phases = phases
	return def


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal contact never records a death
	_ctx = SimContext.new()
	_ctx.reseed(4242)
	_shifts = 0
	_player_px = Vector2(16, 4) * TILE + Vector2(0, 0.5 * TILE) # close to the ring centre
	_arena = ArenaContext.new()
	_arena.contact_source = func() -> Vector2: return _player_px
	_arena.shift_count = func() -> int: return _shifts
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


func _health() -> PlayerHealth:
	var h := PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	h.reset_for_fight()
	h.set_active(true)
	return h


## A reset body; with `still_player` the player stands on the ring centre, so nothing drifts.
func _body(health: PlayerHealth = null, still_player: bool = true) -> InfiniteLoopBody:
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(_ring_only, health, _arena), "setup accepts the Infinite Loop def (ring only)")
	b.reset_for_fight()
	if still_player:
		_player_px = b.body_center_px
	return b


func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)


## The player's first shift, then the tick that sees it.
func _start(b: InfiniteLoopBody) -> void:
	_shifts += 1
	_tick(b)


# --- AC 1: spawn, still until the first shift ---

func test_spawns_a_ring_of_24_with_i_0() -> void:
	var b: InfiniteLoopBody = _body()
	assert_eq(b.ring.segments, 24)
	assert_almost_eq(b.ring.radius_tiles(), 3.8197, 0.001, "24 / 2π tiles")
	assert_eq(b.iteration, 0)
	assert_false(b.is_open())
	assert_false(b.started)
	assert_eq(b.body_center_px, InfiniteLoopBody.clamp_centre(Vector2(16, 4) * TILE, b.radius_px()), "spawn (16, 4), clamped (D-S33-21)")
	for k: int in 24:
		assert_almost_eq(b.segment_px(k).distance_to(b.body_center_px), b.radius_px(), 0.001)
		var gap: float = b.segment_px(k).distance_to(b.segment_px((k + 1) % 24))
		assert_almost_eq(gap, float(TILE), 0.1, "1-tile segments")
	for k: int in 24:
		assert_true(ArenaContext.inside_play_area(b.segment_px(k)), "segment %d inside the play area" % k)


func test_ring_stays_still_until_the_first_shift() -> void:
	var b: InfiniteLoopBody = _body(null, false)
	_player_px = Arena.SPAWN_PX + Vector2(6 * TILE, 3 * TILE) # far away: drift would show
	var centre: Vector2 = b.body_center_px
	var seg0: Vector2 = b.segment_px(0)
	# Story 4.4 (D-S44-1): 299 ticks, the last tick before the 5 s auto-start (was 300 before 4.4).
	_tick(b, InfiniteLoopBody.START_NUDGE_TICKS - 1)
	assert_false(b.started)
	assert_eq(b.travel_mtiles, 0)
	assert_eq(b.iteration, 0)
	assert_false(b.is_open())
	assert_eq(b.body_center_px, centre, "no drift")
	assert_eq(b.segment_px(0), seg0, "no spin")
	assert_eq(b.state, BossController.BossState.GAP)


func test_the_first_shift_starts_the_loop_with_i_1_and_the_semicolon_open() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	assert_true(b.started)
	assert_eq(b.iteration, 1, "the first lap starts on the first spinning tick (D-S33-19)")
	assert_eq(b.open_left, 90)
	assert_eq(b.speed_mtps, 8000)


func test_a_shift_before_reset_does_not_start_the_next_fight() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	_tick(b, 50)
	b.reset_for_fight()
	assert_eq(b.shift_at_fight_start, _shifts, "the count is captured at reset")
	assert_false(b.started)
	assert_eq(b.travel_mtiles, 0)
	assert_eq(b.iteration, 0)
	assert_eq(b.open_left, 0)
	assert_eq(b.speed_mtps, 8000)
	_tick(b, 30)
	assert_false(b.started, "no new shift, no start")
	_start(b)
	assert_true(b.started)


# --- AC 2, 3: spin, ramp, the `;` ---

func test_a_lap_at_8_tiles_per_second_is_exactly_180_ticks() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	_tick(b, 179)
	assert_eq(b.iteration, 1)
	assert_gt(b.travel_mtiles, 23000)
	_tick(b)
	assert_eq(b.iteration, 2, "the second lap starts 180 ticks after the first")
	assert_eq(b.travel_mtiles, 0, "no drift in the integer spin")
	assert_eq(b.travel_rem, 0)
	assert_eq(b.speed_mtps, 8400)


func test_speed_ramps_5_percent_per_lap_up_to_the_cap() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	var speeds: Array[int] = [b.speed_mtps]
	var last: int = b.iteration
	var guard: int = 0
	while speeds.size() < 12 and guard < 5000:
		_tick(b)
		guard += 1
		if b.iteration != last:
			last = b.iteration
			speeds.append(b.speed_mtps)
	assert_eq(speeds.slice(0, 10), RAMP, "laps 1-10 (D-S33-2)")
	assert_eq(speeds[10], 12000, "capped at 12 tiles/s")
	assert_eq(speeds[11], 12000)


func test_semicolon_is_open_exactly_90_ticks_per_lap_and_i_counts_laps() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	var open_ticks: int = 1 # the start tick
	var per_lap: Array[int] = []
	var last: int = b.iteration
	while per_lap.size() < 5:
		_tick(b)
		if b.iteration != last:
			per_lap.append(open_ticks)
			assert_eq(b.iteration, last + 1, "one `i` per opening")
			last = b.iteration
			open_ticks = 0
		if b.is_open():
			open_ticks += 1
	assert_eq(per_lap, [90, 90, 90, 90, 90] as Array[int])
	assert_eq(b.iteration, 6)


func test_the_semicolon_travels_with_the_spin() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	var before: Vector2 = b.semicolon_px()
	assert_eq(before, b.segment_px(0))
	_tick(b, 45) # a quarter lap
	assert_almost_eq(b.semicolon_px().distance_to(before), b.radius_px() * sqrt(2.0), 0.5, "a quarter turn")
	assert_almost_eq(b.junction_angle(), PI / 2.0, 0.01)


# --- AC 2: drift and clamp (D-S33-7) ---

func test_drift_is_2_tiles_per_second_toward_the_player_and_never_past() -> void:
	var b: InfiniteLoopBody = _body(null, false)
	var start: Vector2 = b.body_center_px
	_player_px = start + Vector2(0, 8 * TILE)
	_start(b) # the start tick does not drift
	assert_eq(b.body_center_px, start)
	_tick(b, 60)
	assert_almost_eq(b.body_center_px.y, start.y + 2 * TILE, 0.01, "2 tiles in one second")
	assert_almost_eq(b.body_center_px.x, start.x, 0.001)
	_tick(b, 600)
	assert_almost_eq(b.body_center_px.distance_to(_player_px), 0.0, 0.01, "stops on the player, never past")


func test_drift_is_clamped_inside_the_play_area() -> void:
	var b: InfiniteLoopBody = _body(null, false)
	_player_px = Vector2(1, 1)
	_start(b)
	_tick(b, 1200)
	var inset: float = b.radius_px() + 0.5 * TILE
	assert_almost_eq(b.body_center_px.x, inset, 0.01)
	assert_almost_eq(b.body_center_px.y, inset, 0.01)
	var area: Rect2 = Arena.play_area()
	assert_eq(InfiniteLoopBody.clamp_centre(Vector2(-50, 900), b.radius_px()), Vector2(inset, area.end.y - inset))
	assert_eq(InfiniteLoopBody.clamp_centre(Vector2(900, -50), b.radius_px()), Vector2(area.end.x - inset, inset))
	assert_eq(InfiniteLoopBody.clamp_centre(area.get_center(), b.radius_px()), area.get_center())


# --- AC 5: per-segment contact ---

func test_every_segment_is_a_contact_hazard_and_the_centre_is_not() -> void:
	var b: InfiniteLoopBody = _body()
	for k: int in 24:
		assert_true(b.touches_player(b.segment_px(k)), "segment %d" % k)
		var outward: Vector2 = (b.segment_px(k) - b.body_center_px).normalized()
		assert_true(b.touches_player(b.segment_px(k) + outward * 7.9), "inside 0.5 tile")
		assert_false(b.touches_player(b.segment_px(k) + outward * 8.5), "outside 0.5 tile")
	assert_false(b.touches_player(b.body_center_px))
	assert_false(b.touches_player(Arena.SPAWN_PX), "the player spawn is clear of the ring")


func test_contact_queues_one_hit_through_player_health() -> void:
	var health: PlayerHealth = _health()
	var b: InfiniteLoopBody = _body(health)
	_player_px = b.segment_px(6)
	_tick(b)
	assert_true(health.get(&"_pending"), "contact before the start too (D-S33-6)")
	health.tick(_ctx)
	assert_eq(health.hp, 4)
	for i: int in 30:
		_tick(b)
		health.tick(_ctx)
	assert_eq(health.hp, 4, "invulnerability honoured")


func test_contact_is_live_in_roar_and_off_once_defeated() -> void:
	var health: PlayerHealth = _health()
	var b: InfiniteLoopBody = _body(health)
	b.debug_skip_phase()
	assert_eq(b.state, BossController.BossState.ROAR)
	_player_px = b.segment_px(3)
	_tick(b)
	assert_true(health.get(&"_pending"), "ROAR")
	health.reset_for_fight()
	b.debug_kill()
	assert_eq(b.state, BossController.BossState.DEFEATED)
	assert_false(b.touches_player(b.segment_px(3)))
	_tick(b)
	assert_false(health.get(&"_pending"), "DEFEATED")


# --- AC 4: the `;` is the only hurtbox (D-S33-4, D-S33-5) ---

func _circle(r_tiles: float) -> HitCircle:
	var c := HitCircle.new()
	c.radius_tiles = r_tiles
	return c


func test_only_the_open_semicolon_overlaps_a_hit() -> void:
	var b: InfiniteLoopBody = _body()
	var small: HitCircle = _circle(0.25)
	assert_false(b.overlaps_shape(small, b.semicolon_px(), Vector2.RIGHT), "closed `;` is not hittable")
	assert_eq(b.hit_position(), b.body_center_px)
	_start(b)
	assert_true(b.overlaps_shape(small, b.semicolon_px(), Vector2.RIGHT), "open `;`")
	assert_eq(b.hit_position(), b.semicolon_px())
	assert_true(b.overlaps_shape(small, b.semicolon_px() + Vector2(0, 11.9), Vector2.RIGHT), "hurt radius 0.5 tile + 0.25")
	assert_false(b.overlaps_shape(small, b.segment_px(12), Vector2.RIGHT), "a segment never takes a hit")
	assert_false(b.overlaps_shape(small, b.body_center_px, Vector2.RIGHT), "nor the centre")
	assert_false(b.overlaps_shape(null, b.semicolon_px(), Vector2.RIGHT))
	_tick(b, 90)
	assert_false(b.is_open())
	assert_false(b.overlaps_shape(small, b.semicolon_px(), Vector2.RIGHT), "closed again after 90 ticks")


func test_roar_keeps_spinning_with_no_hit_and_resets_the_speed() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	var guard: int = 0
	while b.iteration < 3 and guard < 1000:
		_tick(b)
		guard += 1
	assert_eq(b.speed_mtps, 8820, "lap 3")
	assert_true(b.is_open(), "lap 3 just started: `;` open")
	b.take_hit(136) # 264 HP: phase 2
	assert_eq(b.phase_index, 1)
	assert_eq(b.state, BossController.BossState.ROAR)
	assert_eq(b.speed_mtps, 8000, "speed ramp resets on the phase change (D-S33-8)")
	assert_eq(b.iteration, 3, "the loop keeps its count")
	assert_true(b.is_open(), "and its `;` state")
	assert_false(b.is_semicolon_hittable(), "no `;` hit in ROAR")
	assert_false(b.overlaps_shape(_circle(0.25), b.semicolon_px(), Vector2.RIGHT))
	var travel: int = b.travel_mtiles
	_tick(b, 10)
	assert_ne(b.travel_mtiles, travel, "still spinning in ROAR")
	_tick(b, 50)
	assert_eq(b.state, BossController.BossState.GAP, "ROAR lasts 60 ticks")
	assert_true(b.is_semicolon_hittable(), "hittable again while still open")
	assert_eq(b.current_weak_window(), Vector2i(Register.Bit.DASH, Register.Bit.ATTACK), "P2 D>A")


func test_defeat_stops_everything() -> void:
	var b: InfiniteLoopBody = _body(null, false)
	_player_px = Arena.SPAWN_PX + Vector2(0, 3 * TILE)
	_start(b)
	_tick(b, 20)
	watch_signals(EventBus)
	b.debug_kill()
	assert_eq(b.hp, 0)
	assert_signal_emitted_with_parameters(EventBus, "boss_defeated", [&"infinite_loop"])
	var travel: int = b.travel_mtiles
	var centre: Vector2 = b.body_center_px
	_tick(b, 200)
	assert_eq(b.travel_mtiles, travel)
	assert_eq(b.body_center_px, centre, "keeps its last position (D-S33-17)")
	assert_false(b.is_semicolon_hittable())
	assert_false(b.overlaps_shape(_circle(1.0), b.semicolon_px(), Vector2.RIGHT))


# --- AC 7: phases; D-S33-9: empty pools ---

func test_phase_thresholds_264_and_132() -> void:
	assert_eq(BossController.phase_for_hp(400, 400, IL_DEF.phases), 0)
	assert_eq(BossController.phase_for_hp(265, 400, IL_DEF.phases), 0)
	assert_eq(BossController.phase_for_hp(264, 400, IL_DEF.phases), 1)
	assert_eq(BossController.phase_for_hp(133, 400, IL_DEF.phases), 1)
	assert_eq(BossController.phase_for_hp(132, 400, IL_DEF.phases), 2)
	var b: InfiniteLoopBody = _body()
	b.take_hit(268)
	assert_eq(b.hp, 132)
	assert_eq(b.phase_index, 2, "multi-phase jump in one hit")
	assert_eq(b.current_weak_window(), Vector2i(Register.Bit.ATTACK, Register.Bit.DASH), "P3 placeholder A>D (D-S33-10)")


func test_empty_pools_keep_the_fsm_in_gap_with_no_tell() -> void:
	var b: InfiniteLoopBody = _body()
	watch_signals(EventBus)
	_start(b)
	for i: int in 1000:
		_tick(b)
		assert_eq(b.state, BossController.BossState.GAP)
	assert_null(b.current)
	assert_signal_emit_count(EventBus, "boss_tell_started", 0)


# --- AC 10: zero RNG (D-S33-12a) ---

func test_draws_nothing_from_the_sim_rng() -> void:
	var b: InfiniteLoopBody = _body(_health(), false)
	_player_px = Arena.SPAWN_PX
	var before: int = _ctx.rng.state
	_tick(b, 100)
	_start(b)
	_tick(b, 1000)
	b.take_hit(150) # a phase change and a ROAR on the way
	_tick(b, 200)
	assert_eq(_ctx.rng.state, before, "no RNG draw over 1300 ticks")


# --- D1, D3: the ring view (presentation helpers, reads only) ---

func test_ring_glyphs_and_counter() -> void:
	assert_eq(BossView.ring_glyph(0), ";", "the loop condition at the junction")
	assert_eq(BossView.ring_glyph(1), "}")
	assert_eq(BossView.ring_glyph(2), "{")
	assert_eq(BossView.ring_glyph(23), "}")
	var braces: int = 0
	for k: int in range(1, 24):
		braces += 1 if BossView.ring_glyph(k) in ["{", "}"] else 0
	assert_eq(braces, 23)
	assert_eq(BossView.counter_text(0), "i = 0")
	assert_eq(BossView.counter_text(12), "i = 12")
	var b: InfiniteLoopBody = _body()
	var c: Vector2 = BossView.counter_centre(b.body_center_px, b.radius_px())
	assert_lt(c.y, b.body_center_px.y, "above the centre")
	assert_gt(c.y, b.body_center_px.y - b.radius_px(), "inside the ring (D-S33-23)")
	assert_gte(c.y - GlyphFont.CELL / 2.0, 0.0, "inside the arena at spawn")


func test_patched_stack_is_clamped_to_the_arena_top() -> void:
	var line_h: float = GlyphFont.CELL * BossView.GLYPH_SCALE
	var low: Vector2 = BossView.patched_stack_tops(200.0, line_h)
	assert_eq(low.y, 200.0 - line_h - BossView.STACK_GAP - BossView.BAR_HEIGHT, "unclamped: above the tell row")
	assert_eq(low.x, low.y - BossView.STACK_GAP - GlyphFont.CELL * BossView.TAG_SCALE)
	var high: Vector2 = BossView.patched_stack_tops(4.0, line_h)
	assert_eq(high.x, 0.0, "the tag never leaves the arena")
	assert_eq(high.y - high.x, low.y - low.x, "tag and bar move as one block")


func test_boss_view_draws_the_ring_without_writing_it() -> void:
	var b: InfiniteLoopBody = _body()
	_start(b)
	var view := BossView.new()
	add_child_autofree(view)
	view.boss = b
	var travel: int = b.travel_mtiles
	var centre: Vector2 = b.body_center_px
	view.queue_redraw()
	await get_tree().process_frame
	assert_eq(b.travel_mtiles, travel)
	assert_eq(b.body_center_px, centre)
	assert_eq(b.iteration, 1)


# --- Story 4.4 AC 12-13 (D-S44-1): the 5 s start nudge ---

func test_no_shift_for_299_ticks_stays_still() -> void:
	var b: InfiniteLoopBody = _body()
	_tick(b, 299)
	assert_eq(InfiniteLoopBody.START_NUDGE_TICKS, 300, "5 s at 60 Hz")
	assert_false(b.started)
	assert_eq(b.waiting_ticks, 299)
	assert_eq(b.iteration, 0)
	assert_false(b.is_open())


func test_no_shift_for_300_ticks_starts_like_the_first_shift() -> void:
	var b: InfiniteLoopBody = _body()
	var shifted: InfiniteLoopBody = _body()
	_start(shifted) # the first-shift path, for comparison
	_shifts = 0 # back to b's captured count: b sees no shift
	_tick(b, 300)
	assert_true(b.started, "the ring starts on tick 300")
	assert_eq(b.iteration, shifted.iteration, "i = 1, the same start path")
	assert_eq(b.open_left, shifted.open_left, "the `;` opens")
	assert_eq(b.open_ring, InfiniteLoopBody.OUTER)
	assert_eq(b.travel_mtiles, 0, "the gate tick does not spin (D-S33-19)")
	_tick(b)
	assert_gt(b.travel_mtiles, 0, "the ring moves from the next tick")
	assert_eq(b.waiting_ticks, 300, "the count stops once started")


func test_a_shift_at_tick_10_starts_at_10() -> void:
	var b: InfiniteLoopBody = _body()
	_tick(b, 9)
	assert_false(b.started)
	_start(b) # tick 10 sees the shift
	assert_true(b.started)
	assert_eq(b.waiting_ticks, 9, "the shift path does not count")
	assert_eq(b.iteration, 1)
	_tick(b, 400)
	assert_eq(b.iteration >= 1, true)


func test_reset_for_fight_resets_the_nudge() -> void:
	var b: InfiniteLoopBody = _body()
	_tick(b, 250)
	b.reset_for_fight()
	assert_eq(b.waiting_ticks, 0, "a retry starts the 5 s again")
	_tick(b, 299)
	assert_false(b.started)
	_tick(b)
	assert_true(b.started)


func test_the_nudge_counts_only_live_boss_ticks() -> void:
	# The count runs in _tick_body, so anything that stops the boss tick (pause, the Breakpoint
	# freeze, hit-stop: SimClock does not call tick) stops it too; a body that is not ticked never starts.
	var b: InfiniteLoopBody = _body()
	_tick(b, 100)
	assert_eq(b.waiting_ticks, 100)
	b.set_active(false)
	_tick(b, 500)
	assert_eq(b.waiting_ticks, 100, "an inactive boss does not count")
	assert_false(b.started)
