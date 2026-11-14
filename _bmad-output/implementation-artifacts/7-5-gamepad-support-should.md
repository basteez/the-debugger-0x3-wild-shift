---
baseline_commit: 95a5f19
---

# Story 7.5: Gamepad Support (Should)

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with the chosen default (D-S75-n); the implementer follows them or records a change in Completion Notes. Scope: the gamepad bindings in the InputMap (GDD mapping plus the option and mute buttons the GDD leaves open), the "any other button" rule on every screen that today takes "any key or click", a gamepad hint row on the pause screen, and the tests. NOT in scope: the practice target itself (7.6; only its L3 binding is reserved here), fullscreen itself (7.7; only its R3 binding is reserved here), remapping (out of scope for v1.0, GDD), new art or text audit changes. -->

## Story

As a player with a controller,
I want to play the whole run on a gamepad,
so that I can play the way I prefer.

**Requirements:** FR61 (Should). GDD "Controls and Input" table: left stick / D-pad move, X / Square = Action 1, A / Cross = Action 2, LB / L1 = `<<`, RB / R1 = `>>`, RT / R2 = Breakpoint, Y / Triangle = Watch, Start = pause. GDD D-048: on the title, Start starts or continues and Select starts a new run; on pause, Start resumes.

Depends on: 7.4 (title `B` and pause `B` option wiring, `title_option_debug_build`), 7.3 (`SaveService.set_muted`, the `[N]` new-run rule), 1.4 (title classifier and any-key start), 1.6 (`PlaceholderScreen.is_advance`), 1.7 (pause input rules and `Game.is_pause_press`), 2.9 (dead screen retry), 6.7 / 6.8 (intro skip and ending leave use the same press rule).

## Acceptance Criteria

**Bindings (FR61, GDD table)**

1. **Given** the `InputMap` in `game/project.godot` `[input]`, **When** a gamepad is connected, **Then** these gameplay actions have these pad events, in addition to the keyboard events, which stay unchanged:
   - `move_left` D-pad left (button 13) and left stick X axis at -1; `move_right` D-pad right (14) and stick X at +1; `move_up` D-pad up (11) and stick Y at -1; `move_down` D-pad down (12) and stick Y at +1. Stick events use the project's existing deadzone 0.2.
   - `action_1` X / Square (button 2); `action_2` A / Cross (button 0).
   - `shift_left` LB / L1 (button 9); `shift_right` RB / R1 (button 10).
   - `breakpoint` RT / R2 (axis `JOY_AXIS_TRIGGER_RIGHT` = 5, motion +1.0).
   - `watch` Y / Triangle (button 3).
   - `pause` Start (button 6), in addition to Esc and P.
2. **And** the menu and option actions get these pad buttons [design call] D-S75-2: `title_option_new_run` Select / Back (button 4); `title_option_debug_build` B / Circle (button 1); `title_option_fullscreen` R3 (button 8, reserved for 7.7); `title_option_practice` L3 (button 7, reserved for 7.6); `mute` Select / Back (button 4). Select is on both `title_option_new_run` and `mute`: the two never meet, because the title is never paused and the pause screen exists only while paused.
3. **And** no gameplay action binds a mouse button (existing test stays green), and no project action binds Shift (existing test stays green).
4. **And** `LiveInput` and every file under `game/src/core`, `game/src/combat`, `game/src/player`, `game/src/bosses` are unchanged. Gamepad input reaches the sim only through the existing InputMap actions (D-S21-3). `game/tools/check_guards.sh` passes unchanged.

**Title (D-048)**

5. **Given** the title with no save past Boss 1, **When** I press any pad button that is not an option button (for example A, X, LB, RT, Start, D-pad), **Then** audio is unlocked and the run starts from the Intro, exactly as a key press does.
6. **And** Start on the title starts or continues the run (it is not a pause: `Game.handle_pause_input` refuses in TITLE and the title sees the event).
7. **And** with a save past Boss 1, Select starts a new run from the Intro (`[N]` rule, 7.3); with no such save, Select starts the run as a plain key does (`[N]` is hidden, D-048). Button B toggles the debug build in place and never starts the run (7.4, AC 1). R3 and L3 are hidden options (7.6, 7.7 not built yet), so they start the run as a hidden key does.
8. **And** stick and trigger axis motion on the title never starts the run. The stick and the trigger act only through their InputMap actions in the fight. [design call] D-S75-3 (a stick nudge on the title would start the run by accident).

**Intro, harvest, ending, dead (any button)**

9. **Given** the Intro, the Harvest, the Ending, or the DEAD screen, **When** I press any pad button except Start, **Then** the press does what a key press does there: Intro skip (gate rules unchanged), Harvest advance (`harvest_skip_open` rule unchanged), Ending leave (`can_leave_ending` rule unchanged), DEAD retry (`RETRY_DELAY_FRAMES` rule unchanged). [design call] D-S75-4: Start never advances or retries on these screens, because Start is the pause press (the Intro already excludes it through `GameFlow.is_pause_press`).
10. **And** stick and trigger axis motion never advances or retries these screens.
11. **And** Start during the Intro, the Harvest, the Ending or the DEAD screen behaves as the Esc key does there: it pauses only in the states where Esc pauses (`Game.PAUSABLE_STATES`), and is ignored otherwise.

**Pause**

12. **Given** a fight, **When** I press Start, **Then** the game pauses. **When** I press Start again while paused, **Then** the game resumes. The click resume guard (`CLICK_RESUME_GUARD_MSEC`) does not apply to Start, as it does not apply to Esc and P.
13. **Given** the pause screen, **When** I press Select, **Then** the Master mute flips, is saved through `SaveService.set_muted`, and the game stays paused (7.3). **When** I press B, **Then** the debug build flag flips, is saved through `SaveService.set_assist`, and the game stays paused (7.4).
14. **And** while paused, other pad buttons and the sticks do nothing, and no gameplay input is polled (D-S21-9, unchanged).
15. **And** the pause screen shows a gamepad hint row in the free slot at `y` 216 (between the last controls row at 192 and the resume row at 240) [design call] D-S75-5: `PAD STICK X A LB RB RT Y START`. It is one glyph row at `TEXT_SCALE` 2, centred by `TitleScreen.centred_x`, and it fits the 640-px base. The other rows keep their positions and text (`lines_for` gains one row only).

**Tests and checks**

16. **Given** the GUT suite, **When** it runs, **Then** it includes the tests in Tasks 5 and 6, and the existing suite still passes, with `tests/unit/test_input_map.gd` updated where it assumed only keyboard events (its physical-keycode assertion must now skip non-key events).
17. **And** `FeatureFlags`, replays (`tests/replays/`) and the save file format are unchanged: the replays record action names, so they are device-independent.

**Human checks (not automated; the story stays `review` until these are done)**

- H-S75-1 Chrome, web build (direct `html.itch.zone` iframe URL, see deferred-work.md): with an Xbox-layout pad, play a full run from the title to the ending using only the pad: move, both actions, both shifts, Breakpoint on RT, Watch on Y, Start to pause and resume, Select to mute, B to toggle the debug build, a death and retry on a pad button.
- H-S75-2 Same run with a PlayStation-layout pad (Chrome) and one spot check in Firefox and Safari: confirm the RT trigger reads as Breakpoint (Godot may expose triggers as axes or as buttons depending on the browser mapping; if RT does not fire, record the event index and reopen this story).
- H-S75-3 Gamepad-only first start in Chrome: the first pad press starts the run, and audio is audible. Browsers may not count a gamepad press as the user gesture that unlocks Web Audio, so if the run is silent until a click, record it as a known limitation for the itch page (7.9) rather than as a bug in this story.
- H-S75-4 The itch.io embed: the Gamepad API needs the iframe to allow it (Permissions-Policy `gamepad`). Confirm on the itch.io page that the pad reaches the game. This is not controllable from the build; if it is blocked, record it and tell Tiziano (see Open questions).

## Tasks / Subtasks

- [x] Task 1: InputMap bindings (AC 1, 2, 3, 4)
  - [x] 1.1 `game/project.godot` `[input]`: append `InputEventJoypadButton` / `InputEventJoypadMotion` events (`"device": -1` for any device, `"deadzone": 0.2`) to `move_left`, `move_right`, `move_up`, `move_down`, `action_1`, `action_2`, `shift_left`, `shift_right`, `breakpoint`, `watch`, `pause`, `mute`, `title_option_new_run`, `title_option_debug_build`, `title_option_fullscreen`, `title_option_practice`. Keep the existing keyboard events in each action. Button indices: A 0, B 1, X 2, Y 3, Back/Select 4, Start 6, L3 7, R3 8, LB 9, RB 10, D-pad up 11, down 12, left 13, right 14. Axes: left X 0, left Y 1, trigger right 5.
  - [x] 1.2 Check the existing `[input]` entries are still in the same order (`test_input_map.gd` compares by action name, not order).
- [x] Task 2: Title classifier (AC 5, 6, 7, 8)
  - [x] 2.1 `game/src/ui/screens/title/title_screen.gd` `classify`: add a branch for `InputEventJoypadButton`: ignore when not `pressed`; `OPTION` when `option_of` finds an option, else `START`. Axis events (`InputEventJoypadMotion`) return `IGNORE`.
  - [x] 2.2 `option_of`: accept `InputEventJoypadButton` in the same branch as `InputEventKey` (it uses `event.is_action(..., true)`, which works for pad buttons).
  - [x] 2.3 Keep `handle_input`'s audio unlock first, as today. Keep `NON_START_KEYS` for keys only.
- [x] Task 3: "Any button" press on the other screens (AC 9, 10, 11)
  - [x] 3.1 `game/src/ui/screens/placeholder/placeholder_screen.gd`: add one static helper `is_pad_press(event: InputEvent) -> bool` (pad button, `pressed`, not the `pause` action) and make `is_advance` return true for it. This covers the Intro skip (`IntroScreen.skip_allowed`, which already excludes the pause press), the Harvest advance and the Ending leave (`EndingScreen.leave_allowed` delegates to `skip_allowed`).
  - [x] 3.2 `game/src/ui/screens/dead/dead_screen.gd` `is_retry_press`: return true for `is_pad_press`. Do not change the `RETRY_DELAY_FRAMES` rule.
  - [x] 3.3 Confirm `game/src/ui/duck/*` has no input handling (duck bubbles are timed; checked while writing this story: no `_input` / `_unhandled_input` there). Nothing to change; say so in Completion Notes.
- [x] Task 4: Pause screen (AC 12, 13, 14, 15)
  - [x] 4.1 `game/src/ui/screens/pause/pause_screen.gd` `is_mute_toggle` and `is_assist_toggle`: accept `InputEventJoypadButton` alongside `InputEventKey` (the `is_action_pressed` checks on `mute` and `ASSIST_ACTION` already work for pad buttons; the mouse branch is unchanged).
  - [x] 4.2 Add `const PAD_HINT_TEXT := "PAD STICK X A LB RB RT Y START"` and `const PAD_HINT_TOP_Y := 216` (on the 8-px grid). Add the row to `lines_for` and `row_tops` between the controls and the resume row. Check the existing `lines_for` / `row_tops` tests still match the new count.
  - [x] 4.3 `game/src/autoloads/game.gd`: no change expected. `handle_pause_input` already reads the `pause` action, so Start pauses and resumes. Verify with a test (Task 5).
- [x] Task 5: Tests (AC 1-3, 5-14, 16)
  - [x] 5.1 `game/tests/unit/test_input_map.gd`: keep `EXPECTED` for keys; add `PAD_EXPECTED` (button indices and axis motions per action, from AC 1-2). Change `test_actions_bind_physical_keycode_only` to assert only the key events. Keep the Shift and mouse checks.
  - [x] 5.2 `game/tests/unit/test_title_input.gd`: pad A, X and Start on the title start the run (`handle_input` returns `START`); pad B returns `OPTION` and does not start; Select with no save returns `START`, with a save past Boss 1 returns `OPTION`; a stick motion event returns `IGNORE`; a released pad button returns `IGNORE`.
  - [x] 5.3 `game/tests/unit/test_intro_screen.gd` (or the existing intro test file): `skip_allowed` is true for pad A and false for pad Start. `game/tests/unit/test_harvest_screen.gd` and `game/tests/unit/test_ending_screen.gd`: `is_advance` / `leave_allowed` true for pad A, false for Start, false for a stick motion. `game/tests/unit/test_dead_screen.gd`: `is_retry_press` true for pad A, false for Start and for a stick motion.
  - [x] 5.4 `game/tests/unit/test_pause_screen.gd` (or the file that holds `is_mute_toggle`): Select event toggles mute, B event toggles assist, A event does neither. `game/tests/unit/test_pause.gd`: `Game.handle_pause_input` with the pad Start event toggles pause on and off in a fight state, and is refused in TITLE.
  - [x] 5.5 Pause layout: the rows of `lines_for` / `row_tops` (the hint row at 216 sits between 192 and 240, and no row overlaps).
  - [x] 5.6 Gameplay coverage (AC 1, 16): for each gameplay action, build the pad event from the project's `InputMap` (`InputMap.action_get_events`) and assert `InputMap.event_is_action(ev, action)` is true. This is the automatable part of "a full run can be completed on a gamepad"; the full run itself is a human check (H-S75-1).
- [x] Task 6: Checks (AC 4, 17)
  - [x] 6.1 Run `bash game/tools/check_guards.sh` from the worktree root.
  - [x] 6.2 Run the GUT suite headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game ...` (see the project's test script; `godot` is not on PATH). All existing tests and replays pass unchanged.
  - [x] 6.3 Web export builds and the size is recorded in Completion Notes (the 32 MB cap, 7.7, is checked there).

## Dev Notes

### What exists now (read before writing code; verified at 95a5f19)

- Keyboard-only InputMap: `game/project.godot` `[input]` (`move_*`, `action_1`, `action_2`, `shift_left`, `shift_right`, `breakpoint`, `watch`, `pause`, `mute`, `title_option_*`, `debug_grid`). Every entry is physical-keycode only (`test_input_map.gd`).
- `LiveInput` (`game/src/input/live_input.gd`) reads `InputMap` actions only: `BUFFERED_ACTIONS` via `is_action_just_pressed`, movement via `Input.get_axis` on the four `move_*` actions (sign-reduced), Watch via `is_action_pressed`. It is the only file in a sim folder that touches `Input`. No change is needed there, because the pad events become action events.
- Title (`title_screen.gd`): `classify` / `option_of` / `resolve` / `handle_input`. `classify` returns `IGNORE` for any event that is neither a key nor a left click, so a pad button does nothing today. This story adds the pad branch.
- Pause (`pause_screen.gd`): `_input` consumes B (assist) and M (mute) through `is_assist_toggle` / `is_mute_toggle`, which accept only `InputEventKey` and mouse clicks. Pad events need the same branch.
- `Game._input` (`game/src/autoloads/game.gd`): `handle_pause_input` (`is_pause_press` = the `pause` action, pausable states only) and `handle_resume_click` (mouse only). Start therefore pauses and resumes with no change here.
- Press rules that use "any key or click": `PlaceholderScreen.is_advance` (Harvest, and Intro through `IntroScreen.skip_allowed`, and Ending through `EndingScreen.leave_allowed`), and `DeadScreen.is_retry_press`. All of them accept keys and left clicks only.
- Duck bubbles (`game/src/ui/duck/`): no input handling. They are timed.
- Hotkey-only screens: `debug_keys.gd` and `debug_grid` (`hud.gd`) are debug tools behind `Debug.enabled`. They stay keyboard-only (not in the GDD controls table).
- Replays (`tests/replays/`, `replay_input.gd`) store action names, so the new bindings do not change them.

### Design calls (all `[design call]`; default chosen, change in Completion Notes if needed)

- **D-S75-1 [design call]** Bindings follow the GDD table exactly (AC 1). Triggers are read as the `breakpoint` action's axis motion (`JOY_AXIS_TRIGGER_RIGHT`, deadzone 0.2). Alternative (rejected): reading `Input.get_joy_axis` in `LiveInput`. That would put a second input path inside the sim boundary (D-S21-3).
- **D-S75-2 [design call]** Option and mute buttons, chosen so each option has a pad equivalent and none collides with play: Select = new run on the title and mute on the pause screen (the two screens never overlap); B = debug build (title and pause, same action as the keyboard `B`); R3 = fullscreen and L3 = practice, reserved for 7.7 and 7.6. Until those stories exist, R3 and L3 are hidden options and act as START, the same as the keys `F` and `P` do now.
- **D-S75-3 [design call]** Stick and trigger axes never start the run or advance a screen. Only buttons do, the same as the keyboard rule for keys. Reason: a stick nudge while the title sits idle would start the run by accident.
- **D-S75-4 [design call]** "Any button" on the Intro, Harvest, Ending and DEAD screens, except Start (the pause press). Start is the pause action in fight and on these screens, and the Intro already excludes it, so Start never skips or retries.
- **D-S75-5 [design call]** One pad hint row on the pause screen at `y` 216, the only free slot in the pause layout. It shows the pad mapping; the mute and debug build rows already show their keys, and their pad buttons (Select, B) are on the pause screen's own rows. No text change to the title prompt (game text audit 6.9).
- **D-S75-6 [design call]** Hidden options accept pad buttons the same way the keys do: a press on a hidden option starts the run (`TitleScreen.resolve`). No new visible state for pad-only players.
- **D-S75-7 [design call]** No new InputMap action, no new autoload, no new scene. The title's existing `title_option_*` and the `pause` / `mute` actions gain pad events only.

### Architecture guardrails

- The sim reads actions, never devices. `LiveInput` and every sim folder stay as they are (AD-04 / D-S21-3; `check_guards.sh`). A test or replay that drives the game by action name is device-independent.
- Presentation may read `InputEvent` types (`TitleScreen`, `PauseScreen`, the press helpers). Keep the pad branch in the same static helpers as the key branch, so the existing pure-function test style applies (`classify`, `is_advance`, `is_retry_press`, `is_mute_toggle`, `is_assist_toggle`).
- Glyph text only, ASCII only (7.3, 6.9). The pause hint row is a code constant like the other pause rows; it is not added to `screen_text.tres`.
- Layout on the 8-px grid of the 640x360 base. A glyph row is `GlyphFont.CELL` (8) x scale = 16 px tall at `TEXT_SCALE` 2. The last controls row sits at 192 (192..208) and the resume row at 240, so `PAD_HINT_TOP_Y` = 216 (216..232) fits with no overlap. Check it in the web build (H-S75-1) and say so in Completion Notes.
- Tests: no RNG in this story's tests. Set the save seam (`SaveService.path = ""` under GUT, 7.3) before any test that toggles mute or assist, so no test writes the real save.

### Previous story intelligence (7.4, 7.3)

- 7.4 kept the assist key on one InputMap action (`title_option_debug_build`) and reused it in pause through `ASSIST_ACTION`. The pad `B` gets the same treatment: one action, two screens, no new action.
- 7.3 kept `SaveService.set_muted` for the pause mute. Select on pause calls the same method.
- `PauseScreen._input` consumes its own keys before `Game` sees them (`set_input_as_handled`). Keep the same order for the pad branch.
- `TitleScreen.handle_input` unlocks audio before any option (1.4 DC8). Keep it first.
- 7.4 story reminder: `[B]` on the title must not start the run. The same holds for the pad `B` (AC 7).

### Human checks

See AC H-S75-1 to H-S75-4. The story stays `review` until they are done. H-S75-3 and H-S75-4 are not fixable inside this story; if they fail, record them in deferred-work.md and in the itch page notes (7.9).

## Open questions

- **Itch.io iframe permission (not a blocker for the build, a blocker for playing on the page):** the Gamepad API inside a cross-origin iframe needs the embed to allow `gamepad`. We do not control the itch.io embed attributes, and this was not checked here. Tiziano should confirm on the page (H-S75-4). If it is blocked, the pad works only in the direct `html.itch.zone` URL, and the itch page copy (7.9) should say so.
- **Web Audio unlock by a pad press (H-S75-3):** if browsers do not count a pad press as a user gesture, a gamepad-only player may hear nothing until a click. Default: accept and document it (no code workaround here). Tiziano can choose a different default if he prefers a visible "click to start" hint for pad users.

## Tasks check

- [x] Every AC in this story maps to at least one task above (AC 1-4 to Task 1, 5-8 to Task 2, 9-11 to Task 3, 12-15 to Task 4, 16-17 to Tasks 5-6).
- [x] No file outside the list in Dev Notes is changed without a Completion Note.

## Dev Agent Record

### Agent Model Used

claude-opus-5-5 (gds-dev-story, pipeline, unattended)

### Debug Log References

- GUT full suite (headless, Godot 4.7.2): 117 scripts, 1700 tests, 1700 passing, `All tests passed!`, no SCRIPT ERROR / Parse Error / [Failed] markers. 1 orphan is pre-existing (`test_ending_screen.gd::test_screen_name_and_no_game_text_literal`).
- `bash game/tools/check_guards.sh`: `check_guards: OK`.
- Local web export (`--export-release Web`, local stock 4.7.2 templates): exit 0; total 49.8 MB, of which `index.side.wasm` 44.1 MB (the stock dlink template, the known size waiver in deferred-work 1.3 H3; CI builds the size-checked template) and `index.pck` 1.94 MB. This story adds only InputMap events, a few lines of GDScript and one text row, so the pck delta is negligible. The 32 MB cap is checked on the CI build in 7.7.

### Completion Notes List

- Task 1: 16 actions in `project.godot` `[input]` gained pad events (`device` -1, the existing 0.2 deadzone), keyboard events untouched, action order untouched. Mapping exactly as AC 1-2 / D-S75-1 / D-S75-2 (RT = `InputEventJoypadMotion` axis 5 +1.0; sticks = axis 0/1 +-1.0; Select on both `mute` and `title_option_new_run`).
- Task 2: `TitleScreen.classify` has a pad-button branch (fresh press -> OPTION if `option_of` finds an option, else START; Start included because TITLE is never paused, AC 6). `InputEventJoypadMotion` falls through to IGNORE (D-S75-3). `option_of` accepts pad buttons in the key branch. Audio unlock order in `handle_input` unchanged; `NON_START_KEYS` stays keys only.
- Task 3: `PlaceholderScreen.is_pad_press` (pad button, pressed, not the `pause` action) feeds `is_advance` (Harvest, and Intro / Ending through `skip_allowed` / `leave_allowed`) and `DeadScreen.is_retry_press`. Gate rules (`harvest_skip_open`, `can_skip_intro`, `can_leave_ending`, `RETRY_DELAY_FRAMES`) untouched. Start on HARVEST / DEAD is refused by `Game.set_paused` exactly like Esc (AC 11). 3.3: `game/src/ui/duck/*` has no `_input` / `_unhandled_input` (checked); nothing changed there.
- Task 4: `PauseScreen.is_mute_toggle` / `is_assist_toggle` accept `InputEventJoypadButton` (Select -> mute saved through `SaveService.set_muted`, B -> assist saved through `SaveService.set_assist`, both consumed in `_input` before `Game`, the game stays paused). `PAD_HINT_TEXT` / `PAD_HINT_TOP_Y` 216 added to `lines_for` / `row_tops` between the controls and resume rows (480 px wide at scale 2, fits the 640 base with the 16 px gutter; existing layout / font coverage tests still pass). `game.gd` unchanged: Start pauses / resumes through the `pause` action; the click guard only applies to mouse clicks.
- Task 5: [design call] D-S75-8: the new pad tests live in one file, `tests/unit/test_gamepad.gd` (17 tests: bindings and `event_is_action` per gameplay action, no two gameplay actions share a pad event, deadzone, title START / OPTION / IGNORE incl. Select with and without a save, title B toggles the assist and stays on TITLE, the any-button rule on all four screens incl. Start / release / stick / trigger refusals, Start pause / resume / refusal in TITLE, HARVEST, DEAD, pause screen Select / B / A through `_input`, the hint row layout) instead of being spread over six existing files; the coverage is the one listed in 5.2-5.6. Title START cases use `resolve` (the same classification `handle_input` acts on) so the tests never leave TITLE or touch run state; `handle_input` itself is exercised for the B toggle. `test_input_map.gd`: `test_actions_bind_physical_keycode_only` now checks key events only and allows pad events; new `test_pad_events_match_the_gdd_table` (PAD_BUTTONS / PAD_AXES per action, device -1, deadzone 0.2). Shift / mouse / P-sharing checks unchanged. No RNG in any new test.
- Task 6: guards OK, full GUT green, replays unchanged (they record action names). `LiveInput`, `game/src/core|combat|player|bosses`, `FeatureFlags`, save format, replays: untouched.
- Coordinator decisions applied: D-S75-* approved as written. Web Audio unlock from a pad press accepted and documented in deferred-work.md (7.9 page copy: "click once to enable audio if you play on a pad"), no in-game hint. itch iframe gamepad permission stays human check H-S75-4.
- Human checks H-S75-1..4 are pending (listed in deferred-work.md, Story 7.5). The pause hint row position should be eyeballed in the web build during H-S75-1.

### File List

- game/project.godot (modified: pad events on 16 InputMap actions)
- game/src/ui/screens/title/title_screen.gd (modified)
- game/src/ui/screens/placeholder/placeholder_screen.gd (modified: `is_pad_press`)
- game/src/ui/screens/dead/dead_screen.gd (modified)
- game/src/ui/screens/pause/pause_screen.gd (modified: pad toggles, hint row)
- game/tests/unit/test_input_map.gd (modified)
- game/tests/unit/test_gamepad.gd (new)
- game/tests/unit/test_gamepad.gd.uid (new)
- _bmad-output/implementation-artifacts/deferred-work.md (modified: Story 7.5 section)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 7-5 -> review)
- _bmad-output/implementation-artifacts/7-5-gamepad-support-should.md (this file)

### Change Log

- 2026-11-14: Story created unattended by gds-create-story (pipeline). Status ready-for-dev.
- 2026-11-14: Implemented by gds-dev-story (pipeline): pad bindings, title / any-button / pause pad rules, pause hint row, tests. Status review (human checks H-S75-1..4 pending).

### Code review (gds-code-review, 2026-11-14)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). Coordinator decisions: D-S75-8 (tests consolidated in `test_gamepad.gd`) approved; testing the title START through `resolve()` is acceptable.
- Patched: none (no blocking issue).
- Deferred (deferred-work.md): held combat button can retry/advance on the first frame of DEAD/Intro/Ending (input grace); stick drift/diagonals with deadzone 0.2 (check in H-S75-1); no auto-pause on pad disconnect; hide cursor on pad use.
- Dismissed: Select shared by `mute` and `title_option_new_run` (auditor grep: no screen reads both; PauseScreen consumes before Game; title has no mute handler); `JOY_BUTTON_RIGHT_TRIGGER` fallback (no such button in Godot 4, RT is axis 5; already covered by H-S75-2); L3/R3 any-button on the title (by design, AC 5); test-style nits.
- Human checks H-S75-1..4 remain pending.
