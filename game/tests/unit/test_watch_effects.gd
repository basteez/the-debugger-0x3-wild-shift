extends GutTest
## Story 5.4 (AC 4, 5, 6, 21): Watch's effects in the core systems, driven by SimContext.watch_held
## only. Half speed through the same ramp (facing still set), J/K presses discarded while held, a
## running action finishes, WATCHING when idle, shifts unaffected, a stun keeps its rule, no damage
## or boss change.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
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


func _press(key: StringName) -> void:
	_buf.push(key, _t)


func _top_speed() -> float:
	return Const.tiles_per_s_to_px_per_frame(_player.def.speed_tiles_s)


# --- AC 4: half speed ---

func test_half_top_speed_while_held() -> void:
	_ctx.watch_held = true
	_ctx.move_dir = Vector2i(1, 0)
	for i: int in 20:
		_tick()
	assert_almost_eq(_player.velocity_px.length(), _top_speed() * 0.5, EPS, "x0.5 top speed")
	assert_eq(Player.WATCH_SPEED_FACTOR, 0.5)


func test_same_ramp_shape_at_half_speed() -> void:
	_ctx.watch_held = true
	_ctx.move_dir = Vector2i(1, 0)
	_tick()
	var step: float = _top_speed() * 0.5 / _player.def.accel_frames
	assert_almost_eq(_player.velocity_px.x, step, EPS, "one accel step of the halved ramp")


func test_release_returns_to_full_speed() -> void:
	_ctx.move_dir = Vector2i(0, 1)
	_ctx.watch_held = true
	for i: int in 10:
		_tick()
	_ctx.watch_held = false
	for i: int in 10:
		_tick()
	assert_almost_eq(_player.velocity_px.length(), _top_speed(), EPS)


func test_direction_still_sets_facing_while_held() -> void:
	_ctx.watch_held = true
	_ctx.move_dir = Vector2i(-1, 1)
	_tick()
	assert_eq(_player.facing, Vector2i(-1, 1))


# --- AC 5: no new actions ---

func test_j_and_k_presses_are_discarded_while_held() -> void:
	_ring([A, D])
	_ctx.watch_held = true
	_press(J)
	_press(K)
	_tick()
	assert_null(_fsm.action, "no action starts")
	assert_eq(_fsm.state, S.WATCHING, "idle under Watch reports WATCHING")
	_ctx.watch_held = false
	_tick()
	assert_null(_fsm.action, "the press was dropped, not kept for later")
	assert_eq(_fsm.state, S.IDLE_MOVE)


func test_k_held_in_link_is_dropped_with_the_link_and_never_outlives_it() -> void:
	_ring([A, D])
	_press(J)
	for i: int in 8: # J reaches its first ACTIVE frame: the link is open
		_tick()
	assert_true(_fsm.link.is_open())
	_fsm.link.hold(K, 1, _t)
	_ctx.watch_held = true
	for i: int in LinkState.LINK_FRAMES + 40: # Watch outlasts the link window
		_tick()
	assert_false(_fsm.link.is_open(), "the link still ages under Watch")
	assert_false(_fsm.link.held, "a held K cannot survive its link window")
	_ctx.watch_held = false
	_tick()
	assert_eq(_fsm.action_slot, -1, "nothing fires on release")


func test_running_action_finishes_under_watch() -> void:
	_ring([A, D])
	_press(J)
	_tick() # slash frame 1
	assert_eq(_fsm.action, Defs.SLASH_1)
	var serial: int = _fsm.action_serial
	_ctx.watch_held = true
	var states: Array = []
	for i: int in 21: # frames 2..22
		_tick()
		states.append(_fsm.state)
	assert_eq(_fsm.action_frame, 22, "the slash ran its normal frames")
	assert_eq(_fsm.action_serial, serial, "no other action started")
	assert_true(states.has(S.ACTIVE))
	assert_true(states.has(S.RECOVERY))
	_tick()
	assert_null(_fsm.action)
	assert_eq(_fsm.state, S.WATCHING, "finished, still held: WATCHING")


func test_press_during_running_action_does_not_chain_or_cancel() -> void:
	_ring([A, D])
	_press(J)
	_tick()
	_ctx.watch_held = true
	for i: int in 8:
		_press(J)
		_press(K)
		_tick()
	assert_eq(_fsm.action, Defs.SLASH_1, "no chain hit, no cancel while held")
	assert_eq(_fsm.action_frame, 9)


func test_slash_link_still_opens_under_watch() -> void:
	_ring([A, D])
	_press(J)
	_tick()
	_ctx.watch_held = true
	for i: int in 6: # frames 2..7: frame 7 is the first ACTIVE frame
		_tick()
	assert_true(_fsm.link.is_open(), "the running J action's link keeps its rule")


func test_movement_is_unlocked_while_watching() -> void:
	_ctx.watch_held = true
	_tick()
	assert_false(_player.locked)


func test_stun_keeps_its_rule_under_watch() -> void:
	_fsm.begin_stun(3, &"test")
	_ctx.watch_held = true
	_tick()
	assert_eq(_fsm.state, S.STUNNED, "stun first, then Watch")
	assert_true(_player.locked)


# --- Shifts stay usable ---

func test_shifts_apply_while_held() -> void:
	_ring([A, D])
	_ctx.watch_held = true
	var serial: int = _reg.shift_serial
	_press(&"shift_left")
	_tick()
	assert_eq(_reg.shift_serial, serial + 1, "a Q shift applies under Watch")
	assert_eq(_fsm.state, S.WATCHING)


func test_breakpoint_press_reaches_the_breakpoint_skill_under_watch() -> void:
	var clock: Node = load("res://src/autoloads/sim_clock.gd").new()
	var bp: FightSkill = Arena.make_breakpoint_skill(true)
	if bp == null:
		clock.free()
		pending("Breakpoint cut in this build")
		return
	bp.set(&"_gate", clock)
	bp.reset_for_fight(true)
	var ctx := SimContext.new()
	ctx.watch_held = true
	bp.poll([&"breakpoint"] as Array[StringName], ctx)
	assert_true(bp.is_active(), "Breakpoint is not an action: Watch does not block it")
	bp.end_fight()
	clock.free()


# --- AC 6: nothing else changes ---

func test_no_damage_scale_or_rng_change() -> void:
	_ring([A, D])
	var rng_state: int = _ctx.rng.state
	_press(J)
	_tick()
	_ctx.watch_held = true
	_tick()
	assert_eq(_fsm.echo_scale(), 1.0)
	assert_eq(_ctx.rng.state, rng_state, "Watch draws no RNG")


func test_core_files_outside_player_and_body_never_read_watch() -> void:
	for path: String in [
		"res://src/combat/combat_resolver.gd",
		"res://src/bosses/framework/boss_controller.gd",
		"res://src/player/player_health.gd",
	]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", "%s exists" % path)
		assert_false(text.to_lower().contains("watch"), "%s reads no Watch state" % path)
	for sub: String in ["infinite_loop/attacks", "null_pointer/attacks"]:
		var d := DirAccess.open("res://src/bosses/" + sub)
		assert_not_null(d, sub)
		if d == null:
			continue
		for f: String in d.get_files():
			if f.ends_with(".gd"):
				assert_false(FileAccess.get_file_as_string("res://src/bosses/%s/%s" % [sub, f]).to_lower().contains("watch"),
						"attack script %s reads no Watch" % f)
