extends GutTest
## Ports the Story 1.1 Game initial-state check.

const GameScript := preload("res://src/autoloads/game.gd")


func test_game_initial_flow_state_is_title() -> void:
	var game: Node = autofree(GameScript.new())
	assert_eq(game.get("flow_state"), GameScript.FlowState.TITLE)
