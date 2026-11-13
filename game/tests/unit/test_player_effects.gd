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
