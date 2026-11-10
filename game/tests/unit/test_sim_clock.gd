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


## Story 4.3: records poll() calls ("poll:<name>:<presses>") and ticks ("tick:<name>") into a log.
class PollSystem:
	extends SimSystem
	var name: String
	var log: Array[String]

	func _init(p_phase: SimSystem.SimPhase, p_name: String, p_log: Array[String]) -> void:
		phase = p_phase
		name = p_name
		log = p_log

	func poll(presses: Array[StringName], _ctx: SimContext) -> void:
		log.append("poll:%s:%s" % [name, ",".join(presses)])

	func tick(_ctx: SimContext) -> void:
		log.append("tick:%s" % name)


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
	assert_eq(_clock.poll_frame, 3, "hit-stop frames are polled frames (D-S23-2)")
	assert_false(_clock.buffer.consume(&"action_1", 0), "stamped with poll_frame, not sim_frame")
	assert_true(_clock.buffer.consume(&"action_1", 1))
	assert_true(_clock.buffer.consume(&"shift_left", 2))


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


func test_presses_buffered_at_current_poll_frame() -> void:
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


# --- Poll frame time base (Story 2.3 A2, D-S23-2) ---

## Records ctx.poll_frame on each world tick.
class PollProbe:
	extends SimSystem
	var seen: Array[int] = []

	func tick(ctx: SimContext) -> void:
		seen.append(ctx.poll_frame)


func test_poll_frame_counts_every_unpaused_frame() -> void:
	assert_eq(_clock.poll_frame, 0)
	_tick(2)
	_clock.hitstop_frames = 2
	_tick(2)
	_clock.breakpoint_gate_active = true
	_tick(3)
	_clock.breakpoint_gate_active = false
	_clock.paused = true
	_tick(5)
	assert_eq(_clock.poll_frame, 7, "hit-stop and Breakpoint count, pause does not")
	assert_eq(_clock.sim_frame, 2)


func test_ctx_poll_frame_is_the_ticked_poll() -> void:
	var probe := PollProbe.new()
	_clock.register_system(probe)
	_tick(2)
	_clock.hitstop_frames = 3
	_tick(4)
	assert_eq(probe.seen, [0, 1, 5] as Array[int])


func test_press_during_long_hitstop_expires() -> void:
	var src := ScriptedInput.new()
	src.frames = [[&"shift_left"]]
	_clock.input_source = src
	_clock.hitstop_frames = 9
	_tick(10) # poll 0 holds the press; polls 0-8 are hit-stop; poll 9 is the first world tick
	assert_false(_clock.buffer.consume(&"shift_left", _clock.ctx.poll_frame), "expired after 9 frames")


# --- Story 2.9: the retry press is swallowed for one poll (D-S29-12) ---

func test_swallow_presses_drops_one_poll_only() -> void:
	var src := ScriptedInput.new()
	src.frames = [[&"action_1"], [&"action_2"]]
	src.moves = [Vector2i(1, 0), Vector2i(0, 1)]
	_clock.input_source = src
	_clock.swallow_presses_next_poll()
	_tick(1)
	assert_eq(_clock.buffer.size(), 0, "the swallowed poll buffers nothing")
	assert_eq(_clock.ctx.move_dir, Vector2i(1, 0), "movement is still read")
	_tick(1)
	assert_eq(_clock.buffer.size(), 1, "the next poll is normal")


func test_swallow_survives_pause_and_begin_fight() -> void:
	var src := ScriptedInput.new()
	src.frames = [[&"action_1"], [&"action_2"]]
	_clock.input_source = src
	_clock.swallow_presses_next_poll()
	_clock.begin_fight(7)
	_clock.paused = true
	_tick(1)
	_clock.paused = false
	_tick(1)
	assert_eq(_clock.buffer.size(), 0, "the first polled tick after the pause is swallowed")


# --- Story 4.3: poll hook and SHIFTS-only freeze (AC 4, D-S43-3, D-S43-4) ---

func test_default_poll_is_a_no_op() -> void:
	var sys := SimSystem.new()
	sys.poll([&"action_1"] as Array[StringName], SimContext.new())
	assert_eq(sys.phase, SimSystem.SimPhase.TIMERS)


func test_poll_runs_on_every_system_before_any_tick() -> void:
	var log: Array[String] = []
	var P := SimSystem.SimPhase
	_clock.register_system(PollSystem.new(P.TIMERS, "t", log))
	_clock.register_system(PollSystem.new(P.SHIFTS, "s", log))
	var src := ScriptedInput.new()
	src.frames = [[&"action_1", &"shift_left"]]
	_clock.input_source = src
	_tick(1)
	assert_eq(log, ["poll:s:action_1,shift_left", "poll:t:action_1,shift_left", "tick:s", "tick:t"] as Array[String])
	assert_true(_clock.buffer.consume(&"action_1", 0), "presses are pushed before poll")


func test_poll_runs_during_hitstop_and_breakpoint_not_pause() -> void:
	var log: Array[String] = []
	_clock.register_system(PollSystem.new(SimSystem.SimPhase.PLAYER, "p", log))
	_clock.hitstop_frames = 1
	_tick(1)
	assert_eq(log, ["poll:p:"] as Array[String], "polled during hit-stop, not ticked")
	log.clear()
	_clock.breakpoint_gate_active = true
	_tick(1)
	assert_eq(log, ["poll:p:"] as Array[String], "polled during Breakpoint, not ticked")
	log.clear()
	_clock.paused = true
	_tick(3)
	assert_eq(log.size(), 0, "pause returns before the poll hook")


func test_poll_can_open_the_gate_for_its_own_tick() -> void:
	var log: Array[String] = []
	var gate := GateOnPoll.new(_clock)
	_clock.register_system(gate)
	_clock.register_system(LogSystem.new(SimSystem.SimPhase.PLAYER, "p", log))
	_tick(1)
	assert_true(_clock.breakpoint_gate_active)
	assert_eq(log.size(), 0, "the gate set in poll freezes that same tick")
	assert_eq(_clock.sim_frame, 0)


func test_breakpoint_freeze_ticks_shifts_only() -> void:
	var log: Array[String] = []
	var P := SimSystem.SimPhase
	_clock.register_system(LogSystem.new(P.TIMERS, "timers", log))
	_clock.register_system(LogSystem.new(P.SHIFTS, "shifts", log))
	_clock.register_system(LogSystem.new(P.ACTIONS, "actions", log))
	_clock.register_system(LogSystem.new(P.SHIFTS, "shifts2", log))
	_clock.hitstop_frames = 4
	_clock.breakpoint_gate_active = true
	_tick(3)
	assert_eq(log, ["shifts", "shifts2", "shifts", "shifts2", "shifts", "shifts2"] as Array[String])
	assert_eq(_clock.sim_frame, 0, "sim_frame frozen")
	assert_eq(_clock.hitstop_frames, 4, "hit-stop untouched")
	assert_eq(_clock.poll_frame, 3)


func test_q_press_shifts_the_register_while_frozen() -> void:
	var register := Register.new(_clock.buffer)
	register.set_fight_start(Register.fight_start_for_boss(1))
	register.set_active(true)
	_clock.register_system(register)
	var src := ScriptedInput.new()
	src.frames = [[], [&"shift_right"]]
	_clock.input_source = src
	_clock.breakpoint_gate_active = true
	watch_signals(EventBus)
	var before: PackedInt32Array = register.ring.duplicate()
	_tick(2)
	assert_signal_emit_count(EventBus, "register_shifted", 1)
	assert_eq(register.ring, Register.rotated(before, Register.RIGHT))
	assert_eq(_clock.sim_frame, 0)


## Test-only: opens the Breakpoint gate from its poll hook.
class GateOnPoll:
	extends SimSystem
	var clock: Node

	func _init(p_clock: Node) -> void:
		phase = SimPhase.TIMERS
		clock = p_clock

	func poll(_presses: Array[StringName], _ctx: SimContext) -> void:
		clock.set(&"breakpoint_gate_active", true)
