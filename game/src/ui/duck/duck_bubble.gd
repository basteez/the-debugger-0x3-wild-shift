class_name DuckBubble
extends Node2D
## The duck's text bubble in the HUD duck region (Story 3.6, FR45, D-047, D-S36-4): the `>o`
## duck at cell (0, 22) and the current line word-wrapped at 12 columns from row 23, revealed by a
## typewriter (TypewriterReveal) with a squeak on every line start (D-046, D-S36-6). Lines arrive
## through EventBus.duck_line_requested (VoiceService.say); up to MAX_PENDING wait in FIFO order.
## Clears whenever the flow leaves FIGHT or HARVEST (D-S36-8, Story 3.8 D-S38-11) and freezes while SimClock.paused (D-S36-12).
## Story 3.7: when VoiceService can speak, the squeak plays first and the voice starts after
## SQUEAK_LEAD_S (D-S37-6); the voice then drives the reveal through
## EventBus.duck_character_spoken (set_revealed(char_index + 1), D-S37-4) and the hold starts at
## EventBus.duck_line_finished (D-S37-5). A cut line (stop, pause, watchdog) finishes silently on
## the timer (D-S37-7). clear() and a pause call VoiceService.stop().
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
## Squeak first, then the voice (D-S37-6): seconds between the line start and the voice start.
const SQUEAK_LEAD_S := 0.15

## The voice seam (VoiceService; tests swap in a fake with can_speak / speak_pending / stop).
var voice: Node = VoiceService

## Queued line texts and their ids (parallel, FIFO), excluding the line showing now.
var _queue: Array[String] = []
var _queue_ids: Array[StringName] = []
var _current_lines: PackedStringArray = PackedStringArray()
var _current_id: StringName = &""
var _reveal: TypewriterReveal = TypewriterReveal.new()
var _hold_s: float = 0.0
var _showing: bool = false
## The current line is voiced: the reveal waits for the voice (set when the line starts).
var _voice_line: bool = false
## The voice is speaking the current line and drives the reveal; the timer and the hold wait.
var _voice_speaking: bool = false
## Squeak lead left before speak_pending() runs (voiced lines only).
var _lead_s: float = 0.0


func _enter_tree() -> void:
	if not EventBus.duck_line_requested.is_connected(_on_duck_line_requested):
		EventBus.duck_line_requested.connect(_on_duck_line_requested)
	if not EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.connect(_on_flow_state_changed)
	if not EventBus.duck_character_spoken.is_connected(_on_duck_character_spoken):
		EventBus.duck_character_spoken.connect(_on_duck_character_spoken)
	if not EventBus.duck_line_finished.is_connected(_on_duck_line_finished):
		EventBus.duck_line_finished.connect(_on_duck_line_finished)


func _exit_tree() -> void:
	if EventBus.duck_line_requested.is_connected(_on_duck_line_requested):
		EventBus.duck_line_requested.disconnect(_on_duck_line_requested)
	if EventBus.flow_state_changed.is_connected(_on_flow_state_changed):
		EventBus.flow_state_changed.disconnect(_on_flow_state_changed)
	if EventBus.duck_character_spoken.is_connected(_on_duck_character_spoken):
		EventBus.duck_character_spoken.disconnect(_on_duck_character_spoken)
	if EventBus.duck_line_finished.is_connected(_on_duck_line_finished):
		EventBus.duck_line_finished.disconnect(_on_duck_line_finished)
	if _voice_speaking:
		_voice_speaking = false
		voice.stop()


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


## Drops the queue and hides the bubble. Hidden first, then the voice is stopped, so the
## duck_line_finished that stop() emits finds no showing line (AC 6). Story 3.8 (AC 9, D-S38-11):
## the voice is always stopped (a no-op when nothing speaks), so no line outlives a flow exit.
func clear() -> void:
	_showing = false
	_voice_line = false
	_voice_speaking = false
	_lead_s = 0.0
	_queue.clear()
	_queue_ids.clear()
	_current_lines = PackedStringArray()
	_current_id = &""
	_reveal.set_line(0)
	_hold_s = 0.0
	voice.stop()
	queue_redraw()


func is_showing() -> bool:
	return _showing


## Story 4.4 (D-S44-4): true when a line requested now would be shown or queued, not dropped (idle,
## or the queue below MAX_PENDING). DuckDirector requests only while this holds. Read-only.
func has_room() -> bool:
	return not _showing or _queue.size() < MAX_PENDING


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


## True while the voice speaks the current line (it drives the reveal).
func is_voice_speaking() -> bool:
	return _voice_speaking


## Squeak lead left before the voice starts (0 when the line is not voiced or already started).
func lead_left() -> float:
	return _lead_s


func _process(delta: float) -> void:
	step(delta)


## One presentation step of `delta` seconds (the _process body, callable from tests).
func step(delta: float) -> void:
	if not _showing:
		return
	if SimClock.paused:
		# D-S37-7: a pause cuts the speech once; the rest of the text finishes on the timer.
		if _voice_speaking:
			_cut_voice()
		return
	if _lead_s > 0.0:
		_lead_s -= delta
		if _lead_s > 0.0:
			return
		_lead_s = 0.0
		# Set before the call: a voice that finishes inside speak_pending (no letters) must reach
		# _on_duck_line_finished with the flag up, or the bubble would wait forever.
		_voice_speaking = true
		if not bool(voice.speak_pending(_current_id, " ".join(_current_lines))):
			_voice_speaking = false
			_reveal.release()
		return
	if _voice_speaking:
		return
	if not _reveal.is_done():
		_reveal.advance(delta)
		_sync_draw()
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
	_voice_speaking = false
	_voice_line = bool(voice.can_speak())
	_lead_s = SQUEAK_LEAD_S if _voice_line else 0.0
	if _voice_line:
		_reveal.set_revealed(0) # the voice will drive the reveal; nothing shows during the lead
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


## D-S37-4: the voice reveals up to and including the spoken character.
func _on_duck_character_spoken(char_index: int) -> void:
	if not _showing or not _voice_speaking:
		return
	_reveal.set_revealed(maxi(_reveal.revealed, char_index + 1))
	_sync_draw()


## D-S37-5: the voice line ended. Completed: the rest shows now and the hold starts; cut: the timer
## takes the reveal back from where the voice left it (silent), then the hold. Ignored when the
## bubble is cleared or shows another line.
func _on_duck_line_finished(line_id: StringName, completed: bool) -> void:
	if not _showing or not _voice_speaking or line_id != _current_id:
		return
	_voice_speaking = false
	if completed:
		_reveal.set_revealed(_reveal.length)
	else:
		_reveal.release()
	_sync_draw()


## Stops the voice for the current line and hands the reveal back to the timer.
func _cut_voice() -> void:
	_voice_speaking = false
	voice.stop()
	_reveal.release()
	_sync_draw()


## Redraws on any change of the revealed count, including one set by the voice.
func _sync_draw() -> void:
	if _reveal.revealed != _drawn_revealed:
		_drawn_revealed = _reveal.revealed
		queue_redraw()


## Story 3.8 (AC 9, D-S38-11): leaving FIGHT clears the bubble and cuts the voice, so a fight line
## never finishes into HARVEST; leaving HARVEST does the same for the harvest line (E5). The HARVEST
## screen requests its line after this (deferred), so the line survives its own entry.
## Story 6.7 (AC 5, D-S67-6): leaving INTRO (skip or cap) clears the intro line the same way.
func _on_flow_state_changed(from: int, to: int) -> void:
	if to != Game.FlowState.FIGHT or from == Game.FlowState.HARVEST or from == Game.FlowState.INTRO:
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
