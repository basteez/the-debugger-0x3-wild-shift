extends GutTest
## Story 2.5 AC2-AC5: ActionResolver rules (chain, cancel, solo) with a real InputBuffer. Pure.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const J := &"action_1"
const K := &"action_2"

var _buf: InputBuffer
var _cd: Cooldowns


func before_each() -> void:
	_buf = InputBuffer.new()
	_cd = Cooldowns.new()


## Resolve with no running action.
func _idle(frame: int, window: Vector2i) -> ActionRequest:
	return ActionResolver.resolve(_buf, frame, window, null, 0, &"", -1, 0, _cd)


func _running(frame: int, window: Vector2i, def: ActionDef, action_frame: int, chain_key: StringName = &"", chain_serial: int = -1, shift_serial: int = 0) -> ActionRequest:
	return ActionResolver.resolve(_buf, frame, window, def, action_frame, chain_key, chain_serial, shift_serial, _cd)


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
	assert_null(_idle(0, Vector2i(L, A)))
	assert_eq(_buf.size(), 1, "not consumed")


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
	var r: ActionRequest = _running(0, Vector2i(L, A), Defs.SLASH_3, 22)
	assert_null(r, "L has no action")
	_buf.push(K, 0)
	r = _running(0, Vector2i(L, A), Defs.SLASH_3, 22)
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
