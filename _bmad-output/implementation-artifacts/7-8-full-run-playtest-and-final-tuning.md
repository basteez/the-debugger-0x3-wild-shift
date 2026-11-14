---
baseline_commit: 304e7dc
---
# Story 7.8: Full-Run Playtest and Final Tuning

Status: review

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with a default (D-S78-n); the implementer follows them or records a change in Completion Notes. Scope is the HARNESS only: the playtest protocol and log template (`playtest-full.md`), and in-game metric capture so the numbers can be read after a run. The human playtest itself (>= 3 first-time testers, 3 consecutive full runs) is PENDING and is not done by this story. No gameplay value is changed here: tuning happens after the human sessions, in a later pass. On dev completion the status becomes `review` with the human ACs H-S78-1..4 pending (deferred-work.md). -->

## Story

As the director,
I want the complete run playtested and tuned,
so that it takes a first-time player 10–15 minutes and feels fair.

**Requirements:** NFR9, NFR11, NFR13, NFR14. GDD Success Metrics > Gameplay Metrics (first shift, first Patch, Boss 1 clear, full run, shift feel, theme proxy).

**Depends on:** 7.7 (fullscreen, perf checks), 7.6 (practice flow: must not count), 7.4 (assist flag: changes clear times, must be recorded), 7.3 (save: practice never writes), 6.8 (ending snapshot `Game.ending_summary` and `RunStats`), 6.9 (text audit done), 2.8 (`Log` lines), 3.2 (`EventBus` hit/death signals).

## Acceptance Criteria

1. **Given** the full build and >= 3 first-time playtesters, **when** each plays a full run, **then** the Gameplay Metrics are recorded in `_bmad-output/implementation-artifacts/playtest-full.md`: first shift <= 30 s, full run 10–15 min, per-boss clear times (Boss 1 60–120 s, Boss 2 120–150 s, Boss 3 150–210 s), shift feel >= 4/5, >= 50% mention the shift unprompted, and Null Pointer locatable by sound alone and by sight alone (per tester, yes/no).
2. **Given** the same sessions, **when** results are recorded, **then** every tester has a section with the fields from the template (build, platform, input device, assist on/off, the metric values, deaths per boss, blocking bugs, pasted `[metrics]` lines), and the aggregate table is filled from those sections.
3. **Given** the findings, **when** tuning is applied (after the sessions), **then** only `.tres` values change, in GDD order (bosses in order, then within each boss the NFR13 knob order: boss HP, tell, recovery, gap; player HP last), the x0.5 / x1.5 multipliers are never changed, and each change is a row in the tuning log linking the session evidence. This story itself changes no gameplay value.
4. **Given** the final build, **when** 3 consecutive full runs are played, **then** there are zero blocking bugs (recorded in the "Final runs" section of `playtest-full.md`).
5. **Given** a playtest run (not practice, not debug-jumped), **when** the first player shift happens, **then** the game logs one `[metrics]` line with `first_shift_s` (seconds from the first title input, Intro included); only the first shift of a run is logged.
6. **Given** a boss defeat in a counted run, **when** the defeat finishes, **then** one `[metrics]` line logs that boss's clear time (first non-retry FIGHT entry for that boss to the defeat), its death count (retries of that boss included), and the `assist` flag. Retries never restart the clear timer.
7. **Given** the run reaches ENDING, **when** the Ending is entered, **then** one `[metrics]` summary line logs `full_run_s` (first title input to ENDING entry; pauses excluded), `hits`, `bosses` (per-boss clear seconds and deaths), `assist` and `debug_jumped`, so a single pasted line carries the whole run.
8. **Given** a practice run (Story 7.6), **when** it is played (shifts, hits, deaths, defeats), **then** no `[metrics]` line is written and nothing is recorded; a debug-jumped run is still logged but carries `debug_jumped=true`.
9. **Given** a run with pauses, deaths and HARVEST screens, **when** the durations are logged, **then** pause time is excluded (sim frames stop while paused), and HARVEST time between bosses is excluded from each boss's clear time (the clock starts at the boss's FIGHT entry and stops at its defeat).
10. **Given** a new run (title start, resume, ENDING -> TITLE, debug jump to TITLE), **when** it starts, **then** the metric record is fresh (it lives in `RunStats`, which those paths already replace).
11. **Given** the metrics code, **when** reviewed, **then** it adds no network calls, no file writes and no `get_ticks_*` calls in simulation code (`tools/check_guards.sh` passes); the ending snapshot shape `{clear_frames, hits, debug_jumped}` is unchanged so the 6.8 ending card and its tests are untouched.
12. **Given** the story is complete, **when** the human checks are listed, **then** `deferred-work.md` has a `## Story 7.8` section with H-S78-1..4 (the sessions, the Null Pointer sound/sight check, the 3-run zero-blocker check, the tuning pass) and the status is `review`.

## Tasks / Subtasks

- [x] Task 1: Metric record in `RunStats` (AC: 5, 6, 7, 9, 10, 11)
  - [x] 1.1 Add fields to `game/src/core/run_stats.gd`: `first_shift_frame: int = -1`, `boss_start_frames: Dictionary` (boss index -> first non-retry FIGHT entry frame), `boss_clear_frames: Dictionary` (boss index -> clear frames), `boss_deaths: Dictionary` (boss index -> deaths). Keep `snapshot()` unchanged.
  - [x] 1.2 Add pure methods: `note_fight_entry(boss_index, frame)` (first entry only), `note_first_shift(frame)` (first only, returns true when it set it), `note_death(boss_index)`, `note_boss_cleared(boss_index, frame) -> int` (returns clear frames, 0 when no start), `static func seconds(frames: int) -> float` (frames / Const.SIM_HZ, -1.0 for negative input).
  - [x] 1.3 Add `metrics_summary(first_input_frame, end_frame, assist, debug_jumped) -> String` (pure) producing the single `[metrics]` ENDING line body (see Dev Notes for the format).
- [x] Task 2: Wire the record in `game/src/autoloads/game.gd` (AC: 5, 6, 7, 8)
  - [x] 2.1 `_ready`: connect `EventBus.register_shifted` to `_on_register_shifted`; disconnect in `_exit_tree` (same pattern as `player_damaged`).
  - [x] 2.2 `_on_register_shifted(_direction, _window, _ring, source)`: when `source == &"player"`, `flow_state == FIGHT`, `not practice_run`, `first_input_frame >= 0` and `stats.note_first_shift(SimClock.sim_frame)` is true, log `Log.info(&"metrics", "first_shift_s=%.1f" % ...)`.
  - [x] 2.3 `_set_flow_state`: on `to == FIGHT and not _retrying and not practice_run`, call `stats.note_fight_entry(run.boss_index, SimClock.sim_frame)`. Do not touch the existing `fight_start_frame` logic.
  - [x] 2.4 `record_death`: inside the existing `if not practice_run:` block, also `stats.note_death(run.boss_index)`.
  - [x] 2.5 `finish_defeat`: before `_set_flow_state(to)`, when `not practice_run`, compute the clear frames and log `boss <n+1> cleared_s=%.1f deaths=%d assist=%s`.
  - [x] 2.6 `_set_flow_state` on `to == ENDING and not practice_run`: log the summary line (after `ending_summary` is set). Read `first_input_frame` before the reset in `finish_ending`.
- [x] Task 3: Tests (AC: 5–11). Seed nothing new: no random picks are involved.
  - [x] 3.1 `game/tests/unit/test_run_stats_metrics.gd`: first-only rules for shift and fight entry; retry does not restart the clock; deaths per boss; clear frames 0 without a start; `seconds()` edge cases; summary line format; practice-free `RunStats.new()` is all -1 / empty.
  - [x] 3.2 `game/tests/integration/` or extend `test_game_flow.gd`: a run through FIGHT (boss 1) -> DEAD -> retry -> defeat -> HARVEST -> FIGHT (boss 2) records two boss starts, one death on boss 1, a clear for boss 1, and no entry for practice; practice start + shift + death records nothing (`stats.first_shift_frame == -1`, empty dicts).
  - [x] 3.3 Existing `test_game_flow.gd` (lines ~750–790) and `test_ending_flow.gd` must pass unchanged.
- [x] Task 4: Playtest harness document (AC: 1, 2, 3, 4)
  - [x] 4.1 Create `_bmad-output/implementation-artifacts/playtest-full.md` from the structure in Dev Notes (protocol, metric table, per-tester sections x3 plus spare slots, aggregate, tuning log in GDD order, final runs, open issues). Written in English. Leave results blank.
  - [x] 4.2 Do not create any other report file.
- [x] Task 5: Human checks and status (AC: 12)
  - [x] 5.1 Append `## Story 7.8 (Full-run playtest and final tuning)` to `_bmad-output/implementation-artifacts/deferred-work.md` with H-S78-1..4 as checkboxes.
  - [x] 5.2 Run GUT (headless, `/Applications/Godot.app/Contents/MacOS/Godot`, see the existing test invocation in CI) and `bash game/tools/check_guards.sh`. Both must pass.
  - [x] 5.3 Set this story's status to `review` at dev completion and fill the Dev Agent Record.

## Dev Notes

### What exists now (read before writing code)

- **`RunStats`** (`game/src/core/run_stats.gd`, Story 6.8): `fight_start_frame` (Fight 1 entry), `hits`, `debug_jumped`; `snapshot(end_frame)` returns `{clear_frames, hits, debug_jumped}` for the Ending card. It is replaced (`RunStats.new()`) on title start, resume, practice start, debug jump to TITLE, ENDING -> TITLE. That makes it the natural home for the per-run metric record: it already has the right reset semantics.
- **`Game`** (`game/src/autoloads/game.gd`): `first_input_frame` (title input, the 30-s clock origin; -1 in practice and after `finish_ending`), `practice_run`, `_retrying`, `run.boss_index`, `run.deaths_on_boss` (per boss, reset by `start_boss`, so it cannot give per-boss totals across the run), `run.assist`. Hooks already exist: `_set_flow_state` (FIGHT / ENDING entries), `record_death`, `finish_defeat`, `on_player_damaged`.
- **Events**: `EventBus.register_shifted(direction, window, ring, source)`; `source == &"player"` for a player shift (`Register.shift`). `source` is `&"sigsegv"` for boss rotations: never count those as the first shift.
- **`Log`** (`game/src/autoloads/log.gd`): `Log.info(tag, msg)` always prints (also in release builds, so devtools shows it). `Log.debug` needs debug mode. Format `[f=<frame>][INFO][tag] msg`.
- **Sim clock**: `SimClock.sim_frame` advances only in `tick()` after the pause check, so pauses are excluded from every duration. `Const.SIM_HZ = 60`.
- **Practice** (7.6) is `Game.practice_run`; it must write nothing to the metric record (AC 8). **Assist** (7.4) is `run.assist`; it lengthens tells x1.5, so every line carries it. **Debug jump** sets `stats.debug_jumped`; the line still prints, flagged.
- **No playtest artifacts exist yet.** `playtest-mvp.md` (3.9) was never written (3.9 is still `backlog`), so there is no earlier format to copy. The template below is designed from the epics and GDD ACs.
- **Ending card** (`game/src/ui/screens/ending/ending_screen.gd`, `summary_rows`) reads `Game.ending_summary` with `get()`; keep that snapshot unchanged.

### Design calls (all `[design call]`; default chosen, change in Completion Notes if needed)

- **D-S78-1 [design call]** Metric record lives in `RunStats` (no new autoload). Reset rules come for free from the existing `RunStats.new()` sites. Practice writes are blocked in `Game`, not in `RunStats`.
- **D-S78-2 [design call]** Surfacing: `Log.info(&"metrics", ...)` lines only. One line per event (first shift, each boss clear), one summary line at ENDING. No file write, no network, no in-game overlay. Tiziano and testers read them from the browser devtools console (F12) and paste the lines into `playtest-full.md`. A debug-only key to dump the record mid-run is NOT built (optional follow-up if sessions are cut short).
- **D-S78-3 [design call]** Per-boss clear time = first non-retry FIGHT entry for that boss -> `finish_defeat` (includes the defeat animation, ~DEFEAT_FRAMES, and all retries). Deaths are reported separately so the clear time and the death count can be read together. HARVEST between bosses is excluded.
- **D-S78-4 [design call]** First shift = first `register_shifted` with `source == &"player"` in FIGHT, in a non-practice run. Measured from the first title input, Intro included (GDD D-040: the 30-s clock includes the <= 8 s intro).
- **D-S78-5 [design call]** Full run = `first_input_frame` -> ENDING entry. Pauses excluded (sim frames stop). The ENDING hold after the clear is excluded because the clock stops at entry.
- **D-S78-6 [design call]** Runs with `assist=true` or `debug_jumped=true` are logged and reported in their own tester section, and are excluded from the aggregate targets. Assist sessions still feed the H-S74-2 "fair tells" check.
- **D-S78-7 [design call]** Null Pointer "locatable by sound alone / by sight alone" is a facilitator observation per tester (yes/no plus a quote), recorded in the tester section. No code, no test seam. The sound-only check uses headphones with the screen covered; the sight-only check uses the mute toggle (`[M]`).
- **D-S78-8 [design call]** Tuning order = bosses in GDD order (Infinite Loop, Null Pointer, Segfault), and inside each boss the NFR13 order (boss HP -> tell -> recovery -> gap); player HP is last. Only `.tres` under `game/data/`. The x0.5 / x1.5 multipliers are fixed.
- **D-S78-9 [design call]** Targets not in the epic AC but in the GDD Gameplay Metrics and NFR14 are tracked in the same table: First Patch with Dash Strike >= 80%, Boss 1 clear within 3 attempts >= 80%. Attempts are counted by the facilitator from `[metrics]` death lines plus retries (no extra field).
- **D-S78-10 [design call]** `playtest-full.md` is authored by the dev agent with empty result cells. Results are filled by Tiziano / the facilitator after the sessions. No tuning is applied in this story.

### Log line formats (fixed, so the sessions can be parsed by eye)

```
[f=<frame>][INFO][metrics] first_shift_s=12.4
[f=<frame>][INFO][metrics] boss 1 cleared_s=87.3 deaths=2 assist=false
[f=<frame>][INFO][metrics] run full_run_s=742.9 hits=31 assist=false debug_jumped=false bosses=[1:87.3/2, 2:131.0/1, 3:176.2/3]
```

`bosses=[index:clear_seconds/deaths]`; a boss not reached is omitted. The summary body comes from `RunStats.metrics_summary`, pure and unit-tested.

### Architecture guardrails

- Sim vs presentation: the metric record is written from `Game` (flow/presentation side) and from EventBus callbacks, never from the sim's `tick` path. Do not add `get_ticks_*`, `Timer` or `await` anywhere in `game/src/register`, `game/src/combat`, `game/src/bosses`, `game/src/player`, `game/src/skills` or `game/src/arena` (see `tools/check_guards.sh`).
- No network telemetry, no `FileAccess` writes for metrics (D-S77-2: no new telemetry).
- Value tuning is `.tres` only (`game/data/`); no GDScript constants change for balance.

### Previous story intelligence (7.7, 7.6, 7.4, 7.3)

- 7.7: "No new telemetry (D-S77-2): the human perf run reads the F10 overlay". This story adds Log lines only, which is consistent with that rule. Its human checks (H-S77-1..6) are still open and are not this story's to close.
- 7.6: practice is excluded from the save and from stats, and its death/retry path is separate (`practice_run` checks everywhere). Keep the same guard style.
- 7.4: assist is applied from the next attempt; the `assist` flag on each line is therefore the flag at the time of the event (read `run.assist`).
- 7.3: resume-from-title enters FIGHT with a fresh `RunState` and `RunStats`; the first boss clock starts at that FIGHT entry (no Intro, so `first_shift_s` is absent for a resumed run: log only when the first shift happens).

### Git intelligence (last commits)

- `304e7dc` Story 7.7: Fullscreen, browser matrix and performance
- `5a765f5` Story 7.6: Practice target from the title screen
- `0a4924e` Story 7.5: Gamepad support

### Project Structure Notes

- New unit test: `game/tests/unit/test_run_stats_metrics.gd` (GUT). Integration additions in `game/tests/integration/` or `test_game_flow.gd`.
- New document: `_bmad-output/implementation-artifacts/playtest-full.md` (the only new file besides the test).
- Edited: `game/src/core/run_stats.gd`, `game/src/autoloads/game.gd`, `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`.

### Testing standards

- GUT, headless, as in the existing suite. Practice and debug tests must restore `Debug.enabled`, `SimClock.sim_frame` and `SimClock.paused` in `after_each` (pattern in `test_game_flow.gd`).
- No randomness in these tests (no seed needed); if a fight is driven, use the existing replay/integration seams.
- `tools/check_guards.sh` must pass.

### `playtest-full.md` structure (to create)

1. **Protocol**: first-time players only (never the director or anyone who has seen the build); title screen with no help beyond the duck; no hints from the facilitator; Intro skip allowed; record the `[metrics]` lines from the devtools console (paste them verbatim). Note the build (commit hash, itch URL or CI artifact, `?debug` absent).
2. **Metric table**: rows = First shift <= 30 s; Full run 600–900 s; Boss 1 clear 60–120 s; Boss 2 clear 120–150 s; Boss 3 clear 150–210 s; Shift feel >= 4/5 (mean); Shift mentioned unprompted >= 50%; Null Pointer locatable by sound alone (n/N); by sight alone (n/N); First Patch with Dash Strike >= 80%; Boss 1 within 3 attempts >= 80%; 3 consecutive full runs with zero blocking bugs. Columns: Target | Result | Pass / Fail | Notes.
3. **Per-tester sections** (Tester 1, 2, 3, plus spare Tester 4 and 5): date, build, browser/platform, input device, assist (on/off), first shift s, full run s, boss clears s and deaths and attempts, shift feel /5, shift mention (yes/no + quote), Null Pointer sound-only (yes/no), sight-only (yes/no), blocking bugs, free notes, pasted `[metrics]` lines. Assisted or debug-jumped sessions are marked and excluded from the aggregate.
4. **Aggregate**: computed from the non-assisted, non-debug sessions.
5. **Tuning log** (GDD order): columns `# | Boss / stage | File (game/data/...) | Key | Old | New | Reason (metric row + session) | Applied by | Date`. Empty rows.
6. **Final runs**: Run 1, 2, 3 (consecutive, final build): date, build, outcome, blocking bugs (none / list).
7. **Open issues**: non-blocking notes carried to 7.9 or the fallback list.

### Human checks (pending, not automatable)

- [ ] H-S78-1 >= 3 first-time playtesters (by Nov 27): play a full run each from the title, release web build; fill their sections and paste the `[metrics]` lines.
- [ ] H-S78-2 Null Pointer locatable by sound alone and by sight alone, asked per tester (D-S78-7).
- [ ] H-S78-3 3 consecutive full runs on the final build, zero blocking bugs.
- [ ] H-S78-4 Tuning pass applied only in `.tres`, in GDD order, every change logged; build re-verified (`check_build_size.sh`, guards, GUT).

### Open questions

- None blocking. The debug-only dump key (D-S78-2) and the exact tester count beyond 3 are decisions for after the first session.

## Dev Agent Record

### Agent Model Used

claude-opus-5-5 (gds-dev-story, pipeline, 2026-11-14)

### Debug Log References

- GUT headless (`/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`): 121 scripts, 1771/1771 tests passing, 145775 asserts, exit 0 (1 orphan, as before).
- `bash game/tools/check_guards.sh`: OK.
- First run caught a test bug (the cut-#4 ENDING test set `segfault_enabled` before the helper reset it); fixed in the test, no code change.

### Completion Notes List

- Implemented D-S78-1..10 as written (no design call changed). No gameplay or tuning value changed; no `.tres` touched.
- `RunStats` (Task 1): new fields `first_shift_frame`, `boss_start_frames`, `boss_clear_frames`, `boss_deaths`; pure methods `note_fight_entry`, `note_first_shift`, `note_death`, `note_boss_cleared`, `deaths_on` (small reader added for the log lines), static `seconds`, and `metrics_summary` producing the exact Dev Notes line format. `snapshot()` unchanged.
- `Game` (Task 2): `register_shifted` connected in `_ready` / disconnected in `_exit_tree`; `_on_register_shifted` logs `first_shift_s` once per run (player source, FIGHT, non-practice, with a title input). Fight entry recorded in `_set_flow_state` on non-retry, non-practice FIGHT; deaths in `record_death`'s non-practice block; boss clear line in `finish_defeat` before the state change; ENDING summary line in `_set_flow_state` right after `ending_summary` (before `finish_ending` resets `first_input_frame`). All writes are on the flow/autoload side (EventBus callbacks and flow transitions), never in the sim tick path; replay tests unchanged and green.
- [design call] Added `RunStats.deaths_on(boss_index)` (read helper, not in Task 1.2's list) so the log line and summary share one lookup.
- [design call] Debug-jumped runs: `first_input_frame` is set at the jump, so `full_run_s` may be shorter than the boss clears; the line is flagged `debug_jumped=true` and excluded from the aggregate per D-S78-6. Noted in deferred-work.md.
- Coordinator decision: playtesters start each full run fresh with `[N]` new run (or a cleared save) so `full_run_s` covers the whole run; a resumed run's `full_run_s` covers only the bosses after resuming. Added to the playtest-full.md protocol. `deaths_on` helper and debug-jump clock note approved.
- Tests (Task 3): `test_run_stats_metrics.gd` (10 tests: first-only rules, retry keeps clock, per-boss deaths, clear without start, `seconds()` edges, summary format incl. omitted/flagged cases, unchanged snapshot shape). `test_metrics_flow.gd` (7 tests on a real `Game` instance: first player shift from the title input, boss rotation and non-FIGHT shifts ignored, FIGHT 1 -> DEAD -> retry -> defeat -> HARVEST -> FIGHT 2 bookkeeping, ENDING snapshot shape + full-run summary, practice records nothing, debug-jumped run recorded and flagged, fresh record on a new run). Existing `test_game_flow.gd` and `test_ending_flow.gd` pass unchanged. No randomness: no seed needed.
- `playtest-full.md` (Task 4) created with empty result cells: protocol, metric table, Tester 1-3 + spare 4-5, aggregate, tuning log (GDD order), final runs, open issues.
- Human ACs 1-4 (H-S78-1..4) are pending in `deferred-work.md`; the story is `review` with those open.

### File List

- game/src/core/run_stats.gd (modified)
- game/src/autoloads/game.gd (modified)
- game/tests/unit/test_run_stats_metrics.gd (new) + .uid
- game/tests/unit/test_metrics_flow.gd (new) + .uid
- _bmad-output/implementation-artifacts/playtest-full.md (new)
- _bmad-output/implementation-artifacts/deferred-work.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/7-8-full-run-playtest-and-final-tuning.md (this story)

### Change Log

- 2026-11-14: Story 7.8 harness: `[metrics]` log lines (first shift, per-boss clear, ENDING run summary) from a per-run record in `RunStats`; `playtest-full.md` template; H-S78-1..4 in deferred-work.md. No gameplay values changed. Status -> review.
