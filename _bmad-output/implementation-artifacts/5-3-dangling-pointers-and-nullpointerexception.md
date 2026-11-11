---
baseline_commit: 667419d
---

# Story 5.3: Dangling Pointers and NullPointerException

Status: done
<!-- Created unattended by gds-create-story (pipeline, 2026-11-11). Self-made design calls are marked [design call] with IDs D-S53-n; the implementer follows them or records a change in Completion Notes. Scope: the third Null Pointer attack (Dangling Pointers, phase 2 only) with its decoy ghosts (instanced sim objects, cap 3, re-cast every 15 s), the decoy dispel by a player hit, and the NullPointerException whiff stun for ATTACK slashes that hit nothing with the boss within 4 tiles. NOT in scope: Watch input and reveal (5.4; 5.3 only makes sure decoys stay out of the reveal), the NULL bit and Null Dodge / Clean Catch (5.5), the Null Pointer tutorial lines (5.6), Segfault (Epic 6). -->

## Story

As a player,
I want decoy ghosts and a penalty for blind swings,
so that I must locate the real pointer before attacking.

**Requirements:** FR38 (NullPointerException whiff stun), FR39 (Null Pointer phases and attacks: Dangling Pointers). Additional: GDD "Boss 2 — Null Pointer" attack table, decoy bullets, whiff penalty; GDD Watch row (decoys never shown in Watch); architecture AD-06 (`BossAttack` per attack, timings in `AttackDef.tres`), AD-05 (presentation reads only); project-context rules (tell >= 20 frames and non-empty `tell_sfx`; attacks aim only via `ctx.target_position()`; no RNG in attack scripts; no untelegraphed damage).

## Acceptance Criteria

**Dangling Pointers (phase 2)**

1. **Given** phase 2 and Dangling Pointers is chosen, **When** its TELL runs, **Then** it lasts 30 frames and two `null` flickers mark the two decoy spots (presentation, D-S53-9); no decoy exists yet and nothing hurts the player.
2. **And** ACTIVE lasts 60 frames (D-S53-1): on ACTIVE entry the two planned decoys spawn, and the 15-second re-cast timer is armed (AC 6).
3. **And** RECOVERY lasts 30 frames, and the ghost is visible for all of them (Story 5.1 visibility rule). Dangling Pointers deals no damage: it has no hazard of its own (`hazard_hit` is false everywhere).
4. **And** `attack_dangling_pointers.tres` has `id = &"dangling_pointers"`, `tell = 30`, `active = 60`, `recovery = 30`, `tell_sfx = &"tell_dangling_pointers"`, `recovery_if_no_breakpoint = 0`, and `AttackDef.validate()` passes.
5. **And** phase 2's `attack_pool` is `[pointer_grab, null_rain, dangling_pointers]`; phase 1's pool stays `[pointer_grab, null_rain]` (D-S53-10). The Story 5.1 values (HP 700, windows, gaps, drop) are unchanged.

**Decoys**

6. **Given** decoys are live, **When** the 15-second timer (900 live ticks, D-S53-1) runs out in phase 2 and the boss is alive, **Then** two new decoy spots are flickered for 30 frames (the same tell as AC 1) and then spawned, if the cap allows (AC 7). The timer re-arms to 900 ticks after each re-cast.
7. **And** at most 3 decoys are alive at once (D-S53-4). A cast that would exceed the cap spawns only the room left; with no room the cast does nothing. Decoys are sim objects owned by `NullPointerBody` (not scene nodes), positions in integer milli-tiles.
8. **And** decoy spots are drawn from `SimContext.rng` on the first TELL tick of Dangling Pointers (not by the attack script): each spot lies inside the play area inset by 2 tiles from every wall, at least 4 tiles from the real body centre and from each other and from every live decoy; up to 32 tries, fewer spots if none fit (D-S53-2). The same seed gives the same spots.
9. **And** decoys never hum (the hum belongs to the real body only, Story 5.1), are never drawn as ghosts (no body, no column), and are invisible except for the 30-frame flicker when they are cast and the 10-frame dispel flash (AC 11). Story 5.4 must not reveal them in Watch (its AC carries this).
10. **And** a decoy is dispelled by a player hit: any non-pass-through action whose hit shape overlaps the decoy (radius 1 tile, the same overlap test as the boss hurtbox) removes it (D-S53-5). Every overlapped decoy is dispelled once per action (serial). A dispel deals no damage, applies no Patched, does not count as a boss hit, and is a hit for the whiff rule (AC 13).
11. **And** a dispelled decoy shows a 10-frame flash at its spot (presentation reads a sim-owned timer), and the dispel requests the hit-stop `HitFeedback.hitstop_for(is_combo, def.hitstop_frames)`.
12. **And** on phase change (ROAR), defeat and retry, all decoys, flickers, flashes and the re-cast timer are cleared (D-S53-7). Dangling Pointers' own `on_cancel` clears its planned spots.

**NullPointerException whiff stun**

13. **Given** an ATTACK slash (`Defs.SLASH_1`, `SLASH_2` or `SLASH_3`, solo or as a chain hit, not run as an Echo, D-S53-11) reaches its last ACTIVE frame, **When** it has landed no hit in that action (no boss hit, no decoy dispel, no practice target hit), **And** the real boss's body centre is within 4 tiles (4000 milli-tiles, measured centre to centre at that tick), **Then** the player enters STUNNED for 20 frames and the HUD log shows `NullPointerException` (D-S53-6). **Exception (D-S53-12, confirmed [design call]):** a slash whose combo link already holds the K follow-up (e.g. the J that opens the A->D Dash Strike) never triggers the whiff stun, which preserves Story 5.2's phase-2 Patch route.
14. **And** a slash that misses while the boss is farther than 4 tiles does not stun; a slash that lands (boss, decoy or practice target) does not stun; a non-slash action (dash, Echo Dash, Breakpoint, Echo itself) never stuns.
15. **And** during the 20 STUNNED frames the player cannot move or start actions; buffered presses are discarded, not kept (D-S53-6); the running action, its chain and its link are cancelled when the stun starts. Breakpoint (a skill, not an action) and Watch stay usable.
16. **And** the stun is sim state in `ActionStateMachine` (its only writer of action state), requested by `CombatResolver` at the whiff tick. Presentation only reads it.
17. **And** the whiff range is a `BossController` virtual (`whiff_stun_range_px()`, default 0 = no stun) that `NullPointerBody` overrides to 4 tiles. Infinite Loop and the test boss keep their current behaviour (no stun).

**Determinism, isolation and telegraph**

18. `dangling_pointers.gd` draws no RNG, reads no `Arena.`, `Player`, `Register`, `PlayerHealth`, `SimClock` or `body_contact_position` members (`test_attack_isolation` covers it automatically). Its declared positions (the planned spots) lie inside the play area against an aim at each corner (`declared_positions`, Pillar 2).
19. Every decoy's and every flicker's position stays inside the play area for a 900-tick seeded run (AC 8 inset holds after each re-cast).

**Tests**

20. Unit tests in `game/tests/unit/test_dangling_pointers.gd` cover AC 1–5, 8 (spot rule and determinism), 18, 19 (decoy count, re-cast timing and cap, dispel rules, clears on ROAR / defeat / retry).
21. Unit tests in `game/tests/unit/test_whiff_stun.gd` cover AC 13–17 through a real `CombatResolver` and `ActionStateMachine` (miss within 4 tiles stuns for 20 frames, miss at 4 tiles + 1 px does not, a landed hit does not, a decoy dispel does not, a dash does not, an Echo slash does not, buffered input is discarded, Infinite Loop boss never stuns).
22. `game/tests/unit/test_data_validation.gd` covers AC 4–5 (defs, pools).
23. `game/tests/integration/test_null_pointer_fight.gd` runs phase 2 from a fixed seed with Dangling Pointers at least once, with no `Log.error` (AC 2, 6, 10 through the real flow).
24. Existing suites (`test_boss_controller`, `test_data_validation`, `test_combat_resolver`, `test_attack_isolation`, `test_null_pointer_body`, `test_null_pointer_attacks`, `test_duck_hint`, `test_action_fsm`) stay green. Full GUT suite and `check_guards` pass.

## Tasks / Subtasks

- [x] Task 1: Dangling Pointers data (AC: 4, 5, 22)
  - [x] 1.1 Create `game/data/bosses/null_pointer/attack_dangling_pointers.tres` mirroring `attack_pointer_grab.tres`.
  - [x] 1.2 Add it to phase 2's `attack_pool` in `null_pointer/boss_def.tres` only.
  - [x] 1.3 Extend `test_data_validation.gd` (defs and both pools).
- [x] Task 2: Decoy state in the body (AC: 6–12, 19; D-S53-2..4, D-S53-7)
  - [x] 2.1 `null_pointer_body.gd`: decoy list (integer milli-tile positions, cap `DECOY_CAP = 3`), planned spots, flicker and dispel-flash timers, re-cast timer `RECAST_TICKS = 900`. All counted in `_tick_body`, all cleared by `reset_for_fight`, `_on_phase_reset` and `_on_defeated`.
  - [x] 2.2 Spot planning from `ctx.rng` on the first TELL tick of Dangling Pointers (detected in `_tick_body` by state, not by the attack script); the spot rule of AC 8.
  - [x] 2.3 `plan_decoys()`, `spawn_planned()` (ACTIVE entry), the re-cast cycle (flicker, then spawn, re-arm).
  - [x] 2.4 `decoy_hit(shape, origin, facing) -> int` (dispelled count): the overlap test through the same geometry as `BossController.overlaps_shape`; the boss base gets a no-op default returning 0.
- [x] Task 3: The attack script (AC: 1–3, 12, 18)
  - [x] 3.1 `game/src/bosses/null_pointer/attacks/dangling_pointers.gd` (`extends BossAttack`): `on_tell` asks the body to plan (no RNG here), `tell_marks()` = planned spots, `tell_glyph()` = `"n"` (presentation draws a flicker, D-S53-9), `on_active` spawns the planned decoys, `declared_positions` = the spots, `on_cancel` / `reset` clear the planned spots, `hazard_hit` stays false.
- [x] Task 4: Dispel and whiff in the sim (AC: 10, 13–17; D-S53-5, D-S53-6, D-S53-11)
  - [x] 4.1 `boss_controller.gd`: two no-op virtuals, `decoy_hit(shape, origin, facing) -> int` (default 0) and `whiff_stun_range_px() -> float` (default 0.0).
  - [x] 4.2 `combat_resolver.gd`: a non-pass-through action first asks `boss.decoy_hit(...)`; a dispel counts as a landed hit for the serial, adds hit-stop, no damage. Track the serial of the last landed hit (`_landed_serial`). On the action's last ACTIVE frame (`action_frame == startup_frames + active_frames`), with no landed hit for `serial`, and the action is a solo or chain slash that is not echoing (Defs.SLASH_1..3 identity), and `boss.whiff_stun_range_px() > 0` and the boss centre within that range: call `actions.begin_stun(20)`. Keep the early return path correct when there is no hit at all.
  - [x] 4.3 `action_state_machine.gd`: `begin_stun(frames)` (cancels the running action with the `_finish` rules, clears chain and link, sets `stun_left`); `tick` checks `stun_left` before input (drain the buffer, no request), keeps `state = STUNNED`, locks the Player with zero velocity; the frame it reaches 0 returns to IDLE_MOVE. The stun is emitted once through `EventBus.player_stunned(&"NullPointerException")` (new signal, Story 5.3 note in `event_bus.gd`).
  - [x] 4.4 `null_pointer_body.gd`: `whiff_stun_range_px()` returns 4 tiles in px; `decoy_hit` as in Task 2.
  - [x] 4.5 Log panel: the `player_stunned` signal appends `NullPointerException` (find the existing LogPanel subscriber; do not add a second writer).
- [x] Task 5: Presentation (AC: 1, 6, 9, 11; AD-05)
  - [x] 5.1 `boss_view.gd`: draw the decoy flicker (cast and re-cast) and the dispel flash from the body's sim getters; draw the Dangling tell marks as a `null` flicker (4-frame on/off), not `!`. Decoys have no other drawing. The ghost, column and hum are unchanged.
  - [x] 5.2 The STUNNED state needs no new presentation beyond the log line; the player's sprite may keep its idle pose.
- [x] Task 6: Tests (AC: 20–24)
  - [x] 6.1 `test_dangling_pointers.gd` (AC 1–5, 8, 18, 19, 20).
  - [x] 6.2 `test_whiff_stun.gd` (AC 13–17, 21).
  - [x] 6.3 Extend `test_null_pointer_fight.gd` for phase 2 with Dangling Pointers (AC 23).
  - [x] 6.4 Full GUT suite headless, `check_guards`, no new `Log.error`.

## Dev Notes

### Design context (what 5.3 must respect)

- The framework (`BossController`, Story 3.1) owns the FSM, pools, Patched and phases. Attacks implement hooks only. Do not duplicate the FSM. Dangling Pointers is an ordinary `AttackDef` with an attack script.
- Attack scripts cannot draw RNG and cannot read the player (`test_attack_isolation`, Story 3.4 guard). Anything random (decoy spots, the re-cast) lives in `NullPointerBody`, which receives `SimContext` in `_tick_body(ctx)`. The attack only asks the body to plan or spawn.
- Decoys are sim state. They never become scene nodes, so the sim stays deterministic and presentation only reads getters (AD-05).
- A decoy dispel is a player hit that is not a boss hit. It goes through `CombatResolver` in the COMBAT phase (after ACTIONS), like practice targets, and never through `touches_player`.
- Whiff: the rule needs three facts at the same tick: the action frame (ASM), the landed-hit record (resolver), the boss position (resolver has `boss`). Both the stun request and the hit record live in `CombatResolver` and `ActionStateMachine` only; no presentation writes.
- `ActionStateMachine.tick` runs before `CombatResolver.tick` in the same frame. A stun requested at the whiff tick therefore takes effect on the next tick (the first STUNNED frame), which is why AC 13 counts 20 frames from the tick after the whiff.
- `ArenaContext` has no player read for attacks. The whiff reads the player through the ASM (`action_origin_px`) or the resolver's `actions` / `player`, as the existing hit path does.

### Dangling Pointers state at 5.2 (for orientation)

- `NullPointerBody` (`game/src/bosses/null_pointer/null_pointer_body.gd`): drift in every live state except ACTIVE and RECOVERY (D-S51-7); `visible_now()` per the 5.1 rule; `on_player_hit` / `on_pass_through`; `touches_player` = `attack_hazard_hit(p)`; `trail_positions()` for the column.
- Attacks: `pointer_grab.gd` and `null_rain.gd` (`game/src/bosses/null_pointer/attacks/`); `BossAttack.hazard_rects()` and `tell_glyph()` exist (Story 5.2 D-S52-5).
- Phase pools: both phases `[pointer_grab, null_rain]` (D-S52-6). 5.3 adds Dangling to phase 2 only.
- Hooks already in `BossController`: `_on_phase_reset`, `_on_defeated`, `_on_attack_started`, `_on_attack_cancelled`, `_attacks_allowed`.

### Files to touch

- New: `game/data/bosses/null_pointer/attack_dangling_pointers.tres`, `game/src/bosses/null_pointer/attacks/dangling_pointers.gd` (+ `.uid`), `game/tests/unit/test_dangling_pointers.gd` (+ `.uid`), `game/tests/unit/test_whiff_stun.gd` (+ `.uid`).
- Edit: `game/data/bosses/null_pointer/boss_def.tres` (phase 2 pool), `game/src/bosses/null_pointer/null_pointer_body.gd` (decoys, planning, dispel, re-cast, whiff range), `game/src/bosses/framework/boss_controller.gd` (two no-op virtuals only), `game/src/combat/combat_resolver.gd` (dispel, landed serial, whiff request), `game/src/player/action_state_machine.gd` (`begin_stun`, STUNNED tick), `game/src/autoloads/event_bus.gd` (`player_stunned` signal), the LogPanel subscriber (find it; `game/src/ui/hud/log_panel.gd` is the panel), `game/src/presentation/boss_view.gd` (decoy and tell drawing), `game/tests/unit/test_data_validation.gd`, `game/tests/integration/test_null_pointer_fight.gd`.
- Do not edit: `src/bosses/infinite_loop/`, `src/bosses/segfault/` (Epic 6), `data/bits/` (5.5), `src/skills/watch/` (5.4), `data/actions/slash_*.tres` (the slashes are identified by `Defs`, not edited).

### Testing standards

GUT tests in `game/tests/unit/` and `game/tests/integration/`. Fixed seeds through `SimContext`. Ticks through `SimClock` or direct `tick` calls, never wall time. Test names `test_<subject>.gd`. Each new `.gd` gets its `.uid` from the editor.

### Previous story intelligence

- Story 5.1 (done): the body is the only writer of its reveal timers; `on_player_hit` and `on_pass_through` route from CombatResolver; reveal hooks are guarded by `_reveal_allowed()`; the falling column flips above the body near the bottom edge. Keep both.
- Story 5.2 (done): `test_attack_isolation` scans every `src/bosses/*/attacks/*.gd`. The grab reads `ctx.target_facing()` through the additive `ArenaContext.facing_source`. Dangling Pointers reads neither.
- Story 3.4 (done): hazards go through `hazard_hit` with the real player position; `on_cancel` on phase change. Follow the Constrict pattern.
- Story 4.2 (done): Echo Dash is a `pass_through` action (no damage, no whiff). A dash is never a slash, so it never stuns.
- Story 4.1 (done): an Echo replays the remembered def with `echoing = true`; `ActionStateMachine.echoing` is the flag used for D-S53-11.
- Story 4.3 (done): `effective_recovery`; `recovery_if_no_breakpoint = 0` keeps the recovery the same with or without Breakpoint.
- deferred-work.md (5.2 and 5.1 items) that 5.3 touches: "Null Rain areas clamp near walls" (not 5.3); "`invuln_frames` 0 could let attacks queue a hit per tick" (not 5.3); "AC 13 covers `declared_positions` only" (5.3 adds the spot check). Do not widen scope to them.

### Latest technical information

No new library or version: GDScript 2.0 on Godot 4.7 with the existing framework. No web research was needed.

## Project Context Rules

- Read-only defs at runtime; mutable state in sim objects (architecture, Story 2.5). Decoys and the stun are sim state.
- Integer sim state; floats for presentation only (D-S33-2). Decoy positions in milli-tiles.
- Presentation may not write sim state; `arena/` may not reference `presentation/`.
- Attack scripts: no RNG, no player read, aim only through `ctx.target_position()`.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

## Design calls

- **D-S53-1 (Dangling Pointers timing):** the GDD gives the tell (30) and recovery (30) but not the active length. Active is 60 frames: two decoys spawn at ACTIVE entry, and a 15-second re-cast timer (900 live ticks) arms then. The GDD cell "re-cast every 15 s" is read as a body cycle that runs while the boss is alive in phase 2, not as an attack-length rule. Tune in the playtest.
- **D-S53-2 (decoy spots):** drawn from `SimContext.rng` in the body on the first TELL tick. Inset 2 tiles from walls, 4 tiles from the real body centre and from each other and from live decoys, 32 tries; fewer spots if none fit. The spot rule is never based on the player position (attacks cannot read it).
- **D-S53-3 (instanced decoys):** "instanced" is read as created per cast, as sim objects owned by the body (RefCounted or plain data). No scene nodes, no pooling. Decoys carry no hurtbox of their own; the body tests them in `decoy_hit` with radius 1 tile.
- **D-S53-4 (cap and re-cast):** at most 3 alive. A re-cast (every 900 live ticks in phase 2) flickers 2 new spots for 30 frames, then spawns as many as the room allows (0 room = no flicker at all). The timer runs in every live state, including GAP, TELL, ACTIVE and RECOVERY, and pauses in ROAR and DEFEATED.
- **D-S53-5 (dispel):** any non-pass-through player action whose hit shape overlaps a decoy dispels it (once per action per decoy). Dispel deals no damage, applies no Patched, is not a boss hit, and gives hit-stop `HitFeedback.hitstop_for(is_combo, def.hitstop_frames)`. Any player action with a hit shape dispels, not only slashes (Dash Strike included).
- **D-S53-6 (whiff stun):** the rule of GDD "Boss 2" (ATTACK slash that hits nothing, boss within 4 tiles): checked once, at the slash's last ACTIVE frame, measured centre to centre. The stun is 20 STUNNED frames starting on the tick after the whiff, cancels the running action, chain and link, locks movement and actions, and discards buffered presses. Breakpoint and Watch are unaffected. The log line `NullPointerException` comes from `EventBus.player_stunned`.
- **D-S53-7 (clears):** phase change (ROAR), defeat and retry clear decoys, flickers, flashes and the timer, and a phase change cancels a planned Dangling Pointers through the framework's `on_cancel`.
- **D-S53-8 (boss hit and dispel in one action):** both may happen in the same action; the boss hit follows the 5.1 and 5.2 rules, the dispel is separate.
- **D-S53-9 (tell look):** Dangling's tell marks draw as a `null` flicker (4-frame on, 4-frame off), not `!`. Decoys have no drawing except the flicker, the dispel flash (10 frames) and nothing else.
- **D-S53-10 (pools):** phase 2 = `[pointer_grab, null_rain, dangling_pointers]` with the framework's uniform draw; phase 1 is unchanged, as the GDD table gives Dangling phase 2 only.
- **D-S53-11 (echoes):** an Echo that replays a slash does not stun (it would punish the LOOP player for the Echo's timing). Only a slash the player started stuns. Echo of a whiffed slash still executes (GDD).

## Open questions (not blocking)

- D-S53-1: the 60-frame active length and the 15-second re-cast cadence are untested against the real fight pace; check the phase-2 length in the playtest (Story 7.8).
- D-S53-6: is 4 tiles measured centre to centre (chosen) or edge to edge? The GDD says "within 4 tiles" without saying which.
- Story 5.4 must keep decoys out of the Watch reveal (GDD: only the real ghost shows in Watch). This story only guarantees decoys are never drawn as ghosts.

## References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.3: Dangling Pointers and NullPointerException]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 2 — Null Pointer]
- [Source: _bmad-output/game-architecture.md#AD-05 (presentation reads only), AD-06 (boss framework)]
- [Source: _bmad-output/implementation-artifacts/5-1-null-pointer-body-and-locating-cues.md] (body, reveal hooks, visibility, D-S51-7 / D-S51-8)
- [Source: _bmad-output/implementation-artifacts/5-2-pointer-grab-and-null-rain.md] (attack pattern, hazard gate, D-S52-5 / D-S52-6)
- [Source: _bmad-output/implementation-artifacts/3-4-head-rush-and-constrict.md] (hazard_hit pattern, declared_positions, on_cancel)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-5.2 (2026-11-11)]

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (gds-create-story, unattended); implementation: claude-opus-5-5 (gds-dev-story, unattended)

### Debug Log References

- First full run after Tasks 1-5: `test_null_pointer_fight::test_dash_strike_on_the_visible_recovery_patches_phase_2` failed. The J slash that opens the A->D Dash Strike from exactly 4 tiles whiffed on its last ACTIVE frame and stunned the player before the held K could start the combo (log: `link holds K` then `whiff slash_1: NullPointerException`). Fixed by D-S53-12 below.
- Final gates (same commands as CI): headless `--import` clean (no SCRIPT ERROR / Parse Error); GUT 1194/1194 passing, 63355 asserts, "All tests passed!"; `check_guards.sh` OK. The headless "Shader compilation failed" line in the fight test predates this story and is not a CI failure marker.

### Completion Notes List

- Story created (ready-for-dev) by gds-create-story, unattended. Design calls D-S53-1 to D-S53-11 are recorded above; the implementer may change them and must note changes here.
- No new library or version is introduced: the work is GDScript on the existing framework, so no web research was run for this story.
- Implemented (gds-dev-story, unattended). Open questions D-S53-1 (60-frame active, 900-tick re-cast) and D-S53-6 (4 tiles centre to centre) kept as written, as tunable constants in `NullPointerBody` (`RECAST_TICKS`, `CAST_FLICKER_FRAMES`, `DECOY_CAP`, `DECOYS_PER_CAST`, `SPOT_*`, `DISPEL_FLASH_FRAMES`, `WHIFF_RANGE_TILES`) and `CombatResolver.NPE_STUN_FRAMES`; the active length lives in the `.tres`.
- Dangling Pointers: `attack_dangling_pointers.tres` (30/60/30, `tell_dangling_pointers`) in phase 2's pool only. The attack script only asks the body: `on_tell` -> `request_decoy_plan()`, `on_active` -> `spawn_planned()` (first ACTIVE tick only), `on_cancel`/`reset` -> `clear_planned()`; `tell_marks()` = the body's planned spots during its TELL, `tell_glyph()` = `"null"`. No RNG, no player read (isolation guard green).
- Decoys: integer milli-tile sim data in `NullPointerBody` (`decoys`, `planned`, `recast_spots`, flash spots/timers, `recast_left`), ticked in `_tick_body` before the drift, paused in ROAR, cleared by `reset_for_fight`, `_on_phase_reset`, `_on_defeated`. Spots drawn from `ctx.rng` on the first TELL tick (AC 8 rule, 32 tries per spot). `decoy_hit()` uses `HitShape.overlaps` with a 1-tile radius.
- For Story 5.4: decoys are not part of `visible_now()`, `body_center_px` or `trail_positions()`; Watch only flips `watch_held`, which reveals the real body only. The only decoy getters are `decoy_positions()` (tests), `planned_positions()`, `recast_flicker_positions()`, `dispel_flash_positions()`; 5.4 must simply not read them.
- CombatResolver: decoys are tested before the boss hit (D-S53-8: a phase-ending boss hit cannot clear them under the same hit); a dispel sets `_landed_serial`, adds `HitFeedback.hitstop_for` and emits no `hit_landed`. The whiff check runs on the slash's last ACTIVE frame, also on the no-hit early-return path.
- ActionStateMachine: `begin_stun(frames, reason)` (cancel via `_finish`, `link.close()`, lock, emit `EventBus.player_stunned` once); `_tick_stun` consumes and drops live J/K presses, keeps STUNNED and the lock for all 20 ticks; tick 21 runs the normal path. LogPanel prints the reason.
- BossView: the Dangling tell and the re-cast spots draw as a `null` flicker (4 on / 4 off from `SimClock.sim_frame`), dispels as an inverted `null` cell for the body's 10-frame timer; live decoys are never drawn.
- [design call] D-S53-12 (new): a slash whose combo link already holds the K follow-up (`actions.link.held`) never stuns. Without it, the phase-2 Patch route (A->D Dash Strike, Story 5.2) is impossible from 1.5 to 4 tiles, because the opening slash whiffs and the stun cancels the combo before it starts.
- [design call] D-S53-13 (new): no stun while the boss is not hittable (ROAR, DEFEATED, inactive): `_check_whiff` requires `boss.is_hittable()`.
- [design call] D-S53-14 (new): the stun discards only J/K presses. Register shifts (`<<`/`>>`) stay usable during the stun, like Breakpoint and Watch, because they are not actions. A stun does not stack or extend while one runs.
- [design call] D-S53-15 (new): the whiff distance uses the player's current centre (`CombatResolver.player`, or the action origin when there is none). A slash never moves, so both are the same.
- [design call] D-S53-16 (new): a cast reserves room when it is planned (decoys + pending spots) and checks the cap again at spawn. The re-cast timer re-arms at every expiry, including when 0 room makes the cast do nothing, and every Dangling ACTIVE re-arms it to 900.
- [design call] D-S53-17 (new): Dangling's `declared_positions` = the planned spots plus the corners of the 2-tile inset rectangle that bounds every possible spot, since spots do not depend on the aim.
- Tests: new `test_dangling_pointers.gd` (18 tests), `test_whiff_stun.gd` (16 tests); `test_data_validation.gd` (defs, both pools) and `test_null_pointer_fight.gd` (phase 2 accepts 3 attacks; a real cast plus re-cast run; a real slash dispels a decoy with no stun) extended.

### File List

- game/data/bosses/null_pointer/attack_dangling_pointers.tres (new)
- game/data/bosses/null_pointer/boss_def.tres
- game/src/bosses/null_pointer/attacks/dangling_pointers.gd (new)
- game/src/bosses/null_pointer/attacks/dangling_pointers.gd.uid (new)
- game/src/bosses/null_pointer/null_pointer_body.gd
- game/src/bosses/framework/boss_controller.gd
- game/src/combat/combat_resolver.gd
- game/src/player/action_state_machine.gd
- game/src/autoloads/event_bus.gd
- game/src/ui/hud/log_panel.gd
- game/src/presentation/boss_view.gd
- game/tests/unit/test_dangling_pointers.gd (new)
- game/tests/unit/test_dangling_pointers.gd.uid (new)
- game/tests/unit/test_whiff_stun.gd (new)
- game/tests/unit/test_whiff_stun.gd.uid (new)
- game/tests/unit/test_data_validation.gd
- game/tests/integration/test_null_pointer_fight.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/5-3-dangling-pointers-and-nullpointerexception.md

## Change Log

- 2026-11-11: Story 5.3 created (ready-for-dev) by gds-create-story, unattended.
- 2026-11-11: Implemented Dangling Pointers (phase 2), body-owned decoys (plan, spawn, re-cast, cap, dispel, clears) and the NullPointerException whiff stun (CombatResolver -> ActionStateMachine.begin_stun, EventBus.player_stunned, LogPanel). Added design calls D-S53-12 to D-S53-17. GUT 1194/1194, check_guards OK. Status -> review.

### Review Findings

Code review 2026-11-11 (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel; coordinator decisions D-S53-12 amended into AC 13 and baseline_commit set to 667419d). Outcome: 0 decision_needed, 2 patch, 6 defer, ~27 dismissed.

- [x] [Review][Patch] Roar test was vacuous (never proved the slash started) [game/tests/unit/test_whiff_stun.gd]
- [x] [Review][Patch] Dead `casts` counter in the 2000-tick seeded run [game/tests/unit/test_dangling_pointers.gd]
- [x] [Review][Defer] Dispel flash is wiped when the same hit crosses a phase or kills the boss (D-S53-7 clears flashes; cosmetic) [null_pointer_body.gd:clear_decoys] — deferred, spec-conformant
- [x] [Review][Defer] No test for a chain slash (SLASH_2/3) whiffing; covered in code by `is_attack_slash` only [test_whiff_stun.gd] — deferred
- [x] [Review][Defer] Tell marks are empty for the first TELL frame (plan happens on the next tick) [null_pointer_body.gd:request_decoy_plan] — deferred
- [x] [Review][Defer] Presses on the last stunned tick are drained (stun feels 21 frames of input) [action_state_machine.gd:_tick_stun] — deferred, documented in AC 15 reading
- [x] [Review][Defer] Whiff range uses player centre at the last ACTIVE frame while the hit shape uses the action origin [combat_resolver.gd:_check_whiff] — deferred, slashes lock movement
- [x] [Review][Defer] Spots are spaced from the body at plan time; the body can drift closer before spawn [null_pointer_body.gd] — deferred, tune in playtest
