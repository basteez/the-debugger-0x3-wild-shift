extends GutTest
## Story 2.4 (AC1-AC5): the pure ShiftJuice model, hit-stop independence, click files and the
## presentation-is-read-only source guard (D-S24-1, D-S24-2, D-S24-7).

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const GUARDED_SOURCES: Array[String] = [
	"res://src/presentation/shift_juice.gd",
	"res://src/presentation/juice_director.gd",
]

var _juice: ShiftJuice


func before_each() -> void:
	_juice = ShiftJuice.new()


func test_tables_have_the_specified_shape() -> void:
	assert_eq(ShiftJuice.SLIDE_FRAMES, 6)
	assert_eq(ShiftJuice.SLIDE_PX.size(), ShiftJuice.SLIDE_FRAMES)
	assert_eq(ShiftJuice.SLIDE_PX[ShiftJuice.SLIDE_FRAMES - 1], 0, "settles at rest")
	assert_eq(ShiftJuice.INVERT_FRAMES, 4)


func test_slide_follows_the_table_in_both_directions() -> void:
	for direction: int in [-1, 1]:
		_juice.on_shift(direction, 50)
		for k: int in ShiftJuice.SLIDE_FRAMES:
			assert_eq(_juice.slide_offset_px(50 + k), -direction * ShiftJuice.SLIDE_PX[k], "dir %d k %d" % [direction, k])
		for k: int in range(ShiftJuice.SLIDE_FRAMES, 12):
			assert_eq(_juice.slide_offset_px(50 + k), 0, "dir %d k %d at rest" % [direction, k])


func test_sign_flips_with_direction() -> void:
	_juice.on_shift(-1, 0)
	var left: int = _juice.slide_offset_px(0)
	_juice.on_shift(1, 0)
	assert_eq(_juice.slide_offset_px(0), -left)
	assert_ne(left, 0)


func test_overshoot_past_rest_then_settles() -> void:
	_juice.on_shift(1, 10)
	assert_lt(_juice.slide_offset_px(10), 0, ">> starts on the side of travel")
	assert_gt(_juice.slide_offset_px(13), 0, ">> overshoots past rest at k = 3")
	assert_eq(_juice.slide_offset_px(15), 0, "back at rest at k = 5")


func test_inversion_lasts_four_frames() -> void:
	_juice.on_shift(-1, 20)
	for k: int in 4:
		assert_true(_juice.is_inverted(20 + k), "k %d inverted" % k)
	for k: int in range(4, 10):
		assert_false(_juice.is_inverted(20 + k), "k %d normal" % k)


func test_no_shift_means_no_juice() -> void:
	assert_eq(_juice.slide_offset_px(0), 0)
	assert_false(_juice.is_inverted(0))
	assert_false(_juice.is_live(0))


func test_rapid_shifts_restart_on_the_latest() -> void:
	_juice.on_shift(-1, 0)
	_juice.on_shift(1, 2)
	_juice.on_shift(1, 4)
	assert_eq(_juice.direction, 1)
	assert_eq(_juice.start, 4)
	assert_eq(_juice.slide_offset_px(4), -ShiftJuice.SLIDE_PX[0])
	assert_eq(_juice.slide_offset_px(9), -ShiftJuice.SLIDE_PX[5])
	assert_eq(_juice.slide_offset_px(9), 0)
	assert_true(_juice.is_inverted(7), "inversion restarted at 4")
	assert_false(_juice.is_inverted(8))


func test_output_depends_only_on_now() -> void:
	var expected: Array[int] = []
	_juice.on_shift(1, 100)
	for t: int in [101, 102, 103]:
		expected.append(_juice.slide_offset_px(t))
	var other := ShiftJuice.new()
	other.on_shift(1, 100)
	for i: int in 3:
		assert_eq(other.slide_offset_px(101 + i), expected[i])


func test_hitstop_freezes_the_sim_but_not_the_juice() -> void:
	var clock: Node = SimClockScript.new()
	clock.request_hitstop(9)
	clock.call(&"_physics_process", 1.0 / 60.0) # the world tick that applies the request
	var frozen_at: int = clock.sim_frame
	assert_eq(clock.hitstop_frames, 9)
	# The engine counter keeps moving: the juice is queried with it while the clock is gated.
	var engine_frame: int = 1000
	_juice.on_shift(1, engine_frame)
	var seen: Array[int] = []
	var inverted: Array[bool] = []
	for k: int in ShiftJuice.SLIDE_FRAMES:
		seen.append(_juice.slide_offset_px(engine_frame + k))
		inverted.append(_juice.is_inverted(engine_frame + k))
		clock.call(&"_physics_process", 1.0 / 60.0)
	assert_eq(clock.sim_frame, frozen_at, "sim frozen during hit-stop")
	for k: int in ShiftJuice.SLIDE_FRAMES:
		assert_eq(seen[k], -ShiftJuice.SLIDE_PX[k], "slide k %d unchanged by hit-stop" % k)
		assert_eq(inverted[k], k < ShiftJuice.INVERT_FRAMES, "inversion k %d" % k)
	clock.free()


func test_click_paths_and_files() -> void:
	assert_true(ShiftJuice.click_path(-1).ends_with("shift_left.wav"))
	assert_true(ShiftJuice.click_path(1).ends_with("shift_right.wav"))
	for path: String in [ShiftJuice.click_path(-1), ShiftJuice.click_path(1)]:
		assert_true(ResourceLoader.exists(path), path)
		assert_true(load(path) is AudioStream, path)
	assert_ne(JuiceDirector.click_stream(-1), JuiceDirector.click_stream(1), "distinct clicks")
	assert_eq(JuiceDirector.click_stream(-1).resource_path, ShiftJuice.click_path(-1))
	assert_eq(JuiceDirector.click_stream(1).resource_path, ShiftJuice.click_path(1))


func test_reset_clears_slide_and_inversion() -> void:
	_juice.on_shift(-1, 5)
	_juice.reset()
	assert_eq(_juice.slide_offset_px(5), 0)
	assert_false(_juice.is_inverted(5))
	assert_false(_juice.is_live(5))


## AC5: juice code never calls a simulation writer nor names a sim singleton outside comments.
func test_juice_sources_are_read_only() -> void:
	var forbidden := RegEx.create_from_string("\\.shift\\(|set_fight_start\\(|\\.insert\\(|set_active\\(|\\.ring\\s*=[^=]|\\bSimClock\\b|\\bInputBuffer\\b|\\bPlayer\\b|request_hitstop")
	for path: String in GUARDED_SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", "cannot read %s" % path)
		for line: String in text.split("\n"):
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue
			assert_null(forbidden.search(code), "%s: %s" % [path, code])
