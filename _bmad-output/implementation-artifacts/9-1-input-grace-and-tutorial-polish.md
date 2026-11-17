---
baseline_commit: 56c5cff
---

# Story 9.1: Input Grace and Tutorial Polish

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from main 56c5cff (first Epic 9 story, no parent branch). Sources: Epic 9 in epics.md, the brief epic9-brief.md and the triage epic9-triage.md (both in gameoff-wt/). Self-made choices are marked [design call] D-S91-n; the implementer follows them or records a change in Completion Notes. Scope: deferred-work.md items 617, 554a, 577, 618a, 618b, 618c. -->

## Story

As a player,
I want stray presses and held buttons at a screen change to do nothing, and the tutorial's hint, completion rows and starting device to read right,
so that a tutorial replay, an Ending or a practice leave never drops me into a run by accident, and the tutorial names the right keys from the first frame.

**Requirements:** deferred-work.md 617 (8.2 review, medium), 554a (7.5 review), 577 (7.7 review), 618a, 618b, 618c (8.2 review, low); triage 9-1 and the coordinator adjustments in the brief; D-S91-1..7 below. Presentation and input only: no sim state changes, no save change, replays unchanged.

## Acceptance Criteria

1. **Given** TITLE is entered from any other state (the tutorial replay ends, an Ending ends, or a practice run is left from FIGHT or DEAD) **When** a non-option key, a left click or a pad button arrives within `TITLE_ENTRY_GATE_FRAMES` (30) sim frames of that entry **Then** nothing starts or resumes a run (617, 554a). [design call] D-S91-1, D-S91-2.
2. **Given** the same gate **When** an option key (`N`, `P`, `B`, `F`, `T`) or a pad option button (R3 fullscreen, L3 practice, Select new run, B assist, the `T` option has no pad button) arrives **Then** the option action is not taken either (577: a held R3 cannot toggle fullscreen on the title). [design call] D-S91-1.
3. **Given** a counted press is ignored by the gate **When** it arrives **Then** `AudioManager.unlock()` still runs for it, so the first click that unlocks web audio is never delayed. [design call] D-S91-1.
4. **Given** the gate has passed **When** the same press arrives **Then** it behaves exactly as today (START starts, option keys act), and the gate never delays a press by more than its window.
5. **Given** first boot (the title is the initial state, no `_set_flow_state` call) **When** any key or click starts the run **Then** behaviour is unchanged: the gate is never armed. [design call] D-S91-1.
6. **Given** a DEAD, INTRO or ENDING entry with a pad button or key held from combat **When** the state is entered **Then** the existing gates hold: the DEAD retry needs a new press at least `RETRY_DELAY_FRAMES` (20) after death, the Intro skip needs a press after `first_input_frame`, and the ENDING leave needs `ENDING_LEAVE_GATE_FRAMES` (60). No new gate is added there; tests pin the three existing gates (554a). [design call] D-S91-3.
7. **Given** the tutorial hint line **When** it is drawn for the keyboard or the pad **Then** it is two 1x rows under the skip hold bar, the skip hold then the pause key, with the device names (`P: pause` and `START: pause`; D-S91-4 two-row fallback), at most 64 columns, every row ASCII, and no row overlaps a checklist row or the skip hold bar (618a). [design call] D-S91-4.
8. **Given** the completion rows `ALL TESTS PASSED.` and `deploying to production...` **When** they are drawn **Then** they sit in the bottom band of the play area (above the bottom edge, where the prompt is empty once every test passed), their BG backing does not touch the player `@` rectangle at `Arena.SPAWN_PX` or the dummy rectangle at `Arena.TUTORIAL_DUMMY_PX`, and a test asserts both (618b). [design call] D-S91-5.
9. **Given** the tutorial screen is built **When** a joypad is connected (`Input.get_connected_joypads()` non-empty) **Then** its device starts as GAMEPAD, otherwise KEYBOARD (618c). [design call] D-S91-6.
10. **Given** a trigger axis (`JOY_AXIS_TRIGGER_LEFT` or `JOY_AXIS_TRIGGER_RIGHT`) at rest, reading below the press threshold (including a rest value of -1 on some pads) **When** its motion event arrives **Then** the device does not flip to GAMEPAD; a value of 0.5 or more on the positive side does. Stick motion keeps its current rule (`absf(axis_value) >= 0.5`). (618c) [design call] D-S91-7.
11. **Given** the story's tests **When** the full GUT suite runs in CI order **Then** it passes, `game/tools/check_guards.sh` passes, and the text audit still passes with the new hint string.
12. **Given** the story is done **When** `deferred-work.md` is edited **Then** items 617, 554a, 577, 618a, 618b and 618c each carry "Resolved in Story 9.1" (with the decision ID), the original text stays, and no other item changes.

## Tasks / Subtasks

### Group A: Title entry gate (617, 577, 554a)

- [x] A1. `game/src/autoloads/game.gd`: add `const TITLE_ENTRY_GATE_FRAMES := 30` next to `ENDING_LEAVE_GATE_FRAMES` (with a `## Story 9.1` comment), and `var title_entry_frame: int = -1` (sim frame of the last non-TITLE to TITLE entry; -1 at boot). (AC 1, 5)
- [x] A2. `game/src/autoloads/game.gd` `_set_flow_state(to)`: when `to == FlowState.TITLE and from != FlowState.TITLE`, set `title_entry_frame = SimClock.sim_frame`; otherwise leave it. Boot never calls `_set_flow_state`, so first boot stays un-gated. (AC 1, 5)
- [x] A3. `game/src/autoloads/game.gd`: add a pure `static func title_gate_open_at(entry_frame: int, frame: int) -> bool` (true when `entry_frame < 0` or `frame >= entry_frame + TITLE_ENTRY_GATE_FRAMES`) and an instance `func title_input_open(frame: int) -> bool` that calls it for `title_entry_frame`. Mirror the shape of `ending_leave_open_at` / `can_leave_ending`. (AC 1, 4)
- [x] A4. `game/src/ui/screens/title/title_screen.gd` `handle_input(event)`: after `resolve(event)` and before any `_begin*` call, if `action != IGNORE` and `not Game.title_input_open(SimClock.sim_frame)`, call `AudioManager.unlock()` and return `Action.IGNORE` (the press is consumed, nothing starts, no option acts). Keep the existing `_started` / `flow_state != TITLE` guard first. Do not change `classify`, `option_of` or `resolve`, so the pure classifier tests keep their meaning. (AC 1-4)
- [x] A5. `game/src/ui/screens/title/title_screen.gd` `_unhandled_input`: no change needed (it calls `handle_input`); verify that a gated press is still consumed with `set_input_as_handled()` only when the action is not IGNORE, so the DEAD and other screens never see a gated press. Record the decision in Completion Notes. (AC 1)
- [x] A6. `game/src/ui/screens/dead/dead_screen.gd` and `game/src/autoloads/game.gd` `leave_practice_to_title`: no change; the practice leave (L3 on DEAD or FIGHT) arms the gate through A2. Verify by test (see Testing). (AC 1)
- [x] A7. Pin 554a with tests, no new production code: `retry_open` gate (20 frames), `can_skip_intro` (frame > `first_input_frame`), `can_leave_ending` (60 frames). Add the assertions in `tests/unit/test_game_flow.gd` or `tests/unit/test_dead_screen.gd` if they are missing. (AC 6)

### Group B: Tutorial hint and completion rows (618a, 618b)

- [x] B1. `game/src/ui/screens/tutorial/tutorial_screen.gd` `PLACEHOLDERS`: add `"{pause}": &"pause"`. `KEY_NAMES[&"pause"]` is already `"P"` and `PAD_NAMES[&"pause"]` is already `"START"` (these were dead entries before this story). (AC 7)
- [x] B2. `data/text/screen_text.tres` `tutorial_hint_skip`: change to `hold {skip}: skip  {pause}: pause` (two spaces). Keep it ASCII. Check the `validate()` path in `game/src/ui/text/text_screen_text.gd` still accepts it. (AC 7)
- [x] B3. Overlap check (pure, testable): compute the hint rect with `TutorialChecklistView.hint_top_left` and `GlyphFont.text_width` at `PROMPT_SCALE`, and the checklist row rects with `row_top_left(i)` at `TEST_SCALE` for every `[PASS]` or `[ ]` variant (`checklist_lines` widths). Assert no intersection, including the 2 px BACKING. Put the test in `tests/unit/test_tutorial_screen.gd` next to `test_every_row_fits_the_play_area_and_clears_the_dummy`. If the overlap check fails with the chosen text, apply the fallback in D-S91-4. (AC 7)
- [x] B4. `game/src/presentation/tutorial_checklist_view.gd`: replace `const DONE_TOP := 136.0` with a bottom-band anchor. Default: `done_top_left(text, i)` returns y = `Arena.play_area().end.y - PROMPT_BOTTOM_MARGIN - DONE_STEP * (rows - 1 - i) - GlyphFont.CELL * TEST_SCALE` (rows = `done_lines().size()`), so the two rows sit at y 240 and 264 in the 288-px play area. Keep `DONE_STEP` and the x centring. Remove `DONE_TOP` only if nothing else reads it (grep `DONE_TOP` first). (AC 8)
- [x] B5. `tests/unit/test_tutorial_screen.gd`: add `test_completion_rows_clear_the_spawn_and_the_dummy`: for each `done_top_left` row rect (with BACKING), assert no intersection with the `@` rect (`Arena.SPAWN_PX` plus or minus half a 2x cell, the same rect `PlayerView` draws) and with the dummy rect (`Arena.TUTORIAL_DUMMY_PX` plus or minus the dummy glyph half-size; read the dummy's draw size from `game/src/bosses/tutorial_dummy/tutorial_dummy_body.gd` or its view, do not guess), and that every row stays inside `Arena.play_area()` (use `fits_play_area`). (AC 8)

### Group C: Device default and trigger rule (618c)

- [x] C1. `game/src/ui/screens/tutorial/tutorial_screen.gd` `_ready()`: set `device = Device.GAMEPAD if not Input.get_connected_joypads().is_empty() else Device.KEYBOARD` before `_refresh_view()`. Do not add a new field. (AC 9)
- [x] C2. `tutorial_screen.gd` `static func device_for(event, current)`: for `InputEventJoypadMotion`, use `motion.axis_value >= 0.5` when `motion.axis` is `JOY_AXIS_TRIGGER_LEFT` or `JOY_AXIS_TRIGGER_RIGHT`; keep `absf(motion.axis_value) >= 0.5` for every other axis. Keep the function pure. (AC 10)
- [x] C3. `tests/unit/test_tutorial_screen.gd` `test_device_follows_the_last_input`: the default assertion at line ~60 (`assert_eq(screen.device, KB, "the default is the keyboard")`) changes to a connected-pad case. Make the default depend on `Input.get_connected_joypads()` through a seam or by asserting the rule only for the no-pad case (the headless CI has no pad). Add trigger cases: rest -1.0 and 0.0 keep the device, 0.6 flips it. (AC 9, 10)

### Group D: Tests and text

- [x] D1. `tests/unit/test_tutorial_screen.gd` line ~92: `"hold Esc or Bksp: skip"` becomes `"hold Esc or Bksp: skip  P: pause"`; line ~136 (the pad hint) updated to `"hold SELECT: skip  START: pause"`. (AC 7)
- [x] D2. `tests/unit/test_text_audit.gd` `test_tutorial_text_is_audited`: add `TutorialScreen.prompt_text(SCREEN.tutorial_hint_skip, device)` length <= 64 for both devices and ASCII. (AC 7, 11)
- [x] D3. `tests/unit/test_title_input.gd` (or a new `tests/unit/test_title_entry_gate.gd` if the file gets crowded): gate tests with a fixed `SimClock.sim_frame`: (a) `title_gate_open_at` table: `(-1, 0)` open, `(10, 39)` closed, `(10, 40)` open; (b) after `Game._set_flow_state(FlowState.TITLE)` from TUTORIAL, a `_key(KEY_J)` and a click are IGNORED by `TitleScreen.handle_input`, a `_pad(JOY_BUTTON_RIGHT_STICK)` does not toggle `Fullscreen` (use the `Fullscreen.get_mode_fn` / `set_mode_fn` seam from `test_fullscreen.gd`), and `AudioManager.unlock` is still called (check the flag via `AudioManager._unlocked` or the existing test seam used in `test_title_input.gd` around line 96); (c) after the gate, the same J key starts the run; (d) a boot title (no state change) starts on the first key with `title_entry_frame == -1`. Restore `SimClock.sim_frame`, `Fullscreen` seams and `Game` state in `after_each`. (AC 1-5)
- [x] D4. `tests/unit/test_gamepad.gd` `test_title_pad_buttons_start_the_run` / `test_title_option_buttons`: unchanged behaviour outside the gate; add one gated case for `JOY_BUTTON_A` and `JOY_BUTTON_RIGHT_STICK`. (AC 2)
- [x] D5. `tests/unit/test_tutorial_flow.gd` `test_replay_from_title_ends_at_title`: assert that the title that follows a replay has `Game.title_entry_frame == SimClock.sim_frame` at entry and that `title_input_open` is false immediately. (AC 1)
- [x] D6. `tests/integration/test_ending_flow.gd`: one assertion that the ENDING to TITLE return arms the gate (leave press after the 60-frame gate, then the title ignores a key until 30 frames pass). (AC 1)
- [x] D7. `tests/unit/test_fullscreen.gd` `test_title_f_r3_and_click_toggle_without_leaving_title`: unchanged on boot; add a gated R3 case that does not toggle. (AC 2)

### Group E: Deferred work bookkeeping

- [x] E1. `_bmad-output/implementation-artifacts/deferred-work.md`: append "Resolved in Story 9.1 (D-S91-n)" to the lines for 617, 554a, 577, 618a, 618b and 618c (the existing text is kept). Do not delete history. (AC 12)
- [x] E2. Set this story's status with the Edit tool when the work is done (`review`, then `done` before the commit), and `sprint-status.yaml` `9-1-input-grace-and-tutorial-polish` accordingly. Do not change it now beyond `ready-for-dev`.

## Dev Notes

### Verified facts (read from the code on 2026-11-17, main 56c5cff)

- **Title is re-created per show.** `game/src/main/main.gd` `_make_screen(TITLE)` builds a new `TitleScreen`; `apply_flow_state` frees the old screen. `TitleScreen._begin*` calls `queue_free()` after one start. So title state cannot be carried on the title node; the gate lives in `Game` (`title_entry_frame`).
- **Entries to TITLE** (all go through `Game._set_flow_state`): `finish_tutorial` for a replay (`tutorial_replay`), `finish_ending` (ENDING, after its 60-frame leave gate), `leave_practice_to_title` (practice FIGHT or DEAD, L3 or Esc), `debug_jump(TITLE)`. Boot starts in `flow_state = TITLE` with no transition.
- **Existing gates already cover part of 554a.** DEAD: `Game.retry_open` needs `frame - death_frame >= RETRY_DELAY_FRAMES` (20); `DeadScreen.is_retry_press` reacts to press edges only (not held). ENDING: `can_leave_ending` needs `ENDING_LEAVE_GATE_FRAMES` (60). INTRO: `can_skip_intro` needs `frame > first_input_frame`. So the new gate is needed for TITLE only.
- **Title input path.** `TitleScreen.handle_input` -> `resolve` -> `classify` (pure) -> `option_of` (keys and pad via `InputMap` action `title_option_*`: N, P, B, F, T and pad Select, B, R3, L3). A pad A press starts the run (`classify` returns START for any non-option pad button). Clicks: START unless on an option label rect.
- **`AudioManager.unlock()`** is flag-only (audio_manager.gd line ~421); calling it on a gated press is harmless.
- **Sim clock.** `SimClock.sim_frame` advances in TITLE as well (it is the world tick, not a fight tick; `Game.ending_leave_open_at` and the tutorial outro already count it outside FIGHT). Verify once in a test that `title_entry_frame` and the frame counter move together under GUT.
- **Hint text.** `data/text/screen_text.tres` line 22: `tutorial_hint_skip = "hold {skip}: skip"`. `TutorialScreen.PLACEHOLDERS` maps `{move} {j} {k} {shift} {skip}` only, so `{pause}` is currently an unmapped token. `KEY_NAMES` and `PAD_NAMES` already carry `pause` (dead entries). The hint is drawn at 1x with `TutorialChecklistView.hint_top_left` (top-right, 8 px margin) and a hold bar 2 px under it.
- **Checklist geometry.** Play area 512x288 (`Arena.play_area()`), tile 16 px, `SPAWN_PX = (256, 144)`, `TUTORIAL_DUMMY_PX = SPAWN_PX + (8, -2) tiles = (384, 112)`. Checklist rows at 2x start x 24, y 16 + 16*i (up to 6 rows, widest `[PASS] test_actions` about 304 px wide). Prompt rows at 1x along the bottom, empty once every test passed (`prompt_rows` returns none).
- **Completion rows** (`done_top_left`): currently `DONE_TOP = 136`, 2x, centred, 24 px apart, so they cover y 136 to 176 and the `@` at y 144 to 160. This is the 618b defect.
- **Device.** `TutorialScreen.device` defaults to `Device.KEYBOARD` (line 49). `device_for` treats any `InputEventJoypadMotion` with `absf(axis_value) >= 0.5` as GAMEPAD, so a trigger reading -1 at rest flips it (618c).
- **Existing tests that change:** `tests/unit/test_tutorial_screen.gd` default-device assertion (~line 60), hint assertions (~lines 92 and 136). `test_text_audit.gd` checks prompt rows only, so add the hint row.
- **Build guard:** `game/tools/check_guards.sh` must pass. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). Run GUT like CI (`--headless --import` first).

### Design calls (Story 9.1)

- **[design call] D-S91-1 Title entry gate.** A non-TITLE to TITLE entry arms a gate of `TITLE_ENTRY_GATE_FRAMES = 30` sim frames (0.5 s at 60 Hz). Inside the gate, every counted title press (key, click, pad button) is consumed without acting, including option keys and pad option buttons, because 577 is a held R3 that IS an option. `AudioManager.unlock()` still runs on such a press. Boot never arms it. Alternative rejected: gate only START presses (the triage default), which leaves a held R3 able to toggle fullscreen (577).
- **[design call] D-S91-2 Frames, not wall time.** The gate counts `SimClock.sim_frame`, so it freezes with pause and is deterministic under test.
- **[design call] D-S91-3 No new gate for DEAD, INTRO or ENDING.** Existing gates cover 554a; a test pins them. Adding a fourth gate would change the Ending and retry timings already tuned by playtest notes.
- **[design call] D-S91-4 Hint row.** `hold {skip}: skip  {pause}: pause` (keyboard `P`, pad `START`), one row, using the `{pause}` placeholder. Fallback if B3 finds an overlap with a `[PASS]` checklist row: keep the skip text, and draw `{pause}: pause` on a second 1x row directly under the hold bar at y 20 (the bar moves to y 30), re-checked by B3.
- **[design call] D-S91-5 Completion rows in the bottom band.** The rows move from y 136 to y 240 and 264 (bottom-anchored), where no prompt is drawn once every test passed. The `@` and the dummy stay clear. Alternative rejected: a centred row above the dummy, which the dummy's damage numbers would cover.
- **[design call] D-S91-6 Device default.** GAMEPAD when a joypad is connected at `_ready`, KEYBOARD otherwise. A keyboard player with a pad plugged in sees pad names until the first key press (accepted, the first input fixes it).
- **[design call] D-S91-7 Trigger rule.** A trigger counts as pressed only at a positive value of 0.5 or more. Rest values of 0 or -1 never flip the device. Sticks keep the absolute rule.

### Open questions (defaults chosen, no elicitation)

1. Gate length 30 frames: default 30. If playtest shows the title feels laggy, 20 is the next choice (no test depends on the exact value except D3).
2. Gate scope: default all counted presses including option keys (D-S91-1). Alternative: START only, leaves 577 open.
3. Hint overlap with a `[PASS]` row: default is one row (D-S91-4); the two-row fallback is applied only if B3 fails.
4. Completion rows: default bottom band (D-S91-5); a human visual check (triage H row 618b) stays HUMAN until a real build is looked at.
5. Keyboard player with a pad connected: default accepts pad names until the first key (D-S91-6).

### Testing

- Unit: `tests/unit/test_title_input.gd`, `tests/unit/test_title_entry_gate.gd` (new, only if needed), `tests/unit/test_gamepad.gd`, `tests/unit/test_fullscreen.gd`, `tests/unit/test_tutorial_screen.gd`, `tests/unit/test_text_audit.gd`, `tests/unit/test_tutorial_flow.gd`, `tests/unit/test_game_flow.gd`, `tests/unit/test_dead_screen.gd`.
- Integration: `tests/integration/test_ending_flow.gd`.
- Seed nothing new: no boss RNG is involved. Reset `SimClock.sim_frame`, `Fullscreen` seams, `AudioManager` unlock flag and `Game.flow_state` in `after_each`.
- Full GUT suite, CI command, plus `game/tools/check_guards.sh`.

### Project Structure Notes

- All production changes are in `game/src/autoloads/game.gd`, `game/src/ui/screens/title/title_screen.gd`, `game/src/ui/screens/tutorial/tutorial_screen.gd`, `game/src/presentation/tutorial_checklist_view.gd` and `game/data/text/screen_text.tres` (path under `game/data/text/`). No new scene, no save key, no new autoload.
- Text lives in `screen_text.tres` (Story 6.9 audit). No string is hard-coded in a screen.

### References

- [Source: _bmad-output/implementation-artifacts/deferred-work.md lines 554, 577, 617, 618]
- [Source: epic9-triage.md, section 9-1 and per-item table rows 442, 461, 488-491]
- [Source: epic9-brief.md, story 1]
- [Source: _bmad-output/implementation-artifacts/8-2-guided-tutorial-test-suite.md, Tasks A6, E2, E3 and D-S82-5..10]
- [Source: _bmad-output/planning-artifacts/epics.md, Story 9.1]

## Project Context Rules

- Godot 4 GDScript. Presentation reads the sim and never writes it (AD-05). Only `Game` changes `flow_state` and `SimClock.paused` (AD-08).
- Guards: `game/tools/check_guards.sh`. Set status with the Edit tool.
- No Fable model. Never commit to main; this story's branch is `story/9-1-input-grace-and-tutorial-polish`, PR base `main`.

## Dev Agent Record

### Agent Model Used

Claude (create-story, unattended); Claude Opus (gds-dev-story, unattended)

### Debug Log References

- Full GUT suite, CI order (`--headless --path game --import`, then `gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`): 127 scripts, 1869 tests, 1869 passing, 150012 asserts, exit 0 (the 1 orphan is the pre-existing `EndingScreen` in `test_ending_screen.gd`). `game/tools/check_guards.sh`: OK.
- Red check: with the `title_screen.gd` gate reverted, `test_gated_presses_do_nothing_but_unlock_audio` fails; the tutorial tests failed to parse before `hint_rows`, `initial_device`, `hint_row_top_left` and `hold_bar_rect` existed.
- First full run after the gate: 12 order-dependent failures (`test_save_service` title tests, `test_duck_bubble`, `test_duck_director`). Causes: suites that enter TITLE through the autoload (`test_null_pointer_fight` `debug_jump(TITLE)`, `test_practice_flow` practice leave) left `Game.title_entry_frame` armed while later suites reset `SimClock.sim_frame`; the new ENDING-flow assertion pressed a title key and left `AudioManager` unlocked. Fixed in the tests by saving / restoring `title_entry_frame` (and resetting it to -1 where a suite assumes a boot title) and restoring the audio lock.

### Completion Notes List

- **Sim clock check (Dev Notes claim verified).** `SimClock.tick()` runs every physics frame in every flow state; it only stops for `paused` (refused outside PAUSABLE_STATES, and `_set_flow_state` clears it on every change), the Breakpoint gate (cleared by `end_fight` on leaving a fight, and capped by MAX_FROZEN_POLLS) and hit-stop (counts down). So `sim_frame` advances in TITLE. Pinned by `test_sim_frame_advances_on_the_title` (30 ticks on the title open the gate) and the ENDING integration test (real Main, ticks 30 frames after the leave). The gate uses `SimClock.sim_frame` as specified.
- **Group A (617, 577, 554a).** `Game.TITLE_ENTRY_GATE_FRAMES = 30`, `title_entry_frame` (armed in `_set_flow_state` on any non-TITLE to TITLE change: tutorial replay end, Ending end, practice leave from FIGHT or DEAD, `debug_jump(TITLE)`), pure `title_gate_open_at` and `title_input_open`. `TitleScreen.handle_input`: after the `_started` / flow guard and `AudioManager.unlock()`, a gated counted press returns IGNORE (no start, no option: N, P, B, F, T and pad Select, B, R3, L3, A). Boot title never gated (-1).
- **A5 decision.** A gated press returns IGNORE, so `_unhandled_input` does not call `set_input_as_handled()`. Nothing else listens in TITLE (the old screen is made deaf and freed by `Main.apply_flow_state`, the HUD only takes the debug grid key), so leaving it unconsumed is harmless and keeps `handle_input`'s contract (IGNORE = not consumed).
- **A7 / 554a.** No production change; `test_existing_screen_gates_are_pinned` pins the DEAD retry gate (20), the press-edge retry rule, the Intro skip (`first_input_frame`) and the Ending leave gate (60). The existing `test_game_flow.gd` boundary tests stay.
- **Group B, deviation (D-S91-4 fallback applied).** The one-row hint does not fit: `hold Esc or Bksp: skip  P: pause` is 32 cols (256 px at 1x), so right-aligned it starts at x 248, and its backing overlaps the `[PASS] test_move` row (x 22-282, y 14-34); the pad row (31 cols) also overlaps. Applied the fallback: the skip row unchanged, a second 1x row `{pause}: pause` right-aligned under the hold bar. Layout change against the D-S91-4 text: the hold bar stays where it was (y 18-20, directly under the skip row, as in 8.2) and the pause row sits 2 px under it (y 22), instead of the pause row at y 20 and the bar moved to y 30; with the bar at y 30 the keyboard bar (x 328-504) would touch the `test_actions` row backing (x up to 330, y 30-50). The text is a new audited field `tutorial_hint_pause = "{pause}: pause"` in `screen_text.tres` (validated non-empty, in `all_text()`), so `tutorial_hint_skip` is unchanged. Rows: keyboard `hold Esc or Bksp: skip` / `P: pause`, pad `hold SELECT: skip` / `START: pause`. `TutorialChecklistView.show_state` now takes the hint rows (PackedStringArray); the hold bar is drawn after the rows. `test_hint_rows_and_hold_bar_clear_the_checklist` checks every `[ ]` / `[PASS]` row and the `>` cursor, backing included, for both devices.
- **618b.** `DONE_TOP` removed (no other reader); `done_top_left` is bottom-anchored: rows at y 240 and 264. `test_completion_rows_clear_the_spawn_and_the_dummy` checks the backing against the `@` rect (`PlayerView.player_top_left(SPAWN_PX)`, 16x16) and a dummy zone built from BossView's real values (the 3-cell `{;}`, the cue radius and the 2x PATCHED damage number band), plus play-area containment.
- **Group C (618c).** `TutorialScreen.initial_device(pads)` (pure) used in `_ready`: GAMEPAD when a joypad is connected. `device_for`: trigger axes count only at +0.5 or more (rest 0 / -1 never flip), sticks keep `absf >= 0.5`. Tests cover both pure rules; the `_ready` default is asserted only when no pad is connected (headless CI).
- **Group D.** D3 lives in the new `tests/unit/test_title_entry_gate.gd` (11 tests); D4 `test_title_pad_buttons_inside_the_entry_gate`; D5 in `test_replay_from_title_ends_at_title`; D6 in `test_ending_flow.gd` `_play_and_leave` (both ending paths); D7 `test_gated_r3_does_not_toggle`; D2 hint rows in the text audit. D1: the hint assertions moved to `hint_rows`.
- **Group E.** deferred-work.md lines 554 (part 1), 577, 617 and 618 annotated "Resolved in Story 9.1" with decision IDs; original text kept. 618's pad tutorial binding (D-S82-13) noted unchanged.
- **For the reviewer:** the cross-suite state (`Game.title_entry_frame` is new global autoload state; any future test that enters TITLE through `_set_flow_state` and then presses on a title must reset it); `title_screen.gd` order (unlock before the gate, AC 3); the hint-row layout change and the new `.tres` field.
- **For a human visual check:** the two-row hint in the top-right corner (pause row under the hold bar, the bar filling on a held Esc / Select); the completion rows in the bottom band over the scenery; the title after a tutorial replay, an Ending and a practice leave (0.5 s of ignored presses should not feel laggy; 20 frames is the fallback); a pad plugged in on the tutorial (pad names at once, triggers at rest do not flip); a pad button held at boot is not covered by the gate (AC 5).

### File List

- _bmad-output/implementation-artifacts/9-1-input-grace-and-tutorial-polish.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml (9-1 to review)
- _bmad-output/implementation-artifacts/deferred-work.md
- game/src/autoloads/game.gd
- game/src/ui/screens/title/title_screen.gd
- game/src/ui/screens/tutorial/tutorial_screen.gd
- game/src/presentation/tutorial_checklist_view.gd
- game/src/ui/text/text_screen_text.gd
- game/data/text/screen_text.tres
- game/tests/unit/test_title_entry_gate.gd (new)
- game/tests/unit/test_title_entry_gate.gd.uid (new)
- game/tests/unit/test_tutorial_screen.gd
- game/tests/unit/test_text_audit.gd
- game/tests/unit/test_gamepad.gd
- game/tests/unit/test_fullscreen.gd
- game/tests/unit/test_tutorial_flow.gd
- game/tests/unit/test_practice_flow.gd
- game/tests/unit/test_save_service.gd
- game/tests/integration/test_ending_flow.gd
- game/tests/integration/test_null_pointer_fight.gd

### Change Log

- 2026-11-17: Story 9.1 implemented (title entry gate, tutorial hint / completion rows / device default / trigger rule, tests, deferred-work bookkeeping). Status review.

## Code Review (2026-11-17)
- Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). No blocker or high findings.
- Patched: stale/rewound `title_entry_frame` now counts as open (test added); AC7 wording matches the two-row hint.
- Deferred (see deferred-work.md, Code review of Story 9.1): central test reset (Story 9.5), mouse click in the gate, idle-pad initial device, test fragility notes.
