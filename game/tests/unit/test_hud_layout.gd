extends GutTest
## Story 1.5 AC2: HUD regions on the 80x45 cell grid and the placeholder text constants.


func test_regions_at_listed_cells() -> void:
	var cases: Dictionary[Vector2i, StringName] = {
		Vector2i(0, 0): &"top_bar", Vector2i(79, 0): &"top_bar",
		Vector2i(0, 1): &"sky", Vector2i(79, 1): &"sky",
		Vector2i(0, 2): &"register", Vector2i(11, 21): &"register",
		Vector2i(0, 22): &"duck", Vector2i(11, 37): &"duck",
		Vector2i(13, 2): &"line_numbers", Vector2i(15, 37): &"line_numbers",
		Vector2i(16, 2): &"arena", Vector2i(79, 37): &"arena",
		Vector2i(0, 38): &"log", Vector2i(16, 38): &"log", Vector2i(79, 44): &"log",
		Vector2i(12, 5): &"gap", Vector2i(12, 2): &"gap", Vector2i(12, 37): &"gap",
		Vector2i(80, 0): &"gap", Vector2i(0, 45): &"gap", Vector2i(-1, 3): &"gap",
	}
	for cell: Vector2i in cases:
		assert_eq(Hud.region_of(cell), cases[cell], "cell %s" % cell)


func test_arena_region_matches_arena_origin_and_size() -> void:
	assert_eq(Hud.ARENA.position, Arena.ORIGIN_CELL)
	assert_eq(Hud.ARENA.size * GlyphFont.CELL, Arena.TILES * Arena.TILE_PX)
	assert_eq(Hud.ARENA.end - Vector2i.ONE, Vector2i(79, 37))


func test_grid_is_80x45_cells_of_8px() -> void:
	assert_eq(Vector2i(Hud.COLS, Hud.ROWS) * GlyphFont.CELL, Const.BASE_RES)


func test_line_numbers_01_to_18_one_per_tile_row() -> void:
	assert_eq(Hud.LINE_NO.size(), Arena.TILES.y)
	for i: int in Hud.LINE_NO.size():
		assert_eq(Hud.LINE_NO[i], "%02d" % (i + 1))
		assert_eq(Hud.line_no_row(i), 2 + 2 * i)
		assert_eq(Hud.region_of(Vector2i(Hud.LINE_NO_COL, Hud.line_no_row(i))), &"line_numbers")
	assert_eq(Hud.line_no_row(17), 36)


func test_text_constants_fit_their_regions() -> void:
	assert_lte(Hud.TOP_BAR.length(), Hud.COLS)
	assert_lte(Hud.SKY.length(), Hud.COLS)
	assert_eq(Hud.LOG_HEADER.length(), Hud.COLS)
	assert_true(Hud.LOG_HEADER.contains(" console "))
	assert_eq(Hud.TOP_BAR, "void fightPlaceholder() // hp ---")
	assert_eq(Hud.SKY, "// TODO: this should terminate")


## Story 3.1 AC 7 (D-S31-14): the boss header replaces the placeholder only while a boss is set.
func test_boss_header_replaces_the_placeholder_only_with_a_boss() -> void:
	assert_eq(Hud.boss_header("testBoss", 20), "void testBoss() // hp 20")
	assert_lte(Hud.boss_header("testBoss", 999999).length(), 69, "fits left of the HP readout")
	var hud: Hud = (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	assert_eq(hud.top_bar_text(), Hud.TOP_BAR, "no boss: placeholder")
	var boss := BossController.new()
	boss.setup(load("res://data/bosses/test_boss/boss_def.tres") as BossDef, null, ArenaContext.new())
	boss.reset_for_fight()
	hud.set_boss(boss)
	assert_eq(hud.top_bar_text(), "void testBoss() // hp 20")
	boss.take_hit(7)
	assert_eq(hud.top_bar_text(), "void testBoss() // hp 13", "live HP")
	boss.debug_kill()
	assert_eq(hud.top_bar_text(), "void testBoss() // hp 0", "hp 0 after defeat")
	hud.set_boss(null)
	assert_eq(hud.top_bar_text(), Hud.TOP_BAR)


func test_panel_boxes_span_their_regions() -> void:
	var reg: PackedStringArray = Hud.box_rows(Hud.REGISTER, Hud.REG_TITLE)
	for row: String in reg:
		assert_eq(row.length(), Hud.REGISTER.size.x)
	assert_true(reg[0].begins_with("┌─reg"))
	assert_true(reg[0].ends_with("┐"))
	assert_eq(reg[2], "└" + "─".repeat(10) + "┘")
	for row: String in Hud.box_rows(Hud.DUCK):
		assert_eq(row.length(), Hud.DUCK.size.x)


func test_hud_scene_layer_and_children() -> void:
	var hud: Hud = (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	assert_eq(hud.layer, 10)
	assert_not_null(hud.get_node_or_null(^"Frame"))
	assert_not_null(hud.get_node_or_null(^"GridOverlay"))
	assert_not_null(hud.register_panel, "register panel exposed (Story 2.3 C4)")
	assert_lt(hud.get_node(^"RegisterPanel").get_index(), hud.get_node(^"GridOverlay").get_index())
	assert_gt(hud.get_node(^"RegisterPanel").get_index(), hud.get_node(^"Frame").get_index())
	assert_eq(hud.get_child(hud.get_child_count() - 1).name, &"GridOverlay", "grid overlay drawn last")
	# Story 2.8: the log panel, after the frame (drawn over its rows), below the grid overlay.
	assert_not_null(hud.log_panel)
	assert_gt(hud.get_node(^"LogPanel").get_index(), hud.get_node(^"Frame").get_index())


## Story 2.8 AC3: rows 39-44 hold the six log lines under the header on row 38.
func test_log_rows_39_to_44_hold_the_lines() -> void:
	assert_eq(Hud.LOG.position.y, 38, "header row")
	assert_eq(Hud.LOG.size.y, Hud.LOG_LINES + 1)
	var rows: Array[int] = []
	for i: int in Hud.LOG_LINES:
		rows.append(LogPanel.line_cell(i).y)
	assert_eq(rows, [39, 40, 41, 42, 43, 44])
