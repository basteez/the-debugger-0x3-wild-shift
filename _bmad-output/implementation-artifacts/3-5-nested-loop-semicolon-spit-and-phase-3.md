---
baseline_commit: 690cd79
---

# Story 3.5: Nested Loop, Semicolon Spit and Phase 3

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S35-n); the implementer follows them or records a change in Completion Notes. Phase 3 is droppable under the MVP fallback (Boss 1 ships phases 1-2 only): all phase-3 work is in Group P, which can be cut without touching Groups A-C and Q, and AC 11 proves the cut is a data-only edit. -->

## Story

As a player,
I want phase 3 to split the loop into two rings with alternating weak points,
so that switching rings means switching windows.

**Requirements:** FR35 (`;` Spit), FR36 (Nested Loop and phase-3 timer); GDD "Boss 1 — Infinite Loop" phase 3 (two rings, alternating `;`, Spit); D-S33-10 (per-ring windows arrive here through `current_weak_window()` overrides); D-S34-17 (phase 3 pool gets Nested Loop and Spit here); Pillar 2 (every tell readable, the open `;` visibly brightest); Pillar 3; AD-01 (sim frames only, integer state for everything hashed); AD-05 (presentation reads, never writes); NP-3 (attacks never touch Player, Register, PlayerHealth or SimClock); D-S34-14 (attacks draw no RNG outside `pick_next`).
**Epic 3 window:** Nov 11-14 (MVP gate Nov 14). **Depends on:** 3.1 (`BossController`, `AttackDef`, `PhaseDef` pools, `ArenaContext`), 3.2 (`current_weak_window()`, `WeakWindowTracker`), 3.3 (`InfiniteLoopBody` ring, `;` hurtbox, `RingDef`, `open_frames`), 3.4 (attack hooks, `hazard_hit` / `replaces_body_contact` / `open_semicolon`, `set_attack_radius_mtiles`, `attack_radius` ring, `attack_isolation` guard, per-run seed).
**Unblocks:** 3.6 (tutorial beats T3 on the phase-3 split), 3.9 (MVP playtest on the full three-phase fight).

## Acceptance Criteria

1. **Given** the Nested Loop attack data
   **When** `data/bosses/infinite_loop/attack_nested_loop.tres` (`AttackDef`, id `&"nested_loop"`, tell 40, active 1, recovery 0, `attack_script` = `nested_loop.gd`, `tell_sfx` `&"tell_nested_loop"`) is loaded and validated
   **Then** `boss_def.tres` phase 3 pool is `[head_rush, constrict, nested_loop]`; phases 1 and 2 pools are unchanged; `BossDef.validate()` accepts the boss
   **And** the Spit is not an attack in any pool (AC 8 explains why)

2. **Given** phase 3 begins (ROAR ends, the phase-3 GAP runs)
   **When** the FSM picks its first attack of phase 3
   **Then** the pick is `nested_loop` with no RNG draw (candidate rule, D-S35-3), and `nested_loop` is never picked again in that fight; later phase-3 picks draw uniformly from `[head_rush, constrict]` with the no-triple-repeat rule
   **And** a retry (reset_for_fight) makes it available again

3. **Given** the Nested Loop TELL (40 frames, the body flashes on the presentation side)
   **When** its ACTIVE tick and recovery finish (`on_recovery`)
   **Then** the single ring splits into an outer ring of 16 segments (radius 16 / 2π ≈ 2.55 tiles) and an inner ring of 8 segments (radius 8 / 2π ≈ 1.27 tiles), both concentric on the body centre, 1 tile per segment, contact circle 0.5 tile each (D-S35-4)
   **And** the split starts the timed `;` schedule with an opening of the outer ring at once (`i` + 1, 90 frames)
   **And** the body centre is clamped so the outer ring stays inside the 32×18 play area

4. **Given** the split is done
   **When** time passes in GAP and ROAR-free live states
   **Then** the outer ring spins as in 3.3 (lap ramp +5% per outer lap, cap 12 tiles/s, lap starts no longer open the `;`)
   **And** the inner ring spins at `min(outer × 150 / 100, 12 tiles/s)` in the same direction (derived each tick, D-S35-5)
   **And** both rings freeze (lap clocks and drift) during the Nested Loop TELL and during every attack's TELL, ACTIVE and RECOVERY (D-S34-5), and the drift resumes in GAP

5. **Given** the split is done
   **When** the timed opening schedule runs
   **Then** one `;` opens every 180 ticks (3 s), alternating outer, inner, outer, each for 90 frames; at most one `;` is open at a time; each opening is `i` + 1
   **And** the schedule is frozen only during ROAR (it runs through attacks); an attack's recovery opening is an opening too: it opens the next ring's `;` and advances the alternation but does NOT restart the 180-tick timer (D-S35-24, supersedes the original AC 5 timer rule)

6. **Given** phase 3 (before and after the split)
   **When** `current_weak_window()` is read
   **Then** before the split it returns the phase data window (A→D, `Vector2i(Register.Bit.ATTACK, Register.Bit.DASH)`); after the split it returns A→D while the outer `;` is open or is the next to open, and D→A (`Vector2i(Register.Bit.DASH, Register.Bit.ATTACK)`) for the inner ring
   **And** phases 1 and 2 return their data windows unchanged

7. **Given** the split rings
   **When** a player hit is resolved against the boss
   **Then** only the open `;` is a hurtbox (`overlaps_shape` and `hit_position` use the open ring's junction; the outer junction when none is open); a hit on any other point does nothing, as in 3.3
   **And** the Patched, damage and hit-stop paths are unchanged

8. **Given** phase 3 (`;` Spit, fixed 6 s cycle)
   **When** the phase-3 timer runs (360 ticks, counted from the end of phase 3's ROAR, not frozen by attacks)
   **Then** the origin `;` (the next-to-open ring's junction, or the outer junction before the split) glows for the last 20 ticks of the cycle (presentation reads the timer)
   **And** on the 360th tick one projectile is fired from the origin junction, aimed at `ctx.target_position()` clamped into the play area, at 6 tiles/s (100 milli-tiles per tick), from a 16-slot fixed pool (D-S35-9)
   **And** a projectile is removed when it leaves the play area or when the pool is cleared; a shot with no free slot is skipped (debug log, D-S35-10)
   **And** Spit draws no RNG

9. **Given** a live projectile
   **When** the player's centre is inside its 0.5-tile circle (body `touches_player`, D-S35-11)
   **Then** one contact hit is queued through `PlayerHealth.queue_hit()` (invulnerability honoured)
   **And** a hit on a projectile does nothing (no Patched, no hit-stop, no `hit_landed`), as for any non-`;` point
   **And** all projectiles are cleared at phase change and at defeat

10. **Given** Constrict in the split state
    **When** its TELL, ACTIVE and RECOVERY run
    **Then** the disc starts from the outer ring's nominal radius (`nominal_radius_mtiles()`, 2546 milli-tiles) instead of the 3820 constant, shrinks to `constrict_radius_tiles` (2000) over 60 ticks as in 3.4, and RECOVERY returns to the outer nominal radius (D-S35-12)
    **And** Head Rush's origin sits on the outer ring's nominal radius (`nominal_radius_px()`)

11. **Given** the epic fallback (phase 3 must be cut)
    **When** the phase-3 entry is removed from `boss_def.tres` (and its pool and Nested Loop / Spit data are left unused)
    **Then** the boss validates and runs as a working 2-phase fight with no split, no Spit, no per-ring window and no code change (test: a copy of the def without phase 3 runs a scripted fight)

12. **Given** the data numbers
    **When** `RingDef.validate()` runs
    **Then** it checks the new fields: outer split segments 16, inner segments 8, inner speed percent 150, opening period 180, Spit period 360, Spit tell 20 (≥ 1 and < period), Spit speed 6 tiles/s (> 0), Spit slots 16 (≥ 1); the existing single-ring rules (24 segments, 8 / 12 tiles/s, 5%, 2 tiles/s drift) stay (D-S35-13)

13. **Given** the replay harness (3.4 H1 test, extended)
    **When** a scripted FIGHT reaches phase 3 (Shift+F6 twice in the test only, D-S34-19), splits, runs at least one timed opening per ring, one Spit, one attack recovery opening and one Constrict
    **Then** the per-tick integer hash includes: `split`, `next_ring`, `ring_timer`, `spit_timer`, `nested_done`, inner `travel_mtiles` and `travel_rem`, inner speed, each projectile slot (active, position and step in milli-tiles), and the existing 3.4 fields and RNG state; the same seed gives the same hashes on replay
    **And** RNG draws happen only in `pick_next` on non-forced picks (AC 2), never in Spit or the split

14. **Given** the attack isolation guard (3.4 C2)
    **When** `test_attack_isolation.gd` and `game/tools/check_guards.sh` run
    **Then** `nested_loop.gd` and `semicolon_spit.gd` are scanned: no `body_contact_position`, `player_position`, `Player`, `Register`, `PlayerHealth`, `SimClock`, `Arena.` (except `play_area` and `clamp_to_play_area`), and no `ctx.rng` outside `pick_next`; Spit aims through `ctx.target_position()` only

15. **Given** AC 5 of Epic 3 (no off-screen attacks) and the 3.4 AC 13 gap
    **When** the tests check `declared_positions()`
    **Then** Nested Loop, Spit (origin, aim point and the whole straight path up to the play-area edge) and Constrict's ACTIVE disc positions are inside the 32×18 play area, and the test checks the real positions the body uses, not a separate method's output (3.1 and 3.4 deferred items, folded)

16. **Given** the presentation (reads only, AD-05)
    **When** the boss is drawn
    **Then** both rings are drawn (outer and inner glyph braces, the `;` of each ring; the open one is the brightest cell, D-S33-24), the body flashes during the Nested Loop TELL, the origin `;` glows during the Spit tell, a projectile is drawn as an INK `;` cell (D-S35-14), and no draw call writes sim state; the palette is INK and BG only

17. **Given** the existing suites
    **When** the full GUT run, `game/tools/check_guards.sh` and the replays run
    **Then** all green; the 3.3 and 3.4 tests and the 3.4 replay expectations hold for single-ring fights (Groups A-C are byte-identical in behaviour for phases 1-2); counts and every design call are recorded in the Dev Agent Record

18. **Given** the human checks (recorded, do not block `review`)
    **When** played in Chrome and Firefox (`?debug`)
    **Then** the split reads at a glance, the alternating `;` reads as a window switch, Spit is dodgeable with the 20-frame glow, and the fallback 2-phase fight plays (Shift+F6 / F6)

## Scope Boundaries

- In: Nested Loop (once per fight, split), the two-ring body in phase 3, timed `;` openings and alternation, per-ring weak windows, `;` Spit with its projectile pool, Constrict and Head Rush base radius for the split state, the candidate hook, the `RingDef` numbers, the phase-3 fallback cut, presentation of the split, tests and guards.
- Out: duck tells and tutorial beats (3.6); the TELL audio stream (`tell_sfx` stays a placeholder id until 7.2); `PlayerEffects` command types (6.5); Echo / decoy targeting (4.2); defeat reassembly and Harvest (3.8); Boss 1 balance tuning (3.9 playtest); the 3.3 start gate on non-player shifts (Epic 6); cross-platform float determinism (the hashed state is integer, the positions are not hashed; deferred as before).

## Tasks / Subtasks

Ship in order. Groups A-C and Q are the non-phase-3 spine. Group P is the separable phase-3 block: if it is cut, do only the data edit in AC 11 and drop P's tests. Each group ends at a green GUT run.

### Group A — Data and validation (no behaviour change)

- [x] A1. `RingDef`: add `split_outer_segments` 16, `split_inner_segments` 8, `split_inner_speed_percent` 150, `opening_period_frames` 180, `spit_period_frames` 360, `spit_tell_frames` 20, `spit_tps` 6, `spit_slots` 16. `validate()` checks them (AC 12). The single-ring 24 / 8 / 12 / 5 / 2 rules are unchanged.
- [x] A2. Create `game/data/bosses/infinite_loop/attack_nested_loop.tres` (`AttackDef`, AC 1) pointing at `nested_loop.gd` (created in P1).
- [x] A3. `ring_def.tres`: the new numbers. `test_data_validation.gd`: the new field rules.

### Group B — Candidate hook in the framework (no behaviour change)

- [x] B1. `BossController`: virtual `_pick_candidates(phase: int) -> PackedInt32Array` (default: the phase pool, as today). `pick_next` draws from the candidates instead of the pool: the one-candidate rule (no RNG, D-S34-3) and the no-triple-repeat rule are unchanged, and they now use the candidate list. `_advance` enters TELL only when the candidate list is non-empty (an empty list keeps the GAP behaviour of D-S33-9).
- [x] B2. Tests: default candidates equal the pool for every phase; 3.1 pick tests and the 3.4 replay stay green unchanged.

### Group C — Two-ring body, single-ring behaviour unchanged (no behaviour change)

- [x] C1. `InfiniteLoopBody`: the existing fields (`travel_mtiles`, `travel_rem`, `speed_mtps`, `_units`) are the OUTER ring. Add `split: bool`, `inner_travel_mtiles`, `inner_travel_rem`, `_inner_units`, `next_ring: int` (0 outer, 1 inner), `ring_timer: int`, `open_ring: int` (-1 none). Helpers: `outer_segments()` (24 until split, then `split_outer_segments`), `outer_radius_mtiles()` and `nominal_radius_mtiles()` (from the outer segment count, so the single-ring value stays 3820), `nominal_radius_px()`.
- [x] C2. `semicolon_px()`, `overlaps_shape`, `hit_position`, `is_open()`: ring-aware through `open_ring` (outer junction when none is open). `segment_px(k)` stays the outer ring; add `inner_segment_px(k)`.
- [x] C3. `touches_player`: loop over both rings' segments (inner ring empty until split); the Constrict disc still replaces them (D-S34-7).
- [x] C4. Tests: the 3.3 and 3.4 ring tests and the 3.4 replay hashes unchanged in phases 1-2. The new fields reset in `reset_for_fight` (`split = false`).

### Group P — Phase 3 (droppable block)

- [x] P1. `game/src/bosses/infinite_loop/attacks/nested_loop.gd` (`extends BossAttack`): `on_tell` / `on_active` do nothing to the ring (the body flashes on presentation); `on_recovery` asks the body to split (`body.split_rings()`, idempotent). `on_cancel` does nothing (a cut before the split leaves the ring whole). Body `_pick_candidates(2)` returns `[nested_loop]` for the first phase-3 pick while `nested_done` is false, then the pool minus `nested_loop` (D-S35-3). `nested_done` is set when `nested_loop` is picked and reset in `reset_for_fight`.
- [x] P2. `split_rings()`: `split = true`, outer reset to 16 segments with the same lap position, inner created at travel 0, concentric; the body centre is re-clamped with the outer radius; `open_ring = 0` and `iteration` + 1 with `open_left = open_frames` (the first opening, D-S35-6); `ring_timer = opening_period_frames`; `next_ring = 1`.
- [x] P3. Speeds (D-S35-5): outer lap start ramps as in 3.3 (no opening there in split mode); inner speed is `min(speed_mtps * 150 / 100, speed_cap * 1000)` derived per tick, and its `inner_travel` advances with the same remainder rule as the outer ring.
- [x] P4. Timed openings (D-S35-6): in split mode `ring_timer` counts down on each live tick except ROAR, frozen during attack TELL/ACTIVE/RECOVERY; at 0 it opens `next_ring`'s `;` (`open_ring = next_ring`, `open_left = open_frames`, `iteration` + 1), flips `next_ring`, resets to `opening_period_frames`. An attack's recovery opening (`open_semicolon` in split mode) also opens `next_ring`, flips it and resets the timer at its start. At most one `;` open: the period (180) is longer than the longest opening (120) and openings never overlap.
- [x] P5. `current_weak_window()` override (D-S35-7): phase index 2 and `split`: outer → A→D, inner → D→A; phase index 2 before the split and all other phases → `super`.
- [x] P6. Phase-3 Spit (`game/src/bosses/infinite_loop/attacks/semicolon_spit.gd`, RefCounted, not a pool attack, D-S35-8): fixed pool of 16 projectile slots (active, `pos_mtiles: Vector2i`, `step_mtiles: Vector2i`, preallocated), `spit_timer` (360) and `glow` (last 20 ticks). `tick(body, ctx)` called from `_tick_body` in phase 3 on live ticks except ROAR; fire at 0: origin = next ring's junction (outer before the split), aim = `Arena.clamp_to_play_area(ctx.target_position())`, direction unit vector rounded once to integer milli-tile step (100 per tick). Slot freed when its position leaves the play area; `clear()` on phase change and defeat.
- [x] P7. Projectile contact (D-S35-11): `touches_player` also asks every live projectile's 0.5-tile circle (integer position converted once to px). Hits on projectiles do nothing (no `overlaps_shape` path).
- [x] P8. Constrict and Head Rush base radius (AC 10): `constrict.gd` takes its start radius from `body.nominal_radius_mtiles()` instead of the 3820 constant (`radius_for` argument and the tell outline), and its RECOVERY restores the outer nominal radius through the body (`set_attack_radius_mtiles(0)`). Head Rush already uses `nominal_radius_px()`; verify.
- [x] P9. `reset_for_fight`: `split = false`, `nested_done = false`, `next_ring = 0`, `open_ring = -1`, timers and projectiles cleared; phase-3 entry (ROAR end) sets `spit_timer` to 360 and clears projectiles and the glow.
- [x] P10. Fallback (AC 11): a test copies `boss_def.tres` without phase 3 and runs a scripted fight to phase 2's end; no split, no Spit, no per-ring window; `BossDef.validate()` passes.

### Group Q — Presentation, tests, guards, finish

- [x] Q1. `BossView` (reads only, AC 16): both rings' braces, each `;` (open = brightest cell, D-S33-24), Nested Loop body flash (presentation frame parity during TELL), the Spit origin glow (`glow`), projectiles as INK `;`. Pure helper tests for the flash and glow timing.
- [x] Q2. `test_infinite_loop_body.gd` / new `test_infinite_loop_split.gd`: split geometry and concentric centre, clamp inside the play area, inner speed formula, freezes, timed openings alternation (per-ring `;` open counts over 1000 ticks), recovery opening advancing the alternation, weak window per ring for each state transition, hits only on the open `;`.
- [x] Q3. `test_infinite_loop_attacks.gd`: Nested Loop once per fight (AC 2) with a seeded RNG over 1000 picks; Spit cadence, glow length, projectile speed (100 milli-tiles per tick), despawn at the edge, pool-full skip, no RNG draws; Constrict and Head Rush radii in the split state; Constrict ACTIVE and Spit paths inside the play area (AC 15).
- [x] Q4. `test_attack_isolation.gd`: the new files are in the scan (AC 14); `game/tools/check_guards.sh` green.
- [x] Q5. `tests/integration/test_infinite_loop_replay.gd`: extend the scripted FIGHT (3.4 H1) to phase 3 with the choreography of AC 13; record the counts in the Dev Agent Record.
- [x] Q6. Full GUT run (same command as CI, 3.1 Debug Log), `bash game/tools/check_guards.sh`; record counts and every design call. Set `3-5-nested-loop-semicolon-spit-and-phase-3` to `review` on completion (dev-story, not this skill).
- [x] Q7. Human checks I1-I3 (non-blocking, AC 18) recorded in the Dev Agent Record.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S35-1 One story, ordered groups, phase 3 separable.** Groups A-C are behaviour-neutral for phases 1-2 and can ship on their own. Group P is everything that only exists in phase 3, so the MVP fallback (ship phases 1-2) is a data edit (remove the phase-3 entry from `boss_def.tres`; AC 11) and P is then dropped with no code change elsewhere.
- **[design call] D-S35-2 Nested Loop is an attack, not a special case.** It is a `BossAttack` with an `AttackDef`, so the FSM, the tell cue, the attack isolation guard and the replay hash all cover it. Its tell is 40 frames and its ACTIVE is 1 frame with no recovery; the split happens in `on_recovery`, which the FSM calls on every normal completion. A cut before completion (phase change or defeat) does not split.
- **[design call] D-S35-3 Once per fight by candidate list.** `_pick_candidates` is the framework hook (B1). In phase 3 the first pick is `nested_loop` alone (one candidate, no RNG draw, the same rule as the 3.4 one-attack pool); after it fires, `nested_loop` leaves the candidate list for the rest of the fight and the no-triple-repeat rule works on the remaining two. Alternative (rejected): a second `BossDef` pool or a body-side forced pick, which would bypass `pick_next` and its history.
- **[design call] D-S35-4 Ring geometry after the split.** Outer 16 segments (radius 16 / 2π ≈ 2.55 tiles), inner 8 segments (≈ 1.27 tiles), 1 tile per segment, the 0.5-tile contact circle per segment (3.3 D-S33-3). The outer ring keeps the single ring's fields, so the split only changes its segment count and radius. The unsplit ring is 24 segments at 3.82 tiles as before.
- **[design call] D-S35-5 Speeds.** The outer ring ramps +5% per outer lap start, capped at 12 tiles/s, as in 3.3, except that a lap start no longer opens the `;` (the timed schedule does). The inner ring is derived each tick as `min(outer × 150 / 100, 12)`: no ramp state of its own, so it cannot drift from the outer. At the phase-3 speed reset (8 tiles/s) the inner ring runs at 12 tiles/s, the cap.
- **[design call] D-S35-6 Timed openings in phase 3.** One `ring_timer` of 180 ticks (3 s) runs only outside ROAR and outside attacks (frozen like the lap clock, D-S34-5). When it reaches zero, `next_ring`'s `;` opens for 90 ticks, `i` + 1, the alternation flips and the timer restarts. An attack's recovery opening is treated as an opening: it opens `next_ring`, flips the alternation and restarts the timer at its start, so the attack never overlaps a timed opening. The first timed opening is the split itself (outer). With 180 > 120 (Constrict recovery) at most one `;` is open at a time, by construction. Flagged for playtest: attacks pause the cadence, so the 3 s rhythm is only exact when no attack runs.
- **[design call] D-S35-7 Per-ring weak windows.** Phase 3 after the split: the window is the ring that is open, or the ring that opens next. Outer = A→D (`ATTACK` then `DASH`), inner = D→A (`DASH` then `ATTACK`), so a player who keeps a combo ready reads the next window on the glow (D-S35-9). Before the split in phase 3 the data window (A→D) applies, which matches the outer ring. The data `weak_window` of phase 3 stays `(1, 2)`.
- **[design call] D-S35-8 Spit is a timed behaviour, not a pool attack.** Spit fires on a fixed 6 s cycle regardless of the FSM (the epic says "every 6 s"), so it is not drawn from a pool and draws no RNG. It is a plain RefCounted script in `attacks/` (for the isolation guard) that the body ticks; it reads only `ctx.target_position()`. It is not frozen by attacks, so a shot can come during Head Rush or Constrict. It is off outside phase 3.
- **[design call] D-S35-9 Spit cycle and origin.** The cycle is 360 ticks. The `;` glows for the last 20 ticks (the tell) and the projectile leaves at tick 0. The origin is the junction of the ring that opens next (outer before the split), so the glow tells the player which window is coming. Because the cadence is 6 s against 3 s openings, the origin is usually the same ring; accepted for MVP, a playtest check (AC 18).
- **[design call] D-S35-10 Spit pool and speed.** 16 preallocated slots (no allocation in tick). Speed 6 tiles/s = 100 milli-tiles per tick, stored as an integer step: the direction is rounded once at fire time. A projectile is removed when its position leaves the 32×18 play area; there is no lifetime. If no slot is free the shot is skipped (logged in debug builds, not queued).
- **[design call] D-S35-11 Projectile contact.** A projectile hurts through the body's `touches_player` (like the segments and the attack hazards), so the single contact path through `PlayerHealth.queue_hit()` holds (NP-3, D-S34-9). The radius is one glyph cell (0.5 tile, the same as the head). Projectiles are cleared at ROAR and defeat, so nothing hurts during the phase change. Tunnelling: at 0.1 tile per tick against a 0.5-tile radius, a projectile cannot skip the player's centre between ticks.
- **[design call] D-S35-12 Constrict and Head Rush in the split state.** Constrict's start radius is the outer nominal radius (2546 milli-tiles after the split, 3820 before), so the disc shrinks from the current ring to the same 2-tile final radius. The disc replaces every segment (both rings) during ACTIVE, as in 3.4. Head Rush's origin uses the outer nominal radius through `nominal_radius_px()`; the inner ring never blocks the head.
- **[design call] D-S35-13 Data numbers.** All phase-3 numbers live in `RingDef` (3.4 D-S34-8 pattern): the split counts, the 150% ratio, the 180 / 360 / 20 tick periods, the 6 tiles/s speed and the 16 slots. Timings of the Nested Loop attack (40 / 1 / 0) are in `attack_nested_loop.tres`. No attack constant lives in code except the ones the spec fixes (the 2-tile final radius is `constrict_radius_tiles`, unchanged).
- **[design call] D-S35-14 Presentation.** Both rings are drawn with the same INK brace glyphs; the open `;` is the brightest cell (inverted, D-S33-24). The body flashes during the Nested Loop TELL by toggling the ring's draw on the presentation frame parity; the flash is not sim state. The Spit projectile is an INK `;` cell (the palette has INK and BG only, 3.3 D-S33-24). The 3.2 Patched tag and bar can overlap the taller stack of rings: left as is, judged by art (deferred, not folded).
- **[design call] D-S35-15 Phase-3 entry and the timer.** At the phase-3 ROAR end the Spit timer starts at 360 (the first shot is six seconds into phase 3). The split is not part of the phase change: the single ring stays until the Nested Loop completes, so the first phase-3 GAP is the 3.3 ring with the phase-3 gap of 60 ticks.
- **[design call] D-S35-16 Replay and determinism.** RNG: `pick_next` only, on non-forced picks (AC 13). Hashed state: integers only (the list in AC 13). Float positions (rings, projectile position as px for drawing and contact) are not hashed; the step vector is integer, so the only float input to hashed state is the one-time direction rounding at fire. Native vs wasm rounding of that direction is the same deferred risk as 3.3 and 3.4 and is recorded, not solved.

### Replay and determinism checklist

- The hashed set grows (AC 13); the 3.4 expectations for phases 1-2 do not change (AC 17).
- No `delta`, `Timer`, `await` or `Engine.time_scale` in `src/bosses/` (AD-01). The timers are tick counters.
- Attacks and Spit draw no RNG (D-S34-14, D-S35-8). Only `pick_next` on non-forced picks draws.
- No new `EventBus` signal (D-S34-20). The existing `boss_tell_started`, `boss_phase_changed` and hit signals cover the split, the openings (through `boss_hp_changed`-free paths: log lines only, debug builds) and the Spit.

### Existing code this story touches (verified at baseline 690cd79)

- `game/src/bosses/framework/boss_controller.gd`: `pick_next` (B1), `_advance` (TELL entry on the candidate list), `_change_phase` and `_cancel_attack` (projectile clear hook), `current_weak_window()` (overridden in the body, P5).
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`: the single-ring fields become the outer ring (C1); `_tick_body`, `_start_lap` (no opening in split mode, P3), `open_semicolon` (P4), `touches_player` (C3, P7), `overlaps_shape` / `hit_position` / `semicolon_px` (C2), `nominal_radius_mtiles` and `nominal_radius_px` (C1), `reset_for_fight` (P9), `_on_attack_cancelled`.
- `game/src/bosses/infinite_loop/ring_def.gd` and `data/bosses/infinite_loop/ring_def.tres` (A1, A3).
- `game/src/bosses/infinite_loop/attacks/constrict.gd` (P8: the 3820 constant at `on_active` and `outline_circle` / `declared_positions`), `head_rush.gd` (verify only).
- `game/src/bosses/framework/phase_def.gd`, `boss_def.gd`: unchanged (the phase-3 pool is data).
- `game/src/combat/combat_resolver.gd`: reads `boss.current_weak_window()` and `boss.hit_position()`; unchanged.
- `game/src/presentation/boss_view.gd` (Q1).
- Tests: `test_infinite_loop_body.gd`, `test_infinite_loop_attacks.gd`, `test_attack_isolation.gd`, `test_boss_controller.gd` (candidate hook), `test_data_validation.gd`, `tests/integration/test_infinite_loop_replay.gd`.

### Architecture guardrails (must follow)

- AD-06 and the folder layout: attacks and the Spit script in `src/bosses/infinite_loop/attacks/`; data in `data/bosses/infinite_loop/`.
- NP-3: attacks and Spit never call `Player`, `Register`, `PlayerHealth`, `SimClock`; they aim with `ctx.target_position()`; the body alone reads `body_contact_position()`.
- Single writers: HP through `take_hit`; Patched through `WeakWindowTracker`; player HP through `PlayerHealth` (contact via `queue_hit`).
- AD-05: presentation reads, never writes (the flash and the glow are presentation).
- AD-04: circle math only; the projectile contact is a point-in-circle test.
- Typing: static types everywhere, GDScript 2.0, no `await`.
- Logging: `Log.debug` on events only (split, opening, Spit fire, pool-full skip); never per tick.

### Previous story intelligence (3.1 to 3.4 and their reviews)

- 3.3 D-S33-10: the phase-3 window is a placeholder until the per-ring windows; closed here (AC 6).
- 3.3 D-S33-24: the palette has INK and BG only; the open `;` is the inverted cell. Kept.
- 3.3 deferred "the ring is a solid wall to non-invulnerable crossing; fast dashes can tunnel between tick endpoints": judged in playtest G1. The 0.1-tile Spit step does not tunnel (D-S35-11).
- 3.3 deferred "`RingDef.validate` hard-codes GDD constants": the new split fields are validated (AC 12); the existing hard-coded checks are left as they are.
- 3.3 deferred "float trig in ring and hit tests": the new hashed state is integer (AC 13); float positions are not hashed (same deferral).
- 3.3 deferred "Patched tag/bar stack can overlap the ring top and the `;`": the stack is taller with two rings; judged by art (D-S35-14).
- 3.4 deferred "Constrict ACTIVE positions not in declared_positions (AC 13)": folded (AC 15).
- 3.4 deferred "Constrict RECOVERY pop-in and wall-hugging escape": not folded; the split changes the Constrict base radius (AC 10), so the RECOVERY snap is 2546 to 2546 in split state (no snap in phase 3 after the split), the 3820 snap only before it. Recorded for the playtest.
- 3.4 deferred "last-tick contact of Head Rush and Constrict is not checked": not folded.
- 3.4 deferred "test_attack_isolation textual guard": extended to the new files (AC 14), not hardened.
- 3.1 deferred "AC5 off-screen safety tests the separate `declared_positions()`": folded for the new attacks (AC 15).
- 3.1 deferred "`PlayerEffects` silently drops commands": still open; the phase-3 work pushes no commands.
- 3.2 deferred "hit and patch cues share one ShiftSfx player": not folded (audio, 7.2).

### Git intelligence

- `690cd79` (3.4) is the tip; the branch stacks 3.1 to 3.4 (`9a67470`, `9ee2c48`, `e496c80`, `295034f`, `690cd79`).
- The 3.4 change set is the template for the attack folder and the test names (`test_infinite_loop_attacks.gd`, `test_attack_isolation.gd`).

### Latest technical information

- Godot 4.7.2-stable (pinned), GDScript only. `Vector2.from_angle`, `move_toward`, `clampi` and integer `/` (with the warning suppressed) are already in use. No new library, no addon. Context7 `/godotengine/godot-docs/__branch__4.7` for any API doubt (project-context rule).
- GUT 9.6.1 headless CLI as in 3.1 to 3.4.

### Project Context Rules

- Only `SimClock` calls `tick()`. No `delta`, `Timer`, `await`, `Tween` or `Engine.time_scale` in `src/combat/` or `src/bosses/`.
- Boss code in `src/bosses/<boss>/`; shared framework in `src/bosses/framework/`; combat math in `src/combat/`.
- Data: typed `*Def` resources under `data/**/*.tres`; balance numbers in `.tres`, invariants in `RingDef.validate()` or pure static helpers.
- Signals only in `src/autoloads/event_bus.gd`, past tense, typed args (none added here).
- Names: `nested_loop.gd`, `semicolon_spit.gd`, `attack_nested_loop.tres`; frame fields end `_frames` (the timer fields are `_frames` or `_ticks` per 3.3 usage: the body uses `_frames` for counters and `_mtiles` for positions); ids `StringName`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.5: Nested Loop, Semicolon Spit and Phase 3]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.3, 3.4 (ring and attack ACs)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss Design, Boss 1 — Infinite Loop, phase 3, `;` Spit]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-018, D-019, D-022]
- [Source: _bmad-output/game-architecture.md#AD-01, AD-04, AD-05, AD-06, NP-3]
- [Source: _bmad-output/implementation-artifacts/3-3-infinite-loop-body-and-loop-condition.md#Design calls D-S33-1 to D-S33-27]
- [Source: _bmad-output/implementation-artifacts/3-4-head-rush-and-constrict.md#Design calls D-S34-1 to D-S34-30, Dev Agent Record]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-3.1, story-3.2, story-3.3, story-3.4]

## Dev Agent Record

### Agent Model Used

claude opus (Claude Code, gds-dev-story, unattended)

### Debug Log References

- GUT, same command as CI: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import`, then `... --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Baseline at 690cd79: Scripts 61, Tests 763, Passing 763. Final run: Scripts 62, Tests 802, Passing 802, Asserts 30962, `---- All tests passed! ----`, no SCRIPT ERROR / Parse Error / pending / risky (the ERROR/WARN lines in the log are the existing tests' deliberate bad-input logs).
- After Groups A-C (+ the phase-3 pool): 770/770 with the 3.3 and 3.4 tests and the 3.4 replay unchanged, so the single-ring behaviour of phases 1-2 held.
- `bash game/tools/check_guards.sh`: `check_guards: OK`. `src/bosses/` has no `delta`, `Timer`, `await` or `Engine.time_scale`.
- Replays (`tests/integration/test_infinite_loop_replay.gd`, 4 tests): the 3.3 fight, the phase-1 no-RNG check, the 3.4 Head Rush/Constrict fight and the new phase-3 fight (seed 35035, 3000 polls, double Shift+F6 at poll 200) all record, replay from file and match per-tick hashes. `test_replays.gd` and `test_retry_snapshot.gd` untouched and green.

### Completion Notes List

- Group A: `RingDef` gains `split_outer_segments` 16, `split_inner_segments` 8, `split_inner_speed_percent` 150, `opening_period_frames` 180, `spit_period_frames` 360, `spit_tell_frames` 20, `spit_tps` 6, `spit_slots` 16, validated (AC 12) plus the pure `split_radius_tiles(count)`. `attack_nested_loop.tres` (40/1/0, `tell_nested_loop`). `ring_def.tres` carries the numbers. Tests: new field values/defaults and one rejection per field.
- Group B: `BossController._pick_candidates(phase)` (default: the pool, no allocation); `pick_next` draws from it with the unchanged one-candidate (no RNG) and no-triple rules, returns -1 on an empty list; `_advance` enters TELL only with a non-empty list. New `_on_defeated()` hook (called once from `_defeat`) for the projectile clear. Tests in `test_boss_controller.gd` (default = pool for every phase, single candidate without RNG, candidates-only over 1000 picks without triples, empty list keeps GAP, defeat hook once).
- Group C: `InfiniteLoopBody` single-ring fields are the outer ring; new `split`, `inner_travel_mtiles`, `inner_travel_rem`, `_inner_units`, `next_ring`, `open_ring`, `ring_timer`, `nested_done`, `spit`; helpers `outer_segments()`, `nominal_radius_mtiles()` (3820 / 2546), `outer_radius_mtiles()`, `nominal_radius_px()`, `inner_radius_px()`, `inner_speed_mtps()`, `inner_segment_px(k)`, `inner_segment_count()`, `junction_px(ring)`, ring-aware `semicolon_px()` (so `overlaps_shape` / `hit_position` follow the open ring), `touches_player` over both rings. All reset in `reset_for_fight`.
- Group P: `nested_loop.gd` (splits in `on_recovery`, nothing else; `declared_positions` = the body's `split_positions()`); body `_pick_candidates` forces the Nested Loop once (generic: any phase whose pool holds `&"nested_loop"`), `nested_done` set in `_on_attack_started`; `split_rings()` (idempotent, lap angle kept, centre re-clamped, outer opening + timer); inner speed derived per tick; timed openings and recovery openings through `_open_next_ring`; `current_weak_window()` override; `semicolon_spit.gd` (RefCounted, 16 preallocated slots, integer positions/steps, glow = last 20 ticks, pool-full skip with a debug log) ticked from `_tick_body` in phase 3 except ROAR, before the attack freeze; projectile contact in `touches_player` (before the Constrict disc replacement, so projectiles still hurt during Constrict ACTIVE); Spit started at the phase-3 ROAR (`_on_phase_reset`, so its 360 ticks count from the ROAR end) and stopped at every other phase change, defeat and retry. P8: Constrict and Head Rush already read `body.nominal_radius_mtiles()` / `nominal_radius_px()`, which are now split-aware, so the only code change in `constrict.gd` is its header comment; tests confirm 2546 -> 2000 -> 2546 and the Head Rush origin on the 2.55-tile ring. P10: fallback test on a deep copy of the def without phase 3.
- Group Q: `BossView` draws both rings (`_draw_ring_cell`), only the open ring's `;` lit, the Nested Loop TELL blink, an INK frame round the Spit origin while it glows, projectiles as INK `;` cells; pure helpers `nested_telling`, `nested_flash_hidden`, `spit_glow_on`. New `tests/unit/test_infinite_loop_split.gd` (30 tests: data, once-per-fight with 1000 seeded picks, retry, split geometry/clamp/opening, inner speed, laps, freezes, alternation over 1000 ticks, recovery opening, weak windows per state, hits only on the open `;`, both rings as hazards, Spit cadence/glow/speed/edge/pool-full/aim/no RNG/contact/invulnerability/clear, Constrict and Head Rush on the split ring, real positions inside the play area, fallback, presentation helpers and a draw-without-writing test). `test_attack_isolation.gd` lists the two new files and checks the Spit reads only `ctx.target_position()`. Replay hash extended per AC 13 for all scenarios, plus the phase-3 scenario.
- Edit to a 3.4 test (recorded): `test_ring_def_rejects_bad_attack_numbers` accepted `constrict_radius_tiles = 3` ("3 < 3.82"); now 3 is rejected because it is not below the 2.55-tile split outer ring (D-S35-18), so the case accepts 2 and checks 3 gives one message. `test_infinite_loop_boss_def_matches_the_gdd` pool list updated to the 3.5 phase-3 pool.
- Q7 / AC 18 human checks recorded, not run (need a browser; non-blocking): I1 Chrome and Firefox `?debug`: the split reads at a glance and the alternating `;` reads as a window switch; I2 the Spit is dodgeable with the 20-frame glow; I3 the fallback 2-phase fight plays (Shift+F6 / F6) on a def without phase 3.

**New design calls (implementer, unattended):**

- [design call] D-S35-17 Timed openings in a real fight (flag for Tiziano, playtest 3.9): as specified (AC 5, D-S35-6), each attack recovery opening takes the next turn and restarts the 180-tick timer, and the timer is frozen during attacks. With phase 3's 60-tick gap, no 180-tick attack-free stretch ever happens after the split, so in a real fight the alternation runs entirely through the recovery openings (outer/inner alternate every attack) and the timed schedule never fires. Implemented as written; the replay therefore asserts openings on both rings after the split (not timed ones), and the timed schedule is tested with the FSM held in GAP. Alternatives for playtest: do not restart the timer on recovery openings (a timed opening every ~3 cycles), or let the timer run during attacks.
- [design call] D-S35-24 (coordinator), supersedes the AC 5 timer rule (and D-S35-6 / P4 / D-S35-17): the 180-tick opening timer keeps running during attacks (frozen only during ROAR) and recovery openings do NOT restart it. When it expires while a `;` is open, it stays at 0 and the timed opening waits until no `;` is open, then fires (one open at a time). Outer/inner alternation continues across both kinds of opening. Implementation call (review): the wait also covers attack TELL / ACTIVE, so a timed `;` never opens mid-attack (D-S34-22); RECOVERY may fire once its recovery `;` has closed. Integer only; `ring_timer` stays hashed. Finding: in a real fight each attack cycle has exactly one recovery and one timed opening, so they alternate in lockstep (recovery inner, timed outer); the replay asserts timed openings occur (outer ring) and the inner-ring timed opening is covered by a unit test with the FSM held in GAP. Flag for playtest 3.9.
- [design call] D-S35-18 `RingDef.validate` bounds `constrict_radius_tiles` by the smaller of the single ring and the split outer ring (2.55 tiles), in the existing single check, so Constrict never grows when it starts from the split ring.
- [design call] D-S35-19 The inner ring's weak window is the phase data window reversed (`Vector2i(w.y, w.x)`), the outer one the data window, rather than hard-coded Register bits: equal to AC 6's A->D / D->A with the current data, and it keeps the body free of Register.
- [design call] D-S35-20 The Nested Loop is found by id (`&"nested_loop"`) in any phase pool, not by phase index; the Spit and the per-ring window are gated on phase index 2 (`PHASE_3`). The fallback def (no phase 3) never reaches either.
- [design call] D-S35-21 `open_ring` is kept in single-ring mode too (0 while the `;` is open, -1 closed) and hashed; behaviour of phases 1-2 is unchanged.
- [design call] D-S35-22 The Nested Loop blink uses blocks of the TELL countdown (`frames_left`, FLASH_BLOCK 6, like the ROAR flash) instead of the presentation frame parity: read-only, deterministic and testable. The Spit glow is an INK 1-px frame round the origin cell (INK/BG palette; the inverted cell stays reserved for the open `;`).
- [design call] D-S35-23 The Spit moves its projectiles before counting its cycle down, so a new shot sits on the origin on its fire tick and moves from the next; the split changes the outer travel by integer scaling (`travel * 16 / 24`), keeping the lap angle within one milli-tile.

### File List

- `_bmad-output/implementation-artifacts/3-5-nested-loop-semicolon-spit-and-phase-3.md` (modified: status, tasks, Dev Agent Record)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: 3-5 -> review)
- `game/data/bosses/infinite_loop/attack_nested_loop.tres` (new)
- `game/data/bosses/infinite_loop/boss_def.tres` (modified: phase-3 pool)
- `game/data/bosses/infinite_loop/ring_def.tres` (modified: phase-3 numbers)
- `game/src/bosses/framework/boss_controller.gd` (modified: candidate hook, defeat hook)
- `game/src/bosses/infinite_loop/infinite_loop_body.gd` (modified: two rings, split, openings, windows, Spit)
- `game/src/bosses/infinite_loop/ring_def.gd` (modified: new fields and validation)
- `game/src/bosses/infinite_loop/attacks/nested_loop.gd` (+ `.uid`) (new)
- `game/src/bosses/infinite_loop/attacks/semicolon_spit.gd` (+ `.uid`) (new)
- `game/src/bosses/infinite_loop/attacks/constrict.gd` (modified: header comment only)
- `game/src/presentation/boss_view.gd` (modified: split rings, blink, glow, projectiles)
- `game/tests/unit/test_infinite_loop_split.gd` (+ `.uid`) (new)
- `game/tests/unit/test_boss_controller.gd` (modified)
- `game/tests/unit/test_data_validation.gd` (modified)
- `game/tests/unit/test_attack_isolation.gd` (modified)
- `game/tests/integration/test_infinite_loop_replay.gd` (modified)

### Change Log

- 2026-11-09: Story 3.5 created unattended (gds-create-story). Status ready-for-dev. Phase 3 kept in a separable Group P.
- 2026-11-09: Implemented Groups A-C, P and Q (gds-dev-story, unattended). GUT 802/802, check_guards OK. Status review.


### Review Notes (2026-11-09, gds-code-review, Blind Hunter + Edge Case Hunter + Acceptance Auditor in parallel)

- Patched: D-S35-24 timer rule (code, unit tests, replay assertions with an explicit `timed_openings` counter instead of FSM-state classification, stale doc comments); `Constrict.declared_positions` used the pre-split segment count (now `outer_segments()`).
- Deferred (see deferred-work.md): Spit projectile not consumed on hit; ring invisible but lethal in Nested Loop TELL blink; timed opening in GAP cut by the next TELL; timed/recovery lockstep; float-derived Spit state; minor items.
- Dismissed: dead `state != ROAR` branch (defensive), inner speed always at cap (data-tunable), validate hard-coded values, per-pick allocation, textual isolation guard, tunnelling note, split_positions duplication (tested by AC 15 against segment geometry).
