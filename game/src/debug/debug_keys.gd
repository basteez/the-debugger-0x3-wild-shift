class_name DebugKeys
extends Node
## F1-F5 debug jump keys (Story 1.6 AC4, DC6, DC7), Shift+F2 practice target (Story 2.7), the F9 frame overlay (Story 2.5 AC7) and the
## F11 input recorder (Story 2.1 AC5).
## Main adds this node only when Debug.enabled, so release builds without `?debug` never see it. Keys are consumed in _input, before any screen.

const GameFlow := preload("res://src/autoloads/game.gd")
const SimClockScript := preload("res://src/autoloads/sim_clock.gd")
## F11 toggles input recording (AD-debug, D-S21-8). On web the browser may take F11 for fullscreen.
const RECORD_KEY := KEY_F11
## F9 (no modifiers) toggles the frame overlay; Shift+F9 is the HUD grid (D-S25-11).
const OVERLAY_KEY := KEY_F9
## Shift+F2 (Story 2.7, D-S27-3): FIGHT boss 0 with the practice target. Plain F2 is unchanged.
const PRACTICE_KEY := KEY_F2
## Physical keycode -> jump target. Matched by keycode (debug only, not an InputMap action).
const JUMPS: Dictionary[Key, Array] = {
	KEY_F1: [GameFlow.FlowState.TITLE, 0],
	KEY_F2: [GameFlow.FlowState.FIGHT, 0],
	KEY_F3: [GameFlow.FlowState.FIGHT, 1],
	KEY_F4: [GameFlow.FlowState.FIGHT, 2],
	KEY_F5: [GameFlow.FlowState.ENDING, 0],
}

## The frame overlay (Story 2.5), set by Main. Null = F9 does nothing.
var frame_overlay: FrameOverlay
## True after Shift+F2 until another jump key (Story 2.7): Main reads it on every FIGHT entry, so a
## retry keeps the practice target. Lives on this debug-only node, so release code never sees it.
var practice_requested: bool = false


## Pure map for Shift+<key>: FIGHT boss 0 with the practice target for F2, empty otherwise.
static func shift_target_for_key(keycode: Key) -> Dictionary:
	if keycode != PRACTICE_KEY:
		return {}
	return {&"state": GameFlow.FlowState.FIGHT, &"boss_index": 0, &"practice": true}


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
	if code == RECORD_KEY:
		toggle_recording()
		return true
	if code == OVERLAY_KEY:
		if key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return false
		if frame_overlay == null:
			return false
		frame_overlay.toggle()
		return true
	var target: Dictionary = {}
	if key.shift_pressed:
		target = shift_target_for_key(code)
	if target.is_empty():
		target = target_for_key(code)
	if target.is_empty():
		return false
	# Set before the jump: Main reads it while handling the flow change.
	practice_requested = target.get(&"practice", false)
	Game.debug_jump(target[&"state"], target[&"boss_index"])
	return true


## F11: start recording on SimClock, or stop it and write user://replay_<unix_time>.json
## (on web the JSON is also logged, D-S21-7). Recording is driven by SimClock.tick, not here.
func toggle_recording() -> void:
	if SimClock.recorder == null:
		if start_recording(SimClock, Debug.enabled, Game.run.fight_seed):
			Log.info(&"replay", "recording on (seed %d)" % Game.run.fight_seed)
		return
	var data: Dictionary = stop_recording(SimClock)
	var path: String = replay_path(int(Time.get_unix_time_from_system()))
	if InputRecorder.save(data, path):
		Log.info(&"replay", "recording off: %d frames -> %s" % [(data["frames"] as Array).size(), ProjectSettings.globalize_path(path)])
	if OS.has_feature("web"):
		Log.info(&"replay", InputRecorder.to_json(data))


## Gives `clock` a started recorder. Refused (false, no recorder) when debug tools are off (C3).
static func start_recording(clock: SimClockScript, debug_enabled: bool, seed_value: int) -> bool:
	var rec: InputRecorder = InputRecorder.create(debug_enabled)
	if rec == null:
		return false
	rec.start(seed_value)
	clock.recorder = rec
	return true


## Stops and detaches the clock's recorder; the recording, or {} when none was running.
static func stop_recording(clock: SimClockScript) -> Dictionary:
	if clock.recorder == null:
		return {}
	var data: Dictionary = clock.recorder.stop()
	clock.recorder = null
	return data


## Pure: the file path of a recording saved at `unix_time`.
static func replay_path(unix_time: int) -> String:
	return "user://replay_%d.json" % unix_time


func _input(event: InputEvent) -> void:
	if handle_key(event):
		get_viewport().set_input_as_handled()
