extends GutTest
## Story 5.4 (AC 1, 2, 3, 16, 20): WatchSkill on a fresh SimClock (not in the tree, direct tick()
## calls). Unlock rule, held start / end on R down / up, the gate and ctx.watch_held copy, resets by
## reset_for_fight and end_fight, gate only in fight, one watch_started / watch_ended per hold.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const MainScript := preload("res://src/main/main.gd")


## Watch held per poll index (0-based); false on other polls.
class HeldInput:
	extends InputSource
	var held_at: Dictionary[int, bool] = {}
	var polls: int = 0

	func watch_held_for_frame() -> bool:
		var out: bool = held_at.get(polls, false)
		polls += 1
		return out


## Records ctx.watch_held on each world tick.
class HeldProbe:
	extends SimSystem
	var seen: Array[bool] = []

	func _init() -> void:
		phase = SimPhase.PLAYER

	func tick(ctx: SimContext) -> void:
		seen.append(ctx.watch_held)


var _clock: SimClockScript
var _src: HeldInput
var _skill: WatchSkill
var _probe: HeldProbe


func before_each() -> void:
	_clock = SimClockScript.new()
	_src = HeldInput.new()
	_clock.input_source = _src
	_clock.begin_fight(5404)
	_skill = WatchSkill.new(_clock)
	_probe = HeldProbe.new()
	_clock.register_system(_skill)
	_clock.register_system(_probe)
	_skill.reset_for_fight(true)


func after_each() -> void:
	_clock.free()


func _hold(from: int, to_excl: int) -> void:
	for i: int in range(from, to_excl):
		_src.held_at[i] = true


func _tick(times: int = 1) -> void:
	for i: int in times:
		_clock.tick()


func test_defaults_and_phase() -> void:
	assert_eq(_skill.phase, SimSystem.SimPhase.TIMERS)
	assert_true(_skill is FightSkill)
	assert_false(_skill.is_active())
	assert_true(_skill.is_unlocked())
	assert_eq(_skill.cooldown_left_frames(), 0)


func test_unlock_rule_boss_index_0_refuses_1_accepts() -> void:
	assert_false(MainScript.watch_unlocked_for(0), "Boss 1: locked")
	assert_true(MainScript.watch_unlocked_for(1), "Boss 2: unlocked")
	assert_true(MainScript.watch_unlocked_for(2))
	_skill.reset_for_fight(MainScript.watch_unlocked_for(0))
	_hold(0, 5)
	watch_signals(EventBus)
	_tick(5)
	assert_false(_skill.is_active(), "R does nothing before Boss 2")
	assert_false(_clock.watch_gate_active)
	assert_eq(_probe.seen, [false, false, false, false, false] as Array[bool])
	assert_signal_emit_count(EventBus, "watch_started", 0)


func test_held_while_r_is_down_and_ends_on_the_first_frame_up() -> void:
	_hold(1, 4) # polls 1, 2, 3
	watch_signals(EventBus)
	_tick(6)
	assert_eq(_probe.seen, [false, true, true, true, false, false] as Array[bool],
			"held on every polled frame R is down, the same tick")
	assert_false(_skill.is_active())
	assert_false(_clock.watch_gate_active)
	assert_signal_emit_count(EventBus, "watch_started", 1)
	assert_signal_emit_count(EventBus, "watch_ended", 1)


func test_gate_mirrors_held_state_each_poll() -> void:
	_hold(0, 2)
	_tick()
	assert_true(_skill.is_active())
	assert_true(_clock.watch_gate_active)
	assert_true(_clock.ctx.watch_held)
	_tick(2)
	assert_false(_clock.watch_gate_active)
	assert_false(_clock.ctx.watch_held)


func test_reset_for_fight_releases_and_emits_once() -> void:
	_hold(0, 10)
	_tick(2)
	assert_true(_skill.is_active())
	watch_signals(EventBus)
	_skill.reset_for_fight(true)
	assert_false(_skill.is_active())
	assert_false(_clock.watch_gate_active)
	assert_signal_emit_count(EventBus, "watch_ended", 1)
	_skill.reset_for_fight(true)
	assert_signal_emit_count(EventBus, "watch_ended", 1, "not held: no second end")
	_tick()
	assert_true(_skill.is_active(), "the held R is re-read on the next poll (D-S54-11)")


func test_end_fight_releases_and_gate_stays_off_outside_the_fight() -> void:
	_hold(0, 10)
	_tick(2)
	watch_signals(EventBus)
	_skill.end_fight()
	assert_false(_skill.is_active())
	assert_false(_skill.is_unlocked())
	assert_false(_clock.watch_gate_active)
	assert_signal_emit_count(EventBus, "watch_ended", 1)
	_tick(3)
	assert_false(_clock.watch_gate_active, "no gate outside FIGHT")
	assert_false(_clock.ctx.watch_held)
	assert_signal_emit_count(EventBus, "watch_started", 0)


func test_one_start_and_one_end_per_hold() -> void:
	_hold(0, 3)
	_hold(5, 7)
	watch_signals(EventBus)
	_tick(8)
	assert_signal_emit_count(EventBus, "watch_started", 2)
	assert_signal_emit_count(EventBus, "watch_ended", 2)


func test_held_during_breakpoint_and_hitstop_polls() -> void:
	_hold(0, 3)
	_clock.hitstop_frames = 2
	_tick()
	assert_true(_skill.is_active(), "poll runs during hit-stop")
	assert_true(_clock.ctx.watch_held)
	assert_eq(_probe.seen.size(), 0, "no world tick yet")


func test_jk_press_in_a_frozen_frame_under_watch_is_dropped() -> void:
	_hold(0, 1)
	_clock.hitstop_frames = 2
	_clock.buffer.push(&"action_1", _clock.poll_frame)
	_tick()
	assert_false(_clock.buffer.consume(&"action_1", _clock.poll_frame), "dropped, never fires after release")
	_clock.hitstop_frames = 0
	_clock.breakpoint_gate_active = true
	_hold(1, 2)
	_clock.buffer.push(&"action_2", _clock.poll_frame)
	_tick()
	assert_false(_clock.buffer.consume(&"action_2", _clock.poll_frame), "dropped under a Breakpoint freeze too")
	_clock.breakpoint_gate_active = false


func test_begin_fight_clears_watch_state() -> void:
	_clock.watch_gate_active = true
	_clock.ctx.watch_held = true
	_clock.begin_fight(1)
	assert_false(_clock.watch_gate_active)
	assert_false(_clock.ctx.watch_held)


func test_begin_fight_clears_move_slowed() -> void:
	_clock.ctx.move_slowed = true
	_clock.begin_fight(1)
	assert_false(_clock.ctx.move_slowed)


func test_no_rng_draw() -> void:
	var state_before: int = _clock.ctx.rng.state
	_hold(0, 5)
	_tick(6)
	assert_eq(_clock.ctx.rng.state, state_before, "Watch draws no RNG")


func test_no_input_source_never_held() -> void:
	_clock.input_source = null
	_tick(2)
	assert_false(_skill.is_active())
	assert_false(_clock.ctx.watch_held)
