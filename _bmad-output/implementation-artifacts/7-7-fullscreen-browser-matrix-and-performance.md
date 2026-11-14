---
baseline_commit: 5a765f5
---
# Story 7.7: Fullscreen, Browser Matrix and Performance

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with a default (D-S77-n); the implementer follows them or records a change in Completion Notes. Scope: the fullscreen toggle (F key, title and pause rows, pad R3), the automatable performance and size checks, and three coordinator release-polish items (a) the FIGHT placeholder text, (b) practice follow-ups from the 7.6 review. The browser matrix (Chrome, Firefox, Safari), the cold-cache title timing and the 2020 laptop run are HUMAN checks, listed below and in deferred-work.md. NOT in scope: the full-run playtest and tuning (7.8), the itch page and README (7.9), new art, new audio. -->

## Story

As a jam player,
I want the game to run smoothly in my browser, fullscreen if I like,
so that my first impression isn't a broken build.

**Requirements:** FR55, NFR1, NFR2, NFR3, NFR4, NFR7. Brief decision (2026-11-14): automate the fullscreen toggle and the checks that can run headless; the browser matrix and the 2020 laptop test are human and stay pending with a checklist.

Depends on: 7.6 (title option rows, `TitleScreen.label_rect_for`, `Game` practice flow, `PracticeFrameCounter`), 7.5 (reserved `title_option_fullscreen` = F key and pad button 8 = R3 in `project.godot [input]`; `PlaceholderScreen.is_pad_press`), 7.4 (`[B]` row pattern, `PauseScreen` row constants), 7.3 (`SaveService`, the `[N]` rule), 1.6 (`PlaceholderScreen`, debug jump keys), 2.8 (`ParticlePool`, F10 perf overlay), 5.6 (`FeatureFlags.segfault` cut flag, `Game.segfault_enabled`).

## Acceptance Criteria

**Fullscreen (FR55)**

1. **Given** the title screen, **When** I press `F` or click the `fullscreen` label, **Then** fullscreen is toggled through `DisplayServer.window_set_mode` called inside the input-event handler (the browser only accepts fullscreen from a user gesture); a second press returns to windowed.
2. **And** the pad button `title_option_fullscreen` (button 8, R3) does the same on the title (7.5 AC 3 wording: R3 is the fullscreen option, no longer hidden).
3. **And** the fullscreen label is a new title row below the `[P] practice` row: `[F] fullscreen` / `[F] windowed` (the text follows the current window mode), at y 336 (`TitleScreen.FULLSCREEN_TOP_Y`), centred, clickable through `label_rects` [design call] D-S77-1. `available[&"fullscreen"]` is `true` in every build. Its text lives in `data/text/screen_text.tres` (6.9 rule).
4. **And** the same toggle is on the pause screen: `[F]` (or R3, or a click on its row) toggles fullscreen without resuming, in a row below the `[B]` assist row at y 336 [design call] D-S77-1. Its text is a code constant like the other pause rows (7.4/7.5 precedent) unless 7.9 audits the pause screen.
5. **And** if the request is refused or the window mode does not change (checked with `DisplayServer.window_get_mode()` 0.75 s after the request on a SceneTreeTimer, because the web request is asynchronous; a newer toggle supersedes a pending check), the game stays windowed silently: no error, no player-visible text, one `Log.warn(&"display", ...)` per session.
6. **And** pressing `F` never starts the run and never reaches the sim: it is an option key on the title, and in FIGHT `F` is ignored (no gameplay binding); on INTRO/HARVEST/ENDING and DEAD (retrying, rule 2.9) `F` is just another key that advances or retries, with no fullscreen effect (coordinator-approved). Stick and trigger motion still start nothing (7.5 AC 8).
7. **And** the fullscreen request never changes `SimClock.paused`, the save (`SaveService`) or the flow state. The browser may exit fullscreen on Esc; the existing focus and Esc rules (D-FIX-FS-1, D-FIX-FS-2) stay as they are.

**Automatable checks (NFR1-4, NFR7)**

8. **Given** the release web export, **When** `game/tools/check_build_size.sh` runs (new; it takes the export directory, default `build/web`), **Then** it prints the total uncompressed size of the export and exits 1 if it is greater than 32 000 000 bytes (decimal 32 MB; the CI budget `WEB_SIZE_BUDGET_BYTES` since the 2026-11-10 NFR4 change; D-S77-5 approved by the coordinator). It exits 2 when the directory is missing. It is also what CI's size step runs; it is not part of `check_guards.sh`.
9. **And** the particle cap is a structural guarantee and is tested: `ParticlePool.CAPACITY == 300`, a spawn beyond capacity is dropped silently, and a GUT test drives a worst-case burst (more spawns than capacity in one frame, over several frames) and asserts `live_count() <= 300` at every step. Seeded, no global RNG.
10. **And** the perf instrumentation stays as it is: the F10 overlay (FPS, frame ms, particles n/300, draw calls) remains debug-only; no new per-frame logging (`Log.debug` only on events, project-context rule). [design call] D-S77-2: no new telemetry in this story; the human perf run uses the F10 overlay.
11. **And** the title's cold-load budget is recorded as an estimate, not a test: at 50 Mbps, 32 MB transfers in about 5.1 s, so the title is interactive in ≤ 10 s when the engine boot and the first frame fit in the remaining ~5 s (human check H-S77-3 confirms it on a real cold cache).

**Coordinator release polish (a): the FIGHT placeholder text**

12. **Given** a normal fight in a release build (no `?debug`), **When** the arena is drawn, **Then** the Story 1.6 PlaceholderScreen text (`FIGHT n` / `boss index n`) is NOT drawn. It is shown only when `Debug.enabled` (debug builds and `?debug`), and never in practice (the 7.6 rule stays).
13. **And** the placeholder node still exists in every build (the `PlaceholderScreen` is the FIGHT screen node; `_make_screen` keeps creating it), with `lines` empty in release. Its key handling is unchanged (it consumes no input, `_unhandled_input` is a no-op). Existing tests in `test_placeholder_fight_keys.gd` are updated only where they assumed the text is always drawn.

**Coordinator release polish (b): practice follow-ups from the 7.6 review**

14. **Given** a practice fight, **When** the player dies, **Then** `Game.record_death` does not increment `run.deaths_on_boss` for the practice, does not emit `EventBus.player_died` (the duck's death hint is for real fights), and does not write `SaveService` (already true; keep it true with a test). It still enters DEAD, so the retry flow works. [design call] D-S77-3: a practice death keeps the DEAD screen and the retry, with no stats change.
15. **And** in a practice fight `Game.on_player_damaged` does not add to `stats.hits` (run stats are never touched by practice). A practice run never reaches Harvest, Ending or a clear (7.6 AC 14, kept).
16. **Given** a practice DEAD screen, **When** I press Esc (keyboard) or L3 (pad, the button that entered practice; D-S76-6), **Then** the game leaves to TITLE through `Game.leave_practice_to_title`, which is now valid from FIGHT and DEAD while `practice_run` is set. The leave is immediate (no 20-frame retry gate). No save write.
17. **And** on a normal (non-practice) DEAD screen, Esc does nothing and L3 retries (7.5 AC 9, 2.9 AC 4: unchanged). The practice leave takes precedence over the retry only in practice.
18. **Given** the cut flag `FeatureFlags.segfault` is off (`Game.segfault_enabled == false`), **When** a practice start or a practice loadout list is built, **Then** the offered loadouts stop at the last fight that exists: `Game.practice_loadout_bosses(highest_boss, segfault_on)` caps the reached bosses at `last_fight_index(segfault_on) + 1`, and the appended "full set" is `Register.fight_start_for_boss(last_fight_index(segfault_on))` (with the cut, the full set is `[A, D, L]`, not `[A, D, L, N]`, because Null Pointer is the last fight and drops nothing). [design call] D-S77-4. With the flag on (the current default), the behaviour of AC 9-10 of 7.6 is unchanged.
19. **And** `practice_loadouts(highest_boss)` and `practice_start_index` take the same flag and are the only places the list is built; `practice_loadout_bosses` keeps its existing tests for the flag-on case.

**Human checks (not automatable; left pending, status is `done` for the automatable scope; these stay pending, see Dev Notes)**

20. **Given** the release build on the itch.io draft page, **When** a full run is played in Chrome, Firefox and Safari (latest), **Then** no crash in any of them; Safari issues are only cosmetic (H-S77-1, H-S77-2).
21. **Given** a 2020-era mid-range laptop with integrated graphics at 1280×720, **When** Segfault phase 3 is played in Chrome and Firefox, **Then** 60 FPS is sustained and live particles never exceed 300 (H-S77-4).

## Tasks / Subtasks

- [x] Task 1: Fullscreen toggle (AC 1-7)
  - [x] 1.1 `game/src/ui/screens/title/title_screen.gd`: `available[&"fullscreen"] = true`; `FULLSCREEN_TOP_Y` = 336; `fullscreen_label_rect()` added to `label_rects` (the 7.4 `debug_build` pattern); draw the row; `handle_input` branch `option == &"fullscreen"` calls the toggle; update the header comment (7.7 line).
  - [x] 1.2 Pure helper, e.g. `src/presentation/fullscreen.gd` (static): `is_fullscreen(mode)`, `toggle_mode(current) -> WindowMode`, `label_text(on)`. Calls `DisplayServer.window_set_mode` / `window_get_mode` only from the handler. Refusal: `Log.warn` once (static flag or `Game` field).
  - [x] 1.3 Pause screen: a new row at `FULLSCREEN_TOP_Y` (336) below `ASSIST_TOP_Y` (304); key `F` and pad R3 (`title_option_fullscreen`) and a click on the row call the same helper; the pause's `row_tops()` and its tests update. Confirm the row fits the 360-px base (352 bottom) on the phone-width check.
  - [x] 1.4 Confirm no other binding uses F or R3 in `project.godot [input]` and that the debug keys (F1-F11) and the browser F11 do not clash: `F` is physical 70 (KEY_F), not a function key, so `TitleScreen.is_function_key` does not swallow it.
- [x] Task 2: Automatable checks (AC 8-11)
  - [x] 2.1 `game/tools/check_build_size.sh`: sums the byte size of every file under the export directory (`find <dir> -type f`, `stat -f%z` on macOS, `stat -c%s` on Linux), prints bytes and MB, exits 0 (≤ 32 MB), 1 (over), 2 (directory missing). Run it after a release export; a plain export is enough (the custom template build is not needed for the size check).
  - [x] 2.2 GUT: particle cap burst test in `tests/unit/test_particle_pool.gd` (create the file if it does not exist, check first with `ls tests/unit`), seeded.
- [x] Task 3: Placeholder text (AC 12-13)
  - [x] 3.1 `Main._make_screen` (FIGHT branch): keep `screen.lines` only when `Debug.enabled` and not `Game.practice_run`; otherwise empty `PackedStringArray()`. One-line comment with the story id.
  - [x] 3.2 Update `tests/unit/test_placeholder_fight_keys.gd` only where it asserted the release text.
- [x] Task 4: Practice follow-ups (AC 14-19)
  - [x] 4.1 `Game.record_death`: when `practice_run`, skip `run.deaths_on_boss += 1` and the `EventBus.player_died.emit`; still `_set_flow_state(DEAD)` and set `death_frame`. Keep the log line.
  - [x] 4.2 `Game.on_player_damaged`: `stats.hits += 1` only when not `practice_run`.
  - [x] 4.3 `Game.leave_practice_to_title`: accept `flow_state` FIGHT or DEAD (not TITLE, INTRO, HARVEST, ENDING). Update its doc comment.
  - [x] 4.4 `DeadScreen`: when `Game.practice_run`, Esc (keyboard) and L3 (`Game.is_practice_leave_press`) call `Game.leave_practice_to_title(SimClock.sim_frame)` and consume the event; every other press follows the existing `is_retry_press` rule. Check the event order: `Game._input` vs `DeadScreen._unhandled_input` (the leave must win over the retry on L3; Esc is in `NON_ADVANCE_KEYS` so the screen ignores it today).
  - [x] 4.5 `Game.practice_loadout_bosses(highest_boss, segfault_on = true)`, `practice_loadouts`, `practice_start_index`, `start_practice_from_title` (reads `segfault_enabled`): cap at `last_fight_index(segfault_on)`, full set from `last_fight_index`. `_apply_practice_loadout` unchanged.
  - [x] 4.6 Tests (`tests/unit/test_practice_flow.gd`, `tests/unit/test_dead_screen.gd`, `tests/unit/test_game_flow.gd`): death in practice (no `deaths_on_boss`, no `player_died`, no save write, DEAD entered); hits not counted in practice; Esc and L3 leave from DEAD in practice; Esc on a normal DEAD still does nothing; L3 on a normal DEAD still retries; loadout lists with the flag off (`highest_boss` 1, 2, 3 with the flag off: bosses `[0,1]`, i.e. `[D,A]` then `[A,D,L]`).
- [x] Task 5: Sprint status and validation
  - [x] 5.1 Set `7-7-fullscreen-browser-matrix-and-performance: done` in `_bmad-output/implementation-artifacts/sprint-status.yaml` (Edit tool).
  - [x] 5.2 Run the GUT suite headless and `bash game/tools/check_guards.sh` before handing to review.

## Dev Notes

### What exists now (read before writing code)

- Title: `game/src/ui/screens/title/title_screen.gd`. `OPTION_ACTIONS` already maps `&"fullscreen"` to `title_option_fullscreen`; `available[&"fullscreen"]` is `false` (hidden, behaves as a plain key that starts the run; the header says "the F hotkey is hidden until its story (7.7) and starts the run"). Rows: title 160, prompt 208, `[N]` 240, `[B]` 272, `[P]` 304. `label_rect_for(text, top_y)` and `centred_x` are the helpers.
- `project.godot [input]`: `title_option_fullscreen` = physical F (70) and joypad button 8 (R3). Nothing else to bind.
- Pause: `game/src/ui/screens/pause/pause_screen.gd`. Row constants: title 24, controls 72 (6 rows, step 24), pad hint 216, resume 240, mute 272, assist 304. `row_tops()` and `row_rect()` are the pure helpers; the mute and assist rows already show the click-and-key pattern (`ASSIST_ACTION`).
- Game flow: `game/src/autoloads/game.gd`. `PAUSABLE_STATES` (INTRO, FIGHT, ENDING), `handle_pause_input`, `handle_practice_input` (FIGHT-only today), `is_practice_leave_press` (Esc or L3), `leave_practice_to_title` (FIGHT-only today), `record_death` (FIGHT-only, increments `run.deaths_on_boss`, emits `EventBus.player_died`), `on_player_damaged` (counts `stats.hits` in FIGHT), `practice_loadout_bosses` / `practice_loadouts` / `practice_start_index` (use `LAST_BOSS_INDEX` directly, ignore `segfault_enabled`), `last_fight_index(segfault_on)` and `route_after_defeat` (the cut ladder, already pure and tested).
- DEAD: `game/src/ui/screens/dead/dead_screen.gd`. `is_retry_press` (pad: any button but Start; keys: any fresh key not in `NON_ADVANCE_KEYS`; left click). `_unhandled_input` calls `Game.retry` after the screen's own check. No practice branch yet.
- FIGHT placeholder: `game/src/ui/screens/placeholder/placeholder_screen.gd` (`lines_for` returns the two rows for FIGHT; `_draw` paints a BG box behind each row). `Main._make_screen` sets `lines` to empty in practice only (7.6 review fix). Coordinator decision: the text is removed for every player-visible fight; it stays in debug builds.
- Particles: `game/src/presentation/particle_pool.gd` (`CAPACITY := 300`, fixed packed arrays, drop when full, `live_count()`, `clear()`). F10 perf overlay: `game/src/debug/perf_overlay.gd` (`particles n/300`).
- Export: `game/export_presets.cfg` preset "Web", `export_path="../build/web/index.html"`, exclude filter drops `addons/gut`, `tests/`, `tools/`. Smoke script: `game/tools/smoke_web.sh` (serves `build/web`, checks headers, prints the size, headless Chrome console check if installed).
- Godot API (checked against the Godot 4.7 class reference via ctx7, `/godotengine/godot-docs/__branch__4.7`): `DisplayServer.window_set_mode(mode: WindowMode, window_id = 0)` and `DisplayServer.window_get_mode(window_id = 0) -> WindowMode`. Use `DisplayServer.WINDOW_MODE_FULLSCREEN` and `WINDOW_MODE_WINDOWED`. Godot 4.7.2 is pinned; do not upgrade. No threads on web.

### Design calls (all `[design call]`; default chosen, change in Completion Notes if needed)

- D-S77-1: fullscreen rows at y 336 on the title (`[F] fullscreen` / `[F] windowed`) and on the pause screen (`[F] FULLSCREEN ON/OFF`). Both are clickable, both respond to F and R3. 336 + 16 = 352 fits the 360-px base.
- D-S77-2: no new telemetry. The perf run uses the existing F10 overlay (FPS, frame ms, particles, draw calls). Adding timers to the sim is forbidden anyway (SimClock only).
- D-S77-3: a practice death keeps DEAD and the retry (so the dummy can be retried in place) but counts nothing: no `deaths_on_boss`, no `player_died`, no `stats.hits`.
- D-S77-4: with `FeatureFlags.segfault` off, the practice "full set" is the last existing fight's set `[A, D, L]` (index 1), not `[A, D, L, N]`. Reason: a cut run never reaches Segfault, so the register cannot hold NULL; offering it would give an unreachable loadout.

### Architecture guardrails

- Sim folders (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) stay untouched. `src/core`, `src/combat`, `src/player`, `src/bosses` do not change. The fullscreen helper lives in `src/presentation/` or `src/ui/`.
- Fullscreen only inside an input-event handler (project-context rule). Refusal is silent for the player; `Log.warn` once.
- Presentation never writes sim state. Esc and L3 leave practice through `Game` methods only (`leave_practice_to_title`), never by setting `flow_state` from a screen.
- No `await`, Timer or Tween in sim code. Any presentation delay (none planned) only in UI.
- Input stays on InputMap actions (`title_option_fullscreen`) or the existing matched-by-code practice keys. No Shift keys.
- Game text goes to `data/text/screen_text.tres` (title rows); pause rows stay code constants (7.4/7.5 precedent).
- `check_guards.sh` must stay green; the new tool script is not a guard.

### Previous story intelligence (7.6, 7.5, 7.4, 7.3)

- 7.6 review left: (1) `PlaceholderScreen` drawn over normal fights in release (now AC 12-13); (2) the practice death path counts deaths and emits `player_died` (AC 14); (3) practice cannot leave from DEAD (AC 16); (4) the practice loadout list ignores `segfault_enabled` (AC 18). Its deferred list also notes: test gaps for the per-hit log line in practice, for the `saved_highest_boss` re-read, and for the pause rows in practice. Add tests for those only where this story touches the code.
- 7.6 `Game` keeps the practice state off the save: `practice_run`, `practice_loadouts_offered`, `practice_loadout_index`, `practice_start_frame` are cleared by `_clear_practice()`. Reuse it.
- 7.5: `title_option_fullscreen` (R3, button 8) is reserved and hidden; `PlaceholderScreen.is_pad_press` treats any pad button but Start as a press on non-title screens. DEAD and HARVEST rely on it: keep the L3 precedence in practice DEAD (AC 16).
- 7.5 deferred: pad button still held from combat can advance the first frame of DEAD/INTRO/ENDING; a stale R3 press on the title is an option now (F and R3 on the title toggle fullscreen; a held R3 at boot should not). Consider a one-frame grace only if H-S77-1 shows it.
- 7.4: the `[B]` row is the model for the new fullscreen row (click rect, key, pad button, pure label function, `label_rects` entry). The assist applies from the next attempt (D-S74-1); fullscreen applies at once.
- 7.3: `SaveService` is never written by fullscreen or by practice death/leave; `note_fight_start` is already skipped in practice.

### Git intelligence (last commits)

- `5a765f5` Story 7.6 (practice): practice flow lives in `game.gd`, `main.gd`, `title_screen.gd`, `presentation/practice_frame_counter.gd`, tests `test_practice_flow.gd`.
- `0a4924e` Story 7.5 (gamepad): pad button indices in `project.godot`, `PlaceholderScreen.is_pad_press`, pad hint row in the pause screen.
- `95a5f19` Story 7.4 (debug build assist): `[B]` row pattern, `SaveService.set_assist`.
- Pattern to keep: pure static helpers for every label rect and classifier, GUT tests for those, no node-tree dependency in the sim.

### Project Structure Notes

- New files: `game/src/presentation/fullscreen.gd` (+ `.uid` by the editor), `game/tools/check_build_size.sh`, optionally `game/tests/unit/test_particle_pool.gd` (check existing names first).
- No new InputMap actions. No new autoloads. No new scenes.
- `_bmad-output/implementation-artifacts/deferred-work.md`: add the human checklist (below) and the deferred items under "Story 7.7".

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (godot is not on PATH).
- Seed any test that uses randomness; the particle burst test uses a seeded RNG or fixed positions.
- Pure-logic tests for: fullscreen label text and rect, toggle mode mapping, DEAD practice leave vs retry classification, loadout lists with the flag on and off, death and hit counting in practice.
- Update, do not weaken: `test_title_input.gd` (the 7.6 note: the "available option keeps TITLE" check uses `fullscreen` as the hidden option; that check must move to another still-hidden option or be removed, record which), `test_pause_screen.gd` (row count and tops), `test_placeholder_fight_keys.gd` (release text).

### Human checks (pending, not automatable)

- H-S77-1 Chrome and Firefox, release web build (no `?debug`): title `F` and click and R3 toggle fullscreen, a second press returns; a full run, no crash; pause `F` toggles without resuming; a refused request (browser blocks it) leaves the game windowed with no error text.
- H-S77-2 Safari (latest): same as H-S77-1; cosmetic issues only are acceptable; record them.
- H-S77-3 Cold cache, 50 Mbps profile (Chrome DevTools throttling): the title is interactive in ≤ 10 s; the build is ≤ 32 MB (`check_build_size.sh` output recorded).
- H-S77-4 2020-era integrated-graphics laptop at 1280×720, Segfault phase 3, Chrome and Firefox: 60 FPS sustained (F10 overlay), particles never above 300.
- H-S77-5 Phone width (640 base): the `[F] fullscreen` title row and the pause `[F]` row fit without overlap (7.6 H-S76-2 style).
- H-S77-6 Practice release build: a death leaves the dummy retry working with no duck death hint; Esc and L3 leave from DEAD.

### Open questions

- None blocking. Design calls D-S77-1 to D-S77-4 are chosen above. The implementer may change them and must record the change.

## Dev Agent Record

### Agent Model Used

Claude Haiku 5.5 (claude-haiku-5-5), gds-create-story, unattended pipeline run 2026-11-14

### Debug Log References

### Completion Notes List

- Story created unattended by gds-create-story (2026-11-14). Status ready-for-dev. Design calls D-S77-1 to D-S77-4 marked above.
- Implemented by gds-dev-story (Claude Opus 5.5, 2026-11-14). D-S77-2, D-S77-3, D-S77-4 followed as written; D-S77-1 changed for the pause row (below).
- Fullscreen (AC 1-7): new static helper `Fullscreen` (`src/presentation/fullscreen.gd`): `is_fullscreen`, `toggle_mode`, `is_on`, `is_refused`, `toggle`, `check_request`, with injectable `get_mode_fn` / `set_mode_fn` seams for tests. `toggle()` is called only from the title's `handle_input` and the pause's `_input`. The web request is asynchronous (document.fullscreenElement is set after the call returns), so the refusal is read on a SceneTreeTimer 0.75 s later (UI side) and warned once per session (`Log.warn(&"display", ...)`); nothing is shown to the player. Both labels poll `Fullscreen.is_on()` in `_process`, so they follow the real mode (incl. a browser Esc exit) and do not flicker on the async request. Title row `[F] fullscreen` / `[F] windowed` at y 336 (text in `screen_text.tres`: `fullscreen_label`, `windowed_label`, validated and audited); always available, clickable. F and R3 never start the run; no other InputMap action uses F or R3 (tested); KEY_F is not a function key.
- [design call] D-S77-1 changed for the pause: y 336 would end at 352, outside the existing 16-px gutter test (bottom 344). The pause option rows now step by 24 like the controls: mute 264 (was 272), assist 288 (was 304), fullscreen 312 (`[F] FULLSCREEN ON/OFF`). The title row stays at 336 (rect ends at 360, inside the base).
- `test_title_input`: the "available option keeps TITLE" check keeps using F (it now really toggles, through a fake display) and the hidden-option check now covers `new_run` only; `test_gamepad`: R3 on the title resolves to OPTION (was START, "hidden until 7.7").
- Build size (AC 8): `game/tools/check_build_size.sh [dir]` (default `<repo>/build/web`), exits 0 / 1 (over budget or empty) / 2 (missing dir), lists every file, writes the GitHub step summary and `::error` annotations when run in Actions. [design call] D-S77-5: the budget is `WEB_SIZE_BUDGET_BYTES` or 32000000 (decimal, CI's NFR4 budget since Story 1.3 DC4), not the AC's 33554432 (32 MiB), so local and CI agree; CI's inline size step is replaced by a call to the script (same budget, same checks), so the check measures the shipped stripped-template build. Verified on dummy dirs (ok / over / empty / missing / names with spaces) and on a local stock-template export in the scratchpad (50 976 700 bytes, 44 MB side wasm, fails as expected: known "1.3 H3" waiver; nothing left in `build/`).
- Particle cap (AC 9): seeded worst-case burst test (300 x 2 in one frame, then 40 bursts per frame over 3 lifetimes) asserts `live_count() <= 300` after every spawn and a fixed slot count. Pool RNG seeded in `before_each`, the picker RNG seeded 7707.
- AC 10-11: no new telemetry (D-S77-2); cold-load estimate recorded in deferred-work.md (H-S77-3).
- Placeholder (AC 12-13): `Main.shows_fight_placeholder(debug_enabled, practice)`; FIGHT `lines` are empty unless `Debug.enabled` and not practice. The node still exists. Existing `test_main_layers` FIGHT text check still runs (debug test build); new tests for the pure rule and for a release (Debug.enabled false) FIGHT screen with no text.
- Practice follow-ups (AC 14-19): `record_death` skips `deaths_on_boss` and `player_died` in practice (still DEAD + `death_frame`); `on_player_damaged` skips `stats.hits` in practice; `leave_practice_to_title` valid from FIGHT and DEAD; `DeadScreen.is_practice_leave(event, practice)` makes Esc / L3 leave a practice DEAD at once (checked before the retry rule; `Game._input` does not consume these in DEAD); `practice_loadout_bosses` / `practice_loadouts` / `practice_start_index` take `segfault_on` (default true) and `start_practice_from_title` passes `segfault_enabled`.
- Human checks H-S77-1..6 (AC 20-21) are pending and listed in deferred-work.md "Story 7.7".
- Validation: GUT 1753/1753 passing, 145541 asserts, "All tests passed!", no pending/risky; `check_guards.sh` OK.

### File List

- .github/workflows/ci.yml
- _bmad-output/implementation-artifacts/7-7-fullscreen-browser-matrix-and-performance.md
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- game/data/text/screen_text.tres
- game/src/autoloads/game.gd
- game/src/main/main.gd
- game/src/presentation/fullscreen.gd (new)
- game/src/presentation/fullscreen.gd.uid (new)
- game/src/ui/screens/dead/dead_screen.gd
- game/src/ui/screens/pause/pause_screen.gd
- game/src/ui/screens/title/title_screen.gd
- game/src/ui/text/text_screen_text.gd
- game/tools/check_build_size.sh (new)
- game/tests/unit/test_assist.gd
- game/tests/unit/test_dead_screen.gd
- game/tests/unit/test_fullscreen.gd (new)
- game/tests/unit/test_fullscreen.gd.uid (new)
- game/tests/unit/test_gamepad.gd
- game/tests/unit/test_particle_pool.gd
- game/tests/unit/test_pause_screen.gd
- game/tests/unit/test_placeholder_fight_keys.gd
- game/tests/unit/test_practice_flow.gd
- game/tests/unit/test_title_input.gd

### Change Log

- 2026-11-14: Story 7.7 implemented (fullscreen toggle on title and pause, check_build_size.sh wired into CI, particle cap burst test, release FIGHT placeholder text removed, practice death/hits/DEAD-leave/Segfault-cut follow-ups). Human checks pending.

### Code review (2026-11-14, coordinator decisions)
- D-S77-5 approved: budget stays 32 000 000 bytes (decimal); AC 8 text updated. Pause rows re-spaced to 24 px steps approved. `F` on a retrying DEAD is fine; AC 6 reworded. AC 5 reworded (0.75 s timer).
- Fixed: stale refusal checks (double press, Esc inside the 0.75 s window) are superseded by a request id, so they no longer write a spurious warning or spend the once-per-session flag. Task 4.6 / 5.1 / status wording aligned.
- Deferred (deferred-work.md): R3 on web is not a browser user gesture; title row gutter; per-frame `is_on()` polling.
- Dismissed: set -e `&&` lists (safe), CI working dir (script path and cwd verified, executable bit 100755 committed), practice stats guard, loadout edge cases.
