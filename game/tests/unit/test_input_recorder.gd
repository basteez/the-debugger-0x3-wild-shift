extends GutTest
## Story 2.1 AC5: recorder format, JSON round trip, ReplayInput parsing and the release gate.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const DebugKeysScript := preload("res://src/debug/debug_keys.gd")
const TMP_PATH := "user://test_input_recorder_tmp.json"


func after_each() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _presses(names: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Variant in names:
		out.append(StringName(str(n)))
	return out


func test_stop_returns_version_seed_frames() -> void:
	var rec := InputRecorder.new()
	rec.start(77)
	rec.record(_presses([&"action_1"]))
	rec.record(_presses([]), Vector2i(-1, 1))
	var data: Dictionary = rec.stop()
	assert_eq(data["version"], 3)
	assert_eq(data["seed"], 77)
	assert_eq(data["frames"], [["action_1"], []])
	assert_eq(data["moves"], [[0, 0], [-1, 1]], "default move is zero")
	assert_false(rec.is_recording())


func test_record_ignored_when_not_started() -> void:
	var rec := InputRecorder.new()
	rec.record(_presses([&"action_1"]))
	rec.start(1)
	assert_eq(rec.stop()["frames"], [])


func test_json_round_trip_through_replay_input() -> void:
	var rec := InputRecorder.new()
	rec.start(123456789)
	rec.record(_presses([&"shift_left", &"action_2"]), Vector2i(1, 0))
	rec.record(_presses([]), Vector2i(-1, -1))
	rec.record(_presses([&"watch"]))
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP_PATH))
	assert_eq(int(parsed["version"]), 3)
	assert_eq((parsed["moves"] as Array).size(), 3)
	var replay := ReplayInput.from_file(TMP_PATH)
	assert_eq(replay.move_for_frame(), Vector2i(1, 0))
	assert_eq(replay.move_for_frame(), Vector2i(-1, -1))
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)
	assert_eq(replay.move_for_frame(), Vector2i.ZERO, "zero once exhausted")
	assert_eq(replay.seed_value, 123456789)
	assert_eq(replay.frame_count(), 3)
	assert_eq(replay.presses_for_frame(), _presses([&"shift_left", &"action_2"]))
	assert_eq(replay.presses_for_frame(), _presses([]))
	assert_eq(replay.presses_for_frame(), _presses([&"watch"]))
	assert_eq(replay.presses_for_frame(), _presses([]), "empty once exhausted")


func test_to_json_is_one_line() -> void:
	var json: String = InputRecorder.to_json({"version": 1, "seed": 3, "frames": [["action_1"]]})
	assert_false(json.contains("\n"))
	assert_eq(JSON.parse_string(json)["frames"], [["action_1"]])


func test_replay_from_missing_file_is_empty() -> void:
	var replay := ReplayInput.from_file("user://does_not_exist_2_1.json")
	assert_eq(replay.frame_count(), 0)
	assert_eq(replay.presses_for_frame(), _presses([]))
	assert_push_error("cannot open")


func test_replay_from_bad_json_is_empty() -> void:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(ReplayInput.from_file(TMP_PATH).frame_count(), 0)
	assert_push_error("bad JSON")


func test_replay_from_data_without_frames_is_empty() -> void:
	assert_eq(ReplayInput.from_data({"seed": 1}).frame_count(), 0)
	assert_eq(ReplayInput.from_data([1, 2]).frame_count(), 0)
	assert_push_error_count(2)


func test_release_gate_creates_no_recorder() -> void:
	assert_null(InputRecorder.create(false))
	assert_not_null(InputRecorder.create(true))


func test_start_recording_refused_when_debug_off() -> void:
	var clock: SimClockScript = SimClockScript.new()
	assert_false(DebugKeysScript.start_recording(clock, false, 1))
	assert_null(clock.recorder)
	clock.free()


func test_start_and_stop_recording_on_a_clock() -> void:
	var clock: SimClockScript = SimClockScript.new()
	assert_true(DebugKeysScript.start_recording(clock, true, 42))
	assert_not_null(clock.recorder)
	clock.tick()
	clock.tick()
	var data: Dictionary = DebugKeysScript.stop_recording(clock)
	assert_null(clock.recorder)
	assert_eq(data["seed"], 42)
	assert_eq((data["frames"] as Array).size(), 2)
	assert_eq(DebugKeysScript.stop_recording(clock), {})
	clock.free()


func test_replay_path_format() -> void:
	assert_eq(DebugKeysScript.replay_path(1700000000), "user://replay_1700000000.json")


func test_f11_is_the_record_key_not_a_jump() -> void:
	assert_eq(DebugKeysScript.RECORD_KEY, KEY_F11)
	assert_true(DebugKeysScript.target_for_key(KEY_F11).is_empty())


func test_v1_recording_replays_with_zero_moves() -> void:
	var replay := ReplayInput.from_data({"version": 1, "seed": 4, "frames": [["action_1"], []]})
	assert_eq(replay.frame_count(), 2)
	assert_eq(replay.presses_for_frame(), _presses([&"action_1"]))
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)


func test_bad_move_entries_are_zero_and_logged() -> void:
	var replay := ReplayInput.from_data({"seed": 1, "frames": [[], [], [], []],
		"moves": [[1, 0], "x", [2, 0], [0.5, 0]]})
	assert_eq(replay.move_for_frame(), Vector2i(1, 0))
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)
	assert_push_error("bad move entries")


func test_moves_not_an_array_is_logged() -> void:
	var replay := ReplayInput.from_data({"seed": 1, "frames": [[]], "moves": 3})
	assert_eq(replay.frame_count(), 1)
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)
	assert_push_error("moves is not an array")
