extends GutTest
## Story 1.5 AC1/Task 7.3: glyph drawing uses only Palette.INK and Palette.BG.

const SOURCES: Array[String] = [
	"res://src/core/glyph_font.gd",
	"res://src/arena/arena.gd",
	"res://src/ui/hud/hud.gd",
	"res://src/ui/hud/hud_frame.gd",
	"res://src/ui/hud/grid_overlay.gd",
	"res://src/ui/hud/register_panel.gd",
	"res://src/ui/screens/title/title_screen.gd",
	"res://src/presentation/player_view.gd",
	"res://src/debug/frame_overlay.gd",
	"res://src/presentation/practice_target_view.gd",
	"res://src/presentation/particle_pool.gd",
	"res://src/presentation/camera_shake.gd",
	"res://src/presentation/camera_shake_driver.gd",
	"res://src/presentation/screen_fx.gd",
	"res://src/ui/hud/log_panel.gd",
	"res://src/debug/perf_overlay.gd",
]


func test_only_ink_and_bg_are_allowed() -> void:
	assert_true(GlyphFont.is_allowed_color(Palette.INK))
	assert_true(GlyphFont.is_allowed_color(Palette.BG))
	assert_false(GlyphFont.is_allowed_color(Palette.WARN))
	assert_false(GlyphFont.is_allowed_color(Color.WHITE))


func test_no_colour_literals_or_warn_in_glyph_sources() -> void:
	var regex := RegEx.create_from_string("\\bColor\\s*\\(|\\bColor\\.[A-Z_]+\\b|Palette\\.WARN")
	for path: String in SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", "cannot read %s" % path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			assert_null(regex.search(line), "%s: %s" % [path, line.strip_edges()])


func test_drawn_colours_are_palette_constants() -> void:
	var regex := RegEx.create_from_string("draw_(cell|at)\\([^\\n]*?,\\s*(Palette\\.[A-Z]+|[a-z_]+)\\s*,\\s*[A-Z_0-9]+\\)")
	for path: String in ["res://src/arena/arena.gd", "res://src/ui/hud/hud_frame.gd", "res://src/ui/screens/title/title_screen.gd", "res://src/ui/hud/register_panel.gd", "res://src/presentation/player_view.gd", "res://src/presentation/practice_target_view.gd", "res://src/presentation/particle_pool.gd", "res://src/ui/hud/log_panel.gd", "res://src/debug/perf_overlay.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		var matches: Array[RegExMatch] = regex.search_all(text)
		assert_gt(matches.size(), 0, "no glyph draw found in %s" % path)
		for m: RegExMatch in matches:
			assert_true(m.get_string(2) in ["Palette.INK", "Palette.BG"], "%s draws with %s" % [path, m.get_string(2)])



## Story 2.8 (D-S28-6): the ScreenFX shader colours come from Palette, and its defaults match it.
func test_screen_fx_colours_follow_the_palette() -> void:
	var fx := ScreenFX.new()
	assert_eq(fx.shader_material.get_shader_parameter(&"ink_colour"), Palette.INK)
	assert_eq(fx.shader_material.get_shader_parameter(&"bg_colour"), Palette.BG)
	fx.free()
	var text: String = FileAccess.get_file_as_string("res://src/presentation/screen_fx.gdshader")
	assert_string_contains(text, "vec4(%.4f, %.4f, %.4f, 1.0)" % [Palette.INK.r, Palette.INK.g, Palette.INK.b])
	assert_string_contains(text, "vec4(%.4f, %.4f, %.4f, 1.0)" % [Palette.BG.r, Palette.BG.g, Palette.BG.b])
