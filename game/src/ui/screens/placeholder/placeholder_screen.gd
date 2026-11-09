class_name PlaceholderScreen
extends Node2D
## One placeholder for INTRO, FIGHT, HARVEST and ENDING (Story 1.6 DC8). Replaced by the real
## screens in 6.7 (Intro), 2.x/3.x (Fight), 3.8 (Harvest) and 6.8 (Ending). Presentation only:
## it calls Game.finish_intro / Game.advance and never writes flow state.

const GameFlow := preload("res://src/autoloads/game.gd")
const TEXT_SCALE := 2
## Top of the first text row, on the 8-px grid; rows are 2 glyph rows apart.
const TOP_Y := 152
const ROW_STEP := 32
const PROMPT_TEXT := "press any key"
## Keys that never advance a placeholder (DC4): modifiers and Esc, as on the title.
const NON_ADVANCE_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_ESCAPE]

var state: int = GameFlow.FlowState.INTRO
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


## ASCII text rows for a state (DC11). FIGHT and HARVEST show the boss index.
static func lines_for(for_state: int, for_boss_index: int) -> PackedStringArray:
	match for_state:
		GameFlow.FlowState.INTRO:
			return PackedStringArray(["INTRO", PROMPT_TEXT])
		GameFlow.FlowState.FIGHT:
			return PackedStringArray(["FIGHT %d" % (for_boss_index + 1), "boss index %d" % for_boss_index])
		GameFlow.FlowState.HARVEST:
			return PackedStringArray(["HARVEST", "boss index %d" % for_boss_index])
		GameFlow.FlowState.ENDING:
			return PackedStringArray(["ENDING", PROMPT_TEXT])
	return PackedStringArray()


## Pure: true for the advance gesture (DC4): a fresh key press that is not a modifier, Esc or a
## function key, or a left-button press.
static func is_advance(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo or key.keycode in NON_ADVANCE_KEYS:
			return false
		return not TitleScreen.is_function_key(key.keycode)
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _unhandled_input(event: InputEvent) -> void:
	# FIGHT is playable since Epic 2: its keys are gameplay, never an any-key advance. Leaving a
	# fight goes through boss defeat (3.8) or the debug jump keys.
	if state == GameFlow.FlowState.FIGHT:
		return
	if not is_advance(event):
		return
	get_viewport().set_input_as_handled()
	if state == GameFlow.FlowState.INTRO:
		if Game.can_skip_intro(SimClock.sim_frame):
			Game.finish_intro(SimClock.sim_frame, true)
	elif Game.flow_state == state:
		Game.advance()


func _physics_process(_delta: float) -> void:
	# Intro cap (DC5): the timeout rule lives in Game; this only asks once per physics frame.
	if state == GameFlow.FlowState.INTRO and Game.flow_state == GameFlow.FlowState.INTRO:
		Game.finish_intro(SimClock.sim_frame)


func _draw() -> void:
	for i: int in lines.size():
		var y: int = TOP_Y + i * ROW_STEP
		var x: int = TitleScreen.centred_x(lines[i])
		# BG backing so the label reads over the arena glyphs in FIGHT.
		draw_rect(Rect2(x - GlyphFont.CELL, y - GlyphFont.CELL * 0.5,
				GlyphFont.text_width(lines[i], TEXT_SCALE) + 2 * GlyphFont.CELL,
				GlyphFont.size_for(TEXT_SCALE) + GlyphFont.CELL), Palette.BG)
		GlyphFont.draw_at(self, Vector2(x, y), lines[i], Palette.INK, TEXT_SCALE)
