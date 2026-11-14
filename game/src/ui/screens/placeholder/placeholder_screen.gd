class_name PlaceholderScreen
extends Node2D
## The FIGHT label placeholder (Story 1.6 DC8). HARVEST has its own screen since 3.8, INTRO since
## 6.7 and ENDING since 6.8, so it serves FIGHT only. Presentation only: it never writes flow state.
## Its is_advance rule is shared with the HARVEST, INTRO and ENDING screens (D-S67-4).

const GameFlow := preload("res://src/autoloads/game.gd")
const TEXT_SCALE := 2
## Top of the first text row, on the 8-px grid; rows are 2 glyph rows apart.
const TOP_Y := 152
const ROW_STEP := 32
## Keys that never advance a placeholder (DC4): modifiers and Esc, as on the title.
const NON_ADVANCE_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_ESCAPE]

var state: int = GameFlow.FlowState.FIGHT
var boss_index: int = 0
var lines: PackedStringArray = []


func setup(for_state: int, for_boss_index: int = 0) -> void:
	state = for_state
	boss_index = for_boss_index
	lines = lines_for(state, boss_index)
	name = StringName(String(GameFlow.FlowState.keys()[state]).to_pascal_case() + "Placeholder")
	queue_redraw()


func _ready() -> void:
	if state == GameFlow.FlowState.FIGHT:
		Log.info(&"flow", "fight placeholder opened boss=%d" % boss_index)


## ASCII text rows for a state (DC11). FIGHT shows the boss index. HARVEST (Story 3.8), INTRO
## (Story 6.7) and ENDING (Story 6.8) have their own screens, so they return no rows.
static func lines_for(for_state: int, for_boss_index: int) -> PackedStringArray:
	match for_state:
		GameFlow.FlowState.FIGHT:
			return PackedStringArray(["FIGHT %d" % (for_boss_index + 1), "boss index %d" % for_boss_index])
	return PackedStringArray()


## Pure: true for the advance gesture (DC4): a fresh key press that is not a modifier, Esc or a
## function key, or a left-button press. Story 7.5 (AC 9, 10): or a pad button press (is_pad_press).
static func is_advance(event: InputEvent) -> bool:
	if is_pad_press(event):
		return true
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo or key.keycode in NON_ADVANCE_KEYS:
			return false
		return not TitleScreen.is_function_key(key.keycode)
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


## Pure: Story 7.5 (D-S75-4): a fresh pad button press that is not the `pause` action (Start), the
## pad's "any button". Stick and trigger motion are not buttons, so they never count (D-S75-3).
static func is_pad_press(event: InputEvent) -> bool:
	var pad := event as InputEventJoypadButton
	if pad == null or not pad.pressed:
		return false
	return not (InputMap.has_action(&"pause") and pad.is_action(&"pause", true))


## FIGHT is playable since Epic 2: its keys are gameplay, never an any-key advance. Leaving a fight
## goes through boss defeat (3.8) or the debug jump keys. Story 6.8: the ENDING advance moved to
## EndingScreen, so the placeholder consumes no input at all.
func _unhandled_input(_event: InputEvent) -> void:
	pass


func _draw() -> void:
	for i: int in lines.size():
		var y: int = TOP_Y + i * ROW_STEP
		var x: int = TitleScreen.centred_x(lines[i])
		# BG backing so the label reads over the arena glyphs in FIGHT.
		draw_rect(Rect2(x - GlyphFont.CELL, y - GlyphFont.CELL * 0.5,
				GlyphFont.text_width(lines[i], TEXT_SCALE) + 2 * GlyphFont.CELL,
				GlyphFont.size_for(TEXT_SCALE) + GlyphFont.CELL), Palette.BG)
		GlyphFont.draw_at(self, Vector2(x, y), lines[i], Palette.INK, TEXT_SCALE)
