extends GutTest
## Story 4.3 (AC 14, F1): a scripted Fight 2 in a real Arena with the Breakpoint module on and the
## framework test boss: Space starts Breakpoint, Q/E shift during the freeze, J ends it (the slash
## runs on the first unfrozen tick), a second Space is refused by the cooldown. Recorded with
## InputRecorder, replayed from the saved file on a fresh Arena with the clock re-seeded; both runs
## end on the same world-tick count and the same per-tick hash of the integer state (skill, ring,
## FSM, boss, RNG). Floats are never hashed (2.2 deferred item).

const GameScript := preload("res://src/autoloads/game.gd")
const TMP_PATH := "user://test_breakpoint_replay_tmp.json"
const SEED := 43043
const FRAMES := 900
const START_AT := 10
const SHIFTS_AT: Array[int] = [15, 20, 25]
const END_AT := 40
const REFUSED_AT := 100


## The scripted player: the Breakpoint choreography, then a fixed walk with more presses.
class BreakpointScript:
	extends InputSource
	var polls: int = 0
	var move_polls: int = 0

	func move_for_frame() -> Vector2i:
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i.ZERO, Vector2i(-1, -1), Vector2i(-1, 0)]
		@warning_ignore("integer_division")
		var out: Vector2i = dirs[(move_polls / 43) % dirs.size()]
		move_polls += 1
		return out

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if polls == START_AT or polls == REFUSED_AT:
			out.append(&"breakpoint")
		if polls == SHIFTS_AT[0] or polls == SHIFTS_AT[2]:
			out.append(&"shift_left")
		if polls == SHIFTS_AT[1]:
			out.append(&"shift_right")
		if polls == END_AT:
			out.append(&"action_1")
		if polls > REFUSED_AT:
			if polls % 29 == 0:
				out.append(&"action_1")
			if polls % 37 == 5:
				out.append(&"shift_right")
			if polls % 41 == 9:
				out.append(&"action_2")
		polls += 1
		return out


var _saved_source: InputSource
var _saved_state: int


func before_each() -> void:
	_saved_source = SimClock.input_source
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal hit never records a death
	SimClock.paused = false


func after_each() -> void:
	SimClock.input_source = _saved_source
	SimClock.recorder = null
	SimClock.breakpoint_gate_active = false
	SimClock.begin_fight(0)
	Game.flow_state = _saved_state as GameScript.FlowState
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _hash(h: int, arena: Arena) -> int:
	var skill: FightSkill = arena.breakpoint_skill
	var parts: Array[int] = [
		1 if skill.is_active() else 0, skill.cooldown_left_frames(), skill.get(&"frozen_polls"),
		arena.register.shift_serial, arena.actions.action_serial, int(arena.actions.state),
		arena.health.hp, SimClock.hitstop_frames,
	]
	for bit: int in arena.register.ring:
		parts.append(bit)
	if arena.boss != null:
		parts.append_array([arena.boss.hp, int(arena.boss.state), arena.boss.frames_left])
	parts.append(int(SimClock.ctx.rng.state & 0x7FFFFFFF))
	for v: int in parts:
		h = (h * 31 + v) & 0x7FFFFFFFFFFF
	return h


func _session(source: InputSource, seed_value: int) -> Dictionary:
	var arena := Arena.new()
	arena.set_breakpoint_enabled(true)
	add_child(arena)
	SimClock.begin_fight(seed_value)
	SimClock.input_source = source
	arena.enter_fight(Register.fight_start_for_boss(1), false, Arena.TEST_BOSS_DEF_PATH, true)
	var counts: Dictionary[StringName, int] = {&"started": 0, &"ended": 0, &"frozen_shifts": 0}
	var on_start: Callable = func() -> void: counts[&"started"] += 1
	var on_end: Callable = func() -> void: counts[&"ended"] += 1
	var on_shift: Callable = func(_d: int, _w: Vector2i, _r: PackedInt32Array, _s: StringName) -> void:
		if SimClock.breakpoint_gate_active:
			counts[&"frozen_shifts"] += 1
	EventBus.breakpoint_started.connect(on_start)
	EventBus.breakpoint_ended.connect(on_end)
	EventBus.register_shifted.connect(on_shift)
	var start_frame: int = SimClock.sim_frame
	var hashes := PackedInt64Array()
	var h: int = 17
	var slash_serial_at_end: int = -1
	var frozen_world_ticks: int = 0
	for i: int in FRAMES:
		var before: int = SimClock.sim_frame
		SimClock.tick()
		if arena.breakpoint_skill.is_active() and SimClock.sim_frame != before:
			frozen_world_ticks += 1
		if i == END_AT:
			slash_serial_at_end = arena.actions.action_serial
		h = _hash(h, arena)
		hashes.append(h)
	var out: Dictionary = {
		&"ticks": SimClock.sim_frame - start_frame,
		&"hashes": hashes,
		&"hash": h,
		&"counts": counts.duplicate(),
		&"ring": arena.register.ring.duplicate(),
		&"slash_serial_at_end": slash_serial_at_end,
		&"frozen_world_ticks": frozen_world_ticks,
		&"rng_state": SimClock.ctx.rng.state,
	}
	EventBus.breakpoint_started.disconnect(on_start)
	EventBus.breakpoint_ended.disconnect(on_end)
	EventBus.register_shifted.disconnect(on_shift)
	arena.leave_fight()
	remove_child(arena)
	arena.free()
	return out


func test_a_recorded_breakpoint_fight_replays_bit_identically() -> void:
	var rec := InputRecorder.new()
	rec.start(SEED)
	SimClock.recorder = rec
	var live: Dictionary = _session(BreakpointScript.new(), SEED)
	SimClock.recorder = null
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))

	var replay := ReplayInput.from_file(TMP_PATH)
	assert_eq(replay.frame_count(), FRAMES)
	var again: Dictionary = _session(replay, replay.seed_value)

	assert_eq(live[&"counts"][&"started"], 1, "the second Space was refused by the cooldown")
	assert_eq(live[&"counts"][&"ended"], 1, "J ended it")
	assert_eq(live[&"counts"][&"frozen_shifts"], 3, "Q, E, Q applied during the freeze")
	assert_eq(live[&"frozen_world_ticks"], 0, "no world tick while frozen")
	assert_gt(live[&"slash_serial_at_end"], 0, "the ending J ran its action on that tick")
	assert_lt(live[&"ticks"], FRAMES, "Breakpoint froze world ticks")
	assert_eq(again[&"ticks"], live[&"ticks"], "same sim_frame")
	assert_eq(again[&"counts"], live[&"counts"])
	assert_eq(again[&"ring"], live[&"ring"])
	assert_eq(again[&"hash"], live[&"hash"])
	assert_eq(again[&"hashes"], live[&"hashes"], "same hash on every tick")
	assert_eq(again[&"rng_state"], live[&"rng_state"])
