class_name TitleScreen
extends Node2D
## Title screen (Story 1.4, FR47, D-048). Presentation only: press any key or click to start.
## Option hotkeys P/F are hidden until their stories (7.6, 7.7) and start the run.
## Story 7.3 (AC 6-10): with a save past Boss 1, `[N] new run` shows; N (or a click on it) resets the
## save and starts from the Intro, any other key or click resumes at the saved boss without the Intro.
## Story 7.4 (AC 1, 3, 4, D-S74-2): `[B] debug build on/off` always shows; B (or a click on it) flips
## the assist through SaveService.set_assist and never starts the run.
## Story 7.5 (FR61, D-048): any pad button starts the run like a key; Select / B / R3 / L3 are the
## pad buttons of the option actions (project.godot [input]). Stick and trigger motion are ignored.

enum Action { IGNORE, START, OPTION }

## Story 6.9 (AC 10): the title line and the prompt are game text, read from data/text/screen_text.tres.
const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
static var TITLE_TEXT: String:
	get:
		return SCREEN_TEXT.title
static var PROMPT_TEXT: String:
	get:
		return SCREEN_TEXT.prompt
## Story 7.3 (D-S73-5): the new-run option label, audited game text.
static var NEW_RUN_TEXT: String:
	get:
		return SCREEN_TEXT.new_run_label
## Story 7.4 (D-S74-8): the debug build assist labels, audited game text.
static var DEBUG_BUILD_ON_TEXT: String:
	get:
		return SCREEN_TEXT.debug_build_on_label
static var DEBUG_BUILD_OFF_TEXT: String:
	get:
		return SCREEN_TEXT.debug_build_off_label
## Pixel font at 2x (16-px glyph cells, Story 1.5 DC2). Y values are the top of each glyph row,
## on the 8-px grid; x is centred on the 640-px base and snapped to the 8-px grid.
const TEXT_SCALE := 2
const TITLE_TOP_Y := 160
const PROMPT_TOP_Y := 208
## Story 7.3 (D-S73-5): the [N] new run label row, below the prompt.
const NEW_RUN_TOP_Y := 240
## Story 7.4 (D-S74-2): the [B] debug build label row, below the new-run row.
const DEBUG_BUILD_TOP_Y := 272
## Option id -> InputMap action (DC7). The keys live only in project.godot [input].
const OPTION_ACTIONS: Dictionary[StringName, StringName] = {
	&"new_run": &"title_option_new_run",
	&"practice": &"title_option_practice",
	&"debug_build": &"title_option_debug_build",
	&"fullscreen": &"title_option_fullscreen",
}

## Which options exist yet (DC2). Hidden options behave as plain keys.
var available: Dictionary[StringName, bool] = {
	&"new_run": false,
	&"practice": false,
	&"debug_build": true, # Story 7.4 (D-S74-2): always shown
	&"fullscreen": false,
}
## Clickable label rects of visible options, in canvas space. Empty while all are hidden.
var label_rects: Dictionary[StringName, Rect2] = {}
var _started := false
## Story 7.3: the saved highest boss read once per title show (_ready); resume when > 1.
var saved_highest_boss: int = 1
## Story 7.4: the assist state the label shows (SaveService.assist, read in _ready, flipped by B).
var assist_shown: bool = false

## Keys that are not a user gesture for the browser (no AudioContext activation): never start the run.
const NON_START_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_ESCAPE]


## Pure classifier: IGNORE, START or OPTION for one input event.
static func classify(event: InputEvent, rects: Dictionary[StringName, Rect2] = {}) -> Action:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return Action.IGNORE
		if key.keycode in NON_START_KEYS or is_function_key(key.keycode):
			return Action.IGNORE
		return Action.OPTION if option_of(key) != &"" else Action.START
	var mouse := event as InputEventMouseButton
	if mouse != null:
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return Action.IGNORE
		return Action.OPTION if option_of(mouse, rects) != &"" else Action.START
	# Story 7.5 (AC 5-8, D-S75-3): a fresh pad button press counts like a key (Start included: the
	# title is never paused); stick and trigger motion (InputEventJoypadMotion) never start the run.
	var pad := event as InputEventJoypadButton
	if pad != null:
		if not pad.pressed:
			return Action.IGNORE
		return Action.OPTION if option_of(pad) != &"" else Action.START
	return Action.IGNORE


## F1-F12 (and beyond) never start the run (Story 1.6 DC7): they are debug keys or browser keys.
static func is_function_key(keycode: Key) -> bool:
	return keycode >= KEY_F1 and keycode <= KEY_F35


## Option id for a key or a pad button (via InputMap) or a click on a label rect; &"" when none.
static func option_of(event: InputEvent, rects: Dictionary[StringName, Rect2] = {}) -> StringName:
	if event is InputEventKey or event is InputEventJoypadButton:
		for option: StringName in OPTION_ACTIONS:
			if InputMap.has_action(OPTION_ACTIONS[option]) and event.is_action(OPTION_ACTIONS[option], true):
				return option
		return &""
	var mouse := event as InputEventMouseButton
	if mouse != null:
		for option: StringName in rects:
			if rects[option].has_point(mouse.position):
				return option
	return &""


func is_option_available(option: StringName) -> bool:
	return available.get(option, false)


## Classification after the availability rule: a hidden option counts as START.
func resolve(event: InputEvent) -> Action:
	var action: Action = classify(event, label_rects)
	if action == Action.OPTION and not is_option_available(option_of(event, label_rects)):
		return Action.START
	return action


func _ready() -> void:
	set_saved_progress(SaveService.highest_boss)
	set_assist_shown(SaveService.assist)


## Story 7.4 (AC 10): the label's state and its clickable rect (always present).
func set_assist_shown(on: bool) -> void:
	assist_shown = on
	label_rects[&"debug_build"] = debug_build_label_rect(on)
	queue_redraw()


static func debug_build_text(on: bool) -> String:
	return DEBUG_BUILD_ON_TEXT if on else DEBUG_BUILD_OFF_TEXT


## Pure: the clickable rect of the [B] debug build label (same margins as the new-run label).
static func debug_build_label_rect(on: bool) -> Rect2:
	return label_rect_for(debug_build_text(on), DEBUG_BUILD_TOP_Y)


## Story 7.3 (AC 8): the [N] new run option exists only with a save past Boss 1; its label is
## clickable only while it shows. Read once per title show.
func set_saved_progress(highest_boss: int) -> void:
	saved_highest_boss = highest_boss
	available[&"new_run"] = highest_boss > 1
	if available[&"new_run"]:
		label_rects[&"new_run"] = new_run_label_rect()
	else:
		label_rects.erase(&"new_run")
	queue_redraw()


## Pure: the clickable rect of the [N] new run label (the glyph row plus a half-cell margin), canvas space.
static func new_run_label_rect() -> Rect2:
	return label_rect_for(NEW_RUN_TEXT, NEW_RUN_TOP_Y)


## Pure: a centred label's glyph row at `top_y` plus a half-cell margin, canvas space.
static func label_rect_for(text: String, top_y: int) -> Rect2:
	var cell: int = GlyphFont.CELL * TEXT_SCALE
	var margin: float = cell / 2.0
	return Rect2(centred_x(text) - margin, top_y - margin,
			GlyphFont.text_width(text, TEXT_SCALE) + 2.0 * margin, cell + 2.0 * margin)


## Every counted input unlocks audio first (DC8). Returns the resolved action.
func handle_input(event: InputEvent) -> Action:
	var action: Action = resolve(event)
	if action == Action.IGNORE:
		return action
	if _started or Game.flow_state != Game.FlowState.TITLE:
		return Action.IGNORE
	AudioManager.unlock()
	if action == Action.START:
		_begin(false)
	else:
		var option: StringName = option_of(event, label_rects)
		if option == &"new_run": # Story 7.3 (AC 9): reset, then the Intro
			_begin(true)
		elif option == &"debug_build": # Story 7.4 (AC 1, 3): toggle in place, saved at once
			SaveService.set_assist(not assist_shown)
			set_assist_shown(SaveService.assist)
		# Other options act in their owning stories (7.6, 7.7).
	return action


## Story 7.3: leaves the title once. `new_run` resets the save and keeps the Intro; otherwise a save
## past Boss 1 resumes (no Intro) and a fresh save starts from the Intro as before.
func _begin(new_run: bool) -> void:
	_started = true
	if new_run:
		Game.start_new_run_from_title(SimClock.sim_frame)
	elif saved_highest_boss > 1:
		Game.resume_run_from_title(SimClock.sim_frame, saved_highest_boss)
	else:
		Game.start_run_from_title(SimClock.sim_frame)
	AudioManager.play_test_sfx()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if handle_input(event) != Action.IGNORE:
		get_viewport().set_input_as_handled()


func _draw() -> void:
	GlyphFont.draw_at(self, Vector2(centred_x(TITLE_TEXT), TITLE_TOP_Y), TITLE_TEXT, Palette.INK, TEXT_SCALE)
	GlyphFont.draw_at(self, Vector2(centred_x(PROMPT_TEXT), PROMPT_TOP_Y), PROMPT_TEXT, Palette.INK, TEXT_SCALE)
	if is_option_available(&"new_run"):
		GlyphFont.draw_at(self, Vector2(centred_x(NEW_RUN_TEXT), NEW_RUN_TOP_Y), NEW_RUN_TEXT, Palette.INK, TEXT_SCALE)
	if is_option_available(&"debug_build"):
		var assist_text: String = debug_build_text(assist_shown)
		GlyphFont.draw_at(self, Vector2(centred_x(assist_text), DEBUG_BUILD_TOP_Y), assist_text, Palette.INK, TEXT_SCALE)


## Left x that centres `text` at TEXT_SCALE on the base width, snapped down to the 8-px grid.
static func centred_x(text: String) -> int:
	var x: int = maxi((Const.BASE_RES.x - GlyphFont.text_width(text, TEXT_SCALE)) / 2, 0)
	return x - x % GlyphFont.CELL
