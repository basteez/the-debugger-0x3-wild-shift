extends GutTest
## Story 6.5 (AC 5, 6, 12, NP-3, D-S65-3): the PlayerEffects queue's first command, RotateRegister.
## Applied in the PLAYER_EFFECTS phase against the bound Register and LinkState; an unbound queue
## drops its commands with an error; clear() empties it.

const A := Register.Bit.ATTACK
const D := Register.Bit.DASH
const L := Register.Bit.LOOP
const N := Register.Bit.NULL_BIT

var _ctx: SimContext
var _fx: PlayerEffects
var _reg: Register
var _link: LinkState


func before_each() -> void:
	_ctx = SimContext.new()
	_fx = PlayerEffects.new()
	_reg = Register.new()
	_reg.set_fight_start(PackedInt32Array([A, D, L, N]))
	_link = LinkState.new()
	_fx.bind(_reg, _link)


func test_runs_in_the_player_effects_phase_between_hazards_and_combat() -> void:
	assert_eq(_fx.phase, SimSystem.SimPhase.PLAYER_EFFECTS)
	assert_lt(SimSystem.SimPhase.SHIFTS, SimSystem.SimPhase.PLAYER_EFFECTS)
	assert_lt(SimSystem.SimPhase.BOSS_HAZARDS, SimSystem.SimPhase.PLAYER_EFFECTS)
	assert_lt(SimSystem.SimPhase.PLAYER_EFFECTS, SimSystem.SimPhase.COMBAT)


func test_rotate_register_applies_once_on_the_tick() -> void:
	watch_signals(EventBus)
	_link.open(Vector2i(A, D), _reg.shift_serial)
	_fx.push(PlayerEffects.RotateRegister.new(2))
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "nothing happens before the tick")
	_fx.tick(_ctx)
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D]))
	assert_false(_link.is_open(), "NP-1: the rotation closes the link")
	assert_signal_emit_count(EventBus, "register_shifted", 1)
	assert_eq(_fx.pending(), 0)
	_fx.tick(_ctx)
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D]), "applied once")
	assert_signal_emit_count(EventBus, "register_shifted", 1)


func test_rotation_discards_a_held_link_press() -> void:
	_link.open(Vector2i(A, D), _reg.shift_serial)
	_link.hold(&"action_2", 1, 10)
	_fx.push(PlayerEffects.RotateRegister.new(2))
	_fx.apply_all()
	assert_false(_link.held)


func test_unbound_queue_drops_with_an_error() -> void:
	var fx := PlayerEffects.new()
	assert_false(fx.is_bound())
	fx.push(PlayerEffects.RotateRegister.new(2))
	fx.apply_all()
	assert_push_error("not bound")
	assert_eq(fx.pending(), 0)


func test_clear_empties_the_queue() -> void:
	_fx.push(PlayerEffects.RotateRegister.new(2))
	_fx.clear()
	assert_eq(_fx.pending(), 0)
	_fx.tick(_ctx)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "a cleared rotation never lands")


func test_the_command_names_pass_the_attack_isolation_patterns() -> void:
	# D-S65-3: the attack may name PlayerEffects.RotateRegister; neither matches \bPlayer\b / \bRegister\b.
	var code := "ctx.player_effects.push(PlayerEffects.RotateRegister.new(2))"
	assert_eq(load("res://tests/unit/test_attack_isolation.gd").violations(code), PackedStringArray())


# --- Story 6.6 (AC 6, 7, 12, 13, 15, D-S66-3, D-S66-4): InsertTemporaryBit and its expiry ---

const G := Register.Bit.GARBAGE


func test_commands_share_the_player_command_base() -> void:
	assert_true(PlayerEffects.RotateRegister.new(2) is PlayerCommand)
	assert_true(PlayerEffects.InsertTemporaryBit.new(G, 600) is PlayerCommand)
	assert_eq(PlayerEffects.GARBAGE_BIT, G)


func test_insert_temporary_bit_applies_once_and_closes_the_link() -> void:
	watch_signals(EventBus)
	_link.open(Vector2i(A, D), _reg.shift_serial)
	_fx.push(PlayerEffects.InsertTemporaryBit.new(PlayerEffects.GARBAGE_BIT, 600))
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "nothing happens before the tick")
	_fx.tick(_ctx)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N, G]))
	assert_false(_link.is_open(), "NP-1")
	assert_signal_emit_count(EventBus, "register_changed", 1)
	assert_eq(_fx.temporary_bit(), G)
	assert_eq(_fx.temporary_frames_left(), 600)
	assert_eq(_fx.pending(), 0)


func test_the_bit_is_present_for_exactly_600_ticks() -> void:
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	var present: int = 0
	for i: int in 700:
		_fx.tick(_ctx)
		if _reg.has_temporary():
			present += 1
	assert_eq(present, 600)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]))
	assert_eq(_fx.temporary_bit(), 0)


func test_expiry_emits_garbage_out_and_closes_the_link() -> void:
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 3))
	_fx.tick(_ctx)
	watch_signals(EventBus)
	_link.open(Vector2i(A, D), _reg.shift_serial)
	_fx.tick(_ctx)
	_fx.tick(_ctx)
	assert_true(_reg.has_temporary())
	_fx.tick(_ctx)
	assert_false(_reg.has_temporary())
	assert_signal_emit_count(EventBus, "register_changed", 1)
	assert_signal_emitted_with_parameters(EventBus, "register_changed",
		[Vector2i(A, D), PackedInt32Array([A, D, L, N]), &"garbage_out"])
	assert_false(_link.is_open())


func test_end_temporary_and_clear_leave_no_garbage() -> void:
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	_fx.tick(_ctx)
	_fx.end_temporary(G)
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]))
	assert_eq(_fx.temporary_bit(), 0)
	_fx.end_temporary(G) # no-op
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	_fx.end_temporary(G)
	assert_eq(_fx.pending(), 0, "a queued insertion is dropped too")
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	_fx.tick(_ctx)
	_fx.clear()
	assert_eq(_reg.ring, PackedInt32Array([A, D, L, N]), "clear() never leaves a `?`")
	assert_eq(_fx.temporary_bit(), 0)


func test_a_refused_insert_starts_no_counter() -> void:
	_reg.insert_temporary(G)
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	_fx.tick(_ctx)
	assert_push_error("while ? is present")
	assert_eq(_fx.temporary_bit(), 0, "the refused command tracks nothing")


func test_unbound_insert_is_dropped_with_an_error() -> void:
	var fx := PlayerEffects.new()
	fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	fx.tick(_ctx)
	assert_push_error("not bound")
	assert_eq(fx.temporary_bit(), 0)
	fx.clear()


func test_rotation_and_insertion_in_one_tick_apply_in_push_order() -> void:
	_fx.push(PlayerEffects.RotateRegister.new(2))
	_fx.push(PlayerEffects.InsertTemporaryBit.new(G, 600))
	_fx.tick(_ctx)
	assert_eq(_reg.ring, PackedInt32Array([L, N, A, D, G]))


func test_the_insert_command_names_pass_the_attack_isolation_patterns() -> void:
	var code := "ctx.player_effects.push(PlayerEffects.InsertTemporaryBit.new(PlayerEffects.GARBAGE_BIT, 600))"
	assert_eq(load("res://tests/unit/test_attack_isolation.gd").violations(code), PackedStringArray())
