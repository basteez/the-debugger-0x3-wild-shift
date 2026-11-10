---
baseline_commit: 861597f
---
# Story 4.1: LOOP Bit - Echo

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-10). Open design questions are marked [design call] with the chosen default (D-S41-n); the implementer follows them or records a change in Completion Notes. Scope: the Echo solo action of the LOOP bit (replaces the Story 3.8 NOP placeholder on bit_loop.tres), the Echo memory, empty-memory rule, Echo's damage factor, the LOOP cooldown, the memory clear on fight start and retry, and the tests. NOT in scope: Echo Dash and the D->L combo (4.2), the PASS_THROUGH producer (4.2), Breakpoint (4.3), the duck hint (4.4), any HUD cooldown display. -->

## Story

As a player,
I want LOOP to replay my last move from where I stand,
so that I can double up attacks and escapes.

## Acceptance Criteria

1. **Data.** `data/bits/bit_loop.tres` (`solo_action`) points at the new `data/actions/echo.tres` instead of `nop.tres`. `echo.tres` is an `ActionDef` with `id = &"echo"`, `echo_action = true`, `cooldown_frames = 90`, `echo_damage_pct = 70`, no hit shape, `base_damage = 0`, `echoable = false`, and it validates (`ActionDef.validate()` empty). `nop.tres` stays in the repo unchanged (Epic 6 garbage bit, NP-3); only its header comment changes. `Defs.ECHO` preloads `echo.tres`; `Defs.solo_action(Register.Bit.LOOP) == Defs.ECHO`.

2. **Storage (what Echo remembers).** Given a solo bit action starts (its exact `ActionDef`, e.g. `slash_3`, `dash`, a chain hit `slash_2`, or K's link follow-up solo), then `EchoMemory.last` becomes that `ActionDef`, whether the action hits or whiffs. Combos, Echo itself and any `echoable = false` def (NOP) never change memory. Starting an action that is cancelled during its startup must not store it (cancel is only possible in RECOVERY today, so this is vacuous; keep the rule in code comments) [design call D-S41-1].

3. **Empty memory.** Given no action has been stored since fight start, when I press the slot holding `L` (J or K, solo or as a link follow-up), then nothing happens: no action starts, no LOOP cooldown starts, the press is not consumed beyond the normal 8-frame expiry, and no error is logged. The other slot's action can still start from the same press set as today.

4. **Echo.** Given memory holds a def and LOOP's cooldown is ready, when I press the `L` slot, then `EchoMemory.last` is re-executed as the running action at my current position (`action_origin_px`) and facing, with the echoed def's frame data, invulnerability, intangibility, hit shape and hit-stop. LOOP's cooldown starts at 90 frames on the start tick. Echo neither checks nor starts the echoed action's own bit cooldown (e.g. DASH) [design call D-S41-4]. Echo does not start or continue an ATTACK chain [design call D-S41-7].

5. **Damage.** Echo's damage uses factor 70% (`echo_damage_pct`, integer, passed to `DamageCalc` as `echo_scale = 0.7`), rounded once with `DamageCalc`. Practice target: Echo of `slash_3` (15) deals 11; Echo of `slash_1` or `slash_2` (10) deals 7; Echo of DASH (0 damage) produces a second dash (movement only).

6. **Boss interaction.** An Echo hit on the boss is a plain solo HIT (not a combo): it applies Patched damage state through the normal `WeakWindowTracker` path but never completes a weak window by itself (NP-4, D-S32-6). An Echo started as K's `link_second` on a no-combo window counts as `link_second` (see D-S41-11).

7. **Reset.** Echo memory is cleared on every fight start and on every retry (both go through `Arena.enter_fight` -> `ActionStateMachine.reset_for_fight`). A new run starts empty.

8. **Determinism and rules.** Echo uses no RNG and no `delta`, `Timer`, `await` or float state beyond `DamageCalc`'s pct conversion. `Log.debug(&"action", ...)` only on the start event (never per frame). Simulation folders (`src/player`, `src/combat`, `src/arena`) do not reference `ui`, `presentation` or audio classes. The replay tests (`tests/replays/`, `tests/integration/test_infinite_loop_replay.gd`) still pass; if a recorded session contains an `L`-slot press whose hash changes, the story records it and updates the expectation with the reason (not silently).

9. **Tests.** Unit tests for AC1-AC7 exist (see Tasks Group F). The two Story 3.8 expectations that assumed NOP on LOOP (`tests/unit/test_data_validation.gd` around lines 268-285 and `tests/unit/test_action_resolver.gd` `test_loop_slot_starts_the_nop_action`) are rewritten to the Echo behaviour and not deleted. Full GUT run headless passes and the guards (`Timer.new`/`await`/bare `print(` / isolation checks) pass.

10. **Scope fence.** No `ComboDef` for D->L is added to `data/combos/combo_table.tres` (that is 4.2); D->L with K on an empty no-combo link therefore resolves to Echo as `link_second` until 4.2 lands. No Breakpoint, no feature flag, no PASS_THROUGH producer.

## Tasks / Subtasks

### Group A: Data (AC: 1, 2)
- [x] A1. Add `ActionDef` fields: `@export var echo_action: bool = false`, `@export var echoable: bool = true`, `@export var echo_damage_pct: int = 100`. `validate()`: `echo_damage_pct` in 1..200 when `echo_action`, and `echo_action` requires `hit_shape == null` and `base_damage == 0`.
- [x] A2. Create `data/actions/echo.tres` (`echo_action = true`, `echoable = false`, `cooldown_frames = 90`, `echo_damage_pct = 70`, `startup_frames = 0`, `active_frames = 1`, `recovery_frames = 0`, `hitstop_frames = 0`, header comment: frame data is a placeholder; the FSM substitutes the remembered def).
- [x] A3. Set `nop.tres` `echoable = false` (explicit) and update its header (no longer on LOOP; kept for the Epic 6 garbage bit).
- [x] A4. `data/bits/bit_loop.tres`: `solo_action = echo.tres`; update its comment.
- [x] A5. `Defs`: `const ECHO: ActionDef = preload("res://data/actions/echo.tres")`. Do not change `BIT_LOOP`.

### Group B: Echo memory and FSM wiring (AC: 2, 4, 5, 7)
- [x] B1. New `src/player/echo_memory.gd` (`class_name EchoMemory`, `RefCounted`): `var last: ActionDef = null`, `func has_last() -> bool`, `func remember(def: ActionDef) -> void` (no-op when `def == null` or `not def.echoable` or `def.echo_action`), `func clear() -> void`. Pure, no node.
- [x] B2. `ActionStateMachine`: own `var echo: EchoMemory = EchoMemory.new()`; `var echoing: bool = false` (true while the running action is an echo); `func echo_scale() -> float` returns `echo_damage_pct / 100.0` when `echoing` and the echo def's pct, else `1.0`.
- [x] B3. `ActionStateMachine._start`: when `request.def.echo_action`, the running `action` becomes `echo.last` (already checked non-null by the resolver gate), `echoing = true`, cooldown = the echo def's `cooldown_frames` on `request.bit` (LOOP), `_clear_chain()`, `link_second` as requested. Otherwise `echoing = false`, and before returning, if the started def is a solo bit action (not combo, not echo) call `echo.remember(def)`. Combo starts never store.
- [x] B4. `ActionStateMachine.reset_for_fight`: `echo.clear()`, `echoing = false`. `_finish()` sets `echoing = false`.
- [x] B5. `Arena.enter_fight`: no new call needed if B4 runs through `actions.reset_for_fight()` (already called there); replace the "Echo memory clear (Epic 4) belongs here" comment with a pointer to `ActionStateMachine.reset_for_fight`.

### Group C: Resolver gate (AC: 3)
- [x] C1. `ResolveInput`: add `var echo_ready: bool = false`. `ActionStateMachine._resolve_input` sets `input.echo_ready = echo.has_last()`.
- [x] C2. `ActionResolver`: in `_solo`, `_cancel` and `_link`, skip a def with `echo_action == true` when `echo_ready` is false (treat as no action; do not consume the press, do not start cooldown). Same rule in `_link` for `held` presses (a held L-K press with empty memory is dropped by the normal lifetime rule).
- [x] C3. Keep `ActionResolver.resolve` pure: the gate reads only `ResolveInput`.

### Group D: Damage (AC: 5, 6)
- [x] D1. `CombatResolver`: both `DamageCalc.compute(..., 1.0)` call sites (practice target in `tick`, boss in `_resolve_boss_hit`) pass `actions.echo_scale()` as `echo_scale`. Clean Catch stays `false`.
- [x] D2. Verify `DamageCalc.to_pct(0.7) == 70` passes the `% 5` assert (it does).

### Group E: Arena and flow (AC: 7)
- [x] E1. Update the `Arena.enter_fight` doc comment only (Echo memory clear now lives in the FSM reset). Retry uses the same route (`Game` -> `enter_fight`).

### Group F: Tests (AC: 1-9)
- [x] F1. `tests/unit/test_echo_memory.gd`: remember/clear rules (combo no, echo no, NOP no, solo yes, whiffed yes, chain hit yes).
- [x] F2. `tests/unit/test_action_fsm.gd` (or a new `test_echo_action.gd`): J/K on an L slot with empty memory starts nothing and leaves cooldown 0; after a `slash_3` start and its end, pressing L starts Echo: `action == slash_3`, `echoing == true`, `cooldowns.remaining(LOOP) == 90`, `cooldowns.remaining(A) == 0`; second L press within 90 frames is blocked and stays buffered.
- [x] F3. Echo of DASH moves the player (second dash, own invulnerability frames 1-8).
- [x] F4. Damage: with `DamageCalc`: 15 -> 11 and 10 -> 7 through `CombatResolver` against `PracticeTarget` (use a stub target at the echo position); Patched Echo of 15 -> 16 (`DamageCalc.compute(15, 1.5, false, 0.7)`).
- [x] F5. Boss rule: a solo Echo HIT does not satisfy `BossInteraction.completes_weak_window` (`is_combo = false`, `is_link_second = false`).
- [x] F6. Reset: after a fight with memory, `Arena.enter_fight(...)` twice (fight start and retry) leaves `actions.echo.has_last() == false`.
- [x] F7. Update the two Story 3.8 expectations (see AC9); keep the NULL_BIT "no action" tests.
- [x] F8. Run the full GUT suite headless (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`) and the guards. Record the test count in Completion Notes.

## Dev Notes

### Design calls for this story (D-S41-n)

- **[design call] D-S41-1 What Echo stores.** `EchoMemory.last` is the exact `ActionDef` of any *solo bit* action at its start: J/K solo, the ATTACK chain hits (`slash_2`, `slash_3`), and K's `link_second` solo. Whiffs count. Not stored: combos, Echo itself (`echo_action`), `echoable = false` defs (NOP). Storage happens at start, so a startup-cancelled action is never stored (cancel is RECOVERY-only today). Source: GDD line 176 ("not a combo, not Echo itself, not an action cancelled during its startup"), NP-5, architecture design call.
- **[design call] D-S41-2 Echo is a data def, the FSM substitutes the memory.** `data/actions/echo.tres` is the solo action of LOOP so the resolver, cooldowns and HUD see a normal bit. The running action is the remembered `ActionDef` itself (not a copy), so its frame data, invulnerability, hit shape and hit-stop are exact.
- **[design call] D-S41-3 Empty memory is "no action" in the resolver, not a runtime no-op.** An L slot with empty memory is not startable: the resolver skips it (press left buffered, expires in 8 frames), no cooldown, no log. This keeps the NOP-free "pressing L does nothing" rule and avoids starting a running action that does nothing.
- **[design call] D-S41-4 Cooldowns.** Echo starts LOOP's 90 frames (from `echo.tres`), and it does not start or check the echoed bit's cooldown. Reason: the echoed action already paid its cost when first performed; double-charging would make Echo of DASH unusable right after a dash. Alternative (charge the echoed bit as well) rejected for 4.1; revisit at the MVP playtest (3.9/4.x tuning).
- **[design call] D-S41-5 Damage factor as integer data.** `echo_damage_pct = 70` lives in `echo.tres`; the float reaches `DamageCalc` only as `pct / 100.0` and is converted back by `DamageCalc.to_pct` (roundi of x100, exact for 70). Keeps integer data authoritative; no float is stored in sim state.
- **[design call] D-S41-6 Echo of a solo or a link_second.** Echo as a solo J/K hit is a plain HIT (does not complete a weak window). Echo as K's `link_second` (on a no-combo window such as D->L before 4.2) is a `link_second` HIT and completes a weak window under NP-4's no-combo rule. This is the existing rule applied to Echo, not a new one.
- **[design call] D-S41-7 Echo does not start a chain.** An echoed `slash_1` does not set `chain_key`/`chain_serial`; the chain record is cleared on echo start. Keeps Echo from creating a second chain path.
- **[design call] D-S41-8 Memory lives on the FSM, cleared in `reset_for_fight`.** `EchoMemory` is owned by `ActionStateMachine` (`src/player/echo_memory.gd`), not by `RunState`. The GDD and AD-08 say retry restores the fight-start snapshot (register, HP, boss); the memory is per-fight, so the snapshot does not carry it. `RunState` is unchanged.
- **[design call] D-S41-9 Presentation.** No new art, sound or HUD. Echo reuses the existing action path (player position, facing, hit feedback via `hit_landed`, hit-stop). A new SFX for Echo is an Epic 7 item (FR63).
- **[design call] D-S41-10 Chain hits count as solo bit actions.** `slash_2` and `slash_3` started through the chain are solo ATTACK actions, so a 3-hit chain's last hit is `slash_3` (matches the AC example in the epic).
- **[design call] D-S41-11 D->L before 4.2.** `combo_table.tres` still has only Dash Strike. The window [D, L] with K therefore runs Echo as `link_second` (no combo) until Story 4.2 adds Echo Dash. Recorded so 4.2 knows the D->L link_second behaviour it replaces.

### Architecture and rules that bind this story

- AD-02 / NP-1: `ActionResolver` is the only J/K -> action path. The memory gate is a resolver input, not a separate check in the FSM.
- AD-01: all durations are int frames; Echo cooldown 90 frames; no `delta`.
- NP-5 (Echo Memory): "set when a solo bit action starts", "re-executes at 70%", "empty memory -> no action, no cooldown", "cleared on fight start and retry". This story implements NP-5 as written, with D-S41-1 to D-S41-8 detailing it.
- NP-4 / D-S32-6: a solo HIT never completes a weak window by itself; `BossInteraction.completes_weak_window` is the single rule (unchanged).
- Project context: "Echo stores the exact last solo `ActionDef` (not combos, not Echo, not garbage NOP, not actions cancelled in startup); empty memory -> no action and no cooldown." "Retry restores the fight-start RunState... Echo memory and link cleared."
- Single writers: damage -> `DamageCalc.compute()` only; J/K -> `ActionResolver`; memory writes only in `EchoMemory` via the FSM start path.
- Defs are read-only at runtime: never mutate `echo.tres` or `ActionDef` fields at runtime; memory holds a reference.
- Simulation code runs without a scene tree (tests build an FSM with `InputBuffer`, `Register`, `Player` and an injected `ComboTable`).

### Existing code this story touches (read before editing)

- `game/src/player/action_state_machine.gd`: `tick()` (resolve, then `_start`), `_start()` (cooldown: currently `request.def.cooldown_frames`, which must use the echo def for Echo; combo branch uses the replaced solo's cooldown), `reset_for_fight()`, `_finish()`, `_resolve_input()`, `_update_link()` (a J action opens the link; Echo from J opens it too, which is intended).
- `game/src/player/action_resolver.gd`: `resolve()`, `_j_request`, `_link` (`Defs.solo_action(target_bit)` at the top), `_cancel`, `_solo`. Each takes `Defs.solo_action(bit)`; the echo gate goes in all three.
- `game/src/player/resolve_input.gd`: add `echo_ready`.
- `game/src/player/action_request.gd`: no change (request carries `def`, `bit`, `slot`, `combo`, `link_second`).
- `game/src/player/action_def.gd`: new fields and validation (Group A).
- `game/src/combat/combat_resolver.gd`: two `DamageCalc.compute` calls with `echo_scale` `1.0` (practice `tick`, boss `_resolve_boss_hit`).
- `game/src/combat/damage_calc.gd`: no change (`echo_scale` already a parameter; `to_pct` converts).
- `game/src/combat/boss_interaction.gd`: no change; `completes_weak_window` already handles HIT with `is_combo` / `is_link_second`.
- `game/src/core/defs.gd`: `BIT_LOOP` and `bit()` already return LOOP's def (Story 3.8); add `ECHO`.
- `game/src/arena/arena.gd`: `enter_fight` (calls `actions.reset_for_fight()`), comment only.
- `game/data/bits/bit_loop.tres`, `game/data/actions/nop.tres`: see Group A.
- Tests that assume LOOP is NOP: `game/tests/unit/test_data_validation.gd` (~lines 268-285, `Defs.solo_action(LOOP) == Defs.NOP`), `game/tests/unit/test_action_resolver.gd` (~lines 81-90, `test_loop_slot_starts_the_nop_action`). Other tests using `L` (`test_register*.gd`, `test_combo_table.gd`, `test_weak_window.gd`, `test_harvest_*.gd`, `test_debug_keys.gd`, `test_game_flow.gd`) use `L` as a ring bit; check each still passes (an empty-memory L is not startable, which changes "press L starts an action" expectations).
- `game/tests/replays/test_replays.gd` and `game/tests/integration/test_infinite_loop_replay.gd`: replay hashes. Check whether any recorded input presses the L slot (see AC8).

### Deferred items reviewed for this story (deferred-work.md)

- **Folded in:** the 3.8 deferred note that `Defs.solo_action(LOOP)` is NOP (D-S38-6) is resolved here by replacing it. The 3.2 note that `PASS_THROUGH`/`DECOY_STRUCK` have no producer stays open: `PASS_THROUGH` is 4.2, `DECOY_STRUCK` is 6.1 (not this story).
- **Not folded (belongs elsewhere):** 2.1 InputBuffer growth while frozen (4.3); 2.4 shift click/inversion gating on `&"player"` (no boss shifts exist); 2.6 ComboDef.validate checks and the Dereference label (4.2 / 6.2); 2.8 ScreenFX non-palette pixels with Breakpoint (4.3); 3.3 shift-count gate "greater than" with non-player shifts (Echo is not a shift; no change); 2.3 `Register.insert` vs buffered shifts (3.8, resolved); 2.9 retry RNG seeding from wall clock (3.4/3.8 territory, not Echo).
- **Note (no action):** 2.3 "hit-stop > 8 frames drops buffered input" applies to Echo presses like any press; judged by feel in the playtest.

### Previous story intelligence (3.8, last done; Epic 3 status done)

- 3.8 registered LOOP with NOP on purpose (D-S38-6) and left `Defs.bit(LOOP)` non-null, so `L` slots now start the NOP. Echo replaces that, and the "no action" slot in tests is `NULL_BIT` (Epic 5) for now.
- Harvest inserts LOOP on a copy of the register outside FIGHT; the arena register is inactive then, so the insertion and buffered shifts never meet in one tick (3.8 C4). Echo does not change this.
- The next fight's register is `Register.fight_start_for_boss(1)` = `[A, D, L]` (`0x07`). Fight 2 therefore has L from the first tick: Echo is live in Fight 2 as soon as the player presses L with memory (memory is empty at fight start, so the first L press does nothing until a solo action has happened).
- Story 3.8 review: "changed test expectations were checked one by one; all tied to the feature". Keep that discipline for the two NOP expectations.

### Previous story intelligence (2.5-2.7, combat core)

- 2.5: `cancel_into` and the chain are RECOVERY-only; there is no startup cancel, so the D-S41-1 startup rule is vacuous today.
- 2.6: the link (`LinkState`) opens on a J action's first ACTIVE frame; K follow-ups go through `_link`. An Echo started from J opens the link like any J solo. Link closes on any shift (NP-1 rule 5).
- 2.7: `CombatResolver` applies `DamageCalc` with `echo_scale = 1.0` today; `hits_for` / `boss_overlapped` dedupe per `action_serial`. Echo is a new action start, so it gets a new serial and hits once.
- 3.2: `BossInteraction` and `WeakWindowTracker` take `window_pair`; the `window_pair` for an Echo hit is the action's `action_window` (window at start).

### Git intelligence (recent commits)

- `861597f` Docs: itch.io deploy and Chrome smoke results (#31); `23bb7e7` Fix: game frozen after resuming from focus-loss pause (#30); `d88634e` Fix: resume with P or click (#29); `04d91cd` Devlog #1 (#28); `35184ec` Story 3.8 (#27). Epic 3 stories 3.1-3.8 are merged; the codebase follows the pattern "resolver/FSM pure + tests + small wiring".

### Latest technical information

- Pinned: Godot 4.7.2-stable (do not upgrade), GUT 9.6.1, GDScript only. Godot 4 syntax only (`@export`, typed arrays, `signal` in `EventBus` only). No new APIs are needed for Echo; `RefCounted` plus static pure functions suffice.

### Project Context Rules (from project-context.md)

- Echo stores the exact last solo `ActionDef` (not combos, not Echo, not garbage NOP, not startup-cancelled); empty memory -> no action and no cooldown; cleared on fight start and retry.
- Only `SimClock` ticks; no `_process`/`delta`/`Timer`/`await` in simulation code. `await` and Tweens only in presentation.
- Static typing everywhere; `StringName` ids (`&"echo"`); `*_frames` int fields; `*_def.gd` for defs; files snake_case.
- Logging: `Log.debug(&"action", ...)` on the start event only; no `print`.
- Simulation folders do not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.
- Tests: `tests/unit/test_<subject>.gd` for pure logic; build systems from defs plus injected `ComboTable`; no scene tree needed.

### Project Structure Notes

- New: `game/src/player/echo_memory.gd` (+ `.uid` by Godot on first open), `game/data/actions/echo.tres`, `game/tests/unit/test_echo_memory.gd` (and optional `test_echo_action.gd`).
- Modified: `game/src/player/{action_def,action_state_machine,action_resolver,resolve_input}.gd`, `game/src/combat/combat_resolver.gd`, `game/src/core/defs.gd`, `game/src/arena/arena.gd` (comment), `game/data/bits/bit_loop.tres`, `game/data/actions/nop.tres` (comment, `echoable`), and the tests listed above.
- No conflicts with the architecture tree: Echo logic lives in `src/player/` (the register/player domain), not `skills/` (no cut flag applies to LOOP).

### Testing standards

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: Echo of 15 -> 11 (unpatched practice target), 10 -> 7, Patched Echo of 15 -> 16.
- Guards in CI: no `Timer.new`/`await` under the sim folders, no bare `print(` in `src/`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1: LOOP Bit - Echo] (ACs, FR12)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] line ~176 (LOOP row: Echo rules, 70%, CD 90), line ~216 (rounding: Echo 15 -> 11 style), line ~301 (Boss 2 [L,A] Echo window).
- [Source: _bmad-output/game-architecture.md#NP-5 Echo Memory] and [#AD-02 Actions & Combos], [#NP-1], [#NP-4].
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] (Echo rules).
- [Source: _bmad-output/implementation-artifacts/3-8-boss-defeat-and-harvest.md] D-S38-5, D-S38-6, Group C.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] sections "code review of story-3.8", "story-3.2", "story-3.3".
- [Source: _bmad-output/implementation-artifacts/2-6-ordered-combo-engine-and-dash-strike.md] link rules; [2-7] damage path.

## Dev Agent Record

### Agent Model Used

claude opus (Claude Code, gds-dev-story, unattended pipeline)

### Debug Log References

- First full GUT run after Groups A-D (before test edits): 950 tests, exactly the two expected Story 3.8 failures (`test_bit_loop_and_nop_validate_and_resolve`, `test_loop_slot_starts_the_nop_action`), confirming no other test relied on NOP on LOOP.
- First run of the new tests: 2 failures fixed in the tests, not the code: (1) `InputBuffer.size()` counts an expired press until the next prune, so the expiry check now uses `consume(J, _t) == false`; (2) a dash moves ~65.87 px (not exactly 64) because the player's own movement integrates over the unlocked frames, so the Echo-of-DASH test asserts "same distance again" relative to the first dash.
- Final: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` -> Tests 975, Passing 975, Asserts 33108, "All tests passed!", no SCRIPT ERROR / Parse Error in import or GUT logs. `bash game/tools/check_guards.sh` -> `check_guards: OK`.

### Completion Notes List

- **Data (AC1):** `ActionDef` gains `echo_action`, `echoable`, `echo_damage_pct` (+ validation: pct 1..200, no hit shape, base 0 when `echo_action`). New `data/actions/echo.tres` (cooldown 90, pct 70, placeholder frame data). `bit_loop.tres` -> Echo. `nop.tres` kept with `echoable = false` and a new header (Epic 6 garbage bit). `Defs.ECHO` added; `Defs.solo_action(LOOP) == Defs.ECHO`.
- **Memory (AC2, AC7):** new `src/player/echo_memory.gd` (`EchoMemory`, pure RefCounted). `ActionStateMachine` owns `echo`, `echoing`, `echo_scale()`; `_start` stores every solo bit start (J/K solo, chain hits, cancels, `link_second`) and never combos, Echo or NOP; `reset_for_fight` clears memory (fight start and retry both go through `Arena.enter_fight`); `_finish` clears `echoing`.
- **Echo start (AC4):** an Echo request runs `echo.last` itself at the current `action_origin_px`/facing, starts LOOP's 90-frame cooldown from the Echo def, never touches the echoed bit's cooldown (D-S41-4), clears the chain (D-S41-7), keeps `link_second` as requested. Log: one `Log.debug(&"action", "<verb> echo <id>")` on start only.
- **Resolver gate (AC3):** `ResolveInput.echo_ready` (set from `echo.has_last()`); `ActionResolver.startable_def()` gates `_solo`, `_cancel` and `_link` (new press left buffered; held link press dropped by the normal lifetime rule). The resolver stays pure.
- **Damage (AC5, AC6):** both `DamageCalc.compute` sites in `CombatResolver` pass `actions.echo_scale()`. Verified: practice 15 -> 11, 10 -> 7; Patched 15 -> 16; boss unpatched solo Echo does not patch. `BossInteraction` unchanged.
- **AC8:** no RNG/delta/Timer/await added; sim folders untouched for UI/audio refs; replay tests (`tests/replays/test_replays.gd`, `tests/integration/test_infinite_loop_replay.gd`) pass with unchanged hashes (no recorded session presses an L slot), so no expectation was updated.
- **AC9 / F7:** the two Story 3.8 NOP-on-LOOP tests were rewritten (not deleted): `test_bit_loop_echo_and_nop_validate_and_resolve` (Echo on LOOP, NOP kept and non-echoable) and `test_loop_slot_starts_echo_only_with_memory` (empty memory -> no action and press not consumed; `echo_ready` -> Echo request). NULL_BIT "no action" tests kept.
- **AC10:** no ComboDef added; D->L with K on an open link runs Echo as `link_second` (covered by `test_echo_of_dash_is_a_second_dash_ignoring_dash_cooldown`).
- **New tests:** `tests/unit/test_echo_memory.gd` (6) and `tests/unit/test_echo_action.gd` (19): data/validation, storage via FSM (whiff, chain, combo, link_second), empty memory on both slots, other slot still starts, resolver gate, Echo of slash_3 (cooldowns, memory, scale, blocked second press), position/facing, no chain, Echo of DASH (second dash, invuln 1-8, DASH cooldown untouched, link_second on [D, L]), damage 11/7/16/0, boss solo rule, reset via FSM and via `Arena.enter_fight` twice.
- **Design calls:** D-S41-1 to D-S41-11 followed as written. New: [design call] D-S41-12 `_start` keeps a belt-and-braces guard: an Echo request reaching the FSM with empty memory is ignored (no cooldown, no state change); unreachable through the resolver gate. [design call] D-S41-13 the Echo damage factor comes from the Echo def that started the running action (kept in a private `_echo_def`), not a global constant, so future Echo variants (e.g. 4.2 Echo Dash) can carry their own pct. [design call] D-S41-14 `nop.tres` gets `echoable = false` explicitly per task A3 (AC1's "unchanged" read as "no gameplay change"; the field is a no-op for NOP's runtime behaviour).

### File List

- game/src/player/echo_memory.gd (new)
- game/src/player/echo_memory.gd.uid (new)
- game/data/actions/echo.tres (new)
- game/tests/unit/test_echo_memory.gd (new)
- game/tests/unit/test_echo_memory.gd.uid (new)
- game/tests/unit/test_echo_action.gd (new)
- game/tests/unit/test_echo_action.gd.uid (new)
- game/src/player/action_def.gd
- game/src/player/action_state_machine.gd
- game/src/player/action_resolver.gd
- game/src/player/resolve_input.gd
- game/src/combat/combat_resolver.gd
- game/src/core/defs.gd
- game/src/arena/arena.gd
- game/data/bits/bit_loop.tres
- game/data/actions/nop.tres
- game/tests/unit/test_action_resolver.gd
- game/tests/unit/test_data_validation.gd
- _bmad-output/implementation-artifacts/4-1-loop-bit-echo.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-10: Story 4.1 created unattended by gds-create-story (pipeline). Status -> ready-for-dev. Design calls D-S41-1 to D-S41-11.
- 2026-11-10: Story 4.1 implemented (claude opus, pipeline): Echo on LOOP, EchoMemory, resolver gate, 70% damage, LOOP cooldown 90, reset on fight start/retry; 3.8 NOP expectations rewritten; GUT 975/975, guards OK. Status -> review. New design calls D-S41-12 to D-S41-14.
- 2026-11-10: Code review (gds-code-review, 3 parallel layers): 2 patch, 5 defer, 7 dismissed. GUT 976/976, guards OK. Status -> done.

### Review Findings

- [x] [Review][Patch] ActionDef.validate accepted an echo_action with echoable = true or cooldown_frames < 1 (Echo spammable every frame on a data error) [game/src/player/action_def.gd]. Fixed, test_echo_validation_rules extended.
- [x] [Review][Patch] No test for a held K link press with empty memory (AC3 / Task C2 held branch) [game/tests/unit/test_echo_action.gd]. Added test_held_link_press_with_empty_memory_is_dropped_by_lifetime.
- [x] [Review][Defer] Echo as link_second on a boss has no end-to-end test of weak-window completion (D-S41-6/D-S41-11); only the pure BossInteraction and FSM halves are tested — deferred, belongs with the 4.2 Echo Dash combo tests.
- [x] [Review][Defer] Echo of a def that has `cancel_into` can cancel into other bits, and an Echo run opens a link on (L, y) like any J solo (intended per Dev Notes, untested) — deferred to 4.2.
- [x] [Review][Defer] Echo keeps a reference to a shared ActionDef resource; safe while defs are immutable, revisit if Epic 5/6 mutates defs at runtime — deferred.
- [x] [Review][Defer] The echoed hit re-applies the original def's Patched/boss interactions at 70% damage; no test pins this — deferred.
- [x] [Review][Defer] `echoable` defaults to true (opt-out); future defs (boss/garbage) must remember to set it — deferred.

Dismissed (7): `_start` empty-memory guard unreachable (belt and braces by design); cooldown read from request.def not action (verified by DASH-cooldown test); echo_scale vs _finish on last frame (no echoable def has a hit on its final frame); float drift of 0.7 (DamageCalc quantizes to integer percent); echo state not in the snapshot ring (cleared per fight, ring is RunState only); NOP test coverage loss and 3.8 rewrites (real: LOOP's solo action is Echo, NOP gained echoable=false, expectations not weakened); AC6 "applies Patched" wording (Echo hit is a plain solo HIT, Patched only changes the multiplier when already patched).
