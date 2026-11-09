---
baseline_commit: 657dbd4
---

# Story 2.7: Combat Resolver, Damage Calc and Practice Target

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. -->

## Story

As a developer and designer,
I want hits resolved by shape math and checked on a training dummy,
so that I can verify every frame-data and damage number on screen.

**Requirements:** FR22 (base: DamageCalc, ×1 practice target, never Patched), FR59 (dev practice target); AD-04 (hit detection is custom geometry resolved inside `tick()` by one `CombatResolver`); NP-4 (order inside `CombatResolver.resolve()`: interactions, then damage, then `hit_landed`; practice target: multiplier ×1, never Patched); GDD "Weak Window and Patched" (damage table, rounding) and "Practice Target".
**Epic 2 window:** Nov 8-10. **Depends on:** Story 2.1 (`SimClock`, `ctx.poll_frame`), 2.2 (`Player.position_px`, `facing`), 2.5 (`HitShape` family, `ActionDef.hit_shape`/`base_damage`, `ActionStateMachine` state and action frames), 2.6 (`ComboDef`, Dash Strike data, `ActionStateMachine.combo`, `link_second`).
**Unblocks:** 2.8 (hit-stop precedence, particles and log lines read `hit_landed` and the combo flag), 2.9 (player damage reuses the shape math), Epic 3 (Patched and weak windows plug into the same resolver).

## Acceptance Criteria

1. **Hit registration.** Given a player action in its ACTIVE state with a `hit_shape`, when the shape overlaps a target's hurtbox on an ACTIVE frame, then the target is hit once per action (not once per frame), with no `Area2D`, `PhysicsBody2D` or other physics body. `CombatResolver` runs once per tick in the COMBAT phase, after the ACTIONS and PLAYER phases. The shape is anchored at the action's start position (D-S27-13), so Dash Strike covers the 5-tile path it travels.

2. **Shape overlap.** Given `HitCircle`, `HitArc` and `HitCapsule`, when asked whether the shape overlaps a circular hurtbox (`overlaps(origin, facing, centre, radius_px)`), then the answer is true when any part of the hurtbox touches the shape. A zero facing means "no direction": the arc then tests as a full circle, and the capsule collapses to a circle (D-S27-1, closes a 2.5 deferral).

3. **DamageCalc.** Given `DamageCalc.compute(base, state_mult, clean_catch, echo_scale)`, when called, then it multiplies all factors (Clean Catch ×1.5 when `clean_catch`) and rounds half up once (`floori(x + 0.5)`), computed in integer percent so float drift cannot change a result (D-S27-6). `tests/unit/test_damage_calc.gd` asserts the GDD examples: 15 × 0.5 = 8; 10 × 0.7 = 7; 15 × 0.7 = 11; 15 × 0.7 × 1.5 = 16; 20 × 1.5 = 30; 20 × 0.5 = 10; 30 × 1.5 × 1.5 = 68.

4. **Practice target.** Given the practice target `/* test */` (infinite HP, no attacks, never Patched), when I hit it, then it takes base damage through `DamageCalc` with multiplier ×1, it shows a per-hit damage log and a frame counter (the sim frame of each hit), and `EventBus.hit_landed` is emitted once per hit.

5. **Reachability.** Given a debug build (`Debug.enabled`), when I press Shift+F2, then FIGHT starts with the practice target placed in the arena, and a fight retry keeps it. Without the debug gate the target and the key do not exist (D-S27-3).

6. **Resolver parameter object.** Given `ActionResolver.resolve` took 11 positional arguments (2.5 and 2.6 deferral, C6), when this story lands, then it takes one `ResolveInput` object, and every behaviour covered by the 2.5 and 2.6 tests is unchanged.

7. **Guards.** `bash game/tools/check_guards.sh` prints OK. Simulation folders reference no `ui/`, `presentation/` or audio. Presentation draws with `Palette.INK` or `Palette.BG` only.

8. **Tests.** `tests/unit/test_damage_calc.gd`, `tests/unit/test_combat_resolver.gd` and `tests/unit/test_practice_target.gd` are new. `test_hit_shapes.gd`, `test_action_resolver.gd`, `test_action_fsm.gd` and `test_debug_keys.gd` are extended. Full GUT run is green, and Main boots headless for 120 frames without errors.

## Scope Boundaries

- **In:** `DamageCalc`, the `overlaps` method on the hit shapes, `CombatResolver` (a `SimSystem` in COMBAT), `PracticeTarget` (sim data), its presentation, the `hit_landed` signal, the shape anchor and action serial on the FSM, the `ResolveInput` cleanup, Shift+F2, tests.
- **Out (later stories):** hit-stop requests and precedence (2.8), particles, screen shake and log panel (2.8; this story uses a text readout in the arena), player damage and death (2.9), Patched, `WeakWindowTracker`, decoys, pass-through and Clean Catch wiring (Epic 3 and 5; the parameter exists and is `false`/`1.0` here), damage states UNPATCHED and PATCHED (Epic 3), `requires_first_active` (6.2).
- **Not changed:** the 2.5 frame data, cancel and chain rules, the 2.6 combo and link rules (their tests must keep passing), the 8-frame `InputBuffer`, the Register and `Player` movement.

## Tasks / Subtasks

### Group A: Resolver parameter object (AC: 6)

- [x] A1. `game/src/player/resolve_input.gd` (`class_name ResolveInput extends RefCounted`): typed fields `buffer`, `frame`, `window`, `action`, `action_frame`, `chain_key`, `chain_serial`, `shift_serial`, `cooldowns`, `link`, `combos`, with defaults that match today's optional arguments. `ActionResolver.resolve(input: ResolveInput) -> ActionRequest` keeps every rule, helper and return value as it is today.
- [x] A2. `ActionStateMachine.tick` builds one `ResolveInput` per tick. Tests build it through a small helper in `test_action_resolver.gd`. Grep the tree after the change: no caller of the old 11-argument form remains.

### Group B: Shape overlap and anchoring (AC: 1, 2)

- [x] B1. `HitShape.overlaps(origin: Vector2, facing: Vector2, centre: Vector2, radius_px: float) -> bool`: base returns false. `HitCircle`: distance from origin to centre <= radius + `radius_px`. `HitCapsule`: distance from centre to the origin-to-tip segment <= radius + `radius_px`; a zero facing is a circle. `HitArc`: the centre is within radius + `radius_px`, and the sector test is widened by the angle `asin(radius_px / distance)` (a centre inside `radius_px` always counts). A zero facing is a full circle (D-S27-1).
- [x] B2. `ActionStateMachine`: `action_origin_px: Vector2` is set in `_start` from `Player.position_px` (or `Vector2.ZERO` without a player), like the captured facing (D-S27-13). `action_serial: int` increments on every action start and is never reset in a session. The FSM is still the only writer.
- [x] B3. `test_hit_shapes.gd`: overlap cases for each shape, the edge tangent case, zero-facing rules, and a centre inside the shape with a large radius.

### Group C: DamageCalc (AC: 3)

- [x] C1. `game/src/combat/damage_calc.gd` (`class_name DamageCalc`, RefCounted, static only): `compute(base: int, state_mult: float, clean_catch: bool, echo_scale: float) -> int`. Multipliers are converted to integer percent (`roundi(x * 100)`), multiplied as integers with the base, and rounded half up with one division. Clean Catch is 150 percent. Pure: no node, no state.
- [x] C2. `test_damage_calc.gd`: the seven GDD examples from AC3; Clean Catch alone (10 → 15); identity (`1.0`, false, `1.0`) returns the base; base 0 returns 0; a result on a .5 boundary rounds up (7.5 → 8).

### Group D: Practice target and CombatResolver (AC: 1, 4, 5)

- [x] D1. `game/src/bosses/practice_target/practice_target.gd` (`class_name PracticeTarget`, RefCounted, sim data only): `position_px: Vector2`, `hurtbox_radius_px` (1.5 tiles, D-S27-2), `hits: int`, `last_hit_serial: int = -1`, and a fixed-capacity ring of the last 8 hit records (sim frame, action id, damage). Methods: `register_hit(serial, frame, action_id, damage) -> void` and `reset() -> void` (fight start, retry). No HP field: infinite HP is the absence of damage state.
- [x] D2. `game/src/combat/combat_resolver.gd` (`class_name CombatResolver extends SimSystem`, `phase = COMBAT`): fields `actions: ActionStateMachine`, `player: Player`, `targets: Array[PracticeTarget]`. A pure static `hits_for(shape, origin, facing, targets, serial) -> Array[PracticeTarget]` returns the targets the shape overlaps that are not yet hit by this serial. `tick(ctx)`: returns unless the FSM is ACTIVE with a non-null `hit_shape`; for each hit, damage = `DamageCalc.compute(action.base_damage, 1.0, false, 1.0)`, `target.register_hit(...)`, `Log.debug(&"combat", "hit %s dmg=%d" % ...)`, then `EventBus.hit_landed.emit(&"practice_target", damage, DAMAGE_BASE, actions.combo != null, target.position_px)`.
- [x] D3. `EventBus` gains `signal hit_landed(target: StringName, damage: int, state: int, is_combo: bool, pos: Vector2)` with `@warning_ignore("unused_signal")`. `state` is `DamageCalc.STATE_BASE` (0) until Epic 3 adds UNPATCHED and PATCHED (D-S27-7).
- [x] D4. `game/src/presentation/practice_target_view.gd` (`class_name PracticeTargetView extends Node2D`): draws `/* test */` at 2x centred on the target in INK, and at 1x in the bottom-left of the play area a readout: `hits N`, then the last three hit lines `f=<frame> <action> <dmg>`. Reads sim state only. Main attaches it, as it does for `PlayerView`, because `arena/` may not reference `presentation/`.
- [x] D5. `Arena`: owns `combat: CombatResolver` (registered in `_enter_tree` after `actions`, unregistered in `_exit_tree`) and `practice_target: PracticeTarget` (null unless requested). `enter_fight` gains a `with_practice: bool = false` argument; when true, the target is placed at `SPAWN_PX + Vector2(4 * TILE_PX, 0)` (D-S27-2) and reset. Existing call sites keep working.
- [x] D6. `DebugKeys`: Shift+F2 checked before the plain F1-F5 table: `Debug`-gated route to FIGHT boss index 0 with the practice target requested. Plain F2 is unchanged. Main passes the request to the Arena (store it where the existing fight route reads it; do not add a global that release code can see). Overlay: the F9 overlay also draws the target hurtbox circle when a target exists (optional, one `draw_arc`).

### Group E: Tests (AC: 8)

- [x] E1. `test_combat_resolver.gd`: `hits_for` hits a circle in range and misses one out of range; a target is hit once per serial and again on a new serial; through the real FSM and `SimClock`-free ticking: Dash Strike from spawn hits a target 4 tiles ahead on its first ACTIVE frame and never a target 12 tiles behind; slash does not hit during STARTUP or RECOVERY; `hit_landed` emitted once per hit with `DAMAGE_BASE` and the combo flag; the damage of slash_1/2 is 10 and slash_3 is 15 on the target.
- [x] E2. `test_practice_target.gd`: hit count, the ring keeps the last 8 records in order, `reset` clears hits and `last_hit_serial`, the target never reports a multiplier other than ×1.
- [x] E3. `test_debug_keys.gd`: Shift+F2 maps to FIGHT with the practice request; plain F2 does not; release gate keeps both out.
- [x] E4. `test_glyph_palette.gd` source list gains `practice_target_view.gd`; `test_font_coverage.gd` covers `/* test */` and the readout strings (ASCII only).
- [x] E5. `test_action_fsm.gd` (extended): `action_origin_px` is the player's position at start and does not follow a dash; `action_serial` increments per start only.

### Group F: Verification (AC: 7, 8)

- [x] F1. `godot --headless --path game --import` once in the fresh worktree (new `class_name`s), then the full GUT run, then `bash game/tools/check_guards.sh` from the repo root, then Main headless for 120 frames with no errors. Record the test count and the guard output in Completion Notes.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S27-1 Overlap and zero facing.** Hit-vs-hurtbox is circle overlap (`overlaps`), not point-in-shape, so a target counts when its edge touches the shape. A zero facing collapses the arc to a full circle; the capsule already collapses to a circle. This also closes the 2.5 deferral "HitArc returns false for zero facing while HitCapsule collapses".
- **[design call] D-S27-2 Practice target placement and hurtbox.** Target centre at `SPAWN_PX + (64, 0)` (4 tiles right of spawn), hurtbox circle radius 1.5 tiles (about 24 px, enough to read as a `/* test */` block and to be reachable from the 1.5-tile slash arc). Judge in H1.
- **[design call] D-S27-3 Reachability.** Shift+F2 starts FIGHT with the target. Release builds have neither the key nor the target. Plain F2 keeps its 2.5 meaning. No boss is present in 2.7, so the dummy is the only target in that fight.
- **[design call] D-S27-4 Hit once per action per target.** The target stores `last_hit_serial`; the resolver skips a target whose serial matches the running action. A second action (even the same slash) is a new serial and can hit again.
- **[design call] D-S27-5 First overlapping ACTIVE frame registers the hit.** No hit is delayed to the end of ACTIVE. The resolver runs after the FSM's frame, so the state it reads is the frame that just executed.
- **[design call] D-S27-6 Integer rounding.** The GDD multipliers are multiples of 5 percent, so percent integers are exact. Example: 15 × 70 × 150 = 157500 percent-units; rounded half up over 10000 gives 16. Floating point `15.0 * 0.7 * 1.5` may land a hair under 15.75 or 10.5 and round wrong with a naive `floori(x + 0.5)`; the integer form avoids that without an epsilon.
- **[design call] D-S27-7 State value in the signal.** `hit_landed.state` carries `DamageCalc.STATE_BASE` (0) now, meaning "×1, not a boss". Epic 3 introduces the damage-state enum; the signal's type stays `int`.
- **[design call] D-S27-8 Log and readout.** Per-hit lines go through `Log.debug(&"combat", ...)` (events, never per frame). The "frame counter" is the sim frame stamp on each hit line (the `[f=...]` prefix format), shown in the arena readout. The real HUD log panel with its ring buffer is Story 2.8; the in-arena readout is a temporary stand-in and is removed when 2.8 lands.
- **[design call] D-S27-9 Presentation attachment.** `PracticeTargetView` is attached by Main when the Arena has a target, the same way `PlayerView` is attached; it reads `PracticeTarget` and never writes it.
- **[design call] D-S27-10 Practice target is not a boss.** It lives in `bosses/practice_target/` only because the architecture puts it there. It has no FSM, no attacks and no `tick`; `CombatResolver` owns its hit bookkeeping through `register_hit`.
- **[design call] D-S27-11 Resolver location and injection.** `CombatResolver` gets its inputs by injection (FSM, Player, targets list), like `ActionStateMachine`, so tests build it without a scene. It holds no node.
- **[design call] D-S27-12 Hit-stop and feedback are not requested here.** `CombatResolver` does not call `SimClock.request_hitstop` in 2.7. Story 2.8 adds the hit-stop precedence (crit 8 > combo 6 or 8 > normal 3) in the same place.
- **[design call] D-S27-13 Shapes anchor at the action start.** The shape origin is `action_origin_px`, captured at the action's start like the facing (D-S25-6). Without the anchor, Dash Strike's 5-tile capsule would move with the player and reach about 10 tiles ahead over the dash. With it, the capsule covers exactly the dash path, which is what the 2.6 story already says it covers. Stationary actions are unchanged because the player does not move during them.
- **[design call] D-S27-14 Combo flag.** `is_combo` in `hit_landed` is `actions.combo != null`, so a Dash Strike hit is a combo hit. A `link_second` solo hit is not.

### Hit data (from 2.5 and 2.6; unchanged)

| Action | Hit shape (anchor = action start) | Base damage | First hit on the target | Hits per action |
|---|---|---|---|---|
| slash_1 | arc 120 deg, 1.5 tiles, ACTIVE frames 1-4 of 6/4/12 | 10 | first overlapping ACTIVE frame | 1 per target |
| slash_2 | same arc as slash_1 | 10 | same | 1 per target |
| slash_3 | same arc as slash_1 | 15 | same | 1 per target |
| dash_strike (A→D, K) | capsule 5 tiles, radius 0.75, ACTIVE frames 1-12 of 0/12/8 | 20 | first ACTIVE frame whose capsule overlaps the target | 1 per target |
| dash (D, solo) | none (`hit_shape` null) | 0 | never | 0 |

Example, Dash Strike from spawn facing right: spawn is (256, 144) px. The target is at (320, 144). The capsule runs from (256, 144) to (336, 144) with radius 12 px, and the target radius is 24 px. Overlap starts on the first ACTIVE frame, once. Facing left, the same target is never hit.

### Architecture guardrails (must follow)

- Hit detection is shape math resolved inside `tick()` by one `CombatResolver` (AD-04, ADR-02). No `Area2D`, no `PhysicsBody2D`, no `Timer`, no `delta`, no `await`.
- `CombatResolver` is a `SimSystem` in the COMBAT phase. Only `SimClock` calls `tick`.
- Damage numbers come only from `DamageCalc.compute()` (single writer; round half up once).
- Defs are read-only at runtime. Mutable hit state lives on `PracticeTarget` and the FSM.
- Single writers: the FSM owns action state (including the new origin and serial), `Player` owns position, `PracticeTarget` owns its hit record.
- Simulation folders (`combat/`, `player/`, `bosses/`, `arena/`) must not reference `ui/`, `presentation/`, `AudioManager` or `VoiceService`. `PracticeTargetView` and the Main attachment are the presentation side.
- Signals are declared only in `event_bus.gd`, past tense, typed arguments, no Dictionary payloads.
- Typing: every variable, parameter and return is typed; `StringName` for ids (`&"practice_target"`).
- `Log.debug` on events only. Palette: `Palette.INK` and `Palette.BG` only in drawing; overlay and readout text ASCII at 1x through `GlyphFont`.
- Simulation code must run without a scene tree (tests build the resolver from defs and a fake `Player`/FSM).

### Previous story intelligence (2.5 and 2.6)

- 2.6 notes: a fresh worktree needs `godot --headless --path game --import` before GUT, or new `class_name`s do not register.
- 2.6 kept `ActionResolver` pure; its extra arguments (`link`, `combos`) were the start of the 11-argument signature that A1 replaces.
- 2.6 `ActionStateMachine` already exposes `combo`, `link_second` and `action_slot` for this story, and `facing` is already captured at start.
- 2.5 deferred items this story closes: "HitArc zero-facing vs HitCapsule" (D-S27-1); "FrameOverlay hurtbox diameter vs radius" (the overlay already halves `hurtbox_tiles`; this story uses the same radius for the target and documents it); "resolve takes 9 positional args" (now `ResolveInput`).
- 2.6 deferred items that stay deferred: `ComboDef.validate` gaps, `ComboTable` lazy index, `left N` before the count starts, the DROP branch, `format_lines` arity, the `ActionRequest`/`ActionResolver` cycle.
- 2.3 deferred: "Hit-stop longer than 8 frames drops all buffered input" (unchanged here; no hit-stop yet).

### Latest technical information

- No new engine features or libraries. Godot 4.7.2 (pinned), GDScript: `Geometry2D.get_closest_point_to_segment`, `Vector2.normalized` (zero stays zero), `roundi`, `floori`, typed `Array[PracticeTarget]`. Confirm exact names against the existing code before use.
- No web research was run for this story; nothing in it depends on a changed API.

### Project Context Rules

- Godot project root is `game/`. Files: `game/src/combat/combat_resolver.gd`, `game/src/combat/damage_calc.gd`, `game/src/combat/shapes/` (edits), `game/src/bosses/practice_target/practice_target.gd`, `game/src/player/resolve_input.gd`, `game/src/presentation/practice_target_view.gd`, `game/tests/unit/`.
- `project-context.md`: "Hits are shape math (`HitCircle`, `HitArc`, `HitCapsule`) in `CombatResolver`"; "Single writers: damage → `DamageCalc.compute()`" (multiply all factors, round half up once); "The practice target is always ×1 and never Patched"; "Use the GDD's worked numbers as test cases"; "`test_data_validation.gd` loads every `.tres`" (no new `.tres` in this story, so it stays green as is).

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.7 H1] Debug build, Shift+F2 (Chrome and Firefox): the dummy `/* test */` is placed 4 tiles right of the `@`, the readout is legible, and a retry (F2 route or the retry flow) keeps it. Note whether the 1.5-tile hurtbox reads right (D-S27-2).
- [ ] [2.7 H2] Hit counts on the dummy: slash_1 and slash_2 log `dmg=10`, slash_3 logs `dmg=15`, Dash Strike logs `dmg=20` exactly once per dash, never more than once on the same dash. No hit on the `[D, A]` solo dash.
- [ ] [2.7 H3] Dash Strike reach from the start point: a target 4 tiles ahead is hit on the first ACTIVE frame; a target 8 tiles ahead is not hit (reach is 5 + 0.75 capsule radius + 1.5 hurtbox radius = 7.25 tiles from the start point, so 7 tiles ahead is still a hit). Note whether the capsule width (0.75 tiles) feels right (carries over from 2.6 H2).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.7] (ACs, FR22, FR59)
- [Source: _bmad-output/planning-artifacts/epics.md#FR22, FR26, FR59] (damage states, practice target, hit-stop table)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Weak Window and Patched] (damage table, rounding, practice target)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Practice Target]
- [Source: _bmad-output/game-architecture.md#NP-4] (CombatResolver order, practice target rule)
- [Source: _bmad-output/game-architecture.md#AD-04, ADR-02] (shape math, no Area2D)
- [Source: _bmad-output/game-architecture.md#Communication Patterns] (`hit_landed` signature)
- [Source: _bmad-output/implementation-artifacts/2-5-action-state-machine-with-attack-and-dash.md] (hit shapes, D-S25-6, D-S25-10, review deferrals)
- [Source: _bmad-output/implementation-artifacts/2-6-ordered-combo-engine-and-dash-strike.md] (Dash Strike data, D-S26-1 to D-S26-14, review deferrals)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (2.5 and 2.6 review deferrals)

## Dev Agent Record

### Agent Model Used

Story created by Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended).
Implemented by Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story (unattended).

### Debug Log References

- Fresh worktree: `godot --headless --path game --import` run before GUT (new `class_name`s: `ResolveInput`, `DamageCalc`, `CombatResolver`, `PracticeTarget`, `PracticeTargetView`).
- Mutation check: anchoring the resolver at `player.position_px` instead of `action_origin_px` fails `test_dash_strike_reach_is_anchored_at_the_start` (10/11), so the anchor is covered.

### Completion Notes List

- **A (AC6).** `ResolveInput` (11 typed fields, defaults = the old optional arguments). `ActionResolver.resolve(input)` unpacks it and keeps every helper unchanged; `ActionStateMachine._resolve_input()` builds one per tick. Tests build it via `_req_input()` in `test_action_resolver.gd` (named so it does not shadow `Node._input`). Grep: no 11-argument caller remains. All 2.5/2.6 resolver and FSM tests pass unchanged in behaviour.
- **B (AC1, AC2).** `HitShape.overlaps(origin, facing, centre, radius_px)` on all shapes. FSM gains `action_origin_px` (player position at `_start`, before the PLAYER phase moves it) and `action_serial` (incremented on every start, never reset). F9 overlay now draws the active shape at `action_origin_px` and the target hurtbox circle.
- **C (AC3).** `DamageCalc.compute` in integer percent over `DEN = 100^3`, half up via `(2 num + DEN) div (2 DEN)`; non-positive products return 0. GDD examples, table rows, Clean Catch, identity, zero and .5 boundaries tested.
- **D (AC1, AC4, AC5).** `PracticeTarget` (ring of 8 records, `register_hit`, `was_hit_by`, `damage_multiplier()` = 1.0, `reset`, no HP). `CombatResolver` (COMBAT phase, injected FSM/Player/targets, pure `hits_for`), registered by the Arena after the player. `EventBus.hit_landed` added. `Arena.enter_fight(fight_start, with_practice = false)` places the target at `PRACTICE_TARGET_PX` = spawn + 4 tiles and resets it, or clears it. `DebugKeys.practice_requested` (set by Shift+F2, cleared by any other jump key) is read by `Main.wants_practice()` on every FIGHT entry, so a retry keeps the target; release builds have no DebugKeys node, no `PracticeTargetView`, and `wants_practice()` is false.
- **[design call] D-S27-1 refined: exact circle-vs-sector test.** The story's `asin(radius_px / distance)` widening over-reports near the outer corners of the arc (a hurtbox just past the arc's corner, inside `radius + radius_px` and inside the widened angle, does not actually touch). `HitArc.overlaps` instead tests: centre within the angle and within `radius + radius_px`, or within `radius_px` of either straight edge segment (covers the centre-near-origin case). Same results on every case the story lists, exact at the corners.
- **[design call] HitArc.contains with zero facing now returns true** (full circle), matching `overlaps` and `HitCapsule` (closes the 2.5 deferral for both methods; no caller passed a zero facing before).
- **[design call] `/* test */` label drawn at 1x, not 2x.** At 2x the label is 160 px (10 tiles) wide; centred 4 tiles right of spawn it would cover the spawn `@`. At 1x (80 px) it clears the `@` (tested) and sits closer to the 48-px hurtbox. Revisit in H1.
- **[design call] Hit frame stamp = `SimClock.sim_frame`** read during the COMBAT tick, which equals the `[f=...]` prefix of the `Log.debug(&"combat", ...)` line for the same hit (D-S27-8).
- **[design call] Readout on a BG rectangle** (bottom-left, one tile inside the tree ring) so grass glyphs never cut through the text. Uses only INK and BG.
- **[design call] Shift+F2 request lives on the DebugKeys node** (`practice_requested`), not on Game or Arena: release code has no node to read it from. Shift+F1/F3/F4/F5 fall back to their plain meaning, as before.
- 2.5 deferrals closed here (for `deferred-work.md` triage at review): HitArc zero facing; resolve positional arguments (now `ResolveInput`). The overlay hurtbox already uses radius = diameter / 2; the target uses `hurtbox_radius_px` directly.
- **F (AC7, AC8).** Full GUT: 45 scripts, 484/484 tests, 6783 asserts, all passing. `bash game/tools/check_guards.sh`: `check_guards: OK`. Main headless `--quit-after 120`: no errors or warnings. No `Area2D`/physics bodies; sim folders reference no `presentation/`, `ui/` or audio.
- Human checks H1-H3 are open for Tiziano (browser: Shift+F2 placement and readout legibility, per-hit damage lines, Dash Strike reach 7 vs 8 tiles).

### File List

- game/src/player/resolve_input.gd (new)
- game/src/player/action_resolver.gd (modified)
- game/src/player/action_state_machine.gd (modified)
- game/src/combat/damage_calc.gd (new)
- game/src/combat/combat_resolver.gd (new)
- game/src/combat/shapes/hit_shape.gd (modified)
- game/src/combat/shapes/hit_circle.gd (modified)
- game/src/combat/shapes/hit_arc.gd (modified)
- game/src/combat/shapes/hit_capsule.gd (modified)
- game/src/bosses/practice_target/practice_target.gd (new)
- game/src/presentation/practice_target_view.gd (new)
- game/src/autoloads/event_bus.gd (modified)
- game/src/arena/arena.gd (modified)
- game/src/debug/debug_keys.gd (modified)
- game/src/debug/frame_overlay.gd (modified)
- game/src/main/main.gd (modified)
- game/tests/unit/test_damage_calc.gd (new)
- game/tests/unit/test_combat_resolver.gd (new)
- game/tests/unit/test_practice_target.gd (new)
- game/tests/unit/test_hit_shapes.gd (modified)
- game/tests/unit/test_action_resolver.gd (modified)
- game/tests/unit/test_action_fsm.gd (modified)
- game/tests/unit/test_debug_keys.gd (modified)
- game/tests/unit/test_glyph_palette.gd (modified)
- game/tests/unit/test_font_coverage.gd (modified)
- (plus the Godot-generated `.gd.uid` files of each new script)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 2-7 -> review)

### Review Findings

Three parallel layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor) ran as separate subagents. No AC violations.

- [x] [Review][Patch] `Arena.leave_fight` left a stale practice target and resolver target list [game/src/arena/arena.gd] (Edge + Auditor + Blind)
- [x] [Review][Patch] `HitCapsule` zero-facing collapse relied on `normalized()` accident; now explicit via `_tip` [game/src/combat/shapes/hit_capsule.gd]
- [x] [Review][Patch] No resolver test for a non-RIGHT facing; added `test_facing_left_hits_the_left_target_and_never_the_right` and `test_leave_fight_drops_the_practice_target`
- [x] [Review][Defer] [design call] `practice_requested` outlives the retry path (kept: retry must keep the target) — deferred, see deferred-work.md
- [x] [Review][Defer] DamageCalc negative/non-5-percent/overflow guards — deferred until Epic 3 passes real multipliers
- [x] [Review][Defer] HitArc concave-sector and corner tests, unused `player` in CombatResolver, hard-coded hit id, per-tick allocation, redraw per frame, extra test gaps — deferred, low risk
- Dismissed (about 12): label 1x vs 2x (recorded design call), `asin` vs sector refinement (recorded), Shift+F2 while already in FIGHT (verified: `_set_flow_state` does not skip same-state), `hit_landed` frame stamp, shared-array and style nits, etc.

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S27-1 to D-S27-14 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): ResolveInput, shape overlap and anchor, DamageCalc, CombatResolver, PracticeTarget and view, Shift+F2. 484/484 GUT tests, guards OK. Status review.
- 2026-11-07: Code review (gds-code-review, 3 parallel layers): 3 patches applied, 3 deferred groups, about 12 dismissed. 489/489 GUT tests, guards OK. Status done.
