extends GutTest
## Story 8.2 (C4, AC 7, 10, D-S82-4, D-S82-12): the tutorial dummy. It never attacks (no tell, no RNG
## draw: the context RNG is seeded and its state checked), its `;` is closed CLOSED_FRAMES then open
## OPEN_FRAMES, only an open `;` lets a Dash Strike apply Patched, a Patched state outlives the `;`,
## the body is hittable at all times, it never hurts the player and is never defeated. Hits go through
## the real FSM and CombatResolver, ticked by hand in SimClock phase order (test_combat_resolver style).

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const DUMMY_DEF: BossDef = preload("res://data/bosses/tutorial_dummy/boss_def.tres")
const SEED := 82

var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _combat: CombatResolver
var _dummy: TutorialDummyBody
var _t: int = 0


func before_each() -> void:
	_buf = InputBuffer.new()
	_ctx = SimContext.new()
	_ctx.reseed(SEED)
	_player = Player.new(load("res://data/player/player_def.tres") as PlayerDef, Arena.player_bounds())
	_player.reset_for_fight(SPAWN)
	_player.set_active(true)
	_reg = Register.new(_buf)
	_reg.set_active(true)
	_fsm = ActionStateMachine.new(_buf, _player, _reg)
	_fsm.reset_for_fight()
	_fsm.set_active(true)
	_combat = CombatResolver.new(_fsm, _player)
	_dummy = TutorialDummyBody.new()
	assert_true(_dummy.setup(DUMMY_DEF, null, null))
	_dummy.reset_for_fight()
	_dummy.body_center_px = SPAWN + Vector2(64, 0)
	_combat.boss = _dummy
	_t = 0
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	watch_signals(EventBus)


func after_each() -> void:
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0


## One world tick in SimClock phase order (the dummy in BOSS_HAZARDS, after COMBAT).
func _tick() -> void:
	_ctx.poll_frame = _t
	_reg.tick(_ctx)
	_fsm.tick(_ctx)
	_player.tick(_ctx)
	_combat.tick(_ctx)
	_dummy.tick(_ctx)
	_t += 1


func _run_to(until: int) -> void:
	while _t < until:
		_tick()


## Ticks only the dummy `n` times.
func _tick_dummy(n: int) -> void:
	for i: int in n:
		_dummy.tick(_ctx)


## A Dash Strike from spawn on [A, D] (J, then K held by the link); returns once it is over.
func _dash_strike() -> void:
	_buf.push(J, _t)
	var start: int = _t
	_run_to(start + 3)
	_buf.push(K, _t)
	_run_to(start + 12)
	while _fsm.action != null:
		_tick()
	SimClock._pending_hitstop = 0


func _boss_hits() -> Array:
	var out: Array = []
	for i: int in get_signal_emit_count(EventBus, "hit_landed"):
		var params: Array = get_signal_parameters(EventBus, "hit_landed", i)
		if params[0] == &"boss":
			out.append(params)
	return out


func test_def_validates_with_an_empty_pool() -> void:
	assert_eq(DUMMY_DEF.validate(), PackedStringArray())
	assert_eq(DUMMY_DEF.boss_id, &"tutorial_dummy")
	assert_eq(DUMMY_DEF.phases.size(), 1)
	assert_true(DUMMY_DEF.phases[0].attack_pool.is_empty())
	assert_eq(DUMMY_DEF.phases[0].weak_window, Vector2i(A, D))
	assert_eq(Arena.boss_class_for(Arena.TUTORIAL_DEF_PATH), TutorialDummyBody)


func test_never_attacks_over_2000_frames_and_draws_no_rng() -> void:
	var state_before: int = _ctx.rng.state
	_tick_dummy(2000)
	assert_eq(_dummy.state, BossController.BossState.GAP, "never leaves GAP")
	assert_null(_dummy.current)
	assert_signal_emit_count(EventBus, "boss_tell_started", 0)
	assert_eq(_ctx.rng.state, state_before, "no RNG draw")


func test_semicolon_is_closed_then_open_on_a_fixed_timer() -> void:
	assert_false(_dummy.is_semicolon_open(), "closed at the start")
	var period: int = TutorialDummyBody.CLOSED_FRAMES + TutorialDummyBody.OPEN_FRAMES
	for k: int in range(1, 2 * period + 1):
		_dummy.tick(_ctx)
		var phase: int = k % period
		var want_open: bool = phase >= TutorialDummyBody.CLOSED_FRAMES
		assert_eq(_dummy.is_semicolon_open(), want_open, "after %d ticks" % k)
		if _dummy.is_semicolon_open() != want_open:
			return
	assert_eq(TutorialDummyBody.CLOSED_FRAMES, 180)
	assert_eq(TutorialDummyBody.OPEN_FRAMES, 120)


func test_weak_window_only_while_open() -> void:
	assert_eq(_dummy.current_weak_window(), Vector2i.ZERO)
	assert_false(_dummy.weak_point_open())
	_tick_dummy(TutorialDummyBody.CLOSED_FRAMES)
	assert_eq(_dummy.current_weak_window(), Vector2i(A, D))
	assert_true(_dummy.weak_point_open())


func test_dash_strike_on_a_closed_semicolon_is_resisted_and_never_patches() -> void:
	_reg.set_fight_start(PackedInt32Array([A, D]))
	_dash_strike()
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_false(_dummy.weak_window.is_patched())
	var hits: Array = _boss_hits()
	assert_eq(hits.size(), 1, "the body is a hurtbox: the strike lands")
	assert_eq(hits[0][2], DamageState.Kind.UNPATCHED)
	assert_true(hits[0][3], "a combo")
	assert_signal_emit_count(EventBus, "hit_missed", 0, "no miss line on the dummy")


func test_dash_strike_on_an_open_semicolon_patches_and_patched_outlives_it() -> void:
	_reg.set_fight_start(PackedInt32Array([A, D]))
	_tick_dummy(TutorialDummyBody.CLOSED_FRAMES) # the `;` opens
	assert_true(_dummy.is_semicolon_open())
	_dash_strike()
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_signal_emitted_with_parameters(EventBus, "patched_applied", [&"tutorial_dummy", WeakWindowTracker.PATCHED_FRAMES])
	assert_eq(_boss_hits()[0][2], DamageState.Kind.PATCHED)
	# Let the `;` close: Patched keeps running for its own length.
	while _dummy.is_semicolon_open():
		_dummy.tick(_ctx)
	assert_true(_dummy.weak_window.is_patched(), "Patched persists after the `;` closes")
	# A plain slash now is a crit (Patched, not the applying hit).
	_buf.push(J, _t)
	_run_to(_t + 12)
	var hits: Array = _boss_hits()
	assert_eq(hits.size(), 2)
	assert_eq(hits[1][2], DamageState.Kind.PATCHED)
	assert_signal_emit_count(EventBus, "patched_applied", 1, "a solo hit never re-patches")


func test_body_is_hittable_at_all_times_and_never_hurts() -> void:
	for k: int in 400:
		assert_true(_dummy.is_hittable(), "tick %d" % k)
		if not _dummy.is_hittable():
			return
		_dummy.tick(_ctx)
	assert_false(_dummy.touches_player(_dummy.body_center_px), "contact never hurts")


func test_never_defeated_after_50_hits() -> void:
	for i: int in 50:
		_dummy.take_hit(500)
	assert_eq(_dummy.hp, 1, "HP floors at 1")
	assert_ne(_dummy.state, BossController.BossState.DEFEATED)
	assert_signal_emit_count(EventBus, "boss_defeated", 0)
