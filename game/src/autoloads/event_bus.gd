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
## The player took a hit (Story 2.9, FR2): the remaining HP (0 on the lethal hit). Emitted by
## PlayerHealth from the sim tick; Game raises the death at 0, the HUD and juice listen.
@warning_ignore("unused_signal")
signal player_damaged(hp: int)
## The player died (Story 2.9, I-5): the boss id of the fight and the deaths on that boss so far.
@warning_ignore("unused_signal")
signal player_died(boss: StringName, deaths_on_boss: int)
## The boss's HP changed (Story 3.1, D-S31-15): the new HP and the boss's max HP. Emitted by
## BossController on every HP change and at fight start; the HUD header and BossView listen.
@warning_ignore("unused_signal")
signal boss_hp_changed(hp: int, max_hp: int)
## The boss entered a new phase (Story 3.1, D-S31-8): the 0-based phase index after the change.
@warning_ignore("unused_signal")
signal boss_phase_changed(phase: int)
## A boss attack started its tell (Story 3.1, Pillar 2, D-S31-16): the AttackDef id and its tell
## cue id. AudioManager plays the placeholder cue until 7.2 maps ids to streams.
@warning_ignore("unused_signal")
signal boss_tell_started(attack_id: StringName, tell_sfx: StringName)
## The boss's ROAR started (Story 3.1, D-S31-8): the phase being entered. BossView flashes.
@warning_ignore("unused_signal")
signal boss_roar_started(phase: int)
## The boss was defeated (Story 3.1, D-S31-19): its BossDef.boss_id. Harvest (3.8) reacts.
@warning_ignore("unused_signal")
signal boss_defeated(boss: StringName)
