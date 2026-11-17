---
baseline_commit: fd1cd19
---

# Story 9.5: Test Isolation Hardening

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from story/9-4 HEAD fd1cd19 (stacked; PR base story/9-4-doc-consistency). Sources: Epic 9 in epics.md (Story 9.5 ACs, lines ~1864-1886), the brief epic9-brief.md (story 5 and the coordinator note on the 9.1 review deferral), the triage epic9-triage.md (its "9-4-test-isolation-hardening" proposal, now 9.5), deferred-work.md items 91, 108, 299, 320, the 9.1 review deferral (line ~625) and the 9.3 review deferral (line ~639). Nothing was committed. Test infrastructure only; the one production edit is an unused test seam in SimClock (D-S95-2). -->

## Story

As a developer,
I want the GUT suite to reset shared autoload state centrally and to stop leaking hit-stop, Defs and EventBus state between suites,
so that the suite passes in any order and a flaky test does not break CI again (#66).

**Requirements:** deferred-work.md 91 (1.4), 108 (1.6), 299 (3.8), 320 (4.2); the 9.1 review deferral (line ~625: six suites save/restore `Game.title_entry_frame` by hand, `Game.reset_for_tests()` and `SimClock.reset_for_tests()` to be folded in here); the 9.3 review deferral (line ~639: `test_live_pending_follows_the_attempt_copy` restores inline); triage 9-4.

## Acceptance Criteria

1. **Given** any GUT run **When** a test or a suite starts **Then** a single central helper has already reset the autoload globals listed in Dev Notes (Game, SaveService, AudioManager, SimClock, Debug, Fullscreen) to their boot values, so no suite needs its own save/restore for those fields (9.1 review deferral).
2. **Given** the GUT mechanism **When** it is wired **Then** it is a GUT pre-run hook (`pre_run_script`) set in `game/.gutconfig.json`, with the hook script under `game/tests/support/`; the CI command in `.github/workflows/ci.yml` is unchanged and still picks the hook up (verified by a log line from the hook in the CI-style run). No GUT addon file is edited.
3. **Given** the six suites that save and restore `Game.title_entry_frame` by hand (test_gamepad, test_practice_flow, test_fullscreen, test_save_service, test_ending_flow, test_null_pointer_fight) **When** this story closes **Then** those save and restore lines are gone; test-local setup lines (e.g. `Game.title_entry_frame = -1` where a test needs a boot title) stay.
4. **Given** `test_live_pending_follows_the_attempt_copy` (test_pause_screen.gd) **When** it runs **Then** it no longer restores `Game.flow_state`, `Game.run`, `SaveService.assist` or `SaveService.path` inline; those saves move to `before_each` and `after_each` (or are covered by the central reset) and the test body only sets up and asserts (9.3 review deferral).
5. **Given** hit-stop leaks across suites (299) **When** a suite needs a clean SimClock **Then** it calls one shared helper that clears `_pending_hitstop`, `_swallow_presses` and `hitstop_frames` through a `SimClock.reset_for_tests()` seam that SimClock owns; no test writes `SimClock._pending_hitstop` or `SimClock.set(&"_pending_hitstop", ...)` any more (grep verified). The seam is never called by shipped code, so production behaviour is unchanged (D-S95-2).
6. **Given** `test_audio_manager.gd` (91) **When** it checks buses **Then** the exact `bus_count == 4` literal is replaced by a comparison with `bus_count` of `res://default_bus_layout.tres`, and the named buses are still asserted; any AudioManager `_unlocked` state a test needs is set in `before_each` and reset by the central helper, never restored inline before an assertion.
7. **Given** `test_combo_def_validation_additions` (test_echo_dash.gd, item 320) **When** it runs **Then** it works on a `duplicate()` of `Defs.SLASH_1` (and of the BIT_NULL solo swap at lines 186-190, the same shared-resource pattern) and never mutates a shared `Defs` resource; `Defs.SLASH_1.startup_frames` is unchanged after the test.
8. **Given** the EventBus (108) **When** a test connects to `EventBus` signals **Then** every such connection is removed in `after_each` or its target is an autofreed node that is freed in the same test; the list of audited tests is written in the Dev Agent Record. No generic EventBus reset is added.
9. **Given** the change set **When** it is verified **Then** `git diff --stat` touches no file under `game/src/` except `game/src/autoloads/sim_clock.gd` (the seam), `game/tools/check_guards.sh` passes, and the production code paths are byte-identical apart from that seam.
10. **Given** the full GUT suite **When** it runs in CI order, in reverse collection order and in shuffled order (`shuffle:<seed>`, seed printed) **Then** all three runs report "All tests passed!" with no SCRIPT ERROR, Parse Error or failure marker (the brief's process rule and epic AC "both pass").
11. **Given** deferred-work.md **When** this story closes **Then** items 91, 108, 299 and 320, the 9.1 review deferral (line ~625) and the 9.3 review deferral (line ~639) each carry "Resolved in Story 9.5 (D-S95-n)" after their original text; no line is deleted and no HUMAN item is ticked.
12. **Given** sprint-status.yaml and this file **When** the create phase ends **Then** the 9-5 key reads `ready-for-dev` (Edit tool) and the story Status reads `ready-for-dev`. Nothing is committed in this phase.

## Tasks / Subtasks

- [x] Task 1: the central helper and GUT hook (AC 1, 2)
  - [x] 1.1 Create `game/tests/support/isolation.gd` (`class_name TestIsolation`, `extends RefCounted`): `static func reset_shared_state()` that restores every item in Dev Notes "Reset list" (primitives from a boot snapshot, objects as fresh instances), then calls `SimClock.reset_for_tests()` and `AudioManager.set_master_muted(SaveService.muted)` so the master bus matches the reset.
  - [x] 1.2 Create `game/tests/support/gut_isolation_hook.gd` (`extends GutHookScript`, see `game/addons/gut/hook_script.gd`). `run()` takes the boot snapshot first (before any suite), connects `gut.start_script` and `gut.end_test` to `TestIsolation.reset_shared_state` (the lambda ignores the signal argument), then reads `OS.get_environment("WILDSHIFT_GUT_ORDER")`: `ci` (default, no change), `reverse` (reverse `gut.get_test_collector().scripts` in place), `shuffle:<int>` (`seed(int)` then shuffle the same array; print `GUT order: shuffle seed N` so a failure can be replayed).
  - [x] 1.3 Create `game/.gutconfig.json` with only `{"pre_run_script": "res://tests/support/gut_isolation_hook.gd"}` (GUT 9.6.1 reads `res://.gutconfig.json` by default, `gut_config.gd` line 20). Do not add `dirs`, `include_subdirs` or `log_level`: the CI command stays the single source of truth.
  - [x] 1.4 Confirm `tests/support/` files are not collected as tests (GUT collects only `test_*.gd`; check `GutUtils` prefix) and that the `-gdir=res://tests -ginclude_subdirs` run still reports the same test count as before this story (record the number before and after).
- [x] Task 2: SimClock seam (AC 5, 9)
  - [x] 2.1 `game/src/autoloads/sim_clock.gd`: add `func reset_for_tests() -> void` that sets `_pending_hitstop = 0`, `_swallow_presses = false`, `hitstop_frames = 0`, `sim_frame = 0`, `poll_frame = 0`, `paused = false` and `breakpoint_gate_active = watch_gate_active = false`, with a `## Test seam (Story 9.5): called only by tests/support, never by shipped code.` comment. Do not touch `_systems`, `buffer`, `ctx` or `recorder` here (see O2).
  - [x] 2.2 Replace every `SimClock.set(&"_pending_hitstop", 0)`, `SimClock._pending_hitstop = 0` and `SimClock.hitstop_frames = 0` in tests with the reset helper call or delete the line when the central reset already covers it. Known sites: test_game_flow, test_metrics_flow, test_echo_action, test_segfault_body, test_infinite_loop_body, test_null_pointer_attacks, test_boss_fallback, test_echo_dash, test_watch_fallback, test_null_pointer_body, test_combat_resolver, test_camera_shake. Re-grep for the full list.
- [x] Task 3: remove hand-written title-entry restores (AC 3)
  - [x] 3.1 test_gamepad.gd, test_practice_flow.gd, test_fullscreen.gd, test_save_service.gd, test_ending_flow.gd, test_null_pointer_fight.gd: remove `_saved_title_entry` capture and the restore line. Keep any `Game.title_entry_frame = -1` that a test uses to start on a boot title, and keep the `title_entry_frame = N` lines that set a gate.
  - [x] 3.2 test_tutorial_flow.gd and test_title_entry_gate.gd build their own `_saved_game` key lists: drop `title_entry_frame` from those lists only if the central reset is the sole restorer (their other keys stay).
- [x] Task 4: the 9.3 inline restore (AC 4)
  - [x] 4.1 test_pause_screen.gd: move the `saved_flow`, `saved_run`, `saved_assist`, `saved_path` captures into `before_each` (as members) and the restores into `after_each`; the test keeps the `SaveService.path = ""` and `Game.run = RunState.new()` setup, which may stay in the test body.
- [x] Task 5: audio and EventBus (AC 6, 8)
  - [x] 5.1 test_audio_manager.gd `test_buses_exist`: keep the four named `get_bus_index` checks; replace `assert_eq(AudioServer.bus_count, 4)` with `assert_eq(AudioServer.bus_count, load("res://default_bus_layout.tres").bus_count)` (verify the property name in the Godot 4 API before writing).
  - [x] 5.2 Set `AudioManager._unlocked` only in `before_each` where a suite needs it locked (test_tutorial_screen, test_assist, test_gamepad, test_title_input already do this); confirm the central reset restores the boot value so their inline restores can go.
  - [x] 5.3 Grep `EventBus\.[a-z_]*\.connect` in `game/tests`, classify each connection (freed-with-test node, or lambda on a long-lived object), and fix any that outlive their test. Record the audited list in the Dev Agent Record.
- [x] Task 6: Defs copies (AC 7)
  - [x] 6.1 test_echo_dash.gd `test_combo_def_validation_additions` (lines 182-204): use `var slash: ActionDef = Defs.SLASH_1.duplicate()` and make the combo under test use it (check how `ComboDef` resolves its first solo: if through `Defs.BIT_ATTACK.solo_action`, swap that bit's solo with the duplicate the same way the null_bit block does, using a duplicate of the BitDef too). The `startup = 8` edit then never touches the shipped resource.
  - [x] 6.2 Same pattern for the BIT_NULL solo swap (lines 186-190): duplicate the bit, not the shared resource.
- [x] Task 7: verification (AC 9, 10, 11, 12)
  - [x] 7.1 Godot: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import` once, then the CI command from `.github/workflows/ci.yml` lines 86-114 (`-s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), grep the log for the markers listed in the CI step.
  - [x] 7.2 Same run with `WILDSHIFT_GUT_ORDER=reverse`, then `WILDSHIFT_GUT_ORDER=shuffle:<seed>` for two seeds (record the seeds). All three must pass.
  - [x] 7.3 `bash game/tools/check_guards.sh` passes. `git diff --stat` shows only the listed test files, the new `tests/support` files, `.gutconfig.json`, `sim_clock.gd`, the deferred-work and story files, sprint-status.
  - [x] 7.4 Annotate deferred-work items per AC 11 with Edit. Set sprint-status `9-5-test-isolation-hardening: ready-for-dev` (Edit tool). Do not commit.

## Dev Notes

### Verified facts (read on 2026-11-17, worktree story/9-5 at fd1cd19)

- GUT is 9.6.1 (`game/addons/gut/plugin.cfg`). CI runs `"$GODOT_BIN" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (`.github/workflows/ci.yml` line 91). No `.gutconfig.json` exists today.
- Hook API in the vendored source: `gut.gd` `pre_run_script` runs after collection and before `start_run` (lines ~762-765), and the run loop iterates `_test_collector.scripts` in index order (lines ~774-791). `gut.start_script` (line 791 region), `gut.end_test` (line 844) and `gut.end_script` (line 878) are signals. `GutHookScript` (`addons/gut/hook_script.gd`) requires a `run()` method and gives `gut`. `gut_config.gd` line 20 loads `res://.gutconfig.json` by default. GUT 9.6.1 has no built-in shuffle; the reverse and shuffle orders are done in the hook.
- `end_test` is emitted after `after_each` (gut.gd `_run_test`, lines ~612-646), so a reset on `end_test` runs after each test's own teardown and before the next `before_each`.
- Only three suites use `before_all` (test_infinite_loop_body, test_text_triggers, test_ending_flow), and none of them keeps autoload state across tests, so a reset per test is safe.
- Autoload state written by tests (public, from the grep): `Game`: flow_state, first_input_frame, title_entry_frame, intro_start_frame, run, death_frame, harvest_start_frame, ending_start_frame, stats, ending_summary, practice_run, practice_loadouts_offered, practice_loadout_index, practice_start_frame, tutorial_routing_enabled, tutorial_replay, segfault_enabled. `SaveService`: highest_boss, assist, muted, tutorial_done, completed, track_fights, path, storage_warned. `AudioManager`: `_unlocked` (set via `set("_unlocked", false)` in test_assist, test_gamepad, test_tutorial_screen, test_title_input), master mute (`set_master_muted`). `SimClock`: sim_frame, paused, hitstop_frames, input_source, `_pending_hitstop`, `_swallow_presses`. `Debug.enabled` (test_save_service). `Fullscreen.get_mode_fn` / `set_mode_fn` (static Callables, src/presentation/fullscreen.gd lines 15-16; test_fullscreen swaps them).
- Title-entry save/restore sites (9.1 deferral): test_gamepad.gd 32/34/44, test_practice_flow.gd 44/45/65, test_fullscreen.gd 33/35/53, test_save_service.gd 40/41/59, test_ending_flow.gd 42/59, test_null_pointer_fight.gd 37/50.
- `SimClock._pending_hitstop` pokes (item 299): about 12 test files (see Task 2.2). `SimClock.request_hitstop` only raises the pending value (`maxi`), so no public call can clear it.
- Item 91: test_audio_manager.gd line 29 `assert_eq(AudioServer.bus_count, 4)`.
- Item 320: test_echo_dash.gd lines 198-204 set `slash.startup_frames = 8` on the shared `Defs.SLASH_1` (`src/core/defs.gd` line 18, `preload` of `data/actions/slash_1.tres`) and restore it before the assert. Lines 186-190 do the same with `Defs.BIT_NULL.solo_action`.
- `SaveService._ready` under GUT: `path = ""`, `track_fights = false`, then `load_save()` (save_service.gd lines 42-47). `Game.tutorial_routing_enabled` is `not running_under_gut()` at boot (game.gd line 112), so its boot value is false and only test_tutorial_flow turns it on.
- `TITLE_ENTRY_GATE_FRAMES = 30` (game.gd line 33). The gate is armed on non-TITLE to TITLE entry; `test_title_entry_gate.gd` covers the arming.

### Mechanism (chosen)

[design call] D-S95-3: the least invasive option that GUT 9.6.1 supports is a pre-run hook script (`pre_run_script` in `.gutconfig.json`) that connects to GUT's own signals. The alternatives were rejected: a `GutTest` base class would need every one of about 90 suites to change `extends` and call `super()` from its own `before_each`/`after_each`; an autoload `reset_for_tests()` called from a hook would add production code for what the hook can do with public fields. The hook is test-only, in `game/tests/support/`, and costs one config file.

### Reset list (boot snapshot for primitives, fresh instances for objects)

The hook captures the boot values once in `run()`, after the autoloads exist and before any suite runs, so GUT-specific boot values (`SaveService.path == ""`, `track_fights == false`, `tutorial_routing_enabled == false`) come from the game itself and are not copied by hand.

- `Game`: flow_state, first_input_frame, title_entry_frame, intro_start_frame, death_frame, harvest_start_frame, ending_start_frame, practice_run, practice_loadouts_offered (`[]`), practice_loadout_index, practice_start_frame, tutorial_routing_enabled, tutorial_replay, segfault_enabled, `_retrying`, `_paused_at_msec` (boot snapshot); `run = RunState.new()`, `stats = RunStats.new()`, `ending_summary = {}`.
- `SaveService`: highest_boss, assist, muted, tutorial_done, completed, storage_warned, track_fights, path (boot snapshot). The save file is never written under GUT (path is empty), so no disk reset is needed.
- `AudioManager`: `_unlocked`, `_warned_locked`, `locked_warn_count` (boot snapshot); master bus mute via `set_master_muted(SaveService.muted)` after the reset.
- `SimClock`: `SimClock.reset_for_tests()` (Task 2.1) for the timing fields and the private hit-stop fields; `input_source` back to its boot value (null); `recorder = null`.
- `Debug.enabled` (boot snapshot).
- `Fullscreen`: `get_mode_fn` and `set_mode_fn` (boot snapshot of the default Callables).

### Design calls (Story 9.5)

- **[design call] D-S95-1 (cadence): reset before every suite and after every test.** The brief asks for a between-suites reset. A per-test reset (on `end_test`) is a superset and covers the intra-suite leaks that the scattered blocks were hiding (test_save_service sets `Game.title_entry_frame = 100` and relies on its own after_each). The cost is a few assignments per test. Default: both points.
- **[design call] D-S95-2 (production seam): one SimClock method, nothing else in `src/`.** Item 299 forbids touching private SimClock fields from the helper, so the owner needs to clear its own private fields. A `reset_for_tests()` that nothing in shipped code calls changes no behaviour. No other autoload gets a seam: every other field is public and reachable from the hook.
- **[design call] D-S95-4 (reset values): boot snapshot for primitives, fresh objects for resources and RefCounted state.** A snapshot of an object reference would not undo in-place mutation (`Game.run.assist = true`), so objects are replaced, not restored.
- **[design call] D-S95-5 (ordering verification): hook-driven reverse and shuffle orders, not a GUT feature.** GUT 9.6.1 has no shuffle flag. The hook reorders `gut.get_test_collector().scripts` in place when `WILDSHIFT_GUT_ORDER` is set, so the same CI command can be replayed in any order and the seed is printed.
- **[design call] D-S95-6 (removal scope): remove the title-entry blocks in the six suites and the 9.3 inline restore; leave other per-suite restores.** Those restores hold values a test sets for itself (for example `Game.run` in test_pause_screen) and are cheap to keep. Removing all of them is not "simple" and would add risk without a failing case behind it.
- **[design call] D-S95-7 (shared resources): duplicate, never mutate.** `Defs` resources and BitDefs are shared by every suite, so tests that need a changed value use `duplicate()` and inject the copy. The restore-before-assert pattern is removed, not moved.
- **[design call] D-S95-8 (EventBus): audit, no generic reset.** EventBus signal connections to freed nodes are dropped by Godot. A generic disconnect-all would also remove connections that the game makes at boot, so connections are fixed test by test.

### Open questions (defaults chosen, no elicitation)

- **O1 (CI second run):** the epic AC says "in CI order and in a shuffled order". Default: add one more CI step after the existing GUT step that runs the same command with `WILDSHIFT_GUT_ORDER=shuffle:20261129` (fixed seed, so it is reproducible). If the CI time roughly doubles, drop the CI step and keep the shuffled run as a documented local check in this story file. Tiziano may choose either.
- **O2 (`SimClock._systems`):** the reset does not clear the registered systems list. Default: leave it, because a system registered by a freed test node can only be removed by its own `unregister_system`. If the reversed run shows a stale system ticking, clear entries whose instance is no longer valid (`is_instance_valid`) in the seam, and record that in the Dev Agent Record.
- **O3 (AudioManager music state):** `music_*` fields and tween handles are not in any current save/restore block. Default: not reset. Add them only if a reversed or shuffled run fails in an audio suite.
- **O4 (EventBus):** the audit in Task 5.3 is the default. A failure in the audit that cannot be fixed inside a test is recorded here, not papered over with a generic reset.
- **O5 (`check_guards.sh`):** it may grep `game/src` for private-field access or `reset` names. Default: run it after Task 2 and adapt only the guard's pattern list if the seam trips it, recording the change.

### Testing

- The GUT suite is the test. The three orders in AC 10 are the verification. Record the test count before and after the `tests/support` files are added (it must not change). Record the two shuffle seeds used.
- No new behaviour tests are needed for the seam beyond a short test that calls `SimClock.reset_for_tests()` and asserts the timing fields are zero (`test_sim_clock_reset.gd` may be added if it fits the existing unit layout; default yes, it is one test).

### Project Structure Notes

- New: `game/.gutconfig.json`, `game/tests/support/isolation.gd`, `game/tests/support/gut_isolation_hook.gd`, optionally `game/tests/unit/test_sim_clock_reset.gd`.
- Edited: `game/src/autoloads/sim_clock.gd` (seam only), the test suites listed in Task 2.2, 3.1, 3.2, 4.1, 5.1, 6.1, `.github/workflows/ci.yml` only if O1 keeps the CI step, `_bmad-output/implementation-artifacts/deferred-work.md`, `sprint-status.yaml`, this file.

### References

- [Source: _bmad-output/planning-artifacts/epics.md, "Story 9.5: Test Isolation Hardening" ACs]
- [Source: gameoff-wt/epic9-brief.md, "Stories" item 5 and "Coordinator notes" (9.1 review deferral)]
- [Source: gameoff-wt/epic9-triage.md, "9-4-test-isolation-hardening" proposal and rows 91, 108, 299, 320]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md, lines ~91, 108, 299, 320, ~625 (9.1 review), ~639 (9.3 review)]
- [Source: game/addons/gut/gut.gd (signals, pre-run hook, run loop), game/addons/gut/hook_script.gd, game/addons/gut/gut_config.gd line 20]
- [Source: .github/workflows/ci.yml lines 86-114 (GUT step and its log markers)]

## Project Context Rules

- Main is protected. Work on branch `story/9-5-test-isolation-hardening`, stacked on `story/9-4-doc-consistency`. Never commit to main. Do not commit in the create phase.
- Set story status and sprint-status with the Edit tool (not sed -i, not scripts).
- Production behaviour is unchanged. The only `src/` edit is the SimClock seam (AC 9).
- Never use the Fable model.
- `godot` is not on PATH: `/Applications/Godot.app/Contents/MacOS/Godot`.

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (create-story phase, unattended, no elicitation). claude-opus-5-5 (dev-story phase, unattended).

### Debug Log References

- GUT hook API and run order read from the vendored 9.6.1 source (see Dev Notes "Verified facts"). ctx7 was not needed for this: the vendored source answers the hook question.
- Current GUT invocation, test-level save/restore sites and `_pending_hitstop` pokes were found by grep in the worktree at fd1cd19.

### Completion Notes List

- Story created unattended. Mechanism: GUT pre-run hook via `game/.gutconfig.json`, reset per test and per suite, one SimClock seam.
- Design calls D-S95-1 to D-S95-8 and open questions O1 to O5 are above, with defaults chosen.
- Not yet verified by a Godot run: the hook's reset list, the test count, and the three orders. These are dev-phase tasks (Task 7).
- Dev phase (2026-11-17): all tasks done; full suite green in CI, reverse and four shuffled suite orders. Details below.

### Implementation Plan / Design calls (dev phase)

- **[design call] coordinator, D-S95-1 override (cadence): the central reset runs at the START OF EACH SUITE only (`gut.start_script`), never per test.** A per-test reset would clobber state that suites set up in `before_all` (test_infinite_loop_body, test_text_triggers, test_ending_flow). Within a suite tests keep their own before_each/after_each. No per-test reset was needed: reverse and shuffled runs pass without one.
- **[design call] coordinator, `.gutconfig.json` holds only `pre_run_script`.** It changes no dirs, include_subdirs, exit or log level. Test count at fd1cd19 without the config: 1905; with the config + hook and before any new test: 1905 (identical, CI order, 127 scripts). After this story's 4 new tests: 1909 (128 scripts). The CI GUT command is byte-identical.
- **[design call] coordinator, O1: CI step kept.** One GUT run takes about 10-11 s locally, so a second step `Unit tests (GUT, shuffled suite order)` with `WILDSHIFT_GUT_ORDER=shuffle:20261129` was added after the existing GUT step, with the same failure markers plus a check of the hook's `GUT order: shuffle seed 20261129` line. The step body was executed locally against this worktree: exit 0.
- **D-S95-9 (seam narrowed, deviation from Task 2.1):** `SimClock.reset_for_tests()` clears only `_pending_hitstop`, `_swallow_presses` and `hitstop_frames`, the state no public call can clear. The first version also zeroed `sim_frame`, `poll_frame`, `paused` and the gates; because tests call the helper mid-test (between hits), that zeroed `sim_frame` inside test_game_flow's ending tests (6 failures). The frame counters, pause and gates are public fields, so the central reset restores them from the boot snapshot instead. Production behaviour unchanged (nothing in `src/` calls the seam).
- **D-S95-10 (EventBus, item 108):** `TestIsolation.connect_bus(links, signal, callable)` / `disconnect_bus(links)` record the lambdas a test connects to EventBus, and the suite's after_each drops any still connected (a script error mid-test would otherwise leak a lambda into every later suite). Inline disconnects that are part of a test's logic stay. No generic EventBus reset (D-S95-8).
- **D-S95-11 (Defs, item 320):** `ComboDef._solo_action` looks the solos up through the `Defs` constants, so swapping a duplicated BitDef into Defs is impossible without mutating it. test_echo_dash uses a test-local `SoloSeamCombo extends ComboDef` whose static `_solo_action` reads a per-test table built from `Defs.solo_action` plus overrides (`{A: slash_duplicate}`, `{N: null}`). Verified by probe that `validate()` dispatches to the subclass's static. No production edit.
- **D-S95-12 (audio, item 91):** AudioBusLayout has no `bus_count` property in Godot 4 (ctx7 /godotengine/godot-docs checked; buses are only `bus/<i>/*` properties), so the test counts `bus/<i>/name` entries of `default_bus_layout.tres` (a new test pins that helper to 4). test_title_input's inline `_unlocked` restore moved to before_each (lock) / after_each (restore). The other suites' after_each `_unlocked` restores stay: with the per-suite cadence they still guard intra-suite order (D-S95-6).
- **Reset list deviation:** `SimClock.input_source` is restored to the boot snapshot (the LiveInput instance SimClock creates in `_ready`), not null as the Dev Notes said; null is not its boot value under GUT. `Game.practice_loadouts_offered` is replaced by a fresh typed array, `Game.run` / `stats` / `ending_summary` by fresh objects, `SimClock.recorder = null`. O2-O5 defaults accepted (no `_systems`, music or generic EventBus reset).
- Task 3.2: test_tutorial_flow and test_title_entry_gate keep `title_entry_frame` in their per-test `_saved_game` lists, because with the per-suite cadence the central reset is not the sole restorer inside a suite.

### Debug Log References

- Baseline at fd1cd19 (CI command): 127 scripts, 1905 tests, all passed.
- Control experiment (hook installed, reset disconnected): CI order, reverse and shuffle:20261129 pass, but **shuffle:7 fails 6 tests in test_text_triggers** (`test_full_run_with_the_segfault_requests_every_duck_line` and siblings: SCRIPT ERRORs on a null Infinite Loop / null `squeak` target, after test_debug_keys / test_ending_screen ran first). With the per-suite reset on, shuffle:7 passes. This is the order-dependent failure the central reset fixes.
- Seam regression found and fixed during dev: see D-S95-9 (test_game_flow, 6 failures from a mid-test `sim_frame = 0`).
- Without `.gutconfig.json` (`-gconfig=`), the two hook-dependent tests in test_sim_clock_reset.gd report pending (CI treats pending as failure, so a lost hook fails CI).
- Final runs (after all edits): CI order 128 scripts / 1909 tests / 1909 passing; reverse 1909/1909; shuffle:20261129 1909/1909; shuffle:7 1909/1909; earlier also shuffle:42 and shuffle:1337 1909/1909. No SCRIPT ERROR, Parse Error or failure marker. `--headless --import` clean. `game/tools/check_guards.sh`: OK.
- Local replay: `WILDSHIFT_GUT_ORDER=reverse` or `WILDSHIFT_GUT_ORDER=shuffle:<seed>` before the CI GUT command.

### EventBus audit (AC 8)

- before_each / after_each pairs on the test object (method callables, disconnected in after_each): test_corrupt_memory (`boss_tell_started`), test_access_violation (`boss_tell_started`), test_text_triggers (`duck_line_requested`), test_infinite_loop_replay (`hit_landed`).
- Lambdas connected inside a test, now tracked with `TestIsolation.connect_bus` and dropped in after_each: test_register (`register_shifted`), test_register_system (`register_shifted`), test_infinite_loop_attacks (`boss_tell_started`), test_breakpoint_replay (`breakpoint_started`, `breakpoint_ended`, `register_shifted`), test_infinite_loop_replay (`boss_tell_started`, `boss_defeated`).
- Nodes under test that connect in `_ready` (log panel, particle pool, duck bubble/director, juice director, semicolon readability) are autofreed in their test; Godot drops the connection on free. `watch_signals(EventBus)` (38 suites) is cleared by GUT after each test.

### File List

- .github/workflows/ci.yml (new shuffled-order GUT step; the existing GUT command unchanged)
- game/.gutconfig.json (new)
- game/tests/support/isolation.gd (new), game/tests/support/isolation.gd.uid (new)
- game/tests/support/gut_isolation_hook.gd (new), game/tests/support/gut_isolation_hook.gd.uid (new)
- game/tests/unit/test_sim_clock_reset.gd (new), game/tests/unit/test_sim_clock_reset.gd.uid (new)
- game/src/autoloads/sim_clock.gd (test seam only)
- game/tests/unit/: test_access_violation, test_audio_manager, test_boss_controller, test_boss_fallback, test_camera_shake, test_clean_catch, test_combat_resolver, test_core_dump, test_corrupt_memory, test_dangling_pointers, test_dereference, test_echo_action, test_echo_dash, test_fullscreen, test_game_flow, test_gamepad, test_ghost_echo, test_infinite_loop_attacks, test_infinite_loop_body, test_infinite_loop_split, test_metrics_flow, test_null_pointer_attacks, test_null_pointer_body, test_pause_screen, test_player_health, test_practice_flow, test_register, test_register_system, test_reserved_write, test_save_service, test_segfault_body, test_sigsegv, test_title_input, test_tutorial_dummy, test_watch_fallback, test_watch_readouts, test_whiff_stun (.gd)
- game/tests/integration/: test_breakpoint_replay, test_ending_flow, test_infinite_loop_replay, test_null_pointer_fight (.gd)
- _bmad-output/implementation-artifacts/deferred-work.md, sprint-status.yaml, 9-5-test-isolation-hardening.md

### Change Log

- 2026-11-17: Story 9.5 implemented. GUT pre-run hook + central per-suite reset of the autoload globals, SimClock hit-stop seam, 87 private hit-stop writes replaced, six title-entry restores and the 9.3 inline restore removed, audio bus count from the layout, Defs duplicates, EventBus links tracked, ordered/shuffled runs, CI shuffled step. Status review.

### Review Findings (2026-11-17, gds-code-review: Blind Hunter, Edge Case Hunter, Acceptance Auditor)

Fixed in review:
- [Fix] `test_ending_flow` and `test_null_pointer_fight` lost their `title_entry_frame` restore and did not reset it per test; the central reset is per suite only. Both now set `Game.title_entry_frame = -1` in `before_each`.
- [Fix] The hook's `seed()` left the global RNG seeded for the whole shuffled run; it now calls `randomize()` after shuffling.
- [Fix] `test_sim_clock_reset` had a tautological assert after its early return; removed.
- [Fix] No static guard kept `SimClock.reset_for_tests` out of shipped code; `check_guards.sh` now fails if `game/src` calls it.

Deferred (low, see deferred-work.md "code review of Story 9.5"):
- The central reset is per suite (coordinator override of D-S95-1); AC 1 and Dev Notes wording that says per test is stale. Suites that mutate shared state within a suite keep their own intra-suite restores (`_unlocked`, `sim_frame`, `paused`, `Game` fields, `SimClock._swallow_presses`).
- Tests still read `SimClock._pending_hitstop` / `_swallow_presses` privately (item 299 write side resolved; reads remain).
- `clear_hitstop()` also zeroes `hitstop_frames` and the swallow flag at the 87 sites (checked: sites drive the resolver directly, no behavioural dependence found).
- `SoloSeamCombo` relies on GDScript static-override resolution (guarded by the `{N: null}` assert); the static `solos` dict is not cleared after the test.
- The bus-count helper test pins 4 again; the editor GUT panel needs "Pre-Run Script" set to res://tests/support/gut_isolation_hook.gd; the shuffled CI step uses one fixed seed; boot snapshot includes the local save file when run on a dev machine.
- AC 12 / D-S95-1 / Task 2.1 text describe the create phase and the pre-override design; the Dev Agent Record (D-S95-1 override, D-S95-9) is authoritative.
