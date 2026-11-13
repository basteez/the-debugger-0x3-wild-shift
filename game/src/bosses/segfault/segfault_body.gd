class_name SegfaultBody
extends BossController
## Boss 3's body (Story 6.3, FR40, AD-06, AD-12): a glitch dragon of BODY_TILES (6 x 4) glyph cells
## drawn from GLYPHS (`▓▒░#@!`), living in the top third of the play area (BAND_ROWS rows 0-5).
## D-S63-1: it drifts horizontally at 2 tiles/s, reflecting at the play-area edges inset by its
## half-width; its centre row is fixed at the band's centre, so it never leaves the band. The start
## direction is its only SimContext.rng draw (on the first drifting tick after reset_for_fight).
## D-S51-7 rule: it drifts in every live state except an attack's ACTIVE and RECOVERY. Motion state
## is integer (milli-tiles plus a remainder, D-S33-2); body_center_px is derived for drawing and
## circle math. D-S63-2: hurtbox radius from BossDef.body_radius_tiles (2.0). D-S63-5: the body is a
## contact hazard (framework default circle) and the live attack's hazard is added on top
## (attack_hazard_hit, ACTIVE only). This folder is a cut-ladder leaf (FeatureFlags.segfault): core
## code loads it by path only (Arena.SEGFAULT_BODY_PATH), never by class name.

## Milli-units per unit (D-S33-2).
const MILLI := 1000
const TICKS_PER_SECOND := 60
## GDD: 2 tiles/s, in milli-tiles per second.
const DRIFT_SPEED_MTPS := 2000
## The body's glyph grid in tiles (FR40: about 6 x 4).
const BODY_TILES := Vector2i(6, 4)
## The top third of the 32 x 18 play area: rows 0-5.
const BAND_ROWS := 6
## FR40 glyph set; every cell of DRAGON_ROWS is one of these.
const GLYPHS := "▓▒░#@!"
## The dragon's fixed glyph pattern, row by row (a pure function of the cell, no RNG).
const DRAGON_ROWS: PackedStringArray = [
	"░▒▓▓@!",
	"▒▓##▓▒",
	"░▓▒▒▓░",
	"#!░░!#",
]
## Spawn centre in milli-tiles: the arena's middle column, the band's centre row.
const SPAWN_MTILES := Vector2i(16000, 3000)

## Body centre in milli-tiles (arena-local); body_center_px is derived from it.
var pos_mtiles: Vector2i = SPAWN_MTILES
## Remainder of the per-tick advance, in milli-tiles / 60 (DRIFT_SPEED_MTPS / 60 is not integral).
var drift_rem: int = 0
## -1 left, +1 right, 0 = not picked yet (picked from SimContext.rng on the first drifting tick).
var drift_dir: int = 0


## Fight start and retry (AC 21): the framework reset, then the dragon back to its spawn with no
## direction (the next drifting tick re-seeds it from the fight's RNG).
func reset_for_fight() -> void:
	super.reset_for_fight()
	pos_mtiles = SPAWN_MTILES
	drift_rem = 0
	drift_dir = 0
	_sync_px()


## One live tick (AC 8): no drift during an attack's ACTIVE and RECOVERY.
func _tick_body(ctx: SimContext) -> void:
	if state == BossState.ACTIVE or state == BossState.RECOVERY:
		return
	_drift(ctx.rng)


## D-S63-1: advance by DRIFT_SPEED_MTPS / 60 per tick (integer, remainder kept), reflect at the
## inset edges. The direction is drawn once per fight.
func _drift(rng: RandomNumberGenerator) -> void:
	if drift_dir == 0:
		drift_dir = 1 if rng.randi_range(0, 1) == 1 else -1
	var total: int = drift_rem + DRIFT_SPEED_MTPS * drift_dir
	@warning_ignore("integer_division")
	var step: int = total / TICKS_PER_SECOND
	drift_rem = total - step * TICKS_PER_SECOND
	var x: int = pos_mtiles.x + step
	var lo: int = min_x_mtiles()
	var hi: int = max_x_mtiles()
	if x < lo:
		x = mini(2 * lo - x, hi)
		drift_dir = -drift_dir
		drift_rem = -drift_rem
	elif x > hi:
		x = maxi(2 * hi - x, lo)
		drift_dir = -drift_dir
		drift_rem = -drift_rem
	pos_mtiles = Vector2i(x, SPAWN_MTILES.y)
	_sync_px()


## The leftmost centre x (milli-tiles): half the body's width from the left edge.
static func min_x_mtiles() -> int:
	@warning_ignore("integer_division")
	return BODY_TILES.x * MILLI / 2


## The rightmost centre x (milli-tiles).
static func max_x_mtiles() -> int:
	return Const.ARENA_TILES.x * MILLI - min_x_mtiles()


func _sync_px() -> void:
	body_center_px = Vector2(pos_mtiles) * Const.TILE_PX / float(MILLI)


## The top band in tiles (AC 5): the full width, rows 0..BAND_ROWS-1. Pure.
static func band_rect() -> Rect2i:
	return Rect2i(0, 0, Const.ARENA_TILES.x, BAND_ROWS)


## The glyph of body cell `cell` (0..5, 0..3), "" outside the grid. Pure, no RNG (AC 5).
static func glyph_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= BODY_TILES.x or cell.y >= BODY_TILES.y:
		return ""
	return DRAGON_ROWS[cell.y][cell.x]


## The arena-local px centre of body cell `cell` around the current body centre. Pure read.
func cell_centre_px(cell: Vector2i) -> Vector2:
	var offset := Vector2(cell.x - (BODY_TILES.x - 1) / 2.0, cell.y - (BODY_TILES.y - 1) / 2.0)
	return body_center_px + offset * Const.TILE_PX


## Every body cell's centre (row by row) and its glyph, parallel: what the view draws and what the
## defeat reassembly moves. Pure read.
func cell_centres() -> PackedVector2Array:
	var out := PackedVector2Array()
	for y: int in BODY_TILES.y:
		for x: int in BODY_TILES.x:
			out.append(cell_centre_px(Vector2i(x, y)))
	return out


static func cell_glyphs() -> PackedStringArray:
	var out := PackedStringArray()
	for y: int in BODY_TILES.y:
		for x: int in BODY_TILES.x:
			out.append(glyph_at(Vector2i(x, y)))
	return out


## D-S63-5: the body circle (framework default) plus the live attack's hazard (ACTIVE only).
func touches_player(p: Vector2) -> bool:
	return super.touches_player(p) or attack_hazard_hit(p)
