---
baseline_commit: b3c766a
---

# Story 9.3: Run and Assist Clarity

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from story/9-2 HEAD b3c766a (stacked; PR base story/9-2-miss-feedback-polish). Sources: Epic 9 in epics.md, the brief epic9-brief.md (story 3) and the triage epic9-triage.md (gameoff-wt/, its 9-2 proposal), deferred-work.md lines 528, 533, 539, 544 (Stories 7.3 and 7.4 deferred sections). Self-made choices are marked [design call] D-S93-n; the implementer follows them or records a change in Completion Notes. Scope: deferred-work.md items 528, 533, 539, 544 only. -->

## Story

As a player,
I want a cleared run to offer a fresh start instead of dropping me into the final boss, a second press before an `[N]` new run wipes my progress, and the debug build assist to say when it takes effect,
so that the title and the pause screen never surprise me with what happens next.

**Requirements:** deferred-work.md 528 (7.3 review: a cleared run keeps `highest_boss` at the final boss, so the title resumes into it), 533 (7.3 review: `[N] new run` has no confirmation), 539 (7.4: the assist applies from the next attempt, no note says so), 544 (7.4 review: the pause row flips to ON at once). The triage's 9-2 summary is covered here; the brief's story 3 numbering is used. Save changes stay inside SaveService v2 (a key, not a new version, D-S73-1). No sim change: nothing in the fight tick reads the new state, replays are unchanged.

### The four items, verbatim (deferred-work.md)

- 528: "A cleared run keeps `highest_boss` at the final boss (AC 11 says finish_ending never lowers it), so the next title resumes into the last fight until the player presses [N]. Spec-mandated; revisit with a "completed" flag if playtests show confusion."
- 533: "[N] new run has no confirmation step."
- 539: "The assist applies from the next fight attempt (D-S74-1): a pause toggle mid-fight changes nothing until the retry / next boss / next run. No on-screen note says so; add one if H-S74-1 shows confusion."
- 544: "The pause row flips to ON at once although the assist applies from the next attempt (D-S74-1); add an on-screen "next attempt" note if playtests show confusion."

## Acceptance Criteria

1. **Given** a save whose run was cleared (`completed` true, `highest_boss` 3) **When** the title opens **Then** `[N] new run` is not offered, and any plain start key or click starts a fresh run through the Intro (`Game.start_run_from_title`), never `resume_run_from_title`. (528) [design call] D-S93-1.
2. **Given** a non-debug, non-practice run reaches ENDING **When** the ending is entered **Then** `SaveService` writes `completed` true once, at entry (a tab closed during the ending still counts). A debug-jumped run or a practice run writes nothing. (528) [design call] D-S93-1.
3. **Given** `completed` is true **When** Fight 1 is entered by a fresh run **Then** `completed` clears and `highest_boss` resets to 1 (one save write), so the new run's own progress is what the title later resumes. With `completed` false, the existing rule holds unchanged: a fresh Fight 1 never lowers `highest_boss` (`test_ending_and_new_run_never_lower` passes unedited). (528) [design call] D-S93-1.
4. **Given** the `completed` key **When** a save is read **Then** a missing key (any version 1 or 2 file) reads as false, a wrong-typed value makes the file invalid (defaults plus one warn, as the other keys), and `VERSION` stays 2 (no migration). (528) [design call] D-S93-1.
5. **Given** a save with progress and the title's `[N] new run` row **When** N is pressed (or the row is clicked) once **Then** the row changes to `PRESS N AGAIN: WIPE PROGRESS`, nothing starts and nothing is wiped. A second N or a click on that row within 90 sim frames runs `Game.start_new_run_from_title` (reset, Intro). After 90 frames the arm lapses. (533) [design call] D-S93-2.
6. **Given** the row is armed **When** any other counted press or click arrives **Then** the arm clears and that press is handled exactly as today (a key resumes at the saved boss, a click elsewhere resumes). (533) [design call] D-S93-2.
7. **Given** the title entry gate (Story 9.1, `Game.title_input_open`) is closed **When** N is pressed **Then** nothing arms and nothing is consumed beyond the gate's existing rule. (533) [design call] D-S93-2.
8. **Given** a FIGHT whose attempt copy (`Game.run.assist`) differs from `SaveService.assist` (a mid-fight pause toggle) **When** the pause screen draws **Then** the assist row reads `[B] DEBUG BUILD ON: NEXT ATTEMPT` (or `OFF`), and its clickable rect is the same text's rect. The saved value still flips at once. (539, 544) [design call] D-S93-3.
9. **Given** no pending difference (outside FIGHT, or the copy equals the saved value) **When** `PauseScreen.lines_for(muted, assist, fullscreen)` is called with its defaults **Then** the rows are exactly today's (`[B] DEBUG BUILD ON` / `OFF`, `test_assist.gd` 352-353 unedited). (539, 544) [design call] D-S93-3.
10. **Given** the new strings **When** the text audit runs **Then** `PRESS N AGAIN: WIPE PROGRESS` is a field of `TextScreenText` (validated, in `all_text()`, ASCII, at most 40 columns at 2x) and the pause suffix row is at most 40 columns at 2x, ASCII. (533, 544) [design call] D-S93-4.
11. **Given** the story is done **When** the full GUT suite runs in CI order and `game/tools/check_guards.sh` runs **Then** both pass, and no replay hash changes (no sim state is written by the new code).
12. **Given** deferred-work.md items 528, 533, 539, 544 **When** the story is done **Then** each carries `**Resolved in Story 9.3 (D-S93-n):** ...` with its decision IDs, the original text stays, and no other item changes. (bookkeeping)

## Tasks / Subtasks

### Group A: Completed run (528, AC 1-4)

- [x] A1. `game/src/autoloads/save_service.gd`: add `var completed: bool = false` (doc: Story 9.3, D-S93-1, the run was cleared; never reset by N). `defaults()` gains `"completed": false`. `parse()` reads `completed` with a `false` default and rejects a non-bool (AC 4). `to_config(...)` gains a trailing `p_completed: bool = false` (existing 3- and 4-arg callers keep working) and writes the key. `_apply()` copies it. `save()` passes it. Update the header comment (keys list). `VERSION` and `READ_VERSIONS` unchanged. (AC 4)
- [x] A2. `save_service.gd`: `func note_run_cleared() -> void`: when `track_fights` is on, sets `completed = true` and calls `save()`. Idempotent (no write when already true). (AC 2)
- [x] A3. `save_service.gd` `note_fight_start(boss_index)`: before the existing `raised` logic, when `track_fights` and `boss_index == 0` and `completed`: set `completed = false`, `highest_boss = MIN_BOSS`, and save (one write); then the existing rule runs (it sees `highest_boss` 1 and raises to 1: no further write). The early return for `track_fights == false` stays first. (AC 3)
- [x] A4. `game/src/autoloads/game.gd` `_set_flow_state`: when `to == FlowState.ENDING and not practice_run and not stats.debug_jumped`, call `SaveService.note_run_cleared()`. Place it next to the existing `note_fight_start` call, in the presentation-side block, never in the sim. (AC 2)
- [x] A5. `game/src/autoloads/game.gd`: no change to `finish_ending`, `resume_run_from_title` or `start_new_run_from_title` (the title decides which one runs; see B1). Add `## Story 9.3` comment only where A4 lands.

### Group B: Title (528 + 533, AC 1, 5-7)

- [x] B1. `game/src/ui/screens/title/title_screen.gd`: add `var saved_completed: bool = false`. `_ready()` reads `SaveService.completed` next to `SaveService.highest_boss`. `set_saved_progress(highest_boss: int, completed: bool = false)` stores both and sets `available[&"new_run"] = highest_boss > 1 and not completed` (the rest of the function unchanged). `_begin(false)` resumes only when `saved_highest_boss > 1 and not saved_completed`; otherwise `start_run_from_title`. Practice keeps using `saved_highest_boss` (the full loadout set after a clear is intended). (AC 1)
- [x] B2. Title arm state: `var new_run_armed_frame: int = -1`. A pure static `new_run_armed(armed_frame: int, frame: int) -> bool` (true when `armed_frame >= 0 and frame >= armed_frame and frame < armed_frame + NEW_RUN_CONFIRM_FRAMES`) and `const NEW_RUN_CONFIRM_FRAMES := 90`. In `handle_input`, after the gate check (`Game.title_input_open`), for an `option == &"new_run"` press: if `new_run_armed(...)` then `_begin(true)`, else arm (`new_run_armed_frame = SimClock.sim_frame`, `queue_redraw()`) and return the action without starting. For any other counted press that resolves to START or OPTION while armed: clear the arm first, then run today's branch. (AC 5, 6, 7)
- [x] B3. Label while armed: `new_run_text()` returns `NEW_RUN_CONFIRM_TEXT` (audited, see D1) when armed, else `NEW_RUN_TEXT`. `_draw()` draws `new_run_text()`; the clickable rect uses the same text (`new_run_label_rect()` takes the text, default the normal label, so `test_save_service.gd` 425-426 keeps passing). The armed state lapses by itself: `_process` clears `new_run_armed_frame` when `not new_run_armed(...)` and redraws. Use `SimClock.sim_frame` (the same clock as the 9.1 gate). (AC 5)
- [x] B4. Keep the header comment of `title_screen.gd` in step: add a `Story 9.3` paragraph (completed run: no `[N]`, plain start is a fresh run; `[N]` needs a second press).

### Group C: Pause (539 + 544, AC 8, 9)

- [x] C1. `game/src/ui/screens/pause/pause_screen.gd`: `const ASSIST_PENDING_SUFFIX := ": NEXT ATTEMPT"` (code constant, like the other pause rows). `assist_text(assist: bool, pending: bool = false)` appends the suffix when `pending`. `assist_label_rect(assist, pending = false)` uses it. `lines_for(muted, assist = false, fullscreen = false, pending = false)` passes it through. `is_assist_toggle(event, assist, pending = false)` uses the same rect. Defaults keep today's strings. (AC 8, 9)
- [x] C2. `pause_screen.gd`: `static func assist_pending(flow_state: int, attempt_assist: bool, saved_assist: bool) -> bool` (pure): true when `flow_state == FIGHT` (`Game.FlowState.FIGHT`) and `attempt_assist != saved_assist`. An instance helper calls it with `Game.flow_state`, `Game.run.assist`, `SaveService.assist`. `_draw()` and `_input()` pass the live value; `_assist` keeps the saved value (it is the toggle source). Redraw when the pending value changes: track `_assist_pending` in `_process` like the fullscreen row, so a retry or a new attempt clears the suffix with no event. (AC 8)
- [x] C3. Title row (B on the title) stays as is (D-S93-3 default, open question O1). No change to `title_screen.gd` assist labels.

### Group D: Text (AC 10)

- [x] D1. `game/data/text/screen_text.tres`: `new_run_confirm_label = "PRESS N AGAIN: WIPE PROGRESS"`. `game/src/ui/text/text_screen_text.gd`: `@export var new_run_confirm_label: String = ""` (doc: Story 9.3, D-S93-2), `validate()` requires it non-empty, and `all_text()` includes it. Check `test_font_coverage.gd` still covers every `all_text()` glyph (the new string uses only existing glyphs: confirm by running it).
- [x] D2. `game/src/ui/screens/title/title_screen.gd`: `static var NEW_RUN_CONFIRM_TEXT: String` getter reading `SCREEN_TEXT.new_run_confirm_label`, like `NEW_RUN_TEXT`.
- [x] D3. Width: 28 columns at 2x (448 px) for the armed row and 33 columns for the pause row (528 px; D3 miscounted 32, see Completion Notes), both within the 640-px base. Assert in tests (AC 10).

### Group E: Tests

Follow the existing patterns: `test_save_service.gd` sets `track_fights = true` and a scratch `path` under `user://` in the test and restores both in `after_each` (see test around lines 265-330); title tests use `_title(highest)` helpers and `_key(...)` / `_click(...)` (`test_save_service.gd` 400-500, `test_title_input.gd`).

- [x] E1. `test_save_service.gd`: `test_completed_round_trips_and_defaults_false` (to_config with completed, parse; a v1 file reads false), `test_completed_wrong_type_is_invalid`, `test_note_run_cleared_writes_once` (second call no write, use a spy on file mtime or check `completed` only), `test_fresh_fight_one_after_completed_resets_progress` (highest 3, completed true, `note_fight_start(0)`: highest 1, completed false, file has both), `test_fresh_fight_one_without_completed_keeps_progress` (existing rule), `test_debug_or_practice_ending_does_not_mark_completed` (Game-level, track on, `debug_jumped` true / practice), `test_ending_entry_marks_completed` (Game-level: enter ENDING via the existing test helpers used by `test_ending_and_new_run_never_lower`).
- [x] E2. `test_title_input.gd` or `test_save_service.gd`: `test_completed_save_hides_new_run_and_starts_fresh` (`set_saved_progress(3, true)`: not available, no rect; `handle_input(_key(KEY_SPACE))` path ends in `start_run_from_title`, `Game.flow_state` INTRO, not FIGHT at boss 3). Use the same stubbing pattern as `test_other_key_with_save_resumes_at_boss_two`.
- [x] E3. Title arm: `test_n_arms_then_second_n_wipes` (SimClock.sim_frame set to 100, N -> label text is `NEW_RUN_CONFIRM_TEXT`, state still TITLE, `SaveService.highest_boss` 3; sim_frame 150, N -> reset, INTRO); `test_arm_lapses_after_ninety_frames` (N at 100, N at 190 re-arms, not start); `test_other_key_disarms_and_resumes` (save at highest 3, N at 100, Space at 110: the arm clears and the press resumes at the saved boss, as today, `Game.resume_run_from_title` path, `SaveService.highest_boss` still 3); `test_click_on_armed_row_confirms` (click the rect twice); `test_arm_ignored_inside_the_title_gate` (title entry gate closed: N neither arms nor starts; reuse the 9.1 gate helper in `test_title_entry_gate.gd`).
- [x] E4. Pause: `test_assist_row_reads_next_attempt_when_pending` (`lines_for(false, true, false, true)[-2] == "[B] DEBUG BUILD ON: NEXT ATTEMPT"`), `test_assist_pending_only_in_fight` (pure helper: FIGHT and differing true; INTRO/DEAD/HARVEST false; equal false), `test_pending_rect_matches_the_drawn_row` (`assist_label_rect(true, true)` covers `TitleScreen.centred_x` of the suffixed text), `test_defaults_unchanged` (`lines_for(false, true)[-2] == "[B] DEBUG BUILD ON"`, already in test_assist 352; assert it again next to the new test).
- [x] E5. Text audit (`test_text_audit.gd`): `test_new_run_confirm_label_is_audited` (`SCREEN.validate()` empty, `SCREEN.new_run_confirm_label` in `all_text()`, `TitleScreen.NEW_RUN_CONFIRM_TEXT` equals it, length <= 28 chars, ASCII) and `test_pause_suffix_fits` (the suffixed assist row length <= 40 chars, ASCII).

### Group F: Bookkeeping

- [x] F1. `_bmad-output/implementation-artifacts/deferred-work.md`: append `**Resolved in Story 9.3 (D-S93-n):** ...` to the bullets for 528 (D-S93-1), 533 (D-S93-2), 539 and 544 (D-S93-3). Keep the original text. Touch nothing else.
- [x] F2. Set this story's status with the Edit tool when the work is done (`review`, then `done` before the commit). `sprint-status.yaml` `9-3-run-and-assist-clarity` accordingly (now `ready-for-dev`, set by this create-story run).

## Dev Notes

### Verified facts (read from the code on 2026-11-17, branch story/9-3 on b3c766a)

- **Title reads the save once.** `title_screen.gd` `_ready()` calls `set_saved_progress(SaveService.highest_boss)` and `set_assist_shown(SaveService.assist)`. `set_saved_progress` (~line 230) sets `available[&"new_run"] = highest_boss > 1` and the clickable rect. `_begin(false)` resumes with `Game.resume_run_from_title(frame, saved_highest_boss)` when `saved_highest_boss > 1`, else `start_run_from_title`. This is the 528 mechanism.
- **The ending never clears the save.** `game.gd` `finish_ending` (~571) resets `run`, `stats` and the flow only. `SaveService.highest_boss` is never lowered on a clear: `note_fight_start` only raises (`raised == highest_boss` returns early), and `reset_run_progress` runs only from `start_new_run_from_title`. The 7.3 rule "never lowers" is preserved by D-S93-1 (the reset runs only with `completed`).
- **`[N]` today.** `title_screen.gd` `handle_input` runs `_begin(true)` on the first counted N (or the click on its rect), which calls `Game.start_new_run_from_title`, which calls `SaveService.reset_run_progress()` then `start_run_from_title`. No arm state exists.
- **Title gate (9.1).** `handle_input` returns IGNORE when `Game.title_input_open(SimClock.sim_frame)` is false, after `AudioManager.unlock()`. The arm must sit after that check. `Game.title_entry_frame` is set in `_set_flow_state` when TITLE is entered from elsewhere.
- **Assist is copied per attempt.** `Game._begin_fight()` (~line 825) runs on every FIGHT entry, retries included (`_set_flow_state` calls it unconditionally for `to == FIGHT`), and sets `run.assist = SaveService.assist`. So a toggle reaches the next FIGHT entry: the next boss, a retry, or the next run. A toggle mid-fight changes nothing for the fight in progress. This is D-S74-1.
- **Pause row.** `pause_screen.gd` `_input` calls `SaveService.set_assist(not _assist)` and sets `_assist` from the saved value, so the row flips at once (544). `lines_for` default args are used by `test_assist.gd` 352-353 and `test_pause_screen.gd` 8-25 (`[-2]` and `[-3]` indices: keep the row count and order).
- **Save format.** `VERSION` 2, `READ_VERSIONS` [1, 2]. `tutorial_done` (8.2) was added the same way: a missing key reads as the default, a v1 file loads. `completed` follows that pattern.
- **Text.** `TextScreenText` carries title strings; `test_text_audit.gd` checks `SCREEN.validate()` and the ASCII rule through `all_text()`. Pause rows are code constants (not audited), as 7.4 review noted; the width is asserted in a test instead.
- **Clock.** `SimClock.sim_frame` advances on every unpaused tick, title included (the 9.1 gate relies on it). The `[N]` window is counted in it.

### Design calls (Story 9.3)

- **[design call] D-S93-1 (528): a `completed` key, set at ENDING entry, cleared on a fresh Fight 1.** Default: `SaveService.completed` (bool, missing = false, no VERSION bump). Set in `_set_flow_state` when ENDING is entered (not practice, not debug-jumped; `track_fights` seam in `note_run_cleared`), so a tab closed during the ending still counts. The title with `completed`: no `[N] new run` row, a plain start runs `start_run_from_title` (Intro). Fight 1 of the next run (`note_fight_start(0)`) clears `completed` and resets `highest_boss` to 1 in one save, so the new run's own progress is what the title later resumes. Practice keeps the full loadout set while `completed` (it reads `highest_boss`, unchanged). Rejected: resetting `highest_boss` to 1 at clear (would shrink practice loadouts after a clear). Rejected: resetting at ENDING exit (a tab closed during the ending would resume into boss 3 again).
- **[design call] D-S93-2 (533): two-press `[N]`.** Default: the first N (or the click on the row) arms; the row reads `PRESS N AGAIN: WIPE PROGRESS` for 90 sim frames (1.5 s); a second N or a click on that row inside the window confirms (reset and Intro, as today). Any other counted press clears the arm and is handled as today. The arm sits after the 9.1 gate, so a press inside the gate neither arms nor starts. The first N does not wipe and does not start, so nothing is lost on a stray press. Rejected: a modal with a Y/N row (more text and layout, and the title has no free row).
- **[design call] D-S93-3 (539, 544): a pending suffix on the pause row only.** Default: while a FIGHT is running and `Game.run.assist` differs from `SaveService.assist`, the assist row reads `[B] DEBUG BUILD ON: NEXT ATTEMPT` (`OFF` likewise). The suffix clears by itself when the next attempt starts (the copy catches up). The saved value and the `[B]` toggle behave as today. Outside FIGHT the row reads the plain value (the next FIGHT entry applies it). Rejected: a second row (no free row between 240 and 352 at 2x; the pause rows already fill the 360-px base).
- **[design call] D-S93-4 (AC 10): text placement.** The armed title label is audited game text (`screen_text.tres`, `new_run_confirm_label`). The pause suffix stays a code constant, width asserted in tests, because the pause rows are not audited (7.4 review).

### Open questions (defaults chosen, no elicitation)

- **O1 (title B toggle):** the title's `[B] debug build on/off` row does not say "next run". Default: unchanged (the title has no attempt in progress, and the next run is the only thing it can affect). Revisit if H-S74-1 shows confusion on the title.
- **O2 (clear marked at ENDING entry, not exit):** a debug-jumped run into ENDING is not marked (mirrors `note_fight_start`). Default: as written.
- **O3 (`completed` and practice):** after a clear, practice still shows the full loadout set via `highest_boss`. Default: intended.
- **O4 (`completed` and a debug jump to fight 1):** `note_fight_start` is skipped for debug jumps, so `completed` stays set until a real fresh Fight 1. Default: as written.

### Testing

- GUT suite in CI order (`--headless --import` first, as in `.github/workflows`), the FULL suite. `check_guards.sh` must pass (run it; the new code is presentation-side and adds no sim-side reads of `SaveService` or `Game`).
- Seed nothing new: no RNG is involved.
- The 9.1 gate tests (`test_title_entry_gate.gd`) and the 7.4 assist tests (`test_assist.gd`) must pass unedited.

### Project Structure Notes

- No new files. Edits to: `game/src/autoloads/save_service.gd`, `game/src/autoloads/game.gd` (one call in `_set_flow_state`), `game/src/ui/screens/title/title_screen.gd`, `game/src/ui/screens/pause/pause_screen.gd`, `game/src/ui/text/text_screen_text.gd`, `game/data/text/screen_text.tres`, tests under `game/tests/unit/` (`test_save_service.gd`, `test_title_input.gd`, `test_pause_screen.gd`, `test_assist.gd`, `test_text_audit.gd`), `deferred-work.md`, `sprint-status.yaml`.

### References

- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Story 7.3 and #Story 7.4 (lines 528, 533, 539, 544)]
- [Source: _bmad-output/implementation-artifacts/9-2-miss-feedback-polish.md] (story format, stacking)
- [Source: game/src/autoloads/save_service.gd] (D-S73-1 keys, D-S82-8 tutorial_done pattern)
- [Source: game/tests/unit/test_save_service.gd#test_ending_and_new_run_never_lower] (existing rule kept)

## Project Context Rules

- Godot 4 GDScript. Text is ASCII, the glyph font only, ink-only visuals (`Palette.INK`), 640x360 base.
- Presentation may read and write SaveService; the sim tick never does (AC 12 of 7.3).
- `game/tools/check_guards.sh` must pass; GUT full suite must pass in CI order.
- Set story status with the Edit tool, never sed.
- Never commit to main; this story's branch is stacked on story/9-2.

## Dev Agent Record

### Agent Model Used

Claude (gds-create-story, unattended); Claude Opus (gds-dev-story, unattended)

### Debug Log References

- Full GUT suite in CI order (`--headless --import`, then `gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`): 1905/1905 passing, "All tests passed!", no CI failure marker. One orphan (`EndingScreen` in `test_ending_screen.gd::test_screen_name_and_no_game_text_literal`), in a suite this story does not touch (not a CI marker).
- `game/tools/check_guards.sh`: OK.

### Completion Notes List

- Ultimate context engine analysis completed (create-story, unattended). Story is ready-for-dev; no code written.
- D-S93-1..4 and O1-O4 defaults implemented as written (coordinator accepted them).
- A (528): `SaveService.completed` (v2 key, missing = false, wrong type = invalid file; `VERSION` 2, `READ_VERSIONS` unchanged). `to_config` gains a trailing `p_completed`. `note_run_cleared()` (track_fights seam, idempotent). `note_fight_start(0)` with `completed` clears it and resets `highest_boss` to 1 in one write, then the 7.3 raise rule runs unchanged (`test_ending_and_new_run_never_lower` passes unedited). `Game._set_flow_state` calls `note_run_cleared()` on ENDING entry when not practice and not debug-jumped (presentation-side, next to the 7.8 metrics line).
- B (528, 533): the title reads `SaveService.completed`; with it `[N]` is hidden and a plain start runs `start_run_from_title` (Intro). `[N]` is two-press: `new_run_armed(armed_frame, frame)` pure, `NEW_RUN_CONFIRM_FRAMES` 90, `SimClock.sim_frame`; the armed row draws `NEW_RUN_CONFIRM_TEXT` and its clickable rect follows the drawn text; `_process` lapses the arm. Any other counted press clears the arm, then runs today's branch. The arm sits after the 9.1 gate. `set_saved_progress` also clears the arm.
- C (539, 544): `PauseScreen.ASSIST_PENDING_SUFFIX`, `assist_pending(flow_state, attempt, saved)` pure, `live_assist_pending()` instance helper (Game.flow_state, Game.run.assist, SaveService.assist); `lines_for` / `assist_text` / `assist_label_rect` / `is_assist_toggle` take a trailing `pending = false` (defaults unchanged, `test_assist.gd` unedited). `_process` redraws when the pending value changes.
- D: `new_run_confirm_label = "PRESS N AGAIN: WIPE PROGRESS"` in `screen_text.tres`, validated and in `all_text()` (font coverage passes).
- Deviation (D3 width): `[B] DEBUG BUILD OFF: NEXT ATTEMPT` is 33 columns, not 32 as D3 counted (ON is 32). AC 10's own bound (at most 40 columns, ASCII) holds; the test asserts <= 40 columns and that both rows sit inside the pause screen's 16-px gutter (528 px <= 608 px).
- Existing tests updated for the new behaviour (AC 5): `test_n_resets_and_goes_to_intro` and `test_click_on_label_is_the_same_as_n` now press twice (and assert the first press wipes nothing).
- Cross-suite state: `SaveService.completed` is added to the SaveService save/restore dicts in `test_save_service.gd`, `test_practice_flow.gd`, `test_title_entry_gate.gd` and `test_tutorial_flow.gd` (the suites that turn `track_fights` on or save `tutorial_done`). Under GUT `track_fights` is off, so the autoload never sets it outside those tests.
- Compatibility: the 9.1 entry gate (`Game.title_entry_frame`) and the 8.2 `tutorial_done` flag are untouched; a new run after a clear never clears `tutorial_done` (only `completed` and `highest_boss` reset on Fight 1). No sim code reads the new state; replays unchanged.
- TDD note: tests and code were written in one pass per group, then the full suite run; the two pre-existing single-press N tests are the red cases for AC 5 under the old code.

### File List

- game/src/autoloads/save_service.gd
- game/src/autoloads/game.gd
- game/src/ui/screens/title/title_screen.gd
- game/src/ui/screens/pause/pause_screen.gd
- game/src/ui/text/text_screen_text.gd
- game/data/text/screen_text.tres
- game/tests/unit/test_save_service.gd
- game/tests/unit/test_pause_screen.gd
- game/tests/unit/test_text_audit.gd
- game/tests/unit/test_practice_flow.gd
- game/tests/unit/test_title_entry_gate.gd
- game/tests/unit/test_tutorial_flow.gd
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/9-3-run-and-assist-clarity.md

### Change Log

- 2026-11-17: story created (ready-for-dev) by gds-create-story, unattended.
- 2026-11-17: implemented (gds-dev-story, unattended): completed-run flag, two-press [N], pause next-attempt suffix, audited confirm label, 28 new tests; status review.
- 2026-11-17: code review (gds-code-review, unattended; Blind Hunter, Edge Case Hunter, Acceptance Auditor). Fixed: a wrong-typed `completed` now reads false instead of invalidating the whole save (test renamed `test_completed_wrong_type_reads_false_and_keeps_the_save`); `handle_input` clears a lapsed arm before the click test so the wide armed rect cannot re-arm after the window; story text corrections (33 columns, 28 tests). Dismissed: tutorial replay resetting a completed save at Fight 1 is the intended fresh-run path (3.1 note_fight_start); `_input` pending rect equals the drawn one (both live). Deferred (low): no NEXT ATTEMPT suffix in the TUTORIAL state; `test_live_pending_follows_the_attempt_copy` restores state inline, not in after_each; no direct test of the `_process` arm lapse or of the pending-rect click through `_input`.
