class_name GhostDecoyView
extends Node2D
## Placeholder drawing of the live Ghost Echo decoy (Story 6.1, D-S61-10): the glyphs of its window
## (`LN`) at 1x ("dim" next to the 2x actors, INK only: the palette has no alpha), centred on its
## spot, always visible (no Watch needed; Watch never reads it). Presentation only: reads the
## decoy's getters, never writes them. A child of the Arena, added by Main. Final look is 7.x.

const GLYPH_SCALE := 1

var decoy: GhostDecoy


func _init(p_decoy: GhostDecoy = null) -> void:
	decoy = p_decoy


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if decoy == null or not decoy.is_live():
		return
	var text: String = label_for(decoy.window_pair)
	GlyphFont.draw_at(self, top_left_for(decoy.position_px, text), text, Palette.INK, GLYPH_SCALE)


## The placeholder text of a window: its two register glyphs ("LN"). Pure.
static func label_for(window: Vector2i) -> String:
	return Register.glyph_of(window.x) + Register.glyph_of(window.y)


## Top-left pixel that centres `text` on `centre`, rounded onto the pixel grid. Pure.
static func top_left_for(centre: Vector2, text: String) -> Vector2:
	var size := Vector2(GlyphFont.text_width(text, GLYPH_SCALE), GlyphFont.size_for(GLYPH_SCALE))
	return (centre - size / 2.0).round()
