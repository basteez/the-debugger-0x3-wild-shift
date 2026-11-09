extends GutTest
## Story 2.5 AC7 / 2.6 AC8: the F9 frame overlay text (with the combo link lines), default visibility, toggle and the debug-only node.

const S := ActionStateMachine.ActionState
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH


func test_format_lines_sample_state() -> void:
	var lines: PackedStringArray = FrameOverlay.format_lines(1234, S.ACTIVE, 3, 0, 17, true, true, Vector2i(A, D), 12, true)
	assert_eq(lines, PackedStringArray(["frame 1234", "ACTIVE 3", "cd J 0 K 17", "invuln yes", "link open", "pair A D", "left 12", "held K"]))
	lines = FrameOverlay.format_lines(0, S.IDLE_MOVE, 0, 0, 0, false, false, Vector2i(A, D), 5, false)
	assert_eq(lines[1], "IDLE_MOVE 0")
	assert_eq(lines[3], "invuln no")
	assert_eq(lines.slice(4), PackedStringArray(["link closed", "pair - -", "left 0", "held -"]))


func test_lines_are_ascii() -> void:
	for open: bool in [true, false]:
		for line: String in FrameOverlay.format_lines(9, S.RECOVERY, 12, 24, 0, false, open, Vector2i(D, A), 18, open):
			for i: int in line.length():
				assert_lt(line.unicode_at(i), 128, line)


## The overlay reads the FSM's live link (AC8).
func test_overlay_reads_the_fsm_link() -> void:
	var fsm := ActionStateMachine.new()
	fsm.link.open(Vector2i(A, D), 0)
	fsm.link.start_count()
	fsm.link.hold(&"action_2", 1, 3)
	var lines: PackedStringArray = FrameOverlay.format_lines(0, fsm.state, 0, 0, 0, false, fsm.link.is_open(), fsm.link.pair, fsm.link.frames_left, fsm.link.held)
	assert_eq(lines.slice(4), PackedStringArray(["link open", "pair A D", "left 18", "held K"]))


func test_hidden_by_default_and_toggles() -> void:
	var overlay: FrameOverlay = autofree(FrameOverlay.new())
	assert_false(overlay.visible)
	overlay.toggle()
	assert_true(overlay.visible)
	overlay.toggle()
	assert_false(overlay.visible)


func test_main_adds_overlay_only_when_debug_enabled() -> void:
	var saved: bool = Debug.enabled
	Debug.enabled = true
	var main_on: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_on)
	var overlay: FrameOverlay = main_on.get_node_or_null(^"Arena/FrameOverlay")
	assert_not_null(overlay)
	if overlay != null:
		assert_false(overlay.visible)
		assert_eq(overlay.actions, main_on.arena.actions)
		assert_eq(overlay.player, main_on.arena.player)
		assert_eq(main_on.get_node(^"DebugKeys").frame_overlay, overlay)
	Debug.enabled = false
	var main_off: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_off)
	Debug.enabled = saved
	assert_null(main_off.get_node_or_null(^"Arena/FrameOverlay"))


## The opaque box covers every line, stays in the play area and clears the F10 box.
func test_text_box_covers_lines_and_clears_perf_box() -> void:
	var count: int = FrameOverlay.format_lines(0, S.IDLE_MOVE, 0, 0, 0, false, false, Vector2i(A, D), 0, false).size()
	var box: Rect2 = FrameOverlay.text_box(count)
	assert_true(Arena.play_area().encloses(box))
	var widest: int = 0
	for line: String in FrameOverlay.format_lines(9999999, S.RECOVERY, 999, 99, 99, true, true, Vector2i(D, A), 18, true):
		widest = maxi(widest, line.length())
	assert_gte(box.size.x, widest * GlyphFont.CELL + 2.0)
	assert_gte(box.size.y, (count - 1) * FrameOverlay.LINE_STEP + GlyphFont.CELL + 2.0)
	var perf := Rect2(PerfOverlay.box_top_left(4), PerfOverlay.box_size(4))
	assert_false(box.intersects(perf))
	assert_eq(int(box.position.x) % 4, 0)


func test_overlay_draws_above_particles() -> void:
	var overlay: FrameOverlay = autofree(FrameOverlay.new())
	assert_gt(overlay.z_index, 0)
