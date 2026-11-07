extends Node2D
## F9 debug grid (Story 1.5 DC7): 1-px lines on every 8-px HUD cell boundary (80x45), brighter
## every 16 px (one arena tile). INK only, at reduced alpha. Hidden by default; Hud toggles it.

const FAINT_ALPHA := 0.25
const STRONG_ALPHA := 0.5


func _ready() -> void:
	visible = false
	visibility_changed.connect(queue_redraw)


func _draw() -> void:
	var cell: int = GlyphFont.CELL
	var size := Vector2(Hud.COLS * cell, Hud.ROWS * cell)
	for x: int in range(0, Hud.COLS + 1):
		var px: float = x * cell + 0.5
		draw_line(Vector2(px, 0), Vector2(px, size.y), _ink(x % 2 == 0), 1.0)
	for y: int in range(0, Hud.ROWS + 1):
		var py: float = y * cell + 0.5
		draw_line(Vector2(0, py), Vector2(size.x, py), _ink(y % 2 == 0), 1.0)


func _ink(strong: bool) -> Color:
	var c: Color = Palette.INK
	c.a = STRONG_ALPHA if strong else FAINT_ALPHA
	return c
