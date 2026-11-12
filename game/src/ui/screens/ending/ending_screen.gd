class_name EndingScreen
extends Node2D
## The ENDING screen (Story 6.8, FR51, GDD "Ending"): one desk panel on a sim-frame timeline since
## Game.ending_start_frame (D-S68-1). Frames 0-29 the panel fades in (the developer back at the desk,
## the duck on the desk); frames 30/45/60/75 the four cells of the reserved nibble light one at a
## time and `0xFF` shows from 75 (a presentation constant, D-S68-9: the sim register is untouched);
## frames 90-299 the commit row types `fix: wild shift` at 20 characters per second (D-S68-2); frame
## 300 requests duck line 9 once (FR45) through VoiceService and the HUD bubble in duck-only mode;
## the credits block shows from frame 360, or 540 after the stretch summary card (D-S68-3). The
## timeline holds at Game.ENDING_HOLD_FRAMES (30 s) and never times out: the player leaves with
## any key or left click once Game.can_leave_ending (D-S68-7).
## Presentation only: it reads Game, SimClock and the ending text data, calls Game.finish_ending and
## never writes flow state, the register, the arena or the sim input buffer (AD-05, AD-08). A pause
## freezes the timeline (sim frames) and the cursor blink (DC4). Ink only (red is for warnings).
## All game text comes from data/ending/ending_text.tres (AC 18, D-S68-8).

const GameFlow := preload("res://src/autoloads/game.gd")
const TEXT: EndingText = preload("res://data/ending/ending_text.tres")
## Duck line 9 in data/duck/duck_lines.tres (GDD Duck row 9).
const LINE_ID := &"ending"

## Timeline beats (indices returned by beat_at).
enum Beat { FADE, NIBBLE, COMMIT, LINE, SUMMARY, CREDITS, HOLD }

## Timeline frames (sim frames since Game.ending_start_frame, 60 Hz).
const FADE_FRAMES := 30
const NIBBLE_START_FRAME := 30
const NIBBLE_STEP_FRAMES := 15
const NIBBLE_CELLS := 4
const FULL_FRAME := NIBBLE_START_FRAME + (NIBBLE_CELLS - 1) * NIBBLE_STEP_FRAMES # 75
const COMMIT_START_FRAME := 90
const COMMIT_CHARS_PER_S := 20.0
const LINE_FRAME := 300
const SUMMARY_FRAME := 360
const CREDITS_FRAME := 360
const CREDITS_AFTER_SUMMARY_FRAME := 540
const HOLD_FRAME := GameFlow.ENDING_HOLD_FRAMES

const TEXT_SCALE := 2
const SMALL_SCALE := 1
## Layout on the 8-px grid of the 640x360 base. Everything under row 22 (y 176) stays right of the
## HUD duck region (cols 0-11, x < 96), where the bubble shows line 9.
const CAPTION_Y := 16
const DESK_Y := 48
const DESK_ROW_STEP := 16
const REGISTER_Y := 104
const FULL_CAPTION_Y := 128
const COMMIT_Y := 152
const SUMMARY_Y := 184
const SUMMARY_ROW_STEP := 24
const CREDITS_Y := 240
const CREDITS_ROW_STEP := 12
const PROMPT_Y := 312
## The commit cursor blinks on presentation frames (never the timeline).
const BLINK_PERIOD := 30
const BYTE_BITS := 8

## Set by Main from FeatureFlags.ending_summary at screen build (AD-12; never read in the sim).
var summary_enabled: bool = false
## Presentation frames since the screen opened while not paused: the cursor blink only.
var frames_open: int = 0
## The beat on screen, -1 before the first poll.
var shown_beat: int = -1
## Timeline frame of the last poll (clamped to HOLD_FRAME).
var timeline_frame: int = 0
## Per-screen latch (freed with the screen): line 9 is requested once.
var line_requested: bool = false
## Seam for tests: the line request (default: VoiceService, which emits EventBus.duck_line_requested).
var say_line: Callable = func(id: StringName) -> void: VoiceService.say(String(id))


func _init() -> void:
	name = &"EndingScreen"
	modulate.a = 0.0 # the panel fades in from its first frame


func _ready() -> void:
	Log.info(&"flow", "ending opened summary=%s" % summary_shown())


func _exit_tree() -> void:
	# Story 6.8 (AC 10, B4): leaving the ending never leaves the duck speaking. Not on a debug jump
	# into a fight, whose own line may start this frame (6.7 review finding).
	if is_instance_valid(VoiceService) and Game.flow_state != GameFlow.FlowState.FIGHT:
		VoiceService.stop()


## Pure: the timeline frame for `frames_since_start`, clamped to [0, HOLD_FRAME] (no beat reads a
## frame past the hold).
static func clamp_frames(frames_since_start: int) -> int:
	return clampi(frames_since_start, 0, HOLD_FRAME)


## Pure: the beat (Beat) at `frames` into the ending; -1 before it. With `summary_on` the summary
## card has frames 360-539 and the credits start at 540.
static func beat_at(frames: int, summary_on: bool = false) -> int:
	if frames < 0:
		return -1
	if frames >= HOLD_FRAME:
		return Beat.HOLD
	if frames < NIBBLE_START_FRAME:
		return Beat.FADE
	if frames < COMMIT_START_FRAME:
		return Beat.NIBBLE
	if frames < LINE_FRAME:
		return Beat.COMMIT
	if frames < SUMMARY_FRAME:
		return Beat.LINE
	if frames < credits_start_frame(summary_on):
		return Beat.SUMMARY
	return Beat.CREDITS


## Pure: the panel's fade-in alpha (presentation).
static func fade_alpha(frames: int) -> float:
	return clampf(float(frames) / FADE_FRAMES, 0.0, 1.0)


## Pure: reserved-nibble cells lit at `frames` (0 to 4): one more every 15 frames from frame 30.
static func nibble_cells_lit(frames: int) -> int:
	if frames < NIBBLE_START_FRAME:
		return 0
	return mini((frames - NIBBLE_START_FRAME) / NIBBLE_STEP_FRAMES + 1, NIBBLE_CELLS)


## Pure: true once the screen shows `0xFF` (all four reserved cells lit).
static func full_shown(frames: int) -> bool:
	return frames >= FULL_FRAME


## Pure: characters of the commit message typed at `frames` (D-S68-2, TypewriterReveal's rule).
static func typed_chars(frames: int, length: int = -1) -> int:
	var n: int = TEXT.commit_message.length() if length < 0 else length
	if frames < COMMIT_START_FRAME:
		return 0
	return TypewriterReveal.visible_chars(float(frames - COMMIT_START_FRAME) / Const.SIM_HZ, COMMIT_CHARS_PER_S, n)


## Pure: the frame the credits block shows from (AC 4 e, AC 14).
static func credits_start_frame(summary_on: bool) -> int:
	return CREDITS_AFTER_SUMMARY_FRAME if summary_on else CREDITS_FRAME


## Pure: true once the credits block is visible.
static func credits_visible(frames: int, summary_on: bool) -> bool:
	return frames >= credits_start_frame(summary_on)


## Pure [STRETCH] (AC 14, 16, 17): the card shows from frame 360 (and stays) when the flag is on
## and the run used no debug jump.
static func summary_visible(frames: int, summary_flag: bool, debug_jumped: bool) -> bool:
	return summary_flag and not debug_jumped and frames >= SUMMARY_FRAME


## Pure [STRETCH]: clear time `m:ss`, floored to whole seconds.
static func format_clear(frames: int) -> String:
	var seconds: int = maxi(frames, 0) / Const.SIM_HZ
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Pure (D-S67-4, AC 6): the leave gesture is the Intro's skip rule (no modifier, Esc / P, F-key,
## echo or release; a left click counts).
static func leave_allowed(event: InputEvent) -> bool:
	return IntroScreen.skip_allowed(event)


## Pure: the register row (high nibble first): `lit` reserved cells set, the owned nibble full.
static func register_row(lit: int) -> String:
	var row: String = ""
	for i: int in BYTE_BITS:
		var on: bool = i >= NIBBLE_CELLS or i < lit
		row += TEXT.cell_on if on else TEXT.cell_off
	return row


## Pure: the left x that centres `text` at `scale` on the base width, snapped to the 8-px grid.
static func centred_x(text: String, scale: int) -> int:
	var x: int = maxi((Const.BASE_RES.x - GlyphFont.text_width(text, scale)) / 2, 0)
	return x - x % GlyphFont.CELL


## Every string the screen can draw (font coverage, tests).
static func text_rows() -> PackedStringArray:
	return TEXT.all_text()


## True when the stretch card is part of this ending (flag on and a run without debug jumps).
func summary_shown() -> bool:
	return summary_enabled and not bool(Game.ending_summary.get(&"debug_jumped", true))


## One step at sim frame `frame`: the beat change (logged once per beat) and the line latch.
## True while the ending is on. Never leaves the ending (the hold is not a cap, D-S68-1).
func poll(frame: int) -> bool:
	if Game.flow_state != GameFlow.FlowState.ENDING:
		return false
	var f: int = clamp_frames(frame - Game.ending_start_frame)
	if f != timeline_frame or shown_beat < 0:
		timeline_frame = f
		modulate.a = fade_alpha(f) # presentation fade of the whole panel (frames 0-29)
		queue_redraw()
	var beat: int = beat_at(f, summary_shown())
	if beat != shown_beat:
		shown_beat = beat
		Log.info(&"flow", "ending beat %s at f=%d" % [Beat.keys()[beat], frame])
		queue_redraw()
	if f >= LINE_FRAME and not line_requested:
		line_requested = true
		say_line.call(LINE_ID)
	return true


func _physics_process(_delta: float) -> void:
	if not poll(SimClock.sim_frame) or SimClock.paused:
		return
	frames_open += 1
	if frames_open % BLINK_PERIOD == 0:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Game.flow_state != GameFlow.FlowState.ENDING or not leave_allowed(event):
		return
	get_viewport().set_input_as_handled() # a press before the gate is consumed and does nothing
	try_leave(SimClock.sim_frame)


## A leave press at sim frame `frame`: TITLE once the gate is open, never while paused. True if it moved.
func try_leave(frame: int) -> bool:
	if not Game.can_leave_ending(frame):
		return false
	return Game.finish_ending(frame, true)


func _draw() -> void:
	var f: int = timeline_frame
	draw_rect(Rect2(Vector2.ZERO, Vector2(Const.BASE_RES)), Palette.BG)
	_draw_text(TEXT.caption, CAPTION_Y, TEXT_SCALE)
	for i: int in TEXT.desk_rows.size():
		_draw_text(TEXT.desk_rows[i], DESK_Y + i * DESK_ROW_STEP, TEXT_SCALE)
	_draw_register(nibble_cells_lit(f))
	if full_shown(f):
		_draw_text(TEXT.full_caption, FULL_CAPTION_Y, TEXT_SCALE)
	if f >= COMMIT_START_FRAME:
		_draw_commit(typed_chars(f))
	if summary_visible(f, summary_enabled, bool(Game.ending_summary.get(&"debug_jumped", true))):
		_draw_summary()
	if credits_visible(f, summary_shown()):
		for i: int in TEXT.credit_lines.size():
			_draw_text(TEXT.credit_lines[i], CREDITS_Y + i * CREDITS_ROW_STEP, SMALL_SCALE)
		_draw_text(TEXT.prompt, PROMPT_Y, TEXT_SCALE)


func _draw_text(text: String, y: int, scale: int) -> void:
	GlyphFont.draw_at(self, Vector2(centred_x(text, scale), y), text, Palette.INK, scale)


## The byte: lit reserved cells are drawn inverted (INK cell, BG glyph), the RegisterPanel style.
func _draw_register(lit: int) -> void:
	var row: String = register_row(lit)
	var x0: int = centred_x(row, TEXT_SCALE)
	var size: int = GlyphFont.size_for(TEXT_SCALE)
	for i: int in row.length():
		var pos := Vector2(x0 + i * size, REGISTER_Y)
		var color: Color = Palette.INK
		if i < lit:
			draw_rect(Rect2(pos, Vector2(size, size)), Palette.INK)
			color = Palette.BG
		GlyphFont.draw_at(self, pos, row[i], color, TEXT_SCALE)


## The git-log row: the hash at once, the message typed, then the blinking cursor.
func _draw_commit(chars: int) -> void:
	var full: String = EndingText.commit_row(TEXT.commit_hash, TEXT.commit_message)
	var prefix_len: int = full.length() - TEXT.commit_message.length()
	var shown: String = full.substr(0, prefix_len + chars)
	var x: int = centred_x(full, TEXT_SCALE)
	GlyphFont.draw_at(self, Vector2(x, COMMIT_Y), shown, Palette.INK, TEXT_SCALE)
	if (frames_open / BLINK_PERIOD) % 2 == 0:
		var cx: int = x + GlyphFont.text_width(shown, TEXT_SCALE)
		GlyphFont.draw_at(self, Vector2(cx, COMMIT_Y), TEXT.cursor, Palette.INK, TEXT_SCALE)


## [STRETCH, cut first] The clear-time and hits card (AC 14), from Game's ENDING snapshot.
func _draw_summary() -> void:
	var rows: PackedStringArray = summary_rows(Game.ending_summary)
	for i: int in rows.size():
		_draw_text(rows[i], SUMMARY_Y + i * SUMMARY_ROW_STEP, TEXT_SCALE)


## Pure [STRETCH]: the card rows for a snapshot ({clear_frames, hits}).
static func summary_rows(summary: Dictionary) -> PackedStringArray:
	var clear: String = format_clear(int(summary.get(&"clear_frames", 0)))
	var hits: int = int(summary.get(&"hits", 0))
	return PackedStringArray([TEXT.clear_label + " " + clear, TEXT.hits_label + " " + str(hits)])
