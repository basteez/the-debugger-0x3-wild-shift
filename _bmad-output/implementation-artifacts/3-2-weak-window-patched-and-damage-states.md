---
baseline_commit: 9a67470
---

# Story 3.2: Weak Window, Patched and Damage States

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S32-n); the implementer follows them or records a change in Completion Notes. Scope is ordered into task groups A-H; ship groups in order and stop at a green build after each group if time runs short. -->

## Story

As a player,
I want hits to be resisted until I patch the bug with the right window,
so that shifting is the way to deal real damage (Pillar 1).

**Requirements:** FR21 (weak window per phase, Patched on affecting it), FR22 (Unpatched ×0.5, Patched ×1.5; practice target ×1), FR23 (`// patched` tag and countdown bar, chime), FR26 (hit-stop precedence), FR27 (resisted vs crit feedback), FR63 (placeholder SFX: thud, chime); GDD D-017 (weak window → Patched; non-damaging interactions count too), D-019 (weak windows per phase); AD-06 (`BossController` owns the phases; weak window per phase); NP-4 (`CombatResolver` emits `BossInteraction`s, `WeakWindowTracker` is the only Patched writer, `DamageCalc.compute()` is the only damage producer).
**Epic 3 window:** Nov 11–14 (MVP gate Nov 14). **Depends on:** 3.1 (`BossController`, `PhaseDef.weak_window` field, `take_hit`, test boss, `EventBus` boss signals), 2.5/2.6 (`ActionStateMachine`, `LinkState`, combo table), 2.7 (`CombatResolver`, `DamageCalc`, `PracticeTarget`), 2.8 (`HitFeedback`, `LogPanel`, `JuiceDirector`), 2.9 (`PlayerHealth` untouched).
**Unblocks:** 3.3 (Infinite Loop weak windows are data on this path), 3.4/3.5 (attacks run while the window matters), 3.8 (Harvest reads `boss_defeated`), 4.x Breakpoint/hint, 6.1 (decoy `DECOY_STRUCK` producer).

## Acceptance Criteria

1. **Given** a boss in a phase whose weak window is A→D (`Vector2i(Register.Bit.ATTACK, Register.Bit.DASH)`)
   **When** Dash Strike started on window `[A, D]` hits it
   **Then** `WeakWindowTracker` applies Patched for 180 frames before that hit's damage is computed, so the hit is already ×1.5 (Dash Strike 20 → 30)
   **And** `EventBus.patched_applied(boss, 180)` is emitted once, and the patching hit takes 4 frames of hit-stop (D-S32-8).

2. **Given** a boss whose weak window is D→A (no combo)
   **When** I dash, then slash on the link (`link_second`) within the 18-frame link and the slash hits the boss
   **Then** Patched is applied and the slash deals 15 (10 × 1.5), with the patching hit's hit-stop (D-S32-8).

3. **Given** an unpatched boss (any window not completed, or no completed window yet)
   **When** any player hit lands on it
   **Then** damage is ×0.5 via `DamageCalc.compute` (slash 15 → 8, Dash Strike 20 → 10), with a dull thud (placeholder SFX), the dithered `console.log("-8") // resisted` log line, half the glyph particles and a smaller damage glyph (D-S32-18).

4. **Given** a Patched boss
   **When** any player hit lands on it
   **Then** damage is ×1.5, the log line is `CRITICAL: 15 dmg` (CAPS), the hit takes 8 frames of hit-stop (FR26 crit), and the screen inverts for 1 frame
   **And** re-applying Patched while active sets the countdown back to 180 frames.

5. **Given** Patched is active
   **When** the boss is drawn
   **Then** a `// patched` tag and a countdown bar (`frames_left / 180`) float above it, and a rising chime (placeholder) plays on application.

6. **Given** `BossInteraction` kinds `HIT`, `PASS_THROUGH`, `DECOY_STRUCK`
   **When** unit tests run
   **Then** all four "affects the boss" cases complete the weak window: `HIT` combo on the window, `HIT` link_second solo on the window, `PASS_THROUGH` and `DECOY_STRUCK` (stubbed interactions) on the window
   **And** a wrong window never patches, a solo non-link hit never patches, and the practice target is never patched (always ×1, state BASE).

7. **Given** a boss in ROAR or DEFEATED, or not active
   **When** a player hit overlaps its body
   **Then** nothing happens: no damage, no Patched, no `hit_landed`, no hit-stop (D-S32-9).

8. **Given** `BossController.take_hit` is called before `reset_for_fight`, while inactive, or after defeat
   **When** it runs
   **Then** HP is unchanged and no signal is emitted (closes the 3.1 deferred guard).

9. **Given** `tests/unit/test_damage_calc.gd`, `tests/unit/test_weak_window.gd` (new), `tests/unit/test_combat_resolver.gd`, `tests/unit/test_boss_controller.gd` and `tests/unit/test_data_validation.gd`
   **When** they run
   **Then** they cover AC 1–8 and the data rules in D-S32-16; the full GUT suite, replays and `game/tools/check_guards.sh` stay green with the test boss off.

## Scope Boundaries

- In: Patched state and its timer, the weak window per phase, Unpatched/Patched damage on the test boss, `BossInteraction` (HIT produced by the resolver; PASS_THROUGH and DECOY_STRUCK only as stubs in tests), hit feedback per state, placeholder SFX, `// patched` tag/bar, the 3.1 deferred items listed in Dev Notes.
- Out: real Boss 1 and its weak windows (3.3); Echo Dash `PASS_THROUGH` producer and Ghost Echo decoy (6.1, 4.2); Clean Catch (5.5); Watch / weak-window highlight on the HUD (5.1); Breakpoint (4.3); tells, attacks and contact changes (3.3–3.5); Harvest and `boss_defeated` flow (3.8); the real SFX (7.2); Area2D or physics bodies (ADR-02); any `delta`/Timer/Tween in sim code.

## Tasks / Subtasks

- [x] **A. Types and signals**
  - [x] A1. `EventBus`: add `patched_applied(boss: StringName, frames: int)` (past tense, typed, doc comment). No other new signals.
  - [x] A2. New `game/src/combat/damage_state.gd` (`class_name DamageState`, pure static): `enum Kind { BASE = 0, UNPATCHED = 1, PATCHED = 2 }` (the int carried by `hit_landed`), `static func multiplier(kind) -> float` (1.0 / 0.5 / 1.5), `static func multiplier_pct(kind) -> int` (100 / 50 / 150).
  - [x] A3. New `game/src/combat/boss_interaction.gd` (`class_name BossInteraction extends RefCounted`): `enum Kind { HIT, PASS_THROUGH, DECOY_STRUCK }`, `kind`, `window_pair: Vector2i`, `is_combo: bool`, `is_link_second: bool`. Static pure `completes_weak_window(i: BossInteraction, weak: Vector2i) -> bool` per D-S32-6.
  - [x] A4. New `game/src/combat/weak_window_tracker.gd` (`class_name WeakWindowTracker extends RefCounted`): the only writer of Patched. Fields `frames_left: int`. Methods `apply_patched(frames)` (sets, does not add), `is_patched() -> bool`, `tick()` (decrement to 0 floor), `clear()`, and static pure `process(interactions: Array[BossInteraction], weak: Vector2i) -> bool` that returns true when any interaction completes the window (the caller then calls `apply_patched(PATCHED_FRAMES)` and emits `patched_applied`). `const PATCHED_FRAMES := 180`.
  - [x] A5. `HitFeedback`: add `PATCHED_APPLIED_HITSTOP := 4`, `CRIT_HITSTOP := 8`, and pure static `hitstop_for_boss_hit(state: int, is_combo: bool, action_hitstop: int, applied: bool) -> int` implementing D-S32-8. `hitstop_for` (practice target) is unchanged.

- [x] **B. Pure math (test first)**
  - [x] B1. `DamageCalc.compute`: keep the signature. Add `assert(to_pct(state_mult) % 5 == 0)` and `assert(base >= 0)` (deferred 2.7 item). Keep `STATE_BASE` as an alias of `DamageState.BASE`. Remove nothing the tests use.
  - [x] B2. Unit-test the GDD numbers: unpatched 20→10, 15→8 (7.5 rounds up), 10→5; patched 10→15, 20→30; practice target ×1 (10→10); 0 base → 0.

- [x] **C. `BossController` and `BossDef`** (`game/src/bosses/framework/`)
  - [x] C1. Field `weak_window: WeakWindowTracker` created in `_init`. `current_weak_window() -> Vector2i` returns `def.phases[phase_index].weak_window`.
  - [x] C2. `tick`: decrement `weak_window.tick()` once per live tick (while `active`, before the FSM step), so Patched counts sim frames only and keeps counting through GAP, TELL, ACTIVE, RECOVERY and ROAR.
  - [x] C3. `is_hittable() -> bool`: `active` and state in {GAP, TELL, ACTIVE, RECOVERY} (D-S32-9).
  - [x] C4. `last_hit_serial: int = -1`, `was_hit_by(serial) -> bool` and `mark_hit(serial)`; reset in `reset_for_fight`. Same contract as `PracticeTarget` (D-S27-4, D-S32-10).
  - [x] C5. `take_hit(damage)` guard (deferred 3.1): return unless `active`, `def != null`, state not DEFEATED, `damage > 0`. Keep the phase-change and defeat logic. `_defeat` and `reset_for_fight` call `weak_window.clear()`.
  - [x] C6. `hit_target_id() -> StringName` returns `&"boss"` (D-S32-11), the id `hit_landed` carries for bosses.
  - [x] C7. `BossDef.validate` (deferred 3.1): each phase's `weak_window` has two distinct bits, both `Register.is_bit`, not `(0,0)`; `name_signature` non-empty, at most 16 characters, identifier characters only (D-S32-16). Extend `test_data_validation.gd`.

- [x] **D. `CombatResolver` and the action window** (`game/src/combat/combat_resolver.gd`, `game/src/player/action_state_machine.gd`, `game/src/arena/arena.gd`)
  - [x] D1. `ActionStateMachine`: store `action_window: Vector2i` in `_start` from the register window passed to `tick` (D-S32-5); clear it in `_finish`.
  - [x] D2. `CombatResolver`: add `var boss: BossController = null` (nullable, set by the Arena; no constructor change). Keep `player` as is (D-S32-13).
  - [x] D3. `tick` order per NP-4 (D-S32-12): (1) collect `BossInteraction.HIT` for the boss if `boss.is_hittable()`, its hurtbox overlaps the shape and `!boss.was_hit_by(serial)`, with `window_pair = actions.action_window`, `is_combo = actions.combo != null`, `is_link_second = actions.link_second`; (2) `WeakWindowTracker.process(..., boss.current_weak_window(), ...)`; if it returns true, `boss.weak_window.apply_patched(180)` and emit `patched_applied(boss.def.boss_id, 180)`; (3) per target, state = PATCHED / UNPATCHED for the boss, BASE for practice targets; `damage = DamageCalc.compute(base, DamageState.multiplier(state), false, 1.0)`; `take_hit(damage)` and `mark_hit(serial)` for the boss, `register_hit` for practice; (4) `hit_landed(target.hit_target_id(), damage, state, is_combo, pos)`; (5) hit-stop: max over hits of `HitFeedback.hitstop_for_boss_hit` (boss) or `hitstop_for` (practice), then `SimClock.request_hitstop` once.
  - [x] D4. Practice targets stay in `targets` and never produce interactions (never patched, always ×1). Their `hit_target_id()` returns `&"practice_target"` (removes the hard-coded id, deferred 2.7).
  - [x] D5. `hits_for` dedupes a target listed twice (deferred 2.7).
  - [x] D6. `Arena._set_test_boss` assigns `combat.boss = boss`; `_remove_boss` and `leave_fight` clear it. `enter_fight` resets the tracker through `reset_for_fight`.

- [x] **E. Test boss data** (`game/data/bosses/test_boss/boss_def.tres`)
  - [x] E1. Phase 1 `weak_window = Vector2i(1, 2)` (A→D, Dash Strike). Phase 2 `weak_window = Vector2i(2, 1)` (D→A, dash then slash). `max_hp` stays 20 (D-S32-2). The attacks still deal no damage.

- [x] **F. Presentation (reads only, D-S32-18)**
  - [x] F1. `AudioManager`: on `hit_landed` with state UNPATCHED from a boss, play a cached `make_thud()`; on `patched_applied`, play a cached `make_chime()` (rising). Both built in `_ready`, never in the sim tick (3.1 review lesson). Placeholders until 7.2.
  - [x] F2. `JuiceDirector`: PATCHED hit → `request_invert(1)`. UNPATCHED boss hit → half the glyph particles for that burst (reads the state from `hit_landed`; check how the burst count is chosen in `ParticlePool`/`JuiceDirector` before editing).
  - [x] F3. `BossView`: `// patched` tag and countdown bar above the boss while `weak_window.is_patched()`, bar width from `frames_left / 180`. Damage number: the last boss hit's number drawn over the boss for 30 presentation frames (`_process` counter, presentation only), 1× scale unpatched, 2× patched.
  - [x] F4. `LogPanel`: `line_for_damage(damage, state)`. UNPATCHED → `console.log("-%d") // resisted` drawn with the existing 50% checker dither (reuse the Story 2.4 checker helper, do not add a new one); PATCHED → `CRITICAL: %d dmg`; BASE keeps `console.log("-%d")`. Keep ASCII-only text.
  - [x] F5. `Log.debug` on Patched applied and on each phase's weak window at phase change (debug builds only, guarded by `Debug.enabled`). No weak window on the HUD (D-S32-20).

- [x] **G. Tests** (GUT, `game/tests/unit/`)
  - [x] G1. `test_damage_calc.gd`: B2 cases.
  - [x] G2. New `test_weak_window.gd`: the `completes_weak_window` matrix (combo match / combo wrong window / solo non-link / link_second match / link_second wrong window / PASS_THROUGH match / DECOY_STRUCK match / PASS_THROUGH wrong window); tracker `apply` sets 180 and a second apply resets to 180 (refresh); `tick` counts down to 0 and stays 0; `hitstop_for_boss_hit` for each row of D-S32-8.
  - [x] G3. `test_combat_resolver.gd`: boss hit by Dash Strike on A→D → 30, `patched_applied` once, `hit_landed` state PATCHED, hit-stop 4; Dash Strike on D→A → 10, UNPATCHED, no patch, hit-stop 6; slash link_second on D→A → 15 patched; a solo slash off-link → 8, no patch; practice target on a matching window → 10, BASE, never patched; one boss hit per action serial; ROAR / DEFEATED / inactive boss → no hit, no signal; a combo hit lands on a boss and a practice target in the same tick.
  - [x] G4. `test_boss_controller.gd`: `take_hit` guard (AC 8); Patched survives a phase change; cleared on `reset_for_fight` and on defeat; Patched counts down through ROAR; `current_weak_window` per phase.
  - [x] G5. `test_data_validation.gd`: the test boss weak windows and the new `BossDef` rules (C7). `test_log_panel.gd`: `line_for_damage` per state. `test_audio_manager.gd`: thud on unpatched boss hit, chime on `patched_applied`. `test_debug_keys.gd` and `test_hud_layout.gd`: unchanged, must stay green.
  - [x] G6. Replays: `tests/replays/test_replays.gd` and `tests/integration/test_retry_snapshot.gd` stay bit-identical (test boss off, practice-only fights unchanged in order of hits).

- [x] **H. Verify**
  - [x] H1. `godot --headless --path game --import`, then GUT: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Baseline 634/634 (Story 3.1). Record the count.
  - [x] H2. `bash game/tools/check_guards.sh` → `check_guards: OK`. Sim dirs (`combat`, `bosses`) use no `delta`, Timer, Area2D or Tween; presentation never writes sim state.
  - [x] H3. Update `_bmad-output/implementation-artifacts/sprint-status.yaml` (3-2 → review at the end of dev, not now) and this file's Dev Agent Record.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S32-1 One story, ordered groups.** Not split (same reasoning as D-S31-1). Groups A–H are the order of work.
- **[design call] D-S32-2 Test boss windows.** Phase 1 A→D (Dash Strike), phase 2 D→A (dash, then slash on the link). Keeps `max_hp` 20 so the test fixture stays cheap; these are not balance numbers.
- **[design call] D-S32-3 Owner of Patched.** `WeakWindowTracker` is the only writer, owned by `BossController` as `weak_window`. It is ticked by the boss in BOSS_HAZARDS, so Patched is a sim-frame timer.
- **[design call] D-S32-4 Patched timing.** Applied in COMBAT on the hit's tick with `frames_left = 180`. Active on the patching tick and the next 179 ticks. Re-applying sets 180 (refresh, not stack). A test pins the exact count.
- **[design call] D-S32-5 Window of the action.** `ActionStateMachine.action_window` is the register window at start. For a combo it equals the combo's pair; for a link_second solo it equals the link's pair (the resolver only runs a link follow-up on the window the link opened on). Only combo or link_second hits can complete a window. A plain solo hit never patches, even on the right bits.
- **[design call] D-S32-6 Completion rule.** `completes_weak_window(i, weak)` is true when `i.window_pair == weak` and (`kind == HIT` and (`is_combo` or `is_link_second`), or `kind` is PASS_THROUGH or DECOY_STRUCK). This is the GDD/NP-4 rule. Only the HIT producer exists in 3.2.
- **[design call] D-S32-7 Damage states.** `DamageState.Kind` ints BASE 0, UNPATCHED 1, PATCHED 2 go into `hit_landed.state` (signal type stays int). Multipliers are whole percent (50, 150) so `DamageCalc`'s percent math stays exact.
- **[design call] D-S32-8 Hit-stop of a boss hit.** Precedence: the hit that applies Patched takes `PATCHED_APPLIED_HITSTOP` (4); a Patched hit that does not apply it takes `CRIT_HITSTOP` (8); an unpatched hit takes the combo's own value (never below 3) or 3 for solo. AC 1 is literal (4 on a Dash Strike patch). AC 2 says "normal slash hit-stop" for the patching slash; this rule gives 4 there too. Keep the single rule and note the wording in Completion Notes. SimClock keeps the maximum per tick (existing).
- **[design call] D-S32-9 When the boss can be hit.** Hittable in GAP, TELL, ACTIVE and RECOVERY. Not in ROAR (the "no damage window" wording of 3.1 AC 2), not in DEFEATED, not while inactive. A hit in ROAR has no effect at all (no hit-stop, no signal).
- **[design call] D-S32-10 One hit per action per boss.** `last_hit_serial` on the boss (like `PracticeTarget`), keyed by `ActionStateMachine.action_serial`.
- **[design call] D-S32-11 `hit_landed` target id.** Boss hits carry `&"boss"` (the EventBus doc), practice hits `&"practice_target"`. Each target returns its own id via `hit_target_id()`.
- **[design call] D-S32-12 Resolver order.** Interactions → patch → damage with the post-patch state → `take_hit` / `register_hit` → `hit_landed` → one hit-stop request. The patching hit's damage already includes ×1.5 (AC 1).
- **[design call] D-S32-13 `CombatResolver.player` stays.** It is unused (2.7 deferred) but removing it changes the constructor used by Arena and tests for no gain. Leave it; log it again if still unused after 3.2.
- **[design call] D-S32-14 Patched across phases.** Patched persists when the phase changes (the bug stays patched; the new window has to be hit to refresh it). Cleared on `reset_for_fight` and on defeat.
- **[design call] D-S32-15 Asserts.** `DamageCalc.compute` asserts whole-5% multipliers and non-negative base (deferred 2.7). Asserts are stripped from release builds; the tests cover the real values.
- **[design call] D-S32-16 `BossDef` rules added.** Each phase's `weak_window`: two distinct valid bits, not zero. `name_signature`: identifier characters, at most 16 characters so `void <name>() // hp <hp>` fits the top bar with room (3.1 deferred name width).
- **[design call] D-S32-17 Placeholder SFX.** `make_thud()` (low, short noise burst) and `make_chime()` (two-step rising sine) are procedural, cached in `_ready`. No audio asset is added (7.2 replaces them).
- **[design call] D-S32-18 Feedback per state.** Unpatched: half the glyph particles for the burst (a count argument, not a new system), a 1× damage number, the dithered `// resisted` line, a thud. Patched: 1 frame of inversion, 2× damage number, `CRITICAL:` line, chime on application only (not on each refresh). Damage number lifetime is presentation frames, not sim frames, so hit-stop does not change it.
- **[design call] D-S32-19 PASS_THROUGH and DECOY_STRUCK are stubs.** Only the tracker and the completion rule exist for them. Real producers come with Echo Dash (4.2) and the decoy (6.1).
- **[design call] D-S32-20 No weak window on the HUD.** The window is readable from the boss's tells, the Patched tag and the log (FR25 Watch is 5.1). Debug logs only (F5).
- **[design call] D-S32-21 Solo hits and `hitstop_frames`.** Boss hits follow D-S32-8, which uses `hitstop_frames` for combos (2.8 deferred: solo ignores it). Practice-target hits keep the 2.8 rule (solo always 3), so existing replays and tests do not change.
- **[design call] D-S32-22 Sim vs presentation.** Patched counts sim frames in BossController.tick. The damage-number and tag/bar presentation may use `_process` counters but never write sim state and never decide whether Patched is active.
- **[design call] D-S32-23 Arena wiring.** `combat.boss` is set and cleared in `Arena` (D6). No second reset path (2.9 rule): `enter_fight` → boss `reset_for_fight` → tracker cleared.
- **[design call] D-S32-24 Hit dedupe in `hits_for`.** A target listed twice is hit once (2.7 deferred). Pure and tested.

### Existing code this story touches (verified at baseline 9a67470)

- `game/src/combat/combat_resolver.gd`: `tick` (one hit loop, `targets: Array[PracticeTarget]`, `hit_landed(&"practice_target", ...)`, `DamageCalc.compute(def.base_damage, target.damage_multiplier(), false, 1.0)`), `static hits_for`.
- `game/src/combat/damage_calc.gd`: `STATE_BASE := 0`, `CLEAN_CATCH_PCT`, `DEN`, `compute`, `to_pct`.
- `game/src/combat/hit_feedback.gd`: `NORMAL_HITSTOP := 3`, `PLAYER_HITSTOP := 4`, `hitstop_for(is_combo, action_hitstop)`.
- `game/src/bosses/framework/boss_controller.gd`: `setup`, `reset_for_fight`, `set_active`, `tick`, `_advance`, `take_hit` (no guard yet), `_change_phase`, `_defeat`, `debug_kill`, `debug_skip_phase`, `jitter_for_hp`, `_check_contact`.
- `game/src/bosses/framework/boss_def.gd` and `phase_def.gd`: `PhaseDef.weak_window: Vector2i` exists (3.1) but is unused; `BossDef.validate` does not check it.
- `game/src/bosses/practice_target/practice_target.gd`: `was_hit_by(serial)`, `register_hit`, `damage_multiplier()`, `hurtbox_radius_px`.
- `game/src/player/action_state_machine.gd`: `_start` (sets `combo`, `link_second`), `_finish` (clears them), `action_serial`, `action_origin_px`, `facing`, `link: LinkState`.
- `game/src/player/action_resolver.gd`: `_link` (K follow-up, `link_second` solo), `_solo`, `_cancel`; `ActionRequest.link_second`.
- `game/src/register/register.gd`: `enum Bit { ATTACK = 1, DASH = 2, LOOP = 3, NULL_BIT = 4 }`, `is_bit`, `active_window()`, `shift_serial`.
- `game/data/combos/dash_strike.tres`: `first = 1` (A), `second = 2` (D), 20 damage, hitstop 6. `game/data/actions/slash_1.tres`: 10 damage, hitstop default 3. `game/data/actions/dash.tres`: solo D, 0 damage.
- `game/src/arena/arena.gd`: `combat = CombatResolver.new(actions, player)`, `_set_test_boss`, `_remove_boss`, `leave_fight`, `enter_fight`.
- `game/src/autoloads/event_bus.gd`: `hit_landed(target, damage, state, is_combo, pos)`, boss signals (3.1).
- `game/src/autoloads/audio_manager.gd`: `make_blip()`, `_on_boss_tell_started`.
- `game/src/ui/hud/log_panel.gd`: `line_for_damage(damage)` returns `console.log("-%d")`; `_on_hit_landed` ignores state today.
- `game/src/presentation/boss_view.gd`: signature line, jitter, TELL `!`, ROAR flash.
- `game/src/presentation/juice_director.gd`: `request_invert(frames)`, `set_dither`.

### Architecture guardrails (must follow)

- NP-4: `CombatResolver` collects `BossInteraction`s; `WeakWindowTracker.process` is the only place Patched is applied; the patch happens before damage is computed.
- Single writers: damage numbers only from `DamageCalc.compute`; Patched only from `WeakWindowTracker`; boss HP and phase only from `BossController`; player HP only from `PlayerHealth`.
- NP-3: bosses and the resolver never call `Player` or `Register` writes. The resolver reads the FSM (`actions`) which it already holds.
- ADR-02 / AD-04: circle and capsule/arc math only, no Area2D, no physics bodies. Boss hurtbox is the body circle (D-S31-12).
- AD-01: only `SimClock` calls `tick()`. No `delta`, Timer, `await`, Tween or `Engine.time_scale` in `src/combat/` or `src/bosses/`.
- Determinism: no RNG draws are added in 3.2 (patch, damage and hit-stop are pure). Replays stay bit-identical with the test boss off.
- Event rules: new signal only `patched_applied` in `event_bus.gd`, past tense, typed args, no Dictionary payloads. Presentation never writes sim state.
- Naming: `damage_state.gd`, `boss_interaction.gd`, `weak_window_tracker.gd`; frame fields end `_frames` / `_frames_left`; ids `StringName`.
- Errors: `Log.error` + safe default for data errors; `assert` only for programmer errors in `DamageCalc`.
- Logging: `Log.debug` only on events (Patched applied, phase weak window), never per tick.

### Previous story intelligence (3.1 review and Epic 2)

- `take_hit` was written as the 3.2 entry point in 3.1 but has no guard (3.1 review defer): fixed in C5 (AC 8).
- `BossDef.validate` does not check `weak_window` or name width (3.1 defer): C7.
- `CombatResolver` hard-codes `&"practice_target"` (2.7 defer): D4.
- `DamageCalc` real-multiplier assert not exercised (2.7 defer): B1, D-S32-15.
- Solo hits ignore `hitstop_frames` by design (2.8 D-S28-1); this story generalises it for boss hits only (D-S32-21).
- `hits_for` does not dedupe a target listed twice (2.7 defer): D5.
- 3.1 pattern to copy: pure static helpers + thin node glue; new tests in `tests/unit/`; GUT green before `review`.
- Click and inversion ignore `register_shifted` source and `SimClock.paused` (2.4 defer) are for boss shifts, not this story.
- Deferred and NOT for 3.2: `ArenaContext.player_position()` bypass (3.4), contact radius vs drawn body (3.3), `PlayerEffects` silent drop (6.5), `register_shifted` source (6.5), `DebugKeys.practice_requested` lifetime (2.7 D-S27-3), itch/browser checks (deferred-work.md top section).

### Git intelligence

- `9a67470` Story 3.1 (this branch's base). Files touched there are listed in `3-1-reusable-boss-framework.md` File List. Story 3.1 is `review` in its file and `done` in `sprint-status.yaml`.
- Recent fixes `7e2b1be` (F9 overlay) and `d3b2519` (FIGHT placeholder) touched `debug/`, `ui/` and `main/`. Expect HUD and DebugKeys tests as regression surface.

### Latest technical information

- Godot 4.7.2-stable pinned; GDScript only; typed arrays, `Vector2i`, `Callable`, `assert` standard. No new library or version.
- GUT 9.6.1 headless CLI as in 3.1.
- Context7 `/godotengine/godot-docs/__branch__4.7` if an API doubt comes up (project-context rule).

### Project Context Rules

- Only `SimClock` calls `tick()`. Presentation (`BossView`, `LogPanel`, `JuiceDirector`, `AudioManager`) may use `_process`; never for sim state.
- Signals only in `src/autoloads/event_bus.gd`, past tense, typed args.
- Data: `*Def` typed resources under `data/**/*.tres`, read-only at runtime; balance numbers in `.tres`, invariants in `Const` or the pure static helpers.
- Boss code in `src/bosses/<boss>/`; shared framework in `src/bosses/framework/`; combat math in `src/combat/`.
- Static typing everywhere. Godot 3 syntax is wrong (`@export`, `@onready`, `signal.connect(callable)`, `await`).

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- **H1 (Chrome, Firefox, `?debug`):** Shift+F3 test boss; the first Dash Strike on the A→D window shows the Patched hit (`CRITICAL: 30 dmg`), the chime and the `// patched` bar; a Dash Strike off-window reads `console.log("-10") // resisted` with a thud.
- **H2:** D→A dash then slash on the link patches the phase-2 boss (after roar); the slash is `CRITICAL: 15 dmg`.
- **H3:** Ctrl+F6 queues a player hit as before; F6 kill still works.
- **H4:** release build (no `?debug`): no boss, no tag, no log change.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.2: Weak Window, Patched and Damage States]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory, FR21–FR23, FR26, FR27, FR63]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-017, D-019]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Weak Window and Patched, Rounding, Hit-stop precedence]
- [Source: _bmad-output/game-architecture.md#AD-06, NP-4 (WeakWindowTracker, BossInteraction, DamageState), Damage & Patched row]
- [Source: _bmad-output/implementation-artifacts/3-1-reusable-boss-framework.md#Design calls D-S31-1–27, Review Findings]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-2-7, story-2-8, story-3-1]

## Dev Agent Record

### Agent Model Used

claude opus (Claude Code, unattended epic pipeline, gds-dev-story)

### Debug Log References

- First full run after groups A-F (before the new tests): 16 failures in `test_boss_controller.gd`, all from its `_phase()` helper building phases with `weak_window = (0, 0)`, which the new `BossDef.validate` rule (C7) rejects. Fixed by giving the helper a valid A>D window; no production change.
- Final run: GUT 689/689 passing (11501 asserts), no `SCRIPT ERROR` / `Parse Error`, import clean. Replays (`tests/replays/test_replays.gd`) and `tests/integration/test_retry_snapshot.gd` unchanged and green. `bash game/tools/check_guards.sh` -> `check_guards: OK`.
- GUT baseline on this branch before the story was 636 (the story text says 634); +53 tests in 3.2.

### Completion Notes List

- **A.** `EventBus.patched_applied(boss, frames)`; new pure `DamageState` (BASE 0 / UNPATCHED 1 / PATCHED 2, multipliers 1.0 / 0.5 / 1.5 and 100 / 50 / 150); `BossInteraction` (HIT / PASS_THROUGH / DECOY_STRUCK, `completes_weak_window` per D-S32-6); `WeakWindowTracker` (only Patched writer: `apply_patched` sets, `tick` floors at 0, `clear`, static `process`, `PATCHED_FRAMES = 180`); `HitFeedback.PATCHED_APPLIED_HITSTOP = 4`, `CRIT_HITSTOP = 8`, `hitstop_for_boss_hit` (D-S32-8). `hitstop_for` unchanged.
- **B.** `DamageCalc.compute` asserts `base >= 0` and whole-5% state multiplier; `STATE_BASE` is now an alias of `DamageState.Kind.BASE`.
- **C.** `BossController`: `weak_window` tracker, ticked once per live tick before the FSM step (counts through ROAR, not while inactive); `is_hittable()` (GAP/TELL/ACTIVE/RECOVERY and active); `last_hit_serial` / `was_hit_by` / `mark_hit`; `take_hit` guard (inactive, no def, DEFEATED, damage <= 0 -> no-op, AC 8); tracker cleared in `reset_for_fight` and `_defeat`; `current_weak_window()`, `hit_target_id()` = `&"boss"`, `body_radius_px()`. Debug log of the new phase's weak window on phase change. `BossDef.validate`: per-phase weak window (two distinct `Register.is_bit` bits, not zero) and `name_signature` identifier of at most 16 chars.
- **D.** `ActionStateMachine.action_window` stored at `_start` from the register window, cleared in `_finish`. `CombatResolver`: nullable `boss`; with a hittable, overlapped, not-yet-hit boss the order is HIT interaction -> `WeakWindowTracker.process` -> `apply_patched(180)` + `patched_applied` -> damage with the post-patch state -> `mark_hit` + `take_hit` -> `hit_landed(&"boss", ...)`; practice targets keep x1/BASE and `hitstop_for`; one `request_hitstop` per tick with the max. `hits_for` dedupes; `PracticeTarget.hit_target_id()` replaces the hard-coded id. `Arena` sets `combat.boss` in `_set_test_boss` and clears it in `_remove_boss` / `leave_fight`; the tracker is reset only through `reset_for_fight` (single reset path).
- **E.** Test boss: phase 1 `weak_window = (1, 2)` A>D, phase 2 `(2, 1)` D>A; `max_hp` 20.
- **F.** `AudioManager`: cached `make_thud()` / `make_chime()` built in `_ready`; thud on an UNPATCHED boss `hit_landed`, chime on `patched_applied` (every application, including a refresh; see D-S32-33). `JuiceDirector`: PATCHED hit -> `request_invert(1)`. `ParticlePool.burst_for(is_combo, state)` halves for UNPATCHED. `BossView`: `// patched` tag + countdown bar (`frames_left / 180`) above the body while Patched; damage number of the last boss hit for 30 `_process` frames, 1x unpatched / 2x patched. `LogPanel.line_for_damage(damage, state)`: BASE `console.log("-N")`, UNPATCHED `console.log("-N") // resisted` drawn under the existing 50% checker, PATCHED `CRITICAL: N dmg`.
- **G.** New `test_weak_window.gd` (completion matrix, tracker apply/refresh/countdown/exact 180, DamageState, every D-S32-8 row). Extended `test_damage_calc.gd`, `test_combat_resolver.gd` (A>D Dash Strike patch 30 + hit-stop 4 + one hit per serial, resisted Dash Strike 10 + hit-stop 6, link_second slash patch 15 + hit-stop 4, solo slash never patches, crit 8, refresh to 180, practice target never patched, ROAR / DEFEATED / inactive no effect, boss + practice in one tick, `hits_for` dedupe, target ids), `test_boss_controller.gd` (take_hit guard x4, Patched across phase change and ROAR countdown, cleared on reset/defeat, frozen while inactive, `current_weak_window` per phase, `is_hittable` per state, serial, BossView helpers and damage number lifetime), `test_data_validation.gd` (test boss windows, weak-window and name rules), `test_log_panel.gd`, `test_audio_manager.gd`, `test_particle_pool.gd`, `test_juice_director.gd`. `test_register_panel.gd` follows the checker rename.
- **D-S32-8 tension (AC 2 wording):** kept the single rule. The patching hit always takes `PATCHED_APPLIED_HITSTOP` (4), so the link_second slash that patches the D>A boss takes 4, not the "normal slash" 3. AC 2's "normal slash hit-stop" is read as "not the crit 8". Recorded as D-S32-25; tests pin 4 for both AC 1 and AC 2.
- **Human checks H1-H4** (browser, `?debug`, release build) were not run (unattended); they do not block `review`.

#### New design calls made during dev

- **[design call] D-S32-25 Patching-hit hit-stop.** One rule for every patching hit: 4, even when the hit's own value is higher (Dash Strike 6) or lower (slash 3). AC 2's "normal slash hit-stop" = no crit. If playtest wants the Dash Strike patch to feel heavier, the change is `maxi(4, combo value)` in `hitstop_for_boss_hit` only.
- **[design call] D-S32-26 Where the weak-window rule lives.** In `BossDef.validate` (C7), not `PhaseDef.validate`, so a bare `PhaseDef` stays valid in phase-only tests; the error text names `phases[i] weak_window`.
- **[design call] D-S32-27 Shared checker.** `RegisterPanel._checker_texture()` renamed to public `checker_texture()` so `LogPanel` reuses the same 8x8 dither (no new helper).
- **[design call] D-S32-28 Half particles.** `ParticlePool` owns the burst on `hit_landed` (JuiceDirector does not own particles), so halving is `burst_for(is_combo, state)`: integer half for UNPATCHED (12 -> 6, 20 -> 10).
- **[design call] D-S32-29 Boss before practice targets.** The boss hit is resolved first in the tick; practice-only ticks keep their exact order and payloads (`state` 0), so replays stay bit-identical. The boss hurtbox for player hits is its body circle (`body_radius_px()`), and `hit_landed.pos` for a boss is `body_center_px`.
- **[design call] D-S32-30 G3 "solo slash -> 8".** `slash_1` is 10 damage, so the off-link solo slash test asserts 5 (10 x 0.5); the 15 -> 8 case is covered in `test_damage_calc.gd`.
- **[design call] D-S32-31 Name rule.** `name_signature` uses `String.is_valid_ascii_identifier()` (letters, digits, `_`, no leading digit) and `length() <= 16`.
- **[design call] D-S32-32 Tag and number placement.** The `// patched` tag and bar stack above the body line (over the tell `!` row); the damage number sits just below the body line so it never covers the tag.
- **[design call] D-S32-33 Chime on refresh.** `patched_applied` is emitted on every application (a refresh is an application), so the chime plays on a refresh too; D-S32-18's "not on each refresh" was read as "not on each Patched hit". Plain Patched hits never chime. Revisit with 7.2 audio.
- **[design call] D-S32-34 Thud/chime player.** Both go through the existing single `play_sfx` player (a new cue cuts the previous one); pooling is 7.2.

### File List

- game/src/combat/damage_state.gd (new)
- game/src/combat/boss_interaction.gd (new)
- game/src/combat/weak_window_tracker.gd (new)
- game/src/combat/combat_resolver.gd
- game/src/combat/damage_calc.gd
- game/src/combat/hit_feedback.gd
- game/src/autoloads/event_bus.gd
- game/src/autoloads/audio_manager.gd
- game/src/bosses/framework/boss_controller.gd
- game/src/bosses/framework/boss_def.gd
- game/src/bosses/framework/phase_def.gd
- game/src/bosses/practice_target/practice_target.gd
- game/src/player/action_state_machine.gd
- game/src/arena/arena.gd
- game/src/presentation/boss_view.gd
- game/src/presentation/juice_director.gd
- game/src/presentation/particle_pool.gd
- game/src/ui/hud/log_panel.gd
- game/src/ui/hud/register_panel.gd
- game/data/bosses/test_boss/boss_def.tres
- game/tests/unit/test_weak_window.gd (new)
- game/tests/unit/test_combat_resolver.gd
- game/tests/unit/test_boss_controller.gd
- game/tests/unit/test_damage_calc.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_log_panel.gd
- game/tests/unit/test_audio_manager.gd
- game/tests/unit/test_particle_pool.gd
- game/tests/unit/test_juice_director.gd
- game/tests/unit/test_register_panel.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/3-2-weak-window-patched-and-damage-states.md
- (Godot `.uid` sidecars for the four new scripts)

### Change Log

- 2026-11-09: Story 3.2 implemented (weak window per phase, Patched tracker, Unpatched/Patched damage on bosses, BossInteraction, per-state feedback, 3.1/2.7 deferred guards). GUT 689/689, check_guards OK. Status -> review.

### Review Findings

### Review Findings

Code review (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel), 2026-11-09. GUT 690 tests all passing (57 scripts, replays included); check_guards OK.

- [x] [Review][Patch] Killing blow's damage number never drawn (BossView `_draw` returned early on DEFEATED) [game/src/presentation/boss_view.gd] — fixed: number drawn in the DEFEATED branch.
- [x] [Review][Patch] Stale damage number carried into a restarted fight [game/src/presentation/boss_view.gd] — fixed: cleared on `boss_hp_changed` at full HP; test added.
- [x] [Review][Patch] `reset_for_fight` with null def skipped clearing `last_hit_serial`/`weak_window` [game/src/bosses/framework/boss_controller.gd] — fixed.
- [x] [Review][Defer] Hit/patch cues share the single ShiftSfx player, so overlapping cues truncate each other [game/src/autoloads/audio_manager.gd] — deferred.
- [x] [Review][Defer] Patched tag/bar and TELL mark can overlap; no top-edge clamp [game/src/presentation/boss_view.gd] — deferred to art pass (3.3).
- [x] [Review][Defer] Low-impact items: presentation-frame number lifetime, missing `_exit_tree` disconnects, `_dithered` not reset on clear, brittle hard-coded test ticks, silent BASE fallback in `DamageState.multiplier`, action overlapping boss during ROAR can land late.
- Dismissed (noise / intended): chime on every refresh (D-S32-33, deliberate); patching hit hit-stop 4 (D-S32-25); signal order (consistent); solo slash test 5 vs spec 8 (D-S32-30); phase change eating Patched frames (D-S32-14); nits.
