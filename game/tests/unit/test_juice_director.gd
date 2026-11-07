extends GutTest
## Story 2.4 (AC1, AC3, AC5): JuiceDirector wiring with a real RegisterPanel and PlayerView.

var _director: JuiceDirector
var _panel: RegisterPanel
var _view: PlayerView


func before_each() -> void:
	_panel = RegisterPanel.new()
	_view = PlayerView.new()
	add_child(_panel)
	add_child(_view)
	_director = JuiceDirector.new()
	_director.register_panel = _panel
	_director.player_view = _view
	add_child(_director)


func after_each() -> void:
	_director.queue_free()
	_panel.queue_free()
	_view.queue_free()
	await get_tree().process_frame


func _emit(direction: int) -> void:
	EventBus.register_shifted.emit(direction, Vector2i(1, 0), PackedInt32Array([1, 0]), &"player")


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
