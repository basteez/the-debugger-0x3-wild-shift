extends GutTest
## Story 5.5 (AC 1-4, 11): the NULL bit and Null Dodge through the real ActionStateMachine, Player
## and Register, ticked by hand in SimClock phase order. N is not owned in play before Story 5.6, so
## every test injects a ring that owns N (D-S55-1). J pressed on tick 0 runs action frame f on tick
## f - 1.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
const J := &"action_1"
const K := &"action_2"
const S := ActionStateMachine.ActionState
const SPAWN := Vector2(256, 144)
const EPS := 0.0001

var _buf: InputBuffer
var _ctx: SimContext
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
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
	_t = 0


func _ring(bits: Array) -> void:
	assert_true(_reg.set_fight_start(PackedInt32Array(bits)))


func _tick() -> void:
	_ctx.poll_frame = _t
	_reg.tick(_ctx)
	_fsm.tick(_ctx)
	_player.tick(_ctx)
	_t += 1


func _run(n: int) -> void:
	for i: int in n:
		_tick()


func _settle() -> void:
	var guard: int = 0
	while (_fsm.action != null or _fsm.link.is_open()) and guard < 200:
		_tick()
		guard += 1


func _top_speed() -> float:
	return Const.tiles_per_s_to_px_per_frame(_player.def.speed_tiles_s)


# --- AC 1: data ---

func test_null_bit_and_null_dodge_data() -> void:
	var bit: BitDef = Defs.bit(N)
	assert_not_null(bit, "Defs.bit(NULL_BIT) is no longer null")
	assert_same(bit, Defs.BIT_NULL)
	assert_eq(bit.id, N)
	assert_eq(bit.glyph, "N")
	assert_same(Defs.solo_action(N), Defs.NULL_DODGE)
	var def: ActionDef = Defs.NULL_DODGE
	assert_eq(def.id, &"null_dodge")
	assert_eq(def.startup_frames, 0)
	assert_eq(def.active_frames, 30)
	assert_eq(def.recovery_frames, 8)
	assert_eq(def.total_frames(), 38)
	assert_eq(def.cooldown_frames, 120)
	assert_eq(def.base_damage, 0)
	assert_null(def.hit_shape)
	assert_almost_eq(def.move_tiles, 0.0, EPS)
	assert_eq(def.cancel_into, PackedInt32Array([D]), "D-S55-8: DASH only")
	assert_true(def.slows_move)
	assert_true(def.arms_clean_catch)
	assert_true(def.echoable, "Echo can replay it (AC 8)")
	for f: int in range(1, 31):
		assert_true(def.is_invulnerable_frame(f), "frame %d intangible" % f)
	assert_false(def.is_invulnerable_frame(31), "recovery is not")
	assert_eq(def.validate(), PackedStringArray())
	assert_eq(bit.validate(), PackedStringArray())


func test_cancel_lists_include_null_where_dash_is() -> void:
	for def: ActionDef in [Defs.SLASH_1, Defs.SLASH_2, Defs.SLASH_3, Defs.DASH]:
		assert_true(def.cancel_into.has(D), "%s keeps DASH" % def.id)
		assert_true(def.cancel_into.has(N), "%s cancels into NULL" % def.id)
	for def: ActionDef in [Defs.DASH_STRIKE, Defs.ECHO_DASH, Defs.ECHO, Defs.NOP]:
		assert_false(def.cancel_into.has(N), "%s unchanged (D-S55-7)" % def.id)


func test_new_flag_validation() -> void:
	var a: ActionDef = Defs.NULL_DODGE.duplicate()
	a.invuln_from = 0
	a.invuln_to = 0
	var text: String = "\n".join(a.validate())
	assert_true(text.contains("arms_clean_catch"), text)
	var b: ActionDef = Defs.NULL_DODGE.duplicate()
	b.arms_clean_catch = false
	b.active_frames = 0
	b.startup_frames = 31
	text = "\n".join(b.validate())
	assert_true(text.contains("slows_move action needs active_frames"), text)
	assert_eq(ActionDef.new().validate(), PackedStringArray(), "both flags default off")


# --- AC 1: start from J or K, cooldown ---

func test_j_starts_null_dodge_and_its_cooldown() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_tick()
	assert_same(_fsm.action, Defs.NULL_DODGE)
	assert_eq(_fsm.state, S.ACTIVE, "startup 0: frame 1 is ACTIVE")
	assert_eq(_fsm.cooldowns.remaining(N), 120)
	assert_eq(_fsm.facing, Player.DEFAULT_FACING, "held facing")
	assert_same(_fsm.echo.last, Defs.NULL_DODGE, "remembered for Echo")


func test_k_starts_null_dodge() -> void:
	_ring([A, N])
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.NULL_DODGE)
	assert_eq(_fsm.cooldowns.remaining(N), 120)


func test_cooldown_blocks_a_second_dodge_until_ready() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_tick()
	_settle()
	assert_null(_fsm.action)
	_buf.push(J, _t)
	_tick()
	assert_null(_fsm.action, "N still cooling down")
	while _fsm.cooldowns.remaining(N) > 0:
		_tick()
	_buf.push(J, _t)
	_tick()
	assert_same(_fsm.action, Defs.NULL_DODGE, "ready again after 120 frames")


func test_frames_and_invulnerability_over_the_dodge() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	for f: int in range(1, 39):
		_tick()
		assert_eq(_fsm.action_frame, f)
		assert_eq(_fsm.invulnerable(), f <= 30, "frame %d" % f)
		assert_eq(_fsm.state, S.ACTIVE if f <= 30 else S.RECOVERY, "frame %d" % f)
	_tick()
	assert_null(_fsm.action, "38 frames in total")


# --- AC 4: recovery cancels ---

func test_slash_recovery_cancels_into_null_dodge() -> void:
	_ring([N, A])
	_buf.push(K, _t) # K = A: a solo slash (K opens no link)
	_run(11) # slash_1 frame 11 = first RECOVERY frame
	assert_same(_fsm.action, Defs.SLASH_1)
	assert_eq(_fsm.state, S.RECOVERY)
	_buf.push(J, _t)
	_tick()
	assert_same(_fsm.action, Defs.NULL_DODGE, "cancelled into Null Dodge")
	assert_eq(_fsm.cooldowns.remaining(N), 120)


func test_slash_recovery_link_second_reaches_null_dodge() -> void:
	_ring([A, N])
	_buf.push(J, _t) # J = A opens the link on (A, N): no combo, so K is N's solo as link_second
	_run(11)
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.NULL_DODGE)


func test_no_cancel_while_n_cools_down() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_tick()
	_settle()
	_buf.push(K, _t)
	_run(11)
	assert_same(_fsm.action, Defs.SLASH_1)
	assert_gt(_fsm.cooldowns.remaining(N), 0)
	_buf.push(J, _t)
	_tick()
	assert_same(_fsm.action, Defs.SLASH_1, "N on cooldown: no cancel")


func test_dash_recovery_cancels_into_null_dodge() -> void:
	_ring([D, N])
	_buf.push(J, _t)
	_run(11) # dash frame 11 = first RECOVERY frame
	assert_same(_fsm.action, Defs.DASH)
	_buf.push(K, _t)
	_tick()
	assert_same(_fsm.action, Defs.NULL_DODGE)


# --- AC 2: half speed on the active frames, no dash distance ---

func test_move_slowed_exactly_on_the_active_frames() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	for f: int in range(1, 39):
		_tick()
		assert_eq(_ctx.move_slowed, f <= 30, "frame %d" % f)
	_tick()
	assert_false(_ctx.move_slowed)


func test_half_top_speed_during_the_dodge_and_normal_after() -> void:
	_ring([N, A])
	_ctx.move_dir = Vector2i(1, 0)
	_buf.push(J, _t)
	_run(20)
	assert_false(_player.locked, "free movement while dodging (D-S55-13)")
	assert_almost_eq(_player.velocity_px.length(), _top_speed() * 0.5, EPS, "x0.5 top speed")
	_run(10) # frame 30, the last active frame
	assert_almost_eq(_player.velocity_px.length(), _top_speed() * 0.5, EPS)
	_tick() # frame 31: recovery, the ramp climbs again
	assert_gt(_player.velocity_px.length(), _top_speed() * 0.5 + EPS, "speed returns on the first frame after")
	_run(10)
	assert_almost_eq(_player.velocity_px.length(), _top_speed(), EPS)


func test_watch_and_dodge_do_not_stack() -> void:
	_ring([N, A])
	_ctx.move_dir = Vector2i(1, 0)
	_buf.push(J, _t)
	_run(5)
	_ctx.watch_held = true
	_run(10)
	assert_same(_fsm.action, Defs.NULL_DODGE, "a running dodge keeps its frames under Watch")
	assert_true(_ctx.move_slowed)
	assert_almost_eq(_player.velocity_px.length(), _top_speed() * 0.5, EPS, "one x0.5, not x0.25")


func test_the_dodge_itself_moves_zero_tiles() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_run(38)
	assert_eq(_player.position_px, SPAWN, "no dash distance")


func test_stun_clears_move_slowed() -> void:
	_ring([N, A])
	_buf.push(J, _t)
	_run(3)
	assert_true(_ctx.move_slowed)
	_fsm.begin_stun(5)
	_tick()
	assert_false(_ctx.move_slowed)


# --- AC 8: an Echo of Null Dodge is the same def ---

func test_echo_of_null_dodge_runs_the_same_def() -> void:
	_ring([L, A])
	_fsm.echo.remember(Defs.NULL_DODGE)
	_buf.push(J, _t)
	_tick()
	assert_true(_fsm.echoing)
	assert_same(_fsm.action, Defs.NULL_DODGE)
	assert_true(_fsm.invulnerable())
	assert_true(_ctx.move_slowed)
	assert_eq(_fsm.cooldowns.remaining(N), 0, "Echo starts LOOP's cooldown only")


# --- AC 11: the default register never reaches N ---

func test_default_register_does_not_own_n() -> void:
	var reg := Register.new(_buf)
	assert_false(reg.ring.has(N))
