extends GutTest
## Story 2.1 AC4: one seeded RNG, reseeded by begin_fight, which also clears buffer and hit-stop.

const SimClockScript := preload("res://src/autoloads/sim_clock.gd")


func _draws(ctx: SimContext, n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		out.append(ctx.rng.randi())
	return out


func test_same_seed_same_sequence() -> void:
	var a := SimContext.new()
	var b := SimContext.new()
	a.reseed(1234)
	b.reseed(1234)
	assert_eq(_draws(a, 20), _draws(b, 20))


func test_reseed_restarts_the_sequence() -> void:
	var ctx := SimContext.new()
	ctx.reseed(42)
	var first: Array[int] = _draws(ctx, 10)
	ctx.reseed(42)
	assert_eq(_draws(ctx, 10), first)


func test_different_seed_different_sequence() -> void:
	var a := SimContext.new()
	var b := SimContext.new()
	a.reseed(1)
	b.reseed(2)
	assert_ne(_draws(a, 10), _draws(b, 10))


func test_begin_fight_reseeds_and_clears() -> void:
	var clock: SimClockScript = SimClockScript.new()
	clock.ctx.reseed(7)
	var expected: Array[int] = _draws(clock.ctx, 5)
	clock.ctx.reseed(999)
	_draws(clock.ctx, 3)
	clock.buffer.push(&"action_1", 0)
	clock.hitstop_frames = 5
	clock.request_hitstop(9)
	clock.begin_fight(7)
	assert_eq(_draws(clock.ctx, 5), expected, "rng reseeded")
	assert_eq(clock.buffer.size(), 0, "buffer cleared")
	assert_eq(clock.hitstop_frames, 0, "hit-stop cleared")
	clock.tick() # a pending request from before begin_fight must not apply
	assert_eq(clock.hitstop_frames, 0, "pending hit-stop cleared")
	assert_eq(clock.sim_frame, 1)
	clock.free()


func test_begin_fight_keeps_sim_frame() -> void:
	var clock: SimClockScript = SimClockScript.new()
	for i: int in 4:
		clock.tick()
	clock.begin_fight(1)
	assert_eq(clock.sim_frame, 4)
	clock.free()
