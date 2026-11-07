---
baseline_commit: 26067e8
---

# Story 1.7: Pause Screen and Auto-Pause on Focus Loss

Status: ready-for-dev

<!-- Last story of Epic 1. Story-level AC coverage is below; the Epic 1 Definition of Done has human steps that this story cannot close (see "Epic 1 done: what remains"). -->

## Story

As a player,
I want the game to pause on Esc or when I switch tabs, showing the controls,
so that I never lose a fight to a background tab and can always check the keys.

**Requirements:** FR54, FR58 (InputMap). Epic 1 (Web Foundation), Nov 6–7.

## Acceptance Criteria

1. **Given** the `InputMap`, **when** I inspect it, **then** actions exist for move (WASD + arrows), `action_1` (J), `action_2` (K), `shift_left` (Q), `shift_right` (E), `breakpoint` (Space), `watch` (R), `pause` (Esc), and no action is bound to the Shift keys. [design call DC14: `move_left`, `move_right`, `move_up`, `move_down`, plus a `mute` action (M) so the mute key is also remappable.]

2. **Given** a fight (FIGHT), **when** I press Esc, **then** `Game` sets `SimClock.paused = true` (not `SceneTree.paused`) and shows the pause screen listing all controls from the GDD table and the options `[Esc]` resume and `[M]` mute (`[F]` and `[B]` appear with 7.7 and 7.4). Pressing Esc again resumes play. [design call DC1: Esc also pauses during INTRO.]

3. **Given** the pause screen, **when** I press `M` or click its mute label, **then** the `Master` bus is muted or unmuted, and the setting is kept for the session (persisted from 7.3) (D-048, Should).

4. **Given** a fight, **when** the browser tab or window loses focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`), **then** the game pauses and stays paused after focus returns until an explicit input, and `sim_frame` does not advance while paused.

## Scope Boundaries

- **In:** the `InputMap` actions (AC1); `Game` pause state (Esc and focus loss) using `SimClock.paused`; the `EventBus` pause signal; the pause screen with the controls list and `[Esc]`/`[M]` lines; `AudioManager` master mute for the session; tests; a smoke-script expectation for Esc; the Epic 1 "what remains" list.
- **Out:** `[F]` fullscreen and the `[B]` debug-build toggle (7.7, 7.4); gamepad Start as pause/resume (7.5); save-backed mute persistence (7.3, `SaveService` is still a stub); the real Fight, Harvest and Intro screens; Breakpoint and hit-stop gates (2.x, 4.x); any change to `SimClock.tick` order; any change to the web template, export preset or CI workflow; the debug-key set (F1–F5 unchanged).
- **Not changed:** `TitleScreen` option table and classify rules (Esc on the title stays ignored), `PlaceholderScreen` text rules, `DebugKeys` JUMPS table, the 1.6 Intro cap (480 sim frames), `Debug.gate_enabled`.

## Tasks / Subtasks

- [ ] Task 1: InputMap actions (AC: 1)
  - [ ] 1.1 `game/project.godot` `[input]`: add `move_left` (physical A, Left), `move_right` (D, Right), `move_up` (W, Up), `move_down` (S, Down), `action_1` (J), `action_2` (K), `shift_left` (Q), `shift_right` (E), `breakpoint` (Space), `watch` (R), `pause` (Escape), `mute` (M). Bind by `physical_keycode`, the same way the title options are bound. Do not touch `title_option_*`, `debug_grid` or the `ui_*` built-ins.
  - [ ] 1.2 Test `game/tests/unit/test_input_map.gd`: each listed action exists and has its key; no project action has an `InputEventKey` with `keycode` or `physical_keycode` equal to `KEY_SHIFT`; `pause` is Esc and `mute` is M.
- [ ] Task 2: Game pause state (AC: 2, 4)
  - [ ] 2.1 `game/src/autoloads/event_bus.gd`: add `signal pause_toggled(paused: bool)` (past tense, typed; the only new signal). Keep `@warning_ignore("unused_signal")`.
  - [ ] 2.2 `game/src/autoloads/game.gd`: add `const PAUSABLE_STATES` (INTRO, FIGHT) and `func set_paused(on: bool, reason: StringName) -> bool`. It is the only writer of `SimClock.paused` outside tests. It refuses outside a pausable state (return false, no log). When the value changes, it emits `EventBus.pause_toggled` and logs `[flow] pause on (<reason>)` or `[flow] pause off` (tag `&"flow"`, event-only, never per frame). Reasons: `&"esc"`, `&"focus"`.
  - [ ] 2.3 `game/src/autoloads/game.gd`: `_input(event)`: when `event.is_action_pressed(&"pause")` (not echo), toggle: if paused, resume (`set_paused(false, &"esc")`); else `set_paused(true, &"esc")`; mark the event handled with `get_viewport().set_input_as_handled()` when the toggle took effect. Esc outside INTRO/FIGHT does nothing and is not consumed (so TitleScreen/Placeholder see it, and they already ignore it).
  - [ ] 2.4 `game/src/autoloads/game.gd`: `_notification(what)`: on `NOTIFICATION_APPLICATION_FOCUS_OUT`, `set_paused(true, &"focus")`. On `NOTIFICATION_APPLICATION_FOCUS_IN`, do nothing (no auto-resume, AC4). Pausing while already paused is a no-op.
  - [ ] 2.5 `Game.advance()` and `Game.finish_intro()` return without effect while `SimClock.paused` (DC4). Add the guard at the top of each, before any state change.
  - [ ] 2.6 `Game._set_flow_state(to)`: after the state change, if `SimClock.paused` is true, set it false and emit `pause_toggled(false)` (DC5). Log stays event-only.
  - [ ] 2.7 Tests in `game/tests/unit/test_pause.gd` (instance `Game` as `test_game_flow.gd` does; restore `SimClock.paused`, `flow_state` and `run` in `after_each`): pause in FIGHT and INTRO sets `SimClock.paused` and emits once; pause in TITLE, HARVEST, ENDING and DEAD is refused; Esc event toggles (synthesize `InputEventKey` with `physical_keycode = KEY_ESCAPE`, `pressed = true`, and check the action via `InputMap`, or call the toggle helper if `_input` is hard to drive headless); focus-out notification pauses in FIGHT and stays paused after focus-in; `advance()` and `finish_intro(frame, true)` do nothing while paused; a flow change (`debug_jump` or `advance`) clears the pause; `SimClock.sim_frame` does not advance across physics steps while paused (call `SimClock._physics_process` directly, as `test_sim_clock.gd` does).
- [ ] Task 3: Master mute (AC: 3)
  - [ ] 3.1 `game/src/autoloads/audio_manager.gd`: `func set_master_muted(muted: bool) -> void` and `func is_master_muted() -> bool`, using `AudioServer.get_bus_index(&"Master")` and `AudioServer.set_bus_mute`. Session only: no file write; the value is held in `AudioServer` state, so 7.3 can read it back. Log `&"audio"` once per change, event-only.
  - [ ] 3.2 Test in `game/tests/unit/test_audio_manager.gd` (extend): toggling sets and clears the Master bus mute; restore the original bus state in `after_each`.
- [ ] Task 4: Pause screen (AC: 2, 3)
  - [ ] 4.1 `game/src/ui/screens/pause/pause_screen.gd` (`class_name PauseScreen`, `extends Node2D`): draws an opaque `Palette.BG` rect over the 640×360 base and the text rows with `GlyphFont.draw_at` in `_draw()` (AD-07, no `Label`). Static `lines_for(muted: bool) -> PackedStringArray` (pure, testable): title `PAUSED`; the controls from the GDD table: `MOVE WASD ARROWS`, `ACTION 1 J`, `ACTION 2 K`, `SHIFT Q E`, `BREAKPOINT SPACE`, `WATCH R`; then `[ESC] RESUME` and `[M] MUTE ON` or `[M] MUTE OFF`. ASCII only. Layout on the 8-px grid, centred with `TitleScreen.centred_x`, TEXT_SCALE 1 or 2 (dev's choice, must fit 640×360 with a 16-px gutter).
  - [ ] 4.2 Mute label hit rect: a static `mute_label_rect(...)` (or a `Rect2` constant derived from the same layout) so a left click on that row toggles mute. Clicks elsewhere on the pause screen do nothing (DC3). `_unhandled_input`: `M` (`is_action_pressed(&"mute")`, not echo) or the label click calls `AudioManager.set_master_muted(not AudioManager.is_master_muted())`, sets the event handled, and `queue_redraw()`. Presentation only: no flow or pause writes.
  - [ ] 4.3 Pause screen does not handle Esc (Game owns it; DC2).
  - [ ] 4.4 Add `PauseScreen.lines_for(false)` and `lines_for(true)` to `_used_codepoints()` in `game/tests/unit/test_font_coverage.gd`. If `[`, `]` or `/` are not in the vendored Wildshift8 font, the font test will fail: change the text (for example `(ESC)`, or `WASD` without `/`) and record the change. Do not add glyphs (DC11 of 1.6 still applies).
  - [ ] 4.5 Test `game/tests/unit/test_pause_screen.gd`: `lines_for` contains every controls label from the GDD table and the `[ESC] RESUME` line; the mute line shows ON or OFF from the argument; the mute hit rect contains a point inside its label and not one far outside it.
- [ ] Task 5: Host the pause screen in Main (AC: 2)
  - [ ] 5.1 `game/src/main/main.gd`: add a `Pause` `CanvasLayer` at `PAUSE_LAYER := 15` (between HUD 10 and ScreenFX 20). Connect `EventBus.pause_toggled`. On `true`, instance `PauseScreen` under it; on `false`, free it (disable process and input first, as `apply_flow_state` does). Update `LAYER_ORDER` handling only if the test expects the new layer; keep the AD-07 order Arena → Entities → Particles → HUD → (Pause) → ScreenFX.
  - [ ] 5.2 Pause layer is not visible in TITLE, ENDING or any state where pause is off: it exists only while paused (Game clears pause on every flow change, DC5).
  - [ ] 5.3 Test additions in `game/tests/unit/test_main_layers.gd`: `pause_toggled(true)` adds one `PauseScreen`; `pause_toggled(false)` frees it; the arena and HUD nodes are the same instances before and after.
- [ ] Task 6: Smoke and flow walk (AC: 2, 4)
  - [ ] 6.1 `game/tools/smoke_web.sh`: add one run `SMOKE_QUERY="?debug" SMOKE_KEYS="F2 Escape Escape" SMOKE_EXPECT="pause on (esc)"` (use the DC15 `SMOKE_KEYS`/`SMOKE_EXPECT` interface from 1.6; the `pause off` line must also appear: extend `SMOKE_EXPECT` to accept a second string only if the script already supports it, otherwise assert `pause off` via a second run). Keep every existing run green.
  - [ ] 6.2 Headless flow walk in scratchpad (not committed), as in 1.6: boot → Enter → INTRO → Esc (paused, `sim_frame` frozen across 120 physics frames) → Esc (resumed) → Space (advances as before) → FIGHT → Esc → M (mute toggles, label changes) → Esc → F5 (ENDING, pause cleared). Record the result in Completion Notes.
  - [ ] 6.3 Record the release web build size in Completion Notes (budget 30,000,000 bytes; 1.6 measured 28,433,114). Expect a few kB more.
- [ ] Task 7: Verify and record
  - [ ] 7.1 GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` passes (1.6 baseline 142 tests); `game/tools/check_guards.sh` OK; no script errors on import.
  - [ ] 7.2 Human checks listed under Human Checks (H1–H3). Not blocking `review`.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] DC1 Pausable states.** Esc and focus loss pause only in INTRO and FIGHT (`Game.PAUSABLE_STATES`). Reason: those are the states where the 60 Hz clock drives the Intro cap and the fight; TITLE has no clock running, and HARVEST and ENDING are placeholders today. Esc in TITLE is ignored (TitleScreen already does); Esc in HARVEST and ENDING is ignored. Revisit when the real Harvest (3.8) exists. Note: the epic says "in a fight"; INTRO is included because the Intro timeout counts sim frames and a background tab would otherwise skip the Intro.
- **[design call] DC2 Pause owner is `Game`.** `Game.set_paused(on, reason)` is the single writer of `SimClock.paused` (architecture: "Game handles Esc and focus loss"). Presentation requests and never writes. Esc is read in `Game._input`, before any screen, so the pause toggle wins over the FIGHT placeholder's any-key advance. Reason: Esc is already in `NON_ADVANCE_KEYS` on title and placeholder, so it does not leak into a screen.
- **[design call] DC3 Resume and input.** Only the `pause` action (Esc) resumes. Focus return does not resume. A click on the mute label toggles mute; other clicks on the pause screen do nothing. Reason: AC4 says "until an explicit input"; a click on a control label is not a resume, and gamepad Start is 7.5.
- **[design call] DC4 Paused means no advance.** While `SimClock.paused`, `Game.advance()` and `Game.finish_intro()` are no-ops. Reason: the placeholder FIGHT advances on any key (1.6 DC4), so without this a J or K press during pause would skip the fight.
- **[design call] DC5 Flow change clears pause.** `_set_flow_state` unpauses (and emits `pause_toggled(false)`) on every transition. Reason: the F1–F5 debug jumps and ENDING→TITLE must not leave the game paused on a screen that cannot show the pause overlay.
- **[design call] DC6 Pause screen hosting.** Main hosts the overlay on `EventBus.pause_toggled`, in its own `Pause` CanvasLayer at 15. Reason: AD-08 keeps presentation out of `Game`, and Main already hosts screens and layers. The architecture's "Game instances the pause screen" is met in effect (Game owns the state, Main instances the screen on its signal); recorded here as the implementation shape.
- **[design call] DC7 Pause overlay is opaque.** The overlay paints the full BG so the controls read clearly; the arena and HUD sit behind it and are frozen (SimClock is paused). Reason: readability on a 640×360 base; no alpha or blur in Sample-era rendering.
- **[design call] DC8 Mute scope.** Session only. `AudioServer` holds the state, so 7.3 can read and write it without this story touching `SaveService` (stub). Unlock rules are unchanged: nothing plays before the title input, and pause is only reachable after it.
- **[design call] DC9 Focus-loss detection on web.** Use `NOTIFICATION_APPLICATION_FOCUS_OUT` on `Game` as the architecture and project rules say. Whether Godot 4.7's web export delivers that notification when the tab is hidden or the window blurs is the one unverified platform fact. Dev: check it in the headless flow walk where possible, and in H2 in Chrome and Firefox (a `[flow] pause on (focus)` line must appear after switching tabs). If it does not fire, do not silently add a fallback: record it in Completion Notes and raise it as a `[design call]` for a `visibilitychange` JavaScript bridge (web only, `JavaScriptBridge`), and keep the rule "resume only on explicit input".
- **[design call] DC10 Browser fullscreen and Esc.** In browser fullscreen, Esc may be taken by the browser before the page sees it. Not solved here; 7.7 owns fullscreen and the browser matrix. Record any observed behaviour in H2.
- **[design call] DC11 Log lines.** `[flow] pause on (esc)`, `[flow] pause on (focus)`, `[flow] pause off`. Event-only, tag `flow`. The smoke expectation uses these exact strings.
- **[design call] DC12 Pause and the Intro timeout.** The Intro cap counts sim frames (1.6 DC5), so pausing in INTRO freezes the cap as well. Verified by the flow walk (Task 6.2).
- **[design call] DC13 Font.** The pause text is ASCII and must pass `test_font_coverage`. If `[`, `]` or `/` are missing from the vendored font, change the text (Task 4.4); do not add glyphs.
- **[design call] DC14 InputMap names.** `move_left`, `move_right`, `move_up`, `move_down` (the AC's "move" group), `action_1`, `action_2`, `shift_left`, `shift_right`, `breakpoint`, `watch`, `pause`, and `mute`. Keys are bound by physical keycode. Gameplay code in 2.x reads these names; no gameplay code uses them yet.
- **[design call] DC15 Pause and debug keys.** F1–F5 still work while paused in debug builds (DebugKeys is `_input` and runs after Game's). A jump clears the pause (DC5). Reason: debug jumps are the way to recover a stuck state.

### Architecture guardrails (must follow)

- **Pause (architecture, Presentation, Pause bullet; project-context, Platform rules):** `SimClock.paused`, never `SceneTree.paused`. `Game` handles Esc and `NOTIFICATION_APPLICATION_FOCUS_OUT`. Play resumes only on an explicit input.
- **Gates (architecture AD-01):** priority pause > Breakpoint > hit-stop. This story only adds the pause gate, which already exists in `SimClock` as `paused`; do not add a Breakpoint or hit-stop gate here.
- **Flow (AD-08):** only `Game` changes `flow_state` (through `_set_flow_state`) and only `Game` writes `SimClock.paused`. Presentation calls `Game` methods and never writes state.
- **Signals (AD-05):** only in `src/autoloads/event_bus.gd`, past tense, typed args. This story adds exactly one signal, `pause_toggled(paused: bool)`. Adding it is an architecture-level change, recorded here and in Completion Notes.
- **Input (project-context):** `InputMap` actions only for gameplay and menu keys; never a Shift key binding. Debug keys stay keycode-matched in `DebugKeys`.
- **Logging:** `Log.*` only, tag `&"flow"` for pause, never per frame.
- **Typing:** `untyped_declaration` is an error. Type every variable, parameter and return. `StringName` ids (`&"pause"`).
- **Glyphs:** `GlyphFont.draw_at` in `_draw()`, no `Label`; palette `INK`/`BG` only.
- **Simulation folders** must not use `Timer`, `await`, `create_timer`, `get_ticks_msec` or reference `ui`/`AudioManager`. `Game` is not in the guard list but keeps no `await` and no Timers.

### Previous story intelligence (1.1–1.6)

- **`Game` (1.1, 1.4, 1.6):** `enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }`; `start_run_from_title`, `can_skip_intro`, `finish_intro(frame, skip_requested)` (DC12 of 1.6), `advance`, `debug_jump` (gated by `Debug.enabled`), `_set_flow_state` (logs and emits `flow_state_changed`). `Game.run` (`RunState`) holds `boss_index`. Pause must go through these, not around them.
- **`SimClock` (1.1):** `sim_frame` and `paused` only; `_physics_process` returns early when paused. `test_sim_clock.gd` already drives it directly, so reuse that pattern.
- **`Main` (1.3–1.6):** `_build_layers()` builds Arena, Entities, Particles, Hud (CanvasLayer 10), ScreenFX (CanvasLayer 20) and the `Screens` host. `apply_flow_state` frees the old screen (disable input and process first, then `queue_free`) and shows arena and HUD only in FIGHT. Mirror that for the pause overlay.
- **`PlaceholderScreen` (1.6, DC4, DC8):** advances on any fresh key except modifiers, Esc and function keys; in FIGHT the advance goes to HARVEST. This is why DC4 (no advance while paused) is required.
- **`TitleScreen` (1.4, 1.6):** `classify` ignores Esc and F1–F12; title input unlocks audio. Do not change the option table.
- **`AudioManager` (1.4):** `unlock()`, `play_test_sfx()`, the SFX bus. Mute goes to the Master bus through `AudioServer`; the unlock gate is untouched.
- **`GlyphFont` / `TitleScreen.centred_x` (1.5, 1.6):** `draw_at`, `text_width`, `size_for`, `CELL` = 8. `test_font_coverage.gd` derives the glyph set from constants: new text constants must be added there.
- **Debug (1.6):** `Debug.enabled` gates debug keys; `Game.debug_jump` is the only debug path into flow.
- **Deferred items relevant here (from `deferred-work.md`):** 1.6 "`Game.advance()` in INTRO ignores `can_skip_intro`" (stays deferred; INTRO skip is handled by `finish_intro`, and this story's DC4 guard does not change that). 1.6 "old and new screen can share a node name in a frame" (stays deferred; the pause overlay is a single node under its own layer). 1.6 "F1/F11/F12 browser defaults and Firefox/Safari not covered" (H2 covers Esc and F-keys in Firefox). 1.4 "AudioManager.unlock only sets a flag" (stays deferred).
- **Deferred items this story does not close:** everything in `deferred-work.md` not listed above. No deferred item is marked closed by this story.
- **Still deferred (not this story):** gamepad (7.5), `[F]` fullscreen (7.7), SaveService persistence (7.3), Arena and HUD camera desync (Epic 7).

### Input and browser notes

- Esc is consumed by `Game._input` only when the toggle takes effect, so it cannot leak to the placeholder.
- Esc and M are matched through `InputMap` actions (`pause`, `mute`) bound by physical keycode, like the title options. `DebugKeys` continues to match F1–F5 by keycode.
- Web: Godot's web canvas may already prevent defaults on keys it handles (1.6 DC13 verified this for F1–F5). Whether Esc is delivered to the canvas in Chrome and Firefox is part of H2.
- The Shift keys must do nothing in the game. Q and E are bound; the Shift key itself is not.

### Project Structure Notes

- New: `game/src/ui/screens/pause/pause_screen.gd` (+ `.uid`), `game/tests/unit/test_input_map.gd`, `game/tests/unit/test_pause.gd`, `game/tests/unit/test_pause_screen.gd` (each + `.uid` when Godot imports).
- Modified: `game/project.godot` (`[input]`), `game/src/autoloads/event_bus.gd`, `game/src/autoloads/game.gd`, `game/src/autoloads/audio_manager.gd`, `game/src/main/main.gd`, `game/tests/unit/test_audio_manager.gd`, `game/tests/unit/test_main_layers.gd`, `game/tests/unit/test_font_coverage.gd`, `game/tools/smoke_web.sh`.
- Architecture path: `src/ui/screens/pause/` is the architecture's `ui/screens/pause` (game-architecture.md screens tree).
- Conflicts: none found. `src/ui/screens/pause` is new; `src/input/` stays empty (InputMap is project-level, no code in 1.7).

### Testing Requirements

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Baseline is 142 tests passing at the 1.6 review.
- Pure helpers test without a scene tree: `PauseScreen.lines_for`, the mute hit rect, `AudioManager` mute via `AudioServer`, `Game.set_paused` on a `Game` instance, `SimClock` frame counting.
- Do not rely on real key events in GUT. If `Game._input` is hard to drive, factor the Esc decision into a static helper and test that helper, and keep the `_input` wrapper to one line.
- Shared autoloads: each test restores `SimClock.paused`, `SimClock.sim_frame` (if changed), `Game.flow_state`, `Game.run`, and the Master bus mute.
- Old tests that assume the `Main` layer set (`test_main_layers.gd`) need the new `Pause` layer taken into account, not removed.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- H1 Desktop: `godot --path game -- debug`: FIGHT, Esc pauses (overlay, arena frozen), Esc resumes, M mutes (label changes), Q/E and Space do nothing while paused, F5 clears the pause.
- H2 Web, Chrome and Firefox, physical keyboard, direct `html.itch.zone/...index.html?debug` URL (1.6 DC2): Esc pauses and resumes in INTRO and FIGHT; M mutes; switch tab for a few seconds and come back: the game is paused and a `[flow] pause on (focus)` line appears; it stays paused until Esc. Record any browser that does not deliver focus loss (DC9) and any Esc behaviour in fullscreen (DC10).
- H3 Release (no `debug`): Esc and M do nothing on the title; during a run Esc still pauses (pause is not debug-gated; only F-keys are).
- H4 Record the release web build size from the export for this story (local at 1.6: 28,433,114 bytes; budget 30,000,000).

## Epic 1 Done: What Remains

Epic 1's Definition of Done (sprint-status header, epics.md Epic List, NFR16): all stories meet their ACs; GUT and CI green; a release web build deployed with `butler` to the itch.io draft page; smoke-tested in Chrome and Firefox (title → the epic's new content) with build size recorded in the story notes. The epic may move to `done` only when this DoD is met.

After 1.7 is implemented and reviewed, the status of each DoD item is:

| DoD item | Status after 1.7 | What is left |
|---|---|---|
| Stories 1.1–1.7 meet ACs | Code complete once 1.7 is reviewed | Dev and review of 1.7 (`dev-story`, then `code-review`) |
| GUT and CI green | Locally green after 1.7 (agent run) | CI run on the PR (GitHub Actions), a human or PR step |
| Release web build deployed with `butler` to the itch.io draft page | **Not done (human)** | No `BUTLER_API_KEY` exists. Tiziano creates the itch.io secret and runs the deploy (1.3 H-steps; butler install and flags verified only at the first real deploy, 1.3 deferred H3). |
| Smoke-tested in Chrome and Firefox (title → the epic's new content) | **Partly done (headless Chrome only)** | Chrome and Firefox physical-key checks on the itch.io page: 1.3 H-steps, 1.6 H1–H3, and 1.7 H1–H4. Firefox has never been run by the agent. |
| Build size recorded in the story notes | Recorded for 1.6 (28,433,114 bytes); 1.7 pending | Task 6.3 and H4 in 1.7 |

Epic 1 stays `in-progress` in `sprint-status.yaml` until Tiziano completes the human steps. Then he moves `epic-1` to `done` by hand (sprint-status rule: manual, once all stories are done and the DoD is met). `epic-1-retrospective` is optional.

## Dev Agent Record

### Agent Model Used

Claude Haiku 5.5 (claude-haiku-5-5), gds-create-story, unattended

### Debug Log References

### Completion Notes List

- Story created unattended by gds-create-story. Design calls DC1–DC15 recorded above; the implementer records any deviation with `[design call]`.
- The epic's DoD cannot be closed by the agent: `butler` deploy (no `BUTLER_API_KEY`) and the Chrome and Firefox smoke are human steps. They are listed in "Epic 1 Done: What Remains".
- Web research was not run for this story: the APIs used (`NOTIFICATION_APPLICATION_FOCUS_OUT`, `AudioServer.set_bus_mute`, `InputMap`) are stable Godot 4 APIs already used in this project. The one platform fact not verified (focus-loss on web, DC9) is a verification item in H2, not a research claim.

### File List

### Review Findings

### Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status → ready-for-dev. Design calls DC1–DC15 recorded. Last story of Epic 1; Epic DoD human steps listed.
