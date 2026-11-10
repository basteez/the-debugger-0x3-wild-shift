---
baseline_commit: 5f337a0
---
# Story 4.4: Duck Hint Template

Status: done
<!-- Created unattended by gds-create-story (pipeline, 2026-11-10). Open design questions are marked [design call] with the chosen default (D-S44-n); the implementer follows them or records a change in Completion Notes. Scope: the hint template line "Quack. Weak window: {X→Y}." with its two triggers (Breakpoint once per boss phase; every 3rd death on the same boss, said at the retry), the Infinite Loop phase-3 window rule, the Infinite Loop start nudge (T1 rewrite plus a sim-side auto-start after 5 s without a shift, coordinator request from the 2026-11-10 playtest, 3.9 UX item), and the duck items from deferred-work.md that belong to the hint system (strict beat order, MAX_PENDING drops, pause gate, Breakpoint during DEFEATED). NOT in scope: the 3.7 voice seam items (stop on clear, typewriter ownership, squeak suppression), the Watch tutorial line (5.1/5.5), the Breakpoint tutorial line (5.5), the 3.9 playtest tuning. -->

## Story

As a stuck player,
I want the duck to tell me the current weak window,
so that I'm never lost for more than a few attempts.

**Requirements:** FR46. Additional: GDD Duck (hint system) section, duck line budget D-039 (10 lines, the hint template counts once), D-046 (voice, pre-render contingency), and the coordinator request on the Infinite Loop stillness (deferred-work.md, "Open for the 3.9 playtest", 3.9 UX).

## Acceptance Criteria

**Hint text and window rendering**

1. **Given** the template `Quack. Weak window: {X→Y}.` and a weak window `w` (two bit ids), **When** the hint text is rendered, **Then** `{X→Y}` is the two bit glyphs joined by `→` (for example `Quack. Weak window: D→A.`), built through `Register.glyph_of`. A pure static function does this; no second bit-letter map is added. (Note: `HarvestScreen.window_text` renders `X>Y  name`, not this format; do not reuse it for the hint.)
2. **Given** a test over every phase of the Infinite Loop (and every phase of Null Pointer and Segfault, read from their `BossDef`s), **When** the hint is rendered with `boss.current_weak_window()`, **Then** the text matches that phase's data window. Infinite Loop phase 1 `A→D`, phase 2 `D→A`, phase 3 with the outer ring's `;` open or next `A→D`, and with the inner ring's `;` open or next `D→A` (the override in `InfiniteLoopBody.current_weak_window()`, Story 3.5 P5). The test drives the ring state with `open_ring` and `next_ring`, not with the wall clock.

**Trigger 1: Breakpoint**

3. **Given** `EventBus.breakpoint_started` while a boss is live in FIGHT, **When** the boss's current `(boss_id, phase_index)` has not yet had its hint in this fight attempt, **Then** the hint for `boss.current_weak_window()` is requested through `VoiceService.say` once. A second Breakpoint in the same phase says nothing (D-S44-5).
4. **Given** Breakpoint starts while the boss is DEFEATED (the open 4.3 deferred item), **When** the hint would fire, **Then** nothing is said and the phase is not marked as hinted.

**Trigger 2: 3rd death**

5. **Given** `EventBus.player_died(boss, deaths_on_boss)` with `deaths_on_boss` equal to 3 for the same boss (and every later multiple of 3, D-S44-6), **When** the death is announced, **Then** the window to show is captured at that moment (the boss is still in its death phase), and the hint is said at the start of the retry (`flow_state_changed` DEAD to FIGHT), not at the death itself.
6. **Given** a death that is not a multiple of 3, **When** the retry starts, **Then** no hint is said.
7. **Given** a death captured for the hint and no retry (the player leaves the fight), **When** the flow goes to TITLE, **Then** the captured window is dropped and nothing is said later.

**Duck beats and queue (deferred items folded in)**

8. **Given** the beats T1 to T4 (D-S44-3), **When** each trigger holds in FIGHT of the Infinite Loop, **Then** each beat is requested once per run, in any order: an unfired earlier beat does not block a later one. A test reaches phase 2 with Dash Strike never active and sees T4 requested (T3 is then skipped for good, not blocked). TITLE resets the record; a retry does not.
9. **Given** the duck bubble's queue is full (`MAX_PENDING`), **When** a beat or a hint is due, **Then** it is not requested and not marked as used; it stays due and is requested on a later poll when `DuckBubble` has room (D-S44-4). No beat or hint is ever dropped. A test submits six due items and sees all six shown in order over time.
10. **Given** `SimClock.paused` is true, **When** the director polls, **Then** nothing is requested (fold of the deferred "poll not gated on pause" item, D-S44-9).

**Infinite Loop start nudge (coordinator request, D-S44-1, D-S44-2)**

11. **Given** the T1 line, **When** the Infinite Loop fight starts, **Then** T1 reads "Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review." (D-S44-2). The bubble wraps it inside the duck region (cols 0–11, rows 22–37) without clipping; a test or a debug check confirms the wrapped height fits.
12. **Given** the Infinite Loop fight starts and no register shift happens, **When** 300 sim ticks (5 s at 60 Hz) have passed since fight start, **Then** the ring starts exactly as it does on the first shift (the same `_start_lap(false)` path, the `;` opens, the ring moves from the next tick). The count is in sim state, reset in `reset_for_fight`, runs only while the loop is not started, and never uses `Timer`, `delta` or `await` (D-S44-1).
13. **Given** a shift at any tick before 300, **When** it happens, **Then** the loop starts on that shift exactly as now (the auto-start only adds a path, it does not change the first-shift path). A test covers: no shift for 299 ticks (still), no shift for 300 ticks (started), a shift at tick 10 (started at 10).
14. **Given** the auto-start is sim state, **When** the replay and hash tests run, **Then** they pass. If a recorded replay diverges because a fight that previously sat still now starts at 300 ticks, the replay is re-recorded and the change is written in Completion Notes (not silently).

**Clips, layering and gates**

15. **Given** every hint window that occurs in any boss phase (the set is derived from `Defs` data in the test, not hard-coded), **When** the voice data is checked, **Then** each has a `DuckLineDef` entry, a clip in `duck_clips.tres` (pre-render fallback, D-S44-7) and `test_duck_voice_data.gd` passes. T1's clip is re-rendered.
16. **Given** the new code, **When** it is checked, **Then** signals are declared only in `event_bus.gd` (none new are needed), the sim folders (`bosses/`, `arena/`) do not reference `ui`, `VoiceService` or `DuckDirector`, and `test_duck_isolation.gd` passes. The hint logic lives in `src/ui/duck/` and reads the boss; it writes no sim state (AD-05).
17. **Given** the full GUT suite, **When** run headless (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), **Then** it passes, and the web export still builds within the 30,000,000-byte budget (the clips are already shipped; no new large asset).

## Tasks / Subtasks

### Group A: Pure hint and beat logic (AC: 1, 2, 8)
- [x] `DuckHint` (or static functions on `DuckDirector`): `window_text(w) -> String` and `line_id_for(w) -> StringName` (for example `&"hint_a_d"`), pure, no tree (AC 1)
- [x] Rework `DuckDirector.due_beat` from strict-order to per-beat trigger with a `requested` bitmask (or a small set); keep the pure-static test style (AC 8, D-S44-3)
- [x] Tests: `test_duck_hint.gd` (text for each window, every boss phase, phase-3 ring cases) (AC 1, 2)

### Group B: Director triggers (AC: 3 to 7, 9, 10)
- [x] Subscribe to `EventBus.breakpoint_started` and `EventBus.player_died` in `_enter_tree` (same pattern as `flow_state_changed`); disconnect in `_exit_tree` (AC 3, 5)
- [x] Per-attempt record of hinted `(boss_id, phase_index)`, cleared at fight start (AC 3, D-S44-5)
- [x] Death: on `deaths_on_boss % 3 == 0` capture the window and the boss id; say it on DEAD to FIGHT; clear on TITLE (AC 5 to 7)
- [x] Breakpoint: skip when the boss state is DEFEATED (AC 4)
- [x] Gate `poll()` on `SimClock.paused` (AC 10)

### Group C: Queue room (AC: 9)
- [x] `DuckBubble`: a read-only `has_room() -> bool` (queue below `MAX_PENDING`, and the bubble idle or not full); the director requests only when true (AC 9, D-S44-4)
- [x] Test with six due items: all six shown in order (AC 9)

### Group D: Infinite Loop start nudge (AC: 11 to 14)
- [x] `InfiniteLoopBody`: `START_NUDGE_TICKS := 300`; a `waiting_ticks` counter in `_tick_body` while `not started`, reset in `reset_for_fight`; when the shift check fails and the counter reaches 300, run the existing start path (AC 12, 13)
- [x] `data/duck/duck_lines.tres`: T1 text updated (AC 11); keep the entry id `t1_shift`
- [x] Re-run `tools/render_duck_lines.gd` (`-- wav`, `--import`, `-- tres`) so `t1_shift.wav` and `duck_clips.tres` match (AC 15)
- [x] Tests: the 299/300/shift-at-10 cases (AC 13); the replay and hash tests (AC 14)

### Group E: Clips and catalogue (AC: 15)
- [x] Add one `DuckLineDef` per hint window in the data, ids from `DuckHint.line_id_for`, text from the template (AC 15, D-S44-7)
- [x] Render the clips with the same tool; `test_duck_voice_data.gd` covers the new ids (AC 15)

### Group F: Gates (AC: 16, 17)
- [x] Full GUT run headless; isolation test; web export size check (AC 16, 17)

## Dev Notes

### Design calls for this story (D-S44-n)

- **D-S44-1 Infinite Loop start: T1 plus a 5 s auto-start, no extra line.** The coordinator asked for a hint or an auto-start, or both. Chosen: both, without a new line. A new "shift to start" hint line would breach the 10-line budget (D-039 counts the template once and the GDD lists 10 lines), and it still needs the player to act. The sim-side auto-start (300 ticks, the same start path as the first shift) guarantees the fight begins. The clearer T1 (D-S44-2) explains it before it starts. **GDD to update after playtest:** the Duck table row 2 and the Boss 1 note "the ring stays still until the first shift" become "until the first shift or 5 s". Note the register stays `[D, A]` after an auto-start, so the first shift still produces `[A, D]`.
- **D-S44-2 T1 text.** "Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review." The first two sentences are the coordinator's wording; the last sentence keeps the instruction about live bits (D-039 merged it into T1). Tune wording only if the playtest says so, and re-render the clip after any change.
- **D-S44-3 Beat order: per-beat trigger, no blocking.** The strict order (D-S36-7) left T4 unreachable if Dash Strike never became the active window. Each beat now fires on its own trigger, once per run. A beat that is still due is requested before a later one only by its own poll order: one beat per poll, lowest index first. Chosen over "supersede" (a later trigger cancels the earlier beats), which would dump T1 and T2 at once and lose them.
- **D-S44-4 Queue: never drop, wait for room.** A due beat or hint stays due when `DuckBubble` is full. This fixes the deferred "beats lost to MAX_PENDING" item at the director, not by raising the cap (the cap of 4 stays).
- **D-S44-5 Breakpoint hint: once per boss phase per fight attempt.** The record is cleared at each fight start, so a retry after a death can show the hint again. "At most once per boss phase" is read per attempt. Breakpoint in DEFEATED says nothing (4.3 deferred item).
- **D-S44-6 Death hint: every third death, captured at death, said at retry.** The retry resets the boss to phase 0, so the window must be captured on `player_died` (the boss still has its death phase). "Reaches 3" is read as every multiple of 3 (3, 6, 9), the natural reading for a player who keeps dying; the GDD says "the 3rd death".
- **D-S44-7 One template, one clip per window.** The GDD counts the template as one line. The implementation needs a clip per filled text for the pre-render fallback (D-S37-14), so each window that occurs in the data gets a catalogue entry generated from the template. This is an implementation detail under the one-line budget; the text is identical in form.
- **D-S44-8 Hint text is `Quack. Weak window: X→Y.`** with the glyphs from `Register.glyph_of` (`A`, `D`, `L`, `N`), joined by `→` (U+2192). The GDD example "D→A" matches.
- **D-S44-9 Pause gate.** `poll()` requests nothing while `SimClock.paused` (deferred item, Story 3.6 Layering). Breakpoint itself does not set `paused`, so Breakpoint hints still work.

### Architecture and rules that bind this story

- Signals are declared only in `src/autoloads/event_bus.gd`. This story adds none: it uses `breakpoint_started`, `player_died`, `flow_state_changed`, `duck_line_requested`.
- Simulation folders (`bosses/`, `arena/`, `skills/`, `combat/`, `player/`, `register/`) do not reference `ui`, `presentation`, `AudioManager` or `VoiceService`. The start nudge (AC 12) lives in `src/bosses/infinite_loop/infinite_loop_body.gd` and uses only sim state.
- Only `SimClock` calls `tick(ctx)`. The nudge counter is ticked from `_tick_body`, so it runs at 60 Hz with the sim. No `Timer`, no `delta`, no `await` in gameplay code.
- Presentation (`DuckDirector`, `DuckBubble`) reads the sim and never writes it (AD-05). `DuckDirector` may read `boss.current_weak_window()`, `boss.state`, `boss.phase_index`, `arena.register`, `SimClock.paused`.
- Static typing everywhere. `StringName` ids (`&"hint_a_d"`). `*_frames` / `*_ticks` names for durations (the nudge is `START_NUDGE_TICKS`).
- Data (`data/duck/*.tres`) is read-only at runtime; the hint text is built from the template in code, not written into the .tres as a second source of truth (the catalogue entries are generated by the render tool or hand-written with the same text, and a test checks they match the template).
- Logging: `Log.debug(&"duck", ...)` on each hint or beat request, never per frame. No bare `print`.

### Existing code this story touches (read before editing)

- `game/src/ui/duck/duck_director.gd`: the current `due_beat` (strict order), `poll()` (no pause gate, one request per call), `_on_flow_state_changed` (resets `requested` on TITLE only). Add the death and Breakpoint handlers here.
- `game/src/ui/duck/duck_bubble.gd`: `MAX_PENDING := 4`, the queue, `say` path (drops the sixth request). Add `has_room()`.
- `game/src/autoloads/voice_service.gd`: `say(line)` resolves an id or raw text and emits `duck_line_requested`; `speak_pending`, `stop`. The pre-render clip is looked up by id (`CLIPS.find(line_id)`), so every hint id needs a clip.
- `game/src/bosses/framework/boss_controller.gd`: `current_weak_window()` (base, `def.phases[phase_index].weak_window`), `reset_for_fight()`, `state`, `phase_index`.
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`: `started`, `shift_at_fight_start`, `_tick_body` (the start gate, lines ~117-125), `_start_lap(false)`, `current_weak_window()` override (phase 3, `open_ring` / `next_ring`), `reset_for_fight()`.
- `game/src/autoloads/game.gd` (`record_death`, `retry`, `_set_flow_state`): `player_died` is emitted at death, `DEAD` to `FIGHT` happens in `retry`. `RunState.deaths_on_boss` resets per boss (`run_state.gd`).
- `game/src/skills/breakpoint/breakpoint_skill.gd`: emits `breakpoint_started` (line ~96) and `breakpoint_ended` (line ~126). Do not change it.
- `game/src/register/register.gd`: `glyph_of(bit)` (line ~165), `window_of`.
- `game/data/duck/duck_lines.tres`, `duck_clips.tres`, `duck_voice.tres`; `game/tools/render_duck_lines.gd` (regenerates WAV and clips, see its header for the three-step run).
- Tests to extend or copy the style of: `game/tests/unit/test_duck_director.gd` (real Arena, Infinite Loop, `watch_signals`), `test_duck_bubble.gd`, `test_duck_lines.gd`, `test_duck_voice_data.gd`, `test_duck_isolation.gd`.

### Previous story intelligence (4.1, 4.2, 4.3)

- **4.3 Breakpoint:** `breakpoint_started` / `breakpoint_ended` are emitted once per start or end by the Breakpoint module from SimClock's poll. Hints subscribe to `breakpoint_started`. Breakpoint can start during the boss's DEFEATED animation (4.3 review, deferred); AC 4 handles it in the director, the skill is unchanged. The 4.3 story reserved the hint line for this story.
- **4.2 Echo Dash:** the PASS_THROUGH producer makes Echo Dash through a boss apply Patched; not a hint input.
- **4.1 Echo:** the LOOP bit's Echo does not affect the hint.
- **3.6 duck beats:** `DuckDirector` is attached in `Main` (`main.gd` lines ~175-178, the JuiceDirector pattern), `requested` resets only on TITLE, a retry keeps it (D-S36-8). Keep that for beats; the hint record is per attempt (D-S44-5).
- **3.7 voice:** `VoiceService.say` only requests; the bubble calls `speak_pending`. Pre-render clips are the AUTO fallback. The duck voice speaks letters only.
- **3.8 harvest:** the shared harvest line `harvest_shared` is in the same catalogue; do not change it.
- **3.9 UX item (deferred-work.md, "Open for the 3.9 playtest"):** the source of the start-nudge request; the playtest owner is Tiziano (3.9 HUMAN checkpoint Nov 14).

### Deferred items folded into this story

From `deferred-work.md`, the duck items that belong to the hint system:
- Strict beat order: T4 never fires if Dash Strike was never active (3.6 review). Folded: D-S44-3, AC 8.
- Beats dropped by the `MAX_PENDING` cap are lost for the run (3.6 review). Folded: D-S44-4, AC 9.
- `DuckDirector.poll()` is not gated on `SimClock.paused` (3.6 review, layering). Folded: AC 10.
- Breakpoint can start during the boss DEFEATED animation (4.3 review). Folded: AC 4.
- Infinite Loop stays still until the first shift; nothing says Q/E starts the fight (3.9 UX). Folded: AC 11 to 14.

Explicitly NOT folded (stay open): the 3.7 voice seam (stop on `clear()`/flow exit, `driven_externally`, squeak suppression), the debug FIGHT to FIGHT jump not resetting `requested` (debug only, unless it blocks AC 8 tests), `Log.warn` before unlock, the Spit projectile contact, and the Constrict escape. Record them as still open in Completion Notes.

### Git intelligence

- Recent commits: `35184ec Story 3.8`, `6cf6163 Story 3.7 (duck voice, mumble-speech)`, `b6c0125 Story 3.6 (duck bubble and tutorial beats)`. The duck code in `game/src/ui/duck/` and `game/data/duck/` was last changed by 3.7 and 3.8.
- The duck tests (`test_duck_director.gd`, `test_duck_bubble.gd`) are the closest style reference. Their helpers (`watch_signals`, real `Arena`) are reusable.

### Latest technical information

- Godot 4.7.2-stable is pinned (`project-context.md`). No API outside the existing repo patterns is needed: signals, `Resource`, GUT, static functions.
- Unicode `→` (U+2192) in GDScript string literals is fine; the pre-render tool reads the text from the `.tres`. The mumble backend speaks letters only, so the arrow is never spoken (the bubble shows it).

### Project Context Rules (from project-context.md)

- Gate order is pause > Breakpoint > hit-stop. `SimClock.paused` is the pause, never `SceneTree.paused`.
- Signals: only in `event_bus.gd`, past tense, typed args, no `Dictionary` payloads.
- Simulation emits; presentation listens. Presentation never writes sim state; flow changes go through `Game` methods.
- Simulation folders do not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.
- Data (`*_def.gd`, `data/**/*.tres`) is read-only at runtime.
- Logging: `Log.debug(&"tag", ...)` on events only.
- Static typing everywhere (`untyped_declaration` is an error). `StringName` ids. `*_frames` names.
- Determinism: no global `randi()`/`randf()`; the nudge uses no RNG.
- Tests: `tests/unit/test_<subject>.gd` for pure logic; `tests/integration/` for the flow and retry; `tests/replays/` for recorded replays.

### Project Structure Notes

- New files: `game/src/ui/duck/duck_hint.gd` (or static functions on `duck_director.gd` if the dev prefers fewer files) and `game/tests/unit/test_duck_hint.gd`. Follow snake_case and the `class_name` convention in `src/ui/duck/`.
- No new folders. No new addon. No new assets beyond the re-rendered `t1_shift.wav` and the per-window hint WAVs.
- Conflict check: none with 4.3's FeatureFlags (the hint is always on; it does not depend on `FeatureFlags.breakpoint`, but the Breakpoint trigger simply never fires when the flag is off, which is the expected behaviour).

### Testing standards

- GUT, headless. Pure functions (`window_text`, `line_id_for`, `due_beat` with per-beat rules) get exhaustive table tests.
- The phase-by-phase Infinite Loop test uses a real `Arena` and drives `open_ring` / `next_ring` directly (not the clock).
- The death test uses `Game.record_death` on a real flow, then `Game.retry`, and checks `duck_line_requested` with `watch_signals(EventBus)`.
- The nudge test uses the real `InfiniteLoopBody` with `SimContext` and ticks 299 / 300 times. It also checks the shift-at-10 case.
- Replay tests: run the existing replays. Any divergence is explained in Completion Notes (AC 14).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.4: Duck Hint Template] (ACs, FR46)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Duck (hint system)] (template, triggers, budget, tone, line table)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 1 — Infinite Loop (tutorial)] (tutorial beats T1 to T4, start register `[D, A]`, phase table)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md] (D-039 line budget, D-046 voice, D-033 no-combo windows)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Open for the 3.9 playtest] (start nudge request)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-3.6] (beat order, MAX_PENDING, pause gate)
- [Source: _bmad-output/implementation-artifacts/3-6-duck-bubble-and-tutorial-beats.md] (D-S36-7, D-S36-8, D-S36-14)
- [Source: _bmad-output/implementation-artifacts/3-7-duck-voice-mumble-speech.md] (D-S37-14 pre-render, clip ids)
- [Source: _bmad-output/implementation-artifacts/4-3-breakpoint-skill.md] (breakpoint signals, DEFEATED deferred item)
- [Source: _bmad-output/project-context.md] (rules listed above)

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (story creation only); implementation: claude opus (claude-opus-5-5), gds-dev-story, unattended pipeline, 2026-11-10.

### Debug Log References

- Baseline before changes: GUT 1065/1065 (80 scripts), check_guards OK.
- First full run after the code changes: 13 failures, all expected test updates (T1 text in 5 tests, strict-order beat tests, line count, the duck isolation regex rejecting `boss.current_weak_window()`, and two "still for N ticks" tests now crossing the 300-tick nudge). Fixed with recorded reasons (below).
- Final: GUT 1098/1098 (82 scripts, 42106 asserts), "All tests passed!", no SCRIPT ERROR / Parse Error in the log; `bash game/tools/check_guards.sh` -> `check_guards: OK` (0 violations); import log clean.
- `tools/render_duck_lines.gd` prints `SCRIPT ERROR: Identifier not found: EventBus` for the first compile of duck_line_def.gd (DuckBubble needs autoloads, absent in `-s` scripts); this was there before 4.4, the tool retries and both modes finish (7 WAVs, `wrote duck_clips.tres (7 clips)`).
- Mumble probe: `Mumble.render("Quack. Weak window: D→A.")` reports `char_index` in Unicode characters (A at 22 of 24), so `char_times` line up with the arrow text; duration 1.375 s.

### Completion Notes List

**Implementation**
- `DuckHint` (new, `src/ui/duck/duck_hint.gd`): pure `window_text(w)` ("Quack. Weak window: X→Y." from `Register.glyph_of`), `line_id_for(w)` (`&"hint_a_d"`), `is_hint_id`, `windows_of(def)` (every phase window plus the Infinite Loop's phase-3 reverse). No second glyph map.
- `DuckDirector`: `requested` is now a bitmask; `due_beat` returns the lowest due beat (per-beat triggers, D-S44-3). Subscribes to `breakpoint_started` and `player_died` (connect in `_enter_tree`, disconnect in `_exit_tree`). Breakpoint queues `boss.current_weak_window()` once per `(boss_id, phase)` per attempt (record cleared on every FIGHT entry), skipped while DEFEATED or outside FIGHT, not marked then. Every 3rd death (`deaths % 3 == 0`) captures the window at the death; DEAD -> FIGHT queues it; any other exit (TITLE) drops it. `poll()` is gated on `SimClock.paused` and `bubble.has_room()`, requests the oldest pending hint first, else the lowest due beat, one per poll. `Log.debug(&"duck", ...)` per request. Reads only (AD-05).
- `DuckBubble.has_room()` (read-only); `Main` hands `hud.duck_bubble` to the director.
- `InfiniteLoopBody`: `START_NUDGE_TICKS := 300`, `waiting_ticks` counted in `_tick_body` while not started, reset in `reset_for_fight`; at 300 it runs the same start block as the first shift (`_start_lap(false)`, `;` opens, ring moves from the next tick). No Timer / delta / await. Pause, the Breakpoint freeze and hit-stop do not advance it because SimClock does not tick the boss then (tested in `test_start_nudge.gd`).
- Data: T1 text rewritten (D-S44-2), entries `hint_a_d` and `hint_d_a` added (the only windows in the data: Infinite Loop A→D / D→A, test boss the same). Clips re-rendered with the tool's three steps; `t1_shift.wav` changed, the other existing WAVs came out byte-identical (deterministic render), two new hint WAVs.
- `DuckLineDef` accepts `EXTRA_GLYPHS` ("→") besides printable ASCII (`is_drawable`).

**AC check**
- AC 1-2: `test_duck_hint.gd` (all 16 bit pairs, every phase of every BossDef found under `data/bosses/`, Infinite Loop phase 3 with `open_ring` / `next_ring`). Null Pointer and Segfault have no `BossDef` yet (empty folders); the test reads whatever `boss_def.tres` exists, so they are covered when they land.
- AC 3-7, 10: `test_duck_director.gd` (Breakpoint once per phase, per attempt, DEFEATED, outside FIGHT; deaths 1/2/3, capture at death, said at retry, TITLE drop; the real `Game.record_death` / `Game.retry` flow; pause gate).
- AC 8: T4 at phase 2 with Dash Strike never active, T3 then skipped; TITLE reset / retry keep unchanged.
- AC 9: six due items (2 hints + 4 beats) on a real `DuckBubble`: five requested, the sixth waits, all six shown in order.
- AC 11: T1 wraps to 11 rows (rows 23-33, inside cols 0-11, rows 22-37), asserted in `test_duck_bubble.gd`.
- AC 12-13: `test_infinite_loop_body.gd` (299 still, 300 started like the first shift, shift at tick 10, reset, inactive boss) and `test_start_nudge.gd` (real Arena on SimClock: tick 300, pause and Breakpoint freeze do not count, retry restarts, deterministic).
- AC 14: every replay and hash test passed without re-recording: all recorded / scripted fights shift in their first ticks, so none sat still for 300 ticks. `waiting_ticks` added to the Infinite Loop replay hash.
- AC 15: `test_duck_hint.gd` derives the window set from the data and checks entry text == template, clip present and matching; `test_duck_voice_data.gd` covers all 7 entries.
- AC 16: no new signal; sim folders untouched by duck names (isolation test green); the hint logic is in `src/ui/duck/`.
- AC 17: GUT green; web size below.

**Tests changed, with reasons (not silent)**
- `test_infinite_loop_body.gd::test_ring_stays_still_until_the_first_shift`: 300 -> 299 ticks (`START_NUDGE_TICKS - 1`); at 300 the nudge now starts the ring (D-S44-1).
- `test_infinite_loop_attacks.gd::test_no_attack_before_the_loop_starts`: 600 -> 299 ticks, same reason.
- `test_duck_director.gd`: the 3.6 strict-order cases rewritten to the bitmask / no-blocking rule (D-S44-3, D-S44-10).
- `test_duck_isolation.gd`: the `boss.xxx(` guard now allows `boss.current_weak_window()` (a read, like `register.active_window()`); a positive case added; `duck_hint.gd` added to the scanned names.
- `test_duck_lines.gd`, `test_duck_bubble.gd`, `test_voice_service.gd`, `test_smoke_voice.gd`: new T1 text, 7 entries, budget counted with the hint template once (6 of 10), the arrow allowed for hint lines only.

**Font (coordinator check)**: the pixel font has U+2192 (already used by `RegisterPanel.JK_LABEL`, covered by `test_font_coverage`, which also scans every duck line). D-S44-8 kept as written.

**Size (AC 17)**: local export with the stock template (the stripped template is built in CI only): `index.pck` 745,484 bytes vs 651,544 at the 4.3 baseline (`git archive HEAD`, same machine): +93,940 bytes (T1 clip about +34 kB, two hint clips 27,111 bytes each imported as QOA, data/code). Estimate for the CI build: the 3.7 record (29,461,134 total with `index.pck` 555,060) puts the non-pck files at 28,906,074, so total ≈ 28,906,074 + 745,484 = 29,651,558 bytes < 30,000,000 (about 348 kB headroom). CI's Web build size step is the authoritative check.

**Design calls made during implementation**
- [design call] D-S44-10 (two parts). (a) A beat that missed its moment is skipped for good once a later beat fired (AC 8 "T3 is then skipped for good"), so beats are never said out of tutorial order; two beats due on the same poll go lowest first. (b) `DuckLineDef` accepts the arrow U+2192 as the only non-ASCII glyph (`EXTRA_GLYPHS`), since the hint entries must hold the template text and the font draws it.
- [design call] D-S44-11 Pending hints are requested before due beats (a hint answers the player's ask; beats are tutorial flavour). The Breakpoint hint captures the window when Breakpoint starts (what the player asked about), not when the bubble has room.
- [design call] D-S44-12 The Breakpoint record is marked when the hint is queued in the director (it is then guaranteed to be said while the fight lasts); queued hints are dropped when the flow leaves FIGHT (the bubble clears then too), except the death hint, which is held through DEAD on purpose.
- [design call] D-S44-13 The death hint does not mark a phase in the new attempt's Breakpoint record (a Breakpoint right after the retry can repeat it; harmless, keeps the two triggers independent).
- [design call] D-S44-14 The nudge counts only live boss ticks (`_tick_body`), with or without an arena; a boss that is not ticked (inactive, DEFEATED, paused, frozen) never counts.

**Still open (not folded, per the story)**: 3.7 voice seam (stop on `clear()` / flow exit, `driven_externally`, squeak suppression), the debug FIGHT -> FIGHT jump not resetting `requested`, `Log.warn` before unlock, the Spit projectile contact, the Constrict escape. The GDD Duck table row 2 and the Boss 1 "still until the first shift" note still need the "or 5 s" edit after the playtest (D-S44-1). deferred-work.md not edited here (the five folded items can be closed at review).

### File List

- game/src/ui/duck/duck_hint.gd (new)
- game/src/ui/duck/duck_hint.gd.uid (new)
- game/src/ui/duck/duck_director.gd
- game/src/ui/duck/duck_bubble.gd
- game/src/ui/duck/duck_line_def.gd
- game/src/bosses/infinite_loop/infinite_loop_body.gd
- game/src/main/main.gd
- game/data/duck/duck_lines.tres
- game/data/duck/duck_clips.tres
- game/assets/audio/duck/t1_shift.wav
- game/assets/audio/duck/hint_a_d.wav (new)
- game/assets/audio/duck/hint_a_d.wav.import (new)
- game/assets/audio/duck/hint_d_a.wav (new)
- game/assets/audio/duck/hint_d_a.wav.import (new)
- game/tests/unit/test_duck_hint.gd (new)
- game/tests/unit/test_duck_hint.gd.uid (new)
- game/tests/integration/test_start_nudge.gd (new)
- game/tests/integration/test_start_nudge.gd.uid (new)
- game/tests/unit/test_duck_director.gd
- game/tests/unit/test_duck_bubble.gd
- game/tests/unit/test_duck_isolation.gd
- game/tests/unit/test_duck_lines.gd
- game/tests/unit/test_infinite_loop_body.gd
- game/tests/unit/test_infinite_loop_attacks.gd
- game/tests/unit/test_smoke_voice.gd
- game/tests/unit/test_voice_service.gd
- game/tests/integration/test_infinite_loop_replay.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/4-4-duck-hint-template.md

### Change Log

- 2026-11-10: Story 4.4 implemented (hint template, Breakpoint and 3rd-death triggers, per-beat duck triggers, queue room and pause gates, Infinite Loop 5 s start nudge, T1 rewrite, hint clips). GUT 1098/1098, guards OK. Status -> review.

## Story Completion Status

Implementation complete. Status: done.

### Review Notes (gds-code-review, 2026-11-10)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). All 17 ACs satisfied (AC 2 partial: Null Pointer and Segfault have no BossDef yet).
- Fixed (patch): the death hint is tied to the boss it was captured on (not said in another boss's fight after a debug jump); no hint is queued for an all-zero window ("?->?"). Test added: `test_death_hint_is_not_said_in_another_boss_fight`.
- Deferred to deferred-work.md (4.4 section): stale queued Breakpoint hint, phase-3 inner ring not re-hinted, T3 transient trigger, AC 2 for Epic 5 bosses, test gaps, arrow to the voice, D-S44-12 departure.
- Dismissed: `LINES.find` null check (LINES is a DuckLinesDef, find returns null, not an Array), signal order on death (player_died follows the DEAD flow change by design), mask/test rewrites (reasons hold), sub_resource id churn in the generated .tres, pause vs Breakpoint freeze for hints (intended).
- deferred-work.md: closed the strict-order T4, MAX_PENDING drops, pause gate, Breakpoint-in-DEFEATED (hint side) and 3.9 start-nudge items.
