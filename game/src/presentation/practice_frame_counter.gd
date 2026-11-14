class_name PracticeFrameCounter
extends Node2D
## Story 7.6 (AC 5, D-S76-2): the practice fight's read-only `frames N` readout (sim frames since the
## practice FIGHT entry) and the practice key hint, in every build. A child of the Arena (arena-local
## pixels), added by Main; draws only while `active` (Main sets it from Game.practice_run on FIGHT
## entry). Presentation only: reads SimClock.sim_frame and Game.practice_start_frame, never writes
## sim or flow state. The F9 frame overlay stays debug-only.

const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
## Glyph font at 1x, like the `/* test */` label and the F9 overlay.
const TEXT_SCALE := 1
## The readout's first row sits this far below the dummy's centre (under its 1.5-tile hurtbox).
const OFFSET_BELOW_TARGET := 32.0
const LINE_STEP := GlyphFont.CELL + 2

## True only during a practice fight.
var active: bool = false
## Centre of the dummy, arena-local pixels (Arena.PRACTICE_TARGET_PX).
var target_px: Vector2 = Arena.PRACTICE_TARGET_PX


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func set_active(on: bool) -> void:
	active = on
	queue_redraw()


## Pure: the frames since `start_frame` (0 before it or when unknown).
static func frames_since(start_frame: int, frame: int) -> int:
	return maxi(frame - start_frame, 0) if start_frame >= 0 else 0


## Pure: the text rows, top to bottom.
static func lines_for(frames: int) -> PackedStringArray:
	return PackedStringArray(["frames %d" % frames, SCREEN_TEXT.practice_hint])


## Pure: the top-left pixel of row `i` of `text`, centred under the dummy, on the pixel grid.
static func row_top_left(centre: Vector2, text: String, i: int) -> Vector2:
	var width: float = GlyphFont.text_width(text, TEXT_SCALE)
	return (centre + Vector2(-width / 2.0, OFFSET_BELOW_TARGET + i * LINE_STEP)).round()


func _draw() -> void:
	if not active:
		return
	var lines: PackedStringArray = lines_for(frames_since(Game.practice_start_frame, SimClock.sim_frame))
	for i: int in lines.size():
		GlyphFont.draw_at(self, row_top_left(target_px, lines[i], i), lines[i], Palette.INK, TEXT_SCALE)
