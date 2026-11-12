---
baseline_commit: 00e7101
---
# Story 6.2: Dereference Combo

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Open design questions are marked [design call] with the chosen default (D-S62-n); the implementer follows them or records a change in Completion Notes. Scope: the N->A combo Dereference (a 3-tile piercing thrust that fires only from Null Dodge's active frames, the requires_first_active gate on ComboDef, the immediate start that replaces Null Dodge mid-ACTIVE, the solo-slash fallback, and the Clean Catch / Patched damage checks), and the Dereference name on the Register panel. NOT in scope: Ghost Echo and the decoy (6.1, done), Boss 3 gating (open question below), the Segfault body and its attacks (6.3-6.5), Reserved Write (6.6), final art or sound (7.x). -->

## Story

As a player,
I want N then A to thrust from inside my dodge,
so that a perfect dodge turns into my strongest hit.

## Acceptance Criteria

1. **Data.** `data/actions/dereference.tres` is an `ActionDef` with `id = &"dereference"`, `startup_frames = 2`, `active_frames = 8`, `recovery_frames = 14`, `invuln_from = 1`, `invuln_to = 10`, `hit_shape` = a `HitCapsule` (`length_tiles = 3.0`, `radius_tiles = 0.5`, D-S62-4), `base_damage = 30`, `cooldown_frames = 0`, `move_tiles = 3.0`, `cancel_into = PackedInt32Array()`, `hitstop_frames = 8`, `echoable = false`, `echo_action = false`, `redirectable = false`, `pass_through = false`, `slows_move = false`, `arms_clean_catch = false`, `decoy_frames = 0`. `data/combos/dereference.tres` is a `ComboDef` with `first = Register.Bit.NULL_BIT`, `second = Register.Bit.ATTACK`, `action` = that def, `display_name = "Dereference"`, `gap_free = false`, `requires_first_active = true`. It is added to `data/combos/combo_table.tres`. `ComboTable.validate()` and `ComboDef.validate()` return empty for the shipped table. `Defs.DEREFERENCE` is added as a preload for tests and lookups (as `Defs.GHOST_ECHO` was in 6.1).

2. **Gate field.** `ComboDef` gains `@export var requires_first_active: bool = false`. `ComboDef.validate()` rejects `requires_first_active` when the first bit's solo action has `active_frames < 1` (the gate would never open).

3. **Trigger.** Given the window `[N, A]` (N in slot 1, A in slot 2), the link is open, and the running action (Null Dodge) has its last executed frame inside its ACTIVE frames (action frames 1-30), when I press K, then Dereference starts on that tick: it consumes the press, replaces Null Dodge at once (even mid-ACTIVE), and does not hold the press. Null Dodge's cooldown is not restarted (it started on the J press), ATTACK's cooldown is 0, the link closes (combo branch), and `EchoMemory` is not written (NP-5).

4. **Fallback.** Given the same window and the link open, when I press K and Null Dodge is NOT in its ACTIVE frames (its recovery, or the link's 18-frame count after it), then K performs ATTACK's solo slash flagged `link_second` (the ordinary no-combo path of `ActionResolver._link`, D-S62-2). Dereference does not start, and no press is dropped by a gap rule.

5. **Intangibility.** Dereference is intangible on its own frames 1-10 (startup and active frames) through the existing invulnerable-frame path. It does not arm Clean Catch and does not consume it on its own (Clean Catch is consumed only by a damaging hit, existing rule).

6. **Damage.** Dereference deals 30 base damage. On a practice target it deals 30; against an unpatched boss it deals 15 (the global UNPATCHED x0.5 multiplier of `DamageCalc` is kept, [design call] D-S62-10, coordinator decision); Patched it deals 45; Patched with Clean Catch armed it deals 68 (`DamageCalc`, existing rounding). Clean Catch alone (practice target) deals 45. The test asserts 45 and 68 for the Patched cases, as the epic does.

7. **Hit-stop.** A combo hit with Dereference requests 8 frames of hit-stop through `HitFeedback.hitstop_for(true, 8)` (existing precedence rule, no new branch). A boss hit that applies Patched keeps the boss-hit hit-stop rule (`hitstop_for_boss_hit`, unchanged).

8. **Piercing thrust.** The capsule is anchored and oriented as Dash Strike's (existing path, no redirect). "Piercing" is the default behaviour of a capsule: one action hits every target and the boss it overlaps during its ACTIVE frames, once each (existing serial rule), and does not stop on the first contact. No new flag (D-S62-3).

9. **Name.** `RegisterPanel.wrap_name("Dereference")` returns `["Derefer-", "ence"]` (D-S62-5). The HUD panel shows the whole name over two rows. `test_register_panel.gd`'s expectation for "Dereference" changes from `["Dereferenc"]`; the 10-cell panel width (`WINDOW_COLS`) is unchanged. The deferred item in `deferred-work.md` ("fix in Story 6.2") is closed by this story.

10. **Decoy.** Dereference's hits never touch a live Ghost Echo decoy (6.1, D-S61-9). A live decoy is neither struck nor dispelled by Dereference.

11. **Tests.** `game/tests/unit/test_dereference.gd` covers: the shipped data validates (AC 1, 2); the gate opens on Null Dodge's ACTIVE frames and starts Dereference at once with no held press (AC 3); the fallback to ATTACK's solo slash with `link_second` outside ACTIVE, including the frame just after ACTIVE (AC 4); Dereference is invulnerable on frames 1-10 and not on 11+ (AC 5); the damage cases 30 / 45 / 68 / 45 (AC 6); the 8-frame hit-stop (AC 7); two practice targets inside one capsule are both hit once (AC 8); no EchoMemory write and no Null Dodge cooldown restart (AC 3); the decoy is untouched (AC 10). `game/tests/unit/test_combo_table.gd` drops `(N, A)` from `test_unknown_pairs_are_null`. `game/tests/unit/test_register_panel.gd` takes the new wrap expectation (AC 9).

12. **Guards and suite.** `bash game/tools/check_guards.sh` passes. The full GUT suite passes headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (the `godot` on PATH is not available here). Replays (`game/tests/replays/test_replays.gd`) and `game/tests/integration/test_infinite_loop_replay.gd` stay green; their expectations change only if a recorded input really presses K on N->A during Null Dodge's ACTIVE frames.

## Tasks / Subtasks

### Group A: Data (AC: 1, 2)
- [x] A1. `game/src/register/combo_def.gd`: add `@export var requires_first_active: bool = false` with its doc comment (D-S62-1, D-S62-2) and the `validate()` check (AC 2). Update the header comment's "Story 4.2" note to mention the gate.
- [x] A2. `game/src/core/defs.gd`: add `const DEREFERENCE: ActionDef = preload("res://data/actions/dereference.tres")` next to `GHOST_ECHO` (tests and lookups).
- [x] A3. Create `game/data/actions/dereference.tres` (AC 1 values; the capsule as a sub-resource like `dash_strike.tres`).
- [x] A4. Create `game/data/combos/dereference.tres` (first NULL_BIT, second ATTACK, `requires_first_active = true`, not gap_free) and add it to `game/data/combos/combo_table.tres`.

### Group B: The gate and the start (AC: 3, 4)
- [x] B1. `game/src/player/action_resolver.gd`: add `static func first_active_ok(action: ActionDef, action_frame: int) -> bool`, true when `action != null` and `action.startup_frames + 1 <= action_frame <= action.startup_frames + action.active_frames` (the last executed frame convention of `gap_free_ok`). Pure.
- [x] B2. In `_link`, after the `combo` lookup and before the `echo_blocked` / gap_free checks: when `combo != null and combo.requires_first_active`: if `first_active_ok(action, action_frame)` is false, set `combo = null` and `def = Defs.solo_action(target_bit)` (the fallback, AC 4; the rest of `_link` then treats it as link_second). If it is true, return `ActionRequest.new(combo.action, target_bit, K_SLOT, false, true, combo, false)` after `buffer.consume(KEYS[K_SLOT], frame)` succeeds, and do not go through the `startable` / HOLD path (D-S62-2 and D-S62-6). A cooldown on the target bit stays a plain `cooldowns.ready` check first (rule 6, the press stays buffered).
- [x] B3. `game/src/player/action_state_machine.gd`: no change expected (the combo branch of `_start` already replaces the action, starts the replaced solo's cooldown (ATTACK = 0), closes the link, and returns before `echo.remember`). Confirm by test; add no branch.

### Group C: Presentation of the name (AC: 9)
- [x] C1. `game/src/ui/hud/register_panel.gd` `wrap_name`: a single word longer than `WINDOW_COLS` is split with a trailing hyphen so it fits its row, the second part on the next row (D-S62-5). Words that fit keep the existing rule (word-wrap, at most `NAME_ROWS` lines). "Dash Strike", "Ghost Echo" and the 26-word case are unchanged.
- [x] C2. Update `game/tests/unit/test_register_panel.gd` `test_wrap_name` for "Dereference" (AC 9).

### Group D: Tests (AC: 11, 12)
- [x] D1. `game/tests/unit/test_dereference.gd`: the cases in AC 11. Build the FSM with `InputBuffer`, `Register`, `Player` and an injected `ComboTable` as in `test_ghost_echo.gd` / `test_echo_dash.gd`. Use the test boss (`src/bosses/test_boss/`) for the Patched and Clean Catch cases, and practice targets for the piercing case.
- [x] D2. Update `game/tests/unit/test_combo_table.gd` (`test_unknown_pairs_are_null`: drop `(N, A)`).
- [x] D3. Run GUT and `bash game/tools/check_guards.sh`; check the replay tests (AC 12).

## Dev Notes

### Design calls for this story (D-S62-n)

- **[design call] D-S62-1 Dereference is a combo data def, shipped globally.** `data/actions/dereference.tres` is the action of `data/combos/dereference.tres` (N->A), the same pattern as Ghost Echo (6.1, D-S61-1), Echo Dash (4.2) and Dash Strike (2.6). It replaces ATTACK's solo slash on the [N, A] window. The GDD lists "Boss 3" as where it exists; the table has no per-boss gating today, so the same open question as 6.1 applies (see Open questions).
- **[design call] D-S62-2 The gate is a field on ComboDef, read from Null Dodge's last executed frame.** `requires_first_active` is the data for the GDD rule "Must be pressed during Null Dodge's active frames" (architecture rule 2: "valid only while the first action is in ACTIVE"). The architecture pseudo-code names it `link.first_active_left > 0`; this story instead reads the running action and its last executed frame (`first_active_ok`), which needs no new counter on LinkState and matches `gap_free_ok` (D-S42-4). When the gate is closed, the press falls through to the ordinary no-combo path (`link_second` solo slash), exactly as the epic's "K performs ATTACK's solo slash instead" says.
- **[design call] D-S62-6 The gate opens an immediate start, not a held press.** Null Dodge's `cancel_into` is `[DASH]` only, so `_link`'s normal `startable` rule (not running, or in recovery with the target in `cancel_into`) would never let Dereference start during Null Dodge's ACTIVE frames: the press would be held and then dropped. So a gate-open press starts the combo on that tick, replacing Null Dodge mid-ACTIVE, the same way a gap_free combo does (D-S42-11). It is not gap_free because a closed gate must fall back to the solo slash, not DROP the press. No vulnerable frame falls between Null Dodge and Dereference: Null Dodge's invulnerable frames 1-30 are exactly its ACTIVE frames, and Dereference's frame 1 is invulnerable.
- **[design call] D-S62-3 "Piercing" is the capsule's default, no flag.** The current resolver already hits every overlapping target once per action (serial rule), and no action stops on first contact. Adding a `piercing` flag would change nothing; the story documents the behaviour and tests it (AC 8). If playtests ask for a single-target thrust, that is a new flag, not this story.
- **[design call] D-S62-4 Frame data and capsule size.** Startup 2, active 8, recovery 14 (GDD). Invulnerable 1-10: the GDD says "stays intangible through its active frames", read as startup plus active (frames 1-10), the same end frame as Dash Strike's invulnerable range. Capsule length 3.0 tiles (GDD "thrust of 3 tiles"), radius 0.5 tile (Echo Dash's radius), anchored as Dash Strike's. `move_tiles = 3.0`: the thrust carries the player the same 3 tiles, like Dash Strike's capsule length and move distance (5 and 5). Balance tune at the playtest if the capsule catches too little.
- **[design call] D-S62-5 Long names on the panel.** "Dereference" is 11 characters; the panel is `WINDOW_COLS = 10` cells wide, and the 6.1 deferred note asked that this be fixed here. Widening the panel would move the layout of every row (`register_panel.gd` cols 1-10 are a fixed design), so this story hyphenates the single over-long word instead: `["Derefer-", "ence"]`. The rule is generic (an over-long single word is hyphenated across two rows); the expectation is pinned in AC 9. Alternative (widen to 11 cols) rejected for layout risk this late in the window.
- **[design call] D-S62-7 Cancels out of Dereference: none.** `cancel_into` is empty (as Dash Strike's): once the thrust starts, its 24 frames are committed. The GDD's "every player action can be cancelled into DASH or Null Dodge during its recovery" is read as applying to solo actions; if playtests want the recovery cancel, it is a one-line data change (`cancel_into = [DASH]`).
- **[design call] D-S62-8 Dereference hit-stop is the combo value.** `hitstop_frames = 8` (GDD combo hit: "8 (Dereference)"), the maximum the ActionDef validator allows (`<= 8`, the InputBuffer window). Boss hits keep the boss-hit precedence rule.
- **[design call] D-S62-9 The decoy is not touched.** Dereference's hit path is the player's hit path: it never reads the Ghost decoy (6.1, D-S61-9). Dereference does not dispel or strike a live decoy.

### Architecture and rules that bind this story

- AD-02 / NP-1: the resolver is the only J/K -> action path. N->A is a `ComboTable` entry; the gate is a field read in `_link`, not a new branch in the FSM.
- NP-1 rule 2 (game-architecture.md ~line 585): the gate is the `requires_first_active` rule; a closed gate falls to rule 3 (the link_second solo).
- NP-4 / D-S32-6: a Dereference hit on a boss uses the existing hit path; Patched is only applied by `WeakWindowTracker`, and `DamageCalc` is the only damage producer.
- NP-5 / D-S41-1: combos never enter Echo memory.
- AD-01: all durations are int sim frames; no `delta`.
- Single writers: J/K -> `ActionResolver`; Patched -> `WeakWindowTracker`; damage -> `DamageCalc`; register -> `Register`.
- Defs are read-only at runtime: `dereference.tres` is never mutated.

### Existing code this story touches (read before editing)

- `game/src/register/combo_def.gd`: `NAME_MAX_CHARS = 11` (Dereference is exactly 11, so it passes), `validate()`, `gap_free` (the pattern for the new flag's doc comment).
- `game/src/player/action_resolver.gd`: `_link` (the only edit point, B2), `_gap_free_link` and `gap_free_ok` (the model for the immediate start and the frame convention, B1), `_solo` / `_cancel` (unchanged).
- `game/src/player/action_state_machine.gd`: `_start` combo branch (already correct, B3); `state_for` / `ActionState.ACTIVE` for reference (the gate itself uses `first_active_ok`).
- `game/src/player/action_def.gd`: no new field (the capsule is `hit_shape`, invuln is `invuln_from/to`).
- `game/src/player/player_health.gd`: `apply_hit` honours Dereference's invulnerable frames through `_actions.invulnerable()`; no change.
- `game/src/combat/combat_resolver.gd`: `tick` / `hits_for` / `_resolve_boss_hit` / `consume_clean_catch` (Clean Catch consumed on `dealt > 0`, existing). No change expected.
- `game/src/combat/damage_calc.gd`: `CLEAN_CATCH_PCT` (x1.5, round half up once). No change.
- `game/src/combat/hit_feedback.gd`: `hitstop_for(true, 8) == 8`. No change.
- `game/src/ui/hud/register_panel.gd`: `wrap_name` (C1), `WINDOW_COLS = 10`, `NAME_ROWS = 2`.
- `game/data/actions/dash_strike.tres`: the model for a capsule action (sub-resource `HitCapsule`, cancel_into empty, combo hit-stop).
- `game/data/actions/null_dodge.tres`: read only (invuln 1-30 = ACTIVE, `cancel_into = [DASH]`, cooldown 120 started on the J press).
- `game/data/combos/combo_table.tres`: add the N->A combo.
- `game/tests/unit/test_combo_table.gd`: `test_unknown_pairs_are_null` drops `(N, A)`.
- `game/tests/unit/test_register_panel.gd`: `test_wrap_name` for "Dereference" (C2).
- `_bmad-output/implementation-artifacts/deferred-work.md` (line ~181): the "Dereference" name item is closed by this story; mark it in the Completion Notes.

### Previous story intelligence (6.1 Ghost Echo, the combo pattern)

- 6.1 added a combo `ComboDef` + `ActionDef` and a `Defs` preload, changed `test_combo_table.gd` for the pair, and kept the FSM's combo branch as the only start path. 6.2 follows the same shape, with one new field on ComboDef (the gate) and one new resolver branch (B2). Keep the two changes small and tested.
- 6.1 review (deferred): "Cast inside an already-locked ACTIVE hazard..." and "Aim snaps back..." are about the decoy, not this story.
- 6.1 completion: `ActionDef.validate` already enforces `hitstop_frames <= 8`; Dereference's 8 is at the cap.

### Previous story intelligence (4.2 Echo Dash, the gap_free pattern)

- 4.2 added `ComboDef.gap_free` and `ActionResolver._gap_free_link` (D-S42-11): a combo that starts mid-ACTIVE when the running action's last frame is invulnerable, with a DROP instead of a hold. 6.2's immediate start (D-S62-6) reuses the "start on the press tick" idea but falls back to the solo slash instead of dropping the press.
- 4.2 D-S42-7: when a pair gains a combo, the no-combo tests inject an empty `ComboTable` or use another pair; do the same if any link_second test uses (N, A).

### Previous story intelligence (5.5 Null Dodge and Clean Catch)

- 5.5 D-S55-4: Clean Catch is armed only by Null Dodge's invulnerable frames (= its ACTIVE frames). The gate's frame range is therefore the same window in which Clean Catch can be armed. The Clean Catch x1.5 applies to the Dereference hit through the existing `consume_clean_catch` rule (AC 6).

### Project Context Rules (from project-context.md)

- Dereference: N->A combo, only during Null Dodge's ACTIVE frames, a 3-tile piercing thrust, 30 base damage (x1.5 with Clean Catch), 8 frames of hit-stop (project-context.md line ~86: "Dereference only during Null Dodge's ACTIVE frames").
- Only `SimClock` ticks; no `_process`/`delta`/`Timer`/`await` in simulation code.
- Static typing everywhere; `StringName` ids (`&"dereference"`); `*_frames` and `*_tiles` names; `*_def.gd` for defs; files snake_case.
- Logging: `Log.debug(&"action", ...)` on start events only; no `print`.
- Tests: `tests/unit/test_<subject>.gd` for pure logic; build systems from defs plus an injected `ComboTable`; no scene tree needed.

### Project Structure Notes

- New: `game/data/actions/dereference.tres`, `game/data/combos/dereference.tres`, `game/tests/unit/test_dereference.gd` (plus `.uid` files created by Godot on first open).
- Modified: `game/src/register/combo_def.gd`, `game/src/player/action_resolver.gd`, `game/src/core/defs.gd`, `game/src/ui/hud/register_panel.gd`, `game/data/combos/combo_table.tres`, `game/tests/unit/test_combo_table.gd`, `game/tests/unit/test_register_panel.gd`.
- No conflict with the architecture tree: Dereference lives in `data/actions` and `data/combos` as game-architecture line 440 lists (`dereference`).

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: Dereference 30 base; Patched 45; Patched with Clean Catch 68; intangible frames 1-10; hit-stop 8; Null Dodge cooldown 120 (not restarted).
- Guards in CI: `bash game/tools/check_guards.sh`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2: Dereference Combo] (ACs)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] combos table (N->A row, line ~196), combo hit hit-stop (line ~236), Clean Catch (line ~177), Boss 3 damage arithmetic (line ~415), phase 2 (line ~420)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md] D-008, D-020 ("Dereference must be pressed during Null Dodge")
- [Source: _bmad-output/game-architecture.md#AD-02], [#NP-1 rule 2, line ~585 and ~608], [#NP-4], [#NP-5]
- [Source: _bmad-output/implementation-artifacts/6-1-ghost-echo-combo.md] D-S61-1 (global combo), D-S61-9 (decoy not dispelled by player hits)
- [Source: _bmad-output/implementation-artifacts/4-2-echo-dash-combo.md] D-S42-4, D-S42-7, D-S42-11 (gap_free)
- [Source: _bmad-output/implementation-artifacts/5-5-null-bit-null-dodge-and-clean-catch.md] D-S55-4 (Clean Catch armed by Null Dodge)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] line ~181 (the Dereference name item, closed here)
- [Source: _bmad-output/project-context.md] line ~86 (Dereference only during Null Dodge's ACTIVE frames)

## Design calls

- D-S62-1 to D-S62-9: see Dev Notes above (IDs are the source of truth; each is referenced in the Tasks and ACs).
- **[design call] D-S62-10 AC 6 contradiction resolved: keep the global unpatched x0.5.** Dereference deals 15 to an unpatched boss and 30 base on a practice target. No damage code changes.

## Open questions (not blocking)

- D-S62-1: GDD says Dereference "exists in Boss 3", but the table ships it globally (as Ghost Echo and Echo Dash do). Gate it when Boss 3 lands (6.3), or leave it global? Same question as D-S61-1; confirm with Tiziano.
- D-S62-4: the 3-tile capsule and radius 0.5 are a first guess; the hit-test balance is for the playtest (7.8).
- D-S62-5: the hyphenated name "Derefer-" / "ence" is a stand-in for the panel; final layout is a 7.x presentation item.
- D-S62-7: cancel-out-of-recovery is off by default; playtest may want DASH.

## Dev Agent Record

### Agent Model Used

gds-create-story (unattended pipeline run, context creation); implementation by gds-dev-story (Claude Opus, unattended)

### Debug Log References

- First GUT run silently skipped `test_dereference.gd` (parse error: assigning to `Defs.NULL_DODGE` const member); fixed by mutating through a local var and restoring.

### Completion Notes List

- Coordinator decisions applied: global combo (no Boss 3 gating, D-S62-1); capsule 3.0 x 0.5 and "Derefer-" / "ence" kept (D-S62-4, D-S62-5); `cancel_into` empty (D-S62-7); action-frame gate (`first_active_ok`) instead of the architecture's `link.first_active_left` (D-S62-2).
- `ActionResolver._link`: a `requires_first_active` combo with the gate open starts on the press tick (consumes the press, or uses an already held one), replacing Null Dodge mid-ACTIVE; a cooling-down target bit stays buffered. Gate closed -> `combo = null`, `def = solo_action(K)` and the ordinary link_second path (hold during Null Dodge recovery, start after it).
- `ComboDef.requires_first_active` + validator check (first solo `active_frames >= 1`). FSM unchanged (B3 confirmed by tests: Null Dodge cooldown keeps counting, ATTACK cd 0, link closed, Echo memory not written).
- `RegisterPanel.wrap_name`: an over-long single word is split by `hyphen_split` at the last consonant->vowel boundary with head <= 9 chars and tail >= 2 (hard cut otherwise). "Dash Strike", "Ghost Echo", the 26-word case unchanged.
- Spec contradiction (AC 6): "against an unpatched boss it deals 30" conflicts with the existing UNPATCHED x0.5 multiplier (`DamageCalc`, as in test_clean_catch: slash 10 -> 5). Unpatched boss = 15. Tested: practice target 30, Clean Catch alone (practice target) 45, Patched boss 45, Patched + Clean Catch 68, unpatched boss = DamageCalc(30, UNPATCHED) = 15. No code change to damage.
- Deferred item (deferred-work.md, "Dereference" cut to "Dereferenc") closed and annotated.
- Results: full GUT suite 1376/1376 passing (97 scripts, replays and infinite-loop replay included, no expectation changes); `check_guards.sh` OK.

### File List

- game/data/actions/dereference.tres (new)
- game/data/combos/dereference.tres (new)
- game/data/combos/combo_table.tres
- game/src/core/defs.gd
- game/src/player/action_resolver.gd
- game/src/register/combo_def.gd
- game/src/ui/hud/register_panel.gd
- game/tests/unit/test_dereference.gd (new, + .uid)
- game/tests/unit/test_combo_table.gd
- game/tests/unit/test_register_panel.gd
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-12: Story 6.2 implemented (Dereference N->A combo, requires_first_active gate, hyphenated long combo names); status -> review.

## Story Completion Status

Status: review. Story context created unattended; the implementer follows the [design call] items or records a change here.
