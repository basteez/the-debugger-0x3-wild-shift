---
baseline_commit: 5d7a2e6
---

# Story 5.2: Pointer Grab and Null Rain

Status: done
<!-- Created unattended by gds-create-story (pipeline, 2026-11-11). Open design questions are marked [design call] with the chosen default (D-S52-n); the implementer follows them or records a change in Completion Notes. Scope: the two Null Pointer attacks that fill both phase pools (Pointer Grab, Null Rain), their BossAttack scripts and AttackDef data, the shared attack-hazard presentation they need (2x2 areas, `*` tell glyph), the body's contact rule resolved for attacks (D-S51-8), and the weak-window / Patched checks during visible recovery. NOT in scope: Dangling Pointers and decoys (5.3), the NullPointerException whiff stun (5.3), the Watch input and reveal (5.4), `bit_null.tres` (5.5), the Null Pointer tutorial lines (5.6). -->

## Story

As a player,
I want the ghost's attacks to reveal it,
so that dodging gives me the chance to strike back.

**Requirements:** FR39 (Null Pointer phases and attacks). Additional: GDD "Boss 2 — Null Pointer" attack table, GDD weak-window table, architecture AD-06 (`BossAttack` per attack, timings in `AttackDef.tres`), project-context rules (tell >= 20 frames and non-empty `tell_sfx`; attacks aim only via `ctx.target_position()`; no untelegraphed damage).

## Acceptance Criteria

**Pointer Grab**

1. **Given** phase 1 or phase 2 and Pointer Grab is chosen, **When** its TELL runs, **Then** it lasts 40 frames, a `*` glyph is drawn at the grab centre (D-S52-2), and no damage is dealt during the tell.
2. **And** ACTIVE lasts 10 frames: a player centre inside the grab circle (radius 1 tile, D-S52-2) during those frames takes 1 HP through `PlayerHealth` (the existing contact path, invulnerability honoured); a player outside it takes nothing.
3. **And** RECOVERY lasts 60 frames, the ghost is visible for all of them (Story 5.1 visibility rule), and the grab deals nothing during recovery.

**Null Rain**

4. **Given** phase 1 or phase 2 and Null Rain is chosen, **When** its TELL runs, **Then** it lasts 45 frames and draws 5 marked areas, each exactly 2 x 2 tiles (outline only, no damage) (D-S52-3, D-S52-10).
5. **And** ACTIVE lasts 20 frames: a player centre inside any of the 5 areas takes 1 HP through `PlayerHealth`; the areas do nothing outside ACTIVE.
6. **And** RECOVERY lasts 40 frames, the ghost is visible, and no area is drawn or active.

**Pools, cut and hazards**

7. **Given** `null_pointer/boss_def.tres`, **When** loaded, **Then** the attack pool of phase 1 and of phase 2 is `[pointer_grab, null_rain]` (D-S52-6), `BossDef.validate()` returns no problems, and the Story 5.1 values (HP 700, windows, gaps, drop) are unchanged.
8. **And** every attack has a tell >= 20 frames and a non-empty `tell_sfx` (`&"tell_pointer_grab"`, `&"tell_null_rain"`, D-S52-8), and `AttackDef.validate()` passes for both.
9. **And** an attack's hazard is live only in its ACTIVE state: `hazard_hit` answers false in TELL, RECOVERY, GAP, ROAR and DEFEATED (the `BossController.attack_hazard_hit` gate), and a phase change or defeat mid-attack clears the hazard without `on_recovery` (`on_cancel`).
10. **And** the body's own contact is off (D-S52-1): with no live attack hazard, `touches_player` is false anywhere; the ghost body never damages the player by itself.

**Weak window during visible recovery**

11. **Given** the ghost is visible in an attack's RECOVERY, **When** I Echo Dash through it in phase 1 (D->L weak window), **Then** the weak window completes and Patched is applied; **and** **when** I Dash Strike it in phase 2 (A->D), **Then** the same happens. The existing CombatResolver path is used; no new combo or damage code (verified by test, through the Story 5.1 boss-hit and pass-through hooks).

**Determinism and isolation**

12. Both attacks draw no RNG and read the aim point only through `ArenaContext.target_position()` (the existing `test_attack_isolation` guard covers the new files automatically). Same aim and same tick give the same areas. Note (approved deviation): attacks read aim via `ArenaContext.target_position()`, and the Pointer Grab additionally reads `ArenaContext.target_facing()`.
13. Every tell mark and hazard position of both attacks, against an aim at each play-area corner, lies inside the play area (`declared_positions`, Pillar 2, as in Story 3.4 AC 5).

**Tests**

14. Unit tests cover AC 1–6, 9, 10, 12, 13 (timings, hazard gates, cancel, areas, on-screen positions) in `game/tests/unit/test_null_pointer_attacks.gd`. AC 7–8 are data tests in `test_data_validation.gd`.
15. An integration test in `game/tests/integration/test_null_pointer_fight.gd` runs the fight from FIGHT boss 1 with a fixed seed through phase 1 and phase 2 (both attacks at least once), with no `Log.error`, and covers AC 11.
16. Existing suites (`test_boss_controller`, `test_data_validation`, `test_combat_resolver`, `test_attack_isolation`, `test_null_pointer_body`, `test_duck_hint`) stay green. Full GUT suite and `check_guards` pass.

## Tasks / Subtasks

- [x] Task 1: AttackDef data (AC: 7, 8)
  - [x] 1.1 Create `game/data/bosses/null_pointer/attack_pointer_grab.tres` (`id = &"pointer_grab"`, `tell = 40`, `active = 10`, `recovery = 60`, `tell_sfx = &"tell_pointer_grab"`) and `attack_null_rain.tres` (`id = &"null_rain"`, `tell = 45`, `active = 20`, `recovery = 40`, `tell_sfx = &"tell_null_rain"`), mirroring `infinite_loop/attack_constrict.tres`.
  - [x] 1.2 Fill `attack_pool` of both phases in `null_pointer/boss_def.tres` with both attacks (the pool is `Array[AttackDef]`; keep the Story 5.1 values).
  - [x] 1.3 Extend `test_data_validation.gd` for the two attack defs and the pool contents.
- [x] Task 2: Framework additions (AC: 9, 13; D-S52-5)
  - [x] 2.1 `game/src/bosses/framework/boss_attack.gd`: add two virtuals with defaults: `hazard_rects() -> Array[Rect2]` (empty; the 2x2 areas, in arena-local px) and `tell_glyph() -> String` (default `"!"`, so existing attacks do not change). Additive only.
  - [x] 2.2 `game/src/presentation/boss_view.gd` `_draw_attack`: draw `hazard_rects()` as outlines at their exact size and use `tell_glyph()` for tell marks. Presentation only; no sim writes (AD-05).
- [x] Task 3: Attack scripts (AC: 1–6, 9, 12, 13)
  - [x] 3.1 `game/src/bosses/null_pointer/attacks/pointer_grab.gd` (`class_name` optional, `extends BossAttack`): `on_tell` locks the grab centre to `ctx.target_position()` (clamped into the play area); `hazard_hit(p)` is true when `p` is within 1 tile of the centre; `tell_marks()` returns the centre; `tell_glyph()` returns `"*"`; `declared_positions` returns the centre and the four circle extremes; `reset()` and `on_cancel()` clear the centre.
  - [x] 3.2 `game/src/bosses/null_pointer/attacks/null_rain.gd`: `on_tell` fixes 5 areas of 2 x 2 tiles at offsets (0, 0), (-6, -4), (6, -4), (-6, 4), (6, 4) tiles from `ctx.target_position()`, each clamped so it lies in the play area (D-S52-3); `hazard_rects()` returns them; `hazard_hit(p)` is true when `p` lies in any of them; `hazard_positions()` returns their centres; `declared_positions` returns the rect corners. No RNG.
- [x] Task 4: Body wiring (AC: 9, 10)
  - [x] 4.1 `NullPointerBody.touches_player` stays `attack_hazard_hit(p)` (already the 5.1 rule); confirm no change is needed beyond D-S51-8 wording. Do not add a passive contact circle.
  - [x] 4.2 Confirm `visible_now()` (5.1) covers both attacks' RECOVERY frames; add no new visibility code.
- [x] Task 5: Tests (AC: 11, 14, 15, 16)
  - [x] 5.1 `game/tests/unit/test_null_pointer_attacks.gd` for AC 1–6, 9, 10, 12, 13, using `SimContext` and `BossController.setup` with a `PlayerHealth` and `ArenaContext`.
  - [x] 5.2 Integration: extend `test_null_pointer_fight.gd` with the phase 1 and phase 2 runs and the visible-recovery Echo Dash / Dash Strike checks (AC 11, 15).
  - [x] 5.3 Run the full GUT suite headless and `check_guards`; no new `Log.error`.

## Dev Notes

### Design context (what 5.2 must respect)

- The framework (`BossController`, Story 3.1) owns the FSM, pools (no triple repeat), the gap and Patched. Attacks only implement `on_tell`, `on_active`, `on_recovery`, `on_cancel`, `hazard_hit` and the presentation getters. Do not duplicate the FSM.
- Hazards reach the player only through `touches_player` in the body: `_check_contact` calls `_health.queue_hit()` once per tick, and `PlayerHealth` decides invulnerability and the 1 HP (D-011). No new damage path.
- `BossAttack.hazard_hit` receives the real player position from the body (`contact_source`, D-S34-9). Attacks never read the player position themselves (`test_attack_isolation`).
- `attack_hazard_hit` is gated on `state == ACTIVE`, so the hazard is live only in ACTIVE. Recovery stays a damage-free visible window.
- Weak windows are unchanged: P1 D->L and P2 A->D come from the phase data (5.1). Patched is applied by `WeakWindowTracker` before the patching hit's damage (project rule). 5.2 only verifies the path.
- Pillar 2: every tell is >= 20 frames and telegraphed; both attacks have tells of 40 and 45 frames.

### Null Pointer state at 5.1 (for orientation)

- `NullPointerBody` (`game/src/bosses/null_pointer/null_pointer_body.gd`): drift in every live state except ACTIVE and RECOVERY (D-S51-7); `visible_now()` is true in ACTIVE, RECOVERY, during the hit flicker, the pass-through reveal, and while Watch is held; `on_player_hit` and `on_pass_through` hooks; column via `trail_positions()`.
- `touches_player` = `attack_hazard_hit(p)`; no attacks exist yet, so both pools are empty and the FSM stays in GAP.
- Hum: `NullPointerHum` in `game/src/presentation/null_pointer_hum.gd`, child of `BossView`. Not touched by 5.2.

### Files to touch

- New: `game/data/bosses/null_pointer/attack_pointer_grab.tres`, `game/data/bosses/null_pointer/attack_null_rain.tres`, `game/src/bosses/null_pointer/attacks/pointer_grab.gd`, `game/src/bosses/null_pointer/attacks/null_rain.gd` (+ `.uid` files from the editor), `game/tests/unit/test_null_pointer_attacks.gd` (+ `.uid`).
- Edit: `game/data/bosses/null_pointer/boss_def.tres` (pools), `game/src/bosses/framework/boss_attack.gd` (two virtuals with defaults), `game/src/presentation/boss_view.gd` (`_draw_attack`), `game/tests/unit/test_data_validation.gd`, `game/tests/integration/test_null_pointer_fight.gd`.
- Do not edit: `src/bosses/infinite_loop/`, `data/bits/` (5.5), `src/skills/watch/` (5.4), `src/bosses/segfault/` (Epic 6 scope), the Dangling Pointers files (5.3).

### Testing standards

GUT tests in `game/tests/unit/` and `game/tests/integration/`. Fixed seeds through `SimContext`. Ticks via `SimClock`, never wall time. Test names `test_<subject>.gd`. The Story 3.4 guard in `test_attack_isolation.gd` scans every `src/bosses/*/attacks/*.gd` and forbids `rng`, `Player`, `Register`, `PlayerHealth`, `SimClock`, `body_contact_position` and `Arena.` members other than `play_area` / `clamp_to_play_area`. The two new scripts must satisfy it.

### Previous story intelligence

- Story 5.1 (done): the body is the only writer of its reveal timers; `on_player_hit` / `on_pass_through` route from CombatResolver. Review patches: the falling column flips above the body near the bottom edge; reveal hooks are guarded by `_reveal_allowed()`. Keep both.
- Story 5.1 deferred items that 5.2 inherits: Fight 2 is a damage sponge until 5.2 and 5.4 land (5.2 fixes the first half); ROAR hides the ghost (playtest decision); `reset_for_fight` clears `watch_held` (5.4 owns it).
- Story 3.4 (done): hazards through `hazard_hit` with the real player position, `declared_positions` on-screen check, `on_cancel` for phase change. Follow Constrict's pattern.
- Story 4.3 (done): `effective_recovery` with `recovery_if_no_breakpoint = 0` means the same recovery with or without Breakpoint for both attacks.

### Project Context Rules

- Read-only defs at runtime; per-fight attack state (grab centre, rain areas) lives in the attack script instance and is cleared by `reset()` / `on_cancel()`.
- Integer frames for all timings; no `delta`, no `Timer`, no `await` in simulation.
- Attacks aim only via `ctx.target_position()`; no untelegraphed damage; tell >= 20 frames; non-empty `tell_sfx`.
- Presentation reads the attack (`tell_marks`, `hazard_positions`, `hazard_rects`, `tell_glyph`) and never writes it (AD-05).
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

## Design calls

- **D-S52-1 (body contact):** the ghost body stays non-damaging. Only a live attack's hazard hurts (`touches_player` = `attack_hazard_hit`). This answers the Story 5.1 note "contact damage deferred to 5.2" as "no passive contact": the GDD lists no body contact for Null Pointer, and recovery is meant to be a safe window to strike back. Revisit in the 5.3 whiff tuning or the playtest.
- **D-S52-2 (grab geometry) [design call, coordinator]:** the grab is a circle of radius 1 tile. Its centre is locked at TELL start BEHIND the player: `aim - facing * 0.75 tile` (facing from `ctx.target_facing()`), clamped so the whole circle lies in the play area. Locked, so a player who moves during the 40-frame tell can dodge. The `*` marks that centre. This overrides the original "at the locked position" reading.
- **D-S52-3 (rain layout):** five 2 x 2 areas at fixed tile offsets (0, 0), (-6, -4), (6, -4), (-6, 4), (6, 4) from the TELL-entry aim, clamped into the play area. Fixed layout because attacks may not draw RNG (`test_attack_isolation`). It forces a move during the 45-frame tell.
- **D-S52-4 (no RNG in attacks):** both attacks are deterministic from the aim point. Variety across casts, if wanted, needs an RNG channel on `ArenaContext`: a framework change, not in 5.2.
- **D-S52-5 (framework touch):** `BossAttack` gains `hazard_rects()` (default empty) and `tell_glyph()` (default `"!"`), additive, so existing attacks are unchanged. Presentation draws the 2 x 2 outlines and the `*`.
- **D-S52-6 (pools):** phase 1 and phase 2 both use `[pointer_grab, null_rain]` with equal weight (the framework's uniform draw). Dangling Pointers joins phase 2 in 5.3.
- **D-S52-7 (ROAR):** no attack runs during ROAR (framework rule). The ghost stays hidden during the roar as in 5.1 (D-S51 deferred item).
- **D-S52-8 (tell SFX ids):** `&"tell_pointer_grab"` and `&"tell_null_rain"`. Story 7.2 maps them to streams; the ids only need to be non-empty now.
- **D-S52-9 (grab effect):** the grab deals 1 HP and nothing else (no hold, no knockback, no Register effect). The GDD names only the damage.
- **D-S52-10 (rain areas):** areas are drawn as outlines during TELL (no damage) and during ACTIVE (damage), and are gone in RECOVERY.

## Open questions (not blocking)

- ~~"Behind the player" for Pointer Grab (D-S52-2)~~ Resolved by the coordinator: grab sits behind the player (see D-S52-2).
- Body contact (D-S52-1): confirm in the playtest that attacks alone give enough pressure.

## References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.2: Pointer Grab and Null Rain]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 2 — Null Pointer]
- [Source: _bmad-output/game-architecture.md#AD-06 (boss framework), AD-05 (presentation reads only)]
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules]
- [Source: _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md] (body, hooks, visibility, D-S51-7 / D-S51-8)
- [Source: _bmad-output/implementation-artifacts/3-4-head-rush-and-constrict.md] (hazard_hit pattern, declared_positions)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-5.1]

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (gds-create-story, unattended); implementation: claude-opus-5-5 (gds-dev-story, unattended)

### Debug Log References

- First run: tell tests counted the TELL->ACTIVE transition tick as a tell frame (the hit lands on that tick's contact check, which is ACTIVE); tests now tick 39/44 then 1. A cross-iteration `_player_px` leak in the cancel test was fixed.
- Story 5.1 tests that assumed empty pools were updated: the drift test uses a test-only `IdleBody` (`_attacks_allowed() == false`), the "empty pool GAP loop" test now checks the 90-frame gap then the first TELL, the 5.1 integration test checks GAP only for the first 89 ticks.
- Final: headless import clean; full GUT suite 1155/1155 passing (85 scripts); `check_guards.sh` OK.

### Completion Notes List

- Story created (ready-for-dev) by gds-create-story, unattended. Design calls D-S52-1 to D-S52-10 are recorded above; the implementer may change them and must note changes here.
- No new library or version is introduced: the work is GDScript on the existing framework, so no web research was run for this story.
- Implemented (dev-story): `AttackDef` data for both attacks and both phase pools; `BossAttack.hazard_rects()` / `tell_glyph()` (additive defaults); `pointer_grab.gd` and `null_rain.gd`; BossView draws the ghost's attacks (`*` on its mark, `!` still above, exact-size rect outlines with a double outline while ACTIVE, the grab circle outline); body wording updated (no code change to `touches_player` / `visible_now`).
- [design call] D-S52-2 changed (coordinator decision): the grab is BEHIND the player as in the GDD. `ArenaContext` gains an additive `facing_source` Callable and `target_facing()` (8-way, default right; never zero); the Arena feeds it `player.facing`. The grab centre is locked at TELL entry at `aim - normalize(facing) * GRAB_OFFSET_TILES` and clamped so the whole circle lies in the play area. Not invasive: three lines in ArenaContext, one in Arena.
- [design call] GRAB_OFFSET_TILES = 0.75 (under the 1-tile radius): a player who ignores the tell is grabbed; any step forward escapes. At 1.0 a stationary player would sit exactly on the edge (float-fragile for diagonals).
- [design call] The grab's circle outline is drawn during TELL and ACTIVE (readability, Pillar 2) in addition to the `*`.
- [design call] Null Rain areas: each 2 x 2 square is centred on aim + offset, its top-left snapped to whole tiles (glyph grid), then clamped into the play area. The centre area always covers the aim. Edges count as inside for both hazards.
- [design call] Non-`!` tell glyphs are drawn on the mark itself (not one cell above); rect hazards suppress the `{` glyph at `hazard_positions()`.
- [design call] Both attacks no-op `on_tell` with a null ArenaContext (bodies set up without an arena in unit tests).
- AC 12 note: the grab also reads `ctx.target_facing()` (the new channel), not only `target_position()`; the isolation guard still passes (no forbidden reads, no RNG).
- Tests: `test_null_pointer_attacks.gd` (21 tests: timings, locked centre, every facing, hit/miss/edge/invulnerability, recovery visibility, rain areas and clamping, ACTIVE-only gate, cancel on phase change and defeat, no body contact, reset, determinism, on-screen declared positions); `test_data_validation.gd` (pools + attack defs); `test_null_pointer_fight.gd` (both attacks in both phases with seed 5252, no Log.error, hits reach PlayerHealth; Echo Dash in phase 1 and Dash Strike in phase 2 Patch the ghost during a visible RECOVERY).

### Review Findings

Code review (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel): 9 patched, 9 deferred, about 14 dismissed.

- [x] [Review][Patch] `NullRain.hazard_rects()` returned the live array; now a copy [null_rain.gd]
- [x] [Review][Patch] `declared_positions(null)` unguarded in both attacks [pointer_grab.gd, null_rain.gd]
- [x] [Review][Patch] `ArenaContext.target_facing()` with an invalid Callable [arena_context.gd]
- [x] [Review][Patch] Grab `on_tell(null)` left stale state; now resets [pointer_grab.gd]
- [x] [Review][Patch] BossView `live` read the view's `boss`; the ghost's state is now passed in [boss_view.gd]
- [x] [Review][Patch] No test for the facing channel; added (default, zero, invalid, source) plus null-ctx and rects-copy tests [test_null_pointer_attacks.gd]
- [x] [Review][Patch] RNG test overclaimed; renamed to a determinism test [test_null_pointer_attacks.gd]
- [x] [Review][Patch] Spec text stale for D-S52-2 / AC 12 / open question; amended (coordinator decision)
- [x] [Review][Patch] Test count in the notes (see Tests line; final suite 1158 passing)
- [x] [Review][Defer] Null Rain areas clamp onto each other near walls (fewer than 5 distinct areas) [null_rain.gd] — deferred, design tuning for the playtest
- [x] [Review][Defer] Grab centre clamped at walls: "any step forward escapes" untested there [pointer_grab.gd] — deferred
- [x] [Review][Defer] Integration tests: recovery window depends on the seeded pick; visibility assertion ORs reveal timers; HP topped up per tick [test_null_pointer_fight.gd] — deferred
- [x] [Review][Defer] "Body never touches player" test is tautological (`touches_player` = `attack_hazard_hit`) — deferred
- [x] [Review][Defer] Phase-2 gap_frames (60) assertion dropped from the rewritten 5.1 body test — deferred
- [x] [Review][Defer] `invuln_frames` 0 would allow a hit per ACTIVE tick (no one-hit latch); shipped data is 60 — deferred
- [x] [Review][Defer] AC 13 checks only declared_positions on 4 facings; BossView drawing untested — deferred
- [x] [Review][Defer] `tell_sfx` ids not registered with audio (silent cue) — deferred to the audio pass
- [x] [Review][Defer] Both phases use the identical pool, so phase escalation is thin (D-S52-6) — deferred

### File List

- game/data/bosses/null_pointer/attack_pointer_grab.tres (new)
- game/data/bosses/null_pointer/attack_null_rain.tres (new)
- game/data/bosses/null_pointer/boss_def.tres
- game/src/bosses/null_pointer/attacks/pointer_grab.gd (new, + .uid)
- game/src/bosses/null_pointer/attacks/null_rain.gd (new, + .uid)
- game/src/bosses/framework/boss_attack.gd
- game/src/bosses/framework/arena_context.gd
- game/src/arena/arena.gd
- game/src/bosses/null_pointer/null_pointer_body.gd (comments only)
- game/src/presentation/boss_view.gd
- game/tests/unit/test_null_pointer_attacks.gd (new, + .uid)
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_null_pointer_body.gd
- game/tests/integration/test_null_pointer_fight.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-11-11: Story 5.2 created (ready-for-dev) by gds-create-story, unattended.
- 2026-11-11: Implemented Pointer Grab (behind the player via a new ArenaContext facing channel) and Null Rain, framework getters, BossView drawing, tests; status review.
