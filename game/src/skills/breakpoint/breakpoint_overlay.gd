class_name BreakpointOverlay
extends Node2D
## The Breakpoint warning (Story 4.3, AC 9, D-S43-10): while Breakpoint runs, a red Palette.WARN dot
## in the HUD gutter (col 12) and a 1-px red line across the play area under the player's tile row,
## like a debugger's breakpoint on the current line. A child of the Arena (arena-local pixels),
## added by Main only when FeatureFlags.breakpoint is on. Presentation only: reads the skill's
## active flag and the player's position, never writes them. ScreenFX leaves WARN pixels unchanged
## (AC 11), so the dither never eats it.

const DOT_RADIUS_PX := 3.0
## Arena-local x of the dot: the centre of HUD column 12 (the gap left of the line numbers).
const DOT_X_PX := 12.0 * 8.0 + 4.0 - 16.0 * 8.0
const LINE_WIDTH_PX := 1.0

## Injected by Main (read only). Null = nothing is drawn.
var skill: FightSkill
var player: Player

## The state drawn last (-1 = hidden), so redraws happen only on a change.
var _shown_row: int = -1


func _process(_delta: float) -> void:
	var row: int = current_row()
	if row != _shown_row:
		_shown_row = row
		queue_redraw()


## The tile row the warning marks while Breakpoint runs, or -1 when hidden.
func current_row() -> int:
	if skill == null or not skill.is_active():
		return -1
	if player == null:
		return 0
	return row_for(player.position_px.y)


## The tile row of an arena-local y, clamped to the play area. Pure.
static func row_for(y_px: float) -> int:
	return clampi(floori(y_px / float(Const.TILE_PX)), 0, Const.ARENA_TILES.y - 1)


## Arena-local y of the dot centre and the line for a tile row: the row's centre and its bottom edge.
static func dot_y_for(row: int) -> float:
	return (float(row) + 0.5) * float(Const.TILE_PX)


static func line_y_for(row: int) -> float:
	return float(row + 1) * float(Const.TILE_PX) - LINE_WIDTH_PX * 0.5


func _draw() -> void:
	var row: int = current_row()
	if row < 0:
		return
	draw_circle(Vector2(DOT_X_PX, dot_y_for(row)), DOT_RADIUS_PX, Palette.WARN)
	var y: float = line_y_for(row)
	draw_line(Vector2(0.0, y), Vector2(float(Const.ARENA_TILES.x * Const.TILE_PX), y), Palette.WARN, LINE_WIDTH_PX)
