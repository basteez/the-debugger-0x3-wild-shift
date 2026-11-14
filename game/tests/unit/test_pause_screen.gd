extends GutTest
## Story 1.7 AC2/AC3: pause screen text, mute line and mute hit rect.

const CONTROL_LABELS: Array[String] = ["MOVE", "ACTION 1", "ACTION 2", "SHIFT", "BREAKPOINT", "WATCH"]


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
