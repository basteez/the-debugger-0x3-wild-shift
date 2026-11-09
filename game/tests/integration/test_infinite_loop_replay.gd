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

const GameScript := preload("res://src/autoloads/game.gd")
const TMP_PATH := "user://test_infinite_loop_replay_tmp.json"
const SEED := 33033
const FRAMES := 720
## Loop indices where the player is placed on the open `;` and the script presses J (a slash).
const STRIKES: Array[int] = [20, 45, 70]


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


## Before tick `i`: on a strike index with the `;` open and hittable, the player stands on it,
## facing the 8-direction closest to the spin tangent.
func _choreography(arena: Arena, body: InfiniteLoopBody, i: int) -> void:
	if not STRIKES.has(i) or not body.is_semicolon_hittable():
		return
	arena.player.position_px = body.semicolon_px()
	var angle: float = body.junction_angle()
	var tangent := Vector2(-sin(angle), cos(angle))
	arena.player.facing = Vector2i(roundi(tangent.x), roundi(tangent.y))


static func _hash(h: int, arena: Arena, body: InfiniteLoopBody) -> int:
	for v: int in [body.travel_mtiles, body.travel_rem, body.speed_mtps, body.iteration, body.open_left, body.hp, body.phase_index, arena.health.hp, int(body.started)]:
		h = (h * 31 + v + 7) & 0x7FFFFFFF
	return h


## One FIGHT session: a fresh Arena in the tree, the clock re-seeded, FRAMES polls.
func _session(source: InputSource, seed_value: int) -> Dictionary:
	_boss_hits = [0]
	var arena := Arena.new()
	add_child(arena)
	SimClock.begin_fight(seed_value)
	SimClock.input_source = source
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.INFINITE_LOOP_DEF_PATH)
	var body := arena.boss as InfiniteLoopBody
	assert_not_null(body, "the Infinite Loop is loaded")
	var start_frame: int = SimClock.sim_frame
	var hashes := PackedInt64Array()
	var h: int = 17
	for i: int in FRAMES:
		_choreography(arena, body, i)
		SimClock.tick()
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
	}
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


func test_the_infinite_loop_draws_no_rng_in_a_real_fight() -> void:
	SimClock.begin_fight(SEED)
	var before: int = SimClock.ctx.rng.state
	var live: Dictionary = _session(LoopScript.new(), SEED)
	assert_true(live[&"iteration"] > 1)
	assert_eq(live[&"rng_state"], before, "no system draws from SimContext.rng in this fight (D-S33-12a)")
