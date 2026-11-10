---
baseline_commit: 295034f
---

# Story 3.4: Head Rush and Constrict

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S34-n); the implementer follows them or records a change in Completion Notes. Scope is ordered into task groups A-H; ship groups in order and stop at a green build after each group if time runs short. -->

## Story

As a player,
I want the loop to lunge and squeeze in telegraphed ways,
so that I read its tells and punish the open semicolon.

**Requirements:** FR35 (Head Rush, Constrict; `;` Spit is 3.5); GDD "Boss 1 — Infinite Loop" attack table (Head Rush phases 1-3: tell 30, active 40, recovery 45; Constrict phases 2-3: tell 40, active 60, recovery 120, escape only by an invulnerable move); GDD "never the same attack 3 times in a row" (D-S31-6); D-022 (Lunge renamed Head Rush); Pillar 2 (every tell readable, `;` visibly open) and Pillar 3; AD-06 (`BossAttack` per attack, `ArenaContext`, `AttackDef` data); NP-3 (attacks never touch Player or Register); AD-01 (sim frames only; integer state for everything hashed); AD-05 (presentation reads, never writes).
**Epic 3 window:** Nov 11-14 (MVP gate Nov 14). **Depends on:** 3.1 (`BossAttack`, `AttackDef`, `PhaseDef` pools, FSM, `ArenaContext`, `PlayerEffects`), 3.2 (`CombatResolver` boss path, Patched, `DamageState`), 3.3 (`InfiniteLoopBody`, ring state, `;` hurtbox, `RingDef`, `boss_def.tres` with empty pools, D-S33-9 / D-S33-12e), 2.9 (`PlayerHealth.queue_hit`, retry; deferred "retry reseeds the RNG from the wall clock").
**Unblocks:** 3.5 (Nested Loop, `;` Spit, phase 3 rings and their weak windows), 3.6 (tutorial beats T2 on the first `;` approach), 3.9 (MVP playtest).

## Acceptance Criteria

1. **Given** the data for the two attacks
   **When** `data/bosses/infinite_loop/attack_head_rush.tres` and `attack_constrict.tres` are loaded and validated
   **Then** Head Rush has tell 30, active 40, recovery 45 and Constrict has tell 40, active 60, recovery 120 (frames), both with a non-empty `tell_sfx`, and every timing the attacks use comes from these files
   **And** `data/bosses/infinite_loop/ring_def.tres` carries the new attack numbers (head charge 10 tiles, Constrict chase 8 tiles/s, Constrict final radius 2 tiles) validated by `RingDef.validate()` (D-S34-8)
   **And** `boss_def.tres` pools are: P1 `[head_rush]`; P2 `[head_rush, constrict]`; P3 `[head_rush, constrict]` (Spit and Nested Loop arrive in 3.5). `BossDef.validate()` accepts them.

2. **Given** phase 1-3 and a Head Rush is drawn
   **When** its TELL runs (30 frames)
   **Then** a `!` shows over the head (presentation), and the head's direction is fixed at tell entry from the ring centre toward `target_position()` (clamped into the play area, D-S34-6)
   **And** the ring does not spin during TELL (D-S34-5).

3. **Given** Head Rush is in ACTIVE (40 frames)
   **When** time passes
   **Then** the head is a single `{` cell (0.5-tile contact circle) that travels 10 tiles in a straight line at 250 milli-tiles per frame, the endpoint clamped into the play area
   **And** touching the head with the player's centre queues one contact hit through `PlayerHealth.queue_hit()` (invulnerability honoured); the head deals no damage through any other path
   **And** a hit on the head does nothing (no Patched, no hit-stop, no `hit_landed`, no `mark_hit`), as for any non-`;` point (D-S33-5).

4. **Given** Head Rush enters RECOVERY (45 frames)
   **When** the recovery starts
   **Then** the `;` opens for exactly the 45 recovery frames, counts as one opening (`i` + 1), and is hittable through the existing boss path (weak window of the phase, Patched, `DamageCalc`, hit-stop)
   **And** the ring's lap clock stays frozen until the attack ends (GAP).

5. **Given** phases 2-3 and a Constrict is drawn
   **When** its TELL runs (40 frames)
   **Then** the final ring outline is drawn at exact size (radius 24 / (2π) ≈ 3.82 tiles, D-S34-7) centred on the aim point (clamped into the play area) and the ring does not spin

6. **Given** Constrict is in ACTIVE (60 frames)
   **When** time passes
   **Then** the ring centre moves toward the aim point at 8 tiles/s (faster than the player's 7 tiles/s walk, so walking out cannot escape), and the radius shrinks in integer milli-tiles from 3820 to 2000 linearly over the 60 frames
   **And** the body's contact area during ACTIVE is the disc of the current radius around the centre, tested against the real player (`body_contact_position`), not the 24 segments; each tick inside queues a contact hit through `PlayerHealth.queue_hit()`
   **And** an invulnerable move (dash i-frames, Dash Strike through the body) takes no contact damage (AC 6 is tested through `PlayerHealth` invulnerability).

7. **Given** Constrict enters RECOVERY (120 frames)
   **When** the recovery starts
   **Then** the radius snaps back to the nominal ring (3820 milli-tiles), the 24 segment contacts return, the `;` is open for all 120 frames (one `i` opening), and it is hittable through the existing boss path.

8. **Given** a phase change (ROAR) or defeat while Head Rush or Constrict is running
   **When** the attack is cut
   **Then** `on_cancel` clears the head and the disc, the ring radius returns to nominal, no `on_recovery` runs, the `;` follows the 3.3 rules (ROAR: closed; DEFEATED: stopped), and the ring spins again from the next GAP/ROAR tick per 3.3 rules.

9. **Given** the ring's spin and the lap clock
   **When** the boss is in TELL, ACTIVE or RECOVERY of an attack
   **Then** the lap clock and `travel_mtiles` do not advance (D-S34-5); in GAP and ROAR they advance exactly as in 3.3, with the 3.3 ramp and cap
   **And** `iteration` (i) increments once per `;` opening, lap starts and attack recovery openings alike.

10. **Given** the pick (D-S31-6, D-S34-3)
    **When** the GAP of a phase with two attacks ends
    **Then** the pick is drawn from `ctx.rng` only (the existing `pick_next`), and the "not the same attack three times in a row" rule holds
    **And** a phase whose pool has one attack (phase 1: Head Rush only) draws it without a redraw; this waives the triple-repeat rule for a one-attack pool and is flagged to Tiziano (GDD conflict, D-S34-3).

11. **Given** the 2.9 deferred item "retry reseeds the RNG from the wall clock" (D-S34-2)
    **When** any FIGHT entry (intro, harvest, retry, debug jump) seeds the fight
    **Then** the seed is `fight_seed_for(run_seed, fight_attempt)`, a pure integer function; `run_seed` is taken from the clock once per run, `fight_attempt` counts FIGHT entries in the run; the simulation never reads the clock; the recorded seed (existing recording) reproduces the fight exactly
    **And** two entries of the same run get different seeds, and the same `(run_seed, attempt)` gives the same seed (unit tests).

12. **Given** the attacks read the arena (NP-3, D-S34-10)
    **When** the guard test runs
    **Then** `ArenaContext.player_position()` is renamed `body_contact_position()` and is read by the body only; attack code in `src/bosses/*/attacks/` reads `target_position()` alone and references neither `Player`, `Register`, nor `body_contact_position`/`player_position` (source guard test). The 3.1 deferred item "player_position lets an attack bypass target_position" is closed by this.

13. **Given** every tell and attack position (Pillar 2, AC 5 of 3.1)
    **When** `declared_positions` is checked for each attack at every tell and active position
    **Then** every position lies inside the play area (edges included).

14. **Given** the presentation (AD-05)
    **When** BossView draws
    **Then** it shows the `!` over the head during Head Rush TELL, the head cell during ACTIVE, the Constrict tell outline, the Constrict disc during ACTIVE, and the `;` state from the body; it reads state only and never writes.

15. **Given** the determinism rules (D-S34-12)
    **When** the GUT suite runs
    **Then** the existing replay, retry snapshot and 3.3 F3 tests pass (F3 edited only if the seed change requires it, recorded in Completion Notes), and a new F3-style integration test scripts a FIGHT through a Head Rush and a Constrict (phase 2 via the debug jump), records it, replays it on the re-seeded clock, and gets the same per-tick hash of integer state (ring, attack progress, `last_pick`, `hp`, player HP, RNG state) for every tick.

16. **Given** the guard scripts
    **When** `bash game/tools/check_guards.sh` runs
    **Then** `src/bosses/` still has no `Area2D`, no `delta`, no timers, no `await`; `check_guards: OK`.

## Scope Boundaries

- In: Head Rush and Constrict (attack scripts, data, tells, hazards, `;` recovery openings), the attack-state hooks on the body (spin freeze, contact delegation), the `ArenaContext` split, the per-run seed fix (2.9 deferred), the presentation of tells and hazards, tests.
- Out: `;` Spit and Nested Loop (3.5); the phase 3 per-ring weak windows (3.5); the duck tells and tutorial beats (3.6); the TELL audio cue (`tell_sfx` stays a placeholder id until 7.2); `PlayerEffects` command types (6.5, the queue stays empty and is not used by 3.4); Echo/decoy targeting (4.2, `target_position()` is the decoy seam but has no decoy yet); defeat reassembly and Harvest (3.8); exclusive/recovery-without-Breakpoint fields (6.5 / 4.3, stored only).

## Tasks / Subtasks

Ship in order. Each group ends at a green GUT run.

### Group A — Data and validation

- [x] A1. `RingDef`: add `head_charge_tiles` (10), `constrict_chase_tps` (8), `constrict_radius_tiles` (2) with `validate()`: `head_charge_tiles > 0`, `constrict_radius_tiles > 0` and `< R` (the nominal radius), `constrict_chase_tps > 0`. The "faster than walking" rule is a test (A4), not a hard-coded constant in `RingDef`.
- [x] A2. Create `game/data/bosses/infinite_loop/attack_head_rush.tres` (`AttackDef`, id `&"head_rush"`, tell 30, active 40, recovery 45, `attack_script` = `head_rush.gd`, `tell_sfx` `&"tell_head_rush"`) and `attack_constrict.tres` (id `&"constrict"`, 40 / 60 / 120, `tell_sfx` `&"tell_constrict"`).
- [x] A3. `boss_def.tres`: fill the pools per AC 1 (P1 `[head_rush]`, P2 and P3 `[head_rush, constrict]`).
- [x] A4. `PhaseDef.validate`: a non-empty pool needs at least one distinct attack (was two; D-S34-4). Update the 3.1/3.3 tests that assert the old message and the 3.3 `empty-pool` case as needed. Tests: Infinite Loop pools match AC 1; `constrict_chase_tps` > the player's `speed_tiles_s` (read from the player def, D-S34-16); the new ring fields validate and reject bad values.

### Group B — Per-run seed (2.9 deferred item, D-S34-2)

- [x] B1. `RunState`: add `run_seed: int = 0` (set once per run) and `fight_attempt: int = 0` (counts FIGHT entries in the run). Keep `fight_seed`.
- [x] B2. A pure static `fight_seed_for(run_seed: int, attempt: int) -> int` (integer mix, masked to a positive 63-bit value, nonzero; no clock, no RNG). Put it in `RunState` or a pure helper next to it.
- [x] B3. `Game._begin_fight`: take `run.run_seed` from `Time.get_ticks_usec()` only if it is 0 (the first FIGHT of the run), increment `fight_attempt`, set `fight_seed = fight_seed_for(run_seed, fight_attempt)`, then `SimClock.begin_fight`. The clock read stays on the presentation side (as today). Reset `run_seed` and `fight_attempt` where a new run starts (title, not retry or harvest).
- [x] B4. Tests: same `(run, attempt)` same seed; consecutive attempts differ; the replay of a recorded fight with its recorded seed reproduces (the existing recorder stores the seed). Update `test_game_flow.gd` where it assumed the wall-clock seed; `test_each_fight_entry_takes_a_new_seed` must still hold.

### Group C — ArenaContext split (NP-3, D-S34-10)

- [x] C1. `ArenaContext.player_position()` renamed to `body_contact_position()`; `target_position()` stays the only aim read. Update `Arena._make_arena_context`, `BossController._check_contact`, `InfiniteLoopBody._drift` and the 3.1 tests (`test_boss_controller.gd` lines that call `player_position`).
- [x] C2. Guard test `test_attack_isolation.gd`: reads every `src/bosses/*/attacks/*.gd` and fails on `body_contact_position`, `player_position`, `Player`, `Register`, `PlayerHealth`, `SimClock`, `Arena.` (except `Arena.play_area()` and `Arena.clamp_to_play_area`), and on `ctx.rng` outside `pick_next` (attacks draw no RNG, D-S34-14).

### Group D — Framework hooks for attack hazards (D-S34-9, D-S34-11)

- [x] D1. `BossAttack`: virtual `hazard_hit(p: Vector2) -> bool` (default false) and `hazard_positions() -> PackedVector2Array` for presentation and tests (default empty). `declared_positions` stays the AC 13 check.
- [x] D2. `BossController`: public `current_attack() -> BossAttack` (null when none); `InfiniteLoopBody.touches_player` = ring segments (GAP, TELL-free states, RECOVERY, ROAR) or the current attack's `hazard_hit`; during Constrict ACTIVE the segments are replaced by the disc (D-S34-7). `_check_contact` is unchanged (contact through `touches_player` only).
- [x] D3. `InfiniteLoopBody._tick_body`: freeze the lap clock and drift in attack TELL/ACTIVE/RECOVERY (Constrict ACTIVE moves the centre toward the aim instead of the drift; D-S34-13). Keep the start gate and the `;` countdown exactly as 3.3 for GAP and ROAR.
- [x] D4. `InfiniteLoopBody`: `_on_attack_recovery_open(frames)` (called by the attacks through a body method, not by the arena): `open_left = frames`, `iteration += 1`. Attack scripts reach the body only through the `BossController` (no new `ArenaContext` channel).
- [x] D5. `BossController` cancels: `_cancel_attack` is the only path that clears attack hazards; the body restores the nominal radius in its `_on_attack_cancelled` hook (the attack's `on_cancel` clears its own fields).

### Group E — Head Rush (`game/src/bosses/infinite_loop/attacks/head_rush.gd`, `class_name`-less `extends BossAttack`)

- [x] E1. `on_tell(ctx)`: `aim = Arena.clamp_to_play_area(ctx.target_position())`; origin = ring centre + R * unit(aim - centre) (R = nominal radius in tiles), clamped inside the play area; direction fixed as the unit vector from origin to aim; integer `travelled_mtiles = 0`.
- [x] E2. `on_active(ctx)`: each active tick adds 250 milli-tiles (10 tiles over 40 frames, D-S34-6), stopped at the clamped endpoint so the head never leaves the play area; the head position is `origin + direction * travelled` (float, presentation and contact only).
- [x] E3. `hazard_hit(p)`: `p` inside a 0.5-tile circle at the head; false in TELL, false after ACTIVE (the head retracts at RECOVERY entry).
- [x] E4. `on_recovery(ctx)`: the body opens the `;` for `recovery` frames (D4). `reset()` clears origin, direction and travel. `declared_positions`: origin and endpoint.
- [x] E5. `on_cancel`: clears the head (no hazard). Tests: tell aims at the target (clamped), 40 ticks of 250 milli-tiles = 10 tiles exactly, endpoint clamp, hazard only during ACTIVE, `;` open for 45 recovery ticks and closed in TELL/ACTIVE, `i` + 1 at the recovery opening, a hit on the head does nothing (no `hit_landed`), a dash through the head with invulnerability takes no damage.

### Group F — Constrict (`game/src/bosses/infinite_loop/attacks/constrict.gd`, `extends BossAttack`)

- [x] F1. `on_tell(ctx)`: `aim = clamp(ctx.target_position())`; the tell outline is the nominal ring at the aim (presentation only), centre starts at the current ring centre (the body's), no radius change yet.
- [x] F2. `on_active(ctx)`: integer `elapsed_frames` (0..59); radius `r_mtiles = 3820 - (3820 - 2000) * elapsed / 60` (integer division, `@warning_ignore`); the centre moves toward the aim at `constrict_chase_tps / 60` tiles per tick, never past the aim; the centre is clamped so the disc stays inside the play area (the 3.3 clamp rule with the current radius).
- [x] F3. `hazard_hit(p)`: `body_contact_position` inside the current disc (D-S34-7). Because the attack gets only the centre through the body, the body passes the real player position into `hazard_hit` (the attack never reads the player itself: `hazard_hit(p)` receives it from the body, which reads it through `ArenaContext.body_contact_position()`).
- [x] F4. `on_recovery(ctx)`: radius back to nominal (3820), segments back, `;` open 120 frames (body opens it, D4). `on_cancel`: clears the disc, nominal radius restored (D5).
- [x] F5. Tests: the tell outline radius is 3.82 tiles and inside the play area; the radius sequence over 60 active ticks is integer and ends at 2000; the centre reaches the aim within 60 ticks and never overshoots; the disc contact uses the real player; walking at 7 tiles/s cannot keep out of the disc (a scripted walk away from the centre is caught); a dash with invulnerability through the disc takes no damage; `;` open 120 recovery ticks; `i` + 1.

### Group G — Presentation (reads only)

- [x] G1. `BossView` (3.3 D2 deferral): `!` over the head during Head Rush TELL (INK, 1 cell above the origin, clamped into the arena); the head glyph `{` in ACTIVE; the Constrict tell outline in ACTIVE-safe style (INK outline at the current radius); the Constrict disc during ACTIVE drawn as an INK outline of the current radius (palette is INK/BG only; D-S34-12).
- [x] G2. The ring draws in the Constrict recovery at nominal radius; the `;` state is unchanged from 3.3 (D-S33-24 open/closed look).
- [x] G3. Pure helper tests for the tell `!` position clamp and the tell outline clamp.

### Group H — Tests, guards, finish

- [x] H1. `tests/integration/test_infinite_loop_replay.gd` (F3 of 3.3): extend the scripted FIGHT with a Head Rush (P1, default pick) and a Constrict (phase 2 via the debug jump Shift+F6 in the test), hash integer state per tick: `travel_mtiles`, `travel_rem`, `speed_mtps`, `iteration`, `open_left`, `started`, boss `hp`, `phase_index`, `state`, `frames_left`, `last_pick`, attack progress (head travel, constrict `elapsed`), player HP, RNG state. Same numbers on replay. Assert both attacks ran and at least one hit landed on the `;` during a recovery.
- [x] H2. Full GUT run (same command as CI, 3.1 Debug Log), `bash game/tools/check_guards.sh`. Record counts and every design call in the Dev Agent Record. Set `3-4-head-rush-and-constrict` to `review` on completion (dev-story, not this skill).
- [x] H3. Human checks listed below (do not block `review`).

### Group I — Human checks (recorded, do not block `review`)

- [ ] I1. Chrome and Firefox (`?debug`): Head Rush `!` reads at the 30-frame tell; the head charge is visible; the `;` opens for the 45-frame recovery and is hittable.
- [ ] I2. Constrict in P2: the tell outline is readable at exact size; walking out does not escape; a dash through the disc does.
- [ ] I3. Retry twice in a row: the attack order differs between attempts and matches on a replay of the same recording.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S34-1 One story, ordered groups.** Head Rush and Constrict ship together (the epic has one AC set for both and the attack hooks are shared). Groups A-H are the order of work; A-D alone give the attack framework with the ring still and no visible tell.
- **[design call] D-S34-2 Per-run seed (closes the 2.9 deferred item).** Today `Game._begin_fight` reseeds from `Time.get_ticks_usec()` on every FIGHT entry (`game.gd`). Fix: `run.run_seed` is captured once per run from the clock, `run.fight_attempt` counts FIGHT entries in the run, and `fight_seed = fight_seed_for(run_seed, fight_attempt)` (pure integer mix). Retries stay different (AC 11) and reproducible: the recorded seed of a recording reproduces the fight. The sim never reads the clock. Alternative (rejected): retry reuses the fight-start seed, which makes every retry identical and the attack order learnable by heart.
- **[design call] D-S34-3 One-attack pool and the triple-repeat rule (GDD conflict).** GDD says "never the same attack 3 times in a row" but the attack table has Head Rush alone in phase 1. Default: a one-attack pool draws it every time (no redraw is possible), so phase 1 repeats Head Rush. Flagged for Tiziano: the alternative is an interleaved GAP or a second P1 attack (Spit is P3-only in the GDD).
- **[design call] D-S34-4 PhaseDef pool rule.** A non-empty pool needs at least one distinct attack (was two, 3.3 D-S33-9 kept the 2-rule for non-empty pools). The 2-rule was only meant to exclude a single-attack boss, which the GDD table requires in phase 1.
- **[design call] D-S34-5 Ring frozen during attacks.** The ring's lap clock and drift stop while an attack is in TELL, ACTIVE or RECOVERY, so the attack reads as the loop's whole body moving. The `;` opening of the recovery is the one opening of that attack (AC 4, AC 7). In GAP and ROAR the 3.3 motion applies unchanged.
- **[design call] D-S34-6 Head Rush geometry.** Origin on the nominal ring at the side facing the aim (clamped into the arena), direction fixed at tell entry, 250 milli-tiles per tick for 40 ticks = exactly 10 tiles (integer). The endpoint is clamped into the play area (the head stops at the edge; the timing stays 40). The head's contact is a 0.5-tile circle (one glyph cell, the cell's inscribed radius, D-S31-25: no player radius added). The head is hazard only; hits on it do nothing (D-S33-5).
- **[design call] D-S34-7 Constrict geometry.** TELL shows the nominal-size outline at the aim. ACTIVE: the centre moves toward the aim at 8 tiles/s (the GDD says "re-centres on the player" and "walking cannot escape", so the chase must beat the 7 tiles/s walk; the aim is `target_position()`, the real contact is the real player). The radius shrinks linearly from 3820 to 2000 milli-tiles over 60 ticks (integer). The contact area is the disc (not the 24 segments) so the inside is lethal and only an invulnerable move gets out. RECOVERY: the radius snaps back to nominal and the segments return; `;` opens for 120 frames.
- **[design call] D-S34-8 Numbers in data.** Timings in `attack_*.tres` (the AC says "all timings come from attack_*.tres"). Attack-specific balance (head charge distance, chase speed, final radius) in `RingDef` (the ring's numbers, D-S33-15). No attack constant lives in code except the 250 milli-tiles/tick derived from the charge (computed in `on_tell` from the def, not hard-coded).
- **[design call] D-S34-9 Contact goes through `touches_player`.** Attack hazards reach the player only through the body's `touches_player` (which asks the current attack's `hazard_hit`), and `_check_contact` queues the hit through `PlayerHealth`. No new `ArenaContext` request channel and no `PlayerEffects` command (NP-3 unchanged; 6.5 owns command types).
- **[design call] D-S34-10 `player_position` split (closes the 3.1 deferred item).** `ArenaContext.player_position()` becomes `body_contact_position()` and is read only by the body (contact, Constrict's disc). Attacks read `target_position()` alone. The guard test (C2) fails if an attack file names either.
- **[design call] D-S34-11 Attack hooks on the framework.** `BossAttack.hazard_hit(p)` and `hazard_positions()` (virtual, defaults false / empty). `BossController.current_attack()` (public). The attack instances stay the 3.1 cached RefCounted scripts; nothing is built per fight.
- **[design call] D-S34-12 Presentation.** `!` tell mark per the 3.3 D2 deferral (one cell above the head origin, clamped). The palette has INK and BG only (3.3 D-S33-24): the Constrict disc is an INK outline at its current radius, the tell outline is an INK outline at nominal radius. Head is a `{` cell (INK). The hazards are visible in the 1-tile glyph grid; nothing is hidden behind a glyph.
- **[design call] D-S34-13 Constrict chase replaces the drift.** During Constrict ACTIVE the centre chases the aim at 8 tiles/s; during Head Rush the drift is suspended; drift resumes in GAP and ROAR. The clamp into the play area applies throughout.
- **[design call] D-S34-14 Attacks draw no RNG.** Only `BossController.pick_next` draws from `ctx.rng`. The per-attack scripts are deterministic from their aim, timings and the body state, so the replay hash covers the RNG only through the picks.
- **[design call] D-S34-15 Phase change and defeat.** `_cancel_attack` (3.1) calls `on_cancel`; the body restores the nominal radius and clears the head/disc (D5). The spin resumes at the next GAP or ROAR tick (3.3 rules). Defeat leaves the ring stopped (3.3 D-S33-17).
- **[design call] D-S34-16 Walk-escape rule is a test.** The 8 tiles/s chase must exceed the player's `speed_tiles_s` (7) in the test (A4); a scripted walk test (F5) confirms the escape fails.
- **[design call] D-S34-17 Phase 3 pool is two attacks.** P3 uses Head Rush and Constrict; the Spit and Nested Loop are added in 3.5 (AC 1 says so). The phase 3 weak window stays the placeholder A-D (3.3 D-S33-10).
- **[design call] D-S34-18 `;` recovery openings and `i`.** The `;` opening of each attack recovery increments `i` once (3.3 AC 3 "once per opening"). The recovery `;` is open for the full recovery length, forced (the lap countdown is overwritten; a lap cannot start during an attack, so there is no conflict).
- **[design call] D-S34-19 Replay test choreography.** Debug jump to phase 2 (Shift+F6) is used in the replay test only; it is not a shipped path.
- **[design call] D-S34-20 3.4 writes no `EventBus` signal.** The existing `boss_tell_started` (3.1) and the 3.2 hit signals cover the tells and hits. A new signal would need an event-bus entry (past tense, typed); none is needed.

### Replay and determinism checklist

- The per-run seed changes which seed a FIGHT gets after the first. The recorded seed reproduces; the replay tests and the retry snapshot test must stay green (edit only with a recorded reason).
- RNG is drawn only by `pick_next`. Attack scripts draw nothing (AC 12, D-S34-14).
- The replay hash includes every integer attack field (head travel, constrict elapsed, radius) and the RNG state. Float positions are not hashed (3.3 D-S33-2; deferred cross-platform float determinism).
- No `delta`, no timers, no `await`, no `Engine.time_scale` in `src/bosses/` (AD-01).

### Existing code this story touches (verified at baseline 295034f)

- `game/src/bosses/framework/boss_controller.gd`: `tick`, `_advance` (pick and tell), `pick_next` (triple-repeat rule), `_cancel_attack`, `_check_contact`, `touches_player`, `attack_for`, `_defeat`.
- `game/src/bosses/framework/boss_attack.gd`: the hooks; `hazard_hit` and `hazard_positions` are added.
- `game/src/bosses/framework/attack_def.gd`, `phase_def.gd` (pool rule, A4), `boss_def.gd`.
- `game/src/bosses/framework/arena_context.gd`: `player_position` renamed (C1).
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`, `ring_def.gd`.
- `game/src/bosses/test_boss/attacks/pulse.gd`, `sweep.gd`: reference attacks (no hazards in 3.1; they stay as is).
- `game/src/arena/arena.gd`: `_make_arena_context` (C1).
- `game/src/autoloads/game.gd`: `_begin_fight` (B3), `retry`.
- `game/src/core/run_state.gd`: `fight_seed` plus the new fields (B1).
- `game/src/debug/input_recorder.gd`, `debug_keys.gd`: the recording's seed (unchanged; B4 tests it).
- `game/src/presentation/boss_view.gd`: tell mark, head, outline, disc (G1).
- `game/tests/unit/test_game_flow.gd`, `test_boss_controller.gd`, `test_infinite_loop_body.gd`, `test_data_validation.gd`, `test_combat_resolver.gd`; `game/tests/integration/test_infinite_loop_replay.gd` (regression surface).

### Architecture guardrails (must follow)

- AD-06 / architecture layout: attacks in `src/bosses/infinite_loop/attacks/`, data in `data/bosses/infinite_loop/`.
- NP-3: attacks never call `Player`, `Register`, `PlayerHealth`, `SimClock`; they read `ArenaContext.target_position()` only and expose hazards to the body.
- AD-05: presentation reads and never writes.
- ADR-02 / AD-04: circle math only.
- Single writers: HP through `take_hit`; Patched through `WeakWindowTracker`; damage through `DamageCalc`; player HP through `PlayerHealth` (contact via `queue_hit`).
- Event rules: no new `EventBus` signal (D-S34-20).
- Typing: static types everywhere; GDScript 2.0; no `await`.
- Logging: `Log.debug` only on events (tell start is already logged by the FSM), never per tick.

### Previous story intelligence (3.1, 3.2, 3.3 reviews)

- 3.3 deferred "non-player shift gating, spawn/drift contact tuning": still open; the start gate is unchanged.
- 3.3 deferred "`PhaseDef.validate` skips the 2-attack rule for any empty pool": resolved by A4 (the rule is now "one attack or more when non-empty"; a per-boss opt-in is not needed for a single-attack boss).
- 3.3 deferred "tests hard-code pixel offsets" and "read private `_pending`": keep the new tests on public API where possible.
- 3.3 deferred "float trig in ring and hit tests, replays may diverge across native/wasm": still open; the new hazards are floats too (not hashed).
- 3.1 deferred "`ArenaContext.player_position()` lets an attack bypass `target_position()`": closed by C1/C2 (D-S34-10).
- 3.1 deferred "contact radius vs drawn body size": closed by 3.3 per-segment contact; the disc of Constrict is a new contact shape (D-S34-7).
- 3.1 deferred "`PlayerEffects` silently drops commands": still open; 3.4 pushes no commands.
- 2.9 deferred "retry reseeds the RNG from the wall clock": closed by B1-B4 (D-S34-2).
- 3.2 deferred "A multi-tick action overlapping a boss during ROAR is not marked consumed": unchanged.
- 3.2 D-S32-14 (Patched persists across phase change): unchanged.

### Git intelligence

- `295034f` is the 3.3 review tip; branch `story/3-4-head-rush-and-constrict` stacks on 3.3 (sprint-status: 3-3 `done`).
- The `game/src/bosses/infinite_loop/attacks/` folder exists and is empty; the 3.3 notes say attacks go there.

### Latest technical information

- Godot 4.7.2-stable (pinned), GDScript only. `Vector2.from_angle`, `Vector2.move_toward`, integer `/` (with the warning suppressed) and `clampi` are standard. No new library, no addon.
- GUT 9.6.1 headless CLI as in 3.1 to 3.3.
- Context7 `/godotengine/godot-docs/__branch__4.7` for any API doubt (project-context rule).

### Project Context Rules

- Only `SimClock` calls `tick()`. No `delta`, `Timer`, `await`, `Tween` or `Engine.time_scale` in `src/combat/` or `src/bosses/`.
- Boss code in `src/bosses/<boss>/`; shared framework in `src/bosses/framework/`; combat math in `src/combat/`.
- Data: typed `*Def` resources under `data/**/*.tres`; balance numbers in `.tres`, invariants in `Const` or pure static helpers.
- Signals only in `src/autoloads/event_bus.gd`, past tense, typed args.
- Names: `head_rush.gd`, `constrict.gd`, `attack_head_rush.tres`; frame fields end `_frames`; ids `StringName`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.4: Head Rush and Constrict]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.5 (`;` Spit, phase 3 pool)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss Design, Boss 1 — Infinite Loop, attack table, Walking evasion]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-022, D-018, D-033]
- [Source: _bmad-output/game-architecture.md#AD-06, NP-3, folder layout for bosses/infinite_loop/attacks]
- [Source: _bmad-output/implementation-artifacts/3-3-infinite-loop-body-and-loop-condition.md#Design calls D-S33-1 to D-S33-27, Dev Agent Record]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-2-9, story-3-1, story-3.2, story-3.3]

## Dev Agent Record

### Agent Model Used

claude opus (Claude Opus 5.5, `claude-opus-5-5`), gds-dev-story, unattended.

### Debug Log References

- GUT, same command as CI: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import`, then `... --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Final run: Scripts 61, Tests 763, Passing 763, Asserts 15170, `---- All tests passed! ----`, no failure markers (no SCRIPT ERROR / Parse Error / pending / risky).
- `bash game/tools/check_guards.sh`: `check_guards: OK`. `src/bosses/` has no `Area2D`, `delta`, timers or `await`.
- First full run after the code (before test updates): 9 expected failures, all from the 3.3/3.1 tests that assumed empty pools or the 2-attack pool rule (fixed as listed below). The replay suites stayed green throughout.

### Completion Notes List

- Group A: `RingDef` gains `head_charge_tiles` 10, `constrict_chase_tps` 8, `constrict_radius_tiles` 2 with validation; `attack_head_rush.tres` (30/40/45, `tell_head_rush`) and `attack_constrict.tres` (40/60/120, `tell_constrict`); `boss_def.tres` pools P1 `[head_rush]`, P2/P3 `[head_rush, constrict]`; `PhaseDef` accepts a one-attack pool (D-S34-4). Tests: pools, ring fields accept/reject, chase 8 > walk 7 read from `player_def.tres`.
- Group B: `RunState.run_seed`, `fight_attempt`, pure `RunState.fight_seed_for(run_seed, attempt)`; `Game._begin_fight` takes the clock once per run (when `run_seed == 0`), counts attempts and seeds with the mix. A new run is a new `RunState` (title, ending, debug jump to title), so both reset there. `test_game_flow.gd`: purity/uniqueness of the mix over 49 attempts x 4 run seeds, retry/harvest keep the run seed and take `fight_seed_for(run_seed, n)`, new run resets. `test_each_fight_entry_takes_a_new_seed` unchanged and green.
- Group C: `ArenaContext.player_position()` -> `body_contact_position()` (and its source `player_source` -> `contact_source`, D-S34-26); call sites in `Arena`, `BossController._check_contact`, `InfiniteLoopBody._drift` and the 3.1/3.2/3.3 tests updated. New `test_attack_isolation.gd` scans every `src/bosses/*/attacks/*.gd` (comments stripped) for the forbidden names, any `Arena.` member but `play_area` / `clamp_to_play_area`, and any RNG use; self-tests the patterns. Closes the 3.1 deferred item.
- Group D: `BossAttack.hazard_hit`, `hazard_positions`, plus `replaces_body_contact`, `tell_marks`, `outline_circle`, `bind_boss`/`boss()`/`is_live()` (D-S34-24). `BossController.current_attack()`, `attack_hazard_hit()`, hooks `_attacks_allowed`, `_on_attack_started`, `_on_attack_cancelled` (called from `_cancel_attack` only when an attack was running); `pick_next` skips the redraw for a one-attack pool (D-S34-3). `InfiniteLoopBody`: lap clock and drift frozen in TELL/ACTIVE/RECOVERY with the `;` countdown still running, `open_semicolon(frames)` (i + 1), `attack_radius_mtiles` + `set_attack_radius_mtiles` + `chase_centre`, `nominal_radius_mtiles()` (3820), contact = live hazard first, segments unless the hazard replaces them.
- D4 naming: the body method the attacks call is the public `open_semicolon(frames)` (D4's `_on_attack_recovery_open` would be private-by-convention yet called from another class); behaviour as specified.
- Group E: `head_rush.gd` per E1-E5 (origin on the nominal ring facing the clamped aim, direction fixed at TELL entry, step = charge*1000/active = 250, travel capped by the ray-to-edge limit, 0.5-tile head contact, recovery opens the `;` 45 ticks, cancel/reset clear). Tests in `test_infinite_loop_attacks.gd`.
- Group F: `constrict.gd` per F1-F5 (tell outline at nominal size around the clamped aim, integer radius 3820 -> 2000 over 60 ticks, chase at 8 tiles/s never past the aim, disc contact on the real player replacing the segments, recovery snaps to nominal and opens the `;` 120 ticks). Tests include the walk-away scenario (inside the disc on every ACTIVE tick), walking out of the ring during the tell (hit), invulnerable dash through the disc (no damage).
- Group G: `BossView._draw_attack` draws the `!` one cell above the Head Rush origin (`tell_mark_centre`, clamped), the `{` head cell, and an INK `draw_arc` outline for Constrict's tell outline and ACTIVE disc; reads only. Pure helper tests and a draw-without-writing test.
- Group H: `test_infinite_loop_replay.gd` hash extended with FSM state, `frames_left`, both picks, `attack_radius_mtiles`, Head Rush travel, Constrict `elapsed` and the RNG state (all integer). New scripted FIGHT (seed 34034, 1500 polls, phase-2 skip at poll 260, recovery choreography) records, replays from file, and matches per-tick hashes; asserts Head Rush and Constrict both ran, a hit landed on the `;` during a recovery, and the RNG moved only on pick ticks. F3 edit (recorded per AC 15): the 3.3 test `test_the_infinite_loop_draws_no_rng_in_a_real_fight` became `..._draws_no_rng_in_phase_1` (D-S34-30); the 3.3 recorded-fight test itself is unchanged apart from the wider hash. `test_retry_snapshot.gd` and `test_replays.gd` untouched and green.
- 3.3 ring tests (`test_infinite_loop_body.gd`) now run on a deep copy of the def with empty pools (`ring_only_def()`), so they still test the 3.3 ring alone; the attacks have their own file.
- Group I (human checks I1-I3) left open: they need a browser and do not block `review`.

**New design calls (implementer, unattended):**

- [design call] D-S34-21 Constrict re-centres on a live aim: `ctx.target_position()` is re-read on every ACTIVE tick (GDD/FR35 "re-centres on the player"); the tell outline uses the aim at TELL entry. Flag for Tiziano: with 8 vs 7 tiles/s a player who is already outside the ring and > ~4 tiles from it at TELL entry can still walk clear (net closure 1 tile/s while the disc shrinks); "walking cannot escape" holds for a player inside or at the ring (walking out crosses the segments in TELL or the disc in ACTIVE), which the tests cover.
- [design call] D-S34-22 The `;` closes at every TELL entry (a lap opening is cut by the attack) and when an attack is cancelled, so the recovery opening is the attack's only opening and ROAR after a cut recovery shows it closed.
- [design call] D-S34-23 No attack before the loop starts: `_attacks_allowed()` (body: `started`) holds the FSM in GAP (no pick, no RNG) until the first shift, matching the tutorial beat "the ring stays still until the first shift".
- [design call] D-S34-24 Attacks reach their body through a weak back-reference (`BossAttack.bind_boss` in `setup`, `boss()`), not a new `ArenaContext` channel and without a RefCounted cycle. Extra virtuals `replaces_body_contact`, `tell_marks`, `outline_circle` keep `BossView` free of attack classes; `BossController.attack_hazard_hit` gates hazards on ACTIVE.
- [design call] D-S34-25 Hazards follow the FSM's ACTIVE window (D-S31-5): the head is live from ACTIVE entry (travel 0) to 9750 milli-tiles; the 40th step (10000) and Constrict's final 2000 radius happen on the tick that enters RECOVERY, so they exist in state but are never contact-checked.
- [design call] D-S34-26 The `ArenaContext` source field is renamed with the method (`player_source` -> `contact_source`), so the guard can ban the old names outright.
- [design call] D-S34-27 Head Rush reuses `RingDef.contact_radius_tiles` (0.5) for the head (one glyph cell; no new field), and the endpoint clamp keeps the direction: the travel is capped where the ray leaves the play area (floored milli-tiles) instead of clamping the endpoint per axis.
- [design call] D-S34-28 `fight_seed_for` is an overflow-free mix modulo 2^31 - 1 (bijective rounds, so consecutive attempts always differ), producing a positive seed below 2^62; `run_seed = max(Time.get_ticks_usec(), 1)`.
- [design call] D-S34-29 The Constrict disc is the current radius only (no extra 0.5-tile segment contact), as AC 6 states.
- [design call] D-S34-30 Phase 1 picks call `randi_range(0, 0)`, which does not advance Godot's RNG; the 3.3 "no RNG" replay test is kept for phase 1, and the new tests check the general rule (RNG moves only on pick ticks).
- D-S34-3 (one-attack pool repeats Head Rush in phase 1) is implemented as written and remains flagged to Tiziano as a GDD conflict.

### File List

- `_bmad-output/implementation-artifacts/3-4-head-rush-and-constrict.md` (modified: tasks, Dev Agent Record, status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: 3-4 -> review)
- `game/data/bosses/infinite_loop/attack_head_rush.tres` (new)
- `game/data/bosses/infinite_loop/attack_constrict.tres` (new)
- `game/data/bosses/infinite_loop/boss_def.tres` (modified: pools)
- `game/data/bosses/infinite_loop/ring_def.tres` (modified: attack numbers)
- `game/src/bosses/infinite_loop/attacks/head_rush.gd` (+ `.uid`, new)
- `game/src/bosses/infinite_loop/attacks/constrict.gd` (+ `.uid`, new)
- `game/src/bosses/infinite_loop/infinite_loop_body.gd` (modified)
- `game/src/bosses/infinite_loop/ring_def.gd` (modified)
- `game/src/bosses/framework/boss_attack.gd` (modified)
- `game/src/bosses/framework/boss_controller.gd` (modified)
- `game/src/bosses/framework/arena_context.gd` (modified)
- `game/src/bosses/framework/phase_def.gd` (modified)
- `game/src/arena/arena.gd` (modified)
- `game/src/autoloads/game.gd` (modified)
- `game/src/core/run_state.gd` (modified)
- `game/src/presentation/boss_view.gd` (modified)
- `game/tests/unit/test_infinite_loop_attacks.gd` (+ `.uid`, new)
- `game/tests/unit/test_attack_isolation.gd` (+ `.uid`, new)
- `game/tests/unit/test_infinite_loop_body.gd` (modified)
- `game/tests/unit/test_boss_controller.gd` (modified)
- `game/tests/unit/test_combat_resolver.gd` (modified)
- `game/tests/unit/test_data_validation.gd` (modified)
- `game/tests/unit/test_game_flow.gd` (modified)
- `game/tests/integration/test_infinite_loop_replay.gd` (modified)

### Change Log

- 2026-11-09: Story 3.4 created unattended (gds-create-story). Status ready-for-dev.
- 2026-11-09: Implemented groups A-H (dev-story, claude opus): Head Rush and Constrict, per-run fight seed, `body_contact_position` split with the attack isolation guard, attack hooks on the framework and body, presentation of tells and hazards, new and extended tests (GUT 763/763, check_guards OK). Status review.

### Review Notes (gds-code-review, 2026-11-09)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). About 30 raw findings: 3 patched, 7 deferred (see deferred-work.md), rest dismissed or recorded design calls (D-S34-21/22/25/27).

- Patched: `pick_next` draws no RNG for a one-attack pool (previously relied on `randi_range(0,0)` being a no-op); `last_pick`/`second_last_pick` reset on phase change so the no-triple rule does not leak across phases; run-seed comment corrected (monotonic clock).
- Deferred: Constrict wall-hugging and RECOVERY pop-in, last-tick contact, seed entropy/mask, Head Rush inward aim, test gaps, float determinism across native/wasm.
- Replay determinism and per-run/per-fight seeding: no global RNG or wall-clock use found in attacks; `fight_seed_for` is pure.
