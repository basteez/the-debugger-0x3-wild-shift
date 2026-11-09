extends GutTest
## Story 2.2 AC2-AC5: speed ramp, stop, diagonals, 8-direction facing, clamp, activation, pause
## and reset. Pure: Player.tick with a SimContext, or a fresh SimClock with a stub InputSource.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
const EPS := 0.0001
const SPAWN := Vector2(256, 144)

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


## Test-only source: always holds `dir`.
class HeldInput:
	extends InputSource
	var dir: Vector2i = Vector2i.ZERO
	var polls: int = 0

	func move_for_frame() -> Vector2i:
		polls += 1
		return dir


var _ctx: SimContext
var _player: Player


func before_each() -> void:
	_ctx = SimContext.new()
	_player = Player.new(load("res://data/player/player_def.tres") as PlayerDef, Arena.player_bounds())
	_player.reset_for_fight(SPAWN)
	_player.set_active(true)


func _v_max() -> float:
	return Const.tiles_per_s_to_px_per_frame(7.0)


func _hold(dir: Vector2i, frames: int) -> void:
	_ctx.move_dir = dir
	for i: int in frames:
		_player.tick(_ctx)


func test_v_max_is_7_tiles_per_second() -> void:
	assert_almost_eq(_v_max(), 7.0 * 16.0 / 60.0, EPS)
	assert_almost_eq(Const.tiles_per_s_to_px_per_frame(_player.def.speed_tiles_s), _v_max(), EPS)


func test_player_phase() -> void:
	assert_eq(_player.phase, SimSystem.SimPhase.PLAYER)


func test_held_right_ramps_to_full_speed_in_4_frames() -> void:
	for k: int in range(1, 5):
		_hold(Vector2i(1, 0), 1)
		assert_almost_eq(_player.velocity_px.length(), k * _v_max() / 4.0, EPS, "frame %d" % k)
	assert_almost_eq(_player.velocity_px.x, _v_max(), EPS)
	_hold(Vector2i(1, 0), 10)
	assert_almost_eq(_player.velocity_px.length(), _v_max(), EPS, "never exceeds top speed")


func test_release_stops_within_3_frames() -> void:
	_hold(Vector2i(1, 0), 10)
	for k: int in range(1, 4):
		_hold(Vector2i.ZERO, 1)
		assert_almost_eq(_player.velocity_px.length(), _v_max() * (3 - k) / 3.0, EPS, "frame %d" % k)
	assert_eq(_player.velocity_px, Vector2.ZERO)
	var x: float = _player.position_px.x
	_hold(Vector2i.ZERO, 5)
	assert_eq(_player.position_px.x, x, "no drift once stopped")


func test_position_advances_by_velocity() -> void:
	_hold(Vector2i(1, 0), 4)
	# 1/4 + 2/4 + 3/4 + 4/4 of v_max.
	assert_almost_eq(_player.position_px.x, SPAWN.x + 2.5 * _v_max(), EPS)
	assert_almost_eq(_player.position_px.y, SPAWN.y, EPS)


func test_diagonal_speed_equals_cardinal() -> void:
	_hold(Vector2i(1, 1), 4)
	assert_almost_eq(_player.velocity_px.length(), _v_max(), EPS)
	assert_almost_eq(_player.velocity_px.x, _player.velocity_px.y, EPS)


func test_all_8_directions_reach_full_speed() -> void:
	for dir: Vector2i in DIRS:
		_player.reset_for_fight(SPAWN)
		_hold(dir, 4)
		assert_almost_eq(_player.velocity_px.length(), _v_max(), EPS, str(dir))
		assert_almost_eq(_player.velocity_px.normalized().dot(Vector2(dir).normalized()), 1.0, EPS, str(dir))


func test_facing_follows_each_direction_and_persists_idle() -> void:
	for dir: Vector2i in DIRS:
		_hold(dir, 1)
		assert_eq(_player.facing, dir)
		_hold(Vector2i.ZERO, 5)
		assert_eq(_player.facing, dir, "persists while idle")


func test_cancelled_input_keeps_facing() -> void:
	_hold(Vector2i(0, -1), 1)
	_hold(Vector2i.ZERO, 1) # opposing keys cancel to zero in LiveInput
	assert_eq(_player.facing, Vector2i(0, -1))


func test_out_of_range_dir_is_reduced_to_its_sign() -> void:
	_hold(Vector2i(5, -3), 4)
	assert_eq(_player.facing, Vector2i(1, -1))
	assert_almost_eq(_player.velocity_px.length(), _v_max(), EPS)
	assert_eq(Player.sanitize_dir(Vector2i(-7, 0)), Vector2i(-1, 0))


func test_reversing_ramps_through_the_same_step() -> void:
	_hold(Vector2i(1, 0), 4)
	_hold(Vector2i(-1, 0), 1)
	assert_almost_eq(_player.velocity_px.x, _v_max() * 0.75, EPS, "no instant turn")


func test_clamp_at_each_edge() -> void:
	var cases: Array[Array] = [
		[Vector2i(-1, 0), 0, 8.0],
		[Vector2i(1, 0), 0, 504.0],
		[Vector2i(0, -1), 1, 8.0],
		[Vector2i(0, 1), 1, 280.0],
	]
	for c: Array in cases:
		_player.reset_for_fight(SPAWN)
		_ctx.move_dir = c[0]
		for i: int in 200:
			_player.tick(_ctx)
			assert_true(Rect2(8, 8, 496, 272).grow(EPS).has_point(_player.position_px), "inside at frame %d" % i)
		var axis: int = c[1]
		assert_almost_eq(_player.position_px[axis], float(c[2]), EPS, str(c[0]))
		assert_eq(_player.velocity_px[axis], 0.0, "velocity into the wall is zero")


func test_clamp_in_a_corner_keeps_sliding_axis() -> void:
	_player.reset_for_fight(Vector2(503, 144))
	_hold(Vector2i(1, 1), 4)
	assert_almost_eq(_player.position_px.x, 504.0, EPS)
	assert_eq(_player.velocity_px.x, 0.0)
	assert_gt(_player.velocity_px.y, 0.0, "still slides along the wall")


func test_leaving_wall_is_immediate_after_reversal() -> void:
	_player.reset_for_fight(Vector2(504, 144))
	_hold(Vector2i(1, 0), 20)
	_hold(Vector2i(-1, 0), 1)
	assert_lt(_player.position_px.x, 504.0, "no stored velocity pushing into the wall")


func test_inactive_player_does_not_move() -> void:
	_player.set_active(false)
	_hold(Vector2i(1, 0), 10)
	assert_eq(_player.position_px, SPAWN)
	assert_eq(_player.velocity_px, Vector2.ZERO)
	assert_eq(_player.facing, Vector2i(1, 0))


func test_paused_clock_freezes_player_and_keeps_velocity() -> void:
	var clock: SimClockScript = SimClockScript.new()
	var src := HeldInput.new()
	src.dir = Vector2i(0, 1)
	clock.input_source = src
	clock.register_system(_player)
	for i: int in 4:
		clock.tick()
	var pos: Vector2 = _player.position_px
	var vel: Vector2 = _player.velocity_px
	clock.paused = true
	for i: int in 30:
		clock.tick()
	assert_eq(_player.position_px, pos)
	assert_eq(_player.velocity_px, vel, "velocity resumes unchanged (D-S22-7)")
	assert_eq(src.polls, 4, "no poll while paused")
	clock.paused = false
	clock.tick()
	assert_almost_eq(_player.position_px.y, pos.y + vel.y, EPS)
	clock.free()


func test_driven_through_sim_clock() -> void:
	var clock: SimClockScript = SimClockScript.new()
	var src := HeldInput.new()
	src.dir = Vector2i(-1, 0)
	clock.input_source = src
	clock.register_system(_player)
	for i: int in 4:
		clock.tick()
	assert_almost_eq(_player.velocity_px.x, -_v_max(), EPS)
	assert_eq(_player.facing, Vector2i(-1, 0))
	clock.free()


func test_reset_for_fight_restores_spawn_velocity_and_facing() -> void:
	_hold(Vector2i(-1, -1), 30)
	_player.reset_for_fight(SPAWN)
	assert_eq(_player.position_px, SPAWN)
	assert_eq(_player.velocity_px, Vector2.ZERO)
	assert_eq(_player.facing, Vector2i(1, 0))


func test_player_view_rounds_onto_pixel_grid() -> void:
	assert_eq(PlayerView.player_top_left(Vector2(256.4, 144.6)), Vector2(248, 137))


func test_duck_sits_behind_the_player_inside_the_play_area() -> void:
	var at: Vector2 = PlayerView.duck_top_left(SPAWN, Vector2i(1, 0))
	assert_lt(at.x + 32.0, SPAWN.x - 8.0 + 0.5, "duck left of a right-facing player")
	var corner: Vector2 = PlayerView.duck_top_left(Vector2(8, 8), Vector2i(1, 1))
	assert_true(Rect2(Vector2.ZERO, Vector2(512 - 32, 288 - 16)).has_point(corner), "clamped inside")


## Story 2.5 (D-S25-6): the movement lock used by the ActionStateMachine.
func test_lock_forces_velocity_and_keeps_facing() -> void:
	_player.facing = Vector2i(0, 1)
	_player.lock_movement(Vector2(3, 0))
	_hold(Vector2i(-1, 0), 2)
	assert_eq(_player.velocity_px, Vector2(3, 0))
	assert_almost_eq(_player.position_px.x, SPAWN.x + 6.0, EPS)
	assert_eq(_player.facing, Vector2i(0, 1), "facing frozen while locked")


func test_lock_with_zero_velocity_holds_position() -> void:
	_hold(Vector2i(1, 0), 4)
	var at: Vector2 = _player.position_px
	_player.lock_movement(Vector2.ZERO)
	_hold(Vector2i(1, 0), 3)
	assert_eq(_player.position_px, at)
	assert_eq(_player.velocity_px, Vector2.ZERO)


func test_locked_movement_is_clamped() -> void:
	_player.reset_for_fight(Vector2(500, 144))
	_player.lock_movement(Vector2(10, 0))
	_hold(Vector2i.ZERO, 1)
	assert_eq(_player.position_px.x, Arena.player_bounds().end.x)
	assert_eq(_player.velocity_px.x, 0.0)


func test_unlock_caps_velocity_and_restores_normal_movement() -> void:
	_player.lock_movement(Vector2(6.4, 0))
	_hold(Vector2i.ZERO, 1)
	_player.unlock_movement()
	assert_false(_player.locked)
	assert_almost_eq(_player.velocity_px.length(), _v_max(), EPS, "capped at walking top speed")
	_hold(Vector2i.ZERO, 3)
	assert_almost_eq(_player.velocity_px.length(), 0.0, EPS, "normal decel ramp")
	_hold(Vector2i(0, -1), 1)
	assert_eq(_player.facing, Vector2i(0, -1))


func test_unlock_when_not_locked_is_a_no_op() -> void:
	_hold(Vector2i(1, 0), 4)
	var v: Vector2 = _player.velocity_px
	_player.unlock_movement()
	assert_eq(_player.velocity_px, v)
