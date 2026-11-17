class_name PracticeFrameCounter
extends Node2D
## Story 7.6 (AC 5, D-S76-2): the practice fight's read-only `frames N` readout (sim frames since the
## practice FIGHT entry) and the practice key hint, in every build. Draws only while `active` (Main
## sets it from Game.practice_run on FIGHT entry). Presentation only: reads SimClock.sim_frame and
## Game.practice_start_frame, never writes sim or flow state. The F9 frame overlay stays debug-only.
## Story 9.7 (D-S97-5, D-S97-9): a child of the HUD (HUD cells, 1x), not of the arena: the readout
## sits on the console header (HUD row 38, the `── console ──` rule), right-aligned RIGHT_MARGIN
## columns from the edge, over a BG backing; nothing practice-related is drawn in the arena.

const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
## HUD text at 1x on the 8-px grid.
const TEXT_SCALE := 1
## Story 9.7 (D-S97-5): columns left free between the readout and the right edge.
const RIGHT_MARGIN := 2
## Story 9.8 (D-S98-4): BG cells of backing on each side of the text, over the console rule.
const BACKING_PAD := 1
## Columns between the frame count and the key hint.
const GAP := "   "

## True only during a practice fight.
var active: bool = false


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func set_active(on: bool) -> void:
	active = on
	queue_redraw()


## Pure: the frames since `start_frame` (0 before it or when unknown).
static func frames_since(start_frame: int, frame: int) -> int:
	return maxi(frame - start_frame, 0) if start_frame >= 0 else 0


## Pure: the readout parts: the frame count, then the key hint.
static func lines_for(frames: int) -> PackedStringArray:
	return PackedStringArray(["frames %d" % frames, SCREEN_TEXT.practice_hint])


## Pure (D-S97-5): the header text: both parts on one row. Story 9.8 (D-S98-4): no pad spaces, so
## the visible text ends RIGHT_MARGIN columns from the edge; the backing adds the pad cells.
static func header_text(frames: int) -> String:
	var parts: PackedStringArray = lines_for(frames)
	return "%s%s%s" % [parts[0], GAP, parts[1]]


## Pure (D-S97-5): the HUD cell of the header text's first glyph: on the console header row,
## right-aligned RIGHT_MARGIN columns from the edge.
static func header_cell(text: String) -> Vector2i:
	return Vector2i(maxi(0, Hud.COLS - RIGHT_MARGIN - text.length()), Hud.LOG.position.y)


## Pure: the BG backing over the console rule under the header text (HUD pixels). Story 9.8
## (D-S98-4): BACKING_PAD cells each side of the text, clipped to the HUD's columns.
static func backing_rect(text: String) -> Rect2:
	var cell: Vector2i = header_cell(text)
	var first: int = maxi(cell.x - BACKING_PAD, 0)
	var end: int = mini(cell.x + text.length() + BACKING_PAD, Hud.COLS)
	var px: Vector2 = GlyphFont.cell_to_px(Vector2i(first, cell.y), TEXT_SCALE)
	return Rect2(px, Vector2((end - first) * GlyphFont.CELL * TEXT_SCALE, GlyphFont.CELL * TEXT_SCALE))


func _draw() -> void:
	if not active:
		return
	var text: String = header_text(frames_since(Game.practice_start_frame, SimClock.sim_frame))
	draw_rect(backing_rect(text), Palette.BG)
	GlyphFont.draw_cell(self, header_cell(text), text, Palette.INK, TEXT_SCALE)
