---
baseline_commit: 9c7a4e3
---
# Story 4.3: Breakpoint Skill
Status: review
<!-- Created unattended by gds-create-story (pipeline, 2026-11-10). Open design questions are marked [design call] with the chosen default (D-S43-n); the implementer follows them or records a change in Completion Notes. Scope: cut-ladder item #3. This story creates FeatureFlags (it did not exist), the Breakpoint freeze/shift/cooldown module behind `FeatureFlags.breakpoint`, its presentation, and the flag-off fallback (SIGSEGV recovery 150 frames, mechanism only: the SIGSEGV body is Story 6.5). NOT in scope: the hint template line (4.4), the Breakpoint duck tutorial line (5.5), the muffled music asset (7.1), the assist cooldown of 360 frames (7.4). -->

## Story

As a player,
I want to freeze time and shift calmly,
so that I always have a safety valve when the fight overwhelms me.

**Requirements:** FR24; Additional: AD-01, AD-12, NP-2. Cut ladder #3 (sprint-status: skip 4.3 Breakpoint, SIGSEGV recovery 150 frames fallback). Story 4.3 may be marked `done` only if the flag-off AC (AC 13) is implemented.

## Acceptance Criteria

1. **FeatureFlags (AD-12).** `game/src/core/feature_flags.gd` (`class_name FeatureFlags`, extends `Def`) with bool exports `reserved_write`, `watch`, `breakpoint`, `segfault`, and `game/data/config/feature_flags.tres` shipping all four `true`. `validate()` returns no errors. `Defs` preloads it as `Defs.FEATURE_FLAGS`. The `.tres` is picked up by `test_data_validation`.

2. **Registration (leaf module).** When `FeatureFlags.breakpoint` is on, `BreakpointSkill` (`game/src/skills/breakpoint/breakpoint_skill.gd`) is constructed and wired at startup and its SimClock hooks are registered. When it is off, nothing under `src/skills/breakpoint/` is instantiated. No file outside `src/skills/breakpoint/` references `BreakpointSkill` (or the overlay) by class name; the core talks to it only through the generic hooks in AC 4 and `EventBus` (D-S43-2). A test or `check_guards.sh` line pins this.

3. **Unlock and first use.** Breakpoint is available only when the current fight is Fight 2 or later (`RunState.boss_index >= 1`, i.e. after Boss 1). Presentation computes the flag and passes it into the skill at FIGHT entry as a plain bool (the simulation never reads `Game`). Space (`breakpoint`) with unlocked, cooldown 0 and not already active starts it on that tick. The first use of each fight is free (cooldown 0 at fight entry). When not unlocked, Space does nothing.

4. **Freeze, generic hooks.** `SimClock` gains two generic hooks (D-S43-3, D-S43-4):
   - `SimSystem.poll(presses: Array[StringName], ctx: SimContext) -> void` (virtual, default no-op). `SimClock.tick()` calls it on every registered system after the presses are pushed and `poll_frame` advances, and before the gate check. It runs even while the world is frozen.
   - While `breakpoint_gate_active` is true, `SimClock.tick()` ticks only the systems in the SHIFTS phase, does not tick other phases, does not advance `sim_frame`, and leaves `hitstop_frames` untouched. Polling continues and presses are stamped with `poll_frame`.
   - Test: during Breakpoint, a Q or E press applies a register shift on that tick (`register_shifted` emitted, ring changed, `sim_frame` unchanged). The existing `test_breakpoint_gate_freezes_world_and_hitstop_but_polls` still passes.

5. **Duration.** Breakpoint lasts at most 120 frozen polls (real frames; `poll_frame` based, D-S43-5). On the 120th frozen poll it ends and the world ticks on that same tick. Paused frames never count (AC 7).

6. **Ends on an action.** While active, a J (`action_1`) or K (`action_2`) press ends it on that poll (`breakpoint_ended` emitted, gate cleared before the world tick). The press stays buffered and the action executes on that same tick, the first unfrozen tick. Q, E and Space do not end it. Hit-stop frames that were running before Breakpoint resume afterwards (NP-2).

7. **Pause priority.** Pause keeps priority (`SimClock.tick` returns before polling while paused). Pausing during Breakpoint keeps it active. Paused frames do not count toward its 120 frames or toward the cooldown. Resume continues it.

8. **Cooldown.** The cooldown is 720 sim frames, counted from the ending tick (NP-2, D-S43-7). It counts only unfrozen world ticks, so hit-stop, pause and Breakpoint itself do not count. Space is refused while it runs and while Breakpoint is active, so it cannot be chained. Exact boundary: Space is refused on the 720 world ticks after the ending tick and accepted on the 721st. The HUD shows the cooldown (AC 10).

9. **Events and presentation.** `EventBus` declares `breakpoint_started` and `breakpoint_ended` (no args, past tense, AD-05). Each is emitted once per start or end.
   - `JuiceDirector` sets the screen dither to 0.5 on started and to 0 on ended.
   - A `BreakpointOverlay` (in `src/skills/breakpoint/`) draws a red `#FF4040` dot and line while active. Red is used for nothing else in this story.
   - `AudioManager` handles both events as a placeholder with no audible change and a debug log only (D-S43-9). The muffled loop arrives in 7.1.

10. **HUD cooldown.** When the flag is on and the fight is unlocked, the HUD shows a read-only Breakpoint readout: `READY` at 0, otherwise the remaining seconds, `ceil(frames / 60)`, in ink. It sits in the HUD cell layout from the GDD's HUD Layout (D-047). It is hidden when the flag is off or the fight is not unlocked. Presentation only reads the skill.

11. **Red exemption in ScreenFX.** The `ScreenFX` dither and invert leave pixels of exactly `#FF4040` unchanged. This closes the 2.8 deferred item "invert maps every non-palette pixel (red warning lines, Epic 3/4)". A test covers the rule (CPU-side helper or shader-logic mirror, dev's choice).

12. **Fight entry and exit.** Every `enter_fight` (intro, harvest, retry, debug jump) resets the skill: gate off, cooldown 0, `active` false, dither 0. If Breakpoint is active when the fight is left (debug jump or flow change), the gate is cleared and `breakpoint_ended` is emitted, so nothing stays frozen or muffled.

13. **Flag-off fallback (cut #3).** With `FeatureFlags.breakpoint = false`:
    - Space does nothing, no HUD readout, no overlay, no dither change, no `breakpoint_*` events, and no skill is constructed. Every other test still passes with the flag off (run the relevant suites once with the flag false).
    - SIGSEGV fallback (mechanism): `BossController` uses `AttackDef.recovery_if_no_breakpoint` in place of `recovery` when the flag is off and that value is > 0, otherwise `recovery`. A test with a test-boss attack set to `recovery = 90`, `recovery_if_no_breakpoint = 150` asserts 150 with the flag off and 90 with it on. The flag is injected into `BossController` (D-S43-11). The real SIGSEGV data arrives in 6.5.

14. **Replay determinism.** All durations are int frames counted in sim frames or polled frames. No `delta`, `Timer`, `await` or Tween in simulation code. A replay test records a fight with a Space start, Q/E shifts during the freeze, a J or K end and a later second Space refused by cooldown. The live and replayed states match, following the pattern of `tests/replays/test_replays.gd`.

15. **Input buffer bound (2.1 deferred item).** During a 120-frame Breakpoint with key mashing, `InputBuffer` stays bounded by the 8-frame press lifetime (no growth). A unit test pins this.

16. **Quality gates.** Full GUT suite green headless (flag on, and the flag-off run from AC 13). `bash game/tools/check_guards.sh` OK. No bare `print`. Static typing everywhere. No `Engine.time_scale`, `SceneTree.paused` or `Timer` in gameplay code.

## Tasks / Subtasks

### Group A: Flags and data (AC: 1, 2, 13)
- [x] A1 `game/src/core/feature_flags.gd` (`class_name FeatureFlags extends Def`) with four bools and `validate()`.
- [x] A2 `game/data/config/feature_flags.tres` (all true). Add `Defs.FEATURE_FLAGS` preload (no cycle: FeatureFlags does not reference Defs).
- [x] A3 Startup wiring reads `Defs.FEATURE_FLAGS.breakpoint` once (Main or Arena), constructs the skill only when on, and passes the flag to `BossController` (AC 13).

### Group B: SimClock hooks (AC: 4, 5, 7, 14, 15)
- [x] B1 `SimSystem.poll(presses, ctx)` virtual, default no-op (D-S43-3).
- [x] B2 `SimClock.tick()`: call `poll` on all systems after presses are pushed and `poll_frame` advances, before the gate. Keep the pause early return first.
- [x] B3 Breakpoint gate branch: run SHIFTS-phase systems only, do not advance `sim_frame`, do not touch hit-stop (D-S43-4). Keep `breakpoint_gate_active` as the bool the skill writes.
- [x] B4 Unit tests in `test_sim_clock.gd`: shifts apply while frozen, the rest of the world does not, `sim_frame` and hit-stop unchanged, poll hook called in order, pause stops the poll hook.

### Group C: BreakpointSkill (AC: 3, 5, 6, 8, 12)
- [x] C1 `game/src/skills/breakpoint/breakpoint_skill.gd` extends `SimSystem`. Injected: the SimClock (or a gate interface for tests), the unlock bool, the cooldown frames (720, a param so 7.4 can change it).
- [x] C2 State: `active`, `frozen_polls`, `cooldown_left`, `unlocked`. `reset_for_fight(unlocked)` (AC 12).
- [x] C3 `poll()`: start on Space (unlocked, cooldown 0, not active); while active, end on J/K or at 120 frozen polls (D-S43-5, D-S43-12).
- [x] C4 `tick()` (TIMERS phase): decrement the cooldown on unfrozen world ticks only, with the exact boundary of AC 8 (D-S43-7).
- [x] C5 Emit `breakpoint_started` / `breakpoint_ended` once per change.
- [x] C6 Unit tests `test_breakpoint_skill.gd`: start and refusals (locked, cooling, active), 120-frame cap, J and K ends, Q/E does not end, pause does not count, cooldown boundary 720/721, no chaining, reset clears gate and emits ended.

### Group D: Presentation (AC: 9, 10, 11)
- [x] D1 `EventBus`: declare `breakpoint_started` and `breakpoint_ended` (AD-05).
- [x] D2 `JuiceDirector`: dither 0.5 on started, 0 on ended, reset on fight entry.
- [x] D3 `game/src/skills/breakpoint/breakpoint_overlay.gd`: red dot and line while active; added in the arena layer order only when the flag is on.
- [x] D4 HUD readout (`src/ui/hud/`), read-only, placed per the GDD HUD Layout; hidden when off or locked.
- [x] D5 `AudioManager`: placeholder handler (log debug only).
- [x] D6 `ScreenFX` (`screen_fx.gdshader` and/or `screen_fx.gd`): exempt exact `#FF4040` from dither and invert; test.

### Group E: Boss fallback (AC: 13)
- [x] E1 `BossController`: effective recovery helper (pure static, e.g. `effective_recovery(def: AttackDef, breakpoint_on: bool) -> int`). Use it at the ACTIVE to RECOVERY transition (line ~165 in `boss_controller.gd`).
- [x] E2 Test with a test-boss attack (`data/bosses/test_boss/`) or a constructed `AttackDef`: 150 off, 90 on. Do not edit shipped boss data.

### Group F: Integration and gates (AC: 13, 14, 16)
- [x] F1 Integration test: Space, Q/E freeze shifts, J end, cooldown refusal, replay equality (AC 14).
- [x] F2 Flag-off run of the affected suites (sim clock, action FSM, boss controller, HUD) with `breakpoint = false` injected.
- [x] F3 `check_guards.sh` OK; GUT full run; the `BreakpointSkill` reference guard (AC 2).

## Dev Notes

### Design calls for this story (D-S43-n)

- **[design call] D-S43-1 FeatureFlags is created here.** It did not exist. `FeatureFlags` is a `Def` so the `.tres` validation test covers it. Only `breakpoint` is used by this story. The other three are present for 4.x-6.x and default on.
- **[design call] D-S43-2 Leaf module, generic hooks only.** The skill lives in `src/skills/breakpoint/` and is never referenced by class from core (`sim_clock.gd`, `register.gd`, `boss_controller.gd`, `arena.gd` except the single wiring point). The core knows only `SimSystem.poll`, `SimClock.breakpoint_gate_active` and `EventBus` signals. Architecture: AD-12, Cross-cutting rule 4.
- **[design call] D-S43-3 `SimSystem.poll` hook.** SimClock must read presses before the gate so that a J/K press can end Breakpoint and Space can start it while the world is frozen. A world `tick` cannot do that, because frozen ticks skip systems. Alternative (a `breakpoint` reference in SimClock) rejected: it breaks the leaf rule.
- **[design call] D-S43-4 Register shifts run during Breakpoint.** AD-01 and the GDD say "shifting stays allowed". Today the gate returns before any system, so shifts would be lost. Fix: frozen ticks run only SHIFTS-phase systems (the register). Other phases stay frozen, `sim_frame` does not advance, and hit-stop is untouched (NP-2).
- **[design call] D-S43-5 Duration counts polled frames.** "120 real frames" = frozen polls (`poll_frame`), so pause does not burn them (pause returns before polling) and replays match because inputs are recorded per poll. The end poll clears the gate before the world tick, so the ending press executes on that tick.
- **[design call] D-S43-6 Unlock source and reset.** Unlocked = `run.boss_index >= 1`, passed as a bool at FIGHT entry. The cooldown resets on every fight entry, retry included, and is not part of the RunState snapshot (like Echo memory, the freeze is per fight attempt). [design call] A retry restarts with the first use free; the alternative (carry the cooldown into the retry) is harder to explain and was rejected.
- **[design call] D-S43-7 Cooldown counting.** 720 unfrozen world ticks counted from the ending tick (the ending tick itself does not decrement), so the refused window is exactly the 720 ticks after it (AC 8). GDD: "12 s, counted in simulation frames from when Breakpoint ends". Hit-stop and pause stop it, as with all sim frames.
- **[design call] D-S43-8 Breakpoint is J/K only for ending.** GDD: "ends early on any action input". In this game every action is J or K (the register window decides the bit), so "action input" = `action_1` or `action_2`. Shifts (Q/E) are explicitly allowed, and Space or other keys are ignored.
- **[design call] D-S43-9 Music is a placeholder.** `assets/audio/music/` has no `breakpoint_muffled.ogg` (7.1 supplies it). The events are emitted and `AudioManager` logs them. Epic AC "music switches to the muffled loop (placeholder until Epic 7)" is therefore met by the event contract, not by sound.
- **[design call] D-S43-10 Red is reserved for the Breakpoint warning.** Only the dot and line use `#FF4040` in this story, per the GDD and D-023. The ScreenFX exemption (AC 11) keeps them intact under dither and invert.
- **[design call] D-S43-11 Boss fallback reads the flag by injection.** `BossController` takes a `breakpoint_on: bool` (default from `Defs.FEATURE_FLAGS.breakpoint` at the call site, not read inside the controller), so tests can drive both sides. The rule is flag-only, not per-player: Breakpoint is always unlocked by Fight 3 (SIGSEGV is Boss 3), so the two are equal in shipped play. GDD: "150 frames if Breakpoint is cut".
- **[design call] D-S43-12 Presses in the freeze.** Q/E shifts apply, J/K ends, Space is ignored while active. Other presses expire on the 8-frame lifetime like any press. The buffer is pruned on push (verified by AC 15), so it cannot grow.
- **[design call] D-S43-13 HUD readout form.** A single text readout, `READY` or `ceil(frames/60)` seconds, in ink, in the HUD cell layout. The readout is the only Breakpoint HUD element in this story (no dithered bar or icon art).
- **[design call] D-S43-14 Dither level.** 0.5 exactly, per the GDD ("50% ink"). A test pins the value, so a playtest tune is a one-line change.
- **[design call] D-S43-15 Starting Breakpoint while a boss is not in the fight.** Irrelevant to the sim: the skill is active only when `active` is true (Arena sets it on FIGHT entry and clears it on exit), so Space on TITLE, INTRO, DEAD or HARVEST does nothing.

### Architecture and rules that bind this story

- AD-01: one fixed 60 Hz tick; gates pause > Breakpoint > hit-stop; register shifts apply during Breakpoint; `Engine.time_scale`, `SceneTree.paused`, `delta`, `Timer` and `await` are banned in simulation.
- NP-2: Breakpoint counts real frames (≤ 120); the ending action executes on the first unfrozen tick; cooldown starts at the end and counts sim frames (720); remaining hit-stop resumes afterwards.
- AD-05: every cross-system signal is declared in `event_bus.gd` only, past tense, typed args.
- AD-12: cuttable modules are leaf folders registered at startup; GDD fallbacks read the flags.
- AD-07: the screen effect (`ScreenFX`) is driven only by `JuiceDirector`; presentation is read-only over sim state.
- Palette: red `#FF4040` only for warnings (Breakpoint, SIGSEGV).

### Existing code this story touches (read before editing)

- `game/src/autoloads/sim_clock.gd`: `tick()` (poll hook, gate branch, SHIFTS-only freeze), `breakpoint_gate_active` (currently a bare bool, the gate hook owned by this story), `request_hitstop`, `begin_fight`.
- `game/src/core/sim_system.gd`: add the virtual `poll`.
- `game/src/register/register.gd`: already SHIFTS phase; `tick` applies buffered Q/E with `ctx.poll_frame`. No change expected beyond verification.
- `game/src/input/input_buffer.gd`: `push` prunes (`_prune`) on every push; `PRESS_LIFETIME_FRAMES = 8`. AC 15 pins it.
- `game/src/arena/arena.gd`: `_enter_tree` / `_exit_tree` register and unregister systems; `enter_fight` resets per fight (add the skill reset and the `unlocked` bool here).
- `game/src/autoloads/game.gd`: `_begin_fight()` (fight entry). The unlock flag is computed from `run.boss_index` by the caller; do not add a sim-side read of `Game`.
- `game/src/main/main.gd`: constructs the HUD, the juice director and the layers (`LAYER_ORDER`); the overlay joins the layer list only when the flag is on.
- `game/src/autoloads/event_bus.gd`: add the two signals.
- `game/src/presentation/juice_director.gd`: `set_dither`, `reset`.
- `game/src/presentation/screen_fx.gd` and `screen_fx.gdshader`: red exemption (AC 11).
- `game/src/ui/hud/hud.gd` and `hud.tscn`: readout (AC 10).
- `game/src/autoloads/audio_manager.gd`: placeholder handlers (AC 9).
- `game/src/bosses/framework/boss_controller.gd` (~line 165, ACTIVE to RECOVERY): effective recovery (AC 13).
- `game/src/bosses/framework/attack_def.gd`: `recovery_if_no_breakpoint` is stored and validated (Story 3.1). Its doc comment says "no behaviour until 4.3": update it.
- `game/src/core/defs.gd`: add `FEATURE_FLAGS`.
- `game/src/skills/breakpoint/` currently holds only `.gitkeep`.
- `game/tests/unit/test_sim_clock.gd` lines ~222-252 (`test_breakpoint_gate_freezes_world_and_hitstop_but_polls`): keep the assertions, extend with the shifts case.
- `game/tests/unit/test_data_validation.gd`: discovers `.tres` under `res://data/`, so `feature_flags.tres` is covered automatically.

### Previous story intelligence (4.1 and 4.2, done)

- 4.1: Echo on LOOP (`EchoMemory`, 90-frame cooldown). Echo memory is reset per fight in `ActionStateMachine.reset_for_fight`. Breakpoint follows the same per-fight reset pattern.
- 4.2: Echo Dash combo with `gap_free` acceptance (D-S42-11), `pass_through` and redirect. Two lessons: (a) a preload cycle through `Defs` broke the parse in 4.2, so `FeatureFlags` must not reference `Defs`; (b) tests that depended on the old behaviour were rewritten with reasons recorded. Expect similar churn in `test_sim_clock.gd` and the replay tests.
- 4.2 review left the Echo Dash items to a later pass (pass-through spent on first overlap; capsule not clamped; `Player.facing` not updated by redirect; refused K silently dropped). They are not 4.3 scope.

### Previous story intelligence (3.1 to 3.8, boss side)

- 3.1: `AttackDef` stores `exclusive` and `recovery_if_no_breakpoint` for 6.5 and 4.3. `BossController` is a SimSystem in BOSS_HAZARDS, and its phase changes drop the attack without `on_recovery`.
- 3.4: `RunState.fight_seed_for` gives a deterministic seed per fight attempt. Replays use it, so the Breakpoint replay test needs no new seed logic.
- 3.8: harvest and fight transitions go through `Game`; the skill is only active in FIGHT.

### Deferred items folded into this story

- 2.1 "InputBuffer grows while the world is frozen" (deferred-work.md, "Revisit with 4.3"): `push` prunes, so growth is bounded; AC 15 pins it.
- 2.8 "ScreenFX dither assumes viewport == BASE_RES; invert maps every non-palette pixel (red warning lines, Epic 3/4) to INK or BG; revisit with Breakpoint": AC 11 keeps red exact. The viewport assumption stays deferred unless a test fails.
- 2.1 / 2.8 "hit-stop or Breakpoint longer than 8 frames drops all buffered input": judged by feel at playtest, not in this story (D-S43-12 keeps the 8-frame rule).

### Git intelligence

- Branch `story/4-3-breakpoint-skill` is stacked on Story 4.2 (`9c7a4e3`), which is on top of 4.1 (`43b93a4`) and `main` (`861597f`). Do not rebase.
- Pattern for stories: pure logic in `RefCounted` or `SimSystem` classes, tests headless, thin wiring in Arena/Main.

### Latest technical information

- Pinned: Godot 4.7.2-stable (do not upgrade), GUT 9.6.1, GDScript only. Godot 4 syntax only.
- No new APIs are needed: `Vector2`, `Resource`, `SimSystem`, `ConfigFile` are not used here. `draw_line` / `draw_circle` in `_draw()` for the overlay, `ceili` for the readout.

### Project Context Rules (from project-context.md)

- Gate order is pause > Breakpoint > hit-stop; register shifts apply during Breakpoint; `SimClock.paused` is the pause, never `SceneTree.paused`.
- Breakpoint counts real frames (≤ 120), ends on an action press (the press executes on the first unfrozen tick), and its cooldown starts at the end and counts sim frames.
- Red `#FF4040` only for warnings (Breakpoint, SIGSEGV).
- Cuttable modules are leaves: nothing outside `src/skills/breakpoint/` references the skill by class.
- Static typing everywhere; `StringName` ids (`&"breakpoint"`); `*_frames` names; `*_def.gd` for defs; files snake_case.
- Logging: `Log.debug(&"sim", ...)` on start and end events only; no bare `print`.
- Simulation folders do not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.

### Project Structure Notes

- New: `game/src/core/feature_flags.gd` (+ `.uid`), `game/data/config/feature_flags.tres`, `game/src/skills/breakpoint/breakpoint_skill.gd`, `game/src/skills/breakpoint/breakpoint_overlay.gd`, tests `game/tests/unit/test_breakpoint_skill.gd`, `game/tests/unit/test_feature_flags.gd` (or fold into the data test), `game/tests/unit/test_boss_fallback.gd` (or extend `test_boss_controller.gd`), and an integration test `game/tests/integration/test_breakpoint_replay.gd`.
- Modified: `game/src/autoloads/sim_clock.gd`, `game/src/core/sim_system.gd`, `game/src/core/defs.gd`, `game/src/autoloads/event_bus.gd`, `game/src/autoloads/audio_manager.gd`, `game/src/presentation/juice_director.gd`, `game/src/presentation/screen_fx.gd` (and/or `.gdshader`), `game/src/ui/hud/hud.gd`, `game/src/arena/arena.gd`, `game/src/main/main.gd`, `game/src/bosses/framework/boss_controller.gd`, `game/src/bosses/framework/attack_def.gd` (comment), `game/tests/unit/test_sim_clock.gd`, `game/tools/check_guards.sh` (reference guard, if chosen).
- Architecture tree lists `src/skills/breakpoint/breakpoint_skill.gd` (cut #3) and `data/config/feature_flags.tres`; this story matches it. No conflict.

### Testing standards

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Use the GDD numbers as cases: Breakpoint 120 real frames; cooldown 720 sim frames (12 s); dither 0.5; LOOP and Echo values unchanged; SIGSEGV recovery 90 vs 150.
- Simulation runs headless without a scene tree: build the skill with an injected SimClock (or gate interface), `InputBuffer`, `Register`.
- Guards: `bash game/tools/check_guards.sh`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3: Breakpoint Skill] (ACs)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.5] (SIGSEGV recovery 90 / 150 if Breakpoint is cut, FR43)
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4] (FR24, AD-12, NP-2)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] (Breakpoint row, Controls, HUD Layout D-047, Cut ladder #3, D-013, D-023, D-026)
- [Source: _bmad-output/game-architecture.md#AD-01, #AD-12, #NP-2, #Cut ladder rules] (SimClock gates, FeatureFlags, leaf modules)
- [Source: _bmad-output/project-context.md] (gate order, red palette, cuttable leaves)
- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml] (cut ladder #3; cut rule: done only with flag-off AC)
- [Source: _bmad-output/implementation-artifacts/4-2-echo-dash-combo.md] (D-S42-11, D-S42-12, the preload-cycle lesson)
- [Source: _bmad-output/implementation-artifacts/3-1-reusable-boss-framework.md] (AttackDef fields)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (2.1 InputBuffer growth, 2.8 ScreenFX red / dither)

## Dev Agent Record

### Agent Model Used

claude opus (gds-dev-story, unattended pipeline, 2026-11-10)

### Debug Log References

- Baseline before changes: GUT 1007/1007.
- `breakpoint` is a reserved GDScript keyword (debugger statement): `@export var breakpoint` fails to parse. Field renamed `breakpoint_enabled` (D-S43-17).
- test_glyph_palette forbids `Palette.WARN` / `Color(` in screen_fx.gd: the CPU mirror moved to `screen_fx_rule.gd`, and the shader's `warn_colour` uniform default is used (no setter call).
- Test-boss attacks need tell >= 20 (BossDef validation): the fallback test uses tell 60 (GDD SIGSEGV tell).
- Flag-off run (feature_flags.tres temporarily `breakpoint_enabled = false`, full suite): 1062/1064; the only failures were the two tests pinning the shipped value (test_shipped_flags_are_all_on_and_valid, and test_arena_default_follows_the_shipped_flag, since made flag-agnostic). The .tres was restored to true.
- Final: GUT 1064/1064 (41506 asserts), all replays included; `bash game/tools/check_guards.sh` OK.

### Completion Notes List

- **Input bindings (coordinator heads-up).** In this worktree `shift_right` is bound to E only and a dedicated `breakpoint` action already exists on Space (physical keycode 32), matching the GDD Controls table (Q `<<`, E `>>`, Space Breakpoint, R Watch); `test_input_map.gd` already pins `shift_right: [KEY_E]`, `breakpoint: [KEY_SPACE]`. No conflict to resolve, no binding changed. No HUD hint or duck line mentions Space yet (the Breakpoint tutorial line is 5.5). [design call] D-S43-18: keep the bindings as they are (E-only `>>`, Space-only `breakpoint`).
- **FeatureFlags (AC 1):** `FeatureFlags extends Def` with `reserved_write`, `watch`, `breakpoint_enabled`, `segfault`; `data/config/feature_flags.tres` all true; `Defs.FEATURE_FLAGS`. Covered by test_data_validation and test_feature_flags (incl. a no-`Defs`-reference check).
- **SimClock hooks (AC 4):** `SimSystem.poll(presses, ctx)` (default no-op) is called on every system after the presses are pushed and `poll_frame` advances, before the gates; pause still returns first. While `breakpoint_gate_active`, only SHIFTS-phase systems tick; `sim_frame` and `hitstop_frames` are untouched. With Breakpoint never used the poll hook is a no-op and the gate branch is never taken, so every existing replay (test_replays, infinite-loop, harvest) is unchanged and still green.
- **BreakpointSkill (AC 3, 5-8, 12):** leaf in `src/skills/breakpoint/`, TIMERS phase. `poll()` starts on Space (in fight, unlocked, cooldown 0, not active), counts frozen polls (start poll = 1), ends on J/K or on the 120th poll; the gate is cleared before the world tick, so the ending press executes that tick (or after resumed hit-stop, within the 8-frame buffer). `tick()` decrements the cooldown on world ticks only, skipping the ending tick (by its poll_frame), giving refused on T1..T720 and accepted on T721. `reset_for_fight(unlocked)` and `end_fight()` clear the gate and emit `breakpoint_ended` once if running. Cooldown length is a constructor param (7.4).
- **Leaf wiring (AC 2, D-S43-2):** new generic `FightSkill` (src/core) is the only type the core/UI uses. Arena loads the skill script by path when the flag is on and registers it; Main loads the overlay by path. check_guards.sh has a new rule (and test_breakpoint_wiring a matching test) rejecting `BreakpointSkill` / `BreakpointOverlay` outside the leaf folder.
- **Unlock (AC 3):** `Main.breakpoint_unlocked_for(boss_index)` = `boss_index >= 1`, passed into `Arena.enter_fight(..., breakpoint_unlocked)` on every FIGHT entry.
- **Presentation (AC 9-11):** EventBus `breakpoint_started` / `breakpoint_ended`; JuiceDirector dither 0.5 / 0; BreakpointOverlay draws a Palette.WARN dot in HUD col 12 and a 1-px line under the player's tile row; AudioManager logs only (placeholder until 7.1); HUD `BreakpointReadout` at REGISTER box col 1 row 20 (`brk READY` / `brk Ns`), hidden when off or locked; ScreenFX shader exempts exact `#FF4040` from invert and dither (closes the 2.8 deferred red-line item), mirrored by `ScreenFxRule` for tests.
- **Flag-off fallback (AC 13):** no skill, overlay, readout or events; Space does nothing. `BossController.breakpoint_on` (injected by Arena) and `effective_recovery()`: 150 with the flag off, 90 on, for a constructed recovery 90 / fallback 150 attack. The Infinite Loop's `;` opening also uses the effective recovery (no data change).
- **Replay (AC 14):** tests/integration/test_breakpoint_replay.gd records a Fight 2 in a real Arena with the test boss (Space, Q/E/Q while frozen, J end with the slash on that tick, Space refused by cooldown) and replays it bit-identically (per-tick integer hash, ticks, RNG).
- **InputBuffer (AC 15):** pinned bounded at (8 + 1) x presses-per-poll while mashing for 119 frozen polls (2.1 deferred item closed).
- **New design calls:**
  - [design call] D-S43-16: the 120-frame cap counts the start poll as poll 1, so the world is frozen for 119 ticks and ticks again on the 120th poll (AC 5 literal reading).
  - [design call] D-S43-17: the flag field is `breakpoint_enabled` (not `breakpoint`, a GDScript keyword); the others keep the AC names.
  - [design call] D-S43-18: input bindings unchanged (no conflict found; see first note).
  - [design call] D-S43-19: generic `FightSkill` base in src/core (reset_for_fight, end_fight, is_active, is_unlocked, cooldown_left_frames) so Arena, Main and the HUD hold the module without naming it; skill and overlay are loaded by path.
  - [design call] D-S43-20: Start and end read the frame's raw presses (not the 8-frame buffer); a Space in the same poll as J starts without ending; Space pressed while refused is not remembered.
  - [design call] D-S43-21: overlay placement: dot in the gutter column 12 at the player's tile row, line along the bottom edge of that row (keeps the `@` clear); node named `BreakpointWarning` in Main so the leaf guard stays string-free.
  - [design call] D-S43-22: Arena reads `Defs.FEATURE_FLAGS.breakpoint_enabled` at construction (default for bare Arenas in tests); Main re-applies its injectable `feature_flags` through `set_breakpoint_enabled` before the arena enters the tree.
- Not in scope / follow-ups: deferred-work.md entries for 2.1 (InputBuffer growth) and 2.8 (ScreenFX red) are now covered by tests here; the doc itself was not edited.

### File List

- game/data/config/feature_flags.tres (new)
- game/data/config/.gitkeep (deleted)
- game/src/core/feature_flags.gd (+ .uid, new)
- game/src/core/fight_skill.gd (+ .uid, new)
- game/src/core/defs.gd
- game/src/core/sim_system.gd
- game/src/autoloads/sim_clock.gd
- game/src/autoloads/event_bus.gd
- game/src/autoloads/audio_manager.gd
- game/src/skills/breakpoint/breakpoint_skill.gd (+ .uid, new)
- game/src/skills/breakpoint/breakpoint_overlay.gd (+ .uid, new)
- game/src/skills/breakpoint/.gitkeep (deleted)
- game/src/arena/arena.gd
- game/src/main/main.gd
- game/src/bosses/framework/boss_controller.gd
- game/src/bosses/framework/attack_def.gd
- game/src/bosses/infinite_loop/attacks/head_rush.gd
- game/src/bosses/infinite_loop/attacks/constrict.gd
- game/src/presentation/juice_director.gd
- game/src/presentation/screen_fx.gd
- game/src/presentation/screen_fx.gdshader
- game/src/presentation/screen_fx_rule.gd (+ .uid, new)
- game/src/ui/hud/breakpoint_readout.gd (+ .uid, new)
- game/tools/check_guards.sh
- game/tests/unit/test_sim_clock.gd
- game/tests/unit/test_breakpoint_skill.gd (+ .uid, new)
- game/tests/unit/test_breakpoint_presentation.gd (+ .uid, new)
- game/tests/unit/test_breakpoint_wiring.gd (+ .uid, new)
- game/tests/unit/test_boss_fallback.gd (+ .uid, new)
- game/tests/unit/test_feature_flags.gd (+ .uid, new)
- game/tests/integration/test_breakpoint_replay.gd (+ .uid, new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/4-3-breakpoint-skill.md

### Change Log

- 2026-11-10: Story 4.3 created unattended by gds-create-story (pipeline). Status -> ready-for-dev. Design calls D-S43-1 to D-S43-15. Cut-ladder #3: FeatureFlags created here; flag-off fallback (SIGSEGV 150) mechanism in AC 13.
- 2026-11-10: Implemented by gds-dev-story (claude opus): FeatureFlags, SimClock poll hook and SHIFTS-only freeze, BreakpointSkill leaf with FightSkill wiring, events, dither, overlay, HUD readout, ScreenFX red exemption, SIGSEGV recovery fallback, tests (57 new) incl. flag-off paths and a Breakpoint replay. Design calls D-S43-16 to D-S43-22. Status -> review.

## Story Completion Status

Status: done. Implemented by gds-dev-story (claude opus); reviewed by gds-code-review.

### Review Findings

Review (2026-11-10): Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel. 3 patch, 10 defer, rest dismissed as noise or accepted design calls.

- [x] [Review][Patch] Cooldown skip keyed on the end poll frame; a hit-stop-delayed end made Space refused for 719 ticks instead of 720. Now a `_skip_next_tick` flag skips the first world tick after the end [game/src/skills/breakpoint/breakpoint_skill.gd]. New test added.
- [x] [Review][Patch] Readout stayed visible (stale READY / cooldown) outside a fight: `end_fight()` now clears `unlocked` and `cooldown_left` [breakpoint_skill.gd].
- [x] [Review][Patch] SimClock frozen loop used `break` on the first non-SHIFTS system; now `continue`, independent of registration order [game/src/autoloads/sim_clock.gd].
- [x] [Review][Defer] Items listed in deferred-work.md under "code review of story-4-3-breakpoint-skill (2026-11-10)" (defeat-window start, 119 vs 120 frozen ticks, readout wording, flag name in spec, hit-stop buffer loss, flag-off CI, ScreenFX exact match, guard gaps, test nits).

Post-review: GUT 1065/1065 (flag on, incl. replays); flag-off run 1064/1065 (only the shipped-value pin fails by design); check_guards OK.
