extends GutTest
## Story 4.3 (AC 3, 5-8, 12, 15): BreakpointSkill on a fresh SimClock (not in the tree, direct
## tick() calls) with a real Register in SHIFTS and test systems in ACTIONS / PLAYER. Covers start
## and refusals, the 120-poll cap, J/K ends with the press executing on the first unfrozen tick,
## Q/E shifts during the freeze, pause, hit-stop, the 720/721 cooldown boundary, no chaining, the
## per-fight reset and the InputBuffer bound while mashing.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")


## Scripted presses keyed by poll index (0-based); empty on other polls.
class ScriptedInput:
	extends InputSource
	var by_poll: Dictionary[int, Array] = {}
	var polls: int = 0

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if by_poll.has(polls):
			out.assign(by_poll[polls])
		polls += 1
		return out


## ACTIONS-phase stand-in for the FSM: consumes action_1 / action_2 at ctx.poll_frame and records
## the clock's sim_frame of each consume.
class ActionProbe:
	extends SimSystem
	var clock: Node
	var consumed_at: Array[int] = []

	func _init(p_clock: Node) -> void:
		phase = SimPhase.ACTIONS
		clock = p_clock

	func tick(ctx: SimContext) -> void:
		var buffer: InputBuffer = clock.get(&"buffer")
		for action: StringName in [&"action_1", &"action_2"]:
			if buffer.consume(action, ctx.poll_frame):
				consumed_at.append(clock.get(&"sim_frame"))


## PLAYER-phase counter: world ticks seen.
class WorldProbe:
	extends SimSystem
	var ticks: int = 0

	func _init() -> void:
		phase = SimPhase.PLAYER

	func tick(_ctx: SimContext) -> void:
		ticks += 1


var _clock: SimClockScript
var _src: ScriptedInput
var _skill: BreakpointSkill
var _register: Register
var _probe: ActionProbe
var _world: WorldProbe


func before_each() -> void:
	_clock = SimClockScript.new()
	_src = ScriptedInput.new()
	_clock.input_source = _src
	_clock.begin_fight(4303)
	_register = Register.new(_clock.buffer)
	_register.set_fight_start(Register.fight_start_for_boss(1))
	_register.set_active(true)
	_skill = BreakpointSkill.new(_clock)
	_probe = ActionProbe.new(_clock)
	_world = WorldProbe.new()
	_clock.register_system(_register)
	_clock.register_system(_probe)
	_clock.register_system(_world)
	_clock.register_system(_skill)
	_skill.reset_for_fight(true)


func after_each() -> void:
	_clock.free()


func _tick(times: int = 1) -> void:
	for i: int in times:
		_clock.tick()


## Presses for poll index `at`.
func _press(at: int, actions: Array[StringName]) -> void:
	_src.by_poll[at] = actions


# --- AC 3: start and refusals ---

func test_defaults_phase_and_constants() -> void:
	assert_eq(_skill.phase, SimSystem.SimPhase.TIMERS)
	assert_eq(BreakpointSkill.MAX_FROZEN_POLLS, 120, "GDD: up to 120 real frames")
	assert_eq(BreakpointSkill.COOLDOWN_FRAMES, 720, "GDD: 12 s in sim frames")
	assert_eq(_skill.cooldown_frames, 720)
	assert_false(_skill.is_active())
	assert_true(_skill.is_unlocked())
	assert_eq(_skill.cooldown_left_frames(), 0, "first use of the fight is free")


func test_space_starts_on_that_tick_and_freezes_the_world() -> void:
	watch_signals(EventBus)
	_press(0, [&"breakpoint"])
	_tick()
	assert_true(_skill.active)
	assert_true(_clock.breakpoint_gate_active)
	assert_eq(_clock.sim_frame, 0, "the start tick is already frozen")
	assert_eq(_world.ticks, 0)
	assert_signal_emit_count(EventBus, "breakpoint_started", 1)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 0)
	_tick(10)
	assert_eq(_clock.sim_frame, 0)
	assert_eq(_world.ticks, 0)
	assert_eq(_clock.poll_frame, 11, "polling continues")


func test_locked_space_does_nothing() -> void:
	watch_signals(EventBus)
	_skill.reset_for_fight(false)
	_press(0, [&"breakpoint"])
	_tick()
	assert_false(_skill.active)
	assert_false(_clock.breakpoint_gate_active)
	assert_eq(_clock.sim_frame, 1)
	assert_signal_emit_count(EventBus, "breakpoint_started", 0)


func test_outside_a_fight_space_does_nothing() -> void:
	_skill.end_fight()
	_press(0, [&"breakpoint"])
	_tick()
	assert_false(_skill.active)
	assert_false(_clock.breakpoint_gate_active)


func test_other_keys_do_not_start_it() -> void:
	_press(0, [&"action_1", &"shift_left", &"watch"])
	_tick()
	assert_false(_skill.active)
	assert_eq(_clock.sim_frame, 1)


# --- AC 5: 120 frozen polls ---

func test_cap_ends_on_the_120th_poll_and_the_world_ticks_that_tick() -> void:
	watch_signals(EventBus)
	_press(0, [&"breakpoint"])
	_tick(119)
	assert_true(_skill.active, "still frozen after 119 polls")
	assert_eq(_skill.frozen_polls, 119)
	assert_eq(_clock.sim_frame, 0)
	_tick()
	assert_false(_skill.active, "ends on the 120th poll")
	assert_false(_clock.breakpoint_gate_active)
	assert_eq(_clock.sim_frame, 1, "the world ticks on that same tick")
	assert_eq(_world.ticks, 1)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1)
	assert_eq(_skill.cooldown_left, 720, "the ending tick does not count")


# --- AC 6: J / K end it, the press executes on the first unfrozen tick ---

func test_j_ends_it_and_executes_on_that_tick() -> void:
	watch_signals(EventBus)
	_press(0, [&"breakpoint"])
	_press(30, [&"action_1"])
	_tick(30)
	assert_true(_skill.active)
	_tick()
	assert_false(_skill.active)
	assert_false(_clock.breakpoint_gate_active)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1)
	assert_eq(_probe.consumed_at, [0] as Array[int], "J consumed on the first world tick")
	assert_eq(_clock.sim_frame, 1)


func test_k_ends_it_too() -> void:
	_press(0, [&"breakpoint"])
	_press(5, [&"action_2"])
	_tick(6)
	assert_false(_skill.active)
	assert_eq(_probe.consumed_at.size(), 1)


func test_q_e_and_space_do_not_end_it_and_shifts_apply_frozen() -> void:
	watch_signals(EventBus)
	var ring_before: PackedInt32Array = _register.ring.duplicate()
	_press(0, [&"breakpoint"])
	_press(3, [&"shift_left"])
	_press(4, [&"shift_right"])
	_press(5, [&"shift_left"])
	_press(6, [&"breakpoint"])
	_tick(4) # polls 0-3
	assert_signal_emit_count(EventBus, "register_shifted", 1, "Q applied during the freeze")
	assert_eq(_register.ring, Register.rotated(ring_before, Register.LEFT))
	assert_eq(_clock.sim_frame, 0)
	_tick(3) # polls 4-6
	assert_signal_emit_count(EventBus, "register_shifted", 3)
	assert_true(_skill.active, "Q, E and Space never end Breakpoint")
	assert_eq(_skill.frozen_polls, 7, "Space while active does not restart it")
	assert_eq(_clock.sim_frame, 0)
	assert_eq(_world.ticks, 0)


func test_same_poll_space_and_j_starts_without_ending() -> void:
	_press(0, [&"action_1", &"breakpoint"])
	_tick()
	assert_true(_skill.active, "the start poll never ends it")


func test_hitstop_frames_resume_after_breakpoint() -> void:
	_clock.hitstop_frames = 3
	_press(0, [&"breakpoint"])
	_press(10, [&"action_1"])
	_tick(10)
	assert_eq(_clock.hitstop_frames, 3, "hit-stop untouched while frozen (NP-2)")
	_tick() # end poll: gate cleared, hit-stop resumes on this tick
	assert_false(_skill.active)
	assert_eq(_clock.hitstop_frames, 2)
	assert_eq(_clock.sim_frame, 0)
	_tick(2)
	assert_eq(_clock.hitstop_frames, 0)
	assert_eq(_clock.sim_frame, 0)
	_tick()
	assert_eq(_clock.sim_frame, 1)
	assert_eq(_probe.consumed_at, [0] as Array[int], "J still live after 3 hit-stop polls (8-frame buffer)")


func test_cooldown_skips_the_first_world_tick_after_a_hitstop_delayed_end() -> void:
	_clock.hitstop_frames = 0
	_press(0, [&"breakpoint"])
	_press(5, [&"action_1"])
	_tick(5)
	_clock.hitstop_frames = 2 # hit-stop pending when the end poll arrives
	_tick() # end poll: no world tick (hit-stop)
	assert_eq(_skill.cooldown_left, _skill.cooldown_frames)
	_tick() # drain the last hit-stop frame
	_tick() # the first world tick after the end: skipped
	assert_eq(_skill.cooldown_left, _skill.cooldown_frames)
	_tick()
	assert_eq(_skill.cooldown_left, _skill.cooldown_frames - 1)


# --- AC 7: pause keeps priority ---

func test_pause_keeps_it_active_and_does_not_count() -> void:
	_press(0, [&"breakpoint"])
	_tick(50)
	assert_eq(_skill.frozen_polls, 50)
	_clock.paused = true
	_tick(500)
	assert_true(_skill.active, "pausing during Breakpoint keeps it")
	assert_eq(_skill.frozen_polls, 50, "paused frames never count")
	assert_true(_clock.breakpoint_gate_active)
	_clock.paused = false
	_tick(69)
	assert_true(_skill.active)
	_tick()
	assert_false(_skill.active, "resume continues it to the 120-poll cap")


func test_pause_does_not_count_toward_the_cooldown() -> void:
	_press(0, [&"breakpoint"])
	_press(1, [&"action_1"])
	_tick(2)
	assert_eq(_skill.cooldown_left, 720)
	_clock.paused = true
	_tick(300)
	assert_eq(_skill.cooldown_left, 720)
	_clock.paused = false
	_tick(10)
	assert_eq(_skill.cooldown_left, 710)


# --- AC 8: cooldown ---

func test_cooldown_boundary_refused_on_720_accepted_on_721() -> void:
	watch_signals(EventBus)
	_press(0, [&"breakpoint"])
	_press(1, [&"action_1"]) # ends on poll 1: the ending tick T0
	_press(1 + 720, [&"breakpoint"]) # T720: refused
	_press(1 + 721, [&"breakpoint"]) # T721: accepted
	_tick(2)
	assert_false(_skill.active)
	assert_eq(_skill.cooldown_left, 720)
	_tick(719) # T1..T719
	assert_eq(_skill.cooldown_left, 1)
	_tick() # T720 with Space
	assert_false(_skill.active, "refused on the 720th world tick after the end")
	assert_eq(_skill.cooldown_left, 0)
	assert_signal_emit_count(EventBus, "breakpoint_started", 1)
	_tick() # T721 with Space
	assert_true(_skill.active, "accepted on the 721st")
	assert_signal_emit_count(EventBus, "breakpoint_started", 2)


func test_cooldown_counts_world_ticks_only() -> void:
	_press(0, [&"breakpoint"])
	_press(1, [&"action_1"])
	_tick(2)
	_clock.hitstop_frames = 20
	_tick(20)
	assert_eq(_skill.cooldown_left, 720, "hit-stop frames never count")
	_tick(5)
	assert_eq(_skill.cooldown_left, 715)


func test_no_chaining_space_refused_while_cooling() -> void:
	watch_signals(EventBus)
	_press(0, [&"breakpoint"])
	_press(1, [&"action_1"])
	_press(2, [&"breakpoint"])
	_press(100, [&"breakpoint"])
	_tick(101)
	assert_false(_skill.active)
	assert_signal_emit_count(EventBus, "breakpoint_started", 1)
	assert_false(_skill.can_start())


func test_cooldown_frames_are_injectable() -> void:
	var short := BreakpointSkill.new(null, 360)
	assert_eq(short.cooldown_frames, 360)
	assert_eq(BreakpointSkill.new(null, -5).cooldown_frames, 0)


# --- AC 12: fight entry and exit ---

func test_reset_clears_gate_emits_ended_and_frees_the_cooldown() -> void:
	_press(0, [&"breakpoint"])
	_tick(5)
	watch_signals(EventBus)
	_skill.reset_for_fight(true)
	assert_false(_skill.active)
	assert_false(_clock.breakpoint_gate_active)
	assert_eq(_skill.frozen_polls, 0)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1)
	_skill.cooldown_left = 400
	_skill.reset_for_fight(false)
	assert_eq(_skill.cooldown_left, 0, "every fight entry frees the first use")
	assert_false(_skill.unlocked)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1, "no second ended when not running")


func test_end_fight_clears_the_gate_once() -> void:
	_press(0, [&"breakpoint"])
	_tick(5)
	watch_signals(EventBus)
	_skill.end_fight()
	_skill.end_fight()
	assert_false(_clock.breakpoint_gate_active)
	assert_signal_emit_count(EventBus, "breakpoint_ended", 1)
	_tick()
	assert_eq(_clock.sim_frame, 1, "the world ticks again")


# --- AC 15: InputBuffer bounded while mashing ---

func test_buffer_stays_bounded_while_mashing_during_breakpoint() -> void:
	var mash: Array[StringName] = [&"shift_left", &"shift_right", &"breakpoint", &"watch"]
	_press(0, [&"breakpoint"])
	for i: int in range(1, 119):
		_press(i, mash)
	var biggest: int = 0
	for i: int in 119:
		_tick()
		biggest = maxi(biggest, _clock.buffer.size())
	assert_true(_skill.active, "mashing Q/E/Space/R never ends it")
	var bound: int = (InputBuffer.PRESS_LIFETIME_FRAMES + 1) * mash.size()
	assert_lte(biggest, bound, "pruned on push: at most lifetime + 1 polls of presses")
	assert_lte(_clock.buffer.size(), bound)
