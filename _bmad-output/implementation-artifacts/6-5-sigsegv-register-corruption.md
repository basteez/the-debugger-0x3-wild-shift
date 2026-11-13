---
baseline_commit: a91f130
---
# Story 6.5: SIGSEGV and Register Corruption

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Open design questions are marked [design call] with the chosen default (D-S65-n); the implementer follows them or records a change in Completion Notes. Scope: the SIGSEGV attack (60-frame red tell, one-frame register rotation by 2 through the PlayerEffects queue, guaranteed recovery of 90 frames or 150 without Breakpoint), the `exclusive` rule, the first real PlayerEffects command (RotateRegister) and its Register / LinkState application, the pool entries in phases 2 and 3, the tell presentation, the guard and the tests. NOT in scope: Reserved Write and InsertTemporaryBit (6.6, cut #1), intro and ending screens (6.7/6.8), all game text beyond the tell line (6.9), final art and sound (7.x). -->

## Story

As a player,
I want the final boss to scramble my register with fair warning,
so that the theme turns against me without feeling cheap.

**Requirements:** FR43 (SIGSEGV register rotation, phases 2–3). Additional: NP-3 (boss-to-player effects through the PlayerEffects queue, applied at the fixed tick point), cut ladder #3 (Breakpoint cut: recovery 150, `AttackDef.recovery_if_no_breakpoint`), cut ladder #4 (`FeatureFlags.segfault`, AD-12). Window: Nov 22–25 (Epic 6). Depends on: 2.3 (Register ring, `shift`, `register_shifted`), 2.6 (LinkState, NP-1 link close), 3.1 (`BossController` FSM, `AttackDef.exclusive` stored, `PlayerEffects` slot), 3.2 (`PATCHED_FRAMES`, weak windows), 4.3 (Breakpoint flag and `effective_recovery`), 6.3 (`SegfaultBody`, the leaf folder, `FeatureFlags.segfault` wiring), 6.4 (Corrupt Memory and Core Dump pools; the phase 1–3 pool shape this story extends).

## Acceptance Criteria

**Pools and data**

1. **Given** `game/data/bosses/segfault/boss_def.tres`, **When** loaded, **Then** phase 1's `attack_pool` is unchanged (`[attack_access_violation, attack_corrupt_memory]`), phase 2's is `[attack_access_violation, attack_corrupt_memory, attack_sigsegv]`, and phase 3's is `[attack_access_violation, attack_corrupt_memory, attack_core_dump, attack_sigsegv]`. SIGSEGV appears in no phase before 2. HP 1000, drop 0, the fixed line, the three weak windows and the phase thresholds (100 / 66 / 33) are unchanged; `BossDef.validate()` returns no problems.
2. **And** `attack_sigsegv.tres` has `id = &"sigsegv"`, `tell = 60`, `active = 1`, `recovery = 90`, `recovery_if_no_breakpoint = 150`, `exclusive = true`, a non-empty `tell_sfx` (`tell_sigsegv`, the SIGSEGV alarm, D-049) and an `attack_script` under `src/bosses/segfault/attacks/`.

**Tell and presentation**

3. **Given** SIGSEGV is chosen, **When** its TELL runs (60 frames), **Then** the HUD gets a solid red (`Palette.WARN`) border for the whole tell, drawn by a separate `WarningBorder` node (the Breakpoint overlay pattern), and the tell line reads `SIGSEGV incoming` as an inverted (BG on INK) cell run in the sky row (amended by coordinator decision, see D-S65-8); the rising alarm plays through the `tell_sigsegv` cue id (data only until the 7.2 audio pass, D-S65-9). No register change and no damage happens during the tell.
4. **And** (amended) the red border lives in `WarningBorder` (`src/presentation/warning_border.gd`), the only SIGSEGV node allowed `Palette.WARN`; the HUD sources stay INK/BG only (`test_glyph_palette`). The presentation reads the attack through a method (`warning_tell()`), never writes sim state (AD-05), and detects the attack by method, not by class name.

**Effect**

5. **Given** SIGSEGV reaches its single ACTIVE frame, **When** `on_active` runs, **Then** it pushes exactly one `PlayerEffects.RotateRegister(2)` command (`+2`, the `>>` direction, D-S65-4). The command is applied in the PLAYER_EFFECTS phase of the same tick, after the Register's SHIFTS phase and before COMBAT.
6. **And** applying the command rotates the ring by 2 slots through `Register` (a new `rotate(n)` method, the only writer of `ring`), closes the link through `LinkState.close()` (NP-1), leaves `shift_serial` unchanged so an in-progress ATTACK chain is not reset (amended D-S65-5; the chain still needs its slot to hold A), and emits `EventBus.register_shifted(direction, window, ring, &"sigsegv")` exactly once.
7. **And** `on_active` is idempotent within the attack (a `fired` latch, cleared by `reset()` and `on_cancel`), so a second call in the same attack never queues a second rotation.
8. **And** the attack files never name `Register`, `Player`, `PlayerHealth`, `LinkState` or `rng` (`test_attack_isolation` stays green; `PlayerEffects.RotateRegister` is a word-boundary-safe name, D-S65-3). The command class lives in `src/bosses/framework/player_effects.gd`, outside the leaf folder.

**Recovery and exclusivity**

9. **Given** `FeatureFlags.breakpoint` is on, **When** SIGSEGV runs, **Then** its RECOVERY lasts 90 frames; **Given** it is off, **Then** 150 frames (`BossController.effective_recovery`, unchanged). Recovery is guaranteed: no cut except a defeat or a phase change ends it early, and it never shortens.
10. **And** `exclusive = true` means: SIGSEGV starts only when no other attack or hazard is in its ACTIVE frames, and no new attack starts until its RECOVERY ends (D-S65-2). The serial FSM makes this hold by construction; the controller also refuses to start an exclusive attack while another attack is current (defensive, one `if`).

**Cut, defeat and retry**

11. **Given** a phase change or the defeat cuts SIGSEGV during TELL, **When** the cut happens, **Then** `on_cancel` clears the fired latch and any pending rotation, no rotation happens, and `on_recovery` does not run.
12. **And** a defeat or a retry leaves the PlayerEffects queue empty and the Register and LinkState as they were at the cut (no effect carries over into the next fight; `reset_for_fight` clears the queue as it does today).
13. **And** with `FeatureFlags.segfault` off (`Game.segfault_enabled == false`), no SIGSEGV is reachable (the body is not built, 6.3), and the 5.6 cut path (Null Pointer → ENDING) holds unchanged.

**Fairness and determinism**

14. **Given** 10 seeded runs of phases 2–3 (GUT, fixed seeds), **When** each SIGSEGV is checked, **Then** none overlaps another attack's or hazard's ACTIVE frames, each is followed by its full RECOVERY (90 or 150 per the flag), and each has exactly one 60-frame TELL before it.
15. **And** the same seed produces the same pick sequence and the same rotation on every run (replay determinism, 2.1). SIGSEGV draws no RNG; the rotation is a fixed `+2`.
16. **And** `game/tools/check_guards.sh` prints OK; its Segfault leaf rule also names `Sigsegv` so the class cannot leak outside `src/bosses/segfault/` (D-S65-10).
17. **And** the GUT suite (headless, `-gexit`) passes with the flag on. The rotation on a 3- and 4-bit ring is covered by unit tests; the 2-bit ring case is pinned as a no-op rotation with the link close and the event still emitted (D-S65-4).
18. **And** the Chrome check of a phase 2 SIGSEGV (tell red flash, alarm, the rotation visibly applied) is recorded in Completion Notes as a human check. It is not automated and does not block this story.

## Tasks / Subtasks

### Group A: Data (AC: 1, 2)
- [x] Add `game/data/bosses/segfault/attack_sigsegv.tres` (AttackDef: id, tell 60, active 1, recovery 90, recovery_if_no_breakpoint 150, exclusive true, tell_sfx `tell_sigsegv`, attack_script).
- [x] Update `boss_def.tres` pools: phase 2 `+ sigsegv`; phase 3 `+ sigsegv` (AC 1). Keep thresholds, windows and gaps.
- [x] Extend the `BossDef.validate` / data validation test: SIGSEGV pool membership (phases 2–3 only), exclusive flag, recovery values.

### Group B: Effect queue and Register (AC: 5, 6, 8)
- [x] `game/src/bosses/framework/player_effects.gd`: add `class RotateRegister` (count n, `apply(register, link)`), and let `apply_all()` run the queued commands against bound targets (`bind(register: Register, link: LinkState)` set by the Arena wiring; an unbound queue logs an error and drops the commands). Keep `push`, `pending`, `clear`.
- [x] `game/src/register/register.gd`: add `rotate(n: int)` (n slots, sign = direction, reduced modulo the ring size; emits `register_shifted` once with the given source, `shift_serial` unchanged, D-S65-5). `shift(direction)` keeps its current behaviour and its `&"player"` source.
- [x] `register_shifted` gets a source argument from the rotation (`&"sigsegv"`); `shift` keeps `&"player"`.
- [x] Arena wiring: bind the PlayerEffects queue to the Register and LinkState of the fight (by the existing arena references; no new class name outside the framework and the arena).

### Group C: SIGSEGV attack (AC: 3, 5, 7, 8, 11)
- [x] `game/src/bosses/segfault/attacks/sigsegv.gd` (`class_name Sigsegv`, `extends BossAttack`): `on_tell` sets the warning flag, `on_active` pushes the RotateRegister once (fired latch), `on_recovery` clears the warning flag, `reset()` / `on_cancel` clear the latch (kept through RECOVERY, rearmed at TELL entry), `warning_tell()` for presentation, `declared_positions` empty (no ground hazard).
- [x] No RNG, no `Register` / `Player` names (AC 8).

### Group D: Controller exclusivity (AC: 9, 10, 12)
- [x] `game/src/bosses/framework/boss_controller.gd`: in `_advance` GAP→TELL, skip a pick that is `exclusive` while another attack is current (defensive; the serial FSM already guarantees it). No change to `effective_recovery`.
- [x] `reset_for_fight` already clears the PlayerEffects queue (verify it still does after `bind`).

### Group E: Presentation (AC: 3, 4)
- [x] `game/src/presentation/boss_view.gd` or the HUD frame draw: while an attack reports `warning_tell()`, a separate `WarningBorder` node draws the `Palette.WARN` border and the tell line reads `SIGSEGV incoming` inverted (BG on INK), glyph set checked, D-S65-8). Detect by method, no class names.
- [x] Verify the glyphs for `SIGSEGV incoming` exist in `wildshift8` (`test_font_coverage` lists them). If a lowercase glyph is missing, add it through `game/tools/gen_glyph_font.py` and regenerate, as 6.4 did for `·`, or use uppercase `SIGSEGV INCOMING` (D-S65-8).

### Group F: Guard (AC: 16)
- [x] `game/tools/check_guards.sh`: add `Sigsegv` to the Segfault leaf rule grep (outside `src/bosses/segfault/`). Do not add `RotateRegister` (it belongs to the framework).

### Group G: Tests (AC: 1–17)
- [x] `game/tests/unit/test_sigsegv.gd`: 60 / 1 / 90 / 150 timings; pool membership by phase; the single rotation per attack; the fired latch; cancel and defeat leave no rotation; `exclusive` refusal; 10 seeded runs of phases 2–3 (no overlap, full recovery, one tell each).
- [x] `game/tests/unit/test_player_effects.gd` (or extend an existing effects test): RotateRegister applies once in the PLAYER_EFFECTS phase; unbound queue drops with an error; `clear()` empties the queue.
- [x] `game/tests/unit/test_register.gd`: `rotate(n)` on 2-, 3- and 4-bit rings (+2 on a 2-bit ring is a no-op for the ring, the event still fires); `shift_serial` bump; `register_shifted` source `&"sigsegv"`; the LinkState closes.
- [x] Extend `test_data_validation` (pools, exclusive, recovery) and `test_font_coverage` (the tell text glyphs).
- [x] Extend `test_boss_fallback` only for the flag-off path (AC 13); keep the 6.3 and 6.4 cases green.
- [x] Run the full GUT suite headless and `bash game/tools/check_guards.sh`.

## Dev Notes

### Design context (what 6.5 must respect)

- The framework (`BossController`, 3.1) owns the FSM, pools, the no-triple-repeat rule, the weak window, Patched and defeat. SIGSEGV adds only its TELL / ACTIVE / RECOVERY hooks and one queued effect.
- NP-3 (architecture): bosses never call `Player` or `Register`; they push effects. Effects are applied at one fixed point in the tick: `PLAYER_EFFECTS` (after `BOSS_HAZARDS`, before `COMBAT`). The queue class already exists as a slot (3.1, `PlayerEffects`); this story adds the first command type.
- GDD: SIGSEGV is the only attack that changes player state, the only one in phases 2–3 that is not a tile or body attack, and the only red element besides the Breakpoint warning (GDD "One accent, red #FF4040, is reserved for warnings"). GDD cut #3: Breakpoint cut raises its recovery to 150.
- Architecture pseudo-code (NP-3): `on_active(ctx) → ctx.player_effects.push(PlayerEffects.RotateRegister.new(2))`. The architecture's `Register.rotate(n) ; LinkState.close() ; EventBus.register_shifted.emit(dir, window, reg, &"sigsegv")` is the apply path.
- Attack files are scanned by `test_attack_isolation` with word-boundary patterns: `\bRegister\b`, `\bPlayer\b`, `\bPlayerHealth\b`, `\brng\b`, `\brand*\(`, `\bArena\.`. `PlayerEffects` and `RotateRegister` do not match `\bPlayer\b` or `\bRegister\b` (no boundary inside the word), so the attack may name `PlayerEffects.RotateRegister` (D-S65-3).
- Determinism: no RNG in SIGSEGV; the rotation is fixed. Replays stay bit-identical because the queue and Register update in fixed phases.

### Current state of the code (read before editing)

- `game/src/bosses/framework/player_effects.gd` (`class_name PlayerEffects`, `extends SimSystem`): `push`, `pending`, `clear`, `apply_all()` drains only; the header says "no command types until 6.5 (RotateRegister)". `tick` calls `apply_all()` in `SimPhase.PLAYER_EFFECTS`.
- `game/src/register/register.gd` (`class_name Register`): ring of owned bits (2–4), `shift(direction)` rotates one slot and emits `register_shifted(..., &"player")`; `preview`, `active_window`, `insert` (harvest). No multi-slot `rotate` yet. `shift_serial` drives the ATTACK combo reset (2.5).
- `game/src/player/link_state.gd` (`class_name LinkState`): `close()` clears the open link, count and held key (D-S26-7).
- `game/src/bosses/framework/attack_def.gd`: `exclusive` (stored, no behaviour until 6.5) and `recovery_if_no_breakpoint` (read by `BossController.effective_recovery`, 4.3).
- `game/src/bosses/framework/boss_controller.gd`: `_advance` (GAP → TELL → ACTIVE → RECOVERY), `pick_next` (uniform, no triple repeat), `_cancel_attack` calls `on_cancel` then `_on_attack_cancelled`, `reset_for_fight` clears `player_effects`. `on_active` runs in `tick` before `_advance`, so a one-frame ACTIVE calls `on_active` exactly once.
- `game/src/bosses/segfault/`: `segfault_body.gd`, `corrupted_tiles.gd`, `attacks/access_violation.gd`, `attacks/corrupt_memory.gd`, `attacks/core_dump.gd`. No `sigsegv.gd` yet.
- `game/data/bosses/segfault/boss_def.tres`: phase pools as in 6.4 (P1–P2 `[claw, corrupt_memory]`, P3 `+ core_dump`).
- `game/src/core/feature_flags.gd`: `breakpoint` (cut #3) and `segfault` (cut #4) flags; `recovery_if_no_breakpoint` is the 150 path.
- `game/src/presentation/boss_view.gd` draws attacks generically and detects tile attacks by method (`is_tile_attack`, 6.4); the warning colour is not yet drawn anywhere in the boss view.
- `game/tools/check_guards.sh`: the Segfault leaf rule names `SegfaultBody|CorruptedTiles|CorruptMemory|CoreDump`; `data/bosses/segfault` path rule exists (6.4).

### Design calls (D-S65-n)

- **[design call] D-S65-1 Pools.** Phase 2 pool: `[access_violation, corrupt_memory, sigsegv]`; phase 3: `[access_violation, corrupt_memory, core_dump, sigsegv]`. Uniform pick (framework rule). The GDD table is the source: SIGSEGV P2–3. The 3-attack pool in P2 means no-triple repeat can still draw it up to twice in a row, which is allowed by the framework rule.
- **[design call] D-S65-2 Exclusivity by construction.** The FSM is serial and the tile and body attacks never run beside an ACTIVE SIGSEGV, so the exclusive rule holds without a scheduler. The controller gets one defensive check: an exclusive pick is refused while another attack is current (the pick falls back to the pool minus exclusive entries, or stays in GAP). Recovery blocking is the serial FSM's existing behaviour.
- **[design call] D-S65-3 Command class location.** `PlayerEffects.RotateRegister` lives in `src/bosses/framework/player_effects.gd` (not the leaf folder, it is a generic NP-3 command, reusable by Reserved Write in 6.6). The attack names it through `PlayerEffects.RotateRegister.new(2)`; the isolation regex passes because the name does not match `\bPlayer\b` / `\bRegister\b`.
- **[design call] D-S65-4 Direction and small rings.** The rotation is `+2` (the `>>` direction, the sign of `RIGHT`), applied modulo the ring size (2–4 owned bits). On a 2-bit ring, rotating by 2 leaves the ring unchanged; the link still closes, `shift_serial` still bumps and the event still fires, so the player still feels the hit. A 2-bit ring is possible only before the first insertion (harvest). Record in Completion Notes whether playtest (7.8) wants a scramble on 2-bit rings (e.g., rotate by 1 when the ring is 2 bits).
- **[design call] D-S65-5 Combo reset and the link (amended by coordinator).** The rotation closes the link (NP-1) but does not bump `shift_serial`, so an in-progress ATTACK chain is not reset (the GDD's "resets on any shift" names the player's shift; the chain still requires its slot to hold A after the rotation). Because the serial is unchanged, `ActionStateMachine._update_link` also requires the window to equal the one J started on, so a rotation during J's startup never opens a link on the rotated pair. `register_shifted` carries the `&"sigsegv"` source.
- **[design call] D-S65-6 Single firing.** SIGSEGV has `active = 1`; its `on_active` pushes once behind a `fired` latch cleared in `reset()`, `on_recovery` and `on_cancel`. If a later data change makes `active > 1`, the latch stops a second rotation.
- **[design call] D-S65-7 Tell timing.** The 60-frame tell is data (AttackDef.tell). The HUD flash and the tell line run for the whole tell (no blink) so the warning reads as a state; the alarm rises once per tell.
- **[design call] D-S65-8 Red border via WARN overlay, inverted ink text (amended by coordinator).** During the SIGSEGV tell a separate `WarningBorder` node (child of the Hud, added by Main, same pattern as the Breakpoint overlay) draws a solid 2-px `Palette.WARN` frame around the 640x360 HUD for the whole tell (no blink, no alpha), and the sky row shows `SIGSEGV incoming` inverted (BG text on an INK run). The HUD sources stay INK/BG only. `wildshift8` covers printable ASCII, so lowercase stays. The text is `Hud.WARNING_TELL_TEXT`; game text polish (6.9) may reword it. This honours GDD line ~516, the architecture palette note and the `Palette.WARN` comment (red reserved for SIGSEGV).
- **[design call] D-S65-9 Tell SFX are data-only.** `tell_sigsegv` is a non-empty id; no audio registration in this story (D-S64-8, same as the tile tells). The SIGSEGV alarm is the one exception the GDD names (D-049); its stream is registered in the Epic 7 audio pass (7.2).
- **[design call] D-S65-10 Guard names.** The Segfault leaf rule adds `Sigsegv` (class name of `attacks/sigsegv.gd`). The 6.3 deferred gap for `AccessViolation` stays open and is recorded, not fixed here.
- **[design call] D-S65-11 Defeat during RECOVERY.** A defeat during the 90 / 150 recovery cancels nothing (the attack has already applied its effect), `on_recovery` already ran, and the PlayerEffects queue is empty by then, so no rotation is lost or repeated. The DEFEATED state shows no register change.

### Architecture and rules that bind this story

- AD-06 / AD-12: attacks in `src/bosses/segfault/`; core code loads by path only; the leaf rule is enforced by `check_guards.sh`.
- NP-1 / NP-3: the rotation closes the link; bosses push effects and never mutate the player or Register directly; effects apply at the fixed PLAYER_EFFECTS tick point.
- NP-4: the Patched path is unchanged; SIGSEGV is not a decoy target and does no `target_position()` use.
- AD-01: durations are int sim frames; no `delta`, no `Timer`, no `await`.
- AD-05: presentation reads `warning_tell()` and the register; it never writes sim state.
- Determinism: one seeded `RandomNumberGenerator`; SIGSEGV draws nothing; no global `randi()`.
- Red `#FF4040` only for warnings (GDD colour rule, D-023).

### Previous story intelligence

- 6.4 (done): the grid and the two tile attacks; pools P1–P2 `[claw, corrupt_memory]`, P3 `+ core_dump`; `tell_*` ids data-only (D-S64-8); the one-hit latch; the `·` glyph was added through `gen_glyph_font.py`. Deferred: `hazard_hit` on tile attacks is used by Ghost Echo decoys; keep SIGSEGV's `hazard_hit` false (no ground hazard).
- 6.3 (done): `SegfaultBody`, `AccessViolation` (locked geometry, TELL-entry lock), `boss_def_path_for(..., segfault_on)`, the leaf guard. Deferred: "No test for the Segfault DEFEATED reassembly draw" and "`AccessViolation` class name still not covered by the guard"; both stay open unless touched here.
- 5.6 (done): `Game.segfault_enabled`, `route_after_defeat`, the cut path; unchanged here.
- 3.4 / 3.5 (done): the Spit's per-tick hit (deferred, playtest 3.9); not used by SIGSEGV.
- 4.3 (done): `recovery_if_no_breakpoint` and `effective_recovery`; SIGSEGV is its first user in Segfault.
- 2.5 (done): `shift_serial` resets the ATTACK chain; the rotation uses the same counter (D-S65-5).
- 2.6 / NP-1 (done): LinkState close on shift; the rotation follows the same rule.

### Git intelligence

- Branch `story/6-5-sigsegv-register-corruption` at `a91f130` (Story 6.4 implementation), stacked on `340e57b` (6.3), `6bb14e6` (6.2) and `00e7101` (6.1). Story pattern: data, pure logic in the leaf folder, framework command queue, presentation by method, guard, tests.

### Latest technical information

- Godot 4.7.2-stable (pinned; do not upgrade), GUT 9.6.1, GDScript 2 only. Typed arrays and `signal` only in `EventBus`. No new APIs needed.

### Project Context Rules

- Read-only defs at runtime; per-fight state (the fired latch, the warning flag) lives in the attack and is cleared by `reset()` / `on_cancel()`.
- Integer sim state; floats for presentation only (D-S33-2).
- Tells ≥ 20 frames (60 here); `tell_sfx` non-empty; ids unique.
- Red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV).
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: tell 60; active 1; recovery 90 (150 without Breakpoint); 10 seeded runs of phases 2–3; rotation +2.
- Guards: `bash game/tools/check_guards.sh` (run from the worktree root).
- The Chrome phase 2 check (red flash, alarm, visible rotation) is a human check; record it in Completion Notes, do not fake it in a test.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.5: SIGSEGV — Register Corruption] (ACs, FR43, NP-3)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] (Boss 3 attack table, SIGSEGV row line ~427; fairness rules ~432–434; colour rule ~516; cut ladder ~678)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md] (D-023 red warnings; D-026 cut ladder; D-049 audible tells)
- [Source: _bmad-output/game-architecture.md#NP-3 — Boss → Player State Mutation] (RotateRegister, exclusivity, recovery rules, pseudo-code ~675–705)
- [Source: _bmad-output/game-architecture.md#project structure, line ~464] (segfault leaf folder, attacks list)
- [Source: _bmad-output/implementation-artifacts/6-4-corrupted-tiles-corrupt-memory-and-core-dump.md] (D-S64-n, pool shape, data-only tell SFX, guard extension)
- [Source: _bmad-output/implementation-artifacts/6-3-segfault-body-and-access-violation.md] (D-S63-n, leaf guard, presentation by method)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (Segfault items from 6.3 and 6.4; 2.5 shift_serial; 3.1 PlayerEffects slot)

## Open questions (not blocking)

- D-S65-4: the 2-bit ring rotation is a no-op for the ring (link close and event still happen). Keep, or rotate by 1 on a 2-bit ring; decide in the 7.8 playtest.
- D-S65-5: whether a SIGSEGV rotation should reset an in-progress ATTACK chain (default yes, via `shift_serial`) or only close the link; playtest.
- D-S65-8: lowercase glyphs in `SIGSEGV incoming`; check `wildshift8` first, fall back to uppercase.
- D-S65-9: the alarm is silent until the Epic 7 audio pass (7.2).
- The Chrome phase 2 SIGSEGV check is pending until a human runs it.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended pipeline run.

### Debug Log References

- Full GUT suite (headless, `-gdir=res://tests -ginclude_subdirs -gexit`): 1465 / 1465 passing (unit + integration + replay).
- `bash game/tools/check_guards.sh`: OK.
- First run after the data change: 11 failures, all expected fallout (Core Dump moved from cache index 2 to 3 because SIGSEGV now enters the cache in phase 2; the 6.4 pool assertion; the 3.1 drain test pushing bare RefCounted into an unbound queue). Tests updated.

### Completion Notes List

- Data: `attack_sigsegv.tres` (60 / 1 / 90, 150 without Breakpoint, exclusive, `tell_sigsegv`); phase 2 and 3 pools end with SIGSEGV. Cache order is now access_violation 0, corrupt_memory 1, sigsegv 2, core_dump 3.
- `PlayerEffects.RotateRegister(n)` (framework file) + `bind(register, link)` (Arena wiring in `_make_arena_context`); `apply_all()` applies in push order, an unbound queue logs an error and drops. `Register.rotate(n, source)`: |n| mod ring size slots in sign direction, one `register_shifted(..., &"sigsegv")`, no `shift_serial` bump.
- `Sigsegv` attack: warning flag in TELL, `warning_tell()` getter, one push behind the `fired` latch (rearmed at TELL entry, cleared by `reset()` / `on_cancel`; kept through RECOVERY so a late `on_active` queues nothing). No RNG, no ground hazard.
- `BossController.can_start(pick)`: the defensive exclusive check in GAP -> TELL (never trips under the serial FSM).
- Presentation: `Hud.warning_tell_on(boss)` (by method, no class name); `hud_frame.gd` draws the INK border and the inverted tell line; `Hud._process` redraws the frame when the warning toggles.
- Coordinator decisions applied: (1) red `Palette.WARN` border via the separate `WarningBorder` node plus the inverted ink tell line (AC 3, AC 4, D-S65-8 amended; an earlier ink-only instruction was corrected); (2) the rotation closes the link but does not reset the ATTACK chain (AC 6, D-S65-5 amended), plus the `_update_link` window guard so a rotation during J's startup cannot open a link on the rotated pair; (3) lowercase `SIGSEGV incoming` (wildshift8 covers printable ASCII, `test_font_coverage` extended); (4) the 2-bit no-op rotation stays (link close + event still happen), revisit in 7.8; (5) all of it is reachable only through the Segfault def (FeatureFlags.segfault).
- Open (not blocking): the Chrome phase 2 check (border, inverted tell line, alarm silent until 7.2, visible rotation) is a human check, not run here. The 6.3 deferred gap (`AccessViolation` not in the leaf guard) stays open.

### File List

- _bmad-output/implementation-artifacts/6-5-sigsegv-register-corruption.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- game/data/bosses/segfault/attack_sigsegv.tres (new)
- game/data/bosses/segfault/boss_def.tres
- game/src/arena/arena.gd
- game/src/bosses/framework/attack_def.gd
- game/src/bosses/framework/boss_controller.gd
- game/src/bosses/framework/player_effects.gd
- game/src/bosses/segfault/attacks/sigsegv.gd (new)
- game/src/bosses/segfault/attacks/sigsegv.gd.uid (new)
- game/src/player/action_state_machine.gd
- game/src/register/register.gd
- game/src/ui/hud/hud.gd
- game/src/ui/hud/hud_frame.gd
- game/src/presentation/warning_border.gd (new)
- game/src/main/main.gd
- game/tools/check_guards.sh
- game/tests/unit/test_action_fsm.gd
- game/tests/unit/test_boss_controller.gd
- game/tests/unit/test_boss_fallback.gd
- game/tests/unit/test_core_dump.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_font_coverage.gd
- game/tests/unit/test_register.gd
- game/tests/unit/test_player_effects.gd (new)
- game/tests/unit/test_player_effects.gd.uid (new)
- game/tests/unit/test_sigsegv.gd (new)
- game/tests/unit/test_warning_border.gd (new)
- game/tests/unit/test_sigsegv.gd.uid (new)

## Change Log

- 2026-11-12: Story 6.5 implemented (SIGSEGV data and attack, PlayerEffects.RotateRegister, Register.rotate, exclusive check, ink-only warning tell in the HUD, guard, tests). AC 3, 4, 6 and D-S65-5, D-S65-8 amended per coordinator decisions. Status -> review.
