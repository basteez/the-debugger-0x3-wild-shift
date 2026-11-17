extends GutTest
## Story 9.6 (AC 5, 6, D-S96-3): a pad disconnect in a PAUSABLE state pauses through Game.set_paused;
## outside them nothing happens; a connect (or a focus return) never resumes. No real joypad is used:
## the handler is called directly on a Game instance outside the tree (the test_pause.gd pattern).
## Shared state (SimClock.paused) is restored here; the suite-level reset is TestIsolation (Story 9.5).

const GameScript := preload("res://src/autoloads/game.gd")
const S := GameScript.FlowState

var _saved_paused: bool


func before_each() -> void:
	_saved_paused = SimClock.paused
	SimClock.paused = false


func after_each() -> void:
	SimClock.paused = _saved_paused


func _game(state: S) -> Node:
	var game: Node = autofree(GameScript.new())
	game.flow_state = state
	return game


func test_autoload_listens_to_joy_connection_changed() -> void:
	assert_true(Input.joy_connection_changed.is_connected(Game.on_joy_connection_changed))


func test_disconnect_pauses_in_every_pausable_state() -> void:
	watch_signals(EventBus)
	var expected: int = 0
	for state: S in [S.FIGHT, S.INTRO, S.ENDING, S.TUTORIAL]:
		SimClock.paused = false
		var game: Node = _game(state)
		expected += 1 # watch_signals counts across the loop (the test_pause.gd pattern)
		assert_true(game.on_joy_connection_changed(0, false), "accepted in %s" % S.keys()[state])
		assert_true(SimClock.paused, "paused in %s" % S.keys()[state])
		assert_signal_emit_count(EventBus, "pause_toggled", expected, "one emit in %s" % S.keys()[state])
		assert_signal_emitted_with_parameters(EventBus, "pause_toggled", [true])
		assert_false(game.get("_focus_lost"), "a pad drop is not a focus loss")


func test_any_device_pauses() -> void:
	var game: Node = _game(S.FIGHT)
	assert_true(game.on_joy_connection_changed(3, false))
	assert_true(SimClock.paused)


func test_disconnect_outside_pausable_states_does_nothing() -> void:
	for state: S in [S.TITLE, S.DEAD, S.HARVEST]:
		var game: Node = _game(state)
		watch_signals(EventBus)
		assert_false(game.on_joy_connection_changed(0, false), "refused in %s" % S.keys()[state])
		assert_false(SimClock.paused)
		assert_signal_not_emitted(EventBus, "pause_toggled")
		assert_eq(game.flow_state, state, "flow unchanged")


func test_connect_never_changes_pause() -> void:
	var game: Node = _game(S.FIGHT)
	watch_signals(EventBus)
	assert_false(game.on_joy_connection_changed(0, true))
	assert_false(SimClock.paused, "a connect does not pause")
	SimClock.paused = true
	assert_false(game.on_joy_connection_changed(0, true))
	assert_true(SimClock.paused, "a connect does not resume")
	assert_signal_not_emitted(EventBus, "pause_toggled")


func test_disconnect_while_paused_stays_paused_without_a_second_emit() -> void:
	var game: Node = _game(S.FIGHT)
	assert_true(game.on_joy_connection_changed(0, false))
	watch_signals(EventBus)
	assert_true(game.on_joy_connection_changed(1, false))
	assert_true(SimClock.paused)
	assert_signal_not_emitted(EventBus, "pause_toggled")


func test_reconnect_or_focus_return_never_resumes() -> void:
	var game: Node = _game(S.FIGHT)
	game.on_joy_connection_changed(0, false)
	game.on_joy_connection_changed(0, true)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(SimClock.paused, "DC3: only P / Start / Esc / a click resume")
