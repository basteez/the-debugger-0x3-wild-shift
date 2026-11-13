class_name DeadScreen
extends Node2D
## The DEAD screen (Story 2.9 AC3, AC4, FR49, GDD "Win/Loss Conditions"): one line,
## `Process exited with code 1`, on the placeholder text grid. A fresh press made at least
## Game.RETRY_DELAY_FRAMES sim frames after the death retries at once (D-049 c, D-S29-3); earlier
## presses are consumed and do nothing. Presentation only: it calls Game.retry and never writes
## flow state.

## Story 6.9 (AC 10): the DEAD line is game text, read from data/text/screen_text.tres.
const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
static var TEXT: String:
	get:
		return SCREEN_TEXT.dead_line
const TEXT_SCALE := 2
## Same text row as the placeholders' first line.
const TOP_Y := PlaceholderScreen.TOP_Y


## Pure: a fresh, non-echo key press that is not Esc, a modifier or an F-key, or a left-button
## press. `physical_keycode` stands in when `keycode` is 0 (web events, 1.6 deferral).
static func is_retry_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return false
		var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if code == KEY_NONE or code in PlaceholderScreen.NON_ADVANCE_KEYS:
			return false
		return not TitleScreen.is_function_key(code)
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _ready() -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_retry_press(event):
		return
	get_viewport().set_input_as_handled()
	Game.retry(SimClock.sim_frame)


func _draw() -> void:
	var x: int = TitleScreen.centred_x(TEXT)
	GlyphFont.draw_at(self, Vector2(x, TOP_Y), TEXT, Palette.INK, TEXT_SCALE)
