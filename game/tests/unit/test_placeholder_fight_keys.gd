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


## Story 7.7 (AC 12-13): the `FIGHT n` text shows only in debug and never in practice; the node stays.
func test_fight_placeholder_text_is_debug_only() -> void:
	const MainScript := preload("res://src/main/main.gd")
	assert_true(MainScript.shows_fight_placeholder(true, false), "debug build or ?debug")
	assert_false(MainScript.shows_fight_placeholder(false, false), "release: no FIGHT n text")
	assert_false(MainScript.shows_fight_placeholder(true, true), "practice: never (7.6)")
	assert_false(MainScript.shows_fight_placeholder(false, true))


func test_release_fight_screen_has_no_text() -> void:
	const MainScene := preload("res://src/main/main.tscn")
	var saved_enabled: bool = Debug.enabled
	var saved_flow: int = Game.flow_state
	Debug.enabled = false
	var main: Node2D = MainScene.instantiate()
	add_child_autofree(main)
	main.apply_flow_state(GameFlow.FlowState.FIGHT, 1)
	var screen := main.current_screen as PlaceholderScreen
	assert_not_null(screen, "the FIGHT screen node still exists in release")
	if screen != null:
		assert_eq(screen.lines.size(), 0, "no FIGHT n / boss index n text in release")
	Debug.enabled = saved_enabled
	Game.flow_state = saved_flow as GameFlow.FlowState
