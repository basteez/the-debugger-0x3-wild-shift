extends GutTest
## Story 1.6 AC4/AC5/AC10: F1-F5 jump map, the release gate and input consumption; Story 2.5: F9.

const DebugKeysScript := preload("res://src/debug/debug_keys.gd")
const MainScript := preload("res://src/main/main.gd")
const GameScript := preload("res://src/autoloads/game.gd")

var _saved_enabled: bool
var _saved_state: int
var _saved_boss: int
var _saved_first: int


func before_each() -> void:
	_saved_enabled = Debug.enabled
	_saved_state = Game.flow_state
	_saved_boss = Game.run.boss_index
	_saved_first = Game.first_input_frame


func after_each() -> void:
	Debug.enabled = _saved_enabled
	Game.flow_state = _saved_state as GameScript.FlowState
	Game.run.boss_index = _saved_boss
	Game.first_input_frame = _saved_first


func _key(code: Key, pressed: bool = true, echo: bool = false, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	ev.shift_pressed = shift
	return ev


func test_target_for_f1_to_f5() -> void:
	assert_eq(DebugKeysScript.target_for_key(KEY_F1), {&"state": GameScript.FlowState.TITLE, &"boss_index": 0})
	assert_eq(DebugKeysScript.target_for_key(KEY_F2), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 0})
	assert_eq(DebugKeysScript.target_for_key(KEY_F3), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 1})
	assert_eq(DebugKeysScript.target_for_key(KEY_F4), {&"state": GameScript.FlowState.FIGHT, &"boss_index": 2})
	assert_eq(DebugKeysScript.target_for_key(KEY_F5), {&"state": GameScript.FlowState.ENDING, &"boss_index": 0})


func test_other_keys_have_no_target() -> void:
	for code: Key in [KEY_F6, KEY_F9, KEY_F12, KEY_A, KEY_ENTER, KEY_ESCAPE]:
		assert_true(DebugKeysScript.target_for_key(code).is_empty(), "key %d" % code)


func test_should_add_debug_keys_follows_the_gate() -> void:
	assert_true(MainScript.should_add_debug_keys(true))
	assert_false(MainScript.should_add_debug_keys(false))


func test_handle_key_jumps_and_reports_handled() -> void:
	Debug.enabled = true
	var keys: Node = autofree(DebugKeysScript.new())
	assert_true(keys.handle_key(_key(KEY_F4)))
	assert_eq(Game.flow_state, GameScript.FlowState.FIGHT)
	assert_eq(Game.run.boss_index, 2)


func test_handle_key_ignores_release_echo_and_unmapped() -> void:
	Debug.enabled = true
	var keys: Node = autofree(DebugKeysScript.new())
	assert_false(keys.handle_key(_key(KEY_F2, false)))
	assert_false(keys.handle_key(_key(KEY_F2, true, true)))
	assert_false(keys.handle_key(_key(KEY_A)))
	assert_false(keys.handle_key(_key(KEY_F9, true, false, true)), "Shift+F9 is the HUD grid (D-S25-11)")


## Story 2.5 AC7: F9 toggles the frame overlay (debug-only node).
func test_f9_toggles_frame_overlay() -> void:
	Debug.enabled = true
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	var overlay: FrameOverlay = autofree(FrameOverlay.new())
	keys.frame_overlay = overlay
	assert_true(keys.handle_key(_key(KEY_F9)))
	assert_true(overlay.visible)
	assert_false(keys.handle_key(_key(KEY_F9, true, true)), "echo ignored")
	assert_true(overlay.visible)
	assert_true(keys.handle_key(_key(KEY_F9)))
	assert_false(overlay.visible)
	assert_false(keys.handle_key(_key(KEY_F9, true, false, true)))
	assert_false(overlay.visible, "Shift+F9 does not toggle the overlay")


func test_main_adds_debug_keys_only_when_enabled() -> void:
	Debug.enabled = true
	var main_on: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_on)
	assert_not_null(main_on.get_node_or_null(^"DebugKeys"))
	Debug.enabled = false
	var main_off: Node2D = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main_off)
	assert_null(main_off.get_node_or_null(^"DebugKeys"))


## Review 2.5: F9 is not consumed when there is no overlay.
func test_f9_without_overlay_is_not_consumed() -> void:
	var keys: DebugKeys = autofree(DebugKeysScript.new())
	assert_false(keys.handle_key(_key(KEY_F9)))
