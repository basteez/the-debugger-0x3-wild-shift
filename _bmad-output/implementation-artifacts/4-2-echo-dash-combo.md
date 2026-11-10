---
baseline_commit: 43b93a4
---
# Story 4.2: Echo Dash Combo

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-10). Open design questions are marked [design call] with the chosen default (D-S42-n); the implementer follows them or records a change in Completion Notes. Scope: the D->L combo Echo Dash (second redirectable dash, 0/10/6, continuous invulnerability), the PASS_THROUGH producer (BossInteraction stub from 3.2 becomes real), the test-boss weak-window completion, and the Story 4.1 deferred items that belong here. NOT in scope: Breakpoint (4.3), the duck hint (4.4), Ghost Echo / decoy (6.1), the Null Pointer 60-frame reveal (5.1, FR37), any HUD cooldown or combo art. -->

## Story

As a player,
I want D then L to chain two invulnerable dashes,
so that I can pass through a boss and reveal or patch it.

## Acceptance Criteria

1. **Data.** `data/actions/echo_dash.tres` is an `ActionDef` with `id = &"echo_dash"`, `startup_frames = 0`, `active_frames = 10`, `recovery_frames = 6`, `invuln_from = 1`, `invuln_to = 10`, `move_tiles = 4.0`, `base_damage = 0`, `cooldown_frames = 0`, `echoable = false`, `echo_action = false`, `redirectable = true`, `pass_through = true`, empty `cancel_into`, and a `HitCapsule` hit shape of `length_tiles = 4.0`, `radius_tiles = 0.5` [design call D-S42-6]. `data/combos/echo_dash.tres` is a `ComboDef` with `first = Register.Bit.DASH`, `second = Register.Bit.LOOP`, `action` = that def, `display_name = "Echo Dash"`. It is added to `data/combos/combo_table.tres`. `ComboTable.validate()` and `ActionDef.validate()` return empty for the shipped table.

2. **Trigger and cost.** Given the window `[D, L]` (D in slot 1, L in slot 2) and the first dash is in ACTIVE, when I press K on the first dash's frames 1-8 (gap-free window, D-S42-4 resolved; the GDD's 18-frame window is superseded), then Echo Dash fires and replaces Echo (K's solo action). The window's combo wins over Echo's memory gate: Echo Dash needs no stored action (`echo_ready` is not consulted for combos). LOOP's cooldown of 90 frames starts (the replaced solo's cooldown, D-S26-3). DASH's cooldown is the one the first dash started and is not touched again. `EchoMemory` is not written by Echo Dash.

3. **Invulnerability.** Echo Dash is invulnerable on its own frames 1-10. The first dash's invulnerability (frames 1-8) is continuous with Echo Dash's when K is pressed on the first dash's frames 1-9: no executed frame between the first dash's frame 1 and Echo Dash's frame 10 is vulnerable. A press after dash frame 8 is refused (consumed and dropped), so no accepted press leaves a vulnerable gap [D-S42-4 resolved, D-S42-11].

4. **Redirect.** Echo Dash moves 4 tiles (`move_tiles`) in the direction of my current input at the press tick, sanitized to one of the 8 directions (`Player.sanitize_dir(ctx.move_dir)`). If there is no input at that tick, it uses the first dash's facing. Its hit capsule uses the same direction and its origin is my position at the press (`action_origin_px`).

5. **PASS_THROUGH producer.** Given Echo Dash's capsule overlaps a hittable boss hurtbox (for Infinite Loop, an open `;`), `CombatResolver` emits one `BossInteraction` of kind `PASS_THROUGH` with `window_pair` = the action's window (D->L), runs `WeakWindowTracker.process`, and marks the boss hit by that action's serial, so it fires at most once per action. If the window matches the boss's current weak window, Patched is applied for 180 frames and `patched_applied` is emitted (through the tracker, the only Patched writer).

6. **No damage.** Echo Dash deals no damage: no `take_hit` and no `hit_landed` for it, no hit-stop, and it never hits practice targets (`pass_through` defs skip `hits_for`) [design call D-S42-2].

7. **Test-boss weak window.** With a test boss whose weak window is D->L, Echo Dash through its hurtbox completes the window: Patched is set (180 frames), and a later hit by a non-Echo action during Patched takes the x1.5 multiplier (Patched damage state). A PASS_THROUGH on the wrong window (e.g. L->A) does not complete it. A PASS_THROUGH while the boss is not hittable (closed `;`) produces no interaction.

8. **Story 4.1 deferred items folded in** (`deferred-work.md`, 4.1 review):
   - (a) an end-to-end weak-window test for Echo as K's `link_second` on a boss: it uses a no-combo window that the shipped table does not hold, `[A, L]` via an injected `ComboTable` with no entries [design call D-S42-7]; `CombatResolver` produces `HIT` with `is_link_second = true`, which completes the window per NP-4, and the solo-HIT rule still holds on a window without the link;
   - (b) an echoed def with `cancel_into` cancels into other bits, and an Echo run opens a link on (L, y) like any J solo: both pinned by tests;
   - (c) the 4.1 test `test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown` (D->L with K as Echo link_second) is rewritten to Echo Dash, and `test_unknown_pairs_are_null` in `tests/unit/test_combo_table.gd` drops `(D, L)` from the null list. Both changes are recorded with the reason in Completion Notes (AC 9).

9. **Combo validation.** `ComboDef.validate()` gains the three checks from the 2.6 deferred note: the second bit has a solo def (`Defs.solo_action(second) != null`), the combo action's `cooldown_frames == 0`, and the first bit's solo startup + 1 <= 8 (buffered K stays live until the link opens) [design call D-S42-8]. The "Dereference" label check stays with Story 6.2.

10. **Determinism and rules.** No RNG, no `delta`, `Timer`, `await` or float state beyond the existing capsule and hit math. Echo Dash's start logs once through the existing combo log line (`Log.debug(&"action", ...)`). Simulation folders (`src/player`, `src/combat`, `src/register`) do not reference `ui`, `presentation` or audio classes. The replay tests (`tests/replays/`, `tests/integration/test_infinite_loop_replay.gd`) still pass. If a recorded session presses K on a `[D, L]` window, its hash changes: the story records it and updates the expectation with the reason, never silently.

11. **Scope fence.** No Breakpoint, no feature flag, no Ghost Echo, no Null Pointer reveal (60 frames, 5.1), no new SFX, VFX or HUD. `BossInteraction` keeps the `DECOY_STRUCK` stub for 6.1.

12. **Tests.** Unit tests for AC 1-9 (see Tasks Group F). Full GUT run headless passes and the guards (`bash game/tools/check_guards.sh`) pass. Test count recorded in Completion Notes.

## Tasks / Subtasks

### Group A: Data (AC: 1, 9)
- [x] A1. `ActionDef` fields: `@export var redirectable: bool = false` (the echo direction comes from input at start), `@export var pass_through: bool = false` (boss overlap yields PASS_THROUGH, no damage). `validate()`: `pass_through` requires `hit_shape != null` and `base_damage == 0`; `redirectable` requires `move_tiles > 0`.
- [x] A2. Create `data/actions/echo_dash.tres` (values in AC 1; header comment: second dash of the D->L combo; the damage is 0 by design, the boss only sees PASS_THROUGH).
- [x] A3. Create `data/combos/echo_dash.tres` (`ComboDef`, pattern of `data/combos/dash_strike.tres`) and add it to `data/combos/combo_table.tres`.
- [x] A4. `Defs`: `const ECHO_DASH: ActionDef = preload("res://data/actions/echo_dash.tres")` if a constant is useful for tests; the table is still `Defs.COMBOS`.
- [x] A5. `ComboDef.validate()`: the three checks of AC 9 (`Defs.solo_action(second)`, `action.cooldown_frames == 0`, `Defs.solo_action(first).startup_frames + 1 <= 8`). Keep `ComboDef.NAME_MAX_CHARS` as is.

### Group B: Action start and redirect (AC: 2, 3, 4)
- [x] B1. `ActionStateMachine.tick(ctx)` passes `ctx.move_dir` into `_start` (new trailing parameter with default `Vector2i.ZERO`, so existing test call sites keep compiling).
- [x] B2. `_start`: when `request.def.redirectable` the FSM `facing` is `Player.sanitize_dir(move_dir)` if non-zero, else the captured facing (AC 4). It applies to the capsule and to `dash_velocity` (both read `facing`). Not written back to `Player.facing`.
- [x] B3. Combo start path (already `request.combo != null`) stays: no `echo.remember`, `link.close()`, `_clear_chain()`, cooldown from the replaced solo (ECHO = 90). Verify with a test; no change in logic expected.
- [x] B4. Invulnerability: no new mechanism. The continuity of AC 3 falls out of the existing per-frame check (`invulnerable()` reads the running action's frame) because the combo replaces the running dash on the press tick. Superseded by D-S42-4/D-S42-11: presses after dash frames 1, 5, 8 are continuous; after 9, in recovery and after the dash they are refused.

### Group C: PASS_THROUGH producer (AC: 5, 6, 7)
- [x] C1. `CombatResolver.tick`: when `def.pass_through`, skip the practice-target hit list (`hits_for` not used) and route the boss overlap to a new `_resolve_pass_through(def, serial)`; no damage, no `take_hit`, no `hit_landed`, no hit-stop request (AC 6).
- [x] C2. `_resolve_pass_through`: build `[BossInteraction.new(Kind.PASS_THROUGH, actions.action_window)]`, call `WeakWindowTracker.process(...)` with the boss's `current_weak_window()`, on applied `boss.weak_window.apply_patched(180)` and `patched_applied` (same as the HIT path), then `boss.mark_hit(serial)`.
- [x] C3. Check `BossInteraction` (no change expected): `PASS_THROUGH` completes on window match only (already tested in 3.2 G2). Update the header comment: PASS_THROUGH now has a producer (Echo Dash, 4.2).
- [x] C4. `boss_overlapped` / `overlaps_shape` unchanged: the Infinite Loop's closed `;` is already not a hurtbox (3.3 D-S33-4/5).

### Group D: Echo memory and Echo Dash interaction (AC: 2, 8b)
- [x] D1. No change to `EchoMemory`: combos never store (4.1 D-S41-1), `echoable = false` on the Echo Dash def is belt and braces.
- [x] D2. Confirm `ActionResolver._link` takes the combo branch before `echo_blocked`: a combo's action is never Echo, so `startable_def` is true for it. Test: D->L with K and empty memory still fires Echo Dash.

### Group E: Tests (AC: 1-9, 12)
- [x] E1. New `tests/unit/test_echo_dash.gd`: data and validation (AC 1, 9), the combo lookup `get_combo(DASH, LOOP)` returns Echo Dash, the table still validates.
- [x] E2. Trigger: K during first dash ACTIVE and within the 18-frame window fires Echo Dash; LOOP cooldown 90 starts; DASH cooldown is the first dash's (24); `EchoMemory` unchanged; works with empty memory (AC 2).
- [x] E3. Invulnerability: presses at dash frames 1, 5, 9: `invulnerable()` is true on every executed frame from the first dash's frame 1 through Echo Dash's frame 10. Superseded: a press after frame 9 is refused (AC 3, D-S42-4).
- [x] E4. Redirect: first dash facing left, `move_dir` right at the press: Echo Dash moves right 4 tiles (within the per-frame sanitize); `move_dir` zero: facing kept; diagonal input sanitizes like `Player.sanitize_dir` (AC 4).
- [x] E5. `CombatResolver` with a test boss (weak window D->L): Echo Dash overlap produces one PASS_THROUGH, Patched 180 on match, `patched_applied` emitted once; the same overlap on window L->A does not complete it; a second overlap in the same action does nothing (`was_hit_by`); a closed `;` (Infinite Loop body) produces nothing (AC 5, 7).
- [x] E6. No damage: a practice target on Echo Dash's capsule is not hit (no `register_hit`, no `hit_landed`), the boss takes no damage and no hit-stop is requested (AC 6).
- [x] E7. Deferred 4.1 e2e (AC 8a): injected empty `ComboTable`, window `[A, L]`, J = slash_1, K = L, test boss on the capsule: K becomes Echo `link_second`; `CombatResolver` produces HIT with `is_link_second = true`; the window `[A, L]` is the boss's weak window: Patched applies (AC 8a). Same pair with the window not matching: no completion.
- [x] E8. Deferred 4.1 (AC 8b): an echoed def with `cancel_into` cancels into another bit (e.g. Echo of a DASH with `cancel_into = [A]`); an Echo run opens the link on (L, y) like any J solo (`link.open` with `pair = (L, y)` once the echoed frame 1 of ACTIVE is reached).
- [x] E9. Rewrite 4.1's `test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown` (in `tests/unit/test_echo_action.gd`) to Echo Dash, keeping its intent (second dash, DASH cooldown untouched); change `test_unknown_pairs_are_null` in `tests/unit/test_combo_table.gd` to drop `(D, L)`. Record both rewrites in Completion Notes with the reason (AC 8c).
- [x] E10. Combo validation: a malformed ComboDef (second without solo, combo action with cooldown, J startup 8) is reported (AC 9).
- [x] E11. Run the full GUT suite headless (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`) and `bash game/tools/check_guards.sh`. Replays: check `tests/replays/test_replays.gd` and `tests/integration/test_infinite_loop_replay.gd` for K presses on `[D, L]` (AC 10). Record the test count.

## Dev Notes

### Design calls for this story (D-S42-n)

- **[design call] D-S42-1 Echo Dash is a combo data def.** `data/actions/echo_dash.tres` is the action of `data/combos/echo_dash.tres` (D->L), the same pattern as Dash Strike (2.6). It replaces Echo (K's solo action on LOOP). No new code path: `ActionResolver` already returns the combo's action (rule 2), and the FSM already replaces the running action with it and closes the link. Source: GDD combo table (`D→L` Echo Dash, 0/10/6, 4-tile redirectable dash, continuous invulnerability), epics 4.2 AC.
- **[design call] D-S42-2 PASS_THROUGH is an ActionDef flag, not a new action class.** `ActionDef.pass_through` tells `CombatResolver` to produce `BossInteraction.Kind.PASS_THROUGH` on a boss overlap, and to skip damage, `hit_landed`, hit-stop and practice targets. The boss is still marked by the action's serial, so one Echo Dash passes once. Alternative (a separate `EchoDashDef` class) rejected: the rest of the action is exactly an ActionDef, and data-driven flags keep one code path (AD-02).
- **[design call] D-S42-3 Redirect is an ActionDef flag, direction from input at the press.** `redirectable = true` on Echo Dash: the FSM sets its facing from `Player.sanitize_dir(ctx.move_dir)` at start (8 directions, same rule as movement), falling back to the first dash's facing when there is no input. `Player.facing` is not changed by the FSM. `move_dir` is in the sim context, so replay determinism holds (no new input source).
- **[design call] D-S42-4 Invulnerability continuity: exact rule.** The combo replaces the running dash on the press tick, so Echo Dash's frame 1 runs on that tick. Dash frame 8 (its last invulnerable frame) is executed before the press when the press is on dash frame 9 or earlier, so no vulnerable executed frame falls between the first dash's frame 1 and Echo Dash's frame 10. A press on dash frame 10 or later leaves dash frame 9 (and any later frames before the press) vulnerable: that is a pre-existing gap of the first dash, not something Echo Dash can cover retroactively. The epic's window `[D, L]` (ACTIVE + 18 frames) is kept as written. **Flagged for the user at playtest:** if "no gap" must hold for every accepted press, shorten the window for D->L to dash frames 1-9 (a one-number data change in the combo's link window, not in this story's code). The tests pin the current behaviour either way.
- **[design call] D-S42-5 Echo Dash costs LOOP's 90 frames and needs no memory.** The combo branch of `_start` already starts the replaced solo's cooldown (ECHO = 90), `link.close()` and `_clear_chain()`, and returns before `echo.remember` (combos never store, 4.1 D-S41-1). The combo action's own `cooldown_frames` is 0 (checked by AC 9). Echo Dash does not depend on `echo_ready`: the gate is for `echo_action` defs only.
- **[design call] D-S42-6 Capsule size.** `HitCapsule` length 4.0 tiles (the dash distance), radius 0.5 tile, anchored at the press position and facing the redirect direction, so it covers the whole path of the dash. Hit radius for a capsule is the same tile-to-px conversion as Dash Strike (5.0 length, 0.75 radius). Balance tune at the 3.9 playtest if the capsule catches too little of a boss.
- **[design call] D-S42-7 The link_second e2e test uses a no-combo window of a test table.** The shipped table now has a combo on `[D, L]`, so the 4.1 deferred "Echo as link_second on a boss" test needs a window with no combo. The test injects an empty `ComboTable` and uses `[A, L]` (J = slash, K = L). The test documents the rule (a link_second HIT completes a window only on the matching pair, NP-4) without changing what the shipped table does.
- **[design call] D-S42-8 ComboDef.validate additions.** The three checks from the 2.6 deferred note are added here (second has a solo def, combo action cooldown 0, J startup + 1 <= 8). The "Dereference" name-length check stays with Story 6.2 as the deferred item says.
- **[design call] D-S42-9 No Null Pointer reveal here.** The GDD's "Echo Dash reveals the ghost for 60 frames" (FR37) belongs to the Null Pointer body (Story 5.1) and needs the boss visible state, which does not exist yet. Echo Dash only applies Patched through the PASS_THROUGH path.
- **[design call] D-S42-10 Closed `;` and non-hittable bosses.** A PASS_THROUGH does not happen while the boss is not hittable or while the Infinite Loop `;` is closed, because `boss_overlapped` already requires `is_hittable()` and `overlaps_shape` (3.3 D-S33-4/5). No new rule.

### Architecture and rules that bind this story

- AD-02 / NP-1: the resolver is the only J/K -> action path. The D->L combo is a `ComboTable` entry, not a new branch.
- NP-4 / D-S32-6 / D-S32-19: `BossInteraction` stub `PASS_THROUGH` becomes real here. `completes_weak_window` is the single rule (unchanged). `WeakWindowTracker` is the only Patched writer. `DamageCalc.compute()` remains the only damage producer; Echo Dash passes no damage (base 0), so it never calls it for the boss.
- NP-5 / D-S41-1: combos never enter Echo memory.
- AD-01: all durations are int frames; no `delta`.
- Single writers: J/K -> `ActionResolver`; Patched -> `WeakWindowTracker`; damage -> `DamageCalc`; register -> `Register`.
- Defs are read-only at runtime: `echo_dash.tres` is never mutated; the FSM holds a reference.
- Simulation code runs without a scene tree (tests build an FSM with `InputBuffer`, `Register`, `Player`, an injected `ComboTable`, and a test boss).

### Existing code this story touches (read before editing)

- `game/src/player/action_state_machine.gd`: `tick(ctx)` (add `ctx.move_dir` to `_start`), `_start` (redirect facing for `redirectable`; combo branch already correct), `_finish`, `_apply_movement` / `dash_velocity(action, facing)` (uses the redirected facing).
- `game/src/player/action_def.gd`: new `redirectable`, `pass_through` fields and their validation (Group A).
- `game/src/player/action_resolver.gd`: `_link` combo branch (rule 2) already returns combo actions; `startable_def` gates only `echo_action` defs.
- `game/src/player/player.gd`: `sanitize_dir(dir)` static (reuse for the redirect); `facing` is updated in `tick` from `ctx.move_dir`.
- `game/src/combat/combat_resolver.gd`: `tick` (skip `hits_for` for `pass_through`, route to `_resolve_pass_through`), `_resolve_boss_hit` (HIT path, unchanged; the PASS_THROUGH path mirrors it without damage).
- `game/src/combat/boss_interaction.gd`: header comment only (PASS_THROUGH now has a producer).
- `game/src/combat/weak_window_tracker.gd`: `process` used as is.
- `game/src/register/combo_def.gd`: `validate()` additions (AC 9).
- `game/src/core/defs.gd`: `COMBOS` already loads `combo_table.tres`; `solo_action` used by the validation.
- `game/data/combos/combo_table.tres`: add the Echo Dash combo.
- Tests that change: `game/tests/unit/test_combo_table.gd` (`test_unknown_pairs_are_null` list: drop `(D, L)`), `game/tests/unit/test_echo_action.gd` (`test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown`: now Echo Dash). Check `tests/unit/test_register_panel.gd` (line ~199-215, uses Echo Dash as a display name only; should still pass).
- Replays: `game/tests/replays/test_replays.gd`, `game/tests/integration/test_infinite_loop_replay.gd` (AC 10).

### Previous story intelligence (4.1, done; Echo on LOOP)

- Echo is LOOP's solo (`Defs.solo_action(LOOP) == Defs.ECHO`); memory is `EchoMemory` on the FSM; `echo_scale()` depends on the Echo def that started the running echo (D-S41-13). Echo Dash is a combo, so `echo_scale` stays 1.0 for it (base damage 0 anyway).
- 4.1 D-S41-11: "until 4.2 adds the D->L combo, D->L with K runs Echo as link_second". This story replaces that: D->L with K now fires Echo Dash. The link_second behaviour survives for no-combo windows (AC 8a).
- 4.1 review deferred items folded here: Echo as link_second e2e weak-window test; echoed `cancel_into` and the link opened by an Echo run; both in Group E.
- 4.1 review deferred item left in 4.1 (not 4.2): the echoed hit re-applies the original def's Patched/boss interactions at 70% damage (no test pins this); it is not in this story's scope.

### Previous story intelligence (3.2 / 3.3 / 3.5, boss side)

- 3.2: `BossInteraction` (kinds HIT / PASS_THROUGH / DECOY_STRUCK), `completes_weak_window` (D-S32-6), `WeakWindowTracker.process` (D-S32-12), `PATCHED_FRAMES = 180`. PASS_THROUGH and DECOY_STRUCK exist only as stubs in tests (D-S32-19): this story gives PASS_THROUGH its producer.
- 3.3: the Infinite Loop's `;` is the only hurtbox (D-S33-4), off-`;` hits are no-ops (D-S33-5); `hit_position` is the `;` junction. Echo Dash through a closed `;` is a no-op, and through an open `;` it is a PASS_THROUGH on the current weak window (phase 3: `current_weak_window()` returns the window of the ring whose `;` is open or next, per 3.5 D-S35-19 / NP-4).
- 3.5: phase-3 weak window is A->D for the outer `;` and D->A for the inner; D->L is therefore a Boss 2 / Null Pointer window, not an Infinite Loop one, so the Infinite Loop never completes a D->L window by Echo Dash. The test boss in tests covers the rule.

### Git intelligence

- Branch `story/4-2-echo-dash-combo` stacked on Story 4.1 (`43b93a4`, the 4.1 review commit). The last merged work is `861597f` (Docs: itch.io deploy and Chrome smoke, #31). Codebase pattern for stories: resolver/FSM pure, tests, small wiring.

### Latest technical information

- Pinned: Godot 4.7.2-stable (do not upgrade), GUT 9.6.1, GDScript only. Godot 4 syntax only (`@export`, typed arrays, `signal` in `EventBus` only). No new APIs needed: `Vector2`, `Geometry2D.get_closest_point_to_segment` (already used by `HitCapsule`), `RefCounted` plus static pure functions.

### Project Context Rules (from project-context.md)

- Echo Dash: continuous invulnerability from the first dash through its frame 10; LOOP cooldown applies; the redirected dash moves in the input direction (project context: "Echo Dash / combo" rules and GDD combos).
- Only `SimClock` ticks; no `_process`/`delta`/`Timer`/`await` in simulation code.
- Static typing everywhere; `StringName` ids (`&"echo_dash"`); `*_frames` and `*_tiles` names; `*_def.gd` for defs; files snake_case.
- Logging: `Log.debug(&"action", ...)` on start events only; no `print`.
- Simulation folders do not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.
- Tests: `tests/unit/test_<subject>.gd` for pure logic; build systems from defs plus an injected `ComboTable`; no scene tree needed.

### Project Structure Notes

- New: `game/data/actions/echo_dash.tres`, `game/data/combos/echo_dash.tres`, `game/tests/unit/test_echo_dash.gd` (plus `.uid` files created by Godot on first open).
- Modified: `game/src/player/{action_def,action_state_machine}.gd`, `game/src/combat/{combat_resolver,boss_interaction}.gd` (comment), `game/src/register/combo_def.gd`, `game/data/combos/combo_table.tres`, `game/tests/unit/{test_combo_table,test_echo_action}.gd`, plus replay expectations only if AC 10 requires them.
- No conflict with the architecture tree: Echo Dash lives in `data/actions` and `data/combos` as the architecture's `echo_dash` entry lists.

### Testing standards

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: Echo Dash 0 damage; Echo Dash 4 tiles; dash invulnerability 1-8, Echo Dash 1-10; LOOP cooldown 90.
- Guards in CI: `bash game/tools/check_guards.sh` (no `Timer.new`/`await` under sim folders, no bare `print(` in `src/`).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2: Echo Dash Combo] (ACs, FR17, FR21 pass-through)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1: LOOP Bit - Echo] and [implementation-artifacts/4-1-loop-bit-echo.md] (D-S41-11, D-S41-13, review deferred items)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] combos table (D→L Echo Dash row), Weak Window and Patched (D-017)
- [Source: _bmad-output/game-architecture.md#AD-02 Actions & Combos], [#NP-1 Register Window -> Action Resolution], [#NP-4 Weak Window -> Patched], [#NP-5 Echo Memory]
- [Source: _bmad-output/implementation-artifacts/3-2-weak-window-patched-and-damage-states.md] D-S32-6, D-S32-12, D-S32-19
- [Source: _bmad-output/implementation-artifacts/3-3-infinite-loop-body-and-loop-condition.md] D-S33-4, D-S33-5
- [Source: _bmad-output/implementation-artifacts/2-6-ordered-combo-engine-and-dash-strike.md] D-S26-3, D-S26-13 (combo cooldown, link)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] Story 4.1 review items (lines ~298-299), 2.6 `ComboDef.validate` note (line ~173), 3.2 PASS_THROUGH note

## Dev Agent Record

### Agent Model Used

claude opus (gds-dev-story, unattended pipeline)

### Debug Log References

- First GUT run after the ComboDef change: parse error "Cannot assign a value of type Resource to constant COMBOS". Cause: `combo_def.gd` referencing `Defs` at parse time while `Defs` preloads `combo_table.tres` (which uses `combo_def.gd`) = preload cycle. Fixed with a call-time lookup (`ComboDef._solo_action`, `load(DEFS_PATH)`), see D-S42-12.
- Second run hung in 4.1's `test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown` (its `while _fsm.action_frame < 8` loop never ended once K on [D, L] after the dash was refused). That is the test AC 8c rewrites; rewritten, no hang.
- Discovery: the story's D-S42-4 / B4 assumed "the combo replaces the running dash on the press tick". It did not: a K on an open link was HELD while the dash ran (DASH's `cancel_into` is [D], not [L]), so Echo Dash would only have started after the dash's last frame (frames 9-16 vulnerable). Fixed by the gap_free rule (D-S42-11).

### Completion Notes List

- **D-S42-4 resolved (coordinator).** "No invulnerability gap" holds for EVERY accepted press. Chosen option: shrink the acceptance window (extending Echo Dash's invulnerability cannot cover frames that already executed). Rule: a K press on the [D, L] link is accepted only on a tick where the running action's last executed frame is invulnerable (`ActionResolver.gap_free_ok`: dash frames 1-8), and Echo Dash replaces the dash on that same tick (its frame 1 runs there, invulnerable 1-10). So Echo Dash may replace dash frames 2-9; the last accepted press resolves after dash frame 8. A press after dash frame 9, in recovery, or after the dash while the link still counts is refused. This supersedes AC 2's "or within 18 frames after" and AC 3's "press on frame 10 or later is still accepted" for this combo. Boundary tests: presses after dash frames 1, 5, 8 (continuous, every executed frame invulnerable from dash frame 1 to Echo Dash frame 10, Echo Dash frame 11 vulnerable), refused after frame 9, in recovery (12) and after the dash (20); `gap_free_ok` pinned for frames 0-16.
- **[design call] D-S42-11 `ComboDef.gap_free`.** The rule is data, not an Echo Dash special case: `ComboDef.gap_free: bool` (true only on `data/combos/echo_dash.tres`). `ActionResolver._link` routes a gap_free combo to `_gap_free_link`: it starts mid-ACTIVE (no hold), and a refused press is consumed and dropped (`LinkOp.DROP` with the press frame; FSM logs "link drops K (gap)"), with no link_second and no later solo Echo fallback (otherwise a refused press could fire Echo after the link closes). A cooling-down LOOP leaves the press buffered as before. `ComboDef.validate` requires a gap_free combo's action to be invulnerable from frame 1. Dash Strike is unchanged (still held until the slash's recovery).
- **[design call] D-S42-12 Call-time Defs lookup in ComboDef.validate.** The AC 9 checks need `Defs.solo_action`, but a parse-time `Defs` reference in `combo_def.gd` is a preload cycle (Defs -> combo_table.tres -> combo_def.gd -> Defs). `ComboDef._solo_action` loads `res://src/core/defs.gd` at call time (validation only, never per tick).
- **[design call] D-S42-13 FSM DROP log text.** "link drops K (cooldown)" became "link drops K (lifetime)" for a held press and "link drops K (gap)" for a gap_free refusal; no test read the old text.
- Group A: `ActionDef.redirectable` / `pass_through` + validation; `echo_dash.tres` (AC 1 values, capsule 4.0 x 0.5); `data/combos/echo_dash.tres` in `combo_table.tres`; `Defs.ECHO_DASH`; `ComboDef.validate` gains the three D-S42-8 checks (second has a solo def, action cooldown 0, first solo startup + 1 <= `InputBuffer.PRESS_LIFETIME_FRAMES`) plus the gap_free check.
- Group B: `tick` passes `ctx.move_dir` to `_start` (new trailing param, default ZERO); a redirectable action's `facing` is `Player.sanitize_dir(move_dir)` when non-zero, else the captured facing; `Player.facing` untouched. Combo branch unchanged (LOOP 90, link closed, no Echo memory write). Invulnerability: no new mechanism, continuity comes from the replacement on the press tick plus the gap_free acceptance rule.
- Group C: `CombatResolver.tick` routes `pass_through` defs to `_resolve_pass_through` (one PASS_THROUGH on `action_window`, `WeakWindowTracker.process`, Patched 180 + `patched_applied` on match, `mark_hit(serial)`); no practice targets, no damage, no `hit_landed`, no hit-stop. `BossInteraction` header comment updated; completion rule unchanged.
- Group D: no EchoMemory change; Echo Dash fires with `echo_ready = false` (resolver test).
- **Test rewrites (recorded reasons, AC 8c / AC 10):**
  - `tests/unit/test_echo_action.gd::test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown`: the shipped table now holds D->L, so K on [D, L] is Echo Dash, not Echo link_second (D-S41-11 superseded). Rewritten to Echo Dash pressed mid-dash, keeping the intent (second 4-tile dash, DASH cooldown neither checked nor restarted, LOOP 90, invulnerable frames 1-10).
  - `tests/unit/test_combo_table.gd::test_unknown_pairs_are_null`: (D, L) removed from the null list (it is Echo Dash).
  - `tests/unit/test_harvest_screen.gd::test_texts`: `window_text(D, L)` is now "D>L  Echo Dash" (data-driven from the shipped table); added an `L>A  --` assertion to keep the no-combo case covered.
  - `tests/unit/test_register_panel.gd::test_previews_show_names_only_where_a_combo_exists`: the << preview of [A, D, L] is [D, L], which now shows "Echo Dash" (the old comment said "not shipped in 2.6").
- Replays (AC 10): `tests/replays/test_replays.gd` and `tests/integration/test_infinite_loop_replay.gd` compare live vs replayed state (no stored hashes) and pass unchanged; no expectation updated.
- Scope fence respected: no Breakpoint, flag, Ghost Echo, Null Pointer reveal, SFX/VFX/HUD; `DECOY_STRUCK` stays a stub.
- Tests: new `tests/unit/test_echo_dash.gd` (31 tests: data/validation, trigger and cost, empty memory, cooldown buffering, invulnerability boundaries, refusals, redirect, PASS_THROUGH match / wrong window / non-hittable / practice target / Patched x1.5 follow-up, Infinite Loop closed and open `;`, 4.1 deferred link_second e2e with injected empty table on [A, L], echoed cancel_into and Echo-opened link). Full GUT headless: **1007/1007 passing** (976 before, 73 -> 74 scripts). `bash game/tools/check_guards.sh`: OK.

### File List

- game/data/actions/echo_dash.tres (new)
- game/data/combos/echo_dash.tres (new)
- game/data/combos/combo_table.tres
- game/src/core/defs.gd
- game/src/player/action_def.gd
- game/src/player/action_resolver.gd
- game/src/player/action_state_machine.gd
- game/src/register/combo_def.gd
- game/src/combat/combat_resolver.gd
- game/src/combat/boss_interaction.gd
- game/tests/unit/test_echo_dash.gd (new)
- game/tests/unit/test_echo_dash.gd.uid (new, Godot-generated)
- game/tests/unit/test_echo_action.gd
- game/tests/unit/test_combo_table.gd
- game/tests/unit/test_harvest_screen.gd
- game/tests/unit/test_register_panel.gd
- _bmad-output/implementation-artifacts/4-2-echo-dash-combo.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-10: Story 4.2 created unattended by gds-create-story (pipeline). Status -> ready-for-dev. Design calls D-S42-1 to D-S42-10.
- 2026-11-10: Code review (gds-code-review, 3 parallel layers): 3 patches, 7 deferred, rest dismissed. Status -> done.
- 2026-11-10: Implemented by gds-dev-story (claude opus). Echo Dash combo, PASS_THROUGH producer, gap_free acceptance (D-S42-4 resolved by coordinator), D-S42-11 to D-S42-13. GUT 1007/1007, guards OK. Status -> review.

## Story Completion Status

Status: done. Implementation complete and reviewed; see Dev Agent Record and Review Notes.

## Review Notes (2026-11-10)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). No AC violation; gap_free path, dropped presses, LOOP cooldown buffering, Dash Strike and other combos, PASS_THROUGH once-per-action and replay determinism verified. The 4 rewritten tests changed for real reasons (D>L is now a combo).

- Patched: stale AC 2/3/B4/E3 text aligned with D-S42-4; `ActionDef.validate` rejects pass_through/redirectable with `active_frames < 1` (+ test); vacuous non-redirectable test now uses a non-zero move_dir.
- Deferred (see deferred-work.md): pass-through spent on first overlap; capsule not clamped to the real path; `Player.facing` not set by redirect; refused K press gives no feedback; `ComboDef._solo_action` runtime load (check web export); Echo Dash start log not asserted; shared `Defs.SLASH_1` mutated in a test.
- Dismissed: echo_blocked ordering (def is the combo action, never an Echo); mid-ACTIVE replacement skipping cancel_into (by design D-S42-4); `action_frame < total_frames` redundancy; unguarded debug log; hardcoded test literals.
