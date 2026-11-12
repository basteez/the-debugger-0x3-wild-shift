---
baseline_commit: ac51a03
---
# Story 6.1: Ghost Echo Combo

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Open design questions are marked [design call] with the chosen default (D-S61-n); the implementer follows them or records a change in Completion Notes. Scope: the L->N combo Ghost Echo (intangible 30 frames, replaces Null Dodge, NULL cooldown), the intangible decoy it leaves for 120 frames, boss targeting through the arena context, and the DECOY_STRUCK producer (BossInteraction, completes the L->N weak window). NOT in scope: Dereference (6.2), the Segfault body and its attacks (6.3-6.5), Reserved Write (6.6), any real Boss 3 gating or Segfault HUD, final art or sound for the decoy (7.x). -->

## Story

As a player,
I want L then N to leave a decoy that bosses attack,
so that I can bait a boss and patch it.

## Acceptance Criteria

1. **Data.** `data/actions/ghost_echo.tres` is an `ActionDef` with `id = &"ghost_echo"`, `startup_frames = 0`, `active_frames = 30`, `recovery_frames = 8`, `invuln_from = 1`, `invuln_to = 30`, `hit_shape = null` (it hits nothing), `base_damage = 0`, `cooldown_frames = 0`, `move_tiles = 0.0`, `echoable = false`, `echo_action = false`, `redirectable = false`, `pass_through = false`, `slows_move = false`, `arms_clean_catch = false`, and the new `decoy_frames = 120` (see D-S61-3). `data/combos/ghost_echo.tres` is a `ComboDef` with `first = Register.Bit.LOOP`, `second = Register.Bit.NULL_BIT`, `action` = that def, `display_name = "Ghost Echo"`, `gap_free = false`. It is added to `data/combos/combo_table.tres`. `ComboTable.validate()` and `ActionDef.validate()` return empty for the shipped table, and `ActionDef.validate()` rejects a negative `decoy_frames`.

2. **Trigger and cost.** Given the window `[L, N]` (L in slot 1, N in slot 2) and the first action (LOOP's Echo) is ACTIVE or inside its 18-frame link window, when I press K, then Ghost Echo fires and replaces Null Dodge (N's solo action, K's solo on this window). NULL's cooldown of 120 frames starts (the replaced solo's cooldown, D-S26-3). LOOP's cooldown is not touched again. The combo is not blocked by Echo memory (`echo_ready` is not consulted for combos). `EchoMemory` is not written by this start (NP-5, D-S41-1). A K press while N is on cooldown follows the normal combo rule (buffered 8 frames, then dropped).

3. **Intangibility.** Ghost Echo is intangible on its own frames 1-30 through the existing invulnerable-frame path (`PlayerHealth` rejects hits on those frames). It does not arm Clean Catch (`arms_clean_catch` is false, D-S61-2). Frames outside 1-30 are not invulnerable.

4. **Decoy spawn.** On the tick Ghost Echo starts, an intangible `GhostDecoy` is created at the player's start point (`action_origin_px` of that start, not the position of any later frame), carrying `window_pair = L->N` (`Vector2i(Register.Bit.LOOP, Register.Bit.NULL_BIT)`) and `frames_left = 120`. The decoy counts down by one per sim frame that is not frozen by hit-stop (D-S61-5). When `frames_left` reaches 0 it is removed. Exactly one live decoy exists at a time: a second Ghost Echo while one is live replaces it at the new start point (D-S61-4).

5. **Targeting.** While a decoy is live, `ArenaContext.target_position()` returns the decoy's position; otherwise it returns the player's position (the same as before this story). `target_facing()` and `body_contact_position()` keep returning the player's values. No boss attack script reads the decoy directly; attacks keep aiming only through `ctx.target_position()` (NP-3, test_attack_isolation still passes).

6. **DECOY_STRUCK.** Given a live decoy and a boss attack in ACTIVE whose `hazard_hit` is true at the decoy's position, when the tick resolves, then `CombatResolver` produces one `BossInteraction` of kind `DECOY_STRUCK` with `window_pair` = the decoy's L->N, runs `WeakWindowTracker.process` against `boss.current_weak_window()`, and removes the decoy (it is struck once). If the window matches, Patched is applied for 180 frames through the tracker and `patched_applied` is emitted. If it does not match, the decoy is still removed and no Patched is applied. The strike deals no damage, emits no `hit_landed`, and requests no hit-stop. The same attack still hits the player under its normal rules in that tick.

7. **Player interactions with the decoy are none.** The player's own hits (`hits_for`, `decoy_hit` for Null Pointer decoys, the whiff rule) never see or dispel the Ghost decoy. Boss body contact (`touches_player`) never checks the decoy. A Ghost decoy never causes a NullPointerException stun.

8. **Lifecycle.** The decoy is cleared on fight start, retry, defeat and fight exit (any leave of FIGHT or HARVEST). A phase change (ROAR) does not clear it (D-S61-6). With no boss in the arena, a live decoy is harmless and is cleared on the same exits.

9. **Presentation.** While a decoy is live it is drawn at its spot as a placeholder (D-S61-10): visible at all times, including without Watch. Its frames do not count as the boss ghost's reveal. No HUD mark, no sound.

10. **Tests.** Unit tests in `game/tests/unit/test_ghost_echo.gd` cover: the shipped data validates (AC 1); the L->N window starts Ghost Echo, replaces Null Dodge and starts NULL's 120-frame cooldown (AC 2); the invulnerable range is exactly frames 1-30 and arms no Clean Catch (AC 3); the decoy spawns at the start point with 120 frames and one live decoy at a time (AC 4); the target switch and its restore (AC 5); DECOY_STRUCK completes only a matching L->N window, applies Patched once, removes the decoy once and deals no damage (AC 6); the player's hits and contact never touch the decoy (AC 7); the clear rules (AC 8). `game/tests/unit/test_combo_table.gd` drops `(L, N)` from its unknown-pairs list. Replays (`game/tests/replays/test_replays.gd`) and `game/tests/integration/test_infinite_loop_replay.gd` stay green; their expectations change only if a recorded input really presses K on L->N.

11. **Guards and suite.** `bash game/tools/check_guards.sh` passes. The full GUT suite passes headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (the `godot` on PATH is not available here).

## Tasks / Subtasks

### Group A: Data (AC: 1)
- [x] A1. Add `decoy_frames: int = 0` to `game/src/player/action_def.gd` with its doc comment (D-S61-3) and the `>= 0` check in `validate()`.
- [x] A2. Create `game/data/actions/ghost_echo.tres` (AC 1 values; `hit_shape` unset).
- [x] A3. Create `game/data/combos/ghost_echo.tres` (first LOOP, second NULL_BIT, not gap_free) and add it to `game/data/combos/combo_table.tres`.
- [x] A4. Confirm `ComboDef.validate()` passes for the new combo (second bit has a solo def, action cooldown 0, J startup + 1 <= 8).

### Group B: Action start and decoy spawn (AC: 2, 3, 4)
- [x] B1. `game/src/player/action_state_machine.gd` `_start`: on a start with `request.def.decoy_frames > 0`, increment a public `decoy_spawn_serial` and record the spawn origin (`action_origin_px`) and window (`action_window`) so a consumer can read them. The FSM holds no reference to the decoy or the arena (AD-02, D-S61-3).
- [x] B2. Confirm the combo branch of `_start` already starts NULL's cooldown and returns before `echo.remember` (D-S26-3, D-S41-1). Add no new branch.
- [x] B3. Create `game/src/bosses/framework/ghost_decoy.gd` (`class_name GhostDecoy`, RefCounted): `window_pair`, `position_px`, `frames_left`, `tick()` (counts down to 0), `is_live()`. Sim data only, no nodes.
- [x] B4. A SimSystem `GhostEchoSystem` (new file under `game/src/bosses/framework/`), registered by `Arena` in the BOSS_HAZARDS phase: on a change of `decoy_spawn_serial` it replaces the live decoy with a new one (D-S61-4); on each sim tick that is not hit-stopped it ticks the decoy and drops it at 0 (D-S61-5).

### Group C: Targeting and lifecycle (AC: 5, 8)
- [x] C1. `game/src/arena/arena.gd` `_make_arena_context`: `target_source` returns the live decoy's `position_px` when one is live, else `player.position_px`. `contact_source` and `facing_source` are unchanged.
- [x] C2. `Arena` clears the decoy on fight start, retry, defeat and fight exit (the same places it resets the boss and `CombatResolver`).
- [x] C3. Keep `ArenaContext` read-only for bosses (NP-3): no setter for the decoy is exposed to attack code.

### Group D: DECOY_STRUCK producer (AC: 6, 7)
- [x] D1. `game/src/combat/combat_resolver.gd`: a new injected `ghost: GhostDecoy` (null by default, set by `Arena`). In `tick`, after the boss hazards and before the player's hit handling, if a decoy is live and `boss.attack_hazard_hit(decoy.position_px)`, produce `BossInteraction.Kind.DECOY_STRUCK` with the decoy's window, run `WeakWindowTracker.process(interactions, boss.current_weak_window())`, apply Patched and emit `patched_applied` on a match, and clear the decoy (D-S61-8).
- [x] D2. Keep the decoy out of `hits_for`, `decoy_hit` (Null Pointer decoys) and `_check_whiff`. No hit-stop, no `hit_landed`, no damage path call.
- [x] D3. `BossInteraction` header comment: DECOY_STRUCK now has a producer (Story 6.1).

### Group E: Presentation (AC: 9)
- [x] E1. Draw the live decoy as a placeholder at its spot (D-S61-10) in the existing boss/arena view code, reading only a getter on `GhostDecoy`. Not drawn by Watch's reveal path (Watch does not read it, Story 5.4 AC 11 stays true for Null Pointer decoys).

### Group F: Tests (AC: 10, 11)
- [x] F1. `game/tests/unit/test_ghost_echo.gd`: the cases listed in AC 10. Build the FSM with `InputBuffer`, `Register`, `Player` and an injected `ComboTable` as in `test_echo_dash.gd`; use the test boss (`src/bosses/test_boss/`) for DECOY_STRUCK, with a live attack's `hazard_hit` set at the decoy position.
- [x] F2. Update `game/tests/unit/test_combo_table.gd` (`test_unknown_pairs_are_null`: drop `(L, N)`).
- [x] F3. Run GUT and `bash game/tools/check_guards.sh`; check the replay tests (AC 10).

## Dev Notes

#### Review Findings

- [x] [Review][Patch] Decoy not cleared when the arena leaves the tree [game/src/arena/arena.gd:_exit_tree]
- [x] [Review][Patch] Missing test: live decoy with no boss is harmless (AC 8) [game/tests/unit/test_ghost_echo.gd]
- [x] [Review][Defer] Cast inside an already-locked ACTIVE hazard strikes the decoy at once — deferred, design call
- [x] [Review][Defer] Aim snaps back to the player when the decoy is struck mid-attack — deferred
- [x] [Review][Defer] Pointer Grab uses the player's facing, not the facing at spawn — deferred
- [x] [Review][Defer] _strike_ghost does not check boss.active — deferred
- [x] [Review][Defer] Remaining test gaps (same-tick player hit, boss contact, real phase change, K buffer edge, view helpers) — deferred
- [x] [Review][Defer] Decoy drawn INK at 1x, not "dim" (palette has no alpha) — deferred

## Design calls for this story (D-S61-n)

- **[design call] D-S61-1 Ghost Echo is a combo data def, shipped globally.** `data/actions/ghost_echo.tres` is the action of `data/combos/ghost_echo.tres` (L->N), the same pattern as Dash Strike (2.6) and Echo Dash (4.2, D-S42-1). It replaces Null Dodge (N's solo). The GDD lists "Boss 3" as where it exists; the table has no per-boss gating today and Echo Dash was shipped the same way. Boss 3 gating is an open question below, not part of this story.
- **[design call] D-S61-2 Intangibility uses the existing invulnerable-frame path.** `invuln_from = 1`, `invuln_to = 30` (GDD "Intangible for 30 frames"). Clean Catch is only armed by Null Dodge (D-S55-4), so `arms_clean_catch` stays false. `slows_move` stays false (GDD states no slow for Ghost Echo). `cancel_into` keeps the default (DASH).
- **[design call] D-S61-3 The decoy is a sim object spawned by an FSM serial, not by the FSM.** `ActionDef.decoy_frames` (120) is the data. The FSM only records `decoy_spawn_serial` plus the origin and window (B1). `GhostEchoSystem` (B4) owns the one live `GhostDecoy`, which keeps the FSM free of the arena and the boss (AD-02, single writers). The class is named `GhostDecoy` in `src/bosses/framework/ghost_decoy.gd` rather than `decoy.gd` (game-architecture lists `decoy.gd`) so it is not confused with the Null Pointer decoy arrays in `null_pointer_body.gd`.
- **[design call] D-S61-4 One live decoy; a new cast replaces it.** The epic and the GDD say "a live decoy" and "an intangible decoy ... for 120 frames". With one live decoy, `target_position()` has an unambiguous answer and the boss never chases two points. A cap of 2 would be a one-constant change if playtests want it.
- **[design call] D-S61-5 The decoy counts sim frames (hit-stop freezes it).** Same clock as Patched and the Null Pointer decoy re-cast (live ticks, D-S54-9 precedent). It is decremented once per world tick that is not hit-stopped; its lifetime is therefore 120 sim frames of play, not wall time.
- **[design call] D-S61-6 Lifecycle.** Cleared on fight start, retry, defeat and fight exit. A phase change (ROAR, 60 frames) keeps it: the epic only says "the phase changes" resets the speed-ramp hook, and the GDD says a phase change gives no damage window, which is about the player, not the decoy.
- **[design call] D-S61-7 Targeting uses only `target_source`.** The arena's closure returns the decoy when live. `contact_source` (the player's body contact, D-S31-21) and `facing_source` stay on the player, so the boss body still collides with the real player and attacks such as Pointer Grab keep their facing rule.
- **[design call] D-S61-8 DECOY_STRUCK is produced by `CombatResolver`, with a point test.** game-architecture NP-4 says `CombatResolver` resolves "boss hits -> player/decoy", so the producer lives there. The overlap test is `boss.attack_hazard_hit(decoy.position_px)`, the same point test that the attacks use for the player (no decoy radius). The strike happens on the attack's ACTIVE frames only (`attack_hazard_hit` is ACTIVE-only), removes the decoy at once, and never damages anything. The player is still hit by the same attack in that tick if the player is inside its hazard.
- **[design call] D-S61-9 The player never interacts with the decoy.** Unlike the Null Pointer decoys (dispelled by any player hit, D-S53-5), the Ghost decoy is intangible to the player's hits and to contact. The GDD says only that the boss strikes it; nothing says the player dispels it. Dispelling it would make "bait a boss" self-defeating.
- **[design call] D-S61-10 Placeholder presentation, always visible.** The decoy is drawn as the two register glyphs of its window (`LN`) in dim ink at its spot, always (no Watch needed). Final look is 7.x. Watch's reveal rules (Story 5.4) are unchanged: Watch never reads the decoy.
- **[design call] D-S61-11 Spawn point is the start point.** `action_origin_px` of the start tick (the player's position on the press tick). Ghost Echo does not move, so the decoy does not follow the player (GDD: "at the start point").

### Architecture and rules that bind this story

- AD-02 / NP-1: the resolver is the only J/K -> action path. L->N is a `ComboTable` entry, not a new branch.
- NP-3 / D-049d: bosses aim only through `ctx.target_position()`, which returns the live decoy or the player. Bosses never mutate the decoy or the player. The decoy is removed by `CombatResolver`, not by the boss.
- NP-4 / D-S32-6 / D-S32-19: `BossInteraction.Kind.DECOY_STRUCK` completes the window (`completes_weak_window`: window match, kind DECOY_STRUCK -> true). `WeakWindowTracker` is the only Patched writer. `DamageCalc` is the only damage producer and is not called for the decoy.
- NP-5 / D-S41-1: combos never enter Echo memory.
- AD-01: all durations are int sim frames; no `delta`.
- Single writers: J/K -> `ActionResolver`; Patched -> `WeakWindowTracker`; damage -> `DamageCalc`; register -> `Register`; decoy state -> `GhostEchoSystem`.
- Defs are read-only at runtime: `ghost_echo.tres` is never mutated.
- Simulation code runs without a scene tree; tests use a test boss and injected combo tables.

### Existing code this story touches (read before editing)

- `game/src/player/action_def.gd`: new `decoy_frames`, its validate check (A1). Existing `is_invulnerable_frame` is reused as is.
- `game/src/player/action_state_machine.gd`: `_start` (combo branch at about line 297-310 already starts the replaced solo's cooldown and returns before `echo.remember`); add `decoy_spawn_serial` only (B1).
- `game/src/player/action_resolver.gd`: `_link` combo branch (rule 2) already returns combo actions; no change expected.
- `game/src/player/player_health.gd`: `apply_hit` uses `_actions.invulnerable()`; Ghost Echo's invulnerable frames are honoured with no change.
- `game/src/combat/combat_resolver.gd`: `tick` (add the decoy strike step; `hits_for` and `boss_overlapped` unchanged), `_resolve_boss_hit` (unchanged), `_check_whiff` (unchanged, D-S61-9).
- `game/src/combat/boss_interaction.gd`: header comment only (DECOY_STRUCK now has a producer).
- `game/src/combat/weak_window_tracker.gd`: `process` used as is.
- `game/src/bosses/framework/boss_controller.gd`: `attack_hazard_hit` (line ~443, public, ACTIVE-only) and `current_weak_window()` are reused as is. `touches_player` is not changed (D-S61-9).
- `game/src/bosses/framework/arena_context.gd`: `target_source` already exists (D-S31-10); the decoy comment says "Ghost Echo (6.1) swaps in the decoy" and is now true.
- `game/src/arena/arena.gd`: `_enter_tree` (register `GhostEchoSystem`), `_make_arena_context` (target closure, line ~294-300), fight start/retry/exit (clear the decoy).
- `game/src/bosses/test_boss/`: the test boss's attacks (`pulse.gd`, `sweep.gd`) are the attacks used in tests (`hazard_hit` set at the decoy point in the test).
- `game/data/combos/combo_table.tres`: add the Ghost Echo combo.
- `game/tests/unit/test_combo_table.gd`: `test_unknown_pairs_are_null` drops `(L, N)`.
- `game/data/actions/null_dodge.tres`: read only (solo cooldown 120, the cooldown Ghost Echo's start will start).
- Known open item from the ArenaContext review (deferred-work.md line ~223): `ArenaContext.player_position()` lets an attack bypass the target abstraction by convention. Do not add it; if a guard is needed, add it in `test_attack_isolation`, not here.

### Previous story intelligence (4.2 Echo Dash, the combo pattern)

- Echo Dash (4.2) is the closest model: a combo `ComboDef` plus an `ActionDef`, added to `combo_table.tres`, with the combo branch of `_start` doing all the work. The 4.2 tests changed `test_combo_table.gd` for the pair that now has a combo (D-S42-7). Do the same for (L, N).
- 4.2 PASS_THROUGH (`BossInteraction.Kind.PASS_THROUGH`) is the nearest existing path for a non-damaging interaction that completes a window; DECOY_STRUCK follows the same tracker call but comes from a decoy rather than from the player's hit shape.
- 4.2 review: the `gap_free` path and dropped presses were reviewed and held. Ghost Echo is not `gap_free` (no gap rule in the GDD for L->N).

### Previous story intelligence (3.2 / 3.4 / 5.3, boss side)

- 3.2: `BossInteraction` (kinds HIT / PASS_THROUGH / DECOY_STRUCK), `completes_weak_window` (D-S32-6), `WeakWindowTracker.process` (D-S32-12), `PATCHED_FRAMES = 180`. DECOY_STRUCK exists only as a stub in tests (D-S32-19); this story gives it its producer.
- 3.4: `attack_hazard_hit` (D-S34-9) is the boss-side hazard test, ACTIVE only. Reuse it for the decoy point test.
- 5.3: decoys in the Null Pointer body are sim data (`Array[Vector2i]`), never nodes; their dispel is a player hit (D-S53-5). The Ghost decoy must not reuse that dispel (D-S61-9).
- 5.4: Watch never reads a decoy getter (AC 11, D-S54-1). The Ghost decoy stays out of Watch's reveal set as well.
- 5.5: Null Dodge's solo cooldown is 120 (`null_dodge.tres`); Ghost Echo's combo start charges that cooldown through the existing combo branch.

### Git intelligence

- Branch `story/6-1-ghost-echo-combo` at `ac51a03` (Devlog #2 record, #43). Last code work: Story 5.6 (`0aff34a`, #42), Story 5.5 (`7240e85`, #41). Story pattern: resolver/FSM pure, tests, small wiring in `Arena`.

### Latest technical information

- Pinned: Godot 4.7.2-stable (do not upgrade), GUT 9.6.1, GDScript only. Godot 4 syntax only (`@export`, typed arrays, `signal` in `EventBus` only). No new APIs needed: `Vector2`, `RefCounted`, static pure functions.

### Project Context Rules (from project-context.md)

- Ghost Echo: L->N combo, intangible 30 frames, leaves a 120-frame decoy; bosses target the decoy (project-context: "Boss attacks aim only via `ctx.target_position()` (player, or a live Ghost Echo decoy); never read the player position directly").
- Retry restores the fight-start state: the decoy is cleared (Group C), register and Echo memory unchanged by this story.
- Only `SimClock` ticks; no `_process`/`delta`/`Timer`/`await` in simulation code.
- Static typing everywhere; `StringName` ids (`&"ghost_echo"`); `*_frames` and `*_tiles` names; `*_def.gd` for defs; files snake_case.
- Logging: `Log.debug(&"action", ...)` / `Log.debug(&"combat", ...)` on start and strike events only; no `print`.
- Simulation folders do not reference `ui`, `presentation`, `AudioManager` or `VoiceService`. The decoy's placeholder drawing lives in presentation and reads only the getter.
- Tests: `tests/unit/test_<subject>.gd` for pure logic; build systems from defs plus an injected `ComboTable`; no scene tree needed.

### Project Structure Notes

- New: `game/data/actions/ghost_echo.tres`, `game/data/combos/ghost_echo.tres`, `game/src/bosses/framework/ghost_decoy.gd`, `game/src/bosses/framework/ghost_echo_system.gd`, `game/tests/unit/test_ghost_echo.gd` (plus `.uid` files created by Godot on first open).
- Modified: `game/src/player/{action_def,action_state_machine}.gd`, `game/src/combat/{combat_resolver,boss_interaction}.gd`, `game/src/arena/arena.gd`, `game/src/bosses/framework/arena_context.gd` (comment only if needed), `game/data/combos/combo_table.tres`, `game/tests/unit/test_combo_table.gd`, the presentation view that draws the decoy.
- No conflict with the architecture tree: Ghost Echo lives in `data/actions` and `data/combos` as the architecture's `ghost_echo` entry lists (game-architecture line 440); the decoy's home is `bosses/framework` (D-S61-3 notes the file name).

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: Ghost Echo 0 damage; intangible frames 1-30; decoy 120 frames; NULL cooldown 120; LOOP cooldown untouched.
- Guards in CI: `bash game/tools/check_guards.sh` (no `Timer.new`/`await` under sim folders, no bare `print(` in `src/`).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1: Ghost Echo Combo] (ACs, FR18, FR21 decoy struck)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2: Dereference Combo] (out of scope; the Dereference window uses Null Dodge's active frames)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1 AC, lines ~800-815] (`ctx.target_position()`, Ghost Echo decoy as the injected target)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] combos table (L->N row, line ~195), Weak Window and Patched ("the boss strikes the Ghost Echo decoy", line ~206), Targeting (D-049, line ~339), Ghost Echo on Boss 3 (line ~421)
- [Source: _bmad-output/game-architecture.md#AD-02 Actions & Combos], [#NP-1], [#NP-3 Boss -> Player State Mutation, line ~679], [#NP-4 Weak Window -> Patched, line ~710-720], [#NP-5 Echo Memory]
- [Source: _bmad-output/implementation-artifacts/4-2-echo-dash-combo.md] D-S42-1, D-S42-5, D-S42-7 (the combo pattern)
- [Source: _bmad-output/implementation-artifacts/5-5-null-bit-null-dodge-and-clean-catch.md] D-S55-4 (Clean Catch, Null Dodge cooldown)
- [Source: _bmad-output/implementation-artifacts/3-2-weak-window-patched-and-damage-states.md] D-S32-6, D-S32-12, D-S32-19
- [Source: _bmad-output/implementation-artifacts/3-4-head-rush-and-constrict.md] D-S34-9 (`attack_hazard_hit`); the code is in `game/src/bosses/framework/boss_controller.gd`
- [Source: _bmad-output/implementation-artifacts/5-3-dangling-pointers-and-nullpointerexception.md] D-S53-5 (decoy dispel by player hits; not applied to Ghost decoys)
- [Source: _bmad-output/implementation-artifacts/5-4-watch-skill.md] D-S54-1, AC 11 (Watch never reads decoy getters)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] ArenaContext.player_position note (line ~223)
- [Source: _bmad-output/project-context.md] "Boss attacks aim only via ctx.target_position()" rule

## Design calls

- D-S61-1 to D-S61-11: see Dev Notes above (IDs are the source of truth; each is referenced in the Tasks and ACs).

## Open questions (not blocking)

- D-S61-1: GDD says Ghost Echo "exists in Boss 3", but the table ships it globally (as Echo Dash does for Boss 2-3). Gate it when Boss 3 lands (6.3), or leave it global? Confirm with Tiziano.
- D-S61-4: one live decoy vs a cap of 2. Playtest in 7.8 (a one-constant change).
- D-S61-10: the placeholder glyph pair `LN` is a stand-in; final look in 7.x.
- Ghost decoy point test (D-S61-8): if an attack's hazard is thin (a line), a point test at the decoy centre may miss; a decoy radius is the fallback if playtests show it.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended pipeline run.

### Debug Log References

- First run of `test_ghost_echo.gd`: 2 failures in the test only (the echoed Dash moves the player 4 tiles before the combo starts, so the start point is not SPAWN); assertions changed to the start tick's `action_origin_px`. No code change.

### Completion Notes List

- Coordinator decisions applied: Ghost Echo ships globally (D-S61-1, no Boss 3 gating), one live decoy (D-S61-4), point test for the strike (D-S61-8). All other D-S61 calls followed as written.
- Data: `ActionDef.decoy_frames` (validated >= 0), `ghost_echo.tres` (0/30/8, invuln 1-30, no shape, `hitstop_frames = 0`, `decoy_frames = 120`), L->N `ComboDef`, added to `combo_table.tres`; `Defs.GHOST_ECHO` added for tests and lookups.
- FSM: `_start` publishes `decoy_spawn_serial` + `decoy_origin_px` / `decoy_window` / `decoy_frames` for any action with `decoy_frames > 0`. The combo branch (NULL cooldown, no Echo memory) is unchanged.
- `GhostDecoy` is a single reused RefCounted object (spawn / tick / clear / is_live), so the Arena can inject the same instance into `CombatResolver.ghost` and the aim closure. `GhostEchoSystem` (BOSS_HAZARDS, registered before any boss) ticks the decoy and turns a serial change into a (re)spawn; hit-stop and Breakpoint freeze it because SimClock does not tick systems then. `clear()` also skips a spawn published before the clear.
- Arena: `aim_point()` = live decoy or player, used by `target_source`; contact and facing unchanged. Cleared in `enter_fight` (start, retry) and `leave_fight` (death, harvest after defeat, any exit).
- CombatResolver: `_strike_ghost()` runs first every tick (independent of the player's action state): boss ACTIVE + `attack_hazard_hit(decoy)` -> DECOY_STRUCK -> tracker -> Patched + `patched_applied` on match; decoy cleared either way; no damage, no `hit_landed`, no hit-stop. Player hits, the Null Pointer decoy dispel and the whiff rule never read it.
- Small addition [design call, D-S61-6 detail]: the resolver also clears the decoy as soon as the boss is DEFEATED (defeat clear happens on the defeat tick, not only when FIGHT is left).
- Presentation [design call, D-S61-10 detail]: `GhostDecoyView` draws the window glyphs (`LN`) at 1x in INK, centred on the spot, always visible. "Dim ink" is rendered as the smaller 1x size, because the palette is INK/BG only (no alpha). Attached by Main under the PlayerView; Watch never reads it.
- Tests: `test_ghost_echo.gd` (23 tests, AC 1-8 plus the label); `test_combo_table.gd` drops (L, N). Full GUT suite 1356/1356 passing headless (replays and Infinite Loop replay unchanged); `check_guards.sh` OK.

### File List

- game/data/actions/ghost_echo.tres (new)
- game/data/combos/ghost_echo.tres (new)
- game/data/combos/combo_table.tres
- game/src/core/defs.gd
- game/src/player/action_def.gd
- game/src/player/action_state_machine.gd
- game/src/bosses/framework/ghost_decoy.gd (new, + .uid)
- game/src/bosses/framework/ghost_echo_system.gd (new, + .uid)
- game/src/bosses/framework/arena_context.gd (comment)
- game/src/combat/combat_resolver.gd
- game/src/combat/boss_interaction.gd (comment)
- game/src/arena/arena.gd
- game/src/main/main.gd
- game/src/presentation/ghost_decoy_view.gd (new, + .uid)
- game/tests/unit/test_ghost_echo.gd (new, + .uid)
- game/tests/unit/test_combo_table.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-12: Story 6.1 implemented (Ghost Echo L->N combo, Ghost decoy, decoy targeting, DECOY_STRUCK producer, placeholder view, tests). Status -> review.

## Story Completion Status

Status: done. All tasks complete; full suite and guards green.
