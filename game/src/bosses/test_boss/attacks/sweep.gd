extends BossAttack
## Framework test fixture (Story 3.1, D-S31-17): a horizontal sweep along the aim point's row,
## from the left edge to the right edge of the play area. Deals no damage; it aims through
## ctx.target_position() and counts its hooks so tests can check the FSM.

## Points along the swept row: one per this many tiles.
const STEP_TILES := 4

var row_y: float = 0.0
var tells: int = 0
var actives: int = 0
var recoveries: int = 0


func on_tell(ctx: ArenaContext) -> void:
	tells += 1
	row_y = Arena.clamp_to_play_area(ctx.target_position()).y


func on_active(_ctx: ArenaContext) -> void:
	actives += 1


func on_recovery(_ctx: ArenaContext) -> void:
	recoveries += 1


func reset() -> void:
	row_y = 0.0
	tells = 0
	actives = 0
	recoveries = 0


## The sweep's start (tell) position and every point along the row.
func declared_positions(ctx: ArenaContext) -> PackedVector2Array:
	var area: Rect2 = Arena.play_area()
	var y: float = Arena.clamp_to_play_area(ctx.target_position()).y
	var out := PackedVector2Array()
	var x: float = area.position.x
	while x <= area.end.x:
		out.append(Vector2(x, y))
		x += STEP_TILES * Const.TILE_PX
	out.append(Vector2(area.end.x, y))
	return out
