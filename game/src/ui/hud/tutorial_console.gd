class_name TutorialConsole
extends Node2D
## Story 9.7 (D-S97-4): the tutorial's checklist and current prompt, in the HUD console (1x, HUD
## cells) instead of the play area. Left block: the six test rows on console lines 0-5 (HUD rows
## 39-44), the rows at CHECKLIST_COL and the `>` cursor at CURSOR_COL on the current test. Right
## block: the prompt from PROMPT_COL, word-wrapped to the PROMPT_WIDTH columns left; the console log
## lines go under the prompt in the same block (LogPanel.set_block). A child of the HUD added by
## Main; the TUTORIAL screen feeds it (show_state / clear). Presentation only, INK/BG only.

const CURSOR := ">"
const CURSOR_COL := 0
const CHECKLIST_COL := 2
## Right block (D-S97-4): from column 24 to the last column.
const PROMPT_COL := 24
const PROMPT_WIDTH := Hud.COLS - PROMPT_COL
const SCALE := 1

## The console log; Main injects it. Its lines move to the right block while the console is fed.
var log_panel: LogPanel
var active: bool = false
var lines: PackedStringArray = PackedStringArray()
var current: int = -1
## The prompt, already wrapped to PROMPT_WIDTH.
var prompt_lines: PackedStringArray = PackedStringArray()


## Pure (D-S97-4, [design call] D-S97-10): the prompt rows joined into one paragraph and word-wrapped
## to PROMPT_WIDTH columns (the second row often continues the first sentence). Story 9.8 (D-S98-4):
## a single word wider than PROMPT_WIDTH (DuckBubble.wrap keeps it whole) is broken every
## PROMPT_WIDTH columns, so no glyph passes column 79. The duck's own wrap is unchanged.
static func wrap_prompt(prompt: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in DuckBubble.wrap(" ".join(prompt), PROMPT_WIDTH):
		while line.length() > PROMPT_WIDTH:
			out.append(line.left(PROMPT_WIDTH))
			line = line.substr(PROMPT_WIDTH)
		out.append(line)
	return out


## Pure: HUD cell of console line `line` (0 = the row under the header) at column `col`.
static func line_cell(col: int, line: int) -> Vector2i:
	return Vector2i(col, Hud.LOG.position.y + 1 + line)


## The tutorial state. Redraws (and moves the log) only when something changed: the screen calls
## this every physics frame.
func show_state(p_lines: PackedStringArray, p_current: int, p_prompt: PackedStringArray) -> void:
	var wrapped: PackedStringArray = wrap_prompt(p_prompt)
	if active and p_lines == lines and p_current == current and wrapped == prompt_lines:
		return
	active = true
	lines = p_lines
	current = p_current
	prompt_lines = wrapped
	if is_instance_valid(log_panel):
		var first: int = mini(prompt_lines.size(), Hud.LOG_LINES)
		log_panel.set_block(PROMPT_COL, first, Hud.LOG_LINES - first)
	queue_redraw()


## Back to the plain console: nothing drawn, the log full width again.
func clear() -> void:
	active = false
	lines = PackedStringArray()
	current = -1
	prompt_lines = PackedStringArray()
	if is_instance_valid(log_panel):
		log_panel.reset_block()
	queue_redraw()


## Every text row of the current state as {cell, text}, in draw order (tests).
func text_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active:
		return out
	for i: int in mini(lines.size(), Hud.LOG_LINES):
		out.append({"cell": line_cell(CHECKLIST_COL, i), "text": lines[i]})
		if i == current:
			out.append({"cell": line_cell(CURSOR_COL, i), "text": CURSOR})
	for i: int in mini(prompt_lines.size(), Hud.LOG_LINES):
		out.append({"cell": line_cell(PROMPT_COL, i), "text": prompt_lines[i]})
	return out


func _draw() -> void:
	for r: Dictionary in text_rows():
		GlyphFont.draw_cell(self, r["cell"], r["text"], Palette.INK, SCALE)
