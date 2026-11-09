extends GutTest
## Story 2.8 AC3, FR57, D-S28-4, D-S28-8: the HUD console log ring.

var _panel: LogPanel


func before_each() -> void:
	_panel = LogPanel.new()
	add_child(_panel)


func after_each() -> void:
	_panel.queue_free()
	await get_tree().process_frame


func test_line_for_damage() -> void:
	assert_eq(LogPanel.line_for_damage(10), "console.log(\"-10\")")
	assert_eq(LogPanel.line_for_damage(20), "console.log(\"-20\")")
	var line: String = LogPanel.line_for_damage(1234)
	for i: int in line.length():
		assert_lt(line.unicode_at(i), 128, "ASCII only")


func test_ring_keeps_the_newest_six_in_order() -> void:
	assert_eq(_panel.lines().size(), 0)
	for i: int in 3:
		_panel.append_line("l%d" % i)
	assert_eq(_panel.lines(), PackedStringArray(["l0", "l1", "l2"]))
	for i: int in range(3, 10):
		_panel.append_line("l%d" % i)
	assert_eq(Hud.LOG_LINES, 6)
	assert_eq(_panel.lines(), PackedStringArray(["l4", "l5", "l6", "l7", "l8", "l9"]), "oldest first, newest last")


func test_hit_signal_appends_a_line() -> void:
	EventBus.hit_landed.emit(&"practice_target", 10, DamageCalc.STATE_BASE, false, Vector2.ZERO)
	EventBus.hit_landed.emit(&"practice_target", 20, DamageCalc.STATE_BASE, true, Vector2.ZERO)
	assert_eq(_panel.lines(), PackedStringArray(["console.log(\"-10\")", "console.log(\"-20\")"]))


func test_clear() -> void:
	_panel.append_line("x")
	_panel.clear()
	assert_eq(_panel.lines().size(), 0)
	_panel.append_line("y")
	assert_eq(_panel.lines(), PackedStringArray(["y"]))


func test_lines_sit_in_hud_rows_39_to_44_inside_the_log_region() -> void:
	for i: int in Hud.LOG_LINES:
		var cell: Vector2i = LogPanel.line_cell(i)
		assert_eq(cell.y, 39 + i)
		assert_eq(Hud.region_of(cell), &"log")
	assert_eq(LogPanel.line_cell(Hud.LOG_LINES - 1).y, Hud.LOG.end.y - 1, "last line is the last log row")


func test_longest_line_fits_the_log_width() -> void:
	assert_lte(LogPanel.line_for_damage(999999).length(), Hud.LOG.size.x)


func test_exit_tree_disconnects() -> void:
	remove_child(_panel)
	assert_false(EventBus.hit_landed.is_connected(_panel._on_hit_landed))
	add_child(_panel)
	assert_true(EventBus.hit_landed.is_connected(_panel._on_hit_landed))


func test_negative_damage_never_prints_a_double_minus() -> void:
	assert_eq(LogPanel.line_for_damage(-5), "console.log(\"-0\")")


# --- Story 2.9: the player hit line (D-S29-9) ---

func test_player_damaged_appends_warn_line() -> void:
	assert_eq(LogPanel.line_for_player_hit(), "WARN: hp--")
	EventBus.player_damaged.emit(4)
	EventBus.player_damaged.emit(3)
	assert_eq(_panel.lines(), PackedStringArray(["WARN: hp--", "WARN: hp--"]))


func test_exit_tree_disconnects_player_damaged() -> void:
	remove_child(_panel)
	assert_false(EventBus.player_damaged.is_connected(_panel._on_player_damaged))
	add_child(_panel)
	assert_true(EventBus.player_damaged.is_connected(_panel._on_player_damaged))
