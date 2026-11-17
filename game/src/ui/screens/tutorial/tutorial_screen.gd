class_name TutorialScreen
extends Node
## Story 8.2 (D-E8-4..6, D-S82-3, E1-E5): the flow screen of the TUTORIAL state ("running the test
## suite"), built by Main._make_screen like the Intro screen. Presentation only (AD-05): once per
## physics frame, after SimClock's tick, it reads the arena's sim state (player position, the action
## serial and slot, the register window) and the boss hit events, feeds them to a pure TutorialSteps,
## and hands the text to the arena's TutorialChecklistView. It owns the Esc / Select skip hold and the
## outro beat, both counted in unpaused physics frames, and the last input device (D-S82-10). It
## never writes sim state; it leaves TUTORIAL only through Game.finish_tutorial (AD-08).

const SCREEN_TEXT: TextScreenText = preload("res://data/text/screen_text.tres")
const GameFlow := preload("res://src/autoloads/game.gd")

enum Device { KEYBOARD, GAMEPAD }

## [design call] D-S82-5: the skip is a 1-s hold (60 frames) of Esc, or of the pad's Select (Start
## pauses). A tap does nothing.
const SKIP_HOLD_FRAMES := 60
const SKIP_BUTTON := JOY_BUTTON_BACK
## [design call] D-S82-7: the `ALL TESTS PASSED.` beat before the exit.
const TUTORIAL_OUTRO_FRAMES := 90
## [design call] D-S82-10: the key names the prompts show, per device (Story 7.5 pad mapping:
## action_1 = X, action_2 = A, shift = LB / RB, pause = Start, Select = the skip hold).
const KEY_NAMES: Dictionary[StringName, String] = {
	&"move": "WASD or arrow keys",
	&"action_1": "J",
	&"action_2": "K",
	&"shift": "Q / E",
	&"skip": "Esc or Bksp",
	&"pause": "P",
}
const PAD_NAMES: Dictionary[StringName, String] = {
	&"move": "left stick or D-pad",
	&"action_1": "(X)",
	&"action_2": "(A)",
	&"shift": "LB / RB",
	&"skip": "SELECT",
	&"pause": "START",
}
## Template placeholder -> key name id.
const PLACEHOLDERS: Dictionary[String, StringName] = {
	"{move}": &"move", "{j}": &"action_1", "{k}": &"action_2", "{shift}": &"shift", "{skip}": &"skip",
	"{pause}": &"pause", # Story 9.1 (618a)
}
## Story 9.1 (AC 10, D-S91-7): the trigger axes, which count only on a positive press (some pads
## report -1 at rest).
const TRIGGER_AXES: Array[JoyAxis] = [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
const MOTION_THRESHOLD := 0.5

## Main injects the arena (read only) and its checklist view.
var arena: Arena
var view: TutorialChecklistView
var steps: TutorialSteps = TutorialSteps.new()
var device: Device = Device.KEYBOARD
## Consecutive unpaused frames the skip key has been held.
var hold_frames: int = 0
## Frames since every test passed (the outro beat).
var outro_frames: int = 0

var _finished: bool = false
var _seeded: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _last_serial: int = -1
## SimClock.sim_frame of the last patched_applied on the dummy (-1 none): a hit in that tick applied it.
var _patch_frame: int = -1


func _ready() -> void:
	name = &"TutorialScreen"
	EventBus.hit_landed.connect(_on_hit_landed)
	EventBus.patched_applied.connect(_on_patched_applied)
	Log.info(&"flow", "tutorial opened%s" % (" (replay)" if Game.tutorial_replay else ""))
	device = initial_device(Input.get_connected_joypads()) as Device # Story 9.1 (618c, D-S91-6)
	_refresh_view()


func _exit_tree() -> void:
	if EventBus.hit_landed.is_connected(_on_hit_landed):
		EventBus.hit_landed.disconnect(_on_hit_landed)
	if EventBus.patched_applied.is_connected(_on_patched_applied):
		EventBus.patched_applied.disconnect(_on_patched_applied)
	if is_instance_valid(view):
		view.clear()


func _input(event: InputEvent) -> void:
	device = device_for(event, device)


func _physics_process(_delta: float) -> void:
	poll(SimClock.sim_frame, skip_held())


## True while Esc, Backspace (Esc is eaten by the browser in itch fullscreen, [design call] coordinator
## (review)) or a pad's Select is held down.
static func skip_held() -> bool:
	if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_BACKSPACE):
		return true
	for pad: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, SKIP_BUTTON):
			return true
	return false


## One step at sim frame `frame` with the skip key `held`: read the sim, feed the steps, count the
## hold and the outro. Nothing moves while paused or outside TUTORIAL. True when it left TUTORIAL.
func poll(frame: int, held: bool) -> bool:
	if _finished or Game.flow_state != GameFlow.FlowState.TUTORIAL:
		return false
	if SimClock.paused:
		hold_frames = 0 # review: a hold that straddles a pause (Esc resumes) must start over
		return false
	_observe_sim()
	hold_frames = next_hold(hold_frames, held)
	if hold_done(hold_frames):
		return _finish(frame, true)
	if steps.all_passed():
		outro_frames += 1
		if outro_frames >= TUTORIAL_OUTRO_FRAMES:
			return _finish(frame, false)
	_refresh_view()
	return false


func _finish(frame: int, skipped: bool) -> bool:
	_finished = Game.finish_tutorial(frame, skipped)
	if _finished and is_instance_valid(view):
		view.clear() # review: never draw over FIGHT 1 for the frame before queue_free
	return _finished


## Reads the arena (AD-05: reads only). The first call only takes the baseline, so the spawn reset of
## the TUTORIAL entry never counts as movement or as an action.
func _observe_sim() -> void:
	if arena == null:
		return
	var pos: Vector2 = arena.player.position_px
	var serial: int = arena.actions.action_serial
	if not _seeded:
		_seeded = true
		_last_pos = pos
		_last_serial = serial
		return
	steps.observe_move(_last_pos.distance_to(pos))
	_last_pos = pos
	if serial != _last_serial:
		_last_serial = serial
		var slot: int = arena.actions.action_slot
		if slot >= 0 and slot < ActionResolver.KEYS.size():
			steps.observe_action(ActionResolver.KEYS[slot])
	steps.observe_window(arena.register.active_window())


func _on_patched_applied(boss_id: StringName, _frames: int) -> void:
	if Game.flow_state != GameFlow.FlowState.TUTORIAL:
		return
	_patch_frame = SimClock.sim_frame
	steps.observe_patched(boss_id)


func _on_hit_landed(target: StringName, _damage: int, state: int, is_combo: bool, _pos: Vector2) -> void:
	if target != &"boss" or Game.flow_state != GameFlow.FlowState.TUTORIAL:
		return
	steps.observe_hit(is_combo, state, _patch_frame == SimClock.sim_frame)


func _refresh_view() -> void:
	if not is_instance_valid(view):
		return
	var current: int = -1 if steps.all_passed() else steps.current_step()
	view.show_state(TutorialChecklistView.checklist_lines(steps), current, prompt_rows(steps.current_step(), device),
			hint_rows(device), hold_fraction(hold_frames), steps.all_passed())


## Pure (Story 9.1, AC 7, D-S91-4): the hint rows for `p_device`: the skip hold, then the pause key.
## Two rows: one 1x row of both is wider than the gap beside the `[PASS] test_move` checklist row.
static func hint_rows(p_device: int) -> PackedStringArray:
	return PackedStringArray([prompt_text(SCREEN_TEXT.tutorial_hint_skip, p_device),
			prompt_text(SCREEN_TEXT.tutorial_hint_pause, p_device)])


## Pure (Story 9.1, AC 9, D-S91-6): the device the screen starts with: the pad when one is connected
## (`pads` = Input.get_connected_joypads()), else the keyboard. The first input then corrects it.
static func initial_device(pads: Array) -> int:
	return Device.KEYBOARD if pads.is_empty() else Device.GAMEPAD


## Pure: the prompt rows of `step` for `device` (one or two; none once every test passed).
static func prompt_rows(step: int, p_device: int) -> PackedStringArray:
	var out := PackedStringArray()
	if step < 0 or step >= TutorialSteps.STEP_COUNT:
		return out
	out.append(prompt_text(SCREEN_TEXT.tutorial_prompts[step], p_device))
	var second: String = SCREEN_TEXT.tutorial_prompts_2[step]
	if not second.is_empty():
		out.append(prompt_text(second, p_device))
	return out


## Pure (E4): `template` with every {placeholder} replaced by the key name for `p_device`.
static func prompt_text(template: String, p_device: int) -> String:
	var out: String = template
	for token: String in PLACEHOLDERS:
		out = out.replace(token, glyph_name(PLACEHOLDERS[token], p_device))
	return out


## Pure (E4): the key or button name of `action` for `p_device` ("" for an unknown action).
static func glyph_name(action: StringName, p_device: int) -> String:
	var names: Dictionary[StringName, String] = PAD_NAMES if p_device == Device.GAMEPAD else KEY_NAMES
	return names.get(action, "")


## Pure (E4, D-S82-10): the last input device after `event`. Keys and the mouse are the keyboard,
## pad buttons and stick / trigger motion past a small deadzone are the gamepad; anything else keeps
## `current`.
static func device_for(event: InputEvent, current: int) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return Device.KEYBOARD
	if event is InputEventJoypadButton:
		return Device.GAMEPAD
	var motion := event as InputEventJoypadMotion
	if motion == null:
		return current
	# Story 9.1 (D-S91-7): a trigger counts only when pressed (positive); a stick in any direction.
	var value: float = motion.axis_value if TRIGGER_AXES.has(motion.axis) else absf(motion.axis_value)
	return Device.GAMEPAD if value >= MOTION_THRESHOLD else current


## Pure (E3): the hold counter after one unpaused frame: +1 while held, 0 on release.
static func next_hold(frames_held: int, held: bool) -> int:
	return frames_held + 1 if held else 0


## Pure (E3): the hold has lasted long enough to skip.
static func hold_done(frames_held: int) -> bool:
	return frames_held >= SKIP_HOLD_FRAMES


## Pure (E3): the hold progress is drawn while the key is held.
static func hold_hint_visible(frames_held: int) -> bool:
	return frames_held > 0


## Pure: the hold progress 0..1.
static func hold_fraction(frames_held: int) -> float:
	return clampf(float(frames_held) / float(SKIP_HOLD_FRAMES), 0.0, 1.0)
