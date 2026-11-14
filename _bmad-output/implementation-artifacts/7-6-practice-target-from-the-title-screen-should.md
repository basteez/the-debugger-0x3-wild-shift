---
baseline_commit: 0a4924effa2c77e4797753db7b506e09b454652a
---
# Story 7.6: Practice Target from the Title Screen (Should)

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with the chosen default (D-S76-n); the implementer follows them or records a change in Completion Notes. Scope: the title's practice option (P key, click, L3 pad), a non-debug practice fight that loads the `/* test */` dummy with the base damage, the per-hit log and a frame counter in every build, the register loadout chooser, and Esc back to the title. NOT in scope: fullscreen (7.7), the browser matrix and performance checks (7.7), remapping, new art, new audio, the debug Shift+F2 sandbox itself (it stays debug-only and unchanged). -->

## Story

As a player,
I want to try combos on a training dummy from the title screen,
so that I can learn the frame data without pressure.

**Requirements:** FR59 (Should). GDD "Practice Target": a `/* test */` training dummy with infinite HP and no attacks, offered to players from the title screen as a Should, with a per-hit damage log and a frame counter. GDD D-048: `[P]` practice on the title. Epics 7.6: the register can be set to any owned loadout reached so far (or the full `[A, D, L, N]`).

Depends on: 7.5 (reserved `title_option_practice` L3 pad binding, `OPTION_ACTIONS`), 7.4 (title option row pattern, `label_rects`), 7.3 (`SaveService.highest_boss`, `SaveService.note_fight_start`, the `[N]` rule), 2.7 (`PracticeTarget`, `Arena.enter_fight(with_practice)`, `PracticeTargetView`), 2.8 (hit log lines), 2.5 (frame overlay), 1.4 (title classifier and any-key start), 6.9 (game text lives in `data/text/screen_text.tres`).

## Acceptance Criteria

**Title option (FR59, D-048)**

1. **Given** the title screen, **When** I press `P` or click the `practice` label, **Then** the practice run starts without the Intro and without the 30-s clock affecting the save (see AC 6): the arena loads The Clearing with the `/* test */` dummy (`PracticeTarget`), at its usual position (`Arena.PRACTICE_TARGET_PX`), with base damage (x1, never Patched, never a boss), the per-hit log and a frame counter.
2. **And** `available[&"practice"]` is `true` in every build (the option is no longer hidden). Its label is a new line in `data/text/screen_text.tres` (`practice_label`, Story 6.9 audited text, in the same style as `[N] new run`), shown below the `[B] debug build` row, and clickable through `label_rects` [design call] D-S76-1: row top `y` 304 (`TitleScreen.PRACTICE_TOP_Y`), centred with `centred_x`.
3. **And** Start, Select, B and R3 on the title are unchanged (Start/any other button starts the normal run; Select new run; B debug build; R3 stays the hidden fullscreen option until 7.7). L3 (`title_option_practice`, button 7, reserved in 7.5) starts practice exactly as P does.
4. **And** stick and trigger motion on the title still never start anything (7.5 AC 8).

**Practice fight (non-debug)**

5. **Given** a practice start, **When** the fight is entered, **Then** the fight runs without the debug gate: `Debug.enabled` is not required for the dummy, its hit log or its frame counter. A release build (no `?debug`) shows the practice target and the frame counter. [design call] D-S76-2: the frame counter is a small read-only "frames" readout (the frame count since fight start, in the existing debug overlay style and glyph font), visible only during practice; it does not add the F9 overlay to release builds.
6. **And** a practice run never raises or writes `SaveService.highest_boss` (`SaveService.note_fight_start` is skipped for practice, as it is for `stats.debug_jumped`), never counts as a clear (`RunStats`), and never changes the saved assist/mute. A save with `highest_boss = 3` is unchanged after a practice session.
7. **And** the practice fight uses no boss: `boss_def_path_for` returns `""` for practice (existing rule), the boss view is detached, and no Breakpoint or Watch unlock changes state (their unlock rules still come from the chosen loadout only, see AC 9).
8. **And** the dummy is reset (`PracticeTarget.reset()`) on every practice (re)start, and the per-hit log shows the damage (base x1) and the hit as the Shift+F2 path does today.

**Loadout (register)**

9. **Given** the practice fight, **When** it starts, **Then** the register starts at the highest owned loadout reached so far, computed from `SaveService.highest_boss` with the GDD fight-start sets (`Register.fight_start_for_boss`): `highest_boss` 1 gives `[D, A]`, 2 gives `[A, D, L]`, 3 gives `[A, D, L, N]`. With a fresh save (`highest_boss` 1) the starting loadout is `[D, A]`.
10. **And** the player can pick any loadout reached so far, or the full `[A, D, L, N]`, through the loadout chooser (AC 11). The chooser never offers a loadout the save has not reached, except the full `[A, D, L, N]`, which is always offered as the last entry [design call] D-S76-3 (the epic says "or the full `[A, D, L, N]`").
11. **And** [design call] D-S76-4: during practice the loadout cycles with `R` (keyboard) and Select (pad, `button 4`, while not paused) through the offered loadouts in order, and each change restarts the dummy fight (a retry: same fight, new register ring from the chosen loadout, dummy reset, HP and cooldowns reset). Pause is still Esc/P/Start; on the pause screen Select stays `mute` (7.5 AC 13), so it never cycles loadouts while paused.
12. **And** the chosen loadout is not saved: the next practice starts from AC 9 again.

**Leaving practice**

13. **Given** a practice fight that is not paused, **When** I press Esc, **Then** the game returns to the title with no pause and no save change (the title's own rules apply after it: the next press starts a normal run or resumes the save as usual). [design call] D-S76-5: in practice, Esc means "leave to title" in one press instead of pausing; `P` and Start still pause. Esc while paused resumes, as on any pause.
14. **And** the practice fight leaves to TITLE through a new `Game` path (`Game.leave_practice_to_title`, valid only from FIGHT in practice), which resets `run`, `stats` and the practice flag, and does not write `SaveService`. Leaving never triggers the Intro, the Harvest or the Ending.
15. **And** the title after a practice leave behaves exactly as at boot: `saved_highest_boss` is re-read by `TitleScreen._ready` (no change in what it shows).

**Pause in practice**

16. **Given** a practice fight, **When** it is paused with P or Start (Esc leaves instead, AC 13), **Then** the pause screen shows the same rows as in a normal fight. The `[B] debug build` option works as in any fight (it changes the assist for the next attempt, 7.4 rule). The pause screen does not offer the `[N]` rule.

**Debug build unchanged**

17. **And** the Shift+F2 debug sandbox (`DebugKeys.PRACTICE_KEY`, `wants_practice()`) keeps its behavior: it stays debug-only, enters Boss 1 with the practice target, and is unaffected by the title option. Its `practice_requested` survives until another jump key, as before (2.7 deferred note).

**Guards and tests**

18. **And** `game/tools/check_guards.sh` passes. Nothing under `game/src/core`, `game/src/combat`, `game/src/player` or `game/src/bosses` changes (the practice target and the resolver are reused as they are). The sim reads no SaveService (D-S21-3). Practice input reaches the sim through existing InputMap actions only.
19. **And** the GUT suite includes: title classify and label rect for `practice` (keyboard P, L3, click), the hidden-to-visible availability, loadout list per `highest_boss` (1, 2, 3) with the full set appended, the Esc classification in practice, `Game` practice start/leave transitions (no save write, no clear), and `wants_practice`-style gating that works with `Debug.enabled = false`. Any test that depends on random picks seeds the RNG (brief). Existing tests stay green, with updates only where they assumed the practice option is hidden (`test_title_input.gd`, `test_gamepad.gd` AC 7 wording).

## Tasks / Subtasks

- [x] Task 1: Title option (AC 1-4)
  - [x] 1.1 `TitleScreen`: `available[&"practice"] = true`; add `PRACTICE_TOP_Y` = 304 and `practice_label_rect()` in `set_saved_progress`-style `label_rects[&"practice"]`.
  - [x] 1.2 Add `practice_label` to `data/text/screen_text.tres` (text: `[P] practice`, to be audited with the 6.9 rules); draw it in `_draw` when available.
  - [x] 1.3 `handle_input`: `option == &"practice"` calls `_begin_practice()`; no other branch changes. Update the header comment (7.6 line).
- [x] Task 2: Game flow (AC 1, 5-6, 13-15)
  - [x] 2.1 `Game`: `practice_run: bool` (not persisted), `start_practice_from_title(frame, highest_boss)` from TITLE: fresh `RunState`, `start_boss` is NOT used (no boss); FIGHT entered with the practice flag set; `stats.debug_jumped` is not used for it, use a separate guard so the save is skipped.
  - [x] 2.2 `_set_flow_state`: skip `SaveService.note_fight_start` when `practice_run`.
  - [x] 2.3 `Game.leave_practice_to_title(frame)`: valid only from FIGHT with `practice_run`; resets `practice_run`, `run`, `stats`, `first_input_frame`, goes to TITLE (same reset as `debug_jump(TITLE)`).
  - [x] 2.4 Esc in practice: `Game.handle_pause_input` routes Esc to leave when `practice_run` and not paused; P/Start keep pausing (D-S76-5).
- [x] Task 3: Arena and Main (AC 5, 7-9, 11)
  - [x] 3.1 `Main._on_state`/`enter_fight` path: `wants_practice()` returns true also when `Game.practice_run` (outside the debug gate); `boss_def_path_for(..., practice=true)` still returns `""`.
  - [x] 3.2 Fight-start ring for practice comes from the chosen loadout (`Register.fight_start_for_boss` of the highest reached boss, or the full set from the chooser). Add `Game.practice_loadout_index` and a pure `Game.practice_loadouts(highest_boss) -> Array[PackedInt32Array]`.
  - [x] 3.3 `R` / Select cycle: a `Game.cycle_practice_loadout(frame)` that re-enters FIGHT as a retry (`_retrying`), resets the dummy and HP/cooldowns; not from the pause screen.
  - [x] 3.4 Frame counter readout (AC 5): a small presentation node added by `Main` in all builds, visible only in practice; reads `SimClock.sim_frame - fight_start_frame`; never writes sim state.
  - [x] 3.5 Keep `PracticeTargetView` and the hit log available in release (today `PracticeTargetView` is attached only under `Debug.enabled`; attach it for practice too).
- [x] Task 4: Tests (AC 19)
  - [x] 4.1 `test_title_input.gd`: P / L3 / click classify as OPTION with `practice` available; B, Select, Start unchanged.
  - [x] 4.2 `test_save_service.gd` or a new `test_practice_flow.gd`: a practice run never changes `highest_boss`, `assist`, `muted`.
  - [x] 4.3 Loadout list pure tests: `highest_boss` 1 -> `[D, A]` only plus full; 2 -> `[D, A]`, `[A, D, L]`, full; 3 -> the three plus full.
  - [x] 4.4 Esc in practice leaves to TITLE; Esc elsewhere still pauses (regression of `test_pause.gd`).
  - [x] 4.5 Run the GUT suite headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless ...` (godot is not on PATH).

## Dev Notes

### What exists now (read before writing code)

- `game/src/ui/screens/title/title_screen.gd`: `OPTION_ACTIONS` already maps `&"practice"` to `title_option_practice`; `available[&"practice"]` is `false` (hidden, behaves as a plain key, which starts the run). The 7.4 `[B]` row (`DEBUG_BUILD_TOP_Y` 272) and the 7.3 `[N]` row (240) are the layout precedents.
- `game/project.godot` `[input]`: `title_option_practice` = P (physical 80) and joypad button 7 (L3). Nothing else to bind.
- Practice today exists only in the debug build: `game/src/debug/debug_keys.gd` (`PRACTICE_KEY` F2 with Shift, `practice_requested`), `game/src/main/main.gd` (`wants_practice()` is `Debug.enabled and ...`, `_attach_practice_target` into `frame_overlay` and `practice_view`, both created only under `Debug.enabled`), `game/src/arena/arena.gd` (`enter_fight(..., with_practice)`, `_set_practice`, `PRACTICE_TARGET_PX`).
- The dummy itself: `game/src/bosses/practice_target/practice_target.gd` (infinite HP, `reset()`, `register_hit`). Damage: `damage_state.gd` BASE x1. The resolver (`combat_resolver.gd`) already handles `targets`.
- `Debug.enabled` = `OS.is_debug_build()` or the `?debug` query (`game/src/autoloads/debug.gd`). Release builds have no debug nodes, so the title option must not depend on them.
- `game/src/autoloads/game.gd`: `resume_run_from_title`, `start_new_run_from_title`, `debug_jump`, `_set_flow_state` (calls `SaveService.note_fight_start` on FIGHT entry unless `_retrying` or `stats.debug_jumped`), `handle_pause_input` (Esc/P), `PAUSABLE_STATES`.
- `game/src/autoloads/save_service.gd`: `highest_boss` (1..3), `note_fight_start`, `reset_run_progress`; a practice run must never raise `highest_boss`.
- `game/src/register/register.gd`: `fight_start_for_boss(0..2)` (GDD sets), `set_fight_start(bits)`, `to_text`.

### Design calls (all `[design call]`; default chosen, change in Completion Notes if needed)

- D-S76-1: title row at `y` 304 with the label `[P] practice`.
- D-S76-2: a frame counter readout is shown in every build during practice only. The F9 overlay stays debug-only.
- D-S76-3: the loadout list is the reached GDD sets plus the full `[A, D, L, N]` at the end.
- D-S76-4: `R` (and Select while not paused) cycles the loadout; each change is a retry-style restart of the dummy fight.
- D-S76-5: Esc in practice (not paused) returns to the title in one press; P and Start pause.

### Architecture guardrails

- The sim (`game/src/core`, `combat`, `player`, `bosses`) is unchanged. Practice reuses the existing dummy and resolver through `Arena.enter_fight`.
- Presentation may read `SimClock`; it never writes sim state. The frame counter is presentation only.
- SaveService is read by Game and the title only (as in 7.3), never by the sim (D-S21-3).
- No new InputMap action names are needed: `title_option_practice` exists. The cycle and Esc routing reuse `pause` and the existing keys; `R` must not clash with the debug keys (check `debug_keys.gd` and `handle_key` before binding it, and do not bind it in the InputMap if it would fire during play).
- Game text goes to `data/text/screen_text.tres` (6.9 rule), not into the scene or script.
- Keep `check_guards.sh` green.

### Previous story intelligence (7.5, 7.4, 7.3)

- 7.5 reserved L3 for practice and says the practice target itself is 7.6. Its tests in `test_gamepad.gd` and `test_title_input.gd` assume the option is hidden in places; update those assertions, do not weaken them.
- 7.4 flips the assist without starting the run and writes through `SaveService.set_assist`. Reuse that pattern for practice labels; the practice option must start a run, so it is not an in-place toggle.
- 7.3 writes the save on FIGHT entry (`note_fight_start`) and skips it for debug jumps. The practice path must skip it the same way.

### Open questions

- None blocking. Design calls D-S76-1 to D-S76-5 are chosen above; the implementer may change them and must record the change.

### Human checks

- Play practice in a release build (no `?debug`) in Chrome: the dummy, the hit log and the frame counter all show; Esc returns to the title.
- The title shows `[P] practice` at the right position with the `[B]` row above it and no overlap at phone width (the 640-px base).

## Tasks check

- Tasks 1-4 are the implementation and tests; the human checks above are not automatable.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended pipeline run 2026-11-14

### Debug Log References

- Full GUT suite (headless, `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`): 118 scripts, 1728/1728 passing, 1 orphan (an existing EndingScreen test, not from this story).
- `bash game/tools/check_guards.sh`: OK.

### Completion Notes List

- Story created unattended by gds-create-story (2026-11-14). Status ready-for-dev.
- Implemented 2026-11-14 (Status review).
- Title (AC 1-4): `[P] practice` always shows at y 304 (`PRACTICE_TOP_Y`, D-S76-1), and its label rect is clickable. The text lives in `screen_text.tres` (`practice_label`). P, L3 or a click calls `TitleScreen._begin_practice()` -> `Game.start_practice_from_title(frame, saved_highest_boss)`. Start, Select, B and R3 are unchanged. Stick and trigger motion still start nothing.
- Game (AC 6, 9-14): `practice_run` (not persisted), `practice_loadouts_offered` and `practice_loadout_index`, plus `practice_start_frame` for the counter. `_set_flow_state` skips `SaveService.note_fight_start` and never recaptures the ring in practice. `leave_practice_to_title` resets run, stats and the practice state and never writes the save. `debug_jump` clears the practice state, so a debug jump out of practice follows the normal rules again.
- Loadout mapping checked against the game data, not just the story text: `SaveService.note_fight_start(boss_index)` stores `highest_boss = boss_index + 1` when a fight starts. The Infinite Loop def drops LOOP (3) and the Null Pointer def drops NULL (4), so `highest_boss` 1/2/3 means the player owns `[D, A]` / `[A, D, L]` / `[A, D, L, N]` = `Register.fight_start_for_boss(hb - 1)`. A test pins this (`test_loadouts_match_the_gdd_fight_start_sets`).
- [design call] D-S76-3 refined: the full set `[A, D, L, N]` is the same as Boss 3's fight-start set, so it is appended only when not already listed (with `highest_boss` 3 the list has 3 entries, not 4). The chooser stores boss indices (`practice_loadout_bosses`). The run's `boss_index` follows the chosen loadout, so the Breakpoint and Watch unlocks come from the loadout (AC 7): the full set unlocks both even on a fresh save.
- [design call] D-S76-4 changed: `R` is the `watch` action, so the keyboard cycle key is `L` ("loadout", `Game.PRACTICE_CYCLE_KEY`). The pad keeps Select (button 4). Both are matched by code in `Game.handle_practice_input`, not through the InputMap, so they never reach the sim. They work only in a practice FIGHT that is not paused, so Select stays `mute` on the pause screen.
- [design call] D-S76-5 as written: Esc (not paused) leaves to the title in one press, P and Start pause, and Esc while paused resumes.
- [design call] D-S76-6 (new): a pad has no Esc and Start pauses, so L3 (the button that entered practice) leaves practice on the pad.
- [design call] D-S76-7 (new): the frame counter (`PracticeFrameCounter`, `src/presentation/`) draws `frames N` and a key hint (`practice_hint` in `screen_text.tres`: `[L / SELECT] loadout  [ESC / L3] title`) at 1x under the dummy. It shows in every build, only during practice. The F9 overlay, F10 perf overlay and DebugKeys stay behind `Debug.enabled`.
- `PracticeTargetView` is now built in every build (it draws nothing without a target), so release shows the `/* test */` label. The per-hit log (HUD LogPanel) already ran in every build.
- Release exposure checked: in a Main built with `Debug.enabled = false`, DebugKeys, `frame_overlay` and `perf_overlay` are null, and the practice dummy, view and counter work (`test_release_build_practice_has_target_view_counter_and_no_boss`).
- No changes under `src/core`, `src/combat`, `src/player`, `src/bosses`. The sim reads no SaveService. No random picks are involved (no boss and no dummy attacks), so no RNG seeding was needed.
- Existing tests updated, not weakened: `test_title_input.gd` (practice is now visible; the "available option keeps TITLE" check moved to the still-hidden `fullscreen`), `test_gamepad.gd` (L3 now resolves to OPTION), `test_debug_keys.gd` (release has a `practice_view` with no target instead of none).

- Coordinator decisions 2026-11-14: D-S76-3 refinement, D-S76-4 change (L instead of R), D-S76-6 (L3 leaves practice) and D-S76-7 (hint row) approved.
- Code review (gds-code-review, 3 layers): (a) key L (physical 76) is bound to no InputMap action in project.godot, so no clash; hint text already says L. (b) The `FIGHT n / boss index n` text is the PlaceholderScreen shown in every build in normal fights (a Story 1.6 leftover), so it is hidden in practice (`Main._make_screen`) and the general question is deferred. Acceptance Auditor: all 19 ACs met. Blind Hunter items were mostly speculative; real ones deferred (see deferred-work.md).

### File List

- `_bmad-output/implementation-artifacts/7-6-practice-target-from-the-title-screen-should.md` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (7-6 status)
- `game/data/text/screen_text.tres` (practice_label, practice_hint)
- `game/src/ui/text/text_screen_text.gd`
- `game/src/ui/screens/title/title_screen.gd`
- `game/src/autoloads/game.gd`
- `game/src/main/main.gd`
- `game/src/presentation/practice_frame_counter.gd` (new)
- `game/src/presentation/practice_frame_counter.gd.uid` (new)
- `game/tests/unit/test_practice_flow.gd` (new)
- `game/tests/unit/test_practice_flow.gd.uid` (new)
- `game/tests/unit/test_title_input.gd`
- `game/tests/unit/test_gamepad.gd`
- `game/tests/unit/test_debug_keys.gd`

### Change Log

- 2026-11-14: Story 7.6 implemented: title practice option, non-debug practice fight with loadout chooser, frame counter, Esc/L3 leave; tests added; status review.
