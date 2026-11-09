class_name InfiniteLoopBody
extends BossController
## Boss 1's body (Story 3.3, FR33, FR34, GDD "Boss 1 — Infinite Loop", D-018, AD-06): a closed ring
## of 24 `{ }` segments that spins in place, speeds up 5% per lap (capped), drifts toward the
## player, and opens its `;` (the loop condition, at the junction) for 90 ticks at each lap start.
## The `;` is the only hurtbox (D-S33-4); every segment is a contact hazard (D-S33-3). The ring
## stays still until the player's first shift of the fight (D-S33-6).
## Motion state is integer (D-S33-2): milli-tiles along the ring plus a remainder, so 8 tiles/s is
## exactly 180 ticks per lap. Positions (centre, segments, `;`) are floats derived from it, used
## for drawing and circle math only, never hashed. Reads the arena only through ArenaContext
## (player_position, read_shift_count; NP-3). No attacks in 3.3 (D-S33-9): the FSM sits in GAP.

const RING_DEF: RingDef = preload("res://data/bosses/infinite_loop/ring_def.tres")
## Spawn centre in tiles (D-S33-18): 5 tiles above the player spawn, then clamped (D-S33-21).
const SPAWN_TILES := Vector2(16, 4)
## Milli-units per unit (D-S33-2).
const MILLI := 1000
const TICKS_PER_SECOND := 60
## Inset of the ring from the play-area edge beyond its radius: half a glyph cell (D-S33-7).
const EDGE_INSET_TILES := 0.5

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

## Unit vectors of the 24 segment angles, rebuilt per tick (no per-tick allocation).
var _units: PackedVector2Array = PackedVector2Array()


## Fight start and retry: the framework reset, then the ring back to its spawn, still, `i = 0`, base
## speed, `;` closed, and the current shift count captured for the start gate (C10).
func reset_for_fight() -> void:
	super.reset_for_fight()
	_units.resize(ring.segments)
	travel_mtiles = 0
	travel_rem = 0
	speed_mtps = ring.base_speed_tps * MILLI
	iteration = 0
	open_left = 0
	started = false
	shift_at_fight_start = _arena.read_shift_count() if _arena != null else 0
	body_center_px = clamp_centre(SPAWN_TILES * Const.TILE_PX, radius_px())
	_rebuild_units()


## One live tick of ring motion (D-S33-14): the start gate, the `;` countdown, the spin with its lap
## starts, the drift. Runs in every live state, ROAR included (D-S33-8); never once DEFEATED
## (BossController.tick stops when inactive).
func _tick_body(_ctx: SimContext) -> void:
	if not started:
		if _arena == null or _arena.read_shift_count() == shift_at_fight_start:
			return
		started = true
		# The gate tick itself does not spin: i = 1 and the `;` opens here, the ring moves from the
		# next tick (D-S33-19), so the first lap is one tick longer than the rest.
		_start_lap(false)
		if Debug.enabled:
			Log.debug(&"boss", "loop started")
		_rebuild_units()
		return
	if open_left > 0:
		open_left -= 1
	var total: int = travel_rem + speed_mtps
	@warning_ignore("integer_division")
	travel_mtiles += total / TICKS_PER_SECOND
	travel_rem = total % TICKS_PER_SECOND
	var lap: int = ring.segments * MILLI
	if travel_mtiles >= lap:
		travel_mtiles -= lap
		_start_lap(true)
	_drift()
	_rebuild_units()


## A lap start: `i` + 1, the `;` opens, and (except the very first) the speed ramps (D-S33-2).
func _start_lap(ramp: bool) -> void:
	iteration += 1
	open_left = ring.open_frames
	if ramp:
		@warning_ignore("integer_division")
		speed_mtps = mini(speed_mtps * (100 + ring.ramp_percent) / 100, ring.speed_cap_tps * MILLI)


## Moves the centre toward the player by the drift step, never past it, then clamps (D-S33-7).
func _drift() -> void:
	if _arena == null:
		return
	var step: float = float(ring.drift_tps) * Const.TILE_PX / float(TICKS_PER_SECOND)
	body_center_px = clamp_centre(body_center_px.move_toward(_arena.player_position(), step), radius_px())


## GDD shared rule (D-S33-8): every phase change resets the speed ramp. The loop keeps its lap
## position, `i` and the `;` state.
func _on_phase_reset() -> void:
	speed_mtps = ring.base_speed_tps * MILLI
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
func touches_player(p: Vector2) -> bool:
	if state == BossState.DEFEATED or _units.size() != ring.segments:
		return false
	var r: float = HitShape.tiles_to_px(ring.contact_radius_tiles)
	var r2: float = r * r
	var rad: float = radius_px()
	for k: int in _units.size():
		if (body_center_px + _units[k] * rad).distance_squared_to(p) <= r2:
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
	return TAU * float(travel_mtiles) / float(ring.segments * MILLI)


## Arena-local centre of segment `k` (0 = the junction, where the `;` sits).
func segment_px(k: int) -> Vector2:
	if k < 0 or k >= _units.size():
		return body_center_px
	return body_center_px + _units[k] * radius_px()


## Arena-local position of the `;` (the junction).
func semicolon_px() -> Vector2:
	return segment_px(0)


func radius_px() -> float:
	return HitShape.tiles_to_px(ring.radius_tiles())


## Speed in whole tiles/s, for tests and the debug log.
func speed_tps() -> float:
	return float(speed_mtps) / float(MILLI)


func _rebuild_units() -> void:
	if _units.size() != ring.segments:
		_units.resize(ring.segments)
	var junction: float = junction_angle()
	for k: int in ring.segments:
		_units[k] = Vector2.from_angle(junction + TAU * float(k) / float(ring.segments))


## The nearest centre that keeps the whole ring (radius + half a cell) inside the play area
## (D-S33-7). Pure.
static func clamp_centre(centre: Vector2, ring_radius_px: float) -> Vector2:
	var inset: float = ring_radius_px + EDGE_INSET_TILES * Const.TILE_PX
	var area: Rect2 = Arena.play_area()
	return Vector2(
		clampf(centre.x, area.position.x + inset, area.end.x - inset),
		clampf(centre.y, area.position.y + inset, area.end.y - inset))
