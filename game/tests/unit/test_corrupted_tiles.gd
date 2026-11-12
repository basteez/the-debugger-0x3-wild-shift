extends GutTest
## Story 6.4 AC 3, 5, 8, 11, 13: the CorruptedTiles grid. Fixed 32 x 18 size, built once by the body
## and cleared in place on retry, the two pickers (seeded, distinct, inside the grid; the 288 / 288
## checkerboard), and the entry latch (D-S64-5: one hit per entry, none while standing still, none on
## the safe parity, none for a player already on the tile when ACTIVE starts).

const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const T := CorruptedTiles.TileState
const TILE := Const.TILE_PX


func _px(cell: Vector2i) -> Vector2:
	return CorruptedTiles.centre_of(cell)


func test_grid_is_32_by_18_and_starts_clear() -> void:
	var g := CorruptedTiles.new()
	assert_eq(CorruptedTiles.SIZE, Vector2i(32, 18))
	assert_eq(g.states.size(), 576)
	assert_true(g.is_empty())
	assert_eq(g.state_at(Vector2i(31, 17)), T.CLEAR)
	assert_eq(g.state_at(Vector2i(32, 0)), T.CLEAR, "outside the grid reads CLEAR")
	assert_false(CorruptedTiles.in_grid(Vector2i(-1, 0)))


func test_cell_geometry() -> void:
	assert_eq(CorruptedTiles.centre_of(Vector2i(0, 0)), Vector2(8, 8))
	assert_eq(CorruptedTiles.centre_of(Vector2i(31, 17)), Vector2(504, 280))
	assert_eq(CorruptedTiles.cell_at(Vector2(15.9, 16.0)), Vector2i(0, 1))
	for i: int in [0, 31, 32, 575]:
		assert_eq(CorruptedTiles.index_of(CorruptedTiles.cell_of_index(i)), i)


func test_reset_clears_in_place() -> void:
	var g := CorruptedTiles.new()
	g.mark_checkerboard()
	g.was_on_attack_tile = true
	g.reset()
	assert_true(g.is_empty())
	assert_eq(g.states.size(), 576)
	assert_eq(g.attack_cells, 0)
	assert_false(g.was_on_attack_tile)


func test_mark_random_is_distinct_inside_and_seeded() -> void:
	for seed_i: int in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var g := CorruptedTiles.new()
		assert_eq(g.mark_random(rng, 12), 12)
		assert_eq(g.attack_cells, 12)
		var centres: PackedVector2Array = g.attack_centres()
		assert_eq(centres.size(), 12, "distinct cells")
		for p: Vector2 in centres:
			assert_true(Arena.play_area().has_point(p), "inside the play area")
		var again := RandomNumberGenerator.new()
		again.seed = seed_i
		var h := CorruptedTiles.new()
		h.mark_random(again, 12)
		assert_eq(h.states, g.states, "same seed, same cells")


func test_checkerboard_is_288_by_288_on_the_odd_parity() -> void:
	var g := CorruptedTiles.new()
	g.mark_checkerboard()
	assert_eq(g.attack_cells, 288)
	assert_eq(g.centres_in(T.SAFE).size(), 288)
	assert_eq(g.state_at(Vector2i(1, 0)), T.MARKED, "(x + y) odd is the hazard parity")
	assert_eq(g.state_at(Vector2i(0, 0)), T.SAFE)
	g.arm()
	assert_eq(g.centres_in(T.HAZARD).size(), 288)
	assert_eq(g.centres_in(T.SAFE).size(), 0, "the safe dots go in ACTIVE")
	assert_eq(g.centres_in(T.MARKED).size(), 0)
	assert_eq(g.attack_cells, 288)


func test_entry_latch_one_hit_per_entry() -> void:
	var g := CorruptedTiles.new()
	var hazard := Vector2i(5, 5)
	g.set_state(hazard, T.MARKED)
	g.arm()
	var outside: Vector2 = _px(Vector2i(4, 5))
	assert_false(g.entry_hit(outside, true))
	assert_true(g.entry_hit(_px(hazard), true), "entering hits")
	for i: int in 30:
		assert_false(g.entry_hit(_px(hazard) + Vector2(i % 3, 0), true), "standing on it does not re-hit")
	assert_false(g.entry_hit(outside, true))
	assert_true(g.entry_hit(_px(hazard), true), "leaving and coming back hits again")


func test_entry_latch_none_while_not_live_and_already_on_at_start() -> void:
	var g := CorruptedTiles.new()
	var cell := Vector2i(10, 10)
	g.set_state(cell, T.MARKED)
	assert_false(g.entry_hit(_px(cell), false), "TELL: never a hit")
	g.arm()
	assert_false(g.entry_hit(_px(cell), true), "already on the tile when ACTIVE starts: no hit")
	assert_false(g.entry_hit(_px(Vector2i(11, 10)), true))
	assert_true(g.entry_hit(_px(cell), true), "until they leave and come back")


func test_entry_latch_ignores_the_safe_parity() -> void:
	var g := CorruptedTiles.new()
	g.mark_checkerboard()
	g.arm()
	var safe: Vector2 = _px(Vector2i(2, 2))
	for i: int in 10:
		assert_false(g.entry_hit(safe, true), "the safe parity never hurts")
	assert_true(g.entry_hit(_px(Vector2i(3, 2)), true))


func test_body_allocates_the_grid_once_and_clears_it_on_retry() -> void:
	var b := SegfaultBody.new()
	assert_null(b.tiles, "nothing before the fight")
	assert_true(b.setup(SF_DEF, null, null))
	b.reset_for_fight()
	var grid: CorruptedTiles = b.tiles
	assert_not_null(grid)
	var ctx := SimContext.new()
	ctx.reseed(64)
	for i: int in 400:
		b.tick(ctx)
		assert_same(b.tiles, grid, "never rebuilt in tick")
		assert_eq(b.tiles.states.size(), 576)
	grid.mark_checkerboard()
	grid.was_on_attack_tile = true
	b.reset_for_fight()
	assert_same(b.tiles, grid, "cleared in place on retry")
	assert_true(grid.is_empty())
	assert_false(grid.was_on_attack_tile, "no latched entry carries over")
