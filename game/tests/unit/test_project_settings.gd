extends GutTest
## Ports the Story 1.1 project-setting checks (renderer, viewport, stretch, timing, audio, typing).


func _setting(key: String) -> Variant:
	return ProjectSettings.get_setting(key)


func test_renderer_is_gl_compatibility() -> void:
	assert_eq(_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_viewport_is_640x360() -> void:
	assert_eq(_setting("display/window/size/viewport_width"), 640)
	assert_eq(_setting("display/window/size/viewport_height"), 360)


func test_window_override_is_1280x720() -> void:
	assert_eq(_setting("display/window/size/window_width_override"), 1280)
	assert_eq(_setting("display/window/size/window_height_override"), 720)


func test_stretch_is_viewport_keep_integer() -> void:
	assert_eq(_setting("display/window/stretch/mode"), "viewport")
	assert_eq(_setting("display/window/stretch/aspect"), "keep")
	assert_eq(_setting("display/window/stretch/scale_mode"), "integer")


func test_default_texture_filter_is_nearest() -> void:
	assert_eq(_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_physics_ticks_per_second_is_60() -> void:
	assert_eq(_setting("physics/common/physics_ticks_per_second"), 60)


func test_web_audio_playback_is_sample() -> void:
	assert_eq(_setting("audio/general/default_playback_type.web"), 1)


func test_untyped_declaration_is_error() -> void:
	assert_eq(_setting("debug/gdscript/warnings/untyped_declaration"), 2)


func test_max_fps_is_60() -> void:
	assert_eq(_setting("application/run/max_fps"), 60)


func test_main_scene_is_main_tscn() -> void:
	assert_eq(_setting("application/run/main_scene"), "res://src/main/main.tscn")


func test_clear_color_is_palette_bg() -> void:
	var clear: Color = _setting("rendering/environment/defaults/default_clear_color")
	assert_true(clear.is_equal_approx(Palette.BG), "clear colour %s != Palette.BG %s" % [clear, Palette.BG])
