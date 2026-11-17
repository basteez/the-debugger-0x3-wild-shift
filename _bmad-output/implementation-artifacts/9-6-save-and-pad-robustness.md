---
baseline_commit: b459f21
---

# Story 9.6: Save and Pad Robustness

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from story/9-5 HEAD b459f21 (stacked; PR base story/9-5-test-isolation-hardening). Sources: Epic 9 in epics.md (Story 9.6 ACs, line ~1890), the brief epic9-brief.md (story 6 and the 9.4 review note on the three partially verified rows), the triage epic9-triage.md (section "9-5-save-and-pad-robustness", rows 426, 427, 444), deferred-work.md items 530, 531, 554c, and the 9.4 review rows at lines 88, 121, 199. Nothing was committed. Design calls are marked [design call] D-S96-n. -->

## Story

As a player,
I want a save that cannot be cut short and a fight that pauses when my pad drops out,
so that a closed tab, a half-written save or an unplugged pad does not cost me progress or a fight.

**Requirements:** deferred-work.md 531 (7.3), 530 (7.3), 554c (7.5); the three 9.4 review rows (88 TitleScreen.label_rects, 121 Esc in browser fullscreen, 199 ScreenFX dither / BASE_RES) re-checked against the code; triage 9-5 (renumbered 9.6); epics.md Story 9.6 (line ~1890).

## Acceptance Criteria

1. **Given** a save write (`SaveService.save()` with a real path) **When** it runs **Then** the values are written to a temp file next to the save (`save.cfg.tmp`), the temp file is read back and parsed to the same values, and only then is it renamed over `save.cfg` with `DirAccess.rename`; no step leaves a truncated `save.cfg` behind (531).
2. **Given** the temp write, the read-back or the rename fails **When** `save()` runs **Then** it falls back to the existing in-place `ConfigFile.save(path)`, removes any leftover temp file, and keeps the one-warn-per-session rule (warn only when the in-place write also fails) (531, [design call] D-S96-1).
3. **Given** a save with one wrong-typed key (`assist`, `muted`, `tutorial_done`, `completed`, `highest_boss`) **When** it is parsed **Then** every other key still loads and the bad key takes its default; the file stays valid as long as the version is readable, and the bad key names are logged once (530, [design call] D-S96-2).
4. **Given** the save version is not in `READ_VERSIONS` or the `version` key is missing **When** it is parsed **Then** the whole save is still a fresh save with one warn, as today (no regression of D-S73-8).
5. **Given** a pad disconnects while the flow is in a pausable state (FIGHT, and the other PAUSABLE_STATES) **When** `Input.joy_connection_changed` reports `connected == false` **Then** the game auto-pauses through `Game.set_paused(true, &"pad")` (the existing pause path: SimClock, `pause_toggled`, PauseScreen); a reconnect never resumes (554c, [design call] D-S96-3).
6. **Given** a pad disconnects outside the pausable states (TITLE, DEAD, HARVEST) **When** the signal fires **Then** nothing pauses and nothing else changes; a connect event never changes pause state.
7. **Given** the 9.4 row at deferred-work.md line 88 (TitleScreen.label_rects in canvas coordinates) **When** it is re-checked **Then** a guard test proves the base viewport and the title's clickable rects share the 640x360 canvas space in the shipped stretch settings, and every label rect lies inside the base frame; a fix is made only if the check fails ([design call] D-S96-4).
8. **Given** the 9.4 row at line 121 (Esc in browser fullscreen is eaten by the browser) **When** it is re-checked **Then** the story records that the code-side mitigation exists (P, Start and a click resume; pause_screen.gd documents it), that Esc itself is browser behaviour no code can intercept, and that the row stays deferred with a human check (H-S96-3); no code change ([design call] D-S96-5).
9. **Given** the 9.4 row at line 199 (ScreenFX dither assumes the viewport equals Const.BASE_RES) **When** it is re-checked **Then** a guard test asserts the stretch mode is `viewport`, `Const.BASE_RES` equals the project viewport size, and the ScreenFX shader `base_size` equals `BASE_RES`; the real-GPU check stays a human check (H-S96-4). No shader change unless the guard fails.
10. **Given** a web build **When** the rename path ships **Then** a human check note exists for a real browser save (IndexedDB-backed `user://`): save, reload, confirm the value persists and no `save.cfg.tmp` is left visible in the file list (H-S96-1), and a pad unplugged mid-fight in Chrome pauses (H-S96-2).
11. **Given** the change set **When** it is verified **Then** `SaveService.VERSION` stays 2 (no version bump; the 9.3 `completed` and 8.2 `tutorial_done` keys are unchanged), `game/tools/check_guards.sh` passes, the full GUT suite passes as CI runs it, and the touched production files are `game/src/autoloads/save_service.gd`, `game/src/autoloads/game.gd` (and nothing else under `game/src/` unless a guard test demands it).
12. **Given** the triage rows **When** this story closes **Then** deferred-work.md items 530, 531, 554c are annotated "Resolved in Story 9.6 (D-S96-n)" (history kept, never deleted), and the rows at lines 88, 121 and 199 gain a dated "9.6 re-check" note with the verdict of D-S96-4, D-S96-5 and D-S96-6.

## Tasks / Subtasks

- [x] Task 1: atomic save in `save_service.gd` (AC: 1, 2, 11)
  - [x] 1.1 Add `const TEMP_SUFFIX := ".tmp"` and a pure static `temp_path(p: String) -> String` (`p + TEMP_SUFFIX`).
  - [x] 1.2 Rewrite `save()`: when `path` is empty return false (unchanged). Otherwise `cfg = to_config(...)`, `cfg.save(temp)`; on OK, `ConfigFile.new().load(temp)` must be OK and `parse(...)` must be valid with the same `highest_boss`, `assist`, `muted`, `tutorial_done`, `completed`; then `DirAccess.open(path.get_base_dir())` and `dir.rename(temp.get_file(), path.get_file())` (Godot docs: rename overwrites an existing destination).
  - [x] 1.3 On any failure before a successful rename: `DirAccess` remove of the temp file if it exists, then `cfg.save(path)` in place (the current behaviour). The warn stays `_warn_once` and fires only if that in-place write also fails.
  - [x] 1.4 Keep the header comment of the file in step (the atomic rule and the D-S73-6 storage-failure note).
- [x] Task 2: per-key parse (AC: 3, 4)
  - [x] 2.1 `parse(cfg)` keeps the version check (`valid` false for a missing or unreadable version, as today).
  - [x] 2.2 Each typed key is checked on its own: wrong type gives that key's default and appends its name to a new `bad_keys` PackedStringArray in the returned dictionary. `highest_boss` non-number gives `MIN_BOSS`; a bool key gives `false`. `completed` already behaves this way (9.3).
  - [x] 2.3 `defaults()` gains `"bad_keys": PackedStringArray()`; `load_save()` logs one warn naming the bad keys when `bad_keys` is non-empty, using the same once-per-session `storage_warned` flag (one warn total, as today).
  - [x] 2.4 Update the tests the new rule changes (see Testing). The old "wrong type means invalid" assertions become "wrong type means that key defaults".
- [x] Task 3: pad disconnect auto-pause in `game.gd` (AC: 5, 6)
  - [x] 3.1 In `_ready()` connect `Input.joy_connection_changed` to a new `on_joy_connection_changed(device: int, connected: bool) -> bool` (no connect-once guard needed: `_ready` runs once for the autoload).
  - [x] 3.2 Body: `if connected: return false`. Otherwise `return set_paused(true, &"pad")` (set_paused already refuses outside PAUSABLE_STATES and is a no-op when already paused). Do not set `_focus_lost` (this is not window focus). Log through the existing `Log.info` in `set_paused`; no new text.
  - [x] 3.3 Do not add any resume path. Focus return and reconnect never resume (Story 1.7 DC3).
  - [x] 3.4 Do not touch `PauseScreen` text: the pause screen already opens from `pause_toggled(true)`. A pad-specific note is an open question (default: none).
- [x] Task 4: re-check the three 9.4 rows (AC: 7, 8, 9)
  - [x] 4.1 Row 88: verify `TitleScreen.label_rects` vs `InputEventMouseButton.position` in the shipped stretch (`window/stretch/mode="viewport"`, `aspect="keep"`, `scale_mode="integer"`, project.godot lines 39-45): in viewport stretch the event positions are already in the 640x360 viewport. Add a guard test (see Testing). Fix only if the guard fails.
  - [x] 4.2 Row 121: no code change; the mitigation is `PauseScreen` text and `Game` P/click resume (D-FIX-FS-1). Record the verdict in the file's Dev Agent Record.
  - [x] 4.3 Row 199: `ScreenFX._init` sets `base_size = Vector2(Const.BASE_RES)`; in viewport stretch `SCREEN_UV * base_size` is the base pixel. Add the guard test. The real-GPU check stays H-S96-4.
- [x] Task 5: tests (AC: 1-9, 11)
  - [x] 5.1 `game/tests/unit/test_save_service.gd`: atomic write leaves no `.tmp` and the file parses; the temp file is read back before the rename (a seam: a test sets a stale `.tmp` containing bad data and checks it is replaced); fallback when the temp path is a directory (the temp write fails, the in-place write succeeds, no warn); per-key tests (bad `assist` keeps `highest_boss` 3; bad `highest_boss` gives 1 and keeps `assist`; `bad_keys` lists the names; one warn for several bad keys); a version 99 file is still a fresh save with one warn.
  - [x] 5.2 `game/tests/unit/test_pause.gd` (or a new `test_pad_pause.gd`): disconnect in FIGHT, INTRO, ENDING, TUTORIAL pauses once and emits `pause_toggled(true)`; disconnect in TITLE, DEAD, HARVEST does nothing; a connect never changes pause; a disconnect while paused stays paused and does not emit again; a later focus return or connect does not resume.
  - [x] 5.3 Guard tests for rows 88 and 199: project stretch mode is `viewport`; `ProjectSettings.get_setting("display/window/size/viewport_width")` and `viewport_height` equal `Const.BASE_RES`; `ScreenFX.new().shader_material.get_shader_parameter(&"base_size")` equals `Vector2(BASE_RES)`; every `TitleScreen.label_rects` value (both fullscreen states, with and without debug build) lies inside `Rect2(0, 0, 640, 360)` and keeps the 16-px gutter where the layout already promises it.
  - [x] 5.4 Run the GUT suite exactly like CI (`.github/workflows`; `--headless --import` first) with `/Applications/Godot.app/Contents/MacOS/Godot`; run `game/tools/check_guards.sh`.
- [x] Task 6: bookkeeping (AC: 12)
  - [x] 6.1 deferred-work.md: annotate items 530, 531, 554c "Resolved in Story 9.6 (D-S96-n)"; annotate lines 88, 121, 199 with the "9.6 re-check" verdict. Never delete.
  - [x] 6.2 Story file: fill Dev Agent Record (completion notes, file list, human checks H-S96-1..4). Status to review only at dev end, per the epic workflow.
  - [x] 6.3 sprint-status.yaml: 9-6 is set to ready-for-dev by this story (done); dev-story moves it on.

## Dev Notes

### Verified facts (read on 2026-11-17, worktree story/9-6 at b459f21)

- `game/src/autoloads/save_service.gd`: one `ConfigFile` at `user://save.cfg`, section `save`, `VERSION := 2`, `READ_VERSIONS := [1, 2]`. `save()` calls `to_config(...).save(path)` directly, i.e. an in-place write (531). `parse(cfg)` returns a dictionary with `valid`; wrong-typed `highest_boss` (non-number), `assist`, `muted` or `tutorial_done` sets `valid = false` and the whole save becomes defaults (530). `completed` already falls back per key (9.3, D-S93-1 review note). `path` is empty under GUT (`running_under_gut()`), so tests use `SCRATCH := "user://test_save_7_3.cfg"`.
- `load_save()` reads once at boot; a version or value failure logs one warn via `_warn_once` (shared `storage_warned` flag, D-S73-6).
- `game/src/autoloads/game.gd`: `PAUSABLE_STATES = [INTRO, FIGHT, ENDING, TUTORIAL]`; `set_paused(on, reason)` is the only writer outside tests (refused outside PAUSABLE_STATES, emits `EventBus.pause_toggled`); focus loss goes through `on_focus_lost()` (`_notification` for APPLICATION / WM focus, `_listen_web_focus` for web `blur` and `visibilitychange`); `_set_flow_state` clears pause on any flow change (DC5) and re-pauses if `_focus_lost` is set on entering a pausable state. `Game._ready()` connects only `player_damaged` and `register_shifted`; no `joy_connection_changed` handler exists in `game/src` (554c confirmed).
- `game/src/ui/screens/title/title_screen.gd`: `label_rects` is a `Dictionary[StringName, Rect2]` built from `practice_label_rect()`, `tutorial_label_rect()`, `fullscreen_label_rect(false)`; `set_fullscreen_shown()` and the debug-build and new-run paths update their entries; `classify()` / `option_of()` test `mouse.position` against these rects (canvas space).
- `project.godot`: `viewport_width=640`, `viewport_height=360`, `window/stretch/mode="viewport"`, `aspect="keep"`, `scale_mode="integer"`. `Const.BASE_RES := Vector2i(640, 360)` (`game/src/core/const.gd`).
- `game/src/presentation/screen_fx.gd`: `_init` sets `base_size = Vector2(Const.BASE_RES)`; `screen_fx.gdshader` uses `ivec2(floor(SCREEN_UV * base_size))` for the dither checker, and `invert` exempts `warn_colour` pixels (Story 4.3).
- `game/src/ui/screens/pause/pause_screen.gd`: the resume text is `[ESC / P / CLICK] RESUME` and the header comment states D-FIX-FS-1 (P and a click resume because Esc may never reach the canvas in browser fullscreen).
- Godot docs (ctx7, `/websites/godotengine_en_stable`): `DirAccess.rename(from, to)` "If the destination file or directory exists and is not access-protected, it will be overwritten"; `OS.is_userfs_persistent` is documented as relevant to Web, where user:// persistence may be unavailable. `rename_absolute` supports only absolute paths, so use an instance from `DirAccess.open(path.get_base_dir())` with file names.
- Existing tests that the new rule changes: `test_parse_rejects_bad_versions_and_values` (test_save_service.gd ~line 144: asserts `valid` false for `assist = "yes"`), `test_wrong_type_flag_is_invalid` (~line 191: asserts `valid` false for `tutorial_done = "yes"`), `test_bad_version_resets_to_defaults_and_warns_once` (~line 131: keep, the version case is unchanged), `test_completed_wrong_type_reads_false_and_keeps_the_save` (~line 542: already the per-key rule, add the `bad_keys` assertion).

### Design calls (Story 9.6)

- **[design call] D-S96-1 Atomic save (531):** temp file, read back, `DirAccess.rename` over `save.cfg`; any failure falls back to the existing in-place write. Rationale: a tab closed mid-write can then leave only the old file or the new file, never a truncated one. Chosen over write-verify-then-replace in place because the in-place write is the step that truncates. Web: the temp file is written and closed, then renamed in the emscripten filesystem that is synced to IndexedDB. Believed but not verified: that a file close triggers a sync, and that the rename is synced before the tab closes. If it is not, IndexedDB still holds the old `save.cfg` (a valid save) or the old file plus a stale `.tmp` that is never read. Unverified in a browser: flagged H-S96-1. `OS.is_userfs_persistent()` false means nothing is persisted anyway, so no extra branch.
- **[design call] D-S96-2 Per-key parse (530):** `valid` now covers the version only. A wrong-typed key takes its own default and is named in `bad_keys`; one warn per session. `VERSION` stays 2 (readers accept 1 and 2, so no bump is needed and the version 1 and 2 tests stay). Wrong-typed `highest_boss` gives `MIN_BOSS` (progress lost for that key only, the decision the triage described as "a nicety").
- **[design call] D-S96-3 Pad auto-pause (554c):** any pad disconnect in a PAUSABLE state pauses through `set_paused(true, &"pad")`. Reconnect never resumes (same rule as focus, DC3). Outside PAUSABLE states nothing happens: a disconnect in TITLE, DEAD or HARVEST has no fight to freeze, and DEAD is already a stop. "Mid-fight" in the epic means FIGHT, and the other pausable states follow the same rule (Story 1.7). Any device, not only the active one (default; see open questions).
- **[design call] D-S96-4 Row 88 (TitleScreen.label_rects):** verdict: the rects are in the same canvas space as the mouse events because the project uses viewport stretch (events are transformed into the 640x360 viewport by the engine). The 9.4 concern is "not proven"; a guard test proves the shipped settings and the rect bounds. No code change unless the guard fails. The row stays annotated, not reopened.
- **[design call] D-S96-5 Row 121 (Esc in browser fullscreen):** verdict: the code side is done (D-FIX-FS-1: P, Start and a click resume, and the PauseScreen row says so). Whether the browser delivers Esc at all is browser behaviour no code can change. Stays deferred with human check H-S96-3 (Chrome, Firefox, Safari, itch iframe: enter fullscreen, press Esc, confirm pause and resume with P or a click). No code change.
- **[design call] D-S96-6 Row 199 (ScreenFX dither / BASE_RES):** verdict: correct in viewport stretch (the screen texture is the 640x360 viewport, so `SCREEN_UV * base_size` is the base pixel and the checker follows game pixels). A guard test asserts the settings. The real-GPU and web check stays H-S96-4. No shader change.

### Open questions (defaults chosen, no elicitation)

1. Pad disconnect on any device or only the active one? Default: any device (a disconnect of the pad in use is the case that matters, and a second pad unplugged should not hurt less).
2. Should the pause screen say "PAD DISCONNECTED"? Default: no new text (text audit scope); the existing pause screen plus the P / click resume is enough. Revisit if H-S96-2 shows confusion.
3. Disconnect while in TUTORIAL: pauses (TUTORIAL is in PAUSABLE_STATES). Default: yes, same as focus loss.
4. Temp file name `save.cfg.tmp`: a stale one from a crash is overwritten by the next save and never read by `load_save()`. Default: no cleanup at boot.
5. Web IndexedDB flush after rename is not verified in a browser (H-S96-1). Default: ship with the in-place fallback and the note; not a blocker for submission unless H-S96-1 fails, in which case revert Task 1 to the in-place write.

### Testing

- GUT, run exactly as CI (`--headless --import` first). Every test touching the save uses `SCRATCH` or a `.tmp` sibling under `user://` and deletes both in `after_each`; the autoload stays in-memory under GUT.
- Seed nothing new (no boss RNG in these tests).
- The pad tests construct `GameScript.new()` through `autofree` (the test_pause.gd pattern) and call `on_joy_connection_changed` directly; they never rely on real joypads (headless CI has none; test_tutorial_screen.gd line ~62 shows the guard).
- Guard tests for rows 88 and 199 are pure (no window, no rendering).

### Project Structure Notes

- No new files under `game/src/`. Touched: `game/src/autoloads/save_service.gd`, `game/src/autoloads/game.gd`.
- Tests: `game/tests/unit/test_save_service.gd`, `game/tests/unit/test_pause.gd` (or new `game/tests/unit/test_pad_pause.gd`), a guard test for the viewport settings (new `game/tests/unit/test_viewport_guard.gd` is acceptable; keep it small).
- `_bmad/` and `.claude/` are gitignored and symlinked; nothing there is edited.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 9.6: Save and Pad Robustness] (line ~1890)
- [Source: deferred-work.md lines 88, 121, 199, 530, 531, 554c]
- [Source: epic9-triage.md section 9-5 and rows 426, 427, 444]
- [Source: game/src/autoloads/save_service.gd] (save, parse, load_save, defaults, _warn_once)
- [Source: game/src/autoloads/game.gd] (PAUSABLE_STATES, set_paused, on_focus_lost, _ready, _set_flow_state)
- [Source: game/src/ui/screens/title/title_screen.gd] (label_rects, classify, option_of)
- [Source: game/src/presentation/screen_fx.gd, screen_fx.gdshader] (base_size, dither checker)
- [Source: project.godot lines 39-45] (viewport stretch)
- [Source: Godot docs via ctx7, /websites/godotengine_en_stable, DirAccess.rename and OS.is_userfs_persistent]

## Project Context Rules

- Main is protected: work on `story/9-6-save-and-pad-robustness` (stacked on `story/9-5-test-isolation-hardening`), PR base is the 9.5 branch; no commit to main; no force push; no `gh pr merge`.
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). Guards: `game/tools/check_guards.sh`.
- Set story status with the Edit tool. Never use the Fable model.
- Every new user-facing string is audited text if it is in `.tres`; code-constant rows follow the pause screen pattern (no new text in this story by default).

## Dev Agent Record

### Agent Model Used

Claude (gds-create-story, unattended, 2026-11-17); Claude Opus (gds-dev-story, unattended, 2026-11-17)

### Debug Log References

- Red: the updated `test_save_service.gd` against the pre-story `save_service.gd` does not load (`atomic_writes`, `temp_path`, `bad_keys` missing) and the old "wrong type means invalid" assertions were flipped; `test_pad_pause.gd` first failed on a cumulative `watch_signals` count (test bug, fixed with the test_pause.gd counting pattern).
- Green: full GUT suite, CI order: 130 scripts, 1934 tests, 1934 passing, 150810 asserts, `---- All tests passed! ----`, no CI failure marker. `WILDSHIFT_GUT_ORDER=shuffle:20261129`: same 130 / 1934 / 1934 / 150810, all passed, no marker. `--headless --import` run first. `game/tools/check_guards.sh`: OK.

### Completion Notes List

- Story created unattended (ultimate context engine analysis completed, comprehensive developer guide created). No elicitation. Status ready-for-dev.
- Human checks to record at dev end (recorded below): H-S96-1 (Chrome and Firefox web build: save, reload, value persists, no visible `.tmp` in the IndexedDB file listing if inspectable; Safari spot check), H-S96-2 (Chrome, unplug a pad mid-fight: auto-pause, plug back in: still paused until P / Start / click), H-S96-3 (browser fullscreen Esc on Chrome, Firefox, Safari, itch iframe), H-S96-4 (real-GPU and web check of the dither frame and the title click rects in fullscreen).

- **[design call] coordinator (atomic save, 531):** temp + read-back + rename runs ONLY when `not OS.has_feature("web")` (`SaveService.atomic_writes`, a test seam). On the web the in-place `ConfigFile.save(path)` is kept exactly as before, because rename over the IndexedDB-backed `user://` is unverified and a save regression right before the jam is worse than the theoretical torn write. The fallback path is kept (any atomic failure writes in place; warn only if that also fails). This narrows AC 1 / D-S96-1 to desktop; H-S96-1 now checks that the web path is unchanged (save, reload, value persists) rather than the rename.
- **[design call] coordinator (open questions):** defaults accepted: 1 any device pauses; 2 no new pause text; 3 TUTORIAL pauses; 4 no boot cleanup of a stale `save.cfg.tmp` (the next atomic save overwrites it; `load_save()` never reads it). Open question 5 is moot on the web (no rename there).
- **[design call] coordinator (per-key parse, 530):** a bad key never raises progress and only `highest_boss` can lower it: a wrong-typed `highest_boss` falls back to `MIN_BOSS` and is logged (one warn per session naming every bad key, shared `storage_warned`). Flag defaults stay those of 8.2 (`tutorial_done` false) and 9.3 (`completed` false). A version problem still wipes to a fresh save with one warn (D-S73-8 unchanged). `VERSION` stays 2.
- Task 1 (531): `TEMP_SUFFIX`, static `temp_path()`, `atomic_writes`, `save()` now builds the config once, tries `_save_atomic()` (write temp, `_read_back_matches()` loads + parses to the same five values with no bad key, `DirAccess.open(base_dir).rename(temp_file, file)`), else removes a leftover temp file and writes in place. Header comment updated.
- Task 2 (530): `parse()` checks each key on its own; `bad_keys` (PackedStringArray) in `defaults()` and the result; `load_save()` warns once naming the bad keys (version warn text now "save version not recognised").
- Task 3 (554c): `Game._ready()` connects `Input.joy_connection_changed` to `on_joy_connection_changed(device, connected) -> bool` (disconnected in `_exit_tree`); a connect returns false and does nothing; a disconnect calls `set_paused(true, &"pad")`; `_focus_lost` untouched; no resume path, no PauseScreen change.
- Task 4: row 88 (D-S96-4) and row 199 (D-S96-6) verified by the new pure guard `test_viewport_guard.gd` (stretch mode `viewport` / aspect `keep`, project viewport = `Const.BASE_RES` = 640x360, `ScreenFX` `base_size` = `BASE_RES`, every title label rect inside the 640x360 frame: practice, tutorial, new-run plain and armed, fullscreen and debug-build both states, and a TitleScreen instance's `label_rects` in both fullscreen states). All pass: no code fix needed. The "16-px gutter" sub-check was not added: the layout makes no gutter promise for these rows (the fullscreen row's margin box touches the bottom edge at y 360), so the guard asserts containment only. Row 121 (D-S96-5): verified `pause_screen.gd` D-FIX-FS-1 and the `[ESC / P / CLICK] RESUME` row; no code change, stays deferred with H-S96-3.
- Task 5 tests: `test_save_service.gd` (+13 tests, 3 updated: `test_parse_rejects_bad_versions_and_defaults_bad_values`, `test_wrong_type_flag_defaults_to_false`, `bad_keys` assertion in the 9.3 completed test; `after_each` also removes a `.tmp` file or directory); new `test_pad_pause.gd` (7 tests, saves/restores `SimClock.paused`; suite-level reset is the 9.5 `TestIsolation` hook); new `test_viewport_guard.gd` (5 pure tests). No RNG used, nothing to seed.
- Task 6: deferred-work.md items 530, 531 and 554c(3) annotated "Resolved in Story 9.6 (D-S96-n)" (531 marked desktop-only), the related 7.5 note at ~line 626 annotated, and the 9.4 rows at lines 88, 121, 199 gained a dated "9.6 re-check" verdict. Nothing deleted.
- Human checks: **H-S96-1** (web, Chrome + Firefox, Safari spot check): save (toggle assist / mute, or reach Fight 2), reload the tab, confirm the value persists; the web build uses the unchanged in-place write, so no `save.cfg.tmp` should ever appear. **H-S96-2** (Chrome web + desktop): unplug a pad mid-fight: the game auto-pauses; plug it back: still paused until P / Start / Esc / click. **H-S96-3**: browser fullscreen Esc on Chrome, Firefox, Safari and the itch iframe: confirm pause, then resume with P or a click. **H-S96-4**: real-GPU desktop + web check of the dither frame and the title click rects in fullscreen. Optional desktop check: after a save, `user://` holds `save.cfg` and no `save.cfg.tmp`.

### File List

- `_bmad-output/implementation-artifacts/9-6-save-and-pad-robustness.md` (new, this story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (9-6: ready-for-dev, then review)
- `_bmad-output/implementation-artifacts/deferred-work.md` (530, 531, 554c, ~626 and the 9.4 rows 88, 121, 199 annotated)
- `game/src/autoloads/save_service.gd` (atomic save off the web, per-key parse, `bad_keys`)
- `game/src/autoloads/game.gd` (pad disconnect auto-pause)
- `game/tests/unit/test_save_service.gd` (updated + new atomic / per-key tests)
- `game/tests/unit/test_pad_pause.gd` (+ `.uid`, new)
- `game/tests/unit/test_viewport_guard.gd` (+ `.uid`, new)

### Change Log

- 2026-11-17: Story 9.6 implemented (gds-dev-story, unattended): desktop-only atomic save with in-place fallback (web unchanged, coordinator call), per-key save parse with `bad_keys` and one warn, pad-disconnect auto-pause, viewport/ScreenFX/title-rect guard tests; deferred-work annotated; status review.

### Review Findings (gds-code-review, 2026-11-17, unattended)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). Web path confirmed behaviourally unchanged; no other reader of `parse()["valid"]`.

- Patched: `clamp_highest` mapped NaN/INF through `int()` (platform-dependent); non-finite floats now give MIN_BOSS and finite ones are clamped first; test added. Save-service comment no longer claims rename atomicity on Windows.
- Amended: AC 1 and D-S96-1 apply to desktop only (coordinator design call, see Dev Agent Record); the web rationale text in D-S96-1 is moot, H-S96-1 checks the web path is unchanged.
- Deferred (low/med, recorded in deferred-work.md): Windows `DirAccess.rename` removes then moves, so a crash between leaves only `save.cfg.tmp` (adopt a verified temp at load, or `.bak`); `storage_warned` is shared by load-time bad keys and write failures (split per category); a pad drop in a non-pausable state (TITLE/DEAD/HARVEST) is forgotten, unlike `_focus_lost`; any device's disconnect pauses (test_any_device_pauses pins it); atomic fallback in place can truncate when the temp fails on a full disk; no fsync; untested branches (rename failure, corrupt temp through `save()`, DirAccess null); no `_exit_tree` disconnect test; `_handle_engine_errors()` called last in two tests; a string `highest_boss` drops to 1 and is rewritten on the next save; float/bool `version` wipes the save (hand-edit only).
- Rejected: fixed temp name (single-instance game), Windows fsync, `atomic_writes` default tautology test.
