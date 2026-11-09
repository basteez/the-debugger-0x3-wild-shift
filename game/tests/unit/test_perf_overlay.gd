extends GutTest
## Story 2.8 AC6, D-S28-7: the F10 perf overlay lines and release gate.

const GameScript := preload("res://src/autoloads/game.gd")

var _saved_enabled: bool


func before_each() -> void:
	_saved_enabled = Debug.enabled


func after_each() -> void:
	Debug.enabled = _saved_enabled


func test_lines_format() -> void:
	assert_eq(PerfOverlay.lines(59.6, 16.66, 42, 37), PackedStringArray(["fps 60", "frame 16.7 ms", "particles 42/300", "draw calls 37"]))


func test_missing_draw_calls_show_a_dash() -> void:
	assert_eq(PerfOverlay.lines(60.0, 1.0, 0, 0)[3], "draw calls -")
	assert_eq(PerfOverlay.lines(60.0, 1.0, 0, -1)[3], "draw calls -")


func test_lines_are_ascii_and_fit_the_box() -> void:
	for line: String in PerfOverlay.lines(999.0, 999.9, 300, 99999):
		assert_lte(line.length(), PerfOverlay.BOX_CHARS, line)
		for i: int in line.length():
			assert_lt(line.unicode_at(i), 128, line)


func test_box_is_inside_the_play_area() -> void:
	var tl: Vector2 = PerfOverlay.box_top_left(4)
	var box := Rect2(tl, PerfOverlay.box_size(4))
	assert_true(Arena.play_area().encloses(box))


func test_toggle_and_refresh_reads_the_pool() -> void:
	var overlay: PerfOverlay = PerfOverlay.new()
	var pool: ParticlePool = ParticlePool.new()
	add_child_autofree(pool)
	add_child_autofree(overlay)
	overlay.particle_pool = pool
	assert_false(overlay.visible, "hidden by default")
	pool.spawn(Vector2.ZERO, 7)
	overlay.toggle()
	assert_true(overlay.visible)
	assert_eq(overlay.shown_lines()[2], "particles 7/300")
	overlay.toggle()
	assert_false(overlay.visible)


func test_main_adds_the_overlay_only_under_the_debug_gate() -> void:
	Debug.enabled = true
	var main_on: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_on)
	assert_not_null(main_on.perf_overlay)
	assert_eq(main_on.perf_overlay.particle_pool, main_on.particle_pool)
	assert_eq((main_on.get_node(^"DebugKeys") as DebugKeys).perf_overlay, main_on.perf_overlay)
	Debug.enabled = false
	var main_off: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_off)
	assert_null(main_off.perf_overlay)
	assert_null(main_off.get_node_or_null(^"DebugKeys"))
