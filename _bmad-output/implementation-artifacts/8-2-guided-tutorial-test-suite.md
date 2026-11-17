---
baseline_commit: c4484ca
---

# Story 8.2: Guided Tutorial Before Boss 1 ("Running the Test Suite")

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), stacked on story/8-1 (baseline c4484ca). Design calls from the Epic 8 brief are D-E8-4..7, marked [design call]. Calls this story adds are D-S82-n; the implementer follows them or records a change in Completion Notes. Scope: a new flow state TUTORIAL (the Clearing, a tutorial dummy that never attacks, six gated steps, skip, replay from the title), the save flag, the title option, and tests. No new duck line, no new audio or sprite asset, no change to Boss 1's rules. -->

## Story

As a first-time player,
I want a short guided tutorial that has me perform each core verb once, in isolation,
so that I know what to do before Boss 1 starts, without a manual.

**Requirements:** Epic 8 brief, playtest finding 1 ("I can't work out what to do... needs a dumbed down tutorial bit at the start"); D-E8-4, D-E8-5, D-E8-6, D-E8-7; NFR10 (first shift within 30 s of the first title input, intro included); AD-05 (presentation reads sim, never writes it); AD-08 (only Game changes flow_state); D-039 (duck budget 10); Story 6.9 (game text audit); Story 7.3 (save, resume, retry); Story 7.5 (pad mapping); Story 7.6 (title practice option); Story 8.1 (the open `;` cue and miss line this story reuses).

## Acceptance Criteria

1. **Given** a fresh run (`tutorial_done` false or missing in SaveService) **When** the flow leaves INTRO (skip or the 480-frame cap) **Then** the flow enters a new state `FlowState.TUTORIAL` in The Clearing (the arena) against a tutorial dummy, and Boss 1 (FIGHT 1) starts only after the tutorial ends. [design call] D-E8-4.

2. **Given** TUTORIAL **When** it is drawn **Then** a checklist of six lines is drawn as 2x glyph text inside the play area (`Arena.play_area()`, not in the 12-column duck bubble): `[ ] test_move`, `[ ] test_actions`, `[ ] test_shift`, `[ ] test_combo`, `[ ] test_patch`, `[ ] test_crit`, each turning to `[PASS] test_x` when its step passes. [design call] D-E8-4.

3. **Given** step 1 **When** the player's cumulative movement in the arena reaches 3 tiles (48 px, path length) **Then** `test_move` passes. [design call] D-E8-5.

4. **Given** step 2 **When** both `action_1` (J) and `action_2` (K) have each started an action during TUTORIAL **Then** `test_actions` passes. [design call] D-E8-5.

5. **Given** step 3 **When** the active register window reads `[A, D]` (`Vector2i(1, 2)`, Register.Bit ATTACK, DASH) after a player shift during TUTORIAL **Then** `test_shift` passes. [design call] D-E8-5.

6. **Given** step 4 **When** a combo hit (a Dash Strike, `hit_landed` with `is_combo` true) lands on the dummy **Then** `test_combo` passes. [design call] D-E8-5.

7. **Given** step 5 **When** `patched_applied` fires for the dummy (`boss_id` `&"tutorial_dummy"`) **Then** `test_patch` passes. The dummy's `;` opens and shuts on a fixed sim-frame timer (D-S82-4). [design call] D-E8-5.

8. **Given** step 6 **When** a `hit_landed` with state `DamageState.Kind.PATCHED` lands on the dummy and that hit did not apply Patched (no `patched_applied` earlier in the same tick) **Then** `test_crit` passes. [design call] D-E8-5.

9. **Given** each step's prompt **When** it is drawn **Then** it is one ASCII line of at most 64 characters at 1x (the copy in Dev Notes, D-S82-6), and the key or pad names follow the last input device: keyboard names (`WASD / arrows`, `J`, `K`, `Q / E`) when the last device was a keyboard or mouse (the default), pad names (`left stick / D-pad`, `X`, `A`, `LB / RB`) when it was a gamepad (D-S82-10).

10. **Given** the tutorial dummy **When** it is hit **Then** it uses damage states (UNPATCHED x0.5 unless Patched, PATCHED x1.5), never attacks (no tell, no attack, no RNG draw), never dies in the tutorial, and its `;` is drawn with the Story 8.1 open cue (inner marker and countdown bar, closed `;` plain). [design call] D-E8-5 / D-S82-4.

11. **Given** all six tests pass **When** the last one completes **Then** the play area shows `ALL TESTS PASSED.` and, on the next line, `deploying to production...` (two lines, D-S82-7), held for a short beat, then a fresh run enters FIGHT 1 (Boss 1) exactly as today: same register start `[D, A]`, same fight-start snapshot, same HUD, duck lines T1 to T4 still play, no new duck line. [design call] D-E8-7.

12. **Given** TUTORIAL **When** the player holds Esc for 1 s (60 sim frames, D-S82-5) **Then** the tutorial is skipped; while Esc is held a hint line `hold Esc: skip` shows. A tap of Esc does not pause in TUTORIAL. [design call] D-E8-6.

13. **Given** the tutorial is completed or skipped **When** the flow leaves it **Then** `tutorial_done` is true in SaveService and the save is written (save version 2; version 1 saves still load, with the flag false; a missing key reads as false, D-S82-8).

14. **Given** a save past Boss 1 (resume from the title), a DEAD retry, a Harvest-to-fight or any non-fresh path **When** it enters FIGHT **Then** the tutorial is never shown again. The title's `[N] new run` keeps the Intro and therefore the tutorial, unless `tutorial_done` is true (it is not reset by a new run: D-S82-9).

15. **Given** the title screen **When** the player presses `T` or clicks the `[T] tutorial` label **Then** TUTORIAL runs regardless of `tutorial_done` (no Intro), completing or skipping it returns to TITLE (no Boss 1, no run stats, no first-shift metric) and the title's practice and new-run options are unchanged. [design call] D-S82-1 / D-S82-9.

16. **Given** NFR10 **When** a first-time player goes straight through (intro at its 480-frame cap, no skip) **Then** the first player shift (the `test_shift` shift) lands within 1800 sim frames (30 s) of the first title input, and the test that proves it (a scripted step run under a fixed frame counter) passes. The first-shift metric line is logged for the tutorial's shift. [design call] D-S82-11.

17. **Given** the tutorial and its flow **When** the suite runs **Then** a flow test covers INTRO to TUTORIAL to FIGHT, the skip, the replay from the title and the save flag, the six steps each have a unit test, `test_text_audit` still passes with the new strings, `check_guards.sh` passes, and the full GUT suite passes locally with the CI command.

## Tasks / Subtasks

### Group A: Flow state (game.gd, main.gd)

- [x] A1. `game/src/autoloads/game.gd` `enum FlowState`: append `TUTORIAL` after `ENDING` (existing ints unchanged). Add it to `PAUSABLE_STATES` (focus loss and P pause work in it). (AC 1, D-S82-1)
- [x] A2. Grep every `FlowState` match or comparison (`game/src/**`, notably `main.gd` `apply_flow_state` / `_make_screen`, `audio_manager.gd` music by state, `hud` and `intro` screens) and handle TUTORIAL explicitly; record each in Completion Notes. (AC 1)
- [x] A3. `game.gd` `finish_intro`: after the skip gate, route with a new pure `static func route_after_intro(tutorial_done: bool, tutorial_on: bool) -> FlowState` (TUTORIAL when `not tutorial_done and tutorial_on`, else FIGHT). Keep `run.start_boss(0)` before the transition. `tutorial_on` is `Game.tutorial_routing_enabled` (new var, default true; GUT tests turn it off like `segfault_enabled`, the flow test turns it on). (AC 1, 14)
- [x] A4. `game.gd`: `start_tutorial_from_title(frame)` (TITLE -> TUTORIAL, `tutorial_replay = true`, `first_input_frame = -1`, fresh RunState and RunStats, no save write) and `finish_tutorial(frame, skipped: bool)` (TUTORIAL -> FIGHT 1 for a fresh run: `run.start_boss(0)`, `SimClock.swallow_presses_next_poll()` when not paused; TUTORIAL -> TITLE for a replay: `_clear_practice`-style reset of run and stats). Both call `SaveService.set_tutorial_done()` (A6) unless the save write is already true. Refused (false, no log) when not in TUTORIAL or paused. (AC 12, 13, 15)
- [x] A5. `game.gd` `_set_flow_state`: TUTORIAL is neither a fight entry nor an ENDING: no `note_fight_entry`, no `fight_start_frame`, no `SaveService.note_fight_start`, no fight ring capture. The arena is set up by Main (C4). (AC 1, 13)
- [x] A6. `game.gd` `handle_pause_input` / `is_pause_press`: in TUTORIAL a bare Esc never toggles pause (P still does). The skip and leave holds are handled in the TUTORIAL screen (E3), counted in sim frames. (AC 12, D-S82-5)
- [x] A7. `game.gd` `_on_register_shifted`: log `first_shift_s` in TUTORIAL too (the first player shift of the run, D-S82-11); still never in practice or without a title input. (AC 16)
- [x] A8. `game/src/main/main.gd` `apply_flow_state`: TUTORIAL shows the arena and the HUD (not duck_only), `arena.enter_fight(fight_start_ring(Game.run, 0), false, TUTORIAL_DEF_PATH, false, false, Game.run.assist)`, and `_attach_boss(true)`. `boss_def_path_for` gains a `tutorial` branch (checked before the boss index). `_make_screen` gets a TUTORIAL branch that returns the tutorial screen (E1). (AC 1, 2)

### Group B: Save (save_service.gd)

- [x] B1. `game/src/autoloads/save_service.gd`: `VERSION` 1 -> 2, `tutorial_done: bool = false` in the in-memory values, section key `tutorial_done`. `parse` accepts version 1 (flag false) and 2 (flag read, wrong type -> invalid as today); any other version is invalid (fresh save, one warn). `to_config` writes version 2 and the flag. `defaults()` gains `tutorial_done: false`. (AC 13, D-S82-8)
- [x] B2. `set_tutorial_done()` (sets the flag and `save()`), used by A4. `reset_run_progress()` does NOT clear the flag (D-S82-9). (AC 13, 14)
- [x] B3. `game/tests/unit/test_save_service.gd`: line 123 expects version 1 -> 2; `test_bad_version_resets_to_defaults_and_warns_once` uses version 2 as the bad value: change it to 3. Add: v1 file loads with the flag false; v2 round-trips the flag; wrong-type flag is invalid. (AC 13)

### Group C: The tutorial dummy (sim, src/bosses/tutorial_dummy/)

- [x] C1. New `game/src/bosses/tutorial_dummy/tutorial_dummy_body.gd`: `class_name TutorialDummyBody extends BossController`, the dummy. Constants: `CLOSED_FRAMES := 180`, `OPEN_FRAMES := 120` (sim frames, [design call] D-S82-4), `MAX_HP` in the .tres. Overrides: `_attacks_allowed() -> false` (never attacks, never draws RNG), `_tick_body(ctx)` advances `open_left` on a fixed timer (no RNG, no wall clock), `current_weak_window()` returns `Vector2i.ZERO` while the `;` is closed (so only an open `;` can apply Patched, D-S82-4) and the phase window otherwise, `weak_point_open() -> bool`, `is_semicolon_open()`. The hurtbox is the whole body (`overlaps_shape` unchanged), so Dash Strike lands at any time; closed hits are UNPATCHED x0.5. Its `body_touch_px` stays the default (Vector2.INF: no miss line for the dummy, D-S82-4).
- [x] C2. `game/data/bosses/tutorial_dummy/boss_def.tres`: one phase, `hp_threshold` 100, `weak_window = Vector2i(1, 2)` ([A, D]), `gap_frames` 60, `attack_pool` empty, `max_hp` 999 (never defeated in the tutorial), `body_radius_tiles` 1.0, `drop_bit` 0, `boss_id` `&"tutorial_dummy"`, `name_signature` `"tutorialDummy"` (check NAME_SIGNATURE_MAX in boss_def.gd), `fixed_line` a short placeholder (no new game text, see D-S82-6). `BossDef.validate()` must pass (`validate` allows an empty pool; confirm in the unit test).
- [x] C3. `game/src/arena/arena.gd`: `const TUTORIAL_DEF_PATH := "res://data/bosses/tutorial_dummy/boss_def.tres"`, `const TUTORIAL_DUMMY_PX := SPAWN_PX + Vector2(0, -5 * TILE_PX)` (same spot as the test boss). `boss_class_for(path)` returns `TutorialDummyBody` for `TUTORIAL_DEF_PATH`. The dummy's `body_center_px` is set in `_set_boss` like the test boss (use the constant).
- [x] C4. Unit tests (new `game/tests/unit/test_tutorial_dummy.gd`): never attacks over 2000 frames with a seeded RNG (`ctx.rng` seeded, Epic 6 lesson, D-S82-12), the `;` open/closed sequence is exactly CLOSED then OPEN, Patched applies only on an open `;` (window [A,D] Dash Strike while closed gives UNPATCHED, `patched_applied` not emitted), a Patched state persists after the `;` closes, the body is hittable at all times, the dummy is never DEFEATED at 999 HP after 50 hits.

### Group D: Steps (pure, src/tutorial/)

- [x] D1. New `game/src/tutorial/tutorial_steps.gd` (`class_name TutorialSteps extends RefCounted`): the six-step state machine. Pure: it takes observations (`observe_move(distance_px)`, `observe_action(action_id)`, `observe_window(window)`, `observe_hit(is_combo, state, applied_patch_this_tick)`, `observe_patched(boss_id)`), never reads the sim, never emits. Exposes `passed(step)`, `current_step()`, `all_passed()`, `step_text_key(step)`, `reset()`. Step order is fixed: move, actions, shift, combo, patch, crit. Each step may only pass when it is the current step, except the rule in D3. (AC 3-8)
- [x] D2. Static pure helpers: `static func tiles_moved_ok(distance_px: float) -> bool` (>= 3 * Const.TILE_PX), `static func actions_done(j_used: bool, k_used: bool) -> bool`, `static func window_ok(window: Vector2i) -> bool` (== Vector2i(1, 2)), `static func is_crit(state: int, applied_patch: bool) -> bool` (state PATCHED and not applied). (AC 3-8)
- [x] D3. Order: the spec gates each step on its own condition; if a later condition is met first (for example, a Dash Strike before the shift step), the earlier step still waits. The combo step counts a Dash Strike whatever the window, because the Dash Strike itself is the combo (documented, D-S82-6). (AC 6)
- [x] D4. Unit tests (new `game/tests/unit/test_tutorial_steps.gd`): each step passes only on its condition and not before its predecessor; a crit does not pass on the applying hit; the all-passed transition; reset; the threshold edges (47.9 px fails, 48 px passes, J only fails, J and K passes). (AC 3-8)

### Group E: Presentation (src/ui/screens/tutorial/, src/presentation/)

- [x] E1. New `game/src/ui/screens/tutorial/tutorial_screen.gd` (`class_name TutorialScreen extends Node`, the flow screen for TUTORIAL, like `PlaceholderScreen`/`IntroScreen`): reads sim state each physics frame (`Game`, `Arena.player`, `Arena.actions`, `Arena.register`, `Arena.boss`, read only, AD-05), feeds `TutorialSteps`, owns the Esc hold counter (E3), tracks the last input device (E4), and emits nothing to the sim. Constructed by `Main._make_screen`.
- [x] E2. Checklist view: new `game/src/presentation/tutorial_checklist_view.gd` (`class_name TutorialChecklistView extends Node2D`), a child of the arena (Main adds it like `PracticeTargetView`, `main.gd:138`), drawing in arena-local px inside `Arena.play_area()`: the six checklist lines at `GlyphFont` scale 2 (16 px rows), the prompt line at scale 1, the hint line at scale 1 while Esc is held. Pure layout helper `static func checklist_lines(steps: TutorialSteps) -> PackedStringArray` (unit tested; ASCII only). The pass/fail text is `[ ]` or `[PASS]` only. (AC 2, 9, 11)
- [x] E3. Esc hold (presentation, sim frames): counts consecutive `SimClock.sim_frame` ticks in which Esc is held (`Input.is_physical_key_pressed(KEY_ESCAPE)`; pad: hold `JOY_BUTTON_BACK`, D-S82-5) while `not SimClock.paused`. At 60 frames calls `Game.finish_tutorial(frame, true)`. A release resets it. A replay hold calls the same and ends at TITLE. Pure helper `static func hold_done(frames_held: int) -> bool` (>= 60) and `static func hold_hint_visible(frames_held: int) -> bool` (> 0). (AC 12, 15)
- [x] E4. Last input device: `static func device_for(event: InputEvent, current: int) -> int` (pure; keyboard and mouse = keyboard, `InputEventJoypadButton` / `InputEventJoypadMotion` = gamepad), held by the TUTORIAL screen (`_input`), default keyboard. Prompt and checklist names come from `static func glyph_name(action: StringName, device: int) -> String` (pure map: `action_1` = J / X, `action_2` = K / A, `shift_left` = Q / LB, `shift_right` = E / RB, `pause` = Esc / Start). (AC 9)
- [x] E5. Completion: when `all_passed()` the view shows the two-line `ALL TESTS PASSED.` / `deploying to production...`, then after 90 sim frames (`TUTORIAL_OUTRO_FRAMES`, D-S82-7) calls `Game.finish_tutorial(frame, false)`. The outro frames count only when not paused. (AC 11)
- [x] E6. Presentation strings in `game/data/text/screen_text.tres` (audited, `TextScreenText` in `game/src/ui/text/text_screen_text.gd`): add `tutorial_label` (`[T] tutorial`), `tutorial_title_hint`? (not needed), `tutorial_hint_skip` (`hold Esc: skip`), `tutorial_all_pass_1` (`ALL TESTS PASSED.`), `tutorial_all_pass_2` (`deploying to production...`), the six checklist names, the six prompt templates, and the pad glyph names if they are text. Add every new field to `all_text()` / the `validate()` ASCII list in `text_screen_text.gd` and to the `test_text_audit.gd` expectations. (AC 9, 17)
- [x] E7. Boss view: `game/src/presentation/boss_view.gd` draws the dummy as one `;` at `body.body_center_px` plus the 8.1 cue. Refactor the 8.1 helpers (`semicolon_cue_on`, `open_cue_marker`, `open_cue_bar`, `open_bar_fraction`) to take plain values (`is_open`, `hidden`, `open_left`, `open_frames`, the `;` px, the ring radius) so the InfiniteLoopBody path and the dummy path share them (`_draw_open_cue` is typed to `InfiniteLoopBody` today). Closed: plain `;`, no marker. Existing 8.1 tests keep passing; add a dummy-path test. (AC 10)

### Group F: Title (title_screen.gd, project.godot)

- [x] F1. `game/project.godot` `[input]`: add `title_option_tutorial` with the keyboard key T (physical 84) and no pad event (D-S82-13). Do not change the other option actions.
- [x] F2. `game/src/ui/screens/title/title_screen.gd`: add `&"tutorial": &"title_option_tutorial"` to `OPTION_ACTIONS`, `available[&"tutorial"] = true`, `TUTORIAL_TEXT` from `SCREEN_TEXT.tutorial_label`. Layout (D-S82-14): `[P] practice` and `[T] tutorial` share the row at `PRACTICE_TOP_Y` (304): practice on the left, tutorial on the right, separated by two glyph cells; each has its own clickable rect (`label_rect_for`). Fullscreen stays at 336. `classify` and `option_of` need no change beyond the map. `handle_input`: `option == &"tutorial"` -> `_begin_tutorial()` (sets `_started`, calls `Game.start_tutorial_from_title(SimClock.sim_frame)`, plays the test SFX, `queue_free()`, like `_begin_practice`). (AC 15)
- [x] F3. Update the title tests that assume the practice label is centred (`game/tests/unit/test_title_input.gd`, `test_practice_flow.gd`, `test_title_font.gd` if it checks rows): the new rects and the side-by-side layout. Add: `T` starts the tutorial replay, `T` is an OPTION (not START), `T` ignores a save (no `tutorial_done` check), the tutorial label rect fits in 640 px.

### Group G: Tests (flow and integration)

- [x] G1. New `game/tests/unit/test_tutorial_flow.gd` (or `test_tutorial_flow.gd` integration, the file style of `test_practice_flow.gd`): with `Game.tutorial_routing_enabled = true` and a fresh save: INTRO -> TUTORIAL -> FIGHT; skip in TUTORIAL (60 held frames) -> FIGHT 1 and `tutorial_done` true; a replay from TITLE -> TUTORIAL -> TITLE with no save change in run stats; resume (`highest_boss` 2) -> FIGHT with no TUTORIAL; a DEAD retry does not enter TUTORIAL; `route_after_intro` table (done/not done x on/off). (AC 1, 12-15, 17)
- [x] G2. NFR10 test (`test_tutorial_flow.gd`, D-S82-11): a scripted sequence in which the Intro runs its 480-frame cap, the player moves 3 tiles over 90 frames, does both actions over 60, shifts to [A, D] at frame X: assert X - first_input_frame <= 1800 and that the first-shift metric line is the tutorial's shift. Frame counts are injected (no wall clock). (AC 16)
- [x] G3. Existing flow tests that assume INTRO -> FIGHT (`test_game_flow.gd`, `test_intro_screen.gd`, `test_metrics_flow.gd`, `test_practice_flow.gd`, `test_title_input.gd`) set `Game.tutorial_routing_enabled = false` in their `before_each` (so they keep their meaning), and the flow test is the only one that turns it on. Record the list in Completion Notes. (AC 17)
- [x] G4. `test_text_audit.gd`: the new screen_text fields are ASCII, within the prompt width (64 chars at 1x), and each prompt has its device variants. (AC 9, 17)
- [x] G5. Replays: `tests/integration/test_infinite_loop_replay.gd` and `tests/replays/test_replays.gd` run unedited and must pass (the tutorial never runs in them). Seed every new test that touches the dummy's RNG (none should draw). (AC 17)

### Group H: GDD, sprint and finish

- [x] H1. GDD text (`_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`): add a short "Onboarding: the tutorial" paragraph (the six tests, skip, replay, save flag) and the TUTORIAL flow state wherever the flow states are listed. No change to Boss 1 text. Do not add a second decision-log entry; the story's D-S82 calls are recorded here and cross-referenced from D-051 in Completion Notes only. (AC 17)
- [x] H2. `_bmad-output/implementation-artifacts/sprint-status.yaml`: `8-2-guided-tutorial-test-suite: ready-for-dev` (set in this create step), then `in-progress` when dev starts and `review` / `done` per the epic flow.
- [x] H3. Run the full GUT suite like CI (`--headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`, with `/Applications/Godot.app/Contents/MacOS/Godot`; read the exact command from `.github/workflows/`) and `bash game/tools/check_guards.sh`. Set Status to `review` with the Edit tool, record every design call and deviation in Completion Notes. (AC 17)

## Dev Notes

### Design calls (taken from the brief, marked [design call])

- **D-E8-4 Framing.** TUTORIAL is a flow state between INTRO and FIGHT 1 on a fresh run. The Clearing (the arena) with the tutorial dummy. The checklist is large ASCII in the play area. All pass: `ALL TESTS PASSED.` then `deploying to production...`, then Boss 1 as today.
- **D-E8-5 Steps.** Six steps as in the AC list. Prompt copy in D-S82-6. Register starts `[D, A]` like Boss 1 (`Main.fight_start_ring(run, 0)` = `Register.fight_start_for_boss(0)`).
- **D-E8-6 Skip and replay.** Skip: hold Esc 1 s (D-S82-5). Replay: title `[T] tutorial` (F2), regardless of the flag. Completing or skipping sets the flag.
- **D-E8-7 No new duck line.** Boss 1's duck beats T1 to T4 still play after the tutorial. The duck bubble is not used by the tutorial.

### Story-level calls (D-S82-n)

- **D-S82-1 Flow state placement.** `TUTORIAL` is appended to `FlowState` (after ENDING) and is pausable (P or focus loss; not Esc). Only Game writes `flow_state` (AD-08). Replays from the title use `start_tutorial_from_title`, which is the only other entry.
- **D-S82-2 Dummy is a BossController, not the practice target.** The brief said "reuse the practice target", but `PracticeTarget` takes base damage only (`DAMAGE_MULT`, no Patched, `DamageState.Kind.BASE` in `CombatResolver.tick`) and cannot grow a `;`. The dummy must take damage states and Patched, so it is a `BossController` subclass (`TutorialDummyBody`) placed in the arena's boss slot. The practice target stays as it is (practice x1, no change). Damage states and Patched then come from the existing resolver boss path (`_resolve_boss_hit`), with no resolver change.
- **D-S82-3 Shape of the steps.** A pure `TutorialSteps` (src/tutorial) consumes observations; the TUTORIAL screen (presentation) reads sim state and feeds it. No step writes sim state, so the tutorial can never change a fight outcome. Presentation reading `Arena.actions.action_serial` and the register window is AD-05-compliant.
- **D-S82-4 Dummy rules.** The dummy's whole body is a hurtbox (`overlaps_shape` unchanged), so a Dash Strike lands at any time. Only an open `;` applies Patched, because `current_weak_window()` returns ZERO while closed (WeakWindowTracker then never completes the window). A Patched hit lands the x1.5 state for the Patched duration (180 frames = 3 s, `WeakWindowTracker.PATCHED_FRAMES`) even after the `;` closes. Timer: closed 180 frames, open 120 frames, first closed (fixed, sim frames, no RNG). No miss line on the dummy (`body_touch_px` stays INF): a closed hit is an ordinary resisted hit, which is what the crit prompt teaches. This keeps `test_combo` passable from the start, which the brief's ordering needs.
- **D-S82-5 Skip gesture.** Keyboard: hold Esc for 60 consecutive unpaused sim frames. Pad: hold `JOY_BUTTON_BACK` (Select) for 60 frames (Start pauses, so it cannot be the skip). A tap of Esc in TUTORIAL does nothing (pause is `P` there, A6). The title replay's "Esc returns to the title" (epics.md 8.2) is the same hold, which ends at TITLE; see Open Questions 4.
- **D-S82-6 Copy.** All prompts 64 characters or fewer, ASCII, 1x. Copy (keyboard names; pad names substituted by `glyph_name`):
  1. `test_move`: `Move: WASD or arrows. Walk about three tiles.`
  2. `test_actions`: `J runs the left live bit, K the right one. Use both.`
  3. `test_shift`: `Q / E shift the register. Shift until the bits read A D.`
  4. `test_combo`: `J then K, fast: Dash Strike.`
  5. `test_patch`: `Dash Strike the ; while it is open: PATCHED.`
  6. `test_crit`: `PATCHED = x1.5 for 3 s. Unpatched hits are x0.5. Hit it now.`
  Steps are strictly ordered (tasks D3): a Dash Strike made before step 3 passes nothing, so the player meets the `[A, D]` window first. Step 4 counts any Dash Strike that lands on the dummy, whatever the window.
- **D-S82-7 Completion text.** `ALL TESTS PASSED.` / `deploying to production...` on two lines (the one-line copy is 44 characters, 704 px at 2x, wider than the 512 px play area; see Open Questions 2). Outro 90 frames, then the exit.
- **D-S82-8 Save version.** `SaveService.VERSION` 1 -> 2. `parse` must accept 1 (a v1 file has no key, so the flag reads false) or the existing players' saves are wiped (today any other version resets the save). The one test that uses version 2 as "bad" moves to 3 (B3). Writing is always version 2.
- **D-S82-9 New run and the flag.** `[N] new run` resets the boss progress only (`reset_run_progress`), not `tutorial_done`. A new run therefore still shows the Intro and skips the tutorial once the flag is true. The brief's "Retry, Continue and resume never re-show it" holds.
- **D-S82-10 Last input device.** Story 7.5 added bindings only; no last-input-device tracking exists in `game/src` (grep finds no device state). This story adds `TutorialScreen` tracking (E4), default keyboard, with no autoload. If a later story needs device state elsewhere it moves to an autoload then.
- **D-S82-11 NFR10.** The first player shift is in the tutorial (`test_shift`), so `Game._on_register_shifted` logs `first_shift_s` in TUTORIAL too (A7). The budget: intro cap 480 frames + the three movement-led steps; the test (G2) fails if the scripted route needs more than 1800 frames to the shift. The tutorial has no timeout of its own.
- **D-S82-12 Seeding.** The dummy draws no RNG. Tests that tick it still seed `SimContext.rng` (the Epic 6 flaky-CI lesson in the brief).
- **D-S82-13 No pad replay in 8.2.** Every pad button not in `OPTION_ACTIONS` starts the run (`TitleScreen.classify`), and the free buttons are the start buttons. No pad replay binding; a click on the label works, as does `T`. See Open Questions 6.
- **D-S82-14 Title layout.** The title's options column ends at Fullscreen (336); the base is 360 px, so a sixth row (368) does not fit. `[T] tutorial` shares the practice row (304): practice left, tutorial right, two glyph cells between them. The practice label's rect moves with it (tests F3).

### Code facts verified at baseline c4484ca

- `game/src/autoloads/game.gd`: `enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }`; `PAUSABLE_STATES` (INTRO, FIGHT, ENDING); `start_run_from_title` / `resume_run_from_title` / `start_practice_from_title` (TITLE only); `finish_intro` (run.start_boss(0), then FIGHT); `advance`; `finish_defeat`; `finish_harvest` (swallows presses, D-S29-12); `debug_jump`; `_set_flow_state` (fight entry capture, `SaveService.note_fight_start` on non-retry, non-debug, non-practice FIGHT entries); `_on_register_shifted` (logs first shift in FIGHT only, source `&"player"`); `on_player_damaged`; `record_death`; `retry`. Only Game writes `flow_state`.
- `game/src/main/main.gd`: `apply_flow_state(state, boss_index)` (arena visible only in FIGHT, `duck_only` for HARVEST / INTRO / ENDING, `enter_fight` only in FIGHT, `_attach_practice_target`, `_attach_boss(in_fight)`); `_make_screen` (match on FlowState); `boss_def_path_for(debug_test_boss, boss_index, practice, segfault_on)` (static, pure); `wants_practice`, `wants_test_boss`; `fight_start_ring`; `practice_view` is added to the arena at `main.gd:138`.
- `game/src/arena/arena.gd`: `enter_fight(fight_start, with_practice, p_boss_def_path, breakpoint_unlocked, watch_unlocked, assist)`; `_set_boss` (one controller per path, `body_center_px` = `TEST_BOSS_PX` for the framework boss, `combat.boss = boss`); `boss_class_for(path)` (static); `TEST_BOSS_DEF_PATH` / `TEST_BOSS_PX` (`SPAWN_PX + (0, -5 tiles)`); `play_area()` = `Rect2(0, 0, 512, 288)` (TILE_PX 16, 32 x 18 tiles); `PRACTICE_TARGET_PX`.
- `game/src/bosses/framework/boss_controller.gd`: `setup`, `reset_for_fight` (clears `weak_window`, phase 0, GAP, active), `tick` (weak window ticks, `_tick_body`, FSM step, `_check_contact`), `_advance` (GAP with an empty candidate list stays in GAP, no RNG: this is how the dummy never attacks), `_attacks_allowed()` (false holds GAP, no pick), `is_hittable()` (GAP, TELL, ACTIVE, RECOVERY, live), `current_weak_window()` (phase window), `take_hit`, `mark_hit`, `hit_target_id()` (`&"boss"`), `overlaps_shape` (the body circle), `hit_position`, `body_touch_px` / `body_overlaps_shape` / `weak_point_open` (8.1 hooks; the dummy keeps the defaults except `weak_point_open` if used), `_tick_body` (default nothing), `whiff_stun_range_px` 0.0 (no stun), `decoy_hit` 0.
- `game/src/combat/combat_resolver.gd`: `tick` (ACTIVE frames only; PASS_THROUGH early return; `boss_overlapped` / `_resolve_boss_hit` for the boss; `hit_landed` with the DamageState from `weak_window.is_patched()`; `patched_applied` emitted by the resolver when `WeakWindowTracker.process` applies it), `_resolve_boss_hit` (`BossInteraction.HIT` with the action window and the combo flag, `WeakWindowTracker.process`, `DamageCalc`, `boss.hit_position()`, `hit_landed`), `_note_body_touch` / `_check_miss` (8.1; the dummy never touches them).
- `game/src/combat/weak_window_tracker.gd` (`PATCHED_FRAMES` 180; `apply_patched`, `is_patched`, `process` = `BossInteraction.completes_weak_window`); `game/src/combat/boss_interaction.gd` (`completes_weak_window`: window equal to the weak window, and a combo or link_second HIT, a PASS_THROUGH or a DECOY_STRUCK; a solo hit never completes it); `game/src/combat/damage_state.gd` (`Kind` BASE 0, UNPATCHED 1, PATCHED 2; x1.0 / x0.5 / x1.5); `game/src/combat/hit_feedback.gd` (crit hit-stop 8 for a Patched hit that did not apply it).
- Register: `Register.Bit` ATTACK = 1 (`A`), DASH = 2 (`D`), LOOP = 3 (`L`), NULL_BIT = 4 (`N`); window = (J bit, K bit) (`ActionStateMachine.action_window`, `action_1` = J = window.x, `action_2` = K = window.y). Infinite Loop weak windows are (1,2) and (2,1): `Vector2i(1, 2)` is `[A, D]`.
- `game/src/autoloads/event_bus.gd`: `hit_landed(target, damage, state, is_combo, pos)`, `hit_missed` (8.1), `patched_applied(boss, frames)`, `register_shifted(direction, window, ring, source)`, `flow_state_changed`, `pause_toggled`. The tutorial's gates listen to these where an event exists; the per-frame observations (movement, action id, window) are read from the sim by the screen.
- `game/src/autoloads/save_service.gd`: `VERSION` 1; `parse` rejects any other version (fresh save, one warn); `defaults()`, `to_config`, `reset_run_progress` (boss progress only), `set_assist`, `set_muted`; `track_fights` and `path` are test seams (empty path under GUT).
- `game/src/ui/screens/title/title_screen.gd`: `OPTION_ACTIONS` (new_run, practice, debug_build, fullscreen), `available`, `label_rects`, `classify` / `option_of` / `resolve`, `_begin` / `_begin_practice`, `_draw` rows: TITLE 160, PROMPT 208, NEW_RUN 240, DEBUG 272, PRACTICE 304, FULLSCREEN 336 (`TEXT_SCALE` 2, base 640 x 360). Pad: `title_option_new_run` button 4, `debug_build` 1, `practice` 7 (L3), `fullscreen` 8 (R3); any other pad button starts the run.
- `game/project.godot [input]`: `pause` = Esc (physical 4194305) and P, pad Start (6); `title_option_practice` = P and L3; `title_option_tutorial` does not exist yet.
- `game/src/ui/text/text_screen_text.gd` (`TextScreenText`): exported strings (title, prompt, new_run_label, debug labels, practice_label, practice_hint, fullscreen labels) and `all_text()` / `validate()` (ASCII). `test_text_audit.gd` checks screen text.
- `game/src/presentation/boss_view.gd`: `_draw_ring(body: InfiniteLoopBody)` (line 184), `_draw_open_cue(body: InfiniteLoopBody, jitter)` (line 407; typed to the Infinite Loop today, see E7), `semicolon_cue_on(body)`, `open_cue_marker`, `open_cue_bar`, `open_bar_fraction` (8.1), `nested_telling` (line 514).
- `game/src/core/glyph_font.gd`: `CELL` 8; `text_width(text, scale)` = chars x 8 x scale. 2x rows are 16 px, which is one tile.
- `game/src/core/run_stats.gd`: `note_first_shift(frame)` (once per run). `game/src/core/const.gd`: `BASE_RES` 640 x 360, `ARENA_TILES` 32 x 18.
- `game/tools/check_guards.sh`: sim folders are `input register player combat bosses skills arena`. `src/bosses/tutorial_dummy/` is sim code: no `Input`, no timers, no RNG outside `SimContext.rng`. `src/tutorial/tutorial_steps.gd` is pure (no sim reads). The screen under `src/ui/` is presentation.
- Existing tests that assert the INTRO -> FIGHT route or the save version: `test_game_flow.gd`, `test_intro_screen.gd`, `test_metrics_flow.gd`, `test_practice_flow.gd`, `test_title_input.gd`, `test_title_font.gd`, `test_save_service.gd` (line 123, 127-129).

### Architecture guardrails (must follow)

- AD-05 / AD-08: only Game changes `flow_state` and `SimClock.paused`; presentation reads sim state and never writes it. The tutorial's steps and skip hold are presentation-side.
- The dummy is sim (`src/bosses/`): its timer is sim frames (`_tick_body`), it draws nothing from RNG, it never reads Input.
- EventBus holds signals only; the steps are pure; no new signal is required (use the existing `hit_landed`, `patched_applied`, `register_shifted`).
- Text: game text is read from `screen_text.tres` (audited) and ASCII only; no new duck line; no new SFX, sprite or font asset.
- Tests: GUT, the file-per-story style, `before_each` sets `Game.tutorial_routing_enabled` (G3). Seeds for any RNG-touching test (D-S82-12).

### Previous story intelligence

- 8.1 gave the open `;` cue (inner marker, countdown bar, 16-px footprint) and the `hit_missed` path. This story reuses its pure cue helpers (E7); it does not change the Infinite Loop's ring or miss rules. The 8.1 review deferred the cue-vs-counter overlap (`deferred-work.md`); the dummy has no `i = N` counter, so it is not affected.
- 7.6 built the practice title option and the `start_practice_from_title` path: the replay (A4, F2) follows the same pattern (TITLE -> state, no save write for practice; the replay tutorial writes the flag on completion, D-S82-9).
- 7.3 built resume (`resume_run_from_title`, `resume_index`) and the save write rules; the tutorial never changes the resume route.
- 7.5 added pad bindings but no device tracking: see D-S82-10.

### Open Questions and Spec Contradictions (chosen defaults)

1. **Practice target vs damage states.** The brief says reuse the practice target and also that the dummy uses damage states. The practice target cannot do either a `;` or Patched. Default: a new `TutorialDummyBody` (D-S82-2). The practice target is unchanged.
2. **Completion line length.** `ALL TESTS PASSED. deploying to production...` is 44 characters, 704 px at 2x, wider than the 512-px play area and the 640-px base. Default: two lines at 2x (`ALL TESTS PASSED.` / `deploying to production...`, 25 characters = 400 px) (D-S82-7).
3. **Save version bump.** `parse` rejects any version other than 1 today, so a plain bump would wipe every existing save. Default: accept 1 and 2, write 2 (D-S82-8). Existing test line 127-129 moves its bad value to 3.
4. **Esc.** The AC says "Esc returns to the title" for the replay, and the brief says "hold Esc about 1 s" for the skip. Default: one hold gesture for both (60 sim frames). A tap does nothing in TUTORIAL. The replay hold returns to TITLE, the run's hold continues to FIGHT 1 (D-S82-5).
5. **Replay completion.** The AC says completion "starts Boss 1" for a fresh run; a replay from the title is not a run. Default: a replay ends at TITLE (A4), it does not start Boss 1, and it still writes the flag true.
6. **Gamepad replay.** No free title pad button exists (every unbound pad button starts the run). Default: no pad replay binding; the keyboard `T` and the label click work. The user may pick a button later (e.g. repurpose Select, which is the new-run button, only if new-run moves).
7. **Title row.** The 360-px base leaves no sixth option row. Default: `[T] tutorial` on the practice row (D-S82-14). Check it in a real window (no headless check of the label's look).
8. **Device tracking.** The brief says "Story 7.5 mapping" supplies device state; it does not. Default: the TUTORIAL screen tracks the last device (D-S82-10).
9. **Music and HUD in TUTORIAL.** Not checked against `audio_manager.gd`. Default: TUTORIAL plays the FIGHT music cue if the cue map is by FlowState; otherwise the arena music of the Intro. Record the choice (A2).
10. **Dummy `;` vs Patched.** Default: Patched only on an open `;` (D-S82-4). A reviewer may prefer any Dash Strike to Patch; that would make test_patch trivially passable and is rejected.
11. **Intro timeout and tutorial length.** Default: no tutorial timeout; the NFR10 test (G2) budgets the route, not the real players' pace.
12. **Debug.** Debug jump to TUTORIAL is not added (not in the brief). `debug_jump` keeps its three targets.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended.

### Debug Log References

- Full GUT suite run like CI (`--headless --path game --import`, then `-s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), the CI log markers checked on the plain log: 126 scripts, 1851 tests, 1851 passing, 0 failing, `---- All tests passed! ----`, no SCRIPT ERROR / Parse Error in the import or test logs. Orphans: 1, the pre-existing `test_ending_screen.gd` one (the baseline c4484ca also has 1).
- `bash game/tools/check_guards.sh`: OK.
- First full run after the code changes: 2 failures in existing tests, both expected consequences of the design: `test_main_layers` (arena and HUD now visible in state 6 = TUTORIAL) and `test_duck_hint` (the new tutorial dummy def is found by the data scan, and its weak window is ZERO while its `;` is closed, D-S82-4). Both tests updated (see Completion Notes).
- The terminal restarted once mid-story; the partial work was intact and the story was resumed from it.

### Completion Notes List

- Story created unattended by gds-create-story on 2026-11-17 from baseline c4484ca (story/8-1 HEAD). Design calls D-E8-4..7 taken as briefed; D-S82-1..14 recorded above.
- [design call] coordinator: the Open Questions defaults are accepted as written: D-S82-2 (new TutorialDummyBody, the practice target unchanged), D-S82-7 (two-line finish text), D-S82-8 (save accepts v1 and v2, writes v2), D-S82-5 (one 60-frame hold of Esc / pad Select for the skip in both first run and replay; a tap does nothing; the replay ends at TITLE and still sets the flag), D-S82-13 (no pad replay binding; T and the label click), D-S82-14 (the tutorial label shares the practice row; visual check flagged), D-S82-10 (TutorialScreen tracks the last device, default keyboard), D-S82-4 (Patched only through the open `;`; body hits are resisted chip damage).
- [design call] coordinator (A2, music and HUD): TUTORIAL plays the title track (`AudioManager.desired_track` groups TUTORIAL with TITLE / INTRO / ENDING), so the calm loop carries on from the Intro and Boss 1's track starts at FIGHT 1 with the normal 60-frame crossfade. No new audio. The HUD is the full fight HUD (not duck-only): the register panel, HP and the boss header (`void tutorialDummy() // hp 999`) show.
- [design call] coordinator (routing seam): `Game.tutorial_routing_enabled` defaults to `not SaveService.running_under_gut()` (read from the preloaded script, since Game is registered before SaveService). Production therefore routes INTRO -> TUTORIAL exactly when `tutorial_done` is false; under GUT the seam is off, so every existing INTRO -> FIGHT test keeps its meaning with no edit, and `test_tutorial_flow.gd` is the only file that turns it on. Deviation from G3 (which asked for `before_each` edits in five files): the GUT default replaces those edits; same effect, one place, same pattern as `SaveService.track_fights`.
- [design call] coordinator (prompt clarity): plain words, keys named per device, and the bits explained at test_actions: second row `The 2 left bits in REGISTER are live. A = slash, D = dash.` Every step has a second row (it fits the 64-column budget, AC 9 checked per device in `test_tutorial_screen.gd` and `test_text_audit.gd`). The prompt copy in D-S82-6 was reworded for a non-gamer reader (final copy in `game/data/text/screen_text.tres`): e.g. step 5 now says `The ; is the only weak spot. Wait until it lights up,` / `then hit it with a Dash Strike: it gets PATCHED.`, which answers the playtester's "when is it vulnerable" question directly.
- A1-A8 (Game, Main): `FlowState.TUTORIAL` appended (int 6), pausable. `finish_intro` routes through the pure `route_after_intro(tutorial_done, tutorial_on)`. `start_tutorial_from_title` (TITLE only; `tutorial_replay`, no first-shift clock, fresh run and stats, `run.start_boss(0)`). `finish_tutorial(frame, skipped)` writes the flag once, then FIGHT 1 (`run.start_boss(0)`, swallow presses) or, for a replay, TITLE with a clean run. TUTORIAL is not a fight entry in `_set_flow_state` (no fight-entry stats, no clear-time start, no `note_fight_start`, no seed). `handle_pause_input`: `esc_is_tutorial_skip` keeps a bare Esc from pausing in an unpaused TUTORIAL (P and pad Start pause, Esc still resumes a pause). `_on_register_shifted` logs `first_shift_s` in TUTORIAL too. `debug_jump` also clears `tutorial_replay`. Main: TUTORIAL shows the arena and the full HUD, `enter_fight(fight_start_ring(run, 0), false, TUTORIAL_DEF_PATH, false, false, assist)`, attaches the dummy to the boss view and HUD; `boss_def_path_for` gains a `tutorial` parameter checked before the boss index; `_make_screen` builds the TutorialScreen (`make_tutorial_screen`, handed the arena and the view).
- A2 FlowState review (every match / comparison in game/src): `audio_manager.gd` (music: TUTORIAL = title track; `on_boss_phase_changed` ignores non-FIGHT); `duck_director.gd` (beats only in FIGHT, `requested` reset only at TITLE: T1-T4 still play in FIGHT 1 after the tutorial); `duck_bubble.gd` (INTRO -> TUTORIAL clears the intro line as INTRO -> FIGHT did; TUTORIAL -> FIGHT keeps nothing to clear); `intro_screen.gd`, `harvest_screen.gd`, `ending_screen.gd`, `title_screen.gd`, `placeholder_screen.gd` (state-guarded, no change); `debug_keys.gd` (F-key jumps unchanged, D-S82 Open Question 12); `Game.advance` (no TUTORIAL branch: does nothing there); `Main.poll_defeat` (FIGHT only; the dummy never dies anyway).
- B1-B3 (save): `VERSION` 2, `READ_VERSIONS` [1, 2], `tutorial_done` parsed (missing key = false, wrong type = invalid), written by `to_config` (new optional parameter) and `set_tutorial_done()`; `reset_run_progress` keeps it. Tests: version 1 load keeps the save with the flag false, v2 round trip, wrong type, new run keeps the flag; the bad-version test now uses 3.
- C1-C4 (dummy): `TutorialDummyBody` (CLOSED_FRAMES 180, OPEN_FRAMES 120, closed first; `_attacks_allowed` false; `current_weak_window` ZERO while closed; `weak_point_open`; `is_semicolon_open`). Deviations, recorded: (1) `touches_player` returns false, so the dummy never hurts the player on contact (a player can die only in FIGHT, and "never attacks" should include the body); (2) `take_hit` floors HP at 1 (never DEFEATED, whatever the hit count, not only at 999 HP); (3) `body_radius_tiles` 1.5 (the drawing `{;}` is 3 cells wide, so the hurtbox matches what the player sees); (4) `TUTORIAL_DUMMY_PX` = spawn + (8, -2) tiles = (384, 112), not the test-boss spot, so the top-left checklist never covers it (checked by a test). `fixed_line` left empty (no new game text; the dummy is never defeated).
- D1-D4 (steps): pure `TutorialSteps` in `src/tutorial/`, strictly ordered, the move threshold on path length (47.9 px fails, 48 passes), J and K both, window [A, D], any combo hit on the dummy (only Dash Strike exists with [A, D] / [D, A]), Patched on `tutorial_dummy`, crit = PATCHED hit that did not apply it. Note: because the order is strict, a Dash Strike during test_combo that happens to land on an open `;` passes test_combo only; test_patch then needs another Dash Strike (consistent with D3; the second try teaches the `;` on its own).
- E1-E5 (presentation): `TutorialScreen` (ui/screens/tutorial) polls after SimClock's tick, takes a baseline on its first poll (so the spawn reset never counts as movement or an action), reads `player.position_px`, `actions.action_serial` / `action_slot` and `register.active_window()`, listens to `hit_landed` / `patched_applied` (a hit in the same sim frame as the patch is the applying hit), owns the hold (60 unpaused frames of Esc or a pad's Select) and the 90-frame outro, tracks the last device in `_input`. `TutorialChecklistView` (presentation) is the arena's first child (drawn under the `@` and the dummy): checklist at 2x top-left with a `>` on the current test, prompt rows at 1x along the bottom edge, skip hint top-right, completion rows at 2x mid-arena, all with a BG backing. [design call] dev: the `hold Esc: skip` hint is always shown (the brief says the skip is "shown as a hint line"; a hidden hint teaches nothing), and while the key is held a fill bar under it shows the hold progress (AC 12's "while held" cue).
- E6 (text): `TextScreenText` gains `tutorial_label`, `tutorial_tests`, `tutorial_prompts`, `tutorial_prompts_2`, `tutorial_hint_skip`, `tutorial_all_pass_1/2` (validated, in `all_text()`); prompts are templates with `{move} {j} {k} {shift} {skip}` filled by `TutorialScreen.prompt_text`. The key / button names are code constants (`KEY_NAMES`, `PAD_NAMES`: `(X)`, `(A)`, `LB / RB`, `SELECT`, `left stick or D-pad`), like the other input names.
- E7 (boss view): `_draw_open_cue` now calls a shared `_draw_cue_at(centre, semicolon, open_left, open_frames)` taking plain values; the dummy path draws `{;}` with the `;` inverted and the cue under it pointing up while open (`dummy_cue_on`, `dummy_cue_centre`, `dummy_cell_centre`), plain `;` while closed, the Patched stack above and the damage number under the cue. 8.1's tests pass unchanged.
- F1-F3 (title): `title_option_tutorial` = T (physical 84), no pad event. `[T] tutorial` on the practice row (`shared_row_x`, `label_rect_at`, `tutorial_label_rect`; practice moved left of centre, two 2x cells between). `_begin_tutorial` like `_begin_practice`. The existing title tests used `practice_label_rect()` and needed no change; new tests cover T as an OPTION, no pad replay, the shared row, the click, and T ignoring the save.
- G1-G5: `test_tutorial_flow.gd` (21 tests: route table, routing default, INTRO -> TUTORIAL -> FIGHT, cap route, the hold skip, tap / broken hold, paused hold, Esc vs P, outro, replay to TITLE by hold and by completion, replay outside TITLE, resume, DEAD retry, new run with the flag, first-shift metric in TUTORIAL and not in a replay, NFR10 scripted route: shift at 631 frames after the title input, budget 1800). `test_tutorial_steps.gd` (11), `test_tutorial_dummy.gd` (8, seeded RNG and checked that it never draws), `test_tutorial_screen.gd` (12), `test_text_audit.gd` + 1, `test_save_service.gd` + 4, `test_main_layers.gd` (TUTORIAL screen and arena wiring), `test_duck_hint.gd` (the dummy's window is checked with its `;` open, and ZERO while closed). Replay tests ran unedited and pass (G5).
- H1: GDD gains "Onboarding: the Tutorial" (before Boss Design) and the tutorial in the level sequence; no Boss 1 text changed; no new decision-log entry (D-051 already summarises Epic 8).
- For the reviewer / human visual check: (1) the shared `[P] practice   [T] tutorial` title row (D-S82-14); (2) the checklist, prompt rows and hint legibility over the grass in a real window, and that the BG backings do not hide the `@` (the view is drawn under the player); (3) the dummy `{;}` at (384, 112), its open cue under the `;`, and the HUD header `void tutorialDummy() // hp 999`; (4) the Esc hold in a browser: in itch.io fullscreen, Esc leaves fullscreen first (the hint still works windowed; pad Select works everywhere); (5) the music staying on the title track through the tutorial and crossfading to Boss 1; (6) whether the strict ordering (a lucky early Patch does not pass test_patch) feels fair in play.

### Review Findings (2026-11-17, gds-code-review: Blind Hunter, Edge Case Hunter, Acceptance Auditor)

- [design call] coordinator (review): a Dash Strike that both lands and applies Patched during test_combo passes test_combo AND test_patch on the same event (supersedes the D1-D4 note "passes test_combo only"); a crit must still be a later hit.
- [design call] coordinator (review): skip hold also accepts Backspace held 60 frames (Esc is eaten by the browser in itch fullscreen); hint `hold Esc or Bksp: skip`; keyboard key names are `WASD or arrow keys` / `Esc or Bksp` (AC 9 literals updated accordingly).
- Fixed: hold counter resets while paused; assist copied on both tutorial entries; view cleared on finish; "reg panel" copy; GDD sync. Tests: +2 (1853 total).
- Deferred and dismissed items: see `deferred-work.md` "Code review of Story 8.2".
- Findings: found 19 (2 medium, rest low/info), fixed 6, deferred 10, dismissed 3.

### File List

- `_bmad-output/implementation-artifacts/8-2-guided-tutorial-test-suite.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (8-2 review)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`
- `game/project.godot`
- `game/data/text/screen_text.tres`
- `game/data/bosses/tutorial_dummy/boss_def.tres` (new)
- `game/src/autoloads/game.gd`
- `game/src/autoloads/save_service.gd`
- `game/src/autoloads/audio_manager.gd`
- `game/src/main/main.gd`
- `game/src/arena/arena.gd`
- `game/src/bosses/tutorial_dummy/tutorial_dummy_body.gd` (new, + `.uid`)
- `game/src/tutorial/tutorial_steps.gd` (new, + `.uid`)
- `game/src/ui/screens/tutorial/tutorial_screen.gd` (new, + `.uid`)
- `game/src/presentation/tutorial_checklist_view.gd` (new, + `.uid`)
- `game/src/presentation/boss_view.gd`
- `game/src/ui/screens/title/title_screen.gd`
- `game/src/ui/text/text_screen_text.gd`
- `game/tests/unit/test_tutorial_flow.gd` (new, + `.uid`)
- `game/tests/unit/test_tutorial_steps.gd` (new, + `.uid`)
- `game/tests/unit/test_tutorial_dummy.gd` (new, + `.uid`)
- `game/tests/unit/test_tutorial_screen.gd` (new, + `.uid`)
- `game/tests/unit/test_save_service.gd`
- `game/tests/unit/test_text_audit.gd`
- `game/tests/unit/test_main_layers.gd`
- `game/tests/unit/test_duck_hint.gd`

### Change Log

- 2026-11-17: story file created (ready-for-dev).
- 2026-11-17: implemented (dev-story): TUTORIAL flow state, tutorial dummy, six-step checklist screen and view, Esc / Select skip hold, title `[T] tutorial` replay, save version 2 with `tutorial_done`, GDD onboarding section; 57 new tests (1851 total, all passing), guards OK. Status: review.
