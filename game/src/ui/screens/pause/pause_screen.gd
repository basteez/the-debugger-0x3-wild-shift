class_name PauseScreen
extends Node2D
## Pause overlay (Story 1.7 AC2, AC3). Main instances it on EventBus.pause_toggled(true) and frees
## it on false (DC6). Opaque BG over the 640x360 base (DC7), glyph text only (AD-07).
## Presentation only: M or a click on the mute label toggles the Master mute (consumed here, so it
## never resumes; Story 7.3: the new value is saved through SaveService.set_muted); Esc / P and any other click belong to Game, which resumes on them (DC2,
## D-FIX-FS-1). It never writes flow or pause state.
## Story 7.4 (AC 2-4, D-S74-3): B or a click on the `[B] DEBUG BUILD` row flips the assist (consumed
## here like M, so it never resumes) and saves it through SaveService.set_assist; it applies from the
## next fight attempt (D-S74-1).
## Story 9.3 (D-S93-3): while a FIGHT runs with an attempt copy (Game.run.assist) that differs from the
## saved value, the row adds ASSIST_PENDING_SUFFIX (`: NEXT ATTEMPT`); the next FIGHT entry clears it.
## Story 7.7 (FR55, AC 4, D-S77-1): F, pad R3 or a click on the `[F] FULLSCREEN` row toggles
## fullscreen inside this input handler (Fullscreen.toggle, a user gesture) and never resumes.

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
## D-FIX-FS-1: Esc may never reach the canvas in browser fullscreen, so P and a click resume too.
## Story 7.5 (AC 15, D-S75-5): the gamepad mapping row, in the free slot between the last controls
## row (192) and the resume row (240). Start pauses and resumes; Select mutes; B flips the assist.
const PAD_HINT_TEXT := "PAD STICK X A LB RB RT Y START"
const PAD_HINT_TOP_Y := 216
const RESUME_TEXT := "[ESC / P / CLICK] RESUME"
const RESUME_TOP_Y := 240
## Story 7.7 [design call] (D-S77-1 changed): the option rows step by 24 like the controls (mute 264,
## assist 288, fullscreen 312, was 272 / 304 / 336) so the new fullscreen row keeps the 16-px gutter
## (bottom 328 <= 344); 336 would end at 352, inside the base but outside the gutter.
const MUTE_TOP_Y := 264
const MUTE_ON_TEXT := "[M] MUTE ON"
const MUTE_OFF_TEXT := "[M] MUTE OFF"
## Story 7.4 (D-S74-3, D-S74-8): the assist row (code constants like the mute row).
const ASSIST_TOP_Y := 288
const ASSIST_ON_TEXT := "[B] DEBUG BUILD ON"
const ASSIST_OFF_TEXT := "[B] DEBUG BUILD OFF"
## Story 9.3 (D-S93-3, D-S93-4): appended while the toggle waits for the next attempt (code constant
## like the other pause rows; its width is asserted in tests).
const ASSIST_PENDING_SUFFIX := ": NEXT ATTEMPT"
## The InputMap action of the assist key (the title's option action, key B).
const ASSIST_ACTION := &"title_option_debug_build"
## Story 7.7 (D-S77-1): the fullscreen row, below the assist row.
const FULLSCREEN_TOP_Y := 312
const FULLSCREEN_ON_TEXT := "[F] FULLSCREEN ON"
const FULLSCREEN_OFF_TEXT := "[F] FULLSCREEN OFF"
## The InputMap action of the fullscreen key (the title's option action: key F, pad R3).
const FULLSCREEN_ACTION := &"title_option_fullscreen"

var _muted: bool = false
var _assist: bool = false
var _fullscreen: bool = false
## Story 9.3 (D-S93-3): the assist row's pending suffix as last drawn.
var _assist_pending: bool = false


func _ready() -> void:
	_muted = AudioManager.is_master_muted()
	_assist = SaveService.assist
	_fullscreen = Fullscreen.is_on()
	_assist_pending = live_assist_pending()


## Story 7.7: the row follows the real window mode (the web request is async; Esc can exit it).
## Story 9.3: the assist suffix follows the attempt copy (a retry or a new attempt clears it).
func _process(_delta: float) -> void:
	var on: bool = Fullscreen.is_on()
	if on != _fullscreen:
		_fullscreen = on
		queue_redraw()
	var pending: bool = live_assist_pending()
	if pending != _assist_pending:
		_assist_pending = pending
		queue_redraw()


## Pure (Story 9.3, D-S93-3): the toggle waits for the next attempt (a FIGHT whose copy differs).
static func assist_pending(flow_state: int, attempt_assist: bool, saved_assist: bool) -> bool:
	return flow_state == Game.FlowState.FIGHT and attempt_assist != saved_assist


## Story 9.3: assist_pending with the live values (read only, presentation side).
func live_assist_pending() -> bool:
	return Game.run != null and assist_pending(Game.flow_state, Game.run.assist, SaveService.assist)


## Pure: every text row, top to bottom. The mute row reads ON when the Master bus is muted.
## Story 7.4: the assist row reads ON when `assist` is on. Story 7.7: the fullscreen row is last.
## Story 9.3 (D-S93-3): `pending` adds the next-attempt suffix to the assist row (default: today's rows).
static func lines_for(muted: bool, assist: bool = false, fullscreen: bool = false, pending: bool = false) -> PackedStringArray:
	var lines := PackedStringArray([TITLE_TEXT])
	lines.append_array(CONTROLS)
	lines.append(PAD_HINT_TEXT)
	lines.append(RESUME_TEXT)
	lines.append(mute_text(muted))
	lines.append(assist_text(assist, pending))
	lines.append(fullscreen_text(fullscreen))
	return lines


static func fullscreen_text(on: bool) -> String:
	return FULLSCREEN_ON_TEXT if on else FULLSCREEN_OFF_TEXT


static func assist_text(assist: bool, pending: bool = false) -> String:
	return (ASSIST_ON_TEXT if assist else ASSIST_OFF_TEXT) + (ASSIST_PENDING_SUFFIX if pending else "")


static func mute_text(muted: bool) -> String:
	return MUTE_ON_TEXT if muted else MUTE_OFF_TEXT


## Pure: top y of each row of lines_for, same order.
static func row_tops() -> PackedInt32Array:
	var tops := PackedInt32Array([TITLE_TOP_Y])
	for i: int in CONTROLS.size():
		tops.append(CONTROLS_TOP_Y + i * CONTROLS_STEP)
	tops.append(PAD_HINT_TOP_Y)
	tops.append(RESUME_TOP_Y)
	tops.append(MUTE_TOP_Y)
	tops.append(ASSIST_TOP_Y)
	tops.append(FULLSCREEN_TOP_Y)
	return tops


## Pure: the clickable rect of the mute label (the glyph row plus a half-cell margin), canvas space.
static func mute_label_rect(muted: bool) -> Rect2:
	return row_rect(mute_text(muted), MUTE_TOP_Y)


## Story 7.4: the clickable rect of the assist label, same shape as mute_label_rect. Pure.
static func assist_label_rect(assist: bool, pending: bool = false) -> Rect2:
	return row_rect(assist_text(assist, pending), ASSIST_TOP_Y)


## Story 7.7: the clickable rect of the fullscreen label, same shape as mute_label_rect. Pure.
static func fullscreen_label_rect(on: bool) -> Rect2:
	return row_rect(fullscreen_text(on), FULLSCREEN_TOP_Y)


## The BG-backed box behind one row: one cell left and right, half a cell above and below.
static func row_rect(text: String, top_y: int) -> Rect2:
	return Rect2(TitleScreen.centred_x(text) - GlyphFont.CELL, top_y - GlyphFont.CELL * 0.5,
			GlyphFont.text_width(text, TEXT_SCALE) + 2 * GlyphFont.CELL, GlyphFont.size_for(TEXT_SCALE) + GlyphFont.CELL)


## Pure: true for a fresh M press or a left click inside the mute label.
static func is_mute_toggle(event: InputEvent, muted: bool) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton: # Story 7.5: pad Select
		return InputMap.has_action(&"mute") and event.is_action_pressed(&"mute")
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
			and mute_label_rect(muted).has_point(mouse.position)


## Story 7.4: true for a fresh B press or a left click inside the assist label. Pure.
static func is_assist_toggle(event: InputEvent, assist: bool, pending: bool = false) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton: # Story 7.5: pad B
		return InputMap.has_action(ASSIST_ACTION) and event.is_action_pressed(ASSIST_ACTION)
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
			and assist_label_rect(assist, pending).has_point(mouse.position)


## Story 7.7: true for a fresh F / R3 press or a left click inside the fullscreen label. Pure.
static func is_fullscreen_toggle(event: InputEvent, on: bool) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton:
		return InputMap.has_action(FULLSCREEN_ACTION) and event.is_action_pressed(FULLSCREEN_ACTION)
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
			and fullscreen_label_rect(on).has_point(mouse.position)


## _input, not _unhandled_input: the placeholder under Screens sits later in the tree, so it would
## see M first and consume it as its any-key advance (which DC4 makes a no-op while paused).
func _input(event: InputEvent) -> void:
	if is_fullscreen_toggle(event, _fullscreen):
		get_viewport().set_input_as_handled()
		Fullscreen.toggle() # Story 7.7 (AC 4): never resumes; the row follows the mode in _process
		return
	if is_assist_toggle(event, _assist, live_assist_pending()):
		get_viewport().set_input_as_handled()
		SaveService.set_assist(not _assist)
		_assist = SaveService.assist
		_assist_pending = live_assist_pending()
		queue_redraw()
		return
	if not is_mute_toggle(event, _muted):
		return
	get_viewport().set_input_as_handled()
	AudioManager.set_master_muted(not AudioManager.is_master_muted())
	_muted = AudioManager.is_master_muted()
	SaveService.set_muted(_muted) # Story 7.3 (D-S73-7 overturned): the mute is kept across sessions
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(Const.BASE_RES)), Palette.BG)
	var lines: PackedStringArray = lines_for(_muted, _assist, _fullscreen, live_assist_pending())
	var tops: PackedInt32Array = row_tops()
	for i: int in lines.size():
		GlyphFont.draw_at(self, Vector2(TitleScreen.centred_x(lines[i]), tops[i]), lines[i], Palette.INK, TEXT_SCALE)
