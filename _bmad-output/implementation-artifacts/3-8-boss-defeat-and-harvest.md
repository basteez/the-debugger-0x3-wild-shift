---
baseline_commit: a1b68e2
---
# Story 3.8: Boss Defeat and Harvest

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S38-n); the implementer follows them or records a change in Completion Notes. Scope: the defeat sequence (hit-stop, reassembly, squeak, boss_defeated), the flow route after a defeat (Harvest for Fights 1-2, Ending for Fight 3, no Harvest), the real HARVEST screen replacing the 1.6 placeholder, the LOOP bit (`bit_loop.tres`), the register insertion, the shared harvest duck line, the F8 debug grant, and the deferred items that name 3.8. NOT in scope: Echo behaviour (4.1), the Null Pointer and Segfault bodies (Epics 5-6), the Ending content (6.8), save/resume of the highest boss (7.3). -->

## Story

As a player,
I want the defeated bug to collapse into its fixed code and drop a new bit,
So that every victory visibly upgrades my weapon.

**Requirements:** FR8 (insertion), FR29 (defeat), FR45 (line 8), FR50. Also FR49 (retry after a Harvest keeps the full-HP reset), FR52 (run sequence), D-049 (b) (full HP and cooldowns reset on every FIGHT entry).

## Acceptance Criteria

1. **Given** boss HP reaches 0
   **When** the boss is defeated
   **Then** 20 frames of hit-stop, the glyphs reassemble into the fixed line `for (i = 0; i < n; i++) { }`, the duck squeaks and `EventBus.boss_defeated` is emitted
   *(Epic AC, verbatim intent. Sim side: `BossController._defeat()` requests `SimClock.request_hitstop(20)` and emits `boss_defeated(&"infinite_loop")` exactly once. Presentation side: the squeak plays on the `boss_defeated` listener via `AudioManager.play_squeak()`.)*

2. **Given** the defeat animation ends (D-S38-1: `DEFEAT_FRAMES` = 60 world ticks after the hit-stop)
   **When** `Game` enters HARVEST (Fights 1 and 2 only, D-S38-2)
   **Then** `data/bits/bit_loop.tres` exists (glyph `L`, `solo_action` = the NOP action, D-S38-6), the LOOP bit flies into the register (presentation), the Harvest screen shows the register with `L` appended, the next fight's register is the Fight 2 fight-start `[A, D, L]` (`0x07`), and the shared harvest line `Bug squashed. It dropped a bit: new windows, new combos.` plays
   *(Epic AC. The next FIGHT already takes `Register.fight_start_for_boss(1)` = `[A, D, L]`; this AC must be proven by test, not assumed.)*

3. **Given** the HARVEST screen is open
   **When** time passes
   **Then** it lasts at most 8 s (480 sim frames, D-S38-10) and any non-modifier key press or left click after 2 s (120 sim frames) ends it early; either way the next fight (Fight `boss_index + 1`) starts with full player HP and all cooldowns reset (D-049 b, D-S38-10)
   *(Epic AC plus the end condition.)*

4. **Given** a debug build
   **When** I press F8 during a fight that has a drop bit whose `BitDef` exists (Fight 1 today)
   **Then** the defeat is granted without a fight: the bit is inserted and the flow goes to HARVEST as if the boss had been defeated (D-S38-7), and the Fight 2 loadout is `[A, D, L]`
   **And** F8 in release builds does nothing (no debug node is instanced) and F8 in any other state logs a `Log.warn` and does nothing
   *(Epic AC, interpreted per D-S38-7: "the next bit whose BitDef exists is granted". NULL has no BitDef until Epic 5, so F8 is a no-op on Fight 2 in this story.)*

5. **Given** the boss is defeated in Fight 1 (`boss_index` 0)
   **When** the defeat animation ends
   **Then** the flow goes FIGHT → HARVEST (`Game.finish_defeat()`), the Harvest screen replaces the 1.6 placeholder for HARVEST only, and no placeholder text remains reachable for HARVEST

6. **Given** the boss is defeated in Fight 3 (`boss_index` == `LAST_BOSS_INDEX`, 2)
   **When** the defeat animation ends
   **Then** the flow goes FIGHT → ENDING with no Harvest screen and no bit (the Segfault drops nothing, GDD D-012), and the ENDING placeholder shows (6.8 replaces it)
   *(Routing only. Null Pointer, the Fight 2 boss, is Epic 5 and uses the same HARVEST path with its own drop.)*

7. **Given** the defeated boss is still on screen during the defeat animation
   **When** a frame is drawn
   **Then** the header reads `void infiniteLoop() // hp 0` (D-S31-14), the ring glyphs move to the fixed line cells over `DEFEAT_FRAMES` (D-S38-9), the `;` stays closed and no damage can land (`is_hittable()` false, as today)
   **And** the player is still live during the animation: a lethal hit in that window is a normal death (D-S38-3)

8. **Given** the simulation state changes in this story
   **When** a replay of a fight that ends in defeat is run twice with the same seed and inputs
   **Then** the per-tick state hash and the `boss_defeated` tick are identical, and the defeat counter is an integer frame counter in sim state only; presentation never writes it (AD-05, D-S38-8)

9. **Given** a defeat or a Harvest exit that happens while a duck line is speaking (3.6 / 3.7 deferred seam)
   **When** the flow leaves FIGHT
   **Then** the duck bubble clears and `VoiceService.stop()` is called on the flow exit, so no line of the old fight finishes into HARVEST (D-S38-11)

10. **Given** a flow change caused by a defeat
    **When** it happens
    **Then** it is requested from presentation after the tick (never from inside `SimClock.tick()`), so the death-in-tick issue from Story 2.9 is not repeated (D-S38-11)

11. **Given** the tests and checks listed in Task G
    **When** `gut` runs headless
    **Then** all existing suites pass, with the F6 and advance tests updated where they encoded the pre-3.8 "no flow change until 3.8" behaviour (see Dev Notes)

## Tasks / Subtasks

### Group A: Defeat sequence in the simulation (AC 1, 7, 8, 10)

- [x] A1. `BossController`: add `const DEFEAT_FRAMES := 60` (D-S38-1) and `var defeat_frames_elapsed: int = 0`. Reset in `reset_for_fight`. Count it up once per world tick while `state == DEFEATED`, even though `active` is false (the body and framework gate on `active`, so the counter must not depend on it). Clamp at `DEFEAT_FRAMES`.
- [x] A2. `_defeat()`: call `SimClock.request_hitstop(20)` (`DEFEAT_HITSTOP_FRAMES`, D-S38-1). Keep the existing single emission of `boss_defeated(def.boss_id)`.
- [x] A3. Add `func defeat_finished() -> bool` (state DEFEATED and `defeat_frames_elapsed >= DEFEAT_FRAMES`). Pure read, used by presentation.
- [x] A4. Add the counter to the hashed/replayed state if the boss state is already hashed (grep the replay hash for `state`, `hp`, `phase_index`); otherwise state why not in the Completion Notes.
- [x] A5. `BossController.take_hit` and the damage path: confirm hits after DEFEATED are ignored (deferred 3.1 item: a hit at hp 0 before `reset_for_fight` must not re-emit). Add a guard and a test if it is missing.

### Group B: Flow routing and the debug grant (AC 2-6, 10)

- [x] B1. `Game.finish_defeat() -> bool`: valid only from FIGHT, only when `arena.boss` is DEFEATED and `defeat_finished()`. Routes: `boss_index < LAST_BOSS_INDEX` → HARVEST, else ENDING (D-S38-2). Called from presentation (B4), never from the tick.
- [x] B2. `Game.finish_harvest(frame)`: valid only from HARVEST; `run.start_boss(boss_index + 1)` then FIGHT. Skip rule (`frame - harvest_start_frame >= 120`) is checked by the screen before calling; the method itself checks nothing extra. Keep `advance()` for tests and for boss-less fights (D-S38-14).
- [x] B3. `Game`: record `harvest_start_frame` on HARVEST entry (sim frame, `SimClock.sim_frame`). Reset in `_set_flow_state` when leaving HARVEST. Add `const HARVEST_MAX_FRAMES := 480` and `const HARVEST_SKIP_FRAMES := 120`. The HARVEST cap is enforced by the screen (like INTRO's cap) using `Game.harvest_timed_out(frame)`, a pure check.
- [x] B4. Presentation trigger: `Main._process` (or a small listener under Main, the JuiceDirector pattern) polls `arena.boss`; when `Game.flow_state == FIGHT` and `finish_defeat` is valid, call it. No new EventBus signal (architecture: adding one is an architecture change). Use `boss_defeated` only for the squeak and the header.
- [x] B5. `Game.debug_grant_bit() -> bool` (Debug-gated, D-S38-7): from FIGHT with a live or dead current boss whose `drop_bit` has a `BitDef` (`Defs.bit(drop_bit) != null`) and the bit not already owned in the run: emit the same routing as B1 without the animation (HARVEST or ENDING). Otherwise `Log.warn(&"debug", ...)` and return false.
- [x] B6. `DebugKeys`: F8 (no modifiers) → `Game.debug_grant_bit()`. Add it to the key table and to the `handle_key` path, honouring the existing rule that debug keys do nothing outside `Debug.enabled`.
- [x] B7. `RunState`: no new persisted field is required. Confirm `start_boss` resets `deaths_on_boss` on the Harvest→Fight path (it does; add a test). Do NOT store the harvested bit in `RunState` yet; the next FIGHT takes `Register.fight_start_for_boss(boss_index)` (D-S38-5).

### Group C: Bit data and the register (AC 2)

- [x] C1. `data/actions/nop.tres` (`ActionDef`, id `nop`): zero damage, no hit shape, startup 0, active 1, recovery 0, cooldown 0, hitstop 0 (check `ActionDef.validate()` for required fields first; if `hit_shape` is required, use the smallest valid shape and say so in the notes). Document in its header that Story 4.1 replaces it on `bit_loop.tres`.
- [x] C2. `data/bits/bit_loop.tres` (`BitDef`): `id = Register.Bit.LOOP` (3), `glyph = "L"`, `solo_action = nop.tres`.
- [x] C3. `Defs`: add `const BIT_LOOP: BitDef = preload("res://data/bits/bit_loop.tres")` and `Register.Bit.LOOP` to `Defs.bit()`. Check `Defs.solo_action(LOOP)` returns the NOP action (so `ActionResolver` now starts a no-op rather than returning null; confirm no regression for `[D, A]` Fight 1).
- [x] C4. `Register`: no change to `insert()`. Harvest calls it on a **copy** (a fresh `Register` built from `run.fight_start_ring`), never on the arena's register (single-writer rule, D-S38-5). Resolve the deferred 2.3 item "Register.insert vs buffered shifts ordering": with the register inactive outside FIGHT and `begin_fight` clearing the buffer, the ordering is defined; write this into the Completion Notes.

### Group D: Presentation of the defeat (AC 1, 7, 9)

- [x] D1. `BossView` (or the ring draw path): during DEFEATED, draw the 24 ring segments moving from their last positions to the fixed line cells over `DEFEAT_FRAMES`. Progress = `defeat_frames_elapsed / DEFEAT_FRAMES`; segment k goes to cell k of `fixed_line` (27 cells; the 3 extra cells fade in) (D-S38-9). Hit-stop freezes the sim, so the presentation uses sim-frame progress, not wall time.
- [x] D2. Squeak: a presentation listener on `EventBus.boss_defeated` calls `AudioManager.play_squeak()` once. Test that a second emission does not play twice.
- [x] D3. Header: keep `hp 0` through the animation (D-S31-14). The header is hidden once HARVEST is entered (D-S38-13).
- [x] D4. Glyph check: the fixed line uses `(`, `)`, `{`, `}`, `;`, `<`, `+`, `=`, `i`, `n`. Confirm each is in `GlyphFont` (test_font_coverage). Any missing glyph → add it to the font or flag it; do not substitute silently.

### Group E: HARVEST screen (AC 2, 3, 5)

- [x] E1. New `src/ui/screens/harvest/harvest_screen.gd` (+ `.tscn` if the project uses scenes for screens; match `dead_screen.gd`). Presentation only: it reads `Game`, `Defs`, `run.fight_start_ring` and calls `Game.finish_harvest` / `Game.harvest_timed_out`. It never writes flow state or the arena.
- [x] E2. Layout (on the 8-px grid, 640×360 base): the fixed line of the defeated bug (its `fixed_line` text) reassembled at the top; the register row below with the new bit appended (`[A, D, L]`), the byte value `0x07` and the new active windows (`window + combo name` from `Defs.COMBOS`); a prompt line `press any key` after 2 s. Animation: the bit glyph flies from the boss position to its slot over `BIT_FLIGHT_FRAMES` = 30 (D-S38-9).
- [x] E3. `Main._make_screen`: HARVEST → `HarvestScreen`; ENDING and INTRO/FIGHT unchanged; the `PlaceholderScreen` HARVEST branch in `lines_for` is removed (the placeholder keeps INTRO, FIGHT and ENDING only).
- [x] E4. Duck line: on HARVEST entry, request the shared line through `VoiceService.say(&"harvest_shared")` (the 3.6 path, D-S38-8). Add the entry `harvest_shared` (text `Bug squashed. It dropped a bit: new windows, new combos.`) to `data/duck/duck_lines.tres`, ASCII only (`DuckLineDef.is_ascii`), within the duck bubble width. The duck line budget stays at 10 (GDD D-039).
- [x] E5. On leaving HARVEST (`finish_harvest` or skip), call `VoiceService.stop()` and clear the bubble (the 3.6/3.7 deferred seam, D-S38-11).
- [x] E6. `Main.apply_flow_state`: the arena and the in-fight HUD stay hidden in HARVEST (`in_fight` logic unchanged); the HarvestScreen draws its own register row, so the HUD is not rewired (D-S38-5).

### Group F: Fight start after Harvest (AC 3)

- [x] F1. Confirm `Arena.enter_fight` gives full player HP and resets all cooldowns on every FIGHT entry, including the one after Harvest (D-049 b). If cooldowns are not reset on a non-retry entry, fix it here and add a test.
- [x] F2. Confirm the fight-start snapshot for Fight 2 is `[A, D, L]` (test: `Game.run.fight_start_ring` after the Harvest → FIGHT path equals `fight_start_for_boss(1)`).

### Group G: Tests (AC 8, 11)

- [x] G1. `tests/unit/test_boss_controller.gd`: defeat emits `boss_defeated` once; hit-stop 20 requested; `defeat_frames_elapsed` reaches 60 and `defeat_finished()` flips exactly then; a hit after DEFEATED changes nothing.
- [x] G2. `tests/unit/test_game_flow.gd`: `finish_defeat` routes Fight 1 → HARVEST, Fight 3 → ENDING with no HARVEST; `finish_harvest` → FIGHT 2 with `boss_index` 1 and `deaths_on_boss` 0; the advance-based flow test (`advance()` FIGHT → HARVEST) is kept only for boss-less fights and renamed to say so.
- [x] G3. `tests/unit/test_debug_keys.gd`: the F6 test that asserted "no flow change until 3.8" is updated: F6 now routes through the defeat path. F8 grants LOOP in debug; F8 is a no-op in release (Debug gate off) and outside FIGHT.
- [x] G4. `tests/unit/test_data_validation.gd`: `bit_loop.tres` and `nop.tres` validate; `Defs.bit(Register.Bit.LOOP)` is non-null; `Defs.solo_action(LOOP)` is the NOP action.
- [x] G5. `tests/unit/test_register.gd` (or a new `test_harvest.gd`): inserting LOOP into `[A, D]` gives `[A, D, L]`, byte `0x07`; inserting into a full ring or a duplicate is rejected with the existing `Log.error` path.
- [x] G6. `tests/integration/test_retry_snapshot.gd` or a new `test_harvest_flow.gd`: defeat → Harvest → Fight 2 start: HP full, cooldowns reset, `fight_start_ring` `[A, D, L]`, `run_seed` kept, `fight_attempt` incremented once per FIGHT entry.
- [x] G7. Replay: a recording of a fight that ends in defeat replays bit-identically (hash per tick and the defeat tick). Add it to `tests/replays/` following the existing recording format; if the recording must be made by hand in the editor, record it as a human check and keep the test on a synthetic input list.
- [x] G8. Isolation: the existing `test_duck_isolation` / `test_attack_isolation` rules still hold; presentation files (`harvest_screen.gd`, `BossView`) do not write sim state (grep test).
- [x] G9. Run the full GUT suite headless and the existing CI (`tests/`) and record the counts in the Completion Notes.

### Group H: Human checks (not gates for this story)

- [ ] H1. Play Fight 1 to defeat in the debug build: the squeak, the reassembly, the bit flight, the harvest line and the skip after 2 s feel right.
- [ ] H2. Browser check on the direct `?debug` URL (see deferred-work.md "itch.io deploy & browser smoke"): no console error from the Harvest path other than the pre-existing warning items.

## Dev Notes

### Decisions taken for this story (D-S38-n)

- **[design call] D-S38-1 Defeat timing.** 20 frames of hit-stop (epic, `request_hitstop`), then `DEFEAT_FRAMES` = 60 world ticks of reassembly counted on the boss (sim state, integer). Hit-stop gates the tick, so `sim_frame` does not advance during it; the animation therefore pauses with the fight.
- **[design call] D-S38-2 Routing.** Fight 1 and Fight 2 defeats go to HARVEST. Fight 3 (Segfault, drops nothing, GDD D-012) goes straight to ENDING with no Harvest. The epics (Story 6.4 AC) already say "Game goes to ENDING (no Harvest)" for the last boss.
- **[design call] D-S38-3 Player live during the defeat window.** Player movement and attacks are not locked; a lethal hit in the 60-tick window is a normal death (DEAD, retry from the fight-start snapshot). Rationale: no new input-lock state; the window is one second. Revisit only if playtest 3.9 shows accidental deaths.
- **[design call] D-S38-4 HARVEST is not pausable.** `PAUSABLE_STATES` stays `[INTRO, FIGHT]`. HARVEST is at most 8 s; its timers use `sim_frame`, so they stop only if the sim is paused, which HARVEST never is.
- **[design call] D-S38-5 Register.** The next fight's register is `Register.fight_start_for_boss(boss_index)` (already `[A, D, L]` for Fight 2), so the harvested bit does not need to be stored. The Harvest screen builds a **copy** of the register with `insert(LOOP)` for display. The arena's register is never written outside FIGHT (single-writer rule). The Harvest screen draws its own register row; the in-fight HUD is not rewired. The HUD shows the new windows from the next FIGHT.
- **[design call] D-S38-6 LOOP solo action.** `bit_loop.tres` points at a NOP `ActionDef` (`data/actions/nop.tres`) as the epic says. It is a zero-effect 1-frame action so pressing `L` in Fight 2 does nothing visible; Story 4.1 replaces it with Echo. NOP is never stored as "last action" for Echo (Epic 4 rule).
- **[design call] D-S38-7 F8 = debug defeat-without-fight.** The epic's "next bit whose BitDef exists is granted without a fight" is implemented as: F8 in FIGHT for a boss whose `drop_bit` has a BitDef routes exactly like a finished defeat (HARVEST or ENDING), skipping the animation. Only LOOP qualifies in this story; NULL gets its BitDef in Epic 5 and then F8 grants it on Fight 2.
- **[design call] D-S38-8 No new signals.** The sim keeps emitting only `boss_defeated` (already declared, architecture I-2). Presentation polls `arena.boss` for `defeat_finished()` and calls `Game.finish_defeat()`. Adding a signal would be an architecture-level change.
- **[design call] D-S38-9 Reassembly and flight visuals.** Ring segment k moves to fixed-line cell k over 60 ticks; the three extra cells (27 vs 24) fade in. The LOOP glyph flies from the defeat point to its register slot over `BIT_FLIGHT_FRAMES` = 30 presentation frames of the HARVEST screen. Presentation-only; no hashed state.
- **[design call] D-S38-10 Harvest timing.** `HARVEST_MAX_FRAMES` = 480 (8 s cap, sim frames). Skip from `HARVEST_SKIP_FRAMES` = 120 (2 s) on any non-modifier key or left click, the same rule as the placeholder (`PlaceholderScreen.is_advance`). The skip never needs the duck line to finish.
- **[design call] D-S38-11 Flow changes out of the tick and voice cut.** Flow changes from a defeat are requested by presentation after the tick (the Story 2.9 deferred item about death inside `tick()` is not repeated for defeat). Every flow exit from FIGHT or HARVEST clears the duck bubble and calls `VoiceService.stop()` (the 3.6/3.7 deferred seam).
- **[design call] D-S38-12 Squeak.** The defeat squeak (AC 1) is `AudioManager.play_squeak()` on `boss_defeated`. The duck bubble also squeaks when the harvest line opens, so two squeaks land about 1 s apart. Accepted; revisit with the ear check in 7.2.
- **[design call] D-S38-13 Header.** The boss header reads `hp 0` during the defeat animation and is not drawn on HARVEST. The next FIGHT shows the placeholder header until Boss 2 has a body (Epic 5).
- **[design call] D-S38-14 advance().** `Game.advance()` keeps its FIGHT → HARVEST/ENDING branch only for fights with no boss body (Fight 2 and 3 in Epic 3). Real defeats use `finish_defeat`. Tests keep using `advance()` for placeholder navigation and say so.
- **[design call] D-S38-15 Fights 2 and 3 are placeholders in Epic 3.** There is no Null Pointer or Segfault body yet, so the placeholder Fight 2 can only be left through debug keys (F1-F5, F8 is a no-op there). This is expected, not a bug, until Epics 5 and 6.

### Architecture and rules that bind this story

- **Single flow writer:** only `Game` changes `flow_state`; presentation calls `Game.finish_defeat`, `Game.finish_harvest`, `Game.debug_grant_bit`.
- **Sim → presentation one way:** `src/ui`, `src/presentation`, audio and voice never write sim state; the HarvestScreen reads `run` and `Defs` only.
- **Integer frames:** all new timers are integer frame counters; no `delta`, `Timer`, `await` in sim folders (consistency rule, grep check in CI).
- **Hit-stop is sim state:** only `SimClock.request_hitstop` (via `BossController._defeat`); presentation never requests hit-stop.
- **Defs are read-only at runtime:** `bit_loop.tres` and `nop.tres` are data; no runtime mutation of `BitDef`.
- **Randomness:** none added. The fight seed is taken on FIGHT entry as before (`_begin_fight`), so the Harvest → Fight 2 seed is `fight_seed_for(run_seed, fight_attempt)` with the attempt count incremented once.
- **Cuttable features:** nothing in this story is behind a FeatureFlag. LOOP's BitDef is needed by the Epic 4 cut ladder only through `Echo`, not here.

### Existing code this story touches (read before editing)

- `game/src/autoloads/game.gd`: `FlowState`, `LAST_BOSS_INDEX` = 2, `advance()` (FIGHT branch), `_set_flow_state` (FIGHT captures `fight_start_ring` from `Register.fight_start_for_boss`), `_begin_fight` (seed), `boss_id()`, `PAUSABLE_STATES`.
- `game/src/core/run_state.gd`: `start_boss` resets `deaths_on_boss`; `fight_start_ring` snapshot; `fight_seed_for`.
- `game/src/bosses/framework/boss_controller.gd`: `_defeat()` (no hit-stop yet; emits `boss_defeated` once via `_defeat_emitted`), `is_hittable()`, DEFEATED state handling in `tick` and `take_hit`.
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`: already stops on DEFEATED (ring frozen, contact off, `;` closed, D-S33-17).
- `game/src/presentation/boss_view.gd`: `_draw_ring` already has the DEFEATED branch (no jitter, no flash, `;` closed); reassembly goes here.
- `game/src/ui/hud/hud.gd`: `_on_boss_defeated` redraws the frame; header from `top_bar_text()`.
- `game/src/main/main.gd`: `apply_flow_state` (HUD and arena visible only in FIGHT), `_make_screen` (HARVEST currently uses PlaceholderScreen).
- `game/src/ui/screens/placeholder/placeholder_screen.gd`: `lines_for` has a HARVEST branch to remove; `is_advance` is reused by the Harvest screen.
- `game/src/register/register.gd`: `insert(bit)` (appends, rejects unknown/duplicate/full), `fight_start_for_boss`, `byte_value()`.
- `game/src/register/bit_def.gd`, `game/src/core/defs.gd`: `Defs.bit(id)` returns null for LOOP today; `Defs.solo_action` returns null → `ActionResolver._solo` returns null, so pressing L currently does nothing (the NOP action makes it explicit).
- `game/src/debug/debug_keys.gd`: F6 (`debug_boss_kill`, currently no flow change), Ctrl+F6, Shift+F6, F1-F5, F9-F11. F8 is free.
- `game/src/ui/duck/duck_director.gd`: Infinite Loop beats T1-T4 only; `due_beat` returns -1 for any other boss id, so it does not fire on Harvest.
- `game/src/ui/duck/duck_bubble.gd`: `_on_flow_state_changed` clears on flow change (check that it runs on HARVEST entry); `AudioManager.play_squeak()` on each line open.
- `game/data/duck/duck_lines.tres`: 4 entries (T1-T4); add `harvest_shared`.
- `game/data/bosses/infinite_loop/boss_def.tres`: `drop_bit = 3` (LOOP), `fixed_line = "for (i = 0; i < n; i++) { }"`, HP 400.
- `game/src/autoloads/sim_clock.gd`: `sim_frame` counts world ticks only (not hit-stop or paused frames); `request_hitstop` takes the max per tick; `begin_fight` clears the buffer and hit-stop.
- `game/src/arena/arena.gd`: `enter_fight` (player reset, register set via `set_fight_start`, `leave_fight` deactivates everything).

### Deferred items folded into this story

From `_bmad-output/implementation-artifacts/deferred-work.md`:
- **3.1 / 3.3 (D-S31-19, D-S33-17, D-S31-14):** "Defeat leaves the ring stopped with no exit from FIGHT until Harvest/flow (3.8)"; "Game does not react until Harvest (3.8)"; header `hp 0` until Harvest decides. Resolved by AC 1-7 and D-S38-13.
- **3.1 (F6):** "boss_defeated, no flow change until 3.8". Resolved: F6 now goes through the defeat path (G3).
- **3.4 (D-S34-15):** "Defeat leaves the ring stopped (3.3 D-S33-17)". Resolved by the reassembly (D1).
- **2.3:** "`Register.insert` vs buffered shifts ordering in the same tick is undefined (harvest, Story 3.8)". Resolved by C4: insertion is on a copy outside FIGHT; `begin_fight` clears the buffer.
- **2.9:** "Death transition runs synchronously mid-tick ... consider deferring death to end of tick". Not fixed in general; defeat transitions are deferred by design (D-S38-11). The death path is unchanged.
- **3.6 / 3.7 voice seam:** "call `VoiceService.stop()` on `clear()`/flow exit". Resolved by E5 and AC 9.
- **3.6:** "Harvest and ending lines (3.8, 6.8)". Resolved for the harvest line by E4; the ending line stays with 6.8.
- **3.9 (not this story):** spit consumption, beat ordering and the `;` window truncation remain for the MVP playtest.

From the Epic 3 review notes: the 3.3 check that a hit after defeat does not re-emit `boss_defeated` (A5) is folded in.

### Previous story intelligence (3.1-3.7, all status done)

- **3.1** (framework): `boss_defeated(boss: StringName)` keeps the id for Harvest and the 3rd-death hint. `DEFEATED` is a state with no transitions out. F6 is the debug kill.
- **3.2** (weak window, damage states): the killing blow's damage number is still drawn after defeat (`BossView` review fix); keep it on the Harvest path if the number is drawn there (not required).
- **3.3** (Infinite Loop body): at 0 HP the body is inactive (no movement, no contact, no `;`), keeps its last position, header `hp 0`. Reassembly and Harvest are explicitly 3.8.
- **3.4 / 3.5** (attacks, phases): `_cancel_attack` runs on defeat through `_defeat`; the nested-loop ring split is a `Ring`-level detail that defeat must not break (the rings freeze too).
- **3.6** (duck bubble): `DuckBubble` owns line display; `DuckDirector` is Infinite-Loop only and needs no change for Harvest. The bubble's squeak plays on every line open.
- **3.7** (duck voice): `VoiceService.say` / `stop`; a missing clip logs a single `Log.warn` and the text shows silently. A harvest line without a pre-rendered clip is expected to behave the same way; check that the pre-render list is regenerated if the backend needs it.

### Git intelligence

- Recent commits on `main` before this branch: `Fix: opaque background for the F9 frame overlay (#19)`, `Fix: FIGHT placeholder no longer advances on any key (#18)`, `Story 2.9 ...` (#17), `Story 2.8 ...` (#16), `Story 2.7 ...` (#15). The stacked branch adds 3.1-3.7 on top. Keep the same commit style (`Story 3.8: Boss defeat and Harvest`) when it is committed; this story does not commit.
- The `FIGHT placeholder no longer advances on any key` fix means the FIGHT placeholder ignores any-key input on purpose; the HARVEST screen must not regress that by advancing on FIGHT.

### Project Structure Notes

- New files: `game/src/ui/screens/harvest/harvest_screen.gd`, `game/data/actions/nop.tres`, `game/data/bits/bit_loop.tres`, tests as listed. Presentation folder rules: `src/ui/screens/` is presentation.
- No new autoload. No new EventBus signal. No new FeatureFlag.
- Naming: screen class `HarvestScreen` (`class_name`), file `harvest_screen.gd`, matching `dead_screen.gd` / `placeholder_screen.gd`.
- No conflicts with the architecture file found beyond the expected: the architecture lists `ui/screens/harvest` already (`game-architecture.md` line 471).

### Testing standards

- GUT, headless, one suite per file in `game/tests/unit/`; integration in `game/tests/integration/`; replay in `game/tests/replays/`.
- Pure static helpers for the routing (`Game.harvest_timed_out`, `route_after_defeat(boss_index)`) so they test without a scene.
- No wall-clock asserts; use `SimClock.sim_frame` or injected frame numbers.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.8: Boss Defeat and Harvest]
- [Source: _bmad-output/planning-artifacts/epics.md#FR50, FR52, FR29, FR8, FR45]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.6, Story 5.6 (NULL Harvest), Story 6.4 (Segfault defeat → ENDING, no Harvest)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Core Gameplay Loop, Win/Loss Conditions, Level Types (Harvest), Boss 1 (Infinite Loop), Economy (full HP reset)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-012, D-039, D-048, D-049]
- [Source: _bmad-output/game-architecture.md#State Management, Simulation Timing (AD-01), Scene structure (AD-08), EventBus (AD-05), Debug Tools (F8), Consistency Rules]
- [Source: _bmad-output/implementation-artifacts/3-3-infinite-loop-body-and-loop-condition.md#D-S33-17]
- [Source: _bmad-output/implementation-artifacts/3-1-reusable-boss-framework.md#D-S31-14, D-S31-15, D-S31-19]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-3.3, story-3.5, story-3.6, story-3.7]

### Human checks

- H1 and H2 above. Not gates for this story.

## Dev Agent Record

### Agent Model Used

claude opus (gds-dev-story, unattended epic pipeline)

### Debug Log References

- Baseline before changes: GUT 899/899 (69 scripts), check_guards OK.
- First full run after the code: 6 failures, all tests that encoded pre-3.8 behaviour (L had no action, 4 duck lines, HUD hidden / placeholder in HARVEST, F6 "no flow change until 3.8"). Updated.
- Flaky-looking `test_camera_shake.test_shake_settles_on_physics_frames`: the new 20-frame defeat hit-stop leaked from `test_boss_controller` through a real physics frame into the next suite (sim frames frozen). Fixed by clearing `hitstop_frames` in `test_boss_controller.after_each` and defensively in `test_camera_shake.before_each`.
- `tools/render_duck_lines.gd` (wav, import, tres) re-run to add the `harvest_shared` pre-render clip; the 4 existing wavs are byte-identical, `duck_clips.tres` only got the new entry plus regenerated sub-resource ids. The 4 `SCRIPT ERROR` lines that tool prints (EventBus not found in `-s` mode) are pre-existing and harmless.
- Final: GUT 936/936 passing, 32857 asserts, 71 scripts, "All tests passed!"; `bash game/tools/check_guards.sh` OK.
- E2E headless sanity run of the real game (temporary SceneTree driver, deleted afterwards): TITLE -> INTRO -> FIGHT 1 (Infinite Loop, ring [D, A]) -> F6 -> DEFEATED with FIGHT held and header `hp 0` -> HARVEST after hit-stop + 60 ticks (HarvestScreen rows `for (i = 0; i < n; i++) { }`, `[A, D, L] = 0x07`, `D>L  --`, `L>A  --`; `harvest_shared` line in the bubble) -> early press ignored -> skip after 2 s -> FIGHT 2 ([A, D, L], hp 5, bubble cleared) -> F2 -> F8 -> HARVEST -> 8-s cap -> FIGHT 2 -> F8 no-op (one Log.warn) -> F4 FIGHT 3. PASS, no errors in the log.

### Completion Notes List

- **A (sim defeat):** `BossController.DEFEAT_HITSTOP_FRAMES = 20`, `DEFEAT_FRAMES = 60`, `defeat_frames_elapsed` (counted in `tick()` while DEFEATED, before the `active` gate, clamped, reset in `reset_for_fight` and on `_defeat`). `_defeat()` requests the hit-stop inside the existing emit-once guard. `defeat_finished()` is a pure read. A4: the boss state is not hashed by the engine; the replay hash lives in `tests/integration/test_infinite_loop_replay.gd` and now includes `defeat_frames_elapsed` and `SimClock.hitstop_frames`. A5: `take_hit` already ignored hits after DEFEATED; added a test that a late hit neither re-emits nor restarts the animation.
- **B (flow):** `Game.route_after_defeat`, `finish_defeat(boss)` (the arena's boss is passed in: Game does not know the arena), `finish_harvest(frame)`, `harvest_start_frame` (set on every HARVEST entry, -1 otherwise), `HARVEST_MAX_FRAMES` / `HARVEST_SKIP_FRAMES`, pure `harvest_timed_out_at` / `harvest_skip_open_at` plus instance `harvest_timed_out` / `harvest_skip_open`, `debug_grant_bit(boss)`. `advance()` unchanged (placeholder navigation, D-S38-14). Main polls `poll_defeat()` in `_physics_process`, which runs after the SimClock autoload's tick in the same physics frame (never inside the tick). F8 in DebugKeys (no modifiers); release has no DebugKeys node and `Game.debug_grant_bit` also checks `Debug.enabled`. B7: `start_boss` resets `deaths_on_boss` on Harvest -> Fight (tested); nothing new in RunState.
- **C (data):** `data/actions/nop.tres` (no hit shape needed: `hit_shape` is optional in `ActionDef.validate()`), `data/bits/bit_loop.tres`, `Defs.BIT_LOOP` / `Defs.NOP`, `Defs.bit(LOOP)`. `[D, A]` Fight 1 unaffected; J/K on an `L` slot now starts the NOP action (tests that used L as the "no action" slot now use NULL_BIT). C4 (deferred 2.3 ordering): the harvest insertion happens on a fresh Register copy outside FIGHT; the arena register is inactive outside FIGHT and `enter_fight` / `begin_fight` clear the buffer, so buffered shifts and the insertion can never meet in one tick. The ordering is therefore defined.
- **D (presentation):** `BossView._draw_reassembly`: outer then inner segments lerp to fixed-line cells on sim progress (`defeat_frames_elapsed / 60`), glyphs swap to the fixed characters and the extra cells pop in at 50% (palette is INK/BG only, so no alpha fade). The line is pushed inside the play area. BossView now redraws while DEFEATED. Squeak: `AudioManager.on_boss_defeated` plays `play_squeak()` once per fight (guard reset on FIGHT entry, `defeat_squeak_count` for tests). D4: the font covers all printable ASCII; the fixed line and every Harvest row were added to `test_font_coverage`.
- **E (HARVEST screen):** `src/ui/screens/harvest/harvest_screen.gd` (script-only like `dead_screen.gd`): fixed line, register row with the bit flying over 30 frames, byte value, new windows with combo names (`--` when none), prompt after 2 s; skip via `PlaceholderScreen.is_advance` after 120 sim frames, cap at 480. The harvest line is requested deferred from `_ready` (after the bubble's flow-change clear). Placeholder HARVEST branch removed. `duck_lines.tres` has `harvest_shared` (5 lines total, budget 10).
- **E5 / AC 9:** `DuckBubble` clears when leaving FIGHT (as before) and also when leaving HARVEST; `clear()` now always calls `voice.stop()` (a no-op when nothing speaks).
- **F:** `Arena.enter_fight` already resets HP, cooldowns (`actions.reset_for_fight`) and the register on every FIGHT entry. The integration test proves it on the Harvest -> Fight 2 path. No fix needed.
- **G:** new `tests/unit/test_harvest_screen.gd`, `tests/integration/test_harvest_flow.gd`, a defeat replay in `test_infinite_loop_replay.gd`, and additions to the boss controller, game flow, debug keys, data validation, register, duck bubble, duck lines, main layers and font coverage suites. G7 uses the synthetic recorded-input pattern (record, save, replay from file). No hand-made editor recording was needed.
- **[design call] D-S38-16 HARVEST shows the HUD in duck-only mode.** The duck line needs the HUD's DuckBubble (it drives the voice), but the HUD was hidden outside FIGHT. In HARVEST, Main shows the HUD with only the bubble (frame/header, register panel, log, HP readout hidden, `Hud.set_duck_only`). The Harvest screen keeps its layout clear of the duck region.
- **[design call] D-S38-17 Harvest register row order.** Inserting L into the Fight 1 snapshot `[D, A]` gives `[D, A, L]`, but Fight 2 starts at `[A, D, L]`. The screen still does the insert on a copy, then shows the next fight's start set when it holds the same bits, so the player sees the loadout they will get, with L in the new last slot.
- **[design call] D-S38-18 F8 / finish_defeat take the boss as an argument.** Game has no arena reference, so callers pass `arena.boss`. On Fight 2 (no body) F8 logs `no boss in this fight`, which matches the D-S38-15 no-op.
- **[design call] D-S38-19 Harvest without a boss def.** When HARVEST is reached without a boss def (placeholder `advance()`), the screen shows `// bug fixed` and the bit the next start set adds (`Main.harvest_bit_for`). With the test boss (drop_bit 0) no bit flies.
- Human checks H1 (feel: squeak, reassembly, flight, line, skip) and H2 (browser `?debug` console) are open for the 3.9 playtest. Not gates. Headless runs cannot verify visuals or audio.

### File List

- `game/src/bosses/framework/boss_controller.gd` (modified)
- `game/src/autoloads/game.gd` (modified)
- `game/src/autoloads/audio_manager.gd` (modified)
- `game/src/core/defs.gd` (modified)
- `game/src/debug/debug_keys.gd` (modified)
- `game/src/main/main.gd` (modified)
- `game/src/presentation/boss_view.gd` (modified)
- `game/src/ui/duck/duck_bubble.gd` (modified)
- `game/src/ui/hud/hud.gd` (modified)
- `game/src/ui/screens/placeholder/placeholder_screen.gd` (modified)
- `game/src/ui/screens/harvest/harvest_screen.gd` (new, + `.uid`)
- `game/data/actions/nop.tres` (new)
- `game/data/bits/bit_loop.tres` (new)
- `game/data/duck/duck_lines.tres` (modified)
- `game/data/duck/duck_clips.tres` (modified, regenerated)
- `game/assets/audio/duck/harvest_shared.wav` (new, + `.import`)
- `game/tests/unit/test_harvest_screen.gd` (new, + `.uid`)
- `game/tests/integration/test_harvest_flow.gd` (new, + `.uid`)
- `game/tests/integration/test_infinite_loop_replay.gd` (modified)
- `game/tests/unit/test_action_resolver.gd`, `test_boss_controller.gd`, `test_camera_shake.gd`, `test_data_validation.gd`, `test_debug_keys.gd`, `test_duck_bubble.gd`, `test_duck_lines.gd`, `test_font_coverage.gd`, `test_game_flow.gd`, `test_main_layers.gd`, `test_register.gd` (modified)
- `_bmad-output/implementation-artifacts/3-8-boss-defeat-and-harvest.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml` (status)

### Change Log

- 2026-11-10: Story 3.8 implemented: defeat hit-stop + 60-tick reassembly, FIGHT -> HARVEST/ENDING routing from presentation, real HARVEST screen, LOOP bit + NOP action, harvest duck line (+ pre-render clip), F8 debug grant, voice cut on flow exit. GUT 936/936, guards OK. Status -> review.

### Review Notes (gds-code-review)

Review run 2026-11-10 (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel). Changed test expectations were checked one by one: all tied to the feature (LOOP now has a BitDef so the "no action" slot is N; HUD visible duck-only in HARVEST; duck line counts), the F6 message-only edit keeps its assertion.

### Review Findings

- [x] [Review][Patch] Skip press leaked into the next fight: `Game.finish_harvest` now calls `SimClock.swallow_presses_next_poll()` like `retry` (D-S29-12) [game/src/autoloads/game.gd]
- [x] [Review][Patch] `_defeat()` restarted `defeat_frames_elapsed` on a second call; the reset now sits inside the `_defeat_emitted` guard [game/src/bosses/framework/boss_controller.gd]
- [x] [Review][Defer] Dying inside the defeat window (D-S38-3) loses the kill; recorded design call, revisit at the MVP playtest
- [x] [Review][Defer] Release build: Fight 2/3 have no boss and no exit until Epic 5/6 (scope gap)
- [x] [Review][Defer] Recorder left running across FIGHT -> HARVEST -> FIGHT does not reproduce fight 2 (seed segment)
- [x] [Review][Defer] Test hygiene: hit-stop leaks across suites (pokes private `_pending_hitstop`); use a shared reset helper
- [x] [Review][Defer] `finish_harvest` has no bounds check on `boss_index + 1`; skip gate lives only in the screen
- [x] [Review][Defer] `Hud.set_duck_only(false)` re-shows every child; `is_duck_only` inferred from `frame.visible`
- [x] [Review][Defer] Harvest screen mixes physics-frame flight and sim-frame skip/cap; bit flight starts top-centre, not at the boss; reassembly segments on space cells vanish
- [x] [Review][Defer] Missing tests: skip input path and click/modifier rule, F8 warn, Main-level ENDING route, cap-path HP reset; F8 skips `boss_defeated`
- Dismissed (7): `register_text` byte (same formula as `Register.byte_value`), display ring vs `insert` order (D-S38-17), `finish_defeat`/`debug_grant_bit` boss argument (D-S38-18), `_physics_process` trigger, squeak guard on debug re-jump, `DuckBubble.clear` stop, fragile isolation test.
