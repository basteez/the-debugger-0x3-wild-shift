---
baseline_commit: 340e57b
---
# Story 6.4: Corrupted Tiles, Corrupt Memory and Core Dump

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Open design questions are marked [design call] with the chosen default (D-S64-n); the implementer follows them or records a change in Completion Notes. Scope: the 32 x 18 corrupted-tile grid, the two tile attacks (Corrupt Memory in phases 1-3, Core Dump in phase 3), their data, the phase pools that gain them, their presentation, and the tests. NOT in scope: SIGSEGV and its register rotation (6.5), Reserved Write (6.6, cut #1), intro and ending screens (6.7/6.8), all game text (6.9), the Access Violation (done in 6.3, unchanged), final art and sound (7.x). -->

## Story

As a player,
I want the dragon to corrupt the arena floor in readable patterns,
so that positioning matters in the final fight.

**Requirements:** FR42 (Corrupt Memory and Core Dump; Access Violation already in 6.3), NFR1 (60 FPS in phase 3 with maximum hazards and particles, measured by hand in Chrome). Additional: cut ladder #4 (`FeatureFlags.segfault`, AD-12). Window: Nov 22–25 (Epic 6). Depends on: 3.2 (`PATCHED_FRAMES`, weak window, `attack_hazard_hit` ACTIVE-only), 3.4 (`hazard_positions` / `hazard_rects` presentation getters, D-S34-9), 3.5 (the one-hit-per-entry concern, see Dev Notes), 5.2 (locked-geometry TELL and `declared_positions`), 6.3 (`SegfaultBody`, `access_violation.gd`, the leaf folder, `FeatureFlags.segfault` wiring).

## Acceptance Criteria

**Pools and data**

1. **Given** `game/data/bosses/segfault/boss_def.tres`, **When** loaded, **Then** phase 1 and phase 2 have `attack_pool = [attack_access_violation, attack_corrupt_memory]`, phase 3 has `attack_pool = [attack_access_violation, attack_corrupt_memory, attack_core_dump]`, and Core Dump appears in no phase before 3. HP 1000, drop 0, the fixed line, the three weak windows (D→L 90, N→A 75, L→N 60) and the phase thresholds (100 / 66 / 33) are unchanged; `BossDef.validate()` returns no problems.
2. **And** `attack_corrupt_memory.tres` has `id = &"corrupt_memory"`, `tell = 60`, `active = 240`, `recovery = 40`, and `attack_core_dump.tres` has `id = &"core_dump"`, `tell = 60`, `active = 180`, `recovery = 60`. Both have a non-empty `tell_sfx` (`tell_corrupt_memory`, `tell_core_dump`) and an `attack_script` under `src/bosses/segfault/attacks/`.
3. **And** the 32 × 18 corrupted-tile grid is fixed in size, allocated once at fight start, cleared in place on every later fight start and retry, and never allocated inside `tick()`.

**Corrupt Memory (phases 1–3)**

4. **Given** Corrupt Memory is chosen, **When** its TELL runs (60 frames), **Then** 8–12 distinct tiles (the count and the cells drawn from the seeded sim RNG at TELL entry, D-S64-2 / D-S64-4) are marked `░` on the grid, all inside the 32 × 18 play area, and no damage is dealt during the tell.
5. **And** ACTIVE lasts 240 frames: each marked tile becomes a `▓` hazard, and a player centre that enters a hazard tile takes 1 HP through `PlayerHealth.queue_hit()` (invulnerability honoured). Standing still on a hazard tile does not re-hit (D-S64-5). Tiles outside the marked set never hurt.
6. **And** RECOVERY lasts 40 frames with no tile marked or hazardous; the grid is empty.

**Core Dump (phase 3)**

7. **Given** phase 3 and Core Dump is chosen, **When** its TELL runs (60 frames), **Then** the whole grid shows a checkerboard: the hazard parity (`(x + y)` odd, D-S64-6) is marked `░` and the safe parity is drawn as `·`, so the safe tiles are visible during the tell and no damage is dealt.
8. **And** ACTIVE lasts 180 frames: the hazard parity is `▓` and entering one takes 1 HP under the same entry rule as AC 5; the safe parity never hurts.
9. **And** RECOVERY lasts 60 frames with no tile marked or hazardous.

**Cancel, defeat and retry**

10. **Given** a phase change or the defeat cuts Corrupt Memory or Core Dump mid-attack, **When** the cut happens, **Then** `on_cancel` clears the marks and hazards at once, `on_recovery` does not run, and no tile is marked or hazardous in the following state (no `▓` visible after DEFEATED).
11. **And** a retry or fight restart starts with an empty grid: no marks, hazards or latched entry state carry over.

**Geometry and fairness**

12. **And** every tell and hazard position that `declared_positions` (or the tile getters) reports for either attack is inside the play area (the 5.2 on-screen rule, AC 5 pattern), and every hazard tile was marked for its full 60-frame tell before it became `▓` (no unannounced damage, Pillar 2).

**Determinism, isolation and presentation**

13. **And** the same seed produces the same marked cells and the same checkerboard on every run (replay determinism, AD / 2.1); no global RNG is used (the existing guard).
14. **And** no file under `src/bosses/*/attacks/` names `rng`, `body_contact_position`, `PlayerHealth`, `Player`, `Arena.` or `SimClock` (the `test_attack_isolation` forbidden list, which stays green with the two new attack files).
15. **And** `BossView` draws the tile states (`░` marked, `▓` hazard, `·` safe checkerboard) in ink `#E8E8E8` only; red `#FF4040` is not used; presentation never writes grid or sim state (AD-05).
16. **And** `game/tools/check_guards.sh` prints OK, and its Segfault leaf rule also names the new classes (`CorruptedTiles`, `CorruptMemory`, `CoreDump`) so they cannot leak outside `src/bosses/segfault/` (D-S64-9; closes the 6.3 deferred guard gap for new names).

**Cut path and performance**

17. **Given** `FeatureFlags.segfault` is off (`Game.segfault_enabled == false`), **When** the run reaches boss index 2, **Then** no grid is allocated, no tile attack is reachable, and the 5.6 cut path (Null Pointer → ENDING) holds unchanged.
18. **And** the GUT suite (headless, `-gexit`) passes with the flag on, and the Chrome F10 check of phase 3 with maximum hazards and particles is recorded in Completion Notes as a human check (NFR1). It is not automated and does not block this story; the final target-hardware check is in Epic 7.

## Tasks / Subtasks

### Group A: Data (AC: 1, 2)
- [x] Add `game/data/bosses/segfault/attack_corrupt_memory.tres` and `attack_core_dump.tres` (AttackDef, tell_sfx ids).
- [x] Update `boss_def.tres` pools per phase (AC 1); keep thresholds, windows and gaps.
- [x] Extend the `BossDef.validate` / data validation test with the pool sizes and the Core Dump phase-3-only rule.

### Group B: Grid and draw helpers (AC: 3, 4, 7, 13)
- [x] `game/src/bosses/segfault/corrupted_tiles.gd` (`class_name CorruptedTiles`, RefCounted): 32 × 18 `PackedByteArray` of states (clear / marked / hazard / safe-marked), `reset()` in place, mark / clear / query helpers, the entry latch (D-S64-5), and the two pickers (random distinct cells, checkerboard) that take the RNG as a parameter.
- [x] `SegfaultBody`: owns the grid (created on the first `reset_for_fight`, cleared afterwards), keeps the sim RNG reference from `_tick_body(ctx)`, and exposes the helper the attacks call (the attacks never name `rng`).
- [x] `touches_player` also asks the grid's entry latch while the body is ACTIVE on a tile attack (D-S64-5), alongside the existing body circle and `attack_hazard_hit`.

### Group C: Corrupt Memory and Core Dump (AC: 4–12)
- [x] `game/src/bosses/segfault/attacks/corrupt_memory.gd` (`extends BossAttack`): `on_tell` marks the drawn cells, `on_active` makes them hazard, `on_recovery` clears, `on_cancel` clears, `hazard_positions()` / marks getter for presentation, `declared_positions` for all marked cells.
- [x] `game/src/bosses/segfault/attacks/core_dump.gd` (`extends BossAttack`): the same hooks for the checkerboard; the safe parity is a presentation getter only.
- [x] Both attacks: no RNG, no player position, no `PlayerHealth` names (AC 14).

### Group D: Presentation (AC: 15)
- [x] `game/src/presentation/boss_view.gd`: draw the tile states via the attack getters, ink only, detected by method (6.3 pattern, no class names).

### Group E: Wiring and guard (AC: 16, 17)
- [x] `check_guards.sh`: add `CorruptedTiles|CorruptMemory|CoreDump` to the Segfault leaf rule grep (outside `src/bosses/segfault/`).
- [x] Confirm the Arena's by-path wiring loads the two new attack scripts through `boss_class_for` / `attack_for` with no new class name outside the folder.
- [x] `FeatureFlags.segfault` off: nothing new is allocated or reachable (AC 17).

### Group F: Tests (AC: 1–18)
- [x] `game/tests/unit/test_corrupted_tiles.gd`: grid size, in-place clear, no allocation in tick, entry latch (one hit per entry, none while standing still, none on the safe parity).
- [x] `game/tests/unit/test_corrupt_memory.gd`: 60 / 240 / 40 frame timings; count 8–12 over many seeds; distinct cells inside the play area; cancel and defeat clear; retry clears.
- [x] `game/tests/unit/test_core_dump.gd`: phase-3-only pool; 60 / 180 / 60 timings; parity; visibility of safe tiles in TELL; the 1 HP entry rule.
- [x] Extend `test_boss_fallback.gd` / `test_game_flow` only for the flag-off path (AC 17); keep the 6.3 cases green.
- [x] Run the full GUT suite headless and `bash game/tools/check_guards.sh`.

## Dev Notes

### Design context (what 6.4 must respect)

- The framework (`BossController`, 3.1) owns the FSM, pools, the no-triple-repeat rule, the weak window, Patched and defeat. The attacks add only their TELL / ACTIVE / RECOVERY behaviour; do not duplicate the FSM.
- Hazards reach the player only through `touches_player` / `attack_hazard_hit` and `PlayerHealth.queue_hit()`. No new damage path (D-011, NP-3).
- Attack files are scanned by `test_attack_isolation`: they may not name `rng`, `rand*`, `body_contact_position`, `player_position`, `contact_source`, `Player`, `Register`, `PlayerHealth`, `SimClock`, or `Arena.` (except `play_area` / `clamp_to_play_area`). Anything that needs the RNG or the player centre therefore lives in `segfault_body.gd` or `corrupted_tiles.gd` (outside `attacks/`, not scanned) and reaches the attack through a body method.
- `BossAttack` already has the presentation getters this story needs: `tell_marks()`, `hazard_positions()`, `hazard_rects()`, `declared_positions()`, `hazard_hit(p)` (ACTIVE only, through `attack_hazard_hit`).
- Pools are allocated at fight start and nothing is allocated in `tick()` (architecture: "corrupted tiles as a 32×18 grid").
- The GDD makes the tiles the boss's only interactive arena element (GDD "Interactive element: only Segfault's corrupted tiles").

### Current state of the code (read before editing)

- `game/src/bosses/segfault/attacks/` holds `access_violation.gd` only. `segfault_body.gd` (`class_name SegfaultBody`) owns the drift, the glyph body, `touches_player` (body circle OR `attack_hazard_hit`), `reset_for_fight`. There is no `corrupted_tiles.gd` yet (architecture line ~464 lists it in the leaf folder).
- `game/src/bosses/framework/boss_controller.gd`: `tick(ctx: SimContext)` passes `ctx.rng` to `_advance(rng)` (the only framework draw, `pick_next`); `_defeat()` calls `_cancel_attack()` first; `touches_player` at ~357; `attack_hazard_hit` at ~443.
- `game/src/bosses/framework/arena_context.gd`: `target_position()`, `body_contact_position()`, `target_facing()`, `player_effects`; no RNG handle.
- `game/src/bosses/null_pointer/attacks/*.gd` and `infinite_loop/attacks/*.gd` draw no RNG (D-S52-4 convention).
- `game/src/presentation/boss_view.gd` draws `tell_marks()`, `hazard_rects()`, `hazard_positions()` generically (lines ~361–374); the Segfault body is detected by method (`is_glyph_body`, 6.3).
- Tell SFX ids (`tell_access_violation`) appear in data and tests only; they are not registered with audio (see D-S64-8).
- Font: `game/assets/fonts/wildshift8*` (8 × 8). `▓▒░` were added in 6.3 (D-S63-6). `·` (U+00B7) must be checked by `test_font_coverage`; add it only if missing, as 6.3 did.

### Design calls (D-S64-n)

- **[design call] D-S64-1 Pools.** Phases 1 and 2 pool: `[access_violation, corrupt_memory]`; phase 3: `[access_violation, corrupt_memory, core_dump]`. Uniform pick (the framework's rule). The GDD's table is the source: Corrupt Memory P1–3, Core Dump P3. SIGSEGV (6.5) joins in P2–3 later.
- **[design call] D-S64-2 Where the random draws happen.** The tile count and cells are drawn from the sim RNG by `SegfaultBody` on the TELL-entry tick, using the `SimContext.rng` reference it keeps from `_tick_body(ctx)`. The attack asks the body for the cells through a method, because attack files may not name `rng`. Alternative if this reads badly: a `rng_source` Callable on `ArenaContext`, mirroring `target_source`. Record the choice in Completion Notes.
- **[design call] D-S64-3 One grid, owned by the body.** `CorruptedTiles` (RefCounted) is created on the first `reset_for_fight` and shared by both attacks; both clear it on `on_cancel` / `on_recovery`. Only one tile attack is live at a time (the boss FSM is serial), so the two attacks never overlap on the grid.
- **[design call] D-S64-4 Corrupt Memory is uniform.** 8–12 tiles, chosen uniformly per use (`randi_range(8, 12)`), distinct cells drawn uniformly over the 32 × 18 grid. No bias toward the player (the 60-frame tell is the fairness tool, not aim). The cells may sit under the dragon's band; the band is above row 6 and does not interact with the grid.
- **[design call] D-S64-5 Entry rule: one hit per entry.** A tile hits once each time the player's centre moves from a non-hazard tile into a hazard tile during ACTIVE. Standing still does not re-hit. A player already on a tile when ACTIVE starts is not hit until they leave and come back. The latch lives in `CorruptedTiles` and is updated once per sim tick from the body's contact check. Reason: a per-tick hazard would re-queue hits (the 3.5 Spit issue, deferred) and the 5.2 deferred note on one-hit latches. PlayerHealth invulnerability still applies on top.
- **[design call] D-S64-6 Core Dump checkerboard is per-tile, full grid.** Hazard parity: `(x + y)` odd (288 hazard tiles); safe: `(x + y)` even (288 tiles). The safe parity is drawn `·` in TELL and nothing in ACTIVE beyond the normal floor. The per-tile reading matches the GDD's "checkerboard" and "safe tiles visible"; a larger checker (2 × 2 cells) is the fallback if the 7.8 playtest finds it unreadable.
- **[design call] D-S64-7 Hazards exist only in ACTIVE.** Tiles are marked (`░`) in TELL, hazard (`▓`) in ACTIVE, and gone in RECOVERY. The grid is empty outside ACTIVE and TELL, so `hazard_hit` is false in RECOVERY (framework rule, 3.4).
- **[design call] D-S64-8 Tell SFX are data-only.** `tell_corrupt_memory` and `tell_core_dump` follow the `tell_access_violation` pattern: non-empty ids in data, no audio registration in this story. This leaves the cue silent, the same gap 5.2 recorded; register all tell ids in one pass in Epic 7 (7.2).
- **[design call] D-S64-9 Guard names.** The Segfault leaf rule in `check_guards.sh` adds `CorruptedTiles`, `CorruptMemory` and `CoreDump`, so the new classes cannot be named outside `src/bosses/segfault/`. This closes the new-name part of the 6.3 deferred item ("leaf rule does not cover AccessViolation / segfault data paths"); the data path `data/bosses/segfault/` stays uncovered and is recorded as still open.
- **[design call] D-S64-10 Presentation stays in the existing view.** No new view class: `BossView` draws the three tile states through the attack getters (ink only). Red is reserved for warnings (project rule).

### Architecture and rules that bind this story

- AD-06 / AD-12: attacks and the grid in `src/bosses/segfault/`; core code loads by path only; leaf rule enforced by `check_guards.sh`.
- NP-3: bosses never mutate the player or Register; the tile attacks do no register change.
- NP-4: the Patched path is unchanged; the tile attacks are not decoy targets (no `target_position()` use is needed).
- AD-01: durations are int sim frames; no `delta`, no `Timer`, no `await`, no `create_tween` in sim.
- AD-05: presentation reads the grid and the attacks; the view never writes sim state.
- Determinism: one seeded `RandomNumberGenerator` (`SimContext.rng`); no global `randi()`.

### Previous story intelligence

- 6.3 (done): `SegfaultBody`, `AccessViolation` (locked geometry, TELL-entry lock, ACTIVE-only `hazard_hit`), `boss_def_path_for(..., segfault_on)`, the glyph font additions (`▓▒`), the leaf guard, the defeat reassembly via `_draw_reassembly_cells`. Its deferred items relevant here: the leaf guard gap (D-S64-9) and "No test for the Segfault DEFEATED reassembly draw" (cover the new 24 + grid cells only if the draw changes).
- 6.2 (done): Dereference, N→A. Its gate notes do not touch this story.
- 6.1 (done): Ghost Echo, L→N, `ctx.target_position()` returns the live decoy. Not used by the tile attacks.
- 5.2 (done): Pointer Grab (locked geometry, `declared_positions` on-screen rule, `outline_circle`), Null Rain (multi-area hazard, no RNG in attacks). Deferred: "With invuln_frames 0 the attacks could queue a hit per ACTIVE tick; add a one-hit latch if invulnerability is retuned." D-S64-5 is that latch for tiles. Also "tell sfx not registered with audio" (D-S64-8).
- 3.5 (done): Semicolon Spit re-queues a hit each tick while overlapping (deferred, playtest 3.9). Do not copy that per-tick hit for tiles.
- 3.4 (done): `attack_hazard_hit` ACTIVE-only; `hazard_positions` / `hazard_rects` for presentation.

### Git intelligence

- Branch `story/6-4-corrupted-tiles-corrupt-memory-and-core-dump` at `340e57b` (Story 6.3 implementation), stacked on `6bb14e6` (6.2) and `00e7101` (6.1). Story pattern: data, pure grid and attack logic, presentation, tests, small wiring in `Arena` / `Main` only if needed.

### Latest technical information

- Godot 4.7.2-stable (pinned; do not upgrade), GUT 9.6.1, GDScript 2 only. Typed arrays, `@export`, `signal` only in `EventBus`. `PackedByteArray` for the grid. No new APIs needed.

### Project Context Rules

- Read-only defs at runtime; per-fight state (the grid, the latch, the marked cells) lives in `CorruptedTiles` / the attack instance and is cleared by `reset()` / `on_cancel()`.
- Integer sim state; floats for presentation only (D-S33-2). Tile cells are `Vector2i`.
- Tells ≥ 20 frames (60 here); `tell_sfx` non-empty; ids unique.
- Red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV); the grid uses ink `#E8E8E8` only.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: tells 60 / 60 / 60; actives 240 / 180; recoveries 40 / 60; count 8–12; grid 32 × 18; checkerboard 288 / 288; 1 HP per entry.
- Guards: `bash game/tools/check_guards.sh` (run from the worktree root).
- The NFR1 frame check is a Chrome F10 human check; record it in Completion Notes, do not fake it in a test.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.4: Corrupted Tiles — Corrupt Memory and Core Dump] (ACs, FR42, NFR1)
- [Source: _bmad-output/planning-artifacts/epics.md#Boss 3 — Segfault] (FR40–FR44, lines ~92–96)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 3 — Segfault (final)] (attack table: Corrupt Memory and Core Dump rows, fairness rules, lines ~407–435)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] (arena section: "Interactive element: only Segfault's corrupted tiles", ~line 314)
- [Source: _bmad-output/game-architecture.md#Pooled data entities, #AD-06, #AD-12, #NP-3, #NP-4, project structure line ~464]
- [Source: _bmad-output/implementation-artifacts/6-3-segfault-body-and-access-violation.md] (D-S63-n, the leaf folder, attack pattern)
- [Source: _bmad-output/implementation-artifacts/5-2-pointer-grab-and-null-rain.md] (locked TELL, `declared_positions`, D-S52-4)
- [Source: _bmad-output/implementation-artifacts/3-4-head-rush-and-constrict.md] (`attack_hazard_hit`, D-S34-9)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (invuln latch note from 5.2; Spit re-hit from 3.5; leaf guard gap from 6.3)
- [Source: _bmad-output/project-context.md] (leaf rule, attacks aim via `ctx.target_position()`, red reserved for warnings)

## Open questions (not blocking)

- D-S64-2: whether the RNG reaches the tile attacks through the body (default) or an `ArenaContext` handle; both keep the isolation test green.
- D-S64-5: the exact place of the entry latch update (in `touches_player`, which the body calls once per tick, or in a per-tick hook). The default is the body's contact check; a test pins one hit per entry either way.
- D-S64-6: a 1-tile checkerboard may read as noise at 288 hazard tiles; the 2 × 2 fallback is one constant away. Decide in the 7.8 playtest.
- D-S64-8: the tell cues stay silent until the Epic 7 audio pass; this is a known gap, not a 6.4 blocker.
- The F10 / NFR1 phase-3 measurement needs a human in Chrome; it is pending until then.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended pipeline

### Debug Log References

### Completion Notes List

- Data (AC 1-2): `attack_corrupt_memory.tres` (60 / 240 / 40, `tell_corrupt_memory`) and `attack_core_dump.tres` (60 / 180 / 60, `tell_core_dump`); pools P1-P2 `[access_violation, corrupt_memory]`, P3 `+ core_dump`. HP, drop, fixed line, windows, gaps and thresholds unchanged; `validate()` clean.
- Grid (AC 3, D-S64-3): `CorruptedTiles` (RefCounted), 576-byte `PackedByteArray` (CLEAR / MARKED / HAZARD / SAFE), allocated on the body's first `reset_for_fight`, cleared in place afterwards (and on `_on_attack_cancelled`, so a cut clears even without an arena context). Pickers: `mark_random(rng, count)` (rejection draw, distinct, seeded) and `mark_checkerboard()`.
- D-S64-2 kept as the default: the body stores `ctx.rng` in `_tick_body` (before the FSM step) and exposes `mark_random_tiles(min, max)`; the attacks never name the RNG (test_attack_isolation green).
- D-S64-5 latch: `CorruptedTiles.entry_hit(p, live)` is updated on every `SegfaultBody.touches_player` call (once per tick from `_check_contact`). "On" counts MARKED and HAZARD tiles, so a player standing on a marked tile when ACTIVE starts is not hit until they leave and return. While a tile attack runs the body does not ask `attack_hazard_hit` (that would hit every tick); the attacks' `hazard_hit` stays a pure ACTIVE-only query.
- Implementation detail: the MARKED -> HAZARD flip runs in `on_active` (idempotent), which first runs one tick after ACTIVE entry; the attacks' getters and `hazard_hit` derive TELL / ACTIVE from the boss state, so the first ACTIVE contact check and drawing already see the hazards (240 / 180 hazard ticks exactly).
- Presentation (AC 15, D-S64-10): `BossView._draw_tiles` draws `░` / `·` (TELL) and `▓` (ACTIVE) under the dragon via `tile_marks()` / `safe_tiles()` / `hazard_positions()`, detected by method (`is_tile_attack`), INK only.
- Font: `·` (U+00B7) was missing; added as a narrow glyph in `game/tools/gen_glyph_font.py` and regenerated `wildshift8.fnt` / `wildshift8_0.png` (112 glyphs); `test_font_coverage` covers the three tile glyphs.
- Guard (AC 16, D-S64-9): the Segfault leaf rule now also names `CorruptedTiles|CorruptMemory|CoreDump`. Still open: the data path `data/bosses/segfault/` is not covered by the guard.
- Spec contradiction (RESOLVED in review as a coordinator design call: AC text amended to 288 / 288): the story originally said 144 / 144, but a per-tile full-grid checkerboard on 32 x 18 = 576 tiles is 288 / 288. The per-tile full-grid rule (D-S64-6) was kept; tests pin 288 / 288. 288 hazard tiles would need a different pattern (playtest 7.8 can revisit together with the 2 x 2 fallback).
- Test adjustments: `test_access_violation.gd` now narrows the candidates to the claw (ClawBody) since the pools hold the tile attacks too.
- AC 17: flag off builds no Segfault body, so no grid or tile attack exists (`test_boss_fallback`); the 5.6 cut path is unchanged.
- Tests: new `test_corrupted_tiles.gd` (9), `test_corrupt_memory.gd` (11), `test_core_dump.gd` (11); extended `test_data_validation`, `test_font_coverage`, `test_boss_fallback`. Full headless GUT suite (unit + integration + replays): 1436 / 1436 passing. `check_guards.sh`: OK.
- NFR1 (AC 18): the Chrome F10 check of phase 3 with maximum hazards and particles is a human check and is PENDING (not automated, does not block; final check in Epic 7).
- D-S64-8: the tell SFX ids are data-only (silent until the Epic 7 audio pass).

### File List

- game/data/bosses/segfault/attack_corrupt_memory.tres (new)
- game/data/bosses/segfault/attack_core_dump.tres (new)
- game/data/bosses/segfault/boss_def.tres
- game/src/bosses/segfault/corrupted_tiles.gd (new)
- game/src/bosses/segfault/corrupted_tiles.gd.uid (new)
- game/src/bosses/segfault/attacks/corrupt_memory.gd (new)
- game/src/bosses/segfault/attacks/corrupt_memory.gd.uid (new)
- game/src/bosses/segfault/attacks/core_dump.gd (new)
- game/src/bosses/segfault/attacks/core_dump.gd.uid (new)
- game/src/bosses/segfault/segfault_body.gd
- game/src/presentation/boss_view.gd
- game/tools/check_guards.sh
- game/tools/gen_glyph_font.py
- game/assets/fonts/wildshift8.fnt
- game/assets/fonts/wildshift8_0.png
- game/tests/unit/test_corrupted_tiles.gd (new)
- game/tests/unit/test_corrupted_tiles.gd.uid (new)
- game/tests/unit/test_corrupt_memory.gd (new)
- game/tests/unit/test_corrupt_memory.gd.uid (new)
- game/tests/unit/test_core_dump.gd (new)
- game/tests/unit/test_core_dump.gd.uid (new)
- game/tests/unit/test_access_violation.gd
- game/tests/unit/test_boss_fallback.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_font_coverage.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/6-4-corrupted-tiles-corrupt-memory-and-core-dump.md

### Change Log

- 2026-11-12: Story 6.4 created (ready-for-dev) by gds-create-story, unattended.
- 2026-11-12: Story 6.4 implemented (corrupted-tile grid, Corrupt Memory, Core Dump, presentation, guard, tests); status review.
