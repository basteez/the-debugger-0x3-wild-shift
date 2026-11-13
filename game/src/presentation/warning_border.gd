class_name WarningBorder
extends Node2D
## Story 6.5 (AC 3, 4, D-S65-8): the SIGSEGV tell's red border, a solid Palette.WARN frame around the
## whole 640x360 HUD for the whole tell (no blink, no alpha). A separate node from the HUD frame so
## the HUD sources stay INK/BG only (test_glyph_palette), like the Breakpoint overlay. A child of the
## Hud, added by Main. Presentation only: reads the boss's warning by method, never writes sim state
## (AD-05). ScreenFX leaves WARN pixels unchanged.

const BORDER_RECT := Rect2(1, 1, Hud.COLS * 8 - 2, Hud.ROWS * 8 - 2)
const BORDER_WIDTH := 2.0

## Injected by Main (read only). Null = nothing is drawn.
var hud: Hud

var _shown: bool = false


func _process(_delta: float) -> void:
	var on: bool = is_on()
	if on != _shown:
		_shown = on
		queue_redraw()


func is_on() -> bool:
	return hud != null and Hud.warning_tell_on(hud.boss)


func _draw() -> void:
	if _shown:
		draw_rect(BORDER_RECT, Palette.WARN, false, BORDER_WIDTH)
