class_name GlyphFont
extends RefCounted
## The one 8x8 CP437-style pixel font (D-047, Story 1.5). World glyphs at 2x (16-px tiles),
## HUD text at 1x on the 8-px grid. Static only; the font is preloaded (AD-13).
## Lives in src/core/ so the simulation folder arena/ never references presentation/ (DC4a).

const FONT: FontFile = preload("res://assets/fonts/wildshift8.fnt")
## One HUD cell, in pixels at 1x. The font's fixed size is also 8, so font size = CELL * scale.
const CELL := 8


static func font() -> Font:
	return FONT


## Font size for an integer scale: the bitmap font scales by whole multiples only (integer mode).
static func size_for(scale: int) -> int:
	return CELL * maxi(scale, 1)


## True only for the two colours glyphs may use (INK, BG).
static func is_allowed_color(color: Color) -> bool:
	return color == Palette.INK or color == Palette.BG


## Top-left pixel of a cell at a scale, canvas-local.
static func cell_to_px(cell: Vector2i, scale: int) -> Vector2:
	return Vector2(cell * CELL * maxi(scale, 1))


## Draws `text` with its first glyph's top-left corner at `cell * CELL * scale`, one glyph per cell.
## Any colour other than INK or BG is a programmer error: logged, then drawn in INK.
static func draw_cell(canvas: CanvasItem, cell: Vector2i, text: String, color: Color, scale: int) -> void:
	draw_at(canvas, cell_to_px(cell, scale), text, color, scale)


## Same as draw_cell, at a pixel position (top-left of the first glyph). Used for centred text.
static func draw_at(canvas: CanvasItem, top_left: Vector2, text: String, color: Color, scale: int) -> void:
	var c: Color = color
	if not is_allowed_color(c):
		Log.error(&"glyph", "colour outside INK/BG, drawing in INK")
		c = Palette.INK
	var size: int = size_for(scale)
	var baseline := Vector2(top_left.x, top_left.y + FONT.get_ascent(size))
	canvas.draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## Width in pixels of `text` at a scale (monospace: one cell per character).
static func text_width(text: String, scale: int) -> int:
	return text.length() * size_for(scale)
