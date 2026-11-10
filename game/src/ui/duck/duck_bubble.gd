class_name DuckBubble
extends Node2D
## The duck's text bubble in the HUD duck region (Story 3.6, FR45, D-047, D-S36-4): the `>o`
## duck at cell (0, 22) and the current line word-wrapped at 12 columns from row 23, revealed by a
## typewriter (TypewriterReveal) with a squeak on every line start (D-046, D-S36-6). Lines arrive
## through EventBus.duck_line_requested (VoiceService.say); up to MAX_PENDING wait in FIFO order.
## Clears whenever the flow leaves FIGHT (D-S36-8) and freezes while SimClock.paused (D-S36-12).
## Presentation only: it reads signal arguments and SimClock.paused, never writes sim state (AD-05).

const SCALE := 1
const DUCK_GLYPH := ">o"
## The duck glyph's HUD cell (top-left of the duck region).
const DUCK_CELL := Vector2i(0, 22)
## First text row and the text area: cols 0-11, rows 23-37.
const TEXT_ORIGIN := Vector2i(0, 23)
const WRAP_WIDTH := 12
const MAX_LINES := 15
## Presentation feel, not balance (D-S36-13).
const MAX_PENDING := 4
const HOLD_BASE_S := 2.0
const HOLD_PER_CHAR_S := 0.05
const CHARS_PER_S := TypewriterReveal.CHARS_PER_S

## Queued line texts and their ids (parallel, FIFO), excluding the line showing now.
var _queue: Array[String] = []
var _queue_ids: Array[StringName] = []
var _current_lines: PackedStringArray = PackedStringArray()
var _current_id: StringName = &""
var _reveal: TypewriterReveal = TypewriterReveal.new()
var _hold_s: float = 0.0
var _showing: bool = false


func _enter_tree() -> void:
	if not EventBus.duck_line_requested.is_connected(_on_duck_line_requested):
		EventBus.duck_line_requested.connect(_on_duck_line_requested)
	if not EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.connect(_on_flow_state_changed)


func _exit_tree() -> void:
	if EventBus.duck_line_requested.is_connected(_on_duck_line_requested):
		EventBus.duck_line_requested.disconnect(_on_duck_line_requested)
	if EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.disconnect(_on_flow_state_changed)


## Shows `text` now when idle, else queues it; a request beyond MAX_PENDING is dropped.
func enqueue(text: String, line_id: StringName = &"") -> void:
	if not _showing:
		_start_line(text, line_id)
		return
	if _queue.size() >= MAX_PENDING:
		Log.debug(&"voice", "duck line dropped, queue full (%s)" % line_id)
		return
	_queue.append(text)
	_queue_ids.append(line_id)


## Drops the queue and hides the bubble.
func clear() -> void:
	_queue.clear()
	_queue_ids.clear()
	_current_lines = PackedStringArray()
	_current_id = &""
	_reveal.set_line(0)
	_hold_s = 0.0
	_showing = false
	queue_redraw()


func is_showing() -> bool:
	return _showing


func current_lines() -> PackedStringArray:
	return _current_lines


func current_id() -> StringName:
	return _current_id


## The queued texts, oldest first (not including the line showing now).
func pending() -> Array[String]:
	return _queue.duplicate()


## The reveal seam (D-S36-11): 3.7 calls reveal().set_revealed(n) from the voice.
func reveal() -> TypewriterReveal:
	return _reveal


func hold_left() -> float:
	return _hold_s


func _process(delta: float) -> void:
	step(delta)


## One presentation step of `delta` seconds (the _process body, callable from tests).
func step(delta: float) -> void:
	if not _showing or SimClock.paused:
		return
	if not _reveal.is_done():
		_reveal.advance(delta)
		# Redraw on any change, including a count set from outside (the 3.7 voice seam).
		if _reveal.revealed != _drawn_revealed:
			_drawn_revealed = _reveal.revealed
			queue_redraw()
		return
	_hold_s -= delta
	if _hold_s > 0.0:
		return
	if _queue.is_empty():
		clear()
		return
	var text: String = _queue.pop_front()
	var line_id: StringName = _queue_ids.pop_front()
	_start_line(text, line_id)


var _drawn_revealed: int = 0


func _start_line(text: String, line_id: StringName) -> void:
	_drawn_revealed = 0
	_current_lines = DuckBubble.wrap(text, WRAP_WIDTH)
	_current_id = line_id
	_reveal.set_line(revealable_length(_current_lines))
	_hold_s = hold_seconds(_reveal.length)
	_showing = true
	AudioManager.play_squeak()
	queue_redraw()


func _draw() -> void:
	if not _showing:
		return
	GlyphFont.draw_cell(self, DUCK_CELL, DUCK_GLYPH, Palette.INK, SCALE)
	var shown: PackedStringArray = visible_lines(_current_lines, _reveal.revealed)
	for i: int in mini(shown.size(), MAX_LINES):
		if shown[i].is_empty():
			continue
		GlyphFont.draw_cell(self, line_cell(i), shown[i], Palette.INK, SCALE)


func _on_duck_line_requested(line_id: StringName, text: String) -> void:
	enqueue(text, line_id)


func _on_flow_state_changed(_from: int, to: int) -> void:
	if to != Game.FlowState.FIGHT:
		clear()


## Greedy word wrap on spaces (D-S36-4): no word is ever split; a word wider than `width` stays on
## its own line (DuckLineDef.validate() rejects such text). Runs of spaces count as one. Pure.
static func wrap(text: String, width: int = WRAP_WIDTH) -> PackedStringArray:
	var out := PackedStringArray()
	var line: String = ""
	for word: String in text.split(" ", false):
		if line.is_empty():
			line = word
		elif line.length() + 1 + word.length() <= width:
			line += " " + word
		else:
			out.append(line)
			line = word
	if not line.is_empty():
		out.append(line)
	return out


## Characters the typewriter reveals for wrapped `lines`: the line texts plus one break between
## lines (the joined text with single spaces), so 3.7's spoken index maps onto it. Pure.
static func revealable_length(lines: PackedStringArray) -> int:
	return " ".join(lines).length()


## The visible part of each wrapped line when `revealed` characters of the joined text are shown.
## Pure.
static func visible_lines(lines: PackedStringArray, revealed: int) -> PackedStringArray:
	var out := PackedStringArray()
	var start: int = 0
	for line: String in lines:
		out.append(line.substr(0, clampi(revealed - start, 0, line.length())))
		start += line.length() + 1
	return out


## Seconds a fully revealed line of `length` characters stays up (D-S36-5). Pure.
static func hold_seconds(length: int) -> float:
	return HOLD_BASE_S + HOLD_PER_CHAR_S * float(maxi(length, 0))


## HUD cell of wrapped line `index` (0 = row 23). Pure.
static func line_cell(index: int) -> Vector2i:
	return Vector2i(TEXT_ORIGIN.x, TEXT_ORIGIN.y + index)


## Every HUD cell a wrapped line `text` at `index` occupies, one per character. Pure.
static func line_cells(index: int, text: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var origin: Vector2i = line_cell(index)
	for i: int in text.length():
		out.append(Vector2i(origin.x + i, origin.y))
	return out


## Every cell the bubble draws for `text` (the duck glyph plus the wrapped lines). Pure.
static func cells_for_text(text: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in DUCK_GLYPH.length():
		out.append(Vector2i(DUCK_CELL.x + i, DUCK_CELL.y))
	var lines: PackedStringArray = DuckBubble.wrap(text, WRAP_WIDTH)
	for i: int in lines.size():
		out.append_array(line_cells(i, lines[i]))
	return out
