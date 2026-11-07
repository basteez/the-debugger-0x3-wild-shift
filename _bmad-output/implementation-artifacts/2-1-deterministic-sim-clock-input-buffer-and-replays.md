---
baseline_commit: f3da78d08008f251936bb2c06717c6e9c691cc13
---

# Story 2.1: Deterministic Sim Clock, Input Buffer and Replays

Status: done

<!-- Large story (readiness report: "still open"). Not split; scoped into ordered task groups A–E below (design call D-S21-1). -->

## Story

As a developer,
I want a fixed 60 Hz simulation tick fed by a buffered, replayable input source,
so that all frame data is exact, testable headless and reproducible from recordings (AD-01).

**Requirements:** FR6 (buffering), FR58 (buffer), NFR5; Additional: AD-01, determinism, input replay.
**Epic 2 window:** Nov 8–10. **Depends on:** Epic 1 (done, except the Epic 1 DoD browser/itch items, which are deferred by Tiziano, see `deferred-work.md`).

## Acceptance Criteria

1. **Tick order and gates.** Given `SimClock`, when a physics frame runs, then it polls the `InputSource` into the `InputBuffer`, evaluates the gates in order **paused > breakpoint (hook, inactive) > hit-stop**, and otherwise ticks registered `SimSystem`s in the fixed phase order **Shifts → Actions → Player → BossHazards → PlayerEffects → Combat → Timers** (the Input poll is built in and runs first), then increments `sim_frame`. Systems within one phase run in registration order.
2. **Hit-stop.** `SimClock.request_hitstop(frames)` keeps the maximum request made within one tick. While hit-stop frames remain, the world does not tick, the input is still polled and buffered, and the hit-stop counter decrements once per physics frame.
3. **InputBuffer.** A press pushed at frame `f` is available through frame `f + 8`, can be consumed at most once, and unconsumed presses expire silently. Consumption is oldest-first. Unit tests in `game/tests/unit/test_input_buffer.gd` cover expiry (f+8 yes, f+9 no), single consumption and ordering.
4. **SimContext RNG.** `SimContext` holds one seeded `RandomNumberGenerator`, reseeded at fight start (`SimClock.begin_fight(seed)`). No simulation code uses global `randi()`/`randf()` family calls; `check_guards.sh` enforces this for sim folders.
5. **Recording (debug).** In a debug build (or `?debug` on web), F11 toggles recording. Per-frame input is written to `user://replay_*.json` (and printed to the console on web). Recording is unavailable in release builds.
6. **Replay.** `ReplayInput` replays a recording. A GUT test in `game/tests/replays/` drives a recorded session and its replay through two fresh `SimClock`s and asserts the same final `sim_frame` and the same final test-state hash, bit-identically.
7. **Input abstraction.** Simulation reads input only through `InputSource` (`LiveInput` for play, `ReplayInput` for playback). No simulation folder touches the `Input` singleton.
8. **Headless.** The whole tick path runs without a scene tree or renderer. The full GUT suite and `game/tools/check_guards.sh` pass.

## Scope Boundaries

- **In:** the tick loop and gates, `InputSource`/`LiveInput`/`ReplayInput`, `InputBuffer`, `SimContext`, `SimSystem` base and phase enum, the hit-stop request, the debug recorder (F11), the replay test, the guard additions.
- **Out (later stories):** any gameplay system (Register 2.3, Player 2.2, Actions 2.5, Combo 2.6); the Breakpoint gate body (4.3, hook only here); `PlayerEffects` consumers; in-game replay playback UI (none planned; replays are test-driven); save of replays on release.
- **Not 2.1's job:** a fight that actually uses the seed. Only the plumbing exists here.

## Tasks / Subtasks

### Group A: Core types (AC: 1, 4, 7)

- [x] A1. Add `game/src/core/sim_context.gd` (`class_name SimContext`, RefCounted): `var rng: RandomNumberGenerator`, `func reseed(seed: int) -> void` (sets `rng.seed`, so the same seed always gives the same sequence). (AC: 4)
- [x] A2. Add `game/src/core/sim_system.gd` (`class_name SimSystem`, RefCounted): `enum SimPhase { SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, PLAYER_EFFECTS, COMBAT, TIMERS }` and a virtual `func tick(ctx: SimContext) -> void`. Each system exposes its `phase: SimPhase`. (AC: 1)
- [x] A3. Add `game/src/input/input_source.gd` (`class_name InputSource`, RefCounted): virtual `func presses_for_frame() -> Array[StringName]` (fresh presses this physics frame, buffered-action names only). (AC: 7)
- [x] A4. Add `game/src/input/live_input.gd` (`class_name LiveInput`): checks `Input.is_action_just_pressed` for the buffered action list `[action_1, action_2, shift_left, shift_right, breakpoint, watch]` (design call D-S21-3). (AC: 7)
- [x] A5. Add `game/src/input/replay_input.gd` (`class_name ReplayInput`): built from an `Array` of per-frame press arrays (and `static func from_file(path) -> ReplayInput`, parse errors → `Log.error` + empty input, no crash). Returns the frame's presses by its own tick counter, then empty arrays once exhausted. (AC: 6, 7)
- [x] A6. Add `game/src/input/input_buffer.gd` (`class_name InputBuffer`, RefCounted): `push(action: StringName, frame: int)`, `consume(action: StringName, frame: int) -> bool`, `clear()`. Lifetime 8 frames (`const PRESS_LIFETIME_FRAMES := 8`), inclusive. Entries are marked consumed, not removed mid-iteration. Prune expired entries on push. (AC: 3)

### Group B: SimClock tick loop (AC: 1, 2, 4, 8)

- [x] B1. Rewrite `game/src/autoloads/sim_clock.gd`: keep `sim_frame` and `paused`; `_physics_process` calls `tick()` (the only caller of `tick()`). Add `var input_source: InputSource` (null → no presses, so GUT can construct `SimClock.new()` without a tree), `var buffer: InputBuffer`, `var ctx: SimContext`, `var breakpoint_gate_active: bool = false` (hook, inactive), `var hitstop_frames: int`, and `func register_system(s: SimSystem) -> void` (stable order within phase). `_ready` assigns `LiveInput.new()`. (AC: 1, 2, 4, 7)
- [x] B2. Implement `tick()` exactly in this order: return if `paused` (no poll, no increment, as today); poll `input_source.presses_for_frame()` into `buffer` at `sim_frame`; if `breakpoint_gate_active` or `hitstop_frames > 0`, do the hit-stop countdown (if `hitstop_frames > 0`) and skip the world; else run systems by phase, apply the pending hit-stop, and increment `sim_frame`. (AC: 1, 2)
- [x] B3. Implement `request_hitstop(frames: int)`: store `_pending_hitstop = max(_pending_hitstop, frames)`. At the end of a world tick, `hitstop_frames = max(hitstop_frames, _pending_hitstop)` and reset `_pending_hitstop` to 0. (AC: 2)
- [x] B4. Implement `begin_fight(seed: int)`: `ctx.reseed(seed)`, `buffer.clear()`, `hitstop_frames = 0`, `_pending_hitstop = 0`. `sim_frame` is not reset (monotonic per session). (AC: 4)
- [x] B5. Check that the existing `game/tests/unit/test_sim_clock.gd` still passes (it calls `_physics_process` directly) and extend it for the new behaviour.

### Group C: Input recording (AC: 5, 6)

- [x] C1. Add `game/src/debug/input_recorder.gd` (`class_name InputRecorder`, RefCounted): `start(seed: int)`, `record(presses: Array[StringName])`, `stop() -> Dictionary` (returns `{"version": 1, "seed": ..., "frames": [...]}`), `static func to_json(data) -> String`. Frame 0 = first world tick after start (design call D-S21-5). (AC: 5)
- [x] C2. Hook F11 into `game/src/debug/debug_keys.gd` (Debug.enabled gate, matched by physical keycode like F1–F5). On toggle-off, write `user://replay_<unix_time>.json` (`FileAccess`, errors → `Log.warn` once and drop the recording), and on web also `Log.info` the JSON. Recording is driven from `SimClock` (a per-tick hook that calls `record`), not from presentation. (AC: 5)
- [x] C3. Make sure release builds never create the recorder: gate on `Debug.enabled`, and assert it in a unit test. (AC: 5)

### Group D: Seed plumbing (AC: 4)

- [x] D1. Add `var fight_seed: int = 0` to `game/src/core/run_state.gd`. Set it on FIGHT entry in `game/src/autoloads/game.gd` (in `_set_flow_state` where FIGHT is entered): `fight_seed = Time.get_ticks_usec()` (presentation-side source, never read in sim code), then `SimClock.begin_fight(run.fight_seed)`. Debug jumps into FIGHT take the same path. (AC: 4)
- [x] D2. Add a guard to `game/tools/check_guards.sh`: `randi|randf|randomize` (and `_range` variants) and `Input\.` in `SIM_DIRS` (outside `input/live_input.gd`), reported like the existing guards. (AC: 4, 7)

### Group E: Tests (AC: 3, 6, 8)

- [x] E1. `game/tests/unit/test_input_buffer.gd`: expiry at f+8 yes and f+9 no; single consumption; oldest-first ordering; `clear()`. (AC: 3)
- [x] E2. Extend `game/tests/unit/test_sim_clock.gd` (no scene tree; drive `_physics_process` or `tick()` directly): order of system phases; registration order within a phase; hit-stop max-per-tick; hit-stop counter decrements once per physics frame; world not ticked during hit-stop; input still buffered during hit-stop; pause freezes poll and frame; `breakpoint_gate_active` gates the world. (AC: 1, 2)
- [x] E3. `game/tests/unit/test_sim_context.gd`: same seed → same sequence; `begin_fight` reseeds and clears the buffer and hit-stop. (AC: 4)
- [x] E4. `game/tests/replays/test_replays.gd`: a scripted `InputSource` drives a recording SimClock run with a test-only `SimSystem` (folds presses into an int hash and draws from `ctx.rng`); the recording is serialised with `InputRecorder.to_json` and loaded with `ReplayInput.from_file`; a second fresh SimClock on the same seed must end with equal `sim_frame` and equal hash. Use a temp path under `user://`. (AC: 6)
- [x] E5. `game/tests/unit/test_input_recorder.gd`: JSON round-trip; release gate (`Debug.enabled` false → recorder not created). (AC: 5)
- [x] E6. Run the GUT suite headless and `bash game/tools/check_guards.sh` from the repo root. Both green. Record the test count in Completion Notes.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S21-1 Scope, not split.** The story stays one story (renumbering 2.2–2.9 would break references in the GDD, architecture and epics). Work is ordered into groups A–E so the dev agent can commit in steps.
- **[design call] D-S21-2 Hit-stop and `sim_frame`.** `sim_frame` counts **world ticks only** (not paused frames, not hit-stop frames). Hit-stop freezes the world, so frame data (8-frame buffer, 18-frame link window) is counted in world frames. Presses are still polled and buffered during hit-stop, so the buffer lifetime then spans the hit-stop (frozen sim frames), which matches the GDD "shifts are buffered during hit-stop". Breakpoint counts real frames separately (4.3), so it is not affected. Revisit only if a playtest shows the buffer feels too long.
- **[design call] D-S21-3 Press detection.** `LiveInput` uses `Input.is_action_just_pressed` from `_physics_process`. Verify in the headless run that no press is lost. If a press can be missed when the display runs faster than 60 Hz, switch `LiveInput` to a queue filled from `_unhandled_input` (drained once per tick) and record the change in Completion Notes. The `InputSource` interface does not change either way.
- **[design call] D-S21-4 Phase order.** `SimPhase` lists the systems after the built-in input poll. Registration order breaks ties inside a phase. No system is registered in 2.1 except the test-only system.
- **[design call] D-S21-5 Replay indexing.** A recording's frame 0 is the first world tick after F11 starts it. `ReplayInput` counts its own ticks, so playback is independent of `sim_frame`. Replays store the `seed` they used; a replay run must call `begin_fight(seed)` first.
- **[design call] D-S21-6 Seed source.** The fight seed is taken in `Game` (presentation-side flow code, not a sim folder) from `Time.get_ticks_usec()` on FIGHT entry, stored on `RunState.fight_seed`, and written into every recording. No simulation code reads the clock or the global RNG. Determinism is "same seed + same inputs → same state"; the seed is recorded so a live session can be reproduced.
- **[design call] D-S21-7 Recording print on web.** On web the whole recording JSON is printed through `Log.info` as one line, as the AC asks. Long lines are accepted for a debug tool.
- **[design call] D-S21-8 F11 key.** F11 is the architecture's recorder key (AD-debug). On web, the browser may use F11 for fullscreen and the page never sees it. Record that in H-notes, same as the F1/F11/F12 browser note in `deferred-work.md`. Do not rebind here; a rebind would need a design decision.
- **[design call] D-S21-9 Pause and buffer.** While `SimClock.paused`, `tick()` returns before polling, so presses made during pause are dropped (not buffered). Reason: a buffered press must not fire on resume, and the existing pause tests assume a frozen clock.
- **[design call] D-S21-10 Test state.** The replay test uses a test-only system with an int hash and `ctx.rng` draws. It is not gameplay and must not move into `src/`.

### Architecture guardrails (must follow)

- **Only `SimClock` calls `tick()`.** No gameplay code in `_process`/`_physics_process`, no `Timer`, no `await`, no Tweens, no `Engine.time_scale`, no `delta` in simulation (project-context, Engine rules; AD-01).
- **Gates order:** pause > Breakpoint > hit-stop (AD-01). Only the pause gate is live in 2.1. Add the Breakpoint gate as a hook (`breakpoint_gate_active`), never its body.
- **Sim folders** (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not reference `ui`, `presentation`, `AudioManager`, `VoiceService`, `Timer`, `await`, `create_timer`, `get_ticks_msec`, `Engine.time_scale`, `delta`. The `input/` folder is a sim folder: `LiveInput` is the one file that may touch `Input`. Put the `Input` call in `live_input.gd` and either exclude that file from the guard or check it by name (choose the cleaner option and record it).
- **Input:** `InputMap` actions only; no Shift key bindings (project-context). Buffer lifetime 8 frames.
- **Determinism:** all randomness from `SimContext.rng`; no global `randi()`/`randf()` (AD-01, project-context Testing).
- **Logging:** `Log.error/warn/info/debug(&"tag", msg)` only, never bare `print`; tags for this story: `&"sim"` for tick and hit-stop events, `&"replay"` for recording. Event-only, never per frame (`Log.debug` only on events).
- **Typing:** `untyped_declaration` is an error. Type every variable, parameter and return. `StringName` literals for ids (`&"action_1"`). Frame counts are `int` with `_frames` suffix.
- **Naming:** files `snake_case`; `class_name` PascalCase; constants `UPPER_SNAKE` (`PRESS_LIFETIME_FRAMES`).
- **Errors:** `assert()` + `Log.error` for programmer/data errors (bad replay file → `Log.error`, empty input). Environment failures (file write) → `Log.warn` once and degrade.
- **Debug gate:** F11 recording only when `Debug.enabled` (debug build or `?debug`). Keys matched by physical keycode in `DebugKeys`, like F1–F5.
- **Shared autoloads in tests:** each test restores `SimClock.paused`, `SimClock.sim_frame` and `Game` state it changes. Prefer fresh `SimClock.new()` instances over the autoload.

### Previous story intelligence (1.7, Epic 1)

- **`SimClock` (1.1):** `sim_frame` and `paused` only; `_physics_process` returns early when paused. `test_sim_clock.gd` drives `_physics_process` directly on a fresh instance with `_clock.call(&"_physics_process", delta)`. Keep that pattern; the delta must not change the increment.
- **Pause (1.7):** `Game` is the only writer of `SimClock.paused` (`Game.set_paused`). `_set_flow_state` clears the pause on every transition (DC5 of 1.7), so FIGHT entry always starts unpaused. `Game.PAUSABLE_STATES` = INTRO, FIGHT.
- **Deferred from 1.7 relevant here:** "Held gameplay actions are not released on pause; handle with the player controller (Epic 2)." The `InputBuffer` must not carry a press across pause (D-S21-9). Held-state release is for 2.2 (the player controller), not this story.
- **Deferred from 1.7:** "Only `SimClock.paused` is paused: tweens, timers and particles keep running; gameplay must read `SimClock.paused`." Respected: nothing here uses a timer.
- **Debug (1.6):** `DebugKeys` is an `_input` node added only when `Debug.enabled`; `Game.debug_jump` is the only debug path into flow. F11 goes through `DebugKeys`, not a new autoload.
- **Game (1.6):** FIGHT is entered from INTRO (`finish_intro`), from DEAD retry (future) and by `debug_jump`. The seed hook must sit in `_set_flow_state` so every route is covered.
- **Test baseline (1.7):** 142 GUT tests passing at the 1.6 review. Note the count at the start of 2.1 and keep it green.

### Git intelligence (recent commits)

- `f3da78d` docs: defer itch.io deploy and browser smoke (sprint and deferred-work updates).
- `2273d1d` Story 1.7: `Game.set_paused` as the single writer, `pause_toggled` on `EventBus` (the only signal added), Pause screen under its own CanvasLayer.
- `094c1a8` Story 1.6: `DebugKeys` gate, placeholder flow with debug jumps.
- Pattern: each story adds small files and extends existing tests; `check_guards.sh` and the folder-tree test guard structure.

### Project Structure Notes

- New: `game/src/core/sim_context.gd`, `game/src/core/sim_system.gd`, `game/src/input/input_source.gd`, `game/src/input/live_input.gd`, `game/src/input/replay_input.gd`, `game/src/input/input_buffer.gd`, `game/src/debug/input_recorder.gd`, `game/tests/unit/test_input_buffer.gd`, `game/tests/unit/test_sim_context.gd`, `game/tests/unit/test_input_recorder.gd`, `game/tests/replays/test_replays.gd` (each with `.uid` once Godot imports them).
- Modified: `game/src/autoloads/sim_clock.gd` (rewritten tick loop), `game/src/autoloads/game.gd` (FIGHT entry seed hook), `game/src/core/run_state.gd` (`fight_seed`), `game/src/debug/debug_keys.gd` (F11), `game/tests/unit/test_sim_clock.gd` (extended), `game/tools/check_guards.sh` (RNG and Input guards).
- Architecture path: `src/input/` (`input_source`, `live_input`, `replay_input`, `input_buffer`), `src/core/` (`sim_context`), `src/debug/input_recorder`. `src/register/`, `src/player/` and the rest stay empty.
- Conflicts: none found. `src/input/` and `src/core/` exist (`.gitkeep` in `src/input`, `src/core` has `const.gd`, `palette.gd`, `run_state.gd`, `url_query.gd`, `glyph_font.gd`).

### Testing Requirements

- GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Static guards: `bash game/tools/check_guards.sh` from the repo root.
- Pure logic with no scene tree: `InputBuffer`, `SimContext`, `SimClock.tick` with a stub `input_source`, `ReplayInput`, `InputRecorder.to_json`.
- Replay test: record a session, serialise, reload, replay on a fresh clock with the same seed; compare `sim_frame` and hash. Bit-identical means equal integers, not "close".
- Don't rely on real key events in GUT. F11 is tested by calling the recorder directly, not through `_input`.
- `Log` output is not captured; test the pure formatter where a line matters.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.1 H1] Debug build: press F11, play a few seconds with J/K/Q/E, press F11 again; confirm `user://replay_*.json` exists and holds the presses (the path is printed in the console).
- [ ] [2.1 H2] Web (`?debug`, Chrome and Firefox): F11 reaches the page or the browser fullscreen takes it (D-S21-8); record which.
- [ ] [2.1 H3] Confirm no press is lost on a 120–144 Hz display (D-S21-3): tap J repeatedly for 5 s and count the `[sim]` lines or the recorded presses.

## Dev Agent Record

### Agent Model Used

Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended).
Implementation: Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story (unattended).

### Debug Log References

- Baseline before 2.1: 171 GUT tests passing (25 scripts), `check_guards.sh` OK.
- First full run after Group E: 213/216; the 3 failures were GUT treating the expected `Log.error` (push_error) of the bad-replay tests as unexpected. Fixed with `assert_push_error` / `assert_push_error_count` in `test_input_recorder.gd`.
- Guard self-check: a temporary file in `src/player/` with `randi()`, `randomize()`, `randf_range()`, `Input.is_action_pressed` and `ctx.rng.randi()` reported 4 violations (the `rng.randi()` method call is correctly not flagged); file removed afterwards.

### Completion Notes List

- **Result:** all tasks A1–E6 done. Final run: **220/220 GUT tests passing** (29 scripts, 3420 asserts; +49 tests over the 171 baseline), `bash game/tools/check_guards.sh` → OK. Headless import (`--import`) needed first in the fresh worktree.
- **Tick path (AC1, AC2, AC8):** `SimClock.tick()` = pause gate (no poll) → poll `input_source` into `buffer` at `sim_frame` → recorder hook → Breakpoint gate → hit-stop gate (decrement) → systems by `SimPhase`, registration order within a phase (stable insert in `register_system`) → apply max pending hit-stop → `sim_frame += 1`. `input_source == null` means no presses, so `SimClock.new()` works without a tree; `_ready` assigns `LiveInput`.
- **[design call] D-S21-11 Breakpoint leaves hit-stop untouched.** Task B2 reads as if the hit-stop countdown also runs while `breakpoint_gate_active`; the architecture (NP-2: "world frozen, hit-stop counter untouched"; "a Breakpoint started during hit-stop preserves the remaining hit-stop frames") says it does not. Followed the architecture; tested in `test_breakpoint_gate_freezes_world_and_hitstop_but_polls`.
- **[design call] D-S21-12 Recording is per polled frame, not per world tick.** The recorder hook runs right after the poll, so hit-stop and Breakpoint frames are recorded too (paused frames are not, since nothing is polled). Presses made during hit-stop are buffered (D-S21-2) and must be replayed, which a world-tick-only recording would lose. `ReplayInput` returns frame *i* on its *i*-th poll, so playback stays aligned with the recording as long as the gates are deterministic. Refines D-S21-5 ("frame 0 = first world tick after start" becomes "first poll after start", identical unless hit-stop is active at that moment).
- **[design call] D-S21-13 Guard for `Input.`:** `live_input.gd` is excluded by name in `check_guards.sh` (cleaner than a per-line marker). The RNG guard matches bare `randi/randf/randi_range/randf_range/randfn/randomize(` calls only, so `ctx.rng.randi()` is allowed.
- **[design call] D-S21-14 F11 helpers are static on `DebugKeys`:** `start_recording(clock, debug_enabled, seed)`, `stop_recording(clock)` and `replay_path(unix_time)` are pure/static and unit-tested; `toggle_recording()` wires them to the `SimClock`/`Debug`/`Game` autoloads. The release gate is `InputRecorder.create(debug_enabled)` returning null (C3), plus `DebugKeys` itself only existing when `Debug.enabled`. `InputRecorder.save` returns false + `Log.warn` on a write failure and the recording is dropped.
- **Seed (D1):** `Game._begin_fight()` runs inside `_set_flow_state` on every entry into FIGHT (intro, harvest → next fight, debug jump, future retry): `run.fight_seed = Time.get_ticks_usec()`, `SimClock.begin_fight(seed)`, one `Log.info(&"flow")` line.
- **Limitation (known):** a recording reproduces exactly only when started at fight start (F2, then F11 at once). Entering FIGHT after F11 reseeds with a new seed the recording does not hold, and mid-fight recordings store the fight seed but not the RNG state reached so far. Fine while no gameplay system exists; revisit with 2.2+ if mid-fight replays are needed.
- **D-S21-3 press detection:** kept `Input.is_action_just_pressed` in `_physics_process` (Godot 4 tracks the physics frame of a press). Cannot be verified headlessly with real key events; left to human check H3.
- **Not added:** no gameplay `SimSystem` is registered (scope). `InputBuffer.size()` and `ReplayInput.frame_count()` exist for tests. Removed the now-unneeded `.gitkeep` files in `src/input/` and `tests/replays/`.
- **Human checks (do not block review):** [2.1 H1] F11 desktop recording file; [2.1 H2] F11 on web vs browser fullscreen (D-S21-8); [2.1 H3] no lost presses at 120–144 Hz (D-S21-3). All three open for Tiziano.

### File List

- `game/src/core/sim_context.gd` (new, + `.uid`)
- `game/src/core/sim_system.gd` (new, + `.uid`)
- `game/src/input/input_source.gd` (new, + `.uid`)
- `game/src/input/live_input.gd` (new, + `.uid`)
- `game/src/input/replay_input.gd` (new, + `.uid`)
- `game/src/input/input_buffer.gd` (new, + `.uid`)
- `game/src/input/.gitkeep` (deleted)
- `game/src/debug/input_recorder.gd` (new, + `.uid`)
- `game/src/debug/debug_keys.gd` (modified: F11 recorder)
- `game/src/autoloads/sim_clock.gd` (rewritten tick loop)
- `game/src/autoloads/game.gd` (modified: fight seed on FIGHT entry)
- `game/src/core/run_state.gd` (modified: `fight_seed`)
- `game/tools/check_guards.sh` (modified: global RNG and `Input.` guards)
- `game/tests/unit/test_input_buffer.gd` (new, + `.uid`)
- `game/tests/unit/test_sim_context.gd` (new, + `.uid`)
- `game/tests/unit/test_input_recorder.gd` (new, + `.uid`)
- `game/tests/unit/test_sim_clock.gd` (extended)
- `game/tests/unit/test_game_flow.gd` (extended: fight seed)
- `game/tests/replays/test_replays.gd` (new, + `.uid`)
- `game/tests/replays/.gitkeep` (deleted)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (2-1 → review)
- `_bmad-output/implementation-artifacts/2-1-deterministic-sim-clock-input-buffer-and-replays.md` (this file)

### Review Findings

Code review 2026-11-07 (gds-code-review, three layers): 0 decision-needed, 1 patch, 3 deferred, rest dismissed.

- [x] [Review][Patch] Over-long doc comment line in `DebugKeys` header [game/src/debug/debug_keys.gd:3] — fixed
- [x] [Review][Defer] InputBuffer grows during long freezes [game/src/input/input_buffer.gd] — deferred, bounded by presses
- [x] [Review][Defer] Mid-fight recordings lack RNG state [game/src/debug/input_recorder.gd] — deferred, known limitation
- [x] [Review][Defer] LiveInput press detection above 60 Hz unverified [game/src/input/live_input.gd] — deferred, human check H3

### Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S21-1 to D-S21-10 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): SimClock tick loop with gates and phases, InputSource/LiveInput/ReplayInput, InputBuffer, SimContext, hit-stop, F11 recorder, fight seed, guards, tests (220/220). Design calls D-S21-11 to D-S21-14. Status review.
