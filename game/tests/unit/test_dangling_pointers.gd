extends GutTest
## Story 5.3 AC 1-12, 18-20: Dangling Pointers and its decoys on the real Null Pointer def. No scene
## tree: a test-only body forces the pick of one attack through the framework's _pick_candidates
## hook and is ticked directly with a seeded SimContext (the same pattern as
## test_null_pointer_attacks).

const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const DANGLING: AttackDef = preload("res://data/bosses/null_pointer/attack_dangling_pointers.tres")
const GRAB: AttackDef = preload("res://data/bosses/null_pointer/attack_pointer_grab.tres")
const DanglingPointers := preload("res://src/bosses/null_pointer/attacks/dangling_pointers.gd")
const S := BossController.BossState

const TILE := Const.TILE_PX
const SEED := 5353


## Test-only body: draws only `only` (a cache index) when set.
class ForcedBody:
	extends NullPointerBody
	var only: int = -1

	func _pick_candidates(p: int) -> PackedInt32Array:
		return PackedInt32Array([only]) if only >= 0 else super(p)


var _ctx: SimContext
var _arena: ArenaContext


func before_each() -> void:
	_ctx = SimContext.new()
	_ctx.reseed(SEED)
	_arena = ArenaContext.new()
	_arena.target_source = func() -> Vector2: return Vector2(200, 150)
	_arena.contact_source = func() -> Vector2: return Vector2(40, 40)
	SimClock._pending_hitstop = 0


func after_each() -> void:
	SimClock._pending_hitstop = 0


## A reset body in phase 2 (ROAR over) that will only draw `attack_def`.
func _body(attack_def: AttackDef = DANGLING, seed_value: int = SEED) -> ForcedBody:
	_ctx.reseed(seed_value)
	var b := ForcedBody.new()
	assert_true(b.setup(NP_DEF, null, _arena))
	b.reset_for_fight()
	b.only = b._defs.find(attack_def)
	assert_gte(b.only, 0)
	b.take_hit(350)
	assert_eq(b.phase_index, 1)
	assert_true(_run_until(b, S.GAP))
	return b


func _run_until(b: BossController, state: S, limit: int = 2000) -> bool:
	for i: int in limit:
		if b.state == state:
			return true
		b.tick(_ctx)
	return b.state == state


func _length_of_state(b: BossController) -> int:
	var s: S = b.state
	var n: int = 0
	while b.state == s and n < 2000:
		b.tick(_ctx)
		n += 1
	return n


## True when `p` lies inside the play area inset by the spot rule's 2 tiles.
static func _inside_inset(p: Vector2) -> bool:
	var r: Rect2 = Arena.play_area().grow(-2.0 * TILE)
	return p.x >= r.position.x and p.y >= r.position.y and p.x <= r.end.x and p.y <= r.end.y


# --- AC 1-3: the attack's states ---

func test_tell_is_30_frames_with_two_null_flickers_and_no_decoy() -> void:
	var b: ForcedBody = _body()
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, DANGLING)
	var attack: BossAttack = b.current_attack()
	assert_eq(attack.tell_glyph(), "null", "D-S53-9: a null flicker, not !")
	assert_eq(attack.tell_marks().size(), 0, "planned on the first TELL tick")
	b.tick(_ctx)
	assert_eq(attack.tell_marks().size(), 2, "two spots marked")
	assert_eq(attack.tell_marks(), b.planned_positions())
	assert_eq(b.decoys.size(), 0, "no decoy during the tell")
	assert_false(attack.hazard_hit(attack.tell_marks()[0]), "nothing hurts")
	assert_eq(_length_of_state(b) + 1, 30, "TELL lasts 30 frames")
	assert_eq(b.state, S.ACTIVE)


func test_active_spawns_the_two_decoys_and_arms_the_recast() -> void:
	var b: ForcedBody = _body()
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	var spots: PackedVector2Array = b.planned_positions()
	assert_true(_run_until(b, S.ACTIVE))
	assert_eq(b.decoys.size(), 0, "the spawn runs on the first ACTIVE tick")
	b.tick(_ctx)
	assert_eq(b.decoy_positions(), spots, "the planned spots became decoys")
	assert_eq(b.planned.size(), 0)
	assert_eq(b.recast_left, NullPointerBody.RECAST_TICKS, "the 15 s re-cast is armed")
	assert_eq(_length_of_state(b) + 1, 60, "ACTIVE lasts 60 frames")
	assert_eq(b.decoys.size(), 2, "spawned once")


func test_recovery_is_30_frames_visible_and_dangling_never_hurts() -> void:
	var b: ForcedBody = _body()
	var attack: BossAttack = b.attack_for(DANGLING)
	assert_true(_run_until(b, S.RECOVERY))
	var n: int = 0
	while b.state == S.RECOVERY:
		assert_true(b.visible_now(), "visible in recovery (Story 5.1)")
		assert_false(attack.hazard_hit(Vector2(200, 150)))
		b.tick(_ctx)
		n += 1
	assert_eq(n, 30)
	assert_false(b.touches_player(b.body_center_px), "no contact hazard")


# --- AC 7, 8: spot rule, cap and determinism ---

func test_spots_follow_the_rule() -> void:
	for seed_value: int in [1, 2, 3, 99, 5353]:
		var b: ForcedBody = _body(DANGLING, seed_value)
		assert_true(_run_until(b, S.TELL))
		b.tick(_ctx)
		var spots: Array[Vector2i] = b.planned
		assert_eq(spots.size(), 2, "seed %d" % seed_value)
		for i: int in spots.size():
			assert_true(_inside_inset(NullPointerBody.spot_px(spots[i])), "inset 2 tiles (seed %d)" % seed_value)
			assert_gte(Vector2(spots[i] - b.pos_mtiles).length(), float(NullPointerBody.SPOT_MIN_DIST_MTILES), "4 tiles from the body")
			for k: int in range(i + 1, spots.size()):
				assert_gte(Vector2(spots[i] - spots[k]).length(), float(NullPointerBody.SPOT_MIN_DIST_MTILES), "4 tiles apart")


func test_the_same_seed_gives_the_same_spots() -> void:
	var a: ForcedBody = _body(DANGLING, 77)
	assert_true(_run_until(a, S.TELL))
	a.tick(_ctx)
	var first: Array[Vector2i] = a.planned.duplicate()
	var b: ForcedBody = _body(DANGLING, 77)
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	assert_eq(b.planned, first)


func test_plan_spots_keeps_away_from_live_decoys_and_gives_fewer_when_none_fit() -> void:
	var b: ForcedBody = _body()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	b.decoys.append(Vector2i(8000, 8000))
	for p: Vector2i in b.plan_spots(rng, 2):
		assert_gte(Vector2(p - Vector2i(8000, 8000)).length(), float(NullPointerBody.SPOT_MIN_DIST_MTILES))
	# Fill the inset with live spots 3 tiles apart: no new spot can be 4 tiles from all of them.
	b.decoys.clear()
	for x: int in range(2000, 31000, 3000):
		for y: int in range(2000, 17000, 3000):
			b.decoys.append(Vector2i(x, y))
	assert_eq(b.plan_spots(rng, 2).size(), 0, "32 tries per spot, none fit")


func test_the_cap_limits_a_cast_to_the_room_left() -> void:
	var b: ForcedBody = _body()
	b.decoys.append(Vector2i(3000, 3000))
	b.decoys.append(Vector2i(29000, 3000))
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	assert_eq(b.planned.size(), 1, "one slot left: one spot")
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(b.decoys.size(), NullPointerBody.DECOY_CAP)
	# A full cap: the next cast does nothing.
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	assert_eq(b.planned.size(), 0, "no room, no spot")
	assert_eq(b.current_attack().tell_marks().size(), 0, "no flicker")
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(b.decoys.size(), NullPointerBody.DECOY_CAP)


# --- AC 6: the re-cast ---

func test_recast_after_900_ticks_flickers_30_then_spawns() -> void:
	var b: ForcedBody = _body()
	assert_true(_run_until(b, S.ACTIVE))
	b.tick(_ctx) # spawn, timer armed
	assert_eq(b.decoys.size(), 2)
	b.only = b._defs.find(GRAB) # no further Dangling cast: only the body's cycle
	b.decoys.remove_at(0) # room for both re-cast spots minus one: room 2
	for i: int in NullPointerBody.RECAST_TICKS - 1:
		b.tick(_ctx)
		assert_eq(b.recast_flicker_positions().size(), 0, "no flicker before the timer (tick %d)" % i)
	b.tick(_ctx)
	assert_eq(b.recast_flicker_positions().size(), 2, "two spots flicker")
	assert_eq(b.recast_left, NullPointerBody.RECAST_TICKS, "re-armed")
	assert_eq(b.decoys.size(), 1)
	for i: int in NullPointerBody.CAST_FLICKER_FRAMES - 1:
		b.tick(_ctx)
		assert_eq(b.decoys.size(), 1, "spawned after the flicker")
	b.tick(_ctx)
	assert_eq(b.decoys.size(), 3)
	assert_eq(b.recast_flicker_positions().size(), 0)
	# Full: the next re-cast flickers nothing and spawns nothing.
	for i: int in NullPointerBody.RECAST_TICKS:
		b.tick(_ctx)
	assert_eq(b.recast_flicker_positions().size(), 0, "0 room = no flicker at all")
	assert_eq(b.decoys.size(), 3)


func test_a_900_tick_seeded_run_keeps_every_spot_inside() -> void:
	var b: ForcedBody = _body()
	var max_alive: int = 0
	for t: int in 2000:
		b.tick(_ctx)
		for p: Vector2 in b.decoy_positions() + b.planned_positions() + b.recast_flicker_positions():
			assert_true(_inside_inset(p), "spot inside at tick %d" % t)
		max_alive = maxi(max_alive, b.decoys.size())
		# Dispel one now and then so re-casts have room.
		if t % 500 == 499 and not b.decoys.is_empty():
			b.decoys.remove_at(0)
	assert_lte(max_alive, NullPointerBody.DECOY_CAP)
	assert_eq(max_alive, NullPointerBody.DECOY_CAP, "the cap was reached")


# --- AC 9: decoys are not part of the ghost ---

func test_decoys_never_make_the_ghost_visible() -> void:
	var b: ForcedBody = _body(GRAB)
	b.decoys.append(Vector2i(5000, 5000))
	assert_eq(b.state, S.GAP)
	assert_false(b.visible_now(), "decoys are not the ghost")
	b.set_watch_held(true)
	assert_true(b.visible_now(), "Watch shows the real body (5.4 keeps decoys out)")


# --- AC 10, 11: dispel ---

func test_a_hit_shape_dispels_each_overlapped_decoy_once_with_a_10_frame_flash() -> void:
	var b: ForcedBody = _body(GRAB)
	var near := Vector2i(10000, 9000)
	var far := Vector2i(25000, 9000)
	b.decoys.append(near)
	b.decoys.append(far)
	var shape: HitShape = Defs.SLASH_1.hit_shape
	var origin: Vector2 = NullPointerBody.spot_px(near) - Vector2(TILE, 0)
	var hp: int = b.hp
	assert_eq(b.decoy_hit(shape, origin, Vector2.RIGHT), 1)
	assert_eq(b.decoys, [far] as Array[Vector2i])
	assert_eq(b.decoy_hit(shape, origin, Vector2.RIGHT), 0, "once")
	assert_eq(b.hp, hp, "no damage")
	assert_eq(b.hit_reveal_left, 0, "not a boss hit: no reveal")
	assert_eq(b.dispel_flash_positions(), PackedVector2Array([NullPointerBody.spot_px(near)]))
	for i: int in NullPointerBody.DISPEL_FLASH_FRAMES - 1:
		b.tick(_ctx)
		assert_eq(b.dispel_flash_positions().size(), 1, "flash frame %d" % (i + 2))
	b.tick(_ctx)
	assert_eq(b.dispel_flash_positions().size(), 0, "10 frames")


func test_combat_resolver_dispels_and_requests_hitstop() -> void:
	var b: ForcedBody = _body(GRAB)
	var spot := Vector2i(10000, 9000)
	b.decoys.append(spot)
	var fsm := ActionStateMachine.new()
	fsm.action = Defs.SLASH_1
	fsm.action_frame = Defs.SLASH_1.startup_frames + 1
	fsm.state = ActionStateMachine.ActionState.ACTIVE
	fsm.action_serial = 7
	fsm.facing = Vector2i(1, 0)
	fsm.action_origin_px = NullPointerBody.spot_px(spot) - Vector2(TILE, 0)
	var combat := CombatResolver.new(fsm, null)
	combat.boss = b
	watch_signals(EventBus)
	combat.tick(_ctx)
	assert_eq(b.decoys.size(), 0)
	assert_eq(SimClock._pending_hitstop, HitFeedback.hitstop_for(false, Defs.SLASH_1.hitstop_frames))
	assert_signal_not_emitted(EventBus, "hit_landed", "a dispel is not a hit on the boss")
	assert_false(b.was_hit_by(7))


func test_echo_dash_does_not_dispel() -> void:
	var b: ForcedBody = _body(GRAB)
	var spot := Vector2i(10000, 9000)
	b.decoys.append(spot)
	var fsm := ActionStateMachine.new()
	fsm.action = Defs.ECHO_DASH
	fsm.action_frame = Defs.ECHO_DASH.startup_frames + 1
	fsm.state = ActionStateMachine.ActionState.ACTIVE
	fsm.action_serial = 8
	fsm.action_origin_px = NullPointerBody.spot_px(spot) - Vector2(TILE, 0)
	var combat := CombatResolver.new(fsm, null)
	combat.boss = b
	combat.tick(_ctx)
	assert_eq(b.decoys.size(), 1, "a pass-through action never dispels")


# --- AC 12: clears ---

func _seed_decoys(b: NullPointerBody) -> void:
	b.decoys.append(Vector2i(5000, 5000))
	b.recast_spots.append(Vector2i(20000, 5000))
	b.recast_flicker_left = 10
	b.recast_left = 300
	b.flash_spots.append(Vector2i(9000, 9000))
	b.flash_left.append(5)


func _assert_cleared(b: NullPointerBody, why: String) -> void:
	assert_eq(b.decoys.size(), 0, why)
	assert_eq(b.planned.size(), 0, why)
	assert_eq(b.recast_flicker_positions().size(), 0, why)
	assert_eq(b.recast_left, 0, why)
	assert_eq(b.dispel_flash_positions().size(), 0, why)


func test_roar_clears_everything() -> void:
	var b := ForcedBody.new()
	assert_true(b.setup(NP_DEF, null, _arena))
	b.reset_for_fight()
	_seed_decoys(b)
	b.take_hit(350)
	assert_eq(b.state, S.ROAR)
	_assert_cleared(b, "phase change")


func test_defeat_and_retry_clear_everything() -> void:
	var b: ForcedBody = _body()
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	_seed_decoys(b)
	b.take_hit(b.hp)
	assert_eq(b.state, S.DEFEATED)
	_assert_cleared(b, "defeat")
	var c: ForcedBody = _body()
	_seed_decoys(c)
	c.reset_for_fight()
	_assert_cleared(c, "retry")


func test_on_cancel_clears_the_plan() -> void:
	var b: ForcedBody = _body()
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	assert_eq(b.planned.size(), 2)
	b.current_attack().on_cancel(_arena)
	assert_eq(b.planned.size(), 0)
	assert_true(_run_until(b, S.ACTIVE))
	b.tick(_ctx)
	assert_eq(b.decoys.size(), 0, "a cancelled cast spawns nothing")


# --- AC 18: isolation and declared positions ---

func test_declared_positions_lie_inside_the_play_area_against_every_corner() -> void:
	var b: ForcedBody = _body()
	assert_true(_run_until(b, S.TELL))
	b.tick(_ctx)
	var attack: BossAttack = b.current_attack()
	var area: Rect2 = Arena.play_area()
	for corner: Vector2 in [area.position, Vector2(area.end.x, 0), Vector2(0, area.end.y), area.end]:
		var ctx := ArenaContext.new()
		ctx.target_source = func() -> Vector2: return corner
		var pts: PackedVector2Array = attack.declared_positions(ctx)
		assert_gte(pts.size(), 6, "the two spots and the inset's corners")
		for p: Vector2 in pts:
			assert_true(ArenaContext.inside_play_area(p), "%s inside (aim %s)" % [p, corner])


func test_the_script_is_scanned_by_the_isolation_guard() -> void:
	var files: PackedStringArray = load("res://tests/unit/test_attack_isolation.gd").attack_files()
	assert_true(files.has("res://src/bosses/null_pointer/attacks/dangling_pointers.gd"))
	var code: String = load("res://tests/unit/test_attack_isolation.gd").code_of("res://src/bosses/null_pointer/attacks/dangling_pointers.gd")
	assert_eq(load("res://tests/unit/test_attack_isolation.gd").violations(code), PackedStringArray())
	assert_true(DanglingPointers.new() is BossAttack)
