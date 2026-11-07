---
baseline_commit: edf44bb
---

# Story 1.3: Web Export and itch.io Draft Deploy

Status: done

## Story

As a developer,
I want a working web build on an itch.io draft page from day one,
so that web pitfalls surface immediately and every epic can end with a deploy.

**Requirements:** NFR4, NFR7, NFR16; Additional: web preset, day-1 smoke tests (AD-09 panning, I-6 mumble-speech web check, I-7 GUT already in 1.2).

**Split of work (read first):** this story has two owners.
- **[DEV]** Everything the dev agent can implement and verify without credentials: the Web preset, a release export and size record, a gated deploy job and README section, a local served build with file-level smoke checks, the audio panning smoke scene, and the mumble-speech release check.
- **[HUMAN]** Tiziano only: create the itch.io draft page, add the `BUTLER_API_KEY` secret and the `ITCH_TARGET` variable, run the first deploy, and do the real-browser smoke tests (Chrome, Firefox, Safari) with audio.

**The dev agent must never perform an outward-facing deploy.** It must not run `butler`, must not trigger the deploy job (no `gh workflow run`, no push), must not touch any itch.io account, and must not create or write any secret or variable.

## Acceptance Criteria

### [DEV] Web preset

**AC1: Web preset matches the requirements**
Given the "Web" export preset in `game/export_presets.cfg`,
When I inspect it,
Then Thread Support is off (`variant/thread_support=false`), Extensions Support is on (`variant/extensions_support=true`), VRAM compression is desktop-only (`vram_texture_compression/for_desktop=true`, `for_mobile=false`), and `addons/gut`, `tests/`, `tools/` and the GoPeak runtime addon are excluded by `exclude_filter`.
And these keys are explicit in the committed file (not left to Godot defaults). This closes the Story 1.2 deferred item "Explicit VRAM keys in export_presets.cfg (Story 1.3 owns)".
And a GUT test in `game/tests/unit/` parses `res://export_presets.cfg` and asserts the keys above, so a later editor re-save cannot silently drop them.

### [DEV] Release export and size record

**AC2: Release Web export and size measured against NFR4**
Given a release Web export (`--export-release "Web"`),
When I measure `build/web/`,
Then the total uncompressed size in bytes is recorded in this story's Dev Agent Record (Completion Notes, "Size record" table: file, bytes, total).
And the budget is **≤ 30 000 000 bytes** (NFR4, see design call DC4).
And if the total is over budget, the dev records the exact number and runs the reduction path in Task 3 (stripped template). If the budget is still not met at the end of the dev run, the story stays in `review` with the AC open and an explicit waiver request for Tiziano in the Completion Notes. The story cannot move to `done` over budget without his written waiver.

**AC3: No thread or cross-origin-isolation requirement**
Given the exported `build/web/index.html`,
When I inspect it,
Then it sets `GODOT_THREADS_ENABLED = false` and the build needs no SharedArrayBuffer, COOP or COEP headers (the itch.io "SharedArrayBuffer support" option stays off, see [HUMAN] AC8h).

### [DEV] Deploy path (written, gated, never run)

**AC4: Deploy job exists and is gated on the secret and the target**
Given `.github/workflows/ci.yml`,
When I read it,
Then a job `deploy-itch-draft` exists that:
- runs only on `workflow_dispatch` and only when `github.ref == 'refs/heads/main'` (no push or pull_request trigger can deploy);
- depends on the export job and downloads the `build/web` artifact it uploads;
- installs `butler` from its official distribution, logs `butler version`, and runs `butler push build/web "$ITCH_TARGET:html5"` with a `--userversion` (commit SHA);
- is skipped (exit 0, with a visible notice) when `BUTLER_API_KEY` or `ITCH_TARGET` is empty. The secret never appears in a command line or in a log.

**AC5: CI reports the build size without failing on it**
Given the export job,
When it finishes,
Then it prints the `build/web` total in bytes and emits `::warning::` when the total exceeds 30 000 000 bytes. It does not fail the build on size until the stripped-template work (Task 3) lands (design call DC4).

**AC6: README documents the deploy command**
Given `README.md`,
When I read it,
Then a short "Deploying a draft build (itch.io)" section gives the `butler push` command, names the `BUTLER_API_KEY` secret and `ITCH_TARGET` variable, states that the deploy is manual (`workflow_dispatch` on `main`), and contains no key or account secret.

### [DEV] Local build served and smoke-checked

**AC7: Local web build is served and passes file-level smoke checks**
Given a release export in `build/web/`,
When I run `game/tools/smoke_web.sh` (new; see Task 4),
Then it serves `build/web` on a local port and checks with HTTP requests that `index.html`, `index.js`, `index.wasm`, `index.side.wasm`, `index.pck` return 200 with a sane content type, and that `index.html` has `GODOT_THREADS_ENABLED = false` and no COOP/COEP requirement.
And it prints the size total and exits 0 only when every check passes.
And if a headless Chrome binary is available, the script also loads the page and records any console error or WASM load failure. If no browser is available, the script says so and the browser check is left to [HUMAN] AC10h.

### [DEV] Audio panning smoke scene

**AC8: Positional audio smoke scene is built and reachable in a release web build**
Given a release web build,
When the URL contains `?debug&smoke=audio`,
Then a scene opens with one `AudioStreamPlayer2D` playing a generated tone, which waits for the first click, then is panned left and right (about 2 s each, the on-screen label shows "L" or "R" in sync) and then loops.
And without `?debug` the smoke scene is never opened (verified by reading the `main.gd` branch and recorded in Completion Notes).
And the smoke scene does not add any `await` or `Timer` to a simulation folder (it lives in `game/src/debug/`).

**AC9: mumble-speech web check (I-6) is resolved on the dev side**
Given the mumble-speech releases (basteez/mumble-speech),
When the dev checks them (Task 6),
Then the Completion Notes record: the latest release tag, whether its Godot zip contains web binaries (inspect with `unzip -l`, do not extract into `game/`), and whether issue #32 is closed.
And if no release including web support for `MumbleSpeaker` exists, the Completion Notes say "I-6: not yet, moved to Story 3.7" and the addon is NOT added to `game/addons/` in this story.
Checked at story creation (2026-11-06, `gh`): issue basteez/mumble-speech#32 is OPEN; latest release is v0.2.0 (2026-11-05) with `mumble-speech-godot-0.2.0.zip`. The dev must still confirm whether that zip has web binaries.

### [HUMAN] itch.io draft and first deploy (Tiziano)

**AC8h: itch.io draft page exists (Tiziano)**
Given an itch.io account, Tiziano creates the project page as a draft (visibility Draft or Restricted, not public), kind "HTML", and the embed settings from the epic: viewport **1280×720**, **fullscreen button enabled**, "SharedArrayBuffer support" **off**, "This file will be played in the browser" set.

**AC9h: Secrets and variables are set (Tiziano)**
Given the repo `basteez/the-debugger-0x3-wild-shift`, Tiziano adds the GitHub Actions secret `BUTLER_API_KEY` (created in the itch.io account settings, API keys) and the repository variable `ITCH_TARGET` = `<itch-user>/<itch-game-slug>` (variable, not secret; the dev never writes either).

**AC10h: First deploy and browser smoke test (Tiziano)**
Given a release build from `main`, Tiziano runs the `deploy-itch-draft` job (Actions, workflow_dispatch on `main`) or runs `butler push build/web <user>/<slug>:html5` himself, then records in this story's Completion Notes, per browser (Chrome, Firefox, Safari latest):
- the main scene (glyph) loads; no console errors;
- the audio pan test result (left and right audible, or "fails" with the note that Null Pointer's hum will use `playback_type = Stream`, AD-09);
- the mumble-speech line result if a web-capable release exists (I-6), otherwise "moved to 3.7";
- the build size as shown on itch.io, and the itch.io page embed viewport and fullscreen behaviour.

## Tasks / Subtasks

### [DEV] tasks

- [x] **Task 1: Web preset (AC: 1)**
  - [x] 1.1 Edit `game/export_presets.cfg`: keep `thread_support=false`, `extensions_support=true`, `vram_texture_compression/for_desktop=true`, `for_mobile=false`. Add the GoPeak runtime addon patterns to `exclude_filter` (see Dev Notes "GoPeak"): keep `addons/gut/*, tests/*, tools/*` and append the runtime addon folder names (verify them in the GoPeak README before pinning; patterns that match nothing are harmless).
  - [x] 1.2 Add `game/tests/unit/test_export_preset.gd` (`extends GutTest`, statically typed, no `Timer`/`await`): load `res://export_presets.cfg` with `ConfigFile`, assert the keys above and that `exclude_filter` contains `addons/gut`, `tests`, `tools`. Name tests `test_thread_support_off`, `test_extensions_support_on`, `test_vram_desktop_only`, `test_exclude_filter_has_gut_tests_tools`. Keep `.gd.uid` with the script.
  - [x] 1.3 Run the GUT suite (Dev Notes "Commands") and confirm the count goes from 34 to 38 (plus any tests added in Task 4).

- [x] **Task 2: Release export and size record (AC: 2, 3)**
  - [x] 2.1 `mkdir -p build/web && /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --export-release "Web" ../build/web/index.html` (exit 0, no `SCRIPT ERROR`).
  - [x] 2.2 Measure: list every file in `build/web` with bytes and total (command in Dev Notes). Record the table in Completion Notes under "Size record".
  - [x] 2.3 Confirm `GODOT_THREADS_ENABLED = false` in `build/web/index.html`; confirm `index.pck` contains no `addons/gut`, `tests`, `tools` (1.2 already checked; re-check after the preset change).

- [x] **Task 3: Size reduction path (AC: 2) — only if total > 30 000 000 bytes**
  - [x] 3.1 The 1.2 local measurement was ~46 MB (`index.side.wasm` 44 MB, `index.wasm` 1.5 MB, `index.js` 2.9 MB, `index.pck` 8.9 KB). Assume this is still over budget and confirm with Task 2.
  - [x] 3.2 Preset-level options do not shrink the engine binary. The next step is a stripped **custom export template** (architecture: "Stripped custom export template only if > 30 MB"): build Godot 4.7.2-stable web templates from source with the Godot SCons web build, `target=template_release`, `dlink_enabled=yes` (required for Extensions Support), and modules/features disabled that the game does not use (3D, advanced GUI, unused text/physics/navigation modules). Record each flag and the resulting size. Point the local export at it with `custom_template/release` in the preset only if it is built and verified; do not commit a template binary into the repo.
  - [x] 3.3 If the stripped build cannot be produced and verified in this run, stop: keep the default template, keep AC2 open, and write the waiver request for Tiziano in Completion Notes (see DC4).

- [x] **Task 4: Local smoke script and GUT guard (AC: 7)**
  - [x] 4.1 Add `game/tools/smoke_web.sh` (bash, `set -euo pipefail`, run from repo root): (a) requires `build/web/index.html`; (b) starts `python3 -m http.server 8060 --directory build/web` in the background, waits for it, kills it on exit (`trap`); (c) `curl -fsI` each required file and check the HTTP status and `Content-Type` for `.wasm` (`application/wasm`) and `.pck`; (d) grep `index.html` for `GODOT_THREADS_ENABLED = false`; (e) print the byte total with `find build/web -type f -exec wc -c {} + | tail -1`; (f) if `command -v` finds Google Chrome (`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` on macOS), run it headless once against `http://localhost:8060/` with `--enable-logging=stderr --v=0 --virtual-time-budget=20000 --dump-dom` and fail on `CONSOLE(...) ... ERROR` or `wasm` load errors; otherwise print "browser check skipped: no browser found". Do not install anything.
  - [x] 4.2 Run `bash game/tools/smoke_web.sh` locally; record its output in Completion Notes.
  - [x] 4.3 No guard change is expected; the new smoke scene and tests must pass the existing guards (`bash game/tools/check_guards.sh`).

- [x] **Task 5: Audio panning smoke scene (AC: 8)**
  - [x] 5.1 Add `game/src/debug/smoke_audio/smoke_audio.tscn` and `smoke_audio.gd` (`extends Node2D`, typed). On the first click (`_unhandled_input` with `InputEventMouseButton` pressed, or any `InputEventKey`), create a generated tone `AudioStreamWAV` (16-bit mono, 440 Hz sine, 1.0 s, loop mode forward) and start an `AudioStreamPlayer2D` on the `SFX` bus (create the bus only if `AudioManager` does not already own it; do not change the bus layout).
  - [x] 5.2 Pan sequence: `position = Vector2(-300, 0)` for 2 s with label "L", then `Vector2(300, 0)` for 2 s with label "R", loop. Use `Timer`-free timing in presentation code only (`await get_tree().create_timer(2.0).timeout` is allowed here because the folder is presentation/debug, not simulation). Note: the guard script's `create_timer` check only covers sim folders.
  - [x] 5.3 Hook: `game/src/main/main.gd` `_ready()` reads the URL on web only: `if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("debug") and str(JavaScriptBridge.eval("location.search")).contains("smoke=audio")` then instance and show the smoke scene instead of the glyph. Non-web builds and URLs without both parameters are unchanged. Wrap the JavaScriptBridge call so a failure does nothing (no error shown).
  - [x] 5.4 Verify locally in the editor: the scene runs, the click starts playback, the label switches (dev can run it from the editor or via `godot --headless --path game --quit` for parse only; full audio is human).

- [x] **Task 6: mumble-speech I-6 check (AC: 9)**
  - [x] 6.1 `gh issue view 32 -R basteez/mumble-speech --json state,title,closedAt` and `gh release list -R basteez/mumble-speech --limit 5`.
  - [x] 6.2 For the newest release that has a Godot asset: `gh release download <tag> -R basteez/mumble-speech -p '*godot*.zip' -D "$SCRATCH"` where `$SCRATCH` is a new empty directory under the session scratchpad, then `unzip -l` (listing only, do not extract into `game/`). Check for web (`.wasm`/`web` directory) binaries.
  - [x] 6.3 Record the findings. Do not add `game/addons/mumble_speech/` in this story (Story 3.7 owns it; DC7).

- [x] **Task 7: Deploy job and README (AC: 4, 5, 6)**
  - [x] 7.1 In `.github/workflows/ci.yml`, in the `test-and-export` job, upload `build/web` as an artifact (`actions/upload-artifact`, `retention-days: 3`) as a step after the export, so it runs only after a successful export. Also add the size step from AC5 (prints bytes, `::warning::` over 30 000 000).
  - [x] 7.2 Add `deploy-itch-draft`: `needs: test-and-export`, `if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'`, `timeout-minutes: 10`, `permissions: contents: read`. Put `BUTLER_API_KEY` and `ITCH_TARGET` in a job-level `env:` (from `secrets.` and `vars.`) so the step-level `if` can test them; a first step emits `skip=true` when either is empty and prints a notice; later steps use `if: steps.gate.outputs.skip != 'true'`.
  - [x] 7.3 Install butler from the official itch.io distribution (`https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default`, zip, unzip to `$HOME/.local/bin`). The URL is a Dev Notes item to verify at implementation time; record the exact URL and `butler version` output in Completion Notes. Never run butler locally.
  - [x] 7.4 Push: `butler push build/web "$ITCH_TARGET:html5" --userversion "${GITHUB_SHA}"` (confirm flags against `butler push --help` once installed in CI; record that the flag set was taken from the help text, not from memory).
  - [x] 7.5 Validate the workflow YAML parses (`python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/ci.yml"))'`) and, if `actionlint` is installed, run it. Do not run the workflow.
  - [x] 7.6 Add the README section (AC6). Do not touch the README header, status line or deadline text (see Open Questions for the deadline mismatch).

- [x] **Task 8: Verify and record (all ACs)**
  - [x] 8.1 Run the full local chain: GUT suite, `bash game/tools/check_guards.sh`, release export, size measurement, `bash game/tools/smoke_web.sh`. All must exit 0 (size: over budget is expected to be reported, not failed by the script).
  - [x] 8.2 Record every command's exit code and key output in Dev Agent Record → Debug Log References.
  - [x] 8.3 Confirm no `gh workflow run`, no butler run, no secrets (the branch push was allowed by the coordinator, so "nothing pushed" does not hold), no `gh workflow run`, no butler invocation, and `_bmad` and `.claude` were not staged (`git status`).

### [HUMAN] tasks (Tiziano; the dev only leaves the checklist)

- [ ] **H1: Create the itch.io draft page (AC: 8h).** Use the Dev Notes "itch.io settings checklist".
- [ ] **H2: Add `BUTLER_API_KEY` (secret) and `ITCH_TARGET` (variable) in GitHub (AC: 9h).**
- [ ] **H3: Run the first deploy from `main` via Actions → CI → Run workflow, or locally with `butler push` (AC: 10h).** Local `butler` is not installed; install it first if running locally.
- [ ] **H4: Browser smoke in Chrome, Firefox and Safari (latest), recorded in Completion Notes (AC: 10h).** Include the audio pan result and the build size from itch.io.

## Dev Notes

### Scope boundaries

- In scope: the Web preset and its test; release export and size record; size reduction path only if over budget (Task 3); deploy job and README section, both unrun; local served build smoke script; audio panning smoke scene behind `?debug&smoke=audio`; mumble-speech web check on the dev side.
- Out of scope: the itch.io page, secrets, variables, the first deploy and all real-browser or audio listening tests (all [HUMAN]); the title screen and press-to-start (1.4); the debug-key system and the real `?debug` check in `Debug` (1.6, `debug.gd` says so); adding `mumble_speech` or GoPeak to `game/addons/` (3.7 and the AI tooling setup); any gameplay code; the `Debug.enabled` semantics.
- Do not touch `_bmad/` or `.claude/` (symlinks, gitignored). Commit only `_bmad-output/` for the story docs (`docs(story)`); code commits are `feat(game)`, `chore(game)` or `chore(ci)`. Do not push (`main` is protected; PR-only workflow).

### Current repo state (verified 2026-11-06, HEAD edf44bb)

- `game/export_presets.cfg` exists from `d3a9964` and already contains: `name="Web"`, `export_path="../build/web/index.html"`, `exclude_filter="addons/gut/*, tests/*, tools/*"`, `variant/thread_support=false`, `variant/extensions_support=true`, `vram_texture_compression/for_desktop=true`, `vram_texture_compression/for_mobile=false`, `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true`. The VRAM keys are present but were written by the export, not by hand; AC1 requires they stay explicit (test in Task 1.2).
- GoPeak runtime addon is not present (`game/addons/` has only GUT when 1.2 is merged). Its exclude pattern is added now so the export rule is ready (Task 1.1).
- `.github/workflows/ci.yml` (from 1.2, branch `story/1-2-...`) has: `test-and-export` job, Godot 4.7.2-stable cached, `GODOT_BIN=/home/runner/.local/share/godot/bin/godot`, GUT step, guards step, Web export step writing `build/web/` (`index.html`, `index.pck`, `index.wasm` checked). `permissions: contents: read`, `concurrency`, push on `main` and `pull_request` on any base. No deploy job, no butler, no artifact upload, no secrets referenced.
- Local Godot: `/Applications/Godot.app/Contents/MacOS/Godot` version `4.7.2.stable.official.ed1daf0bf`. Web export templates for `4.7.2.stable` are installed in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (installed in 1.2: `version.txt` and `web_*.zip` only). `butler` is NOT installed locally and is not needed by the dev.
- `game/src/autoloads/debug.gd`: `var enabled: bool = OS.is_debug_build()`, with the comment "The ?debug URL check arrives in Story 1.6." The smoke scene therefore reads the URL itself in `main.gd` and does not change `Debug.enabled` (DC6).
- `game/src/main/main.gd`: persistent root, `_ready()` logs `flow boot`, `_draw()` renders the 8×8 test glyph at 2×. Story 1.3 adds only the URL branch (Task 5.3).
- Repo has no GitHub Actions secrets as far as the repo state shows (the dev has no access to check and does not need to). `BUTLER_API_KEY` and `ITCH_TARGET` are unset.

### Size record: known risk

The 1.2 local release export measured **46 MB** (`index.side.wasm` 44 MB, `index.wasm` 1.5 MB, `index.js` 2.9 MB, `index.pck` 8.9 KB). The NFR4 budget is 30 MB uncompressed. This story therefore carries the size risk that the architecture named ("stripped custom export template only if > 30 MB"). Measure it again in Task 2 with the release preset; do not assume the number.

Measurement command (macOS, no GNU tools needed):
```bash
find build/web -type f -exec wc -c {} + | tail -1      # total bytes
find build/web -type f -exec wc -c {} +                 # per file
```

### Commands (copy exactly)

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

# import (after any addon or class change)
$GODOT --headless --path game --import

# unit tests: exit code AND log markers, as in ci.yml
$GODOT --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# static guards
bash game/tools/check_guards.sh

# release web export
mkdir -p build/web && $GODOT --headless --path game --export-release "Web" ../build/web/index.html

# local serve and smoke (Task 4)
bash game/tools/smoke_web.sh
```

### Architecture requirements that bind this story

- **Web target:** Compatibility renderer, single-threaded export, Extensions Support on (dlink template), Sample audio playback. [Source: _bmad-output/game-architecture.md#Technical Constraints; AD-09; AD-14; project-context.md#Platform & Build Rules]
- **Preset:** no threads, extensions on, exclude `addons/gut`, `tests/`, `tools/`, GoPeak runtime; VRAM desktop only. [Source: _bmad-output/game-architecture.md, "Web export preset" bullets; epics.md#Story 1.3]
- **Size:** web build ≤ 30 MB uncompressed; stripped template only if > 30 MB. [Source: _bmad-output/game-architecture.md (performance and loading), project-context.md#Performance Rules]
- **Audio:** Sample mode, no effects; positional audio unreliable, fallback `playback_type = Stream` on the Null Pointer hum node only. [Source: game-architecture.md AD-09; project-context.md#Platform & Build Rules]
- **Mumble-speech:** runtime on web via GDExtension, pinned at first release including basteez/mumble-speech#32; I-6 check pulled into 1.3; contingency pre-render backend. [Source: game-architecture.md AD-14, I-6, ADR-05]
- **Debug gating:** debug tools only with `OS.is_debug_build()` or `?debug`; release builds without `?debug` expose nothing. [Source: project-context.md#Platform & Build Rules]
- **Deploy:** `butler` to the itch.io draft page; the DoD requires it at every epic end. [Source: epics.md#Epic List (Definition of Done, NFR16)]

### Latest Tech (verified and to-verify, 2026-11-06)

- **Verified with `gh` (2026-11-06):** basteez/mumble-speech issue #32 ("Web (HTML5) export support for the Godot addon") is **OPEN**. Releases: v0.2.0 (Latest, 2026-11-05, assets include `mumble-speech-godot-0.2.0.zip`), v0.1.1-rc.1 (pre-release, 2026-10-24), v0.1.0 (2026-10-24). The v0.2.0 release notes describe the playground and Unity Android changes; the web Godot support is not in the visible notes. Task 6 decides from the zip contents.
- **Godot 4.7.2 web export:** non-threaded export with Extensions Support uses the dlink template (`index.side.wasm`), which is why the total is large. Threads off means no SharedArrayBuffer and no COOP/COEP requirement. Check the 4.7 export docs for the exact template build flags before Task 3 (Context7 `/godotengine/godot-docs/__branch__4.7` per project-context).
- **itch.io HTML5 uploads:** the uploaded folder must have `index.html` at its root; `butler push <folder> <user>/<game>:<channel>` uploads it, `--userversion` labels the build; `BUTLER_API_KEY` is read by butler from the environment. Verify the flag names with `butler push --help` after installing (Task 7.4). The itch.io embed options (viewport, fullscreen button, SharedArrayBuffer) are set in the itch.io web UI, not by butler.
- **butler download:** `https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default` is the official broth endpoint for the Linux build; confirm the current URL and whether a checksum file is published before pinning it in CI (Task 7.3).

### Design calls

Made unattended during story creation (gds-create-story). Each is a recommendation the designer can overrule before dev-story.

- **DC1 Work split:** the story is split into [DEV] and [HUMAN]. The human steps (itch page, secret and variable, first deploy, real-browser and audio tests) need Tiziano's account and ears. The dev does everything else and never deploys. Reason: no secrets and no butler locally.
- **DC2 Deploy trigger:** `workflow_dispatch` on `main` only, no push trigger. Reason: an automatic upload on every merge is an unplanned outward-facing action; the epic DoD is a deliberate per-epic deploy. Recommendation: revisit once the epic cadence is settled.
- **DC3 Target as variable, not secret:** `ITCH_TARGET` is a repository variable (`vars.ITCH_TARGET`) holding `<user>/<slug>`, channel `html5`. Reason: it is not sensitive; only `BUTLER_API_KEY` is a secret. Until Tiziano sets it, the job skips.
- **DC4 Size budget:** the budget is 30 000 000 bytes (decimal MB, the number itch.io and the NFR use). CI warns but does not fail until the stripped template exists, since the current build is over budget and a red CI would hide real regressions. A story cannot go to `done` over budget without Tiziano's written waiver. Recommendation: flip the warning to a hard failure once the stripped template passes.
- **DC5 Smoke split:** the dev runs file-level and optional headless-console smoke checks; the real Chrome, Firefox and Safari loads, the click-gated audio and the listening test are [HUMAN]. Reason: the dev agent cannot hear audio and has no reliable browser automation here; the script says so instead of faking a pass.
- **DC6 Audio smoke gating:** the smoke scene is opened from `main.gd` only with both `?debug` and `smoke=audio` in the URL, read with `JavaScriptBridge` on web. It does not touch `Debug.enabled` (1.6 owns that). Reason: a temporary test path must not be reachable by players, and 1.6 will replace the URL check.
- **DC7 mumble-speech not vendored yet:** the addon is added only when a release with web support for `MumbleSpeaker` is confirmed (Task 6). Default expectation: not yet, the check moves to 3.7 as the AC allows. Reason: an addon without web binaries would break the web export or silently fail at runtime.
- **DC8 VRAM keys:** keep `for_desktop=true` and `for_mobile=false` explicit, and cover them in the GUT test. Reason: closes the 1.2 deferred item; the defaults in the file are already these values.
- **DC9 Build artifact for deploy:** the export job uploads `build/web` (3-day retention) and the deploy job downloads it, instead of re-exporting. Reason: one export per run, the deployed bytes are the bytes that were tested. This makes the 1.2 deferred "no build artifact upload" item partly done; the logs are still not uploaded.
- **DC10 Deploy gating in YAML:** secrets and variables are placed in the job-level `env:` and tested in a gate step, because `secrets.*` is not available in job-level `if:` conditions. Reason: standard GitHub Actions behaviour; the dev verifies the YAML parses, and the gate is covered by the skip path, which is the path that runs today.
- **DC11 Size tool:** a dev-written shell command rather than a Godot script, since `build/web` is outside Godot's `res://`. Reason: no addon needed.

### Previous story intelligence (Story 1.2, done; Story 1.1, done)

- Godot 4.7.2 binary on macOS is the one above; headless export works locally with the web templates installed in 1.2. Keep the same CLI style.
- GUT 9.6.1 runs as is; the suite is 34 tests / 68 asserts at 1.2 close. Task 1.3 expects 38 after the new preset test (plus any Task 4 tests).
- CI failure markers already defined (`SCRIPT ERROR`, `Parse Error`, `Failed to load script`, `does not extend GutTest`, `[Failed]`, `failing tests`) and the all-passed line is required. New test files must not trigger them.
- `untyped_declaration = Error` applies to our own `tests/` files (the 1.2 probe confirmed it; `addons/` is exempt). Type every variable in new test and scene scripts.
- 1.2 Completion Notes say VRAM keys were "left at Godot's defaults for Story 1.3 to decide". DC8 decides: explicit.
- 1.2 review deferred items that 1.3 touches: explicit VRAM keys (closed here), build artifact upload (partly closed, DC9). The rest stay deferred.
- Story 1.1 check: all Log, Const and Palette checks are covered by GUT; `Log` is the only print path. The smoke scene must log through `Log` (no bare `print`).

### Git intelligence

- Recent commits on this branch: `d3a9964 chore(game): add minimal Web export preset`, `1331ebe ci: run GUT, static guards and Web export on push and PR`, `734facc ci: move checkout and cache actions off deprecated Node 20`, `1b97e00 fix(ci): harden workflow and static guards after code review`, `edf44bb docs(story): record code review findings and mark story 1.2 done`.
- Pattern: code commits `chore(game)`/`feat(game)`/`ci`; story docs `docs(story)`. Story 1.3 code commits should be `chore(game)` (preset, tools), `feat(game)` (smoke scene, main.gd hook, test) and `ci` (workflow); docs in one `docs(story)` commit.

### Project Structure Notes

- Godot root is `game/`. Export path is `../build/web/index.html` (repo-root `build/`, gitignored). The workflow lives in `.github/workflows/ci.yml`. Scripts for dev use live in `game/tools/` (excluded from export).
- New files: `game/tests/unit/test_export_preset.gd` (+ `.gd.uid`), `game/tools/smoke_web.sh` (executable, committed with mode 755), `game/src/debug/smoke_audio/smoke_audio.tscn` and `smoke_audio.gd` (+ `.gd.uid`). `game/src/debug/` already exists (`.gitkeep`) and is not a simulation folder.
- Alignment: matches the domain-first layout (`src/debug`), no conflicts found with the architecture tree.

### Project Context Rules

Populated from `_bmad-output/project-context.md` (Platform & Build Rules, Testing Rules, Engine-Specific Rules, Code Organization Rules):

- Web is the only target; no audio before the first user input (the smoke scene waits for a click).
- Sample mode: no AudioEffects, no reverb, no `AudioStreamGenerator`; the tone is a generated `AudioStreamWAV`, not a generator.
- Export excludes `addons/gut`, `tests/`, `tools/` and the GoPeak runtime addon.
- Debug tools only with `OS.is_debug_build()` or `?debug` (the smoke scene uses `?debug&smoke=audio`).
- `Log.*` only, no bare `print`. Static typing everywhere. `await` and `create_timer` are allowed only in presentation/debug code, never under the simulation folders (the guard enforces this).
- GUT: `tests/unit/test_<subject>.gd`, `extends GutTest`, run headless with the command above.
- Godot 4.7.2-stable pinned, GDScript only. Do not upgrade.

### GoPeak

- Architecture names the GoPeak runtime addon folders `godot_mcp_editor` and `godot_mcp_runtime` (game-architecture.md, AI tooling section), with the README as the authority: verify the folder names from the GoPeak README before finalising Task 1.1. The exclude patterns must match the real folder names.

### itch.io settings checklist (for [HUMAN] H1)

- Kind of project: HTML. "This file will be played in the browser": on. Upload is via butler, so no manual file upload is needed.
- Embed: viewport 1280 × 720, "Fullscreen button" on, "SharedArrayBuffer support" off (threads are off).
- Visibility: Draft (or Restricted) until the epic DoD and the Story 1.3 smoke tests pass.
- Title: the full title "The Debugger 0x03: Wild Shift" (Story 7.9 finalises the page text).

### References

- Story 1.3 ACs and requirements: [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3]
- Epic 1 DoD (deploy and smoke every epic, size recorded): [Source: _bmad-output/planning-artifacts/epics.md#Epic List; NFR16]
- Web preset and export rules: [Source: _bmad-output/game-architecture.md (Web export preset bullet, Build system row); project-context.md#Platform & Build Rules]
- Size budget: [Source: epics.md NFR4; game-architecture.md (performance table)]
- Mumble-speech I-6 and AD-14: [Source: game-architecture.md I-6 row, AD-14, ADR-05]
- Day-1 smoke tests (AD-09 panning, I-6, I-7): [Source: epics.md "Additional Requirements" day-1 smoke tests]
- Deferred items touched: [Source: _bmad-output/implementation-artifacts/deferred-work.md, Story 1.2 section]
- Story 1.2 export and CI state: [Source: _bmad-output/implementation-artifacts/1-2-test-framework-and-ci-pipeline.md#Dev Agent Record; .github/workflows/ci.yml]
- Readiness report items for 1.3 (I-6 pulled in, itch embed 1280×720): [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-11-06.md]

## Open Questions (for Tiziano, not blocking dev-story)

1. **Size over budget.** The known 46 MB build needs a stripped template (Task 3) or a waiver. Do you want the stripped template built in this story, or a waiver until a later epic?
2. **README deadline mismatch.** `README.md` says the jam deadline is "2026-12-01 13:37 PST"; `epics.md` and the sprint-status header say 2026-11-29 12:00 PST. Not changed by this story; please confirm which is right (Story 7.9 owns the README).
3. **Deploy trigger.** DC2 chooses manual `workflow_dispatch` on `main`. Do you want automatic deploys on merge to `main` instead?
4. **Itch target.** Confirm the itch.io user and game slug to set as `ITCH_TARGET`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended run 2026-11-06/07.

### Debug Log References

All commands run from the worktree root on macOS, Godot 4.7.2.stable.official.ed1daf0bf.

| Step | Command | Exit | Key output |
|---|---|---|---|
| 1.2 red | GUT with the old preset (GoPeak test added first) | n/a | 40 tests, 39 passing: `test_exclude_filter_has_gopeak_runtime` failed as expected |
| 1.3 | GUT suite after the preset change | 0 | 40/40 passing |
| 5 red | GUT with `test_smoke_audio.gd` before the scene existed | n/a | `Parse Error: Preload file "res://src/debug/smoke_audio/smoke_audio.gd" does not exist` |
| 8.1 | `godot --headless --path game --import` | 0 | 0 `SCRIPT ERROR`/`Parse Error` lines |
| 8.1 | GUT (`-gdir=res://tests -ginclude_subdirs -gexit`) | 0 | Tests 46, Passing 46, Asserts 110, `---- All tests passed! ----` |
| 8.1 | `bash game/tools/check_guards.sh` | 0 | `check_guards: OK` |
| 2.1 / 8.1 | `--export-release "Web" ../build/web/index.html` | 0 | no `ERROR` lines; `index.pck` contains no `addons/gut`, `res://tests/`, `res://tools/` strings |
| 2.3 | `grep GODOT_THREADS_ENABLED build/web/index.html` | 0 | `GODOT_THREADS_ENABLED = false`; no `serviceWorker` in `GODOT_CONFIG` (PWA off) |
| 4.2 / 8.1 | `bash game/tools/smoke_web.sh` | 0 | 5 files 200 with the right types; threads off; no COOP/COEP; size 48 515 307 (warning, not failure); headless Chrome over CDP: `[f=0][INFO][flow] boot`, loader overlay removed, `smoke_web: PASS` |
| 5.4 | `SMOKE_QUERY='?debug&smoke=audio' SMOKE_CLICK=1 SMOKE_EXPECT='pan R' bash game/tools/smoke_web.sh` | 0 | `audio smoke scene opened`, click, `audio pan smoke started on bus Master`, `pan L` (f=3), `pan R` (f=124), `pan L` (f=245) |
| 5.4 | `SMOKE_QUERY='?smoke=audio' bash game/tools/smoke_web.sh` (no `debug`) | 0 | boot only, smoke scene not opened |
| 4 neg. | smoke on a copy without `index.side.wasm` | 1 | `FAIL: index.side.wasm: HTTP request failed` |
| 4 neg. | smoke on a copy with a corrupt `index.pck` | 1 | `console.error: ERROR: Cannot open resource pack 'index.pck'` ... `FAIL 7 console error(s)` (in 7 s) |
| 3.2 | `bash game/tools/build_web_template.sh <scratch>` (emsdk 4.0.11, SCons, Godot 4.7.2-stable source) | 0 | full build `Time elapsed: 00:01:31` on 15 cores; zip `godot.web.template_release.wasm32.nothreads.dlink.zip` 7 980 436 bytes |
| 3.2 | release export with `custom_template/release` set temporarily to that zip (not committed) | 0 | 28 398 468 bytes; smoke PASS (boot, and the audio pan sequence) |
| 7.5 | YAML parse (`uv run --with pyyaml`) | 0 | jobs `test-and-export`, `deploy-itch-draft`; triggers push(main), pull_request, workflow_dispatch |
| 7.5 | `shellcheck -S warning` over the 11 extracted `run:` blocks, and over `game/tools/*.sh` | 0 | clean. `actionlint` is not installed (running it via `go run` was blocked by the sandbox), so it was not run |
| 8.3 | `git status`, `gh run list` | 0 | `_bmad`/`.claude` not staged; no butler run, no `gh workflow run`, no secrets or variables written. The branch was pushed (coordinator allowed it). CI did not run because `ci.yml` triggers only on push to `main` and on `pull_request`, and no PR was opened |

### Completion Notes List

- Story created unattended by gds-create-story (2026-11-06). Design calls DC1–DC11 above; each is overrulable before dev-story.
- Implemented unattended by gds-dev-story. All [DEV] tasks are done. The [HUMAN] tasks H1–H4 are open and pending for Tiziano. That does not block `review`.

**[DEV] Size record (AC2, Task 2.2): default 4.7.2 dlink nothreads template, release export**

| File | Bytes | gzip -9 | brotli q11 |
|---|---:|---:|---:|
| `index.side.wasm` | 44 078 870 | 10 474 800 | 7 075 783 |
| `index.js` | 2 859 484 | 357 258 | 253 226 |
| `index.wasm` | 1 508 095 | 580 705 | 475 121 |
| `index.png` | 21 443 | 19 338 | 19 367 |
| `index.pck` | 14 052 | 9 178 | 8 706 |
| `index.apple-touch-icon.png` | 11 944 | 11 994 | 11 949 |
| `index.audio.worklet.js` | 7 298 | 2 217 | 1 821 |
| `index.icon.png` | 5 700 | 5 738 | 5 705 |
| `index.html` | 5 448 | 2 205 | 1 702 |
| `index.audio.position.worklet.js` | 2 973 | 1 193 | 895 |
| **Total** | **48 515 307** | **11 464 626** | **7 854 275** |

The total is over budget by 18 515 307 bytes. Even without Extensions Support, the stock `web_nothreads_release` template is 39 816 638 bytes, so it is over budget too.

**[DEV] Size record: stripped template (Task 3), same project**

| File | Bytes | gzip -9 | brotli q11 |
|---|---:|---:|---:|
| `index.side.wasm` | 25 414 813 | 7 113 761 | 4 977 294 |
| `index.wasm` | 1 600 314 | 595 552 | 484 412 |
| `index.js` | 1 314 483 | 216 784 | 170 343 |
| other 7 files | 68 858 | — | — |
| **Total** | **28 398 468** | **7 977 960** | **5 682 195** |

The stripped build is under budget, with 1 601 532 bytes of headroom. It boots in headless Chrome and passes the audio pan smoke test.

- **Q1: transfer vs disk.** NFR4 limits the size on disk. epics.md NFR4, gdd.md (Build size) and game-architecture.md (Load) all say "web build ≤ 30 MB **uncompressed**". The architecture also notes "build size on itch.io (no on-the-fly compression)". So the budget is the uncompressed upload, and the architecture assumes players download about that much from itch.io. The gzip and brotli columns are only the best case if the CDN compresses. Tiziano can check the real transfer in DevTools (Network, "transferred") during H4.
- **Task 3 flags** (recipe in `game/tools/build_web_template.sh`): `platform=web target=template_release threads=no dlink_enabled=yes optimize=size_extra debug_symbols=no use_closure_compiler=yes`, emscripten 4.0.11 (the version in Godot's `web_builds.yml` at 4.7.2-stable; the official template reports 4.0.20). The `custom.py` sets `disable_3d=yes`, `module_text_server_adv_enabled=no` and `module_text_server_fb_enabled=yes` (Latin-only text), and turns off these modules: astcenc, basis_universal, bcdec, betsy, bmp, camera, csg, cvtt, dds, enet, etcpak, fbx, glslang, gltf, godot_physics_3d, gridmap, hdr, interactive_music, jolt_physics, jsonrpc, ktx, lightmapper_rd, mbedtls, meshoptimizer, mobile_vr, mp3, msdfgen, multiplayer, navigation_2d, navigation_3d, noise, objectdb_profiler, openxr, raycast, svg, tga, theora, tinyexr, upnp, vhacd, webrtc, websocket, webxr, xatlas_unwrap, zip, mono. These stay on: gdscript, godot_physics_2d, freetype, ogg, vorbis, webp, jpg, regex, text_server_fb. Re-enable navigation_2d, msdfgen or text_server_adv if later stories need them.
- **AC2 is still open for the deployed build.** The stripped template is built and verified locally, but CI still exports with the stock template. The `deploy-itch-draft` job uploads the CI artifact, so a deploy today pushes 48.5 MB. Following the story (no local path or binary committed), `custom_template/release` stays empty, and CI keeps warning without failing (DC4).
  **Waiver / decision request for Tiziano:** (a) accept a temporary waiver so the first draft deploys (H3) can use the 48.5 MB stock build, **and** (b) choose how CI gets the stripped template in a follow-up: build it in CI with a cache keyed on the recipe (about 1.5 min locally on 15 cores; slower on a 4-core runner, cached afterwards), or attach the zip to a GitHub release and download it with a pinned checksum. Once that lands, turn the CI size warning into a failure (DC4).
- **AC3:** `GODOT_THREADS_ENABLED = false`; `GODOT_CONFIG` has no `serviceWorker` (PWA off), so the `ensureCrossOriginIsolationHeaders` branch never runs. No SharedArrayBuffer and no COOP/COEP needed. The headless Chrome boot with a plain `http.server` (no COOP/COEP headers) confirms it.
- **AC8 gate:** `main.gd` opens the smoke scene only when `OS.has_feature("web")` and `wants_audio_smoke(location.search)` are both true. The query must have a `debug` key **and** `smoke=audio`. GUT covers the parser (including `?smoke=audio`, `?nodebug&smoke=audio`, `?debugger&...`, `smoke=audiox`). The release web build was checked with and without `debug`. Off web the read returns `""`, so the glyph path is unchanged. A non-String bridge result also gives `""`. The scene lives in `src/debug/`, so the sim-folder guards pass.
- **AC9 / I-6: not yet, moved to Story 3.7.** basteez/mumble-speech#32 is OPEN. Latest release: v0.2.0 (2026-11-05). `mumble-speech-godot-0.2.0.zip` (listed with `unzip -l`, not extracted into `game/`) holds only `bin/libmumble_godot.so`, `.dylib`, `.dll` and `mumble_speech.gdextension`. It has no `.wasm` and no web binaries. The addon was not added.
- **AC4 / Task 7.3–7.4:** butler is pinned to 15.32.0 from `https://broth.itch.zone/butler/linux-amd64/15.32.0/archive/default` (LATEST was 15.32.0 on 2026-11-06). broth does not publish a checksum, so the dev downloaded the archive once (it was never run) and pinned `sha256 2335971394ef6596f95ded0833e85ee28755e13761716ef4c91d6b11f69162f5` in the job. The output of `butler version` can only come from the first CI deploy (H3); the job prints `butler version` and `butler push --help` before the push. **Honest note:** the hard rule bans running butler locally, so the push flags (`butler push <dir> <user>/<game>:<channel> --userversion <v>`, `BUTLER_API_KEY` from the environment) come from the itch.io butler docs (`itch.io/docs/butler/pushing.html`, `login.html`), not from the help text. The help text appears in the first deploy log, so Tiziano can check it there.
- **Q2 (flag for Tiziano, nothing changed):** `README.md` says the deadline is "2026-12-01 13:37 PST". `epics.md` and the sprint-status header say 2026-11-29 12:00 PST. Neither file was edited, and the new README section does not touch the status line. Please confirm which date is right.
- **Test count:** 34 → 46. That is 6 preset tests (the 4 named ones, plus `test_preset_is_web` and `test_exclude_filter_has_gopeak_runtime`) and 6 smoke/gate tests in `test_smoke_audio.gd`.

**Design calls made in this dev run**

- [design call] — coordinator: Q3. The deploy stays manual (`workflow_dispatch` on `main`) (DC2). `workflow_dispatch` was added to the workflow triggers so the job can run at all.
- [design call] — coordinator: Q4. `ITCH_TARGET` stays a repository variable that Tiziano fills in. The dev did not guess a slug; README and the job use `<itch-user>/<game-slug>`.
- [design call] — coordinator: Q2. README and epics were not changed; the mismatch is flagged above.
- [design call] — coordinator: Q1. Sizes were measured (raw, gzip, brotli). The budget is uncompressed size per GDD/architecture. A stripped template was realistic (toolchain installable in the session scratchpad, 1.5 min build) and was built and verified. CI keeps warn-not-fail, and the waiver request above covers the gap until CI uses the template.
- [design call] — dev: the GoPeak exclusions are `addons/godot_mcp_runtime/*`, `addons/godot_mcp_editor/*` and `addons/auto_reload/*`. The folder names come from GoPeak's `install-addon.sh` (the README points to it). All three are editor or AI tooling, so none belongs in a player build.
- [design call] — dev: the headless browser check uses the Chrome DevTools Protocol from plain Node 22+ (built-in WebSocket, no packages), not `--dump-dom`/`--virtual-time-budget`. A test showed `--dump-dom` returns before the 44 MB side module compiles, so the page never booted (false failures). The script skips the browser check with a message when Chrome or Node 22+ is missing. Optional env vars: `SMOKE_WEB_DIR`, `SMOKE_PORT`, `SMOKE_QUERY`, `SMOKE_CLICK`, `SMOKE_EXPECT`, `SMOKE_TIMEOUT_S`, `CHROME_BIN`. Every CDP call has a 5 s cap, so a page left stuck after an engine abort cannot hang the script.
- [design call] — dev: the smoke tone plays on the `SFX` bus if one exists, otherwise on `Master`. There is no `SFX` bus yet and `AudioManager` is a stub. Creating a bus at runtime would change the bus layout, which the task forbids.
- [design call] — dev: the gate is a pure static `Main.wants_audio_smoke(search)` that parses keys exactly, not `String.contains`. With `contains`, `?debugger` or `?nodebug` would open a debug path. The smoke scene loads with `load()` only when the gate is open.
- [design call] — dev: butler is pinned to a version and checksum instead of `LATEST`, so the deploy does not change silently and a tampered download fails.
- [design call] — dev: the stripped-template recipe is committed as `game/tools/build_web_template.sh` (excluded from export), not wired into CI. CI wiring needs Tiziano's choice (see the waiver request).
- [design call] — dev: `game/src/debug/.gitkeep` was removed now that the folder has files.

**[HUMAN] pending for Tiziano (H1–H4, not done):**
- H1: create the itch.io draft page (HTML, played in browser, 1280×720 viewport, fullscreen button on, SharedArrayBuffer off, Draft/Restricted).
- H2: add the `BUTLER_API_KEY` secret and the `ITCH_TARGET` variable (`<user>/<slug>`) in the repo settings.
- H3: after merge to `main`, Actions → CI → Run workflow on `main` (or `butler push` by hand). Record the `butler version` and `butler push --help` output from the log. Decide the size waiver first (see above).
- H4: Chrome, Firefox and Safari smoke tests: glyph boots with no console errors; `?debug&smoke=audio` (click, then L/R audible, or "fails" and the hum falls back to `playback_type = Stream`); mumble-speech "moved to 3.7"; size shown on itch.io and transfer size in DevTools; embed viewport and fullscreen behaviour.

### File List

- `.github/workflows/ci.yml` (modified: `workflow_dispatch` trigger, size step, artifact upload, `deploy-itch-draft` job)
- `README.md` (modified: "Deploying a draft build (itch.io)" section)
- `game/export_presets.cfg` (modified: GoPeak exclude patterns)
- `game/src/main/main.gd` (modified: smoke gate)
- `game/src/debug/.gitkeep` (deleted)
- `game/src/debug/smoke_audio/smoke_audio.gd` (new)
- `game/src/debug/smoke_audio/smoke_audio.gd.uid` (new)
- `game/src/debug/smoke_audio/smoke_audio.tscn` (new)
- `game/tests/unit/test_export_preset.gd` (new)
- `game/tests/unit/test_export_preset.gd.uid` (new)
- `game/tests/unit/test_smoke_audio.gd` (new)
- `game/tests/unit/test_smoke_audio.gd.uid` (new)
- `game/tools/smoke_web.sh` (new, 755)
- `game/tools/build_web_template.sh` (new, 755)
- `_bmad-output/implementation-artifacts/1-3-web-export-and-itch-io-draft-deploy.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (1-3 → review)

### Change Log

- 2026-11-07: Dev implementation of all [DEV] tasks. Status → review. AC2 was met locally only, with the uncommitted stripped template; CI still exported with the 48.5 MB stock template (see Review Findings for the fix). [HUMAN] H1–H4 are pending.


### Review Findings

Code review 2026-11-07 (Blind Hunter, Edge Case Hunter, Acceptance Auditor; unattended). Diff `origin/story/1-2-test-framework-ci...HEAD`.

- [x] [Review][Patch][design call, coordinator] AC2 unmet for deployed builds: CI exported with the 48.5 MB stock template [.github/workflows/ci.yml]. Fixed: CI builds the stripped template with `game/tools/build_web_template.sh` (emsdk 4.0.11), caches it (key: Godot release + hash of the script), installs it over `web_dlink_nothreads_release.zip`, exports with it, and the size step now fails over 30 000 000 bytes. Local result 28 398 564 bytes. Outcome: the CI build path was kept (no fallback, no waiver). Cold template build 11 min 37 s (CI run 42339513710, whole job 12 min); warm runs restore from cache.
- [x] [Review][Patch] Smoke server could test a foreign server on a busy port (false green) [game/tools/smoke_web.sh]. Fixed: `kill -0` checked before `curl`.
- [x] [Review][Patch] `upload-artifact` duplicate name on "re-run all jobs" [ci.yml]. Fixed: `overwrite: true`.
- [x] [Review][Patch] `BUTLER_API_KEY` exposed to every deploy step [ci.yml]. Fixed: scoped to gate and push steps.
- [x] [Review][Patch] `ITCH_TARGET` unvalidated / whitespace passes the gate [ci.yml]. Fixed: trimmed and regex-checked.
- [x] [Review][Patch] Size total via `tail -1` fragile; empty dir crashes [ci.yml, smoke_web.sh]. Fixed: awk sum, empty check; smoke budget reads `WEB_SIZE_BUDGET_BYTES` and now fails over budget.
- [x] [Review][Patch] `?debug=0`/`?debug=false` opened the debug scene [game/src/main/main.gd]. Fixed, tests added.
- [x] [Review][Patch] Exclude patterns for godot_mcp_editor/auto_reload and empty `custom_template/*` untested [test_export_preset.gd]. Fixed.
- [x] [Review][Patch] Silent exits: content-type grep under pipefail, python detection, `set -u` around emsdk_env, relative WORK_DIR, unpinned emsdk/scons [smoke_web.sh, build_web_template.sh]. Fixed (emsdk tag 4.0.11, scons <5).
- [x] [Review][Patch] Pan loop could resume after free [smoke_audio.gd]. Fixed (`is_instance_valid`).
- [x] [Review][Patch] Dispatch run could be replaced by a push run in the same concurrency group [ci.yml]. Fixed (group per event kind).
- [x] [Review][Patch] README manual deploy lacked `mkdir -p build/web` and used a short SHA unlike CI [README.md]. Fixed.
- [x] [Review][Patch] Story text overstated Task 8.3 and AC2 status. Fixed.
- [x] [Review][Defer] Stripped template disables svg, noise, mbedtls, websocket, zip, text_server_adv — may break later stories — deferred: re-enable in the script when a story needs it; CI size gate shows the cost.
- [x] [Review][Defer] Audio smoke URL gate cannot be reached from the itch.io iframe (`window.location.search` is the iframe URL) — deferred: H4 must open the html-classic iframe URL with `?debug&smoke=audio` or test locally.
- [x] [Review][Defer] Headless Chrome launch robustness (root/`--no-sandbox`, partial DevToolsActivePort) — deferred: script is local-only.
- [x] [Review][Defer] butler unzip location, butler flags and version unverified until first real deploy — deferred: H3 verifies in the first deploy log.
- [x] [Review][Defer] Actions pinned by tag, not SHA — deferred, same as Story 1.2.
- [x] [Review][Defer] smoke_web.sh browser step needs Node 22+ and skips otherwise; Task 4.1(f) used CDP instead of `--dump-dom` (recorded reason) — deferred.

[HUMAN] tasks H1–H4 remain pending for Tiziano; they do not block review completion.
