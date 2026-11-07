extends GutTest
## Story 1.5 AC4/DC2: the title uses the pixel font at 2x; text constants unchanged.

const TITLE_PATH := "res://src/ui/screens/title/title_screen.gd"


func test_no_fallback_font_in_title() -> void:
	var text: String = FileAccess.get_file_as_string(TITLE_PATH)
	assert_ne(text, "")
	assert_false(text.contains("fallback_font"), "title still references ThemeDB.fallback_font")
	assert_true(text.contains("GlyphFont."), "title does not draw with GlyphFont")


func test_text_constants_unchanged() -> void:
	assert_eq(TitleScreen.TITLE_TEXT, "The Debugger 0x03: Wild Shift")
	assert_eq(TitleScreen.PROMPT_TEXT, "press any key")


func test_title_fits_and_sits_on_the_8px_grid() -> void:
	assert_eq(TitleScreen.TEXT_SCALE, 2)
	assert_eq(GlyphFont.text_width(TitleScreen.TITLE_TEXT, 2), 464)
	assert_lte(GlyphFont.text_width(TitleScreen.TITLE_TEXT, 2), Const.BASE_RES.x)
	for y: int in [TitleScreen.TITLE_TOP_Y, TitleScreen.PROMPT_TOP_Y]:
		assert_eq(y % 8, 0)
	for t: String in [TitleScreen.TITLE_TEXT, TitleScreen.PROMPT_TEXT]:
		var x: int = TitleScreen.centred_x(t)
		assert_eq(x % 8, 0)
		assert_lte(absi(x * 2 + GlyphFont.text_width(t, 2) - Const.BASE_RES.x), 16, "not centred: %s" % t)
