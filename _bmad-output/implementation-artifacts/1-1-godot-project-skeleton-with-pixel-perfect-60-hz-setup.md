# Story 1.1: Godot Project Skeleton with Pixel-Perfect 60 Hz Setup

Status: ready-for-dev

## Story

As a developer,
I want an empty Godot 4.7.2 project configured exactly as the architecture prescribes,
so that every later story starts from the same pixel-perfect, fixed-60 Hz, statically typed foundation.

**Requirements:** NFR6 (640×360 base, integer-scaled, Nearest filtering). Additional: project setup, no starter template.

## Acceptance Criteria

**AC1: Project settings**
Given a fresh clone of the repo,
When I open `game/project.godot` in Godot 4.7.2-stable,
Then the project uses the Compatibility renderer, viewport 640×360, stretch mode `viewport`, aspect `keep`, scale mode `integer`, default texture filter Nearest, physics ticks 60 and web audio playback type `Sample`,
And the `untyped_declaration` warning is set to error.

**AC2: Folder tree and foundation constants**
Given the project,
When I inspect the file tree,
Then the domain-first folders from the architecture Directory Structure exist under `game/` (`src/<domain>`, `data/<domain>`, `assets/`, `tests/{unit,integration,replays}`, `tools/`),
And `src/core/const.gd` (`class_name Const`: `TILE_PX = 16`, `SIM_HZ = 60`, base resolution, arena 32×18, `tiles_per_s_to_px_per_frame()`) and `src/core/palette.gd` (`INK #E8E8E8`, `BG #101014`, `WARN #FF4040`) exist.

**AC3: Boot, autoloads and logging**
Given the project,
When it boots,
Then the autoloads `Log`, `EventBus`, `SimClock`, `Game`, `Debug`, `AudioManager`, `VoiceService` and `SaveService` are registered as typed stubs, and a persistent `main.tscn` is the main scene,
And `Log` prints `[f=<sim_frame>][LEVEL][tag] msg` and is the only logging path (no bare `print` anywhere in `game/`),
And `SimClock` increments `sim_frame` once per `_physics_process` and exposes `paused` (see Design Call DC3).

**AC4: Pixel-perfect output**
Given the game runs in a 1280×720 window,
When I look at a test glyph drawn with the palette,
Then pixels are crisp at 2× integer scale and the frame rate is 60 FPS.

## Tasks / Subtasks

- [ ] Task 1: Create the Godot project and its settings (AC: 1)
  - [ ] 1.1 Create `game/project.godot` with Godot 4.7.2-stable (Project Manager → New Project, path `game/`, renderer Compatibility). Do NOT use a starter template.
  - [ ] 1.2 Set `rendering/renderer/rendering_method` to Compatibility (`gl_compatibility`).
  - [ ] 1.3 Set `display/window/size/viewport_width = 640` and `viewport_height = 360`; set the window size to 1280×720 (window size is separate from the viewport base; see DC5).
  - [ ] 1.4 Set `display/window/stretch/mode = "viewport"`, `display/window/stretch/aspect = "keep"`, `display/window/stretch/scale_mode = "integer"`.
  - [ ] 1.5 Set default canvas texture filter to Nearest (`rendering/textures/canvas_textures/default_texture_filter`, Nearest).
  - [ ] 1.6 Set `physics/common/physics_ticks_per_second = 60`.
  - [ ] 1.7 Set Audio > General > Default Playback Type (web) to `Sample` (the web key is `audio/general/default_playback_type.web`; verify the exact key in the editor).
  - [ ] 1.8 Set `debug/gdscript/warnings/untyped_declaration` to Error.
  - [ ] 1.9 Set the clear colour to `BG` (#101014) so the empty frame is background-coloured.
  - [ ] 1.10 Check that the root `.gitignore` ignores `game/.godot/` and export output; add entries only if missing.
- [ ] Task 2: Create the folder tree (AC: 2)
  - [ ] 2.1 Under `game/` create `addons/`, `assets/{fonts,audio/music,audio/sfx,shaders}`, `data/{config,player,bits,actions,combos,bosses/{infinite_loop,null_pointer,segfault},duck,text}`, `src/{autoloads,core,input,register,player,combat/shapes,skills/{breakpoint,watch},bosses/{framework,infinite_loop/attacks,null_pointer/attacks,segfault/attacks,practice_target},arena,presentation,ui/{hud,duck,screens},main,debug}`, `tools/`, `tests/{unit,integration,replays}`.
  - [ ] 2.2 Git does not track empty folders: add a `.gitkeep` in each leaf folder that is otherwise empty.
  - [ ] 2.3 Do NOT add `addons/gut` or `mumble_speech` here (Story 1.2 and Story 1.3/AD-14).
- [ ] Task 3: Constants and palette (AC: 2)
  - [ ] 3.1 `src/core/const.gd`: `class_name Const`; `const TILE_PX := 16`, `const SIM_HZ := 60`, `const BASE_RES := Vector2i(640, 360)`, `const ARENA_TILES := Vector2i(32, 18)`; `static func tiles_per_s_to_px_per_frame(tiles_s: float) -> float` returning `tiles_s * TILE_PX / SIM_HZ`.
  - [ ] 3.2 `src/core/palette.gd`: `class_name Palette`; `INK` = `#E8E8E8`, `BG` = `#101014`, `WARN` = `#FF4040` (WARN is for warnings only). If `Color("#...")` is rejected in a `const`, use `static var` and note it in Completion Notes.
- [ ] Task 4: Autoload stubs, Log, SimClock and main scene (AC: 3)
  - [ ] 4.1 Register autoloads in this order (Log first, since the others log through it): `Log`, `EventBus`, `SimClock`, `Game`, `Debug`, `AudioManager`, `VoiceService`, `SaveService`. Script paths: `src/autoloads/<snake_name>.gd` (e.g. `log.gd`, `event_bus.gd`, `sim_clock.gd`, `game.gd`, `debug.gd`, `audio_manager.gd`, `voice_service.gd`, `save_service.gd`).
  - [ ] 4.2 `Log` (`extends Node`): methods `error`, `warn`, `info`, `debug` each taking `(tag: StringName, msg: String)`. Output format `[f=<sim_frame>][LEVEL][tag] msg`, where `sim_frame` is read from `SimClock`. `debug` prints only when `Debug.enabled`. Destinations: `info`/`debug`/`error` via `print`; `warn` via `push_warning`; `error` also via `push_error` (no popups, no pausing). See DC6.
  - [ ] 4.3 `SimClock` (`extends Node`): `var sim_frame: int = 0`, `var paused: bool = false`. `_physics_process(_delta: float) -> void` increments `sim_frame` by 1 when not paused. No other logic in this story. `delta` is never used for gameplay.
  - [ ] 4.4 `EventBus` (`extends Node`): empty. The signal list is added in later stories; all signals live only in this file.
  - [ ] 4.5 `Game` (`extends Node`): declare `enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }` and `var flow_state: FlowState = FlowState.TITLE`. No transitions yet.
  - [ ] 4.6 `Debug` (`extends Node`): `var enabled: bool = OS.is_debug_build()`. The `?debug` URL check is added in Story 1.6 (DC8).
  - [ ] 4.7 `AudioManager`, `VoiceService`, `SaveService` (`extends Node`): typed empty stubs with a one-line class comment. No behaviour; no `AudioServer` calls.
  - [ ] 4.8 `src/main/main.tscn` with root `main.gd` (`extends Node2D`) as the persistent root (AD-08). Set it as the main scene (`application/run/main_scene`). It holds no arena, HUD or screens yet.
- [ ] Task 5: Test glyph for the pixel-perfect check (AC: 4)
  - [ ] 5.1 In `main.gd` `_draw()`, draw one 8×8 test glyph (a fixed bit pattern built from `draw_rect` calls) at 2× scale (each cell 2×2 px = 16 px tile size), INK on BG. Use `queue_redraw()` if it must redraw.
  - [ ] 5.2 Rects, not a font: there is no font asset yet (the font arrives in Story 1.5). See DC4.
- [ ] Task 6: Verify (AC: 1–4)
  - [ ] 6.1 Open `game/project.godot` in Godot 4.7.2-stable: zero warnings in the Output panel and the Project Settings values match Task 1.
  - [ ] 6.2 Run the project from the editor at 1280×720. Confirm the test glyph has hard, crisp edges at 2× with no uneven pixel widths. Confirm the boot log line appears, e.g. `[f=0][INFO][flow] boot`.
  - [ ] 6.3 Confirm `SimClock.sim_frame` increases by 60 per second: inspect it in the Remote Inspector (or a temporary breakpoint) while the game runs. Do not add a logging loop.
  - [ ] 6.4 Headless boot: `godot --headless --path game --quit` exits 0 with no errors.
  - [ ] 6.5 Grep check: `grep -rn "print(" game/src` returns only `src/autoloads/log.gd`.
  - [ ] 6.6 Check FPS: the editor's Monitors/FPS readout shows 60 with the test glyph on screen. The F10 perf overlay does not exist yet.
  - [ ] 6.7 Record the Godot version, the export-template status and any setting-key differences in Completion Notes.

## Dev Notes

### Scope boundaries

- In scope: project file, folder tree, `Const`, `Palette`, typed autoload stubs, `Log`, `SimClock.sim_frame`, `main.tscn`, a test glyph.
- Out of scope (later stories): GUT and CI (1.2), Web export preset and itch.io deploy (1.3), title screen and audio unlock (1.4), arena and HUD (1.5), debug keys F1–F11 (1.6), pause and focus loss (1.7), any gameplay code, real font, any `tick()` logic.
- Do not create files outside `game/` except the `.gitignore` entry in Task 1.10.

### Architecture requirements that bind this story

- **Godot 4.7.2-stable** pinned. GDScript only. No C#.
- **AD-01** Simulation timing: `SimClock` runs in `_physics_process` (60 ticks/s). Its `paused` flag is the gate for the world (later used with Breakpoint and hit-stop). In this story only `sim_frame` and `paused` exist.
- **AD-08** `Main` is a persistent scene. `Game` is the flow state machine; only `Game` changes flow state.
- **AD-05** `EventBus` is the only place signals are declared (empty here).
- **Logging** (cross-cutting): `[f=<sim_frame>][<LEVEL>][<tag>] <message>`; levels ERROR, WARN, INFO, DEBUG; tags are short `StringName`s such as `&"flow"`, `&"sim"`, `&"save"`. No per-frame logging. DEBUG only in debug builds.
- **Palette**: `INK #E8E8E8`, `BG #101014`, `WARN #FF4040` only for warnings.
- **Resolution**: 640×360 base, stretch `viewport`, scale mode `integer`, Nearest. The itch.io embed is 1280×720 (2× integer).
- **Web audio**: playback type `Sample` (no AudioEffects, no reverb, no doppler, no `AudioStreamGenerator`). Positional audio is unreliable in Sample mode; not used in this story.

### Godot 4.7 specifics (verified against the Godot 4.7 docs, 2026-11-06)

- Integer scaling is `display/window/stretch/scale_mode = "integer"`. It rounds the scale factor down to an integer. With viewport 640×360 in a 1280×720 window the scale is exactly 2×.
- Stretch `viewport` renders the scene to a 640×360 viewport and scales that to the window. Use this, not `canvas_items`, to keep pixel art crisp.
- Since Godot 4.3, web audio uses the Web Audio API. `Sample` is the default web playback type and is low latency without threads. Setting: Audio > General > Default Playback Type.web.
- Use static typing everywhere: `:=` for inferred locals is fine; any untyped `var x = ...` or untyped parameter becomes an error under `untyped_declaration`. Annotate every parameter and return type.

### Source tree to touch (all new)

```
game/
  project.godot
  src/core/const.gd           src/core/palette.gd
  src/autoloads/log.gd        src/autoloads/event_bus.gd   src/autoloads/sim_clock.gd
  src/autoloads/game.gd       src/autoloads/debug.gd       src/autoloads/audio_manager.gd
  src/autoloads/voice_service.gd                           src/autoloads/save_service.gd
  src/main/main.tscn          src/main/main.gd
  (folder tree + .gitkeep per Task 2)
```

No existing code is modified: the repo currently has only `_bmad-output/`, `_bmad/`, `.claude/`, `README.md`, `LICENSE`.

### Project Structure Notes

- Godot root is `game/` (`res://` = `game/`). Never place game files at the repo root.
- Domain-first layout per architecture Directory Structure; the epic AC's `src/core/` paths match.
- Autoload script names are `snake_case`; `class_name` is PascalCase; autoload names are PascalCase.
- The project-context.md config table says `scripts/core/const.gd`. That conflicts with the architecture Directory Structure and this story's AC. Use `src/` (see DC2).

### Project Context Rules

Populated from `_bmad-output/project-context.md` (the file is not under `planning-artifacts`):

- Godot 4.7.2-stable, do not upgrade. GDScript only.
- Only `SimClock` calls `tick()`. Only `SimClock._physics_process` runs in this story; no gameplay `_process`/`_physics_process`, no `Timer` nodes, no `await`, no `create_tween()`, no `delta` in gameplay.
- No `Area2D`/`PhysicsBody2D`/`CharacterBody2D` for gameplay.
- Signals only in `event_bus.gd`, past tense, typed args.
- Logging only through `Log` (`Log.error/warn/info/debug(&"tag", msg)`); no bare `print`.
- Errors: `assert()` + `Log.error` for programmer errors, then return a safe default; environment errors → `Log.warn` once and degrade silently. Never show errors to the player.
- Godot 3 syntax is wrong: use `@export`, `@onready`, `signal.connect(callable)`, `await`.
- No `Engine.time_scale`, no `SceneTree.paused` for gameplay pause (use `SimClock.paused`).
- Static typing everywhere; `StringName` literals (`&"..."`) for ids.
- Assets are `preload()`ed (AD-13); no runtime `load()` in this story.

### Design Calls

Made unattended during story creation. Each is a recommendation the designer can overrule.

- **DC1 Architecture source:** the architecture file is `_bmad-output/game-architecture.md`. It is outside the `planning-artifacts` input pattern, so it was loaded directly. Used as the architecture source.
- **DC2 Source root:** `src/` and `data/` (architecture Directory Structure and this story's AC), not `scripts/` (project-context.md config table). Recommended: `src/`.
- **DC3 SimClock gating:** `sim_frame` increments only when `paused` is false. AD-01 says the pause gate stops the tick. The AC literal (increment per `_physics_process`) still holds when unpaused.
- **DC4 Test glyph:** drawn with `draw_rect` from an 8×8 bit pattern, not a font, because no font asset exists until Story 1.5. Recommended: rects now, font in 1.5.
- **DC5 Window vs viewport:** the viewport base is 640×360 (stretch `viewport`); the window is 1280×720 as set in the Project Settings window size. This matches the 2× case in AC4 and the itch.io 1280×720 embed.
- **DC6 Log destinations:** `info`/`debug`/`error` use `print`; `warn` uses `push_warning`; `error` also calls `push_error`. The architecture says "print / push_warning" and "no push_error popups". `push_error` in the editor and browser console only, with no popup, is accepted. If a popup appears, drop the `push_error` call.
- **DC7 Autoload stubs:** typed, empty, no behaviour. Behaviour arrives in the story that owns each system.
- **DC8 Debug enabled:** `Debug.enabled = OS.is_debug_build()` only. The `?debug` URL check (architecture Debug Tools) is added in Story 1.6 with the debug keys, to avoid a `JavaScriptBridge` call in a story that has no need for it.
- **DC9 Autoload order:** `Log` first. Its `sim_frame` read needs `SimClock` to exist at call time, which is true because logging happens after `_ready`.

### References

- Epic 1 Story 1.1 ACs and NFR6: [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1]
- Engine, project initialization settings: [Source: _bmad-output/game-architecture.md#Project Initialization]
- Decisions AD-01, AD-05, AD-08, AD-09, AD-13: [Source: _bmad-output/game-architecture.md#Architectural Decisions]
- Cross-cutting logging, configuration, error handling, event system: [Source: _bmad-output/game-architecture.md#Cross-cutting Concerns]
- Directory Structure and Architectural Boundaries: [Source: _bmad-output/game-architecture.md#Project Structure]
- Rendering and resolution (GDD D-047): [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md]
- Project rules: [Source: _bmad-output/project-context.md]
- Godot 4.7 docs (stretch, integer scale, web audio playback): godot-docs branch 4.7, `tutorials/rendering/multiple_resolutions.rst` and `tutorials/export/exporting_for_web.rst`.

## Dev Agent Record

### Agent Model Used

_To be filled in by the dev agent._

### Debug Log References

### Completion Notes List

### File List
