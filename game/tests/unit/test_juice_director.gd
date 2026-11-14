extends GutTest
## Story 2.4 (AC1, AC3, AC5): JuiceDirector wiring with a real RegisterPanel and PlayerView.

var _director: JuiceDirector
var _panel: RegisterPanel
var _view: PlayerView
var _fx: ScreenFX


func before_each() -> void:
	_panel = RegisterPanel.new()
	_view = PlayerView.new()
	add_child(_panel)
	add_child(_view)
	_director = JuiceDirector.new()
	_director.register_panel = _panel
	_director.player_view = _view
	_fx = ScreenFX.new()
	add_child(_fx)
	_director.screen_fx = _fx
	add_child(_director)


func after_each() -> void:
	_director.queue_free()
	_panel.queue_free()
	_view.queue_free()
	_fx.queue_free()
	SimClock.hitstop_frames = 0
	await get_tree().process_frame


func _emit(direction: int) -> void:
	EventBus.register_shifted.emit(direction, Vector2i(1, 0), PackedInt32Array([1, 0]), &"player")


# Story 7.2 (AC 8, FR28): the click is requested in the same call as the shift, with the stream of
# the direction (no call_deferred, no timer).
func test_shift_requests_the_direction_click_in_the_same_call() -> void:
	var played: Array[AudioStream] = []
	_director.play_click = func(stream: AudioStream) -> void: played.append(stream)
	_emit(-1)
	assert_eq(played, [JuiceDirector.CLICK_LEFT] as Array[AudioStream], "<< on the input frame")
	_emit(1)
	assert_eq(played, [JuiceDirector.CLICK_LEFT, JuiceDirector.CLICK_RIGHT] as Array[AudioStream], ">> too")
	assert_ne(JuiceDirector.CLICK_LEFT, JuiceDirector.CLICK_RIGHT)


func test_connects_once() -> void:
	assert_true(EventBus.register_shifted.is_connected(_director._on_register_shifted))


func test_shift_slides_the_panel_and_inverts_the_glyph() -> void:
	_emit(-1)
	assert_eq(_panel.slide_px, -(-1) * ShiftJuice.SLIDE_PX[0], "<< slide starts on frame 0")
	assert_eq(_panel.content.position.x, float(_panel.slide_px), "content follows the slide")
	assert_true(_view.inverted)
	_emit(1)
	assert_eq(_panel.slide_px, -ShiftJuice.SLIDE_PX[0], ">> restarts toward the latest state")
	assert_true(_view.inverted)


func test_reset_clears_both() -> void:
	_emit(1)
	_director.reset()
	assert_eq(_panel.slide_px, 0)
	assert_eq(_panel.content.position, Vector2.ZERO)
	assert_false(_view.inverted)


func test_settles_after_the_slide() -> void:
	_emit(1)
	await wait_physics_frames(ShiftJuice.SLIDE_FRAMES + 2)
	await get_tree().process_frame
	assert_eq(_panel.slide_px, 0, "back at rest")
	assert_false(_view.inverted)


func test_exit_tree_disconnects() -> void:
	remove_child(_director)
	assert_false(EventBus.register_shifted.is_connected(_director._on_register_shifted))
	add_child(_director)
	assert_true(EventBus.register_shifted.is_connected(_director._on_register_shifted))


func test_panel_at_rest_is_unchanged() -> void:
	var panel := RegisterPanel.new()
	assert_eq(panel.slide_px, 0)
	assert_eq(panel.clip_children, CanvasItem.CLIP_CHILDREN_ONLY)
	assert_eq(panel.content.position, Vector2.ZERO)
	assert_eq(RegisterPanel.CLIP_RECT, Rect2(8, 24, 80, 144))
	panel.free()


## Review: at rest every plan() cell lies inside the clip mask, so clipping changes nothing (D-S24-3).
func test_every_plan_cell_lies_inside_the_clip_rect() -> void:
	for bits: int in [2, 3, 4, 8]:
		var ring := PackedInt32Array()
		for i in bits:
			ring.append(i)
		for c: RegisterPanel.Cell in RegisterPanel.plan(ring):
			var rect := Rect2(GlyphFont.cell_to_px(c.cell, RegisterPanel.SCALE), Vector2(c.text.length(), 1) * GlyphFont.CELL)
			assert_true(RegisterPanel.CLIP_RECT.encloses(rect), "cell '%s' at %s inside the mask" % [c.text, c.cell])


func test_direction_is_normalised_to_its_sign() -> void:
	var j := ShiftJuice.new()
	j.on_shift(3, 10)
	assert_eq(j.direction, 1)
	j.on_shift(-7, 20)
	assert_eq(j.direction, -1)


# --- Story 2.8: ScreenFX inversion and dither (AC5), hit-stop independence (AC8) ---

func test_request_invert_inverts_the_screen_for_one_frame() -> void:
	assert_false(_fx.visible, "no effect, no screen copy")
	_director.request_invert()
	var t: int = _director.now()
	assert_true(_fx.is_inverted())
	assert_true(_fx.visible)
	assert_true(_director.is_screen_inverted(t))
	assert_false(_director.is_screen_inverted(t + 1), "1 frame by default")
	await wait_physics_frames(2)
	await get_tree().process_frame
	assert_false(_fx.is_inverted(), "inversion is over")
	assert_false(_fx.visible)


func test_request_invert_for_n_frames_and_ignores_zero() -> void:
	_director.request_invert(0)
	assert_false(_fx.is_inverted())
	_director.request_invert(3)
	var t: int = _director.now()
	assert_true(_director.is_screen_inverted(t + 2))
	assert_false(_director.is_screen_inverted(t + 3))


func test_low_dither_keeps_the_screen_fx_hidden() -> void:
	_director.set_dither(0.3)
	assert_false(_fx.visible, "below 0.5 the shader draws nothing, so skip the screen copy")
	_director.set_dither(0.5)
	assert_true(_fx.visible)


func test_set_dither_clamps_and_writes_the_uniform() -> void:
	_director.set_dither(0.5)
	assert_eq(_fx.dither_level(), 0.5)
	assert_true(_fx.visible)
	_director.set_dither(3.0)
	assert_eq(_director.dither_level(), 1.0)
	assert_eq(_fx.dither_level(), 1.0)
	_director.set_dither(-1.0)
	assert_eq(_fx.dither_level(), 0.0)
	assert_false(_fx.visible)


func test_reset_clears_screen_effects() -> void:
	_director.request_invert(10)
	_director.set_dither(1.0)
	_director.reset()
	assert_false(_fx.is_inverted())
	assert_eq(_fx.dither_level(), 0.0)


func test_null_screen_fx_is_safe() -> void:
	_director.screen_fx = null
	_director.request_invert()
	_director.set_dither(1.0)
	assert_eq(_director.dither_level(), 1.0)


func test_slide_advances_while_the_world_is_in_hitstop() -> void:
	# 2.4 H4 automated part (AC8): the slide runs on physics frames, not on the sim clock.
	var was_paused: bool = SimClock.paused
	SimClock.paused = false
	SimClock.hitstop_frames = 100
	var frozen_at: int = SimClock.sim_frame
	_emit(1)
	var first: int = _panel.slide_px
	await wait_physics_frames(2)
	await get_tree().process_frame
	assert_gt(SimClock.hitstop_frames, 0, "still in hit-stop")
	assert_eq(SimClock.sim_frame, frozen_at, "the world stayed frozen")
	assert_ne(_panel.slide_px, first, "the slide advanced during hit-stop")
	SimClock.paused = was_paused


# Story 3.2 (AC 4, D-S32-18): a Patched hit inverts the screen for 1 frame; others do not.
func test_patched_hit_inverts_the_screen_for_one_frame() -> void:
	var t: int = _director.now()
	EventBus.hit_landed.emit(&"boss", 5, DamageState.Kind.UNPATCHED, false, Vector2.ZERO)
	EventBus.hit_landed.emit(&"practice_target", 10, DamageState.Kind.BASE, false, Vector2.ZERO)
	assert_false(_director.is_screen_inverted(t))
	EventBus.hit_landed.emit(&"boss", 15, DamageState.Kind.PATCHED, false, Vector2.ZERO)
	assert_true(_director.is_screen_inverted(t))
	assert_false(_director.is_screen_inverted(t + 1), "one frame only")
