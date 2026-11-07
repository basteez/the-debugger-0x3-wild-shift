class_name TitleScreen
extends Node2D
## Title screen (Story 1.4, FR47, D-048). Presentation only: press any key or click to start.
## Option hotkeys N/P/B/F are hidden until their stories (7.3, 7.4, 7.6, 7.7) and start the run.

enum Action { IGNORE, START, OPTION }

const TITLE_TEXT := "The Debugger 0x03: Wild Shift"
const PROMPT_TEXT := "press any key"
const TITLE_FONT_SIZE := 32
const PROMPT_FONT_SIZE := 16
const TITLE_BASELINE_Y := 160
const PROMPT_BASELINE_Y := 210
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
	&"debug_build": false,
	&"fullscreen": false,
}
## Clickable label rects of visible options, in canvas space. Empty while all are hidden.
var label_rects: Dictionary[StringName, Rect2] = {}


## Pure classifier: IGNORE, START or OPTION for one input event.
static func classify(event: InputEvent, rects: Dictionary[StringName, Rect2] = {}) -> Action:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return Action.IGNORE
		return Action.OPTION if option_of(key) != &"" else Action.START
	var mouse := event as InputEventMouseButton
	if mouse != null:
		if not mouse.pressed:
			return Action.IGNORE
		return Action.OPTION if option_of(mouse, rects) != &"" else Action.START
	return Action.IGNORE


## Option id for a key (via InputMap) or a click on a label rect; &"" when none.
static func option_of(event: InputEvent, rects: Dictionary[StringName, Rect2] = {}) -> StringName:
	if event is InputEventKey:
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


## Every counted input unlocks audio first (DC8). Returns the resolved action.
func handle_input(event: InputEvent) -> Action:
	var action: Action = resolve(event)
	if action == Action.IGNORE:
		return action
	AudioManager.unlock()
	if action == Action.START:
		Game.start_run_from_title(SimClock.sim_frame)
		AudioManager.play_test_sfx()
		queue_free()
	# Action.OPTION: no option is available in 1.4; each owning story acts here.
	return action


func _unhandled_input(event: InputEvent) -> void:
	if handle_input(event) != Action.IGNORE:
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = float(Const.BASE_RES.x)
	draw_string(font, Vector2(0, TITLE_BASELINE_Y), TITLE_TEXT, HORIZONTAL_ALIGNMENT_CENTER, width, TITLE_FONT_SIZE, Palette.INK)
	draw_string(font, Vector2(0, PROMPT_BASELINE_Y), PROMPT_TEXT, HORIZONTAL_ALIGNMENT_CENTER, width, PROMPT_FONT_SIZE, Palette.INK)
