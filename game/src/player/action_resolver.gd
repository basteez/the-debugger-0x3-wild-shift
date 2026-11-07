class_name ActionResolver
extends RefCounted
## The only code that turns J/K presses into actions (NP-1, Story 2.5). A pure static function
## over its inputs: the shared InputBuffer, the poll frame, the active window, the running action
## and chain record, the cooldowns and (Story 2.6) the combo link and the combo table. It consumes a
## buffered press only when it returns a request (or tells the FSM to hold a link press); any other
## press stays buffered and expires after 8 frames (FR6, D-S25-3, D-S25-7, D-S25-8, D-S26-5).

## Slot keys: ring[0] = J = action_1, ring[1] = K = action_2. J is resolved first (NP-1 rule 8).
const KEYS: Array[StringName] = [&"action_1", &"action_2"]
const K_SLOT := 1
## A chain press is accepted on the last CHAIN_WINDOW_FRAMES recovery frames (frames 15-22 of a
## slash, D-S25-1).
const CHAIN_WINDOW_FRAMES := 8


## Rules in order: chain, link (Story 2.6), cancel, solo, else nothing.
## `action` is the running ActionDef or null; `action_frame` its last executed frame.
## `chain_key` / `chain_serial` are the chain record (serial -1 = no chain); `shift_serial` is
## Register.shift_serial now. `link` is the FSM's LinkState (read only here; null = no link) and
## `combos` the combo table (null = Defs.COMBOS).
static func resolve(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, action_frame: int, chain_key: StringName, chain_serial: int, shift_serial: int, cooldowns: Cooldowns, link: LinkState = null, combos: ComboTable = null) -> ActionRequest:
	if buffer == null or cooldowns == null:
		return null
	var running: bool = action != null and action_frame < action.total_frames()
	if action != null:
		var chained: ActionRequest = _chain(buffer, frame, window, action, action_frame, chain_key, chain_serial, shift_serial)
		if chained != null:
			return chained
	# While the link is open on this window, K presses belong to the link rule only (D-S26-5).
	var link_owns_k: bool = link != null and link.is_open() and link.serial == shift_serial and window == link.pair
	if link_owns_k:
		# Rule 8, AC6: J resolves first; a K press stays buffered (or held) for the link next tick.
		var j_request: ActionRequest = _j_request(buffer, frame, window, action, action_frame, running, cooldowns, link_owns_k)
		if j_request != null:
			return j_request
		return _link(buffer, frame, window, action, action_frame, running, cooldowns, link, combos if combos != null else Defs.COMBOS)
	return _j_request(buffer, frame, window, action, action_frame, running, cooldowns, link_owns_k)


static func _j_request(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, action_frame: int, running: bool, cooldowns: Cooldowns, link_owns_k: bool) -> ActionRequest:
	if action != null and running and in_recovery(action, action_frame):
		var cancelled: ActionRequest = _cancel(buffer, frame, window, action, cooldowns, link_owns_k)
		if cancelled != null:
			return cancelled
	if running:
		return null
	return _solo(buffer, frame, window, cooldowns, link_owns_k)


## The K follow-up of an open link (NP-1 rules 2, 5, 6; D-S26-5 to D-S26-8). The target is the
## window's combo, or K's solo action flagged link_second when the window has none. A held press is
## evaluated before new buffered presses. Returns a start, a HOLD / DROP instruction, or null.
static func _link(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, action_frame: int, running: bool, cooldowns: Cooldowns, link: LinkState, combos: ComboTable) -> ActionRequest:
	var target_bit: int = window.y
	var combo: ComboDef = combos.get_combo(window.x, window.y) if combos != null else null
	var def: ActionDef = combo.action if combo != null else Defs.solo_action(target_bit)
	if def == null:
		return null
	var startable: bool = not running or (in_recovery(action, action_frame) and action.cancel_into.has(target_bit))
	var ready: bool = cooldowns.ready(target_bit)
	if link.held:
		if not ready:
			# D-045 / D-S26-8: a blocked press is dropped 8 frames after it was pushed.
			if frame - link.held_frame > InputBuffer.PRESS_LIFETIME_FRAMES:
				return ActionRequest.link_instruction(ActionRequest.LinkOp.DROP, K_SLOT)
			return null
		if startable:
			return ActionRequest.new(def, target_bit, K_SLOT, false, running, combo, combo == null)
		return null
	if not ready:
		return null # stays in the buffer and expires normally (no partial execution)
	if startable:
		if buffer.consume(KEYS[K_SLOT], frame):
			return ActionRequest.new(def, target_bit, K_SLOT, false, running, combo, combo == null)
		return null
	var pushed: int = buffer.consume_pushed_frame(KEYS[K_SLOT], frame)
	if pushed >= 0:
		return ActionRequest.link_instruction(ActionRequest.LinkOp.HOLD, K_SLOT, pushed)
	return null


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


static func _cancel(buffer: InputBuffer, frame: int, window: Vector2i, action: ActionDef, cooldowns: Cooldowns, skip_k: bool = false) -> ActionRequest:
	for slot: int in KEYS.size():
		if skip_k and slot == K_SLOT:
			continue
		var bit: int = _bit_in(window, slot)
		if not action.cancel_into.has(bit) or not cooldowns.ready(bit):
			continue
		var def: ActionDef = Defs.solo_action(bit)
		if def == null:
			continue
		if buffer.consume(KEYS[slot], frame):
			return ActionRequest.new(def, bit, slot, false, true)
	return null


static func _solo(buffer: InputBuffer, frame: int, window: Vector2i, cooldowns: Cooldowns, skip_k: bool = false) -> ActionRequest:
	for slot: int in KEYS.size():
		if skip_k and slot == K_SLOT:
			continue
		var bit: int = _bit_in(window, slot)
		var def: ActionDef = Defs.solo_action(bit)
		if def == null or not cooldowns.ready(bit):
			continue
		if buffer.consume(KEYS[slot], frame):
			return ActionRequest.new(def, bit, slot, false, false)
	return null
