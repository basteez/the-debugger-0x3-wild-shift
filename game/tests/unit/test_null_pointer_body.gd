extends GutTest
## Story 5.1 AC 3-13, 17-18: the Null Pointer's body. Visibility rule and reveal timers (each
## source), the seeded integer drift (speed, re-pick, bounds), the falling column and the hum
## following the body every tick, the empty-pool GAP loop, the arena / Main wiring, the sky comment
## and the CombatResolver hooks (a real slash and a real Echo Dash). The body is ticked by hand.

const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const J := &"action_1"
const K := &"action_2"
const TILE := Const.TILE_PX
const SPAWN := Vector2(256, 144)

var _ctx: SimContext


func before_each() -> void:
	_ctx = SimContext.new()
	_ctx.reseed(5151)
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func after_each() -> void:
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


func _body() -> NullPointerBody:
	var b := NullPointerBody.new()
	assert_true(b.setup(NP_DEF, null, null), "setup accepts the Null Pointer def")
	b.reset_for_fight()
	return b


## Ticks the body once and returns whether it is visible after that tick (what the next draw sees).
func _tick_visible(b: NullPointerBody) -> bool:
	b.tick(_ctx)
	return b.visible_now()


## Places the body (test only) at arena-local px `p`.
static func _place(b: NullPointerBody, p: Vector2) -> void:
	b.pos_mtiles = Vector2i((p * NullPointerBody.MILLI / float(TILE)).round())
	b.body_center_px = p


# --- AC 1, 3: spawn and wiring ---

func test_spawn_state() -> void:
	var b: NullPointerBody = _body()
	assert_true(b.active)
	assert_eq(b.state, BossController.BossState.GAP)
	assert_eq(b.hp, 700)
	assert_eq(b.pos_mtiles, NullPointerBody.SPAWN_TILES * 1000)
	assert_eq(b.body_center_px, Vector2(NullPointerBody.SPAWN_TILES * TILE))
	assert_false(b.visible_now(), "invisible at spawn")
	assert_eq(b.current_weak_window(), Vector2i(D, L), "phase 1 window D->L")


func test_arena_and_main_wiring() -> void:
	assert_eq(Arena.boss_class_for(Arena.NULL_POINTER_DEF_PATH), NullPointerBody)
	assert_eq(Arena.boss_class_for(Arena.INFINITE_LOOP_DEF_PATH), InfiniteLoopBody)
	var main_script: GDScript = load("res://src/main/main.gd")
	assert_eq(main_script.boss_def_path_for(false, 1), Arena.NULL_POINTER_DEF_PATH)
	assert_eq(main_script.boss_def_path_for(false, 1, true), "", "practice: no boss")
	assert_eq(main_script.boss_def_path_for(true, 1), Arena.TEST_BOSS_DEF_PATH, "Shift+F3 wins")
	assert_eq(main_script.boss_def_path_for(false, 2), "", "Segfault still a placeholder")


func test_arena_enter_fight_places_the_null_pointer() -> void:
	var arena := Arena.new()
	add_child_autofree(arena)
	arena.enter_fight(Register.fight_start_for_boss(1), false, Arena.NULL_POINTER_DEF_PATH, true)
	assert_true(arena.boss is NullPointerBody)
	assert_same(arena.combat.boss, arena.boss)
	assert_eq(arena.boss.body_center_px, Vector2(NullPointerBody.SPAWN_TILES * TILE), "places itself on reset")
	arena.leave_fight()
	assert_false(arena.boss.active)


# --- AC 4-9: visibility ---

func test_attack_active_and_recovery_frames_are_visible() -> void:
	var b: NullPointerBody = _body()
	for s: BossController.BossState in [BossController.BossState.ACTIVE, BossController.BossState.RECOVERY]:
		b.state = s
		assert_true(b.visible_now(), "visible in %s" % BossController.BossState.keys()[s])
	for s: BossController.BossState in [BossController.BossState.GAP, BossController.BossState.TELL, BossController.BossState.ROAR]:
		b.state = s
		assert_false(b.visible_now(), "hidden in %s" % BossController.BossState.keys()[s])


func test_hit_reveal_lasts_exactly_10_sim_frames() -> void:
	var b: NullPointerBody = _body()
	b.reveal_for_hit()
	var seen: int = 1 if b.visible_now() else 0 # the frame of the hit (COMBAT runs after BOSS_HAZARDS)
	for i: int in 30:
		if _tick_visible(b):
			seen += 1
	assert_eq(seen, NullPointerBody.HIT_REVEAL_FRAMES)
	assert_eq(NullPointerBody.HIT_REVEAL_FRAMES, 10)


func test_pass_through_reveal_lasts_exactly_60_sim_frames() -> void:
	var b: NullPointerBody = _body()
	b.on_pass_through()
	var seen: int = 1 if b.visible_now() else 0
	for i: int in 120:
		if _tick_visible(b):
			seen += 1
	assert_eq(seen, 60)


func test_a_hit_never_shortens_a_running_pass_through_reveal() -> void:
	var b: NullPointerBody = _body()
	b.on_pass_through()
	for i: int in 5:
		b.tick(_ctx)
	b.reveal_for_hit()
	assert_eq(b.pass_reveal_left, 55)
	assert_eq(b.hit_reveal_left, 10)
	b.on_player_hit()
	assert_eq(b.hit_reveal_left, 10, "the CombatResolver hook is the hit reveal")


func test_watch_held_is_visible() -> void:
	var b: NullPointerBody = _body()
	assert_false(b.watch_held, "Watch released by default")
	b.set_watch_held(true)
	assert_true(b.visible_now())
	assert_true(_tick_visible(b), "stays visible while held")
	b.set_watch_held(false)
	assert_false(b.visible_now())
	b.set_watch_held(true)
	b.reset_for_fight()
	assert_false(b.visible_now(), "a retry releases Watch and clears every reveal")


func test_reveal_timers_freeze_while_the_boss_does_not_tick() -> void:
	var b: NullPointerBody = _body()
	b.reveal_for_hit()
	b.set_active(false)
	for i: int in 20:
		b.tick(_ctx)
	assert_eq(b.hit_reveal_left, 10, "inactive (leave, pause gate): sim timers do not run")
	b.set_active(true)
	b.tick(_ctx)
	assert_eq(b.hit_reveal_left, 9)


func test_visible_now_is_a_pure_read() -> void:
	var b: NullPointerBody = _body()
	b.reveal_for_hit()
	for i: int in 50:
		b.visible_now()
	assert_eq(b.hit_reveal_left, 10, "reading never counts a timer down")


func test_defeated_ghost_is_shown_and_the_column_stops() -> void:
	var b: NullPointerBody = _body()
	b.take_hit(700)
	assert_eq(b.state, BossController.BossState.DEFEATED)
	assert_true(b.visible_now(), "D-S51-6")
	assert_false(b.alive())
	SimClock._pending_hitstop = 0


func test_patched_stack_is_drawn_while_the_ghost_is_hidden() -> void:
	var b: NullPointerBody = _body()
	var view := BossView.new()
	add_child_autofree(view)
	view.boss = b
	b.weak_window.apply_patched(WeakWindowTracker.PATCHED_FRAMES)
	assert_false(b.visible_now())
	assert_true(b.weak_window.is_patched(), "Patched state the view's stack reads (AC 8)")
	view.queue_redraw()
	await wait_physics_frames(1)
	assert_true(view.is_inside_tree(), "the draw path runs without errors on a hidden, Patched ghost")


# --- AC 10: drift ---

func test_drift_speed_repick_and_bounds_over_a_seeded_run() -> void:
	var b: NullPointerBody = _body()
	var lo: Vector2i = b.min_mtiles()
	var hi: Vector2i = b.max_mtiles()
	assert_eq(lo, Vector2i(1000, 1000), "body radius 1 tile inset")
	assert_eq(hi, Vector2i(31000, 17000))
	var travelled: float = 0.0
	var prev: Vector2i = b.pos_mtiles
	var picks: Array[int] = []
	for t: int in 900:
		var timer_before: int = b.drift_timer
		b.tick(_ctx)
		if timer_before == 0:
			picks.append(t)
		var step: float = Vector2(b.pos_mtiles - prev).length()
		assert_lte(step, 68.0, "never faster than 4 tiles/s (tick %d)" % t)
		travelled += step
		prev = b.pos_mtiles
		assert_true(b.pos_mtiles.x >= lo.x and b.pos_mtiles.x <= hi.x and b.pos_mtiles.y >= lo.y and b.pos_mtiles.y <= hi.y, "inside the play area (tick %d)" % t)
		var area: Rect2 = Arena.play_area()
		assert_true(area.has_point(b.body_center_px), "px inside the play area")
	assert_eq(picks, [0, 90, 180, 270, 360, 450, 540, 630, 720, 810], "re-picked every 90 ticks")
	# Reflections shorten a tick's step by at most the overshoot; 900 ticks at 4 tiles/s is 60000.
	assert_almost_eq(travelled, 60000.0, 600.0, "4 tiles/s on average")


func test_drift_is_deterministic_per_seed() -> void:
	var a: NullPointerBody = _body()
	var b: NullPointerBody = _body()
	var c: NullPointerBody = _body()
	var ca := SimContext.new()
	var cb := SimContext.new()
	var cc := SimContext.new()
	ca.reseed(7)
	cb.reseed(7)
	cc.reseed(8)
	var differs: bool = false
	for t: int in 300:
		a.tick(ca)
		b.tick(cb)
		c.tick(cc)
		assert_eq(a.pos_mtiles, b.pos_mtiles)
		differs = differs or a.pos_mtiles != c.pos_mtiles
	assert_true(differs, "another seed takes another path")


func test_reflection_at_the_edges() -> void:
	var r: Vector3i = NullPointerBody._step_axis(1010, 0, -1000, 1000, 31000)
	assert_eq(r.x, 1000 + (1000 - (1010 - 66)), "reflected back inside")
	assert_eq(r.z, 1000, "direction flipped")
	r = NullPointerBody._step_axis(30990, 0, 1000, 1000, 31000)
	assert_lte(r.x, 31000)
	assert_eq(r.z, -1000)
	r = NullPointerBody._step_axis(5000, 0, 1000, 1000, 31000)
	assert_eq(r, Vector3i(5066, 40000, 1000), "66 mtiles plus a remainder of 40000 / 60000")


func test_no_drift_during_attack_active_and_recovery() -> void:
	var b: NullPointerBody = _body()
	b.tick(_ctx) # picks a direction
	b.state = BossController.BossState.ACTIVE
	b.frames_left = 50
	var at: Vector2i = b.pos_mtiles
	b.tick(_ctx)
	assert_eq(b.pos_mtiles, at, "the ghost holds still in ACTIVE")
	b.state = BossController.BossState.RECOVERY
	b.tick(_ctx)
	assert_eq(b.pos_mtiles, at, "and in RECOVERY")


# --- AC 11, 12: the column and the hum follow the body each tick ---

func test_hum_and_trail_follow_the_body_over_300_ticks() -> void:
	var b: NullPointerBody = _body()
	var view := BossView.new()
	add_child_autofree(view)
	view.boss = b
	var hum: NullPointerHum = view.hum
	assert_not_null(hum)
	assert_same(hum.get_parent(), view)
	for t: int in 300:
		b.tick(_ctx)
		hum.sync_to(b)
		assert_eq(hum.position, b.body_center_px, "hum on the body (tick %d)" % t)
		var trail: PackedVector2Array = b.trail_positions()
		assert_eq(trail.size(), NullPointerBody.TRAIL_GLYPHS)
		var fall: float = float((t + 1) % 15) / 15.0
		if b.body_center_px.y + (NullPointerBody.TRAIL_GLYPHS + 1) * TILE > Arena.play_area().end.y:
			continue # the flipped column has its own test
		for k: int in trail.size():
			assert_almost_eq(trail[k], b.body_center_px + Vector2(0.0, (1.0 + k + fall) * TILE), Vector2(0.001, 0.001), "glyph %d (tick %d)" % [k, t])


func test_column_hangs_above_the_body_at_the_bottom_edge_and_stays_inside() -> void:
	var b: NullPointerBody = _body()
	var area: Rect2 = Arena.play_area()
	b.body_center_px = Vector2(area.get_center().x, area.end.y - TILE)
	var trail: PackedVector2Array = b.trail_positions()
	assert_eq(trail.size(), NullPointerBody.TRAIL_GLYPHS)
	var size := Vector2(GlyphFont.text_width(BossView.TRAIL_GLYPH, BossView.GHOST_SCALE), GlyphFont.CELL * BossView.GHOST_SCALE)
	for p: Vector2 in trail:
		assert_lt(p.y, b.body_center_px.y, "above the body")
		assert_true(BossView.trail_glyph_inside(p, size, area), "inside the play area")


func test_a_hit_or_pass_that_cannot_count_reveals_nothing() -> void:
	var b: NullPointerBody = _body()
	b.set_active(false)
	b.on_player_hit()
	b.on_pass_through()
	assert_eq(b.hit_reveal_left, 0)
	assert_eq(b.pass_reveal_left, 0)


func test_column_has_four_glyphs_one_tile_apart_and_wraps() -> void:
	var b: NullPointerBody = _body()
	assert_eq(NullPointerBody.TRAIL_GLYPHS, 4)
	assert_eq(b.trail_tick, 0)
	for i: int in 14:
		b.tick(_ctx)
	assert_eq(b.trail_tick, 14)
	b.tick(_ctx)
	assert_eq(b.trail_tick, 0, "wraps to the column top after 15 ticks (1 tile)")
	var trail: PackedVector2Array = b.trail_positions()
	for k: int in range(1, trail.size()):
		assert_almost_eq(trail[k].y - trail[k - 1].y, float(TILE), 0.001)


func test_trail_glyph_inside_rule() -> void:
	var area: Rect2 = Arena.play_area()
	var size := Vector2(32, 8)
	assert_true(BossView.trail_glyph_inside(Vector2(256, 144), size, area))
	assert_false(BossView.trail_glyph_inside(Vector2(256, 286), size, area), "past the bottom edge: skipped")


# --- AC 13: the hum ---

func test_hum_stream_is_a_generated_loop() -> void:
	var wav: AudioStreamWAV = NullPointerHum.make_hum()
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, 22050)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(wav.loop_end, 22050)
	assert_eq(wav.data.size(), 22050 * 2)
	var hum := NullPointerHum.new()
	add_child_autofree(hum)
	assert_eq(hum.playback_type, AudioServer.PLAYBACK_TYPE_STREAM, "AD-09 fallback on this node only")
	assert_eq(hum.bus, &"SFX")


func test_hum_plays_only_during_a_live_fight() -> void:
	var b: NullPointerBody = _body()
	assert_true(NullPointerHum.should_play(b, true, false), "fight live")
	assert_false(NullPointerHum.should_play(null, true, false), "fight left (no boss)")
	assert_false(NullPointerHum.should_play(b, false, false), "audio still locked")
	assert_false(NullPointerHum.should_play(b, true, true), "paused")
	b.set_active(false)
	assert_false(NullPointerHum.should_play(b, true, false), "boss inactive (leave_fight)")
	b.set_active(true)
	b.take_hit(700)
	SimClock._pending_hitstop = 0
	assert_false(NullPointerHum.should_play(b, true, false), "defeated")


func test_hum_never_plays_for_another_boss() -> void:
	var hum := NullPointerHum.new()
	add_child_autofree(hum)
	var other := BossController.new()
	hum.sync_to(other)
	assert_false(hum.playing)
	hum.sync_to(null)
	assert_false(hum.playing)


# --- AC 2: the sky comment ---

func test_sky_comment_for_the_null_pointer_fight() -> void:
	assert_eq(Hud.sky_for(&"null_pointer"), "// FIXME: who owns this pointer?")
	assert_eq(Hud.sky_for(&"infinite_loop"), Hud.SKY, "Boss 1 keeps its sky row")
	assert_eq(Hud.sky_for(&""), Hud.SKY, "no boss: the default")
	assert_lte(Hud.SKY_NULL_POINTER.length(), Hud.COLS)


# --- AC 17: the empty pool runs GAP to GAP ---

func test_empty_pool_runs_gap_to_gap_without_error() -> void:
	var b: NullPointerBody = _body()
	for t: int in 600:
		b.tick(_ctx)
		assert_eq(b.state, BossController.BossState.GAP, "no attack picked (tick %d)" % t)
		assert_null(b.current)
	assert_null(b.current_attack())
	assert_push_error_count(0)
	# Phase 2 (50%): gap 60, still GAP after the ROAR.
	b.take_hit(350)
	assert_eq(b.phase_index, 1)
	assert_eq(b.current_weak_window(), Vector2i(A, D), "phase 2 window A->D")
	for t: int in 200:
		b.tick(_ctx)
	assert_eq(b.state, BossController.BossState.GAP)


func test_ghost_is_not_a_contact_hazard() -> void:
	var b: NullPointerBody = _body()
	assert_false(b.touches_player(b.body_center_px), "D-S51-8: no contact hazard until 5.2")


# --- AC 5, 6: the CombatResolver hooks with real actions ---

func _combat_rig(bits: Array) -> Dictionary:
	var buf := InputBuffer.new()
	var player := Player.new(load("res://data/player/player_def.tres") as PlayerDef, Arena.player_bounds())
	player.reset_for_fight(SPAWN)
	player.set_active(true)
	var reg := Register.new(buf)
	reg.set_active(true)
	assert_true(reg.set_fight_start(PackedInt32Array(bits)))
	var fsm := ActionStateMachine.new(buf, player, reg)
	fsm.reset_for_fight()
	fsm.set_active(true)
	var combat := CombatResolver.new(fsm, player)
	return {"buf": buf, "player": player, "reg": reg, "fsm": fsm, "combat": combat}


func _rig_tick(rig: Dictionary, t: int) -> void:
	_ctx.poll_frame = t
	(rig["reg"] as Register).tick(_ctx)
	(rig["fsm"] as ActionStateMachine).tick(_ctx)
	(rig["player"] as Player).tick(_ctx)
	(rig["combat"] as CombatResolver).tick(_ctx)


func test_a_real_slash_reveals_the_ghost_for_10_frames() -> void:
	var rig: Dictionary = _combat_rig([A, D])
	var b: NullPointerBody = _body()
	_place(b, SPAWN + Vector2(32, 0))
	(rig["combat"] as CombatResolver).boss = b
	(rig["buf"] as InputBuffer).push(J, 0)
	var t: int = 0
	while b.hp == 700 and t < 20:
		_rig_tick(rig, t)
		t += 1
	assert_lt(b.hp, 700, "the slash hit the invisible ghost")
	assert_eq(b.hit_reveal_left, NullPointerBody.HIT_REVEAL_FRAMES)
	assert_true(b.visible_now())
	assert_eq(b.pass_reveal_left, 0)


func test_a_real_echo_dash_reveals_the_ghost_for_60_frames() -> void:
	var rig: Dictionary = _combat_rig([D, L])
	var b: NullPointerBody = _body()
	_place(b, SPAWN + Vector2(56, 0))
	(rig["combat"] as CombatResolver).boss = b
	(rig["buf"] as InputBuffer).push(J, 0)
	var t: int = 0
	while t < 3:
		_rig_tick(rig, t)
		t += 1
	(rig["buf"] as InputBuffer).push(K, t)
	while b.pass_reveal_left == 0 and t < 30:
		_rig_tick(rig, t)
		t += 1
	assert_eq(b.pass_reveal_left, NullPointerBody.PASS_REVEAL_FRAMES)
	assert_eq(b.hp, 700, "no damage")
	assert_true(b.weak_window.is_patched(), "D->L pass-through Patches phase 1")
	assert_eq(b.hit_reveal_left, 0)
