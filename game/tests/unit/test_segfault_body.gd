extends GutTest
## Story 6.3 AC 1-9, 13, 20-21, 24: the Segfault body. Glyph band, seeded integer drift (speed,
## reflection, top-third bounds), the drift rule per state, jitter steps at the phase thresholds,
## the hurtbox and contact, wiring (Arena by path, Main behind the flag), the sky comment, the
## defeat route and the reset on retry. The body is ticked by hand.

const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const TILE := Const.TILE_PX
const S := BossController.BossState

var _ctx: SimContext
var _saved_state: int


## A body that holds its attacks (framework hook), so the drift tests see pure GAP drift.
class IdleBody:
	extends SegfaultBody

	func _attacks_allowed() -> bool:
		return false


class FakeActions:
	extends ActionStateMachine

	func invulnerable() -> bool:
		return false


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE
	_ctx = SimContext.new()
	_ctx.reseed(6363)
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func _body(idle: bool = false) -> SegfaultBody:
	var b: SegfaultBody = IdleBody.new() if idle else SegfaultBody.new()
	assert_true(b.setup(SF_DEF, null, null), "setup accepts the Segfault def")
	b.reset_for_fight()
	return b


# --- AC 1-4: wiring, flag, sky ---

func test_arena_and_main_wiring() -> void:
	assert_eq(Arena.boss_class_for(Arena.SEGFAULT_DEF_PATH), SegfaultBody, "loaded by path")
	assert_eq(Arena.SEGFAULT_BODY_PATH, (SegfaultBody as Script).resource_path)
	var main_script: GDScript = load("res://src/main/main.gd")
	assert_eq(main_script.boss_def_path_for(false, 2, false, true), Arena.SEGFAULT_DEF_PATH)
	assert_eq(main_script.boss_def_path_for(false, 2, false, false), "", "AC 2: cut -> placeholder")
	assert_eq(main_script.boss_def_path_for(false, 2, true, true), "", "practice: no boss")
	assert_eq(main_script.boss_def_path_for(true, 2, false, true), Arena.TEST_BOSS_DEF_PATH, "Shift+F3 wins")
	assert_eq(main_script.boss_def_path_for(false, 1, false, false), Arena.NULL_POINTER_DEF_PATH, "boss 1 unaffected")
	assert_true(main_script.breakpoint_unlocked_for(2), "AC 4")
	assert_true(main_script.watch_unlocked_for(2), "AC 4")


func test_sky_comment() -> void:
	assert_eq(Hud.sky_for(&"segfault"), "// HACK: do not read past this line")
	assert_eq(Hud.sky_for(&"null_pointer"), Hud.SKY_NULL_POINTER)
	assert_eq(Hud.sky_for(&""), Hud.SKY, "restored on leave")


func test_defeat_routes_to_ending_with_no_drop() -> void:
	assert_eq(GameScript.route_after_defeat(2, true), GameScript.FlowState.ENDING)
	assert_false(GameScript.drops_bit(2, true))


# --- AC 5: the glyph band ---

func test_glyph_grid_is_6x4_from_the_fr40_set_and_pure() -> void:
	assert_eq(SegfaultBody.BODY_TILES, Vector2i(6, 4))
	var glyphs: PackedStringArray = SegfaultBody.cell_glyphs()
	assert_eq(glyphs.size(), 24)
	for y: int in 4:
		for x: int in 6:
			var g: String = SegfaultBody.glyph_at(Vector2i(x, y))
			assert_eq(g.length(), 1)
			assert_true(SegfaultBody.GLYPHS.contains(g), "cell %d,%d '%s'" % [x, y, g])
			assert_eq(SegfaultBody.glyph_at(Vector2i(x, y)), g, "pure")
	assert_eq(SegfaultBody.glyph_at(Vector2i(6, 0)), "")
	assert_eq(SegfaultBody.glyph_at(Vector2i(0, -1)), "")


func test_band_is_the_top_third() -> void:
	assert_eq(SegfaultBody.band_rect(), Rect2i(0, 0, 32, 6))


func test_spawn_state_and_cells_inside_the_band() -> void:
	var b: SegfaultBody = _body()
	assert_true(b.active)
	assert_eq(b.state, S.GAP)
	assert_eq(b.hp, 1000)
	assert_eq(b.phase_index, 0)
	assert_eq(b.body_center_px, Vector2(256, 48))
	assert_eq(b.current_weak_window(), Vector2i(Register.Bit.DASH, Register.Bit.LOOP))
	_assert_cells_in_band(b)


func _assert_cells_in_band(b: SegfaultBody) -> void:
	var band := Rect2(Vector2.ZERO, Vector2(SegfaultBody.band_rect().size * TILE))
	for c: Vector2 in b.cell_centres():
		var cell := Rect2(c - Vector2(TILE, TILE) / 2.0, Vector2(TILE, TILE))
		assert_true(band.encloses(cell), "cell %s inside the top band" % c)


# --- AC 6, 9: drift ---

func test_drift_speed_over_300_seeded_ticks() -> void:
	var b: SegfaultBody = _body(true)
	var x0: int = b.pos_mtiles.x
	b.tick(_ctx)
	var dir: int = b.drift_dir
	assert_true(dir == 1 or dir == -1, "direction drawn from the fight RNG")
	# 2 tiles/s: 300 ticks = 5 s = 10 tiles, as long as no wall is reached (16 +- 10 stays in 3..29).
	for i: int in 299:
		b.tick(_ctx)
	assert_eq(b.pos_mtiles.x - x0, dir * 10000, "exactly 10 tiles in 300 ticks")
	assert_eq(b.pos_mtiles.y, SegfaultBody.SPAWN_MTILES.y, "no vertical motion")


func test_reflects_at_the_inset_edges_and_never_leaves_the_band() -> void:
	var b: SegfaultBody = _body(true)
	var flips: int = 0
	var last_dir: int = 0
	for i: int in 3000:
		b.tick(_ctx)
		if last_dir != 0 and b.drift_dir != last_dir:
			flips += 1
		last_dir = b.drift_dir
		assert_between(b.pos_mtiles.x, 3000, 29000)
		assert_eq(b.pos_mtiles.y, 3000)
	assert_gt(flips, 1, "it reflects at both edges")
	_assert_cells_in_band(b)


func test_drift_is_deterministic_for_a_seed() -> void:
	var a: SegfaultBody = _body(true)
	var c: SegfaultBody = _body(true)
	var ctx_a := SimContext.new()
	ctx_a.reseed(99)
	var ctx_c := SimContext.new()
	ctx_c.reseed(99)
	for i: int in 500:
		a.tick(ctx_a)
		c.tick(ctx_c)
	assert_eq(a.pos_mtiles, c.pos_mtiles)


# --- AC 8: the drift rule per state ---

func test_drifts_in_gap_and_tell_but_not_active_or_recovery() -> void:
	var b: SegfaultBody = _body()
	var seen: Dictionary = {}
	for i: int in 600:
		var s: S = b.state
		var before: int = b.pos_mtiles.x
		b.tick(_ctx)
		if b.state != s:
			continue # a transition tick
		var moved: bool = b.pos_mtiles.x != before
		if s == S.ACTIVE or s == S.RECOVERY:
			assert_false(moved, "still in %s" % S.keys()[s])
		elif s == S.GAP or s == S.TELL:
			# 33.3 mtiles a tick: every tick moves
			assert_true(moved, "drifts in %s" % S.keys()[s])
		seen[s] = true
	for s: S in [S.GAP, S.TELL, S.ACTIVE, S.RECOVERY]:
		assert_true(seen.has(s), "reached %s" % S.keys()[s])


func test_drifts_during_roar() -> void:
	var b: SegfaultBody = _body()
	b.take_hit(340) # 660 / 1000 = 66%: phase 2
	assert_eq(b.state, S.ROAR)
	var before: int = b.pos_mtiles.x
	b.tick(_ctx)
	assert_ne(b.pos_mtiles.x, before)


# --- AC 7: hurtbox and contact ---

func test_hurtbox_radius_and_contact() -> void:
	var b: SegfaultBody = _body()
	assert_almost_eq(b.body_radius_px(), 2.0 * TILE, 0.001)
	assert_true(b.touches_player(b.body_center_px + Vector2(2 * TILE, 0)), "D-S63-5: body contact on")
	assert_false(b.touches_player(b.body_center_px + Vector2(2 * TILE + 1, 0)))


func test_body_contact_queues_one_hit() -> void:
	var arena := ArenaContext.new()
	var h := PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	h.reset_for_fight()
	h.set_active(true)
	var b := IdleBody.new()
	assert_true(b.setup(SF_DEF, h, arena))
	b.reset_for_fight()
	arena.contact_source = func() -> Vector2: return b.body_center_px
	b.tick(_ctx)
	h.tick(_ctx)
	assert_eq(h.hp, PLAYER_DEF.max_hp - 1, "a dragon contact deals 1 HP")


# --- AC 11, 13: phases and jitter ---

func test_phase_thresholds_drive_the_jitter_steps() -> void:
	var b: SegfaultBody = _body()
	assert_eq(b.jitter_level(), 0)
	b.take_hit(339) # 661
	assert_eq(b.phase_index, 0)
	assert_eq(b.jitter_level(), 0)
	b.take_hit(1) # 660: 66%
	assert_eq(b.phase_index, 1)
	assert_eq(b.jitter_level(), 1)
	assert_eq(b.current_weak_window(), Vector2i(Register.Bit.NULL_BIT, Register.Bit.ATTACK))
	b.take_hit(331) # 329: 32.9%
	assert_eq(b.phase_index, 2)
	assert_eq(b.jitter_level(), 2)
	assert_eq(b.current_weak_window(), Vector2i(Register.Bit.LOOP, Register.Bit.NULL_BIT))


# --- AC 20-21: defeat and retry ---

func test_defeat_and_retry_reset() -> void:
	var b: SegfaultBody = _body()
	for i: int in 200:
		b.tick(_ctx)
	b.take_hit(500)
	b.debug_kill()
	assert_eq(b.state, S.DEFEATED)
	assert_eq(b.cell_centres().size(), 24, "the cells the reassembly moves")
	b.reset_for_fight()
	assert_eq(b.hp, 1000)
	assert_eq(b.phase_index, 0)
	assert_eq(b.state, S.GAP)
	assert_eq(b.frames_left, 90)
	assert_eq(b.pos_mtiles, SegfaultBody.SPAWN_MTILES)
	assert_eq(b.drift_dir, 0, "re-seeded on the next drifting tick")
	assert_true(b.active)


# --- AD-05: presentation reads only ---

func test_boss_view_draws_it_as_a_glyph_body() -> void:
	var b: SegfaultBody = _body()
	assert_true(BossView.is_glyph_body(b))
	assert_false(BossView.is_glyph_body(BossController.new()))
