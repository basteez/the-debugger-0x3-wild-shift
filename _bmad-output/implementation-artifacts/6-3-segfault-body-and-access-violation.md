---
baseline_commit: 6bb14e6
---
# Story 6.3: Segfault Body and Access Violation

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Open design questions are marked [design call] with the chosen default (D-S63-n); the implementer follows them or records a change in Completion Notes. Scope: the Segfault body (glitch dragon, drift band, glyphs, hurtbox), its BossDef data (HP 1000, no drop, fixed line, P1-P3 weak windows and gaps), its wiring as FIGHT boss 2 behind `FeatureFlags.segfault`, the sky comment, the first Segfault attack (Access Violation, the only attack in all three pools for now), and the defeat path (no drop, ENDING). NOT in scope: Corrupt Memory and Core Dump and the corrupted tiles (6.4), SIGSEGV and its register rotation (6.5), Reserved Write (6.6), intro and ending screens (6.7/6.8), all game text (6.9), final art and sound (7.x). -->

## Story

As a player,
I want a glitch dragon that claws across the arena,
so that the final bug feels big and dangerous.

**Requirements:** FR40 (Segfault body), FR41 (phases, weak windows, gaps), FR42 (Access Violation only; Corrupt Memory and Core Dump are 6.4). Additional: cut ladder #4 (`FeatureFlags.segfault`, AD-12). Window: Nov 22–25 (Epic 6). Depends on: 3.1 (boss framework), 3.2 (weak window and Patched), 3.4 (`attack_hazard_hit`, `declared_positions`), 5.1/5.2 (body and attack pattern, the Null Pointer as the model), 5.6 (`Game.segfault_enabled`, `route_after_defeat`, `drops_bit`), 6.1/6.2 (the Ghost Echo and Dereference combos the Segfault weak windows are built from).

## Acceptance Criteria

**Gating and spawn**

1. **Given** `FeatureFlags.segfault` is on (the shipped value), **When** the fight starts with `[A, D, L, N]` (FIGHT boss index 2), **Then** the boss is a `SegfaultBody` (`BossController` subclass in `game/src/bosses/segfault/`), created through `Arena.boss_class_for` by path, and `Main.boss_def_path_for(false, 2, false, segfault_on)` returns `Arena.SEGFAULT_DEF_PATH`.
2. **And** with `FeatureFlags.segfault` off, `boss_def_path_for` for index 2 returns `""` (placeholder header, no boss) and no code path names `SegfaultBody` or the `segfault/` folder by class (the leaf rule, AD-12, `check_guards.sh` extended). The cut-path routing itself is already covered by Story 5.6 and is not changed here.
3. **And** the sky comment reads `// HACK: do not read past this line` while this fight is live (`Hud.sky_for(&"segfault")`, restored to `Hud.SKY` on leave, the same mechanism as the Null Pointer's line, D-S51-4).
4. **And** Breakpoint and Watch stay unlocked for index 2 (existing `boss_index >= 1` rule); no change.

**Body**

5. **Given** the Segfault body is alive, **When** it is drawn, **Then** it is a glitch dragon of ≈ 6 × 4 tile glyphs drawn from `▓▒░#@!` (the glyph set of FR40), occupying the top third of the 32 × 18 play area (rows 0–5). Its glyph pattern is a fixed function of cell position (no `rng` in presentation).
6. **And** it moves at 2 tiles/s (2000 milli-tiles per second, integer, D-S33-2 style) horizontally across the top band, reflecting at the play-area edges inset by its half-width; it never leaves the top third and never leaves the play area ([design call] D-S63-1 for the motion pattern).
7. **And** the body is a hurtbox: `body_radius_tiles` is set ([design call] D-S63-2, default 2.0 tiles); player hits land on it through the existing `CombatResolver` path with no change. Body contact follows the framework default (`touches_player` in `BossController`): a dragon contact deals 1 HP ([design call] D-S63-5).
8. **And** the body's motion rule: it drifts in every live state except an attack's ACTIVE and RECOVERY (the same rule as Null Pointer, D-S51-7), so the claw's 12-frame hazard and its 50-frame recovery are read against a still target.
9. **And** the body's motion and the top-third band are pure sim state (integer milli-tiles, `SimContext.rng` only for the start direction); presentation reads them and never writes them (AD-05).

**Data and phases**

10. **Given** `game/data/bosses/segfault/boss_def.tres`, **When** loaded, **Then** `boss_id = &"segfault"`, `name_signature = "segfault"`, `max_hp = 1000`, `drop_bit = 0` (no drop), `fixed_line = "if (idx < len) buf[idx] = val;"`, `BossDef.validate()` returns no problems, and `Game.drops_bit(2, true)` stays false (its route is ENDING, not HARVEST).
11. **And** phase 1 has `hp_threshold = 100`, `weak_window = Vector2i(2, 3)` (D→L), `gap_frames = 90`; phase 2 has `hp_threshold = 66`, `weak_window = Vector2i(4, 1)` (N→A), `gap_frames = 75`; phase 3 has `hp_threshold = 33`, `weak_window = Vector2i(3, 4)` (L→N), `gap_frames = 60`.
12. **And** each phase's `attack_pool` is `[attack_access_violation]` only (one distinct attack is legal, D-S34-4). Corrupt Memory and Core Dump join in 6.4; SIGSEGV in 6.5.
13. **And** the phase thresholds drive the existing 66% and 33% jitter steps (D-S31-9): the body's jitter level rises at the same HP points as the framework, with no separate rule.

**Access Violation**

14. **Given** Access Violation is chosen in phase 1, 2 or 3, **When** its TELL starts, **Then** the claw's arc is drawn for the full 30-frame tell (`tell_marks` / outline, the claw arc on the body's lower edge facing the target), and the `EventBus.boss_tell_started(attack_id, tell_sfx)` path runs as for every attack (D-S31-16).
15. **And** the sweep's final area is drawn at its exact size during TELL ([design call] D-S63-3: a 6 × 2 tile rectangle, the sweep's reach), and nothing outside it is drawn as a hazard.
16. **Given** ACTIVE (12 frames), **When** the sweep is live, **Then** `hazard_hit(p)` is true for a player centre inside the locked rectangle only, ACTIVE only (`attack_hazard_hit` gating, D-S34-9); the hit goes through `PlayerHealth.queue_hit()` with the normal 1 HP and invulnerability rules.
17. **And** the rectangle is locked at TELL entry from `ctx.target_position()` (the player or a live Ghost Echo decoy, NP-3) and the claw's origin; a player who moves out of the locked rectangle during the 30-frame tell is not hit. The attack never reads the player position directly (`test_attack_isolation`).
18. **Given** RECOVERY (50 frames), **When** it runs, **Then** nothing is hazardous; the body is visible and the boss is punishable: an Echo Dash through the claw Patches the boss in P1 (the P1 window D→L, via the framework's PASS_THROUGH path, no new code).
19. **And** every declared position (the claw origin and the four corners of the rectangle) lies inside the 32 × 18 play area, checked by `declared_positions` in a test (AC 5 of Story 3.1).

**Defeat and fight flow**

20. **Given** the Segfault is defeated (HP 0), **When** the defeat plays, **Then** its glyphs reassemble into `if (idx < len) buf[idx] = val;` through the existing defeat presentation (the 5.6 reassembly path, reading `def.fixed_line`), and `Game` goes to ENDING with no HARVEST (`route_after_defeat(2, true)` is ENDING; no `Register` change).
21. **Given** a retry or a fight start, **When** the fight begins, **Then** the body is at full HP, phase 1, GAP, at its start position, with the band direction re-seeded by `begin_fight` (no state carried over).

**Tests and guards**

22. **Given** tests, **When** they run, **Then** `game/tests/unit/test_segfault_body.gd` covers AC 5–9 and 13 (glyph band, speed over a 300-tick seeded run, top-third bounds, drift rule per state, jitter steps), `game/tests/unit/test_access_violation.gd` covers AC 14–19 (tell length 30, ACTIVE 12, recovery 50, locked rectangle, hit only inside, ACTIVE only, declared positions in play area, a player who leaves the rectangle during TELL is not hit), and `test_data_validation.gd` covers AC 10–12 (def values and validation).
23. **And** `test_font_coverage.gd` (or a new assertion in it) confirms the glyphs `▓▒░#@!` used by the dragon are present in the font; if any is missing, the story adds it to the font data and records the change in Completion Notes ([design call] D-S63-6).
24. **And** `test_boss_fallback.gd` / the flag-off path: with `segfault` off, boss index 2 returns no boss def and the existing placeholder header stays; `test_attack_isolation.gd` passes with the new attack in `src/bosses/segfault/attacks/` (no `rng`, `Player`, `Register`, `PlayerHealth`, `SimClock`, `body_contact_position`).
25. **And** `bash game/tools/check_guards.sh` passes; the full GUT suite passes headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. The `godot` on PATH is not available here; use the absolute path. Replays (`game/tests/replays/test_replays.gd`) stay green (no recorded replay reaches boss index 2).

## Tasks / Subtasks

### Group A: Data (AC: 10, 11, 12)
- [x] A1. Create `game/data/bosses/segfault/attack_access_violation.tres` (`AttackDef`: id `&"access_violation"`, tell 30, active 12, recovery 50, `exclusive = false`, `recovery_if_no_breakpoint = 0`, `tell_sfx` non-empty placeholder per D-S31-16, script `res://src/bosses/segfault/attacks/access_violation.gd`).
- [x] A2. Create `game/data/bosses/segfault/boss_def.tres` (HP 1000, drop 0, fixed line, `name_signature = "segfault"`, `body_radius_tiles = 2.0`, three `PhaseDef` sub-resources with the windows and gaps of AC 11, each pool `[attack_access_violation]`), mirroring `data/bosses/null_pointer/boss_def.tres`.
- [x] A3. Add the Segfault def to `test_data_validation.gd` (values of AC 10–12).

### Group B: Body controller (AC: 5–9, 13, 21)
- [x] B1. Create `game/src/bosses/segfault/segfault_body.gd` (`class_name SegfaultBody extends BossController`): integer milli-tile position inside the top band, horizontal drift at 2000 mtps, reflection at the inset edges, the drift rule of AC 8 in `_tick_body`, start direction from `SimContext.rng` in `reset_for_fight` or the first tick.
- [x] B2. Expose the body's `band_rect()` (top third, tiles) and `glyph_at(cell)` (pure function of position, from `▓▒░#@!`) for presentation; no `rng` in these.
- [x] B3. `Arena.boss_class_for`: `SEGFAULT_DEF_PATH` maps to `SegfaultBody` via `load(SEGFAULT_BODY_PATH)` (string path, as the Breakpoint and Watch wiring do), so core code names no class (AD-12).
- [x] B4. `Main.boss_def_path_for`: add the index 2 branch behind the flag (a `segfault_on: bool = true` parameter, passed from `Game.segfault_enabled` at the call site, D-S63-4); index 2 returns `""` when the flag is off.

### Group C: Access Violation (AC: 14–19)
- [x] C1. Create `game/src/bosses/segfault/attacks/access_violation.gd` (`extends BossAttack`): lock the claw origin and the 6 × 2 rectangle in `on_tell` from `ctx.target_position()` and `ctx.target_facing()`, `hazard_hit` ACTIVE-only and rectangle-only, `on_recovery` / `on_cancel` / `reset` clear the lock, `tell_marks` / `outline` draw the arc and rectangle during TELL and the rectangle during ACTIVE, `declared_positions` for AC 19.
- [x] C2. The attack draws no `rng` (D-S52-4 precedent) and reads only `ArenaContext` getters.

### Group D: Presentation (AC: 5, 14, 15, 20, 23)
- [x] D1. A `SegfaultBodyView` (or the existing `boss_view.gd` branch) draws the dragon's glyph grid from `glyph_at`, the claw arc and the sweep rectangle from the attack's getters, and the defeat reassembly through the existing 5.6 path. Presentation reads only; it writes no sim state (AD-05).
- [x] D2. `Hud.sky_for(&"segfault")` returns `// HACK: do not read past this line`; `Hud.SKY` otherwise.

### Group E: Wiring and flag (AC: 1, 2, 4)
- [x] E1. `Main`/`Arena` read `Game.segfault_enabled` once (the 5.6 startup read); no new flag read in sim code.
- [x] E2. `check_guards.sh`: add a leaf-rule line for `SegfaultBody` and `segfault/` names outside `src/bosses/segfault/` (the same form as the Breakpoint and Watch lines).

### Group F: Tests (AC: 22–25)
- [x] F1. `test_segfault_body.gd`, `test_access_violation.gd` (cases of AC 22).
- [x] F2. Extend `test_data_validation.gd` and `test_font_coverage.gd` (AC 10–12, 23).
- [x] F3. Run GUT and `check_guards.sh`; record the flag-off run in Completion Notes (AC 24) by temporarily setting `segfault = false` in a local copy only, not committed.

## Dev Notes

### Design context (what 6.3 must respect)

- The framework (`BossController`, Story 3.1) owns the FSM, pools, the no-triple-repeat rule, the ROAR, the weak window, Patched and defeat. The body subclass adds motion only (`_tick_body`, `_on_phase_reset`, `_pick_candidates`). Do not duplicate the FSM.
- Attacks implement `on_tell`, `on_active`, `on_recovery`, `on_cancel`, `hazard_hit`, the presentation getters and `declared_positions` (Story 5.2 pattern; Pointer Grab is the closest model: a locked centre in TELL, `hazard_hit` gated on ACTIVE through `attack_hazard_hit`).
- Hazards reach the player only through `touches_player` / `attack_hazard_hit` and `PlayerHealth.queue_hit()`. No new damage path (D-011).
- Attacks aim only through `ctx.target_position()` / `ctx.target_facing()`; `test_attack_isolation` scans `src/bosses/*/attacks/*.gd` and forbids the forbidden members.
- An attack pool of one distinct attack is legal (D-S34-4); `PhaseDef.validate` rejects only an empty-distinct non-empty pool.
- Weak windows are bit pairs (`Register.Bit`: ATTACK 1 = A, DASH 2 = D, LOOP 3 = L, NULL_BIT 4 = N). P2 N→A is `Vector2i(4, 1)`; P3 L→N is `Vector2i(3, 4)`. The GDD table and epics agree on these.
- Cut ladder: the Segfault module is a leaf folder (`src/bosses/segfault/`). Nothing outside it names its classes; the wiring loads by path (AD-12, `check_guards.sh`).

### Current state of the code (read before editing)

- `game/src/bosses/segfault/attacks/` exists and is empty (`.gitkeep`). `game/data/bosses/segfault/` exists and is empty.
- `game/src/core/feature_flags.gd`: `segfault` already exists (cut #4, `true` in `feature_flags.tres`). `Defs.FEATURE_FLAGS` and `Game.segfault_enabled` (Story 5.6) are the read path.
- `game/src/autoloads/game.gd`: `LAST_BOSS_INDEX = 2`, `route_after_defeat(index, segfault_on)` sends index 2 to ENDING, `drops_bit(index, segfault_on)` is true only for HARVEST routes, so Segfault drops nothing automatically. `last_fight_index(segfault_on)` is 2 with the flag on.
- `game/src/register/register.gd`: `fight_start_for_boss(2)` is `[ATTACK, DASH, LOOP, NULL_BIT]` (already in place).
- `game/src/main/main.gd` `boss_def_path_for` (line ~315): index 0 and 1 branches exist; index 2 returns `""` today (the placeholder header). `breakpoint_unlocked_for` / `watch_unlocked_for` already hold for index >= 1.
- `game/src/arena/arena.gd`: `INFINITE_LOOP_DEF_PATH`, `NULL_POINTER_DEF_PATH`, `boss_class_for(path)` (line ~284); the Breakpoint and Watch paths are loaded by `load(path) as GDScript`.
- `game/src/ui/hud/hud.gd`: `SKY`, `SKY_NULL_POINTER`, `sky_for(boss_id)` (line ~87).
- `game/src/bosses/framework/boss_controller.gd`: `touches_player` (line ~357) is the body circle (`body_center_px` within `_body_radius_px`), the framework default contact; `attack_hazard_hit` (line ~443) is ACTIVE-only; `on_player_hit` / `on_pass_through` hooks (lines ~396, ~400); `_on_phase_reset` (line ~339).
- `game/src/bosses/null_pointer/null_pointer_body.gd`: the model for body motion (integer milli-tiles, drift per state, reset in `reset_for_fight`).
- `game/src/bosses/null_pointer/attacks/pointer_grab.gd`: the model for a locked-geometry TELL attack, `declared_positions`, `outline_circle`, `tell_glyph`.
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`: the model for a body with a non-trivial, integer, seeded motion.
- Glyph font: `game/assets/fonts/wildshift8*` (8 × 8 CP437-style). `test_font_coverage.gd` checks glyph coverage (AC 23).

### Design calls (D-S63-n)

- **[design call] D-S63-1 Motion: a horizontal drift in the top band.** The dragon drifts left and right at 2 tiles/s across rows 0–5, reflecting at the edges inset by half its width (3 tiles). The start direction is the only `rng` draw. Vertical position is fixed at the band's centre so the body stays inside the top third. A vertical bob or a turn-around on the player's side are rejected: they would make the tell's position ambiguous. The GDD gives speed and band only.
- **[design call] D-S63-2 Hurtbox radius 2.0 tiles.** A circle that covers the 6 × 4 body's centre region, large enough that a player can hit it from the arena's middle. Tune in the 7.8 playtest.
- **[design call] D-S63-3 Access Violation geometry: a 6 × 2 tile sweep rectangle.** At TELL entry the attack locks (a) the claw origin on the body's lower edge at the body's x, and (b) the target's row (the row of `ctx.target_position()`), and draws a 6-tile-long, 2-tile-tall rectangle from the claw origin toward the target's horizontal side, its rows being the locked row and the one below. The sweep is the rectangle; the arc is drawn on the lower edge from the claw origin toward the rectangle (presentation only). A player who moves out of the locked rows during the 30-frame tell is not hit, which keeps the tell readable (Pillar 2). The exact size is drawn during TELL (AC 15).
- **[design call] D-S63-4 `boss_def_path_for` takes the flag as a parameter.** `Main.boss_def_path_for(debug_test_boss, boss_index, practice, segfault_on = true)`. The default keeps existing test callers compiling; every production call passes `Game.segfault_enabled` (the same choice as D-S56-11).
- **[design call] D-S63-5 Body contact is the framework default.** The Segfault body is a contact hazard (1 HP, `touches_player` body circle), unlike the Null Pointer ghost (D-S51-8). A dragon that moves into the player is expected; the Infinite Loop's body is a contact hazard too. If playtests show ambush deaths, switch to a no-contact override in one place.
- **[design call] D-S63-6 Glyph coverage.** The dragon's glyphs `▓▒░#@!` must render in the 8 × 8 font. The font is CP437-style, so `▓▒░` should be present; the story verifies this in `test_font_coverage` and adds any missing glyph to the font data only if the test fails (recorded in Completion Notes).
- **[design call] D-S63-7 One attack in each pool for this story.** Access Violation alone in P1–3 (AC 12). The phase pools grow in 6.4 and 6.5, so the Segfault fight in this story is a single-attack fight with the Patched cycle; the GAP-only phases of 5.1 do not apply (the pool is not empty).

### Architecture and rules that bind this story

- AD-06 / AD-12: boss body and attacks in `src/bosses/segfault/`; core code loads it by path only; the leaf rule is enforced by `check_guards.sh`.
- NP-3: bosses never mutate the player or Register; the Access Violation does no register change (SIGSEGV is 6.5).
- NP-4: the Patched path is unchanged (`WeakWindowTracker`, `attack_hazard_hit` for player hits on the body). Access Violation is not a decoy target; the Ghost decoy (6.1) is read only through `ctx.target_position()`.
- AD-01: all durations are int sim frames; no `delta`, no `Timer`, no `await`, no `create_tween` in sim.
- AD-05: presentation reads the body and the attack; the Segfault view never writes sim state.

### Previous story intelligence

- 6.1 / 6.2 (done): the Ghost Echo and Dereference combos. The Segfault weak windows (D→L, N→A, L→N) are the ones these combos complete. 6.1 made `ctx.target_position()` return the live decoy, so Access Violation's lock (AC 17) must use the same accessor.
- 5.1 (done): Null Pointer body, drift rule per state (D-S51-7), body radius (D-S51-5), sky comment per fight (D-S51-4), defeat reassembly path (5.6). The Segfault body follows the same shape.
- 5.2 (done): Pointer Grab is the locked-geometry TELL attack; its `declared_positions` on-screen check and `outline_circle` are the pattern. Its review found that a body hidden at the bottom edge loses its trail: keep the Segfault body and its sweep inside the band.
- 5.6 (done): `Game.segfault_enabled`, `route_after_defeat`, `drops_bit`, `last_fight_index`. Flag-off fallback is already implemented; this story must keep it passing (AC 2, AC 24).
- 3.2 / 3.4 (done): `PATCHED_FRAMES = 180`, weak-window tracker, `attack_hazard_hit` ACTIVE-only, Constrict's ring-shrink pattern for a moving attack shape.

### Git intelligence

- Branch `story/6-3-segfault-body-and-access-violation` at `6bb14e6` (Story 6.2), stacked on `00e7101` (Story 6.1) and `ac51a03`. Story pattern: data, pure controller, one attack, presentation, tests, small wiring in `Arena` / `Main`.

### Latest technical information

- Godot 4.7.2-stable (pinned; do not upgrade), GUT 9.6.1, GDScript 2 only. Typed arrays, `@export`, `signal` only in `EventBus`. `Vector2`, `Rect2`, `RefCounted`, static pure functions only in sim. No new APIs needed.

### Project Context Rules

- Read-only defs at runtime; per-fight attack state (the locked rectangle) lives in the attack script instance and is cleared by `reset()` / `on_cancel()`.
- Integer sim state; floats for presentation only (D-S33-2).
- Tells ≥ 20 frames (30 here); `tell_sfx` non-empty; ids unique.
- Red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV); the dragon and the claw use ink `#E8E8E8` only.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: HP 1000; tells 30 / 12 / 50; drift 2 tiles/s; band rows 0–5; weak windows; gaps 90 / 75 / 60; defeat to ENDING with no drop.
- Guards: `bash game/tools/check_guards.sh`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.3: Segfault Body and Access Violation] (ACs, FR40, FR41, FR42)
- [Source: _bmad-output/planning-artifacts/epics.md#Boss 3 — Segfault] (FR40–FR44 lines ~90–96)
- [Source: _bmad-output/planning-artifacts/epics.md#Cut ladder, tooling and quality] (AD-12, FeatureFlags)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 3 — Segfault (final)] (table of phases and attacks, lines ~407–435)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Cut ladder for v1.0] (cut #4 = Segfault)
- [Source: _bmad-output/game-architecture.md#AD-12, #NP-3, #NP-4, ADR-04, project structure line ~464 (segfault/ as a cut-ladder leaf)]
- [Source: _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md] (body pattern, D-S51-n)
- [Source: _bmad-output/implementation-artifacts/5-2-pointer-grab-and-null-rain.md] (locked-geometry TELL attack, D-S52-n)
- [Source: _bmad-output/implementation-artifacts/3-1-reusable-boss-framework.md] (FSM, pools, D-S31-n)
- [Source: _bmad-output/implementation-artifacts/5-6-null-pointer-tutorials-defeat-and-null-harvest.md] (D-S56-3, D-S56-4, D-S56-8, D-S56-11)
- [Source: _bmad-output/implementation-artifacts/6-1-ghost-echo-combo.md] (decoy as `ctx.target_position()`)
- [Source: _bmad-output/project-context.md] (leaf rule, attacks aim via `ctx.target_position()`, red reserved for warnings)

## Open questions (not blocking)

- D-S63-1: the drift pattern (horizontal only) is the default; playtests may want a faster turnaround near the player's column.
- D-S63-3: the sweep's 6 × 2 shape is a design call against the GDD's "6-tile sweep"; the arc may read better as a sweep line. Final look in 7.x.
- D-S63-5: body contact is on by default; if the fight feels unfair, the Null Pointer precedent (no contact) is one override away.
- The Segfault's defeat reassembly reuses the 5.6 path; if the reassembly reads boss-specific text, it must read `def.fixed_line` only (6.9 audits the text).

## Dev Agent Record

### Agent Model Used

Claude Opus (gds-dev-story, unattended pipeline).

### Debug Log References

- Full GUT suite headless: 99 scripts, 1402 tests, all passing (replays included). `bash game/tools/check_guards.sh`: OK.
- Flag-off run (AC 24, F3): `segfault = false` set in `game/data/config/feature_flags.tres` locally, suite run, value restored (not committed). The game runs (no script error, no crash): boss index 2 resolves to no boss def, the placeholder header and `Hud.SKY` stay, and the 5.6 cut path (Null Pointer -> ENDING, no NULL drop) holds. The only failures were tests that assert the shipped value (`test_feature_flags` "segfault ships on", the F4 / F8 Fight-3 jump cases in `test_debug_keys`, `test_game_flow` Fight 3 -> ENDING), as expected when the shipped flag is flipped. The two 6.3 cases in `test_debug_keys` now set `Game.segfault_enabled` explicitly so they do not depend on the shipped value.

### Completion Notes List

- Data: `attack_access_violation.tres` (30 / 12 / 50, `tell_access_violation`) and `boss_def.tres` (HP 1000, drop 0, fixed line, radius 2.0, P1 D→L 90, P2 N→A 75, P3 L→N 60, each pool `[access_violation]`).
- `SegfaultBody` (leaf `src/bosses/segfault/`): integer milli-tile drift at 2000 mtps (remainder in 1/60 milli-tiles), centre row fixed at band centre (3 tiles), x reflected inside [3, 29] tiles, start direction is the only RNG draw (first drifting tick after reset, so `begin_fight` re-seeds it). No drift in ACTIVE / RECOVERY (drifts in GAP, TELL, ROAR). `band_rect()`, `glyph_at(cell)` (fixed 6 × 4 pattern `DRAGON_ROWS` from `▓▒░#@!`), `cell_centres()` / `cell_glyphs()` for the view and the reassembly. `touches_player` = framework body circle (D-S63-5, contact ON) OR `attack_hazard_hit` (the framework default circle alone would never let the claw hit).
- Access Violation: locks the claw origin (body x, 2 tiles below centre) and the 6 × 2 sweep at TELL entry from `ctx.target_position()` only (D-S63-3; `target_facing()` is not needed since the side comes from the aim's x, so C1's mention of it is not used). Rectangle clamped into the play area; `hazard_hit` ACTIVE-only, edges inclusive; `hazard_rects()` in TELL + ACTIVE, `claw_arc()` polyline and `!` tell mark in TELL; `declared_positions` = origin + 4 corners. No RNG, isolation test green.
- Wiring: `Arena.SEGFAULT_DEF_PATH` / `SEGFAULT_BODY_PATH`, `boss_class_for` loads the body script by path; `Main.boss_def_path_for(..., segfault_on = true)` (D-S63-4), production call passes `Game.segfault_enabled` (the 5.6 startup read; no new flag read). `Hud.SKY_SEGFAULT` + `sky_for(&"segfault")`. `check_guards.sh` leaf rule: `SegfaultBody` or `src/bosses/segfault/` outside the folder (only the Arena's `SEGFAULT_BODY_PATH` constant is allowed).
- Presentation: `BossView` detects the dragon by method (`is_glyph_body`, never names the class), draws the 24 glyph cells (HP jitter, ROAR inverts), the attack via the existing getters (rect outline, double outline in ACTIVE, `!`), the claw arc, the Patched stack and damage number. Defeat: the 3.8 reassembly was generalised to `_draw_reassembly_cells(sources, glyphs)` (Infinite Loop unchanged), so the 24 dragon cells move into `if (idx < len) buf[idx] = val;` (30 cells, the extra 6 pop in at the swap).
- D-S63-6: the font lacked `▓` and `▒` (`░` was present). Added both as wide 8 × 8 glyphs in `game/tools/gen_glyph_font.py` and regenerated `wildshift8.fnt` / `wildshift8_0.png` (111 glyphs); `test_font_coverage` now covers the dragon glyphs, the sky line, the header and the fixed line.
- New design call D-S63-8 (spec gap): the Segfault's weak windows N→A and L→N are new, and `test_duck_hint` requires a hint catalogue entry and a pre-rendered clip for every window in the data. Added `hint_n_a` / `hint_l_n` to `duck_lines.tres` (the mechanical `DuckHint.window_text` template, no authored text; the template counts once in the D-039 budget) and rendered their clips with `tools/render_duck_lines.gd` (wav + `duck_clips.tres` regenerated; existing clips byte-identical, only sub-resource ids churned). `test_duck_lines` / `test_duck_bubble` counts updated (10 -> 12 entries).
- Existing tests that used boss 2 as "no boss" (`test_debug_keys`, `test_null_pointer_body`) now assert the Segfault with the flag on and the placeholder with it off; the no-boss debug-key cases use the Shift+F2 sandbox.
- AC 18 (Echo Dash through the claw Patches in P1) relies on the framework PASS_THROUGH path with no new code; not separately tested here (covered by the 3.2 / 6.1 combo tests).
- Human check (not run): play Fight 3 in Chrome with `?debug` (F4) to see the dragon, the claw tell and the reassembly.

### File List

- game/data/bosses/segfault/attack_access_violation.tres (new)
- game/data/bosses/segfault/boss_def.tres (new)
- game/data/bosses/segfault/.gitkeep (deleted)
- game/src/bosses/segfault/segfault_body.gd (new, + .uid)
- game/src/bosses/segfault/attacks/access_violation.gd (new, + .uid)
- game/src/bosses/segfault/attacks/.gitkeep (deleted)
- game/src/arena/arena.gd
- game/src/main/main.gd
- game/src/ui/hud/hud.gd
- game/src/presentation/boss_view.gd
- game/tools/check_guards.sh
- game/tools/gen_glyph_font.py
- game/assets/fonts/wildshift8.fnt
- game/assets/fonts/wildshift8_0.png
- game/data/duck/duck_lines.tres
- game/data/duck/duck_clips.tres
- game/assets/audio/duck/hint_n_a.wav (new, + .import)
- game/assets/audio/duck/hint_l_n.wav (new, + .import)
- game/tests/unit/test_segfault_body.gd (new, + .uid)
- game/tests/unit/test_access_violation.gd (new, + .uid)
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_font_coverage.gd
- game/tests/unit/test_debug_keys.gd
- game/tests/unit/test_null_pointer_body.gd
- game/tests/unit/test_duck_lines.gd
- game/tests/unit/test_duck_bubble.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-12: Story 6.3 created (ready-for-dev) by gds-create-story, unattended.
- 2026-11-12: Implemented (gds-dev-story): Segfault body and data, Access Violation, wiring behind FeatureFlags.segfault, sky comment, dragon view and reassembly, leaf guard, `▓▒` glyphs, N→A / L→N duck hint entries and clips; tests added. Status -> review.
