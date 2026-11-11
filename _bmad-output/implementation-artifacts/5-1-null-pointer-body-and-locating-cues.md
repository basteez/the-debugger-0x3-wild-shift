---
baseline_commit: b71bdfa5117e3cc7f8b08772e43b4c3c51716f47
---

# Story 5.1: Null Pointer Body and Locating Cues

Status: done
<!-- Created unattended by gds-create-story (pipeline, 2026-11-11). Open design questions are marked [design call] with the chosen default (D-S51-n); the implementer follows them or records a change in Completion Notes. Scope: the Null Pointer body (invisible ghost, visibility rules, idle drift), its locating cues (falling `null` column, panned hum, `null` trail), its BossDef data (HP 700, drop NULL, fixed line, phase weak windows and gaps), its wiring as FIGHT boss 1 (index 1), and the sky comment. NOT in scope: attacks (Pointer Grab, Null Rain, Dangling Pointers: 5.2 and 5.3, so the phase pools stay empty here), the NullPointerException whiff stun (5.3), decoys (5.3), Watch input and reveal (5.4; 5.1 exposes the hook only), the NULL bit def `bit_null.tres` (5.5), the Null Pointer tutorial lines and the Watch tutorial (5.5 / 5.6). -->

## Story

As a player,
I want to track an invisible ghost by its trail and hum,
so that the bug feels like a pointer to nothing (Pillar 3).

**Requirements:** FR23 (tag on invisible boss; Patched tag stays visible), FR37 (Null Pointer body), FR39 (phases, weak windows and gaps). Additional: GDD "Boss 2 — Null Pointer" section, GDD Boss stat table (HP 700), GDD sky comment list, architecture AD-09 (Null Pointer hum on `AudioStreamPlayer2D`, `Stream` fallback on that node only), AD-06 (boss framework).

## Acceptance Criteria

**Body and spawn**

1. **Given** the Null Pointer fight starts with `[A, D, L]` (FIGHT boss index 1), **When** the boss spawns, **Then** it is a ghost of `null` glyphs (a `BossController` subclass `NullPointerBody`, `src/bosses/null_pointer/`) that drifts invisibly at 4 tiles/s, with a column of 3–5 falling `null` glyphs drifting under it and a looping hum panned by its position (on `AudioStreamPlayer2D`, or `playback_type = Stream` on that node if the Epic 1 smoke test failed; the fallback decision is recorded in Completion Notes, not in code).
2. **And** the sky comment reads `// FIXME: who owns this pointer?` while this fight is live (the HUD sky row currently shows the `Hud.SKY` constant, `// TODO: this should terminate`; see [design call] D-S51-4).
3. **And** `Arena.boss_class_for` returns `NullPointerBody` for the Null Pointer def path, and `Main.boss_def_path_for` returns that path for `boss_index == 1` (no debug test boss, not practice). Boss 2 (Segfault, index 2) still returns `""` (placeholder header) and is out of scope.

**Visibility**

4. **Given** the ghost is invisible, **When** its controller state is `ACTIVE` or `RECOVERY` (an attack's active or recovery frames), **Then** it is drawn visible for those frames.
5. **Given** a player hit lands on the boss (a HIT on the Null Pointer through CombatResolver), **When** the hit resolves, **Then** the ghost is visible for exactly 10 sim frames (the 10-frame flicker).
6. **Given** Echo Dash passes through the ghost (`BossInteraction.Kind.PASS_THROUGH` produced by CombatResolver), **When** the dash resolves, **Then** the ghost is visible for exactly 60 sim frames.
7. **Given** Watch is held, **When** the ghost is drawn, **Then** it is visible. 5.1 only exposes `set_watch_held(bool)` on the body (default false, read by the visibility rule); the Watch input and skill are Story 5.4. A test drives the setter.
8. **And** while Patched (`weak_window` active), the `// patched` tag and its countdown bar stay visible even when the body is invisible, as a position hint (the existing BossView Patched stack, with the body hidden).
9. Reveal timers are sim state: counted in `tick()` and never reset by the draw path. Visibility is read by presentation only; `visible_now()` is a pure function of sim state.

**Motion and locating cues**

10. **Given** the idle state (no attack in ACTIVE or RECOVERY, no Watch), **When** the ghost moves, **Then** it drifts at 4 tiles/s (4000 milli-tiles per second, integer, D-S33-2 style) in a direction chosen from `SimContext.rng`, re-chosen every 90 ticks and reflected at the play-area edges; it never leaves the play area ([design call] D-S51-1).
11. **Given** the boss moves, **When** each tick ends, **Then** the hum's `AudioStreamPlayer2D` position equals the boss's arena-local position, so its pan follows its x position, and the `null` trail (the falling column) follows the boss position every tick. A test asserts both over a 300-tick run with a fixed seed.
12. **Given** the falling column, **When** the boss is alive, **Then** it shows 4 `null` glyphs (3–5 allowed, [design call] D-S51-2), spaced one cell apart, falling at 1 tile per 15 ticks, wrapping back to the boss's column top, drawn beneath the body (not part of the hurtbox).
13. **And** the hum is a looping `AudioStreamWAV` generated in code at load (no new audio asset in this story; [design call] D-S51-3). It starts when the fight starts and stops when the fight is left or the boss is defeated.
14. "Locatable by sound alone and by sight alone" is NOT verified here; it is the Story 7.8 playtest.

**BossDef and phases**

15. **Given** `game/data/bosses/null_pointer/boss_def.tres`, **When** loaded, **Then** `boss_id = &"null_pointer"`, `name_signature = "nullPointer"`, `max_hp = 700`, `drop_bit = Register.Bit.NULL_BIT` (value 4; the GDD calls it `N`; `bit_null.tres` arrives in Story 5.5, so the drop is recorded but not granted until then), `fixed_line = "if (ptr != null) ptr.deref();"`, and `BossDef.validate()` returns no problems.
16. **And** phase 1 has `hp_threshold = 100`, `weak_window = Vector2i(2, 3)` (D→L), `gap_frames = 90`; phase 2 has `hp_threshold = 50`, `weak_window = Vector2i(1, 2)` (A→D), `gap_frames = 60`. Both `attack_pool`s are empty for now (GAP only; D-S33-9); 5.2 and 5.3 fill them.
17. **And** `body_radius_tiles` is set ([design call] D-S51-5, default 1.0), and a unit test checks that a BossDef with an empty pool runs GAP to GAP without error.

**Tests**

18. Unit tests cover AC 4–9 (visibility rule and timers, each source), AC 10 (drift speed and bounds over a seeded run), AC 11 (hum and trail follow position each tick), AC 15–17 (def validation and values). Existing suites (`test_boss_controller`, `test_data_validation`, `test_combat_resolver`, `test_attack_isolation`) stay green.
19. A replay or headless run confirms the fight boots from FIGHT boss 1 without errors (`Log.error` free) and the boss returns to GAP with no attack.

## Tasks / Subtasks

- [x] Task 1: BossDef data (AC: 15, 16, 17)
  - [x] 1.1 Create `game/data/bosses/null_pointer/boss_def.tres` (+ phase sub-resources, empty `attack_pool`), mirroring `infinite_loop/boss_def.tres`.
  - [x] 1.2 Add a data test in `test_data_validation.gd` for HP, drop, fixed line, phase windows and gaps.
- [x] Task 2: NullPointerBody controller (AC: 1, 4, 7, 9, 10)
  - [x] 2.1 Create `game/src/bosses/null_pointer/null_pointer_body.gd` (`class_name NullPointerBody extends BossController`), integer position in milli-tiles, drift per tick in `_tick_body`.
  - [x] 2.2 Expose `visible_now()`, `set_watch_held(bool)`, `reveal_for_hit()` and a PASS_THROUGH hook (`on_pass_through()`), all sim-state only.
  - [x] 2.3 Wire `Arena.boss_class_for` and `Arena.NULL_POINTER_DEF_PATH`; add the `Main.boss_def_path_for` branch for index 1.
- [x] Task 3: Interaction hooks (AC: 5, 6)
  - [x] 3.1 Route the boss-hit and PASS_THROUGH results from CombatResolver to the body (the body is the only writer of its reveal timers). Keep `arena/` free of `presentation/` references.
- [x] Task 4: Presentation (AC: 1, 2, 8, 11, 12, 13)
  - [x] 4.1 Draw the ghost (`null` glyphs) only when `visible_now()`; draw the falling column always while alive.
  - [x] 4.2 Patched tag and bar still drawn while invisible (BossView).
  - [x] 4.3 Hum: `AudioStreamPlayer2D` child of the body view, looping generated `AudioStreamWAV`, position synced every tick; start on fight start, stop on leave or defeat.
  - [x] 4.4 Sky comment: set `// FIXME: who owns this pointer?` for this fight (D-S51-4).
- [x] Task 5: Tests (AC: 18, 19)
  - [x] 5.1 `game/tests/unit/test_null_pointer_body.gd` covering AC 4–11.
  - [x] 5.2 Run the full GUT suite and the replay suite; no new `Log.error`.

## Dev Notes

### Design context (what 5.1 must respect)

- The boss framework (Story 3.1, `BossController`) owns the FSM, HP, phase, weak window and defeat. Subclasses only add body behaviour (`_tick_body`, `_on_phase_reset`, `_pick_candidates`), as `InfiniteLoopBody` does. Do not duplicate the FSM.
- Empty `attack_pool` is legal (Story 3.3, D-S33-9): the boss sits in GAP. The GAP counter still runs; with no pool, `_advance` must not pick an attack. Confirm this in the test from AC 17 before relying on it.
- Ring-body pattern (Story 3.3): integer milli-unit motion, floats for drawing only, all randomness from `SimContext.rng`. Mirror that.
- `ArenaContext` gives read access to the player's position (`body_contact_position`) and the aim point. The Null Pointer body needs neither in 5.1 (no contact hazard yet); do not add a Player or Register reference.
- Presentation reads the controller and never writes it (AD-05). `boss_view.gd` draws the current placeholder; the ghost is a new view responsibility, not a second writer.
- Hum: AD-09 places the hum on `AudioStreamPlayer2D`. The Epic 1 web panning smoke test result is not in this repo's code; the implementer records which playback mode is used. Keep the fallback to one node's `playback_type`.

### Weak window convention

Bit ids: ATTACK = 1 (A), DASH = 2 (D), LOOP = 3 (L), NULL_BIT = 4 (N) (`Register.Bit`). `Vector2i(2, 3)` is D→L; `Vector2i(1, 2)` is A→D. Same ordering convention as `infinite_loop/boss_def.tres`.

### Files to touch

- New: `game/data/bosses/null_pointer/boss_def.tres`, `game/src/bosses/null_pointer/null_pointer_body.gd` (+ `.uid` from the editor), its view script if split out, `game/tests/unit/test_null_pointer_body.gd`.
- Edit: `game/src/arena/arena.gd` (path constant, `boss_class_for`), `game/src/main/main.gd` (`boss_def_path_for`), `game/src/bosses/framework/boss_controller.gd` only if a hook is needed (prefer subclass overrides), `game/src/presentation/boss_view.gd` (skip the body glyphs while invisible, keep the Patched stack), `game/src/ui/hud/hud.gd` (sky comment for this fight), CombatResolver hook site (Task 3).
- Do not edit: `data/bits/` (5.5), `src/skills/watch/` (5.4), `src/bosses/infinite_loop/` (except through shared framework), any Epic 6 files.

### Testing standards

GUT tests in `game/tests/unit/` and `game/tests/integration/`. Fixed seeds through `SimContext`. Use `SimClock` ticks, never wall time. Follow the existing `test_*.gd` naming and the `.gd.uid` convention. Run `check_guards` (the leaf-folder rule from Story 4.3) if the new folder touches the cut-ladder boundaries.

### Previous story intelligence

- Story 4.4 (done): the duck hint for Null Pointer and Segfault is blocked until their BossDefs land. Its test expects `current_weak_window()` to return the phase data window for each boss; 5.1 makes that true for Null Pointer (`test_duck_hint` should pick it up; verify, do not assume).
- Story 4.3 (done): `BossController.breakpoint_on` is injected by the arena; a Null Pointer body inherits it and needs no change.
- Story 3.8 (done): `Game.BOSS_IDS` already includes `&"null_pointer"` at index 1; `Game.finish_defeat` routes Boss 2 to HARVEST. The defeat path must not regress.

### Latest technical information

Godot 4.7 (project `game/project.godot`), GDScript 2.0 with typed arrays. `AudioStreamWAV` is built in code (format 16-bit, mix rate 22050, `loop_mode = LOOP_FORWARD`, `loop_end` set to the sample count). Web export uses Sample playback (AD-09): the implementer checks the web build plays the hum in the browser (human check in the Epic 7 playtest).

## Project Context Rules

- Read-only defs at runtime; mutable state in sim objects (architecture, Story 2.5).
- Integer sim state; floats for presentation only (D-S33-2).
- Presentation may not write sim state; `arena/` may not reference `presentation/`.
- Leaf-folder rule for cut-ladder modules (Story 4.3). Null Pointer is core to the MVP (no flag), so its folder is not cuttable.
- Documents in English; code comments follow the existing `Story X.Y (DECISION-ID)` style.

## Design calls

- **D-S51-1 (drift pattern):** random direction re-picked every 90 ticks from `SimContext.rng`, reflected at play-area edges, integer milli-tiles. The GDD gives the speed only.
- **D-S51-2 (falling column):** 4 `null` glyphs, one cell apart, falling 1 tile per 15 ticks, wrapping to the top. The GDD allows 3–5.
- **D-S51-3 (hum asset):** generated `AudioStreamWAV` loop in code (a low saw or sine drone with a slow pitch wobble), no new file. Replace with a real asset when the music pass (Epic 7) lands.
- **D-S51-4 (sky comment):** a per-fight sky comment, set while the Null Pointer fight is live, restored to `Hud.SKY` on leave. Boss 1 keeps its current sky row.
- **D-S51-5 (body radius):** 1.0 tile. Tune with the 5.2 grab and 5.3 whiff tests.

## Open questions (not blocking)

- The Epic 1 `AudioStreamPlayer2D` web panning smoke test: the result is not recorded in the repo I checked. If it failed, the implementer switches the hum node to `Stream` and notes it in Completion Notes.
- The GDD's Watch-held visibility (AC 7) needs the Watch input in 5.4; until then `set_watch_held` is test-only.

## References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.1: Null Pointer Body and Locating Cues]
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5: Null Pointer & Watch]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 2 — Null Pointer]
- [Source: _bmad-output/game-architecture.md#AD-06 (boss framework), AD-09 (audio)]
- [Source: _bmad-output/implementation-artifacts/3-3-infinite-loop-body-and-loop-condition.md] (body pattern, integer motion)
- [Source: _bmad-output/implementation-artifacts/4-4-duck-hint-template.md] (weak window hint dependency)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (Null Pointer has no BossDef yet, from 4.4)

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (gds-create-story, unattended); claude-opus-5-5 (gds-dev-story, unattended)

### Debug Log References

- Full GUT suite (headless, Godot 4.7.2, CI command): 1128/1128 passing, 49842 asserts, `---- All tests passed! ----`, no SCRIPT ERROR / Parse Error markers. `check_guards.sh`: OK. Headless `--import`: no script errors. (One pre-existing `SHADER ERROR` in screen_fx, unrelated, already on main.)
- First full run after wiring boss 1 failed in 6 tests that assumed "FIGHT boss 1 has no boss" (test_debug_keys x4, test_harvest_flow) and in test_duck_hint (no catalogue entry for the new D→L window); fixed as described below.

### Completion Notes List

- Story created (ready-for-dev) by gds-create-story, unattended. Design calls D-S51-1 to D-S51-5 are recorded above; the implementer may change them and must note changes here.
- Implemented (gds-dev-story, unattended). D-S51-1 to D-S51-5 followed as written: 16 integer directions (milli-units), re-picked every 90 live ticks from `SimContext.rng`, per-axis remainder (4000 mtps / 60), reflection at the play area inset by the body radius; 4 trail glyphs, 1 tile apart, 1 tile per 15 ticks; generated hum; per-fight sky comment (`Hud.sky_for(boss_id)`, restored automatically when the HUD's boss changes); `body_radius_tiles = 1.0`.
- **Hum playback mode (AC 1, AD-09):** the Epic 1 web panning smoke result is not recorded in the repo, and AD-09 notes that positional audio is unreliable in Sample mode. [design call] The safe option was taken: the hum node alone sets `playback_type = PLAYBACK_TYPE_STREAM` (the AD-09 fallback); everything else keeps the project's Sample default on web. Revert to Default on that one node if the web smoke test confirms Sample panning works. Human check in the browser is still the Epic 7 playtest.
- [design call] D-S51-6: `visible_now()` is true once DEFEATED (the ghost shows where it was caught; the column and the hum stop). The fixed-line reassembly for this boss is later work.
- [design call] D-S51-7: the ghost drifts in every live state except an attack's ACTIVE / RECOVERY (GAP, TELL, ROAR), Watch held or not. "No Watch" in AC 10 is read as the invisibility condition, not a freeze.
- [design call] D-S51-8: the ghost is not a contact hazard (`touches_player` returns only the live attack's hazard, none until 5.2), per the Dev Notes "no contact hazard yet". Its hurtbox is the default body circle (player hits land while it is invisible).
- [design call] D-S51-9: the ghost is drawn as two rows of `null` at 1x (2 x 1 tiles, about the hurtbox diameter); column glyphs are `null` at 1x, skipped when they would leave the play area. The Patched stack and the damage number are drawn whether the ghost is visible or not (AC 8).
- [design call] D-S51-10: the hum stops while the game is paused (`SimClock.paused`) and before the audio unlock, besides leave and defeat.
- Task 3 hooks: two no-op virtuals on `BossController` (`on_player_hit()`, `on_pass_through()`) called by CombatResolver after a boss HIT and after a PASS_THROUGH; `NullPointerBody` overrides them (`on_player_hit` -> `reveal_for_hit`). `arena/` gained no presentation reference; the hum (`NullPointerHum`, presentation/) is a child of BossView and syncs in `BossView._physics_process` (after SimClock's tick).
- Reveal timing: timers count down at the start of `_tick_body`; a hit resolved in COMBAT (after BOSS_HAZARDS) is visible on that frame and the next 9 = exactly 10 sim frames (60 for the pass-through). Tests assert both, plus a real slash and a real Echo Dash through CombatResolver.
- **Spec gap resolved:** the new phase-1 window D→L had no duck hint line, so the Story 4.4 suite (`test_duck_hint`, every window in the data needs an entry and a clip) failed. Added `hint_d_l` ("Quack. Weak window: D→L.") to `duck_lines.tres` and rendered its clip with `tools/render_duck_lines.gd` (the existing WAVs re-rendered byte-identical; `duck_clips.tres` re-serialised with new sub-resource ids, same content plus the new clip). Updated the line counts in `test_duck_lines` / `test_duck_bubble`. This adds one small WAV (~132 KB) the story did not list.
- Tests that assumed boss 1 had no boss now use boss 2 (F4) for the "no boss" path and assert the Null Pointer on boss 1 (`test_debug_keys`, `test_harvest_flow`).
- Not done here (by scope): attacks, whiff stun, decoys (5.2 / 5.3), Watch input (5.4), `bit_null.tres` (5.5); "locatable by sound / sight alone" is the 7.8 playtest. `deferred-work.md` still lists "Null Pointer has no BossDef" from 4.4; it can be closed.

### File List

- game/data/bosses/null_pointer/boss_def.tres (new)
- game/src/bosses/null_pointer/null_pointer_body.gd (new) + .uid
- game/src/presentation/null_pointer_hum.gd (new) + .uid
- game/tests/unit/test_null_pointer_body.gd (new) + .uid
- game/tests/integration/test_null_pointer_fight.gd (new) + .uid
- game/assets/audio/duck/hint_d_l.wav (new) + .wav.import
- game/data/duck/duck_lines.tres
- game/data/duck/duck_clips.tres
- game/src/arena/arena.gd
- game/src/bosses/framework/boss_controller.gd
- game/src/combat/combat_resolver.gd
- game/src/main/main.gd
- game/src/presentation/boss_view.gd
- game/src/ui/hud/hud.gd
- game/src/ui/hud/hud_frame.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_debug_keys.gd
- game/tests/unit/test_duck_bubble.gd
- game/tests/unit/test_duck_lines.gd
- game/tests/unit/test_font_coverage.gd
- game/tests/integration/test_harvest_flow.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md

### Review Findings

Code review 2026-11-11 (Blind Hunter, Edge Case Hunter, Acceptance Auditor): 0 decision_needed, 2 patch, 8 defer, 7 dismissed.

- [x] [Review][Patch] The falling `null` column vanished when the ghost sat in the bottom rows (AC 12); it now hangs above the body when it does not fit below [game/src/bosses/null_pointer/null_pointer_body.gd:trail_positions]
- [x] [Review][Patch] A hit or Echo Dash pass that cannot count (inactive, ROAR, DEFEATED) still revealed the ghost; reveal hooks now guard [game/src/bosses/null_pointer/null_pointer_body.gd:on_player_hit]
- [x] [Review][Defer] Fight 2 ships as an unattackable, mostly invisible damage sponge until Stories 5.2 and 5.4 — deferred, planned epic order
- [x] [Review][Defer] ROAR (phase change) hides the ghost; design call whether the roar should show the body — deferred, playtest
- [x] [Review][Defer] `reset_for_fight` clears `watch_held` while the key may still be held — deferred, Story 5.4 owns Watch
- [x] [Review][Defer] Drift continues while Watch is held (AC 10 wording, recorded as D-S51-7) — deferred, revisit in 5.4
- [x] [Review][Defer] `body_radius_tiles` >= 9 is not rejected by `BossDef.validate` — deferred, data only
- [x] [Review][Defer] Every BossView builds a NullPointerHum (one-off 22k-sample loop, static cached) — deferred, lazy-create if web profiling shows a hitch
- [x] [Review][Defer] Weak tests: `test_patched_stack_is_drawn_while_the_ghost_is_hidden` ends on `is_inside_tree()`, hum play/stop path is not exercised headless (audio locked) — deferred
- [x] [Review][Defer] `hint_d_l` clip `char_times` copy `hint_d_a`; `duck_clips.tres` ids were re-serialised — deferred, verify by ear in the browser

## Change Log

- 2026-11-11: Story 5.1 implemented: Null Pointer BossDef (HP 700, NULL drop, D→L / A→D, gaps 90 / 60, empty pools), NullPointerBody (invisible ghost, reveal timers, seeded integer drift, falling `null` column), CombatResolver reveal hooks, BossView ghost drawing, NullPointerHum (generated loop, Stream playback), per-fight sky comment, FIGHT boss 1 wiring, D→L duck hint line and clip; 28 new tests. Status -> review.
- 2026-11-11: Code review: 2 patches applied (column flips above the body at the bottom edge, reveal hooks guarded), 8 deferred, 7 dismissed; 2 new tests (1130 total). Status -> done.
