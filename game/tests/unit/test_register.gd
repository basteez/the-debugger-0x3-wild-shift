extends GutTest
## Story 2.3 E1: the register ring model (D-S23-1), shift signal, previews, insert, fight-start
## sets and byte value. Pure: no scene tree, no SimClock.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT

var _reg: Register


func before_each() -> void:
	_reg = Register.new()


func _ring(bits: Array) -> PackedInt32Array:
	return PackedInt32Array(bits)


func _start(bits: Array) -> void:
	assert_true(_reg.set_fight_start(_ring(bits)))


func test_default_ring_is_boss_1_start() -> void:
	assert_eq(_reg.ring, _ring([D, A]))
	assert_false(_reg.active)
	assert_eq(_reg.phase, SimSystem.SimPhase.SHIFTS)


func test_two_bits_shift_both_ways() -> void:
	_start([D, A])
	_reg.shift(Register.LEFT)
	assert_eq(_reg.ring, _ring([A, D]), "[D, A] << = [A, D] (Dash Strike)")
	assert_eq(_reg.active_window(), Vector2i(A, D))
	_start([D, A])
	_reg.shift(Register.RIGHT)
	assert_eq(_reg.ring, _ring([A, D]))


func test_three_bits_shift_both_ways() -> void:
	_start([A, D, L])
	_reg.shift(Register.LEFT)
	assert_eq(_reg.ring, _ring([D, L, A]))
	assert_eq(_reg.active_window(), Vector2i(D, L))
	_start([A, D, L])
	_reg.shift(Register.RIGHT)
	assert_eq(_reg.ring, _ring([L, A, D]))
	assert_eq(_reg.active_window(), Vector2i(L, A))


func test_four_bits_shift_both_ways() -> void:
	_start([A, D, L, N])
	_reg.shift(Register.LEFT)
	assert_eq(_reg.ring, _ring([D, L, N, A]))
	assert_eq(_reg.active_window(), Vector2i(D, L))
	_start([A, D, L, N])
	_reg.shift(Register.RIGHT)
	assert_eq(_reg.ring, _ring([N, A, D, L]))
	assert_eq(_reg.active_window(), Vector2i(N, A))


func test_full_cycle_returns_to_start_and_window_always_owned() -> void:
	for start: Array in [[D, A], [A, D, L], [A, D, L, N]] as Array[Array]:
		for direction: int in [Register.LEFT, Register.RIGHT]:
			_start(start)
			for i: int in start.size():
				_reg.shift(direction)
				var w: Vector2i = _reg.active_window()
				assert_true(start.has(w.x) and start.has(w.y) and w.x != w.y, "window owned %s" % w)
				assert_eq(_reg.owned_count(), start.size())
			assert_eq(_reg.ring, _ring(start), "full cycle %s dir %d" % [start, direction])


func test_shift_emits_register_shifted_once() -> void:
	watch_signals(EventBus)
	_start([A, D, L])
	_reg.shift(Register.LEFT)
	assert_signal_emit_count(EventBus, "register_shifted", 1)
	assert_signal_emitted_with_parameters(EventBus, "register_shifted",
		[Register.LEFT, Vector2i(D, L), _ring([D, L, A]), &"player"])
	_reg.shift(Register.RIGHT)
	assert_signal_emit_count(EventBus, "register_shifted", 2)
	assert_signal_emitted_with_parameters(EventBus, "register_shifted",
		[Register.RIGHT, Vector2i(A, D), _ring([A, D, L]), &"player"])


func test_signal_ring_is_a_copy() -> void:
	var seen: Array[PackedInt32Array] = []
	var cb := func(_d: int, _w: Vector2i, r: PackedInt32Array, _s: StringName) -> void: seen.append(r)
	EventBus.register_shifted.connect(cb)
	_reg.shift(Register.LEFT)
	EventBus.register_shifted.disconnect(cb)
	assert_eq(seen.size(), 1)
	_reg.shift(Register.LEFT)
	assert_eq(seen[0], _ring([A, D]), "listener's copy is not changed by later shifts")


func test_bad_direction_is_rejected() -> void:
	watch_signals(EventBus)
	_reg.shift(0)
	assert_push_error("shift direction")
	assert_eq(_reg.ring, _ring([D, A]))
	assert_signal_not_emitted(EventBus, "register_shifted")


func test_previews_match_shift_and_do_not_mutate() -> void:
	for start: Array in [[D, A], [A, D, L], [A, D, L, N]] as Array[Array]:
		for direction: int in [Register.LEFT, Register.RIGHT]:
			_start(start)
			var p: Vector2i = _reg.preview(direction)
			assert_eq(_reg.ring, _ring(start), "preview leaves the ring")
			_reg.shift(direction)
			assert_eq(p, _reg.active_window(), "preview %s dir %d" % [start, direction])


func test_insert_appends_after_last_owned() -> void:
	_start([D, A])
	assert_true(_reg.insert(L))
	assert_eq(_reg.ring, _ring([D, A, L]))
	_reg.shift(Register.LEFT)
	assert_true(_reg.insert(N))
	assert_eq(_reg.ring, _ring([A, L, D, N]))


func test_insert_rejects_duplicate_full_and_unknown() -> void:
	_start([A, D, L])
	assert_false(_reg.insert(D))
	assert_push_error("insert of owned bit")
	assert_false(_reg.insert(99))
	assert_push_error("unknown bit")
	assert_eq(_reg.ring, _ring([A, D, L]))
	_start([A, D, L])
	_reg.insert(N)
	assert_false(_reg.insert(5))
	assert_push_error("unknown bit")
	assert_eq(_reg.ring, _ring([A, D, L, N]))


func test_insert_rejects_full_register() -> void:
	_start([A, D, L, N])
	assert_false(_reg.insert(N))
	assert_push_error("full register")
	assert_eq(_reg.ring, _ring([A, D, L, N]))


func test_set_fight_start_accepts_the_three_sets() -> void:
	for bits: Array in [[D, A], [A, D, L], [A, D, L, N]] as Array[Array]:
		assert_true(_reg.set_fight_start(_ring(bits)))
		assert_eq(_reg.ring, _ring(bits))


func test_set_fight_start_copies_the_input() -> void:
	var bits: PackedInt32Array = _ring([A, D, L])
	_reg.set_fight_start(bits)
	_reg.shift(Register.LEFT)
	assert_eq(bits, _ring([A, D, L]), "caller's array untouched")


func test_set_fight_start_rejects_bad_sets() -> void:
	_start([A, D, L])
	var bad: Array[Array] = [[], [A], [A, D, L, N, A], [A, A], [D, A, D], [A, 0], [A, D, 7]]
	for bits: Array in bad:
		assert_false(_reg.set_fight_start(_ring(bits)), "rejected %s" % [bits])
		assert_eq(_reg.ring, _ring([A, D, L]), "unchanged after %s" % [bits])
	assert_push_error_count(bad.size())


func test_byte_value() -> void:
	_start([D, A])
	assert_eq(_reg.byte_value(), 0x03)
	_start([A, D, L])
	assert_eq(_reg.byte_value(), 0x07)
	_start([A, D, L, N])
	assert_eq(_reg.byte_value(), 0x0F)


func test_glyphs() -> void:
	assert_eq(Register.glyph_of(A), "A")
	assert_eq(Register.glyph_of(D), "D")
	assert_eq(Register.glyph_of(L), "L")
	assert_eq(Register.glyph_of(N), "N")
	assert_eq(Register.glyph_of(0), "?")


func test_fight_start_for_boss() -> void:
	assert_eq(Register.fight_start_for_boss(0), _ring([D, A]))
	assert_eq(Register.fight_start_for_boss(1), _ring([A, D, L]))
	assert_eq(Register.fight_start_for_boss(2), _ring([A, D, L, N]))
	assert_eq(Register.fight_start_for_boss(7), _ring([D, A]), "unknown index falls back to Boss 1")
	assert_eq(Register.fight_start_for_boss(-1), _ring([D, A]))


## Story 2.5 (D-S25-2): shift_serial counts applied shifts only.
func test_shift_serial_counts_applied_shifts() -> void:
	assert_eq(_reg.shift_serial, 0)
	_reg.shift(Register.LEFT)
	assert_eq(_reg.shift_serial, 1)
	_reg.shift(Register.RIGHT)
	assert_eq(_reg.shift_serial, 2)
	_reg.shift(0)
	assert_push_error("shift direction")
	assert_eq(_reg.shift_serial, 2, "a rejected shift does not count")
	_reg.preview(Register.LEFT)
	assert_eq(_reg.shift_serial, 2, "preview never counts")


# --- Story 3.8 (G5): the harvest insertion ---

func test_inserting_loop_into_a_d_gives_a_d_l_and_0x07() -> void:
	_start([A, D])
	assert_true(_reg.insert(L))
	assert_eq(_reg.ring, _ring([A, D, L]))
	assert_eq(_reg.byte_value(), 0x07)
	assert_eq(_reg.ring, Register.fight_start_for_boss(1), "the Fight 2 start set")


func test_inserting_into_a_full_ring_or_a_duplicate_is_rejected() -> void:
	_start([A, D, L])
	assert_false(_reg.insert(L))
	assert_push_error("insert of owned bit")
	_start([A, D, L, N])
	assert_false(_reg.insert(L))
	assert_push_error("insert into a full register")
	assert_eq(_reg.ring, _ring([A, D, L, N]))


# --- Story 6.5 (AC 6, 17, D-S65-4, D-S65-5): rotate(n), the SIGSEGV path ---

func test_rotate_by_2_on_3_and_4_bit_rings() -> void:
	_start([A, D, L])
	_reg.rotate(2)
	assert_eq(_reg.ring, _ring([D, L, A]), "+2 on 3 bits = two `>>` = one `<<`")
	_start([A, D, L, N])
	_reg.rotate(2)
	assert_eq(_reg.ring, _ring([L, N, A, D]), "+2 on 4 bits swaps the halves")
	assert_eq(_reg.active_window(), Vector2i(L, N))
	_reg.rotate(-1)
	assert_eq(_reg.ring, _ring([N, A, D, L]), "a negative count rotates `<<`")


func test_rotate_on_a_2_bit_ring_is_a_ring_no_op_but_still_emits() -> void:
	watch_signals(EventBus)
	_start([D, A])
	_reg.rotate(2)
	assert_eq(_reg.ring, _ring([D, A]), "D-S65-4: +2 mod 2 leaves the ring as it was")
	assert_signal_emit_count(EventBus, "register_shifted", 1)
	assert_signal_emitted_with_parameters(EventBus, "register_shifted",
		[Register.RIGHT, Vector2i(D, A), _ring([D, A]), &"sigsegv"])


func test_rotate_emits_once_with_the_sigsegv_source_and_keeps_the_serial() -> void:
	watch_signals(EventBus)
	_start([A, D, L, N])
	var serial: int = _reg.shift_serial
	_reg.rotate(2)
	assert_signal_emit_count(EventBus, "register_shifted", 1)
	assert_signal_emitted_with_parameters(EventBus, "register_shifted",
		[Register.RIGHT, Vector2i(L, N), _ring([L, N, A, D]), &"sigsegv"])
	assert_eq(_reg.shift_serial, serial, "D-S65-5 (amended): a rotation is not a player shift")
	_reg.shift(Register.LEFT)
	assert_eq(_reg.shift_serial, serial + 1, "shift() still bumps it")


func test_rotate_rejects_zero_and_short_rings() -> void:
	watch_signals(EventBus)
	_start([A, D, L])
	_reg.rotate(0)
	assert_push_error("rotate by 0 slots")
	_reg.ring = PackedInt32Array([A])
	_reg.rotate(2)
	assert_push_error("rotate on a ring of 1 bits")
	assert_signal_emit_count(EventBus, "register_shifted", 0)
