extends GutTest
## Ports the Story 1.1 SimClock ticking and pause checks (DC6: not in the tree, direct calls).

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")

var _clock: Node


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
