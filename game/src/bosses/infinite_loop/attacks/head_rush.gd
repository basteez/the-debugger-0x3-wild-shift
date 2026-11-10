extends BossAttack
## Infinite Loop, Head Rush (Story 3.4, FR35, D-022, D-S34-6): phases 1-3. TELL: the head's origin
## and direction are fixed (origin on the nominal ring on the side facing the aim, direction from the
## origin to the aim), and BossView shows a `!` over the origin. ACTIVE: the head, a single `{` cell
## with a 0.5-tile contact circle, travels head_charge_tiles in a straight line at an integer
## milli-tile step per tick (10 tiles / 40 frames = 250), stopped where it would leave the play area.
## RECOVERY: the head retracts and the body opens the `;` for the recovery (D-S34-18).
## Aims only through ctx.target_position() (NP-3); draws no RNG (D-S34-14). Hits on the head do
## nothing (only the `;` is a hurtbox, D-S33-5). Numbers: timings from attack_head_rush.tres, the
## charge and contact radius from the ring's RingDef (D-S34-8).

const MILLI := 1000

## Head origin in arena-local px (float: presentation and contact only, never hashed).
var origin_px: Vector2 = Vector2.ZERO
## Unit direction of the charge, fixed at TELL entry.
var direction: Vector2 = Vector2.ZERO
## Milli-tiles the head has travelled (integer, hashed by the replay test).
var travelled_mtiles: int = 0
## Milli-tiles added per ACTIVE tick (charge / active frames, computed at TELL entry).
var step_mtiles: int = 0
## Longest travel that keeps the head inside the play area (<= the full charge), milli-tiles.
var max_travel_mtiles: int = 0


func on_tell(ctx: ArenaContext) -> void:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null:
		return
	var geometry: Array = aim_geometry(body, ctx.target_position())
	origin_px = geometry[0]
	direction = geometry[1]
	travelled_mtiles = 0
	var active_frames: int = maxi(body.current.active if body.current != null else 1, 1)
	@warning_ignore("integer_division")
	step_mtiles = body.ring.head_charge_tiles * MILLI / active_frames
	max_travel_mtiles = mini(body.ring.head_charge_tiles * MILLI, travel_limit_mtiles(origin_px, direction))


func on_active(_ctx: ArenaContext) -> void:
	travelled_mtiles = mini(travelled_mtiles + step_mtiles, max_travel_mtiles)


func on_recovery(_ctx: ArenaContext) -> void:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body != null and body.current != null:
		body.open_semicolon(BossController.effective_recovery(body.current, body.breakpoint_on))


func on_cancel(_ctx: ArenaContext) -> void:
	reset()


func reset() -> void:
	origin_px = Vector2.ZERO
	direction = Vector2.ZERO
	travelled_mtiles = 0
	step_mtiles = 0
	max_travel_mtiles = 0


## The head's centre now (arena-local px).
func head_px() -> Vector2:
	return origin_px + direction * (float(travelled_mtiles) / float(MILLI) * Const.TILE_PX)


## The player's centre inside the head's 0.5-tile circle, while ACTIVE only (the body asks then).
func hazard_hit(p: Vector2) -> bool:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null or not is_live():
		return false
	var r: float = HitShape.tiles_to_px(body.ring.contact_radius_tiles)
	return head_px().distance_squared_to(p) <= r * r


func hazard_positions() -> PackedVector2Array:
	return PackedVector2Array([head_px()]) if is_live() else PackedVector2Array()


## The `!` hangs over the origin during TELL.
func tell_marks() -> PackedVector2Array:
	var b: BossController = boss()
	if b == null or b.state != BossController.BossState.TELL or b.current_attack() != self:
		return PackedVector2Array()
	return PackedVector2Array([origin_px])


## The origin (tell) and the clamped endpoint of a charge against `ctx` from the body's current
## centre (AC 13).
func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	var body: InfiniteLoopBody = boss() as InfiniteLoopBody
	if body == null:
		return PackedVector2Array()
	var geometry: Array = aim_geometry(body, ctx.target_position())
	var o: Vector2 = geometry[0]
	var d: Vector2 = geometry[1]
	var travel: int = mini(body.ring.head_charge_tiles * MILLI, travel_limit_mtiles(o, d))
	return PackedVector2Array([o, o + d * (float(travel) / float(MILLI) * Const.TILE_PX)])


## [origin, direction] for a charge at `target` from `body` (D-S34-6): the aim clamped into the play
## area; the origin on the nominal ring facing the aim, clamped; the direction from origin to aim
## (straight down when the aim gives none). Pure apart from reading the body's centre and radius.
static func aim_geometry(body: InfiniteLoopBody, target: Vector2) -> Array:
	var aim: Vector2 = Arena.clamp_to_play_area(target)
	var centre: Vector2 = body.body_center_px
	var outward: Vector2 = (aim - centre).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2.DOWN
	var o: Vector2 = Arena.clamp_to_play_area(centre + outward * body.nominal_radius_px())
	var d: Vector2 = (aim - o).normalized()
	if d == Vector2.ZERO:
		d = outward
	return [o, d]


## The longest travel (whole milli-tiles, floored) from `o` along unit `d` that stays inside the
## play area, edges included. Pure.
static func travel_limit_mtiles(o: Vector2, d: Vector2) -> int:
	var area: Rect2 = Arena.play_area()
	var t: float = INF
	if d.x > 0.0:
		t = minf(t, (area.end.x - o.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (area.position.x - o.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (area.end.y - o.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (area.position.y - o.y) / d.y)
	if t == INF:
		return 0
	return maxi(floori(t / Const.TILE_PX * MILLI), 0)
