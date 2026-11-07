extends GutTest
## Story 1.7 AC1 (DC14): gameplay and menu InputMap actions, bound by physical keycode, no Shift key.

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
	&"pause": [KEY_ESCAPE],
	&"mute": [KEY_M],
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


func test_actions_bind_physical_keycode_only() -> void:
	for action: StringName in EXPECTED:
		for ev: InputEvent in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			assert_not_null(key, "%s has a non-key event" % action)
			if key != null:
				assert_eq(key.keycode, KEY_NONE, "%s binds a logical keycode" % action)


func test_no_project_action_binds_shift() -> void:
	for action: StringName in InputMap.get_actions():
		for ev: InputEvent in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			if key == null:
				continue
			assert_ne(key.keycode, KEY_SHIFT, "%s binds Shift (keycode)" % action)
			assert_ne(key.physical_keycode, KEY_SHIFT, "%s binds Shift (physical)" % action)


func test_pause_is_escape_and_mute_is_m() -> void:
	assert_eq(_physical_keys(&"pause"), [KEY_ESCAPE] as Array[Key])
	assert_eq(_physical_keys(&"mute"), [KEY_M] as Array[Key])
