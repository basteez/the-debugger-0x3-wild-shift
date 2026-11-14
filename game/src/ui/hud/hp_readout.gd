class_name HpReadout
extends Node2D
## The player's HP readout `hp: 0b11111` (Story 2.9 AC1, GDD "Player HP"), drawn at 1x on the HUD
## top bar, right-aligned to the last column (D-S29-8 [design call]: the 11-character text does not
## fit the register box's 10-column interior). Presentation only (AD-05): reads PlayerHealth.hp,
## never writes it. Main injects `health`.

const SCALE := 1
const ROW := 0

var health: PlayerHealth
## The text drawn last; redraws only when it changes.
var _shown: String = ""


func _process(_delta: float) -> void:
	var text: String = current_text()
	if text != _shown:
		_shown = text
		queue_redraw()


## The readout for the injected health; empty without one.
func current_text() -> String:
	if health == null or health.def == null:
		return ""
	return PlayerHealth.hp_text(health.hp, health.max_hp) # Story 7.4 (AC 5): the live max


## HUD cell of the readout's first glyph: right-aligned on ROW, ending at the last column. Pure.
static func cell_for(text: String) -> Vector2i:
	return Vector2i(Hud.COLS - text.length(), ROW)


func _draw() -> void:
	var text: String = current_text()
	if text != "":
		GlyphFont.draw_cell(self, cell_for(text), text, Palette.INK, SCALE)
