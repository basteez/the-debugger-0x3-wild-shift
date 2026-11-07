class_name DebugKeys
extends Node
## F1-F5 debug jump keys (Story 1.6 AC4, DC6, DC7). Main adds this node only when Debug.enabled,
## so release builds without `?debug` never see it. Keys are consumed in _input, before any screen.

const GameFlow := preload("res://src/autoloads/game.gd")
## Physical keycode -> jump target. Matched by keycode (debug only, not an InputMap action).
const JUMPS: Dictionary[Key, Array] = {
	KEY_F1: [GameFlow.FlowState.TITLE, 0],
	KEY_F2: [GameFlow.FlowState.FIGHT, 0],
	KEY_F3: [GameFlow.FlowState.FIGHT, 1],
	KEY_F4: [GameFlow.FlowState.FIGHT, 2],
	KEY_F5: [GameFlow.FlowState.ENDING, 0],
}


## Pure map: {state, boss_index} for F1-F5, empty for any other key.
static func target_for_key(keycode: Key) -> Dictionary:
	if not JUMPS.has(keycode):
		return {}
	return {&"state": JUMPS[keycode][0], &"boss_index": JUMPS[keycode][1]}


## Jumps on a fresh F1-F5 press. True when the event was a debug key (the caller consumes it).
func handle_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var target: Dictionary = target_for_key(code)
	if target.is_empty():
		return false
	Game.debug_jump(target[&"state"], target[&"boss_index"])
	return true


func _input(event: InputEvent) -> void:
	if handle_key(event):
		get_viewport().set_input_as_handled()
