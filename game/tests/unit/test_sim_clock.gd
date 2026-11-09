extends GutTest
## Ports the Story 1.1 SimClock ticking and pause checks (DC6: not in the tree, direct calls),
## extended for Story 2.1: phase order, hit-stop, Breakpoint hook, input polling (AC1, AC2, AC8).

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")


## Test-only system: appends its name to a shared log when ticked, optionally requests hit-stop.
class LogSystem:
	extends SimSystem
	var name: String
	var log: Array[String]
	var clock: Node
	var hitstop_request: int = 0

	func _init(p_phase: SimSystem.SimPhase, p_name: String, p_log: Array[String]) -> void:
		phase = p_phase
		name = p_name
		log = p_log

	func tick(_ctx: SimContext) -> void:
		log.append(name)
		if hitstop_request > 0 and clock != null:
			clock.call(&"request_hitstop", hitstop_request)


## Test-only source: returns the scripted presses (and moves) per poll, empty/zero after.
class ScriptedInput:
	extends InputSource
	var frames: Array[Array] = []
	var moves: Array[Vector2i] = []
	var polls: int = 0
	var move_polls: int = 0

	func move_for_frame() -> Vector2i:
		var out: Vector2i = Vector2i.ZERO
		if move_polls < moves.size():
			out = moves[move_polls]
		move_polls += 1
		return out

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if polls < frames.size():
			out.assign(frames[polls])
		polls += 1
		return out


var _clock: SimClockScript


func before_each() -> void:
	_clock = SimClockScript.new()


func after_each() -> void:
	_clock.free()


func _tick(times: int, delta: float = 1.0 / 60.0) -> void:
	for i: int in times:
		_clock.call(&"_physics_process", delta)


func test_sim_frame_starts_at_zero() -> void:
	assert_eq(_clock.get("sim_frame"), 0)


func test_sim_frame_plus_60_over_60_ticks() -> void:
	_tick(60)
	assert_eq(_clock.get("sim_frame"), 60)


func test_paused_freezes_sim_frame() -> void:
	_tick(10)
	_clock.set("paused", true)
	_tick(60)
	assert_eq(_clock.get("sim_frame"), 10)


func test_resume_after_pause_increments_again() -> void:
	_clock.set("paused", true)
	_tick(5)
	_clock.set("paused", false)
	_tick(3)
	assert_eq(_clock.get("sim_frame"), 3)


func test_delta_does_not_change_increment() -> void:
	_tick(1, 0.5)
	_tick(1, 0.0)
	assert_eq(_clock.get("sim_frame"), 2)


func test_null_input_source_ticks_without_tree() -> void:
	assert_null(_clock.input_source)
	assert_false(_clock.is_inside_tree())
	_tick(3)
	assert_eq(_clock.sim_frame, 3)


# --- Phase order (AC1) ---

func test_systems_run_in_phase_order() -> void:
	var log: Array[String] = []
	var P := SimSystem.SimPhase
	# Registered in scrambled order on purpose.
	_clock.register_system(LogSystem.new(P.TIMERS, "timers", log))
	_clock.register_system(LogSystem.new(P.COMBAT, "combat", log))
	_clock.register_system(LogSystem.new(P.SHIFTS, "shifts", log))
	_clock.register_system(LogSystem.new(P.PLAYER_EFFECTS, "effects", log))
	_clock.register_system(LogSystem.new(P.PLAYER, "player", log))
	_clock.register_system(LogSystem.new(P.BOSS_HAZARDS, "boss", log))
	_clock.register_system(LogSystem.new(P.ACTIONS, "actions", log))
	_tick(1)
	assert_eq(log, ["shifts", "actions", "player", "boss", "effects", "combat", "timers"] as Array[String])


func test_registration_order_within_a_phase() -> void:
	var log: Array[String] = []
	var P := SimSystem.SimPhase
	_clock.register_system(LogSystem.new(P.COMBAT, "c1", log))
	_clock.register_system(LogSystem.new(P.PLAYER, "p1", log))
	_clock.register_system(LogSystem.new(P.COMBAT, "c2", log))
	_clock.register_system(LogSystem.new(P.PLAYER, "p2", log))
	_clock.register_system(LogSystem.new(P.COMBAT, "c3", log))
	_tick(1)
	assert_eq(log, ["p1", "p2", "c1", "c2", "c3"] as Array[String])


func test_systems_get_the_clock_context() -> void:
	var seen: Array[SimContext] = []
	var probe := ContextProbe.new(seen)
	_clock.register_system(probe)
	_tick(1)
	assert_same(seen[0], _clock.ctx)


class ContextProbe:
	extends SimSystem
	var seen: Array[SimContext]

	func _init(p_seen: Array[SimContext]) -> void:
		seen = p_seen

	func tick(ctx: SimContext) -> void:
		seen.append(ctx)


# --- Hit-stop (AC2) ---

func test_hitstop_max_request_within_a_tick_wins() -> void:
	var log: Array[String] = []
	var a := LogSystem.new(SimSystem.SimPhase.COMBAT, "a", log)
	var b := LogSystem.new(SimSystem.SimPhase.COMBAT, "b", log)
	var c := LogSystem.new(SimSystem.SimPhase.BOSS_HAZARDS, "c", log)
	for s: LogSystem in [a, b, c]:
		s.clock = _clock
	a.hitstop_request = 3
	b.hitstop_request = 8
	c.hitstop_request = 5
	_clock.register_system(a)
	_clock.register_system(b)
	_clock.register_system(c)
	_tick(1)
	assert_eq(_clock.hitstop_frames, 8)


func test_hitstop_freezes_world_and_counts_down_per_physics_frame() -> void:
	var log: Array[String] = []
	var s := LogSystem.new(SimSystem.SimPhase.COMBAT, "s", log)
	s.clock = _clock
	s.hitstop_request = 3
	_clock.register_system(s)
	_tick(1) # world tick, requests 3
	assert_eq(_clock.sim_frame, 1)
	assert_eq(_clock.hitstop_frames, 3)
	s.hitstop_request = 0
	_tick(1)
	assert_eq(_clock.hitstop_frames, 2)
	_tick(1)
	assert_eq(_clock.hitstop_frames, 1)
	_tick(1)
	assert_eq(_clock.hitstop_frames, 0)
	assert_eq(_clock.sim_frame, 1, "world frozen during hit-stop")
	assert_eq(log.size(), 1, "systems not ticked during hit-stop")
	_tick(1)
	assert_eq(_clock.sim_frame, 2)
	assert_eq(log.size(), 2)


func test_hitstop_request_outside_tick_applies_after_next_world_tick() -> void:
	_clock.request_hitstop(4)
	assert_eq(_clock.hitstop_frames, 0)
	_tick(1)
	assert_eq(_clock.hitstop_frames, 4)
	assert_eq(_clock.sim_frame, 1)


func test_hitstop_keeps_running_maximum() -> void:
	_clock.hitstop_frames = 6
	_clock.request_hitstop(2)
	_tick(1) # gated: decrements to 5, pending stays
	assert_eq(_clock.hitstop_frames, 5)


func test_input_buffered_during_hitstop() -> void:
	var src := ScriptedInput.new()
	src.frames = [[], [&"action_1"], [&"shift_left"]]
	_clock.input_source = src
	_clock.hitstop_frames = 5
	_tick(3)
	assert_eq(src.polls, 3, "input polled every hit-stop frame")
	assert_eq(_clock.sim_frame, 0)
	assert_true(_clock.buffer.consume(&"action_1", 0))
	assert_true(_clock.buffer.consume(&"shift_left", 0))


# --- Pause and Breakpoint gates (AC1) ---

func test_pause_freezes_poll_and_frame() -> void:
	var src := ScriptedInput.new()
	src.frames = [[&"action_1"]]
	_clock.input_source = src
	_clock.paused = true
	_clock.hitstop_frames = 3
	_tick(5)
	assert_eq(src.polls, 0, "no poll while paused (D-S21-9)")
	assert_eq(_clock.buffer.size(), 0)
	assert_eq(_clock.hitstop_frames, 3, "hit-stop frozen by pause")
	assert_eq(_clock.sim_frame, 0)


func test_breakpoint_gate_freezes_world_and_hitstop_but_polls() -> void:
	var log: Array[String] = []
	_clock.register_system(LogSystem.new(SimSystem.SimPhase.PLAYER, "p", log))
	var src := ScriptedInput.new()
	src.frames = [[&"shift_right"]]
	_clock.input_source = src
	_clock.hitstop_frames = 2
	_clock.breakpoint_gate_active = true
	_tick(4)
	assert_eq(_clock.sim_frame, 0)
	assert_eq(log.size(), 0)
	assert_eq(_clock.hitstop_frames, 2, "hit-stop untouched during Breakpoint (NP-2)")
	assert_eq(src.polls, 4)
	assert_true(_clock.buffer.consume(&"shift_right", 0))
	_clock.breakpoint_gate_active = false
	_tick(2) # remaining hit-stop resumes
	assert_eq(_clock.hitstop_frames, 0)
	assert_eq(_clock.sim_frame, 0)
	_tick(1)
	assert_eq(_clock.sim_frame, 1)
	assert_eq(log.size(), 1)


func test_presses_buffered_at_current_sim_frame() -> void:
	var src := ScriptedInput.new()
	src.frames = [[], [], [&"watch"]]
	_clock.input_source = src
	_tick(3)
	assert_false(_clock.buffer.consume(&"watch", 1))
	assert_true(_clock.buffer.consume(&"watch", 2))


func test_recorder_records_every_polled_frame() -> void:
	var src := ScriptedInput.new()
	src.frames = [[&"action_1"], [], [&"action_2", &"shift_left"]]
	_clock.input_source = src
	var rec := InputRecorder.new()
	rec.start(5)
	_clock.recorder = rec
	_clock.hitstop_frames = 1 # the first poll is a hit-stop frame, still recorded
	_tick(3)
	_clock.paused = true
	_tick(2) # paused frames are not recorded
	var data: Dictionary = rec.stop()
	assert_eq(data["frames"], [["action_1"], [], ["action_2", "shift_left"]])


# --- Held direction and unregister (Story 2.2 E3) ---

## Records ctx.move_dir on each world tick.
class MoveProbe:
	extends SimSystem
	var seen: Array[Vector2i] = []

	func tick(ctx: SimContext) -> void:
		seen.append(ctx.move_dir)


func test_move_dir_set_from_source_each_polled_frame() -> void:
	var src := ScriptedInput.new()
	src.moves = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, -1)]
	_clock.input_source = src
	var probe := MoveProbe.new()
	_clock.register_system(probe)
	_tick(4)
	assert_eq(probe.seen, [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i.ZERO] as Array[Vector2i])
	assert_eq(src.move_polls, 4)


func test_move_dir_zero_without_input_source() -> void:
	_clock.ctx.move_dir = Vector2i(1, 1)
	_tick(1)
	assert_eq(_clock.ctx.move_dir, Vector2i.ZERO)


func test_move_dir_not_updated_while_paused() -> void:
	var src := ScriptedInput.new()
	src.moves = [Vector2i(1, 0), Vector2i(0, 1)]
	_clock.input_source = src
	_tick(1)
	_clock.paused = true
	_tick(3)
	assert_eq(_clock.ctx.move_dir, Vector2i(1, 0))
	assert_eq(src.move_polls, 1)


func test_move_polled_during_hitstop() -> void:
	var src := ScriptedInput.new()
	src.moves = [Vector2i(0, 1)]
	_clock.input_source = src
	_clock.hitstop_frames = 2
	_tick(1)
	assert_eq(_clock.ctx.move_dir, Vector2i(0, 1))
	assert_eq(_clock.sim_frame, 0)


func test_unregister_system_stops_ticking() -> void:
	var log: Array[String] = []
	var a := LogSystem.new(SimSystem.SimPhase.PLAYER, "a", log)
	var b := LogSystem.new(SimSystem.SimPhase.PLAYER, "b", log)
	_clock.register_system(a)
	_clock.register_system(b)
	_clock.unregister_system(a)
	_clock.unregister_system(a) # no-op when absent
	_clock.unregister_system(LogSystem.new(SimSystem.SimPhase.PLAYER, "never", log))
	_tick(1)
	assert_eq(log, ["b"] as Array[String])


func test_recorder_records_moves() -> void:
	var src := ScriptedInput.new()
	src.frames = [[&"action_1"], []]
	src.moves = [Vector2i(1, -1), Vector2i(0, 1)]
	_clock.input_source = src
	var rec := InputRecorder.new()
	rec.start(1)
	_clock.recorder = rec
	_tick(2)
	assert_eq(rec.stop()["moves"], [[1, -1], [0, 1]])
