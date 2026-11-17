extends GutTest
## Story 9.6 (AC 7, 9, D-S96-4, D-S96-6): guards for the 9.4 review rows 88 and 199. In the shipped
## `viewport` stretch the engine maps mouse events and SCREEN_UV into the 640x360 base viewport, so the
## title's clickable rects and the ScreenFX dither checker are right only while these settings hold.
## Pure: no window, no rendering. The real-GPU and browser check stays human (H-S96-4).

const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")

var _frame := Rect2(Vector2.ZERO, Vector2(Const.BASE_RES))


func test_stretch_mode_is_viewport() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")


func test_base_res_is_the_project_viewport() -> void:
	assert_eq(Const.BASE_RES, Vector2i(640, 360))
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), Const.BASE_RES.x)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), Const.BASE_RES.y)


func test_screen_fx_base_size_is_base_res() -> void:
	var fx: ScreenFX = autofree(ScreenFX.new())
	assert_eq(fx.shader_material.get_shader_parameter(&"base_size"), Vector2(Const.BASE_RES))


func test_title_label_rects_lie_inside_the_base_frame() -> void:
	var rects: Array[Rect2] = [
		TitleScreenScript.practice_label_rect(),
		TitleScreenScript.tutorial_label_rect(),
		TitleScreenScript.new_run_label_rect(),
		TitleScreenScript.new_run_label_rect(TitleScreenScript.NEW_RUN_CONFIRM_TEXT), # Story 9.3 armed row
	]
	for on: bool in [false, true]:
		rects.append(TitleScreenScript.fullscreen_label_rect(on))
		rects.append(TitleScreenScript.debug_build_label_rect(on))
	for rect: Rect2 in rects:
		assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "non-empty %s" % rect)
		assert_true(_frame.encloses(rect), "%s inside the 640x360 canvas" % rect)


func test_title_instance_rects_lie_inside_the_base_frame() -> void:
	var title: Node = autofree(TitleScreenScript.new())
	for on: bool in [false, true]:
		title.set_fullscreen_shown(on)
		for key: StringName in title.label_rects:
			assert_true(_frame.encloses(title.label_rects[key]), "%s (fullscreen %s) inside the canvas" % [key, on])
