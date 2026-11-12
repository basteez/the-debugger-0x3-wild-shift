class_name NullPointerBody
extends BossController
## Boss 2's body (Story 5.1, FR37, FR23, GDD "Boss 2 — Null Pointer", AD-06): a ghost of `null`
## glyphs that is invisible except during an attack's ACTIVE and RECOVERY frames, while Watch is
## held, for HIT_REVEAL_FRAMES after a player hit and for PASS_REVEAL_FRAMES after Echo Dash passes
## through it. It drifts at 4 tiles/s in a direction re-picked from SimContext.rng every
## DRIFT_REPICK_TICKS ticks, reflected at the play-area edges (D-S51-1). A column of TRAIL_GLYPHS
## falling `null` glyphs follows it (D-S51-2); the hum (presentation, NullPointerHum) follows
## body_center_px. Motion state is integer (D-S33-2 style): milli-tiles plus a per-axis remainder;
## body_center_px is derived from it for drawing and circle math only. Reveal timers are sim state,
## counted in _tick_body and never written by presentation (AC 9). No attacks yet (5.2, 5.3): the
## phase pools are empty and the FSM sits in GAP (D-S33-9). Story 5.1 (D-S51-8): the ghost itself is
## not a contact hazard; only a live attack's hazard is (attack_hazard_hit, none until 5.2).

## Milli-units per unit (D-S33-2).
const MILLI := 1000
const TICKS_PER_SECOND := 60
## GDD idle drift: 4 tiles/s, in milli-tiles per second.
const DRIFT_SPEED_MTPS := 4000
## D-S51-1: the drift direction is re-picked every this many live ticks.
const DRIFT_REPICK_TICKS := 90
## The drift directions: 16 unit vectors (k * 22.5 degrees) in milli-units, integer (D-S51-1).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1000, 0), Vector2i(924, 383), Vector2i(707, 707), Vector2i(383, 924),
	Vector2i(0, 1000), Vector2i(-383, 924), Vector2i(-707, 707), Vector2i(-924, 383),
	Vector2i(-1000, 0), Vector2i(-924, -383), Vector2i(-707, -707), Vector2i(-383, -924),
	Vector2i(0, -1000), Vector2i(383, -924), Vector2i(707, -707), Vector2i(924, -383),
]
## GDD reveal lengths in sim frames: the hit flicker and the Echo Dash pass-through.
const HIT_REVEAL_FRAMES := 10
const PASS_REVEAL_FRAMES := 60
## D-S51-2: the falling `null` column: glyph count, one tile apart, 1 tile per TRAIL_FALL_TICKS.
const TRAIL_GLYPHS := 4
const TRAIL_FALL_TICKS := 15
## Spawn centre in tiles: 5 tiles above the player spawn, like the Infinite Loop (D-S33-18).
const SPAWN_TILES := Vector2i(16, 4)

## Body centre in milli-tiles (arena-local); body_center_px is derived from it.
var pos_mtiles: Vector2i = Vector2i.ZERO
## Sub-milli-tile remainder per axis of the per-tick advance (milli-units of milli-tiles).
var drift_rem: Vector2i = Vector2i.ZERO
## The current drift direction (an entry of DIRECTIONS, its signs flipped by reflections).
var drift_dir: Vector2i = Vector2i.ZERO
## Live ticks until the next direction pick; 0 = pick on the next drifting tick.
var drift_timer: int = 0
## Sim frames left of the hit flicker (AC 5) and of the pass-through reveal (AC 6).
var hit_reveal_left: int = 0
var pass_reveal_left: int = 0
## Watch held (AC 7). Story 5.4 drives it; in 5.1 only tests do. Read by visible_now().
var watch_held: bool = false
## The falling column's phase, 0..TRAIL_FALL_TICKS-1 (AC 12).
var trail_tick: int = 0


## Fight start and retry: the framework reset, then the ghost back to its spawn, no direction yet,
## every reveal timer cleared, Watch released, the column at its top.
func reset_for_fight() -> void:
	super.reset_for_fight()
	pos_mtiles = clamp_mtiles(SPAWN_TILES * MILLI)
	drift_rem = Vector2i.ZERO
	drift_dir = Vector2i.ZERO
	drift_timer = 0
	hit_reveal_left = 0
	pass_reveal_left = 0
	watch_held = false
	trail_tick = 0
	_sync_px()


## One live tick (D-S33-14 order: after the Patched tick, before the FSM step): the reveal timers
## count down, the column falls, and outside an attack's ACTIVE / RECOVERY frames the ghost drifts.
func _tick_body(ctx: SimContext) -> void:
	if hit_reveal_left > 0:
		hit_reveal_left -= 1
	if pass_reveal_left > 0:
		pass_reveal_left -= 1
	trail_tick = (trail_tick + 1) % TRAIL_FALL_TICKS
	if state == BossState.ACTIVE or state == BossState.RECOVERY:
		return
	_drift(ctx.rng)


## D-S51-1: pick a direction when the timer runs out, advance by DRIFT_SPEED_MTPS / 60 per tick
## (integer, remainder kept), reflect at the edges of the inset play area.
func _drift(rng: RandomNumberGenerator) -> void:
	if drift_timer <= 0:
		drift_dir = DIRECTIONS[rng.randi_range(0, DIRECTIONS.size() - 1)]
		drift_timer = DRIFT_REPICK_TICKS
	drift_timer -= 1
	var lo: Vector2i = min_mtiles()
	var hi: Vector2i = max_mtiles()
	var nx: Vector3i = _step_axis(pos_mtiles.x, drift_rem.x, drift_dir.x, lo.x, hi.x)
	var ny: Vector3i = _step_axis(pos_mtiles.y, drift_rem.y, drift_dir.y, lo.y, hi.y)
	pos_mtiles = Vector2i(nx.x, ny.x)
	drift_rem = Vector2i(nx.y, ny.y)
	drift_dir = Vector2i(nx.z, ny.z)
	_sync_px()


## One axis of the drift: (position, remainder, direction) after one tick. Pure.
static func _step_axis(p: int, rem: int, dir: int, lo: int, hi: int) -> Vector3i:
	const PER_TICK := MILLI * TICKS_PER_SECOND
	var total: int = rem + DRIFT_SPEED_MTPS * dir
	@warning_ignore("integer_division")
	var step: int = total / PER_TICK
	rem = total - step * PER_TICK
	p += step
	if p < lo:
		p = mini(2 * lo - p, hi)
		dir = -dir
		rem = -rem
	elif p > hi:
		p = maxi(2 * hi - p, lo)
		dir = -dir
		rem = -rem
	return Vector3i(p, rem, dir)


## The lowest centre (milli-tiles) that keeps the body circle inside the play area.
func min_mtiles() -> Vector2i:
	var r: int = radius_mtiles()
	return Vector2i(r, r)


## The highest centre (milli-tiles) that keeps the body circle inside the play area.
func max_mtiles() -> Vector2i:
	var r: int = radius_mtiles()
	return Vector2i(Const.ARENA_TILES.x * MILLI - r, Const.ARENA_TILES.y * MILLI - r)


## The body radius in milli-tiles (BossDef.body_radius_tiles, D-S51-5).
func radius_mtiles() -> int:
	return roundi((def.body_radius_tiles if def != null else 1.0) * MILLI)


func clamp_mtiles(p: Vector2i) -> Vector2i:
	return p.clamp(min_mtiles(), max_mtiles())


func _sync_px() -> void:
	body_center_px = Vector2(pos_mtiles) * Const.TILE_PX / float(MILLI)


## AC 4-7, 9: true when the ghost is drawn. A pure read of sim state: an attack's ACTIVE or
## RECOVERY frames, a running reveal timer, Watch held. D-S51-6: shown once DEFEATED (the bug is
## caught; the fixed-line reassembly for this boss is later work).
func visible_now() -> bool:
	if def == null:
		return false
	if state == BossState.DEFEATED:
		return true
	return state == BossState.ACTIVE or state == BossState.RECOVERY \
			or hit_reveal_left > 0 or pass_reveal_left > 0 or watch_held


## AC 7: Watch held or released (Story 5.4's skill; tests in 5.1).
func set_watch_held(held: bool) -> void:
	watch_held = held


## AC 5: a player hit landed: visible for HIT_REVEAL_FRAMES sim frames (never shortens a longer one).
func reveal_for_hit() -> void:
	hit_reveal_left = maxi(hit_reveal_left, HIT_REVEAL_FRAMES)


## AC 6: Echo Dash passed through: visible for PASS_REVEAL_FRAMES sim frames.
func on_pass_through() -> void:
	if not _reveal_allowed():
		return
	pass_reveal_left = maxi(pass_reveal_left, PASS_REVEAL_FRAMES)


## CombatResolver's hit hook (BossController virtual).
func on_player_hit() -> void:
	if not _reveal_allowed():
		return
	reveal_for_hit()


## Review patch: a hit or pass that cannot count (inactive, roaring, defeated) reveals nothing.
func _reveal_allowed() -> bool:
	return active and state != BossState.DEFEATED and state != BossState.ROAR


## True while the hum plays and the column falls: a live, undefeated fight.
func alive() -> bool:
	return def != null and active and state != BossState.DEFEATED


## AC 12: the centres of the falling `null` glyphs, top first: one tile apart, starting one tile
## under the body centre, shifted down by trail_tick / TRAIL_FALL_TICKS of a tile (wraps to the top).
## Review patch: when the column would not fit below the body (bottom of the play area) it hangs
## above it instead, so the locating cue never vanishes. Floats for drawing only.
func trail_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var fall: float = float(trail_tick) / float(TRAIL_FALL_TICKS)
	var fits_below: bool = body_center_px.y + (TRAIL_GLYPHS + 1) * Const.TILE_PX <= Arena.play_area().end.y
	for k: int in TRAIL_GLYPHS:
		var slot: float = 1.0 + k + fall if fits_below else -(TRAIL_GLYPHS - k) + fall
		out.append(body_center_px + Vector2(0.0, slot * Const.TILE_PX))
	return out


## D-S51-8: the ghost is not a contact hazard; only a live attack's hazard is (none until 5.2).
func touches_player(p: Vector2) -> bool:
	return attack_hazard_hit(p)
