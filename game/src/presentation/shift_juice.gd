class_name ShiftJuice
extends RefCounted
## Pure shift-juice model (Story 2.4, FR28, D-S24-1, D-S24-2): the register slide with its
## overshoot and the 4-frame weapon inversion, as integer frame tables. No node, no scene tree:
## every query takes the presentation frame `now`, so tests are deterministic and hit-stop (a
## simulation gate) cannot freeze it. Reads nothing and writes nothing outside itself.

## Slide length in frames (GDD "Hit Feedback", Shift row).
const SLIDE_FRAMES := 6
## Offset in px per slide frame for `<<`-style travel, scaled by -direction: starts 8 px away,
## overshoots rest by 1 px on frame 3 and settles on frame 5 (D-S24-2).
const SLIDE_PX: Array[int] = [8, 5, 2, -1, 1, 0]
## Frames the weapon glyph stays inverted after a shift.
const INVERT_FRAMES := 4
const CLICK_LEFT := "res://assets/audio/sfx/shift_left.wav"
const CLICK_RIGHT := "res://assets/audio/sfx/shift_right.wav"
## Sentinel `start` meaning "no shift shown".
const NO_START := -1

var direction: int = 0
var start: int = NO_START


## A shift happened at frame `now`. A second call restarts the slide and inversion (AC3, D-S24-7).
func on_shift(p_direction: int, now: int) -> void:
	direction = signi(p_direction)
	start = now


## Horizontal panel offset in px at frame `now`; 0 when no slide is running.
func slide_offset_px(now: int) -> int:
	var k: int = _age(now)
	if k < 0 or k >= SLIDE_FRAMES:
		return 0
	return -direction * SLIDE_PX[k]


## True for the first INVERT_FRAMES frames after the latest shift.
func is_inverted(now: int) -> bool:
	var k: int = _age(now)
	return k >= 0 and k < INVERT_FRAMES


## True while the slide or the inversion still has frames to show.
func is_live(now: int) -> bool:
	var k: int = _age(now)
	return k >= 0 and k < maxi(SLIDE_FRAMES, INVERT_FRAMES)


## The click resource for a direction: `<<` (-1) left, `>>` (+1) right (AC2).
static func click_path(p_direction: int) -> String:
	return CLICK_LEFT if p_direction < 0 else CLICK_RIGHT


func reset() -> void:
	direction = 0
	start = NO_START


func _age(now: int) -> int:
	if start == NO_START:
		return -1
	return now - start
