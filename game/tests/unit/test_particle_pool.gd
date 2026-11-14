extends GutTest
## Story 2.8 AC2, NFR2, D-S28-2, D-S28-3: the fixed 300-slot glyph particle pool.

var _pool: ParticlePool


func before_each() -> void:
	_pool = ParticlePool.new()
	_pool.rng.seed = 1234
	add_child(_pool)


func after_each() -> void:
	_pool.queue_free()
	await get_tree().process_frame


func test_capacity_is_300_allocated_once() -> void:
	assert_eq(ParticlePool.CAPACITY, 300)
	assert_eq(_pool.slot_count(), 300)
	assert_eq(_pool.live_count(), 0)


func test_spawn_places_and_counts() -> void:
	assert_eq(_pool.spawn(Vector2(10, 10), 12), 12)
	assert_eq(_pool.live_count(), 12)
	assert_eq(_pool.spawn(Vector2.ZERO, 0), 0)
	assert_eq(_pool.spawn(Vector2.ZERO, -3), 0)
	assert_eq(_pool.slot_count(), 300, "spawning never grows the pool")


func test_full_pool_drops_the_rest_silently() -> void:
	assert_eq(_pool.spawn(Vector2.ZERO, 290), 290)
	assert_eq(_pool.spawn(Vector2.ZERO, 20), 10, "only the free slots are filled")
	assert_eq(_pool.live_count(), 300)
	assert_eq(_pool.spawn(Vector2.ZERO, 5), 0)
	assert_eq(_pool.live_count(), 300)
	assert_eq(_pool.slot_count(), 300)


func test_burst_sizes() -> void:
	assert_eq(ParticlePool.burst_for(false), 12)
	assert_eq(ParticlePool.burst_for(true), 20)
	assert_gt(ParticlePool.burst_for(true), ParticlePool.burst_for(false))


func test_particles_do_not_step_while_the_sim_frame_is_unchanged() -> void:
	_pool.advance_to(100)
	_pool.spawn(Vector2(50, 50), 1)
	var p0: Vector2 = _pool.position_of(0)
	_pool.advance_to(100)
	_pool.advance_to(100)
	assert_eq(_pool.position_of(0), p0, "frozen with the sim (hit-stop, pause, Breakpoint)")
	_pool.advance_to(101)
	assert_ne(_pool.position_of(0), p0, "steps on a new sim frame")


func test_expiry_after_lifetime_sim_frames() -> void:
	_pool.advance_to(0)
	_pool.spawn(Vector2.ZERO, 5)
	_pool.advance_to(ParticlePool.LIFETIME - 1)
	assert_eq(_pool.live_count(), 5)
	_pool.advance_to(ParticlePool.LIFETIME)
	assert_eq(_pool.live_count(), 0)
	assert_eq(_pool.spawn(Vector2.ZERO, 300), 300, "expired slots are reused")


func test_hit_landed_bursts_solo_and_combo() -> void:
	EventBus.hit_landed.emit(&"practice_target", 10, DamageCalc.STATE_BASE, false, Vector2(100, 100))
	assert_eq(_pool.live_count(), 12)
	EventBus.hit_landed.emit(&"practice_target", 20, DamageCalc.STATE_BASE, true, Vector2(100, 100))
	assert_eq(_pool.live_count(), 32)
	assert_eq(_pool.position_of(0), Vector2(100, 100), "bursts from the hit point")


func test_exit_tree_disconnects() -> void:
	remove_child(_pool)
	assert_false(EventBus.hit_landed.is_connected(_pool._on_hit_landed))
	add_child(_pool)
	assert_true(EventBus.hit_landed.is_connected(_pool._on_hit_landed))


func test_clear_frees_every_slot() -> void:
	_pool.spawn(Vector2.ZERO, 40)
	_pool.clear()
	assert_eq(_pool.live_count(), 0)


func test_glyphs_are_ascii_and_ink_only_source() -> void:
	for g: String in ParticlePool.GLYPHS:
		assert_eq(g.length(), 1)
		assert_lt(g.unicode_at(0), 128)
	var text: String = FileAccess.get_file_as_string("res://src/presentation/particle_pool.gd")
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		assert_false(line.contains("SimContext") or line.contains("ctx.rng"), "presentation randomness only (D-S28-3): %s" % line)
		assert_false(line.contains("Label"), "no Label nodes")


# Story 3.2 (AC 3, D-S32-18): a resisted boss hit bursts half the glyphs.
func test_unpatched_hit_bursts_half() -> void:
	assert_eq(ParticlePool.burst_for(false, DamageState.Kind.UNPATCHED), 6)
	assert_eq(ParticlePool.burst_for(true, DamageState.Kind.UNPATCHED), 10)
	assert_eq(ParticlePool.burst_for(true, DamageState.Kind.PATCHED), 20)
	assert_eq(ParticlePool.burst_for(false), 12)
	EventBus.hit_landed.emit(&"boss", 5, DamageState.Kind.UNPATCHED, false, Vector2(10, 10))
	assert_eq(_pool.live_count(), 6)


## Story 7.7 (AC 9, NFR2): the cap is structural. A worst-case burst (more spawns than slots in one
## frame, repeated over several frames, combo bursts from many hit points) never exceeds CAPACITY.
## Seeded through the pool's own RNG (before_each), no global RNG.
func test_worst_case_burst_never_exceeds_the_cap() -> void:
	var picker := RandomNumberGenerator.new()
	picker.seed = 7707
	_pool.advance_to(0)
	assert_eq(_pool.spawn(Vector2(320, 180), ParticlePool.CAPACITY * 2), ParticlePool.CAPACITY, "one oversized burst fills, the rest drops")
	assert_eq(_pool.live_count(), ParticlePool.CAPACITY)
	for frame: int in range(1, ParticlePool.LIFETIME * 3):
		_pool.advance_to(frame)
		for _hit: int in 40:
			var at := Vector2(picker.randf_range(0, 512), picker.randf_range(0, 288))
			_pool.spawn(at, ParticlePool.burst_for(picker.randf() < 0.5))
			assert_true(_pool.live_count() <= ParticlePool.CAPACITY, "live %d at frame %d" % [_pool.live_count(), frame])
		assert_eq(_pool.slot_count(), ParticlePool.CAPACITY, "never grows")
	assert_eq(_pool.live_count(), ParticlePool.CAPACITY, "saturated, still capped")
