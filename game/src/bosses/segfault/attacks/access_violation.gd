extends BossAttack
## Segfault, Access Violation (Story 6.3, FR42, D-S63-3): phases 1-3. TELL (30 frames): the claw
## origin (the body's lower edge at its x) and the sweep rectangle are locked at TELL entry, and the
## claw arc plus the rectangle at its exact size (SWEEP_TILES, 6 x 2) are drawn. The rectangle runs
## SWEEP_TILES.x tiles from the claw origin toward the aim's horizontal side; its rows are the aim's
## row and the one below, clamped into the play area. ACTIVE (12 frames): a player centre inside the
## locked rectangle takes 1 HP through the body's contact path. RECOVERY (50 frames): nothing.
## Aims only through ctx.target_position() (the player or a live Ghost Echo decoy, NP-3); draws no
## RNG (D-S52-4).

## D-S63-3: the sweep's reach (tiles long, tiles tall).
const SWEEP_TILES := Vector2i(6, 2)
## The claw origin sits this many tiles below the body centre (half the 4-tile body).
const CLAW_DROP_TILES := 2.0
## Points of the drawn claw arc (presentation).
const ARC_POINTS := 8

## The claw origin and the sweep rectangle (arena-local px), locked at TELL entry.
var origin_px: Vector2 = Vector2.ZERO
var sweep: Rect2 = Rect2()
## True between TELL entry and RECOVERY / cancel / reset.
var armed: bool = false


func on_tell(ctx: ArenaContext) -> void:
	if ctx == null: # a body set up without an arena (unit tests): nothing to aim at
		reset()
		return
	origin_px = claw_origin()
	sweep = sweep_rect(origin_px, ctx.target_position())
	armed = true


func on_recovery(_ctx: ArenaContext) -> void:
	armed = false


func on_cancel(_ctx: ArenaContext) -> void:
	reset()


func reset() -> void:
	origin_px = Vector2.ZERO
	sweep = Rect2()
	armed = false


## The player's centre inside the locked rectangle (edges included), ACTIVE only (AC 16).
func hazard_hit(p: Vector2) -> bool:
	if not armed or not is_live():
		return false
	return p.x >= sweep.position.x and p.y >= sweep.position.y and p.x <= sweep.end.x and p.y <= sweep.end.y


## TELL: the `!` over the claw origin.
func tell_marks() -> PackedVector2Array:
	if armed and _in_state(BossController.BossState.TELL):
		return PackedVector2Array([origin_px])
	return PackedVector2Array()


## TELL and ACTIVE: the sweep rectangle at its exact size (AC 15).
func hazard_rects() -> Array[Rect2]:
	if armed and (_in_state(BossController.BossState.TELL) or _in_state(BossController.BossState.ACTIVE)):
		return [sweep]
	return []


## TELL: the claw arc, a polyline from the claw origin bowing down to the rectangle's near top edge
## (AC 14, presentation only). Empty outside TELL.
func claw_arc() -> PackedVector2Array:
	if not armed or not _in_state(BossController.BossState.TELL):
		return PackedVector2Array()
	return arc_points(origin_px, sweep)


## The claw origin and the rectangle's four corners against `ctx` (AC 19).
func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	if ctx == null:
		return PackedVector2Array()
	var o: Vector2 = claw_origin()
	var r: Rect2 = sweep_rect(o, ctx.target_position())
	return PackedVector2Array([o, r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end])


func _in_state(s: BossController.BossState) -> bool:
	var b: BossController = boss()
	return b != null and b.state == s and b.current_attack() == self


## The claw origin: the body's lower edge at the body's x, clamped into the play area.
func claw_origin() -> Vector2:
	var b: BossController = boss()
	var centre: Vector2 = b.body_center_px if b != null else Arena.play_area().get_center()
	return Arena.clamp_to_play_area(centre + Vector2(0.0, CLAW_DROP_TILES * Const.TILE_PX))


## D-S63-3: the 6 x 2-tile sweep from `origin` toward `aim`'s horizontal side, on `aim`'s row and
## the one below, shifted so it lies wholly in the play area. Pure.
static func sweep_rect(origin: Vector2, aim: Vector2) -> Rect2:
	var area: Rect2 = Arena.play_area()
	var size := Vector2(SWEEP_TILES * Const.TILE_PX)
	var x: float = origin.x if aim.x >= origin.x else origin.x - size.x
	var row: int = floori(clampf(aim.y, area.position.y, area.end.y - 1.0) / Const.TILE_PX)
	var y: float = row * Const.TILE_PX
	x = clampf(x, area.position.x, area.end.x - size.x)
	y = clampf(y, area.position.y, area.end.y - size.y)
	return Rect2(Vector2(x, y), size)


## The claw arc: a quadratic curve from `origin` to the middle of `rect`'s top edge, bowed toward
## the rectangle's far side. Pure.
static func arc_points(origin: Vector2, rect: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var target := Vector2(rect.get_center().x, rect.position.y)
	var control := Vector2(target.x, origin.y)
	for i: int in ARC_POINTS + 1:
		var t: float = float(i) / ARC_POINTS
		out.append(origin.lerp(control, t).lerp(control.lerp(target, t), t))
	return out
