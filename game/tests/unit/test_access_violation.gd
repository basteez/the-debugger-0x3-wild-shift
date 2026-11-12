extends GutTest
## Story 6.3 AC 14-19: Access Violation on the real Segfault def. No scene tree: the body is
## ticked directly with an ArenaContext whose aim and contact position the test drives, and a
## PlayerHealth ticked after it (SimClock order). Story 6.4: the pools now hold the tile attacks too,
## so ClawBody narrows the candidates to Access Violation (cache index 0, first in every pool); the
## real FSM still runs the attack.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const CLAW: AttackDef = preload("res://data/bosses/segfault/attack_access_violation.tres")
const AccessViolation := preload("res://src/bosses/segfault/attacks/access_violation.gd")
const TILE := Const.TILE_PX
const S := BossController.BossState

var _ctx: SimContext
var _arena: ArenaContext
var _player_px: Vector2
var _target_px: Vector2
var _health: PlayerHealth
var _saved_state: int
var _tells: Array = []


## Story 6.4: the real Segfault body with Access Violation as its only candidate.
class ClawBody:
	extends SegfaultBody

	var _claw_only := PackedInt32Array([0])

	func _pick_candidates(_phase: int) -> PackedInt32Array:
		return _claw_only


class FakeActions:
	extends ActionStateMachine

	func invulnerable() -> bool:
		return false


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal contact never records a death
	_ctx = SimContext.new()
	_ctx.reseed(6363)
	_arena = ArenaContext.new()
	_player_px = Vector2(-1000, -1000) # nowhere unless a test moves it
	_target_px = Vector2(300, 150)
	_arena.target_source = func() -> Vector2: return _target_px
	_arena.contact_source = func() -> Vector2: return _player_px
	_tells.clear()
	EventBus.boss_tell_started.connect(_on_tell)
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	EventBus.boss_tell_started.disconnect(_on_tell)
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


func _on_tell(id: StringName, sfx: StringName) -> void:
	_tells.append([id, sfx])


func _body() -> SegfaultBody:
	_health = PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	_health.reset_for_fight()
	_health.set_active(true)
	var b := ClawBody.new()
	assert_true(b.setup(SF_DEF, _health, _arena))
	assert_eq(b.attack_for(CLAW), b._attacks[0], "the claw is cache index 0")
	b.reset_for_fight()
	return b


func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)
		_health.tick(_ctx)


func _run_until(b: BossController, state: S, limit: int = 400) -> bool:
	for i: int in limit:
		if b.state == state:
			return true
		_tick(b)
	return b.state == state


func _length_of_state(b: BossController) -> int:
	var s: S = b.state
	var n: int = 0
	while b.state == s and n < 1000:
		_tick(b)
		n += 1
	return n


# --- AC 14-15, 16: timings, tell drawing, the tell SFX path ---

func test_tell_30_active_12_recovery_50() -> void:
	var b: SegfaultBody = _body()
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, CLAW)
	assert_eq(_tells, [[&"access_violation", &"tell_access_violation"]], "D-S31-16 tell path")
	assert_eq(_length_of_state(b), 30)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(_length_of_state(b), 12)
	assert_eq(b.state, S.RECOVERY)
	assert_eq(_length_of_state(b), 50)
	assert_eq(b.state, S.GAP)


func test_tell_draws_the_claw_arc_and_the_exact_rectangle() -> void:
	var b: SegfaultBody = _body()
	assert_true(_run_until(b, S.TELL))
	var claw: BossAttack = b.current_attack()
	var origin: Vector2 = b.body_center_px + Vector2(0, 2 * TILE)
	assert_eq(claw.tell_marks(), PackedVector2Array([origin]), "the `!` over the claw origin")
	var rects: Array[Rect2] = claw.hazard_rects()
	assert_eq(rects.size(), 1)
	assert_eq(rects[0].size, Vector2(6 * TILE, 2 * TILE), "D-S63-3: 6 x 2 tiles")
	var arc: PackedVector2Array = claw.call(&"claw_arc")
	assert_gt(arc.size(), 2)
	assert_eq(arc[0], origin)
	for i: int in 29:
		_tick(b)
		assert_eq(b.state, S.TELL)
		assert_eq(claw.hazard_rects(), rects, "drawn for the full tell")
		assert_false(claw.call(&"claw_arc").is_empty())
	_tick(b)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(claw.hazard_rects(), rects, "the live sweep keeps its outline")
	assert_true(claw.call(&"claw_arc").is_empty(), "the arc is a TELL drawing")
	assert_eq(claw.tell_marks(), PackedVector2Array())
	_run_until(b, S.RECOVERY)
	assert_eq(claw.hazard_rects(), [] as Array[Rect2], "nothing drawn as a hazard in RECOVERY")


# --- AC 16-17: the locked rectangle, hit inside only, ACTIVE only ---

func test_rectangle_geometry_toward_the_aim_side() -> void:
	var o := Vector2(256, 80)
	var right: Rect2 = AccessViolation.sweep_rect(o, Vector2(300, 150))
	assert_eq(right, Rect2(Vector2(256, 144), Vector2(96, 32)), "right of the claw, rows 9-10")
	var left: Rect2 = AccessViolation.sweep_rect(o, Vector2(100, 150))
	assert_eq(left, Rect2(Vector2(160, 144), Vector2(96, 32)), "left of the claw")
	var corner: Rect2 = AccessViolation.sweep_rect(Vector2(500, 80), Vector2(510, 287))
	assert_true(Arena.play_area().encloses(corner), "clamped into the play area")
	assert_eq(corner, Rect2(Vector2(416, 256), Vector2(96, 32)), "shifted in at the bottom-right corner")
	assert_true(corner.has_point(Vector2(510, 287)), "the aim stays inside")


func test_hit_only_inside_the_rectangle_and_only_in_active() -> void:
	var b: SegfaultBody = _body()
	assert_true(_run_until(b, S.TELL))
	var claw: BossAttack = b.current_attack()
	var r: Rect2 = claw.hazard_rects()[0]
	assert_true(r.has_point(_target_px), "the aim is inside its own sweep")
	_player_px = r.get_center()
	assert_false(claw.hazard_hit(_player_px), "no hazard in TELL")
	_tick(b, 29)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "standing in the rectangle during the tell is safe")
	_player_px = Vector2(r.end.x + 1, r.get_center().y)
	_tick(b) # into ACTIVE
	assert_eq(b.state, S.ACTIVE)
	assert_false(claw.hazard_hit(_player_px), "outside the rectangle")
	_tick(b, 2)
	assert_eq(_health.hp, PLAYER_DEF.max_hp)
	_player_px = r.get_center()
	assert_true(claw.hazard_hit(_player_px))
	_tick(b)
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "1 HP through PlayerHealth.queue_hit")
	assert_true(claw.hazard_hit(r.position), "edges included")
	assert_true(claw.hazard_hit(r.end))
	_run_until(b, S.RECOVERY)
	assert_false(claw.hazard_hit(r.get_center()), "RECOVERY: nothing is hazardous")


func test_moving_out_of_the_locked_rectangle_during_the_tell_dodges() -> void:
	var b: SegfaultBody = _body()
	assert_true(_run_until(b, S.TELL))
	var claw: BossAttack = b.current_attack()
	var locked: Rect2 = claw.hazard_rects()[0]
	_target_px = Vector2(40, 260) # the aim moves away: the lock does not follow
	_player_px = _target_px
	_tick(b, 30)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(claw.hazard_rects()[0], locked, "locked at TELL entry")
	_tick(b, 12)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "the player who left is not hit")


func test_cancel_and_reset_clear_the_lock() -> void:
	var b: SegfaultBody = _body()
	assert_true(_run_until(b, S.TELL))
	var claw: BossAttack = b.current_attack()
	b.take_hit(400) # phase 2: the attack is cut
	assert_eq(b.state, S.ROAR)
	assert_false(claw.get(&"armed"))
	assert_eq(claw.hazard_rects(), [] as Array[Rect2])


# --- AC 19: declared positions ---

func test_declared_positions_lie_in_the_play_area() -> void:
	var b: SegfaultBody = _body()
	var claw: BossAttack = b.attack_for(CLAW)
	for aim: Vector2 in [Vector2(0, 0), Vector2(512, 288), Vector2(0, 288), Vector2(512, 0), Vector2(256, 144), Vector2(8, 280)]:
		_target_px = aim
		for x: int in [3000, 16000, 29000]:
			b.pos_mtiles = Vector2i(x, 3000)
			b.body_center_px = Vector2(b.pos_mtiles) * TILE / 1000.0
			var points: PackedVector2Array = claw.declared_positions(_arena)
			assert_eq(points.size(), 5, "the claw origin and four corners")
			for p: Vector2 in points:
				assert_true(ArenaContext.inside_play_area(p), "%s for aim %s, body x %d" % [p, aim, x])
