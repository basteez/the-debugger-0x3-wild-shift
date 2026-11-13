extends GutTest
## Story 4.2: Echo Dash (D->L combo), the gap-free acceptance rule (D-S42-4 resolved, D-S42-11),
## the redirect, the PASS_THROUGH producer and the Story 4.1 deferred items. The real FSM, Player,
## Register and CombatResolver are ticked by hand in SimClock phase order. J pressed on tick 0 runs
## dash frame f on tick f - 1, so before tick t the dash's last executed frame is t.

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
const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")

var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _combat: CombatResolver
var _t: int = 0
var _il_shifts: int = 0


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
	_combat = CombatResolver.new(_fsm, _player)
	_t = 0
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	watch_signals(EventBus)


func after_each() -> void:
	SimClock._pending_hitstop = 0
	SimClock.hitstop_frames = 0
	_combat = null
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
	_combat.tick(_ctx)
	_t += 1


func _run_to(until: int) -> void:
	while _t < until:
		_tick()


func _settle() -> void:
	var guard: int = 0
	while (_fsm.action != null or _fsm.link.is_open()) and guard < 200:
		_tick()
		guard += 1


## Dash on [D, L] from tick 0, then K pushed on tick `press` (the dash's last executed frame is
## `press` when that tick resolves). Returns after the press tick.
func _dash_then_k(press: int) -> void:
	_ring([D, L])
	_buf.push(J, 0)
	_run_to(press)
	_buf.push(K, _t)
	_tick()


func _boss(weak: Vector2i, pos: Vector2) -> BossController:
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
	c.body_center_px = pos
	_combat.boss = c
	return c


func _boss_hits() -> int:
	var n: int = 0
	for i: int in get_signal_emit_count(EventBus, "hit_landed"):
		if get_signal_parameters(EventBus, "hit_landed", i)[0] == &"boss":
			n += 1
	return n


# --- AC1, AC9: data and validation ---

func test_echo_dash_def_data() -> void:
	var def: ActionDef = Defs.ECHO_DASH
	assert_eq(def.id, &"echo_dash")
	assert_eq([def.startup_frames, def.active_frames, def.recovery_frames], [0, 10, 6])
	assert_eq([def.invuln_from, def.invuln_to], [1, 10])
	assert_eq(def.move_tiles, 4.0)
	assert_eq(def.base_damage, 0)
	assert_eq(def.cooldown_frames, 0)
	assert_false(def.echoable)
	assert_false(def.echo_action)
	assert_true(def.redirectable)
	assert_true(def.pass_through)
	assert_eq(def.cancel_into, PackedInt32Array())
	assert_true(def.hit_shape is HitCapsule)
	var cap := def.hit_shape as HitCapsule
	assert_eq([cap.length_tiles, cap.radius_tiles], [4.0, 0.5])
	assert_eq(def.validate(), PackedStringArray())


func test_d_then_l_is_echo_dash_and_the_table_validates() -> void:
	var c: ComboDef = Defs.COMBOS.get_combo(D, L)
	assert_not_null(c)
	if c == null:
		return
	assert_same(c.action, Defs.ECHO_DASH)
	assert_eq(c.display_name, "Echo Dash")
	assert_true(c.gap_free)
	assert_null(Defs.COMBOS.get_combo(L, D), "ordered")
	assert_eq(Defs.COMBOS.validate(), PackedStringArray())
	assert_eq(c.validate(), PackedStringArray())


func test_action_def_flag_validation() -> void:
	var pt: ActionDef = Defs.ECHO_DASH.duplicate()
	pt.base_damage = 5
	assert_eq(pt.validate().size(), 1, "pass_through with damage")
	pt = Defs.ECHO_DASH.duplicate()
	pt.hit_shape = null
	assert_eq(pt.validate().size(), 1, "pass_through without a shape")
	var rd: ActionDef = Defs.ECHO_DASH.duplicate()
	rd.move_tiles = 0.0
	assert_eq(rd.validate().size(), 1, "redirectable without movement")
	var idle: ActionDef = Defs.ECHO_DASH.duplicate()
	idle.startup_frames = 10
	idle.active_frames = 0
	var text: String = "\n".join(idle.validate())
	assert_true(text.contains("pass_through action needs active_frames"), text)
	assert_true(text.contains("redirectable action needs active_frames"), text)


func _combo(first: int, second: int, action: ActionDef) -> ComboDef:
	var c := ComboDef.new()
	c.first = first
	c.second = second
	c.action = action
	c.display_name = "Test"
	return c


func test_combo_def_validation_additions() -> void:
	assert_eq(_combo(D, L, Defs.ECHO_DASH).validate().size(), 0)
	# Story 5.5: N has a solo action now; the check is exercised by clearing it for one call.
	assert_eq(_combo(A, N, Defs.DASH_STRIKE).validate().size(), 0, "N's solo is Null Dodge")
	var null_bit: BitDef = Defs.BIT_NULL
	var null_solo: ActionDef = null_bit.solo_action
	null_bit.solo_action = null
	var no_solo: int = _combo(A, N, Defs.DASH_STRIKE).validate().size()
	null_bit.solo_action = null_solo
	assert_eq(no_solo, 1, "second bit without a solo action")
	assert_eq(_combo(A, D, Defs.DASH).validate().size(), 1, "combo action with a cooldown")
	var gap := _combo(D, L, Defs.DASH_STRIKE)
	gap.gap_free = true
	assert_eq(gap.validate().size(), 0, "Dash Strike is invulnerable from frame 1")
	gap.action = Defs.SLASH_1
	assert_eq(gap.validate().size(), 1, "gap_free needs an action invulnerable from frame 1")
	# J startup + 1 > 8: shipped defs are read-only at runtime, restored right after.
	var slash: ActionDef = Defs.SLASH_1
	var startup: int = slash.startup_frames
	slash.startup_frames = 8
	var errors: PackedStringArray = _combo(A, D, Defs.DASH_STRIKE).validate()
	slash.startup_frames = startup
	assert_eq(errors.size(), 1, "first solo startup 8")


# --- AC2: trigger and cost ---

func test_k_during_the_dash_fires_echo_dash_with_loop_cooldown_only() -> void:
	_dash_then_k(4)
	assert_same(_fsm.action, Defs.ECHO_DASH)
	assert_not_null(_fsm.combo)
	assert_eq(_fsm.combo.display_name, "Echo Dash")
	assert_false(_fsm.echoing)
	assert_false(_fsm.link_second)
	assert_eq(_fsm.action_frame, 1, "Echo Dash frame 1 runs on the press tick")
	assert_eq(_fsm.action_window, Vector2i(D, L))
	assert_eq(_fsm.cooldowns.remaining(L), 90)
	assert_eq(_fsm.cooldowns.remaining(D), 24 - 4, "the first dash's cooldown, untouched")
	assert_same(_fsm.echo.last, Defs.DASH, "Echo Dash is not stored")
	assert_false(_fsm.link.is_open(), "one link, one K")


func test_k_pressed_with_j_fires_echo_dash_on_the_next_tick() -> void:
	_ring([D, L])
	_buf.push(J, 0)
	_buf.push(K, 0)
	_tick()
	assert_same(_fsm.action, Defs.DASH)
	_tick()
	assert_same(_fsm.action, Defs.ECHO_DASH)


func test_echo_dash_needs_no_echo_memory() -> void:
	var link := LinkState.new()
	link.open(Vector2i(D, L), 0)
	var buf := InputBuffer.new()
	buf.push(K, 3)
	var input := ResolveInput.new()
	input.buffer = buf
	input.frame = 3
	input.window = Vector2i(D, L)
	input.action = Defs.DASH
	input.action_frame = 3
	input.cooldowns = Cooldowns.new()
	input.link = link
	input.echo_ready = false
	var r: ActionRequest = ActionResolver.resolve(input)
	assert_not_null(r)
	if r == null:
		return
	assert_same(r.def, Defs.ECHO_DASH)
	assert_not_null(r.combo)
	assert_eq(r.bit, L)
	assert_false(r.link_second)


func test_a_cooling_down_loop_keeps_the_press_buffered() -> void:
	var link := LinkState.new()
	link.open(Vector2i(D, L), 0)
	var buf := InputBuffer.new()
	buf.push(K, 3)
	var cd := Cooldowns.new()
	cd.start(L, 10)
	var input := ResolveInput.new()
	input.buffer = buf
	input.frame = 3
	input.window = Vector2i(D, L)
	input.action = Defs.DASH
	input.action_frame = 3
	input.cooldowns = cd
	input.link = link
	assert_null(ActionResolver.resolve(input))
	assert_eq(buf.size(), 1, "not consumed, expires normally")


# --- AC3 / D-S42-4 resolved: no vulnerable frame between the dashes, for every accepted press ---

func _assert_continuous(press: int) -> void:
	_ring([D, L])
	_buf.push(J, 0)
	var frames: Array[bool] = []
	while _t < press:
		_tick()
		frames.append(_fsm.invulnerable())
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.ECHO_DASH, "press on dash frame %d accepted" % (press + 1))
	frames.append(_fsm.invulnerable())
	while _fsm.action_frame < 10:
		_tick()
		frames.append(_fsm.invulnerable())
	assert_eq(frames.size(), press + 10, "dash frames 1..%d then Echo Dash 1..10" % press)
	assert_false(frames.has(false), "press %d: every executed frame invulnerable %s" % [press, frames])
	_tick()
	assert_false(_fsm.invulnerable(), "Echo Dash frame 11 is vulnerable")


func test_press_after_dash_frame_1_is_continuous() -> void:
	_assert_continuous(1)


func test_press_after_dash_frame_5_is_continuous() -> void:
	_assert_continuous(5)


## Boundary: the dash's last invulnerable frame is 8, so a press resolving after frame 8 (Echo Dash
## replaces dash frame 9) is the last accepted one.
func test_press_after_dash_frame_8_is_the_last_accepted_and_continuous() -> void:
	_assert_continuous(8)


func _assert_refused(press: int) -> void:
	_ring([D, L])
	_buf.push(J, 0)
	_run_to(press)
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.DASH, "press %d refused: the dash keeps running" % press)
	assert_false(_buf.consume(K, _t), "press %d consumed and dropped, not buffered" % press)
	assert_false(_fsm.link.held, "never held")
	assert_eq(_fsm.cooldowns.remaining(L), 0, "no LOOP cooldown")
	_settle()
	_run_to(_t + 10)
	assert_null(_fsm.action, "no Echo or Echo Dash after the link closes")
	assert_eq(_fsm.cooldowns.remaining(L), 0)


## Boundary: after dash frame 9 (vulnerable) the window refuses the press (D-S42-4 resolved).
func test_press_after_dash_frame_9_is_refused() -> void:
	_assert_refused(9)


func test_press_in_dash_recovery_is_refused() -> void:
	_assert_refused(12)


func test_press_after_the_dash_while_the_link_counts_is_refused() -> void:
	_ring([D, L])
	_buf.push(J, 0)
	_run_to(20)
	assert_null(_fsm.action)
	assert_true(_fsm.link.is_open(), "link still counting")
	_buf.push(K, _t)
	_tick()
	assert_null(_fsm.action, "refused: no dash is running")
	assert_false(_buf.consume(K, _t))


func test_gap_free_ok_boundaries() -> void:
	assert_false(ActionResolver.gap_free_ok(null, 0))
	assert_false(ActionResolver.gap_free_ok(Defs.DASH, 0))
	for f: int in range(1, 9):
		assert_true(ActionResolver.gap_free_ok(Defs.DASH, f), "dash frame %d" % f)
	for f: int in [9, 10, 11, 16]:
		assert_false(ActionResolver.gap_free_ok(Defs.DASH, f), "dash frame %d" % f)


# --- AC4: redirect ---

func _echo_dash_with_input(dir: Vector2i) -> void:
	_ring([D, L])
	_ctx.move_dir = Vector2i(-1, 0)
	_tick() # turn left
	_ctx.move_dir = Vector2i.ZERO
	_run_to(12) # stop walking
	_buf.push(J, _t)
	_tick()
	assert_same(_fsm.action, Defs.DASH)
	assert_eq(_fsm.facing, Vector2i(-1, 0))
	_run_to(_t + 3)
	_ctx.move_dir = dir
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.ECHO_DASH)


func test_redirect_right_moves_4_tiles_right() -> void:
	_echo_dash_with_input(Vector2i(1, 0))
	assert_eq(_fsm.facing, Vector2i(1, 0))
	assert_eq(_player.facing, Vector2i(-1, 0), "the FSM does not write Player.facing")
	var origin: Vector2 = _fsm.action_origin_px
	_run_to(_t + 9)
	assert_eq(_fsm.action_frame, 10)
	assert_almost_eq(_player.position_px.x, origin.x + 4.0 * TILE, 0.001)
	assert_almost_eq(_player.position_px.y, origin.y, 0.001)


func test_no_input_keeps_the_first_dash_facing() -> void:
	_echo_dash_with_input(Vector2i.ZERO)
	assert_eq(_fsm.facing, Vector2i(-1, 0))
	var origin: Vector2 = _fsm.action_origin_px
	_run_to(_t + 9)
	assert_almost_eq(_player.position_px.x, origin.x - 4.0 * TILE, 0.001)


func test_diagonal_input_is_sanitized() -> void:
	_echo_dash_with_input(Vector2i(3, -2))
	assert_eq(_fsm.facing, Player.sanitize_dir(Vector2i(3, -2)))
	assert_eq(_fsm.facing, Vector2i(1, -1))
	var origin: Vector2 = _fsm.action_origin_px
	_run_to(_t + 9)
	var moved: Vector2 = _player.position_px - origin
	assert_almost_eq(moved.length(), 4.0 * TILE, 0.01)
	assert_almost_eq(moved.x, -moved.y, 0.01)


func test_redirect_is_ignored_for_non_redirectable_actions() -> void:
	_ring([D, A])
	_ctx.move_dir = Vector2i(0, -1)
	_buf.push(J, 0)
	_tick()
	assert_same(_fsm.action, Defs.DASH)
	assert_eq(_fsm.facing, Player.DEFAULT_FACING)


# --- AC5, AC6, AC7: PASS_THROUGH ---

func test_pass_through_on_the_weak_window_patches_once_without_damage() -> void:
	var boss: BossController = _boss(Vector2i(D, L), SPAWN + Vector2(56, 0))
	_dash_then_k(3)
	assert_same(_fsm.action, Defs.ECHO_DASH)
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	assert_signal_emitted_with_parameters(EventBus, "patched_applied", [&"unit_boss", 180])
	assert_eq(boss.weak_window.frames_left, 180)
	assert_eq(boss.last_hit_serial, _fsm.action_serial, "marked by the action's serial")
	while _fsm.action != null:
		_tick()
	assert_signal_emit_count(EventBus, "patched_applied", 1, "at most once per action")
	assert_eq(boss.hp, 100, "no damage")
	assert_eq(_boss_hits(), 0, "no hit_landed")
	assert_signal_emit_count(EventBus, "hit_landed", 0)
	assert_eq(SimClock._pending_hitstop, 0, "no hit-stop")


func test_echo_dash_through_the_segfault_claw_patches_in_phase_one() -> void:
	# Story 6.3 AC 18: the claw's ACTIVE frames are hazardous but the body is still hittable.
	var sf_def: BossDef = load("res://data/bosses/segfault/boss_def.tres")
	var arena := ArenaContext.new()
	arena.target_source = func() -> Vector2: return Vector2(300, 150)
	arena.contact_source = func() -> Vector2: return Vector2(-1000, -1000)
	var sf := SegfaultBody.new()
	assert_true(sf.setup(sf_def, null, arena))
	sf.reset_for_fight()
	var guard: int = 0
	while not (sf.state == BossController.BossState.ACTIVE and sf.tiles.attack_cells == 0) and guard < 900:
		sf.tick(_ctx)
		guard += 1
	assert_eq(sf.state, BossController.BossState.ACTIVE, "in the claw's ACTIVE frames")
	assert_eq(sf.phase_index, 0)
	var win: Vector2i = sf.current_weak_window()
	_ring([win.x, win.y])
	sf.body_center_px = SPAWN + Vector2(56, 0)
	_combat.boss = sf
	_buf.push(J, 0)
	_run_to(3)
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.ECHO_DASH)
	assert_true(sf.weak_window.is_patched(), "Patched through the claw")
	assert_eq(sf.hp, sf_def.max_hp, "no damage")


func test_pass_through_on_the_wrong_window_does_not_patch() -> void:
	var boss: BossController = _boss(Vector2i(L, A), SPAWN + Vector2(56, 0))
	_dash_then_k(3)
	while _fsm.action != null:
		_tick()
	assert_false(boss.weak_window.is_patched())
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_eq(boss.hp, 100)
	assert_ne(boss.last_hit_serial, -1, "the pass-through still happened")


func test_pass_through_on_a_non_hittable_boss_does_nothing() -> void:
	var boss: BossController = _boss(Vector2i(D, L), SPAWN + Vector2(56, 0))
	boss.set_active(false)
	_dash_then_k(3)
	while _fsm.action != null:
		_tick()
	assert_false(boss.weak_window.is_patched())
	assert_eq(boss.last_hit_serial, -1)


func test_echo_dash_never_hits_practice_targets() -> void:
	var target := PracticeTarget.new(SPAWN + Vector2(56, 0))
	_combat.targets.append(target)
	_dash_then_k(3)
	while _fsm.action != null:
		_tick()
	assert_eq(target.records().size(), 0)
	assert_signal_emit_count(EventBus, "hit_landed", 0)
	assert_eq(SimClock._pending_hitstop, 0)


func test_a_hit_during_patched_takes_x1_5() -> void:
	var boss: BossController = _boss(Vector2i(D, L), SPAWN + Vector2(56, 0))
	_dash_then_k(3)
	_settle()
	assert_true(boss.weak_window.is_patched())
	_ring([A, D])
	boss.body_center_px = _player.position_px + Vector2(32, 0)
	_buf.push(J, _t)
	_run_to(_t + 10)
	assert_eq(boss.hp, 100 - DamageCalc.compute(10, 1.5, false, 1.0), "slash 10 x 1.5")


func _loop(at: Vector2, open: bool) -> InfiniteLoopBody:
	_il_shifts = 0
	var ctx := ArenaContext.new()
	ctx.shift_count = func() -> int: return _il_shifts
	var b := InfiniteLoopBody.new()
	assert_true(b.setup(IL_DEF, null, ctx))
	b.reset_for_fight()
	var centre: Vector2 = b.body_center_px
	ctx.contact_source = func() -> Vector2: return centre
	if open:
		_il_shifts = 1
		b.tick(SimContext.new())
		assert_true(b.is_open())
	b.body_center_px += at - b.segment_px(0)
	_combat.boss = b
	return b


func test_closed_semicolon_produces_no_pass_through() -> void:
	var b: InfiniteLoopBody = _loop(SPAWN + Vector2(56, 0), false)
	_dash_then_k(3)
	while _fsm.action != null:
		_tick()
	assert_eq(b.last_hit_serial, -1)
	assert_signal_emit_count(EventBus, "patched_applied", 0)
	assert_eq(b.hp, 400)


func test_open_semicolon_passes_through_but_d_l_is_not_a_loop_window() -> void:
	var b: InfiniteLoopBody = _loop(SPAWN + Vector2(56, 0), true)
	_dash_then_k(3)
	while _fsm.action != null:
		_tick()
	assert_ne(b.last_hit_serial, -1, "PASS_THROUGH happened on the open `;`")
	assert_signal_emit_count(EventBus, "patched_applied", 0, "D->L is no Infinite Loop weak window")
	assert_eq(b.hp, 400)


# --- AC8a: Echo as link_second on a no-combo window (4.1 deferred) ---

func _echo_link_second_on(weak: Vector2i) -> BossController:
	_fsm.combos = ComboTable.new() # D-S42-7: a table with no entries, so [A, L] has no combo
	_ring([A, L])
	var boss: BossController = _boss(weak, SPAWN + Vector2(40, 0))
	_buf.push(J, 0)
	_run_to(10) # slash_1 ACTIVE done: its solo HIT landed
	assert_eq(_boss_hits(), 1)
	assert_false(boss.weak_window.is_patched(), "a solo HIT never completes the window")
	_buf.push(K, _t) # held by the link until slash_1 ends
	var guard: int = 0
	while _boss_hits() < 2 and guard < 40:
		SimClock._pending_hitstop = 0
		_tick()
		guard += 1
	assert_true(_fsm.echoing)
	assert_true(_fsm.link_second)
	assert_eq(_boss_hits(), 2)
	return boss


func test_echo_link_second_completes_the_matching_window() -> void:
	var boss: BossController = _echo_link_second_on(Vector2i(A, L))
	assert_true(boss.weak_window.is_patched())
	assert_signal_emit_count(EventBus, "patched_applied", 1)
	var params: Array = get_signal_parameters(EventBus, "hit_landed", 1)
	assert_eq(params[2], DamageState.Kind.PATCHED)
	assert_false(params[3], "a link_second is not a combo")


func test_echo_link_second_on_another_window_does_not_complete() -> void:
	var boss: BossController = _echo_link_second_on(Vector2i(D, A))
	assert_false(boss.weak_window.is_patched())
	assert_signal_emit_count(EventBus, "patched_applied", 0)


# --- AC8b: echoed cancel_into and the link opened by an Echo run (4.1 deferred) ---

func _echo_of(def: ActionDef) -> void:
	_ring([L, A])
	_fsm.echo.remember(def)
	_buf.push(J, 0)
	_tick()
	assert_true(_fsm.echoing)
	assert_same(_fsm.action, def)


func test_an_echo_run_opens_the_link_on_l_y() -> void:
	_echo_of(Defs.DASH)
	assert_true(_fsm.link.is_open(), "echoed frame 1 is ACTIVE: link opens")
	assert_eq(_fsm.link.pair, Vector2i(L, A))


func test_an_echoed_def_cancels_into_its_cancel_into_bits() -> void:
	var dash_a: ActionDef = Defs.DASH.duplicate()
	dash_a.cancel_into = PackedInt32Array([A])
	_echo_of(dash_a)
	_run_to(11) # echoed dash frame 11 = first RECOVERY frame
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.SLASH_1, "cancelled the echoed dash's recovery into A")
	assert_true(_fsm.link_second)


func test_an_echoed_def_without_the_bit_does_not_cancel() -> void:
	_echo_of(Defs.DASH) # cancel_into = [D]
	_run_to(11)
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.DASH, "no cancel into A: the press is held")
	assert_true(_fsm.link.held)
	_run_to(17)
	assert_same(_fsm.action, Defs.SLASH_1, "starts once the echoed dash ends")
