extends GutTest
## Story 1.5 AC5 / 1.6 AC2: the vendored font covers every glyph the arena, HUD frame, title and
## placeholder screens draw.
## The set is derived from the code's constants so it cannot drift from what is drawn.

const FONT_DIR := "res://assets/fonts/"
const LICENSE_PATH := "res://assets/fonts/wildshift8-LICENSE.txt"
## Glyphs the HUD frame draws besides its text constants (box drawing) and the 2.3 cooldown cells.
const FRAME_GLYPHS := "┌┐└┘├┤─│■□░█"


func _used_codepoints() -> Dictionary[int, String]:
	var texts: PackedStringArray = []
	texts.append_array(Arena.LAYOUT)
	texts.append(Arena.LABEL)
	texts.append_array([Hud.TOP_BAR, Hud.SKY, Hud.REG_TITLE, Hud.LOG_HEADER])
	texts.append_array(Hud.LINE_NO)
	texts.append_array(Hud.box_rows(Hud.REGISTER, Hud.REG_TITLE))
	texts.append_array(Hud.box_rows(Hud.DUCK))
	texts.append_array([TitleScreen.TITLE_TEXT, TitleScreen.PROMPT_TEXT])
	texts.append(FRAME_GLYPHS)
	# Story 2.6: the register panel's J→K label and every combo name (D3).
	texts.append(RegisterPanel.JK_LABEL)
	for combo: ComboDef in Defs.COMBOS.combos:
		texts.append(combo.display_name)
	# Story 1.6 placeholder screens: every state and boss index they can show.
	for state: int in [Game.FlowState.INTRO, Game.FlowState.FIGHT, Game.FlowState.HARVEST, Game.FlowState.ENDING]:
		for boss: int in 3:
			texts.append_array(PlaceholderScreen.lines_for(state, boss))
	# Story 1.7 pause screen, both mute states.
	texts.append_array(PauseScreen.lines_for(false))
	texts.append_array(PauseScreen.lines_for(true))
	# Story 2.7: the practice target label (the 2.7 readout is gone, Story 2.8).
	texts.append(PracticeTargetView.LABEL)
	# Story 2.8: the log lines, the perf overlay and the particle glyphs.
	texts.append(LogPanel.line_for_damage(1234567890))
	texts.append_array(PerfOverlay.lines(60.0, 16.7, 300, 1234567890))
	texts.append_array(PerfOverlay.lines(60.0, 16.7, 0, 0))
	texts.append_array(ParticlePool.GLYPHS)
	# Story 3.1: the boss header, the test boss line and the tell mark.
	texts.append(Hud.boss_header("testBoss", 1234567890))
	texts.append((load("res://data/bosses/test_boss/boss_def.tres") as BossDef).name_signature)
	texts.append(BossView.TELL_MARK)
	# Story 3.6: the duck bubble's glyph and every duck line (wrapped as drawn).
	texts.append(DuckBubble.DUCK_GLYPH)
	for entry: DuckLineDef in (load("res://data/duck/duck_lines.tres") as DuckLinesDef).entries:
		texts.append_array(DuckBubble.wrap(entry.text))
	# Story 3.8: the HARVEST screen rows and the Infinite Loop's fixed line (D4).
	var harvest := HarvestScreen.new()
	harvest.setup(0, (load("res://data/bosses/infinite_loop/boss_def.tres") as BossDef).fixed_line, Register.Bit.LOOP, Register.fight_start_for_boss(0))
	texts.append_array(harvest.text_rows())
	harvest.free()
	texts.append(HarvestScreen.FIXED_FALLBACK)
	var used: Dictionary[int, String] = {}
	for t: String in texts:
		for i: int in t.length():
			used[t.unicode_at(i)] = t[i]
	return used


func test_font_has_every_used_glyph() -> void:
	var font: Font = GlyphFont.font()
	var used: Dictionary[int, String] = _used_codepoints()
	assert_gt(used.size(), 20, "derived glyph set looks too small")
	for code: int in used:
		if code == 0x20:
			continue
		assert_true(font.has_char(code), "font lacks U+%04X '%s'" % [code, used[code]])


func test_font_covers_printable_ascii() -> void:
	var font: Font = GlyphFont.font()
	for code: int in range(0x21, 0x7F):
		assert_true(font.has_char(code), "font lacks ASCII 0x%02X" % code)


func test_font_is_an_8px_bitmap_font_with_integer_scaling() -> void:
	var font := GlyphFont.font() as FontFile
	assert_not_null(font)
	assert_eq(font.fixed_size, 8)
	assert_eq(font.fixed_size_scale_mode, TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY)
	assert_eq(font.get_height(8), 8.0)
	assert_eq(font.get_height(16), 16.0)
	assert_eq(font.get_string_size("ab", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 16.0)
	assert_eq(font.get_string_size("ab", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, 32.0)


func test_licence_file_names_font_version_url_and_cc0() -> void:
	assert_true(FileAccess.file_exists(LICENSE_PATH), "licence file missing")
	var text: String = FileAccess.get_file_as_string(LICENSE_PATH)
	assert_string_contains(text, "Wildshift8")
	assert_string_contains(text, "Version:")
	assert_string_contains(text, "https://github.com/basteez/the-debugger-0x3-wild-shift")
	assert_string_contains(text, "CC0 1.0 Universal")
	assert_string_contains(text, "Statement of Purpose")
