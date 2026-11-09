extends GutTest
## Story 2.9 AC3-AC6 (integration): Main, the Arena, PlayerHealth, the autoload Game and SimClock.
## A register shifted mid-fight is restored to the fight-start snapshot on retry, the player is
## healed, cooldowns are cleared, the FSM is unlocked, and a retry does not re-capture the snapshot.

const MainScene := preload("res://src/main/main.tscn")
const GameScript := preload("res://src/autoloads/game.gd")
const D := Register.Bit.DASH
const A := Register.Bit.ATTACK

var _saved_enabled: bool
var _saved_state: int
var _saved_run: RunState
var _saved_first: int
var _main: Node2D


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_run = Game.run
	_saved_first = Game.first_input_frame
	Game.run = RunState.new() # the test mutates the run; never the saved one
	Debug.enabled = true
	SimClock.paused = false
	_main = MainScene.instantiate()
	add_child_autofree(_main)


func after_each() -> void:
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run = _saved_run
	Game.first_input_frame = _saved_first
	Game.death_frame = -1
	Debug.enabled = _saved_enabled
	SimClock.set(&"_swallow_presses", false)
	SimClock.paused = false


func _tick(times: int) -> void:
	for i: int in times:
		SimClock.tick()


## Queues one hit and runs the sim until the hit-stop and the invulnerability have passed.
func _hit(arena: Arena) -> void:
	arena.health.queue_hit()
	_tick(1 + HitFeedback.PLAYER_HITSTOP + Arena.PLAYER_DEF.invuln_frames)


func test_retry_restores_the_fight_start_snapshot() -> void:
	var arena: Arena = _main.arena
	Game.debug_jump(GameScript.FlowState.FIGHT, 0)
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.fight_start_ring, PackedInt32Array([D, A]), "snapshot captured on FIGHT enter")
	assert_eq(arena.register.ring, PackedInt32Array([D, A]))
	# Shift mid-fight, start a cooldown and lock the player as a dash would.
	arena.register.shift(Register.LEFT)
	assert_eq(arena.register.ring, PackedInt32Array([A, D]), "shifted")
	arena.actions.cooldowns.start(D, 120)
	arena.player.lock_movement(Vector2(4, 0))
	watch_signals(EventBus)
	for i: int in 4:
		_hit(arena)
	assert_eq(arena.health.hp, 1)
	assert_eq(_main.hp_readout.current_text(), "hp: 0b00001")
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	arena.health.queue_hit()
	_tick(1)
	# Death (AC 3)
	assert_eq(Game.flow_state, GameScript.FlowState.DEAD)
	assert_eq(Game.run.deaths_on_boss, 1)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"infinite_loop", 1])
	assert_true(_main.current_screen is DeadScreen)
	assert_false(arena.health.active, "no hits while dead")
	assert_false(arena.player.locked, "a death mid-dash leaves the player unlocked")
	assert_eq(_main.hud.log_panel.lines()[-1], "WARN: hp--", "the log keeps the fight's lines")
	# Gate (AC 4)
	_tick(5)
	assert_false(Game.retry(SimClock.sim_frame), "too early")
	assert_eq(Game.flow_state, GameScript.FlowState.DEAD)
	assert_true(Game.retry(Game.death_frame + GameScript.RETRY_DELAY_FRAMES))
	# Restored (AC 5, AC 6)
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(arena.register.ring, PackedInt32Array([D, A]), "register back to the snapshot")
	assert_eq(Game.run.fight_start_ring, PackedInt32Array([D, A]), "the retry did not re-capture")
	assert_eq(arena.health.hp, Arena.PLAYER_DEF.max_hp)
	assert_eq(arena.health.invuln_left, 0)
	assert_false(arena.health.dead)
	assert_true(arena.health.active)
	assert_eq(arena.actions.cooldowns.remaining(D), 0, "cooldowns reset")
	assert_false(arena.player.locked, "FSM unlocked")
	assert_eq(Game.run.deaths_on_boss, 1, "a retry keeps the death count")
	assert_eq(_main.hud.log_panel.lines().size(), 0, "the new fight starts with a clean log")
	assert_eq(_main.hp_readout.current_text(), "hp: 0b11111")


func test_retry_does_not_recapture_a_changed_snapshot() -> void:
	var arena: Arena = _main.arena
	Game.debug_jump(GameScript.FlowState.FIGHT, 0)
	# Stand-in for a richer snapshot: a retry must restore exactly what was captured.
	Game.run.fight_start_ring = PackedInt32Array([A, D])
	Game.record_death(SimClock.sim_frame)
	assert_true(Game.retry(SimClock.sim_frame + GameScript.RETRY_DELAY_FRAMES))
	assert_eq(Game.run.fight_start_ring, PackedInt32Array([A, D]))
	assert_eq(arena.register.ring, PackedInt32Array([A, D]))
