---
baseline_commit: 5fcd66caec6e18a8aeb128b123ff3f20b0342be0
---

# Story 1.1: Godot Project Skeleton with Pixel-Perfect 60 Hz Setup

Status: done

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

- [x] Task 1: Create the Godot project and its settings (AC: 1)
  - [x] 1.1 Create `game/project.godot` with Godot 4.7.2-stable (Project Manager → New Project, path `game/`, renderer Compatibility). Do NOT use a starter template.
  - [x] 1.2 Set `rendering/renderer/rendering_method` to Compatibility (`gl_compatibility`).
  - [x] 1.3 Set `display/window/size/viewport_width = 640` and `viewport_height = 360`; set the window size to 1280×720 (window size is separate from the viewport base; see DC5).
  - [x] 1.4 Set `display/window/stretch/mode = "viewport"`, `display/window/stretch/aspect = "keep"`, `display/window/stretch/scale_mode = "integer"`.
  - [x] 1.5 Set default canvas texture filter to Nearest (`rendering/textures/canvas_textures/default_texture_filter`, Nearest).
  - [x] 1.6 Set `physics/common/physics_ticks_per_second = 60`.
  - [x] 1.7 Set Audio > General > Default Playback Type (web) to `Sample` (the web key is `audio/general/default_playback_type.web`; verify the exact key in the editor).
  - [x] 1.8 Set `debug/gdscript/warnings/untyped_declaration` to Error.
  - [x] 1.9 Set the clear colour to `BG` (#101014) so the empty frame is background-coloured.
  - [x] 1.10 Check that the root `.gitignore` ignores `game/.godot/` and export output; add entries only if missing.
- [x] Task 2: Create the folder tree (AC: 2)
  - [x] 2.1 Under `game/` create `addons/`, `assets/{fonts,audio/music,audio/sfx,shaders}`, `data/{config,player,bits,actions,combos,bosses/{infinite_loop,null_pointer,segfault},duck,text}`, `src/{autoloads,core,input,register,player,combat/shapes,skills/{breakpoint,watch},bosses/{framework,infinite_loop/attacks,null_pointer/attacks,segfault/attacks,practice_target},arena,presentation,ui/{hud,duck,screens},main,debug}`, `tools/`, `tests/{unit,integration,replays}`.
  - [x] 2.2 Git does not track empty folders: add a `.gitkeep` in each leaf folder that is otherwise empty.
  - [x] 2.3 Do NOT add `addons/gut` or `mumble_speech` here (Story 1.2 and Story 1.3/AD-14).
- [x] Task 3: Constants and palette (AC: 2)
  - [x] 3.1 `src/core/const.gd`: `class_name Const`; `const TILE_PX := 16`, `const SIM_HZ := 60`, `const BASE_RES := Vector2i(640, 360)`, `const ARENA_TILES := Vector2i(32, 18)`; `static func tiles_per_s_to_px_per_frame(tiles_s: float) -> float` returning `tiles_s * TILE_PX / SIM_HZ`.
  - [x] 3.2 `src/core/palette.gd`: `class_name Palette`; `INK` = `#E8E8E8`, `BG` = `#101014`, `WARN` = `#FF4040` (WARN is for warnings only). If `Color("#...")` is rejected in a `const`, use `static var` and note it in Completion Notes.
- [x] Task 4: Autoload stubs, Log, SimClock and main scene (AC: 3)
  - [x] 4.1 Register autoloads in this order (Log first, since the others log through it): `Log`, `EventBus`, `SimClock`, `Game`, `Debug`, `AudioManager`, `VoiceService`, `SaveService`. Script paths: `src/autoloads/<snake_name>.gd` (e.g. `log.gd`, `event_bus.gd`, `sim_clock.gd`, `game.gd`, `debug.gd`, `audio_manager.gd`, `voice_service.gd`, `save_service.gd`).
  - [x] 4.2 `Log` (`extends Node`): methods `error`, `warn`, `info`, `debug` each taking `(tag: StringName, msg: String)`. Output format `[f=<sim_frame>][LEVEL][tag] msg`, where `sim_frame` is read from `SimClock`. `debug` prints only when `Debug.enabled`. Destinations: `info`/`debug`/`error` via `print`; `warn` via `push_warning`; `error` also via `push_error` (no popups, no pausing). See DC6.
  - [x] 4.3 `SimClock` (`extends Node`): `var sim_frame: int = 0`, `var paused: bool = false`. `_physics_process(_delta: float) -> void` increments `sim_frame` by 1 when not paused. No other logic in this story. `delta` is never used for gameplay.
  - [x] 4.4 `EventBus` (`extends Node`): empty. The signal list is added in later stories; all signals live only in this file.
  - [x] 4.5 `Game` (`extends Node`): declare `enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }` and `var flow_state: FlowState = FlowState.TITLE`. No transitions yet.
  - [x] 4.6 `Debug` (`extends Node`): `var enabled: bool = OS.is_debug_build()`. The `?debug` URL check is added in Story 1.6 (DC8).
  - [x] 4.7 `AudioManager`, `VoiceService`, `SaveService` (`extends Node`): typed empty stubs with a one-line class comment. No behaviour; no `AudioServer` calls.
  - [x] 4.8 `src/main/main.tscn` with root `main.gd` (`extends Node2D`) as the persistent root (AD-08). Set it as the main scene (`application/run/main_scene`). It holds no arena, HUD or screens yet.
- [x] Task 5: Test glyph for the pixel-perfect check (AC: 4)
  - [x] 5.1 In `main.gd` `_draw()`, draw one 8×8 test glyph (a fixed bit pattern built from `draw_rect` calls) at 2× scale (each cell 2×2 px = 16 px tile size), INK on BG. Use `queue_redraw()` if it must redraw.
  - [x] 5.2 Rects, not a font: there is no font asset yet (the font arrives in Story 1.5). See DC4.
- [x] Task 6: Verify (AC: 1–4)
  - [x] 6.1 Open `game/project.godot` in Godot 4.7.2-stable: zero warnings in the Output panel and the Project Settings values match Task 1.
  - [x] 6.2 Run the project from the editor at 1280×720. Confirm the test glyph has hard, crisp edges at 2× with no uneven pixel widths. Confirm the boot log line appears, e.g. `[f=0][INFO][flow] boot`.
  - [x] 6.3 Confirm `SimClock.sim_frame` increases by 60 per second: inspect it in the Remote Inspector (or a temporary breakpoint) while the game runs. Do not add a logging loop.
  - [x] 6.4 Headless boot: `godot --headless --path game --quit` exits 0 with no errors.
  - [x] 6.5 Grep check: `grep -rn "print(" game/src` returns only `src/autoloads/log.gd`.
  - [x] 6.6 Check FPS: the editor's Monitors/FPS readout shows 60 with the test glyph on screen. The F10 perf overlay does not exist yet.
  - [x] 6.7 Record the Godot version, the export-template status and any setting-key differences in Completion Notes.

### Review Findings

Code review (gds-code-review, unattended, diff `origin/main...HEAD`, 2026-11-06). Blind/edge/auditor layers were folded into one adversarial pass by the reviewing agent. AC1-AC3 verified against `project.godot` and the sources; AC4 verified via the dev's recorded measurements.

- [x] [Review][Patch] Render FPS uncapped (120 on a 120 Hz display) versus AC4 "frame rate is 60 FPS" and GNFR10 fixed 60 — added `application/run/max_fps=60` [game/project.godot:15]. Decision: AC4 reads as a hard 60 FPS, the cap is one line and safe (sim is tick-driven, never delta-driven); browsers still pace via rAF.
- [x] [Review][Defer] `error()` prints and also calls `push_error` (double line in the editor) [game/src/autoloads/log.gd] — skipped, intentional per DC6; revisit if a popup or noise appears.
- [x] [Review][Defer] No committed tests — skipped, GUT arrives in Story 1.2 (forbidden here); the throwaway 37-check script should be ported there.

Dismissed as noise: 3 (default-valued keys may be dropped on editor re-save; autoload order Log-before-SimClock is safe at call time; `.gd.uid` files intentionally committed).
Re-validated after the fix: `--headless --import` exit 0, `--headless --quit` exit 0 with only `[f=0][INFO][flow] boot`.

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

Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story, unattended.

### Debug Log References

All checks ran against Godot `4.7.2.stable.official.ed1daf0bf` (macOS, Apple M5 Pro, OpenGL 4.1 Metal, Compatibility).

- `godot --headless --path game --import` exit 0; global classes `Const`, `Palette` registered.
- Setting-key probe (`ProjectSettings.get_property_list()`): `audio/general/default_playback_type.web` exists, hint `Stream,Sample`, so `1` = Sample. `debug/gdscript/warnings/untyped_declaration` hint `Ignore,Warn,Error`, so `2` = Error. `default_texture_filter` `0` = Nearest.
- `godot --headless --path game --quit` exit 0, output only `[f=0][INFO][flow] boot` (Task 6.4, AC3 boot line).
- `godot --headless --editor --path game --quit`: no warning or error lines in output; `project.godot` not rewritten (Task 6.1, headless equivalent of opening the editor).
- Untyped probe: a throwaway script with `var x = 1` / `func f(a):` fails to parse with "Warning treated as error" (AC1 `untyped_declaration`). The probe was deleted.
- Verification script (SceneTree, scratchpad, not committed; GUT arrives in 1.2): 37/37 PASS. Covers every Task 1 setting, clear colour = BG, `Const` values, `tiles_per_s_to_px_per_frame(3.75) == 1.0` and `(0) == 0`, palette hex values, autoload order and presence, `Game.flow_state == TITLE`, `Log` format `[f=N][INFO][flow] boot`, `sim_frame` +60 over 60 physics ticks, `paused` freezes `sim_frame`.
- Windowed run at 1280×720 (`--resolution 1280x720`): window (1280, 720), root viewport (640, 360), root final transform scale exactly 2.0 (integer 2×). Captured 640×360 viewport: exactly two colours (`101014`, `e8e8e8`), glyph bbox (312,172)–(327,187) = 16×16 px, no filtered/blended pixels (AC4 crispness). `sim_frame` rate measured 59.92/s over wall-clock time (Task 6.3). Render FPS read 120 (see design call on FPS).
- `grep -rn "print(" game/src` returns only `src/autoloads/log.gd` (Task 6.5).

### Completion Notes List

- Created the Godot 4.7.2 project in `game/` by hand (no template) with all Task 1 settings; window 1280×720 via `window_width_override`/`window_height_override`, clear colour BG.
- Domain-first folder tree with `.gitkeep` in the 36 empty leaf folders; no `addons/gut` or `mumble_speech`.
- `Const` and `Palette` as `class_name` scripts (`extends RefCounted`). **`const INK := Color("#E8E8E8")` is accepted by Godot 4.7.2 in a `const`**: no `static var` fallback needed.
- Eight typed autoload stubs registered in order Log → SaveService. `Log` reads `SimClock.sim_frame`; `debug` gated on `Debug.enabled`; `warn` → `push_warning`; `error` → `print` + `push_error` (DC6). `SimClock` increments only when not paused (DC3).
- `main.tscn` (root `Main`, `Node2D`, `main.gd`) is the main scene; logs `boot` in `_ready` and draws an 8×8 framed-square glyph from `draw_rect` with 2×2 cells (16×16 px) in INK, centred.
- Setting-key differences: none. The web playback key is exactly `audio/general/default_playback_type.web` as the story guessed.
- Export templates: not checked or installed (out of scope; Web preset is Story 1.3). `butler` not installed (not needed here).
- [design call] No committed tests: GUT and the test layout arrive in Story 1.2, and the story forbids adding `addons/gut` here. Verification ran as a throwaway headless SceneTree script, recorded above. Recommend Story 1.2 ports these checks (settings, `Const`, `SimClock` gating, `Log` format) into GUT unit tests.
- [design call] Editor-only checks (6.1 Output panel, 6.2 run from editor, 6.3 Remote Inspector, 6.6 Monitors) were replaced by the real-binary equivalents above (headless editor open, windowed scripted run, measured `sim_frame` rate, viewport capture). Tiziano should still glance at the editor once.
- [design call] FPS: the simulation runs at exactly 60 Hz (59.92 sim frames/s measured), but render FPS follows vsync and read 120 on this 120 Hz ProMotion display. No `application/run/max_fps` cap was added, since it is not in the tasks and capping would only matter on >60 Hz displays (browsers drive rAF at display rate anyway). If AC4 is read as a hard 60 render FPS, add `application/run/max_fps=60` in a follow-up.
- [design call] Settings left explicit even where they equal engine defaults (physics 60, Nearest, web Sample). Note: if the editor later re-saves `project.godot` it may drop default-valued keys; behaviour is unchanged.
- [design call] Added the script `uid` to `main.tscn`'s `ext_resource` and committed the `*.gd.uid` files Godot 4.7 generates, so opening the editor does not churn the scene file.
- [design call] Glyph shape: a framed square with an inner square (outer ring + inner 4×4 ring), which shows uneven pixel widths or blur at any edge.

### File List

- .gitignore (unchanged: already ignores `.godot/` at any depth and build output)
- game/project.godot
- game/src/core/const.gd, game/src/core/const.gd.uid
- game/src/core/palette.gd, game/src/core/palette.gd.uid
- game/src/autoloads/log.gd, event_bus.gd, sim_clock.gd, game.gd, debug.gd, audio_manager.gd, voice_service.gd, save_service.gd (each with its `.gd.uid`)
- game/src/main/main.tscn, game/src/main/main.gd, game/src/main/main.gd.uid
- game/**/.gitkeep (36 empty leaf folders under addons/, assets/, data/, src/, tests/, tools/)
- _bmad-output/implementation-artifacts/1-1-godot-project-skeleton-with-pixel-perfect-60-hz-setup.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-06: Implemented Story 1.1: Godot 4.7.2 project skeleton, folder tree, Const/Palette, typed autoload stubs with Log and SimClock, persistent main scene with test glyph. Status → review.
- 2026-11-06: Code review: added `application/run/max_fps=60` (AC4). Status -> done.
