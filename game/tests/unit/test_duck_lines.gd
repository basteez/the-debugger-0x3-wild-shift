extends GutTest
## Story 3.6 AC 6 (A1-A3, H2): data/duck/duck_lines.tres holds T1-T4 with the GDD strings exactly,
## unique ids, ASCII text that fits the bubble, and DuckLinesDef.find() / validate() behave.

const LINES_PATH := "res://data/duck/duck_lines.tres"
const GDD: Dictionary[StringName, String] = {
	# Story 4.4 (D-S44-2): T1 rewritten for the Infinite Loop start nudge.
	&"t1_shift": "Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review.",
	&"t2_semicolon": "See the semicolon? It's always the semicolon. Hit it when it opens.",
	&"t3_dash_strike": "J then K: Dash Strike. Two bits, one commit.",
	&"t4_phase_two": "It refactored itself. Have you tried shifting it off and on again?",
}
## Story 3.8 (E4, FR45 line 8): the shared harvest line.
const HARVEST_TEXT := "Bug squashed. It dropped a bit: new windows, new combos."
## GDD D-039: the duck speaks at most 10 lines in the whole game.
const LINE_BUDGET := 10
## Story 5.6 (FR45 lines 6-7, D-S56-1): the Null Pointer tutorial lines.
const NULL_POINTER_LINES: Dictionary[StringName, String] = {
	&"n1_breakpoint": "Space: Breakpoint. Time stops, you shift. Finally, a debugger that works.",
	&"n2_hold_r": "Hold R. Pointers point *somewhere*.",
}


func _lines() -> DuckLinesDef:
	return load(LINES_PATH) as DuckLinesDef


func _line(id: StringName, text: String) -> DuckLineDef:
	var d := DuckLineDef.new()
	d.id = id
	d.text = text
	return d


func test_the_four_tutorial_lines_equal_the_gdd_strings() -> void:
	var lines: DuckLinesDef = _lines()
	assert_not_null(lines)
	assert_eq(lines.entries.size(), 12, "T1-T4 (D-S36-3), the 3.8 harvest line, the two 4.4 hint windows, the 5.1 D->L window, the 6.3 N->A and L->N windows, the 5.6 N1-N2")
	for i: int in DuckDirector.DUCK_IDS.size():
		var id: StringName = DuckDirector.DUCK_IDS[i]
		assert_eq(lines.entries[i].id, id, "order follows the beats")
		assert_eq(lines.find(id).text, GDD[id], String(id))


func test_harvest_line_is_the_fifth_entry_and_the_budget_holds() -> void:
	var lines: DuckLinesDef = _lines()
	assert_eq(lines.entries[4].id, &"harvest_shared")
	assert_eq(lines.find(&"harvest_shared").text, HARVEST_TEXT)
	assert_eq(lines.find(StringName(HarvestScreen.LINE_ID)).text, HARVEST_TEXT, "the screen's id resolves")
	assert_lte(budget_count(lines), LINE_BUDGET, "duck line budget (GDD D-039, the hint template counts once)")


## Lines counted against D-039: every entry but the hint windows, plus one for the hint template.
static func budget_count(lines: DuckLinesDef) -> int:
	var n: int = 0
	var has_hint: bool = false
	for entry: DuckLineDef in lines.entries:
		if DuckHint.is_hint_id(entry.id):
			has_hint = true
		else:
			n += 1
	return n + (1 if has_hint else 0)


func test_budget_counts_the_hint_template_once() -> void:
	assert_eq(budget_count(_lines()), 8, "T1-T4, harvest, the hint template, N1-N2 (Story 5.6)")


func test_null_pointer_lines_equal_the_gdd_strings() -> void:
	var lines: DuckLinesDef = _lines()
	for id: StringName in NULL_POINTER_LINES:
		assert_not_null(lines.find(id), String(id))
		if lines.find(id) != null:
			assert_eq(lines.find(id).text, NULL_POINTER_LINES[id], String(id))
			assert_true(DuckLineDef.is_ascii(lines.find(id).text), String(id))
			assert_eq(lines.find(id).validate(), PackedStringArray(), "fits the bubble: %s" % id)


func test_ids_are_unique_and_text_is_ascii() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for entry: DuckLineDef in _lines().entries:
		assert_false(seen.has(entry.id), "duplicate %s" % entry.id)
		seen[entry.id] = true
		if DuckHint.is_hint_id(entry.id):
			assert_true(DuckLineDef.is_drawable(entry.text), "%s: ASCII plus the arrow (D-S44-10)" % entry.id)
		else:
			assert_true(DuckLineDef.is_ascii(entry.text), String(entry.id))


func test_every_entry_validates() -> void:
	assert_eq(_lines().validate(), PackedStringArray())
	for entry: DuckLineDef in _lines().entries:
		assert_eq(entry.validate(), PackedStringArray(), String(entry.id))


func test_find_returns_null_when_absent() -> void:
	assert_null(_lines().find(&"no_such_line"))
	assert_null(_lines().find(&""))


func test_line_validation_reports_bad_values() -> void:
	assert_gt(_line(&"", "hi").validate().size(), 0, "empty id")
	assert_gt(_line(&"x", "").validate().size(), 0, "empty text")
	assert_gt(_line(&"x", "café").validate().size(), 0, "non-ASCII")
	assert_eq(_line(&"x", "Weak window: D→A.").validate().size(), 0, "the hint arrow is allowed (D-S44-10)")
	assert_gt(_line(&"x", "D←A").validate().size(), 0, "other arrows are not")
	assert_gt(_line(&"x", "a supercalifragilistic word").validate().size(), 0, "word wider than 12")
	assert_gt(_line(&"x", "word ".repeat(40).strip_edges()).validate().size(), 0, "20 lines, more than 15")
	assert_eq(_line(&"x", "short and fine").validate().size(), 0)


func test_lines_def_reports_duplicates_and_nulls() -> void:
	var d := DuckLinesDef.new()
	d.entries = [_line(&"a", "one"), _line(&"a", "two"), null]
	var messages: PackedStringArray = d.validate()
	assert_eq(messages.size(), 2, ", ".join(messages))
