extends GutTest
## Story 5.3 AC 13-17, 21: NullPointerException. A real Register, ActionStateMachine, Player and
## CombatResolver ticked in SimClock phase order against a Null Pointer held still in GAP (a
## test-only body: no drift, no attack). An ATTACK slash that lands nothing with the boss centre
## within 4 tiles stuns for 20 frames; every other case does not.

const NP_DEF: BossDef = preload("res://data/bosses/null_pointer/boss_def.tres")
const IL_DEF: BossDef = preload("res://data/bosses/infinite_loop/boss_def.tres")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")
const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const J := &"action_1"
const K := &"action_2"
const SPAWN := Vector2(256, 144)
const TILE := Const.TILE_PX
const AS := ActionStateMachine.ActionState
## Slash 1: 6 startup + 4 active frames; its last ACTIVE frame is executed on the 10th tick.
const SLASH_LAST_ACTIVE := 10


## Test-only body: holds still and never attacks, so distances are exact.
class StillBody:
	extends NullPointerBody

	func _drift(_rng: RandomNumberGenerator) -> void:
		pass

	func _attacks_allowed() -> bool:
		return false


var _buf: InputBuffer
var _player: Player
var _reg: Register
var _fsm: ActionStateMachine
var _combat: CombatResolver
var _ctx: SimContext
var _t: int = 0


func before_each() -> void:
	SimClock._pending_hitstop = 0
	_t = 0


func after_each() -> void:
	SimClock._pending_hitstop = 0


func _rig(bits: Array, boss: BossController) -> void:
	_buf = InputBuffer.new()
	_player = Player.new(PLAYER_DEF, Arena.player_bounds())
	_player.reset_for_fight(SPAWN)
	_player.set_active(true)
	_reg = Register.new(_buf)
	_reg.set_active(true)
	assert_true(_reg.set_fight_start(PackedInt32Array(bits)))
	_fsm = ActionStateMachine.new(_buf, _player, _reg)
	_fsm.reset_for_fight()
	_fsm.set_active(true)
	_combat = CombatResolver.new(_fsm, _player)
	_combat.boss = boss
	_ctx = SimContext.new()
	_ctx.reseed(53)


## A still Null Pointer whose centre is at `offset` from the player's spawn.
func _np_at(offset: Vector2) -> StillBody:
	var b := StillBody.new()
	assert_true(b.setup(NP_DEF, null, ArenaContext.new()))
	b.reset_for_fight()
	_place(b, SPAWN + offset)
	return b


func _place(b: NullPointerBody, p: Vector2) -> void:
	b.pos_mtiles = Vector2i((p * NullPointerBody.MILLI / float(TILE)).round())
	b.body_center_px = p


## One tick in SimClock phase order (SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, COMBAT).
func _tick(times: int = 1) -> void:
	for i: int in times:
		_ctx.poll_frame = _t
		_reg.tick(_ctx)
		_fsm.tick(_ctx)
		_player.tick(_ctx)
		if _combat.boss != null:
			_combat.boss.tick(_ctx)
		_combat.tick(_ctx)
		SimClock._pending_hitstop = 0
		_t += 1


## Presses `key` and runs the action through its last ACTIVE frame.
func _press_and_run(key: StringName) -> void:
	_buf.push(key, _t)
	_tick(SLASH_LAST_ACTIVE)


# --- AC 13: a miss within 4 tiles stuns for 20 frames ---

func test_a_slash_that_misses_within_4_tiles_stuns_for_20_frames() -> void:
	_rig([A, D], _np_at(Vector2(3 * TILE, 0)))
	watch_signals(EventBus)
	_press_and_run(J)
	assert_eq(_fsm.stun_left, CombatResolver.NPE_STUN_FRAMES, "requested at the whiff tick")
	assert_null(_fsm.action, "the running slash is cancelled")
	assert_signal_emit_count(EventBus, "player_stunned", 1)
	assert_signal_emitted_with_parameters(EventBus, "player_stunned", [&"NullPointerException"])
	for i: int in 20:
		_tick()
		assert_eq(_fsm.state, AS.STUNNED, "stunned frame %d" % (i + 1))
	_tick()
	assert_eq(_fsm.state, AS.IDLE_MOVE, "free on the 21st tick")
	assert_signal_emit_count(EventBus, "player_stunned", 1, "emitted once")


func test_the_range_is_4_tiles_centre_to_centre_edge_included() -> void:
	_rig([A, D], _np_at(Vector2(4 * TILE, 0)))
	_press_and_run(J)
	assert_eq(_fsm.stun_left, 20, "exactly 4 tiles stuns")


func test_a_miss_at_4_tiles_plus_1_px_does_not_stun() -> void:
	_rig([A, D], _np_at(Vector2(4 * TILE + 1, 0)))
	watch_signals(EventBus)
	_press_and_run(J)
	assert_eq(_fsm.stun_left, 0)
	assert_signal_not_emitted(EventBus, "player_stunned")
	_tick()
	assert_ne(_fsm.state, AS.STUNNED)


# --- AC 14: a landed hit, a decoy dispel, a dash and an Echo never stun ---

func test_a_slash_that_hits_the_boss_does_not_stun() -> void:
	var boss: StillBody = _np_at(Vector2(2 * TILE, 0))
	_rig([A, D], boss)
	var hp: int = boss.hp
	_press_and_run(J)
	assert_lt(boss.hp, hp, "the slash landed")
	assert_eq(_fsm.stun_left, 0)


func test_a_slash_that_dispels_a_decoy_does_not_stun() -> void:
	var boss: StillBody = _np_at(Vector2(0, 3 * TILE)) # 3 tiles below: outside the arc facing right
	boss.decoys.append(Vector2i(((SPAWN + Vector2(TILE, 0)) * NullPointerBody.MILLI / float(TILE)).round()))
	_rig([A, D], boss)
	var hp: int = boss.hp
	_press_and_run(J)
	assert_eq(boss.decoys.size(), 0, "the decoy was dispelled")
	assert_eq(boss.dispel_flash_positions().size(), 1, "its flash runs")
	assert_eq(boss.hp, hp, "a dispel deals no damage")
	assert_false(boss.weak_window.is_patched(), "and applies no Patched")
	assert_eq(_fsm.stun_left, 0, "a dispel is a hit for the whiff rule")


func test_the_same_miss_without_the_decoy_stuns() -> void:
	var boss: StillBody = _np_at(Vector2(0, 3 * TILE))
	_rig([A, D], boss)
	_press_and_run(J)
	assert_eq(_fsm.stun_left, 20, "control: the miss alone stuns")


func test_a_dash_never_stuns() -> void:
	_rig([A, D], _np_at(Vector2(0, 3 * TILE)))
	watch_signals(EventBus)
	_buf.push(K, _t)
	_tick(30)
	assert_signal_not_emitted(EventBus, "player_stunned")
	assert_eq(_fsm.stun_left, 0)


func test_an_echo_of_a_slash_never_stuns() -> void:
	var boss: StillBody = _np_at(Vector2(12 * TILE, 0)) # far: the first slash may whiff freely
	_rig([A, L], boss)
	watch_signals(EventBus)
	_press_and_run(J)
	_tick(40) # slash over, link closed
	assert_eq(_fsm.state, AS.IDLE_MOVE)
	_place(boss, SPAWN + Vector2(3 * TILE, 0))
	_buf.push(K, _t)
	_tick()
	assert_true(_fsm.echoing, "K runs LOOP's Echo of slash 1")
	assert_eq(_fsm.action, Defs.SLASH_1)
	_tick(SLASH_LAST_ACTIVE)
	assert_signal_not_emitted(EventBus, "player_stunned", "an Echo slash never stuns (D-S53-11)")


## [design call] D-S53-12: a slash whose link holds the K follow-up is a combo opener: the A->D
## Dash Strike (the phase 2 Patch, Story 5.2) still runs from 4 tiles.
func test_a_slash_opening_a_held_combo_does_not_stun() -> void:
	_rig([A, D], _np_at(Vector2(4 * TILE, 0)))
	watch_signals(EventBus)
	_buf.push(J, _t)
	_tick(3)
	_buf.push(K, _t)
	_tick(SLASH_LAST_ACTIVE)
	assert_signal_not_emitted(EventBus, "player_stunned")
	assert_eq(_fsm.action, Defs.DASH_STRIKE, "the combo runs")


# --- AC 15: no movement, no actions, buffered presses discarded ---

func test_the_stun_locks_movement_and_discards_buffered_presses() -> void:
	_rig([A, D], _np_at(Vector2(3 * TILE, 0)))
	_press_and_run(J)
	var at: Vector2 = _player.position_px
	_ctx.move_dir = Vector2i(0, 1)
	for i: int in 19:
		_buf.push(J if i % 2 == 0 else K, _t)
		_tick()
		assert_null(_fsm.action, "no action starts while stunned (tick %d)" % (i + 1))
	_buf.push(J, _t) # pushed on the last stunned tick: live for 8 more frames if kept
	_tick()
	assert_eq(_fsm.state, AS.STUNNED, "20th stunned frame")
	assert_eq(_player.position_px, at, "no movement while stunned")
	_tick()
	assert_null(_fsm.action, "the press was discarded, not kept for after the stun")
	_ctx.move_dir = Vector2i.ZERO
	_buf.push(J, _t)
	_tick()
	assert_eq(_fsm.action, Defs.SLASH_1, "a fresh press after the stun works")


# --- AC 16-17: sim state and the per-boss range ---

func test_only_the_null_pointer_has_a_whiff_range() -> void:
	assert_eq(BossController.new().whiff_stun_range_px(), 0.0, "the framework default: no stun")
	assert_eq(InfiniteLoopBody.new().whiff_stun_range_px(), 0.0, "the Infinite Loop keeps no stun")
	assert_eq(NullPointerBody.new().whiff_stun_range_px(), 4.0 * TILE)
	assert_eq(BossController.new().decoy_hit(Defs.SLASH_1.hit_shape, Vector2.ZERO, Vector2.RIGHT), 0)


func test_the_test_boss_never_stuns() -> void:
	var boss := BossController.new()
	assert_true(boss.setup(IL_DEF, null, ArenaContext.new()))
	boss.reset_for_fight()
	boss.body_center_px = SPAWN + Vector2(0, 3 * TILE)
	_rig([A, D], boss)
	watch_signals(EventBus)
	_press_and_run(J)
	_tick()
	assert_signal_not_emitted(EventBus, "player_stunned")


func test_the_infinite_loop_never_stuns() -> void:
	var boss := InfiniteLoopBody.new()
	assert_true(boss.setup(IL_DEF, null, ArenaContext.new()))
	boss.reset_for_fight()
	_rig([A, D], boss)
	watch_signals(EventBus)
	_press_and_run(J)
	_tick()
	assert_signal_not_emitted(EventBus, "player_stunned")


func test_a_roaring_boss_does_not_stun() -> void:
	var boss: StillBody = _np_at(Vector2(0, 3 * TILE))
	boss.take_hit(350)
	assert_eq(boss.state, BossController.BossState.ROAR)
	_rig([A, D], boss)
	_buf.push(J, _t)
	_tick()
	assert_not_null(_fsm.action, "the slash really started")
	_tick(SLASH_LAST_ACTIVE - 1)
	assert_eq(_fsm.stun_left, 0, "[design call] no NullPointerException while the boss cannot be hit")


func test_reset_and_deactivation_clear_the_stun() -> void:
	_rig([A, D], _np_at(Vector2(3 * TILE, 0)))
	_press_and_run(J)
	assert_eq(_fsm.stun_left, 20)
	_fsm.reset_for_fight()
	assert_eq(_fsm.stun_left, 0)
	assert_eq(_fsm.state, AS.IDLE_MOVE)
	assert_false(_player.locked)


func test_log_panel_prints_the_stun() -> void:
	var panel := LogPanel.new()
	add_child_autofree(panel)
	EventBus.player_stunned.emit(&"NullPointerException")
	assert_eq(panel.lines()[-1], "NullPointerException")
