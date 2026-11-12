extends GutTest
## Story 4.3 (AC 13, E1-E2, D-S43-11): the SIGSEGV fallback mechanism. With FeatureFlags.breakpoint
## off, an attack with recovery_if_no_breakpoint > 0 recovers for that many frames instead of
## `recovery`. Constructed test-boss attacks (recovery 90, fallback 150); shipped data untouched.

const GameScript := preload("res://src/autoloads/game.gd")
const RecordingScript := preload("res://src/bosses/test_boss/attacks/pulse.gd")

var _ctx: SimContext
var _arena: ArenaContext
var _saved_state: int


func before_each() -> void:
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE
	_ctx = SimContext.new()
	_ctx.reseed(4313)
	_arena = ArenaContext.new()
	_arena.contact_source = func() -> Vector2: return Vector2(-1000, -1000)
	_arena.target_source = func() -> Vector2: return Vector2(-1000, -1000)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)
	SimClock.hitstop_frames = 0


func _attack(id: StringName) -> AttackDef:
	var a := AttackDef.new()
	a.id = id
	a.tell = 60 # GDD SIGSEGV tell
	a.active = 2
	a.recovery = 90
	a.recovery_if_no_breakpoint = 150
	a.tell_sfx = &"tell_test"
	a.attack_script = RecordingScript
	return a


func _def() -> BossDef:
	var p := PhaseDef.new()
	p.hp_threshold = 100
	p.weak_window = Vector2i(Register.Bit.ATTACK, Register.Bit.DASH)
	p.gap_frames = 1
	p.attack_pool = [_attack(&"sigsegv_a"), _attack(&"sigsegv_b")] as Array[AttackDef]
	var d := BossDef.new()
	d.boss_id = &"fallback_boss"
	d.name_signature = "fallbackBoss"
	d.max_hp = 100
	d.phases = [p] as Array[PhaseDef]
	d.body_radius_tiles = 1.0
	return d


## Ticks a fresh controller to its RECOVERY entry and returns the recovery length it entered with.
func _recovery_frames(breakpoint_on: bool) -> int:
	var c := BossController.new()
	c.breakpoint_on = breakpoint_on
	assert_true(c.setup(_def(), null, _arena))
	c.reset_for_fight()
	for i: int in 200:
		c.tick(_ctx)
		if c.state == BossController.BossState.RECOVERY:
			return c.frames_left
	return -1


func test_effective_recovery_helper() -> void:
	var a := _attack(&"x")
	assert_eq(BossController.effective_recovery(a, false), 150, "flag off: the fallback")
	assert_eq(BossController.effective_recovery(a, true), 90, "flag on: recovery")
	a.recovery_if_no_breakpoint = 0
	assert_eq(BossController.effective_recovery(a, false), 90, "no fallback set: recovery")
	assert_eq(BossController.effective_recovery(null, false), 0)


func test_fsm_recovers_150_with_breakpoint_off() -> void:
	assert_eq(_recovery_frames(false), 150)


func test_fsm_recovers_90_with_breakpoint_on() -> void:
	assert_eq(_recovery_frames(true), 90)


func test_controller_default_is_on() -> void:
	assert_true(BossController.new().breakpoint_on, "the arena injects the flag; default matches shipped data")


func test_shipped_attacks_do_not_set_the_fallback_yet() -> void:
	# The real SIGSEGV data arrives in 6.5; until then no shipped attack changes with the flag.
	for path: String in ["res://data/bosses/test_boss/attack_pulse.tres", "res://data/bosses/test_boss/attack_sweep.tres"]:
		var a := load(path) as AttackDef
		assert_eq(BossController.effective_recovery(a, false), a.recovery, path)


## Story 6.4 (AC 17): FeatureFlags.segfault off: boss index 2 gets no def path, so no Segfault body,
## no tile grid and no tile attack is ever built (the 5.6 cut path, Null Pointer -> ENDING, holds).
func test_segfault_cut_builds_no_grid_or_tile_attack() -> void:
	var main_script: GDScript = load("res://src/main/main.gd")
	assert_eq(main_script.boss_def_path_for(false, 2, false, false), "", "no def path with the flag off")
	assert_eq(GameScript.route_after_defeat(1, false), GameScript.FlowState.ENDING, "5.6 cut path")
	assert_eq(Arena.boss_class_for(""), BossController, "an empty path builds no Segfault body")
	# With the flag on, the grid exists only once a Segfault body has had its first reset.
	var body_script: GDScript = load(Arena.SEGFAULT_BODY_PATH)
	var b: BossController = body_script.new()
	assert_null(b.get(&"tiles"), "no grid before the first reset_for_fight")


## Story 6.5 (AC 9): the shipped SIGSEGV recovers 90 frames with Breakpoint, 150 without.
func test_shipped_sigsegv_uses_the_fallback() -> void:
	var a := load("res://data/bosses/segfault/attack_sigsegv.tres") as AttackDef
	assert_eq(BossController.effective_recovery(a, true), 90)
	assert_eq(BossController.effective_recovery(a, false), 150)


## Story 6.5 (AC 13): with FeatureFlags.segfault off no Segfault def is reachable, so SIGSEGV never
## runs: boss index 2 gets no def path and the 5.6 cut path (Null Pointer -> ENDING) holds.
func test_segfault_cut_reaches_no_sigsegv() -> void:
	var main_script: GDScript = load("res://src/main/main.gd")
	for boss: int in 3:
		var path: String = main_script.boss_def_path_for(false, boss, false, false)
		assert_false(path.contains("segfault"), "boss %d path %s" % [boss, path])
	assert_eq(GameScript.route_after_defeat(1, false), GameScript.FlowState.ENDING)


## Story 6.6 (AC 3, AD-12, cut #1): FeatureFlags.reserved_write. The Arena reads it once and the
## boss gets the attack id as excluded: with the flag off the Segfault's phase 3 is the 6.5 pool and
## no Reserved Write script is ever built; on, the shipped pool. Flipping it rebuilds on next entry.
func test_reserved_write_flag_drives_the_segfault_pool() -> void:
	for on: bool in [true, false]:
		var arena := Arena.new()
		assert_eq(arena.reserved_write_enabled, Defs.FEATURE_FLAGS.reserved_write, "read once at construction")
		arena.set_reserved_write_enabled(on)
		add_child_autofree(arena)
		arena.enter_fight(Register.fight_start_for_boss(2), false, Arena.SEGFAULT_DEF_PATH)
		var b: BossController = arena.boss
		assert_not_null(b)
		var ids: Array[StringName] = []
		for i: int in b._pick_candidates(2):
			ids.append(b._defs[i].id)
		var expected: Array[StringName] = [&"access_violation", &"corrupt_memory", &"core_dump", &"sigsegv"]
		if on:
			expected.append(&"reserved_write")
		assert_eq(ids, expected, "flag %s" % on)
		var built: bool = false
		for attack: BossAttack in b._attacks:
			built = built or attack.has_method(&"reserved_tell")
		assert_eq(built, on, "the ReservedWrite object exists only with the flag on")
		arena.leave_fight()


func test_flipping_the_reserved_write_flag_rebuilds_the_boss() -> void:
	var arena := Arena.new()
	arena.set_reserved_write_enabled(true)
	add_child_autofree(arena)
	arena.enter_fight(Register.fight_start_for_boss(2), false, Arena.SEGFAULT_DEF_PATH)
	var first: BossController = arena.boss
	assert_eq(first._pick_candidates(2).size(), 5)
	arena.set_reserved_write_enabled(false)
	arena.enter_fight(Register.fight_start_for_boss(2), false, Arena.SEGFAULT_DEF_PATH)
	assert_ne(arena.boss, first, "a new controller without the cut attack")
	assert_eq(arena.boss._pick_candidates(2).size(), 4)
	arena.leave_fight()
