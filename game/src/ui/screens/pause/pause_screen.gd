class_name PauseScreen
extends Node2D
## Pause overlay (Story 1.7 AC2, AC3). Main instances it on EventBus.pause_toggled(true) and frees
## it on false (DC6). Opaque BG over the 640x360 base (DC7), glyph text only (AD-07).
## Presentation only: M or a click on the mute label toggles the Master mute; Esc belongs to Game
## (DC2), and other clicks do nothing (DC3). It never writes flow or pause state.

const TEXT_SCALE := 2
## Tops of the text rows, on the 8-px grid. Title, then the GDD controls table, then the options.
const TITLE_TEXT := "PAUSED"
const TITLE_TOP_Y := 24
const CONTROLS: PackedStringArray = [
	"MOVE WASD ARROWS",
	"ACTION 1 J",
	"ACTION 2 K",
	"SHIFT Q E",
	"BREAKPOINT SPACE",
	"WATCH R",
]
const CONTROLS_TOP_Y := 72
const CONTROLS_STEP := 24
const RESUME_TEXT := "[ESC] RESUME"
const RESUME_TOP_Y := 240
const MUTE_TOP_Y := 272
const MUTE_ON_TEXT := "[M] MUTE ON"
const MUTE_OFF_TEXT := "[M] MUTE OFF"

var _muted: bool = false


func _ready() -> void:
	_muted = AudioManager.is_master_muted()


## Pure: every text row, top to bottom. The mute row reads ON when the Master bus is muted.
static func lines_for(muted: bool) -> PackedStringArray:
	var lines := PackedStringArray([TITLE_TEXT])
	lines.append_array(CONTROLS)
	lines.append(RESUME_TEXT)
	lines.append(mute_text(muted))
	return lines


static func mute_text(muted: bool) -> String:
	return MUTE_ON_TEXT if muted else MUTE_OFF_TEXT


## Pure: top y of each row of lines_for, same order.
static func row_tops() -> PackedInt32Array:
	var tops := PackedInt32Array([TITLE_TOP_Y])
	for i: int in CONTROLS.size():
		tops.append(CONTROLS_TOP_Y + i * CONTROLS_STEP)
	tops.append(RESUME_TOP_Y)
	tops.append(MUTE_TOP_Y)
	return tops


## Pure: the clickable rect of the mute label (the glyph row plus a half-cell margin), canvas space.
static func mute_label_rect(muted: bool) -> Rect2:
	return row_rect(mute_text(muted), MUTE_TOP_Y)


## The BG-backed box behind one row: one cell left and right, half a cell above and below.
static func row_rect(text: String, top_y: int) -> Rect2:
	return Rect2(TitleScreen.centred_x(text) - GlyphFont.CELL, top_y - GlyphFont.CELL * 0.5,
			GlyphFont.text_width(text, TEXT_SCALE) + 2 * GlyphFont.CELL, GlyphFont.size_for(TEXT_SCALE) + GlyphFont.CELL)


## Pure: true for a fresh M press or a left click inside the mute label.
static func is_mute_toggle(event: InputEvent, muted: bool) -> bool:
	if event is InputEventKey:
		return InputMap.has_action(&"mute") and event.is_action_pressed(&"mute")
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
			and mute_label_rect(muted).has_point(mouse.position)


## _input, not _unhandled_input: the placeholder under Screens sits later in the tree, so it would
## see M first and consume it as its any-key advance (which DC4 makes a no-op while paused).
func _input(event: InputEvent) -> void:
	if not is_mute_toggle(event, _muted):
		return
	get_viewport().set_input_as_handled()
	AudioManager.set_master_muted(not AudioManager.is_master_muted())
	_muted = AudioManager.is_master_muted()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(Const.BASE_RES)), Palette.BG)
	var lines: PackedStringArray = lines_for(_muted)
	var tops: PackedInt32Array = row_tops()
	for i: int in lines.size():
		GlyphFont.draw_at(self, Vector2(TitleScreen.centred_x(lines[i]), tops[i]), lines[i], Palette.INK, TEXT_SCALE)
