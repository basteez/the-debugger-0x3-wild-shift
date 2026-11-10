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
