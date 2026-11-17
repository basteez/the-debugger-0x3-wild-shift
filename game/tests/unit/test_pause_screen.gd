extends GutTest
## Story 1.7 AC2/AC3: pause screen text, mute line and mute hit rect.

const CONTROL_LABELS: Array[String] = ["MOVE", "ACTION 1", "ACTION 2", "SHIFT", "BREAKPOINT", "WATCH"]

# Story 9.5 (AC 4): the shared state a test changes is saved and restored here, not inline.
var _saved_flow: int
var _saved_run: RunState
var _saved_assist: bool
var _saved_path: String


func before_each() -> void:
	_saved_flow = Game.flow_state
	_saved_run = Game.run
	_saved_assist = SaveService.assist
	_saved_path = SaveService.path


func after_each() -> void:
	Game.flow_state = _saved_flow as Game.FlowState
	Game.run = _saved_run
	SaveService.assist = _saved_assist
	SaveService.path = _saved_path


func test_lines_list_every_control_and_resume() -> void:
	var lines: PackedStringArray = PauseScreen.lines_for(false)
	assert_eq(lines[0], "PAUSED")
	var text: String = "\n".join(lines)
	for label: String in CONTROL_LABELS:
		assert_string_contains(text, label)
	for key: String in ["WASD", "ARROWS", " J", " K", "Q E", "SPACE", " R"]:
		assert_string_contains(text, key)
	assert_has(lines, "[ESC / P / CLICK] RESUME")
	assert_eq(lines.size(), PauseScreen.row_tops().size())


func test_mute_line_follows_the_argument() -> void:
	assert_eq(PauseScreen.lines_for(true)[-3], "[M] MUTE ON") # Story 7.4 / 7.7: assist, then fullscreen
	assert_eq(PauseScreen.lines_for(false)[-3], "[M] MUTE OFF")


func test_layout_fits_the_base_with_a_gutter() -> void:
	var lines: PackedStringArray = PauseScreen.lines_for(false)
	var tops: PackedInt32Array = PauseScreen.row_tops()
	var bounds := Rect2(16, 16, Const.BASE_RES.x - 32, Const.BASE_RES.y - 32)
	for i: int in lines.size():
		assert_eq(tops[i] % GlyphFont.CELL, 0, "row %d on the 8-px grid" % i)
		if i > 0:
			assert_gt(tops[i], tops[i - 1] + GlyphFont.size_for(PauseScreen.TEXT_SCALE) - 1, "rows do not overlap")
		var r := Rect2(TitleScreen.centred_x(lines[i]), tops[i],
				GlyphFont.text_width(lines[i], PauseScreen.TEXT_SCALE), GlyphFont.size_for(PauseScreen.TEXT_SCALE))
		assert_true(bounds.encloses(r), "row '%s' inside the 16-px gutter" % lines[i])


func test_mute_hit_rect() -> void:
	for muted: bool in [false, true]:
		var rect: Rect2 = PauseScreen.mute_label_rect(muted)
		var inside: Vector2 = Vector2(TitleScreen.centred_x(PauseScreen.mute_text(muted)) + 4, PauseScreen.MUTE_TOP_Y + 4)
		assert_true(rect.has_point(inside))
		assert_false(rect.has_point(Vector2(8, 8)))
		assert_false(rect.has_point(Vector2(320, PauseScreen.RESUME_TOP_Y + 4)), "resume row is not the mute label")


func _click(at: Vector2) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	return click


func test_mute_toggle_input() -> void:
	var m := InputEventKey.new()
	m.physical_keycode = KEY_M
	m.pressed = true
	assert_true(PauseScreen.is_mute_toggle(m, false))
	m.echo = true
	assert_false(PauseScreen.is_mute_toggle(m, false), "echo ignored")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	assert_false(PauseScreen.is_mute_toggle(esc, false), "Esc belongs to Game")
	assert_true(PauseScreen.is_mute_toggle(_click(PauseScreen.mute_label_rect(false).get_center()), false))
	assert_false(PauseScreen.is_mute_toggle(_click(Vector2(8, 8)), false), "click elsewhere does nothing")


# --- Story 9.3: the assist row's next-attempt suffix (539, 544, AC 8-10, D-S93-3) ---------------

func test_assist_row_reads_next_attempt_when_pending() -> void:
	assert_eq(PauseScreen.lines_for(false, true, false, true)[-2], "[B] DEBUG BUILD ON: NEXT ATTEMPT")
	assert_eq(PauseScreen.lines_for(false, false, false, true)[-2], "[B] DEBUG BUILD OFF: NEXT ATTEMPT")
	assert_eq(PauseScreen.lines_for(false, true, false, true).size(), PauseScreen.row_tops().size(), "same rows")


func test_defaults_unchanged() -> void:
	assert_eq(PauseScreen.lines_for(false, true)[-2], "[B] DEBUG BUILD ON")
	assert_eq(PauseScreen.lines_for(false, false)[-2], "[B] DEBUG BUILD OFF")
	assert_eq(PauseScreen.assist_text(true), "[B] DEBUG BUILD ON")


func test_assist_pending_only_in_fight() -> void:
	var S := Game.FlowState
	assert_true(PauseScreen.assist_pending(S.FIGHT, false, true))
	assert_true(PauseScreen.assist_pending(S.FIGHT, true, false))
	assert_false(PauseScreen.assist_pending(S.FIGHT, true, true), "equal: nothing pending")
	assert_false(PauseScreen.assist_pending(S.FIGHT, false, false))
	for state: int in [S.TITLE, S.INTRO, S.DEAD, S.HARVEST, S.ENDING, S.TUTORIAL]:
		assert_false(PauseScreen.assist_pending(state, false, true), "%s: the next FIGHT entry applies it" % S.keys()[state])


func test_pending_rect_matches_the_drawn_row() -> void:
	for assist: bool in [false, true]:
		var text: String = PauseScreen.assist_text(assist, true)
		var rect: Rect2 = PauseScreen.assist_label_rect(assist, true)
		assert_eq(rect, PauseScreen.row_rect(text, PauseScreen.ASSIST_TOP_Y))
		var left := Vector2(TitleScreen.centred_x(text) + 2, PauseScreen.ASSIST_TOP_Y + 4)
		var right := Vector2(TitleScreen.centred_x(text) + GlyphFont.text_width(text, PauseScreen.TEXT_SCALE) - 2,
				PauseScreen.ASSIST_TOP_Y + 4)
		assert_true(rect.has_point(left))
		assert_true(rect.has_point(right), "the suffix end is clickable")
		assert_false(PauseScreen.assist_label_rect(assist).has_point(right), "the plain rect is narrower")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = right
		assert_true(PauseScreen.is_assist_toggle(click, assist, true))
		assert_false(rect.intersects(PauseScreen.mute_label_rect(false)), "does not overlap the mute row")
		assert_false(rect.intersects(PauseScreen.fullscreen_label_rect(false)), "nor the fullscreen row")


func test_pending_layout_fits_the_gutter() -> void:
	var bounds := Rect2(16, 16, Const.BASE_RES.x - 32, Const.BASE_RES.y - 32)
	for assist: bool in [false, true]:
		var text: String = PauseScreen.assist_text(assist, true)
		var r := Rect2(TitleScreen.centred_x(text), PauseScreen.ASSIST_TOP_Y,
				GlyphFont.text_width(text, PauseScreen.TEXT_SCALE), GlyphFont.size_for(PauseScreen.TEXT_SCALE))
		assert_true(bounds.encloses(r), "'%s' inside the 16-px gutter" % text)


func test_live_pending_follows_the_attempt_copy() -> void:
	SaveService.path = ""
	Game.run = RunState.new()
	Game.flow_state = Game.FlowState.FIGHT
	Game.run.assist = false
	SaveService.assist = false
	var pause: PauseScreen = PauseScreen.new()
	add_child_autofree(pause)
	assert_false(pause.live_assist_pending())
	var b := InputEventKey.new()
	b.keycode = KEY_B
	b.physical_keycode = KEY_B
	b.pressed = true
	pause._input(b) # the mid-fight toggle: saved at once, applies from the next attempt
	assert_true(SaveService.assist)
	assert_false(Game.run.assist, "the attempt copy is untouched")
	assert_true(pause.live_assist_pending())
	Game.run.assist = true # the next attempt copies it (Game._begin_fight)
	pause._process(0.0)
	assert_false(pause.live_assist_pending(), "the suffix clears with no event")
