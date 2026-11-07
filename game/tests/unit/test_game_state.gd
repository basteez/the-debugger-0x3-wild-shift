extends GutTest
## Ports the Story 1.1 Game initial-state check.

const GameScript := preload("res://src/autoloads/game.gd")


func test_game_initial_flow_state_is_title() -> void:
	var game: Node = autofree(GameScript.new())
	assert_eq(game.get("flow_state"), GameScript.FlowState.TITLE)


func test_start_run_from_title_moves_to_intro() -> void:
	var game: Node = autofree(GameScript.new())
	watch_signals(EventBus)
	game.start_run_from_title(120)
	assert_eq(game.get("flow_state"), GameScript.FlowState.INTRO)
	assert_eq(game.get("first_input_frame"), 120)
	assert_signal_emit_count(EventBus, "flow_state_changed", 1)
	assert_signal_emitted_with_parameters(EventBus, "flow_state_changed", [0, 1])


func test_title_input_frame_does_not_skip_intro() -> void:
	var game: Node = autofree(GameScript.new())
	assert_false(game.can_skip_intro(0), "no skip before the run starts")
	game.start_run_from_title(120)
	assert_false(game.can_skip_intro(120))
	assert_true(game.can_skip_intro(121))


func test_second_start_is_rejected() -> void:
	var game: Node = autofree(GameScript.new())
	game.start_run_from_title(120)
	watch_signals(EventBus)
	game.start_run_from_title(200)
	assert_eq(game.get("first_input_frame"), 120)
	assert_eq(game.get("flow_state"), GameScript.FlowState.INTRO)
	assert_signal_emit_count(EventBus, "flow_state_changed", 0)
