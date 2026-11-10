class_name InfiniteLoopBody
extends BossController
## Boss 1's body (Story 3.3, FR33, FR34, GDD "Boss 1 — Infinite Loop", D-018, AD-06): a closed ring
## of 24 `{ }` segments that spins in place, speeds up 5% per lap (capped), drifts toward the
## player, and opens its `;` (the loop condition, at the junction) for 90 ticks at each lap start.
## The `;` is the only hurtbox (D-S33-4); every segment is a contact hazard (D-S33-3). The ring
## stays still until the player's first shift of the fight (D-S33-6), or until START_NUDGE_TICKS
## live ticks pass without one (Story 4.4, D-S44-1: the same start path, sim ticks only).
## Motion state is integer (D-S33-2): milli-tiles along the ring plus a remainder, so 8 tiles/s is
## exactly 180 ticks per lap. Positions (centre, segments, `;`) are floats derived from it, used
## for drawing and circle math only, never hashed. Reads the arena only through ArenaContext
## (body_contact_position, read_shift_count; NP-3).
## Story 3.4 (D-S34-5, D-S34-9, D-S34-13, D-S34-18, D-S34-22, D-S34-23): Head Rush and Constrict. No
## attack is drawn before the loop starts. While an attack runs (TELL, ACTIVE, RECOVERY) the lap
## clock and the drift stop and only the `;` countdown runs; the `;` closes at TELL entry and each
## attack's recovery opens it once (open_semicolon, `i` + 1). Contact asks the live attack's hazard
## first; Constrict's disc replaces the segments while ACTIVE and shrinks the ring through
## attack_radius_mtiles (integer, hashed). A cut attack restores the nominal ring and closes the `;`.
## Story 3.5 (D-S35-3 to D-S35-16): phase 3. The single-ring fields are the OUTER ring. The Nested Loop
## (forced once as the first phase-3 pick through _pick_candidates) splits it into an outer ring of 16
## and a concentric inner ring of 8 (split_rings); the inner ring spins at min(outer x 150%, cap). After
## the split, lap starts only ramp the speed; a 180-tick ring_timer (runs during attacks, frozen
## only in ROAR; D-S35-24) opens the `;` of next_ring for 90 ticks, alternating outer / inner; an
## attack's recovery opening takes the next turn but does not restart the timer. An expired timer
## waits while a `;` is open or an attack is in TELL / ACTIVE, then fires. The weak window follows the open (or next) ring: outer =
## the phase data window, inner = its reverse. The `;` Spit (semicolon_spit.gd) runs on its own fixed
## 360-tick cycle in phase 3 (not frozen by attacks) and its projectiles are contact hazards here.

const RING_DEF: RingDef = preload("res://data/bosses/infinite_loop/ring_def.tres")
## Spawn centre in tiles (D-S33-18): 5 tiles above the player spawn, then clamped (D-S33-21).
const SPAWN_TILES := Vector2(16, 4)
## Milli-units per unit (D-S33-2).
const MILLI := 1000
const TICKS_PER_SECOND := 60
## Inset of the ring from the play-area edge beyond its radius: half a glyph cell (D-S33-7).
const EDGE_INSET_TILES := 0.5
## Story 3.5: the attack the candidate list forces once per fight (D-S35-3).
const NESTED_LOOP_ID := &"nested_loop"
## Story 3.5: the phase (0-based) where the Spit runs and the per-ring windows apply.
const PHASE_3 := 2
## Ring indices (Story 3.5).
const OUTER := 0
const INNER := 1
## Story 4.4 (D-S44-1): live ticks without a shift after which the ring starts on its own (5 s).
const START_NUDGE_TICKS := 300
const SemicolonSpit := preload("res://src/bosses/infinite_loop/attacks/semicolon_spit.gd")

## The ring numbers (D-S33-15). Tests may swap it before setup.
var ring: RingDef = RING_DEF
## Position of the junction along the ring, milli-tiles in [0, segments * 1000).
var travel_mtiles: int = 0
## Sub-milli-tile remainder of the per-tick advance, 0..59.
var travel_rem: int = 0
## Current spin speed in milli-tiles per second.
var speed_mtps: int = 0
## The `i` counter: lap starts (`;` openings) since the ring started.
var iteration: int = 0
## Ticks the `;` stays open; open while > 0.
var open_left: int = 0
## False until the first shift after fight start (D-S33-6).
var started: bool = false
## ArenaContext.read_shift_count() captured at reset_for_fight.
var shift_at_fight_start: int = 0
## Story 4.4 (D-S44-1): live ticks spent waiting for the first shift; the ring starts at
## START_NUDGE_TICKS. Counts only while not started; reset in reset_for_fight. Frozen with the
## boss tick (pause, Breakpoint, hit-stop).
var waiting_ticks: int = 0
## Story 3.4 (D-S34-7): the ring radius set by an attack (Constrict), milli-tiles; 0 = nominal.
var attack_radius_mtiles: int = 0

## Story 3.5 (C1): true once the Nested Loop split the ring (phase 3).
var split: bool = false
## Inner ring position along its circumference, milli-tiles in [0, inner segments * 1000), and remainder.
var inner_travel_mtiles: int = 0
var inner_travel_rem: int = 0
## The ring whose `;` opens next (OUTER / INNER); the ring whose `;` is open now (-1 none).
var next_ring: int = OUTER
var open_ring: int = -1
## Ticks to the next timed opening after the split (D-S35-6, D-S35-24); stays 0 while it waits.
var ring_timer: int = 0
## Timed openings fired since the ring reset (tests; not hashed).
var timed_openings: int = 0
## True once the Nested Loop was picked this fight (D-S35-3).
var nested_done: bool = false
## The phase-3 `;` Spit (D-S35-8): cycle timer and projectile pool.
var spit: SemicolonSpit = SemicolonSpit.new()

## Unit vectors of the outer segment angles, rebuilt per tick (no per-tick allocation).
var _units: PackedVector2Array = PackedVector2Array()
## Unit vectors of the inner segment angles (empty until the split).
var _inner_units: PackedVector2Array = PackedVector2Array()


## Fight start and retry: the framework reset, then the ring back to its spawn, still, `i = 0`, base
## speed, `;` closed, and the current shift count captured for the start gate (C10).
func reset_for_fight() -> void:
	super.reset_for_fight()
	split = false
	_units.resize(ring.segments)
	_inner_units.resize(0)
	inner_travel_mtiles = 0
	inner_travel_rem = 0
	next_ring = OUTER
	open_ring = -1
	ring_timer = 0
	timed_openings = 0
	nested_done = false
	spit.configure(ring)
	travel_mtiles = 0
	travel_rem = 0
	speed_mtps = ring.base_speed_tps * MILLI
	iteration = 0
	open_left = 0
	started = false
	waiting_ticks = 0
	attack_radius_mtiles = 0
	shift_at_fight_start = _arena.read_shift_count() if _arena != null else 0
	body_center_px = clamp_centre(SPAWN_TILES * Const.TILE_PX, radius_px())
	_rebuild_units()


## One live tick of ring motion (D-S33-14): the start gate, the `;` countdown, the spin with its lap
## starts, the drift. Runs in every live state, ROAR included (D-S33-8); never once DEFEATED
## (BossController.tick stops when inactive).
func _tick_body(_ctx: SimContext) -> void:
	if not started:
		var shifted: bool = _arena != null and _arena.read_shift_count() != shift_at_fight_start
		if not shifted:
			# D-S44-1: no shift yet; after START_NUDGE_TICKS live ticks the ring starts anyway.
			waiting_ticks += 1
			if waiting_ticks < START_NUDGE_TICKS:
				return
		started = true
		# The gate tick itself does not spin: i = 1 and the `;` opens here, the ring moves from the
		# next tick (D-S33-19), so the first lap is one tick longer than the rest.
		_start_lap(false)
		if Debug.enabled:
			Log.debug(&"boss", "loop started (%s)" % ("shift" if shifted else "nudge"))
		_rebuild_units()
		return
	if open_left > 0:
		open_left -= 1
		if open_left == 0:
			open_ring = -1
	_tick_spit() # D-S35-8: the Spit cycle is not frozen by attacks
	_tick_ring_timer()
	if _attack_running(): # D-S34-5: the whole body is the attack; lap clock and drift wait
		return
	var total: int = travel_rem + speed_mtps
	@warning_ignore("integer_division")
	travel_mtiles += total / TICKS_PER_SECOND
	travel_rem = total % TICKS_PER_SECOND
	var lap: int = outer_segments() * MILLI
	if travel_mtiles >= lap:
		travel_mtiles -= lap
		_start_lap(true)
	if split: # D-S35-5: derived speed, same remainder rule, no lap event
		var inner_total: int = inner_travel_rem + inner_speed_mtps()
		@warning_ignore("integer_division")
		inner_travel_mtiles += inner_total / TICKS_PER_SECOND
		inner_travel_rem = inner_total % TICKS_PER_SECOND
		var inner_lap: int = ring.split_inner_segments * MILLI
		if inner_travel_mtiles >= inner_lap:
			inner_travel_mtiles -= inner_lap
	_drift()
	_rebuild_units()


## D-S35-24: the timed openings. The timer runs through attacks (frozen only in ROAR); at zero it
## waits until no `;` is open and no attack is in TELL / ACTIVE, then opens next_ring's `;` and restarts.
func _tick_ring_timer() -> void:
	if not split or state == BossState.ROAR:
		return
	if ring_timer > 0:
		ring_timer -= 1
	if ring_timer > 0 or open_ring >= 0 or state == BossState.TELL or state == BossState.ACTIVE:
		return
	timed_openings += 1
	_open_next_ring(ring.open_frames, true)


## A lap start: `i` + 1, the `;` opens, and (except the very first) the speed ramps (D-S33-2).
## Story 3.5 (D-S35-5): after the split a lap start only ramps (the timed schedule opens the `;`).
func _start_lap(ramp: bool) -> void:
	if not split:
		iteration += 1
		open_left = ring.open_frames
		open_ring = OUTER
	if ramp:
		@warning_ignore("integer_division")
		speed_mtps = mini(speed_mtps * (100 + ring.ramp_percent) / 100, ring.speed_cap_tps * MILLI)


## Moves the centre toward the player by the drift step, never past it, then clamps (D-S33-7).
func _drift() -> void:
	if _arena == null:
		return
	var step: float = float(ring.drift_tps) * Const.TILE_PX / float(TICKS_PER_SECOND)
	body_center_px = clamp_centre(body_center_px.move_toward(_arena.body_contact_position(), step), radius_px())


## True in TELL, ACTIVE and RECOVERY of an attack.
func _attack_running() -> bool:
	return state == BossState.TELL or state == BossState.ACTIVE or state == BossState.RECOVERY


## No attack before the loop starts (D-S34-23): the first shift starts the fight for real.
func _attacks_allowed() -> bool:
	return started


## TELL entry: a lap's `;` closes; the attack's recovery is its one opening (D-S34-22).
## Story 3.5 (D-S35-3): picking the Nested Loop spends it for the fight.
func _on_attack_started() -> void:
	open_left = 0
	open_ring = -1
	if current != null and current.id == NESTED_LOOP_ID:
		nested_done = true


## A cut attack (ROAR, defeat): the nominal ring returns and the `;` closes (D-S34-15).
func _on_attack_cancelled() -> void:
	open_left = 0
	open_ring = -1
	set_attack_radius_mtiles(0)


## Story 3.5 (P9, D-S35-11): defeat clears the Spit and its projectiles.
func _on_defeated() -> void:
	spit.stop()


## An attack's recovery opens the `;` for `frames` ticks: one opening, `i` + 1 (D-S34-18).
## Called by the attack scripts (Head Rush, Constrict) from on_recovery. Story 3.5 (D-S35-6): after
## the split it opens next_ring's `;` and flips the alternation; the timer is not restarted (D-S35-24).
func open_semicolon(frames: int) -> void:
	if frames <= 0:
		return
	if split:
		_open_next_ring(frames, false)
		return
	iteration += 1
	open_left = frames
	open_ring = OUTER
	if Debug.enabled:
		Log.debug(&"boss", "recovery opening i=%d (%d)" % [iteration, frames])


## Story 3.5 (P4): opens next_ring's `;` for `frames` ticks (`i` + 1) and flips the alternation;
## `restart` (timed openings and the split) also restarts the opening timer.
func _open_next_ring(frames: int, restart: bool) -> void:
	open_ring = next_ring
	open_left = frames
	iteration += 1
	next_ring = INNER if next_ring == OUTER else OUTER
	if restart:
		ring_timer = ring.opening_period_frames
	if Debug.enabled:
		Log.debug(&"boss", "%s opening i=%d (%d)" % ["inner" if open_ring == INNER else "outer", iteration, frames])


## Story 3.5 (P2, D-S35-4): the Nested Loop split, idempotent. The outer ring becomes 16 segments at
## the same lap angle, the inner ring of 8 starts at travel 0, both on the body centre (re-clamped with
## the outer radius); the outer `;` opens at once (the first timed opening) and the timer starts.
func split_rings() -> void:
	if split:
		return
	@warning_ignore("integer_division")
	travel_mtiles = travel_mtiles * ring.split_outer_segments / ring.segments
	split = true
	_units.resize(ring.split_outer_segments)
	_inner_units.resize(ring.split_inner_segments)
	inner_travel_mtiles = 0
	inner_travel_rem = 0
	body_center_px = clamp_centre(body_center_px, radius_px())
	next_ring = OUTER
	_open_next_ring(ring.open_frames, true)
	_rebuild_units()
	if Debug.enabled:
		Log.debug(&"boss", "nested loop: split")


## Story 3.5 (AC 15): both rings' segment centres if the ring split now (the split_rings geometry
## from the current centre and lap angle). Allocates; tests and declared_positions only.
func split_positions() -> PackedVector2Array:
	var outer_r: float = HitShape.tiles_to_px(RingDef.split_radius_tiles(ring.split_outer_segments))
	var inner_r: float = HitShape.tiles_to_px(RingDef.split_radius_tiles(ring.split_inner_segments))
	var c: Vector2 = clamp_centre(body_center_px, outer_r)
	var out := PackedVector2Array()
	var a0: float = junction_angle()
	for k: int in ring.split_outer_segments:
		out.append(c + Vector2.from_angle(a0 + TAU * float(k) / float(ring.split_outer_segments)) * outer_r)
	for k: int in ring.split_inner_segments:
		out.append(c + Vector2.from_angle(TAU * float(k) / float(ring.split_inner_segments)) * inner_r)
	return out


## Story 3.5 (P6, D-S35-8): the Spit cycle, phase 3 only, every live tick except ROAR.
func _tick_spit() -> void:
	if phase_index != PHASE_3 or state == BossState.ROAR or _arena == null or not spit.is_running():
		return
	spit.tick(spit_origin_px(), _arena)


## The Spit origin: the junction of the ring that opens next (the outer junction before the split, D-S35-9).
func spit_origin_px() -> Vector2:
	return junction_px(next_ring if split else OUTER)


## Story 3.5 (D-S35-3): in a phase whose pool holds the Nested Loop, the first pick is the Nested Loop
## alone (no RNG draw) until it was picked, then the pool without it.
func _pick_candidates(phase: int) -> PackedInt32Array:
	var pool: PackedInt32Array = super(phase)
	var nested: int = _nested_index()
	if nested < 0 or not pool.has(nested):
		return pool
	if not nested_done:
		return PackedInt32Array([nested])
	var out := PackedInt32Array()
	for at: int in pool:
		if at != nested:
			out.append(at)
	return out


## Cache index of the Nested Loop attack, or -1 (a def without it, e.g. the phase-3 cut).
func _nested_index() -> int:
	for i: int in _defs.size():
		if _defs[i].id == NESTED_LOOP_ID:
			return i
	return -1


## Story 3.5 (P5, D-S35-7): after the split in phase 3, the window of the open ring (or the next one):
## outer = the phase data window, inner = its reverse. Everything else: the data window.
func current_weak_window() -> Vector2i:
	var w: Vector2i = super()
	if phase_index != PHASE_3 or not split:
		return w
	var r: int = open_ring if open_ring >= 0 else next_ring
	return w if r == OUTER else Vector2i(w.y, w.x)


## Sets the attack-driven ring radius in milli-tiles (0 = nominal) and re-clamps the centre with it.
func set_attack_radius_mtiles(r_mtiles: int) -> void:
	attack_radius_mtiles = maxi(r_mtiles, 0)
	body_center_px = clamp_centre(body_center_px, radius_px())


## Moves the centre toward `target` by at most `step_px`, never past it, clamped with the current
## radius (Constrict's chase, D-S34-13).
func chase_centre(target: Vector2, step_px: float) -> void:
	body_center_px = clamp_centre(body_center_px.move_toward(target, step_px), radius_px())


## Story 3.5 (C1): the outer ring's segment count: 24 until the split, then split_outer_segments.
func outer_segments() -> int:
	return ring.split_outer_segments if split else ring.segments


## The nominal (outer) ring radius in whole milli-tiles (24 / 2π tiles -> 3820; 16 / 2π -> 2546 split).
func nominal_radius_mtiles() -> int:
	return roundi(RingDef.split_radius_tiles(outer_segments()) * MILLI)


## The outer ring's current radius in milli-tiles: the attack radius while set, else nominal.
func outer_radius_mtiles() -> int:
	return attack_radius_mtiles if attack_radius_mtiles > 0 else nominal_radius_mtiles()


## The nominal (outer) ring radius in px (attack radius ignored).
func nominal_radius_px() -> float:
	return HitShape.tiles_to_px(RingDef.split_radius_tiles(outer_segments()))


## The inner ring radius in px (8 / 2π tiles); not moved by attacks.
func inner_radius_px() -> float:
	return HitShape.tiles_to_px(RingDef.split_radius_tiles(ring.split_inner_segments))


## Story 3.5 (D-S35-5): the inner ring speed, derived from the outer one each tick, capped.
func inner_speed_mtps() -> int:
	@warning_ignore("integer_division")
	return mini(speed_mtps * ring.split_inner_speed_percent / 100, ring.speed_cap_tps * MILLI)


## GDD shared rule (D-S33-8): every phase change resets the speed ramp. The loop keeps its lap
## position, `i` and the `;` state.
func _on_phase_reset() -> void:
	speed_mtps = ring.base_speed_tps * MILLI
	# Story 3.5 (P9, D-S35-15): projectiles go at every phase change; phase 3 starts the Spit cycle,
	# which does not count during ROAR, so its first shot comes spit_period_frames after ROAR ends.
	if phase_index == PHASE_3:
		spit.start()
	else:
		spit.stop()
	if Debug.enabled:
		Log.debug(&"boss", "loop speed reset")


## The `;` is the only hurtbox (D-S33-4, D-S33-5): only while hittable and open.
func overlaps_shape(shape: HitShape, origin: Vector2, facing: Vector2) -> bool:
	if shape == null or not is_semicolon_hittable():
		return false
	return shape.overlaps(origin, facing, semicolon_px(), HitShape.tiles_to_px(ring.hurt_radius_tiles))


## The `;` while open, the centre otherwise.
func hit_position() -> Vector2:
	return semicolon_px() if is_open() else body_center_px


## Contact (AC 5, D-S33-3): the player's centre inside any segment's circle. Off once DEFEATED.
## Story 3.4 (D-S34-9): the live attack's hazard first; a hazard that replaces the body (Constrict's
## disc) leaves the segments out while ACTIVE.
## Story 3.5 (C3, P7, D-S35-11): the Spit projectiles (0.5-tile circles) and both rings' segments.
func touches_player(p: Vector2) -> bool:
	if state == BossState.DEFEATED or _units.size() != outer_segments():
		return false
	if attack_hazard_hit(p):
		return true
	var r: float = HitShape.tiles_to_px(ring.contact_radius_tiles)
	var r2: float = r * r
	if spit_hit(p, r2):
		return true
	var attack: BossAttack = current_attack()
	if attack != null and state == BossState.ACTIVE and attack.replaces_body_contact():
		return false
	var rad: float = radius_px()
	for k: int in _units.size():
		if (body_center_px + _units[k] * rad).distance_squared_to(p) <= r2:
			return true
	var inner_rad: float = inner_radius_px()
	for k: int in _inner_units.size():
		if (body_center_px + _inner_units[k] * inner_rad).distance_squared_to(p) <= r2:
			return true
	return false


## True when `p` is inside a live Spit projectile's circle of squared radius `r2` (point in circle).
func spit_hit(p: Vector2, r2: float) -> bool:
	for k: int in spit.slot_active.size():
		if spit.slot_active[k] != 0 and SemicolonSpit.mtiles_to_px(spit.slot_pos_mtiles[k]).distance_squared_to(p) <= r2:
			return true
	return false


func is_open() -> bool:
	return open_left > 0


## True when a player hit on the `;` would count: open, and the boss hittable (not ROAR, not
## DEFEATED, live).
func is_semicolon_hittable() -> bool:
	return is_open() and is_hittable() and state != BossState.DEFEATED


## The junction angle in radians (C4): lap position over the radius. Presentation and hit math only.
func junction_angle() -> float:
	return TAU * float(travel_mtiles) / float(outer_segments() * MILLI)


## Story 3.5: the inner ring's junction angle in radians.
func inner_junction_angle() -> float:
	return TAU * float(inner_travel_mtiles) / float(ring.split_inner_segments * MILLI)


## Arena-local centre of outer segment `k` (0 = the junction, where the `;` sits).
func segment_px(k: int) -> Vector2:
	if k < 0 or k >= _units.size():
		return body_center_px
	return body_center_px + _units[k] * radius_px()


## Story 3.5 (C2): arena-local centre of inner segment `k` (the centre before the split).
func inner_segment_px(k: int) -> Vector2:
	if k < 0 or k >= _inner_units.size():
		return body_center_px
	return body_center_px + _inner_units[k] * inner_radius_px()


## Number of inner segments (0 until the split).
func inner_segment_count() -> int:
	return _inner_units.size()


## The junction of ring `r` (OUTER / INNER; the outer one before the split).
func junction_px(r: int) -> Vector2:
	return inner_segment_px(0) if r == INNER and split else segment_px(0)


## Arena-local position of the `;`: the open ring's junction, the outer junction when none is open.
func semicolon_px() -> Vector2:
	return junction_px(open_ring if open_ring == INNER else OUTER)


## The ring radius in px: the attack radius while one is set (Constrict), else nominal.
func radius_px() -> float:
	if attack_radius_mtiles > 0:
		return HitShape.tiles_to_px(float(attack_radius_mtiles) / float(MILLI))
	return nominal_radius_px()


## Speed in whole tiles/s, for tests and the debug log.
func speed_tps() -> float:
	return float(speed_mtps) / float(MILLI)


func _rebuild_units() -> void:
	var n: int = outer_segments()
	if _units.size() != n:
		_units.resize(n)
	var junction: float = junction_angle()
	for k: int in n:
		_units[k] = Vector2.from_angle(junction + TAU * float(k) / float(n))
	if not split:
		return
	var m: int = ring.split_inner_segments
	if _inner_units.size() != m:
		_inner_units.resize(m)
	var inner_junction: float = inner_junction_angle()
	for k: int in m:
		_inner_units[k] = Vector2.from_angle(inner_junction + TAU * float(k) / float(m))


## The nearest centre that keeps the whole ring (radius + half a cell) inside the play area
## (D-S33-7). Pure.
static func clamp_centre(centre: Vector2, ring_radius_px: float) -> Vector2:
	var inset: float = ring_radius_px + EDGE_INSET_TILES * Const.TILE_PX
	var area: Rect2 = Arena.play_area()
	return Vector2(
		clampf(centre.x, area.position.x + inset, area.end.x - inset),
		clampf(centre.y, area.position.y + inset, area.end.y - inset))
