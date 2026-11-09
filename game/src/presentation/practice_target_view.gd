class_name PracticeTargetView
extends Node2D
## Draws the `/* test */` practice target and its hit readout (Story 2.7 AC4, D-S27-8, D-S27-9).
## Presentation only: reads PracticeTarget, never writes it. A child of the Arena (arena-local
## pixels), added by Main in debug builds because arena/ may not reference presentation/.
## The readout is a temporary stand-in for the Story 2.8 HUD log panel.

const LABEL := "/* test */"
## [design call] The label draws at 1x: at 2x it is 160 px (10 tiles) wide and would cover the
## spawn `@` 4 tiles away; at 1x (80 px) it stays close to the 48-px hurtbox.
const LABEL_SCALE := 1
## How many hit lines the readout shows (newest last).
const READOUT_HITS := 3
const LINE_STEP := GlyphFont.CELL + 1
## Readout top-left inset from the bottom-left corner of the play area: clear of the tree ring.
const READOUT_INSET := Vector2(Const.TILE_PX + 4, Const.TILE_PX + 4)

var target: PracticeTarget


func _init(p_target: PracticeTarget = null) -> void:
	target = p_target


func _process(_delta: float) -> void:
	if target != null:
		queue_redraw()


func _draw() -> void:
	if target == null:
		return
	GlyphFont.draw_at(self, label_top_left(target.position_px), LABEL, Palette.INK, LABEL_SCALE)
	var lines: PackedStringArray = readout_lines(target)
	var top_left: Vector2 = readout_top_left(lines.size())
	var width: int = 0
	for line: String in lines:
		width = maxi(width, GlyphFont.text_width(line, 1))
	draw_rect(Rect2(top_left - Vector2(2, 2), Vector2(width + 4, lines.size() * LINE_STEP + 3)), Palette.BG)
	for i: int in lines.size():
		GlyphFont.draw_at(self, top_left + Vector2(0, i * LINE_STEP), lines[i], Palette.INK, 1)


## Top-left pixel of the label centred on the target, on the pixel grid. Pure.
static func label_top_left(centre: Vector2) -> Vector2:
	var size := Vector2(GlyphFont.text_width(LABEL, LABEL_SCALE), GlyphFont.CELL * LABEL_SCALE)
	return (centre - size / 2.0).round()


## Top-left pixel of a readout of `line_count` lines, bottom-left of the play area. Pure.
static func readout_top_left(line_count: int) -> Vector2:
	var area: Rect2 = Arena.play_area()
	return Vector2(area.position.x + READOUT_INSET.x, area.end.y - READOUT_INSET.y - line_count * LINE_STEP)


## The readout (ASCII only): `hits N`, then the last READOUT_HITS hits as `f=<frame> <action> <dmg>`.
static func readout_lines(t: PracticeTarget) -> PackedStringArray:
	var out := PackedStringArray(["hits %d" % t.hits])
	var recs: Array[Dictionary] = t.records()
	for rec: Dictionary in recs.slice(maxi(recs.size() - READOUT_HITS, 0)):
		out.append(hit_line(rec[&"frame"], rec[&"action"], rec[&"damage"]))
	return out


static func hit_line(frame: int, action_id: StringName, damage: int) -> String:
	return "f=%d %s %d" % [frame, action_id, damage]
