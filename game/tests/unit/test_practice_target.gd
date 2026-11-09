extends GutTest
## Story 2.7 AC4: the practice target's hit bookkeeping (D-S27-4, D-S27-10). Pure sim data.


func test_defaults() -> void:
	var t := PracticeTarget.new(Vector2(320, 144))
	assert_eq(t.position_px, Vector2(320, 144))
	assert_eq(t.hurtbox_radius_px, 24.0, "1.5 tiles (D-S27-2)")
	assert_eq(t.hits, 0)
	assert_eq(t.last_hit_serial, -1)
	assert_true(t.records().is_empty())
	assert_false("hp" in t, "infinite HP: no HP field")


func test_register_hit_counts_and_remembers_the_serial() -> void:
	var t := PracticeTarget.new()
	t.register_hit(3, 100, &"slash_1", 10)
	assert_eq(t.hits, 1)
	assert_eq(t.last_hit_serial, 3)
	assert_true(t.was_hit_by(3))
	assert_false(t.was_hit_by(4))
	t.register_hit(4, 130, &"slash_2", 10)
	assert_eq(t.hits, 2)
	var expected: Array[Dictionary] = [
		{&"frame": 100, &"action": &"slash_1", &"damage": 10},
		{&"frame": 130, &"action": &"slash_2", &"damage": 10},
	]
	assert_eq(t.records(), expected)


func test_ring_keeps_the_last_8_in_order() -> void:
	var t := PracticeTarget.new()
	for i: int in 11:
		t.register_hit(i, i * 10, &"slash_1", i)
	assert_eq(t.hits, 11)
	var recs: Array[Dictionary] = t.records()
	assert_eq(recs.size(), PracticeTarget.LOG_CAPACITY)
	for i: int in recs.size():
		assert_eq(recs[i][&"frame"], (i + 3) * 10, "oldest first")
		assert_eq(recs[i][&"damage"], i + 3)


func test_reset_clears_hits_serial_and_records() -> void:
	var t := PracticeTarget.new()
	t.register_hit(1, 5, &"dash_strike", 20)
	t.reset()
	assert_eq(t.hits, 0)
	assert_eq(t.last_hit_serial, -1)
	assert_true(t.records().is_empty())
	assert_false(t.was_hit_by(1))
	t.register_hit(2, 6, &"slash_1", 10)
	assert_eq(t.records().size(), 1)


func test_multiplier_is_always_one() -> void:
	var t := PracticeTarget.new()
	assert_eq(t.damage_multiplier(), 1.0)
	for i: int in 20:
		t.register_hit(i, i, &"slash_3", 15)
	assert_eq(t.damage_multiplier(), 1.0, "never Patched, whatever it took")


func test_view_readout_lines_are_ascii_and_show_the_last_three() -> void:
	var t := PracticeTarget.new()
	assert_eq(PracticeTargetView.readout_lines(t), PackedStringArray(["hits 0"]))
	t.register_hit(1, 100, &"slash_1", 10)
	t.register_hit(2, 130, &"slash_2", 10)
	t.register_hit(3, 160, &"slash_3", 15)
	t.register_hit(4, 400, &"dash_strike", 20)
	var lines: PackedStringArray = PracticeTargetView.readout_lines(t)
	assert_eq(lines, PackedStringArray(["hits 4", "f=130 slash_2 10", "f=160 slash_3 15", "f=400 dash_strike 20"]))
	for line: String in lines:
		for i: int in line.length():
			assert_lt(line.unicode_at(i), 128, line)


func test_view_label_is_centred_and_readout_inside_the_play_area() -> void:
	var tl: Vector2 = PracticeTargetView.label_top_left(Arena.PRACTICE_TARGET_PX)
	assert_eq(tl + Vector2(GlyphFont.text_width(PracticeTargetView.LABEL, PracticeTargetView.LABEL_SCALE), GlyphFont.CELL) / 2.0, Arena.PRACTICE_TARGET_PX)
	var spawn_cell := Rect2(Arena.SPAWN_PX - Vector2(8, 8), Vector2(16, 16))
	var label := Rect2(tl, Vector2(GlyphFont.text_width(PracticeTargetView.LABEL, PracticeTargetView.LABEL_SCALE), GlyphFont.CELL))
	assert_false(label.intersects(spawn_cell), "the label never covers the spawn @")
	var top: Vector2 = PracticeTargetView.readout_top_left(4)
	assert_true(Arena.play_area().has_point(top))
	assert_true(Arena.play_area().has_point(top + Vector2(0, 4 * PracticeTargetView.LINE_STEP)))
