---
baseline_commit: 44b85d2
---

# Story 1.2: Test Framework and CI Pipeline

Status: ready-for-dev

## Story

As a developer,
I want headless unit tests and a CI pipeline from day one,
so that AI-written frame logic is verified automatically on every push (I-7).

**Requirements:** Additional: testing (AD-11, I-7), CI checks. Closes the Story 1.1 deferred item "No committed tests for Story 1.1 checks; port the throwaway verification into GUT in Story 1.2" (`_bmad-output/implementation-artifacts/deferred-work.md`).

## Acceptance Criteria

**AC1: GUT runs headless**
Given GUT 9.6.1 installed in `game/addons/gut/`,
When I run `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (after `godot --headless --path game --import`, see Dev Notes),
Then the sample/real tests in `game/tests/unit/` pass and the command exits 0 with a passing summary.
And if GUT cannot run on Godot 4.7.2, gdUnit4 6.x is installed instead and the fallback is recorded in this story's Completion Notes and in `_bmad-output/project-context.md` (Testing Rules line on GUT).

**AC2: Story 1.1 checks are committed as tests**
Given the 37-check headless verification recorded in Story 1.1's Debug Log References,
When the GUT suite runs,
Then every check category listed in Task 3 is covered by a GUT assertion in `game/tests/unit/` (settings, Const, Palette, folder tree, autoload order and presence, Game initial state, Log format, SimClock ticking and pause), each test is named for the check it replaces, and the suite passes.

**AC3: CI runs tests and export on push**
Given a push to GitHub (or a pull request),
When `.github/workflows/ci.yml` runs,
Then it installs Godot 4.7.2-stable (Linux headless), imports the project, runs the GUT suite headless, performs a Web export of the "Web" preset to `build/web/`, and fails the build on any test failure or export error.

**AC4: Failing tests fail the build with the name visible**
Given a failing test,
When CI runs,
Then the job is marked failed and the failing test name appears in the log. Because Godot 4 headless may exit 0 after failures (see Latest Tech), the job also fails on GUT failure output, not only on the exit code.

**AC5: Static guards fail the build**
Given the guard script run by CI,
When a `Timer.new` or `await` appears under `game/src/{input,register,player,combat,bosses,skills,arena}`, or a bare `print(` appears anywhere under `game/src/` except `src/autoloads/log.gd`,
Then the guard step fails and names the offending file and line.

**AC6: Web preset exists for the CI export**
Given `game/export_presets.cfg`,
When I inspect the "Web" preset,
Then Thread Support is off, Extensions Support is on, and `addons/gut/*`, `tests/*` and `tools/*` are excluded from export. The remaining preset checks (VRAM compression, GoPeak exclusion, itch.io deploy, build-size record) stay in Story 1.3.

**AC7: Failure is proven, not assumed**
Given the finished pipeline,
When I add one deliberately failing GUT test and one deliberate `Timer.new` line in a scratch copy (or temporarily, then revert),
Then the GUT run reports the failing test name and the guard script exits non-zero. Both probes are reverted before commit and the outcome is recorded in Completion Notes.

## Tasks / Subtasks

- [ ] Task 1: Install and prove GUT (AC: 1)
  - [ ] 1.1 Vendor GUT 9.6.1 into `game/addons/gut/` (download the 9.6.1 release from `github.com/bitwes/Gut`, copy its `addons/gut/` folder; keep its LICENSE file). Commit it as plain files, not a submodule (DC1).
  - [ ] 1.2 Run `godot --headless --path game --import` (Godot 4.7.2 at `/Applications/Godot.app/Contents/MacOS/Godot` on the dev machine, as in Story 1.1). Confirm GUT's own scripts parse under `untyped_declaration = Error` (see Risk below).
  - [ ] 1.3 Run the AC1 command with a trivial `tests/unit/test_smoke_gut.gd` first. If GUT does not parse or run on 4.7.2, stop and apply the gdUnit4 fallback (DC2); do not patch GUT's source to suppress warnings.
  - [ ] 1.4 Confirm the exit-code behaviour and the failure output format with a temporary failing assertion (feeds AC4, AC7). Record the exact summary string GUT prints on failure, for the CI grep in Task 5.
  - [ ] 1.5 Delete the smoke test once the real tests exist (Task 3).
- [ ] Task 2: Vendor and hook the test layout (AC: 1)
  - [ ] 2.1 `tests/unit/`, `tests/integration/`, `tests/replays/` already exist (`.gitkeep`). Real test files go in `tests/unit/` for this story; `tests/integration/` and `tests/replays/` stay empty (their `.gitkeep` remain).
  - [ ] 2.2 Test files: `tests/unit/test_<subject>.gd`, `extends GutTest`, every variable and parameter typed (the project's `untyped_declaration = Error` applies to tests too).
- [ ] Task 3: Port the Story 1.1 verification to GUT (AC: 2). One test file per group, each test named for the check it replaces:
  - [ ] 3.1 `tests/unit/test_project_settings.gd`: read `ProjectSettings` values and assert: renderer `gl_compatibility`; viewport 640×360; window override 1280×720; stretch `viewport`, aspect `keep`, scale_mode `integer`; `rendering/textures/canvas_textures/default_texture_filter` == 0 (Nearest); `physics/common/physics_ticks_per_second` == 60; `audio/general/default_playback_type.web` == 1 (Sample); `debug/gdscript/warnings/untyped_declaration` == 2 (Error); `application/run/max_fps` == 60 (added in 1.1 review); `application/run/main_scene` == `res://src/main/main.tscn`; clear colour equals `Palette.BG` (`ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")`).
  - [ ] 3.2 `tests/unit/test_const_palette.gd`: `Const.TILE_PX == 16`, `SIM_HZ == 60`, `BASE_RES == Vector2i(640, 360)`, `ARENA_TILES == Vector2i(32, 18)`; `tiles_per_s_to_px_per_frame(3.75) == 1.0` and `(0.0) == 0.0`; `Palette.INK == Color("#E8E8E8")`, `BG == Color("#101014")`, `WARN == Color("#FF4040")`.
  - [ ] 3.3 `tests/unit/test_folder_tree.gd`: assert `res://` folders from AC2 of Story 1.1 exist (`src/core`, `src/autoloads`, `src/main`, `data/*`, `assets/fonts`, `assets/audio/{music,sfx}`, `assets/shaders`, `tests/{unit,integration,replays}`, `tools`, `addons`).
  - [ ] 3.4 `tests/unit/test_autoloads.gd`: parse the raw `res://project.godot` `[autoload]` section in file order (DC4). Assert the eight names in order `Log, EventBus, SimClock, Game, Debug, AudioManager, VoiceService, SaveService` (`Log` first). Assert presence at runtime: each name is a child of the root node (`(Engine.get_main_loop() as SceneTree).root.has_node(name)`), which is how autoloads are mounted.
  - [ ] 3.5 `tests/unit/test_game_state.gd`: `Game.flow_state == Game.FlowState.TITLE` on a fresh `Game.new()` (avoid asserting the live autoload's state if it has been changed by an earlier test).
  - [ ] 3.6 `tests/unit/test_log.gd`: format check `[f=N][INFO][flow] boot` via the format helper (DC5); `WARN` and `ERROR` lines use the same shape; `debug` output is suppressed when `Debug.enabled` is false (assert via the helper, not via stdout).
  - [ ] 3.7 `tests/unit/test_sim_clock.gd`: `SimClock.new()` (not added to the tree, DC6). Assert: `sim_frame == 0` initially; calling `_physics_process(0.0)` 60 times yields `sim_frame == 60`; with `paused = true`, 60 calls leave `sim_frame` unchanged; resuming increments again; `delta` values do not change the increment (call with `0.5` and `0.0`). Free the instance after each test.
  - [ ] 3.8 Record the final assertion count and the mapping (check → test name) in Completion Notes. The throwaway 37-check script was in the scratchpad and is not in the repo; re-derive it from the Story 1.1 Debug Log References list. The count does not need to equal 37 (AC2 is about coverage).
- [ ] Task 4: Minimal Web preset for CI (AC: 6). Create `game/export_presets.cfg` with one preset `Web`: `export_path="../build/web/index.html"`, Thread Support off, Extensions Support on (non-threaded dlink template), `exclude_filter="addons/gut/*, tests/*, tools/*"`. Leave VRAM compression, GoPeak and itch.io settings to 1.3 (DC9).
- [ ] Task 5: Static guard script (AC: 5). Create `game/tools/check_guards.sh` (executable). It runs from the repo root and exits 1 with `file:line: message` output on any violation:
  - `grep -rnE --include=*.gd '\bTimer\.new\b|\bawait\b' game/src/{input,register,player,combat,bosses,skills,arena}` → violation.
  - `grep -rnE --include=*.gd '\bprint\(' game/src` excluding `game/src/autoloads/log.gd` → violation.
  - Extras (DC10): `create_tween` and `Engine\.time_scale` under the same sim folders.
  - Use `grep` with `|| true` pattern only for the exit logic; do not pipe through `head` (it hides the exit code).
  - Exclude comment-only matches if they appear; if a comment needs `await`, reword the comment, do not special-case the regex.
- [ ] Task 6: GitHub Actions workflow `.github/workflows/ci.yml` (AC: 3, 4). Trigger `push` and `pull_request`. Single job on `ubuntu-latest`:
  1. Checkout.
  2. Download Godot 4.7.2-stable Linux headless binary and the matching export templates `Godot_v4.7.2-stable_export_templates.tpz` from the official `godotengine/godot` 4.7.2-stable release; cache under `~/.local/share/godot` and `~/.local/share/godot/export_templates/4.7.2.stable` (DC8). Verify both file names exist on the release page before pinning.
  3. `godot --headless --path game --import` (class_name cache is gitignored, so this is required on a clean checkout).
  4. GUT: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee gut.log`, then fail the step if the shell exit code is non-zero **or** `gut.log` contains a failure marker (DC7). The markers must be the exact GUT failure strings found in Task 1.4 plus `SCRIPT ERROR` and `Parse Error`.
  5. Guards: `bash game/tools/check_guards.sh`.
  6. Web export: `mkdir -p build/web && godot --headless --path game --export-release "Web" ../build/web/index.html`; fail on non-zero exit; also fail if `build/web/index.html` is missing.
- [ ] Task 7: Verify and record (AC: 1–7)
  - [ ] 7.1 Run the exact GUT command, the guard script and the Web export locally; all must pass on a clean working tree with `.godot/` removed first.
  - [ ] 7.2 Run the AC4/AC7 failing probe: add one failing assertion, run GUT, confirm the failing test name and the failure marker appear and the step would fail. Revert.
  - [ ] 7.3 Run the AC5 probe: add `Timer.new()` to a throwaway `game/src/register/_probe.gd`, run `check_guards.sh`, confirm non-zero exit and file:line output. Delete the probe file.
  - [ ] 7.4 Confirm `git status` shows only the intended files: `game/addons/gut/`, `game/tests/unit/`, `game/tools/check_guards.sh`, `game/export_presets.cfg`, `.github/workflows/ci.yml`, and the `.gd.uid` files. No `.godot/`, no `build/`, no probe files.
  - [ ] 7.5 Record in Completion Notes: Godot and GUT versions, the GUT failure marker strings, the exported `build/web` size (informational, Story 1.3 records the official number), and whether CI was run on GitHub (see Dev Notes: the CI proof on GitHub happens when the branch is pushed as a PR).

## Dev Notes

### Scope boundaries

- In scope: GUT addon vendored and running, unit tests porting Story 1.1 checks, guard script, minimal Web preset, GitHub Actions workflow with GUT + guards + Web export.
- Out of scope: itch.io deploy with `butler`, full Web preset verification, browser smoke tests, build-size record, audio/voice smoke tests (all Story 1.3); title screen (1.4); any gameplay code; `tests/integration/` and `tests/replays/` content (empty until Story 2.1); `data/**/*.tres` validation test (Story 2.2 owns `test_data_validation.gd`); `InputSource`, `Register` and other simulation code.
- Do not touch `_bmad/`, `.claude/` (symlinks, gitignored). Do not commit anything under `_bmad-output/` from this story run; the dev-story run commits the code.
- Do not add `mumble_speech` or GoPeak to `game/addons/` (Story 1.3 and the AI tooling setup).

### Current repo state (verified 2026-11-06, HEAD 44b85d2)

- `game/addons/` contains only `.gitkeep`. `game/tests/{unit,integration,replays}/` contain only `.gitkeep`. `game/tools/` contains only `.gitkeep`. There is no `game/export_presets.cfg` and no `.github/` folder.
- Root `.gitignore` already ignores `.godot/` (any depth), `build/`, `dist/`, `*.zip`, `export*.cfg` (note: `export_presets.cfg` is NOT ignored; `export_credentials.cfg` and `export.cfg` are). Do not add `export_presets.cfg` to `.gitignore`; it must be committed (the CI export needs it).
- Existing autoload scripts: `game/src/autoloads/{log,event_bus,sim_clock,game,debug,audio_manager,voice_service,save_service}.gd`, each with `.gd.uid`. `log.gd` is the only file that calls `print(` (the guard exempts it).
- `game/src/core/const.gd` (`class_name Const`) and `game/src/core/palette.gd` (`class_name Palette`) use `const` `Color("#...")` values (accepted by 4.7.2, per 1.1 Completion Notes).
- `game/project.godot` has `run/max_fps=60`, `physics_ticks_per_second=60`, `default_texture_filter=0`, `default_playback_type.web=1`, `untyped_declaration=2`, autoloads in order Log → SaveService, `main_scene` = `res://src/main/main.tscn`.

### Architecture requirements that bind this story

- **AD-11 Testing:** GUT for unit tests of sim logic, run headless from CLI. Fallback gdUnit4 6.x. [Source: _bmad-output/game-architecture.md#Architectural Decisions, AD-11]
- **Test layout:** `tests/unit/` (register, combo table, `ActionResolver`, `DamageCalc`, input buffer, boss controller, data validation), `tests/integration/` (fight flow, retry snapshot), `tests/replays/` (recorded input + replay test). Naming `tests/<kind>/test_<subject>.gd`. [Source: _bmad-output/game-architecture.md#Project Structure; _bmad-output/project-context.md#Testing Rules]
- **Simulation runs without a scene tree or renderer** in tests. Build systems from defs plus a `SimContext`. [Source: _bmad-output/project-context.md#Testing Rules]
- **CI checks:** grep for `Timer.new`/`await` under simulation folders and bare `print`; enforcement table rows "Time" and "Damage" name these as CI/test checks. [Source: _bmad-output/game-architecture.md (enforcement table, Time rule); _bmad-output/planning-artifacts/epics.md#Story 1.2]
- **Export:** Web preset with Thread Support off, Extensions Support on; export excludes `addons/gut`, `tests/`, `tools/`, GoPeak runtime. [Source: _bmad-output/project-context.md#Platform & Build Rules]
- **Logging:** tests assert the format helper; no test relies on stdout capture. Only `Log` may print.
- Godot 4.7.2-stable pinned; do not upgrade. GDScript only.

### Commands (copy exactly)

```bash
# one-time (and after any addon/class change): build the class_name cache
godot --headless --path game --import

# unit tests (AC1): non-zero exit OR failure marker in output = fail
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# static guards (AC5)
bash game/tools/check_guards.sh

# web export (AC3, AC6)
mkdir -p build/web && godot --headless --path game --export-release "Web" ../build/web/index.html
```

Godot binary on macOS: `/Applications/Godot.app/Contents/MacOS/Godot` (use it in place of `godot` if `godot` is not on PATH). The repo's export path is relative to `game/` (`../build/web/index.html`).

### Latest Tech (web research, 2026-11-06)

- **GUT command line:** GUT's documented CLI is `gut_cmdln.gd` with `-gdir` and `-gexit`. The `-ginclude_subdirs` flag name is from memory of GUT's options; **verify with `-gh` or the addon's `gut_cmdln.gd` source before pinning CI**. If it differs, use the GUT config-file alternative (`.gutconfig.json` with `include_subdirs`) and record the choice.
- **Exit codes are not trustworthy alone:** a Godot forum report (measured on Godot 4.7.2 and 4.4.1) found that headless runs can exit 0 despite failed tests and script errors. CI must therefore also grep the log (AC4). [Source: https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990]
- **GUT docs:** https://gut.readthedocs.io/en/latest/Command-Line.html
- Do not use a community Docker image for Godot in CI; download the official 4.7.2-stable binary and templates (DC8).

### Risk: `untyped_declaration = Error` and third-party code

The project setting makes untyped declarations a parse error in every compiled script, including `addons/gut/`. If GUT 9.6.1 contains untyped declarations, GUT will fail to load. Task 1.2/1.3 must check this first. Allowed responses, in order: (1) GUT 9.6.1 runs as is → proceed; (2) it fails → switch to gdUnit4 6.x per AC1 and DC2; (3) do NOT edit vendored GUT sources and do NOT lower the project-wide warning level (that would break AC1 of Story 1.1). Record the outcome.

### Design Calls

Made unattended during story creation. Each is a recommendation the designer can overrule.

- **DC1 Vendoring GUT:** commit GUT 9.6.1's `addons/gut/` as plain files (not a submodule), keep its LICENSE. Reason: CI needs it on a clean checkout with no network-dependent step, and the project pins versions for the whole jam.
- **DC2 Fallback:** attempt GUT 9.6.1 first; fall back to gdUnit4 6.x only if GUT does not run on 4.7.2 (Task 1.3). Record in Completion Notes and `project-context.md`.
- **DC3 Test granularity:** one test file per topic (settings, const/palette, folder tree, autoloads, game state, log, sim clock) rather than one big file. Reason: `tests/unit/test_<subject>.gd` convention; each failure names its subject.
- **DC4 Autoload order:** read `res://project.godot` raw text in file order. Reason: `ConfigFile`/`ProjectSettings` key order is not a stable contract for order checks. Note the test reads the file, which is fine in headless runs (`res://` is readable).
- **DC5 Log format test:** assert through the format helper (`Log._format`) with a known `SimClock.sim_frame`, instead of capturing stdout. Reason: GUT stdout capture is not reliable across Godot builds, and `print` output is not a contract. If `_format` is private-by-convention and the dev prefers, add a `static func format_line(level, tag, msg, frame)` in `log.gd` and call that; this is a small, allowed refactor that does not change output.
- **DC6 SimClock tests:** instantiate `SimClock.new()` and call `_physics_process(delta)` directly; do not add to the tree and do not depend on the real physics loop. Reason: determinism and project rule "simulation runs without a scene tree". The live autoload still gets its 60 Hz check from the real run (Story 1.1 verification).
- **DC7 Failure detection:** CI fails on non-zero exit AND on failure markers in the log (`SCRIPT ERROR`, `Parse Error`, and GUT's failure summary/line). Reason: Godot 4 headless may exit 0 (see Latest Tech).
- **DC8 CI runner:** `ubuntu-latest`, official Godot 4.7.2-stable Linux headless binary and export templates from the GitHub release, cached. Reason: version pinned per project rule; no third-party image.
- **DC9 Web preset scope:** create the minimal "Web" preset here because the AC requires a Web export in CI; Story 1.3 owns the rest of the preset (VRAM compression, GoPeak exclusion), the itch.io deploy, browser smoke tests and the size record. Reason: the epic's AC3 requires a Web export in this story's CI, which cannot exist without a preset.
- **DC10 Extra guard patterns:** `create_tween` and `Engine.time_scale` under the simulation folders are checked in addition to `Timer.new`/`await`. Reason: both are banned by the project rules (project-context Engine-Specific Rules); the cost is zero.
- **DC11 Guard script location:** `game/tools/check_guards.sh` (not in `.github/`). Reason: developers run it locally; `tools/` is excluded from export. Note: this is a `.sh` in the Godot project folder and must be committed with the executable bit.
- **DC12 No stdout capture, no integration/replay tests yet:** `tests/integration/` and `tests/replays/` stay empty; their first real content is Story 2.1 and 2.x. Reason: the story AC lists only unit-level checks; empty dirs keep the `-gdir` run simple.
- **DC13 Story 1.1 check count:** the original 37 checks were in a scratchpad script not committed to the repo. This story ports each check category, not the exact count (AC2 is coverage-based). Record the final count.
- **DC14 CI proof:** the local probes (Task 7.2, 7.3) prove the failure paths; the GitHub Actions run is proven when the branch is pushed as a PR (main is protected; PR-only workflow). Do not merge from this story run.

### Previous story intelligence (Story 1.1, done)

- Godot binary used: `4.7.2.stable.official.ed1daf0bf`. Headless commands used: `--import`, `--quit`, `--editor --quit`. Keep the same CLI style.
- Autoload order, typed stubs and `Log` format are implemented and reviewed. Do not change their behaviour in this story; tests only assert them. The only allowed source change to sim code is DC5's optional `format_line` helper (if chosen) and nothing else.
- Review (2026-11-06) added `application/run/max_fps=60`. Test it (Task 3.1).
- Setting keys verified: `audio/general/default_playback_type.web` = 1 (Sample); `debug/gdscript/warnings/untyped_declaration` = 2 (Error); `default_texture_filter` = 0 (Nearest).
- `.gd.uid` files are committed by design. New GUT and test `.gd` files will produce `.gd.uid` files too: commit them with the scripts.
- Deferred from 1.1 (`deferred-work.md`): (a) `Log.error` double-prints in the editor, intentional, skip; (b) no committed tests, port the throwaway verification here — done by Task 3.
- Story 1.1's Completion Notes flagged that editor-only checks were replaced by headless equivalents; the GUT suite is the permanent version of those headless checks.

### Git intelligence

- Recent commits show the 1.1 pattern: `chore(game)` for folders, `feat(game)` for code, `docs(story)` for story files. Use `feat(game)`/`chore(ci)` for code and `docs(story)` for `_bmad-output` changes.
- Only `_bmad-output/` and `game/` are touched by this project so far; `.github/` is new in this story.

### Project Structure Notes

- Godot root is `game/` (`res://` = `game/`). The workflow file lives in the repo root `.github/workflows/ci.yml`, not under `game/`. The guard script lives in `game/tools/`.
- Test file names: `snake_case`; class names: none needed for test files (GUT uses `extends GutTest`).
- Default-valued settings in `project.godot` must remain explicit (1.1 decision); do not re-save the file with the editor in a way that drops them, or re-check Task 3.1 after any editor save.

### Project Context Rules

Populated from `_bmad-output/project-context.md` (Testing Rules, Engine-Specific Rules, Platform & Build Rules):

- GUT 9.6.1 for tests (fallback gdUnit4 6.x if GUT fails on 4.7.2). Record any fallback in `project-context.md`.
- Command: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (this story adds `-ginclude_subdirs`, see DC and Latest Tech).
- Tests: `tests/unit/test_<subject>.gd`; simulation tests run without a scene tree; use the GDD worked numbers when they exist (none apply to this story's checks).
- Logging: `Log` only; no bare `print`; guard enforces it.
- Static typing everywhere, including test files (`untyped_declaration = Error`).
- No `Timer`, `await`, `create_tween`, `Engine.time_scale`, `delta` in simulation folders; guard enforces it.
- Export excludes `addons/gut`, `tests/`, `tools/`.
- Godot 4.7.2-stable pinned; GDScript only.

### References

- Story 1.2 ACs and CI scope: [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2]
- Epic 1 DoD (GUT and CI green every epic): [Source: _bmad-output/planning-artifacts/epics.md#Epic List; _bmad-output/implementation-artifacts/sprint-status.yaml header]
- AD-11 testing and I-7 GUT verification: [Source: _bmad-output/game-architecture.md#Architectural Decisions (AD-11); I-7 row of the risk table]
- Test layout and run command: [Source: _bmad-output/game-architecture.md#Project Structure; #Development Environment]
- Testing and platform rules: [Source: _bmad-output/project-context.md#Testing Rules; #Platform & Build Rules]
- 1.1 verification and deferred test port: [Source: _bmad-output/implementation-artifacts/1-1-godot-project-skeleton-with-pixel-perfect-60-hz-setup.md#Dev Agent Record; _bmad-output/implementation-artifacts/deferred-work.md]
- GUT CLI: https://gut.readthedocs.io/en/latest/Command-Line.html
- Godot exit-code caveat: https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990

## Dev Agent Record

### Agent Model Used

{{to be filled by dev-story}}

### Debug Log References

### Completion Notes List

- [design call] Story created unattended by gds-create-story. Design calls DC1–DC14 above; each is overrulable before dev-story.

### File List

- _bmad-output/implementation-artifacts/1-2-test-framework-and-ci-pipeline.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
