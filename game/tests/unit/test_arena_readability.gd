extends GutTest
## Story 9.7 (D-S97-1..8): arena readability. The 75% scenery dither and its core home (DC4a), the
## water glyph, the actor halo and its redraw-on-change rule, the inverted title bar, the practice
## readout on the console header and the sky row comments. Pure geometry and data; no pixel reads.

const SKY: TextSkyComments = preload("res://data/text/sky_comments.tres")
const SCREEN: TextScreenText = preload("res://data/text/screen_text.tres")
const FAR := Vector2.INF

var _arena: Arena


func before_each() -> void:
	TestIsolation.reset_shared_state()


func after_each() -> void:
	if is_instance_valid(_arena):
		_arena.free()


# --- AC 1, 5: the dither textures --------------------------------------------------------------


func test_scenery_dither_keeps_one_ink_pixel_per_2x2_block() -> void:
	var img: Image = Dither.scenery().get_image()
	assert_eq(img.get_size(), Vector2i(Dither.SIZE, Dither.SIZE))
	var kept: int = 0
	for y: int in Dither.SIZE:
		for x: int in Dither.SIZE:
			var c: Color = img.get_pixel(x, y)
			if x % 2 == 0 and y % 2 == 0:
				assert_eq(c.a, 0.0, "INK kept at %d,%d" % [x, y])
				kept += 1
			else:
				assert_eq(c, Palette.BG, "BG at %d,%d" % [x, y])
	assert_eq(kept * 4, Dither.SIZE * Dither.SIZE, "75% BG")


func test_checker_is_the_register_panels_50_percent_pattern() -> void:
	assert_same(RegisterPanel.checker_texture(), Dither.checker(), "one shared texture, built in core")
	var img: Image = Dither.checker().get_image()
	for y: int in Dither.SIZE:
		for x: int in Dither.SIZE:
			var c: Color = img.get_pixel(x, y)
			if (x + y) % 2 == 0:
				assert_eq(c, Palette.BG)
			else:
				assert_eq(c.a, 0.0)


## DC4a: nothing under src/arena/ references ui/ or presentation/ (paths or class names).
func test_arena_folder_never_names_ui_or_presentation() -> void:
	var names: Array[String] = []
	for dir: String in ["res://src/ui", "res://src/presentation"]:
		for path: String in _scripts(dir):
			var m: RegExMatch = RegEx.create_from_string("(?m)^class_name\\s+(\\w+)").search(FileAccess.get_file_as_string(path))
			if m != null:
				names.append(m.get_string(1))
	assert_gt(names.size(), 5, "class names collected")
	var arena_files: Array[String] = _scripts("res://src/arena")
	assert_gt(arena_files.size(), 0)
	for path: String in arena_files:
		var text: String = FileAccess.get_file_as_string(path)
		assert_false(text.contains("res://src/ui") or text.contains("res://src/presentation"), "%s loads a ui/presentation path" % path)
		var code: String = _code_only(text)
		for n: String in names:
			assert_null(RegEx.create_from_string("\\b%s\\b" % n).search(code), "%s names %s" % [path, n])
	assert_string_contains(FileAccess.get_file_as_string("res://src/arena/arena.gd"), "Dither.scenery()")


# --- AC 2: the water glyph ---------------------------------------------------------------------


func test_water_is_equals_and_no_tilde_left() -> void:
	assert_eq(Arena.WATER, "=")
	var water: int = 0
	for line: String in Arena.LAYOUT:
		assert_false(line.contains("~"), line)
		water += line.count("=")
	assert_gt(water, 20, "the stream is still there")
	assert_true(GlyphFont.FONT.has_char("=".unicode_at(0)), "the font has the glyph")


# --- AC 3: the halo ------------------------------------------------------------------------------


func test_halo_radii() -> void:
	var c := Vector2(100, 100)
	for d: float in [0.0, 23.0, 24.0]:
		assert_true(Arena.in_halo(c, c + Vector2(d, 0), FAR, 0.0, FAR, FAR), "player at %s" % d)
	assert_false(Arena.in_halo(c, c + Vector2(24.5, 0), FAR, 0.0, FAR, FAR), "outside the player halo")
	assert_true(Arena.in_halo(c, FAR, c + Vector2(0, 30), 10.0, FAR, FAR), "boss radius 10 + 20")
	assert_false(Arena.in_halo(c, FAR, c + Vector2(0, 30.5), 10.0, FAR, FAR))
	assert_true(Arena.in_halo(c, FAR, FAR, 0.0, c + Vector2(32, 0), FAR), "practice target 32")
	assert_false(Arena.in_halo(c, FAR, FAR, 0.0, c + Vector2(32.5, 0), FAR))
	assert_true(Arena.in_halo(c, FAR, FAR, 0.0, FAR, c - Vector2(24, 0)), "decoy 24")
	assert_false(Arena.in_halo(c, FAR, FAR, 0.0, FAR, c - Vector2(24.5, 0)))
	assert_false(Arena.in_halo(c, FAR, FAR, 0.0, FAR, FAR), "no actor, no halo")


func test_trees_and_label_are_never_hidden() -> void:
	# Every actor on top of the label row and the ring corners.
	var hidden: PackedInt32Array = Arena.hidden_cells_for(Vector2(40, 8), Vector2(200, 8), 200.0, Vector2(8, 280), Vector2(504, 140))
	assert_gt(hidden.size(), 0)
	for idx: int in hidden:
		@warning_ignore("integer_division")
		var ch: String = Arena.LAYOUT[idx / Arena.TILES.x][idx % Arena.TILES.x]
		assert_true(Arena.is_scenery(ch), "only scenery hides (got '%s')" % ch)
	assert_false(Arena.is_scenery(Arena.TREE))
	for i: int in Arena.LABEL.length():
		assert_false(Arena.is_scenery(Arena.LABEL[i]), "label glyph '%s'" % Arena.LABEL[i])
	# The label row is row 0: no index there is ever hidden.
	for idx: int in hidden:
		assert_gt(idx, Arena.TILES.x - 1, "row 0 (ring + label) stays")


func test_hidden_cells_follow_the_live_actors() -> void:
	_arena = Arena.new()
	_arena.player.position_px = Vector2(-500, -500)
	assert_eq(_arena.current_hidden_cells().size(), 0, "nothing near: nothing hidden")
	_arena.player.position_px = Arena.cell_centre_px(Vector2i(1, 1)) # a grass cell
	assert_eq(Arena.LAYOUT[1][1], Arena.GRASS)
	var near: PackedInt32Array = _arena.current_hidden_cells()
	assert_true(near.has(Arena.cell_index(Vector2i(1, 1))), "the cell under the @")
	_arena.player.position_px = Vector2(-500, -500)
	_arena.enter_fight(Register.fight_start_for_boss(0), true)
	assert_not_null(_arena.practice_target)
	var with_target: PackedInt32Array = _arena.current_hidden_cells()
	assert_eq(with_target, Arena.hidden_cells_for(Vector2(-500, -500), FAR, 0.0, Arena.PRACTICE_TARGET_PX, FAR))


## AC 4: the arena redraws only when the hidden set changes.
func test_redraw_only_when_the_set_changes() -> void:
	_arena = Arena.new()
	_arena.player.position_px = Vector2(-500, -500)
	_arena.refresh_hidden_cells()
	assert_false(_arena.refresh_hidden_cells(), "same set: no redraw")
	_arena.player.position_px = Arena.cell_centre_px(Vector2i(1, 1))
	assert_true(_arena.refresh_hidden_cells(), "the @ moved onto grass")
	assert_eq(_arena.hidden_cells(), _arena.current_hidden_cells())
	_arena.player.position_px += Vector2(0.5, 0)
	assert_false(_arena.refresh_hidden_cells(), "half a pixel: the same cells")
	var src: String = FileAccess.get_file_as_string("res://src/arena/arena.gd")
	var body: String = src.substr(src.find("func _process("), 200)
	assert_false(body.contains("queue_redraw"), "no unconditional redraw in _process")


# --- AC 10, 11: the title bar, HP readout and practice readout ------------------------------------


func test_title_bar_spans_row_0() -> void:
	assert_eq(HudFrameScript.title_bar_rect(), Rect2(0, 0, Hud.COLS * GlyphFont.CELL, 8))
	assert_eq(HpReadout.COLOR, Palette.BG, "the HP readout is BG on the bar")
	assert_eq(HpReadout.cell_for("hp: 0b11111"), Vector2i(Hud.COLS - 11, 0))


## D-S97-14: 16 px for rows 0-1. The title bar is one cell (8 px) and its text starts on its top row;
## y = 8 is a BG gap; the sky text starts at y = 9 and the all-caps tell rect is cap height (7 px),
## so it starts 1 px under the bar and ends on row 2's top edge.
func test_rows_0_and_1_pixel_layout() -> void:
	var bar: Rect2 = HudFrameScript.title_bar_rect()
	var text_top: Vector2 = HudFrameScript.title_text_px(0)
	assert_eq(text_top, Vector2(0, 0))
	assert_eq(HpReadout.top_left_for("hp: 0b11111"), Vector2((Hud.COLS - 11) * GlyphFont.CELL, 0), "the readout matches the bar text")
	assert_eq(text_top.y + GlyphFont.CELL, bar.end.y, "the whole glyph cell (descender row too) is inside the bar")
	var sky: Vector2 = HudFrameScript.sky_text_px()
	assert_eq(sky, Vector2(0, 9))
	var tell: Rect2 = HudFrameScript.tell_rect(Hud.WARNING_TELL_TEXT)
	assert_eq(tell.position, sky)
	assert_gte(tell.position.y - bar.end.y, 1.0, "D-S97-14: at least 1 px of BG between the bar and the tell")
	assert_eq(tell.size, Vector2(Hud.WARNING_TELL_TEXT.length() * GlyphFont.CELL, 7))
	assert_lte(tell.end.y, float(Hud.REGISTER.position.y * GlyphFont.CELL), "the tell never covers row 2")
	assert_eq(Hud.WARNING_TELL_TEXT, Hud.WARNING_TELL_TEXT.to_upper(), "no descender row: the glyphs fit the 7-px rect")
	var font: Font = GlyphFont.font()
	assert_eq(font.get_ascent(GlyphFont.CELL), 7.0, "the baseline is not the cause (ascent 7 at size 8)")
	assert_eq(font.get_height(GlyphFont.CELL), 8.0)


func test_practice_readout_on_the_console_header() -> void:
	var text: String = PracticeFrameCounter.header_text(1234)
	assert_string_contains(text, "frames 1234")
	assert_string_contains(text, SCREEN.practice_hint)
	var cell: Vector2i = PracticeFrameCounter.header_cell(text)
	assert_eq(cell.y, Hud.LOG.position.y, "row 38, the console rule")
	assert_eq(cell.x + text.length(), Hud.COLS - 2, "right-aligned two columns from the edge")
	assert_gt(cell.x, 12, "clear of the `── console` title")
	var back: Rect2 = PracticeFrameCounter.backing_rect(text)
	assert_eq(back.position, Vector2(cell * GlyphFont.CELL))
	assert_eq(back.size, Vector2(text.length() * GlyphFont.CELL, GlyphFont.CELL))
	var wide: String = PracticeFrameCounter.header_text(9999999)
	assert_gt(PracticeFrameCounter.header_cell(wide).x, 12, "a long practice still fits")


func test_practice_counter_lives_on_the_hud() -> void:
	var main_src: String = FileAccess.get_file_as_string("res://src/main/main.gd")
	assert_string_contains(main_src, "hud.add_child(practice_counter)")
	assert_false(main_src.contains("arena.add_child(practice_counter)"))


# --- AC 15, 16: the sky row --------------------------------------------------------------------------


func test_sky_comments_for_tutorial_and_practice() -> void:
	assert_eq(SKY.tutorial, "// TODO: write the tests first")
	assert_eq(SKY.practice, "// sandbox: nothing here ships")
	assert_true(SKY.all_text().has(SKY.tutorial) and SKY.all_text().has(SKY.practice), "audited and font-checked")
	assert_eq(SKY.validate(), PackedStringArray())
	assert_eq(Hud.sky_for_context(Hud.SKY_CONTEXT_TUTORIAL, &"tutorial_dummy"), SKY.tutorial)
	assert_eq(Hud.sky_for_context(Hud.SKY_CONTEXT_PRACTICE, &""), SKY.practice)
	assert_eq(Hud.sky_for_context(Hud.SKY_CONTEXT_FIGHT, &"null_pointer"), SKY.null_pointer)
	assert_eq(Hud.sky_for_context(Hud.SKY_CONTEXT_FIGHT, &"segfault"), SKY.segfault)
	assert_eq(Hud.sky_for_context(Hud.SKY_CONTEXT_FIGHT, &"infinite_loop"), SKY.default_comment)
	assert_eq(MainScript.sky_context_for(true, false), Hud.SKY_CONTEXT_TUTORIAL)
	assert_eq(MainScript.sky_context_for(false, true), Hud.SKY_CONTEXT_PRACTICE)
	assert_eq(MainScript.sky_context_for(false, false), Hud.SKY_CONTEXT_FIGHT)


## D-S97-13: the normal sky comment is plain INK (no dither); the tell is the inverted run.
func test_sky_comment_is_plain_ink() -> void:
	var src: String = FileAccess.get_file_as_string("res://src/ui/hud/hud_frame.gd")
	assert_false(src.contains("Dither"), "no dither on row 1")
	assert_false(src.contains("sky_dither_rect"))


## D-S97-14: every glyph of the tell text is fully inside the 7-px rect (no pixel on glyph row 7).
func test_tell_glyphs_fit_the_rect() -> void:
	for ch: String in Hud.WARNING_TELL_TEXT:
		if ch == " ":
			continue
		for px: Vector2i in _glyph_pixels(ch):
			assert_lt(px.y, Hud.TELL_HEIGHT_PX, "glyph %s pixel %s inside the tell rect" % [ch, px])


## The INK pixels of glyph `ch` in the font atlas, glyph-local (x, y).
static func _glyph_pixels(ch: String) -> Array[Vector2i]:
	var fnt: String = FileAccess.get_file_as_string("res://assets/fonts/wildshift8.fnt")
	var m: RegExMatch = RegEx.create_from_string("char id=%d x=(\\d+) y=(\\d+)" % ch.unicode_at(0)).search(fnt)
	var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/fonts/wildshift8_0.png"))
	atlas.convert(Image.FORMAT_RGBA8)
	var out: Array[Vector2i] = []
	for y: int in GlyphFont.CELL:
		for x: int in GlyphFont.CELL:
			var p: Color = atlas.get_pixel(int(m.get_string(1)) + x, int(m.get_string(2)) + y)
			if p.a > 0.5 and p.r > 0.5:
				out.append(Vector2i(x, y))
	return out


const HudFrameScript := preload("res://src/ui/hud/hud_frame.gd")
const MainScript := preload("res://src/main/main.gd")


## The source without comment lines, trailing comments or string literals (identifiers only).
static func _code_only(text: String) -> String:
	var strings := RegEx.create_from_string("\"[^\"\\n]*\"")
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		var code: String = strings.sub(line, "\"\"", true)
		var hash_at: int = code.find("#")
		out.append(code.left(hash_at) if hash_at >= 0 else code)
	return "\n".join(out)


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
