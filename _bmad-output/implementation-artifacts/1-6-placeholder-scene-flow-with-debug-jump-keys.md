---
baseline_commit: 2d1ed4e
---

# Story 1.6: Placeholder Scene Flow with Debug Jump Keys

Status: review

## Story

As a developer,
I want the whole run sequence wired with placeholders and jump keys,
so that each screen can be reached and tested before its content exists.

**Requirements:** FR52; Additional: debug tools (architecture Debug Tools F1–F5, Debug activation).

## Acceptance Criteria

**AC1: Flow sequence (epics)**
Given `Game`'s flow state machine (enum + `match`: TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING),
When I advance through the placeholders with any key or click,
Then the sequence is Title → Intro → Fight 1 → Harvest → Fight 2 → Harvest → Fight 3 → Ending,
And `Game.run.boss_index` (a `RunState`) is 0, 1, 2 for Fight 1, 2, 3 and is 0 again after Ending returns to Title,
And every transition goes through `Game` only and emits `EventBus.flow_state_changed(from, to)`.

**AC2: Placeholder screens (epics)**
Given a placeholder screen is shown,
Then it shows its name (`TITLE`, `INTRO`, `FIGHT`, `HARVEST`, `ENDING`) and, for FIGHT and HARVEST, the boss index (ASCII only, in the Wildshift8 glyph font, drawn in `_draw()`).

**AC3: Intro timing (epics, D-040)**
Given the Intro placeholder,
Then it advances to FIGHT by itself after at most `Game.INTRO_MAX_FRAMES` = 480 sim frames (8 s at 60 Hz),
And it is skippable from its first frame: any key or click after the title input (`Game.can_skip_intro(SimClock.sim_frame)`) advances to FIGHT,
And the title input that started the run never counts as a skip (same-frame input is rejected).

**AC4: Debug jump keys (epics, architecture Debug Tools)**
Given a debug build, or a URL whose query has `debug` (`Debug.enabled`),
When I press F1, F2, F3, F4 or F5,
Then the game jumps to Title, Fight 1, Fight 2, Fight 3 or Ending respectively (`Game.run.boss_index` set to match; the jump is logged with `Log.info(&"debug", ...)`),
And a debug jump to Title resets `Game.first_input_frame` to -1 (closes the 1.4 deferred item).

**AC5: Release build gating (epics)**
Given a release web build whose URL has no `debug` key,
When I press F1–F5,
Then nothing happens, and no debug node is instanced (`Main` adds the debug key node only when `Debug.enabled`).

**AC6: Screen lifecycle (epics)**
Given `Game` leaves a flow state,
When the state changes,
Then the screen instanced for the old state is freed and the screen for the new state is instanced under `Main`,
And `Main` (with the arena and HUD layers) is never freed or rebuilt during the flow.

**AC7: FIGHT replaces the arena smoke gate (1.5 DC9)**
Given the FIGHT state,
When it is entered,
Then the arena and HUD are visible (`Arena` + `Hud` layers), and they are hidden in every other state,
And the `?debug&smoke=arena` URL gate is removed (the 1.5 `wants_arena_smoke` / `show_arena` path goes away).

**AC8: Debug gate reuse (1.3 deferred, 1.5 `UrlQuery`)**
Given the `?debug` check,
Then it lives in the `Debug` autoload only (`Debug.enabled = Debug.gate_enabled(OS.is_debug_build(), UrlQuery.web_search())`), built on `UrlQuery.has_debug`,
And `Main`'s audio smoke gate and the HUD F9 gate read `Debug.enabled` (the `?debug` parser is not duplicated).

**AC9: Iframe reachability (1.3 deferred) `[design call]` DC2**
Given the itch.io embed, whose iframe URL cannot carry the page's query string,
Then the debug route is documented in the story (Completion Notes) and in the Dev Notes: open the game's hosted iframe URL directly with `?debug` appended. No in-game secret input is added.

**AC10: Input does not leak into debug keys or the title (1.4/1.5 deferred items)**
Given F1–F12 on the title screen,
Then they never start the run (`TitleScreen.classify` ignores function keys), and debug keys are consumed in `_input` before the title sees them.

## Scope Boundaries

- In: `Game` flow transitions and `RunState` (minimal), debug jump keys, the `Debug` gate, placeholder screens (one shared script), the Intro skip/timeout, the screen host in `Main`, FIGHT showing the arena/HUD, removal of the arena smoke gate, tests, `smoke_web.sh` expectation update.
- Out: the real Intro panels (6.7), the pause screen and Esc (1.7), DEAD (2.9; no DEAD placeholder and no path into it), boss content, the register and HUD content, save/`[N]` new run (7.3), options (7.x), the frame/perf/invincibility/kill debug tools (F6–F11 are later stories), the F9 frame overlay (architecture F9 is the 1.5 grid overlay, DC7 of 1.5, kept).
- Not changed: web template, `export_presets.cfg`, CI workflow, `check_guards.sh`, the title's option table, the audio smoke scene, `Const`.

## Tasks / Subtasks

- [x] Task 1: Debug gate (AC: 4, 5, 8)
  - [x] 1.1 `src/autoloads/debug.gd`: add `static func gate_enabled(is_debug_build: bool, search: String) -> bool` returning `is_debug_build or UrlQuery.has_debug(search)`. Set `enabled = gate_enabled(OS.is_debug_build(), UrlQuery.web_search())` in `_ready()` (not as a field initialiser, so `web_search` runs once after the bridge is up). Keep the field name `enabled`.
  - [x] 1.2 `src/ui/hud/hud.gd`: the F9 key path reads `Debug.enabled`. The static `grid_toggle_allowed` and its test stay unchanged.
  - [x] 1.3 Test `tests/unit/test_debug_gate.gd`: `gate_enabled` truth table (`?debug`, `?debug&smoke=x`, `?debug=0`, `?debugger`, `?nodebug`, debug build true with empty search).
- [x] Task 2: RunState and Game flow (AC: 1, 3, 4)
  - [x] 2.1 `src/core/run_state.gd` (`class_name RunState`, `extends RefCounted`): `var boss_index: int = 0`. `deaths_on_boss` is added in 2.9, not here.
  - [x] 2.2 `src/autoloads/game.gd`: `const INTRO_MAX_FRAMES := 480`; `var run: RunState = RunState.new()`; `advance() -> void` with a `match flow_state` (TITLE is a no-op: its own input starts the run; INTRO → FIGHT with boss_index 0; FIGHT → ENDING if boss_index == 2 else HARVEST; HARVEST → FIGHT with boss_index + 1; ENDING → TITLE with `run = RunState.new()` and first_input_frame -1; DEAD → no-op, logged with `Log.warn` once per call).
  - [x] 2.3 `Game.finish_intro(frame)`: INTRO → FIGHT if `can_skip_intro(frame)` or the timeout is reached (`frame - intro_start_frame >= INTRO_MAX_FRAMES`); track `intro_start_frame` set on entering INTRO (`start_run_from_title` records `SimClock.sim_frame`).
  - [x] 2.4 `Game.debug_jump(target: FlowState, boss_index: int) -> void`: returns unless `Debug.enabled`; allowed targets TITLE, FIGHT (boss_index 0..2), ENDING; sets `run.boss_index`; TITLE resets `first_input_frame = -1`; logs `Log.info(&"debug", "jump -> %s boss=%d" % ...)`; emits through `_set_flow_state`.
  - [x] 2.5 All `flow_state` writes stay in `Game` (`_set_flow_state`). Presentation calls `advance()`, `finish_intro()` or `start_run_from_title()` only.
  - [x] 2.6 Tests in `tests/unit/test_game_state.gd` (extend) or `test_game_flow.gd`: full sequence Title → Intro → Fight 1 → Harvest → Fight 2 → Harvest → Fight 3 → Ending → Title; boss_index values; `can_skip_intro` false on the same frame as the title input and true on the next; intro timeout at 480 frames; debug jump ignored when `Debug.enabled` is false; jump to Title clears `first_input_frame`.
- [x] Task 3: Placeholder screens and host (AC: 2, 3, 6, 7)
  - [x] 3.1 `src/ui/screens/placeholder/placeholder_screen.gd` (`class_name PlaceholderScreen`, `extends Node2D`): one script for INTRO, FIGHT, HARVEST, ENDING. `setup(state: Game.FlowState)` picks the label text and whether the boss index is shown. `_draw()` uses `GlyphFont.draw_at` with `Palette.INK`, 2× scale, text top-left on the 8-px grid, centred with the same rule as the title (`TitleScreen.centred_x` or a shared helper).
  - [x] 3.2 Input: `_unhandled_input` treats any key press (not echo, not a modifier-only key, not a function key) or left-click press as the advance gesture. INTRO: call `Game.finish_intro(SimClock.sim_frame)` only when `Game.can_skip_intro(...)`. FIGHT, HARVEST, ENDING: call `Game.advance()`. Mark the event handled.
  - [x] 3.3 INTRO timeout: the screen does not use a Timer. Its `_physics_process` calls `Game.finish_intro(SimClock.sim_frame)`; the timeout check lives in `Game` (2.3). Presentation may use `_physics_process`; no `await`/Timer in `src/core` or `src/autoloads` for this.
  - [x] 3.4 `src/main/main.gd`: add a `Screens` `Node2D` child under `Main`. Listen to `EventBus.flow_state_changed` (connect in `_ready`); on change, free the current screen with `queue_free()` (guard `is_instance_valid`), then instance the new one: TITLE → `TitleScreen`, INTRO/FIGHT/HARVEST/ENDING → `PlaceholderScreen` after `setup()`, DEAD → none. Also instance the initial screen from `Game.flow_state` at boot (TITLE unless a smoke gate opened).
  - [x] 3.5 Arena/HUD visibility (AC7): set `arena.visible` and `hud.visible` from `flow_state == FIGHT` on each change and at boot. Remove `wants_arena_smoke`, `show_arena` and the arena smoke log line. Keep `_build_layers()` order (Arena → Entities → Particles → Hud → ScreenFX).
  - [x] 3.6 `TitleScreen`: on START it still calls `Game.start_run_from_title(SimClock.sim_frame)` and then `queue_free()` (the host is fine with an already-freed title). Add the function-key guard (AC10): `KEY_F1..KEY_F12` added to the non-start list in `classify`, so F9 on the title no longer starts the run (closes the 1.5 deferred item).
  - [x] 3.7 Debug keys (AC4, AC5): `src/debug/debug_keys.gd` (`class_name DebugKeys`, `extends Node`). `static func target_for_key(keycode: Key) -> Dictionary` (pure): F1 → TITLE/0, F2 → FIGHT/0, F3 → FIGHT/1, F4 → FIGHT/2, F5 → ENDING/0; anything else → empty. `_input(event)`: on a pressed, non-echo function key in the map, call `Game.debug_jump(...)`, then `get_viewport().set_input_as_handled()`. `Main._ready()` adds a `DebugKeys` node only when `Debug.enabled` (AC5).
  - [x] 3.8 `src/debug/smoke_audio/` stays as is; `Main` keeps the `?debug&smoke=audio` gate (`wants_audio_smoke`), now also requiring `Debug.enabled` (AC8).
- [x] Task 4: Tests (AC: all)
  - [x] 4.1 `tests/unit/test_debug_keys.gd`: `target_for_key` for F1–F5 and for a non-debug key; `DebugKeys` node not instanced when `Debug.enabled` is false (instance `Main` with the flag forced by a test helper, or test `Main.should_add_debug_keys(enabled)` as a pure static).
  - [x] 4.2 `tests/unit/test_main_layers.gd`: delete the `wants_arena_smoke` and `show_arena` tests (their behaviour is replaced). Add: arena and HUD visible only in FIGHT; screen for each state (TITLE → TitleScreen, INTRO/FIGHT/HARVEST/ENDING → PlaceholderScreen with matching label).
  - [x] 4.3 `tests/unit/test_title_input.gd`: F1–F12 classify as IGNORE, and F9 does not start the run.
  - [x] 4.4 `tests/unit/test_font_coverage.gd`: extend the glyph set with the placeholder labels (`TITLE`, `INTRO`, `FIGHT`, `HARVEST`, `ENDING`, `boss index`, digits). Glyphs must be in the Wildshift8 set.
  - [x] 4.5 Run the whole suite headless (command in Testing Requirements). The 1.1–1.5 tests stay green except the two arena-smoke tests in 4.2.
- [x] Task 5: Browser and export checks (AC: 4, 5, 9)
  - [x] 5.1 `game/tools/smoke_web.sh`: update the `?debug&smoke=arena` expectation to the FIGHT placeholder log line (`fight placeholder opened`), or add a `?debug` run that presses F2 and expects it. Keep the audio smoke run unchanged.
  - [x] 5.2 Release export (`game/tools/build_web_template.sh` is unchanged): record the build size in Completion Notes; expected about 28.4 MB (budget 30 000 000).
  - [x] 5.3 Windowed desktop check (`godot -- debug` on desktop, the `run` skill can drive it): F1–F5 move through the screens, the arena and HUD show only in FIGHT, F9 grid still toggles. Save the screenshot path (not committed).
  - [x] 5.4 Web local check: `?debug` F1–F5 jumps work; no `?debug` release: F1–F5 do nothing. Record results in Completion Notes.
- [x] Task 6: Docs and sprint status (AC: 9)
  - [x] 6.1 Completion Notes: the iframe route (DC2) written out as the steps the developer will use (H-items below).
  - [x] 6.2 `sprint-status.yaml`: `1-6-placeholder-scene-flow-with-debug-jump-keys` → `review` at the end of dev-story (not at create time).

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] DC1 RunState scope.** A minimal `RunState` (`core/run_state.gd`, `boss_index` only), owned by `Game` as `Game.run`. The architecture's `deaths_on_boss` and register snapshot come in 2.9 and 2.3. Reason: the epic names `RunState.boss_index`, and nothing else reads it before 2.x.
- **[design call] DC2 Debug inside the itch.io iframe.** The page's query string never reaches the embedded game (the iframe loads its own URL), so `?debug` cannot be added on the itch.io page. Decision: document it, do not add a secret chord. Route: open the game's hosted iframe URL (the `html.itch.zone` address that 1.3 H4 already uses) directly, with `?debug` appended. Release builds opened that way with no `debug` key have no debug tools. A secret in-game chord would be a player-reachable debug path, which the release rule forbids. The route goes in the README dev section in 7.9; until then, it is in this story's Completion Notes. The 1.3 deferred item is closed by this decision.
- **[design call] DC3 Debug gate.** One function, `Debug.gate_enabled(is_debug_build, search)`, built on `UrlQuery.has_debug`. `UrlQuery.web_search()` (1.5) already handles the desktop `-- debug` args. `Debug.enabled` is the single gate for F1–F5, F9 and the audio smoke gate.
- **[design call] DC4 Advance gesture.** Any key (not echo, not a function key, not a modifier) or a left click advances a placeholder, as the title does. Function keys are excluded so the debug keys never advance a screen by accident.
- **[design call] DC5 Intro timeout in sim frames.** The Intro's 8-s cap counts `SimClock.sim_frame` (480 frames), not wall time, so it stops with pause (1.7) and matches the first-shift metric. The timeout check lives in `Game.finish_intro`, the presentation only calls it.
- **[design call] DC6 Debug jumps.** Jumps go to TITLE, FIGHT 0–2 and ENDING only (the epic's list). DEAD and HARVEST are not jump targets; HARVEST is reached through FIGHT. A jump to TITLE clears `first_input_frame` (closes the 1.4 deferred item). Jumps are logged with tag `&"debug"`.
- **[design call] DC7 Debug keys live before the title.** `DebugKeys` handles F1–F5 in `_input` and marks them handled, so they never reach `TitleScreen`. Separately, `TitleScreen.classify` ignores F1–F12 (closes the 1.5 deferred item "F9 on the title counts as press any key"). Both rules apply in release too: in release the keys do nothing and do not start the run.
- **[design call] DC8 One placeholder script.** `PlaceholderScreen` serves INTRO, FIGHT, HARVEST and ENDING (labels and input differ by state). Real screens replace it in their stories (6.7 Intro, 6.8 Ending, 2.x/3.x FIGHT, 3.8 Harvest). Reason: fewer files, and the host logic is what must be tested.
- **[design call] DC9 Arena and HUD only in FIGHT.** `Main` keeps the persistent layers (AD-08) but shows the arena and HUD only while `flow_state == FIGHT`. The arena smoke gate is removed (the FIGHT placeholder replaces it, 1.5 DC9). The Title and Intro sit on the `BG` colour alone.
- **[design call] DC10 Ending returns to Title.** ENDING advances to TITLE and resets `RunState` (`boss_index` 0). The real end-of-game credits flow is 6.8.
- **[design call] DC11 Placeholder text.** ASCII only. FIGHT and HARVEST show `FIGHT 1`… and `boss index 0`… so the boss index is visible on screen. No extra glyphs are added to the Wildshift8 set (`test_font_coverage` must still pass).

### Architecture guardrails (must follow)

- **Flow (AD-08):** only `Game` changes `flow_state`, and only through `_set_flow_state`. Presentation calls `Game` methods and never writes state. Screens are instanced and freed; `Main` (arena, HUD, layers) persists.
- **Signals (AD-05):** only in `src/autoloads/event_bus.gd`, past tense, typed args. Use the existing `flow_state_changed(from: int, to: int)`; add no signal.
- **Debug (architecture Debug Tools, project-context):** debug tools only when `Debug.enabled` (`OS.is_debug_build()` or `?debug`). Debug UI lives in `src/debug/`; export excludes `addons/gut`, `tests/`, `tools/`.
- **Simulation folders** (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not use `Timer.new`, `await`, `create_timer` or `get_ticks_msec` (CI guard), and must not reference `ui`, `presentation`, `AudioManager`, `VoiceService`. `core/` and `autoloads/` are not in the guard list, but keep `Game` free of `await` and Timers as well.
- **Logging:** `Log.*` only. No bare `print`, no `push_warning` or `push_error` outside `Log`. Log flow transitions with tag `&"flow"`, debug jumps with `&"debug"`, and never per frame.
- **Typing:** `untyped_declaration` is an error: type every variable, parameter and return. `StringName` ids (`&"flow"`).
- **Glyphs:** `draw_at`/`draw_char` in `_draw()`, no `Label` per glyph; palette `INK`/`BG` only.
- **Assets:** preload (AD-13). No runtime `load()` except the existing audio smoke gate.

### Previous story intelligence (1.1–1.5)

- **`Game` (1.1, 1.4):** `enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }`; `start_run_from_title(frame)` (TITLE → INTRO, sets `first_input_frame`, logs `title -> intro at f=`); `can_skip_intro(frame)` returns true only for frames after the title input. 1.4 DC5 says 1.6 uses these. Nothing else changes flow state.
- **`TitleScreen` (1.4, 1.5):** `classify(event, rects)` pure; `handle_input` unlocks audio, calls `Game.start_run_from_title`, then `queue_free()`. Draws with `GlyphFont.draw_at` at `TEXT_SCALE := 2` on the 8-px grid; `centred_x` is the centring helper to reuse.
- **`Main` (1.3–1.5):** `wants_audio_smoke(search)` and `wants_arena_smoke(search)` are pure statics; `_build_layers()` adds `Arena` (hidden), `Entities`, `Particles`, `Hud` (CanvasLayer 10, hidden), `ScreenFX` (CanvasLayer 20). 1.5 DC9 says the FIGHT placeholder is the 1.6 deliverable that shows the arena normally.
- **`UrlQuery` (1.5, `src/core/url_query.gd`):** `has_debug`, `has_smoke`, `web_search()`. Off web, debug builds read the user args after `--`. Reuse; do not add another parser.
- **`Hud` (1.5):** `grid_toggle_allowed(is_debug_build, search)` gates F9. Keep the function; change the caller to `Debug.enabled`.
- **`GlyphFont` (1.5):** `draw_at(canvas, top_left, text, color, scale)`, `text_width(text, scale)`, `size_for(scale)`, `CELL` = 8. Font coverage is tested against the strings in the tests (`test_font_coverage.gd`).
- **`smoke_web.sh` (1.3, 1.5):** runs headless Chrome; the expectation strings are per run. The arena run (`?debug&smoke=arena`, expects `arena smoke view opened`) must be updated (Task 5.1).
- **Deferred items this story closes:** 1.4 "`Game.first_input_frame` not reset on re-entering TITLE" (Task 2.4, DC6); 1.5 "F9 on the title screen counts as press any key" (DC7); 1.3 "audio smoke `?debug` URL unreachable inside the itch.io iframe" (DC2). The 1.4 item "`start_run_from_title` returns nothing" stays deferred (no caller needs a return value).
- **Still deferred (not this story):** 1.4 "AudioManager.unlock only sets a flag"; 1.5 "Arena is a Node2D while the HUD is a CanvasLayer" (Epic 7); 1.4 "label_rects canvas vs viewport" (7.x); 1.2 "no delta check in sim folders".
- **Size baseline:** 1.5 web build 28,425,410 bytes (budget 30 000 000). No template change here; expect within a few kB.

### Input and browser notes

- Web: function keys can be taken by the browser (F1 help, F5 reload, F11 fullscreen in some browsers). Whether the Godot canvas suppresses them is not verified here; H2 checks that F5 does not reload the page. If it does, record it and pick another debug key (a design call); do not drop the F5 jump silently.
- `InputMap` is for gameplay actions. Debug keys are matched by keycode in `DebugKeys` (debug-only node), which is allowed because the node is not in release.

### Project Structure Notes

- New: `game/src/core/run_state.gd` (+ `.uid`), `game/src/ui/screens/placeholder/placeholder_screen.gd` (+ `.uid`), `game/src/debug/debug_keys.gd` (+ `.uid`), `game/tests/unit/test_debug_gate.gd`, `game/tests/unit/test_debug_keys.gd`, `game/tests/unit/test_game_flow.gd` (or extended `test_game_state.gd`).
- Modified: `game/src/autoloads/debug.gd`, `game/src/autoloads/game.gd`, `game/src/main/main.gd`, `game/src/ui/screens/title/title_screen.gd`, `game/src/ui/hud/hud.gd`, `game/tests/unit/test_main_layers.gd`, `game/tests/unit/test_title_input.gd`, `game/tests/unit/test_font_coverage.gd`, `game/tools/smoke_web.sh`.
- Architecture path for screens is `src/ui/screens/` (1.4). Placeholders go in `src/ui/screens/placeholder/`; the real Intro, Harvest, Ending and Pause screens later get their own folders under the same parent.
- Conflicts: none found with the architecture tree. `src/debug/` is excluded from release export as the architecture requires.

### Testing Requirements

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Keep the pure helpers testable without a scene tree: `Debug.gate_enabled`, `DebugKeys.target_for_key`, `Game.advance` / `finish_intro` / `debug_jump` on a `Game` instance (the existing `test_game_state.gd` already instances it), `TitleScreen.classify`.
- Test Main's screen host by instancing `Main` and calling the change handler directly with the flow states; do not rely on real key events.
- The 1.1–1.5 tests stay green except the arena-smoke tests replaced in Task 4.2.

### Human checks (for Tiziano, recorded in Completion Notes; do not block dev-story `review`)

- H1 Desktop: `godot --path game -- debug` (or the editor), then F1–F5 through each screen; arena and HUD only in FIGHT; F9 grid still works.
- H2 Web, Chrome and Firefox: `https://<itch iframe URL>?debug` (the direct `html.itch.zone` URL, DC2): F1–F5 jumps; F5 does not reload the page. Release (no `debug`): F1–F5 do nothing.
- H3 Record the build size from the release export.

### References

- Epics: `_bmad-output/planning-artifacts/epics.md` → Epic 1, Story 1.6 (lines 460–483); FR52 and the debug tools note.
- Architecture: `_bmad-output/game-architecture.md` → Flow and state (AD-08, around lines 186–196), Debug Tools table and Activation (lines 389–406), `Game` FSM and `RunState` (lines 191–193).
- Project rules: `_bmad-output/project-context.md` (debug tools line 79; `RunState` line 92).
- GDD: Intro skippable from first frame (D-040, GDD Intro row, Gameplay Metrics first-shift 30 s); option and title input (D-048). `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md`.
- Story 1.4 (title, `Game.first_input_frame`, DC5): `_bmad-output/implementation-artifacts/1-4-title-screen-with-press-to-start-and-audio-unlock.md`.
- Story 1.5 (arena, HUD, UrlQuery, DC9): `_bmad-output/implementation-artifacts/1-5-the-clearing-arena-and-ide-hud-frame.md`.
- Story 1.3 (iframe deferred item, H4): `_bmad-output/implementation-artifacts/1-3-web-export-and-itch-io-draft-deploy.md`.
- Deferred items: `_bmad-output/implementation-artifacts/deferred-work.md`.

## Dev Agent Record

### Agent Model Used

Claude Haiku 5.5 (claude-haiku-5-5), gds-create-story, unattended
Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended

### Debug Log References

- Red phase: new tests failed to parse before implementation (`gate_enabled`, `DebugKeys`, `should_add_debug_keys`, `PlaceholderScreen`, `RunState` missing).
- Flow walk driver (scratchpad, not committed) found a real bug the first unit tests missed: the Intro screen polls `Game.finish_intro` every physics frame, and with the story's literal rule (`can_skip_intro(frame) or timeout`) the Intro advanced to FIGHT one frame after the title input with no key press. Fixed with an explicit `skip_requested` argument (DC12 below) and a unit test that polls 479 frames without input.
- GUT (CI-identical marker check): 141 tests, 141 passing, `All tests passed!`, no failure markers. `check_guards.sh`: OK. Import: no script errors.

### Completion Notes List

- Story created unattended by gds-create-story. Design calls DC1–DC11 recorded above; the implementer records any deviation with `[design call]`.
- Iframe route (DC2): the itch.io page query does not reach the embedded game. Debug is reached by opening the hosted iframe URL directly with `?debug` appended. No in-game chord.
- HUMAN steps (Tiziano), still open: H1 desktop walk-through, H2 Chrome and Firefox check of F1–F5 and the F5 reload risk, H3 release build size.
- **Implemented (gds-dev-story, unattended).** `Debug.gate_enabled` + `Debug.enabled` set in `_ready` (single gate for F1–F5, F9 and the audio smoke gate); `RunState` (`boss_index`) owned by `Game.run`; `Game.advance`, `finish_intro`, `intro_timed_out`, `debug_jump`, `INTRO_MAX_FRAMES = 480`, every transition through `_set_flow_state` (now also logs `FROM -> TO` with tag `flow`); `PlaceholderScreen` (one script for INTRO/FIGHT/HARVEST/ENDING, `_draw()` with `GlyphFont.draw_at` at 2x, centred with `TitleScreen.centred_x`, BG backing rect so FIGHT text reads over the arena); `Main` gets a `Screens` host after the AD-07 layers, swaps screens on `EventBus.flow_state_changed`, shows arena + HUD only in FIGHT, adds `DebugKeys` only when `Debug.enabled`; the arena smoke gate (`wants_arena_smoke`, `show_arena`) is removed; `TitleScreen.is_function_key` makes F1–F12 (to F35) IGNORE; HUD F9 reads `Debug.enabled`.
- **Tests added/changed:** `test_debug_gate.gd` (truth table + autoload matches gate), `test_game_flow.gd` (full sequence and signal count, boss_index, fresh RunState after Ending, TITLE/DEAD no-op, skip not on the title frame, no advance while polling without input, 480-frame timeout, debug jump gate/targets/rejections, Title jump clears `first_input_frame`), `test_debug_keys.gd` (F1–F5 map, other keys empty, `should_add_debug_keys`, `handle_key` jumps and ignores release/echo/unmapped, Main adds `DebugKeys` only when enabled), `test_main_layers.gd` (arena-smoke tests removed; Screens host, visibility per state, screen per state with label, old screen freed, signal-driven swap keeps Arena/Hud nodes), `test_title_input.gd` (F1–F12 IGNORE, F9 does not start the run), `test_grid_overlay.gd` (F9 ignored when `Debug.enabled` is false), `test_font_coverage.gd` (every placeholder line for boss 0–2).
- **Flow walk (Task 5.3), real input events through `Input.parse_input_event` into `Main`:** headless and windowed (`godot --path game -s <scratchpad>/walk/walk.gd`), 20/20 steps OK both times: boot TITLE (arena/HUD hidden) → F9 on title (no start) → Enter → INTRO → Space → FIGHT 1 (boss 0, arena+HUD on) → HARVEST (boss 0) → FIGHT 2 (boss 1) → HARVEST (boss 1) → click → FIGHT 3 (boss 2) → ENDING → TITLE (boss 0, `first_input_frame` -1) → Enter → INTRO held at intro_start+479 → FIGHT at exactly intro_start+480 (f=45 → f=525) → F9 grid on in FIGHT → F5 ENDING → F4 FIGHT 3 → F3 FIGHT 2 → F2 FIGHT 1 → F1 TITLE (`first_input_frame` -1) → Shift on title (no start). `Screens` holds one child at the end. Screenshots (not committed): `/private/tmp/claude-501/-Users-tizianobasile-workspace-me-github-gameoff-2026/ff533116-16c6-46ad-8c71-3734310679b8/scratchpad/walk/step_00.png` … `step_19.png` (step_03 = FIGHT 1 over arena + HUD, step_04 = HARVEST).
- **Release web export (Task 5.2):** stripped template from the `build_web_template.sh` work folder via a temporary `custom_template/release` (reverted, not committed). Export log clean. **Size 28,433,114 bytes** (budget 30,000,000; 1.5 was 28,425,410, +7,704 bytes).
- **Web checks (Task 5.1, 5.4), `smoke_web.sh` headless Chrome over CDP, all PASS:** no query (boot); `?debug&smoke=audio` + click (`pan R`); `?debug` + F2 → `jump -> FIGHT boss=0`, `fight placeholder opened boss=0`; `?debug` + F5 F3 F4 F1 → ENDING, FIGHT 2, FIGHT 3, TITLE; release without `debug` + F2 F5 F1 → no `[debug] jump` line, title stays. Every run: no navigation after boot, the window sentinel survives.
- **F5 in the browser:** a bubble-phase `keydown` listener on `window` reports `defaultPrevented: true` for F1, F2, F3, F4 and F5, with and without `?debug`: the Godot web canvas already calls `preventDefault` on these keys, so the browser does not run its own F5 reload / F1 help. A control page showed that CDP `Input.dispatchKeyEvent` never triggers Chrome's reload accelerator (not even headful, not even on a page without handlers), so "no reload" in automation alone proves nothing; `defaultPrevented: true` is the evidence. No code change needed and F5 stays the Ending jump (DC13). H2 confirms it with a physical keyboard in Chrome and Firefox.
- **Iframe route (DC2), steps for Tiziano:** 1) open the itch.io game page, 2) take the embedded game's iframe `src` (the `https://html.itch.zone/html/<id>/index.html` address from 1.3 H4, browser dev tools → the game iframe), 3) open that URL directly in a new tab with `?debug` appended (`.../index.html?debug`), 4) F1–F5 jump, F9 toggles the grid in FIGHT; `?debug&smoke=audio` still opens the audio smoke scene. Without `?debug` the release build has no debug tools.
- **[design call] DC12 Explicit Intro skip.** `Game.finish_intro(frame, skip_requested := false)`: the skip counts only with `skip_requested` (an input) and `can_skip_intro(frame)`; the per-frame poll only applies the 480-frame cap. Reason: the story's literal rule ended the Intro one frame after the title input without any key (found by the flow walk).
- **[design call] DC13 F5 stays the Ending jump.** Verified that the engine prevents the browser default for F1–F5 (see above); no extra `preventDefault` code and no other key.
- **[design call] DC14 `src/debug/` stays in the export.** The story's Project Structure note says `src/debug/` is excluded from release, but a release web build opened with `?debug` needs `DebugKeys` and the audio smoke scene. The preset is unchanged (it never excluded `src/debug/`); release safety comes from `Debug.enabled` (the node is not instanced without it).
- **[design call] DC15 Smoke script interface.** `smoke_web.sh` gains `SMOKE_KEYS` (CDP key presses after boot) and `SMOKE_REJECT` (a log line that must not appear), and every run fails on a navigation after boot. The arena run is replaced by `SMOKE_QUERY="?debug" SMOKE_KEYS="F2" SMOKE_EXPECT="fight placeholder opened"`.
- **[design call] DC16 Small extras inside the tasks.** `Game._set_flow_state` logs each transition (`[flow] FROM -> TO`, event-only); a debug jump to an invalid target logs `Log.warn(&"debug", ...)` and does nothing; `PlaceholderScreen` draws a BG rect behind its text so the FIGHT label is legible over the arena; `TitleScreen` gets the name `TitleScreen` under `Screens`.
- **HUMAN steps (Tiziano), still open, not blocking review:** H1 desktop walk-through (`godot --path game -- debug`): F1–F5, arena/HUD only in FIGHT, F9 grid. H2 web with a physical keyboard in Chrome and Firefox at the direct `html.itch.zone/...?debug` URL: F1–F5 jump, F5 does not reload; release URL without `debug`: F1–F5 do nothing. H3 note the CI release export size on the PR (local: 28,433,114 bytes).

### File List

- game/src/autoloads/debug.gd (modified)
- game/src/autoloads/game.gd (modified)
- game/src/core/run_state.gd (new)
- game/src/core/run_state.gd.uid (new)
- game/src/debug/debug_keys.gd (new)
- game/src/debug/debug_keys.gd.uid (new)
- game/src/main/main.gd (modified)
- game/src/ui/hud/hud.gd (modified)
- game/src/ui/screens/placeholder/placeholder_screen.gd (new)
- game/src/ui/screens/placeholder/placeholder_screen.gd.uid (new)
- game/src/ui/screens/title/title_screen.gd (modified)
- game/tests/unit/test_debug_gate.gd (new)
- game/tests/unit/test_debug_gate.gd.uid (new)
- game/tests/unit/test_debug_keys.gd (new)
- game/tests/unit/test_debug_keys.gd.uid (new)
- game/tests/unit/test_game_flow.gd (new)
- game/tests/unit/test_game_flow.gd.uid (new)
- game/tests/unit/test_font_coverage.gd (modified)
- game/tests/unit/test_grid_overlay.gd (modified)
- game/tests/unit/test_main_layers.gd (modified)
- game/tests/unit/test_title_input.gd (modified)
- game/tools/smoke_web.sh (modified)
- _bmad-output/implementation-artifacts/1-6-placeholder-scene-flow-with-debug-jump-keys.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)

### Review Findings

### Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status → ready-for-dev. Design calls DC1–DC11 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): Debug gate, RunState and Game flow, placeholder screens and Main screen host, F1–F5 debug keys, arena/HUD only in FIGHT, arena smoke gate removed, title ignores function keys, smoke_web.sh key presses and reload check. 141 GUT tests pass; web build 28,433,114 bytes. Design calls DC12–DC16 added. Status → review.
