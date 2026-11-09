class_name ActionResolver
extends RefCounted
## The only code that turns J/K presses into actions (NP-1, Story 2.5). A pure static function
## over its inputs: the shared InputBuffer, the poll frame, the active window, the running action
## and chain record, and the cooldowns. It consumes a buffered press only when it returns a request;
## any other press stays buffered and expires after 8 frames (FR6, D-S25-3, D-S25-7, D-S25-8).

## Slot keys: ring[0] = J = action_1, ring[1] = K = action_2. J is resolved first (NP-1 rule 8).
const KEYS: Array[StringName] = [&"action_1", &"action_2"]
## A chain press is accepted on the last CHAIN_WINDOW_FRAMES recovery frames (frames 15-22 of a
## slash, D-S25-1).
const CHAIN_WINDOW_FRAMES := 8


## Rules in order: chain, cancel, solo, else nothing (Story 2.5 Group B).
## `action` is the running ActionDef or null; `action_frame` its last executed frame.
## `chain_key` / `chain_serial` are the chain record (serial -1 = no chain); `shift_serial` is
## Register.shift_serial now.
static func resolve(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, action_frame: int, chain_key: StringName, chain_serial: int, shift_serial: int, cooldowns: Cooldowns) -> ActionRequest:
	if buffer == null or cooldowns == null:
		return null
	var running: bool = action != null and action_frame < action.total_frames()
	if action != null:
		var chained: ActionRequest = _chain(buffer, frame, window, action, action_frame, chain_key, chain_serial, shift_serial)
		if chained != null:
			return chained
		if running and in_recovery(action, action_frame):
			var cancelled: ActionRequest = _cancel(buffer, frame, window, action, cooldowns)
			if cancelled != null:
				return cancelled
	if running:
		return null
	return _solo(buffer, frame, window, cooldowns)


## True when `action_frame` (the last executed frame) is a RECOVERY frame, the last one included.
static func in_recovery(action: ActionDef, action_frame: int) -> bool:
	return action != null and action_frame > action.startup_frames + action.active_frames and action_frame <= action.total_frames()


## True when `action_frame` is inside the chain window (last 8 recovery frames).
static func in_chain_window(action: ActionDef, action_frame: int) -> bool:
	if not in_recovery(action, action_frame):
		return false
	return action_frame > action.total_frames() - CHAIN_WINDOW_FRAMES


static func _bit_in(window: Vector2i, slot: int) -> int:
	return window.x if slot == 0 else window.y


static func _chain(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, action_frame: int, chain_key: StringName, chain_serial: int, shift_serial: int) -> ActionRequest:
	if chain_serial < 0 or chain_serial != shift_serial or action.chain_next == null:
		return null
	if not in_chain_window(action, action_frame):
		return null
	var slot: int = KEYS.find(chain_key)
	if slot < 0 or _bit_in(window, slot) != Register.Bit.ATTACK:
		return null
	if not buffer.consume(chain_key, frame):
		return null
	return ActionRequest.new(action.chain_next, Register.Bit.ATTACK, slot, true, false)


static func _cancel(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, cooldowns: Cooldowns) -> ActionRequest:
	for slot: int in KEYS.size():
		var bit: int = _bit_in(window, slot)
		if not action.cancel_into.has(bit) or not cooldowns.ready(bit):
			continue
		var def: ActionDef = Defs.solo_action(bit)
		if def == null:
			continue
		if buffer.consume(KEYS[slot], frame):
			return ActionRequest.new(def, bit, slot, false, true)
	return null


static func _solo(buffer: InputBuffer, frame: int, window: Vector2i, cooldowns: Cooldowns) -> ActionRequest:
	for slot: int in KEYS.size():
		var bit: int = _bit_in(window, slot)
		var def: ActionDef = Defs.solo_action(bit)
		if def == null or not cooldowns.ready(bit):
			continue
		if buffer.consume(KEYS[slot], frame):
			return ActionRequest.new(def, bit, slot, false, false)
	return null
