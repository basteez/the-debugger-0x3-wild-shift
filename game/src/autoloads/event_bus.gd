extends Node
## Global signal hub. Every cross-system signal is declared here and only here.

@warning_ignore("unused_signal")
signal flow_state_changed(from: int, to: int)
@warning_ignore("unused_signal")
signal pause_toggled(paused: bool)
## A register shift was applied (Story 2.3): direction -1 `<<` or +1 `>>`, the new active window
## (two bit ids), the whole ring after the shift, and who shifted it (&"player"; boss effects later).
@warning_ignore("unused_signal")
signal register_shifted(direction: int, window: Vector2i, ring: PackedInt32Array, source: StringName)
## A player hit landed (Story 2.7, NP-4): who was hit (&"practice_target"; &"boss" from Epic 3),
## the DamageCalc result, the damage state (DamageCalc.STATE_BASE until Epic 3, D-S27-7), whether
## the hitting action is a combo (D-S27-14) and the target's arena-local position.
@warning_ignore("unused_signal")
signal hit_landed(target: StringName, damage: int, state: int, is_combo: bool, pos: Vector2)
