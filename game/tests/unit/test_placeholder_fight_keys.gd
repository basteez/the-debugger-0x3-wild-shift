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


## The Story 1.6 `FIGHT n` / `boss index n` label is retired: no text in any build, debug included.
func test_fight_screen_has_no_text_in_any_build() -> void:
	const MainScene := preload("res://src/main/main.tscn")
	var saved_enabled: bool = Debug.enabled
	var saved_flow: int = Game.flow_state
	for debug_on: bool in [false, true]:
		Debug.enabled = debug_on
		var main: Node2D = MainScene.instantiate()
		add_child_autofree(main)
		main.apply_flow_state(GameFlow.FlowState.FIGHT, 1)
		var screen := main.current_screen as PlaceholderScreen
		assert_not_null(screen, "the FIGHT screen node still exists (debug=%s)" % debug_on)
		if screen != null:
			assert_eq(screen.lines.size(), 0, "no FIGHT n / boss index n text (debug=%s)" % debug_on)
	Debug.enabled = saved_enabled
	Game.flow_state = saved_flow as GameFlow.FlowState
