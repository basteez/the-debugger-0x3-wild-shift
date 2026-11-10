extends GutTest
## Story 2.3 E4 (AC7, AC8): the pure RegisterPanel.plan() for 2, 3 and 4 owned bits (D-S23-8).

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const InteriorRect := Rect2i(1, 3, 10, 18) # REGISTER box interior: cols 1-10, rows 3-20


func _ring(bits: Array) -> PackedInt32Array:
	return PackedInt32Array(bits)


## Cells on a row, keyed by column (multi-glyph runs are keyed by their first column).
func _row(plan: Array[RegisterPanel.Cell], row: int) -> Dictionary:
	var out: Dictionary = {}
	for c: RegisterPanel.Cell in plan:
		if c.cell.y == row:
			out[c.cell.x] = c
	return out


func _only(plan: Array[RegisterPanel.Cell], row: int) -> RegisterPanel.Cell:
	var cells: Dictionary = _row(plan, row)
	assert_eq(cells.size(), 1, "one run on row %d" % row)
	return cells.values()[0] if cells.size() > 0 else null


func test_hex_value() -> void:
	var cases: Dictionary = {"0x03": [D, A], "0x07": [A, D, L], "0x0F": [A, D, L, N]}
	for hex: String in cases:
		var c: RegisterPanel.Cell = _only(RegisterPanel.plan(_ring(cases[hex])), RegisterPanel.HEX_ROW)
		assert_eq(c.text, hex)
		assert_eq(c.style, RegisterPanel.INK)
		assert_eq(c.cell, Vector2i(1, 3))


func test_byte_row_two_bits() -> void:
	_assert_byte_row([D, A], ["0", "0", "0", "0", "D", "A", "0", "0"])


func test_byte_row_three_bits() -> void:
	_assert_byte_row([A, D, L], ["0", "0", "0", "0", "A", "D", "L", "0"])


func test_byte_row_four_bits() -> void:
	_assert_byte_row([A, D, L, N], ["0", "0", "0", "0", "A", "D", "L", "N"])


func test_byte_row_is_window_first_after_a_shift() -> void:
	var reg := Register.new()
	reg.set_fight_start(_ring([A, D, L]))
	reg.shift(Register.LEFT)
	_assert_byte_row(Array(reg.ring), ["0", "0", "0", "0", "D", "L", "A", "0"])


func _assert_byte_row(bits: Array, expected: Array) -> void:
	var cells: Dictionary = _row(RegisterPanel.plan(_ring(bits)), RegisterPanel.BYTE_ROW)
	assert_eq(cells.size(), 8, "8 bit cells")
	for i: int in 8:
		var c: RegisterPanel.Cell = cells.get(1 + i)
		assert_not_null(c, "bit cell at col %d" % (1 + i))
		if c == null:
			continue
		assert_eq(c.text, expected[i], "%s col %d" % [bits, 1 + i])
		var owned: bool = i >= 4 and i - 4 < bits.size()
		assert_eq(c.style, RegisterPanel.INK if owned else RegisterPanel.GREYED, "%s col %d style" % [bits, 1 + i])


func test_reserved_label_greyed() -> void:
	var c: RegisterPanel.Cell = _only(RegisterPanel.plan(_ring([D, A])), RegisterPanel.LABEL_ROW)
	assert_eq(c.text, "reserved")
	assert_eq(c.style, RegisterPanel.GREYED)
	assert_eq(c.cell, Vector2i(1, 6))


func test_window_inverted_with_jk_below() -> void:
	var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(_ring([D, A]))
	var w: RegisterPanel.Cell = _only(plan, RegisterPanel.WINDOW_ROW)
	assert_eq(w.style, RegisterPanel.INVERTED)
	assert_eq(w.cell, Vector2i(1, 12))
	assert_eq(w.text.length(), 10, "inverted across cols 1-10")
	assert_eq(w.text[RegisterPanel.J_COL - 1], "D")
	assert_eq(w.text[RegisterPanel.K_COL - 1], "A")
	var jk: RegisterPanel.Cell = _only(plan, RegisterPanel.JK_ROW)
	assert_eq(jk.text, "J→K")
	assert_eq(jk.style, RegisterPanel.INK)
	assert_eq(jk.cell, Vector2i(RegisterPanel.J_COL, 13))


func test_previews_faded_and_match_register_preview() -> void:
	for bits: Array in [[D, A], [A, D, L], [A, D, L, N]]:
		var reg := Register.new()
		reg.set_fight_start(_ring(bits))
		var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(reg.ring)
		var left: RegisterPanel.Cell = _only(plan, RegisterPanel.PREVIEW_LEFT_ROW)
		var right: RegisterPanel.Cell = _only(plan, RegisterPanel.PREVIEW_RIGHT_ROW)
		assert_eq(left.style, RegisterPanel.FADED)
		assert_eq(right.style, RegisterPanel.FADED)
		assert_eq(left.cell.x, 1)
		assert_eq(right.cell.x, 1)
		assert_true(left.text.begins_with("<< "))
		assert_true(right.text.begins_with(">> "))
		var lp: Vector2i = reg.preview(Register.LEFT)
		var rp: Vector2i = reg.preview(Register.RIGHT)
		assert_eq(left.text, "<< %s %s" % [Register.glyph_of(lp.x), Register.glyph_of(lp.y)], "%s" % [bits])
		assert_eq(right.text, ">> %s %s" % [Register.glyph_of(rp.x), Register.glyph_of(rp.y)], "%s" % [bits])


func test_dash_attack_previews() -> void:
	var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(_ring([A, D, L]))
	assert_eq(_only(plan, RegisterPanel.PREVIEW_LEFT_ROW).text, "<< D L")
	assert_eq(_only(plan, RegisterPanel.PREVIEW_RIGHT_ROW).text, ">> L A")


func test_every_cell_inside_the_register_box_interior() -> void:
	for bits: Array in [[D, A], [A, D, L], [A, D, L, N]]:
		for c: RegisterPanel.Cell in RegisterPanel.plan(_ring(bits)):
			assert_true(InteriorRect.has_point(c.cell), "%s starts inside" % c.cell)
			var last: Vector2i = c.cell + Vector2i(c.text.length() - 1, 0)
			assert_true(InteriorRect.has_point(last), "%s '%s' ends inside" % [c.cell, c.text])
			assert_eq(Hud.region_of(c.cell), &"register")
			assert_true(c.style in [RegisterPanel.INK, RegisterPanel.GREYED, RegisterPanel.FADED, RegisterPanel.INVERTED])


func test_plan_leaves_the_ring_unchanged() -> void:
	var reg := Register.new()
	reg.set_fight_start(_ring([A, D, L, N]))
	var before: PackedInt32Array = reg.ring.duplicate()
	RegisterPanel.plan(reg.ring)
	assert_eq(reg.ring, before)


func test_panel_without_register_is_safe() -> void:
	var panel := RegisterPanel.new()
	add_child_autofree(panel)
	panel.queue_redraw()
	await wait_process_frames(2)
	assert_null(panel.register)


func test_panel_never_writes_the_register() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/ui/hud/register_panel.gd")
	var writes := RegEx.create_from_string("register\\.(ring\\s*=|shift\\(|insert\\(|set_fight_start\\(|set_active\\(|active\\s*=)")
	assert_null(writes.search(text), "RegisterPanel only reads the Register (D-S23-9)")


func test_panel_draws_an_active_register_without_errors() -> void:
	var reg := Register.new()
	reg.set_fight_start(_ring([A, D, L]))
	reg.set_active(true)
	var panel := RegisterPanel.new()
	panel.register = reg
	add_child_autofree(panel)
	await wait_process_frames(3)
	assert_not_null(RegisterPanel.checker_texture(), "checker dither built")
	assert_eq(RegisterPanel.checker_texture().get_size(), Vector2(8, 8))
	assert_eq(reg.ring, _ring([A, D, L]), "drawing never writes the register")


# --- Story 2.6 D (AC8): combo names on the window and the previews ---

func _texts(plan: Array[RegisterPanel.Cell], first_row: int) -> Array:
	var out: Array = []
	for row: int in range(first_row, first_row + RegisterPanel.NAME_ROWS):
		var cells: Dictionary = _row(plan, row)
		for c: RegisterPanel.Cell in cells.values():
			out.append(c.text)
	return out


func test_active_dash_strike_window_shows_name_and_jk() -> void:
	var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(_ring([A, D]))
	assert_eq(_texts(plan, RegisterPanel.WINDOW_NAME_ROW), ["Dash", "Strike"])
	for row: int in range(RegisterPanel.WINDOW_NAME_ROW, RegisterPanel.WINDOW_NAME_ROW + 2):
		assert_eq(_only(plan, row).style, RegisterPanel.INK)
	assert_eq(_only(plan, RegisterPanel.JK_ROW).text, "J→K")
	var w: RegisterPanel.Cell = _only(plan, RegisterPanel.WINDOW_ROW)
	assert_eq(w.text[RegisterPanel.J_COL - 1], "A")
	assert_eq(w.text[RegisterPanel.K_COL - 1], "D")


func test_no_combo_window_shows_glyphs_only() -> void:
	var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(_ring([D, A]))
	assert_eq(_texts(plan, RegisterPanel.WINDOW_NAME_ROW), [], "no name, no '(no combo)' (D-S26-10)")
	assert_eq(_only(plan, RegisterPanel.JK_ROW).text, "J→K")


func test_previews_show_names_only_where_a_combo_exists() -> void:
	# [D, A]: both shifts give [A, D] = Dash Strike.
	var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(_ring([D, A]))
	assert_eq(_only(plan, RegisterPanel.PREVIEW_LEFT_ROW).text, "<< A D")
	assert_eq(_texts(plan, RegisterPanel.PREVIEW_LEFT_NAME_ROW), ["Dash", "Strike"])
	assert_eq(_texts(plan, RegisterPanel.PREVIEW_RIGHT_NAME_ROW), ["Dash", "Strike"])
	for c: RegisterPanel.Cell in plan:
		if c.cell.y >= RegisterPanel.PREVIEW_LEFT_NAME_ROW and c.cell.y < RegisterPanel.PREVIEW_LEFT_NAME_ROW + 2:
			assert_eq(c.style, RegisterPanel.FADED)
	# [A, D, L]: << gives [D, L] (Echo Dash, shipped in Story 4.2), >> gives [L, A] (no combo).
	plan = RegisterPanel.plan(_ring([A, D, L]))
	assert_eq(_texts(plan, RegisterPanel.PREVIEW_LEFT_NAME_ROW), ["Echo Dash"])
	assert_eq(_texts(plan, RegisterPanel.PREVIEW_RIGHT_NAME_ROW), [])
	assert_eq(_texts(plan, RegisterPanel.WINDOW_NAME_ROW), ["Dash", "Strike"])


func test_plan_uses_the_injected_combo_table() -> void:
	var c := ComboDef.new()
	c.first = D
	c.second = L
	c.action = Defs.DASH_STRIKE
	c.display_name = "Echo Dash"
	var t := ComboTable.new()
	t.combos = [c]
	var plan: Array[RegisterPanel.Cell] = RegisterPanel.plan(_ring([A, D, L]), Register.MAX_BITS, t)
	assert_eq(_texts(plan, RegisterPanel.PREVIEW_LEFT_NAME_ROW), ["Echo Dash"], "fits one row")
	assert_eq(_texts(plan, RegisterPanel.WINDOW_NAME_ROW), [], "the stub has no [A, D]")


func test_wrap_name() -> void:
	assert_eq(RegisterPanel.wrap_name("Dash Strike"), PackedStringArray(["Dash", "Strike"]))
	assert_eq(RegisterPanel.wrap_name("Ghost Echo"), PackedStringArray(["Ghost Echo"]))
	assert_eq(RegisterPanel.wrap_name("Dereference"), PackedStringArray(["Dereferenc"]), "cut to 10 cells")
	assert_eq(RegisterPanel.wrap_name("a b c d e f g h i j k l m n o p q r s t u v w"), PackedStringArray(["a b c d e", "f g h i j"]))
