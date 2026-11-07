class_name RegisterPanel
extends Node2D
## The REGISTER box content (Story 2.3, FR9, GFR5-GFR10, D-S23-8): hex byte value, the 8 bit cells,
## the faded `<<` / `>>` previews around the inverted active window, and `J→K`. Presentation only
## (AD-05, D-S23-9): reads the injected Register, never writes it. HUD text at 1x on the 8-px grid.
## The pure `plan()` decides every cell; `_draw()` only executes it.

## One run of text to draw: top-left HUD cell, text (one glyph per cell) and style.
class Cell:
	extends RefCounted
	var cell: Vector2i
	var text: String
	var style: StringName

	func _init(p_cell: Vector2i, p_text: String, p_style: StringName) -> void:
		cell = p_cell
		text = p_text
		style = p_style


const SCALE := 1
## Styles (D-S23-7): INK glyph; greyed and faded = glyph under a 50% BG checker; inverted = INK cell
## with a BG glyph. Greyed and faded draw the same; the names keep their meaning for 2.4 / 2.6.
const INK := &"ink"
const GREYED := &"greyed"
const FADED := &"faded"
const INVERTED := &"inverted"
## Layout (D-S23-8), HUD cells inside the REGISTER box interior (cols 1-10, rows 3-20).
const LEFT_COL := 1
const HEX_ROW := 3
const BYTE_ROW := 8
const LABEL_ROW := 9
const PREVIEW_LEFT_ROW := 11
const WINDOW_ROW := 12
const JK_ROW := 13
const PREVIEW_RIGHT_ROW := 14
## The J and K glyph columns, shared by both previews, the window and `J→K`.
const J_COL := 4
const K_COL := 6
const WINDOW_COLS := 10
const BYTE_BITS := 8
const NIBBLE_BITS := 4
const RESERVED_LABEL := "reserved"
const JK_LABEL := "J→K"
const UNOWNED := "0"

## The register to show. Injected by Main (null-safe: nothing is drawn without one).
var register: Register

## 8x8 50% checker of BG pixels (transparent elsewhere), built once on first draw.
static var _checker: ImageTexture


func _process(_delta: float) -> void:
	if register != null and register.active:
		queue_redraw()


func _draw() -> void:
	if register == null:
		return
	for c: Cell in plan(register.ring):
		var rect := Rect2(GlyphFont.cell_to_px(c.cell, SCALE), Vector2(c.text.length(), 1) * GlyphFont.CELL)
		if c.style == INVERTED:
			draw_rect(rect, Palette.INK)
			GlyphFont.draw_cell(self, c.cell, c.text, Palette.BG, SCALE)
			continue
		GlyphFont.draw_cell(self, c.cell, c.text, Palette.INK, SCALE)
		if c.style == GREYED or c.style == FADED:
			draw_texture_rect(_checker_texture(), rect, true)


## Every cell of the panel for a ring of owned bits (window first), in draw order. Pure: no node,
## no Register instance; `ring` is never modified. `owned_cap` is the low-nibble width.
static func plan(ring: PackedInt32Array, owned_cap: int = Register.MAX_BITS) -> Array[Cell]:
	var out: Array[Cell] = []
	var byte_value: int = (1 << ring.size()) - 1
	out.append(Cell.new(Vector2i(LEFT_COL, HEX_ROW), "0x%02X" % byte_value, INK))
	# 8 bit cells: the reserved high nibble, then the owned bits window first, then unowned slots.
	var high: int = BYTE_BITS - clampi(owned_cap, 0, BYTE_BITS)
	for i: int in BYTE_BITS:
		var col: int = LEFT_COL + i
		var slot: int = i - high
		if slot >= 0 and slot < ring.size():
			out.append(Cell.new(Vector2i(col, BYTE_ROW), Register.glyph_of(ring[slot]), INK))
		else:
			out.append(Cell.new(Vector2i(col, BYTE_ROW), UNOWNED, GREYED))
	out.append(Cell.new(Vector2i(LEFT_COL, LABEL_ROW), RESERVED_LABEL, GREYED))
	if ring.size() < Register.MIN_BITS:
		return out
	out.append(Cell.new(Vector2i(LEFT_COL, PREVIEW_LEFT_ROW),
			"<< " + _pair_text(Register.window_of(Register.rotated(ring, Register.LEFT))), FADED))
	var window: String = " ".repeat(J_COL - LEFT_COL) + _pair_text(Register.window_of(ring))
	out.append(Cell.new(Vector2i(LEFT_COL, WINDOW_ROW), window + " ".repeat(WINDOW_COLS - window.length()), INVERTED))
	out.append(Cell.new(Vector2i(J_COL, JK_ROW), JK_LABEL, INK))
	out.append(Cell.new(Vector2i(LEFT_COL, PREVIEW_RIGHT_ROW),
			">> " + _pair_text(Register.window_of(Register.rotated(ring, Register.RIGHT))), FADED))
	return out


## "D A": the J glyph at J_COL, the K glyph at K_COL when the run starts J_COL - LEFT_COL earlier.
static func _pair_text(window: Vector2i) -> String:
	return Register.glyph_of(window.x) + " ".repeat(K_COL - J_COL - 1) + Register.glyph_of(window.y)


## The dither (D-S23-7, NFR8): BG on pixels where x + y is even, transparent elsewhere. Built from
## Palette.BG only, so the panel draws no colour outside INK and BG.
static func _checker_texture() -> ImageTexture:
	if _checker == null:
		var img: Image = Image.create_empty(GlyphFont.CELL, GlyphFont.CELL, false, Image.FORMAT_RGBA8)
		for y: int in GlyphFont.CELL:
			for x: int in GlyphFont.CELL:
				if (x + y) % 2 == 0:
					img.set_pixel(x, y, Palette.BG)
		_checker = ImageTexture.create_from_image(img)
	return _checker
