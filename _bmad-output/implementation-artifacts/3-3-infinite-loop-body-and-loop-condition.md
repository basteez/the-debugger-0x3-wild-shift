---
baseline_commit: e496c80
---

# Story 3.3: Infinite Loop Body and Loop Condition

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S33-n); the implementer follows them or records a change in Completion Notes. Scope is ordered into task groups A-H; ship groups in order and stop at a green build after each group if time runs short. -->

## Story

As a player,
I want to face a spinning ring of braces whose semicolon is the only weak point,
so that the bug behaves like an infinite loop (Pillar 3).

**Requirements:** FR33 (Infinite Loop body), FR34 (Infinite Loop phases: HP, weak windows, gaps; attacks are 3.4); GDD "Boss 1 — Infinite Loop" (form, bug behaviour, spin speed, phase table); D-018 (ring of 24, `;` opens 90 frames once per lap, HP 400); D-033 (P2 weak window D→A, P3 per-ring windows); AD-06 (`BossController` subclass per boss, `ArenaContext`, `BossDef` data); NP-3 (no Player/Register writes from the boss; read-only `shift_count`); AD-01 (sim frames only, integer state for everything that is hashed); AD-05 (presentation reads, never writes); Pillar 2 (visible tell, `;` visibly open) and Pillar 3.
**Epic 3 window:** Nov 11–14 (MVP gate Nov 14). **Depends on:** 3.1 (`BossDef`/`PhaseDef`/`AttackDef`, `BossController` FSM, `ArenaContext`, `EventBus` boss signals, test boss, `Arena._set_test_boss`), 3.2 (`WeakWindowTracker`, `CombatResolver` boss path, `DamageState`, `BossView` tag/bar/number, `LogPanel` damage lines), 2.7 (`HitShape.overlaps`, `DamageCalc`), 2.9 (`PlayerHealth.queue_hit`, `Arena.enter_fight` reset hooks), 2.3 (`Register.shift_serial`, `Register.fight_start_for_boss(0) == [D, A]`).
**Unblocks:** 3.4 (attacks: Head Rush, Constrict, `;` Spit, and the phase attack pools), 3.5 (Nested Loop, per-ring `;` windows, duck tutorial beats, first-shift start), 3.8 (Harvest reads `boss_defeated`), 3.9 (MVP playtest).

## Acceptance Criteria

1. **Given** the Infinite Loop fight starts with the register `[D, A]` (`Register.fight_start_for_boss(0)`)
   **When** the boss spawns
   **Then** it is a closed ring of 24 `{ }` segments, 1 tile each, on a circle of radius 24 / (2π) ≈ 3.82 tiles, with an `i = 0` counter above it
   **And** the ring stays still (no spin, no drift, `;` closed, no contact movement) until the player's first shift after fight start
   **And** the sky comment reads `// TODO: this should terminate` (existing `Hud.SKY`, unchanged).

2. **Given** the ring has started (first shift seen)
   **When** time passes
   **Then** it spins in place at 8 tiles/s (one lap of 24 tiles = exactly 180 ticks at base speed)
   **And** the speed rises by 5% (integer floor, D-S33-2) at each lap start, capped at 12 tiles/s
   **And** the ring centre drifts toward the player's position at 2 tiles/s and stays inside the play area (D-S33-7).

3. **Given** the ring is spinning
   **When** a lap starts (the loop condition passes the junction)
   **Then** the `;` glyph opens for exactly 90 ticks at the junction, travelling with the spin, and `i` increments once per opening (the first opening is at the first tick of spin, so `i` reads 1 then)
   **And** the `;` is closed for the rest of the lap; a closed `;` is not hittable.

4. **Given** the `;` is open and the boss is hittable (not ROAR, not DEFEATED)
   **When** a player hit overlaps the `;` hurt circle (radius 0.5 tile)
   **Then** the hit goes through the existing boss path (weak window, Patched or Unpatched, `DamageCalc`, `take_hit`, `hit_landed`, hit-stop)
   **And** a hit anywhere else on the ring (or on a closed `;`) deals no damage, applies no Patched, requests no hit-stop, emits no `hit_landed` and does not mark the action as having hit the boss (D-S33-5).

5. **Given** the 24 segments
   **When** the player's centre lies inside a segment's contact circle (radius 0.5 tile)
   **Then** the player takes 1 HP contact damage through `PlayerHealth.queue_hit()` (invulnerability honoured)
   **And** contact is live in GAP, TELL, ACTIVE, RECOVERY and ROAR, and off once DEFEATED.

6. **Given** `data/bosses/infinite_loop/boss_def.tres` and `ring_def.tres`
   **When** loaded and validated
   **Then** `boss_id = &"infinite_loop"`, `name_signature = "infiniteLoop"`, `max_hp = 400`, `drop_bit = Register.Bit.LOOP`, `fixed_line = "for (i = 0; i < n; i++) { }"`
   **And** phases: P1 `hp_threshold` 100, weak window A→D, `gap_frames` 120; P2 66, D→A, 90; P3 33, A→D (placeholder, D-S33-10), 60
   **And** the attack pools are empty until 3.4 (D-S33-9) and `BossDef.validate()` accepts that
   **And** `ring_def.tres` carries the ring numbers (segments 24, base speed 8 tiles/s, cap 12, ramp 5%, drift 2 tiles/s, `;` open 90 frames, contact and hurt radius 0.5 tile), validated by `RingDef.validate()`.

7. **Given** HP crosses 66% or 33%
   **When** the phase changes
   **Then** the 60-tick ROAR runs (no `;` hit, body contact live), the ring's speed ramp resets to 8 tiles/s, and the new phase's weak window is the one `current_weak_window()` returns (D-S33-8).

8. **Given** a fight with the Infinite Loop
   **When** the HUD top bar is drawn
   **Then** it reads `void infiniteLoop() // hp 400` with live HP (existing 3.1 header path)
   **And** at 0 HP the boss is defeated (`boss_defeated(&"infinite_loop")`), the ring stops moving and stops touching the player, and the header reads `hp 0` until the next FIGHT (Harvest is 3.8).

9. **Given** a FIGHT entered by a plain route (no debug jump, release or debug build)
   **When** `boss_index` is 0
   **Then** the Infinite Loop is the fight's boss (D-S33-11); `boss_index` 1 and 2 keep the placeholder
   **And** Shift+F3 still gives the framework test boss, which takes precedence.

10. **Given** the determinism rules (D-S33-12)
    **When** the GUT suite runs
    **Then** the Infinite Loop draws nothing from `SimContext.rng` (asserted), the existing replay and retry tests pass unchanged, and a new integration test records a scripted FIGHT with the Infinite Loop, replays it on a fresh clock, and gets the same `sim_frame` and the same hash of the ring's integer state.

11. **Given** the guard scripts (`game/tools/check_guards.sh`)
    **When** they run
    **Then** `src/bosses/` has no `Area2D`, no `delta`, no timers, no `await`, and presentation files do not write sim state. `check_guards: OK`.

## Scope Boundaries

- In: the ring body (motion, `;`, contact, hurt), the `i` counter, the data for the Infinite Loop boss and its ring, the phase table with empty pools, default FIGHT wiring for boss 0, the ring view, and the framework hooks it needs.
- Out: attacks of any kind (Head Rush, Constrict, `;` Spit, Nested Loop) — 3.4 and 3.5; the duck tutorial and first-shift timing — 3.5; defeat reassembly, Harvest and LOOP insertion — 3.8; the Nested Loop's second ring and per-ring weak windows — 3.5; `PlayerEffects` command types — 6.5; Echo/decoy targeting — 4.2 and 6.1; audio assets (the tell blip stays a placeholder and no attack fires a tell yet) — 7.2.

## Tasks / Subtasks

Ship in order. Each group ends at a green GUT run.

### Group A — Data and validation

- [x] A1. Add `game/src/bosses/infinite_loop/ring_def.gd` (`class_name RingDef extends Def`) with the exports in AC 6 and `validate()`: `segments == 24`, `base_speed_tps == 8`, `speed_cap_tps == 12` (>= base), `ramp_percent == 5`, `drift_tps == 2`, `open_frames >= 1`, `contact_radius_tiles` and `hurt_radius_tiles` > 0 (D-S33-15).
- [x] A2. Create `game/data/bosses/infinite_loop/ring_def.tres`, `boss_def.tres` (`phases` of 3 `PhaseDef` sub-resources, empty `attack_pool`s, `body_radius_tiles` set to the ring radius for the framework fallback, see D-S33-3).
- [x] A3. Relax the pool rule: `PhaseDef.validate()` requires at least 2 distinct attacks only when `attack_pool` is non-empty (D-S33-9). Update the 3.1 tests that assert the old message, and add the new case.
- [x] A4. `test_data_validation.gd` picks up the new `.tres` files through its glob; add a test that the Infinite Loop boss and ring validate and match AC 6 values.

### Group B — Framework hooks (no visible change)

- [x] B1. `BossController` gets virtual hooks (D-S33-14): `overlaps_shape(shape: HitShape, origin: Vector2, facing: Vector2) -> bool` (default: body circle, the 3.2 behaviour), `hit_position() -> Vector2` (default `body_center_px`), `touches_player(p: Vector2) -> bool` (default: body circle), and `_tick_body(ctx: SimContext)` called from `tick()` after the weak-window tick and before the FSM step (default: nothing). Default behaviour must keep every 3.1/3.2 test green.
- [x] B2. `CombatResolver.boss_overlapped` and `_resolve_boss_hit` use `overlaps_shape` and `hit_position()` instead of the body circle. `hits_for` is unchanged.
- [x] B3. `BossController._advance` in GAP with an empty pool: stay in GAP (re-enter GAP with `gap_frames`), no pick, no RNG draw, no tell, no signal (D-S33-9).
- [x] B4. `ArenaContext` gets `shift_count: Callable` (default returns 0) and a `read_shift_count()` helper, set by `Arena` to `register.shift_serial` (D-S33-6). Read-only.
- [x] B5. `Arena._set_test_boss` becomes a general boss loader: `Arena.enter_fight(fight_start, with_practice, boss_def_path: String = "")`. The path picks the def and the class (`InfiniteLoopBody` for the Infinite Loop def path, plain `BossController` for the test boss). The controller is built once and reused across retries (existing 3.1 pattern); `_remove_boss` on empty path; `combat.boss` and SimClock registration as today.
- [x] B6. `Main`: a function `boss_def_path_for(debug_test_boss: bool, boss_index: int) -> String` (pure, tested): test boss if Shift+F3 (`wants_test_boss()`), else `res://data/bosses/infinite_loop/boss_def.tres` when `boss_index == 0`, else empty (D-S33-11). `Main._attach_boss` guards `boss_view` and `hud` being null and clears the boss on leave (3.1 deferred item).

### Group C — InfiniteLoopBody (`game/src/bosses/infinite_loop/infinite_loop_body.gd`, `class_name InfiniteLoopBody extends BossController`)

- [x] C1. Integer ring state (D-S33-2): `travel_mtiles` (position along the ring in milli-tiles, wraps at 24000), `travel_rem` (0..59 remainder), `speed_mtps` (8000 at reset), `iteration` (i), `open_left` (ticks), `started` (bool), `shift_at_fight_start` (captured in `reset_for_fight`). Position is recomputed from integers each tick for drawing and tests.
- [x] C2. Start gate: `_tick_body` does nothing until `started`. `started` becomes true on the first tick where `ctx`'s shift count (via `ArenaContext`) differs from `shift_at_fight_start` (D-S33-6). Nothing else moves before it.
- [x] C3. Spin: each live tick, `total = travel_rem + speed_mtps`; `travel_mtiles += total / 60`; `travel_rem = total % 60` (integer division, `@warning_ignore("integer_division")` as in `BossController`). When `travel_mtiles >= 24000`: subtract 24000, `iteration += 1`, `open_left = ring.open_frames`, and ramp the speed: `speed_mtps = mini(speed_mtps * 105 / 100, 12000)` (D-S33-2). The first lap start is the first spinning tick (so `i` reads 1 right after the first shift).
- [x] C4. `;` state: `open_left` counts down per live tick; `;` is open while `open_left > 0`. Its position is the junction angle: `angle = travel_mtiles / 1000 / radius_tiles` (float, presentation and hit math only), the same angle the segment layout uses.
- [x] C5. Drift: while `started` and not DEFEATED, move the ring centre toward `ArenaContext.player_position()` by `drift_tps / 60` tiles per tick, never past the player, and clamp the centre so the whole ring (radius + 0.5 tile) stays inside `Arena.play_area()` (D-S33-7). Drift runs in ROAR too.
- [x] C6. Segments: 24 contact circles of `contact_radius_tiles` at the segment angles `junction + 2π k / 24` (k = 0..23), from the current centre. `touches_player(p)` tests all 24 (no allocation: loop over indices, compute with `Vector2.from_angle` or cached unit vectors rebuilt per tick into a preallocated `PackedVector2Array`).
- [x] C7. `overlaps_shape`: false unless `is_hittable()` and `open_left > 0`; otherwise the hurt circle at the `;` (radius `hurt_radius_tiles`) overlapped with the shape. `hit_position()` returns the `;` position while open, the centre otherwise.
- [x] C8. `_on_phase_reset()`: `speed_mtps = base` (the GDD speed-ramp reset). `iteration`, `travel_mtiles` and `open_left` are not reset (the loop keeps going).
- [x] C9. Defeat: `BossController._defeat` sets `active = false`, so `tick` stops; `touches_player` and `overlaps_shape` return false when DEFEATED (AC 8).
- [x] C10. `reset_for_fight()` override: call the base, then zero the ring state, `started = false`, capture `shift_at_fight_start` from the arena's shift count (D-S33-6).
- [x] C11. No attacks: `_attacks` is empty in 3.3 (D-S33-9); the FSM sits in GAP. Assert in tests that no RNG is drawn.

### Group D — Presentation (reads only)

- [x] D1. `BossView` draws the ring when the boss is an `InfiniteLoopBody`: 24 glyph cells at the segment positions (`{` / `}` alternating by index, INK), the `;` at the junction (INK while open, dimmed while closed), the `i = <iteration>` counter above the ring. Presentation may read the body's integer state and positions, never write them.
- [x] D2. Keep the 3.1 jitter (the ring centre offset) and the ROAR flash; the `!` TELL mark is not used in 3.3 (no attacks) and stays for 3.4.
- [x] D3. The `// patched` tag and bar get a top-edge clamp so they never leave the arena (3.2 deferred item). Tests for the clamp (pure helper).
- [x] D4. `LogPanel`: nothing new. Hits on a closed `;` log nothing (no `hit_landed`).

### Group E — Debug and wiring checks

- [x] E1. F6 kill, Shift+F6 next phase, Ctrl+F6 player hit unchanged. Shift+F3 still the test boss; test that Shift+F3 wins over boss_index 0.
- [x] E2. Plain F1 to F5 jumps: FIGHT boss 0 now shows the Infinite Loop. Update any 3.1/2.x test that assumed no boss in a plain FIGHT (`test_arena_player.gd`, `test_main_layers.gd`, `test_hud_layout.gd` as needed). Keep the placeholder header for boss 1 and 2.

### Group F — Tests

- [x] F1. `tests/unit/test_infinite_loop_body.gd`: still until first shift (AC 1); lap = 180 ticks at 8 tiles/s, lap starts counted; speed ramp list over the first 10 laps is exactly `[8000, 8400, 8820, 9261, 9724, 10210, 10720, 11256, 11818, 12000]` (cap on lap 10); `;` open exactly 90 ticks per lap, `iteration` = number of laps; closed `;` not hittable and not hit (AC 4); hit on a segment does nothing and does not mark the action; drift speed 2 tiles/s and the clamp; contact per segment (AC 5); ROAR keeps spinning, no hit; DEFEATED stops everything; phase thresholds 264 → P2, 132 → P3 with `BossController.phase_for_hp` (AC 7); RNG draws zero over 1000 ticks (AC 10).
- [x] F2. `tests/unit/test_combat_resolver.gd`: the boss path through `overlaps_shape`; a `;` hit applies Patched in P1 (A→D Dash Strike) and damage 30; a D→A slash in P2 (link_second) patches; off-`;` hits no-op. Existing 3.2 cases stay green.
- [x] F3. `tests/integration/test_infinite_loop_replay.gd`: scripted session (reuse the `ScriptedInput` pattern from `tests/replays/test_replays.gd`) in a real `Arena` FIGHT with the Infinite Loop; record, replay on a fresh `SimClock`, compare `sim_frame` and a hash of `(travel_mtiles, speed_mtps, iteration, open_left, hp, player HP)` each tick. Assert the hit-stop path was exercised (hits landed on the `;`, or the test asserts it at least once with a scripted hit on the open `;`, using a deterministic player position).
- [x] F4. `test_data_validation.gd` and `test_boss_controller.gd` updated for A3 (pool rule) and the new hooks defaults.
- [x] F5. `test_debug_keys.gd` / `test_main_layers.gd`: `boss_def_path_for` precedence (AC 9).

### Group G — Human checks (recorded, do not block `review`)

- [ ] G1. H1 (Chrome, Firefox, `?debug`): plain F1 into FIGHT shows `void infiniteLoop() // hp 400`, the ring, `i = 0`; the ring stays still until the first shift; the first shift starts the spin and opens the `;` (`i = 1`).
- [ ] G2. H2: a Dash Strike into the open `;` on the A→D window reads `CRITICAL: 30 dmg` (P1); the same hit off the `;` does nothing.
- [ ] G3. H3: release build (no `?debug`): the Infinite Loop is present (supersedes the 3.2 H4 "no boss in release" check, D-S33-11).

### Group H — Finish

- [x] H1. `godot --headless --path game --import`, then the GUT command from the 3.1 Debug Log, then `bash game/tools/check_guards.sh`. All green, no `SCRIPT ERROR` / `Parse Error`.
- [x] H2. Record the test counts, the replay check, and every `[design call]` taken in the Dev Agent Record. Set `sprint-status` for `3-3` to `review`.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S33-1 One story, ordered groups.** Not split, like 3.1 and 3.2 (splitting renumbers 3.4–3.9). Groups A–H are the order of work; A–C alone give a ring with no visible change beyond the boss header.
- **[design call] D-S33-2 Integer ring motion.** Positions are not hashed. The ring's motion state is integer milli-tiles: `travel_mtiles` wraps at 24000 (the circumference: 24 segments of 1 tile, so one lap is 24 tiles). Each tick adds `speed_mtps` to a remainder accumulator divided by 60, so 8 tiles/s is exactly 180 ticks per lap with no drift. The +5% ramp is integer `speed * 105 / 100` floored, applied at each lap start, capped at 12000 (12 tiles/s), so the sequence is `8000, 8400, 8820, 9261, 9724, 10210, 10720, 11256, 11818, 12000`.
- **[design call] D-S33-3 Ring geometry and framework fallback.** Segment `k` sits at `junction + 2π k / 24` on radius `24 / (2π)` ≈ 3.82 tiles. Contact is per segment (`contact_radius_tiles` 0.5 tile, a point-in-circle test on the player centre, D-S31-25: no player radius added). `BossDef.body_radius_tiles` is set to the ring radius only so the framework's fallback body circle is not zero; the Infinite Loop never uses it for contact or hits (`touches_player` and `overlaps_shape` are overridden). Closes the 3.1 deferred item "contact radius vs drawn body size" for this boss.
- **[design call] D-S33-4 The `;` is the only hurtbox.** One circle of 0.5 tile at the junction, open or not. The 3.2 hit rules are unchanged; only `overlaps_shape` and `hit_position` change.
- **[design call] D-S33-5 Off-`;` hits are no-ops.** A hit on a segment or a closed `;` produces no interaction, no Patched, no hit-stop and no `hit_landed`, and does not call `mark_hit`. So a long action (a dash) can still land on the `;` when it opens during the action. This is the existing `boss_overlapped` gate applied to the new shape. Reading "segments are contact hazards only" (epics 3.3) literally.
- **[design call] D-S33-6 Still until the first shift.** The start gate reads the register's `shift_serial` through a read-only `ArenaContext.shift_count` Callable (the D-S31-10 pattern; the boss never holds the Register, NP-3). `reset_for_fight` captures the count; `started` flips on the first tick where it differs. Before that, the ring does not spin, drift, open, or move at all (contact is still checked, which is harmless at the spawn distance of 5 tiles).
- **[design call] D-S33-7 Drift and clamp.** Drift moves the centre toward the player at 2 tiles/s (`2000 mtps / 60` per tick, as a float step), never past the player. The centre is clamped so the ring stays inside `Arena.play_area()`: centre x in `[R + 0.5, 32 - R - 0.5]` tiles, y in `[R + 0.5, 18 - R - 0.5]`. The AC says "drifts toward the player"; the clamp is needed so the ring cannot leave the arena (Pillar 2: no off-screen hazards).
- **[design call] D-S33-8 ROAR and phase change.** The ring keeps spinning and drifting through ROAR (the GDD roar is a glitch, not a freeze); the `;` cannot be hit in ROAR because `is_hittable()` is false (D-S32-9). The speed ramp resets to 8 tiles/s on every phase change (GDD shared rules, `_on_phase_reset`). `iteration` and the lap position continue.
- **[design call] D-S33-9 Empty attack pools until 3.4.** The Infinite Loop has no attacks in 3.3, so its phase pools are empty. `PhaseDef.validate` requires two distinct attacks only when a pool is non-empty (3.1's "at least 2" rule still holds for any real pool). An empty pool leaves the FSM in GAP with no pick, no RNG draw, no tell. 3.4 fills the pools.
- **[design call] D-S33-10 Phase 3 weak window is a placeholder.** P3 uses A→D (the outer ring's window in the GDD). The per-ring windows (outer A→D, inner D→A) need the Nested Loop's second ring, so they arrive in 3.5 through `current_weak_window()` overrides. P3 is reachable in 3.3 by damage; with only one ring, every `;` opening is A→D.
- **[design call] D-S33-11 The Infinite Loop is the boss of FIGHT boss 0 in every build.** The placeholder header for boss 0 is replaced; Shift+F3 keeps the framework test boss and takes precedence. Reason: the boss is the MVP's first real content and 3.5 assumes the fight starts with the boss. Consequence: 3.2's human check H4 ("release build: no boss") is superseded (G3). Boss 1 and 2 keep the placeholder.
- **[design call] D-S33-12 Replay determinism.** (a) The Infinite Loop draws zero RNG in 3.3 (no attacks), so `SimContext.rng` consumption of every other system is unchanged. Asserted in F1. (b) Default FIGHT with boss 0 now changes the simulated outcome (contact damage, `;` hits, hit-stop). Recordings made before 3.3 do not reproduce: nothing committed depends on them (verify no replay JSON is tracked; if one is, regenerate it). (c) `tests/replays/test_replays.gd` uses its own hash system and no arena, so its assertions (live vs replay of the same build) do not change; it stays as is. (d) F3 is the new replay check with the real boss, hashing integer state only; float positions are same-binary only (deferred 2.2 item) and are not hashed. (e) The 2.9 deferred item "retry reseeds the RNG from the wall clock" has no effect in 3.3 (no RNG), and must be fixed before 3.4 adds seeded picks (noted in 3.4's inputs).
- **[design call] D-S33-13 Arena boss loader.** `Arena.enter_fight(fight_start, with_practice, boss_def_path)` replaces `with_test_boss`. The path picks the def and the class. The controller is built once and kept across retries (3.1 pattern, D-S31-18), `reset_for_fight` each entry. `Main.boss_def_path_for` is pure and tested.
- **[design call] D-S33-14 Virtual hooks on `BossController`.** `overlaps_shape`, `hit_position`, `touches_player` and `_tick_body` defaults equal the 3.1/3.2 behaviour, so the test boss, its tests and the replay numbers are unchanged. `CombatResolver` calls only these hooks (it does not know the ring).
- **[design call] D-S33-15 Ring data.** The ring numbers live in `data/bosses/infinite_loop/ring_def.tres` (`RingDef`), per the project rule that balance numbers are in `.tres`. The GDD's fixed facts (24 segments, 90 frames, the cap) are validated by `RingDef.validate()`, not hard-coded in the body.
- **[design call] D-S33-16 Ring rendering.** `BossView` draws the ring from the body's read-only state (segment cells, the `;`, `i = N`). No new scene, no `.tscn` (the architecture's `.tscn` is not required; the view is code-built like the rest of 3.1/3.2). The `;` is INK while open and dimmed while closed (Pillar 2: the open point is visible).
- **[design call] D-S33-17 Defeat.** At 0 HP the body stops (inactive: no movement, no contact, no `;`), keeps its last position, and the header reads `hp 0`. Reassembly into the fixed line and the Harvest are 3.8.
- **[design call] D-S33-18 Spawn position.** The ring centre is at `(16, 4)` tiles, 5 tiles above the player spawn (the same offset rule as `Arena.TEST_BOSS_PX`). The ring's top edge sits about 0.2 tile inside the play area; the whole ring is inside it at spawn (AC 2 clamp applies from the start too).
- **[design call] D-S33-19 Start-of-lap `;` and the first open.** The `;` opens at the first spinning tick (`i` = 1) and then at each lap start. A player who shifts sees the `;` open at once (tutorial beat 2 "hit it when it opens" reads on the first shift). If playtest says the first open is too early, shift the first lap start by one lap in `reset`; not expected.
- **[design call] D-S33-20 Attacks absent means the boss header and the defeat path still work.** No tell cue plays in 3.3 (no tells). `AudioManager` is untouched.

### Replay and determinism checklist (explicit, per the epic pipeline rule)

- Default FIGHT boss 0 is active, so the simulated result of a FIGHT changes. Expected and accepted (D-S33-11, D-S33-12b).
- RNG consumption is unchanged (D-S33-12a); assert it.
- The replay harness (`tests/replays/test_replays.gd`) and the retry snapshot test (`tests/integration/test_retry_snapshot.gd`) must stay green without edits. If one needs an edit, the reason goes in the Completion Notes.
- The new F3 integration test hashes integer ring state only.
- No `delta`, no timers, no `await`, no `Engine.time_scale` in `src/bosses/`. Ring motion runs only in `BossController.tick` through SimClock (AD-01).
- Floats (`Vector2`, angles, drift step) are allowed in the sim for positions (same binary, as Player does); they are never the state that is hashed.

### Existing code this story touches (verified at baseline e496c80)

- `game/src/bosses/framework/boss_controller.gd`: `tick`, `_advance` (GAP picks from `_pools[phase_index]`), `_check_contact` (body circle), `take_hit`, `_change_phase`, `_defeat`, `is_hittable`, `current_weak_window`, `body_radius_px`, `hit_target_id`, `_on_phase_reset`, `phase_for_hp`, `reset_for_fight`. Virtual hooks added in B1.
- `game/src/bosses/framework/phase_def.gd`: `validate()` requires `distinct.size() >= 2` today (A3 changes it to "only when non-empty").
- `game/src/bosses/framework/boss_def.gd`: `validate()` (phases, weak windows, name rules). `is_valid_weak_window` unchanged.
- `game/src/bosses/framework/arena_context.gd`: `target_source`, `player_source`, `player_effects`. `shift_count` added (B4).
- `game/src/combat/combat_resolver.gd`: `_resolve_boss_hit` uses `boss.body_center_px` and `boss.body_radius_px()` through `boss_overlapped`. Switch both to the hooks (B2).
- `game/src/combat/shapes/hit_circle.gd`, `hit_shape.gd`: `overlaps(origin, facing, centre, radius_px)`, `HitShape.tiles_to_px`.
- `game/src/arena/arena.gd`: `enter_fight(fight_start, with_practice, with_test_boss)`, `_set_test_boss`, `_remove_boss`, `leave_fight`, `TEST_BOSS_PX`, `play_area()`, `_make_arena_context()`.
- `game/src/main/main.gd`: `_flow_changed`-driven `enter_fight(fight_start_ring(...), wants_practice(), wants_test_boss())`, `_attach_boss()` (no null guard, B6), `wants_test_boss()`.
- `game/src/register/register.gd`: `enum Bit { ATTACK = 1, DASH = 2, LOOP = 3, NULL_BIT = 4 }`, `shift_serial` (incremented in `shift`), `fight_start_for_boss(0) == [DASH, ATTACK]`, `is_bit`, `glyph_of`.
- `game/src/presentation/boss_view.gd`: `_draw` (single body line), `line_top_left`, `_draw_patched` (tag/bar, no top clamp), `damage_number`, `jitter_offset`, `roar_flash_on`. Ring branch added (D1), tag clamp (D3).
- `game/src/ui/hud/hud.gd` and `hud_frame.gd`: `SKY` (`// TODO: this should terminate`, drawn in the top-left by `HudFrame`), `top_bar_text()` and `boss_header()` (unchanged).
- `game/src/debug/debug_keys.gd`: `JUMPS` (plain F3 is FIGHT boss 1), `boss_map` for Shift+F2 (practice, boss 0) and Shift+F3 (test boss, boss 0), `test_boss_requested`.
- `game/src/autoloads/game.gd`: `BOSS_IDS[0] == &"infinite_loop"`, `LAST_BOSS_INDEX`.
- `game/data/bosses/test_boss/boss_def.tres`: the reference shape for the new `.tres` files.
- `game/tests/unit/test_boss_controller.gd`, `test_combat_resolver.gd`, `test_weak_window.gd`, `test_data_validation.gd`, `test_debug_keys.gd`, `test_main_layers.gd`, `test_arena_player.gd`, `test_hud_layout.gd`, `test_font_coverage.gd`: the regression surface.

### Architecture guardrails (must follow)

- AD-06 / architecture layout: the Infinite Loop body is `src/bosses/infinite_loop/infinite_loop_body.gd`; its attacks go to `src/bosses/infinite_loop/attacks/` in 3.4; data to `data/bosses/infinite_loop/`.
- NP-3: the body never calls `Player` or `Register`. It reads `ArenaContext` only (`player_position()`, `shift_count`), and writes its own state.
- AD-05: presentation (`BossView`, `HudFrame`, `LogPanel`, `JuiceDirector`, `AudioManager`) reads and never writes sim state.
- ADR-02 / AD-04: circle math only, no `Area2D`, no physics body.
- Single writers: boss HP and phase only through `BossController.take_hit`; Patched only through `WeakWindowTracker`; damage only through `DamageCalc.compute`; player HP only through `PlayerHealth`.
- Event rules: no new `EventBus` signal is needed in 3.3. If one is added, it goes in `event_bus.gd`, past tense, typed.
- Typing: static types everywhere; GDScript 2.0 (`@export`, `@onready`, `signal.connect(callable)`), no `await`.
- Logging: `Log.debug` only on events (ring started, phase speed reset), never per tick; `Debug.enabled` guard for string building.

### Previous story intelligence (3.1 and 3.2 reviews)

- 3.1 deferred "contact radius vs drawn body size; tie radius to the drawn size when Boss 1 art lands (3.3)": closed by D-S33-3 and per-segment contact.
- 3.1 deferred "`Main._attach_boss` does not guard `boss_view`/`hud`, and a stale boss stays attached after `leave_fight`": closed by B6.
- 3.1 deferred "`ArenaContext.player_position()` lets an attack bypass `target_position()` by convention": still open; the Infinite Loop uses `player_position()` only for drift and contact, which is correct. The split is 3.4's job before any attack reads the arena.
- 3.1 deferred "`PlayerEffects` silently drops commands": no commands in 3.3; unchanged.
- 3.2 deferred "Patched tag/bar can overlap the TELL mark row and has no top-edge clamp; revisit with art (3.3)": closed by D3.
- 3.2 deferred "Damage number counts presentation frames": unchanged; it is cosmetic.
- 3.2 deferred "A multi-tick action overlapping a boss during ROAR is not marked consumed and could land after ROAR": unchanged by 3.3. With the `;` gate (D-S33-5) a dash overlapping the `;` during ROAR can land when ROAR ends, which is the intended reading of "no damage window in ROAR".
- 3.2 D-S32-14 (Patched persists across phase change): unchanged; the Patched tag stays through the roar.
- 3.2 D-S32-29 (boss hit resolved before practice targets): unchanged.
- 2.9 deferred "Retry reseeds the RNG from the wall clock; the seed is not part of the fight-start snapshot. Revisit with seeded boss patterns (Epic 3)": not used in 3.3 (no RNG); must be done in 3.4 before seeded picks are used for replays. Flagged in D-S33-12e.
- 2.9 deferred "Log panel is hidden in DEAD": unchanged.
- 2.9 deferred "Death transition runs synchronously mid-tick": the ring is not defeated by the player, so no new case; unchanged.
- 2.3 deferred "Register.insert vs buffered shifts ordering": harvest (3.8); unchanged.

### Git intelligence

- `e496c80` Story 3.2 review notes; `9ee2c48` Story 3.2; `9a67470` Story 3.1. Branch `story/3-3-infinite-loop-body-and-loop-condition` is stacked on 3.2.
- Recent `7e2b1be` and `d3b2519` touched `debug/`, `ui/` and `main/`: expect DebugKeys, HUD and Main regression tests to matter in B6, E2.

### Latest technical information

- Godot 4.7.2-stable (pinned), GDScript only. `Vector2.from_angle`, `PackedVector2Array`, `Callable`, `Vector2i` and integer `/` (with the warning suppressed) are standard. No new library, no new addon.
- GUT 9.6.1 headless CLI as in 3.1 and 3.2.
- Context7 `/godotengine/godot-docs/__branch__4.7` for any API doubt (project-context rule).

### Project Context Rules

- Only `SimClock` calls `tick()`. No `delta`, `Timer`, `await`, `Tween` or `Engine.time_scale` in `src/combat/` or `src/bosses/`.
- Boss code in `src/bosses/<boss>/`; shared framework in `src/bosses/framework/`; combat math in `src/combat/`.
- Data: typed `*Def` resources under `data/**/*.tres`, read-only at runtime; balance numbers in `.tres`, invariants in `Const` or pure static helpers.
- Signals only in `src/autoloads/event_bus.gd`, past tense, typed args.
- Names: `ring_def.gd`, `infinite_loop_body.gd`; frame fields end `_frames`; ids `StringName`.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- G1 to G3 above (Chrome, Firefox, `?debug`; release build for G3). The first-shift start and the `;` opening are the items most likely to need a feel change (D-S33-19).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.3: Infinite Loop Body and Loop Condition]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.4, 3.5 (phase windows, `;` openings, ring sizes)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss Design, Boss 1 — Infinite Loop]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-018, D-028, D-033, D-045, D-049]
- [Source: _bmad-output/game-architecture.md#AD-06, NP-3, NP-4, folder layout for bosses/infinite_loop]
- [Source: _bmad-output/implementation-artifacts/3-1-reusable-boss-framework.md#Design calls D-S31-1–27, Review Findings]
- [Source: _bmad-output/implementation-artifacts/3-2-weak-window-patched-and-damage-states.md#Design calls D-S32-1–34, Review Findings]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-2-9, story-3-1, story-3.2]

## Dev Agent Record

### Agent Model Used

claude opus (Claude Opus 5.5, `claude-opus-5-5`), unattended epic pipeline, implementation phase.

### Debug Log References

- Import: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import` (clean).
- GUT (same command as CI): `Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
  Baseline e496c80: 57 scripts, 690 tests, 11503 asserts, all passing. Final: **59 scripts, 724 tests, 724 passing, 12921 asserts, `---- All tests passed! ----`**; no CI failure marker (`SCRIPT ERROR`, `Parse Error`, `Failed to load script`, `[Failed]`, `failing tests`) in the log; no ObjectDB leak warning at exit.
- `bash game/tools/check_guards.sh`: `check_guards: OK`.
- First full run after group A-E: 4 expected failures, all in `test_debug_keys.gd` (they assumed plain F2 = no boss); updated for D-S33-11. One intermediate run leaked 42 ObjectDB instances: a test lambda in `test_combat_resolver.gd` captured the body that holds its own ArenaContext (ref cycle); fixed in the test.
- Replay check (F3): live and replayed runs give the same world-tick count, the same per-tick hash of `(travel_mtiles, travel_rem, speed_mtps, iteration, open_left, boss hp, phase, player hp, started)` over 720 polls, the same boss HP and RNG state; at least one slash lands on the open `;` (log: `boss hit slash_1 dmg=5`) and hit-stop froze world ticks.
- `tests/replays/test_replays.gd` and `tests/integration/test_retry_snapshot.gd` pass with no edit (D-S33-12c). No replay JSON is tracked in the repo (D-S33-12b).

### Completion Notes List

- **Group A.** `RingDef` (`src/bosses/infinite_loop/ring_def.gd`) with the GDD numbers validated; `data/bosses/infinite_loop/ring_def.tres` and `boss_def.tres` (400 HP, `infiniteLoop`, drop LOOP, fixed line, P1 100/A>D/120, P2 66/D>A/90, P3 33/A>D/60, empty pools, `body_radius_tiles` 3.82). `PhaseDef.validate` accepts an empty pool (the "at least 2" rule still applies to any non-empty pool).
- **Group B.** `BossController` virtual hooks `overlaps_shape`, `hit_position`, `touches_player`, `_tick_body` (defaults = 3.1/3.2 body circle; contact goes through `touches_player`); GAP with an empty pool re-enters GAP (no pick, no RNG, no tell). `CombatResolver.boss_overlapped` / `_resolve_boss_hit` use the hooks. `ArenaContext.shift_count` + `read_shift_count()` (Arena binds `register.shift_serial`). `Arena.enter_fight(fight_start, with_practice, boss_def_path)` with `_set_boss` (controller cached per def path, reused across retries, replaced on a different path) and pure `Arena.boss_class_for`. `Main.boss_def_path_for` (pure); `Main._attach_boss` null-safe and detaches the views outside FIGHT.
- **Group C.** `InfiniteLoopBody` exactly as C1-C11: integer spin with remainder (180 ticks per lap at 8 tiles/s), ramp `speed * 105 / 100` capped at 12000 from the ring def, `;` open 90 ticks from each lap start, `i` per opening, drift 2 tiles/s never past the player, centre clamp, 24 contact circles from a preallocated unit-vector array, `;`-only hurtbox while hittable, phase reset of the speed, defeat stops everything, reset captures the shift count.
- **Group D.** `BossView` draws the ring (segments with jitter and ROAR flash, the `;`, the `i = N` counter), keeps the 3.1 line for other bosses; `patched_stack_tops` clamps the Patched tag/bar to the arena top (pure, tested). LogPanel untouched.
- **Group E.** F6 / Shift+F6 / Ctrl+F6 unchanged and tested on the Infinite Loop; Shift+F3 wins over boss 0; plain F2 shows the Infinite Loop; `test_debug_keys.gd` updated (boss 1 used where a test needs "no boss"); release FIGHT boss 0 has the Infinite Loop (test). `test_arena_player.gd`, `test_main_layers.gd`, `test_hud_layout.gd` needed no change.
- **Group F.** New `tests/unit/test_infinite_loop_body.gd` (22 tests), `tests/integration/test_infinite_loop_replay.gd` (2 tests); additions to `test_combat_resolver.gd` (5), `test_data_validation.gd` (3), `test_debug_keys.gd` (2), `test_boss_controller.gd` (empty-pool case).
- **Group G (human checks, not blocking `review`, still open for Tiziano):** G1 plain F1 → FIGHT shows `void infiniteLoop() // hp 400`, ring and `i = 0`, still until the first shift, which starts the spin and lights the `;` (`i = 1`); G2 Dash Strike into the open `;` on A>D reads `CRITICAL: 30 dmg`, off the `;` nothing; G3 release build has the Infinite Loop. Not run here (headless only).
- **Coordinator decision applied:** D-S33-11 confirmed: the Infinite Loop is the boss of FIGHT boss 0 in every build.
- **New design calls taken during implementation:**
  - [design call] D-S33-21 Spawn is clamped. D-S33-18's `(16, 4)` puts the ring's 0.5-tile cells 0.32 tile above the play area, so the spawn goes through the same clamp as drift: the centre starts at `(16, 4.32)` tiles. The bottom segment is then 0.86 tile from the player spawn (no contact at rest).
  - [design call] D-S33-22 No boss in the Shift+F2 practice sandbox. `boss_def_path_for(debug_test_boss, boss_index, practice = false)`: test boss (Shift+F3) > practice (no boss) > boss 0 Infinite Loop > none. A drifting ring would make the dummy unusable for hit tuning.
  - [design call] D-S33-23 The `i = N` counter sits inside the ring, 1.5 tiles below its top, above the centre (scale 1). "Above the ring" leaves the play area whenever the ring is near the top edge (it is at spawn), so the counter is drawn above the centre instead.
  - [design call] D-S33-24 The palette has only INK and BG, so "dimmed while closed" is drawn as: closed `;` = a plain INK glyph like the braces; open `;` = a lit, inverted cell (BG on INK). The open point is the brightest cell on screen (Pillar 2).
  - [design call] D-S33-25 The start tick (the first shift seen) is a lap start with no motion: `i` = 1, `;` open, travel 0; movement begins on the next tick. This is what makes one lap exactly 180 ticks and the ramp list start at 8000.
  - [design call] D-S33-26 F3 runs on the SimClock autoload re-seeded with `begin_fight` and a fresh Arena per run (the Arena registers with the autoload, so a separate `SimClock` instance is not possible without changing the Arena); world-tick deltas are compared because `sim_frame` is monotonic. The test choreography (the same in both runs) places the player on the open `;` and sets its facing before each scripted slash, so the `;` hit and its hit-stop are guaranteed.
  - [design call] D-S33-27 The segment glyphs are drawn `;` (k = 0, the junction), then `}` / `{` alternating (odd / even k), so the ring has 23 braces and the `;` is one of the 24 cells, not an extra glyph on top of a brace.
- **Deviations:** none functional from the ACs; recorded design calls differ from the literal AC wording: D-S33-27 (ring is 23 braces plus the `;` cell), D-S33-23 (counter inside the ring), D-S33-24 (closed `;` not dimmed, palette limit), D-S33-22 (practice sandbox has no boss). F1 asks for drift/clamp/contact/ROAR/defeat/RNG tests; all present. AC 10's "fresh clock" is the re-seeded autoload (D-S33-26).
- **For 3.4:** the 2.9 deferred "retry reseeds the RNG from the wall clock" still must be fixed before seeded picks (D-S33-12e). The body exposes `semicolon_px()`, `segment_px(k)`, `junction_angle()`, `is_open()` for attacks and 3.5's second ring.

### File List

- `game/src/bosses/infinite_loop/ring_def.gd` (new)
- `game/src/bosses/infinite_loop/ring_def.gd.uid` (new)
- `game/src/bosses/infinite_loop/infinite_loop_body.gd` (new)
- `game/src/bosses/infinite_loop/infinite_loop_body.gd.uid` (new)
- `game/data/bosses/infinite_loop/ring_def.tres` (new)
- `game/data/bosses/infinite_loop/boss_def.tres` (new)
- `game/src/bosses/framework/boss_controller.gd` (modified)
- `game/src/bosses/framework/phase_def.gd` (modified)
- `game/src/bosses/framework/arena_context.gd` (modified)
- `game/src/combat/combat_resolver.gd` (modified)
- `game/src/arena/arena.gd` (modified)
- `game/src/main/main.gd` (modified)
- `game/src/presentation/boss_view.gd` (modified)
- `game/tests/unit/test_infinite_loop_body.gd` (new)
- `game/tests/unit/test_infinite_loop_body.gd.uid` (new)
- `game/tests/integration/test_infinite_loop_replay.gd` (new)
- `game/tests/integration/test_infinite_loop_replay.gd.uid` (new)
- `game/tests/unit/test_combat_resolver.gd` (modified)
- `game/tests/unit/test_data_validation.gd` (modified)
- `game/tests/unit/test_debug_keys.gd` (modified)
- `game/tests/unit/test_boss_controller.gd` (modified)
- `_bmad-output/implementation-artifacts/3-3-infinite-loop-body-and-loop-condition.md` (story record)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (3-3 → review)

### Change Log

- 2026-11-09: Story 3.3 implemented (groups A-F, H): Infinite Loop ring body, RingDef and boss data, framework hooks, arena boss loader, default FIGHT boss 0 wiring, ring view, tests incl. the real-boss replay. 690 → 724 GUT tests, all green; check_guards OK. Status → review. Human checks G1-G3 open.

### Review Findings


### Review Notes (code review, 2026-11-09)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). D-S33-11 treated as confirmed.

- Patched: `Arena._remove_boss` now calls `set_active(false)` on the detached controller; gate-tick comment in `InfiniteLoopBody._tick_body` corrected (first lap is one tick longer); Completion Notes "Deviations" line now lists the recorded design calls.
- Deferred (see deferred-work.md): cross-platform float determinism, non-player shift gating, spawn/drift contact tuning (G1 playtest), defeat exit flow (3.8), test brittleness, RingDef/boss_def linkage and validation, empty-pool validation scope.
- Dismissed: orphaned test comment (comment is correct), `_draw_number` zero size, minor log on reset, replay choreography teleports (documented test design D-S33-26).
