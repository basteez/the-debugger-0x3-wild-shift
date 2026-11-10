extends GutTest
## Story 3.3 AC 10 (F3, D-S33-12d): a scripted FIGHT against the real Infinite Loop in a real Arena,
## recorded with InputRecorder and replayed from the saved file on a fresh Arena with the clock
## re-seeded. Both runs must end on the same number of world ticks and the same per-tick hash of
## the ring's integer state (travel, speed, i, `;` timer), the boss HP and the player HP. Floats
## (positions) are never hashed (same-binary only, 2.2 deferred item).
## The Arena registers its systems with the SimClock autoload, so "fresh clock" is the autoload
## re-seeded with begin_fight (sim_frame is monotonic, so the runs compare world-tick deltas).
## The test choreography (identical in both runs, keyed on the loop index and the sim state) puts
## the player on the open `;` facing along the spin right before each scripted slash, so the boss
## path with its hit-stop is exercised.
## Story 3.4 (H1, AC 15, D-S34-19): the hash now also covers the FSM (state, frames_left, picks), the
## attacks' integer progress (Head Rush travel, Constrict elapsed, the ring's attack radius) and the
## RNG state. A second scripted FIGHT runs a Head Rush in phase 1, jumps to phase 2 (the Shift+F6
## debug skip, called on the body in the test only), runs until a Constrict has played, and places
## the player on the `;` during attack recoveries so the boss path is hit there too.

const GameScript := preload("res://src/autoloads/game.gd")
const HEAD_RUSH: AttackDef = preload("res://data/bosses/infinite_loop/attack_head_rush.tres")
const CONSTRICT: AttackDef = preload("res://data/bosses/infinite_loop/attack_constrict.tres")
const TMP_PATH := "user://test_infinite_loop_replay_tmp.json"
const SEED := 33033
const FRAMES := 720
## Loop indices where the player is placed on the open `;` and the script presses J (a slash).
const STRIKES: Array[int] = [20, 45, 70]
## Story 3.4: the attack scenario's length, the loop index of the phase-2 skip, and its seed.
const ATTACK_FRAMES := 1500
const SKIP_AT := 260
const ATTACK_SEED := 34034


## The scripted player: the first shift on poll 1 starts the ring, J on each STRIKES poll, then a
## fixed walk with more presses, independent of the sim.
class LoopScript:
	extends InputSource
	var polls: int = 0
	var move_polls: int = 0

	func move_for_frame() -> Vector2i:
		var out := Vector2i.ZERO
		if move_polls >= 120:
			var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i.ZERO, Vector2i(1, 1)]
			@warning_ignore("integer_division")
			out = dirs[(move_polls / 41) % dirs.size()]
		move_polls += 1
		return out

	func presses_for_frame() -> Array[StringName]:
		var out: Array[StringName] = []
		if polls == 1:
			out.append(&"shift_left")
		if STRIKES.has(polls):
			out.append(&"action_1")
		if polls >= 120:
			if polls % 29 == 0:
				out.append(&"action_1")
			if polls % 53 == 7:
				out.append(&"shift_right")
			if polls % 31 == 11:
				out.append(&"action_2")
		polls += 1
		return out


var _saved_source: InputSource
var _saved_state: int
var _boss_hits: Array[int] = []
## Boss hits that landed while the boss was in an attack's RECOVERY (Story 3.4).
var _recovery_hits: Array[int] = []
var _body: InfiniteLoopBody = null


func before_each() -> void:
	_saved_source = SimClock.input_source
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE # a lethal hit never records a death
	SimClock.paused = false
	EventBus.hit_landed.connect(_on_hit_landed)


func after_each() -> void:
	EventBus.hit_landed.disconnect(_on_hit_landed)
	SimClock.input_source = _saved_source
	SimClock.recorder = null
	SimClock.begin_fight(0)
	Game.flow_state = _saved_state as GameScript.FlowState
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _on_hit_landed(target: StringName, _damage: int, _state: int, _combo: bool, _pos: Vector2) -> void:
	if target == &"boss":
		_boss_hits[0] += 1
		if _body != null and _body.state == BossController.BossState.RECOVERY:
			_recovery_hits[0] += 1


## Before tick `i`: on a strike index with the `;` open and hittable, the player stands on it,
## facing the 8-direction closest to the spin tangent.
func _choreography(arena: Arena, body: InfiniteLoopBody, i: int) -> void:
	if not STRIKES.has(i) or not body.is_semicolon_hittable():
		return
	arena.player.position_px = body.semicolon_px()
	var angle: float = body.junction_angle()
	var tangent := Vector2(-sin(angle), cos(angle))
	arena.player.facing = Vector2i(roundi(tangent.x), roundi(tangent.y))


## Story 3.4 (H1): before tick `i` of the attack scenario, while an attack's recovery has the `;`
## open and the script presses J this poll, the player stands on it facing along the spin.
func _recovery_choreography(arena: Arena, body: InfiniteLoopBody, i: int) -> void:
	if body.state != BossController.BossState.RECOVERY or not body.is_semicolon_hittable():
		return
	if i < 120 or i % 29 != 0:
		return
	arena.player.position_px = body.semicolon_px()
	var angle: float = body.junction_angle()
	var tangent := Vector2(-sin(angle), cos(angle))
	arena.player.facing = Vector2i(roundi(tangent.x), roundi(tangent.y))


static func _hash(h: int, arena: Arena, body: InfiniteLoopBody) -> int:
	var head: BossAttack = body.attack_for(HEAD_RUSH)
	var constrict: BossAttack = body.attack_for(CONSTRICT)
	var rng_state: int = SimClock.ctx.rng.state
	var values: Array[int] = [
		body.travel_mtiles, body.travel_rem, body.speed_mtps, body.iteration, body.open_left, body.hp,
		body.phase_index, arena.health.hp, int(body.started),
		int(body.state), body.frames_left, body.last_pick, body.second_last_pick, body.attack_radius_mtiles,
		head.get(&"travelled_mtiles"), constrict.get(&"elapsed"),
		rng_state & 0x7FFFFFFF, (rng_state >> 31) & 0x7FFFFFFF, (rng_state >> 62) & 0x3,
	]
	for v: int in values:
		h = (h * 31 + v + 7) & 0x7FFFFFFF
	return h


## One FIGHT session: a fresh Arena in the tree, the clock re-seeded, `frames` polls. With
## `attacks` (Story 3.4) the phase-2 skip runs at SKIP_AT and the recovery choreography is on.
func _session(source: InputSource, seed_value: int, frames: int = FRAMES, attacks: bool = false) -> Dictionary:
	_boss_hits = [0]
	_recovery_hits = [0]
	var tells: Dictionary[StringName, int] = {}
	var on_tell: Callable = func(id: StringName, _sfx: StringName) -> void: tells[id] = tells.get(id, 0) + 1
	EventBus.boss_tell_started.connect(on_tell)
	var arena := Arena.new()
	add_child(arena)
	SimClock.begin_fight(seed_value)
	SimClock.input_source = source
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.INFINITE_LOOP_DEF_PATH)
	var body := arena.boss as InfiniteLoopBody
	assert_not_null(body, "the Infinite Loop is loaded")
	_body = body
	var start_frame: int = SimClock.sim_frame
	var hashes := PackedInt64Array()
	var h: int = 17
	var rng_off_tell: int = 0
	for i: int in frames:
		_choreography(arena, body, i)
		if attacks:
			_recovery_choreography(arena, body, i)
			if i == SKIP_AT:
				body.debug_skip_phase() # Shift+F6 (D-S34-19), test only
		var rng_before: int = SimClock.ctx.rng.state
		var tells_before: int = tells.values().reduce(func(a: int, b: int) -> int: return a + b, 0)
		SimClock.tick()
		if SimClock.ctx.rng.state != rng_before and tells.values().reduce(func(a: int, b: int) -> int: return a + b, 0) != tells_before + 1:
			rng_off_tell += 1
		h = _hash(h, arena, body)
		hashes.append(h)
	var out: Dictionary = {
		&"ticks": SimClock.sim_frame - start_frame,
		&"hashes": hashes,
		&"hash": h,
		&"boss_hp": body.hp,
		&"iteration": body.iteration,
		&"boss_hits": _boss_hits[0],
		&"rng_state": SimClock.ctx.rng.state,
		&"recovery_hits": _recovery_hits[0],
		&"tells": tells.duplicate(),
		&"rng_off_tell": rng_off_tell,
		&"phase": body.phase_index,
	}
	EventBus.boss_tell_started.disconnect(on_tell)
	_body = null
	arena.leave_fight()
	remove_child(arena)
	arena.free()
	return out


func test_a_recorded_fight_with_the_infinite_loop_replays_bit_identically() -> void:
	var rec := InputRecorder.new()
	rec.start(SEED)
	SimClock.recorder = rec
	var live: Dictionary = _session(LoopScript.new(), SEED)
	SimClock.recorder = null
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))

	var replay := ReplayInput.from_file(TMP_PATH)
	assert_eq(replay.frame_count(), FRAMES)
	var again: Dictionary = _session(replay, replay.seed_value)

	assert_true(live[&"iteration"] > 1, "the ring started and looped")
	assert_gt(live[&"boss_hits"], 0, "at least one hit landed on the open `;`")
	assert_lt(live[&"boss_hp"], 400)
	assert_lt(live[&"ticks"], FRAMES, "hit-stop froze world ticks, so the gates were exercised")
	assert_eq(again[&"ticks"], live[&"ticks"], "same sim_frame")
	assert_eq(again[&"boss_hits"], live[&"boss_hits"])
	assert_eq(again[&"boss_hp"], live[&"boss_hp"])
	assert_eq(again[&"hash"], live[&"hash"], "same ring-state hash")
	assert_eq(again[&"hashes"], live[&"hashes"], "same hash on every tick")
	assert_eq(again[&"rng_state"], live[&"rng_state"])


## Story 3.4: phase 1 has one attack (D-S34-3); RandomNumberGenerator.randi_range(0, 0) does not
## advance the generator, so the phase-1 picks leave the RNG where it was seeded.
func test_the_infinite_loop_draws_no_rng_in_phase_1() -> void:
	SimClock.begin_fight(SEED)
	var before: int = SimClock.ctx.rng.state
	var live: Dictionary = _session(LoopScript.new(), SEED)
	assert_true(live[&"iteration"] > 1)
	assert_eq(live[&"phase"], 0)
	assert_gt(live[&"tells"].get(&"head_rush", 0), 0, "Head Rush was drawn")
	assert_eq(live[&"rng_state"], before, "no RNG change in phase 1 (D-S33-12a, D-S34-14)")


func test_a_recorded_fight_through_head_rush_and_constrict_replays_bit_identically() -> void:
	var rec := InputRecorder.new()
	rec.start(ATTACK_SEED)
	SimClock.recorder = rec
	var live: Dictionary = _session(LoopScript.new(), ATTACK_SEED, ATTACK_FRAMES, true)
	SimClock.recorder = null
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))

	var replay := ReplayInput.from_file(TMP_PATH)
	assert_eq(replay.frame_count(), ATTACK_FRAMES)
	assert_eq(replay.seed_value, ATTACK_SEED, "the recording carries its seed")
	var again: Dictionary = _session(replay, replay.seed_value, ATTACK_FRAMES, true)

	assert_gt(live[&"tells"].get(&"head_rush", 0), 0, "a Head Rush ran")
	assert_gt(live[&"tells"].get(&"constrict", 0), 0, "a Constrict ran (phase 2)")
	assert_gte(live[&"phase"], 1, "the debug skip reached phase 2")
	assert_gt(live[&"recovery_hits"], 0, "a hit landed on the `;` during an attack recovery")
	assert_eq(live[&"rng_off_tell"], 0, "the RNG moves only on pick ticks (D-S34-14)")
	assert_eq(again[&"ticks"], live[&"ticks"], "same sim_frame")
	assert_eq(again[&"tells"], live[&"tells"], "same attack order counts")
	assert_eq(again[&"boss_hits"], live[&"boss_hits"])
	assert_eq(again[&"recovery_hits"], live[&"recovery_hits"])
	assert_eq(again[&"boss_hp"], live[&"boss_hp"])
	assert_eq(again[&"hashes"], live[&"hashes"], "same integer-state hash on every tick")
	assert_eq(again[&"rng_state"], live[&"rng_state"])
