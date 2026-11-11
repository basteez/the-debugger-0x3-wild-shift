extends BossAttack
## Null Pointer, Pointer Grab (Story 5.2, FR39, D-S52-2, D-S52-9): phases 1-2. TELL (40 frames): a
## `*` appears behind the aim, GRAB_OFFSET_TILES against its facing, and the grab circle (radius
## GRAB_RADIUS_TILES) is outlined; the centre is locked at TELL entry, so moving away during the tell
## dodges it. ACTIVE (10 frames): a player centre inside the circle takes 1 HP through the body's
## contact path (PlayerHealth honours invulnerability). RECOVERY (60 frames): nothing; the ghost is
## visible (Story 5.1). The centre is clamped so the whole circle lies in the play area (Pillar 2).
## Aims only through ctx.target_position() / ctx.target_facing() (NP-3); draws no RNG (D-S52-4).

const GRAB_RADIUS_TILES := 1.0
## [design call] D-S52-2: how far behind the aim the `*` sits. Under the radius, so a player who
## ignores the tell is grabbed; any step forward (7 tiles/s over 40 frames) escapes.
const GRAB_OFFSET_TILES := 0.75

## The grab centre (arena-local px), locked at TELL entry.
var centre_px: Vector2 = Vector2.ZERO
## True between TELL entry and RECOVERY / cancel / reset.
var armed: bool = false


func on_tell(ctx: ArenaContext) -> void:
	if ctx == null: # a body set up without an arena (unit tests): nothing to aim at
		reset()
		return
	centre_px = grab_centre(ctx.target_position(), ctx.target_facing())
	armed = true


func on_recovery(_ctx: ArenaContext) -> void:
	armed = false


func on_cancel(_ctx: ArenaContext) -> void:
	reset()


func reset() -> void:
	centre_px = Vector2.ZERO
	armed = false


## The player's centre within GRAB_RADIUS_TILES of the locked centre, ACTIVE only (edge included).
func hazard_hit(p: Vector2) -> bool:
	if not armed or not is_live():
		return false
	var r: float = radius_px()
	return centre_px.distance_squared_to(p) <= r * r


## TELL: the `*` at the grab centre.
func tell_marks() -> PackedVector2Array:
	if armed and _in_state(BossController.BossState.TELL):
		return PackedVector2Array([centre_px])
	return PackedVector2Array()


func tell_glyph() -> String:
	return "*"


## TELL and ACTIVE: the grab circle's outline.
func outline_circle() -> Vector3:
	if armed and (_in_state(BossController.BossState.TELL) or _in_state(BossController.BossState.ACTIVE)):
		return Vector3(centre_px.x, centre_px.y, radius_px())
	return Vector3.ZERO


## The centre and the circle's four extremes against `ctx` (AC 13).
func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	if ctx == null:
		return PackedVector2Array()
	var c: Vector2 = grab_centre(ctx.target_position(), ctx.target_facing())
	var r: float = radius_px()
	return PackedVector2Array([c, c + Vector2(r, 0), c - Vector2(r, 0), c + Vector2(0, r), c - Vector2(0, r)])


func _in_state(s: BossController.BossState) -> bool:
	var b: BossController = boss()
	return b != null and b.state == s and b.current_attack() == self


static func radius_px() -> float:
	return GRAB_RADIUS_TILES * Const.TILE_PX


## The grab centre: GRAB_OFFSET_TILES behind `aim` (against `facing`, normalised for diagonals),
## clamped so the whole circle lies in the play area. Pure.
static func grab_centre(aim: Vector2, facing: Vector2i) -> Vector2:
	var back: Vector2 = -Vector2(facing).normalized() * GRAB_OFFSET_TILES * Const.TILE_PX
	var area: Rect2 = Arena.play_area().grow(-radius_px())
	return (aim + back).clamp(area.position, area.end)
