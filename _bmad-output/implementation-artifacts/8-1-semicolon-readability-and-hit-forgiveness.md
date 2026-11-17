---
baseline_commit: fd0c801
---

# Story 8.1: Semicolon Readability and Hit Forgiveness

Status: done

<!-- Created unattended by gds-create-story. Design calls from the Epic 8 brief are D-E8-1..3 (marked [design call] below, as in 3.6); calls this story adds are D-S81-n. Implementer follows them or records a change in Completion Notes. Scope: the Infinite Loop `;` (hurt circle, open/closed cue, countdown), miss feedback on the ring body, and the tests and GDD text that assert the old numbers. No new duck line, no new audio asset, no sim-state change beyond the hurt radius. -->

## Story

As a first-time player,
I want to see at a glance when the `;` is hittable and where it is, and to get told when my hit missed,
so that near-misses count and I can tell what I did wrong instead of guessing.

**Requirements:** Epic 8 brief, playtest finding 2 ("hard to consistently hit", "is it vulnerable after it fires? when the `;` is highlighted? do I have to hit it from the inside?"); D-E8-1, D-E8-2, D-E8-3; AD-05 (presentation reads, never writes sim); D-S33-4 (the `;` is the only hurtbox, superseded in radius only); D-S33-5 (a miss never marks the action); D-S33-14 (`hit_position`); D-S28-4 and D-S32-18 (log line formats, resisted lines dithered); NFR (determinism, replay hashes).

## Acceptance Criteria

1. **Given** `data/bosses/infinite_loop/ring_def.tres` **When** the tuning is applied **Then** `hurt_radius_tiles` is 1.0 (was 0.5) for both rings, the default in `ring_def.gd` matches, `contact_radius_tiles` stays 0.5, and `RingDef.validate()` still passes. [design call] D-E8-1.

2. **Given** the `;` is open and a player hit overlaps its hurt circle **When** the hit resolves **Then** damage, Patched rules, hit-stop, the hit log line and the hit particles are exactly as today. Only the circle is larger.

3. **Given** the `;` is open **When** the ring is drawn **Then** the open `;` keeps its inverted cell and gains an INK marker on the inner side of the ring (a pointer toward the `;`, inside the ring's existing footprint, D-S81-1), and a small countdown bar, also inside the footprint, shows `open_left / open_frames` (presentation only, AD-05). [design call] D-E8-2.

4. **Given** the `;` is closed **When** the ring is drawn **Then** the `;` is the plain glyph with no marker and no bar, so closed and open differ at a glance, and the marker and bar never draw while closed or after DEFEATED.

5. **Given** a damaging action (a slash, a dash strike, a combo, not a PASS_THROUGH Echo Dash) whose hit shape overlaps a ring body segment (outer or inner, circle of `contact_radius_tiles`) and does not land on the open `;` **When** the action's last active frame resolves without any landed hit **Then** exactly one miss event is emitted for that action, and the log gets exactly one line: `// miss: ";" is closed` when the `;` is closed, or `// miss: aim for the ";"` when it is open but missed (D-S81-2). The line is dithered like the resisted line. [design call] D-E8-3.

6. **Given** the miss event **When** it is handled **Then** a small deflect particle burst (3 particles, D-S81-6) is placed at the contact point and the existing `hit_resisted` cue plays (no new audio asset). Both are presentation; they never write sim state.

7. **Given** a damaging action that overlaps nothing (empty space, the arena, the player's own body) **When** it resolves **Then** there is no miss line, no particle and no SFX. The Null Pointer whiff stun path (`_check_whiff`) is unchanged.

8. **Given** the Infinite Loop is DEFEATED or in ROAR **When** an action overlaps the body **Then** no miss feedback is produced (the body is not a target then).

9. **Given** the miss path **When** a replay runs twice with the same seed **Then** the per-tick hash in `test_infinite_loop_replay` and `test_replays` still matches; the miss event and its signal add no hash input, no RNG draw and no hit-stop. The hurt radius change is the only sim-visible change.

10. **Given** the tests **When** the full GUT suite runs locally and in CI **Then** all pass. Assertions that hard-code 0.5 tile for the hurt circle (`test_data_validation.gd:383`, `test_infinite_loop_body.gd` `test_only_the_open_semicolon_overlaps_a_hit`) are updated to 1.0, and each AC above has a unit test.

## Scope Boundaries

- In: the ring's hurt radius (data), the open and closed `;` cue and countdown (`boss_view.gd`), the miss detection and event (`infinite_loop_body.gd`, `boss_controller.gd` default, `combat_resolver.gd`), the signal (`event_bus.gd`), the log line (`log_panel.gd`), the deflect particle, the GDD and decision-log text, and the tests.
- Out: the guided tutorial and the tutorial dummy (Story 8.2), any new duck line, any new SFX or sprite asset, any change to Patched, damage or the weak-window rules, any change to other bosses' hit rules (Null Pointer, Segfault, practice target keep their current behaviour), the `;` Spit projectiles (they are hazards, not hurtboxes).

## Tasks / Subtasks

### Group A: Data (hurt radius)

- [x] A1. `game/data/bosses/infinite_loop/ring_def.tres` line 14: `hurt_radius_tiles = 1.0` (AC 1).
- [x] A2. `game/src/bosses/infinite_loop/ring_def.gd` line 23: default `@export var hurt_radius_tiles: float = 1.0` so the script default matches the data.
- [x] A3. `game/src/bosses/infinite_loop/ring_def.gd` `validate()` (lines ~65-66): unchanged rule (must be > 0). No new rule; do not add a hurt ≥ contact rule (not asked).

### Group B: Body miss detection (pure where possible)

- [x] B1. `game/src/bosses/framework/boss_controller.gd` near `overlaps_shape` (line ~383): add the virtual hook `func body_overlaps_shape(shape: HitShape, origin: Vector2, facing: Vector2) -> bool: return false` with a comment (Story 8.1, D-S81-8). The base boss has no ring body to miss.
- [x] B2. `game/src/bosses/infinite_loop/infinite_loop_body.gd`: override `body_overlaps_shape`. Return false unless `state` is not DEFEATED and not ROAR. Otherwise `shape.overlaps(origin, facing, segment_px(k), HitShape.tiles_to_px(ring.contact_radius_tiles))` for each outer segment k, then `inner_segment_px(k)` for each inner segment (after the split). Null shape returns false. Do not change `overlaps_shape` other than through A1.
- [x] B3. `infinite_loop_body.gd`: add `static func open_bar_fraction(open_left: int, open_frames: int) -> float` (pure, clamped to 0..1, 0 when `open_frames <= 0`) for AC 3. It is presentation, so it may live in `boss_view.gd` instead if that reads better; pick one and note it in Completion Notes.
- [x] B4. `game/src/combat/combat_resolver.gd` `tick()` (lines 59-107): on each ACTIVE frame of a damaging, non-PASS_THROUGH action, compute `body_touch = boss.body_overlaps_shape(def.hit_shape, origin, facing)` (only when `boss != null`) and remember the serial in a new `_body_touch_serial` field. Do not change the existing `boss_hit` path. Do not emit here.
- [x] B5. `combat_resolver.gd`: add `_check_miss(def, serial)` called on the action's LAST active frame, next to `_check_whiff`. It emits exactly once when `_body_touch_serial == serial` and `_landed_serial != serial`. It passes `closed = not boss.is_semicolon_hittable()` and the contact position (the first overlapped segment's centre, or the player's origin if the detail is hard to pick; choose the first and record it). D-S81-4 governs the rule. Serial guards exactly as `_check_whiff` uses `_landed_serial`.
- [x] B6. `game/src/autoloads/event_bus.gd`: add `signal hit_missed(target: StringName, closed: bool, pos: Vector2)` next to `hit_landed` (line 21). EventBus holds signals only; no logic.

### Group C: Log line, particle, SFX (presentation listeners)

- [x] C1. `game/src/ui/hud/log_panel.gd`: add `static func line_for_miss(closed: bool) -> String` returning `// miss: ";" is closed` or `// miss: aim for the ";"` (ASCII only, pure). Connect `EventBus.hit_missed` in `_enter_tree` and disconnect in `_exit_tree`, following the existing `hit_landed` pattern (lines 27-42), and call `append_line(line_for_miss(closed), true)`.
- [x] C2. Deflect particle: the particle pool listens to `EventBus.hit_missed` (or the existing listener in `game/src/presentation/juice_director.gd` if that is where hit particles are triggered; check `particle_pool.gd:130-132` and `juice_director.gd:117` first) and calls `spawn(pos, 3)`. The pool stays at the arena origin (`main.gd:148` note), so `pos` is arena-local.
- [x] C3. SFX: `game/src/autoloads/audio_manager.gd` already maps `&"hit_resisted"` (line ~28, CUES). Connect `EventBus.hit_missed` to `play_cue(&"hit_resisted")` through the existing `_on_hit_landed` pattern (line ~118 connect block), with no new `.wav`.

### Group D: Open and closed cue (presentation)

- [x] D1. `game/src/presentation/boss_view.gd` `_draw_ring` (lines ~163-189): after the ring cells, when `open` and not defeated, draw the INK marker on the inner side of the open junction cell (`body.semicolon_px()`), toward the ring centre and inside the ring's footprint (AC 3, D-S81-1). Use `_draw_ring_cell`'s cell size (`GlyphFont.CELL * GLYPH_SCALE`, 16 px). Do not draw when closed, defeated or hidden (the Nested Loop telling blink hides the whole ring: `hidden` must hide the cue too).
- [x] D2. Countdown bar: inside the footprint next to the marker (D-S81-7), INK fill proportional to `open_bar_fraction(body.open_left, body.ring.open_frames)` (outline in INK). Hidden when closed.
- [x] D3. Closed `;`: no change to the glyph (`SEMICOLON` plain, as today, D-S33-24). Add a test that the closed state draws no marker (via a pure predicate `static func semicolon_cue_on(body) -> bool` that the draw code and the test both use).
- [x] D4. Confirm the marker does not clash with the `i = N` counter, the Patched stack (`_draw_patched`) or the Spit origin glow (`spit_glow_on`); if it does, the Patched stack wins (record in Completion Notes).

### Group E: Tests

- [x] E1. `game/tests/unit/test_data_validation.gd` line 383: `assert_eq(ring.hurt_radius_tiles, 1.0)`. Keep the negative case at line 390 as is.
- [x] E2. `game/tests/unit/test_infinite_loop_body.gd` `test_only_the_open_semicolon_overlaps_a_hit` (lines ~297-313): the assertion at 305 (`0.5 tile + 0.25`, offset 11.9 px) now needs the 1.0-tile radius: inside at `Vector2(0, 19.9)` (16 px + 4 px circle), outside at `Vector2(0, 20.5)`. Update the message text.
- [x] E3. `test_infinite_loop_body.gd` `test_drift_is_clamped_inside_the_play_area` (lines ~233-244): unchanged (D-S81-1, coordinator: the clamp and `EDGE_INSET_TILES` stay as is). Instead, add a test that the open cue's geometry stays inside the ring's footprint.
- [x] E4. New tests in `test_infinite_loop_body.gd` (or a new `game/tests/unit/test_semicolon_readability.gd` for the pure helpers, keeping the file-per-story style): `body_overlaps_shape` true on a segment (outer and inner after split), false on the centre and the `;` when closed (the `;` itself is a segment junction, so test the centre-to-segment-edge geometry explicitly), false when DEFEATED and when ROAR; `open_bar_fraction` edges (0, open_frames, over, zero frames); `line_for_miss` both strings, ASCII only.
- [x] E5. `game/tests/unit/test_combat_resolver.gd`: a damaging slash that overlaps a closed body emits exactly one `hit_missed(closed = true)` on the last active frame and no `hit_landed`; open body and a miss emits `closed = false`; an action that lands the `;` emits no miss; a PASS_THROUGH Echo Dash emits no miss; empty-space slash emits nothing; an action whose whiff stun applies (Null Pointer) is unchanged. Use `_landed_serial` and the existing test doubles in that file; the Infinite Loop needs its body set up as the existing tests do.
- [x] E6. `game/tests/unit/test_log_panel.gd`: `line_for_miss` strings, and the miss line is dithered (`dithered_lines()` true for that line).
- [x] E7. Seed: no test in this story draws boss attack picks, but any new replay-style test must seed the RNG (Epic 6 flaky-CI lesson, brief rule).
- [x] E8. Run the existing `tests/integration/test_infinite_loop_replay.gd` and `tests/replays/test_replays.gd` unedited. They must pass (AC 9).
- [x] E9. Run `game/tools/check_guards.sh` (SIM_DIRS include combat and bosses; EventBus emission from combat already exists for `hit_landed`, so the new emit must follow that precedent).

### Group F: GDD and decision log text

- [x] F1. `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`: Boss 1 section (line ~349, "The open `;` is the only damageable point"): add that its hurt circle is 1.0 tile (was 0.5, D-051) and the open cue (inner marker and countdown bar). In Hit Feedback, add one line for the `// miss` log lines and the deflect particle. Keep the GDD's wording style; do not touch unrelated text.
- [x] F2. The decision-log entry D-051 already exists (written with the Epic 8 planning). Do not add a second entry; if the design calls change, edit D-051 and the story's Completion Notes together.
- [x] F3. `epics.md` Story 3.3 text (the 0.5 hurt circle) is a historical record: do not rewrite it. Story 8.1 supersedes it.

### Group G: Finish

- [x] G1. Run the full GUT suite (CI command from `.github/workflows/`, run locally with `/Applications/Godot.app/Contents/MacOS/Godot`, not on PATH) and `check_guards.sh`.
- [x] G2. Set Status to `review` with the Edit tool when done; record every design call taken and the final miss wording in Completion Notes.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-E8-1 Hurt circle 0.5 → 1.0 tile.** Data tuning only, both rings (the body `overlaps_shape` uses `ring.hurt_radius_tiles` for either ring's `;`). Contact radius stays 0.5. Effect: a hit within 1 tile of the junction counts while the `;` is open.
- **[design call] D-E8-2 Open cue, ink-only.** Keep the inverted cell; add an INK marker at the junction (placed per D-S81-1: inner side, inside the footprint); add a countdown bar of the open frames. Palette is INK/BG only; WARN `#FF4040` is reserved for warnings and must not be used.
- **[design call] D-E8-3 Miss feedback on the body.** One log line per damaging action that touches the ring body but does not land on the open `;`, dithered, plus a 3-particle deflect and the existing dull `hit_resisted` cue. No sim change.
- **[design call] coordinator D-S81-1 Marker on the inner side, no clamp change.** The drift clamp (`EDGE_INSET_TILES = 0.5`, D-S33-7) and its tests stay as they are. The open-`;` marker and the countdown bar are drawn on the INNER side of the ring (toward the ring centre), inside the ring's existing footprint, so nothing reaches past `Arena.play_area()` into the HUD frame. (Create-story default of raising the inset to 1 tile was rejected by the coordinator.)
- **[design call] coordinator D-S81-2 Miss wording.** Closed: `// miss: ";" is closed`. Open but missed: `// miss: aim for the ";"`. Both ASCII.
- **[design call] D-S81-3 Body test uses the contact radius.** A ring segment counts as touched when the hit shape overlaps a circle of `contact_radius_tiles` (0.5) around the segment centre, the same circle the player's contact uses. The hurt radius only applies to the `;`.
- **[design call] D-S81-4 One miss per action, only when nothing landed.** Miss is decided on the action's last active frame, like `_check_whiff`: it fires when the body was touched on any active frame of the action and no hit landed on that serial. A hit on the `;` on any frame wins and suppresses the miss. Guards by serial, so no line repeats across ticks.
- **[design call] coordinator D-S81-5 PASS_THROUGH and Echo Dash (accepted).** `tick()` returns before the hit logic for `def.pass_through`; no miss line, no particle, no SFX. Echo Dash's pass-through already has its own Patched path (Story 4.2).
- **[design call] D-S81-6 Deflect particle.** Three particles at the contact point through `ParticlePool.spawn(pos, 3)`. Smaller than the hit burst (`burst_for`, D-S28-2), which is the feel the brief asked for: visible, never a hit.
- **[design call] D-S81-7 Countdown bar geometry.** Inside the ring's footprint, between the `;` and the inner marker, tangent to the ring, INK outline with INK fill proportional to `open_left / open_frames`. Exact pixel placement is free; the fraction function and the footprint bound are the tested parts. (The create-story four-cell bar does not fit inside the ring next to the junction; see Completion Notes.)
- **[design call] D-S81-8 Other bosses unchanged.** `body_overlaps_shape` defaults to false in `BossController`, so Null Pointer, Segfault and the practice target get no miss feedback in this story. A later story may extend it.

### Existing code this story touches (verified at baseline fd0c801)

- `game/data/bosses/infinite_loop/ring_def.tres` line 14: `hurt_radius_tiles = 0.5`; line 13 `contact_radius_tiles = 0.5` (unchanged).
- `game/src/bosses/infinite_loop/ring_def.gd` line 23: `@export var hurt_radius_tiles: float = 0.5`; `validate()` lines ~65-66 (must stay > 0).
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`:
  - `overlaps_shape` (~line 402): returns false unless `is_semicolon_hittable()`; else `shape.overlaps(origin, facing, semicolon_px(), HitShape.tiles_to_px(ring.hurt_radius_tiles))`.
  - `hit_position` (~409): the `;` while open, the centre otherwise (D-S33-14, used by `_resolve_boss_hit` for the hit position).
  - `touches_player` (~line 420s): contact per outer and inner segment, `contact_radius_tiles`; not changed.
  - `is_semicolon_hittable()`, `is_open()` (`open_left > 0`), `semicolon_px()`, `junction_px(r)`, `segment_px(k)`, `inner_segment_px(k)`, `inner_segment_count()`, `radius_px()`, `clamp_centre` (static, uses `EDGE_INSET_TILES`, line ~38 region). `open_left`, `open_ring`, `split`, `state`, `ring` are public.
  - Story 3.5 split: `_inner_units` exists only after the split; `body_overlaps_shape` must loop `inner_segment_count()` (0 before the split).
- `game/src/bosses/framework/boss_controller.gd` line ~383: base `overlaps_shape` (virtual, used by the resolver through `boss_overlapped`). Add `body_overlaps_shape` next to it with the same virtual-hook comment style (Story 3.3 block).
- `game/src/combat/combat_resolver.gd`:
  - `tick()` (lines 59-107): PASS_THROUGH early return; `hits_for` for practice targets; `boss_overlapped` for the boss; `decoy_hit`; `if hit.is_empty() and not boss_hit and dispelled == 0: _check_whiff(...)` then return. Miss logic goes beside this, not inside the landed branch.
  - `_check_whiff` (~line 134): Null Pointer stun, `_landed_serial` guard. Model `_check_miss` on it.
  - `_resolve_boss_hit` (~162): interactions, Patched, damage, `boss.hit_position()`, `hit_landed` emit. Not changed.
  - `boss_overlapped` (~218): static, pure, delegates to `p_boss.overlaps_shape`.
- `game/src/autoloads/event_bus.gd` line 21: `signal hit_landed(target, damage, state, is_combo, pos)`. Add `hit_missed` next to it.
- `game/src/ui/hud/log_panel.gd`: `line_for_damage` (lines ~84-92, pure, `// resisted` format), `line_for_player_hit` (~95), `_enter_tree`/`_exit_tree` connect pattern (lines 27-42), `_on_hit_landed` (~114) appends with dither = UNPATCHED. Add `line_for_miss` and `_on_hit_missed`.
- `game/src/presentation/boss_view.gd`: header comment block (Story 3.3 D1, 3.5 Q1, 3.4 G1); `_draw_ring` (lines ~163-189) with `open`, `hidden` (Nested Loop telling blink), `defeated`; `_draw_ring_cell` (~373); `SEMICOLON` glyph; `spit_glow_on` (~492); `_draw_patched` (~420). Presentation only (AD-05).
- `game/src/presentation/particle_pool.gd`: `spawn(at, count)` (line ~70), `burst_for` (~132, hit burst sizes). `main.gd:148`: pool at arena origin, so positions are arena-local.
- `game/src/autoloads/audio_manager.gd`: `hit_resisted` in the cue map (line ~28), `play_cue(id)` (line ~359, locked-audio safe), `_on_hit_landed` (line ~316, state-dependent `hit_resisted`) and its connect block (~118).
- `game/src/core/palette.gd`: INK and BG; no new colour.
- `game/src/arena/` or `game/src/core/glyph_font.gd`: `GlyphFont.CELL` (8 px) and `GLYPH_SCALE` (2 in boss_view) give a 16 px cell = 1 tile.

### Tests that assert the current numbers

- `game/tests/unit/test_data_validation.gd:383` asserts `hurt_radius_tiles == 0.5` (E1).
- `game/tests/unit/test_infinite_loop_body.gd:297-313` `test_only_the_open_semicolon_overlaps_a_hit`: the `0.5 tile + 0.25` probe at offset 11.9 px (E2).
- `game/tests/unit/test_infinite_loop_body.gd:233-244` `test_drift_is_clamped_inside_the_play_area` and the `clamp_centre` assertions use `0.5 * TILE` (E3, follows D-S81-1).
- `game/tests/unit/test_infinite_loop_body.gd:253-254` contact tests use the 0.5 contact radius (unchanged, do not edit).
- `game/tests/integration/test_infinite_loop_replay.gd` and `game/tests/replays/test_replays.gd`: same-binary double-run hash equality (not stored hashes), so the radius change should not break them; they must pass unedited (E8).

### Architecture guardrails (must follow)

- AD-05: the boss view and log line only read; the miss signal is emitted by the resolver after its sim decision and carries no sim state.
- D-S33-5 / D-S33-14: a miss never marks the action (no `mark_hit`), and `hit_position` is unchanged.
- No new RNG draw, no hit-stop, no new sim field that is hashed. The miss path keeps `_body_touch_serial` as a local resolver field, not in the boss.
- EventBus holds signals only. Logic lives in the listeners.
- Balance values stay in `.tres` (hurt radius); presentation constants (marker size, particle count, bar width) are named `const`s in the presentation file (D-S36-13 precedent).

### Previous story intelligence (3.3, 3.4, 3.5, 2.8)

- 3.3 wrote the `;` as the only hurtbox with `overlaps_shape`; this story keeps that contract and changes only the radius and adds a body query beside it.
- 2.8 and 3.2 set the log line and dither precedent (`dithered` for UNPATCHED / resisted). Reuse, do not invent a new dither.
- 3.5 added the inner ring; `body_overlaps_shape` must cover both rings, guarded by `split`.
- Epic 6 lesson: seed any test that draws attack picks (brief rule).

### Project Context Rules

- No project-context.md extraction beyond the brief and the GDD rules above. Game is Godot 4 GDScript; run Godot from `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- Set story status with the Edit tool, not `sed -i`.
- Never commit to main; this worktree branch is `story/8-1-semicolon-readability-and-hit-forgiveness`.

### References

- Epic 8 brief (scratchpad): `/private/tmp/claude-501/-Users-tizianobasile-workspace-me-github-gameoff-2026/f61681b3-9148-4004-84a7-86d84f801a65/scratchpad/epic8-brief.md`
- `_bmad-output/planning-artifacts/epics.md` → Epic 8 → Story 8.1 (ACs above derive from it)
- GDD `gdd-github-gameoff-2026-2026-11-06/gdd.md` → Boss 1 Infinite Loop (line ~348-349), Hit Feedback
- GDD decision log D-051 (Epic 8 summary), D-S33-4 (hurtbox), D-S33-5, D-S33-14, D-S33-7, D-S28-4, D-S32-18, D-S36-13

## Open Questions and Spec Notes (resolved by the coordinator, 2026-11-17)

1. **Open-miss wording** (D-S81-2): resolved, `// miss: aim for the ";"`.
2. **Marker vs the play area** (D-S81-1): resolved, the marker and the bar are drawn inside the ring's footprint; the clamp (D-S33-7) is unchanged.
3. **Epic 8 window**: Nov 17–25 accepted; the "proposal" wording was removed from epics.md, sprint-status.yaml and D-051.
4. **Story 3.3 text still says 0.5 tile** in `epics.md` and in the 3-3 story file: kept as history; the GDD Boss 1 text gets the new 1.0-tile value.
5. **Echo Dash on the body**: no miss feedback for PASS_THROUGH, accepted.

## Dev Agent Record

### Agent Model Used

claude-opus-5-5 (gds-dev-story, unattended, 2026-11-17)

### Debug Log References

- Baseline at fd0c801 + planning edits: GUT 121 scripts / 1770 tests, all passing.
- RED: 11 failing tests + 1 script parse error (missing `hit_missed`, `line_for_miss`, `semicolon_cue_on`, `open_cue_*`; 0.5 vs 1.0 asserts).
- GREEN: GUT run like CI (`--headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`, no failure markers): 122 scripts / 1793 tests / 146607 asserts, all passed. `game/tools/check_guards.sh`: OK. `test_infinite_loop_replay` and `test_replays` pass unedited.

### Completion Notes List

- Story created unattended (gds-create-story) on 2026-11-17 from baseline fd0c801. Design calls D-E8-1..3 taken as briefed; D-S81-1..8 recorded above.
- Coordinator decisions applied before implementation (marked "[design call] coordinator"): D-S81-1 marker on the inner side, no clamp change (E3 became "clamp test unchanged + footprint test"); D-S81-2 wording `// miss: ";" is closed` / `// miss: aim for the ";"`; D-S81-5 Echo Dash no miss accepted; Epic 8 window accepted (the "proposal / to confirm" wording removed from epics.md, sprint-status.yaml and D-051). epics.md Story 8.1 ACs and D-051 synced to the inner marker and the final wording.
- A (AC 1): `hurt_radius_tiles = 1.0` in `ring_def.tres` and as the `RingDef` default; `contact_radius_tiles` 0.5; `validate()` unchanged.
- B (AC 5, 7, 8): `BossController` gets three read-only virtual hooks: `body_touch_px(shape, origin, facing) -> Vector2` (Vector2.INF = no touch), `body_overlaps_shape(...) -> bool` (built on it) and `weak_point_open() -> bool` (default false). `InfiniteLoopBody` overrides `body_touch_px` (outer then inner segments, contact circle 0.5 tile, nothing unless `is_hittable()`, so ROAR / DEFEATED / inactive give nothing) and `weak_point_open()` (= `is_semicolon_hittable()`). Deviation from B5's wording: `closed` comes from the virtual `weak_point_open()` instead of calling `is_semicolon_hittable()` on a BossController (which does not have it), and it is "closed on every touched frame" (an action that touched the body while the `;` was open on any frame gets the "aim for" line). Contact position = the first touched segment's centre on the first touched frame.
- B (resolver, D-S81-4): `_note_body_touch` runs on every ACTIVE frame of a non-PASS_THROUGH action (after the decoy query, before the landed/whiff branch); `_check_miss` runs beside `_check_whiff` on the last ACTIVE frame (`action_frame == startup + active`) and emits `EventBus.hit_missed(&"boss", closed, pos)` once when the body was touched and `_landed_serial != serial`. The bookkeeping (`_body_touch_serial/_px/_open`) is resolver-local, not hashed; no RNG, no hit-stop, no `mark_hit`. An action cut before its last ACTIVE frame gives no miss line (same rule as the whiff).
- B3: `open_bar_fraction` lives in `BossView` (presentation), not in the body.
- C (AC 5, 6): `LogPanel.line_for_miss` + dithered append on `hit_missed`; `ParticlePool.DEFLECT_BURST = 3` spawned at the contact point; `AudioManager` plays the existing `hit_resisted` cue on `hit_missed` (no new asset; locked audio stays silent).
- D (AC 3, 4, D-S81-1, D-S81-7): `BossView.semicolon_cue_on(body)` (hittable and not hidden by the Nested Loop blink) gates `_draw_open_cue`: a tangent countdown bar 12 px inside the `;` centre (16 px long, 2 px fill, 1 px INK outline) and a filled INK triangle 15-21 px inside pointing at the `;`, both clamped never to pass the ring centre (so the 8-segment inner ring works too). Pure geometry in `open_cue_marker` / `open_cue_bar`; a test checks every point stays within the ring radius for both ring sizes and 16 junction angles. D-S81-7 changed: the bar is one cell long, not four (four cells do not fit inside the ring next to the junction). Closed `;` glyph unchanged.
- D4 overlaps: the cue is drawn after the `i = N` counter and before the Patched stack, so the Patched stack wins. When the open `;` passes the top of the outer ring, the triangle can briefly overlap the 1x `i = N` counter (counter at 1.5 tiles inside the top, triangle base at 21 px); accepted, the cue wins over the counter for those frames. The Spit glow frame is drawn around the Spit origin cell itself, so it does not clash with the inner cue. Not checked visually in a running build (headless only).
- F: GDD Boss 1 gets the 1.0-tile hurt circle and the open cue; Hit Feedback gets a "Miss on a boss body" row. Story 3.3 text in epics.md / the 3-3 story left as history. itch-page-copy.md and README.md have no "how to play" section (only Controls), so no sentence was added (brief: only if such a section exists).
- Tests: new `test_semicolon_readability.gd` (11 tests: data, 1-tile reach from both sides, body query outer/inner/closed `;`/ROAR/DEFEATED, base boss defaults, bar fraction edges, cue predicate, cue footprint geometry, miss line wording/ASCII/width, dithered log line + disconnect, 3-particle deflect, resisted cue); `test_combat_resolver.gd` +8 (closed miss once on the last active frame at a segment centre, open miss, landed `;` suppresses, solo slash miss with no stun, empty space, ROAR, plain boss far/hit); `test_echo_dash.gd` +1 (PASS_THROUGH over the body: no miss); updated `test_data_validation.gd` (1.0) and `test_infinite_loop_body.gd` probe (19.9 in / 20.5 out). No new test draws boss attack picks (no seeding needed; the resolver tests never tick the boss FSM).

### File List

- `_bmad-output/implementation-artifacts/8-1-semicolon-readability-and-hit-forgiveness.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (Epic 8 entries, window accepted, 8-1 status)
- `_bmad-output/planning-artifacts/epics.md` (Epic 8 added; 8.1 ACs synced with the coordinator decisions)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md` (D-051)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` (Boss 1 hurt circle and cue, Hit Feedback miss row)
- `game/data/bosses/infinite_loop/ring_def.tres`
- `game/src/bosses/infinite_loop/ring_def.gd`
- `game/src/bosses/framework/boss_controller.gd`
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`
- `game/src/combat/combat_resolver.gd`
- `game/src/autoloads/event_bus.gd`
- `game/src/autoloads/audio_manager.gd`
- `game/src/ui/hud/log_panel.gd`
- `game/src/presentation/particle_pool.gd`
- `game/src/presentation/boss_view.gd`
- `game/tests/unit/test_semicolon_readability.gd` (new) and `game/tests/unit/test_semicolon_readability.gd.uid` (new)
- `game/tests/unit/test_combat_resolver.gd`
- `game/tests/unit/test_echo_dash.gd`
- `game/tests/unit/test_data_validation.gd`
- `game/tests/unit/test_infinite_loop_body.gd`

### Change Log

- 2026-11-17: story file created (ready-for-dev).
- 2026-11-17: coordinator decisions applied (D-S81-1 inner marker / no clamp change, D-S81-2 wording, Echo Dash accepted, Epic 8 window accepted).
- 2026-11-17: implemented (hurt circle 1.0 tile, ring body query + miss event, log/particle/SFX listeners, open `;` cue and countdown, GDD sync, tests). Status: review.
- 2026-11-17: code review (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel). Patched: cue vs `i = N` counter overlap and inner-ring cue collapse (cue scales with ring radius). Deferred items in `deferred-work.md`. Dismissed: stale-serial leak (action serials are monotonic), spec departures already recorded (B5 `closed` semantics, 16 px bar). Status: done.
