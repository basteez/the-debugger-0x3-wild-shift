extends GutTest
## Story 5.2 AC 1-6, 9, 10, 12, 13: Pointer Grab and Null Rain on the real Null Pointer def. No
## scene tree: the body is ticked directly with an ArenaContext whose aim, facing and contact
## position the test drives, and a PlayerHealth ticked after it (SimClock order: BOSS_HAZARDS
## queues the hit, the health resolves it). A test-only body forces the pick through the
## framework's _pick_candidates hook, so every attack runs through the real FSM.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const GRAB: AttackDef = preload("res://data/bosses/null_pointer/attack_pointer_grab.tres")
const RAIN: AttackDef = preload("res://data/bosses/null_pointer/attack_null_rain.tres")
const PointerGrab := preload("res://src/bosses/null_pointer/attacks/pointer_grab.gd")
const NullRain := preload("res://src/bosses/null_pointer/attacks/null_rain.gd")
const TILE := Const.TILE_PX
const S := BossController.BossState
const AIM := Vector2(200, 150)


## Test-only body: draws only `only` (a cache index) when set.
class ForcedBody:
	extends NullPointerBody
	var only: int = -1

	func _pick_candidates(p: int) -> PackedInt32Array:
		return PackedInt32Array([only]) if only >= 0 else super(p)


## Test-only FSM whose dash invulnerability is set by the test.
class FakeActions:
	extends ActionStateMachine
	var invuln: bool = false

	func invulnerable() -> bool:
		return invuln


var _ctx: SimContext
var _arena: ArenaContext
var _player_px: Vector2
var _target_px: Vector2
var _facing: Vector2i
var _health: PlayerHealth
var _saved_state: int


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal contact never records a death
	_ctx = SimContext.new()
	_ctx.reseed(5252)
	_arena = ArenaContext.new()
	_target_px = AIM
	_player_px = Vector2(40, 40) # far from every hazard unless a test moves it
	_facing = Vector2i(1, 0)
	_arena.target_source = func() -> Vector2: return _target_px
	_arena.contact_source = func() -> Vector2: return _player_px
	_arena.facing_source = func() -> Vector2i: return _facing
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


func _make_health(invuln: bool = false) -> PlayerHealth:
	var actions := FakeActions.new()
	actions.invuln = invuln
	var h := PlayerHealth.new(PLAYER_DEF, actions)
	h.reset_for_fight()
	h.set_active(true)
	return h


## A reset body that will only draw `attack_def`.
func _body(attack_def: AttackDef, invuln: bool = false) -> ForcedBody:
	_health = _make_health(invuln)
	var b := ForcedBody.new()
	assert_true(b.setup(NP_DEF, _health, _arena))
	b.reset_for_fight()
	b.only = b._defs.find(attack_def)
	assert_gte(b.only, 0)
	return b


## One sim tick in SimClock order: the boss (queues contact), then the player's health.
func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)
		_health.tick(_ctx)


## Ticks until the boss enters `state` (at most `limit` ticks). True when reached.
func _run_until(b: BossController, state: S, limit: int = 400) -> bool:
	for i: int in limit:
		if b.state == state:
			return true
		_tick(b)
	return b.state == state


## Ticks counted while the boss stays in its current state.
func _length_of_state(b: BossController) -> int:
	var s: S = b.state
	var n: int = 0
	while b.state == s and n < 1000:
		_tick(b)
		n += 1
	return n


# --- AC 1-3: Pointer Grab ---

func test_grab_tell_is_40_frames_with_a_star_behind_the_aim_and_no_damage() -> void:
	var b: ForcedBody = _body(GRAB)
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, GRAB)
	var grab: BossAttack = b.current_attack()
	var centre: Vector2 = AIM - Vector2(PointerGrab.GRAB_OFFSET_TILES * TILE, 0)
	assert_eq(grab.tell_marks(), PackedVector2Array([centre]), "the `*` sits behind the aim (facing right)")
	assert_eq(grab.tell_glyph(), "*")
	assert_eq(grab.outline_circle(), Vector3(centre.x, centre.y, TILE), "the grab circle is outlined")
	_player_px = centre # standing on the `*` during the tell is safe
	_tick(b, 39)
	assert_eq(b.state, S.TELL, "the entry tick plus 39")
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "no damage during the tell")
	_tick(b)
	assert_eq(b.state, S.ACTIVE, "40 TELL frames, then the grab")


func test_grab_centre_is_locked_at_tell_entry() -> void:
	var b: ForcedBody = _body(GRAB)
	_facing = Vector2i(0, 1) # facing down: the `*` is above
	assert_true(_run_until(b, S.TELL))
	var grab: BossAttack = b.current_attack()
	var locked: Vector2 = AIM - Vector2(0, PointerGrab.GRAB_OFFSET_TILES * TILE)
	assert_eq(grab.tell_marks()[0], locked)
	_target_px = AIM + Vector2(100, 50)
	_facing = Vector2i(-1, 0)
	_tick(b, 10)
	assert_eq(grab.tell_marks()[0], locked, "moving during the tell does not move the grab")


func test_grab_centre_behind_every_facing() -> void:
	for f: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var c: Vector2 = PointerGrab.grab_centre(AIM, f)
		assert_almost_eq(c.distance_to(AIM), PointerGrab.GRAB_OFFSET_TILES * TILE, 0.001, "offset for %s" % f)
		assert_lt((c - AIM).dot(Vector2(f)), 0.0, "behind for %s" % f)
		assert_lt(c.distance_to(AIM), PointerGrab.radius_px(), "a player who ignores the tell is inside (%s)" % f)


func test_grab_active_is_10_frames_and_hits_inside_the_circle_once() -> void:
	var b: ForcedBody = _body(GRAB)
	assert_true(_run_until(b, S.TELL))
	_player_px = AIM # stood still: inside the circle
	assert_true(_run_until(b, S.ACTIVE))
	assert_eq(_length_of_state(b), 10)
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "1 HP, invulnerability stops a second hit")
	assert_eq(b.state, S.RECOVERY)


func test_grab_misses_a_player_outside_the_circle() -> void:
	var b: ForcedBody = _body(GRAB)
	assert_true(_run_until(b, S.TELL))
	var centre: Vector2 = b.current_attack().tell_marks()[0]
	_player_px = centre + Vector2(TILE + 1, 0) # just past the radius
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(_health.hp, PLAYER_DEF.max_hp)


func test_grab_edge_is_inside() -> void:
	var b: ForcedBody = _body(GRAB)
	assert_true(_run_until(b, S.TELL))
	var centre: Vector2 = b.current_attack().tell_marks()[0]
	_player_px = centre + Vector2(0, TILE)
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1)


func test_grab_honours_invulnerability() -> void:
	var b: ForcedBody = _body(GRAB, true)
	assert_true(_run_until(b, S.TELL))
	_player_px = AIM
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "a dash's invulnerable frames dodge the grab")


func test_grab_recovery_is_60_visible_frames_without_damage() -> void:
	var b: ForcedBody = _body(GRAB)
	assert_true(_run_until(b, S.RECOVERY))
	_player_px = AIM
	var grab: BossAttack = b.current_attack()
	var n: int = 0
	while b.state == S.RECOVERY:
		assert_true(b.visible_now(), "visible in recovery (frame %d)" % n)
		assert_false(b.touches_player(_player_px))
		assert_eq(grab.tell_marks().size(), 0)
		assert_eq(grab.outline_circle(), Vector3.ZERO)
		_tick(b)
		n += 1
	assert_eq(n, 60)
	assert_eq(_health.hp, PLAYER_DEF.max_hp)
	assert_eq(b.state, S.GAP)


# --- AC 4-6: Null Rain ---

func test_rain_tell_is_45_frames_with_five_2x2_areas_and_no_damage() -> void:
	var b: ForcedBody = _body(RAIN)
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, RAIN)
	var rain: BossAttack = b.current_attack()
	var rects: Array[Rect2] = rain.hazard_rects()
	assert_eq(rects.size(), 5)
	for r: Rect2 in rects:
		assert_eq(r.size, Vector2(2 * TILE, 2 * TILE), "exactly 2 x 2 tiles")
		assert_eq(fmod(r.position.x, TILE), 0.0, "snapped to the tile grid")
		assert_eq(fmod(r.position.y, TILE), 0.0)
	assert_true(NullRain.inside(rects[0], AIM), "the centre area covers the aim")
	assert_eq(rain.tell_marks().size(), 0, "outline only")
	_player_px = rects[0].get_center()
	_tick(b, 44)
	assert_eq(b.state, S.TELL)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "no damage during the tell")
	_tick(b)
	assert_eq(b.state, S.ACTIVE, "45 TELL frames, then the rain")


func test_rain_active_is_20_frames_and_hits_in_any_area() -> void:
	for k: int in 5:
		var b: ForcedBody = _body(RAIN)
		assert_true(_run_until(b, S.TELL))
		_player_px = b.current_attack().hazard_rects()[k].get_center()
		assert_true(_run_until(b, S.ACTIVE))
		assert_eq(b.current_attack().hazard_rects().size(), 5, "drawn while ACTIVE (D-S52-10)")
		assert_eq(_length_of_state(b), 20)
		assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "area %d hits" % k)


func test_rain_misses_a_player_outside_every_area() -> void:
	var b: ForcedBody = _body(RAIN)
	assert_true(_run_until(b, S.TELL))
	_player_px = AIM + Vector2(3 * TILE, 0) # between the centre and the side areas
	for r: Rect2 in b.current_attack().hazard_rects():
		assert_false(NullRain.inside(r, _player_px))
	assert_true(_run_until(b, S.RECOVERY))
	assert_eq(_health.hp, PLAYER_DEF.max_hp)


func test_rain_recovery_is_40_visible_frames_without_areas() -> void:
	var b: ForcedBody = _body(RAIN)
	assert_true(_run_until(b, S.RECOVERY))
	var rain: BossAttack = b.current_attack()
	_player_px = AIM
	var n: int = 0
	while b.state == S.RECOVERY:
		assert_true(b.visible_now())
		assert_eq(rain.hazard_rects().size(), 0, "no area drawn in recovery")
		assert_false(rain.hazard_hit(AIM))
		_tick(b)
		n += 1
	assert_eq(n, 40)
	assert_eq(_health.hp, PLAYER_DEF.max_hp)


func test_rain_areas_clamp_into_the_play_area() -> void:
	var area: Rect2 = Arena.play_area()
	for aim: Vector2 in [Vector2.ZERO, Vector2(area.end.x, 0), Vector2(0, area.end.y), area.end]:
		for r: Rect2 in NullRain.areas_for(aim):
			assert_true(area.encloses(r), "%s in the play area (aim %s)" % [r, aim])
			assert_eq(r.size, Vector2(2 * TILE, 2 * TILE))


# --- AC 9, 10: hazard gates, cancel, no body contact ---

func test_hazard_is_live_only_in_active() -> void:
	for a_def: AttackDef in [GRAB, RAIN]:
		var b: ForcedBody = _body(a_def)
		_player_px = AIM
		assert_false(b.attack_hazard_hit(AIM), "GAP")
		assert_true(_run_until(b, S.TELL))
		assert_false(b.attack_hazard_hit(AIM), "TELL")
		assert_false(b.current_attack().hazard_hit(AIM), "TELL (attack)")
		assert_true(_run_until(b, S.ACTIVE))
		assert_true(b.attack_hazard_hit(AIM), "ACTIVE (%s)" % a_def.id)
		assert_true(_run_until(b, S.RECOVERY))
		assert_false(b.attack_hazard_hit(AIM), "RECOVERY")
		assert_true(_run_until(b, S.GAP))
		assert_false(b.attack_hazard_hit(AIM), "GAP after")


func test_phase_change_mid_attack_cancels_without_recovery() -> void:
	for a_def: AttackDef in [GRAB, RAIN]:
		_player_px = Vector2(40, 40) # away from the hazards until the cut
		var b: ForcedBody = _body(a_def)
		assert_true(_run_until(b, S.ACTIVE))
		var attack: BossAttack = b.current_attack()
		b.take_hit(350) # phase 2
		assert_eq(b.state, S.ROAR)
		assert_null(b.current_attack())
		assert_eq(attack.tell_marks().size(), 0, "%s: cleared" % a_def.id)
		assert_eq(attack.hazard_rects().size(), 0)
		assert_eq(attack.outline_circle(), Vector3.ZERO)
		assert_false(attack.hazard_hit(AIM))
		_player_px = AIM
		for i: int in BossController.ROAR_FRAMES:
			assert_false(b.touches_player(AIM), "ROAR")
			_tick(b)
		assert_eq(_health.hp, PLAYER_DEF.max_hp, "%s: no hit after the cancel" % a_def.id)


func test_defeat_mid_attack_clears_the_hazard() -> void:
	var b: ForcedBody = _body(RAIN)
	assert_true(_run_until(b, S.ACTIVE))
	var attack: BossAttack = b.current_attack()
	b.take_hit(700)
	assert_eq(b.state, S.DEFEATED)
	assert_eq(attack.hazard_rects().size(), 0)
	assert_false(b.attack_hazard_hit(AIM))
	assert_false(b.touches_player(AIM))
	var g: ForcedBody = _body(GRAB)
	assert_true(_run_until(g, S.TELL))
	var grab: BossAttack = g.current_attack()
	g.take_hit(700)
	assert_eq(grab.tell_marks().size(), 0)
	assert_false(grab.hazard_hit(AIM))


func test_the_ghost_body_never_touches_the_player() -> void:
	var b: ForcedBody = _body(GRAB)
	for i: int in 400:
		var p: Vector2 = b.body_center_px
		assert_eq(b.touches_player(p), b.attack_hazard_hit(p), "D-S52-1: only the attack's hazard (tick %d)" % i)
		if b.state != S.ACTIVE:
			assert_false(b.touches_player(p), "D-S52-1: the ghost body is harmless (tick %d, %s)" % [i, S.keys()[b.state]])
		_tick(b)


func test_reset_clears_both_attacks() -> void:
	var b: ForcedBody = _body(RAIN)
	assert_true(_run_until(b, S.ACTIVE))
	var rain: BossAttack = b.current_attack()
	b.reset_for_fight()
	assert_eq(rain.hazard_rects().size(), 0)
	var grab := PointerGrab.new()
	grab.on_tell(_arena)
	grab.reset()
	assert_false(grab.armed)
	assert_eq(grab.centre_px, Vector2.ZERO)


# --- AC 12, 13: determinism, on-screen positions ---

func test_same_aim_gives_the_same_areas_and_no_rng_is_drawn() -> void:
	var r1 := NullRain.new()
	var r2 := NullRain.new()
	r1.on_tell(_arena)
	r2.on_tell(_arena)
	assert_eq(r1.areas, r2.areas)
	var g1 := PointerGrab.new()
	var g2 := PointerGrab.new()
	g1.on_tell(_arena)
	g2.on_tell(_arena)
	assert_eq(g1.centre_px, g2.centre_px)
	var files: PackedStringArray = load("res://tests/unit/test_attack_isolation.gd").attack_files()
	assert_true(files.has("res://src/bosses/null_pointer/attacks/pointer_grab.gd"), "the isolation guard scans the grab")
	assert_true(files.has("res://src/bosses/null_pointer/attacks/null_rain.gd"), "and the rain")


func test_attack_runs_are_deterministic_for_a_seed() -> void:
	# The only draws are the body's drift and the framework's pick; a run with the same seed twice
	# gives the same areas, the same pick sequence and the same ghost position.
	var runs: Array = []
	for run: int in 2:
		_ctx.reseed(777)
		var b: ForcedBody = _body(RAIN)
		b.only = -1
		var trace: Array = []
		for i: int in 900:
			_tick(b)
			if b.state == S.TELL and b.frames_left == b.current.tell:
				trace.append([i, b.current.id, b.current_attack().hazard_rects().duplicate()])
		trace.append(b.pos_mtiles)
		runs.append(trace)
	assert_eq(runs[0], runs[1])
	assert_gt(runs[0].size(), 3, "several attacks ran")


func test_declared_positions_are_on_screen_for_every_corner_aim() -> void:
	var area: Rect2 = Arena.play_area()
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(area.end.x, 0), Vector2(0, area.end.y), area.end]
	for a_def: AttackDef in [GRAB, RAIN]:
		var attack: BossAttack = a_def.attack_script.new()
		for c: Vector2 in corners:
			_target_px = c
			for f: Vector2i in [Vector2i(1, 0), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(1, 1)]:
				_facing = f
				var points: PackedVector2Array = attack.declared_positions(_arena)
				assert_gt(points.size(), 0)
				for p: Vector2 in points:
					assert_true(ArenaContext.inside_play_area(p), "%s: %s off-screen (aim %s, facing %s)" % [a_def.id, p, c, f])


func test_target_facing_defaults_right_and_never_zero() -> void:
	var c := ArenaContext.new()
	assert_eq(c.target_facing(), Vector2i(1, 0), "default facing is right")
	c.facing_source = func() -> Vector2i: return Vector2i.ZERO
	assert_eq(c.target_facing(), Vector2i(1, 0), "zero falls back to right")
	c.facing_source = func() -> Vector2i: return Vector2i(0, -1)
	assert_eq(c.target_facing(), Vector2i(0, -1), "the source is read")
	c.facing_source = Callable()
	assert_eq(c.target_facing(), Vector2i(1, 0), "an invalid Callable falls back to right")


func test_null_ctx_is_safe_for_declared_positions_and_on_tell() -> void:
	var g := PointerGrab.new()
	g.on_tell(null)
	assert_false(g.armed)
	assert_eq(g.declared_positions(null).size(), 0)
	var r := NullRain.new()
	r.on_tell(null)
	assert_eq(r.declared_positions(null).size(), 0)


func test_hazard_rects_is_a_copy() -> void:
	var r := NullRain.new()
	r.areas = NullRain.areas_for(Vector2(200, 100))
	r.hazard_rects().clear()
	assert_eq(r.areas.size(), 5, "mutating the returned array does not touch the hazard")
