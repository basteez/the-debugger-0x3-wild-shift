extends GutTest
## Story 2.5 AC3: Cooldowns start, ready, tick, reset and independent bits (D-S25-4). Pure.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH

var _cd: Cooldowns


func before_each() -> void:
	_cd = Cooldowns.new()


func test_fresh_bits_are_ready() -> void:
	assert_true(_cd.ready(D))
	assert_eq(_cd.remaining(D), 0)


func test_start_and_tick_to_zero() -> void:
	_cd.start(D, 3)
	assert_false(_cd.ready(D))
	assert_eq(_cd.remaining(D), 3)
	_cd.tick()
	_cd.tick()
	assert_eq(_cd.remaining(D), 1)
	assert_false(_cd.ready(D))
	_cd.tick()
	assert_true(_cd.ready(D))
	_cd.tick()
	assert_eq(_cd.remaining(D), 0, "never negative")


func test_zero_start_is_ready() -> void:
	_cd.start(A, 0)
	assert_true(_cd.ready(A))


func test_bits_are_independent() -> void:
	_cd.start(D, 2)
	_cd.start(A, 5)
	_cd.tick()
	_cd.tick()
	assert_true(_cd.ready(D))
	assert_eq(_cd.remaining(A), 3)


func test_reset_clears_all() -> void:
	_cd.start(D, 24)
	_cd.start(A, 4)
	_cd.reset()
	assert_true(_cd.ready(D))
	assert_true(_cd.ready(A))
