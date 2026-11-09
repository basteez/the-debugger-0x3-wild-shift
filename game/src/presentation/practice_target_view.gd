class_name PracticeTargetView
extends Node2D
## Draws the `/* test */` practice target label (Story 2.7 AC4, D-S27-9). Presentation only: reads
## PracticeTarget, never writes it. A child of the Arena (arena-local pixels), added by Main in
## debug builds because arena/ may not reference presentation/. Story 2.8 removed the temporary
## hit readout (D-S28-9): hits now show in the HUD LogPanel, and the frame stamp lives on in the
## `[f=...]` prefix of the debug combat log line (D-S28-10).

const LABEL := "/* test */"
## [design call] The label draws at 1x: at 2x it is 160 px (10 tiles) wide and would cover the
## spawn `@` 4 tiles away; at 1x (80 px) it stays close to the 48-px hurtbox.
const LABEL_SCALE := 1

var target: PracticeTarget


func _init(p_target: PracticeTarget = null) -> void:
	target = p_target


func _draw() -> void:
	if target == null:
		return
	GlyphFont.draw_at(self, label_top_left(target.position_px), LABEL, Palette.INK, LABEL_SCALE)


## Top-left pixel of the label centred on the target, on the pixel grid. Pure.
static func label_top_left(centre: Vector2) -> Vector2:
	var size := Vector2(GlyphFont.text_width(LABEL, LABEL_SCALE), GlyphFont.CELL * LABEL_SCALE)
	return (centre - size / 2.0).round()
