extends BossAttack
## Infinite Loop, Constrict (Story 3.4, FR35, D-S34-7, D-S34-13, D-S34-21): phases 2-3. TELL: the
## final ring outline is shown at its exact (nominal) size around the aim, clamped into the play
## area; the ring stays where it is. ACTIVE: the ring re-centres on the aim (re-read every tick, the
## GDD's "re-centres on the player") at constrict_chase_tps, never past it, and its radius shrinks in
## integer milli-tiles from the nominal 3820 to constrict_radius_tiles * 1000 over the active frames.
## The whole disc of the current radius is the contact area (it replaces the segments), so walking
## cannot get out; only an invulnerable move does (PlayerHealth honours invulnerability).
## RECOVERY: the nominal radius returns and the body opens the `;` for the recovery (D-S34-18).
## Aims only through ctx.target_position() (NP-3); draws no RNG (D-S34-14). The real player position
## reaches hazard_hit from the body (D-S34-9).

const MILLI := 1000
const TICKS_PER_SECOND := 60

## Aim point at TELL entry (clamped into the play area): the tell outline's centre.
var tell_centre_px: Vector2 = Vector2.ZERO
## ACTIVE ticks run so far (integer, hashed by the replay test).
var elapsed: int = 0


func on_tell(ctx: ArenaContext) -> void:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null:
		return
	elapsed = 0
	tell_centre_px = tell_outline_centre(ctx.target_position(), body.nominal_radius_px())


func on_active(ctx: ArenaContext) -> void:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null or body.current == null:
		return
	var active_frames: int = maxi(body.current.active, 1)
	elapsed = mini(elapsed + 1, active_frames)
	body.set_attack_radius_mtiles(radius_for(elapsed, active_frames, body.nominal_radius_mtiles(), body.ring.constrict_radius_tiles * MILLI))
	var step_px: float = float(body.ring.constrict_chase_tps) * Const.TILE_PX / float(TICKS_PER_SECOND)
	body.chase_centre(Arena.clamp_to_play_area(ctx.target_position()), step_px)


func on_recovery(_ctx: ArenaContext) -> void:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null:
		return
	body.set_attack_radius_mtiles(0)
	if body.current != null:
		body.open_semicolon(body.current.recovery)


## The disc goes with the attack; the body restores the nominal radius in its cancel hook (D5).
func on_cancel(_ctx: ArenaContext) -> void:
	reset()


func reset() -> void:
	tell_centre_px = Vector2.ZERO
	elapsed = 0


## The player's centre inside the disc of the current radius around the ring centre (ACTIVE only).
func hazard_hit(p: Vector2) -> bool:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null or not is_live():
		return false
	var r: float = body.radius_px()
	return body.body_center_px.distance_squared_to(p) <= r * r


func replaces_body_contact() -> bool:
	return is_live()


## TELL: the final outline at nominal size around the aim. ACTIVE: the disc's edge. Else none.
func outline_circle() -> Vector3:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null or body.current_attack() != self:
		return Vector3.ZERO
	if body.state == BossController.BossState.TELL:
		return Vector3(tell_centre_px.x, tell_centre_px.y, body.nominal_radius_px())
	if body.state == BossController.BossState.ACTIVE:
		return Vector3(body.body_center_px.x, body.body_center_px.y, body.radius_px())
	return Vector3.ZERO


## Points on the tell outline against `ctx` (one per segment) and its centre (AC 13).
func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null:
		return PackedVector2Array()
	var r: float = body.nominal_radius_px()
	var c: Vector2 = tell_outline_centre(ctx.target_position(), r)
	var out := PackedVector2Array([c])
	for k: int in body.ring.segments:
		out.append(c + Vector2.from_angle(TAU * float(k) / float(body.ring.segments)) * r)
	return out


## Radius after `tick` of `frames` ACTIVE ticks: linear from `from_mtiles` to `to_mtiles`, integer
## (floor of the shrink). Pure.
static func radius_for(tick: int, frames: int, from_mtiles: int, to_mtiles: int) -> int:
	if frames <= 0:
		return to_mtiles
	@warning_ignore("integer_division")
	return from_mtiles - (from_mtiles - to_mtiles) * clampi(tick, 0, frames) / frames


## The tell outline's centre: the aim, clamped into the play area, then so the whole outline (radius
## plus half a cell) fits (the ring's own clamp, D-S33-7). Pure.
static func tell_outline_centre(target: Vector2, radius_px: float) -> Vector2:
	return InfiniteLoopBody.clamp_centre(Arena.clamp_to_play_area(target), radius_px)
