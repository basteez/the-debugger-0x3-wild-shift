extends GutTest
## Story 2.3 E2 (AC3, AC4): the Register ticked by a real SimClock (not in the tree) with a stub
## InputSource. Shifts apply in 0 frames, survive short hit-stops, expire in long ones, keep press
## order, and nothing happens while inactive or paused.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP


## Presses per poll; empty after the script ends.
class ScriptedInput:
	extends InputSource
	var frames: Array[Array] = []
	var polls: int = 0

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if polls < frames.size():
			out.assign(frames[polls])
		polls += 1
		return out


var _clock: SimClockScript
var _src: ScriptedInput
var _reg: Register


func before_each() -> void:
	_clock = SimClockScript.new()
	_src = ScriptedInput.new()
	_clock.input_source = _src
	_reg = Register.new(_clock.buffer)
	_reg.set_fight_start(PackedInt32Array([A, D, L]))
	_reg.set_active(true)
	_clock.register_system(_reg)


func after_each() -> void:
	_clock.free()


func _tick(n: int) -> void:
	for i: int in n:
		_clock.tick()


func test_press_applies_on_the_same_tick() -> void:
	_src.frames = [[], [&"shift_left"]]
	_tick(1)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L]))
	_tick(1)
	assert_eq(_reg.ring, PackedInt32Array([D, L, A]), "0 frames: applied on the press's poll")


func test_short_hitstop_applies_on_first_unfrozen_tick() -> void:
	_src.frames = [[&"shift_right"]]
	_clock.hitstop_frames = 3
	_tick(3)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L]), "buffered during hit-stop")
	_tick(1)
	assert_eq(_reg.ring, PackedInt32Array([L, A, D]), "applied on the first unfrozen tick")


func test_hitstop_of_eight_still_applies() -> void:
	_src.frames = [[&"shift_left"]]
	_clock.hitstop_frames = 8
	_tick(9) # press at poll 0, first world tick at poll 8: age 8, still live
	assert_eq(_reg.ring, PackedInt32Array([D, L, A]))


func test_press_late_in_a_long_hitstop_still_applies() -> void:
	_src.frames = [[], [&"shift_left"]]
	_clock.hitstop_frames = 9
	_tick(12) # press at poll 1, first world tick at poll 9: age 8, still live (AC4 is about age)
	assert_eq(_reg.ring, PackedInt32Array([D, L, A]))


func test_long_hitstop_expires_the_press() -> void:
	watch_signals(EventBus)
	_src.frames = [[&"shift_left"]]
	_clock.hitstop_frames = 9
	_tick(12)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L]), "expired after 8 frames, never applied")
	assert_signal_not_emitted(EventBus, "register_shifted")


func test_presses_apply_in_press_order() -> void:
	watch_signals(EventBus)
	_src.frames = [[&"shift_left"], [&"shift_right"]]
	_clock.hitstop_frames = 2 # both buffered, then applied in one tick
	_tick(3)
	assert_signal_emit_count(EventBus, "register_shifted", 2)
	var first: Array = get_signal_parameters(EventBus, "register_shifted", 0)
	var second: Array = get_signal_parameters(EventBus, "register_shifted", 1)
	assert_eq(first[0], Register.LEFT)
	assert_eq(second[0], Register.RIGHT)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L]))


func test_same_poll_both_shifts_in_listed_order() -> void:
	watch_signals(EventBus)
	_src.frames = [[&"shift_right", &"shift_left"]]
	_tick(1)
	assert_eq(get_signal_parameters(EventBus, "register_shifted", 0)[0], Register.RIGHT)
	assert_eq(get_signal_parameters(EventBus, "register_shifted", 1)[0], Register.LEFT)


func test_inactive_register_ignores_shifts() -> void:
	_reg.set_active(false)
	_src.frames = [[&"shift_left"], [&"shift_right"]]
	_tick(3)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L]))


func test_paused_clock_polls_and_applies_nothing() -> void:
	_src.frames = [[&"shift_left"]]
	_clock.paused = true
	_tick(5)
	assert_eq(_src.polls, 0)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L]))
	_clock.paused = false
	_tick(1) # the scripted press is only made now, on the first unpaused poll
	assert_eq(_reg.ring, PackedInt32Array([D, L, A]))


func test_other_actions_are_left_in_the_buffer() -> void:
	_src.frames = [[&"action_1", &"shift_left"]]
	_tick(1)
	assert_true(_clock.buffer.consume(&"action_1", 0), "J press untouched by the register")


func test_shift_loop_stops_when_a_listener_deactivates_the_register() -> void:
	_src.frames = [[&"shift_left", &"shift_left"]]
	_reg.set_active(true)
	var off := func(_d: int, _w: Vector2i, _r: PackedInt32Array, _s: StringName) -> void:
		_reg.set_active(false)
	EventBus.register_shifted.connect(off)
	_tick(1)
	EventBus.register_shifted.disconnect(off)
	assert_eq(_reg.ring, PackedInt32Array([D, L, A]), "second buffered shift not applied once inactive")
