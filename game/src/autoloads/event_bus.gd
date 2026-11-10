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
## A player hit landed (Story 2.7, NP-4): who was hit (&"practice_target" or &"boss", D-S32-11),
## the DamageCalc result, the damage state (a DamageState.Kind int, D-S32-7), whether
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
## The boss became Patched (Story 3.2, FR21-FR23, D-S32-4): its BossDef.boss_id and the Patched
## length in frames. Emitted by CombatResolver once per application (a refresh emits again);
## AudioManager plays the chime, BossView draws the `// patched` tag.
@warning_ignore("unused_signal")
signal patched_applied(boss: StringName, frames: int)
## The duck was asked to say a line (Story 3.6, AD-14, D-S36-2): the DuckLinesDef id (&"" for raw
## text) and the resolved text. Emitted only by VoiceService.say; DuckBubble shows it. No sim emitter.
@warning_ignore("unused_signal")
signal duck_line_requested(line_id: StringName, text: String)
## The duck voice spoke one character of the line on the bubble (Story 3.7, D-S37-1): its 0-based
## code point index in the spoken text (letters only on the mumble backend; the bubble reveals
## char_index + 1). Emitted only by VoiceService; DuckBubble listens. No sim emitter.
@warning_ignore("unused_signal")
signal duck_character_spoken(char_index: int)
## The duck voice line ended (Story 3.7, D-S37-1): its DuckLinesDef id (&"" for raw text) and
## whether it played to the end (false when cut by VoiceService.stop or the watchdog). Emitted only
## by VoiceService, once per spoken line; DuckBubble reveals the rest and starts the hold.
@warning_ignore("unused_signal")
signal duck_line_finished(line_id: StringName, completed: bool)
## Breakpoint started (Story 4.3, FR24, AD-05): the world is frozen, shifts stay allowed. Emitted
## once per start by the Breakpoint module from SimClock's poll; JuiceDirector dithers the screen,
## the overlay draws the red dot and line, AudioManager switches music (placeholder until 7.1).
@warning_ignore("unused_signal")
signal breakpoint_started()
## Breakpoint ended (Story 4.3): on J/K, at the 120-frame cap, or when the fight is reset or left.
## Emitted once per end; the gate is already cleared.
@warning_ignore("unused_signal")
signal breakpoint_ended()
