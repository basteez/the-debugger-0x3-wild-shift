extends GutTest
## Story 1.7 AC1 (DC14): gameplay and menu InputMap actions, bound by physical keycode, no Shift key.
## Story 7.5 (AC 1, 2, 16): the actions also carry pad events (PAD_EXPECTED); key events stay physical.

const EXPECTED: Dictionary[StringName, Array] = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"action_1": [KEY_J],
	&"action_2": [KEY_K],
	&"shift_left": [KEY_Q],
	&"shift_right": [KEY_E],
	&"breakpoint": [KEY_SPACE],
	&"watch": [KEY_R],
	&"pause": [KEY_ESCAPE, KEY_P], # D-FIX-FS-1: P for the fullscreen Esc lock
	&"mute": [KEY_M],
}

## Story 7.5: pad buttons per action (GDD Controls and Input, D-S75-2).
const PAD_BUTTONS: Dictionary[StringName, Array] = {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"action_1": [JOY_BUTTON_X],
	&"action_2": [JOY_BUTTON_A],
	&"shift_left": [JOY_BUTTON_LEFT_SHOULDER],
	&"shift_right": [JOY_BUTTON_RIGHT_SHOULDER],
	&"breakpoint": [],
	&"watch": [JOY_BUTTON_Y],
	&"pause": [JOY_BUTTON_START],
	&"mute": [JOY_BUTTON_BACK],
	&"title_option_new_run": [JOY_BUTTON_BACK],
	&"title_option_debug_build": [JOY_BUTTON_B],
	&"title_option_fullscreen": [JOY_BUTTON_RIGHT_STICK],
	&"title_option_practice": [JOY_BUTTON_LEFT_STICK],
}
## Story 7.5: pad axis motions per action, as [axis, direction].
const PAD_AXES: Dictionary[StringName, Array] = {
	&"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	&"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	&"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	&"breakpoint": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
}


func _physical_keys(action: StringName) -> Array[Key]:
	var keys: Array[Key] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		var key := ev as InputEventKey
		if key != null:
			keys.append(key.physical_keycode)
	return keys


func test_every_action_exists_with_its_physical_keys() -> void:
	for action: StringName in EXPECTED:
		assert_true(InputMap.has_action(action), "action %s missing" % action)
		var keys: Array[Key] = _physical_keys(action)
		assert_eq(keys.size(), EXPECTED[action].size(), "%s key count" % action)
		for key: Key in EXPECTED[action]:
			assert_has(keys, key, "%s lacks %s" % [action, OS.get_keycode_string(key)])


## Story 7.5 (AC 16): only key events are checked; pad events are allowed (PAD_EXPECTED below).
func test_actions_bind_physical_keycode_only() -> void:
	for action: StringName in EXPECTED:
		for ev: InputEvent in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			if key != null:
				assert_eq(key.keycode, KEY_NONE, "%s binds a logical keycode" % action)
			else:
				assert_true(ev is InputEventJoypadButton or ev is InputEventJoypadMotion,
						"%s has a non-key, non-pad event" % action)


func test_pad_events_match_the_gdd_table() -> void:
	for action: StringName in PAD_BUTTONS:
		var buttons: Array[int] = []
		var axes: Array = []
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				assert_eq(ev.device, -1, "%s pad button binds any device" % action)
				buttons.append((ev as InputEventJoypadButton).button_index)
			elif ev is InputEventJoypadMotion:
				var m := ev as InputEventJoypadMotion
				assert_eq(m.device, -1, "%s pad axis binds any device" % action)
				axes.append([m.axis, m.axis_value])
		assert_eq(buttons.size(), PAD_BUTTONS[action].size(), "%s pad button count" % action)
		for b: int in PAD_BUTTONS[action]:
			assert_has(buttons, b, "%s lacks pad button %d" % [action, b])
		var want_axes: Array = PAD_AXES.get(action, [])
		assert_eq(axes.size(), want_axes.size(), "%s pad axis count" % action)
		for a: Array in want_axes:
			assert_has(axes, a, "%s lacks pad axis %s" % [action, a])
		assert_almost_eq(InputMap.action_get_deadzone(action), 0.2, 0.001, "%s deadzone" % action)


func test_no_project_action_binds_shift() -> void:
	for action: StringName in InputMap.get_actions():
		for ev: InputEvent in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			if key == null:
				continue
			assert_ne(key.keycode, KEY_SHIFT, "%s binds Shift (keycode)" % action)
			assert_ne(key.physical_keycode, KEY_SHIFT, "%s binds Shift (physical)" % action)


func test_pause_is_escape_or_p_and_mute_is_m() -> void:
	assert_eq(_physical_keys(&"pause"), [KEY_ESCAPE, KEY_P] as Array[Key])
	assert_eq(_physical_keys(&"mute"), [KEY_M] as Array[Key])


## D-FIX-FS-1: P is pause in play; the only other action on P is the title's Practice option, and
## TITLE never pauses, so the two never meet.
func test_p_is_shared_only_with_the_title_practice_option() -> void:
	for action: StringName in InputMap.get_actions():
		if action == &"pause" or action == &"title_option_practice" or String(action).begins_with("ui_"):
			continue
		assert_false(KEY_P in _physical_keys(action), "%s also binds P" % action)
