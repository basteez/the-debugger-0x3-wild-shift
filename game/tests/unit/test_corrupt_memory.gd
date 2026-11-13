extends GutTest
## Story 6.4 AC 4-6, 10-14: Corrupt Memory on the real Segfault def. The body is ticked directly with
## an ArenaContext whose contact position the test drives, and a PlayerHealth ticked after it
## (SimClock order). TileBody narrows the candidates to Corrupt Memory (cache index 1); the real
## FSM runs it.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const CORRUPT: AttackDef = preload("res://data/bosses/segfault/attack_corrupt_memory.tres")
const S := BossController.BossState
const T := CorruptedTiles.TileState

var _ctx: SimContext
var _arena: ArenaContext
var _player_px: Vector2
var _health: PlayerHealth
var _saved_state: int
var _tells: Array = []


## The real Segfault body with one candidate attack (cache index; 1 = Corrupt Memory).
class TileBody:
	extends SegfaultBody

	var only := PackedInt32Array([1])

	func _pick_candidates(_phase: int) -> PackedInt32Array:
		return only


class FakeActions:
	extends ActionStateMachine

	func invulnerable() -> bool:
		return false


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal contact never records a death
	_ctx = SimContext.new()
	_ctx.reseed(6464)
	_arena = ArenaContext.new()
	_player_px = Vector2(-1000, -1000)
	_arena.target_source = func() -> Vector2: return Vector2(256, 200)
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


func _body() -> TileBody:
	_health = PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	_health.reset_for_fight()
	_health.set_active(true)
	var b := TileBody.new()
	assert_true(b.setup(SF_DEF, _health, _arena))
	assert_eq(b.attack_for(CORRUPT), b._attacks[1], "Corrupt Memory is cache index 1")
	b.reset_for_fight()
	return b


func _tick(b: BossController, times: int = 1) -> void:
	for i: int in times:
		b.tick(_ctx)
		_health.tick(_ctx)


func _run_until(b: BossController, state: S, limit: int = 600) -> bool:
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


## A tile that is not marked and not under the dragon's contact circle.
func _clear_tile_px(b: SegfaultBody) -> Vector2:
	for y: int in range(17, 6, -1):
		for x: int in 32:
			var cell := Vector2i(x, y)
			if b.tiles.state_at(cell) == T.CLEAR:
				return CorruptedTiles.centre_of(cell)
	return Vector2(-1000, -1000)


## The lowest marked tile (clear of the dragon's contact circle in the top band).
func _low_mark(marks: PackedVector2Array) -> Vector2:
	var best: Vector2 = marks[0]
	for p: Vector2 in marks:
		if p.y > best.y:
			best = p
	assert_gt(best.y, 6.0 * Const.TILE_PX, "below the dragon's band")
	return best


# --- AC 4-6: timings, marks, hazards, recovery ---

func test_tell_60_active_240_recovery_40() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, CORRUPT)
	assert_eq(_tells, [[&"corrupt_memory", &"tell_corrupt_memory"]], "the tell SFX id (D-S64-8)")
	assert_eq(_length_of_state(b), 60)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(_length_of_state(b), 240)
	assert_eq(b.state, S.RECOVERY)
	assert_true(b.tiles.is_empty(), "AC 6: nothing marked in RECOVERY")
	assert_eq(_length_of_state(b), 40)
	assert_eq(b.state, S.GAP)


func test_tell_marks_8_to_12_distinct_tiles_over_many_seeds() -> void:
	var seen: Dictionary = {}
	for seed_i: int in 60:
		_ctx.reseed(seed_i)
		var b: TileBody = _body()
		assert_true(_run_until(b, S.TELL))
		var attack: BossAttack = b.current_attack()
		var marks: PackedVector2Array = attack.call(&"tile_marks")
		assert_between(marks.size(), 8, 12, "seed_i %d" % seed_i)
		assert_eq(b.tiles.attack_cells, marks.size(), "distinct cells")
		seen[marks.size()] = true
		for p: Vector2 in marks:
			assert_true(Arena.play_area().has_point(p))
		assert_eq(attack.hazard_positions(), PackedVector2Array(), "no hazard in TELL")
		assert_eq(attack.call(&"safe_tiles"), PackedVector2Array())
	for n: int in range(8, 13):
		assert_true(seen.has(n), "count %d drawn" % n)


func test_same_seed_same_cells() -> void:
	_ctx.reseed(99)
	var a: TileBody = _body()
	assert_true(_run_until(a, S.TELL))
	var cells_a: PackedByteArray = a.tiles.states.duplicate()
	_ctx.reseed(99)
	var c: TileBody = _body()
	assert_true(_run_until(c, S.TELL))
	assert_eq(c.tiles.states, cells_a, "AC 13: replay determinism")


func test_marked_tiles_turn_hazard_for_the_full_active() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	var marks: PackedVector2Array = attack.call(&"tile_marks")
	for i: int in 59:
		_tick(b)
		assert_eq(attack.call(&"tile_marks"), marks, "marked for the full tell (AC 12)")
	_tick(b)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(attack.hazard_positions(), marks, "the same tiles are now hazards")
	assert_eq(attack.call(&"tile_marks"), PackedVector2Array())
	_tick(b)
	for p: Vector2 in marks:
		assert_eq(b.tiles.state_at(CorruptedTiles.cell_at(p)), T.HAZARD)


func test_entering_a_hazard_tile_costs_1_hp_once_per_entry() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	var hazard: Vector2 = _low_mark(attack.call(&"tile_marks"))
	_player_px = hazard
	_tick(b, 59)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "no damage during the tell")
	_player_px = _clear_tile_px(b)
	_tick(b) # into ACTIVE, off the tiles
	assert_eq(b.state, S.ACTIVE)
	_tick(b, 5)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "outside the marked set never hurts")
	_player_px = hazard
	_tick(b)
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "1 HP on entry")
	_tick(b, 120)
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "standing still does not re-hit (D-S64-5)")
	assert_true(attack.hazard_hit(hazard), "still a hazard")


func test_standing_on_a_marked_tile_when_active_starts_is_not_hit() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.TELL))
	var hazard: Vector2 = _low_mark(b.current_attack().call(&"tile_marks"))
	_player_px = hazard
	_tick(b, 120) # the whole tell and into ACTIVE
	assert_eq(b.state, S.ACTIVE)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "D-S64-5: already on it, no entry")


func test_recovery_clears_and_nothing_hurts() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	var hazard: Vector2 = _low_mark(attack.call(&"tile_marks"))
	assert_true(_run_until(b, S.RECOVERY))
	assert_true(b.tiles.is_empty())
	assert_false(attack.hazard_hit(hazard))
	assert_eq(attack.hazard_positions(), PackedVector2Array())
	_player_px = _clear_tile_px(b)
	_tick(b)
	_player_px = hazard
	_tick(b, 5)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "RECOVERY: no hazard")


# --- AC 10-11: cancel, defeat, retry ---

func test_phase_change_cancels_and_clears() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.ACTIVE))
	assert_false(b.tiles.is_empty())
	b.take_hit(400) # phase 2: the attack is cut
	assert_eq(b.state, S.ROAR)
	assert_true(b.tiles.is_empty(), "on_cancel cleared at once")
	_tick(b)
	assert_true(b.tiles.is_empty())


func test_defeat_cancels_and_clears() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.ACTIVE))
	var attack: BossAttack = b.current_attack()
	b.debug_kill()
	assert_eq(b.state, S.DEFEATED)
	assert_true(b.tiles.is_empty(), "no `▓` after DEFEATED")
	assert_eq(attack.hazard_positions(), PackedVector2Array())
	SimClock.set(&"_pending_hitstop", 0)


func test_retry_starts_with_an_empty_grid() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.ACTIVE))
	_player_px = b.current_attack().hazard_positions()[0]
	_tick(b, 3)
	b.reset_for_fight()
	assert_true(b.tiles.is_empty())
	assert_false(b.tiles.was_on_attack_tile, "no latched entry")
	assert_eq(b.state, S.GAP)


# --- AC 12: declared positions ---

func test_declared_positions_are_the_marked_tiles_inside_the_play_area() -> void:
	var b: TileBody = _body()
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	var points: PackedVector2Array = attack.declared_positions(_arena)
	assert_eq(points, attack.call(&"tile_marks"))
	for p: Vector2 in points:
		assert_true(ArenaContext.inside_play_area(p), str(p))
