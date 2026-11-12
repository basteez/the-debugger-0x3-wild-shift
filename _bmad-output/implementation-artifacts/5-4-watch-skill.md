---
baseline_commit: 36195db
---

# Story 5.4: Watch Skill

Status: done
<!-- Created unattended by gds-create-story (pipeline, 2026-11-11). Self-made design calls are marked [design call] with IDs D-S54-n; the implementer follows them or records a change in Completion Notes. Scope: cut-ladder item #2, the Watch skill behind `FeatureFlags.watch`: the held R input, the leaf module in `src/skills/watch/` (state, unlock, effects), the reveal of the real Null Pointer ghost, the boss read-outs (next attack name, bit labels, weak window highlight), and the flag-off fallback (ghost flicker 20 frames every 2 s). NOT in scope: the Watch duck tutorial line (5.6), the Null Pointer tutorials, the NULL bit (5.5), decoy reveal (see D-S54-1: decoys stay hidden), Ghost Echo decoys (Epic 6), any change to decoy or whiff logic (5.3). -->

## Story

As a player,
I want to hold R to see what is hidden and what is coming,
so that I can read the fight even against an invisible bug.

**Requirements:** FR25; Additional: cut ladder #2 (`FeatureFlags.watch`). GDD "Skills" table (Watch: hold R, reveals hidden entities, highlights the weak window, shows the next attack's name and the boss's bits; while held move speed x0.5 and no actions), GDD "Boss 2 — Null Pointer" (only the real ghost shows in Watch; decoys never hum), GDD cut ladder #2 (flag-off: ghost flickers 20 frames every 2 s). Architecture AD-01 (SimClock gates), AD-05 (presentation reads only), AD-12 (FeatureFlags, leaf modules). Project-context rules: integer sim state, no RNG in attack scripts, presentation may not write sim state, `arena/` may not reference `presentation/`.

## Acceptance Criteria

**Unlock and input**

1. **Given** `FeatureFlags.watch` is on (`Defs.FEATURE_FLAGS.watch`, already in `feature_flags.tres`), **When** a fight starts, **Then** Watch is usable only when the fight is Boss 2 or later (`RunState.boss_index >= 1`, same rule as `Arena.breakpoint_unlocked_for`, D-S54-4). Before that R does nothing.
2. **Given** Watch is unlocked and the FIGHT is active, **When** R is held, **Then** Watch is held for every polled frame R is down (a held state, not a press), and it ends on the first frame R is up. Entering FIGHT, retry, debug jump and leaving FIGHT all clear the held state (D-S54-11).
3. **And** the held R is read through a new generic `InputSource.watch_held_for_frame() -> bool` (LiveInput: `Input.is_action_pressed(&"watch")`; ReplayInput: from the recording, D-S54-2). Simulation code never touches the `Input` singleton.

**Effects while held (sim)**

4. **Given** Watch is held, **When** the player moves, **Then** the top speed is halved (×0.5 of `PlayerDef.speed_tiles_s`) through the same ramp (`Player.tick`), and the held direction still sets facing (D-S54-5).
5. **And** while held, a J or K press starts no action: the press is consumed and discarded (not kept for later). A running action finishes normally (its chain and link are unaffected). When no action runs, `ActionState` reports `WATCHING` (the enum value already exists, Story 2.5). Register shifts, Q/E and Breakpoint stay usable, because they are not actions (D-S54-5, as D-S53-14).
6. **And** Watch does not stun, does not change damage, Patched, the boss FSM, the RNG or any attack timing. Nothing in the boss or the attack scripts reads Watch except the body's visibility (AC 7).

**Reveal and read-outs (presentation reads only)**

7. **Given** Watch is held and a Null Pointer fight is running, **When** the ghost is drawn, **Then** it is visible (the Story 5.1 `watch_held` rule, now driven by the held state, not by a test setter). Decoys are not revealed (AC 11, D-S54-1).
8. **And** while held, the boss's **next attack name** is shown above the boss: the attack in TELL or ACTIVE (the attack being telegraphed now). In GAP no attack is picked yet, so the label reads `NEXT: ?` (D-S54-7). No attack name is shown when no attack is planned (the phase has no attack, or the boss is defeated).
9. **And** while held, the boss's **bits** are shown as a bit label above the boss: the drop bit (`BossDef.drop_bit`, `Register.glyph_of`) and the current phase's weak window as two bit glyphs (D-S54-8).
10. **And** while held, the **current weak window** is highlighted on the HUD: the two bits of `current_weak_window()` are marked in the register panel (presentation only; the Register itself is not changed). Released Watch removes every mark.
11. **And** Watch reveals the real body only. Decoys (Story 5.3) are never drawn by Watch: `WatchOverlay` and `BossView` do not read any decoy getter (`decoy_positions()`, `planned_positions()`, `recast_flicker_positions()`, `dispel_flash_positions()`), and `WatchSkill` does not reference the boss's decoy API. A test pins this (AC 19).

**Flag-off fallback (cut #2)**

12. **Given** `FeatureFlags.watch = false`, **When** the Null Pointer fight runs, **Then** R does nothing (no skill constructed, no overlay, no HUD mark, no `watch_*` events, no held state reaches the sim), and the ghost flickers visible for 20 frames every 120 live ticks (2 s), counted in live ticks, paused in ROAR and DEFEATED, reset on every fight entry (D-S54-9). Decoys still never hum (5.1 / 5.3 rules unchanged).
13. **And** the fallback is driven by a `watch_fallback: bool` on `NullPointerBody` injected by `Arena` at wiring (default from `Defs.FEATURE_FLAGS.watch`, like `breakpoint_on`), so tests drive both sides. With the flag on, the fallback is inert.

**Leaf module and wiring**

14. **Given** the flag is on, **When** the Arena is built, **Then** `WatchSkill` (`game/src/skills/watch/watch_skill.gd`, `extends FightSkill`, TIMERS phase) is constructed by path and registered with SimClock; with the flag off nothing under `src/skills/watch/` is instantiated (AD-12, D-S54-3).
15. **And** no file outside `src/skills/watch/` names `WatchSkill` or `WatchOverlay` by class name. `game/tools/check_guards.sh` gets a rule for it (the same pattern as the Breakpoint rule), and `tests/unit/test_watch_wiring.gd` pins it.
16. **And** the core talks to the skill only through a generic bool `SimClock.watch_gate_active` (written by the skill in `poll()`, read by SimClock), `SimContext.watch_held` (copied from the gate by SimClock before the systems tick), and `EventBus` signals `watch_started` / `watch_ended` (new). Player, ActionStateMachine and NullPointerBody read `ctx.watch_held` only.
17. **And** `FeatureFlags` still does not reference `Defs` (4.2 lesson). `Arena` reads the flag once at construction, as Breakpoint does.

**Determinism, replay and isolation**

18. **And** Watch-held is part of the replay: the recorder writes a `watch` array (format v3, one bool per polled frame), and `ReplayInput` returns it on the same poll index as the presses and moves. A v1 or v2 recording (no `watch`) replays with Watch never held. A recording made with Watch held replays to the same sim state (test).
19. `watch_skill.gd`, `watch_overlay.gd` and the Watch read-outs draw no RNG, write no sim state other than the gate, and read no decoy getter (AC 11). `test_attack_isolation` keeps passing.

**Tests**

20. Unit tests in `game/tests/unit/test_watch_skill.gd`: unlock rule (boss index 0 refuses, 1 accepts), held start and end on R down / up, cleared by `reset_for_fight` and `end_fight`, gate written only while in fight, emits `watch_started` / `watch_ended` once each.
21. Unit tests in `game/tests/unit/test_watch_effects.gd`: half speed while held (`Player` through `SimContext.watch_held`), J/K presses discarded while held, running action finishes, `WATCHING` when idle, shifts and Breakpoint not blocked, no stun / no damage change.
22. Unit tests in `game/tests/unit/test_watch_fallback.gd`: flag-off ghost flicker (20 on every 120 live ticks, paused in ROAR / DEFEATED, reset per fight), flag-on fallback inert, with the flag off no skill is constructed.
23. Unit tests in `game/tests/unit/test_watch_readouts.gd`: next-attack label rule (TELL / ACTIVE name, GAP `NEXT: ?`, none when defeated), bit label rule (drop bit + weak window glyphs), HUD marks only while held, decoys not in any reveal set (AC 11).
24. Unit tests in `game/tests/unit/test_replay_watch.gd` (or extend the existing replay test): format v3 round-trip, v2 replays with no Watch, a recording with Watch held reproduces.
25. `game/tests/unit/test_data_validation.gd`: `feature_flags.tres` still validates (no new field). `game/tests/unit/test_watch_wiring.gd`: the leaf rule and the flag-off construction (the Breakpoint wiring test's pattern).
26. Existing suites (`test_breakpoint_*`, `test_null_pointer_*`, `test_action_fsm`, `test_attack_isolation`, `test_replay*`, `test_feature_flags`) stay green. Full GUT suite headless, `check_guards.sh`, no new `Log.error`. Run the relevant suites once with `FeatureFlags.watch = false` (temporary `feature_flags.tres` edit, restored after) as the 4.3 flag-off run did.

## Tasks / Subtasks

- [x] Task 1: Input and replay (AC: 2, 3, 18; D-S54-2)
  - [x] 1.1 `input_source.gd`: `watch_held_for_frame() -> bool` (default false). `live_input.gd`: `Input.is_action_pressed(&"watch")` guarded by `InputMap.has_action`.
  - [x] 1.2 `sim_context.gd`: `var watch_held: bool = false` (set by SimClock, read-only for systems). `sim_clock.gd`: read `watch_held_for_frame()` each polled frame into a raw `ctx.watch_input` (not yet the held state), pass it to the recorder, and after the polls copy `ctx.watch_held = watch_gate_active` before the gates.
  - [x] 1.3 `input_recorder.gd`: format v3, `record(presses, move, watch)`, a parallel `watch` array of bools, `stop()` returns `"watch"`. `replay_input.gd`: `watch` argument (default empty), `watch_for_frame()`, a v1/v2 recording gives all false. Keep the presses format unchanged.
- [x] Task 2: Skill and gate (AC: 1, 2, 14, 16, 17; D-S54-3, D-S54-4, D-S54-11)
  - [x] 2.1 `sim_clock.gd`: `var watch_gate_active: bool = false` (generic, written by the leaf only, like `breakpoint_gate_active`).
  - [x] 2.2 `game/src/skills/watch/watch_skill.gd` (`class_name WatchSkill extends FightSkill`, phase TIMERS): `_init(p_gate, ...)`, `reset_for_fight(unlocked)` (held false, in_fight true), `end_fight()` (gate off, `watch_ended` if held), `poll(presses, ctx)`: when in fight and unlocked, held = `ctx.watch_input`, write the gate, emit `watch_started` / `watch_ended` on edges. Not in fight or locked: gate false. `is_active()` = held, `is_unlocked()`, `cooldown_left_frames()` = 0.
  - [x] 2.3 `event_bus.gd`: `watch_started`, `watch_ended` signals (Story 5.4 note).
  - [x] 2.4 `arena.gd`: `make_watch_skill(enabled)` (static, by path, null when off), construction next to the Breakpoint skill, registration in `_enter_tree` / `_exit_tree`, `reset_for_fight(unlocked)` and `end_fight()` in `enter_fight` / `leave_fight`, `set_watch_enabled` for flag-off tests, `watch_fallback` injected into the boss (Task 4). Unlock: `Arena.watch_unlocked_for(boss_index)` returns `boss_index >= 1` (or reuse `breakpoint_unlocked_for`; D-S54-4).
- [x] Task 3: Effects in the core (AC 4, 5, 6; D-S54-5)
  - [x] 3.1 `player.gd`: `tick` halves `v_max` when `ctx.watch_held` (and `unlock_movement` cap stays walking top speed, so a dash carried out of Watch is capped the same way).
  - [x] 3.2 `action_state_machine.gd`: in `tick`, after the stun check: when `ctx.watch_held` and no action is running, consume J/K presses live this tick (drop, do not keep), set `state = WATCHING`, skip the input read and movement lock; a running action continues its normal frames. `state_for` keeps reporting the action states; `WATCHING` only when idle.
  - [x] 3.3 Confirm no path in `CombatResolver`, `BossController` or the attacks reads `ctx.watch_held`.
- [x] Task 4: Null Pointer body and fallback (AC 7, 11, 12, 13; D-S54-1, D-S54-6, D-S54-9)
  - [x] 4.1 `null_pointer_body.gd`: `_tick_body(ctx)` sets `watch_held = ctx.watch_held` (the 5.1 setter stays for tests). `visible_now()` unchanged in shape (the `watch_held` term already exists).
  - [x] 4.2 `null_pointer_body.gd`: `var watch_fallback: bool = false`; when on, a `fallback_cycle_left` live-tick counter (120 cycle, 20 visible), paused in ROAR and DEFEATED, reset in `reset_for_fight`; `visible_now()` adds `fallback_visible`.
  - [x] 4.3 `boss_controller.gd`: nothing beyond the injected flag (no Watch branch in the framework). `arena.gd` sets `boss.body.watch_fallback` from `Defs.FEATURE_FLAGS.watch` (or the injected value) in `_set_boss`.
- [x] Task 5: Presentation (AC 8, 9, 10, 11, 15; D-S54-7, D-S54-8)
  - [x] 5.1 `game/src/skills/watch/watch_overlay.gd` (`extends Node2D`, loaded by path from `main.gd` when the skill exists, like `BreakpointOverlay`): draws the next-attack label above the boss (`NEXT: ?` in GAP) and the bit label (drop bit glyph and the two weak-window glyphs) only while held. Reads `skill` and `boss` only.
  - [x] 5.2 HUD: the register panel marks the two weak-window bits while Watch is held (through a generic `FightSkill` reference passed by `hud`; presentation only, `register_panel.gd` may read `is_active()`).
  - [x] 5.3 `main.gd`: `_build_watch_views()` next to `_build_breakpoint_views()`, returns early when `arena.watch_skill == null`.
  - [x] 5.4 `boss_view.gd`: no change. Decoy getters stay unread.
- [x] Task 6: Guards and tests (AC: 15, 19, 20–26)
  - [x] 6.1 `game/tools/check_guards.sh`: rule rejecting `WatchSkill` / `WatchOverlay` outside `game/src/skills/watch/` (the Breakpoint rule's pattern).
  - [x] 6.2 Unit tests listed in AC 20–25, each new `.gd` with its `.uid`.
  - [x] 6.3 Full GUT headless, `check_guards.sh`, a flag-off run (`feature_flags.tres` `watch = false`, restored), no new `Log.error`.

## Dev Notes

### Design context (what 5.4 must respect)

- Watch is a cut-ladder module (cut #2). Follow the Breakpoint pattern of Story 4.3 exactly: a `FightSkill` leaf in its own folder, built by path only when the flag is on, touching the core only through a generic gate bool and EventBus signals (D-S43-2).
- Watch's effects must reach the Player and the ASM, which are core systems. They read the generic `ctx.watch_held`; they do not name the skill. This is the only way to keep the leaf rule and still halve speed and block J/K.
- Held versus press: `InputBuffer` holds presses for 8 frames, which is wrong for a hold. Watch uses the raw held state from the InputSource each polled frame. The `watch` press stays in `BUFFERED_ACTIONS` (harmless, nothing consumes it), so the presses format does not change.
- Decoys: GDD ("Only the real ghost hums and shows in Watch") and Story 5.3 AC 9 say decoys are never revealed in Watch. The epic line "decoys marked as decoys" is read as superseded (D-S54-1). Watch must not read the decoy getters at all (the user's instruction for this story).
- The ASM tick order: stun check first (5.3), then Watch, then the normal path. A stunned player stays stunned under Watch.

### Existing code to read first

- `game/src/core/feature_flags.gd`: `watch` already exists (Story 4.3 created the class with all four flags).
- `game/src/core/fight_skill.gd`, `game/src/skills/breakpoint/breakpoint_skill.gd`, `game/src/skills/breakpoint/breakpoint_overlay.gd`: the leaf pattern (`reset_for_fight`, `end_fight`, `is_active`, `is_unlocked`, `poll`, gate writes, EventBus signals).
- `game/src/arena/arena.gd`: `make_breakpoint_skill`, `set_breakpoint_enabled`, `enter_fight`, `leave_fight`, `_set_boss` (`breakpoint_on` injection), `breakpoint_unlocked_for` lives in `main.gd`.
- `game/src/autoloads/sim_clock.gd`: `tick()` order (presses, move_dir, recorder, poll, breakpoint gate, hit-stop, ticks). Add the watch input read and copy after the polls and before the gates.
- `game/src/input/live_input.gd`, `input_source.gd`, `replay_input.gd`, `game/src/debug/input_recorder.gd` (format v2 today, v3 here).
- `game/src/player/player.gd` (`tick`, `lock_movement`, `unlock_movement`), `game/src/player/action_state_machine.gd` (`tick`, `begin_stun`, `_tick_stun`, `WATCHING` enum value).
- `game/src/bosses/null_pointer/null_pointer_body.gd`: `watch_held`, `set_watch_held`, `visible_now()`, `reset_for_fight`, `_tick_body`.
- `game/src/bosses/framework/boss_controller.gd`: `current`, `state`, `current_weak_window()`, `is_hittable()`.
- `game/src/core/run_state.gd` (`boss_index`), `game/src/main/main.gd` (`breakpoint_unlocked_for`, `_build_breakpoint_views`).
- `game/src/presentation/boss_view.gd` (attack tells are drawn here; Watch labels go in `watch_overlay.gd`, not here).
- `game/src/register/register.gd`: `Register.glyph_of(bit)` for the bit label, `Register.window_of`.

### Files to touch

- New: `game/src/skills/watch/watch_skill.gd` (+ `.uid`), `game/src/skills/watch/watch_overlay.gd` (+ `.uid`), `game/tests/unit/test_watch_skill.gd`, `test_watch_effects.gd`, `test_watch_fallback.gd`, `test_watch_readouts.gd`, `test_watch_wiring.gd`, `test_replay_watch.gd` (each + `.uid`). `game/src/skills/watch/.gitkeep` is removed.
- Edit: `game/src/input/input_source.gd`, `live_input.gd`, `replay_input.gd`, `game/src/debug/input_recorder.gd`, `game/src/core/sim_context.gd`, `game/src/autoloads/sim_clock.gd`, `game/src/autoloads/event_bus.gd`, `game/src/arena/arena.gd`, `game/src/main/main.gd`, `game/src/player/player.gd`, `game/src/player/action_state_machine.gd`, `game/src/bosses/null_pointer/null_pointer_body.gd`, `game/src/ui/hud/register_panel.gd` (weak window marks), `game/tools/check_guards.sh`.
- Do not edit: `src/bosses/infinite_loop/`, `src/bosses/segfault/` (Epic 6), `data/bits/` (5.5), `data/config/feature_flags.tres` (flags already present), any decoy logic in `null_pointer_body.gd` or `dangling_pointers.gd` (5.3), `combat_resolver.gd` (no Watch effect), `boss_view.gd` (no change).

### Testing standards

GUT tests in `game/tests/unit/` and `game/tests/integration/`. Fixed seeds through `SimContext`. Ticks through `SimClock` or direct `tick` calls, never wall time. Simulation runs headless without a scene tree: build the skill with an injected gate object (a `RefCounted` with a `watch_gate_active` property, as the Breakpoint tests do).

### Previous story intelligence

- Story 4.3 (done): FeatureFlags creation, leaf wiring by path, `check_guards` rule, `breakpoint_on` injection by Arena, flag-off run of the suite. Its lessons apply directly (preload cycle: `FeatureFlags` must not reference `Defs`).
- Story 5.1 (done): `watch_held` and `set_watch_held` exist on the body; `visible_now()` already reveals on `watch_held`. The body is the only writer of its reveal timers.
- Story 5.3 (done): decoys are sim objects owned by the body; `decoy_hit`, the re-cast, and the clears. Its AC 9 and the open question "Story 5.4 must keep decoys out of the Watch reveal" are answered by AC 11 here. `stun_left` and `_tick_stun` in the ASM are the pattern for "a state that locks the player".
- Story 4.1 (done): `echoing` flag. An Echo replays a remembered action and starts from Q/E-style presses, not from a live J/K press; Watch's J/K block is about live presses only, so an Echo already running finishes.

### Latest technical information

No new library or version: GDScript 2.0 on Godot 4.7, the existing `InputMap` / `Input.is_action_pressed` API. No web research needed.

## Project Context Rules

- Read-only defs at runtime; mutable state in sim objects (architecture, Story 2.5). The Watch gate and the held state are sim state written by the leaf only.
- Integer sim state; floats for presentation only (D-S33-2). The half speed scales the existing float px-per-frame top speed (presentation-safe; the sim keeps its px values as today).
- Presentation may not write sim state. `arena/` may not reference `presentation/` (the Watch overlay is loaded by path from `main.gd`, as Breakpoint's is).
- `FeatureFlags` must not reference `Defs`. Feature flags are read once at wiring, never in the sim.
- Attack scripts: no RNG, no player read. Watch touches no attack script.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

## Design calls

- **D-S54-1 (decoys stay hidden in Watch):** the GDD ("Only the real ghost hums and shows in Watch") and Story 5.3 AC 9 win over the epic's "decoys marked as decoys" line. Decoys are never drawn or read by Watch; the user's instruction (Watch must not read decoy getters) is the same rule. Open question for Tiziano: confirm before the playtest (Story 7.8).
- **D-S54-2 (held input and replay v3):** Watch is a held state, read from `InputSource.watch_held_for_frame()` each polled frame. Replays need it because Watch changes sim behaviour (speed, J/K block), so the recorder writes a `watch` array (format v3); a recording without it replays with Watch never held. The presses format is unchanged.
- **D-S54-3 (leaf and gate):** `WatchSkill` writes `SimClock.watch_gate_active` in `poll()`, the same generic-bool pattern as the Breakpoint gate. SimClock copies it to `ctx.watch_held` before the ticks. Player, ASM and the Null Pointer body read `ctx.watch_held`. With the flag off the skill is not built, so the gate never turns on.
- **D-S54-4 (unlock):** Watch is usable from Boss 2 on (`RunState.boss_index >= 1`), as the epic and GDD say ("start of Boss 2"). It reuses the Breakpoint rule's shape and is reset at every fight entry.
- **D-S54-5 (effects while held):** move speed x0.5 through the existing ramp. J/K presses are discarded while held; a running action finishes (GDD "no actions" read as "no new actions", so a combo in progress is not cut). Shifts, Q/E and Breakpoint stay usable (not actions, as D-S53-14). A stun in progress keeps its rule (5.3).
- **D-S54-6 (reveal):** while held, the real ghost is visible through the 5.1 rule. The hit flicker, the pass-through reveal and the Patched tag are unchanged.
- **D-S54-7 (next attack label):** Watch shows the attack that is being telegraphed (TELL or ACTIVE). In GAP no attack is picked yet (the pick is at GAP end, and the RNG is not drawn early), so the label reads `NEXT: ?`. No label when there is no attack (phase with an empty pool, or defeated).
- **D-S54-8 (bit label):** the bit label above the boss is the drop bit (`BossDef.drop_bit`, the bit it drops at Harvest) plus the current phase's weak window as two bit glyphs (`Register.glyph_of`). The weak window is also highlighted on the register panel while held.
- **D-S54-9 (flag-off fallback):** with `FeatureFlags.watch = false` the ghost flickers visible for 20 frames every 120 live ticks (2 s), counted in live ticks, paused in ROAR and DEFEATED, reset on fight entry. The fallback is injected by Arena (the boss reads no flag). Decoys still never hum.
- **D-S54-10 (no Watch in attacks):** Watch changes no attack timing, no RNG order and no damage. A Watch-held replay reproduces the same fight only with the v3 `watch` array (D-S54-2).
- **D-S54-11 (state reset):** fight entry, retry, debug jump and leaving FIGHT clear the held state and the gate, and emit `watch_ended` once if it was held. A held R at fight entry does not carry into the fight (the held state is re-read from the next poll).

## Open questions (not blocking)

- D-S54-1: the epic's "decoys marked as decoys" revealed in Watch vs the GDD / 5.3 "never shown in Watch". Shipped as hidden (GDD). Confirm with Tiziano.
- D-S54-5: "no actions" read as no new J/K starts while held. If the playtest wants a running combo cut too, that is a one-line change in `ActionStateMachine.tick`.
- D-S54-7: "the next attack's name" during GAP is `NEXT: ?`. A preview of the next pick would need the RNG drawn early, which changes the sequence, so it is not done here.

## References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.4: Watch Skill]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Skills, #Boss 2 — Null Pointer, #Out of Scope (cut ladder #2)]
- [Source: _bmad-output/game-architecture.md#AD-01 (SimClock gates), AD-05 (presentation reads only), AD-12 (FeatureFlags, leaf modules)]
- [Source: _bmad-output/implementation-artifacts/4-3-breakpoint-skill.md] (leaf pattern, FeatureFlags, flag-off run, D-S43-1 / D-S43-2 / D-S43-11)
- [Source: _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md] (watch_held hook, visibility, D-S51-7 / D-S51-8)
- [Source: _bmad-output/implementation-artifacts/5-3-dangling-pointers-and-nullpointerexception.md] (decoys, AC 9, D-S53-9 / D-S53-14)
- [Source: _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md#Review Findings] (`reset_for_fight` clears `watch_held` while the key may still be held: owned by 5.4, D-S54-11)

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (gds-create-story, unattended)

### Debug Log References

- Full GUT run (flag on): 1262/1262 passing (1265 after review patches). First run after the code change showed 4 expected failures in existing tests (format v2 asserts, the Breakpoint flag-off "no FightSkill registered" check now seeing the Watch skill, and the 5.1 Watch test whose tick now copies ctx.watch_held); updated as listed below.
- Flag-off run (`feature_flags.tres` `watch = false`, restored after, `git status` clean on data/): only `test_feature_flags.test_shipped_flags_are_all_on_and_valid` fails, as expected for a flag-off run (same as the 4.3 run). `test_null_pointer_fight` failed first because its visibility assert did not know the fallback flicker; the assert now includes `fallback_visible()`.
- `game/tools/check_guards.sh`: OK. Headless `--import`: no SCRIPT ERROR / Parse Error.

### Completion Notes List

- Implemented by gds-dev-story (claude-opus-5-5, unattended, coordinator-delegated). All 6 tasks done; ACs 1-26 covered by the six new test files plus the updated existing ones.
- Coordinator confirmed the open questions: D-S54-1 (decoys stay hidden in Watch) and D-S54-5 (Watch blocks new J/K starts only; a running action / combo finishes) shipped as written.
- Input / replay: `InputSource.watch_held_for_frame()`; SimClock reads it into `ctx.watch_input` each polled frame, records it, runs the poll hooks, then copies `watch_gate_active` into `ctx.watch_held`. Recorder format v3 adds a `watch` bool array; ReplayInput keeps loading v1 / v2 (no `watch` = never held); a non-array or non-bool entry is a Log.error data error, never a crash (same policy as `moves`).
- Leaf: `src/skills/watch/watch_skill.gd` (TIMERS phase, all logic in `poll`) and `watch_overlay.gd`, built by path from Arena / Main only when `FeatureFlags.watch` is on; `check_guards.sh` and `test_watch_wiring.gd` pin the leaf rule. EventBus `watch_started` / `watch_ended`.
- Core effects read only `ctx.watch_held`: Player halves `v_max` (target and ramp step), ASM `_tick_watch` after the stun check discards J/K presses, lets a running action run its frames (link still ages / opens), reports WATCHING when idle. NullPointerBody copies `ctx.watch_held` on each live tick; `watch_fallback` (injected by Arena as `not watch_enabled`) drives the 20-of-120 flicker, paused in ROAR / DEFEATED, reset per fight.
- Read-outs: WatchOverlay draws `NEXT: <attack id>` / `NEXT: ?` and `drop X  weak A B` above the boss while held; RegisterPanel frames the byte-row cells of the current weak window bits while held (Callable source injected by Main). BossView unchanged; no decoy getter read anywhere in the Watch path.
- [design call] D-S54-12: `watch_unlocked_for(boss_index)` lives in `main.gd` next to `breakpoint_unlocked_for` (same pure rule, boss_index >= 1), passed to `Arena.enter_fight` as a new trailing `watch_unlocked` parameter (default false).
- [design call] D-S54-13: while held, the ASM skips the resolver entirely (not only the J/K presses), so a K held in the combo link from before Watch does not fire as a link follow-up during Watch; it may still fire after release within its normal lifetime. A J/K press during a running action under Watch is dropped (no chain hit, no cancel).
- [design call] D-S54-14: the next-attack label reads `NEXT: ?` in every live non-TELL/ACTIVE state of a phase with attacks (GAP, RECOVERY, ROAR), `""` for an empty pool or DEFEATED. The label uses the AttackDef `id` (AttackDef has no display name field).
- [design call] D-S54-15: the ghost's Watch reveal follows the body's live ticks (it copies `ctx.watch_held` in `_tick_body`), so during Breakpoint freeze / hit-stop the reveal state is frozen with the rest of the body; the overlay read-outs and HUD marks follow the skill's poll and update even while frozen.
- [design call] D-S54-16: the fallback cycle starts hidden at fight entry; the first 20-frame flash is on live ticks 100-119 of each 120-tick cycle.
- [design call] D-S54-17: the HUD mark is a 1-px INK frame around each byte-row cell holding a weak-window bit (INK/BG only); a weak bit the player does not own is not marked.
- Existing tests adapted: `test_input_recorder` (version 3), `test_breakpoint_wiring` (flag-off check now looks for the Breakpoint script only), `test_null_pointer_body.test_watch_held_is_visible` (sets `ctx.watch_held` for the tick), `test_null_pointer_fight` (visibility assert includes the flag-off flicker).
- Spec note: the story's "Files to touch" lists `game/tools/check_guards.sh`; edited there (the file is `game/tools/check_guards.sh`, not repo-root `tools/`). `src/skills/watch/.gitkeep` removed.

- Story created (ready-for-dev) by gds-create-story, unattended. Design calls D-S54-1 to D-S54-11 are recorded above; the implementer may change them and must note changes here.
- No new library or version is introduced: the work is GDScript on the existing framework, so no web research was run.

### File List

- game/src/input/input_source.gd
- game/src/input/live_input.gd
- game/src/input/replay_input.gd
- game/src/debug/input_recorder.gd
- game/src/core/sim_context.gd
- game/src/autoloads/sim_clock.gd
- game/src/autoloads/event_bus.gd
- game/src/arena/arena.gd
- game/src/main/main.gd
- game/src/player/player.gd
- game/src/player/action_state_machine.gd
- game/src/bosses/null_pointer/null_pointer_body.gd
- game/src/ui/hud/register_panel.gd
- game/src/skills/watch/watch_skill.gd (new)
- game/src/skills/watch/watch_skill.gd.uid (new)
- game/src/skills/watch/watch_overlay.gd (new)
- game/src/skills/watch/watch_overlay.gd.uid (new)
- game/src/skills/watch/.gitkeep (deleted)
- game/tools/check_guards.sh
- game/tests/unit/test_watch_skill.gd (+ .uid, new)
- game/tests/unit/test_watch_effects.gd (+ .uid, new)
- game/tests/unit/test_watch_fallback.gd (+ .uid, new)
- game/tests/unit/test_watch_readouts.gd (+ .uid, new)
- game/tests/unit/test_watch_wiring.gd (+ .uid, new)
- game/tests/unit/test_replay_watch.gd (+ .uid, new)
- game/tests/unit/test_input_recorder.gd
- game/tests/unit/test_breakpoint_wiring.gd
- game/tests/unit/test_null_pointer_body.gd
- game/tests/integration/test_null_pointer_fight.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/5-4-watch-skill.md

### Review Findings

Code review (gds-code-review, 2026-11-11; Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel): 0 decision_needed, 3 patch (fixed), 6 defer, rest dismissed.

- [x] [Review][Patch] J/K pressed under Watch in a hit-stop or Breakpoint-frozen frame stayed buffered and fired after R was released (AC 5) [game/src/autoloads/sim_clock.gd:tick] — fixed: presses are dropped at poll time while the gate is held and the world does not tick; test in test_watch_skill.gd
- [x] [Review][Patch] Watch gate / ctx.watch_held / ctx.watch_input leaked across `SimClock.begin_fight` (replay start) [game/src/autoloads/sim_clock.gd:begin_fight] — fixed + test
- [x] [Review][Patch] Replay `watch` array length not checked against `frames` (silent desync on a truncated v3 file) [game/src/input/replay_input.gd:from_data] — now Log.warn on mismatch (v1/v2 with no `watch` key unchanged)
- [x] [Review][Patch] D-S54-13 had no test: a K held in the combo link before R can never outlive its link window (the link still ages under Watch and closes with the held press) [game/tests/unit/test_watch_effects.gd] — test added; no code change needed
- [x] [Review][Defer] Pause leaves the Watch gate and overlay held until the first poll after resume [game/src/autoloads/sim_clock.gd] — deferred, cosmetic
- [x] [Review][Defer] A dash carried out of Watch can exceed half top speed for about accel_frames; halved speed also halves the decel step [game/src/player/player.gd] — deferred, tune in playtest
- [x] [Review][Defer] Ghost reveal does not update during hit-stop or Breakpoint freeze (design call, body ticks only) [game/src/bosses/null_pointer/null_pointer_body.gd] — deferred
- [x] [Review][Defer] HUD weak-window marks skip bits the player does not own; next-attack line shows the raw attack id [game/src/ui/hud/register_panel.gd, game/src/skills/watch/watch_overlay.gd] — deferred, design calls D-S54-14 / D-S54-17
- [x] [Review][Defer] `set_watch_enabled(true)` mid-fight leaves the skill out of the fight until the next enter_fight (tests / debug only) [game/src/arena/arena.gd] — deferred
- [x] [Review][Defer] Source-grep guard tests (`contains("watch")`) are fragile against harmless edits [game/tests/unit/test_watch_effects.gd, test_watch_readouts.gd] — deferred

### Change Log

- 2026-11-11: Code review of Story 5.4: 3 patches applied plus a D-S54-13 test; 6 deferred. Status -> done. Full GUT 1265/1265, check_guards OK, import clean.
- 2026-11-11: Story 5.4 implemented (Watch skill leaf module, held input and replay v3, half speed and J/K block, ghost reveal, read-outs and HUD weak-window marks, flag-off flicker fallback, guards and tests). Status -> review.

