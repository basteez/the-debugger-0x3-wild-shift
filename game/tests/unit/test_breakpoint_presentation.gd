extends GutTest
## Story 4.3 (AC 9-11, D-S43-9, D-S43-13, D-S43-14): JuiceDirector dither on the Breakpoint events,
## the AudioManager placeholder, the HUD `brk` readout, the overlay geometry and the ScreenFX red
## exemption (CPU mirror ScreenFxRule plus the shader source).


## A FightSkill stand-in the views read.
class FakeSkill:
	extends FightSkill
	var on: bool = false
	var open: bool = true
	var left: int = 0

	func is_active() -> bool:
		return on

	func is_unlocked() -> bool:
		return open

	func cooldown_left_frames() -> int:
		return left


# --- AC 9: juice and audio ---

func test_juice_dithers_half_on_started_and_clears_on_ended() -> void:
	var director := JuiceDirector.new()
	var fx := ScreenFX.new()
	director.screen_fx = fx
	add_child_autofree(fx)
	add_child_autofree(director)
	assert_eq(JuiceDirector.BREAKPOINT_DITHER, 0.5)
	EventBus.breakpoint_started.emit()
	assert_eq(director.dither_level(), 0.5)
	assert_eq(fx.dither_level(), 0.5)
	assert_true(fx.visible)
	EventBus.breakpoint_ended.emit()
	assert_eq(director.dither_level(), 0.0)
	assert_false(fx.visible)
	EventBus.breakpoint_started.emit()
	director.reset()
	assert_eq(director.dither_level(), 0.0, "fight entry reset clears it")


func test_audio_manager_placeholder_counts_events_only() -> void:
	var before: int = AudioManager.breakpoint_music_events
	EventBus.breakpoint_started.emit()
	EventBus.breakpoint_ended.emit()
	assert_eq(AudioManager.breakpoint_music_events, before + 2)
	assert_true(EventBus.breakpoint_started.is_connected(AudioManager.on_breakpoint_started))
	assert_true(EventBus.breakpoint_ended.is_connected(AudioManager.on_breakpoint_ended))


# --- AC 10: HUD readout ---

func test_readout_text() -> void:
	assert_eq(BreakpointReadout.text_for(0), "brk READY")
	assert_eq(BreakpointReadout.text_for(720), "brk 12s")
	assert_eq(BreakpointReadout.text_for(661), "brk 12s", "ceil")
	assert_eq(BreakpointReadout.text_for(660), "brk 11s")
	assert_eq(BreakpointReadout.text_for(1), "brk 1s")


func test_readout_hidden_without_skill_or_when_locked() -> void:
	var readout := BreakpointReadout.new()
	assert_eq(readout.current_text(), "", "no skill (flag off): nothing")
	var skill := FakeSkill.new()
	readout.skill = skill
	skill.open = false
	assert_eq(readout.current_text(), "", "locked fight: nothing")
	skill.open = true
	skill.left = 125
	assert_eq(readout.current_text(), "brk 3s")
	readout.free()


func test_readout_fits_the_register_box() -> void:
	var cell := Vector2i(BreakpointReadout.COL, BreakpointReadout.ROW)
	assert_eq(Hud.region_of(cell), &"register")
	assert_eq(Hud.region_of(cell + Vector2i(BreakpointReadout.text_for(0).length() - 1, 0)), &"register")
	assert_gt(BreakpointReadout.ROW, RegisterPanel.PREVIEW_RIGHT_NAME_ROW + RegisterPanel.NAME_ROWS - 1, "below the register content")


# --- AC 9: overlay ---

func test_overlay_draws_only_while_active() -> void:
	var overlay := BreakpointOverlay.new()
	assert_eq(overlay.current_row(), -1)
	var skill := FakeSkill.new()
	overlay.skill = skill
	assert_eq(overlay.current_row(), -1)
	skill.on = true
	assert_eq(overlay.current_row(), 0, "no player: row 0")
	overlay.free()


func test_overlay_row_geometry() -> void:
	assert_eq(BreakpointOverlay.row_for(8.0), 0)
	assert_eq(BreakpointOverlay.row_for(40.0), 2)
	assert_eq(BreakpointOverlay.row_for(9999.0), Const.ARENA_TILES.y - 1)
	assert_eq(BreakpointOverlay.dot_y_for(2), 40.0)
	assert_lt(BreakpointOverlay.DOT_X_PX, 0.0, "the dot sits in the gutter left of the arena")
	assert_eq(Hud.region_of(Vector2i(int((BreakpointOverlay.DOT_X_PX + 128.0) / 8.0), 3)), &"gap")


func test_overlay_uses_warn_red() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/skills/breakpoint/breakpoint_overlay.gd")
	assert_string_contains(text, "Palette.WARN")
	assert_eq(Palette.WARN, Color("#FF4040"))


# --- AC 11: ScreenFX red exemption ---

func test_warn_passes_dither_and_invert_unchanged() -> void:
	for p: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 5)]:
		for inv: bool in [false, true]:
			assert_eq(ScreenFxRule.shade(Palette.WARN, p, inv, 0.5), Palette.WARN)


func test_other_colours_keep_the_2_8_rules() -> void:
	assert_eq(ScreenFxRule.shade(Palette.INK, Vector2i(0, 0), false, 0.5), Palette.BG, "even checker -> BG")
	assert_eq(ScreenFxRule.shade(Palette.INK, Vector2i(1, 0), false, 0.5), Palette.INK)
	assert_eq(ScreenFxRule.shade(Palette.INK, Vector2i(1, 0), true, 0.0), Palette.BG, "invert swaps")
	assert_eq(ScreenFxRule.shade(Palette.BG, Vector2i(1, 0), true, 0.0), Palette.INK)
	assert_eq(ScreenFxRule.shade(Color(1.0, 0.3, 0.3), Vector2i(1, 0), true, 0.0), Palette.BG, "near-red is not exempt (bright: inverts to BG)")
	assert_true(ScreenFxRule.is_warn(Color8(255, 64, 64)))
	assert_false(ScreenFxRule.is_warn(Color8(255, 65, 64)))


func test_shader_has_the_exemption_with_warn_default() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/presentation/screen_fx.gdshader")
	assert_string_contains(text, "uniform vec4 warn_colour = vec4(1.0, 0.25098, 0.25098, 1.0);")
	assert_almost_eq(Palette.WARN.g, 0.25098, 0.00001)
	assert_string_contains(text, "WARN_EPSILON")
	assert_lt(text.find("warn_colour.rgb"), text.find("if (invert)"), "exemption checked before invert")
