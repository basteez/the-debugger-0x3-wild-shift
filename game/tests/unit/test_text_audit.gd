extends GutTest
## Story 6.9 (E1; AC 1-3, 5-10, 13): the game text audit. The GDD Duck table (with the shipped T1,
## D-S69-3), the 10-line budget (D-S69-4), the hint windows derived from the boss data, the three
## fixed lines and sky comments (data/text), the HUD sky accessor, the harvest fallback, the screen
## text, and the check that no `data`-class string reappears as a literal in its former script.

const LINES: DuckLinesDef = preload("res://data/duck/duck_lines.tres")
const FIXED: TextFixedLines = preload("res://data/text/fixed_lines.tres")
const SKY: TextSkyComments = preload("res://data/text/sky_comments.tres")
const SCREEN: TextScreenText = preload("res://data/text/screen_text.tres")
const ENDING: EndingText = preload("res://data/ending/ending_text.tres")
const BOSS_DEF_PATHS: Dictionary[StringName, String] = {
	&"infinite_loop": "res://data/bosses/infinite_loop/boss_def.tres",
	&"null_pointer": "res://data/bosses/null_pointer/boss_def.tres",
	&"segfault": "res://data/bosses/segfault/boss_def.tres",
}
## GDD "Duck (hint system)" table, rows 1-9 (row 2 is the shipped T1, D-S44-2 / D-S69-3).
const GDD_DUCK: Dictionary[StringName, String] = {
	&"intro_handover": "Quack. Explain the bug to me. Use these.",
	&"t1_shift": "Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review.",
	&"t2_semicolon": "See the semicolon? It's always the semicolon. Hit it when it opens.",
	&"t3_dash_strike": "J then K: Dash Strike. Two bits, one commit.",
	&"t4_phase_two": "It refactored itself. Have you tried shifting it off and on again?",
	&"n1_breakpoint": "Space: Breakpoint. Time stops, you shift. Finally, a debugger that works.",
	&"n2_hold_r": "Hold R. Pointers point *somewhere*.",
	&"harvest_shared": "Bug squashed. It dropped a bit: new windows, new combos.",
	&"ending": "Quack. Works on your machine now.",
}
## GDD row 10: "Quack. Weak window: {X→Y}."
const GDD_HINT_PREFIX := "Quack. Weak window: "
const LINE_BUDGET := 10
## GDD Boss Design "Fixed line on defeat".
const GDD_FIXED: Dictionary[StringName, String] = {
	&"infinite_loop": "for (i = 0; i < n; i++) { }",
	&"null_pointer": "if (ptr != null) ptr.deref();",
	&"segfault": "if (idx < len) buf[idx] = val;",
}
## GDD Art Style sky comment list.
const GDD_SKY_DEFAULT := "// TODO: this should terminate"
const GDD_SKY_NULL_POINTER := "// FIXME: who owns this pointer?"
const GDD_SKY_SEGFAULT := "// HACK: do not read past this line"
## AC 13 allowlist: the `data`-class strings moved by this story, and the scripts that held them.
## Each quoted string must never reappear (with its quotes) in its former script.
## Built at run time: a const typed Dictionary of PackedStringArray (with const refs) came out empty
## and then crashed (signal 11) on the Linux CI build of Godot 4.7.2.
func _moved_literals() -> Dictionary:
	return {
		"res://src/ui/hud/hud.gd": [GDD_SKY_DEFAULT, GDD_SKY_NULL_POINTER, GDD_SKY_SEGFAULT],
		"res://src/ui/screens/harvest/harvest_screen.gd": ["press any key", "// bug fixed"],
		"res://src/ui/screens/title/title_screen.gd": ["The Debugger 0x03: Wild Shift", "press any key"],
		"res://src/ui/screens/intro/intro_screen.gd": ["2 a.m.", "stuck on a bug", "squeeze", "QUACK", "The Clearing"],
		"res://src/ui/screens/dead/dead_screen.gd": ["Process exited with code 1"],
		"res://src/ui/screens/placeholder/placeholder_screen.gd": ["press any key"],
		"res://src/ui/screens/ending/ending_screen.gd": ["press any key", "fix: wild shift"],
	}


func _boss(id: StringName) -> BossDef:
	return load(BOSS_DEF_PATHS[id]) as BossDef


# --- Duck lines (AC 1-5) ---------------------------------------------------------------------


func test_hand_written_lines_equal_the_gdd_table() -> void:
	var hand_written: Array[StringName] = []
	for entry: DuckLineDef in LINES.entries:
		if not DuckHint.is_hint_id(entry.id):
			hand_written.append(entry.id)
	assert_eq(hand_written.size(), GDD_DUCK.size(), "exactly the 9 hand-written GDD rows")
	for id: StringName in GDD_DUCK:
		var entry: DuckLineDef = LINES.find(id)
		assert_not_null(entry, "%s is in the catalogue" % id)
		if entry != null:
			assert_eq(entry.text, GDD_DUCK[id], String(id))


func test_the_budget_is_ten_with_the_hint_template_counted_once() -> void:
	var count: int = 0
	var has_hint: bool = false
	for entry: DuckLineDef in LINES.entries:
		if DuckHint.is_hint_id(entry.id):
			has_hint = true
		else:
			count += 1
	assert_true(has_hint)
	assert_eq(count + (1 if has_hint else 0), LINE_BUDGET, "GDD D-039: 10 lines, never more")


func test_hint_entries_are_exactly_the_boss_windows() -> void:
	assert_eq(DuckHint.PREFIX, GDD_HINT_PREFIX, "the template matches GDD row 10")
	var expected: Dictionary[StringName, String] = {}
	for id: StringName in BOSS_DEF_PATHS:
		for w: Vector2i in DuckHint.windows_of(_boss(id)):
			expected[DuckHint.line_id_for(w)] = DuckHint.window_text(w)
	var actual: Dictionary[StringName, String] = {}
	for entry: DuckLineDef in LINES.entries:
		if DuckHint.is_hint_id(entry.id):
			actual[entry.id] = entry.text
	assert_eq(actual.size(), expected.size(), "no missing and no extra hint window")
	for id: StringName in expected:
		assert_eq(actual.get(id, ""), expected[id], String(id))
		assert_true(String(actual.get(id, "")).begins_with(GDD_HINT_PREFIX))


func test_every_duck_line_validates_and_fits_the_bubble() -> void:
	for entry: DuckLineDef in LINES.entries:
		assert_eq(entry.validate(), PackedStringArray(), String(entry.id))
		var text: String = entry.text.replace(DuckHint.ARROW, "") if DuckHint.is_hint_id(entry.id) else entry.text
		assert_true(DuckLineDef.is_ascii(text), "%s is ASCII (the hint arrow aside)" % entry.id)
		var rows: PackedStringArray = DuckBubble.wrap(entry.text, DuckBubble.WRAP_WIDTH)
		assert_lte(rows.size(), DuckBubble.MAX_LINES, String(entry.id))
		for row: String in rows:
			assert_lte(row.length(), DuckBubble.WRAP_WIDTH, String(entry.id))


# --- Fixed lines and sky comments (AC 6-9) ---------------------------------------------------


func test_fixed_lines_are_the_three_gdd_lines_and_match_the_bosses() -> void:
	assert_eq(FIXED.validate(), PackedStringArray())
	assert_eq(FIXED.entries.size(), 3)
	for id: StringName in GDD_FIXED:
		assert_eq(FIXED.line_for(id), GDD_FIXED[id], String(id))
		assert_eq(_boss(id).fixed_line, FIXED.line_for(id), "D-S69-2: BossDef agrees with the audited list (%s)" % id)


func test_sky_comments_are_the_three_gdd_comments() -> void:
	assert_eq(SKY.validate(), PackedStringArray())
	assert_eq(SKY.default_comment, GDD_SKY_DEFAULT)
	assert_eq(SKY.null_pointer, GDD_SKY_NULL_POINTER)
	assert_eq(SKY.segfault, GDD_SKY_SEGFAULT)


func test_hud_sky_reads_the_data_for_each_boss_and_no_boss() -> void:
	assert_eq(Hud.SKY, SKY.default_comment)
	assert_eq(Hud.SKY_NULL_POINTER, SKY.null_pointer)
	assert_eq(Hud.SKY_SEGFAULT, SKY.segfault)
	assert_eq(Hud.sky_for(&"infinite_loop"), SKY.default_comment)
	assert_eq(Hud.sky_for(&"null_pointer"), SKY.null_pointer)
	assert_eq(Hud.sky_for(&"segfault"), SKY.segfault)
	assert_eq(Hud.sky_for(&""), SKY.default_comment, "no boss")
	for text: String in SKY.all_text():
		assert_lte(text.length(), Hud.COLS)


func test_harvest_fallback_is_data_and_used_only_without_a_fixed_line() -> void:
	assert_eq(FIXED.fallback, "// bug fixed")
	assert_eq(HarvestScreen.FIXED_FALLBACK, FIXED.fallback)
	assert_false(FIXED.entries.values().has(FIXED.fallback), "not one of the 3 GDD lines (D-S69-7)")
	var screen := HarvestScreen.new()
	screen.setup(0, "", 0, Register.fight_start_for_boss(0))
	assert_eq(screen.fixed_text(), FIXED.fallback)
	screen.setup(0, GDD_FIXED[&"infinite_loop"], 0, Register.fight_start_for_boss(0))
	assert_eq(screen.fixed_text(), GDD_FIXED[&"infinite_loop"])
	screen.free()


func test_text_defs_report_bad_values() -> void:
	var fixed := TextFixedLines.new()
	assert_gt(fixed.validate().size(), 0, "no entries, no fallback")
	var sky := TextSkyComments.new()
	assert_gt(sky.validate().size(), 0, "empty comments")
	var wrong_ids := TextFixedLines.new()
	wrong_ids.fallback = "x"
	wrong_ids.entries = {&"nullpointer": "a", &"infinite_loop": "b", &"segfault": "c"}
	assert_gt(wrong_ids.validate().size(), 0, "a mistyped boss id is reported")
	var screen := TextScreenText.new()
	assert_gt(screen.validate().size(), 0, "empty fields, no panels")
	var bad: TextScreenText = SCREEN.duplicate()
	var one_panel: Array[PackedStringArray] = []
	one_panel.append(PackedStringArray(["one"]))
	bad.intro_captions = one_panel
	assert_eq(bad.validate().size(), 1, "one panel instead of 3")


# --- Screen text (AC 10, 11) -----------------------------------------------------------------


func test_screen_text_validates_and_the_screens_read_it() -> void:
	assert_eq(SCREEN.validate(), PackedStringArray())
	assert_eq(TitleScreen.TITLE_TEXT, SCREEN.title)
	assert_eq(TitleScreen.PROMPT_TEXT, SCREEN.prompt)
	assert_eq(HarvestScreen.PROMPT_TEXT, SCREEN.prompt)
	assert_eq(DeadScreen.TEXT, SCREEN.dead_line)
	assert_eq(SCREEN.title, "The Debugger 0x03: Wild Shift")
	assert_eq(SCREEN.prompt, "press any key")
	assert_eq(SCREEN.dead_line, "Process exited with code 1")


func test_intro_captions_keep_their_panel_grouping() -> void:
	assert_eq(SCREEN.intro_captions.size(), IntroScreen.PANEL_COUNT)
	var sizes: Array[int] = []
	for panel: int in IntroScreen.PANEL_COUNT:
		assert_eq(IntroScreen.caption_for(panel), SCREEN.intro_captions[panel])
		sizes.append(IntroScreen.caption_for(panel).size())
	assert_eq(sizes, [2, 2, 1] as Array[int], "2 + 2 + 1 rows")
	assert_eq(IntroScreen.caption_for(-1), PackedStringArray())
	assert_eq(IntroScreen.caption_for(3), PackedStringArray())


func test_ending_text_is_audited_in_place() -> void:
	assert_eq(ENDING.validate(), PackedStringArray())
	assert_eq(ENDING.prompt, SCREEN.prompt, "the same prompt wording, kept in ending_text.tres (AC 11)")
	assert_eq(LINES.find(EndingScreen.LINE_ID).text, GDD_DUCK[&"ending"])


# --- Literal reappearance (AC 13) ------------------------------------------------------------


func test_moved_strings_never_reappear_as_literals_in_their_former_scripts() -> void:
	var moved: Dictionary = _moved_literals()
	for path: String in moved:
		assert_true(FileAccess.file_exists(path), path)
		var source: String = FileAccess.get_file_as_string(path)
		assert_gt(source.length(), 0, path)
		for text: String in moved[path]:
			assert_ne(text, "", "%s: a moved literal resolved to empty, so it would match anything" % path)
			if text.is_empty():
				continue
			var quoted: String = "\"%s\"" % text
			assert_false(source.contains(quoted), "%s holds the literal %s (move it to data/text)" % [path, quoted])
