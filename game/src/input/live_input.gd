class_name LiveInput
extends InputSource
## Live keyboard/gamepad input (D-S21-3). The only file in a simulation folder allowed to read
## the Input singleton (check_guards.sh excludes it by name). Polled from SimClock._physics_process.

## Actions that go through the 8-frame InputBuffer, in a fixed order so a frame's presses are stable.
const BUFFERED_ACTIONS: Array[StringName] = [
	&"action_1", &"action_2", &"shift_left", &"shift_right", &"breakpoint", &"watch",
]


func presses_for_frame() -> Array[StringName]:
	var out: Array[StringName] = []
	for action: StringName in BUFFERED_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			out.append(action)
	return out
