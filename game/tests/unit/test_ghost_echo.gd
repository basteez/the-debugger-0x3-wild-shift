extends GutTest
## Story 6.1: Ghost Echo (L->N combo), its decoy, the boss aim switch and the DECOY_STRUCK producer.
## The real FSM, Player, Register, GhostEchoSystem and CombatResolver are ticked by hand in SimClock
## phase order (SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, COMBAT).

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const TILE := Const.TILE_PX
const PULSE: AttackDef = preload("res://data/bosses/test_boss/attack_pulse.tres")
const SWEEP: AttackDef = preload("res://data/bosses/test_boss/attack_sweep.tres")
const LN := Vector2i(L, N)


## Test attack: the test boss's pulse with a hazard at one settable point.
class HazardPulse:
	extends "res://src/bosses/test_boss/attacks/pulse.gd"
	var hazard_px: Vector2 = Vector2(-1000, -1000)

	func hazard_hit(p: Vector2) -> bool:
		return p.distance_to(hazard_px) < 1.0


var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _ghost: GhostEchoSystem
var _combat: CombatResolver
var _t: int = 0


func before_each() -> void:
	_buf = InputBuffer.new()
	_ctx = SimContext.new()
	_player = Player.new(load("res://data/player/player_def.tres") as PlayerDef, Arena.player_bounds())
	_player.reset_for_fight(SPAWN)
	_player.set_active(true)
	_reg = Register.new(_buf)
	_reg.set_active(true)
	_fsm = ActionStateMachine.new(_buf, _player, _reg)
	_fsm.reset_for_fight()
	_fsm.set_active(true)
	_ghost = GhostEchoSystem.new(_fsm)
	_combat = CombatResolver.new(_fsm, _player)
	_combat.ghost = _ghost.decoy
	_t = 0
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	watch_signals(EventBus)


func after_each() -> void:
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	_combat = null
	_ghost = null
	_fsm = null
	_player = null
	_reg = null
	_buf = null
	_ctx = null


func _ring(bits: Array) -> void:
	assert_true(_reg.set_fight_start(PackedInt32Array(bits)))


func _tick() -> void:
	_ctx.poll_frame = _t
	_reg.tick(_ctx)
	_fsm.tick(_ctx)
	_player.tick(_ctx)
	_ghost.tick(_ctx)
	_combat.tick(_ctx)
	_t += 1


## Echo (LOOP's J, replaying a remembered Dash) then K on [L, N]; ticks until Ghost Echo starts.
## True when it started; the start tick is the last one run.
func _ghost_echo() -> bool:
	_ring([L, N])
	_fsm.echo.remember(Defs.DASH)
	_buf.push(J, _t)
	_tick()
	assert_true(_fsm.echoing, "Echo runs")
	_tick()
	_buf.push(K, _t)
	for i: int in 40:
		_tick()
		if _fsm.action == Defs.GHOST_ECHO:
			return true
	return false


func _boss(weak: Vector2i) -> BossController:
	var p := PhaseDef.new()
	p.hp_threshold = 100
	p.weak_window = weak
	p.gap_frames = 40
	p.attack_pool = [PULSE, SWEEP]
	var d := BossDef.new()
	d.boss_id = &"unit_boss"
	d.name_signature = "unitBoss"
	d.max_hp = 100
	d.phases = [p]
	d.body_radius_tiles = 1.0
	var c := BossController.new()
	assert_true(c.setup(d, null, null))
	c.reset_for_fight()
	c.body_center_px = SPAWN + Vector2(0, -5 * TILE)
	_combat.boss = c
	return c


## Forces the boss into ACTIVE with a HazardPulse whose hazard sits at `at`.
func _force_active(c: BossController, at: Vector2) -> HazardPulse:
	var attack := HazardPulse.new()
	attack.bind_boss(c)
	attack.hazard_px = at
	c._attacks[0] = attack
	c._current_index = 0
	c.current = PULSE
	c.state = BossController.BossState.ACTIVE
	c.frames_left = 10
	return attack


# --- AC 1: data ---

func test_ghost_echo_def_data() -> void:
	var def: ActionDef = Defs.GHOST_ECHO
	assert_eq(def.id, &"ghost_echo")
	assert_eq([def.startup_frames, def.active_frames, def.recovery_frames], [0, 30, 8])
	assert_eq([def.invuln_from, def.invuln_to], [1, 30])
	assert_null(def.hit_shape)
	assert_eq(def.base_damage, 0)
	assert_eq(def.cooldown_frames, 0)
	assert_eq(def.move_tiles, 0.0)
	assert_false(def.echoable)
	assert_false(def.echo_action)
	assert_false(def.redirectable)
	assert_false(def.pass_through)
	assert_false(def.slows_move)
	assert_false(def.arms_clean_catch)
	assert_eq(def.decoy_frames, 120)
	assert_eq(def.validate(), PackedStringArray())


func test_l_then_n_is_ghost_echo_and_the_table_validates() -> void:
	var c: ComboDef = Defs.COMBOS.get_combo(L, N)
	assert_not_null(c)
	if c == null:
		return
	assert_same(c.action, Defs.GHOST_ECHO)
	assert_eq(c.display_name, "Ghost Echo")
	assert_false(c.gap_free)
	assert_null(Defs.COMBOS.get_combo(N, L), "ordered")
	assert_eq(c.validate(), PackedStringArray())
	assert_eq(Defs.COMBOS.validate(), PackedStringArray())


func test_negative_decoy_frames_rejected() -> void:
	var def: ActionDef = Defs.GHOST_ECHO.duplicate()
	def.decoy_frames = -1
	assert_eq(def.validate().size(), 1)


# --- AC 2: trigger and cost ---

func test_l_n_window_starts_ghost_echo_with_null_cooldown() -> void:
	assert_true(_ghost_echo())
	assert_not_null(_fsm.combo)
	assert_eq(_fsm.combo.display_name, "Ghost Echo")
	assert_eq(_fsm.action_frame, 1)
	assert_eq(_fsm.action_window, LN)
	assert_eq(_fsm.cooldowns.remaining(N), 120, "Null Dodge's cooldown")
	assert_lt(_fsm.cooldowns.remaining(L), 90, "LOOP's Echo cooldown, not restarted")
	assert_gt(_fsm.cooldowns.remaining(L), 0)
	assert_same(_fsm.echo.last, Defs.DASH, "combos are never stored")
	assert_ne(_fsm.action, Defs.NULL_DODGE)


func test_combo_ignores_echo_memory() -> void:
	var link := LinkState.new()
	link.open(LN, 0)
	var buf := InputBuffer.new()
	buf.push(K, 3)
	var input := ResolveInput.new()
	input.buffer = buf
	input.frame = 3
	input.window = LN
	input.action = null
	input.action_frame = 0
	input.cooldowns = Cooldowns.new()
	input.link = link
	input.echo_ready = false
	var r: ActionRequest = ActionResolver.resolve(input)
	assert_not_null(r)
	if r == null:
		return
	assert_same(r.def, Defs.GHOST_ECHO)
	assert_eq(r.bit, N)


func test_k_on_null_cooldown_is_dropped() -> void:
	_fsm.cooldowns.start(N, 200)
	_ring([L, N])
	_fsm.echo.remember(Defs.DASH)
	_buf.push(J, _t)
	_tick()
	_tick()
	_buf.push(K, _t)
	for i: int in 60:
		_tick()
		assert_ne(_fsm.action, Defs.GHOST_ECHO)
		assert_ne(_fsm.action, Defs.NULL_DODGE)
	assert_eq(_ghost.decoy.frames_left, 0)


# --- AC 3: intangibility ---

func test_invulnerable_exactly_frames_1_to_30() -> void:
	var def: ActionDef = Defs.GHOST_ECHO
	assert_false(def.is_invulnerable_frame(0))
	for f: int in range(1, 31):
		assert_true(def.is_invulnerable_frame(f), "frame %d" % f)
	for f: int in range(31, 39):
		assert_false(def.is_invulnerable_frame(f), "frame %d" % f)


func test_hits_are_rejected_and_arm_no_clean_catch() -> void:
	var health := PlayerHealth.new(load("res://data/player/player_def.tres") as PlayerDef, _fsm)
	health.reset_for_fight()
	assert_true(_ghost_echo())
	for f: int in range(1, 31):
		assert_eq(_fsm.action_frame, f)
		assert_true(_fsm.invulnerable(), "frame %d" % f)
		assert_false(health.apply_hit(), "frame %d rejects" % f)
		_tick()
	assert_false(_fsm.clean_catch_armed)
	assert_eq(_fsm.action_frame, 31)
	assert_false(_fsm.invulnerable(), "frame 31 is vulnerable")
	assert_true(health.apply_hit())


# --- AC 4: spawn ---

func test_decoy_spawns_at_start_point_with_120_frames() -> void:
	assert_true(_ghost_echo())
	var d: GhostDecoy = _ghost.decoy
	assert_true(d.is_live())
	assert_eq(d.frames_left, 120)
	var start: Vector2 = _player.position_px
	assert_eq(d.position_px, _fsm.action_origin_px)
	assert_eq(d.position_px, start, "the player's position on the start tick")
	assert_eq(d.window_pair, LN)
	_ctx.move_dir = Vector2i(1, 0)
	for i: int in 50:
		_tick()
	assert_ne(_player.position_px, start, "the player walked away")
	assert_eq(d.position_px, start, "the decoy stays at the start point")
	assert_eq(d.frames_left, 70)


func test_decoy_expires_after_120_ticks() -> void:
	assert_true(_ghost_echo())
	for i: int in 119:
		_tick()
	assert_eq(_ghost.decoy.frames_left, 1)
	_tick()
	assert_false(_ghost.decoy.is_live())


func test_second_ghost_echo_replaces_the_decoy() -> void:
	assert_true(_ghost_echo())
	_settle_and_move()
	_fsm.cooldowns.reset()
	var first: Vector2 = _ghost.decoy.position_px
	_buf.push(J, _t)
	_tick()
	_tick()
	_buf.push(K, _t)
	var started: bool = false
	for i: int in 40:
		_tick()
		if _fsm.action == Defs.GHOST_ECHO and _fsm.action_frame == 1:
			started = true
			break
	assert_true(started)
	assert_eq(_ghost.decoy.position_px, _fsm.action_origin_px, "one live decoy, at the new point")
	assert_ne(_ghost.decoy.position_px, first)
	assert_eq(_ghost.decoy.frames_left, 120)


func _settle_and_move() -> void:
	_ctx.move_dir = Vector2i(0, 1)
	for i: int in 45:
		_tick()
	_ctx.move_dir = Vector2i.ZERO
	_tick()


func test_hitstop_freezes_the_decoy() -> void:
	var probe := GhostEchoSystem.new()
	probe.decoy.spawn(SPAWN, LN, 10)
	SimClock.register_system(probe)
	SimClock.hitstop_frames = 3
	for i: int in 3:
		SimClock.tick()
	assert_eq(probe.decoy.frames_left, 10, "frozen by hit-stop")
	SimClock.tick()
	SimClock.unregister_system(probe)
	assert_eq(probe.decoy.frames_left, 9)


# --- AC 6: DECOY_STRUCK ---

func test_strike_on_matching_window_patches_once() -> void:
	var boss: BossController = _boss(LN)
	assert_true(_ghost_echo())
	var hp: int = boss.hp
	_force_active(boss, _ghost.decoy.position_px)
	_tick()
	assert_false(_ghost.decoy.is_live(), "struck once, removed")
	assert_true(boss.weak_window.is_patched())
	assert_eq(boss.weak_window.frames_left, WeakWindowTracker.PATCHED_FRAMES)
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_signal_emit_count(EventBus, "hit_landed", 0)
	assert_eq(boss.hp, hp, "no damage")
	assert_eq(SimClock._pending_hitstop, 0, "no hit-stop")
	_tick()
	assert_signal_emit_count(EventBus, "patched_applied", 1, "never twice")


func test_strike_on_other_window_removes_without_patch() -> void:
	var boss: BossController = _boss(Vector2i(A, D))
	assert_true(_ghost_echo())
	_force_active(boss, _ghost.decoy.position_px)
	_tick()
	assert_false(_ghost.decoy.is_live())
	assert_false(boss.weak_window.is_patched())
	assert_signal_emit_count(EventBus, "patched_applied", 0)


func test_no_strike_outside_hazard_or_active() -> void:
	var boss: BossController = _boss(LN)
	assert_true(_ghost_echo())
	var attack: HazardPulse = _force_active(boss, _ghost.decoy.position_px + Vector2(3 * TILE, 0))
	_tick()
	assert_true(_ghost.decoy.is_live(), "hazard elsewhere")
	attack.hazard_px = _ghost.decoy.position_px
	boss.state = BossController.BossState.TELL
	_tick()
	assert_true(_ghost.decoy.is_live(), "TELL never strikes")
	assert_false(boss.weak_window.is_patched())


func test_no_boss_a_live_decoy_is_harmless() -> void:
	assert_true(_ghost_echo())
	assert_null(_combat.boss)
	for i: int in 5:
		_tick()
	assert_true(_ghost.decoy.is_live(), "no boss: nothing strikes it, it just counts down")
	assert_signal_emit_count(EventBus, "patched_applied", 0)


func test_defeated_boss_clears_the_decoy() -> void:
	var boss: BossController = _boss(LN)
	assert_true(_ghost_echo())
	boss.state = BossController.BossState.DEFEATED
	_tick()
	assert_false(_ghost.decoy.is_live())


func test_decoy_struck_completes_only_its_window() -> void:
	var i := BossInteraction.new(BossInteraction.Kind.DECOY_STRUCK, LN)
	assert_true(BossInteraction.completes_weak_window(i, LN))
	assert_false(BossInteraction.completes_weak_window(i, Vector2i(A, D)))


# --- AC 7: the player never touches the decoy ---

func test_player_hits_never_touch_the_decoy() -> void:
	var boss: BossController = _boss(LN)
	_ghost.decoy.spawn(SPAWN + Vector2(TILE, 0), LN, 120)
	_ring([A, D])
	_buf.push(J, _t)
	for i: int in 25:
		_tick()
	assert_true(_ghost.decoy.is_live(), "a slash over the decoy never dispels it")
	assert_eq(_ghost.decoy.frames_left, 95)
	assert_eq(_fsm.stun_left, 0, "no NullPointerException")
	assert_false(boss.weak_window.is_patched())


# --- AC 5, 8: arena targeting and lifecycle ---

func test_arena_aims_at_the_live_decoy_then_back() -> void:
	var arena := Arena.new()
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TEST_BOSS_DEF_PATH)
	var ctx: ArenaContext = arena.arena_context
	assert_eq(ctx.target_position(), arena.player.position_px)
	assert_same(arena.combat.ghost, arena.ghost_echo.decoy)
	var spot := Vector2(40, 40)
	arena.ghost_echo.decoy.spawn(spot, LN, 120)
	assert_eq(ctx.target_position(), spot, "aim at the decoy")
	assert_eq(ctx.body_contact_position(), arena.player.position_px, "contact stays on the player")
	assert_eq(ctx.target_facing(), arena.player.facing)
	arena.ghost_echo.decoy.clear()
	assert_eq(ctx.target_position(), arena.player.position_px, "restored")
	arena.leave_fight()
	arena.free()


func test_arena_clears_the_decoy_on_entry_retry_and_exit() -> void:
	var arena := Arena.new()
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TEST_BOSS_DEF_PATH)
	arena.ghost_echo.decoy.spawn(Vector2(40, 40), LN, 120)
	arena.leave_fight()
	assert_false(arena.ghost_echo.decoy.is_live(), "exit (death, harvest)")
	arena.ghost_echo.decoy.spawn(Vector2(40, 40), LN, 120)
	arena.enter_fight(Register.fight_start_for_boss(0), false, Arena.TEST_BOSS_DEF_PATH)
	assert_false(arena.ghost_echo.decoy.is_live(), "fight start / retry")
	arena.leave_fight()
	arena.free()


func test_clear_skips_a_pending_spawn() -> void:
	assert_true(_ghost_echo())
	_fsm.decoy_spawn_serial += 1 # a start published but not yet consumed
	_ghost.clear()
	_tick()
	assert_false(_ghost.decoy.is_live())


func test_phase_change_keeps_the_decoy() -> void:
	var boss: BossController = _boss(LN)
	assert_true(_ghost_echo())
	boss.state = BossController.BossState.ROAR
	_tick()
	assert_true(_ghost.decoy.is_live())
	assert_eq(_ghost.decoy.frames_left, 119)


func test_placeholder_label() -> void:
	assert_eq(GhostDecoyView.label_for(LN), Register.glyph_of(L) + Register.glyph_of(N))
