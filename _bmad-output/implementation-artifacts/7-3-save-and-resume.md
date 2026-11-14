---
baseline_commit: 88e4623
---

# Story 7.3: Save and Resume

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with the chosen default (D-S73-n); the implementer follows them or records a change in Completion Notes. Scope: SaveService (AD-10) persists highest_boss, assist and muted to user://save.cfg; the run resumes at the highest boss reached; the title shows [N] new run when a save exists; storage failure is silent. The assist field is written as false and must be ready for 7.4 to hook into (SaveService.set_assist). NOT in scope: the assist toggle itself (7.4), the gamepad Select binding (7.5), the practice option (7.6), the mute toggle UI (see D-S73-7), browser checks (human, see the checklist). -->

## Story

As a returning player,
I want to resume at the highest boss I reached,
so that closing the tab doesn't cost me my progress.

**Requirements:** FR53, NFR12 (and FR47 for the title options, FR54/FR55 context). Closes the GFR55 gap in the readiness report (full HP between fights is verified here, see AC 6).
Additional: AD-10 (`SaveService`: `ConfigFile` at `user://save.cfg`, `version`, `highest_boss`, `assist`; write on fight start and assist toggle; read at boot; any failure means in-memory only), D-048 (title: option hotkeys act on their option only, any other key or click starts), D-S73 decisions below.

Depends on: 1.4 (title press-to-start, `TitleScreen.classify` / `resolve` / `available`), 1.6 (`Game.start_run_from_title`, `RunState`), 2.9 (retry, fight-start snapshot), 3.8 (`finish_harvest`, Harvest -> next Fight), 6.7 (Intro gate), 7.1 (AudioManager mute and music plumbing must not change), 7.2 (`AudioManager` pool, unaffected). Window: Nov 26–29 (Epic 7). Before 7.4 (assist toggle, which writes through `SaveService.set_assist`).

## Acceptance Criteria

**SaveService and the save file (FR53, AD-10)**

1. **Given** `SaveService` (`game/src/autoloads/save_service.gd`, autoload `SaveService`), **When** the game boots, **Then** it reads `user://save.cfg` once. A missing file is a fresh save (`highest_boss = 1`, `assist = false`, `muted = false`) with no warning. A file with a `version` other than the current `VERSION = 1`, or unreadable values, is treated as a fresh save (no crash, one `Log.warn`). `highest_boss` is clamped to `1..3` (`Game.LAST_BOSS_INDEX + 1`).
2. **And Given** a fight starts (a `Game` FIGHT entry that is not a retry and not a debug jump), **When** the fight begins, **Then** `SaveService` sets `highest_boss = max(highest_boss, boss_index + 1)` and writes `user://save.cfg` with `version`, `highest_boss`, `assist` and `muted`. A retry does not write (nothing changed); a debug jump does not write (D-S73-3).
3. **And** `SaveService.set_assist(on: bool)` sets `assist` and writes the file at once. It is the only API 7.4 needs; 7.4 must not write the file itself. Until 7.4 it is never called, so `assist` stays `false` in every save.
4. **And** `muted` is written from `AudioManager.is_master_muted()` on every save, and applied with `AudioManager.set_master_muted()` once at boot after the read (no UI change; see D-S73-7).
5. **Given** storage fails (itch.io iframe, private mode, `ConfigFile.load` or `save` returns an error other than "file not found"), **When** reading or writing, **Then** exactly one `Log.warn` is written for the session (`storage_warned` flag), the game runs with the in-memory values, and the player sees nothing. No call path raises or blocks. Tests cover a write to an unwritable path.

**Resume and title (FR53, FR47)**

6. **Given** a save with `highest_boss = 2`, **When** I press any key (or click) on the title, **Then** the run starts with `Game.resume_run_from_title(frame)`: `first_input_frame` is set (the 30-s clock starts), `run = RunState.new()` with `start_boss(1)` (Boss 2), `stats = RunStats.new()`, the Intro is skipped (D-S73-2) and the flow goes straight to FIGHT with the Boss 2 fight-start register, full HP (`Arena` already calls `health.reset_for_fight()` on every fight start; the test must prove it) and reset cooldowns. The resumed FIGHT entry triggers the AC 2 save (no change in value).
7. **And** the resume index is capped by the Segfault cut: `boss_index = mini(highest_boss - 1, last_fight_index(segfault_enabled))` (D-S73-4). With the Segfault fight cut, a save with `highest_boss = 3` resumes at the last enabled fight.
8. **Given** a save with `highest_boss > 1`, **When** the title shows, **Then** the title shows `[N] new run` (option `new_run`, `TitleScreen.available[&"new_run"] = true`, label text from `data/text/screen_text.tres`, see D-S73-5). With `highest_boss = 1` (or no save) the option stays hidden and `N` is a plain start key, as today.
9. **And** pressing `N` (or clicking the label) with the option visible resets `highest_boss = 1`, writes the file, and starts a new run from the Intro (`Game.start_run_from_title`, which keeps the Intro without skipping it, D-048). Any other key or click on the title resumes (AC 6) and never resets the save. The title input never counts as an Intro skip (6.7 gate unchanged).
10. **And** the title input still unlocks audio first (1.4 DC8), and an option key or click while the option is hidden acts as a start key (the existing `TitleScreen.resolve` rule).

**Robustness and the rest of the flow**

11. **And** `highest_boss` is not written from `Game.run` in DEAD, HARVEST or ENDING. Harvest -> next Fight (3.8) is a FIGHT entry and writes through AC 2. A new run (`finish_ending`, `debug_jump`) never lowers `highest_boss`: the save only ever moves forward except through the title `N` (AC 9).
12. **And** nothing in the sim tick touches the file system: the write happens in `Game._set_flow_state` (presentation-side, after the state change), never inside `SimContext` or `SimClock`. The 1.7 pause rules, the 6.8 stats and the 2.9 retry are unchanged.
13. **And** `TitleScreen` shows no new option before the first input and no audio change (7.1 and 7.2 tests stay green). No new bus effects.

## Tasks / Subtasks

- [x] Task 1: SaveService (AC 1–5, 12)
  - [x] 1.1 Rewrite `game/src/autoloads/save_service.gd` (currently a stub). Constants: `PATH := "user://save.cfg"`, `VERSION := 1`, section `"save"`. State: `highest_boss: int`, `assist: bool`, `muted: bool`, `storage_warned: bool`, `path: String` (a test seam, defaults to `PATH`; tests set a scratch path under `user://`).
  - [x] 1.2 Pure static helpers for the tests: `static func clamp_highest(v: Variant) -> int`, `static func parse(cfg: ConfigFile) -> Dictionary` (returns fresh defaults on a bad version), `static func to_config(...) -> ConfigFile`. No I/O in the helpers.
  - [x] 1.3 `load_save() -> void` (called from `_ready`), `save() -> bool`, `note_fight_start(boss_index: int) -> void`, `reset_run_progress() -> void` (sets `highest_boss = 1` and saves), `set_assist(on: bool) -> void`. Every error path goes through one `_warn_once(msg)`.
  - [x] 1.4 `_ready`: `load_save()`, then `AudioManager.set_master_muted(muted)`. Check the autoload order in `project.godot` so `AudioManager` exists before `SaveService._ready` (or apply the mute in `AudioManager` on its own `_ready`; record which).
- [x] Task 2: Game integration (AC 2, 6, 7, 11, 12)
  - [x] 2.1 `Game._set_flow_state(FIGHT)`: when `not _retrying` and `not stats.debug_jumped`, call `SaveService.note_fight_start(run.boss_index)`. Keep the existing order (`run.fight_start_ring` capture, `_begin_fight`).
  - [x] 2.2 `Game.resume_run_from_title(frame: int) -> void` (valid only from TITLE, same guard as `start_run_from_title`): sets `first_input_frame`, `run = RunState.new()`, `run.start_boss(index)` with the AC 7 cap, `stats = RunStats.new()`, `_set_flow_state(FlowState.FIGHT)`. Add a static pure `resume_index(highest_boss: int, segfault_on: bool) -> int` for the test.
  - [x] 2.3 `Game.start_new_run_from_title` path: `SaveService.reset_run_progress()` then `start_run_from_title(frame)` (the N option).
- [x] Task 3: Title (AC 8–10)
  - [x] 3.1 `TitleScreen._ready` (or first `_process`): `available[&"new_run"] = SaveService.highest_boss > 1`. Remember the choice is read once per title show.
  - [x] 3.2 `handle_input`: on `Action.OPTION` with `new_run` available, call `AudioManager.unlock()`, `Game.start_new_run_from_title(...)` (or `resume` when the action is a START); keep `_started` and `queue_free` as today.
  - [x] 3.3 Draw the label: a `new_run` label rect (canvas space, under the prompt) in `_draw`, with the text from `TextScreenText` (new field `new_run_label`, value `[N] new run` rendered as the glyph font allows, ASCII only). Fill `label_rects[&"new_run"]` only while available.
  - [x] 3.4 Confirm `project.godot` `title_option_new_run` (key N, physical 78) is the action used; keep the `OPTION_ACTIONS` map.
  - [x] 3.5 Resume path: the Intro is skipped. The title's `handle_input` calls `Game.resume_run_from_title(SimClock.sim_frame)` instead of `start_run_from_title` when `SaveService.highest_boss > 1` and the action is START.
- [x] Task 4: Tests (AC 1–13)
  - [x] 4.1 `game/tests/unit/test_save_service.gd`: defaults on missing file; round trip into a scratch path (`user://test_save_<name>.cfg`, deleted after); bad version -> defaults and one warn; clamp of `highest_boss` (0, 9, "x"); `set_assist` writes `assist`; unwritable path -> `storage_warned` set once, `save()` returns false, no exception. Use the pure helpers for most cases.
  - [x] 4.2 `game/tests/unit/test_game_flow.gd` (or the existing flow test): FIGHT entry (non-retry) raises `highest_boss` to `boss_index + 1`; retry does not write; debug jump does not write; `resume_run_from_title` lands in FIGHT with `boss_index == 1`, no INTRO, `first_input_frame >= 0`; `resume_index` caps with Segfault cut; `finish_harvest` to Boss 3 saves 3.
  - [x] 4.3 Title tests in `test_title_screen.gd`: `[N]` available only when `highest_boss > 1`; `N` resets to 1 and goes to INTRO; any other key with a save resumes at Boss 2; `N` with no save is a start key; click on the label rect is the same as `N`.
  - [x] 4.4 Full HP: in the resume test, the health after `Arena` setup equals `max_hp` (use the existing arena test helpers, see `test_arena_player.gd`).
  - [x] 4.5 Seam rule: no test writes the real `user://save.cfg`. Set `SaveService.path` in `before_each` and delete the scratch file in `after_each`. Grep the test tree for any test that reaches FIGHT without the seam and fix it.
  - [x] 4.6 Run `game/tools/check_guards.sh` and the full GUT suite headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game ...` (see the project README for the GUT command).
- [x] Task 5: Records
  - [x] 5.1 Update `_bmad-output/implementation-artifacts/deferred-work.md`: the save file format (`version` 1, keys), the human checks, and any review notes.
  - [x] 5.2 Note the save format in the README only if 7.9 asks for it (not here).

## Dev Notes

### What exists now (read before writing code)

- `game/src/autoloads/save_service.gd` is a stub (`extends Node`, one doc line). Register stays as `SaveService="*res://src/autoloads/save_service.gd"` in `project.godot` (line ~31).
- `Game` (`game/src/autoloads/game.gd`): `start_run_from_title(frame)` (line ~198) sets the 30-s clock, `RunState.new()`, `stats`, and goes to INTRO. `finish_intro` calls `run.start_boss(0)` and goes to FIGHT. `_set_flow_state` (line ~411) is the only writer of `flow_state`; a FIGHT entry captures the fight-start ring unless `_retrying`. `_begin_fight` (line ~487) draws the fight seed. `LAST_BOSS_INDEX := 2`, `last_fight_index(segfault_on)` and `route_after_defeat` are static and already tested (5.6).
- `RunState` (`game/src/core/run_state.gd`): `boss_index`, `start_boss(index)` (resets `deaths_on_boss`), fight-start ring.
- `TitleScreen` (`game/src/ui/screens/title/title_screen.gd`): `available` dict (all false until their stories; `new_run` is the 7.3 option), `OPTION_ACTIONS` (InputMap actions in `project.godot` lines ~49–66), `label_rects`, `classify` / `option_of` / `resolve` (a hidden option acts as START), `handle_input` (unlock first, `_started` guard, `Game.start_run_from_title`, `AudioManager.play_test_sfx`, `queue_free`). `_draw` draws the title and the prompt with `GlyphFont` only.
- Game text lives in `game/data/text/screen_text.tres` (class `TextScreenText`, `game/src/ui/text/text_screen_text.gd`, Story 6.9 audit). The title line and prompt come from it.
- `Arena` resets the player, actions, health (`health.reset_for_fight()`, line ~172), breakpoint and watch skills and the boss on every fight start. That is the full-HP and cooldown reset of AC 6; prove it in a test (4.4).
- `AudioManager` (`game/src/autoloads/audio_manager.gd`): `set_master_muted`, `is_master_muted`, `unlock`, `play_test_sfx`. Music and the SFX pool (7.1, 7.2) must not change.
- `Log` (`game/src/autoloads/log.gd`): `Log.warn(tag, msg)` (push_warning). Use tag `&"save"`.
- The readiness report (`_bmad-output/planning-artifacts/implementation-readiness-report-2026-11-06.md`, lines ~120, 242, 289, 423) asks for: save/resume with silent fallback, full HP between fights, and "Continue / New run" when a save exists.

### Design calls (all `[design call]`, default chosen; change in Completion Notes if needed)

- **D-S73-1 [design call]** The file is `ConfigFile` at `user://save.cfg`, section `save`, keys `version` (int, 1), `highest_boss` (int, 1..3), `assist` (bool, false), `muted` (bool, false). Text, human-readable, no encryption (it is not a secret).
- **D-S73-2 [design call]** Resume skips the Intro. The Intro is the opening of the run (D-040); a resumed run goes straight to the boss fight, with the 30-s first-shift clock started by the title input. The epic's "(after the Intro or skipping it)" is read as "skipping it".
- **D-S73-3 [design call]** Writes happen on non-retry FIGHT entries only; debug-jumped runs (`stats.debug_jumped`) never write, so a debug jump cannot raise or lower the save. A retry changes nothing and does not write.
- **D-S73-4 [design call]** Resume index = `mini(highest_boss - 1, last_fight_index(segfault_enabled))`, so the cut Segfault fight (cut ladder #4) is never resumed into. The save itself keeps `highest_boss = 3` (the value the player earned); only the resume is capped.
- **D-S73-5 [design call]** The option label reads `[N] new run` (the epic's wording), drawn with `GlyphFont` in the title's lower area, below the prompt (`PROMPT_TOP_Y` 208, label at 240 unless the layout test says otherwise). The text is a field of `TextScreenText` (`new_run_label`), so the 6.9 audit covers it. The label is clickable only while available.
- **D-S73-6 [design call]** `save()` returns `bool` and is idempotent; a write that fails logs once per session (`storage_warned`) and then stays silent, so an iframe with blocked storage produces one line in the log and nothing else. Writes are not retried.
- **D-S73-7 [design call] — OVERTURNED by the coordinator (2026-11-14):** the `[M]` mute toggle already exists on the pause screen (`game/src/ui/screens/pause/pause_screen.gd`, Master bus; epics.md "persisted from 7.3"). So toggling mute writes `muted` through `SaveService.set_muted`, and the saved value is applied to the Master bus at boot (`SaveService._ready`). The original text follows for the record. ~~`muted` is persisted and applied at boot, but this story adds no mute toggle or key. The mute UI belongs to its own story (the epic's line about "mute persisted from 7.3" is read as "the value is kept"); until it exists `muted` stays `false` in practice. If the mute story is already built at implementation time, wire its toggle to `SaveService.save()` and record it here.~~
- **D-S73-8 [design call]** A version other than 1 (newer or older) or a corrupt value resets to defaults and logs one warn; the file is overwritten on the next save. No migration code (there is only version 1).
- **D-S73-9 [design call]** The save never lowers `highest_boss` except through the title `N` option (AC 9). A Harvest or Fight entry can only raise it; debug jumps and the Ending do not write.
- **D-S73-10 [design call]** Resumed runs are real runs for the Ending: `stats` starts clean at resume, so the clear time counts from the resume (not from the first ever start). The clear card does not show "resumed"; the Ending `debug_jumped` rule does not apply to resumes.

### Architecture guardrails

- Presentation-side I/O only: `SaveService` is an autoload, called from `Game` (after the flow change) and `TitleScreen`. Nothing in `SimContext`, `SimClock` or the sim tick reads or writes the file (AD-10, D-S73 AC 12).
- Storage access is wrapped: every `ConfigFile.load` and `save` return code is checked; no `push_error` on a missing or blocked file (the NFR12 silent fallback). Use `Log.warn` only, once.
- Web: `user://` maps to IndexedDB in the browser; itch.io iframes may refuse it. The fallback is the in-memory values, which is the AC 5 behaviour.
- Game text (the `[N] new run` label) goes in `data/text/screen_text.tres` via `TextScreenText`, ASCII only (6.9).
- Keep `check_guards.sh` green (no new guard expected; check it does not flag `user://`).

### Project Structure Notes

- Changed: `game/src/autoloads/save_service.gd`, `game/src/autoloads/game.gd`, `game/src/ui/screens/title/title_screen.gd`, `game/src/ui/text/text_screen_text.gd` (one field), `game/data/text/screen_text.tres` (one value).
- New tests: `game/tests/unit/test_save_service.gd` (+ `.uid` after the editor run), extra cases in `test_game_flow` / `test_title_screen` (use the existing file if present).
- No new scene, no new autoload (SaveService exists).

### Previous story intelligence (7.2, 7.1, 6.9)

- 7.1 and 7.2 kept file and track names fixed so later changes are file swaps; the same spirit applies here: the save keys are fixed now (D-S73-1) so 7.4 and 7.6 can add fields without a migration.
- 7.2 review (deferred) noted that SFX must not touch the Music players; the title SFX path (`play_test_sfx`) stays as is.
- 6.8 `RunStats` / `ending_summary` are reset on every new run; a resumed run gets a fresh `RunStats` (D-S73-10).
- 6.9 text audit: the title prompt and screen text are audited data; the new label is added there, not as a literal in code.
- Review 1.4 / 1.6 lessons already in code: `TitleScreen` never starts twice (`_started`), a hidden option acts as start, function keys never start the run. Keep all three.

### Human checks (not automated; the story stays `review` until they are done)

- H-S73-1 Chrome and Firefox (web build): play to Boss 2, reload the tab, press a key: the run starts at Boss 2 with full HP and no Intro; `[N] new run` is visible; `N` resets to the Intro.
- H-S73-2 itch.io iframe (or a private window): the game runs, no visible error, the console shows one `save` warn at most.
- H-S73-3 Safari: same as H-S73-1 (IndexedDB backed `user://`).

## Tasks check

- Acceptance tests are the GUT tests in Task 4. A human check (H-S73-1..3) is not a substitute for them.

## Dev Agent Record

### Agent Model Used

Claude (gds-create-story, unattended pipeline run, 2026-11-14)

### Debug Log References

- First full GUT run: Main-based integration tests (Intro, Harvest, Ending flows) failed because fights played by earlier tests raised the in-memory `SaveService.highest_boss`, so a later title resumed at Boss 2+ instead of playing the Intro. Fixed with the `track_fights` seam (off under GUT). Second: `ConfigFile.get_value` with a `null` default raises an engine error; `parse` checks `has_section_key` first.

### Completion Notes List

- Story created unattended. All judgment calls are D-S73-1..10 (`[design call]`). No blocker for the developer.
- Pre-existing facts verified while writing: `Arena` resets health and cooldowns on fight start (line ~163–181); `title_option_new_run` is bound to N in `project.godot`; `SaveService` is a stub.
- Implemented (dev-story, 2026-11-14): `SaveService` (pure `clamp_highest` / `defaults` / `parse` / `to_config`; `load_save`, `save`, `note_fight_start`, `reset_run_progress`, `set_assist`, `set_muted`, `has_progress`; one `_warn_once` per session). Mute applied in `SaveService._ready` (AudioManager is registered before SaveService in `project.godot`, Task 1.4).
- `Game`: `resume_run_from_title(frame, highest_boss = -1)` (-1 reads SaveService; skips the Intro, fresh RunState/RunStats, FIGHT), `start_new_run_from_title(frame)` (reset then the normal Intro start), static `resume_index` (clamped to `0..last_fight_index`). The write sits in `_set_flow_state` after `_begin_fight`, guarded by `not _retrying and not stats.debug_jumped`.
- `TitleScreen`: `_ready` reads `SaveService.highest_boss` once (`set_saved_progress`), shows `[N] new run` at y 240 (`NEW_RUN_TOP_Y`) from `TextScreenText.new_run_label`, label rect clickable only while shown. START resumes when the save is past Boss 1; the `new_run` option resets and starts from the Intro; the `_started` guard, unlock-first and hidden-option-as-start rules are unchanged.
- D-S73-7 overturned (see Design calls): `PauseScreen._input` calls `SaveService.set_muted(...)` after the toggle.
- [design call] D-S73-11: AC 4 says `muted` is written from `AudioManager.is_master_muted()` on every save; implemented instead as a `muted` field kept by `set_muted` (the pause toggle is the only writer of the Master mute besides boot) so `save()` has no AudioManager dependency. Same file content in practice.
- [design call] D-S73-12: test isolation. Under GUT (detected from the main-loop script path or an `addons/gut/` command-line arg, AND only when `OS.has_feature("editor")`, so an export template or web build can never disable saving) the autoload runs with `path = ""` (in-memory only, never reads or writes `user://save.cfg`) and `track_fights = false` (a fight in any test leaves `highest_boss` at 1, so Main-based tests keep getting the Intro). `test_save_service.gd` enables tracking and a scratch path per test and restores them. Verified after the run: no `save.cfg` or scratch file under the Godot user dir.
- [design call] D-S73-13: `resume_run_from_title` takes an optional `highest_boss` so the title passes the value it read on `_ready` (the "read once per title show" rule) and tests stay pure.
- Tests: `game/tests/unit/test_save_service.gd` (34 tests: parse/clamp/round trip/bad version/unwritable path/in-memory, Game write rules incl. retry, debug jump, harvest to Boss 3, resume + Segfault cap, new run, full HP on the resumed fight via Main/Arena, title option/label/click/resume/N-without-save/no double start, pause mute persistence). Full GUT: 1657/1657 passing; `check_guards.sh` OK.
- Human checks H-S73-1..3 remain (recorded in deferred-work.md).

### File List

- `_bmad-output/implementation-artifacts/7-3-save-and-resume.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (7-3 set to review)
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `game/src/autoloads/save_service.gd`
- `game/src/autoloads/game.gd`
- `game/src/ui/screens/title/title_screen.gd`
- `game/src/ui/screens/pause/pause_screen.gd`
- `game/src/ui/text/text_screen_text.gd`
- `game/data/text/screen_text.tres`
- `game/tests/unit/test_save_service.gd` (new)
- `game/tests/unit/test_save_service.gd.uid` (new)

### Change Log

- 2026-11-14: Story 7.3 implemented (SaveService, resume at highest boss, `[N] new run`, mute persisted via the pause toggle per the D-S73-7 overturn). Status -> review.

- Coordinator decisions (2026-11-14): D-S73-11..13 approved; the D-S73-7 overturn stands. Review hardened D-S73-12 with the editor-feature guard.

### Review Findings
- [x] [Review][Patch] GUT detection could in theory disable saving in a build; now requires `OS.has_feature("editor")` [save_service.gd]
- [x] [Review][Patch] `parse` rejected a float `highest_boss` that `clamp_highest` accepts; now tolerated [save_service.gd]
- [x] [Review][Patch] `note_fight_start` skips the write when `highest_boss` is unchanged [save_service.gd]
- [x] [Review][Defer] Cleared run resumes at final boss, overwrite of unknown version, all-or-nothing parse, in-place write, web flush/mute indicator, no [N] confirm — deferred (see deferred-work.md)
- Dismissed as noise: AC 4 cache vs AudioManager (D-S73-11 approved), test placement, AC 13 wording, stats null (non-null initialiser), key-repeat writes, MAX_BOSS literal (test-guarded).
