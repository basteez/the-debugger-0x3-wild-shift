extends Node2D
## Persistent root scene (AD-08). Draws one test glyph for the pixel-perfect check.

const GLYPH_CELL_PX := 2
const GLYPH_ORIGIN := Vector2(312, 172)
## 8x8 test glyph, one row per entry, MSB is the leftmost cell.
const GLYPH_ROWS: Array[int] = [
	0b11111111,
	0b10000001,
	0b10111101,
	0b10100101,
	0b10100101,
	0b10111101,
	0b10000001,
	0b11111111,
]


func _ready() -> void:
	Log.info(&"flow", "boot")


func _draw() -> void:
	for y: int in GLYPH_ROWS.size():
		var row: int = GLYPH_ROWS[y]
		for x: int in 8:
			if row & (0b10000000 >> x) != 0:
				var pos := GLYPH_ORIGIN + Vector2(x * GLYPH_CELL_PX, y * GLYPH_CELL_PX)
				draw_rect(Rect2(pos, Vector2(GLYPH_CELL_PX, GLYPH_CELL_PX)), Palette.INK)
