extends GutTest
## Story 2.1 AC6: a recorded session and its replay, run on two fresh SimClocks with the same seed,
## end with the same sim_frame and the same test-state hash, bit for bit (D-S21-10: test-only state).

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const TMP_PATH := "user://test_replay_tmp.json"
const SEED := 20261107
const FRAMES := 600


## Test-only state: folds consumed presses and RNG draws into an int hash; requests hit-stop on
## action_2 so the gates are part of the replayed path.
class HashSystem:
	extends SimSystem
	var clock: Node
	var hash_value: int = 17

	func _init(p_clock: Node) -> void:
		phase = SimSystem.SimPhase.ACTIONS
		clock = p_clock

	func tick(ctx: SimContext) -> void:
		var frame: int = clock.get(&"sim_frame")
		var buffer: InputBuffer = clock.get(&"buffer")
		var i: int = 0
		for action: StringName in LiveInput.BUFFERED_ACTIONS:
			i += 1
			if buffer.consume(action, frame):
				hash_value = (hash_value * 31 + i * 1009 + frame) & 0x7FFFFFFF
				if action == &"action_2":
					clock.call(&"request_hitstop", 3 + ctx.rng.randi_range(0, 4))
		hash_value = (hash_value * 31 + int(ctx.rng.randi() & 0xFFFF)) & 0x7FFFFFFF


## Scripted "player": a fixed pattern of presses, independent of the clock.
class ScriptedInput:
	extends InputSource
	var polls: int = 0

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if polls % 7 == 0:
			out.append(&"action_1")
		if polls % 11 == 3:
			out.append(&"shift_left")
		if polls % 23 == 5:
			out.append(&"action_2")
		if polls % 13 == 9:
			out.append(&"shift_right")
		polls += 1
		return out


func after_each() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _run(clock: SimClockScript, source: InputSource, polls: int) -> HashSystem:
	clock.input_source = source
	var system := HashSystem.new(clock)
	clock.register_system(system)
	for i: int in polls:
		clock.tick()
	return system


func test_recorded_session_replays_bit_identically() -> void:
	# Recording run.
	var live: SimClockScript = SimClockScript.new()
	live.begin_fight(SEED)
	var rec := InputRecorder.new()
	rec.start(SEED)
	live.recorder = rec
	var live_state: HashSystem = _run(live, ScriptedInput.new(), FRAMES)
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))

	# Replay run on a fresh clock.
	var replay := ReplayInput.from_file(TMP_PATH)
	assert_eq(replay.frame_count(), FRAMES)
	var again: SimClockScript = SimClockScript.new()
	again.begin_fight(replay.seed_value)
	var replay_state: HashSystem = _run(again, replay, FRAMES)

	assert_gt(live.sim_frame, 0)
	assert_lt(live.sim_frame, FRAMES, "hit-stop happened, so the gates were exercised")
	assert_eq(again.sim_frame, live.sim_frame)
	assert_eq(replay_state.hash_value, live_state.hash_value)
	live.free()
	again.free()


func test_different_seed_diverges() -> void:
	var a: SimClockScript = SimClockScript.new()
	a.begin_fight(1)
	var sa: HashSystem = _run(a, ScriptedInput.new(), 120)
	var b: SimClockScript = SimClockScript.new()
	b.begin_fight(2)
	var sb: HashSystem = _run(b, ScriptedInput.new(), 120)
	assert_ne(sa.hash_value, sb.hash_value, "the hash depends on the seeded RNG")
	a.free()
	b.free()
