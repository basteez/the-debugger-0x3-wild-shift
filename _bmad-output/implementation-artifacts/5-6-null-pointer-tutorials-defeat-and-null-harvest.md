---
baseline_commit: 6086206
---

# Story 5.6: Null Pointer Tutorials, Defeat and NULL Harvest

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-11). Self-made design calls are marked [design call] with IDs D-S56-n; the implementer follows them or records a change in Completion Notes. Scope: the two duck tutorial beats of the Null Pointer fight (Breakpoint line always, Watch line only with FeatureFlags.watch), the Null Pointer defeat path (reassembly of its fixed line, Harvest inserts NULL, shared harvest line), and the cut ladder #4 path (FeatureFlags.segfault = false: no NULL drop, Ending directly after Null Pointer). NOT in scope: Segfault body and its fight (Epic 6), the Ending content (6.8), save/resume (7.3), any new HUD, any change to Null Dodge, Clean Catch or Watch behaviour. This is the last story of Epic 5. -->

## Story

As a player,
I want the duck to introduce my new skills and the fight to end with a new bit,
so that Boss 2 is a complete, guided fight.

**Requirements:** FR45 (lines 6-7), FR50. Additional: cut ladder #4 (`FeatureFlags.segfault`). Epic 5 window Nov 18-21.

## Acceptance Criteria

1. **Given** the Null Pointer fight starts (control begins, boss not DEFEATED)
   **When** the fight is first polled for duck beats in this run
   **Then** the duck says `Space: Breakpoint. Time stops, you shift. Finally, a debugger that works.` (line id `n1_breakpoint`), once per run (D-S56-1)
   **And** Breakpoint is available at once on its first use of the fight attempt (free first use, D-S43-6; verified by a test, not re-implemented)

2. **Given** `FeatureFlags.watch` is on and line 1 has been requested in this run
   **When** the bubble has room (line 1 is no longer on screen)
   **Then** the duck says `Hold R. Pointers point *somewhere*.` (line id `n2_hold_r`), once per run

3. **Given** `FeatureFlags.watch = false` (cut ladder #2)
   **When** the Null Pointer fight runs
   **Then** line 2 is never requested and line 1 still plays (the Breakpoint line does not depend on Watch)

4. **Given** Null Pointer is defeated with `FeatureFlags.segfault = true`
   **When** the defeat sequence plays
   **Then** its glyphs reassemble into `if (ptr != null) ptr.deref();` (the boss's `fixed_line`, reusing the Story 3.8 path), the Harvest screen inserts NULL (`drop_bit = 4`) into a copy of the Fight 2 fight-start ring, so the display reads `[A, D, L, N]` (`0x0F`), and the shared harvest line `Bug squashed. It dropped a bit: new windows, new combos.` plays (Story 3.8, E4)

5. **Given** the Harvest after Null Pointer is left (`Game.finish_harvest`, or the skip)
   **When** Fight 3 starts
   **Then** the fight-start register is `Register.fight_start_for_boss(2)` = `[A, D, L, N]` exactly once (no duplicate N), HP is full and cooldowns are reset (D-049 b), and the arena's register was never written outside FIGHT

6. **Given** `FeatureFlags.segfault = false` (cut ladder #4)
   **When** Null Pointer is defeated
   **Then** the flow goes FIGHT -> ENDING directly (no HARVEST), NULL is not dropped (no Harvest screen, no bit inserted), and the ENDING placeholder shows (6.8 replaces it)

7. **Given** `FeatureFlags.segfault = false`
   **When** the player presses F8 on Fight 2 (debug)
   **Then** nothing is granted and the flow does not change (Log.warn, D-S56-4); with the flag on, F8 keeps the Story 3.8 behaviour (grant N, route to HARVEST)

8. **Given** the Null Pointer tutorials and the Harvest path
   **When** the unit and integration tests run
   **Then** AC 1, 2, 3, 4, 5, 6, 7 are each covered by a test (see Tasks), and the existing suite (including the replay tests, which must not change their recorded inputs) passes unchanged

9. **Given** a retry after a Null Pointer death or a debug jump
   **When** the fight restarts
   **Then** the Null Pointer beats are not repeated (per-run mask, D-S36-8 rule); a return to TITLE resets them

## Tasks / Subtasks

### Group A: Duck beats for Null Pointer (AC: 1, 2, 3, 9)

- [x] A1. `game/src/ui/duck/duck_director.gd`: add two ids `N1 = n1_breakpoint`, `N2 = n2_hold_r` (new constants next to `DUCK_IDS`; they do NOT join `DUCK_IDS`, so the Infinite Loop `due_beat` and its skip rule are untouched, D-S56-1). Add a pure `static func due_null_pointer_beat(p_requested: int, in_fight: bool, boss_id: StringName, watch_enabled: bool) -> int` returning the bit index (4 for N1, 5 for N2) or -1. Bits 4 and 5 live in the same `requested` mask (reset only on TITLE). N1 is due when its bit is clear, `boss_id == &"null_pointer"`, in FIGHT. N2 is due when its bit is clear, N1's bit is set, `watch_enabled` is true and the boss is `null_pointer`.
- [x] A2. `DuckDirector.poll()`: after the Infinite Loop `due_beat` check returns -1, call `due_null_pointer_beat` with the arena boss id (and `boss.state != DEFEATED`, so no line is requested on a defeated boss). The bubble room check stays where it is (`has_room()` returns early), which gives "then" for N2. Log with `Log.debug(&"duck", "beat ...")`, same as the other beats.
- [x] A3. `DuckDirector`: a public `var watch_enabled: bool = true`, set by `Main` from `arena.watch_enabled` (the one startup read, D-S54-3). The director never reads `FeatureFlags` itself.
- [x] A4. `data/duck/duck_lines.tres`: add two `DuckLineDef` sub-resources, `n1_breakpoint` and `n2_hold_r`, with the exact texts of AC 1 and 2 (ASCII only, `DuckLineDef.is_ascii`, fit the bubble width). The count goes from 8 to 10, the budget (GDD D-039).
- [x] A5. Pre-render the two voice clips with `game/tools/render_duck_lines.gd` (as Story 3.8 did for `harvest_shared`); the existing wavs stay byte-identical. A missing clip falls back to text only (Story 3.7), but the clips are required for the shipped build.
- [x] A6. Tests: `test_duck_director.gd` (N1 once per run, N2 only after N1 and only with watch on, neither on a DEFEATED boss, neither outside FIGHT or on other bosses, mask kept on retry, cleared on TITLE); `test_duck_lines.gd` / `test_duck_voice_data.gd` (ids exist, count is 10, clips present); `test_data_validation.gd` (the two new lines validate).
- [x] A7. Test AC 1's Breakpoint availability: in a Null Pointer fight the first Space press starts Breakpoint (no cooldown). Use the existing breakpoint wiring test as the model; add the assertion only if no test covers it yet.

### Group B: Null Pointer defeat, Harvest and fight 3 start (AC: 4, 5)

- [x] B1. Verify (test, no new code expected) that `Main.make_harvest_screen` uses `def.drop_bit` and `def.fixed_line` of the Null Pointer def (the generic 3.8 path, `main.gd` around line 393). Add a test that the Harvest for boss index 1 gets bit 4 and the Null Pointer `fixed_line`.
- [x] B2. Verify the display ring: boss index 1 -> `[A, D, L, N]` (`0x0F`) via the copy-based insert (`HarvestScreen` static helpers, D-S38-5). The arena register is never written.
- [x] B3. `Register.fight_start_for_boss(2)` already returns `[A, D, L, N]` (Story 5.5 note). Add a test: the Harvest -> Fight 3 path leaves `run.fight_start_ring == [A, D, L, N]` with N present once. Accepted deviation (coordinator): inserting N into the full `[A, D, L, N]` ring fails as "insert into a full register" (MAX_BITS = 4) before the owned-bit check, so the owned-bit rejection is tested on `[A, D, N]` and the full-ring rejection on `[A, D, L, N]`; N is never duplicated either way.
- [x] B4. Extend `test_harvest_flow.gd` (or `test_null_pointer_fight.gd`) with one integration path: Null Pointer defeat -> HARVEST -> FIGHT 3 with HP full, cooldowns reset, `fight_attempt` incremented once.

### Group C: Cut ladder #4, `FeatureFlags.segfault` (AC: 6, 7)

- [x] C1. `game/src/autoloads/game.gd`: add `var segfault_enabled: bool = Defs.FEATURE_FLAGS.segfault` (read once; tests may override before the fight, the same pattern as `Arena.watch_enabled`). Add a pure `static func route_after_defeat(index: int, segfault_on: bool) -> FlowState`: index 1 with `segfault_on = false` goes to ENDING; index >= LAST_BOSS_INDEX goes to ENDING; otherwise HARVEST. Update every caller (`finish_defeat`, `debug_grant_bit`) and the `advance()` FIGHT branch to use the same rule.
- [x] C2. `game.gd`: add a pure `static func drops_bit(index: int, segfault_on: bool) -> bool` (false for index 1 when `segfault_on` is false, true otherwise for bosses with a BitDef). `debug_grant_bit` returns false with `Log.warn(&"debug", ...)` when the boss does not drop (D-S56-4). `Main.make_harvest_screen` is not reached on the cut path; the cut path must not construct a HarvestScreen at all (test it).
- [x] C3. `Main`: when `segfault_enabled` is false, the defeat of Null Pointer routes to ENDING; the `harvest_bit_for` fallback is not used for index 1 on the cut path. Keep Main's `feature_flags` read as is.
- [x] C4. `game/src/core/feature_flags.gd`: correct the cut numbering comments to the ladder in `sprint-status.yaml` (`reserved_write` #1, `watch` #2, `breakpoint_enabled` #3, `segfault` #4). Comments only (D-S56-8). The `.tres` values stay `true`.
- [x] C5. Tests: `test_game_flow.gd` (route_after_defeat with segfault on and off; finish_defeat from boss 1 with the flag off -> ENDING and no HARVEST; advance FIGHT -> ENDING when off); `test_debug_keys.gd` or `test_game_flow.gd` (F8 on Fight 2 with flag off: no grant, no flow change, warn; with flag on: grant + HARVEST, unchanged); `test_feature_flags.gd` (the four flags exist, shipped values true).

### Group D: Verification (AC: 8)

- [x] D1. Run the full GUT suite and `game/tools/check_guards.sh` from the repo root (`bash game/tools/check_guards.sh`). Both must be green before the story leaves `ready-for-dev`.
- [x] D2. (Listed for the human in Completion Notes, not run by the agent) Manual (human, Chrome, `?debug`): play Null Pointer to defeat with the flag on (Breakpoint line, Watch line, reassembly, harvest with `0x0F`); then with `FeatureFlags.segfault = false` in a local copy only, defeat -> ENDING. Record results in Completion Notes. Not a blocker for `ready-for-dev`.
- [x] D3. Closes deferred items (`deferred-work.md`): "No dedicated tests for F8 on Fight 2 granting nothing extra" (covered by B3 and C5) and "Test gaps: ... Main-level ENDING route after Fight 3" if C5 covers it; otherwise leave the item open with a note.

### Review Findings

Code review 2026-11-11 (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel): 0 decision_needed, 3 patch, 7 defer, rest dismissed.

- [x] [Review][Patch] `route_after_defeat` default `segfault_on = true` silently ignores the cut; parameter now required [game/src/autoloads/game.gd]
- [x] [Review][Patch] Main never copied `feature_flags.segfault` into `Game.segfault_enabled` (two sources of truth); now set next to the other startup reads [game/src/main/main.gd]
- [x] [Review][Patch] `debug_jump` into Fight 3 accepted with the Segfault cut; now bounded by `last_fight_index(segfault_enabled)` + test [game/src/autoloads/game.gd]
- [x] [Review][Defer] N1 (Breakpoint) line ignores `breakpoint_enabled` (cut #3); spec says Breakpoint line plays always, N2 depends on N1 [game/src/ui/duck/duck_director.gd] - deferred, spec letter
- [x] [Review][Defer] Director copies `watch_enabled` at build time instead of reading the arena lazily - deferred, startup-only flag
- [x] [Review][Defer] Director excludes only DEFEATED, so N1/N2 may queue during hit-stop before the state flips; N1 and N2 can fire back to back - deferred, playtest tuning
- [x] [Review][Defer] `HarvestScreen` / `make_harvest_screen(1)` and `finish_harvest` have no cut-path guard; normal flow never reaches HARVEST at index 1 with the flag off - deferred
- [x] [Review][Defer] Brittle tests (hard-coded wrapped-line counts, regex over flag comments, PlaceholderScreen coupling); N2_BIT not asserted against DUCK_IDS.size() + 1 - deferred
- [x] [Review][Defer] `duck_clips.tres` sub-resource ids regenerated by editor resave; stale load_steps - deferred
- [x] [Review][Defer] Web budget (NFR4) not re-measured locally; two new WAVs add 571,290 bytes raw (CI gate decides) - deferred

## Dev Notes

### Note from Story 5.5 (binding)

- F8 already grants N on Fight 2 via the Story 3.8 route (`debug_grant_bit` checks `Defs.bit(drop_bit) != null` and that N is not in `fight_start_ring`), and `Register.fight_start_for_boss(2)` (Fight 3 start) already contains N. Story 5.6 must not double-grant N or assume N is absent on Fight 3. The Harvest screen inserts into a copy, so the display ring and the Fight 3 ring come from separate sources and do not collide.
- Story 5.5 D-S55-1 said N is not owned until 5.6; after this story, N is owned by the Fight 3 start register only (through the Harvest after Null Pointer), never by the Fight 2 start ring.

### Design calls for this story (D-S56-n)

- **[design call] D-S56-1 (Null Pointer beats, per run):** two new duck beats, `n1_breakpoint` (AC 1) and `n2_hold_r` (AC 2). They do not join `DuckDirector.DUCK_IDS`, because `due_beat` is Infinite Loop only and its skip rule ("an earlier beat is skipped for good once a later beat fired") must not change. They use bits 4 and 5 of the existing per-run `requested` mask, which resets on TITLE and is kept on retry (D-S36-8). Trigger: the first poll in FIGHT with `boss_id == null_pointer` and the boss not DEFEATED. This is "control begins" in practice, because the poll runs only in FIGHT and not while paused.
- **[design call] D-S56-2 (line order):** N2 waits for N1 to have been requested and for the bubble to have room (`has_room()`), so "then" holds without a timer. No frame timeout.
- **[design call] D-S56-3 (cut path):** `FeatureFlags.segfault = false` makes the Null Pointer defeat go to ENDING. The Null Pointer's `drop_bit` is ignored on this path: no HarvestScreen, no insert, no `Register` change. Implemented with pure statics on `Game` (`route_after_defeat(index, segfault_on)`, `drops_bit(index, segfault_on)`) so they test without a scene. The flag is read once (`Game.segfault_enabled`), like `Arena.watch_enabled`.
- **[design call] D-S56-4 (F8 on the cut path):** F8 on Fight 2 with the flag off logs a warning and does nothing, because the bit is not dropped on this path. With the flag on, F8 is unchanged (Story 3.8, D-S38-7).
- **[design call] D-S56-5 (no new Harvest visuals):** the Null Pointer defeat reassembly and the bit flight reuse the Story 3.8 generic path with the boss's `fixed_line` and `drop_bit`. No new art, no new screen. The Harvest line is the existing shared `harvest_shared` (Story 3.8, E4), not a Null Pointer line.
- **[design call] D-S56-6 (Fight 3 register):** unchanged data. `Register.fight_start_for_boss(2)` stays `[A, D, L, N]`. Only the tests are added (B3), so the Fight 3 path is proven rather than assumed.
- **[design call] D-S56-7 (Breakpoint first use):** no code change. Breakpoint's first use per fight attempt is free (Story 4.3, D-S43-6); AC 1 is a test.
- **[design call] D-S56-8 (flag comments):** `feature_flags.gd` comments number the cuts differently from the ladder in `sprint-status.yaml` (the comments say segfault = #1 and reserved_write = #4). This story corrects the comments to the sprint-status ladder. Comments only; no value or name changes.
- **[design call] D-S56-9 (cut ladder #4 status):** this story implements the flag-off fallback (AC 6). Once it is done, the cut-ladder #4 fallback is covered in the Epic 5 record; the Segfault stories (6.3-6.6) stay `backlog` and are not changed by this story.

### Architecture and rules that bind this story

- Single flow writer: only `Game` changes `flow_state` (`finish_defeat`, `finish_harvest`, `debug_grant_bit`, `advance`). The new routing stays inside `Game`.
- Presentation reads, never writes sim state: `DuckDirector` reads the arena and the flag (`watch_enabled` is injected); it writes only its own `requested`/pending state.
- The Harvest screen builds a copy of the register; the arena register is never written outside FIGHT (D-S38-5).
- Feature flags are read once at startup (AD-12, Story 4.3 D-S43-1). Tests may override before the fight.
- Guard rules (`game/tools/check_guards.sh`): no `Timer.new`, `await`, global RNG or `Input` singleton in sim dirs. Duck and Harvest code live in `src/ui` (presentation) and may use tweens.
- Documents in English. Code comments use the `Story 5.6 (D-S56-n)` style.

### Existing code this story touches (read before editing)

- `game/src/autoloads/game.gd` (~420 lines): `LAST_BOSS_INDEX = 2` (line 13), `advance()` FIGHT branch (line ~228), `route_after_defeat(index)` (line ~243, currently ENDING only for index >= 2), `finish_defeat` (line ~251), `debug_grant_bit` (line ~297), `debug_jump` (unchanged; F1-F5 may still target boss 2 as a placeholder). Change: segfault-aware routing and drop rule.
- `game/src/main/main.gd`: `feature_flags` (line 59), `arena.set_watch_enabled` wiring (line 106), `DuckDirector` attach (lines 180-185; add the `watch_enabled` hand-over here), `make_harvest_screen` (line ~393: `def.drop_bit`, `def.fixed_line`, `harvest_bit_for` fallback). Change: cut path must not build a HarvestScreen.
- `game/src/ui/duck/duck_director.gd`: `DUCK_IDS`, `due_beat` (Infinite Loop only, returns -1 otherwise), `poll()`, `_on_flow_state_changed` (clears `requested` on TITLE only). Change: the Null Pointer beats (A1-A3). Preserve all Infinite Loop behaviour and its tests.
- `game/src/ui/duck/duck_line_def.gd` / `duck_lines_def.gd`: `is_ascii` check, `id`, `text`. Change: none expected; data added.
- `game/data/duck/duck_lines.tres`: 8 entries today (t1-t4, `harvest_shared`, `hint_a_d`, `hint_d_a`, `hint_d_l`). Add `n1_breakpoint`, `n2_hold_r` (count 10).
- `game/src/ui/screens/harvest/harvest_screen.gd`: `setup(boss_index, fixed_line, p_bit, previous)`, `display_ring` (copy-based insert, uses `Register.fight_start_for_boss(boss_index + 1)`), `LINE_ID = harvest_shared`. Change: none expected; test it.
- `game/src/register/register.gd`: `fight_start_for_boss` (line 126; index 2 already `[ATTACK, DASH, LOOP, NULL_BIT]`), `insert`, `byte_value`. Change: none.
- `game/data/bosses/null_pointer/boss_def.tres`: `drop_bit = 4`, `fixed_line = "if (ptr != null) ptr.deref();"`, `max_hp = 700`. Change: none.
- `game/src/core/feature_flags.gd` and `game/data/config/feature_flags.tres`: `segfault = true` (the only flag this story uses; values stay true). Change: comments only (C4).
- `game/src/arena/arena.gd`: `breakpoint_enabled` (line 88), `watch_enabled` (line 95). Read only.
- `game/src/skills/breakpoint/breakpoint_skill.gd`: Space starts Breakpoint; `cooldown_left = 0` on the first use of each fight attempt (line 50). Read only.
- Tests to extend: `game/tests/unit/test_game_flow.gd`, `test_debug_keys.gd`, `test_duck_director.gd`, `test_duck_lines.gd`, `test_duck_voice_data.gd`, `test_data_validation.gd`, `test_feature_flags.gd`; integration: `game/tests/integration/test_harvest_flow.gd`, `test_null_pointer_fight.gd`, `test_retry_snapshot.gd` (read before editing).

### Previous story intelligence

- **5.5:** Null Dodge and Clean Catch are data-driven (`arms_clean_catch`, `slows_move`). The N bit is registered in `Defs` with `bit_null.tres` (id 4, glyph N, solo `null_dodge.tres`). Nothing in 5.6 touches those. Review deferred items that stay open after 5.6: Clean Catch has no expiry; Echo of Null Dodge is unit-level only (end-to-end against a live boss attack, to be covered in the 5.6 integration test if cheap, otherwise playtest).
- **5.4:** `FeatureFlags.watch` is read once in `Arena`; off means the Null Pointer gets the flicker fallback injected. The Watch line (AC 2) depends on the flag, the Breakpoint line (AC 1) does not.
- **5.1:** `boss_def.tres` for Null Pointer exists with `fixed_line` (the defeat reassembly text) and `drop_bit = 4`.
- **4.4:** `DuckHint` and the hint lines (`hint_a_d`, `hint_d_a`, `hint_d_l`) are in `duck_lines.tres`, with a per-attempt key. Null Pointer hints already route through `poll()` (`pending_hints` first). The new beats must not reorder hints: the hint branch in `poll()` runs before the beat branch and keeps that order.
- **4.3:** Breakpoint is gated by `FeatureFlags.breakpoint_enabled` (cut #3); first use free per attempt (D-S43-6).
- **3.8:** Harvest is generic over `drop_bit` and `fixed_line`; F8 routes like a defeat (D-S38-7); the harvest line is `harvest_shared`; every flow exit from FIGHT or HARVEST clears the bubble and calls `VoiceService.stop()` (D-S38-11). The Null Pointer path inherits all of it.
- **3.6 / 3.7:** duck beats are per run, the bubble clears on flow change, `VoiceService.say` falls back to text when a clip is missing.
- **Deferred items that name 5.6 or Epic 5:** `deferred-work.md` lines about the F8 Fight 2 test (covered by C5), the Main-level ENDING route (covered by C5 if it is a unit test of routing), and the Null Pointer BossDef (resolved in 5.1).

### Git intelligence

- Recent branch commits: `6086206 Story 5.5: NULL bit, Null Dodge and Clean Catch`, `0782e08 Story 5.4: Watch skill`, `36195db Story 5.3`. Use the same commit style for this story: `Story 5.6: Null Pointer tutorials, Defeat and NULL Harvest`. This story does not commit (the dev-story run or the human does).

### Latest technical information

- Godot 4 GDScript, the project's own engine version (see `game/project.godot`). No new library. Web export unchanged. The build-size budget (NFR4, 32 MB, commit b71bdfa) applies to the release web build; the two new wav clips must be checked against it.

### Project Context Rules

- No `project-context.md` rules beyond the `_bmad-output` conventions and the guard script were found for this story. Rules applied: presentation never writes sim state, feature flags are read once at startup, guard script green, English documents.

### Project Structure Notes

- New files: none expected in code (the two clips and their `.import` are generated by the render tool). Tests extend existing files.
- Presentation files stay in `src/ui/`; flow routing stays in `src/autoloads/game.gd`.

### Testing standards summary

- GUT tests under `game/tests/unit/` and `game/tests/integration/`. Pure static helpers are tested without scenes. Replay tests must keep passing with unchanged recorded inputs.
- `bash game/tools/check_guards.sh` must be green. Full GUT suite green.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.6: Null Pointer Tutorials, Defeat and NULL Harvest]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.6, Story 3.8, Story 4.4]
- [Source: _bmad-output/implementation-artifacts/5-5-null-bit-null-dodge-and-clean-catch.md#Dev Notes (Note for Story 5.6)]
- [Source: _bmad-output/implementation-artifacts/3-8-boss-defeat-and-harvest.md#Design calls (D-S38-2, D-S38-5, D-S38-7)]
- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml#CUT ORDER (cut ladder #4)]

## Design calls

- D-S56-1 through D-S56-9: see Dev Notes above (IDs are the source of truth; each is referenced in the Tasks and ACs).

## Open questions (not blocking)

- D-S56-8: the feature-flag comment numbering was corrected to the sprint-status ladder. If the GDD ladder numbers differ from sprint-status, the GDD wins and the comments follow; confirm with Tiziano.
- D-S56-3: on the cut path the Ending plays directly after Null Pointer. The Ending is still the placeholder until 6.8; the player will see the placeholder. Expected.
- D-S56-2: N2 waits for bubble room, not a timer. If playtests show a long gap between the two lines, a frame cap is a one-constant change.
- Manual check D2 (Chrome, flag-off build) is a human step; the story can close without it.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended pipeline run (2026-11-11).

### Debug Log References

- Baseline suite before changes: 1303/1303. Final: 1332/1332 (+29 tests), `check_guards: OK`, headless `--import` with no SCRIPT ERROR / Parse Error.
- Flag-off verification: `data/config/feature_flags.tres` set to `segfault = false` temporarily, full suite run: 1330/1332; the only 2 failures are the shipped-value assertions (`test_shipped_flags_are_all_on_and_valid`, `test_four_cut_ladder_flags_exist_and_are_numbered_like_the_gdd`: "segfault ships on"), as expected. Flag restored to `true` (file byte-identical to HEAD).
- First flag-off run also failed `test_full_sequence_and_boss_index_via_placeholder_advance` and `test_f8_grants_null_on_fight_2_and_is_a_no_op_outside_fight` because they assumed the shipped flag; both now pin `segfault_enabled = true` (one line each) so they test the flag-on route regardless of the shipped data.
- Leak found while testing: a test that leaves FIGHT 2 without returning to TITLE leaves `Game.run.fight_start_ring = [A, D, L]` with `boss_index` restored to 0, which broke `test_main_layers` (Harvest insert of owned L). The new F8 test ends with F1 (TITLE).
- `render_duck_lines.gd` (wav, import, tres): the 8 existing wavs are byte-identical (md5 before/after); `duck_clips.tres` gains 2 entries (its sub-resource ids are regenerated by ResourceSaver, contents unchanged). New wav sizes: n1 391 KB, n2 180 KB (raw, all 10 clips 2.77 MB); the web build budget (NFR4, 32 MB) was not re-measured here.

### Completion Notes List

- A (AC 1-3, 9): `DuckDirector` gets `N1`/`N2` ids, `N1_BIT = 4`/`N2_BIT = 5`, a pure `due_null_pointer_beat()` and `watch_enabled` (Main hands over `arena.watch_enabled`). `poll()` checks the Null Pointer beats after `due_beat` returns -1, never on a DEFEATED boss; hints keep priority. Two lines added to `duck_lines.tres` (10 entries, D-039 budget count 8 of 10) and their clips rendered.
- A7 (AC 1): Breakpoint free first use in a Null Pointer fight is covered by a new wiring test (no code change, D-S56-7).
- B (AC 4, 5): no production change. Unit tests for the 0x0F display ring and the owned-N rejection; integration test Null Pointer defeat -> HARVEST (fixed line, bit N, harvest line, arena register untouched) -> Fight 3 (`[A, D, L, N]`, N once, full HP, cooldowns reset, attempt +1).
- C (AC 6, 7): `Game.segfault_enabled` (read once), pure `last_fight_index()`, `route_after_defeat(index, segfault_on = true)`, `drops_bit()`; used by `advance()`, `finish_defeat()` and `debug_grant_bit()` (warns and refuses on the cut path). Main needs no routing change: Game never enters HARVEST on the cut path, so no HarvestScreen is built (integration test). `feature_flags.gd` comments renumbered.
- Cut-ladder numbering (coordinator question 1): the GDD Out of Scope ladder (gdd.md "Cut ladder for v1.0") agrees with sprint-status: #1 Reserved Write, #2 Watch, #3 Breakpoint, #4 Segfault. Comments corrected accordingly; values unchanged.
- [design call] D-S56-10: `due_beat`'s skip rule ("a later beat already fired") now looks only at the Infinite Loop bits (0-3). Without the mask, N1/N2 bits set by a debug jump to Fight 2 before Fight 1 (same run, no TITLE) would mark T1-T4 skipped. Behaviour for the Infinite Loop bits is unchanged; all existing tests pass.
- [design call] D-S56-11: `route_after_defeat` keeps a default `segfault_on = true` so the 3.8 one-argument callers/tests still compile; every production caller passes `segfault_enabled`.
- [design call] D-S56-12: the rule is expressed as `last_fight_index(segfault_on)` (2, or 1 when cut) so `route_after_defeat` and `drops_bit` cannot disagree.
- [design call] D-S56-13: two existing tests (full placeholder sequence, F8 grants N on Fight 2) pin `segfault_enabled = true` so the flag-off suite run isolates real fallback behaviour. Recorded inputs of the replay tests are untouched.
- Spec note: B3 says inserting N into a ring that already has N fails with the owned-bit error; for `[A, D, L, N]` the Register rejects with "insert into a full register" first (MAX_BITS = 4). Tests cover both (full 4-bit ring and `[A, D, N]`).
- D3: deferred-work.md annotated: F8-on-Fight-2 item closed (chain cap stays open); F8 warn path covered; "Main-level ENDING route after Fight 3" stays open until the Segfault fight exists (Epic 6), the cut-path ENDING after Fight 2 is covered.
- Human step (not a blocker, D2): in Chrome with `?debug`, play Null Pointer to defeat with the shipped flags (Breakpoint line, then Watch line, `if (ptr != null) ptr.deref();` reassembly, Harvest `[A, D, L, N] = 0x0F`), then with `segfault = false` in a local copy only: defeat -> ENDING placeholder, F8 on Fight 2 does nothing. Also listen to the two new clips.
- Expected: after the cut path the ENDING is the placeholder until Story 6.8.

### File List

- game/src/autoloads/game.gd
- game/src/core/feature_flags.gd
- game/src/main/main.gd
- game/src/ui/duck/duck_director.gd
- game/data/duck/duck_lines.tres
- game/data/duck/duck_clips.tres
- game/assets/audio/duck/n1_breakpoint.wav (new)
- game/assets/audio/duck/n1_breakpoint.wav.import (new)
- game/assets/audio/duck/n2_hold_r.wav (new)
- game/assets/audio/duck/n2_hold_r.wav.import (new)
- game/tests/unit/test_duck_director.gd
- game/tests/unit/test_duck_lines.gd
- game/tests/unit/test_duck_voice_data.gd
- game/tests/unit/test_duck_bubble.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_breakpoint_wiring.gd
- game/tests/unit/test_harvest_screen.gd
- game/tests/unit/test_game_flow.gd
- game/tests/unit/test_debug_keys.gd
- game/tests/unit/test_feature_flags.gd
- game/tests/integration/test_harvest_flow.gd
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/5-6-null-pointer-tutorials-defeat-and-null-harvest.md

### Change Log

- 2026-11-11: Story 5.6 implemented: Null Pointer duck beats N1/N2 (+ clips), segfault-aware defeat routing and F8 (cut ladder #4), feature-flag comments renumbered to the GDD ladder, NULL Harvest / Fight 3 tests. 1332 tests green, guards OK. Status -> review.
