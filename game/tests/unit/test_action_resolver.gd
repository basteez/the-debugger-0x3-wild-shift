extends GutTest
## Story 2.5 AC2-AC5: ActionResolver rules (chain, cancel, solo) with a real InputBuffer. Pure.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT
## Story 5.5: every Register.Bit has a BitDef now (NULL's solo is Null Dodge), so the "no action"
## slot is an id with no def.
const NONE := 0
const J := &"action_1"
const K := &"action_2"

var _buf: InputBuffer
var _cd: Cooldowns


func before_each() -> void:
	_buf = InputBuffer.new()
	_cd = Cooldowns.new()


## Story 2.7 AC6: one ResolveInput per call, built here.
func _req_input(frame: int, window: Vector2i, def: ActionDef = null, action_frame: int = 0, chain_key: StringName = &"", chain_serial: int = -1, shift_serial: int = 0, link: LinkState = null, combos: ComboTable = null) -> ResolveInput:
	var input := ResolveInput.new()
	input.buffer = _buf
	input.frame = frame
	input.window = window
	input.action = def
	input.action_frame = action_frame
	input.chain_key = chain_key
	input.chain_serial = chain_serial
	input.shift_serial = shift_serial
	input.cooldowns = _cd
	input.link = link
	input.combos = combos
	return input


## Resolve with no running action.
func _idle(frame: int, window: Vector2i) -> ActionRequest:
	return ActionResolver.resolve(_req_input(frame, window))


func _running(frame: int, window: Vector2i, def: ActionDef, action_frame: int, chain_key: StringName = &"", chain_serial: int = -1, shift_serial: int = 0) -> ActionRequest:
	return ActionResolver.resolve(_req_input(frame, window, def, action_frame, chain_key, chain_serial, shift_serial))


func test_solo_press_on_attack_and_dash() -> void:
	_buf.push(J, 0)
	var r: ActionRequest = _idle(0, Vector2i(A, D))
	assert_not_null(r)
	assert_eq(r.def, Defs.SLASH_1)
	assert_eq(r.bit, A)
	assert_eq(r.slot, 0)
	assert_eq(r.key, J)
	assert_false(r.chain)
	assert_false(r.cancel)
	_buf.push(K, 1)
	r = _idle(1, Vector2i(A, D))
	assert_eq(r.def, Defs.DASH)
	assert_eq(r.bit, D)
	assert_eq(r.slot, 1)
	assert_null(_idle(2, Vector2i(A, D)), "each press consumed once")


func test_j_before_k_when_both_buffered() -> void:
	_buf.push(K, 0)
	_buf.push(J, 0)
	var r: ActionRequest = _idle(0, Vector2i(D, A))
	assert_eq(r.key, J)
	assert_eq(r.def, Defs.DASH)
	r = _idle(1, Vector2i(D, A))
	assert_eq(r.key, K, "the K press waited in the buffer")


func test_slot_without_action_does_nothing() -> void:
	_buf.push(J, 0)
	assert_null(_idle(0, Vector2i(NONE, A)))
	assert_eq(_buf.size(), 1, "not consumed")


## Story 3.8 put NOP on LOOP; Story 4.1 (D-S41-3): LOOP's solo action is Echo, which is not
## startable with an empty memory (the press stays buffered) and starts Echo once memory is set.
func test_loop_slot_starts_echo_only_with_memory() -> void:
	_buf.push(J, 0)
	assert_null(_idle(0, Vector2i(L, A)), "empty memory: no action")
	assert_eq(_buf.size(), 1, "not consumed")
	var input: ResolveInput = _req_input(0, Vector2i(L, A))
	input.echo_ready = true
	var r: ActionRequest = ActionResolver.resolve(input)
	assert_not_null(r)
	assert_eq(r.def, Defs.ECHO)
	assert_eq(r.bit, L)
	assert_eq(r.def.base_damage, 0)
	assert_null(r.def.hit_shape)


func test_cooled_down_press_stays_buffered_fires_when_ready_then_drops() -> void:
	_cd.start(D, 3)
	_buf.push(J, 0)
	for f: int in range(0, 3):
		assert_null(_idle(f, Vector2i(D, A)), "frame %d" % f)
		_cd.tick()
	var r: ActionRequest = _idle(3, Vector2i(D, A))
	assert_not_null(r, "fires on the first ready frame")
	_cd.start(D, 20)
	_buf.push(J, 10)
	for f: int in range(10, 19):
		assert_null(_idle(f, Vector2i(D, A)))
		_cd.tick()
	_cd.reset()
	assert_null(_idle(19, Vector2i(D, A)), "expired after 8 frames")


func test_running_action_blocks_solo() -> void:
	_buf.push(J, 0)
	assert_null(_running(0, Vector2i(A, D), Defs.SLASH_1, 5))
	assert_eq(_buf.size(), 1)


func test_finished_action_allows_solo() -> void:
	_buf.push(J, 0)
	var r: ActionRequest = _running(0, Vector2i(NONE, A), Defs.SLASH_3, 22)
	assert_null(r, "an id with no BitDef has no action")
	_buf.push(K, 0)
	r = _running(0, Vector2i(NONE, A), Defs.SLASH_3, 22)
	assert_not_null(r)
	assert_false(r.cancel)
	assert_eq(r.def, Defs.SLASH_1)


func test_chain_window_is_frames_15_to_22() -> void:
	for f: int in range(1, 23):
		_buf.clear()
		_buf.push(J, 0)
		var r: ActionRequest = _running(0, Vector2i(A, D), Defs.SLASH_1, f, J, 0, 0)
		if f >= 15:
			assert_not_null(r, "frame %d chains" % f)
			if r != null:
				assert_true(r.chain)
				assert_eq(r.def, Defs.SLASH_2)
		else:
			assert_null(r, "frame %d does not chain" % f)


func test_chain_rejects_the_other_key() -> void:
	_buf.push(K, 0)
	assert_null(_running(0, Vector2i(A, L), Defs.SLASH_1, 16, J, 0, 0), "K is not the chain key")
	assert_eq(_buf.size(), 1)


func test_chain_rejected_when_slot_no_longer_attack() -> void:
	_buf.push(J, 0)
	var r: ActionRequest = _running(0, Vector2i(L, A), Defs.SLASH_1, 16, J, 0, 0)
	assert_null(r)
	assert_eq(_buf.size(), 1)


func test_chain_rejected_after_shift_serial_changed() -> void:
	_buf.push(J, 0)
	assert_null(_running(0, Vector2i(A, L), Defs.SLASH_1, 16, J, 0, 1))
	assert_null(_running(0, Vector2i(A, L), Defs.SLASH_1, 16, J, -1, 0), "no chain record")


func test_hit_three_never_chains() -> void:
	_buf.push(J, 0)
	assert_null(_running(0, Vector2i(A, L), Defs.SLASH_3, 16, J, 0, 0))
	assert_eq(Defs.SLASH_2.chain_next, Defs.SLASH_3)


func test_cancel_only_in_recovery() -> void:
	for f: int in range(1, 23):
		_buf.clear()
		_buf.push(K, 0)
		var r: ActionRequest = _running(0, Vector2i(A, D), Defs.SLASH_1, f)
		if f >= 11:
			assert_not_null(r, "frame %d cancels" % f)
			if r != null:
				assert_eq(r.cancel, f < 22, "last frame is a solo start, not a cancel")
				assert_eq(r.def, Defs.DASH)
		else:
			assert_null(r, "frame %d refuses" % f)


func test_cancel_only_into_dash() -> void:
	_buf.push(K, 0)
	assert_null(_running(0, Vector2i(D, A), Defs.SLASH_1, 12), "A is not in cancel_into")
	_buf.push(J, 0)
	var r: ActionRequest = _running(0, Vector2i(D, A), Defs.SLASH_1, 12)
	assert_not_null(r)
	assert_eq(r.key, J)


func test_cancel_blocked_by_cooldown() -> void:
	_cd.start(D, 5)
	_buf.push(J, 0)
	assert_null(_running(0, Vector2i(D, A), Defs.DASH, 12))
	assert_eq(_buf.size(), 1)


func test_dash_recovery_cancels_into_dash_when_ready() -> void:
	_buf.push(J, 0)
	var r: ActionRequest = _running(0, Vector2i(D, A), Defs.DASH, 11)
	assert_not_null(r)
	assert_true(r.cancel)
	assert_null(_running(0, Vector2i(D, A), Defs.DASH, 10), "dash frame 10 is ACTIVE")


# --- Story 2.6: the link rule (AC2-AC6) with a LinkState built by hand ---

func _open_link(pair: Vector2i, serial: int = 0) -> LinkState:
	var link := LinkState.new()
	link.open(pair, serial)
	return link


func _linked(frame: int, window: Vector2i, def: ActionDef, action_frame: int, link: LinkState, shift_serial: int = 0) -> ActionRequest:
	return ActionResolver.resolve(_req_input(frame, window, def, action_frame, &"", -1, shift_serial, link, Defs.COMBOS))


func test_combo_press_during_slash_active_is_held() -> void:
	var link: LinkState = _open_link(Vector2i(A, D))
	_buf.push(K, 4)
	var r: ActionRequest = _linked(7, Vector2i(A, D), Defs.SLASH_1, 7, link)
	assert_not_null(r)
	assert_null(r.def, "a link instruction, not a start")
	assert_eq(r.link_op, ActionRequest.LinkOp.HOLD)
	assert_eq(r.held_frame, 4)
	assert_eq(r.slot, 1)
	assert_false(_buf.consume(K, 7), "consumed from the buffer")


func test_held_combo_starts_on_the_first_recovery_frame() -> void:
	var link: LinkState = _open_link(Vector2i(A, D))
	link.hold(K, 1, 4)
	for f: int in range(7, 11):
		assert_null(_linked(f, Vector2i(A, D), Defs.SLASH_1, f, link), "frame %d is ACTIVE" % f)
	var r: ActionRequest = _linked(11, Vector2i(A, D), Defs.SLASH_1, 11, link)
	assert_not_null(r)
	assert_eq(r.def, Defs.DASH_STRIKE)
	assert_eq(r.combo, Defs.COMBOS.get_combo(A, D))
	assert_eq(r.bit, D, "the second bit's cooldown applies")
	assert_true(r.cancel)
	assert_false(r.link_second)


func test_combo_from_idle_inside_the_link() -> void:
	var link: LinkState = _open_link(Vector2i(A, D))
	_buf.push(K, 25)
	var r: ActionRequest = _linked(25, Vector2i(A, D), null, 0, link)
	assert_eq(r.def, Defs.DASH_STRIKE)
	assert_false(r.cancel)


func test_no_combo_window_holds_during_dash_and_starts_after_it() -> void:
	var link: LinkState = _open_link(Vector2i(D, A))
	_buf.push(K, 3)
	var r: ActionRequest = _linked(3, Vector2i(D, A), Defs.DASH, 3, link)
	assert_eq(r.link_op, ActionRequest.LinkOp.HOLD)
	link.hold(K, 1, r.held_frame)
	for f: int in range(4, 16):
		assert_null(_linked(f, Vector2i(D, A), Defs.DASH, f, link), "dash frame %d: ATTACK is not in cancel_into" % f)
	r = _linked(16, Vector2i(D, A), Defs.DASH, 16, link)
	assert_eq(r.def, Defs.SLASH_1)
	assert_true(r.link_second)
	assert_null(r.combo)
	assert_eq(r.key, K)


func test_ordered_lookup_never_fires_a_combo_on_d_a() -> void:
	var link: LinkState = _open_link(Vector2i(D, A))
	_buf.push(K, 20)
	var r: ActionRequest = _linked(20, Vector2i(D, A), null, 0, link)
	assert_eq(r.def, Defs.SLASH_1)
	assert_null(r.combo)


func test_held_press_on_cooldown_drops_after_8_frames() -> void:
	var link: LinkState = _open_link(Vector2i(A, D))
	link.hold(K, 1, 10)
	_cd.start(D, 30)
	assert_null(_linked(18, Vector2i(A, D), Defs.SLASH_1, 12, link), "8 frames: still held")
	var r: ActionRequest = _linked(19, Vector2i(A, D), Defs.SLASH_1, 13, link)
	assert_not_null(r)
	assert_eq(r.link_op, ActionRequest.LinkOp.DROP)


func test_unheld_press_on_cooldown_stays_buffered() -> void:
	var link: LinkState = _open_link(Vector2i(A, D))
	_cd.start(D, 30)
	_buf.push(K, 8)
	assert_null(_linked(8, Vector2i(A, D), Defs.SLASH_1, 9, link))
	assert_eq(_buf.size(), 1, "not consumed, not held (no partial execution)")
	assert_null(_linked(12, Vector2i(A, D), Defs.SLASH_1, 13, link), "the solo cancel is not tried either")
	assert_eq(_buf.size(), 1)


func test_shift_serial_change_hands_k_back_to_the_solo_rules() -> void:
	var link: LinkState = _open_link(Vector2i(A, D), 0)
	_buf.push(K, 12)
	var r: ActionRequest = _linked(12, Vector2i(A, D), Defs.SLASH_1, 12, link, 1)
	assert_eq(r.def, Defs.DASH, "solo cancel: the link belongs to the old serial")
	assert_null(r.combo)


func test_closed_link_k_uses_the_2_5_rules() -> void:
	var link := LinkState.new()
	_buf.push(K, 3)
	assert_null(_linked(3, Vector2i(A, D), Defs.SLASH_1, 3, link), "K in STARTUP is not held without a link")
	assert_eq(_buf.size(), 1)


func test_same_frame_j_and_k_resolves_j_first() -> void:
	var link: LinkState = _open_link(Vector2i(D, A))
	_buf.push(J, 30)
	_buf.push(K, 30)
	var r: ActionRequest = _linked(30, Vector2i(D, A), null, 0, link)
	assert_eq(r.key, J)
	assert_eq(_buf.size(), 2, "K still buffered")


func test_j_still_resolves_while_the_link_owns_k() -> void:
	var link: LinkState = _open_link(Vector2i(D, A))
	link.hold(K, 1, 28)
	_buf.push(J, 30)
	_buf.push(K, 30)
	_cd.start(A, 99) # the held slash cannot start; K belongs to the link
	var r: ActionRequest = _linked(30, Vector2i(D, A), null, 0, link)
	assert_eq(r.key, J, "J's dash")
	assert_eq(r.def, Defs.DASH)


# --- Story 2.7 AC6: the ResolveInput parameter object ---

func test_resolve_input_defaults_match_the_old_optional_arguments() -> void:
	var input := ResolveInput.new()
	assert_null(input.action)
	assert_eq(input.action_frame, 0)
	assert_eq(input.chain_key, &"")
	assert_eq(input.chain_serial, -1)
	assert_eq(input.shift_serial, 0)
	assert_null(input.link)
	assert_null(input.combos)


func test_resolve_with_null_or_incomplete_input_is_null() -> void:
	assert_null(ActionResolver.resolve(null))
	var input := ResolveInput.new()
	input.cooldowns = _cd
	assert_null(ActionResolver.resolve(input), "no buffer")
	input.buffer = _buf
	input.cooldowns = null
	_buf.push(J, 0)
	assert_null(ActionResolver.resolve(input), "no cooldowns")
	assert_eq(_buf.size(), 1, "nothing consumed")
