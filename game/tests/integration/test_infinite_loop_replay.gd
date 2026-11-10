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
## Story 3.5 (Q5, AC 13, D-S35-16): the hash also covers the split state (split, next_ring, open_ring,
## ring_timer, nested_done, the inner ring's travel, remainder and speed) and the Spit (cycle timer,
## every projectile slot's active flag, position and step in milli-tiles). A third scripted FIGHT
## jumps to phase 3 (Shift+F6 twice, test only), splits, and runs timed openings on both rings, Spit
## shots, attack recovery openings and a Constrict; RNG moves only on (non-forced) pick ticks.

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
## Story 3.5: the phase-3 scenario's length, the loop index of the double skip, and its seed.
const P3_FRAMES := 3000
const P3_SKIP_AT := 200
const P3_SEED := 35035


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
		int(body.split), body.next_ring, body.open_ring, body.ring_timer, int(body.nested_done),
		body.inner_travel_mtiles, body.inner_travel_rem, body.inner_speed_mtps(), body.spit.timer,
		body.defeat_frames_elapsed, SimClock.hitstop_frames, # Story 3.8 (A4, AC 8)
	]
	for k: int in body.spit.slot_active.size():
		values.append(body.spit.slot_active[k])
		values.append(body.spit.slot_pos_mtiles[k].x)
		values.append(body.spit.slot_pos_mtiles[k].y)
		values.append(body.spit.slot_step_mtiles[k].x)
		values.append(body.spit.slot_step_mtiles[k].y)
	for v: int in values:
		h = (h * 31 + v + 7) & 0x7FFFFFFF
	return h


## One FIGHT session: a fresh Arena in the tree, the clock re-seeded, `frames` polls. With
## `attacks` (Story 3.4) the phase-2 skip runs at SKIP_AT and the recovery choreography is on.
func _session(source: InputSource, seed_value: int, frames: int = FRAMES, attacks: bool = false, p3: bool = false, kill_at: int = -1) -> Dictionary:
	_boss_hits = [0]
	var defeat_tick: Array[int] = [-1]
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
	var on_defeat: Callable = func(_id: StringName) -> void: defeat_tick[0] = SimClock.sim_frame - start_frame
	EventBus.boss_defeated.connect(on_defeat)
	var hashes := PackedInt64Array()
	var h: int = 17
	var rng_off_tell: int = 0
	var timed_openings: Array[int] = [0, 0] # Story 3.5: per ring, after the split, outside recoveries
	var recovery_openings_split: int = 0
	var ring_openings: Array[int] = [0, 0] # Story 3.5: every opening after the split, per ring
	for i: int in frames:
		_choreography(arena, body, i)
		if p3 and i == P3_SKIP_AT:
			body.debug_skip_phase() # Shift+F6 twice (D-S34-19), test only
			body.debug_skip_phase()
		if i == kill_at:
			body.debug_kill() # Story 3.8 (G7): the F6 path, test only
		if attacks:
			_recovery_choreography(arena, body, i)
			if i == SKIP_AT:
				body.debug_skip_phase() # Shift+F6 (D-S34-19), test only
		var rng_before: int = SimClock.ctx.rng.state
		var tells_before: int = tells.values().reduce(func(a: int, b: int) -> int: return a + b, 0)
		var i_before: int = body.iteration
		var was_split: bool = body.split
		var timed_before: int = body.timed_openings
		SimClock.tick()
		if was_split and body.iteration != i_before and body.open_ring >= 0:
			ring_openings[body.open_ring] += 1
			if body.timed_openings != timed_before: # D-S35-24: an explicit signal, not the FSM state
				timed_openings[body.open_ring] += 1
			else:
				recovery_openings_split += 1
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
		&"split": body.split,
		&"timed_openings": timed_openings,
		&"recovery_openings_split": recovery_openings_split,
		&"ring_openings": ring_openings,
		&"spit_shots": body.spit.shots,
		&"defeat_tick": defeat_tick[0],
		&"defeat_finished": body.defeat_finished(),
		&"defeat_frames": body.defeat_frames_elapsed,
	}
	EventBus.boss_defeated.disconnect(on_defeat)
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


func test_a_recorded_fight_through_phase_3_replays_bit_identically() -> void:
	var rec := InputRecorder.new()
	rec.start(P3_SEED)
	SimClock.recorder = rec
	var live: Dictionary = _session(LoopScript.new(), P3_SEED, P3_FRAMES, false, true)
	SimClock.recorder = null
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))

	var replay := ReplayInput.from_file(TMP_PATH)
	assert_eq(replay.frame_count(), P3_FRAMES)
	var again: Dictionary = _session(replay, replay.seed_value, P3_FRAMES, false, true)

	assert_eq(live[&"phase"], 2, "the debug skips reached phase 3")
	assert_true(live[&"split"], "the Nested Loop split the ring")
	assert_eq(live[&"tells"].get(&"nested_loop", 0), 1, "once per fight")
	assert_gt(live[&"tells"].get(&"constrict", 0), 0, "a Constrict ran")
	# D-S35-24: the 180-tick timer runs through attacks and recovery openings do not restart it, so
	# timed openings really occur in a phase-3 fight, on both rings (AC 13).
	# In a real fight each attack cycle holds exactly one recovery and one timed opening, so the
	# alternation locks (recoveries on the inner ring, timed on the outer, 9000-tick run checked);
	# the inner-ring timed opening is covered by test_infinite_loop_split.gd (FSM held in GAP).
	assert_gt(live[&"timed_openings"][0], 0, "timed openings occur in a real phase-3 fight (D-S35-24)")
	assert_eq(live[&"timed_openings"][0] + live[&"timed_openings"][1] + live[&"recovery_openings_split"], live[&"ring_openings"][0] + live[&"ring_openings"][1], "every opening is timed or a recovery")
	assert_gt(live[&"ring_openings"][0], 0, "an outer opening after the split")
	assert_gt(live[&"ring_openings"][1], 0, "an inner opening after the split")
	assert_gt(live[&"recovery_openings_split"], 0, "an attack recovery opening after the split")
	assert_gt(live[&"spit_shots"], 0, "the Spit fired")
	assert_eq(live[&"rng_off_tell"], 0, "the RNG moves only on pick ticks (AC 13)")
	assert_eq(again[&"ticks"], live[&"ticks"], "same sim_frame")
	assert_eq(again[&"tells"], live[&"tells"])
	assert_eq(again[&"timed_openings"], live[&"timed_openings"])
	assert_eq(again[&"ring_openings"], live[&"ring_openings"])
	assert_eq(again[&"spit_shots"], live[&"spit_shots"])
	assert_eq(again[&"boss_hp"], live[&"boss_hp"])
	assert_eq(again[&"hashes"], live[&"hashes"], "same integer-state hash on every tick")
	assert_eq(again[&"rng_state"], live[&"rng_state"])



## Story 3.8 (G7, AC 8, D-S38-8): a fight that ends in a defeat (killed on loop index KILL_AT through
## the F6 path) replays bit-identically: same per-tick hash (it covers defeat_frames_elapsed and the
## hit-stop counter), same defeat tick, and the 60-tick reassembly completes in sim state.
const KILL_AT := 200
const DEFEAT_SEED := 38038


func test_a_recorded_fight_ending_in_defeat_replays_bit_identically() -> void:
	var rec := InputRecorder.new()
	rec.start(DEFEAT_SEED)
	SimClock.recorder = rec
	var live: Dictionary = _session(LoopScript.new(), DEFEAT_SEED, 360, false, false, KILL_AT)
	SimClock.recorder = null
	assert_true(InputRecorder.save(rec.stop(), TMP_PATH))
	var replay := ReplayInput.from_file(TMP_PATH)
	var again: Dictionary = _session(replay, replay.seed_value, 360, false, false, KILL_AT)
	assert_eq(live[&"boss_hp"], 0)
	assert_gte(live[&"defeat_tick"], 0, "boss_defeated was emitted")
	assert_true(live[&"defeat_finished"], "the reassembly finished within the run")
	assert_eq(live[&"defeat_frames"], BossController.DEFEAT_FRAMES)
	assert_eq(again[&"defeat_tick"], live[&"defeat_tick"], "same defeat tick")
	assert_eq(again[&"ticks"], live[&"ticks"], "same sim_frame (the 20-frame hit-stop included)")
	assert_eq(again[&"hashes"], live[&"hashes"], "same integer-state hash on every tick")
	assert_eq(again[&"rng_state"], live[&"rng_state"])
