extends GutTest
## Story 1.5 AC1/AC3: the Clearing layout constant and the bounds clamp.


func _cells() -> Array[String]:
	var out: Array[String] = []
	for row: String in Arena.LAYOUT:
		for i: int in row.length():
			out.append(row[i])
	return out


func test_layout_is_18_rows_of_32() -> void:
	assert_eq(Arena.LAYOUT.size(), 18)
	assert_eq(Arena.TILES, Vector2i(32, 18))
	for r: int in Arena.LAYOUT.size():
		assert_eq(Arena.LAYOUT[r].length(), 32, "row %d" % r)


func test_ring_is_trees_except_label() -> void:
	var last: int = Arena.LAYOUT.size() - 1
	for c: int in 32:
		if c < Arena.LABEL_COL or c >= Arena.LABEL_COL + Arena.LABEL.length():
			assert_eq(Arena.LAYOUT[0][c], Arena.TREE, "top col %d" % c)
		assert_eq(Arena.LAYOUT[last][c], Arena.TREE, "bottom col %d" % c)
	for r: int in Arena.LAYOUT.size():
		assert_eq(Arena.LAYOUT[r][0], Arena.TREE, "left row %d" % r)
		assert_eq(Arena.LAYOUT[r][31], Arena.TREE, "right row %d" % r)


func test_label_on_row_0_from_col_2_with_trees_both_sides() -> void:
	assert_eq(Arena.LABEL, "stack frame 0x03")
	assert_eq(Arena.LAYOUT[0].substr(2, 16), Arena.LABEL)
	assert_eq(Arena.LAYOUT[0][1], Arena.TREE)
	assert_eq(Arena.LAYOUT[0][18], Arena.TREE)


func test_glyph_set_is_allowed() -> void:
	var allowed: Dictionary[String, bool] = {Arena.TREE: true, Arena.GRASS: true, Arena.ROCK: true, Arena.WATER: true, " ": true}
	for i: int in Arena.LABEL.length():
		allowed[Arena.LABEL[i]] = true
	for ch: String in _cells():
		assert_true(allowed.has(ch), "unexpected glyph '%s'" % ch)
	assert_true(_cells().has(Arena.GRASS), "no grass")


func test_interior_has_only_scenery() -> void:
	for r: int in range(1, 17):
		for c: int in range(1, 31):
			assert_true(Arena.LAYOUT[r][c] in [Arena.GRASS, Arena.ROCK, Arena.WATER, " "], "cell %d,%d" % [c, r])


func test_stream_crosses_every_interior_column_connected() -> void:
	var prev_rows: Array[int] = []
	for c: int in range(1, 31):
		var rows: Array[int] = []
		for r: int in range(1, 17):
			if Arena.LAYOUT[r][c] == Arena.WATER:
				rows.append(r)
		assert_false(rows.is_empty(), "no water in column %d" % c)
		for r: int in rows:
			assert_true(r >= 6 and r <= 11, "water far from the stream band at %d,%d" % [c, r])
		if not prev_rows.is_empty():
			var linked: bool = false
			for r: int in rows:
				for p: int in prev_rows:
					linked = linked or absi(r - p) <= 1
			assert_true(linked, "stream breaks at column %d" % c)
		prev_rows = rows


func test_at_least_six_rocks() -> void:
	var rocks: int = 0
	for r: int in range(1, 17):
		for c: int in range(1, 31):
			if Arena.LAYOUT[r][c] == Arena.ROCK:
				rocks += 1
	assert_gte(rocks, 6)


func test_origin_cell_and_play_area() -> void:
	assert_eq(Arena.ORIGIN_CELL, Vector2i(16, 2))
	assert_eq(Arena.TILE_PX, 16)
	assert_eq(Arena.play_area(), Rect2(0, 0, 512, 288))


func test_clamp_inside_unchanged() -> void:
	assert_eq(Arena.clamp_to_play_area(Vector2(100, 50)), Vector2(100, 50))
	assert_eq(Arena.clamp_to_play_area(Vector2(0, 0)), Vector2(0, 0))
	assert_eq(Arena.clamp_to_play_area(Vector2(512, 288)), Vector2(512, 288))


func test_clamp_each_side_and_corners() -> void:
	assert_eq(Arena.clamp_to_play_area(Vector2(-5, 300)), Vector2(0, 288))
	assert_eq(Arena.clamp_to_play_area(Vector2(-1, 100)), Vector2(0, 100))
	assert_eq(Arena.clamp_to_play_area(Vector2(100, -1)), Vector2(100, 0))
	assert_eq(Arena.clamp_to_play_area(Vector2(600, 100)), Vector2(512, 100))
	assert_eq(Arena.clamp_to_play_area(Vector2(100, 400)), Vector2(100, 288))
	assert_eq(Arena.clamp_to_play_area(Vector2(9999, 9999)), Vector2(512, 288))
	assert_eq(Arena.clamp_to_play_area(Vector2(-9999, -9999)), Vector2(0, 0))
