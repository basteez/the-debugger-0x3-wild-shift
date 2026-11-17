extends Node2D
## Draws the HUD frame text at 1x on the 8-px grid (Story 1.5). No Label nodes. Story 3.1: the top
## bar reads Hud.top_bar_text() (the boss header while a boss is in the fight). Story 3.6 (D-S36-4):
## the DUCK box is no longer drawn; the DuckBubble owns cols 0-11, rows 22-37 without a border.
## Story 9.7 (D-S97-6): row 0 is an inverted title bar (a full-width INK bar, BG text; the HpReadout
## draws on it in BG too). Story 9.7 (D-S97-13): a normal sky comment (row 1) is plain INK (the 50%
## checker made the 1x text unreadable in the export); the inverted SIGSEGV warning tell stands out
## on its own, with a BG pixel row between the title bar and the tell (D-S97-14).

const SCALE := 1

func _ready() -> void:
	queue_redraw()


## Story 9.7 (D-S97-6, D-S97-7): the title bar rect, HUD pixels: the full 80-column width,
## Hud.TITLE_BAR_PX tall (row 0 plus the top pixel row of row 1). Pure.
static func title_bar_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(Hud.COLS * GlyphFont.CELL * SCALE, Hud.TITLE_BAR_PX))


## Story 9.7 (D-S97-7): top-left pixel of the title text (row 0), Hud.TITLE_TEXT_DY down. Pure.
static func title_text_px(col: int) -> Vector2:
	return GlyphFont.cell_to_px(Vector2i(col, 0), SCALE) + Vector2(0, Hud.TITLE_TEXT_DY)


## Story 9.7 (D-S97-7): top-left pixel of the sky row text (row 1), Hud.SKY_TEXT_DY down. Pure.
static func sky_text_px() -> Vector2:
	return GlyphFont.cell_to_px(Vector2i(0, 1), SCALE) + Vector2(0, Hud.SKY_TEXT_DY)


## Story 6.5 (D-S65-8), Story 9.7 (D-S97-14): the inverted warning tell rect: the line's width, the
## seven glyph rows (cap height) from sky_text_px(), so it starts one BG pixel row under the title bar
## and ends on row 2's top edge, never covering its first pixel row (`01`, the `reg` box). Pure.
static func tell_rect(line: String) -> Rect2:
	return Rect2(sky_text_px(), Vector2(GlyphFont.text_width(line, SCALE), Hud.TELL_HEIGHT_PX))


func _draw() -> void:
	var hud := get_parent() as Hud
	draw_rect(title_bar_rect(), Palette.INK)
	GlyphFont.draw_at(self, title_text_px(0), hud.top_bar_text() if hud != null else Hud.TOP_BAR, Palette.BG, SCALE)
	var warning: bool = hud != null and Hud.warning_tell_on(hud.boss)
	if warning: # Story 6.5 (D-S65-8): the tell line is an inverted ink cell run (INK/BG only)
		var line: String = hud.sky_text()
		draw_rect(tell_rect(line), Palette.INK)
		GlyphFont.draw_at(self, sky_text_px(), line, Palette.BG, SCALE)
	else:
		var sky: String = hud.sky_text() if hud != null else Hud.SKY # Story 5.1 (D-S51-4)
		GlyphFont.draw_at(self, sky_text_px(), sky, Palette.INK, SCALE)
	_box(Hud.REGISTER, Hud.REG_TITLE)
	for i: int in Hud.LINE_NO.size():
		_text(Vector2i(Hud.LINE_NO_COL, Hud.line_no_row(i)), Hud.LINE_NO[i])
	for row: int in range(Hud.ARENA.position.y, Hud.ARENA.end.y):
		_text(Vector2i(Hud.SEPARATOR_COL, row), "│")
	_text(Hud.LOG.position, Hud.LOG_HEADER)


func _box(rect: Rect2i, title: String = "") -> void:
	var rows: PackedStringArray = Hud.box_rows(rect, title)
	_text(rect.position, rows[0])
	for y: int in range(rect.position.y + 1, rect.end.y - 1):
		_text(Vector2i(rect.position.x, y), "│")
		_text(Vector2i(rect.end.x - 1, y), "│")
	_text(Vector2i(rect.position.x, rect.end.y - 1), rows[2])


func _text(cell: Vector2i, text: String) -> void:
	GlyphFont.draw_cell(self, cell, text, Palette.INK, SCALE)
