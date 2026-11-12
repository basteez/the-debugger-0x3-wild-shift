extends GutTest
## Story 5.4 (AC 18, 24, D-S54-2): Watch-held in the replay. Format v3 round trip (the `watch` array,
## one bool per polled frame), v1 / v2 recordings replay with Watch never held, bad entries are a
## data error, and a recording made with Watch held reproduces the same sim state.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const TMP_PATH := "user://test_replay_watch_tmp.json"
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")


## Scripted live input: presses, moves and Watch per poll index.
class ScriptedInput:
	extends InputSource
	var presses: Dictionary[int, Array] = {}
	var moves: Dictionary[int, Vector2i] = {}
	var watch: Dictionary[int, bool] = {}
	var _p: int = 0
	var _m: int = 0
	var _w: int = 0

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if presses.has(_p):
			out.assign(presses[_p])
		_p += 1
		return out

	func move_for_frame() -> Vector2i:
		var out: Vector2i = moves.get(_m, Vector2i.ZERO)
		_m += 1
		return out

	func watch_held_for_frame() -> bool:
		var out: bool = watch.get(_w, false)
		_w += 1
		return out


## A self-contained fight rig on its own clock: register, actions, player and the Watch skill.
class Rig:
	var clock: Node
	var register: Register
	var player: Player
	var actions: ActionStateMachine
	var skill: FightSkill

	func _init(seed_value: int, def: PlayerDef) -> void:
		clock = (load("res://src/autoloads/sim_clock.gd") as GDScript).new()
		clock.call(&"begin_fight", seed_value)
		var buffer: InputBuffer = clock.get(&"buffer")
		register = Register.new(buffer)
		register.set_fight_start(Register.fight_start_for_boss(1))
		register.set_active(true)
		player = Player.new(def, Arena.player_bounds())
		player.reset_for_fight(Arena.SPAWN_PX)
		player.set_active(true)
		actions = ActionStateMachine.new(buffer, player, register)
		actions.reset_for_fight()
		actions.set_active(true)
		skill = (load("res://src/skills/watch/watch_skill.gd") as GDScript).new(clock)
		skill.reset_for_fight(true)
		for s: SimSystem in [register, actions, player, skill]:
			clock.call(&"register_system", s)

	func run(frames: int) -> Array:
		var trace: Array = []
		for i: int in frames:
			clock.call(&"tick")
			trace.append([player.position_px, actions.state, actions.action_serial, skill.is_active()])
		return trace


func after_each() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _presses(names: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Variant in names:
		out.append(StringName(str(n)))
	return out


func test_recorder_writes_format_v3_with_watch() -> void:
	var rec := InputRecorder.new()
	rec.start(9)
	rec.record(_presses([]), Vector2i(1, 0), true)
	rec.record(_presses([&"action_1"]), Vector2i.ZERO, false)
	rec.record(_presses([]))
	var data: Dictionary = rec.stop()
	assert_eq(InputRecorder.FORMAT_VERSION, 3)
	assert_eq(data["version"], 3)
	assert_eq(data["watch"], [true, false, false])
	assert_eq(data["frames"], [[], ["action_1"], []], "the presses format is unchanged")


func test_v3_json_round_trip() -> void:
	var rec := InputRecorder.new()
	rec.start(77)
	rec.record(_presses([]), Vector2i.ZERO, true)
	rec.record(_presses([&"watch"]), Vector2i.ZERO, true)
	rec.record(_presses([]), Vector2i.ZERO, false)
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))
	var replay := ReplayInput.from_file(TMP_PATH)
	assert_true(replay.watch_held_for_frame())
	assert_true(replay.watch_held_for_frame())
	assert_false(replay.watch_held_for_frame())
	assert_false(replay.watch_held_for_frame(), "false once exhausted")


func test_v2_recording_replays_with_watch_never_held() -> void:
	var replay := ReplayInput.from_data({"version": 2, "seed": 1, "frames": [[], ["action_1"]], "moves": [[1, 0], [0, 0]]})
	assert_eq(replay.frame_count(), 2)
	for i: int in 3:
		assert_false(replay.watch_held_for_frame())
	assert_push_error_count(0)


func test_v1_recording_replays_with_watch_never_held() -> void:
	var replay := ReplayInput.from_data({"version": 1, "seed": 1, "frames": [["action_1"]]})
	assert_false(replay.watch_held_for_frame())
	assert_eq(replay.move_for_frame(), Vector2i.ZERO)


func test_bad_watch_data_is_a_data_error_not_a_crash() -> void:
	var replay := ReplayInput.from_data({"version": 3, "seed": 1, "frames": [[]], "watch": "yes"})
	assert_false(replay.watch_held_for_frame())
	assert_push_error("watch is not an array")
	var replay2 := ReplayInput.from_data({"version": 3, "seed": 1, "frames": [[], []], "watch": [1, true]})
	assert_false(replay2.watch_held_for_frame(), "a non-bool entry replays as not held")
	assert_true(replay2.watch_held_for_frame())
	assert_push_error("bad watch entries")


func test_sim_clock_records_watch_input_every_polled_frame() -> void:
	var clock: Node = SimClockScript.new()
	var src := ScriptedInput.new()
	src.watch = {1: true, 2: true}
	clock.set(&"input_source", src)
	var rec := InputRecorder.new()
	rec.start(3)
	clock.set(&"recorder", rec)
	clock.set(&"hitstop_frames", 1) # a hit-stop poll is still recorded
	for i: int in 4:
		clock.call(&"tick")
	assert_eq(rec.stop()["watch"], [false, true, true, false])
	clock.free()


func test_recording_with_watch_held_reproduces() -> void:
	var live := Rig.new(5454, PLAYER_DEF)
	var src := ScriptedInput.new()
	for i: int in range(0, 40):
		src.moves[i] = Vector2i(1, 0)
	for i: int in range(10, 30):
		src.watch[i] = true
	src.presses[12] = [&"action_1"] # discarded under Watch
	src.presses[35] = [&"action_1"] # starts after release
	live.clock.set(&"input_source", src)
	var rec := InputRecorder.new()
	rec.start(5454)
	live.clock.set(&"recorder", rec)
	var live_trace: Array = live.run(60)
	var data: Dictionary = JSON.parse_string(InputRecorder.to_json(rec.stop()))
	var replay := ReplayInput.from_data(data)
	var again := Rig.new(replay.seed_value, PLAYER_DEF)
	again.clock.set(&"input_source", replay)
	var replay_trace: Array = again.run(60)
	assert_eq(replay_trace, live_trace, "same sim state on every tick")
	assert_true(live_trace[15][3], "Watch was held in the recording")
	# Without the watch array the same presses diverge (Watch changes the sim, D-S54-2).
	data.erase("watch")
	var no_watch := Rig.new(5454, PLAYER_DEF)
	no_watch.clock.set(&"input_source", ReplayInput.from_data(data))
	assert_ne(no_watch.run(60), live_trace)
	for rig: Rig in [live, again, no_watch]:
		rig.clock.free()
