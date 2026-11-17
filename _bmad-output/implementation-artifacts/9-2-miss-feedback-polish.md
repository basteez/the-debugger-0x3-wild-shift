---
baseline_commit: 9a69d5b
---

# Story 9.2: Miss Feedback Polish

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from story/9-1 HEAD 9a69d5b (stacked; PR base story/9-1-input-grace-and-tutorial-polish). Sources: Epic 9 in epics.md, the brief epic9-brief.md (story 2) and the triage epic9-triage.md (gameoff-wt/), deferred-work.md lines 609-610 (Story 8.1 review). Self-made choices are marked [design call] D-S92-n; the implementer follows them or records a change in Completion Notes. Scope: deferred-work.md items 609 and 610 only. -->

## Story

As a player,
I want the miss line to appear only when I really swung at the ring I could see, and never for an Echo replay, a combo opener or a swing that already stunned me,
so that the log says what happened once, and a swing at a blinked-out ring does not read as a miss I could have avoided.

**Requirements:** deferred-work.md 609 and 610 (8.1 review, both low); triage 9-2 is not this story (see the brief: story 2 is miss feedback only). D-S92-1..6 below. Presentation and resolver bookkeeping only: no damage, no mark, no hit-stop, no RNG, no save change, no new asset, no new text. Replays unchanged.

## Acceptance Criteria

1. **Given** the Nested Loop TELL blink hides the ring on a frame (the same predicate that hides the ring drawing) **When** a damaging player hit shape touches the ring body on that frame **Then** `BossController.body_touch_px` returns `Vector2.INF` (no touch recorded) and no `EventBus.hit_missed` is emitted for that action because of that frame (609). [design call] D-S92-1.
2. **Given** the same geometry on a frame where the ring is drawn **When** the action's last ACTIVE frame lands nothing **Then** one miss is still logged, exactly as Story 8.1 AC 5 (no regression). [design call] D-S92-1.
3. **Given** the blink predicate **When** it is evaluated in the sim **Then** it is one pure sim-side function (`InfiniteLoopBody`), and `BossView.nested_flash_hidden` / `BossView.semicolon_cue_on` return the same values for every `frames_left` in 0..60 during TELL (presentation delegates; drawing is unchanged). [design call] D-S92-1.
4. **Given** an Echo replay (`actions.echoing` true) of a damaging action on the closed or open ring that lands nothing **When** its last ACTIVE frame is resolved **Then** no `hit_missed` is emitted (610, "Echo replay"). [design call] D-S92-2.
5. **Given** a combo opener whose K follow-up is held (`actions.link.held` true at the opener's last ACTIVE frame) and that lands nothing **When** its last ACTIVE frame is resolved **Then** no `hit_missed` is emitted; the follow-up is the action that is judged (610, "non-final combo steps"). [design call] D-S92-3.
6. **Given** a combo action with its link closed (the A+D Dash Strike, test at test_combat_resolver.gd ~681) that lands nothing **When** it resolves **Then** it still logs exactly one miss (pinned, unchanged). [design call] D-S92-3.
7. **Given** an ATTACK slash whose last ACTIVE frame begins an NPE whiff stun on the same frame (boss centre within `whiff_stun_range_px()`, body touched) **When** the tick resolves **Then** the stun is applied and no `hit_missed` is emitted on that frame (610, same-frame overlap). The whiff line is the only feedback for that swing. [design call] D-S92-4.
8. **Given** any of AC 4 to 7 **When** the action lands something (boss, decoy, practice target) **Then** behaviour is unchanged (no miss, as today).
9. **Given** the story is done **When** the replay hash tests and the full GUT suite run in CI order **Then** every replay hash is unchanged (no sim state written by the new code, `_body_touch_*` stays resolver-local and is never hashed), `game/tools/check_guards.sh` passes, and all existing 8.1 miss tests pass unedited except where a test name in this story says it is added. [design call] D-S92-5.
10. **Given** deferred-work.md items 609 and 610 **When** the story is done **Then** each carries "Resolved in Story 9.2 (D-S92-n)" with the decision IDs, the original text stays, and no other item changes. [design call] D-S92-6.

## Tasks / Subtasks

### Group A: Blink gate on the ring body (609)

- [x] A1. `game/src/bosses/infinite_loop/infinite_loop_body.gd`: add `const FLASH_BLOCK := 6` (moved from `game/src/presentation/boss_view.gd` line 48) and `func ring_blinked_out() -> bool`: true while `state == BossState.TELL` and `current != null and current.id == NESTED_LOOP_ID` and `(frames_left / FLASH_BLOCK) % 2 == 1`. Pure read, `## Story 9.2 (D-S92-1)` comment. (AC 3)
- [x] A2. `game/src/presentation/boss_view.gd`: `const FLASH_BLOCK := InfiniteLoopBody.FLASH_BLOCK` (keep the name: `test_boss_controller.gd` uses `BossView.FLASH_BLOCK` for the ROAR flash). `nested_flash_hidden(telling, frames_left)` and `nested_telling(body)` keep their signatures (tests `test_infinite_loop_split.gd` ~700-712 call them); the body of `nested_flash_hidden` stays the same arithmetic. No drawing change. (AC 3)
- [x] A3. `game/src/bosses/infinite_loop/infinite_loop_body.gd` `body_touch_px(shape, origin, facing)`: return `Vector2.INF` first when `ring_blinked_out()` (after the `shape == null or not is_hittable()` check), and update its doc comment. `overlaps_shape` (the `;` hurtbox) is NOT changed: a hit on an open `;` still lands during the blink (TELL is hittable). (AC 1, 2)
- [x] A4. Parity test in `game/tests/unit/test_semicolon_readability.gd` (ring body section, next to `test_no_body_while_roaring_or_defeated`): `test_ring_blinked_out_matches_the_drawn_blink` loops `frames_left` 0..60 in a Nested Loop TELL (set up as in `test_infinite_loop_split.gd` ~700-712) and asserts `body.ring_blinked_out() == BossView.nested_flash_hidden(BossView.nested_telling(body), f)`. (AC 3)
- [x] A5. `game/tests/unit/test_combat_resolver.gd` (after `test_a_plain_boss_hit_gives_no_miss`, ~line 770): `test_a_slash_on_the_blinked_out_ring_logs_no_miss` (Nested Loop TELL with the blink off-block, slash on the ring: one miss; same geometry on a blink-off frame: zero misses) and `test_a_hit_on_the_open_semicolon_during_the_blink_still_lands` (the `;` hit lands, no miss). (AC 1, 2)

### Group B: Resolver suppressions (610)

- [x] B1. `game/src/combat/combat_resolver.gd` `_check_whiff(def, serial)`: return `bool` (true when it calls `actions.begin_stun`, false otherwise). `tick()`: replace `_check_whiff(def, serial)` followed by `_check_miss(def, serial)` with `if not _check_whiff(def, serial): _check_miss(def, serial)`. (AC 7)
- [x] B2. `combat_resolver.gd` `_check_miss(def, serial)`: add `if actions.echoing or actions.link.held: return` (before the serial reset, so the touch bookkeeping of the action is dropped without emitting). Doc comment: Echo replays and combo openers with a held K follow-up never miss (D-S92-2, D-S92-3). (AC 4, 5)
- [x] B3. Do NOT exclude `actions.combo != null` (that would drop the Dash Strike miss pinned by `test_a_dash_strike_on_the_closed_ring_logs_one_closed_miss_on_its_last_active_frame`). (AC 6)
- [x] B4. Tests in `game/tests/unit/test_combat_resolver.gd` (new, after the Story 8.1 block): `test_an_echo_replay_on_the_closed_ring_logs_no_miss` (build the Echo with the helpers used by `game/tests/unit/test_echo_action.gd`; the Echo of a slash, not the pass-through Echo Dash which already logs none), `test_a_combo_opener_with_a_held_k_logs_no_miss` (press the opener, hold K, `link.held` true on the last active frame), `test_a_dash_strike_still_logs_one_miss` (pins AC 6 explicitly, same setup as ~681), `test_a_whiff_stun_on_the_last_frame_logs_no_miss` (a stub: `class_name`-free inner script or a test double that extends `InfiniteLoopBody` and overrides `whiff_stun_range_px` to 400.0; assert `player_stunned` emitted once and `hit_missed` count 0). The Infinite Loop itself never whiff-stuns (`whiff_stun_range_px` = 0 from `BossController`), so the stub is the only way to pin the overlap. (AC 4-7)

### Group C: Bookkeeping

- [x] C1. `_bmad-output/implementation-artifacts/deferred-work.md`: append `**Resolved in Story 9.2 (D-S92-n):** ...` to the lines for 609 (line 609, D-S92-1) and 610 (line 610, D-S92-2..4). Keep the original text. Do not delete history. (AC 10)
- [x] C2. Set this story's status with the Edit tool when the work is done (`review`, then `done` before the commit), and `sprint-status.yaml` `9-2-miss-feedback-polish` accordingly. Do not change it now beyond `ready-for-dev`.

## Dev Notes

### Verified facts (read from the code on 2026-11-17, branch story/9-2 on 9a69d5b)

- **Tick order.** `CombatResolver.tick` (combat_resolver.gd ~line 69): `_strike_ghost`, then for a non-pass-through ACTIVE action: `hits_for`, `boss_overlapped`, `boss.decoy_hit`, `_note_body_touch`. When nothing landed, it calls `_check_whiff` and then `_check_miss`, both on the action's last ACTIVE frame. So the whiff (stun) runs first on the same frame.
- **Miss bookkeeping.** `_note_body_touch` stores the first touch point and `_body_touch_open` per serial (resolver-local, never hashed). `_check_miss` emits `EventBus.hit_missed(boss.hit_target_id(), not _body_touch_open, _body_touch_px)` once and resets `_body_touch_serial` to -1.
- **Whiff range.** `BossController.whiff_stun_range_px()` returns 0.0 (boss_controller.gd ~468); `InfiniteLoopBody` does not override it, so the ring never whiff-stuns (8.1 test `test_a_solo_slash_on_the_closed_ring_logs_one_miss_and_no_stun`). The 610 overlap is therefore latent today and is pinned with a stub.
- **Ring body.** `InfiniteLoopBody.body_touch_px` (infinite_loop_body.gd ~417) checks `is_hittable()` and then the outer and inner contact circles (`ring.contact_radius_tiles`). It does not check the blink. `is_hittable()` (boss_controller.gd ~342) includes TELL, so a `;` hit can land during the blink.
- **The blink is presentation today.** `BossView.nested_telling(body)` (boss_view.gd ~548) checks `state == TELL` and `current.id == InfiniteLoopBody.NESTED_LOOP_ID`; `BossView.nested_flash_hidden(telling, frames_left)` (~551) is `(frames_left / FLASH_BLOCK) % 2 == 1` when telling. `FLASH_BLOCK = 6` (boss_view.gd line 48, also used by `roar_flash_on`). The sim must not read presentation (AD-05), so the predicate moves to the sim side (D-S92-1). Both `current` and `frames_left` are BossController sim fields.
- **Echo.** `ActionStateMachine.echoing` is true for an Echo replay (action_state_machine.gd `_start`, ~line 283: `is_echo = request.def.echo_action and request.combo == null`). `_echo_def` holds the replayed def.
- **Combo and link.** A combo start sets `combo = request.combo` and calls `link.close()` (`_start`, ~line 316), so a combo action has its link closed; combos are never stored. `LinkState.held` (player/link_state.gd, `held` at line 21) is true while a K press waits for its target (D-S26-5). D-S53-12 already uses `actions.link.held` to mean "combo opener, not a blind swing" in the whiff rule.
- **Existing miss tests to keep passing unedited:** `test_a_dash_strike_on_the_closed_ring_logs_one_closed_miss_on_its_last_active_frame` (~681, a combo with a closed link), `test_a_solo_slash_on_the_closed_ring_logs_one_miss_and_no_stun` (~719), `test_a_landed_semicolon_hit_logs_no_miss`, `test_a_slash_into_empty_space_logs_nothing`, `test_a_roaring_ring_gives_no_miss`, `test_a_plain_boss_never_gets_miss_feedback`, `test_a_plain_boss_hit_gives_no_miss`; `test_echo_dash.gd` ~642 (Echo Dash pass-through, zero misses already); `test_tutorial_dummy.gd` ~147 (no miss line on the dummy).
- **Existing blink tests:** `test_infinite_loop_split.gd` ~700-712 (`nested_flash_hidden`, `nested_telling`), `test_boss_controller.gd` ~737 (`BossView.FLASH_BLOCK` for ROAR).
- **Miss listeners** (no change): `game/src/ui/hud/log_panel.gd` `_on_hit_missed` (line 138), `game/src/presentation/particle_pool.gd` `_on_hit_missed` (line 167), `game/src/autoloads/audio_manager.gd` `_on_hit_missed` (line 327).

### Design calls (Story 9.2)

- **[design call] D-S92-1 Blink gate on the body, sim-side predicate.** While the Nested Loop blink hides the ring, the ring is not a touchable body for miss feedback: `body_touch_px` returns INF. The predicate lives on `InfiniteLoopBody.ring_blinked_out()`, the same arithmetic as `BossView.nested_flash_hidden`, and BossView delegates to it. The `;` hurtbox is untouched, so hits and damage are unchanged. Alternative rejected: have the resolver read `BossView` (sim would read presentation, AD-05).
- **[design call] D-S92-2 Echo replays never miss.** A replayed action is not a player swing at the ring; its outcome is the original action's. Gate: `actions.echoing`.
- **[design call] D-S92-3 Combo openers with a held K never miss.** A slash whose K follow-up is already held (`link.held`) is judged by the follow-up (D-S53-12 precedent). Combos with a closed link (Dash Strike) keep their single miss. Gate: `actions.link.held`, checked on the last ACTIVE frame.
- **[design call] D-S92-4 Whiff beats miss on the same frame.** When the whiff stun begins on the last ACTIVE frame, the NPE line is the swing's feedback and no miss is logged. `_check_whiff` returns true when it stuns.
- **[design call] D-S92-5 No sim change, no new text.** The new code writes no sim state and draws nothing new. The miss line wording (`LogPanel.line_for_miss`) and the miss particle and cue are unchanged. Replays unchanged by construction; the replay hash tests are the proof.
- **[design call] D-S92-6 Deferred-work bookkeeping.** Items 609 and 610 are annotated with the decision IDs above; the original text stays.

### Open questions (defaults chosen, no elicitation)

1. A swing at the ring during the blink logs nothing (D-S92-1). Alternative: log the miss as `closed` with the blink as the reason. Default: nothing, because the player could not see the target; the triage calls the miss "log/stat only" anyway.
2. Combo opener scope (D-S92-3): default is `link.held` only. Alternative: any open link (`link.is_open()`), which would also silence solo slashes that open a D link; not chosen because it changes the 8.1 solo-slash test.
3. Whiff overlap (D-S92-4): default is the NPE line only. Alternative: both lines. Default chosen to keep the log at one line per swing (the 610 "log spam" concern).
4. Log spam in playtests (609/610 both say "watch in playtest"): stays HUMAN in the triage; no code change here beyond the gates above.

### Testing

- Unit: `game/tests/unit/test_combat_resolver.gd` (A5, B4), `game/tests/unit/test_semicolon_readability.gd` (A4), `game/tests/unit/test_infinite_loop_split.gd` and `test_boss_controller.gd` must pass unedited.
- Seed nothing new: no boss RNG is involved in the tests above (the Nested Loop TELL is driven by `frames_left` set through the existing setup). If a test does pick attacks through RNG, seed it.
- Reset `SimClock.sim_frame` and the `EventBus` signal counts through the existing `before_each` helpers; do not add global state.
- Full GUT suite in CI order (`--headless --path game --import`, then `gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), the replay hash tests, and `game/tools/check_guards.sh`. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).

### Project Structure Notes

- Production changes: `game/src/bosses/infinite_loop/infinite_loop_body.gd`, `game/src/presentation/boss_view.gd` (delegation only), `game/src/combat/combat_resolver.gd`. No new scene, no save key, no new autoload, no new asset, no new text.
- Tests: `game/tests/unit/test_combat_resolver.gd`, `game/tests/unit/test_semicolon_readability.gd`.

### References

- [Source: _bmad-output/implementation-artifacts/deferred-work.md lines 609-610 (Story 8.1 review)]
- [Source: epic9-triage.md, per-item rows 609 and 610 (classified WONTFIX; promoted to DO for 9-2 by the coordinator)]
- [Source: epic9-brief.md, story 2]
- [Source: _bmad-output/implementation-artifacts/8-1-semicolon-readability-and-hit-forgiveness.md, D-E8-3, D-S81-3..8, AC 5, 7, 8]
- [Source: _bmad-output/implementation-artifacts/9-1-input-grace-and-tutorial-polish.md (template and stacking base)]

## Project Context Rules

- Godot 4 GDScript. Presentation reads the sim and never writes it (AD-05). Sim code never reads presentation.
- Guards: `game/tools/check_guards.sh`. Set status with the Edit tool.
- No Fable model. Never commit to main; this story's branch is `story/9-2-miss-feedback-polish`, stacked on `story/9-1-input-grace-and-tutorial-polish`, PR base the 9.1 branch.

## Dev Agent Record

### Agent Model Used

Claude (create-story, unattended); dev-story: Claude Opus (unattended, 2026-11-17)

### Debug Log References

- Red check: with the resolver gates and the `body_touch_px` blink gate reverted, the new tests fail (blinked-out ring, Echo replay, combo opener, parity test's "no body while blinked out"); restored, all pass.
- Full GUT suite CI order (`--headless --path game --import`, then `gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`): 127 scripts, 1877/1877 passing, no failure markers, "All tests passed!". Replay hash suites (tests/replays, test_infinite_loop_replay, test_breakpoint_replay) pass unedited. `game/tools/check_guards.sh`: OK.

### Completion Notes List

- Coordinator defaults accepted: blink = no miss at all (D-S92-1); combo-opener scope = `link.held` only (D-S92-3); whiff overlap = NPE line only (D-S92-4).
- A1/A2 (D-S92-1): `InfiniteLoopBody` now owns `FLASH_BLOCK`, `nested_telling()`, `static blink_hidden(telling, frames_left)` and `ring_blinked_out()` (pure reads of the hashed `state` / `current` / `frames_left`; no new state, nothing hashed). `BossView.FLASH_BLOCK` aliases it; `BossView.nested_telling` / `nested_flash_hidden` keep their signatures and delegate; `_draw_ring` and `semicolon_cue_on` call `body.ring_blinked_out()`. Small deviation from A2's wording ("body of nested_flash_hidden stays the same arithmetic"): it now delegates to `InfiniteLoopBody.blink_hidden`, which is the identical arithmetic, so there is one source of truth (coordinator: "BossView must delegate").
- A3: `body_touch_px` returns INF while `ring_blinked_out()`; `overlaps_shape` (the `;`) unchanged. The boss ticks in BOSS_HAZARDS before COMBAT, so the resolver sees the same `frames_left` the frame draws.
- A4/A5: parity test loops frames_left 0..60 in a real Nested Loop TELL. A5 split into three tests (deviation: the "drawn frame still logs one miss" half of AC 2 is its own test, `test_a_slash_on_the_drawn_ring_during_the_nested_tell_logs_one_miss`, instead of two scenarios in one test). The resolver tests put the ring into the Nested Loop TELL by setting `state`/`current`/`frames_left` (the resolver suite never ticks the boss).
- B1/B2 (D-S92-2..4): `_check_whiff` returns bool; `tick()` calls `_check_miss` only when it did not stun. `_check_miss` returns without emitting for `actions.echoing or actions.link.held`. Deviation: the gate sits right AFTER the `_body_touch_serial = -1` reset (not before), so the touch bookkeeping is actually dropped, as the task's own rationale states.
- Finding: the same-frame whiff + miss overlap (610) was already prevented incidentally: `begin_stun` calls `_finish()`, which resets `action_frame`, so `_check_miss`'s last-frame check failed. The explicit gate makes it intentional; `test_a_whiff_stun_on_the_last_frame_logs_no_miss` (WhiffLoop inner-class stub, range 400) pins it but was green before the change too.
- B3: `actions.combo` is not excluded; `test_a_dash_strike_still_logs_one_miss` and the 8.1 Dash Strike test pin AC 6.
- `_loop()` helper in test_combat_resolver.gd gained an optional trailing `body` parameter for the stub (existing callers unchanged).
- C1: deferred-work.md items 609 and 610 annotated "Resolved in Story 9.2 (D-S92-n)", originals kept. Playtest log-spam watch remains HUMAN.

### File List

- game/src/bosses/infinite_loop/infinite_loop_body.gd
- game/src/presentation/boss_view.gd
- game/src/combat/combat_resolver.gd
- game/tests/unit/test_combat_resolver.gd
- game/tests/unit/test_semicolon_readability.gd
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/9-2-miss-feedback-polish.md

### Change Log

- 2026-11-17: Story 9.2 implemented (blink gate on the ring body via a sim-side predicate; Echo / held-K opener / whiff-stun miss suppressions; 8 new tests). Status review.

### Review Findings (gds-code-review, 2026-11-17)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel, all completed). No blocking finding.

- Patched: parity test was tautological (BossView delegates); added an independent `(f/6)%2==1` expectation over 0..60.
- Verified OK: blink predicate is a pure read (no new hashed state; BOSS_HAZARDS ticks before COMBAT so sim and draw see the same frames_left); BossView draws as before; Dash Strike miss still logged (link.held false for combos); echoing resets in `_finish`; whiff-then-miss order; the `;` hurtbox deliberately ungated.
- Deferred (recorded in deferred-work.md): held-K opener with no follow-up stays silent; touch latched on a drawn block with a miss on a hidden block (swing > 6 frames); whiff test does not fail without the gate; no open-ring Echo test.
- Dismissed: negative frames_left modulo (safe, same as before); const alias cycle (class_name resolves); spec B2 order (code intentionally resets first, documented in Completion Notes).
