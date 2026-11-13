class_name IntroScreen
extends Node2D
## The INTRO screen (Story 6.7, FR48, GDD "Intro"): three glyph panels of PANEL_FRAMES sim frames
## each (the developer at a desk at 2 a.m.; the duck squeeze and its quack; the screen tearing into
## glyphs over The Clearing), then a 30-frame hold on panel 3 until Game's 480-frame cap
## (Game.INTRO_MAX_FRAMES, D-S67-1) moves the flow to FIGHT 1. The squeak plays once at the start of
## panel 2 (D-S67-5); duck line 1 (`intro_handover`, FR45) is requested once at the start of panel 3,
## through VoiceService.say and the HUD's duck bubble in duck-only mode (D-S67-2).
## Skippable from its first frame with any key or left click (D-040), except the title input frame
## (Game.can_skip_intro), Esc / P (pause, AC 6), modifiers and function keys (D-S67-4).
## Presentation only: it reads Game and SimClock, calls Game.finish_intro and never writes flow
## state, the arena or the sim input buffer (AD-05, AD-08). Panels follow sim frames since
## Game.intro_start_frame, so a pause freezes them (DC4).

const GameFlow := preload("res://src/autoloads/game.gd")
## Duck line 1 in data/duck/duck_lines.tres (GDD Duck row 1).
const LINE_ID := &"intro_handover"
## About 2.5 s per panel at 60 Hz (GDD Intro row).
const PANEL_FRAMES := 150
const PANEL_COUNT := 3
## The panels end here; the screen holds panel 3 until the cap (D-S67-1).
const PANELS_END_FRAMES := PANEL_FRAMES * PANEL_COUNT
## Panel 2 squeaks on entry, panel 3 requests the duck line on entry.
const SQUEAK_PANEL := 1
const LINE_PANEL := 2
const TEXT_SCALE := 2
## Top of the first caption row, on the 8-px grid; rows are 2 glyph rows apart. Above the HUD duck
## region (rows 22-37), where the bubble shows line 1 on panel 3.
const TOP_Y := 96
const ROW_STEP := 32
## Placeholder captions (D-S67-3): final art is 7.x. Story 6.9 (AC 10): the wording is game text,
## read from data/text/screen_text.tres (3 panels, 2 + 2 + 1 rows).
const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
## Panel 3's glyph tear (presentation only): a row of glyphs drawn over the caption, its characters
## jittered by row offset on the presentation frame counter.
const TEAR_ROW := "#/\\|=+*%#/\\|=+*%"
const TEAR_Y := 64
const TEAR_JITTER_PX := 8
const TEAR_PERIOD := 4

## Presentation frames since the screen opened: drives only the tear jitter, never the panel index.
var frames_open: int = 0
## The panel on screen (0-2), -1 before the first physics frame.
var shown_panel: int = -1
## Per-screen latches (freed with the screen): the squeak and the line are requested once.
var squeak_played: bool = false
var line_requested: bool = false
## Seams for tests: the squeak and the line request (defaults: AudioManager and VoiceService).
var squeak: Callable = func() -> void: AudioManager.play_squeak()
var say_line: Callable = func(id: StringName) -> void: VoiceService.say(String(id))


func _init() -> void:
	name = &"IntroScreen"


## The first panel shows from the next physics frame (poll), so building the screen inside a flow
## change never re-enters Game.
func _ready() -> void:
	Log.info(&"flow", "intro opened")


func _exit_tree() -> void:
	# D-S67-6 (B5): freed while the flow is still INTRO never leaves the duck speaking. A skip or
	# cap exit is already cleared by DuckBubble on the flow change; stopping here (end of frame)
	# could cut a line the FIGHT 1 entry requested in the same frame (review finding).
	if is_instance_valid(VoiceService) and Game.flow_state in [GameFlow.FlowState.INTRO]:
		VoiceService.stop()


## Pure: the panel (0, 1, 2) at `frames_since_start` sim frames into the Intro; -1 before it or
## once the panels have ended (the hold).
static func panel_at(frames_since_start: int) -> int:
	if frames_since_start < 0 or frames_since_start >= PANELS_END_FRAMES:
		return -1
	return frames_since_start / PANEL_FRAMES


## Pure: true once the three panels have played (the hold on panel 3 until the cap).
static func hold_started(frames_since_start: int) -> bool:
	return frames_since_start >= PANELS_END_FRAMES


## Pure: the panel drawn at `frames_since_start`: panel 3 stays up through the hold.
static func display_panel(frames_since_start: int) -> int:
	return PANEL_COUNT - 1 if hold_started(frames_since_start) else maxi(panel_at(frames_since_start), 0)


## Pure (D-S67-4): the skip gesture. The placeholder's advance rule (a fresh non-echo key press that
## is not a modifier, Esc or a function key, or a left-button press), minus the pause key (P).
static func skip_allowed(event: InputEvent) -> bool:
	return PlaceholderScreen.is_advance(event) and not GameFlow.is_pause_press(event)


## Pure: the caption rows of `panel` (0-2); none for any other index.
static func caption_for(panel: int) -> PackedStringArray:
	if panel < 0 or panel >= PANEL_COUNT:
		return PackedStringArray()
	return SCREEN_TEXT.caption_for(panel)


## Every caption row and the tear row (font coverage, tests).
static func text_rows() -> PackedStringArray:
	var rows := PackedStringArray([TEAR_ROW])
	for panel: int in PANEL_COUNT:
		rows.append_array(caption_for(panel))
	return rows


## One step of the Intro at sim frame `frame`: the cap first (Game owns the rule), then the panel
## change and its latches. Called once per physics frame; true while the Intro is still on.
func poll(frame: int) -> bool:
	if Game.flow_state != GameFlow.FlowState.INTRO:
		return false
	if Game.finish_intro(frame):
		return false
	var panel: int = display_panel(frame - Game.intro_start_frame)
	if panel != shown_panel:
		_enter_panel(panel)
	return true


func _enter_panel(panel: int) -> void:
	shown_panel = panel
	Log.info(&"flow", "intro panel %d opened" % (panel + 1))
	if panel == SQUEAK_PANEL and not squeak_played:
		squeak_played = true
		squeak.call()
	if panel == LINE_PANEL and not line_requested:
		line_requested = true
		say_line.call(LINE_ID)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Game.flow_state != GameFlow.FlowState.INTRO or not skip_allowed(event):
		return
	get_viewport().set_input_as_handled() # the title-frame press is consumed and does nothing
	try_skip(SimClock.sim_frame)


## A skip press at sim frame `frame`: FIGHT 1 at once when the gate is open (never on the title
## input frame, never while paused). True if it moved.
func try_skip(frame: int) -> bool:
	if not Game.can_skip_intro(frame):
		return false
	return Game.finish_intro(frame, true)


func _physics_process(_delta: float) -> void:
	if not poll(SimClock.sim_frame):
		return
	if shown_panel == LINE_PANEL and not SimClock.paused:
		frames_open += 1
		if frames_open % TEAR_PERIOD == 0:
			queue_redraw()


## Pure: the tear row's horizontal offset at presentation frame `frames` (0 or +-TEAR_JITTER_PX).
static func tear_offset(frames: int) -> int:
	match (frames / TEAR_PERIOD) % 3:
		1:
			return TEAR_JITTER_PX
		2:
			return -TEAR_JITTER_PX
	return 0


func _draw() -> void:
	# Before the first poll the BG and panel 1 already show (no blank frame after the title press).
	var panel: int = maxi(shown_panel, 0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(Const.BASE_RES)), Palette.BG)
	var caption: PackedStringArray = caption_for(panel)
	for i: int in caption.size():
		var y: int = TOP_Y + i * ROW_STEP
		GlyphFont.draw_at(self, Vector2(TitleScreen.centred_x(caption[i]), y), caption[i], Palette.INK, TEXT_SCALE)
	if panel == LINE_PANEL:
		var x: int = TitleScreen.centred_x(TEAR_ROW) + tear_offset(frames_open)
		GlyphFont.draw_at(self, Vector2(x, TEAR_Y), TEAR_ROW, Palette.INK, TEXT_SCALE)
