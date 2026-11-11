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
## counted in _tick_body and never written by presentation (AC 9). Story 5.1 (D-S51-8) and Story 5.2
## (D-S52-1): the ghost itself is never a contact hazard; only a live attack's hazard is
## (attack_hazard_hit: Pointer Grab and Null Rain, ACTIVE only).
## Story 5.3 (D-S53-2..4, D-S53-7): the body owns the Dangling Pointers decoys as sim data (integer
## milli-tile spots, no scene nodes): spots planned from SimContext.rng on the first TELL tick of
## Dangling Pointers (the attack only requests the plan), spawned at its ACTIVE, re-cast every
## RECAST_TICKS live ticks (a CAST_FLICKER_FRAMES flicker, then the spawn), capped at DECOY_CAP,
## dispelled by a player hit (decoy_hit, a DISPEL_FLASH_FRAMES flash). Decoys never hum, are never
## drawn as ghosts and are not part of visible_now(): Watch (Story 5.4) reveals the real body only.
## The whiff range (NullPointerException, D-S53-6) is WHIFF_RANGE_TILES.

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
## Story 5.3 (D-S53-1..6): tunable decoy and whiff constants (open questions: playtest them in 7.8).
const DANGLING_ID := &"dangling_pointers"
## Decoys alive at once (D-S53-4) and spots per cast (GDD: two decoy bullets).
const DECOY_CAP := 3
const DECOYS_PER_CAST := 2
## The re-cast cadence in live ticks (15 s, D-S53-1) and the re-cast flicker (same as the tell, 30).
const RECAST_TICKS := 900
const CAST_FLICKER_FRAMES := 30
## The dispel flash in sim frames (AC 11).
const DISPEL_FLASH_FRAMES := 10
## A decoy's hit radius for decoy_hit, in milli-tiles (1 tile, like the body hurtbox, D-S53-3).
const DECOY_RADIUS_MTILES := 1000
## Spot rule (D-S53-2): inset from every wall, minimum spacing, tries per spot (milli-tiles).
const SPOT_INSET_MTILES := 2000
const SPOT_MIN_DIST_MTILES := 4000
const SPOT_TRIES := 32
## NullPointerException (D-S53-6): a whiffed slash stuns within this range, centre to centre.
const WHIFF_RANGE_TILES := 4

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
## Story 5.3: live decoys (milli-tiles). Sim objects owned here, never nodes (D-S53-3).
var decoys: Array[Vector2i] = []
## Dangling Pointers' planned spots (milli-tiles): planned on its first TELL tick, spawned at ACTIVE.
var planned: Array[Vector2i] = []
## The re-cast's spots (milli-tiles) while they flicker, and the flicker's frames left.
var recast_spots: Array[Vector2i] = []
var recast_flicker_left: int = 0
## Live ticks to the next re-cast; 0 = not armed (armed at Dangling Pointers' ACTIVE).
var recast_left: int = 0
## Dispel flashes: spot (milli-tiles) and frames left, parallel.
var flash_spots: Array[Vector2i] = []
var flash_left: PackedInt32Array = PackedInt32Array()
## Set by Dangling Pointers' on_tell; consumed by the next TELL tick's plan (the attack draws no RNG).
var _plan_requested: bool = false
## True from Dangling Pointers' on_tell to its first ACTIVE tick (the spawn and the timer arm once).
var _cast_pending: bool = false


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
	clear_decoys()
	_sync_px()


## One live tick (D-S33-14 order: after the Patched tick, before the FSM step): the reveal timers
## count down, the column falls, and outside an attack's ACTIVE / RECOVERY frames the ghost drifts.
func _tick_body(ctx: SimContext) -> void:
	if hit_reveal_left > 0:
		hit_reveal_left -= 1
	if pass_reveal_left > 0:
		pass_reveal_left -= 1
	trail_tick = (trail_tick + 1) % TRAIL_FALL_TICKS
	_tick_decoys(ctx.rng)
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


## D-S51-8, D-S52-1: the ghost is not a contact hazard; only a live attack's hazard is (ACTIVE only).
func touches_player(p: Vector2) -> bool:
	return attack_hazard_hit(p)


# --- Story 5.3: Dangling Pointers decoys (D-S53-2..7) ---

## Story 5.3 (D-S53-7): drops every decoy, planned spot, flicker, flash and the re-cast timer.
func clear_decoys() -> void:
	decoys.clear()
	planned.clear()
	recast_spots.clear()
	recast_flicker_left = 0
	recast_left = 0
	flash_spots.clear()
	flash_left.clear()
	_plan_requested = false
	_cast_pending = false


## D-S53-7: a phase change (ROAR) clears the decoys.
func _on_phase_reset() -> void:
	clear_decoys()


## D-S53-7: the defeat clears the decoys.
func _on_defeated() -> void:
	clear_decoys()


## Dangling Pointers' on_tell: plan the spots on the next TELL tick (AC 8). No RNG in the attack.
func request_decoy_plan() -> void:
	planned.clear()
	_plan_requested = true
	_cast_pending = true


## Dangling Pointers' on_cancel / reset: the planned spots are dropped (AC 12).
func clear_planned() -> void:
	planned.clear()
	_plan_requested = false
	_cast_pending = false


## Dangling Pointers' ACTIVE (AC 2): the planned spots become decoys (cap permitting, AC 7) and the
## re-cast timer is armed. Only the first call of a cast spawns (the plan is consumed).
func spawn_planned() -> void:
	if not _cast_pending:
		return
	_spawn(planned)
	planned.clear()
	_plan_requested = false
	_cast_pending = false
	recast_left = RECAST_TICKS


## One live tick of the decoy state (in _tick_body, before the drift). ROAR pauses it (D-S53-4).
func _tick_decoys(rng: RandomNumberGenerator) -> void:
	for i: int in range(flash_left.size() - 1, -1, -1):
		flash_left[i] -= 1
		if flash_left[i] <= 0:
			flash_left.remove_at(i)
			flash_spots.remove_at(i)
	if state == BossState.ROAR:
		return
	if _plan_requested and state == BossState.TELL and current != null and current.id == DANGLING_ID:
		_plan_requested = false
		planned = plan_spots(rng, mini(DECOYS_PER_CAST, _room()))
	if recast_flicker_left > 0:
		recast_flicker_left -= 1
		if recast_flicker_left == 0:
			_spawn(recast_spots)
			recast_spots.clear()
	if recast_left > 0:
		recast_left -= 1
		if recast_left == 0:
			recast_left = RECAST_TICKS # D-S53-4: re-armed at every re-cast, cast or not
			var spots: Array[Vector2i] = plan_spots(rng, mini(DECOYS_PER_CAST, _room()))
			if not spots.is_empty(): # no room: no flicker at all
				recast_spots = spots
				recast_flicker_left = CAST_FLICKER_FRAMES


## Free decoy slots, counting spots already planned or flickering (AC 7).
func _room() -> int:
	return maxi(0, DECOY_CAP - decoys.size() - planned.size() - recast_spots.size())


## Spawns `spots` as decoys, as many as the cap allows (AC 7).
func _spawn(spots: Array[Vector2i]) -> void:
	for p: Vector2i in spots:
		if decoys.size() >= DECOY_CAP:
			return
		decoys.append(p)


## AC 8 (D-S53-2): up to `count` spots drawn from `rng`, each inside the play area inset by
## SPOT_INSET_MTILES, at least SPOT_MIN_DIST_MTILES from the body centre, from each other, from
## every live decoy and from every pending spot; SPOT_TRIES draws per spot, fewer spots if none fit.
func plan_spots(rng: RandomNumberGenerator, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := Vector2i(SPOT_INSET_MTILES, SPOT_INSET_MTILES)
	var hi: Vector2i = Const.ARENA_TILES * MILLI - lo
	var avoid: Array[Vector2i] = [pos_mtiles]
	avoid.append_array(decoys)
	avoid.append_array(planned)
	avoid.append_array(recast_spots)
	for n: int in count:
		for t: int in SPOT_TRIES:
			var p := Vector2i(rng.randi_range(lo.x, hi.x), rng.randi_range(lo.y, hi.y))
			if _far_from_all(p, avoid):
				out.append(p)
				avoid.append(p)
				break
	return out


static func _far_from_all(p: Vector2i, others: Array[Vector2i]) -> bool:
	var min_sq: int = SPOT_MIN_DIST_MTILES * SPOT_MIN_DIST_MTILES
	for o: Vector2i in others:
		var d: Vector2i = p - o
		if d.x * d.x + d.y * d.y < min_sq:
			return false
	return true


## AC 10 (D-S53-5): dispels every live decoy the hit shape overlaps (radius DECOY_RADIUS_MTILES,
## the boss hurtbox test) and starts its flash. Returns the number dispelled. No damage, no Patched.
func decoy_hit(shape: HitShape, origin: Vector2, facing: Vector2) -> int:
	if shape == null or not alive():
		return 0
	var r: float = mtiles_to_px(DECOY_RADIUS_MTILES)
	var n: int = 0
	for i: int in range(decoys.size() - 1, -1, -1):
		if shape.overlaps(origin, facing, spot_px(decoys[i]), r):
			flash_spots.append(decoys[i])
			flash_left.append(DISPEL_FLASH_FRAMES)
			decoys.remove_at(i)
			n += 1
	return n


## D-S53-6: a whiffed slash stuns within WHIFF_RANGE_TILES (centre to centre).
func whiff_stun_range_px() -> float:
	return float(WHIFF_RANGE_TILES * Const.TILE_PX)


## Arena-local px of a milli-tile spot (drawing, overlap math). Pure.
static func spot_px(p: Vector2i) -> Vector2:
	return Vector2(p) * Const.TILE_PX / float(MILLI)


static func mtiles_to_px(m: int) -> float:
	return m * Const.TILE_PX / float(MILLI)


static func _to_px(spots: Array[Vector2i]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2i in spots:
		out.append(spot_px(p))
	return out


## Live decoys in px (tests and the dispel; never drawn, AC 9).
func decoy_positions() -> PackedVector2Array:
	return _to_px(decoys)


## Dangling Pointers' planned spots in px (its tell marks).
func planned_positions() -> PackedVector2Array:
	return _to_px(planned)


## The re-cast's flickering spots in px (empty when no re-cast flickers).
func recast_flicker_positions() -> PackedVector2Array:
	return _to_px(recast_spots) if recast_flicker_left > 0 else PackedVector2Array()


## The dispel flashes in px (AC 11).
func dispel_flash_positions() -> PackedVector2Array:
	return _to_px(flash_spots)
