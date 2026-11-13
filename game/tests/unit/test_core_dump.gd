extends GutTest
## Story 6.4 AC 1, 7-14: Core Dump on the real Segfault def. Phase-3-only pool, 60 / 180 / 60
## timings, the 288 / 288 checkerboard on the (x + y) odd parity, the safe tiles visible in TELL,
## the one-hit-per-entry rule, cancel / defeat / retry clearing, declared positions. DumpBody narrows
## the candidates to Core Dump (cache index 2) after the fight is taken to phase 3.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const SF_DEF: BossDef = preload("res://data/bosses/segfault/boss_def.tres")
const DUMP: AttackDef = preload("res://data/bosses/segfault/attack_core_dump.tres")
const S := BossController.BossState
const T := CorruptedTiles.TileState

var _ctx: SimContext
var _arena: ArenaContext
var _player_px: Vector2
var _health: PlayerHealth
var _saved_state: int


class DumpBody:
	extends SegfaultBody

	var only := PackedInt32Array([2])

	func _pick_candidates(_phase: int) -> PackedInt32Array:
		return only


class FakeActions:
	extends ActionStateMachine

	func invulnerable() -> bool:
		return false


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE
	_ctx = SimContext.new()
	_ctx.reseed(6400)
	_arena = ArenaContext.new()
	_player_px = Vector2(-1000, -1000)
	_arena.target_source = func() -> Vector2: return Vector2(256, 200)
	_arena.contact_source = func() -> Vector2: return _player_px
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


## A DumpBody in phase 3 (HP 320).
func _body() -> DumpBody:
	_health = PlayerHealth.new(PLAYER_DEF, FakeActions.new())
	_health.reset_for_fight()
	_health.set_active(true)
	var b := DumpBody.new()
	assert_true(b.setup(SF_DEF, _health, _arena))
	assert_eq(b.attack_for(DUMP), b._attacks[2], "Core Dump is cache index 2")
	b.reset_for_fight()
	b.take_hit(680)
	assert_eq(b.phase_index, 2)
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


func _px(cell: Vector2i) -> Vector2:
	return CorruptedTiles.centre_of(cell)


# --- AC 1: phase-3-only ---

func test_core_dump_is_only_in_the_phase_3_pool() -> void:
	var b := SegfaultBody.new()
	assert_true(b.setup(SF_DEF, null, null))
	var dump: int = b._attacks.find(b.attack_for(DUMP))
	assert_eq(dump, 2)
	assert_false(b._pick_candidates(0).has(dump), "phase 1")
	assert_false(b._pick_candidates(1).has(dump), "phase 2")
	assert_true(b._pick_candidates(2).has(dump), "phase 3")
	assert_eq(b._pick_candidates(2).size(), 3)


func test_the_real_fsm_picks_core_dump_only_in_phase_3() -> void:
	var b := SegfaultBody.new()
	assert_true(b.setup(SF_DEF, null, _arena))
	b.reset_for_fight()
	var picked: Dictionary = {}
	for i: int in 6000:
		var was: S = b.state
		b.tick(_ctx)
		if b.state == S.TELL and was != S.TELL:
			picked[[b.phase_index, b.current.id]] = true
	assert_false(picked.has([0, &"core_dump"]), "never in phase 1")
	assert_true(picked.has([0, &"corrupt_memory"]), "Corrupt Memory in phase 1")
	b.take_hit(680)
	for i: int in 6000:
		var was: S = b.state
		b.tick(_ctx)
		if b.state == S.TELL and was != S.TELL:
			picked[[b.phase_index, b.current.id]] = true
	assert_true(picked.has([2, &"core_dump"]), "Core Dump in phase 3")


# --- AC 7-9: timings and the checkerboard ---

func test_tell_60_active_180_recovery_60() -> void:
	var b: DumpBody = _body()
	assert_true(_run_until(b, S.TELL))
	assert_eq(b.current, DUMP)
	assert_eq(_length_of_state(b), 60)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(_length_of_state(b), 180)
	assert_eq(b.state, S.RECOVERY)
	assert_true(b.tiles.is_empty(), "AC 9: nothing marked in RECOVERY")
	assert_eq(_length_of_state(b), 60)
	assert_eq(b.state, S.GAP)


func test_tell_shows_the_checkerboard_and_the_safe_tiles() -> void:
	var b: DumpBody = _body()
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	var marks: PackedVector2Array = attack.call(&"tile_marks")
	var safe: PackedVector2Array = attack.call(&"safe_tiles")
	assert_eq(marks.size(), 288)
	assert_eq(safe.size(), 288, "the safe parity is visible during the tell")
	for p: Vector2 in marks:
		assert_true(CorruptedTiles.is_hazard_parity(CorruptedTiles.cell_at(p)), "(x + y) odd")
	for p: Vector2 in safe:
		assert_false(CorruptedTiles.is_hazard_parity(CorruptedTiles.cell_at(p)))
	assert_eq(attack.hazard_positions(), PackedVector2Array())
	for i: int in 59:
		_tick(b)
		assert_eq((attack.call(&"tile_marks") as PackedVector2Array).size(), 288, "the full 60-frame tell")
	_tick(b)
	assert_eq(b.state, S.ACTIVE)
	assert_eq(attack.hazard_positions(), marks, "the marked parity becomes `▓`")
	assert_eq(attack.call(&"safe_tiles"), PackedVector2Array(), "no dots in ACTIVE")


func test_checkerboard_is_deterministic() -> void:
	var a: DumpBody = _body()
	assert_true(_run_until(a, S.TELL))
	var states: PackedByteArray = a.tiles.states.duplicate()
	_ctx.reseed(1)
	var c: DumpBody = _body()
	assert_true(_run_until(c, S.TELL))
	assert_eq(c.tiles.states, states, "the same board for any seed")


func test_entry_rule_on_the_hazard_parity_and_none_on_the_safe_one() -> void:
	var b: DumpBody = _body()
	assert_true(_run_until(b, S.TELL))
	var safe: Vector2 = _px(Vector2i(10, 12)) # (10 + 12) even: safe
	var hazard: Vector2 = _px(Vector2i(11, 12)) # odd: hazard
	_player_px = hazard
	_tick(b, 30)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "no damage in the tell")
	_player_px = safe
	_tick(b, 30) # into ACTIVE on a safe tile
	assert_eq(b.state, S.ACTIVE)
	_tick(b, 30)
	assert_eq(_health.hp, PLAYER_DEF.max_hp, "the safe parity never hurts")
	_player_px = hazard
	_tick(b)
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "1 HP on entry")
	_tick(b, 60)
	assert_eq(_health.hp, PLAYER_DEF.max_hp - 1, "standing still does not re-hit")


# --- AC 10-11: cancel, defeat, retry ---

func test_defeat_clears_the_board() -> void:
	var b: DumpBody = _body()
	assert_true(_run_until(b, S.ACTIVE))
	assert_false(b.tiles.is_empty())
	b.debug_kill()
	assert_eq(b.state, S.DEFEATED)
	assert_true(b.tiles.is_empty())
	SimClock.set(&"_pending_hitstop", 0)


func test_cancel_hook_clears_the_board() -> void:
	var b: DumpBody = _body()
	assert_true(_run_until(b, S.TELL))
	var attack: BossAttack = b.current_attack()
	attack.on_cancel(_arena)
	assert_true(b.tiles.is_empty())


func test_retry_starts_empty() -> void:
	var b: DumpBody = _body()
	assert_true(_run_until(b, S.ACTIVE))
	b.reset_for_fight()
	assert_true(b.tiles.is_empty())
	assert_eq(b.phase_index, 0)


# --- AC 12: declared positions ---

func test_declared_positions_are_the_288_hazard_tiles_in_the_play_area() -> void:
	var b: DumpBody = _body()
	var points: PackedVector2Array = b.attack_for(DUMP).declared_positions(_arena)
	assert_eq(points.size(), 288)
	for p: Vector2 in points:
		assert_true(ArenaContext.inside_play_area(p), str(p))


# --- AC 15: presentation reads by method, ink glyphs only ---

func test_boss_view_detects_the_tile_attacks_by_method() -> void:
	var b := SegfaultBody.new()
	assert_true(b.setup(SF_DEF, null, null))
	assert_true(BossView.is_tile_attack(b.attack_for(DUMP)))
	assert_true(BossView.is_tile_attack(b.attack_for(load("res://data/bosses/segfault/attack_corrupt_memory.tres"))))
	assert_false(BossView.is_tile_attack(b.attack_for(load("res://data/bosses/segfault/attack_access_violation.tres"))))
	assert_false(BossView.is_tile_attack(null))
	assert_eq([BossView.TILE_MARKED, BossView.TILE_HAZARD, BossView.TILE_SAFE], ["░", "▓", "·"])
	var code: String = FileAccess.get_file_as_string("res://src/presentation/boss_view.gd")
	assert_false(code.contains("FF4040"), "no red in the boss view")
	assert_false(code.contains("Palette.WARN"), "red is reserved for warnings")
