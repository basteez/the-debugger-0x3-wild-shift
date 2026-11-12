extends BossAttack
## Null Pointer, Null Rain (Story 5.2, FR39, D-S52-3, D-S52-10): phases 1-2. TELL (45 frames): five
## 2 x 2-tile areas are outlined at fixed tile offsets from the aim taken at TELL entry. ACTIVE (20
## frames): a player centre inside any area takes 1 HP through the body's contact path. RECOVERY (40
## frames): the areas are gone; the ghost is visible (Story 5.1). Each area's top-left is snapped to
## the tile grid and clamped so the area lies in the play area (Pillar 2). Aims only through
## ctx.target_position() (NP-3); a fixed layout, no RNG (D-S52-4).

const AREA_TILES := 2
## D-S52-3: area centres in tiles from the aim: the aim itself and four around it.
const OFFSETS_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(-6, -4), Vector2i(6, -4), Vector2i(-6, 4), Vector2i(6, 4),
]

## The five areas (arena-local px), fixed at TELL entry; empty outside TELL / ACTIVE.
var areas: Array[Rect2] = []


func on_tell(ctx: ArenaContext) -> void:
	if ctx == null: # a body set up without an arena (unit tests): nothing to aim at
		areas = []
		return
	areas = areas_for(ctx.target_position())


func on_recovery(_ctx: ArenaContext) -> void:
	areas = []


func on_cancel(_ctx: ArenaContext) -> void:
	reset()


func reset() -> void:
	areas = []


## The player's centre inside any area (edges included), ACTIVE only.
func hazard_hit(p: Vector2) -> bool:
	if not is_live():
		return false
	for r: Rect2 in areas:
		if inside(r, p):
			return true
	return false


## TELL and ACTIVE: the areas to outline (D-S52-10).
func hazard_rects() -> Array[Rect2]:
	return areas.duplicate()


## The areas' centres (tests; the view draws the rects instead of glyphs).
func hazard_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for r: Rect2 in areas:
		out.append(r.get_center())
	return out


## Every area corner against `ctx` (AC 13).
func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	var out := PackedVector2Array()
	if ctx == null:
		return out
	for r: Rect2 in areas_for(ctx.target_position()):
		out.append_array(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]))
	return out


## The five areas for an aim at `aim`: each AREA_TILES square centred on aim + offset, its top-left
## snapped to whole tiles and clamped into the play area. Pure.
static func areas_for(aim: Vector2) -> Array[Rect2]:
	var tile := float(Const.TILE_PX)
	var size := Vector2(AREA_TILES, AREA_TILES) * tile
	var area: Rect2 = Arena.play_area()
	var out: Array[Rect2] = []
	for off: Vector2i in OFFSETS_TILES:
		var centre: Vector2 = aim + Vector2(off) * tile
		var top_left: Vector2 = ((centre - size / 2.0) / tile).round() * tile
		out.append(Rect2(top_left.clamp(area.position, area.end - size), size))
	return out


## `p` inside `r`, edges included. Pure.
static func inside(r: Rect2, p: Vector2) -> bool:
	return p.x >= r.position.x and p.y >= r.position.y and p.x <= r.end.x and p.y <= r.end.y
