extends GutTest
## Story 2.9 AC1, AC2, AC3, AC5: PlayerHealth (HP, post-hit and dash invulnerability, death flag),
## the HP readout text and the blink schedule. No scene tree: the system is ticked directly.

const GameScript := preload("res://src/autoloads/game.gd")
const PLAYER_DEF: PlayerDef = preload("res://data/player/player_def.tres")


## Test-only FSM whose dash invulnerability is set by the test.
class FakeActions:
	extends ActionStateMachine
	var invuln: bool = false

	func invulnerable() -> bool:
		return invuln


var _health: PlayerHealth
var _actions: FakeActions
var _ctx: SimContext
var _saved_state: int


func before_each() -> void:
	# A lethal hit emits player_damaged(0); keep the autoload Game out of FIGHT so it records nothing.
	_saved_state = Game.flow_state
	Game.flow_state = GameScript.FlowState.TITLE
	_actions = FakeActions.new()
	_health = PlayerHealth.new(PLAYER_DEF, _actions)
	_health.reset_for_fight()
	_health.set_active(true)
	_ctx = SimContext.new()
	SimClock.set(&"_pending_hitstop", 0)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	SimClock.set(&"_pending_hitstop", 0)


func _tick(times: int = 1) -> void:
	for i: int in times:
		_health.tick(_ctx)


func _hit() -> void:
	_health.queue_hit()
	_tick()


func test_defaults_come_from_player_def() -> void:
	assert_eq(_health.phase, SimSystem.SimPhase.COMBAT)
	assert_eq(_health.hp, 5)
	assert_eq(_health.invuln_left, 0)
	assert_false(_health.dead)


func test_a_hit_takes_one_hp_and_starts_invulnerability_and_hitstop() -> void:
	watch_signals(EventBus)
	_hit()
	assert_eq(_health.hp, 4)
	assert_eq(_health.invuln_left, PLAYER_DEF.invuln_frames)
	assert_eq(SimClock.get(&"_pending_hitstop"), HitFeedback.PLAYER_HITSTOP)
	assert_eq(HitFeedback.PLAYER_HITSTOP, 4)
	assert_signal_emitted_with_parameters(EventBus, "player_damaged", [4])


func test_lethal_sequence_five_to_zero() -> void:
	var seen: Array[int] = []
	for i: int in 5:
		_hit()
		seen.append(_health.hp)
		_tick(PLAYER_DEF.invuln_frames)
	assert_eq(seen, [4, 3, 2, 1, 0])
	assert_true(_health.dead)


func test_invulnerability_blocks_at_59_frames_and_admits_at_60() -> void:
	_hit()
	_tick(58)
	_health.queue_hit()
	_tick() # 59 frames after the hit
	assert_eq(_health.hp, 4, "blocked inside invulnerability")
	_health.queue_hit()
	_tick() # 60 frames after the hit
	assert_eq(_health.hp, 3, "admitted once invulnerability ends")


func test_blocked_hit_has_no_feedback() -> void:
	_hit()
	SimClock.set(&"_pending_hitstop", 0)
	watch_signals(EventBus)
	_hit()
	assert_signal_not_emitted(EventBus, "player_damaged")
	assert_eq(SimClock.get(&"_pending_hitstop"), 0, "no hit-stop for an ignored hit")


func test_dash_invulnerability_blocks() -> void:
	_actions.invuln = true
	watch_signals(EventBus)
	_hit()
	assert_eq(_health.hp, 5)
	assert_signal_not_emitted(EventBus, "player_damaged")
	_actions.invuln = false
	_hit()
	assert_eq(_health.hp, 4)


func test_real_fsm_dash_frames_block() -> void:
	var fsm := ActionStateMachine.new()
	var health := PlayerHealth.new(PLAYER_DEF, fsm)
	health.reset_for_fight()
	fsm.action = Defs.DASH
	fsm.action_frame = Defs.DASH.invuln_from
	assert_true(fsm.invulnerable(), "dash frame %d is invulnerable" % fsm.action_frame)
	assert_false(health.apply_hit(), "a hit on a dash invulnerable frame is ignored")
	assert_eq(health.hp, 5)
	fsm.action_frame = Defs.DASH.invuln_to + 1
	assert_false(fsm.invulnerable())
	assert_true(health.apply_hit(), "after the invulnerable range it counts")
	assert_eq(health.hp, 4)
	SimClock.set(&"_pending_hitstop", 0)


func test_dead_ignores_hits() -> void:
	for i: int in 5:
		_hit()
		_tick(PLAYER_DEF.invuln_frames)
	assert_true(_health.dead)
	watch_signals(EventBus)
	_health.invuln_left = 0
	assert_false(_health.apply_hit())
	assert_eq(_health.hp, 0)
	assert_signal_not_emitted(EventBus, "player_damaged")


func test_inactive_does_not_tick_or_apply() -> void:
	_health.set_active(false)
	_health.queue_hit()
	_tick()
	assert_eq(_health.hp, 5)


func test_reset_for_fight_heals_and_clears() -> void:
	for i: int in 5:
		_hit()
		_tick(PLAYER_DEF.invuln_frames)
	_health.queue_hit()
	_health.reset_for_fight()
	assert_eq(_health.hp, PLAYER_DEF.max_hp)
	assert_eq(_health.invuln_left, 0)
	assert_false(_health.dead)
	_tick()
	assert_eq(_health.hp, 5, "a pending hit does not survive the reset")


func test_hp_text() -> void:
	assert_eq(PlayerHealth.hp_text(5, 5), "hp: 0b11111")
	assert_eq(PlayerHealth.hp_text(4, 5), "hp: 0b01111")
	assert_eq(PlayerHealth.hp_text(1, 5), "hp: 0b00001")
	assert_eq(PlayerHealth.hp_text(0, 5), "hp: 0b00000")
	assert_eq(PlayerHealth.hp_text(5, 5).length(), 11)


func test_blink_alternates_in_4_frame_blocks() -> void:
	assert_false(PlayerHealth.blink_hidden(0))
	assert_false(PlayerHealth.blink_hidden(-3))
	var got: Array[bool] = []
	for left: int in range(60, 44, -1):
		got.append(PlayerHealth.blink_hidden(left))
	assert_eq(got, [true, true, true, true, false, false, false, false,
			true, true, true, true, false, false, false, false])
	assert_true(PlayerHealth.blink_hidden(1), "last frame of the 15th block is hidden")
