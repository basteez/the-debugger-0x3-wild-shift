extends GutTest
## Story 1.4 AC2/AC3: the pure title input classifier and the hidden-option rule.

const TitleScreenScript := preload("res://src/ui/screens/title/title_screen.gd")


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func _click(pos: Vector2 = Vector2(100, 100)) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	return ev


func test_option_keys_classify_as_option() -> void:
	for code: Key in [KEY_N, KEY_P, KEY_B, KEY_F]:
		assert_eq(TitleScreenScript.classify(_key(code)), TitleScreenScript.Action.OPTION, "key %d" % code)


func test_option_ids_match_keys() -> void:
	assert_eq(TitleScreenScript.option_of(_key(KEY_N)), &"new_run")
	assert_eq(TitleScreenScript.option_of(_key(KEY_P)), &"practice")
	assert_eq(TitleScreenScript.option_of(_key(KEY_B)), &"debug_build")
	assert_eq(TitleScreenScript.option_of(_key(KEY_F)), &"fullscreen")
	assert_eq(TitleScreenScript.option_of(_key(KEY_A)), &"")


func test_echo_and_release_are_ignored() -> void:
	assert_eq(TitleScreenScript.classify(_key(KEY_N, true, true)), TitleScreenScript.Action.IGNORE)
	assert_eq(TitleScreenScript.classify(_key(KEY_N, false)), TitleScreenScript.Action.IGNORE)
	assert_eq(TitleScreenScript.classify(_key(KEY_ENTER, false)), TitleScreenScript.Action.IGNORE)


func test_other_keys_start() -> void:
	for code: Key in [KEY_ENTER, KEY_SPACE, KEY_A]:
		assert_eq(TitleScreenScript.classify(_key(code)), TitleScreenScript.Action.START, "key %d" % code)


func test_click_on_screen_starts() -> void:
	assert_eq(TitleScreenScript.classify(_click()), TitleScreenScript.Action.START)


func test_click_release_is_ignored() -> void:
	var ev := _click()
	ev.pressed = false
	assert_eq(TitleScreenScript.classify(ev), TitleScreenScript.Action.IGNORE)


func test_click_on_option_label_is_option() -> void:
	var rects: Dictionary[StringName, Rect2] = {&"practice": Rect2(10, 10, 50, 10)}
	assert_eq(TitleScreenScript.classify(_click(Vector2(20, 15)), rects), TitleScreenScript.Action.OPTION)
	assert_eq(TitleScreenScript.option_of(_click(Vector2(20, 15)), rects), &"practice")
	assert_eq(TitleScreenScript.classify(_click(Vector2(200, 200)), rects), TitleScreenScript.Action.START)


func test_mouse_motion_is_ignored() -> void:
	assert_eq(TitleScreenScript.classify(InputEventMouseMotion.new()), TitleScreenScript.Action.IGNORE)


func test_option_actions_exist_in_input_map() -> void:
	for action: StringName in TitleScreenScript.OPTION_ACTIONS.values():
		assert_true(InputMap.has_action(action), "missing InputMap action %s" % action)


func test_all_options_hidden_in_1_4() -> void:
	var screen: Node = autofree(TitleScreenScript.new())
	for option: StringName in [&"new_run", &"practice", &"debug_build", &"fullscreen"]:
		assert_false(screen.is_option_available(option), "%s should be hidden" % option)


func test_hidden_option_resolves_to_start() -> void:
	var screen: Node = autofree(TitleScreenScript.new())
	assert_eq(screen.resolve(_key(KEY_N)), TitleScreenScript.Action.START)


func test_available_option_does_not_start() -> void:
	var screen: Node = autofree(TitleScreenScript.new())
	screen.available[&"practice"] = true
	assert_eq(screen.resolve(_key(KEY_P)), TitleScreenScript.Action.OPTION)
	assert_eq(screen.resolve(_key(KEY_N)), TitleScreenScript.Action.START)


func test_available_option_input_keeps_title_and_unlocks_audio() -> void:
	var was_unlocked: bool = AudioManager.is_unlocked()
	var screen: Node = autofree(TitleScreenScript.new())
	screen.available[&"practice"] = true
	screen.handle_input(_key(KEY_P))
	assert_eq(Game.flow_state, Game.FlowState.TITLE, "an available option must not leave TITLE")
	assert_true(AudioManager.is_unlocked())
	if not was_unlocked:
		AudioManager.set("_unlocked", false)


func test_modifier_and_escape_keys_are_ignored() -> void:
	for code: Key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_ESCAPE]:
		assert_eq(TitleScreenScript.classify(_key(code)), TitleScreenScript.Action.IGNORE, "key %d" % code)


func test_non_left_mouse_buttons_are_ignored() -> void:
	for button: MouseButton in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var ev := _click()
		ev.button_index = button
		assert_eq(TitleScreenScript.classify(ev), TitleScreenScript.Action.IGNORE, "button %d" % button)


func test_function_keys_are_ignored() -> void:
	for code: int in range(KEY_F1, KEY_F12 + 1):
		assert_eq(TitleScreenScript.classify(_key(code as Key)), TitleScreenScript.Action.IGNORE, "F-key %d" % code)


func test_f9_on_the_title_does_not_start_the_run() -> void:
	var title: TitleScreen = autofree(TitleScreenScript.new())
	var before: int = Game.flow_state
	assert_eq(title.handle_input(_key(KEY_F9)), TitleScreenScript.Action.IGNORE)
	assert_eq(Game.flow_state, before)
