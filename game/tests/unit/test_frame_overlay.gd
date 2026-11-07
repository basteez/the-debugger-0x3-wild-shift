extends GutTest
## Story 2.5 AC7: the F9 frame overlay text, default visibility, toggle and the debug-only node.

const S := ActionStateMachine.ActionState


func test_format_lines_sample_state() -> void:
	var lines: PackedStringArray = FrameOverlay.format_lines(1234, S.ACTIVE, 3, 0, 17, true)
	assert_eq(lines, PackedStringArray(["frame 1234", "ACTIVE 3", "cd J 0 K 17", "invuln yes"]))
	lines = FrameOverlay.format_lines(0, S.IDLE_MOVE, 0, 0, 0, false)
	assert_eq(lines[1], "IDLE_MOVE 0")
	assert_eq(lines[3], "invuln no")


func test_lines_are_ascii() -> void:
	for line: String in FrameOverlay.format_lines(9, S.RECOVERY, 12, 24, 0, false):
		for i: int in line.length():
			assert_lt(line.unicode_at(i), 128, line)


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
