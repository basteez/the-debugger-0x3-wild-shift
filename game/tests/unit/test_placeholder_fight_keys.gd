extends GutTest
## Hotfix after Epic 2: the FIGHT placeholder must not treat gameplay keys as an any-key advance.

const GameFlow := preload("res://src/autoloads/game.gd")
const PlaceholderScreenScript := preload("res://src/ui/screens/placeholder/placeholder_screen.gd")


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func test_fight_placeholder_ignores_gameplay_keys() -> void:
	var screen: PlaceholderScreen = PlaceholderScreenScript.new()
	screen.setup(GameFlow.FlowState.FIGHT, 0)
	add_child_autofree(screen)
	var before: int = Game.flow_state
	for code: Key in [KEY_J, KEY_K, KEY_W, KEY_Q, KEY_E, KEY_SPACE]:
		screen._unhandled_input(_key(code))
	assert_eq(Game.flow_state, before, "no flow change from gameplay keys in FIGHT")
