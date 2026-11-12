---
baseline_commit: 0782e08
---

# Story 5.5: NULL Bit - Null Dodge and Clean Catch

Status: done
<!-- Created unattended by gds-create-story (pipeline, 2026-11-11). Self-made design calls are marked [design call] with IDs D-S55-n; the implementer follows them or records a change in Completion Notes. Scope: the NULL bit data (bit_null.tres, null_dodge.tres), the Null Dodge action (30 intangible frames at x0.5 move, 120-frame cooldown, cancel rules), the Clean Catch arming and consumption through DamageCalc, and the tests. NOT in scope: Ghost Echo and Dereference (Epic 6, they need the N-owned register and the decoy), the NULL drop and Harvest insert (5.6, `drop_bit = 4` already in boss_def.tres), the N tutorial line (5.6), any HUD for Clean Catch (log line only, D-S55-12), the Segfault boss. -->

## Story

As a player,
I want a long intangible dodge that rewards perfect reads,
so that I can pass through attacks and strike harder.

**Requirements:** FR13, FR14, FR22 (Clean Catch). GDD "Bits" table (NULL: Null Dodge 0/30/8, CD 120, slower movement; Clean Catch ×1.5 on top of the damage state), GDD "Damage states" (Clean Catch ×0.75 unpatched, ×2.25 patched), GDD "The Register" (every action cancels into DASH or Null Dodge during recovery). Architecture: `ActionDef` (`cancel_into`, `invuln_from/to`), `CombatResolver`, `DamageCalc` (Clean Catch factor already wired as a parameter, unused by callers).

## Acceptance Criteria

**Null Dodge bit and action**

1. **Given** `bit_null.tres` (`id = Register.Bit.NULL_BIT`, glyph `N`, solo action `null_dodge.tres`) and `null_dodge.tres` (startup 0, active 30, recovery 8, invulnerable frames 1-30, no hit shape, base damage 0, cooldown 120 frames)
   **When** I press the slot holding `N` (J or K) while N is in the active window and its cooldown is ready
   **Then** Null Dodge starts with the held facing, the N cooldown starts (120 frames), and `Defs.bit(Register.Bit.NULL_BIT)` returns the new def (no longer null)

2. **Given** Null Dodge's 30 active frames
   **When** I am moving during them
   **Then** my top speed is ×0.5 (same ramp shape as Watch, D-S55-3), the speed returns to normal on the first frame after the dodge, and the dodge itself moves me 0 tiles (no dash distance)

3. **Given** I am in Null Dodge's active frames
   **When** a boss hit reaches me
   **Then** no HP is lost and no post-hit invulnerability is started (existing `PlayerHealth` invulnerability path, unchanged)

4. **Given** the recovery of any player action that currently lists DASH in `cancel_into` (slash 1-3, Dash; Dash Strike has an empty `cancel_into` today, corrected at dev time)
   **When** the recovery is running and I press the slot holding `N` (and N is in the active window and its cooldown is ready)
   **Then** the action is cancelled into Null Dodge, the same way DASH cancels work

**Clean Catch**

5. **Given** a boss attack's hitbox passes through me during Null Dodge's invulnerable frames (a body or attack contact is queued and rejected by the invulnerability)
   **When** the contact happens
   **Then** Clean Catch is armed (once, idempotent), the hit is still ignored, and a debug log line records it

6. **Given** Clean Catch is armed
   **When** my next damaging action lands on the boss (solo, chain, or combo hit) and deals damage > 0
   **Then** DamageCalc applies ×1.5 on top of the damage state (×2.25 Patched, ×0.75 unpatched, ×1.5 base on a practice target), and Clean Catch is consumed

7. **Given** Clean Catch is armed
   **When** my damaging action does not land (whiff, a decoy dispel, a pass-through such as Echo Dash, or a boss hit that deals 0)
   **Then** Clean Catch stays armed for the next damaging hit

8. **Given** Echo replays Null Dodge (`EchoMemory.last` = `null_dodge`)
   **When** the echoed dodge passes a boss attack through me
   **Then** Clean Catch arms exactly as for a live Null Dodge (no separate code path)

9. **Given** a fight entry, a retry, or a debug jump
   **When** the fight resets
   **Then** Clean Catch is disarmed

**Unit tests**

10. **Given** the unit tests
    **When** they run
    **Then** Clean Catch slash 10 deals 23 Patched (22.5 rounds half up, D-S55-6) and 8 unpatched (7.5 rounds to 8), and Echo of Null Dodge can arm and then trigger Clean Catch (AC 8)

11. **Given** the flag-off and the default register (no N owned)
    **When** the existing replay and integration tests run
    **Then** they pass unchanged (no recorded input can reach N unless N is in the ring)

## Tasks / Subtasks

### Group A: Data (AC: 1, 2, 4)

- [x] Create `game/data/bits/bit_null.tres` (BitDef, `id = 4`, `glyph = "N"`, `solo_action = null_dodge.tres`). Model it on `bit_loop.tres`.
- [x] Create `game/data/actions/null_dodge.tres` (ActionDef): `startup_frames = 0`, `active_frames = 30`, `recovery_frames = 8`, `invuln_from = 1`, `invuln_to = 30`, `base_damage = 0`, `cooldown_frames = 120`, `move_tiles = 0.0`, `cancel_into = PackedInt32Array(2)` (DASH = 2, D-S55-8), `arms_clean_catch = true`, `slows_move = true`, no hit shape.
- [x] `game/src/player/action_def.gd`: add two exports with doc comments in the Story X.Y style: `slows_move: bool = false` (D-S55-3) and `arms_clean_catch: bool = false` (D-S55-4). In `validate()`: `arms_clean_catch` needs a non-zero invulnerable range (otherwise it can never arm); `slows_move` needs `active_frames >= 1`.
- [x] `game/src/core/defs.gd`: `const BIT_NULL: BitDef = preload("res://data/bits/bit_null.tres")` and a `Register.Bit.NULL_BIT` case in `bit()`. Add `const NULL_DODGE: ActionDef = preload(...)` next to the other action consts. Update the comment that says NULL_BIT is null "until Epic 5".
- [x] Add `Register.Bit.NULL_BIT` (4) to `cancel_into` of `slash_1.tres`, `slash_2.tres`, `slash_3.tres`, `dash.tres` (keeps DASH = 2, so `PackedInt32Array(2, 4)`) (D-S55-7). `dash_strike.tres` has an explicit empty `cancel_into` today (it does not cancel into DASH), so it stays as it is under the D-S55-7 rule (corrected at dev time, see Completion Notes). `echo_dash.tres`, `echo.tres` and `nop.tres` stay as they are (D-S55-7).
- [x] Update `game/tests/unit/test_data_validation.gd` coverage so the new defs and the new fields validate.

### Group B: Dodge movement and state (AC: 2, 4)

- [x] `game/src/core/sim_context.gd`: add `var move_slowed: bool = false` next to `watch_held`, with a comment (Story 5.5, D-S55-3).
- [x] `game/src/player/action_state_machine.gd`: at the end of `tick()` (after the frame step, before `_apply_movement`), set `ctx.move_slowed = action != null and action.slows_move and action_frame >= 1 and action_frame <= action.active_frames`. Set `ctx.move_slowed = false` on the stun and Watch early returns. Do not touch the echo path: an Echo of Null Dodge slows through the same `action` field.
- [x] `game/src/player/player.gd`: in `tick()`, scale `v_max` by `WATCH_SPEED_FACTOR` (0.5) when `ctx.watch_held or ctx.move_slowed`. One factor, not two: the two do not stack (D-S55-3).
- [x] Verify (no code change expected) that `ActionStateMachine.tick` cancel path reaches Null Dodge from recovery: `ActionResolver._cancel` already checks `cancel_into` and `cooldowns.ready(bit)`.

### Group C: Clean Catch (AC: 5, 6, 7, 8, 9)

- [x] `game/src/player/action_state_machine.gd`: add `var clean_catch_armed: bool = false`, `func arm_clean_catch() -> void` (idempotent, logs once at `Log.debug(&"action", ...)`), and `func consume_clean_catch() -> bool` (returns the old value and clears it). Clear it in `reset_for_fight()` (AC 9). Writers: these methods only.
- [x] `game/src/player/player_health.gd`: in `apply_hit()`, when the hit is rejected only because `_actions.invulnerable()` is true and `_actions.action.arms_clean_catch` (read the running def, which covers Echo because `action` is the echoed def), call `_actions.arm_clean_catch()`. Keep the existing return value (`false`). Dash invulnerability does not arm (only the data flag arms).
- [x] `game/src/combat/combat_resolver.gd`: pass `actions.clean_catch_armed` to `DamageCalc.compute` as the `clean_catch` argument in `_resolve_boss_hit` (the boss damage line) and in the practice target loop in `tick()`. Consume only when the computed damage is > 0, after the damage is computed: `if damage > 0 and clean: actions.consume_clean_catch()`. The consume happens on the hit path only (not on whiff, decoy dispel, or pass-through), which implements AC 7.
- [x] Update the header comment of `combat_resolver.gd` with a `Story 5.5 (D-S55-5, D-S55-6)` paragraph.

### Group D: Tests (AC: 1-11)

- [x] `game/tests/unit/test_null_dodge.gd` (new, plus `.uid`): action frames (active 30, invulnerable 1-30, recovery 8, total 38), cooldown 120 on bit N, `Defs.bit(4)` non-null with glyph `N`, `Defs.solo_action(4)` is `null_dodge`, `ActionResolver` starts it from N in slot J/K with an injected ring that owns N.
- [x] Cancel test: a slash in recovery with N in the window and cooldown ready cancels into Null Dodge (AC 4). Same action with N on cooldown does not cancel.
- [x] Slow test: `ctx.move_slowed` true exactly on the 30 active frames; Player top speed ×0.5 with and without Watch (no stacking, D-S55-3).
- [x] `game/tests/unit/test_clean_catch.gd` (new, plus `.uid`): arm during dodge via `PlayerHealth.queue_hit` + tick (no HP loss, AC 3, 5); arming is idempotent; a hit on a boss consumes it; a whiff, a decoy dispel and a pass-through do not consume it (AC 7); a 0-damage hit does not consume it; reset clears it (AC 9); Echo of Null Dodge arms it (AC 8).
- [x] `game/tests/unit/test_damage_calc.gd`: add the Clean Catch rows (AC 10): `compute(10, 1.5, true, 1.0) == 23`, `compute(10, 0.5, true, 1.0) == 8`, `compute(10, 1.0, true, 1.0) == 15` (already present), practice target `compute(10, 1.0, true, 1.0) == 15`.
- [x] Integration: one fight-level test (`game/tests/integration/`) with a Null Pointer fight (AC 6 on the boss): dodge through a boss contact, then slash, expect the x2.25 Patched or x0.75 unpatched value through `hit_landed`. Reuse the existing Null Pointer fight harness (`test_null_pointer_fight.gd`).
- [x] Run the full GUT suite and `game/tools/check_guards.sh`. Both must be green before the story leaves `ready-for-dev`.

### Review Findings

- [x] [Review][Patch] `ctx.move_slowed` survived a fight start / retry (same bug class as 5.4's `watch_held`) [game/src/autoloads/sim_clock.gd] — fixed in `begin_fight`, test `test_begin_fight_clears_move_slowed`
- [x] [Review][Defer] One tick with several damaging hits (boss plus practice targets) applies the single Clean Catch charge to all of them; boss fight has one damaging target [game/src/combat/combat_resolver.gd] — deferred, practice scenes only
- [x] [Review][Defer] Clean Catch has no expiry (it survives whiffs, stuns, phase changes until the next damaging hit or fight reset) — deferred, matches D-S55-5, revisit in playtest
- [x] [Review][Defer] A hit during the 60-frame post-hit blink does not arm Clean Catch even inside the dodge's frames (D-S55-14, confirmed design call) — deferred, tune in playtest
- [x] [Review][Defer] Echo of Null Dodge is not covered end to end against a live boss attack (unit-level only) — deferred to 5.6 / playtest
- [x] [Review][Defer] F8 on Fight 2 grant behaviour and the Dash-Null-Dash-Null chain cap have no dedicated tests — deferred
- Dismissed (12): out-param style, hardcoded ids in .tres, magic frame numbers in tests, test global-state restore style, hit-stop not boosted for Clean Catch (not in AC), rounding rows (exact binaries), and other style or speculative notes.

## Dev Notes

### Note for Story 5.6

- F8 already grants N on Fight 2 via the 3.8 route, and Fight 3's start register already has N. Story 5.6 must not double-grant or assume N is absent there.
- Confirmed design calls: D-S55-13 (free x0.5 walk during dodge ACTIVE frames, required for AC 2) and `dash_strike` keeps an empty `cancel_into` (AC 4 = slashes + Dash only).

### Design calls for this story (D-S55-n)

- **D-S55-1 (N bit is data-only in 5.5):** `bit_null.tres` is registered in `Defs`, but the register still starts as `[DASH, ATTACK]`. N becomes owned in Story 5.6 (Harvest). Tests inject a ring that owns N. No debug grant is added here (see Open questions).
- **D-S55-2 (Null Dodge frame data):** `0/30/8`, CD 120, from the epic and the GDD table. Intangibility is the existing invulnerable-frame path (`ActionDef.invuln_from/to` read by `PlayerHealth.apply_hit`), so no new hit-filter is needed.
- **D-S55-3 (slow movement):** a new data flag `ActionDef.slows_move`. The ASM publishes `SimContext.move_slowed` at the end of its tick; `Player` applies the same ×0.5 factor it uses for Watch. The two do not stack (Watch cannot start a dodge; both flags only take half speed). Movement is read through `ctx`, so `Player` never holds the ASM (no script cycle).
- **D-S55-4 (Clean Catch arming):** a data flag `ActionDef.arms_clean_catch`, set only on `null_dodge.tres`. Arming happens in `PlayerHealth.apply_hit` when a queued contact is rejected by that action's invulnerability. This is the only point where "an attack passed through me" is known. Arming is data-driven so Echo (which replays the same def) needs no extra code.
- **D-S55-5 (consumption and persistence):** Clean Catch is consumed only by a damaging hit on the boss or a practice target (`damage > 0`). It persists across actions until consumed and is cleared at fight reset. No timeout (the GDD gives none). It is stored on the ASM because `CombatResolver` already reads `actions.echo_scale()`.
- **D-S55-6 (Clean Catch values):** the formula is applied as written in FR22 and the GDD table: Patched + Clean Catch = ×2.25, so slash 10 = 23 (22.5 rounds half up). The epic's AC line "Clean Catch slash 10 deals 15 Patched" reads as the non-Clean-Catch Patched value and conflicts with ×2.25; the formula wins. Flagged in Open questions.
- **D-S55-7 (cancel rules):** NULL is added to the `cancel_into` of every action that already cancels into DASH (slashes, Dash, Dash Strike). Echo Dash, Echo and NOP keep their current lists (Echo Dash is a combo second action with no recovery cancel by design, D-S42-*).
- **D-S55-8 (Null Dodge recovery):** `cancel_into = [DASH]`. A dodge can be followed by a dash; it does not cancel into itself (cooldown would block it anyway).
- **D-S55-9 (cooldown):** `cooldown_frames = 120` on the solo def, which is what `ActionResolver` and `ActionStateMachine._start` read for bit N (same path as the other bits).
- **D-S55-10 (Dereference is not here):** the GDD's "Dereference must be pressed during Null Dodge's active frames" is Story 6.2 (Epic 6) and needs the N-owned combo table. Not added here.
- **D-S55-11 (no new feature flag):** the cut ladder (`FeatureFlags`) does not list NULL, so no flag is added.
- **D-S55-12 (feedback):** Clean Catch shows as a debug `Log.debug` line and the existing damage state already drives the feedback tier. No HUD, no SFX (the GDD gives Clean Catch no visual of its own beyond the damage-state feedback; out of scope for this story).

### Architecture and rules that bind this story

- Integer sim state, floats for presentation only. Factors are whole-percent through `DamageCalc.to_pct`; the half-speed factor scales the existing float px-per-frame velocity (same as Watch, D-S54-5).
- Single writer per state: `arm_clean_catch` / `consume_clean_catch` / `clean_catch_armed` are written only by `ActionStateMachine`. `DamageCalc` stays pure and takes the flag as an argument.
- `ActionDef` is read-only runtime data. New flags are data, not `if def.id == &"null_dodge"` checks.
- Attack scripts draw no RNG and read no player state (no change here).
- Presentation writes no sim state. No HUD code in this story.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

### Existing code this story touches (read before editing)

Read in full before editing (current state, what changes, what must stay):

- `game/src/player/action_def.gd` (103 lines): fields `invuln_from/to`, `cancel_into` (default `[DASH]`), `cooldown_frames`, `echo_action`, `echoable`, `redirectable`, `pass_through`; `validate()` checks each combination. Changes: two new flags and their checks. Preserve: all existing validation.
- `game/src/player/action_state_machine.gd` (383 lines): `tick()` order is cooldowns, stun, Watch (`_tick_watch`, which still advances action frames), then `ActionResolver.resolve`, then the frame step, `_update_link`, `_apply_movement`. `_start()` starts the cooldown for the bit (`request.def.cooldown_frames`, or the replaced solo's value for a combo). `invulnerable()` is `action.is_invulnerable_frame(action_frame)`. Changes: `ctx.move_slowed` publish, clean-catch state, reset. Preserve: the Echo path (`echoing`, `_echo_def`).
- `game/src/player/player.gd` (105 lines): `tick()` picks `v_max`, applies `WATCH_SPEED_FACTOR` when `ctx.watch_held`, uses accel/decel ramps. Change: the `or ctx.move_slowed` condition only.
- `game/src/player/player_health.gd` (94 lines): `apply_hit()` rejects on `dead`, `invuln_left > 0`, or `_actions.invulnerable()`. Change: arm Clean Catch on the last rejection. Preserve: HP, post-hit invulnerability, hit-stop.
- `game/src/combat/combat_resolver.gd` (176 lines): `tick()` (decoys, `hit` list for practice targets, `_resolve_boss_hit`, `_check_whiff`, `_resolve_pass_through`). `DamageCalc.compute` is called at the practice target loop and in `_resolve_boss_hit` with `clean_catch = false` today. Change: pass the flag and consume on damage > 0.
- `game/src/combat/damage_calc.gd` (no change): `compute(base, state_mult, clean_catch, echo_scale)` already applies `CLEAN_CATCH_PCT = 150`.
- `game/src/core/defs.gd` (`bit()`, `solo_action()`, consts): add BIT_NULL and NULL_DODGE; `bit()` returns null for NULL_BIT today.
- `game/src/core/sim_context.gd`: has `watch_held`; add `move_slowed` beside it.
- `game/src/register/register.gd`: `Bit.NULL_BIT = 4`, glyph `N`, `MAX_BITS = 4` (the nibble is already reserved). No change.
- `game/src/register/bit_def.gd`, `game/data/bits/bit_loop.tres` (pattern for `bit_null.tres`).
- `game/src/bosses/framework/boss_controller.gd` (`_check_contact`, line ~243-249): body contact queues one hit through `PlayerHealth.queue_hit()`. This is the "attack passes through me" event.
- `game/data/actions/slash_1.tres`, `slash_2.tres`, `slash_3.tres`, `dash.tres`, `dash_strike.tres` (default cancel `[DASH]`), `echo_dash.tres`, `echo.tres`, `nop.tres`.
- `game/data/bosses/null_pointer/boss_def.tres`: `drop_bit = 4` already set (Story 5.1). Do not change (Story 5.6 consumes it).

### Files to touch

- New: `game/data/bits/bit_null.tres`, `game/data/actions/null_dodge.tres`, `game/tests/unit/test_null_dodge.gd`, `game/tests/unit/test_clean_catch.gd` (each with `.uid` if the project keeps them).
- Edit: `game/src/player/action_def.gd`, `action_state_machine.gd`, `player.gd`, `player_health.gd`, `game/src/combat/combat_resolver.gd`, `game/src/core/defs.gd`, `game/src/core/sim_context.gd`, `game/data/actions/slash_1.tres`, `slash_2.tres`, `slash_3.tres`, `dash.tres`, `dash_strike.tres`, `game/tests/unit/test_damage_calc.gd`, `game/tests/unit/test_data_validation.gd`, one integration test under `game/tests/integration/`.
- Do not edit: `data/config/feature_flags.tres`, `boss_def.tres` files, `damage_calc.gd`, `register.gd`, any attack script under `src/bosses/`, `src/skills/`.

### Testing standards

GUT tests in `game/tests/unit/` and `game/tests/integration/`. Fixed seeds through `SimContext`. Ticks through `SimClock` or direct `tick(ctx)` calls, never wall time. Headless, no scene tree. Use the `_make_health` / `ForcedBody` / test FSM patterns already in `test_null_pointer_attacks.gd` and `test_echo_action.gd`. Replays (`tests/replays/`) must still pass: no recorded input reaches N because the default ring does not own N.

### Previous story intelligence

- Story 4.1 (done): Echo memory (`EchoMemory.last`, set for every solo bit action that is `echoable`). Null Dodge is solo and echoable, so its Echo works without changes. `echo_scale()` is 0.7 and has no effect on a 0-damage dodge.
- Story 4.2 (done): `pass_through` and `redirectable` flags; `echo_dash.tres` has `cancel_into = ()` and an invulnerable range. The pass-through path never damages, which is why AC 7 excludes it from consumption.
- Story 4.3 (done): FeatureFlags and the leaf-module pattern. Not needed here (no flag), but the rule "FeatureFlags must not reference Defs" still holds.
- Story 5.1 (done): Null Pointer body, `drop_bit = 4` (N), contact and hit hooks (`on_player_hit`, `on_pass_through`). The Null Pointer fight is the integration target for AC 6.
- Story 5.3 (done): NPE whiff stun. A whiff must not consume Clean Catch (AC 7): the whiff path returns before the damage path in `CombatResolver.tick()`.
- Story 5.4 (done): `ctx.watch_held` and the ×0.5 Player factor (`WATCH_SPEED_FACTOR`). Reuse the same factor constant. `_tick_watch` advances action frames, so a dodge that is running keeps its frames under Watch.

### Git intelligence

Recent commits: `b71bdfa` (web budget), `20ce60f` (Story 4.4 duck hint), `01bca91` (4.3 Breakpoint), `f4ef433` (4.2 Echo Dash), `06e91e1` (4.1 LOOP Echo). The leaf-module and data-first pattern is consistent across them: data file first, `Defs` constant, `ActionDef` flag, test per flag.

### Latest technical information

No new library or engine version: GDScript 2.0 on Godot 4.7, GUT for tests. No web research needed.

### Project Context Rules (from project-context.md)

- Read-only defs at runtime; mutable state in sim objects.
- Integer sim state; floats only for presentation or the px-per-frame velocity.
- Presentation may not write sim state; `arena/` may not reference `presentation/`.
- Feature flags are read once at wiring, never in the sim (not used here).

### Project Structure Notes

- Bit data lives in `game/data/bits/`, action data in `game/data/actions/`, both as `.tres`.
- New tests follow `game/tests/unit/test_<topic>.gd`.

### Testing standards summary

- Unit tests per rule; one integration test for the boss path; replays unchanged.
- Run the GUT suite and `game/tools/check_guards.sh` before moving the story to `review`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.5: NULL Bit - Null Dodge and Clean Catch]
- [Source: _bmad-output/planning-artifacts/epics.md#FR13, FR14, FR22]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Bits (NULL), #Damage states, #The Register (cancels)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-009, D-020, D-021, D-037]
- [Source: _bmad-output/game-architecture.md#ActionDef, #Damage & Patched]
- [Source: _bmad-output/implementation-artifacts/4-1-loop-bit-echo.md] (Echo memory)
- [Source: _bmad-output/implementation-artifacts/4-2-echo-dash-combo.md] (pass-through, cancel lists)
- [Source: _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md] (drop_bit = N, contact hooks)
- [Source: _bmad-output/implementation-artifacts/5-3-dangling-pointers-and-nullpointerexception.md] (whiff rule)
- [Source: _bmad-output/implementation-artifacts/5-4-watch-skill.md] (ctx.watch_held, WATCH_SPEED_FACTOR)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (dash.tres cancel_into note, line ~168)

## Design calls

- D-S55-1 through D-S55-12: see Dev Notes above (the IDs are the source of truth; each is repeated where it is used in Tasks and ACs).

## Open questions (not blocking)

- D-S55-6: the epic's AC "Clean Catch slash 10 deals 15 Patched" conflicts with ×2.25 (23). Shipped as ×2.25 (FR22, GDD). Confirm with Tiziano.
- D-S55-1: N is not owned until Story 5.6, so the bit cannot be tried in a live build before 5.6 unless a debug grant is added. Not added (no story asks for it). Confirm if an earlier playtest of Null Dodge is wanted.
- D-S55-5: Clean Catch never expires. If playtests show it carrying across a long fight unexpectedly, a frame timeout is a one-constant change.
- D-S55-7: Echo Dash and Echo keep their current cancel lists. Confirm that a dodge cannot be reached from Echo Dash's recovery (currently no cancel path).

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (story creation); claude-opus-5-5 (implementation, gds-dev-story, 2026-11-11)

### Debug Log References

- First integration run did not arm in 4000 ticks: the Null Pointer's first ACTIVE tick hit the idle player before the dodge started, and the 60-frame post-hit invulnerability then rejected every contact ahead of the dodge (see D-S55-14). The test undoes that first hit's HP and blink.
- Full suite after the change: 4 existing tests encoded "NULL has no BitDef until Epic 5" (2 in test_action_resolver, 1 in test_echo_dash, 1 in test_debug_keys); updated (see Completion Notes).

### Completion Notes List

**Spec inconsistencies fixed at dev time (story file edited in Tasks / AC 4):**
- Bit ids: `Register.Bit` is `ATTACK = 1, DASH = 2, LOOP = 3, NULL_BIT = 4`. The story wrote DASH as `1`. Shipped `null_dodge.tres` `cancel_into = (2)` and slashes / Dash `cancel_into = (2, 4)`.
- Dash Strike: `dash_strike.tres` has an explicit empty `cancel_into` (it never cancelled into DASH), not the `[DASH]` default the story assumed. Under the D-S55-7 rule ("add NULL where DASH already is") it stays empty; AC 4 now lists slash 1-3 and Dash only.
- Movement: `ActionStateMachine._apply_movement` locks the player on every ACTIVE frame (a 0-tile action locks at zero velocity), which would make AC 2 ("moving at x0.5") impossible. Added D-S55-13 below.
- D-S55-1 says N cannot be reached before 5.6. Not quite: `Register.fight_start_for_boss(2)` (Fight 3) already owns N, so the F5 debug jump plays N, and the existing Story 3.8 F8 grant now grants N on Fight 2 (it only needed a BitDef). No new debug key added; this is the debug path (coordinator decision 2).

**Design calls made during implementation:**
- [design call] D-S55-13: the ACTIVE frames of a `slows_move` action are unlocked (free movement), with `ctx.move_slowed` halving the top speed through Player's Watch factor. Recovery is unlocked as before, so speed ramps back on frame 31.
- [design call] D-S55-14: only a rejection by the dodge's own invulnerable frames arms Clean Catch; when post-hit invulnerability (`invuln_left`) is running, it rejects first and nothing arms (task wording "rejected only because `_actions.invulnerable()`").
- [design call] D-S55-15: `clean_catch_armed` is read once per CombatResolver tick and applies to every hit of that tick (boss and practice targets); it is consumed once after the tick when the summed damage is > 0.
- [design call] `ctx.move_slowed` is also published on Watch ticks (a running dodge keeps its frames under Watch); the speed factor is the same single x0.5 either way. Stun ticks publish false.
- [design call] `null_dodge.tres` `hitstop_frames = 0` (no hit shape, the field is unused).

**Coordinator decisions applied:** damage follows FR22/GDD (Clean Catch Patched slash 10 = 23, unpatched = 8); N via test-only rings (plus the existing F8 path); Clean Catch persists until a damage > 0 hit or fight reset; Echo / Echo Dash cancel lists unchanged.

**Implemented:** `bit_null.tres`, `null_dodge.tres` (0/30/8, invulnerable 1-30, CD 120, 0 tiles); `ActionDef.slows_move` / `arms_clean_catch` with validation; `Defs.BIT_NULL`, `Defs.NULL_DODGE`, `Defs.bit(NULL_BIT)`; `SimContext.move_slowed`; ASM publishes it, unlocks slows_move ACTIVE frames, owns `clean_catch_armed` / `arm_clean_catch` / `consume_clean_catch`, clears it in `reset_for_fight`; `Player` x0.5 on `watch_held or move_slowed`; `PlayerHealth.apply_hit` arms on a dodge rejection (Echo included: the echoed def is `action`); `CombatResolver` passes the flag to DamageCalc and consumes it on damage > 0.

**Tests:** new `test_null_dodge.gd` (18) and `test_clean_catch.gd` (16), Clean Catch rows in `test_damage_calc.gd`, flag validation in `test_data_validation.gd`, a fight-level test in `test_null_pointer_fight.gd` (a real Null Pointer attack through Null Dodge arms Clean Catch, then a slash on the unpatched ghost deals 8 through `hit_landed`). Full GUT suite 1302/1302 passing, `check_guards.sh` OK, headless import clean (no SCRIPT ERROR / Parse Error). Replays unchanged and passing.

### File List

- game/data/bits/bit_null.tres (new)
- game/data/actions/null_dodge.tres (new)
- game/data/actions/slash_1.tres
- game/data/actions/slash_2.tres
- game/data/actions/slash_3.tres
- game/data/actions/dash.tres
- game/src/player/action_def.gd
- game/src/player/action_state_machine.gd
- game/src/player/player.gd
- game/src/player/player_health.gd
- game/src/combat/combat_resolver.gd
- game/src/core/defs.gd
- game/src/core/sim_context.gd
- game/tests/unit/test_null_dodge.gd (new)
- game/tests/unit/test_null_dodge.gd.uid (new)
- game/tests/unit/test_clean_catch.gd (new)
- game/tests/unit/test_clean_catch.gd.uid (new)
- game/tests/unit/test_damage_calc.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_action_resolver.gd
- game/tests/unit/test_echo_dash.gd
- game/tests/unit/test_debug_keys.gd
- game/tests/integration/test_null_pointer_fight.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/5-5-null-bit-null-dodge-and-clean-catch.md

### Change Log

- 2026-11-11: Story 5.5 implemented (NULL bit, Null Dodge, Clean Catch); spec bit ids and Dash Strike cancel list corrected; status -> review.
