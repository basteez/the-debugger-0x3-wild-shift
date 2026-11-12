extends Node2D
## Draws the HUD frame text at 1x on the 8-px grid (Story 1.5). No Label nodes. Story 3.1: the top
## bar reads Hud.top_bar_text() (the boss header while a boss is in the fight). Story 3.6 (D-S36-4):
## the DUCK box is no longer drawn; the DuckBubble owns cols 0-11, rows 22-37 without a border.

const SCALE := 1


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var hud := get_parent() as Hud
	_text(Vector2i(0, 0), hud.top_bar_text() if hud != null else Hud.TOP_BAR)
	var warning: bool = hud != null and Hud.warning_tell_on(hud.boss)
	if warning: # Story 6.5 (D-S65-8): the tell line is an inverted ink cell run (INK/BG only)
		var line: String = hud.sky_text()
		draw_rect(Rect2(GlyphFont.cell_to_px(Vector2i(0, 1), SCALE), Vector2(GlyphFont.text_width(line, SCALE), GlyphFont.CELL * SCALE)), Palette.INK)
		GlyphFont.draw_cell(self, Vector2i(0, 1), line, Palette.BG, SCALE)
	else:
		_text(Vector2i(0, 1), hud.sky_text() if hud != null else Hud.SKY) # Story 5.1 (D-S51-4)
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
