extends GutTest
## Story 2.9 AC3, AC4, AC9: the DEAD screen text and its retry press rule (D-049 c).

const DeadScreenScript := preload("res://src/ui/screens/dead/dead_screen.gd")
const GameScript := preload("res://src/autoloads/game.gd")


func _key(code: Key, pressed: bool = true, echo: bool = false, physical: Key = KEY_NONE) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = physical if physical != KEY_NONE else code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func test_text() -> void:
	assert_eq(DeadScreen.TEXT, "Process exited with code 1")


func test_fresh_key_press_retries() -> void:
	assert_true(DeadScreen.is_retry_press(_key(KEY_J)))
	assert_true(DeadScreen.is_retry_press(_key(KEY_SPACE)))
	assert_true(DeadScreen.is_retry_press(_key(KEY_ENTER)))


func test_release_and_echo_do_not_retry() -> void:
	assert_false(DeadScreen.is_retry_press(_key(KEY_J, false)), "release")
	assert_false(DeadScreen.is_retry_press(_key(KEY_J, true, true)), "echo (a key held through death)")


func test_esc_modifiers_and_f_keys_do_not_retry() -> void:
	for code: Key in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_F5, KEY_F6, KEY_F1, KEY_F12]:
		assert_false(DeadScreen.is_retry_press(_key(code)), "key %d" % code)


func test_mouse_left_press_only() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_true(DeadScreen.is_retry_press(click))
	click.pressed = false
	assert_false(DeadScreen.is_retry_press(click))
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_false(DeadScreen.is_retry_press(right))


func test_keycode_zero_uses_physical_keycode() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_NONE
	ev.physical_keycode = KEY_K
	ev.pressed = true
	assert_true(DeadScreen.is_retry_press(ev), "web event with keycode 0")
	ev.physical_keycode = KEY_ESCAPE
	assert_false(DeadScreen.is_retry_press(ev), "physical Esc never retries")
	ev.physical_keycode = KEY_NONE
	assert_false(DeadScreen.is_retry_press(ev), "no key at all")


func test_text_fits_the_screen() -> void:
	var x: int = TitleScreen.centred_x(DeadScreen.TEXT)
	assert_gt(x, 0)
	assert_lt(x + GlyphFont.text_width(DeadScreen.TEXT, DeadScreen.TEXT_SCALE), Const.BASE_RES.x)
