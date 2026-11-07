---
baseline_commit: 560c8b4
---

# Story 1.4: Title Screen with Press-to-Start and Audio Unlock

Status: review

## Story

As a player,
I want a title screen that starts the game on my first key press or click,
so that nothing blares before I interact and I move straight into the game.

**Requirements:** FR47 (D-048 title and option interaction); NFR3 (title interactive in ≤ 10 s on 50 Mbps, cold cache; checked in the browser by the human steps only).

## Acceptance Criteria

**AC1: Title shows, silence before input**
Given the game has loaded,
When the title screen appears,
Then it shows the full title `The Debugger 0x03: Wild Shift` and a `press any key` prompt,
And no audio plays (no player starts before the first input; nothing autoplays).

**AC2: Any non-option key or click starts the run**
Given the title screen,
When I press any key or click that is not an option hotkey (`N`, `P`, `B`, `F`) or a click on an option label,
Then `Game` transitions TITLE → INTRO and emits `EventBus.flow_state_changed(from, to)`,
And `AudioManager` is unlocked and a test SFX plays on the `SFX` bus,
And `Game` records the sim frame of this first input as the start of the 30-s first-shift clock, logged with `Log.info(&"flow", ...)`,
And that same input does not count as a skip of the Intro placeholder (`Game.can_skip_intro(frame)` is false for that frame; the Intro itself arrives in 1.6).

**AC3: Option hotkeys and labels unlock audio but do not start the run**
Given the title screen,
When I press an option hotkey or click an option label whose option is available,
Then audio is unlocked (and the test SFX may play) but `Game` does not leave TITLE,
And options with no implementation yet are hidden, and their keys then start the run as normal keys do (D-048; options appear in 7.3, 7.4, 7.6 and 7.7).

**AC4: AudioManager buses and unlock gate**
Given `AudioManager` initialises,
When the audio server is inspected,
Then buses `Master` → `Music`, `SFX`, `Voice` exist, each sending to `Master`, with no bus effects,
And any play request before unlock is ignored, with exactly one `Log.warn` for the session (no crash, no sound).

## Scope Boundaries

- **In scope:** title screen node and its input handling; the title text and prompt; `Game` TITLE → INTRO transition and first-input frame; `EventBus.flow_state_changed`; `AudioManager` buses, unlock gate and test SFX; GUT tests; a headless and a windowed scripted check.
- **Out of scope:** the CP437 pixel font and its licence file (1.5, D-047); the Intro placeholder, F1–F5 debug jump keys and the `?debug` URL check (1.6); pause and focus loss (1.7); the arena and HUD (1.5); save/resume and the `N` option (7.3); debug build `B` (7.4); practice `P` (7.6); fullscreen `F` (7.7); gamepad Start/Select (7.5, Should); the real music and SFX assets (7.1, 7.2); any change to the web template.
- **Not touched:** `_bmad`, `.claude` (symlinks, gitignored); the 1.3 smoke scene content; CI workflow; `check_guards.sh` rules.

## Tasks / Subtasks

- [x] Task 1: Bus layout and AudioManager (AC: 4, 2)
  - [x] 1.1 Create `game/default_bus_layout.tres` (res:// root, the path Godot uses for the default bus layout) with `Master` (send none), `Music`, `SFX`, `Voice` (each send `Master`), no effects. Verify the file loads headless: `AudioServer.get_bus_index(&"SFX") >= 0` after a `--headless --quit` boot. Use the editor's own save format if a hand-written `.tres` is rejected (see DC3).
  - [x] 1.2 Implement `game/src/autoloads/audio_manager.gd` (stub from 1.1, `extends Node`):
    - `var _unlocked: bool = false` and `var _warned_locked: bool = false`.
    - `func unlock() -> void`: idempotent. Sets `_unlocked = true`, logs `Log.info(&"audio", "unlocked")` once.
    - `func is_unlocked() -> bool`.
    - `func play_test_sfx() -> void`: if not unlocked, call `_warn_locked_once()` and return. Otherwise play a generated blip on the `SFX` bus (see DC4).
    - `func _warn_locked_once() -> void`: `Log.warn(&"audio", "play ignored before unlock")` only when `_warned_locked` is false, then set it true.
    - Creates no `AudioStreamPlayer` at boot and never calls `play()` before unlock. No `AudioServer` bus creation at runtime (the layout is the file).
  - [x] 1.3 Keep the smoke scene (1.3) working: its tone falls back to `Master` only when `SFX` is missing, so it should now land on `SFX`. Do not change the smoke scene file.
- [x] Task 2: EventBus and Game flow (AC: 2, 3)
  - [x] 2.1 `src/autoloads/event_bus.gd`: add `signal flow_state_changed(from: int, to: int)` (architecture signal list; typed, past-tense naming already matches). No other signal.
  - [x] 2.2 `src/autoloads/game.gd`: keep `enum FlowState` and `flow_state`. Add:
    - `var first_input_frame: int = -1`.
    - `func start_run_from_title(frame: int) -> void`: only valid when `flow_state == TITLE` (else `Log.warn` and return). Sets `first_input_frame = frame`, logs `Log.info(&"flow", "title -> intro at f=%d" % frame)`, then calls `_set_flow_state(FlowState.INTRO)`.
    - `func can_skip_intro(frame: int) -> bool`: returns `first_input_frame >= 0 and frame > first_input_frame`. Story 1.6 must use it for the Intro skip.
    - `func _set_flow_state(to: FlowState) -> void` (private): stores `flow_state`, emits `EventBus.flow_state_changed.emit(from, to)`. Only `Game` writes `flow_state`.
  - [x] 2.3 Game does not change `SimClock`, does not use `Engine.time_scale`, and adds no `Timer` or `await`.
- [x] Task 3: Title screen (AC: 1, 2, 3)
  - [x] 3.1 Create `game/src/ui/screens/title/title_screen.gd` (`class_name TitleScreen`, `extends Node2D`). No `.tscn` is required (drawn in code, like the 1.1 glyph). Presentation only: no `await`, no `Timer`, no sim state writes.
  - [x] 3.2 Pure input classifier, unit-testable without a scene: `static func classify(event: InputEvent) -> int` returning `TitleScreen.Action.IGNORE`, `START`, or `OPTION` (plus the option id when `OPTION`, e.g. a `StringName` `&"new_run" | &"practice" | &"debug_build" | &"fullscreen"`). Rules:
    - `InputEventKey` with `pressed` and not `echo`: `N`/`P`/`B`/`F` → `OPTION`; any other key → `START`.
    - `InputEventMouseButton` with `pressed`: a click on an option label → `OPTION`; any other click → `START`.
    - Everything else (releases, echoes, mouse motion) → `IGNORE`.
  - [x] 3.3 `_unhandled_input(event)`: run `classify`. On `IGNORE` return. Otherwise call `AudioManager.unlock()` first (every input unlocks audio, including option keys). Then:
    - `START`: `Game.start_run_from_title(SimClock.sim_frame)`, `AudioManager.play_test_sfx()`, then free this screen (`queue_free()`).
    - `OPTION`: if the option is available (the `available` table, see DC2), act on it (no option is available in 1.4). If not available, treat it exactly as `START`.
    - Mark input as handled with `get_viewport().set_input_as_handled()`.
  - [x] 3.4 Drawing, in `_draw()` only, with `ThemeDB.fallback_font` (DC1): the title `The Debugger 0x03: Wild Shift` centred on the 640×360 base, and `press any key` below it, both in `Palette.INK` on the `BG` clear colour. Use `queue_redraw()` if the text changes. No blink (DC9). Option labels `[N] new run`, `[P] practice`, `[B] debug build`, `[F] fullscreen` are NOT drawn in 1.4 because all four are unavailable (DC2).
  - [x] 3.5 The title's `classify` uses option key constants defined once in `title_screen.gd` (no magic keycodes spread around). Input mapping: see DC7.
- [x] Task 4: Main wiring (AC: 1)
  - [x] 4.1 `src/main/main.gd` `_ready()`: keep the Story 1.3 smoke gate unchanged (`wants_audio_smoke`, `?debug&smoke=audio`). When the gate is closed, instance `TitleScreen` as a child (`load` or `preload` of its script, AD-13) instead of drawing the test glyph. Keep the `Log.info(&"flow", "boot")` line.
  - [x] 4.2 Remove the 1.1 test glyph from the default path (DC11) only if no test depends on it; otherwise leave the function but hide it while the title is shown.
  - [x] 4.3 Nothing in `main.gd` may branch on `?debug` for the title (DC6).
- [x] Task 5: Tests (AC: 1–4)
  - [x] 5.1 `tests/unit/test_title_input.gd`: `classify` table: `N`,`P`,`B`,`F` pressed → `OPTION`; `N` echo → `IGNORE`; `N` release → `IGNORE`; `Enter`, `Space`, `A` pressed → `START`; left click on the screen → `START`; mouse motion → `IGNORE`.
  - [x] 5.2 `tests/unit/test_audio_manager.gd`: after boot, `AudioServer` has `Master`, `Music`, `SFX`, `Voice`; each non-Master bus sends to `Master`; no effect count > 0 on any bus; `play_test_sfx()` before `unlock()` does not change the count of playing `AudioStreamPlayer`s and produces exactly one warn (capture via the Log warn counter, see Testing Requirements); after `unlock()` (idempotent on a second call) `play_test_sfx()` starts one player on `SFX`.
  - [x] 5.3 `tests/unit/test_game_state.gd` (extend the 1.1 file): `start_run_from_title(120)` moves TITLE → INTRO, `first_input_frame == 120`, `can_skip_intro(120) == false`, `can_skip_intro(121) == true`; a second `start_run_from_title` from INTRO is rejected and does not change `first_input_frame`; `flow_state_changed` fires once with `(0, 1)` (TITLE=0, INTRO=1).
  - [x] 5.4 Re-run the existing suite and the guards; no test from 1.1–1.3 may be weakened.
- [x] Task 6: Verify (AC: 1–4)
  - [x] 6.1 `godot --headless --path game --quit` exits 0; boot log only (no errors, no `Locked` warnings at boot).
  - [x] 6.2 `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` passes with the new tests.
  - [x] 6.3 `bash game/tools/check_guards.sh` passes (the title and audio code live outside the sim folders).
  - [x] 6.4 Windowed scripted run (scratchpad script, not committed, as in 1.1): title visible with no `AudioStreamPlayer` playing; a synthetic key press (`N` is hidden so `N` starts the run) moves `Game.flow_state` to INTRO with `first_input_frame` equal to the `SimClock.sim_frame` at press time; log line `title -> intro at f=N` appears.
  - [x] 6.5 Release web export built locally with the stripped template recipe (`game/tools/build_web_template.sh` already in repo): export succeeds, size recorded in Dev Agent Record (expect about 28.4 MB, unchanged in kind; DC12). The `?debug&smoke=audio` path still opens the 1.3 smoke scene with `smoke_web.sh`.
  - [x] 6.6 Record Godot version, GUT result, guard result, size in Completion Notes.

### [HUMAN] steps (Tiziano, not the dev agent)

- [ ] H1: In Chrome, Firefox and Safari (latest) on the itch.io draft: title shows, silent until the first key or click; the test blip is audible after the first click and not before. Note the result per browser.
- [ ] H2: Option keys `N`, `P`, `B`, `F` do nothing visible yet and start the run as normal keys (D-048 hidden-option rule). Record it.
- [ ] H3: Confirm the title reaches a playable state in ≤ 10 s on a throttled connection (NFR3).

## Dev Notes

### Design calls (made unattended during story creation)

Each is a recommendation; the designer can overrule it. Each is also marked `[design call]` in the story's Completion Notes when the dev agent acts on it.

- **DC1 Title font `[design call]`:** use the engine's built-in fallback font (`ThemeDB.fallback_font`, drawn with `draw_string`) for the title and prompt. Reason: the epics say "glyph font", but the CP437 pixel font and its licence arrive only in Story 1.5 (D-047). Pulling a font download and licence check into 1.4 would move that work forward and risk the Nov 6–7 window. The fallback font needs no asset, and the stripped template keeps `freetype` and `text_server_fb` on, so it renders. Recommended: fallback font now, swap to the 1.5 pixel font when it lands. Pick an integer font size and draw at integer positions so the text stays crisp under Nearest filtering.
- **DC2 Option visibility `[design call]`:** all four options (`N`, `P`, `B`, `F`) are hidden in 1.4. `N` needs a save (none until 7.3), `P` and `B` are Should, and `F` (fullscreen) is 7.7. The epics say hidden option keys "start the game as normal keys do", so `N`/`P`/`B`/`F` start the run here. The "option does not start the run" branch (AC3) is implemented behind an `available` table (`&"new_run"`, `&"practice"`, `&"debug_build"`, `&"fullscreen"` all `false`) and covered by a GUT test that flips one entry to `true` on a test instance. Nothing visible changes for the player in 1.4.
- **DC3 Bus layout file `[design call]`:** the bus layout is a file, `res://default_bus_layout.tres`, which Godot loads by default, rather than runtime bus creation. Reason: AD-09 fixes the buses and the 1.3 smoke scene explicitly deferred bus creation to this story. Recommended: write the file, and let the editor re-save it if the hand-written format is rejected. Verify with a headless boot.
- **DC4 Test SFX `[design call]`:** a generated 0.15-s 16-bit mono sine blip built in code (`AudioStreamWAV`, the same approach as the 1.3 smoke tone), so no audio asset or import is needed. It plays on `SFX`. Real SFX arrive in 7.2.
- **DC5 Intro boundary `[design call]`:** `Game.first_input_frame` plus `Game.can_skip_intro(frame)` records the title input and stops it counting as an Intro skip (D-040, D-048). The Intro placeholder that uses it arrives in 1.6. In 1.4 no INTRO screen exists; after the transition `Main` shows an empty `BG` screen.
- **DC6 Debug gate (1.3 deferred item) `[design call]`:** the deferred 1.3 note ("the `?debug` audio smoke URL is unreachable through the itch.io iframe") is owned by Story 1.6 (the real `?debug` check in `Debug`) and by the human step H4 of 1.3. Story 1.4 adds no debug-gated behaviour: the title and the audio unlock work with no URL parameter, and the existing `main.gd` smoke gate is left as is. Nothing in 1.4 should be debugging-only, so the iframe limit does not block it.
- **DC7 Input mapping `[design call]`:** the architecture says `InputMap` actions only. Recommended: add four `InputMap` actions in `project.godot` `[input]` with keyboard events: `title_option_new_run` (N), `title_option_practice` (P), `title_option_debug_build` (B), `title_option_fullscreen` (F). `classify` reads the action names, not raw keycodes. Any other key counts as `START`. Gamepad Start/Select is 7.5 and is not in 1.4. If hand-writing the `[input]` entries is error-prone, define them in code at boot in `TitleScreen` and note the choice; the classifier stays the same.
- **DC8 Unlock point `[design call]`:** `AudioManager.unlock()` is called by the title screen on every counted input, before any other handling. Godot's web build resumes the audio context on the first user gesture; the explicit unlock flag is the game's own gate, so the test blip plays inside the input handler, which browsers accept.
- **DC9 No blink `[design call]`:** `press any key` is static. A blink would need a presentation timer; that is cosmetic, so it waits for the polish epic (7.7 or 7.9).
- **DC10 Log wording `[design call]`:** the first-input log line is `title -> intro at f=<frame>` with tag `&"flow"`, and the unlock line `unlocked` with tag `&"audio"`. These are the only new log lines (no per-frame logging).
- **DC11 Test glyph `[design call]`:** the 1.1 test glyph is removed from the default path because the title screen replaces it. If a test depends on it, the function stays and is hidden while the title shows (Task 4.2).
- **DC12 Size `[design call]`:** the stripped template from 1.3 stays; 1.4 adds no template module. Expect the release export to stay about 28.4 MB. Any module needed later (svg, zip, websocket, mbedtls, noise) is re-enabled in `game/tools/build_web_template.sh` in the story that needs it. 1.4 needs none: fallback font (freetype, text_server_fb, on), WAV (core), input (core).

### Previous story intelligence (1.1–1.3)

- **1.1:** `Log` is the only logging path. `SimClock.sim_frame` increments only when not paused. `Game.flow_state` enum is `FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }` with no transitions yet; this story adds the first one. `Palette.INK`/`BG` and `Const` already exist. `untyped_declaration` is an error: type every parameter and return.
- **1.2:** GUT 9.6.1 in `game/addons/gut`, headless command in Testing Requirements. `check_guards.sh` forbids `Timer.new`, `await`, `create_timer`, `get_ticks_msec` in `src/{input,register,player,combat,bosses,skills,arena}` and bare `print`/`push_warning`/`push_error` outside `Log`. Title and audio code under `src/ui` and `src/autoloads` are outside these folders, but `push_warning` must still go through `Log.warn`.
- **1.3:** the stripped web template disables `svg`, `noise`, `mbedtls`, `websocket`, `zip`, `text_server_adv` and more; it keeps `freetype`, `text_server_fb`, `webp`, `jpg`, `ogg`, `vorbis`, `regex` (see DC12). The `?debug&smoke=audio` gate lives in `main.gd` (`wants_audio_smoke`, pure static, exact key parse). The smoke scene plays its tone on `SFX` if the bus exists, else `Master`; with this story's bus file, it should now play on `SFX`. Deferred: the URL gate is unreachable inside the itch.io iframe (DC6). Size gate: CI fails over 30 000 000 bytes (stripped template, CI cold build about 12 min, warm runs cached).

### Git intelligence (last commits)

- `560c8b4 docs(story): mark story 1.3 done after review`; `c2a4ffa fix: build stripped Web template in CI, fail the size gate...`; `8139c16 docs(story): ... story 1.3 ready for review`. Code and docs commits are separate; the story file and sprint status are committed with `docs(story): ...`.
- The stripped template recipe is `game/tools/build_web_template.sh` (excluded from export). CI uses it, caches it and fails on size.

### Architecture requirements that bind this story

- **AD-05** Signals only in `event_bus.gd`, past tense, typed args. `flow_state_changed(from: int, to: int)` is the architecture's listed signal.
- **AD-08** `Game` is the flow FSM; only `Game` changes `flow_state` and only through its methods. Presentation calls `Game.start_run_from_title`; it never writes state.
- **AD-09** Buses `Master` → `Music`, `SFX`, `Voice`; Sample playback; no bus effects; **nothing plays before the first input**.
- **AD-13** Preload assets; no runtime `load()` except the existing smoke gate.
- **AD-14** Not in this story (duck voice is 3.7).
- Input: `InputMap` actions (keyboard + gamepad), never Shift keys; the title is not simulation, so the 8-frame buffer does not apply.
- Fullscreen (`F`) is a later story but must call `DisplayServer` from an input handler (noted for 7.7).

### Project Structure Notes

- New: `game/default_bus_layout.tres`, `game/src/ui/screens/title/title_screen.gd` (+ `.uid`), `game/tests/unit/test_title_input.gd`, `game/tests/unit/test_audio_manager.gd` (+ `.uid`s). Modified: `game/src/autoloads/{audio_manager,event_bus,game}.gd`, `game/src/main/main.gd`, `game/tests/unit/test_game_state.gd`, `game/project.godot` (only if DC7 uses `[input]`).
- Architecture path is `src/ui/screens/` (title, intro, harvest, dead, ending, pause). The 1.4 title goes in `src/ui/screens/title/` to match.
- No conflicts found with the architecture tree or the sim-folder guard.

### Testing Requirements

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Warn counting: `Log.warn` goes through `push_warning`. Test the once-only behaviour by a `_warned_locked` flag check and the `AudioStreamPlayer` count, not by capturing stderr.
- Keep the pure `classify` function free of scene nodes so it runs without a renderer (project rule: simulation and logic tests need no scene tree; this is presentation logic but kept pure for the same reason).
- Run the existing 1.1–1.3 tests unchanged; the 1.3 preset test expects `addons/gut`, `tests/`, `tools/` excluded, which must still hold.

### Project Context Rules

Populated from `_bmad-output/project-context.md`:

- Godot 4.7.2-stable, GDScript only. Compatibility renderer, Sample web audio, no audio effects.
- No audio before the first user input (title press-to-start). No `AudioStreamGenerator`.
- Only `Game` changes flow state; presentation never writes sim state.
- Signals only in `event_bus.gd`; `StringName` literals for ids (`&"new_run"`); static typing everywhere.
- Glyphs and text in `_draw()` with `draw_string`/`draw_char`; no `Label` per glyph.
- `Log.*` only; no bare `print`, no `push_warning`/`push_error` outside `Log`.
- Debug tools (F1–F11, overlays) only with `OS.is_debug_build()` or `?debug`; none in this story.
- `Assets` preloaded (AD-13); the test blip is generated, not loaded.
- Errors: a play request before unlock is an environment condition: `Log.warn` once, then ignore silently. Never show an error to the player.

### References

- Story 1.4 ACs and FR47: [Source: _bmad-output/planning-artifacts/epics.md#Story 1.4]
- D-040 (Intro skippable from its first frame; title input does not skip it), D-048 (title and option interaction): [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md]
- GDD Controls, press-to-start and option hotkeys: [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Controls]
- Architecture: AD-05, AD-08, AD-09, Audio buses, signal list, Input: [Source: _bmad-output/game-architecture.md]
- Project rules: [Source: _bmad-output/project-context.md]
- Previous story: [Source: _bmad-output/implementation-artifacts/1-3-web-export-and-itch-io-draft-deploy.md#Dev Notes]
- Deferred items: [Source: _bmad-output/implementation-artifacts/deferred-work.md]
- Godot 4.7 docs (verified via Context7 `/godotengine/godot-docs/__branch__4.7`): `ThemeDB.fallback_font` and `draw_string(font, pos, text, alignment, width, font_size)` in `CanvasItem`; default bus layout saved as `res://default_bus_layout.tres` ([audio_buses]).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended.

### Debug Log References

- Red phase: new tests failed to parse (missing `make_blip`, `title_screen.gd`, `start_run_from_title`) before implementation; green after.
- The first two stripped-template builds failed on `git clone` of the Godot source (network reset, `fetch-pack: invalid index-pack output`). Workaround: the 4.7.2-stable source tarball was unpacked into `WORK_DIR/godot` (the script skips the clone when the folder exists); the build then ran unchanged in 1 min 59 s. Script not changed.

### Completion Notes List

- Godot 4.7.2.stable.official (ed1daf0bf), macOS. Template built with emscripten 4.0.11.
- **Bus layout (Task 1.1):** hand-written `default_bus_layout.tres` loads as is, no editor re-save needed. Headless and windowed boot both show 4 buses (Music=1, SFX=2, Voice=3), each sending to Master, no effects (GUT `test_audio_manager`).
- **AudioManager:** `unlock()` idempotent, `play_test_sfx()` ignored before unlock with one `Log.warn` per session (`locked_warn_count` exposed for the test), no player at boot, one reused `AudioStreamPlayer` on `SFX` created at the first unlocked play.
- **Game:** `start_run_from_title`, `can_skip_intro`, `_set_flow_state`; `EventBus.flow_state_changed(from, to)`. No SimClock, time_scale, Timer or await changes.
- **TitleScreen:** pure static `classify(event, rects)` + `option_of(event, rects)`; instance `resolve()` applies the `available` table; `handle_input()` unlocks audio first, then on START calls `Game.start_run_from_title(SimClock.sim_frame)`, plays the blip and frees itself.
- **Main:** opens `TitleScreen` (preloaded) when the 1.3 smoke gate is closed; the 1.1 test glyph is removed (no test used it). Smoke gate unchanged.
- **GUT:** 71/71 passing (was 48; +13 title input, +7 audio manager, +3 game state), CI failure markers absent. **Guards:** `check_guards: OK`. **Headless boot:** exit 0, only `[flow] boot`, no warnings.
- **Windowed scripted run (6.4, scratch autoload, not committed):** title present, 0 playing players, locked; synthetic `N` press at f=30 -> `[audio] unlocked`, `[flow] title -> intro at f=30`, `flow_state=INTRO`, `first_input_frame=30`, 1 player playing, title freed. Screenshot checked: title and prompt centred and legible at 640x360.
- **Web export (6.5):** release export with the locally built stripped template (preset path set temporarily, not committed): **28,406,474 bytes** (budget 30,000,000; side.wasm 25,414,775). `smoke_web.sh` PASS (plain boot); `SMOKE_CLICK=1 SMOKE_EXPECT="title -> intro"` PASS (`[audio] unlocked`, `title -> intro at f=2`); `?debug&smoke=audio` PASS, tone now on bus `SFX` (Task 1.3).
- **Audio unlock in headless Chrome** (scratch CDP probe, `--autoplay-policy=document-user-activation-required`, hooks on `AudioContext` and `AudioBufferSourceNode.start`): before input the context is `suspended` and 0 buffer sources exist; after one click (and, in a second run, one `N` key press) the context is `running` and exactly one 0.15 s buffer source was started. Audibility per browser stays with H1.
- [design call] DC1 fallback font (`ThemeDB.fallback_font`), title 32 px, prompt 16 px, integer baselines.
- [design call] DC2 all four options hidden; the AC3 branch is covered by GUT flipping `available[&"practice"]` on a test instance (stays in TITLE, audio unlocked).
- [design call] DC3 bus layout as a file; the hand-written format was accepted.
- [design call] DC4 blip: 880 Hz, 0.15 s, 16-bit mono 22050 Hz, linear fade-out to avoid a click, no loop.
- [design call] DC5 `first_input_frame` + `can_skip_intro`; after the transition Main shows an empty BG screen until 1.6.
- [design call] DC6 no debug-gated behaviour added.
- [design call] DC7 four InputMap actions hand-written in `project.godot [input]` using `physical_keycode` (N/P/B/F); `option_of` checks `event.is_action(action, true)`.
- [design call] DC8 unlock on every counted input, before any other handling; the blip plays inside the input handler.
- [design call] DC9 static prompt, no blink. DC10 log lines as specified. DC11 glyph removed. DC12 no template change.
- [design call] (dev) `classify` returns the `Action` enum; the option id comes from a separate pure `option_of()` rather than a tuple return, so both stay simple to test.
- [design call] (dev) the test-only `Game`/`AudioManager` autoload state touched by `test_available_option_input_keeps_title_and_unlocks_audio` is restored by the test (`_unlocked` reset if it was false).
- HUMAN steps H1–H3 remain open for Tiziano (browser audibility per browser, hidden-option behaviour, NFR3 throttled load).

### File List

- game/default_bus_layout.tres (new)
- game/src/autoloads/audio_manager.gd (modified)
- game/src/autoloads/event_bus.gd (modified)
- game/src/autoloads/game.gd (modified)
- game/src/ui/screens/title/title_screen.gd (new)
- game/src/ui/screens/title/title_screen.gd.uid (new)
- game/src/main/main.gd (modified)
- game/project.godot (modified, `[input]` section)
- game/tests/unit/test_title_input.gd (new)
- game/tests/unit/test_title_input.gd.uid (new)
- game/tests/unit/test_audio_manager.gd (new)
- game/tests/unit/test_audio_manager.gd.uid (new)
- game/tests/unit/test_game_state.gd (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/1-4-title-screen-with-press-to-start-and-audio-unlock.md (modified)

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status → ready-for-dev. Design calls DC1–DC12 recorded above.
- 2026-11-07: Implemented by gds-dev-story (unattended): bus layout, AudioManager unlock gate, Game TITLE -> INTRO, title screen, InputMap option actions, 23 new GUT tests; web build 28,406,474 bytes. Status → review.
