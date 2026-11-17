class_name TutorialChecklistView
extends Node2D
## Story 8.2 (D-E8-4, AC 2, 9, 11, 12, E2): the tutorial's text inside the play area (arena-local px,
## Arena.play_area()), never in the duck bubble: the six-test checklist at 2x in the top-left corner
## (a `>` marks the current test), the current prompt (one or two rows at 1x) along the bottom edge,
## the skip hint at 1x in the top-right corner with a fill bar while the key is held and the pause
## hint under the bar (Story 9.1), and the two completion rows at 2x in the bottom band once every
## test passed (Story 9.1, D-S91-5: clear of the `@` at spawn and the dummy). Every row has a BG backing so it reads
## over the scenery. A child of the Arena added by Main before the player and boss views (drawn under
## them). Presentation only: the TUTORIAL screen hands it the text (show_state); it reads no sim state.
## INK/BG only.

const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
const TEST_SCALE := 2
const PROMPT_SCALE := 1
const PASS_MARK := "[PASS]"
const TODO_MARK := "[ ]"
const CURSOR := ">"
## Checklist rows: the `>` cursor column, then the rows, 16 px (one 2x row) apart.
const CURSOR_LEFT := 8.0
const CHECKLIST_LEFT := 24.0
const CHECKLIST_TOP := 16.0
const ROW_STEP := 16.0
## Prompt rows: centred, the last one 8 px above the play area's bottom edge.
const PROMPT_BOTTOM_MARGIN := 8.0
const PROMPT_STEP := 12.0
## Skip hint: 8 px in from the top-right corner; the hold bar 2 px under it. Story 9.1 (D-S91-4):
## further hint rows (the pause key) right-aligned under the bar, HINT_ROW_GAP below it, 12 px apart.
const HINT_MARGIN := 8.0
const HOLD_BAR_HEIGHT := 2.0
const HOLD_BAR_GAP := 2.0
const HINT_ROW_GAP := 2.0
const HINT_ROW_STEP := 12.0
## Completion rows (D-S82-7): centred, 2x, 24 px apart. Story 9.1 (D-S91-5): bottom-anchored like the
## prompt (empty once every test passed), the last row PROMPT_BOTTOM_MARGIN above the bottom edge.
const DONE_STEP := 24.0
## BG backing around each text row.
const BACKING := 2.0

var active: bool = false
var lines: PackedStringArray = []
var current: int = -1
var prompt: PackedStringArray = []
var hints: PackedStringArray = []
var hold: float = 0.0
var done: bool = false


## Pure (E2): the six checklist rows, `[ ] test_x` until the test passes, then `[PASS] test_x`.
static func checklist_lines(steps: TutorialSteps) -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in TutorialSteps.STEP_COUNT:
		out.append("%s %s" % [PASS_MARK if steps != null and steps.passed(i) else TODO_MARK, SCREEN_TEXT.tutorial_tests[i]])
	return out


## Pure (D-S82-7): the two completion rows.
static func done_lines() -> PackedStringArray:
	return PackedStringArray([SCREEN_TEXT.tutorial_all_pass_1, SCREEN_TEXT.tutorial_all_pass_2])


## Pure: top-left of checklist row `i`.
static func row_top_left(i: int) -> Vector2:
	return Vector2(CHECKLIST_LEFT, CHECKLIST_TOP + i * ROW_STEP)


## Pure: top-left of prompt row `i` of `count`, centred on the play area, the last row at the bottom.
static func prompt_top_left(text: String, i: int, count: int) -> Vector2:
	var area: Rect2 = Arena.play_area()
	var bottom_top: float = area.end.y - PROMPT_BOTTOM_MARGIN - GlyphFont.CELL * PROMPT_SCALE
	var x: float = area.position.x + (area.size.x - GlyphFont.text_width(text, PROMPT_SCALE)) / 2.0
	return Vector2(x, bottom_top - (count - 1 - i) * PROMPT_STEP).round()


## Pure: top-left of the skip hint, right-aligned in the top-right corner.
static func hint_top_left(text: String) -> Vector2:
	var area: Rect2 = Arena.play_area()
	return Vector2(area.end.x - HINT_MARGIN - GlyphFont.text_width(text, PROMPT_SCALE), area.position.y + HINT_MARGIN)


## Pure (Story 9.1): the hold bar under the skip hint row `text` (its width).
static func hold_bar_rect(text: String) -> Rect2:
	var h: Vector2 = hint_top_left(text)
	return Rect2(h + Vector2(0, GlyphFont.CELL * PROMPT_SCALE + HOLD_BAR_GAP), Vector2(GlyphFont.text_width(text, PROMPT_SCALE), HOLD_BAR_HEIGHT))


## Pure (Story 9.1, D-S91-4): top-left of hint row `i` of `rows`: row 0 is the skip hint, the others
## sit right-aligned under its hold bar.
static func hint_row_top_left(rows: PackedStringArray, i: int) -> Vector2:
	var at: Vector2 = hint_top_left(rows[i])
	if i == 0:
		return at
	var bar_bottom: float = hold_bar_rect(rows[0]).end.y
	return Vector2(at.x, bar_bottom + HINT_ROW_GAP + (i - 1) * HINT_ROW_STEP)


## Pure: top-left of completion row `i`, centred on the play area. Story 9.1 (D-S91-5): bottom
## band, the last row PROMPT_BOTTOM_MARGIN above the play area's bottom edge.
static func done_top_left(text: String, i: int) -> Vector2:
	var area: Rect2 = Arena.play_area()
	var x: float = area.position.x + (area.size.x - GlyphFont.text_width(text, TEST_SCALE)) / 2.0
	var rows: int = done_lines().size()
	var y: float = area.end.y - PROMPT_BOTTOM_MARGIN - GlyphFont.CELL * TEST_SCALE - DONE_STEP * (rows - 1 - i)
	return Vector2(x, y).round()


## Pure: true when every row fits inside the play area (tests).
static func fits_play_area(top_left: Vector2, text: String, scale: int) -> bool:
	var r := Rect2(top_left, Vector2(GlyphFont.text_width(text, scale), GlyphFont.CELL * scale))
	return Arena.play_area().encloses(r)


func show_state(p_lines: PackedStringArray, p_current: int, p_prompt: PackedStringArray, p_hints: PackedStringArray, p_hold: float, p_done: bool) -> void:
	active = true
	lines = p_lines
	current = p_current
	prompt = p_prompt
	hints = p_hints
	hold = p_hold
	done = p_done
	queue_redraw()


func clear() -> void:
	active = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	for i: int in lines.size():
		var at: Vector2 = row_top_left(i)
		_text(at, lines[i], TEST_SCALE)
		if i == current:
			_text(Vector2(CURSOR_LEFT, at.y), CURSOR, TEST_SCALE)
	for i: int in prompt.size():
		_text(prompt_top_left(prompt[i], i, prompt.size()), prompt[i], PROMPT_SCALE)
	for i: int in hints.size():
		_text(hint_row_top_left(hints, i), hints[i], PROMPT_SCALE)
	if not hints.is_empty() and hold > 0.0: # after the rows, so no backing ever covers the bar
		var bar: Rect2 = hold_bar_rect(hints[0])
		draw_rect(bar, Palette.INK, false, 1.0)
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * hold), HOLD_BAR_HEIGHT)), Palette.INK)
	if done:
		var rows: PackedStringArray = done_lines()
		for i: int in rows.size():
			_text(done_top_left(rows[i], i), rows[i], TEST_SCALE)


## One text row with a BG backing.
func _text(top_left: Vector2, text: String, scale: int) -> void:
	var size := Vector2(GlyphFont.text_width(text, scale), GlyphFont.CELL * scale)
	draw_rect(Rect2(top_left - Vector2.ONE * BACKING, size + Vector2.ONE * BACKING * 2.0), Palette.BG)
	GlyphFont.draw_at(self, top_left, text, Palette.INK, scale)
