---
baseline_commit: 0b057fa89aabc17131b44efcf5daccfcde9d53b6
---

# Story 2.2: Player Movement and Facing

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. -->

## Story

As a player,
I want fast, responsive 8-direction movement,
so that I can reposition instantly around the arena.

**Requirements:** FR1, FR3 (clamp); GDD Movement table (GFR1, GFR2 data only, GFR3); NFR8 (`@` and `>o` glyphs, 16-px grid).
**Epic 2 window:** Nov 8–10. **Depends on:** Story 2.1 (SimClock, InputSource, recorder), Story 1.5 (Arena play area), Story 1.6 (FIGHT flow).

## Acceptance Criteria

1. **Def and validation.** Given `data/player/player_def.tres` (speed 7 tiles/s, accel 4 frames, decel 3 frames, HP 5, post-hit invulnerability 60 frames, hurtbox 0.6 tiles), when the game loads, then the def's `validate()` returns no messages, and `tests/unit/test_data_validation.gd` loads every `.tres` under `res://data/` and asserts all `validate()` calls are empty.
2. **Speed and ramp.** Given the player `@` (with the `>o` duck companion) in the arena, when I hold a direction with WASD or the arrow keys, then the player reaches 7 tiles/s (converted once via `Const.tiles_per_s_to_px_per_frame`) in 4 frames and stops within 3 frames of release, in 8 directions.
3. **Facing.** Facing is set to the last movement direction and persists while idle.
4. **Clamp.** Given the player at the arena edge, when I keep moving outward, then the position is clamped inside the 32×18 play area (no physics bodies are used).
5. **Tick-only logic.** Movement runs only inside `SimClock.tick()` with integer-frame logic and no `delta`. While `SimClock.paused` the player does not move.
6. **Guards.** `bash game/tools/check_guards.sh` and the full GUT suite pass (no `Input.` or global RNG in the player folder; the existing guards cover this).

## Scope Boundaries

- **In:** `PlayerDef` (+ the first `Def` base class and `test_data_validation.gd`), the `Player` movement system (speed ramp, decel, 8-direction facing, clamp), held-direction input through `InputSource`, the `@` and `>o` drawing, FIGHT wiring (spawn, activate, reset), recorder support for held direction, tests.
- **Out (later stories):** shifts and the register (2.3), any action, attack or dash (2.5), combo (2.6), hurtbox use in combat and HP/damage/death/invulnerability logic (2.7, 2.9; the values are stored in the def only), contact damage (3.1+), Duck bubble and voice (3.6, 3.7), gamepad stick (7.5 Should), invulnerability blink (2.9), Null Dodge move-speed ×0.5 (4.x / 5.x).
- **Not 2.2's job:** the real FIGHT screen or HUD. The placeholder FIGHT screen (1.6) stays; the arena and player show behind it.

## Tasks / Subtasks

### Group A: Data and def (AC: 1)

- [x] A1. Add `game/src/core/def.gd` (`class_name Def`, extends `Resource`): `func validate() -> PackedStringArray` returning an empty array by default. Architecture: every `*Def` resource implements `validate()`. (AC: 1)
- [x] A2. Add `game/src/player/player_def.gd` (`class_name PlayerDef`, extends `Def`) with typed `@export` fields: `speed_tiles_s: float = 7.0`, `accel_frames: int = 4`, `decel_frames: int = 3`, `max_hp: int = 5`, `invuln_frames: int = 60`, `hurtbox_tiles: float = 0.6`. `validate()` returns messages for: speed ≤ 0; accel or decel < 1; max_hp < 1; invuln < 0; hurtbox ≤ 0 or > 1 tile. Every field typed, no magic numbers in the code (balance lives in the `.tres`). (AC: 1)
- [x] A3. Add `game/data/player/player_def.tres` with the GDD values above. Use the script's `uid` if Godot has generated one; otherwise reference the script by path. Read-only at runtime. (AC: 1)
- [x] A4. Add `game/tests/unit/test_data_validation.gd`: recursively list `res://data/` for `*.tres`, load each, call `validate()` when the resource has it (`has_method`), assert the messages are empty. Also one test that `PlayerDef.new().validate()` reports each bad value (use a fresh def with bad fields, not the shipped `.tres`). (AC: 1)

### Group B: Input and clock plumbing (AC: 2, 5)

- [x] B1. `game/src/input/input_source.gd`: add a virtual `func move_for_frame() -> Vector2i` returning `Vector2i.ZERO`. Doc comment: held direction, one value per polled frame, components in {-1, 0, 1}. (AC: 2)
- [x] B2. `game/src/input/live_input.gd`: implement `move_for_frame()` with `Input.get_axis(&"move_left", &"move_right")` and `Input.get_axis(&"move_up", &"move_down")`, each reduced to its sign (`signi(int(v))` or `int(signf(v))`), so opposing keys cancel to 0. LiveInput stays the only sim-folder file touching `Input` (excluded by name in `check_guards.sh`). (AC: 2, 6)
- [x] B3. `game/src/input/replay_input.gd`: store a parallel per-frame move list; `move_for_frame()` returns entry *i* on the i-th poll (same counter as presses), `Vector2i.ZERO` when exhausted or when the recording has no `moves` key (format v1). Bad entries → `Log.error` and zero. (AC: 2, 5)
- [x] B4. `game/src/core/sim_context.gd`: add `var move_dir: Vector2i = Vector2i.ZERO` ("the held direction for the current polled frame, set by SimClock before the systems tick; read-only for systems"). (AC: 2)
- [x] B5. `game/src/autoloads/sim_clock.gd`: in `tick()`, after the press poll and before the recorder hook, set `ctx.move_dir = input_source.move_for_frame()` (or `ZERO` when `input_source == null`), and call `recorder.record(presses, ctx.move_dir)`. Gate order unchanged: the move is still polled during hit-stop and Breakpoint, but systems do not tick there. Keep the paused early-return (no poll, no move) per D-S21-9. (AC: 2, 5)
- [x] B6. `game/src/autoloads/sim_clock.gd`: add `func unregister_system(system: SimSystem) -> void` (removes by identity; no-op when absent). Needed so the Arena can detach the player when it leaves the tree and tests do not double-register. (AC: 5)
- [x] B7. `game/src/debug/input_recorder.gd`: `record(presses: Array[StringName], move: Vector2i = Vector2i.ZERO)`; store the move per frame in a parallel `moves` array (`[x, y]`). Bump `FORMAT_VERSION` to 2. `stop()` returns `{"version", "seed", "frames", "moves"}`. The default argument keeps existing callers compiling. (AC: 5)

### Group C: Player movement system (AC: 2, 3, 4, 5)

- [x] C1. Add `game/src/player/player.gd` (`class_name Player`, extends `SimSystem`): `phase = SimPhase.PLAYER`. Constructor takes a `PlayerDef`. State, all plain fields: `position_px: Vector2` (arena-local, centre of the `@` glyph), `velocity_px: Vector2` (px per frame), `facing: Vector2i` (default `Vector2i(1, 0)`), `active: bool = false`. `_init` asserts the def is not null (`assert` + `Log.error`, then uses `PlayerDef.new()` defaults). (AC: 2, 3, 4)
- [x] C2. `Player.tick(ctx: SimContext)`: return when `not active`. Otherwise:
  1. `dir := ctx.move_dir`. If `dir != ZERO`, `facing = dir` (the last non-zero direction; facing persists while idle).
  2. `v_max := Const.tiles_per_s_to_px_per_frame(def.speed_tiles_s)` (already px per frame; do not multiply by `TILE_PX` again). `target := Vector2(dir).normalized() * v_max`, or `Vector2.ZERO` when `dir == ZERO`.
  3. `step := v_max / def.accel_frames` when moving, `v_max / def.decel_frames` when stopping (linear ramp; `move_toward` on the velocity).
  4. `velocity_px = velocity_px.move_toward(target, step)`.
  5. `position_px += velocity_px`, then clamp (C3).
  Converted once through `Const`; no `delta`, no float timers. (AC: 2, 5)
- [x] C3. Clamp: the glyph's centre is kept so the whole `@` cell stays inside `Arena.play_area()` (`Rect2(0, 0, 512, 288)`): clamp to `Arena.play_area().grow(-Const.TILE_PX / 2.0)`, i.e. centre in [8, 504] × [8, 280]. Use `Arena.clamp_to_play_area`-style logic on the shrunk rect (reuse it; do not add a second clamp). Velocity components that point into a wall are zeroed. (AC: 4)
- [x] C4. Facing is always one of the 8 directions (components in {-1, 0, 1}, not both zero); the `move_dir` value is validated as such (any other value is clamped to its sign). (AC: 3)
- [x] C5. `func reset_for_fight(spawn_px: Vector2) -> void`: `position_px = spawn_px`, `velocity_px = Vector2.ZERO`, `facing = Vector2i(1, 0)`. Called on every FIGHT entry (E1). (AC: 5)
- [x] C6. `func set_active(on: bool) -> void`. Inactive players do not tick and are not drawn at a new position. (AC: 5)

### Group D: Presentation and FIGHT wiring (AC: 2, 4)

- [x] D1. Add `game/src/presentation/player_view.gd` (`class_name PlayerView`, extends `Node2D`): holds a reference to the `Player`, draws in `_draw()` only. `@` at `Palette.INK` at 2× (`GlyphFont.draw_at` with top-left = `position_px.round() - Vector2(8, 8)`). Companion `>o` (`>` and `o` at 2×) drawn one tile behind the player, opposite to `facing` ([design call] D-S22-8). Calls `queue_redraw()` each frame while active (presentation only; reads sim state, never writes). (AC: 2)
- [x] D2. `game/src/arena/arena.gd`: owns the `Player` (created in `_ready`, def loaded by `preload("res://data/player/player_def.tres")`), registers it with `SimClock.register_system` in `_ready`, unregisters in `_exit_tree`, and adds a `PlayerView` child so its coordinates are arena-local (drawn above the layout). Provides `func enter_fight() -> void` (reset to spawn `Vector2(256, 144)` centre of play area, `set_active(true)`) and `func leave_fight() -> void` (`set_active(false)`). (AC: 2, 4, 5)
- [x] D3. `game/src/main/main.gd` `apply_flow_state`: in FIGHT call `arena.enter_fight()`; on any other state call `arena.leave_fight()`. This runs for every route into FIGHT (intro, harvest, debug jump, future retry) because it follows `flow_state_changed` (same reasoning as D-S21-6). (AC: 5)
- [x] D4. Check the placeholder FIGHT text (`PlaceholderScreen`) still reads on top of the arena; no change to the placeholder is expected. Record a one-line note in Completion Notes. (AC: —)

### Group E: Tests and guards (AC: 1–6)

- [x] E1. `game/tests/unit/test_player_movement.gd` (no scene tree; drive `Player.tick` directly with a `SimContext` whose `move_dir` is set, or drive `SimClock.new()` with a stub `InputSource`):
  - held right from rest: speed after frame 1, 2, 3, 4 is `k * v_max / 4` and equals `v_max` (with float tolerance) at frame 4; `v_max` equals `Const.tiles_per_s_to_px_per_frame(7.0)`;
  - release from full speed: speed reaches 0 within 3 frames (`v_max / 3` per frame);
  - diagonal (e.g. `(1,1)`) reaches the same speed (7 tiles/s) as the cardinal direction, within float tolerance;
  - facing: each of the 8 directions sets facing; facing persists while idle; opposing keys (`(0,0)` after cancel) do not change facing;
  - clamp: holding outward for 200 frames stops at the edge (centre x = 8 on the left, 504 on the right, y = 8 and 280), never outside; the velocity component into the wall is zero;
  - inactive player does not move; paused `SimClock` does not move the player and keeps its velocity (D-S22-7);
  - `reset_for_fight` restores spawn, zero velocity and default facing.
- [x] E2. `game/tests/unit/test_data_validation.gd` (from A4).
- [x] E3. `game/tests/unit/test_sim_clock.gd` (extend): `ctx.move_dir` equals the stub's `move_for_frame()` on each polled frame; zero when `input_source == null`; not updated while paused; `unregister_system` removes a system so it no longer ticks.
- [x] E4. `game/tests/unit/test_input_recorder.gd` and `game/tests/replays/test_replays.gd` (update): record moves, JSON round-trip includes `moves` and `version == 2`; the replay test drives movement through `ReplayInput` and asserts the same final `Player.position_px` on two fresh clocks (bit-identical float equality). `ReplayInput` accepts a v1 recording (no `moves`) and returns zero moves.
- [x] E5. Run the full GUT suite headless and `bash game/tools/check_guards.sh` from the repo root. Both green. Record the test count in Completion Notes (baseline 220/220 from 2.1).
- [x] E6. Import first in the fresh worktree (`godot --headless --path game --import`) so the new `.tres` and `.gd` files get `.uid` files; commit the `.uid` files with the code.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S22-1 Movement model.** Linear ramp with `Vector2.move_toward`: step `v_max / accel_frames` while a direction is held, `v_max / decel_frames` when released. From rest, full speed is reached on frame 4 and stop takes 3 frames from full speed. Reversing direction ramps through the same step (no instant turn). This matches "reaches 7 tiles/s in 4 frames" and "stops within 3 frames" exactly.
- **[design call] D-S22-2 Diagonals and clamp.** Diagonal input is normalised so diagonal speed equals cardinal speed (7 tiles/s). The `@` glyph centre is clamped so the whole glyph stays inside the 32×18 play area, which means the player can stand on the outer tree ring. The GDD says "solid tree-line walls"; the alternative (clamp one more tile inward, so the ring acts as a wall) is a one-line change in C3. Default kept as written; Tiziano may flip it after the playtest (human check H2).
- **[design call] D-S22-3 Held input through InputSource.** Movement is a held state, not a press, so it does not go through `InputBuffer`. `InputSource` gains `move_for_frame()`; `SimClock` puts the frame's direction in `SimContext.move_dir` before the systems tick. Systems never touch `Input`, which keeps the replay path identical to play.
- **[design call] D-S22-4 Recording format v2.** Held direction must be recorded or replays of movement diverge. Format v2 adds a parallel `moves` array (`[x, y]` per frame) next to the existing `frames` (presses). v1 files stay readable (zero moves). Recorder and replay tests are updated, not duplicated.
- **[design call] D-S22-5 Activation and reset.** The player only ticks while `active`. `Main.apply_flow_state` turns it on for FIGHT and off otherwise, so the player does not move on the title or intro. Every FIGHT entry resets the player to the spawn point, zero velocity and default facing. Retry (2.9) will reuse `enter_fight()`.
- **[design call] D-S22-6 Spawn and default facing.** Spawn at the play-area centre `(256, 144)` px. Default facing `(1, 0)` (right). Both are data-free constants; they move into the def only if tuning needs it.
- **[design call] D-S22-7 Pause and wall contact.** While paused nothing is polled and nothing ticks (D-S21-9), so the player's velocity is frozen and resumes unchanged on unpause, and the live held state is read again from that point (a key released during pause is no longer held). This closes the deferred item from 1.7 "held gameplay actions are not released on pause". Velocity components pointing into a wall are zeroed, so the player does not stick to the edge after reversing.
- **[design call] D-S22-8 Duck companion.** The `>o` duck is presentation only: two 2× glyphs drawn one tile behind the `@`, opposite to facing. Its exact cell placement is a visual call; the human check H1 confirms it reads well. It has no sim state until Epic 3 (duck voice and bubble).
- **[design call] D-S22-9 PlayerDef and Def base.** The first `Def` base class is added in `src/core/def.gd`, as the architecture specifies (`*Def` resources with `validate()`). Hurtbox, HP and invulnerability are stored in the def now (GDD GFR2 is "2.2 (def), 2.9") but are not used until 2.7 and 2.9.
- **[design call] D-S22-10 Unregister.** The Arena registers the player with the autoload `SimClock` and unregisters on `_exit_tree`, so re-instancing Main in tests does not double-tick the player. `SimClock.unregister_system` is the only new public method on the clock besides `move_dir`.

### Architecture guardrails (must follow)

- Only `SimClock` calls `tick()`. No `_process`/`_physics_process` in gameplay code, no `Timer`, no `await`, no Tweens, no `Engine.time_scale`, no `delta` in simulation (AD-01, project-context).
- Integer frames: every duration is `int` with `_frames`. Positions are float pixels and are the only non-integer state (sim-only, rounded only when drawn).
- Sim folders (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not reference `ui`, `presentation`, `AudioManager`, `VoiceService`, `Timer`, `await`, `create_timer`, `get_ticks_msec`, `Engine.time_scale`, `delta`. `PlayerView` therefore lives in `src/presentation/`, not `src/player/`.
- Presentation (`PlayerView`) reads sim state and never writes it (AD-05).
- Only `LiveInput` reads `Input` (guard in `check_guards.sh`). Player code reads `ctx.move_dir`.
- Typing: `untyped_declaration` is an error. Type every variable, parameter and return. `StringName` literals for ids (`&"move_left"`).
- Logging: `Log.error/warn/info/debug(&"tag", msg)` only, never bare `print`. Tag `&"sim"` for ticks/events; `&"data"` for def errors. Never log per frame.
- Balance in `.tres` (data), invariants in `Const`. No numeric speed literals in code.
- Pixel rules: world glyphs at 2× on 16-px tiles; draw positions rounded (`round()`) so glyphs stay on the pixel grid.
- Godot 4.7.2 APIs only (`Input.get_axis`, `Vector2.move_toward`, `Vector2.normalized`, `Rect2.grow`). Docs: Context7 `/godotengine/godot-docs/__branch__4.7` if an API is in doubt (project-context).

### Previous story intelligence (2.1, Epic 2)

- `SimClock` (2.1): `tick()` order is pause gate (no poll) → poll presses into `buffer` → recorder hook → Breakpoint gate → hit-stop → systems by phase → hit-stop apply → `sim_frame += 1`. The move poll goes next to the press poll (B5). Systems are sorted by `SimPhase`; `Player` uses `PLAYER`.
- `SimContext` (2.1) holds `rng` only; `move_dir` is added here (B4). Keep the RNG untouched.
- `LiveInput` (2.1) uses `Input.is_action_just_pressed` in `_physics_process`; the move read follows the same pattern and is covered by the same human check (H3 of 2.1).
- `InputRecorder` (2.1): `record(presses)` is called once per polled frame; frame 0 is the first poll after start (D-S21-12). Recording a session that includes movement must start at fight start to replay exactly; the known limitation (no RNG state captured mid-fight) is unchanged and still deferred.
- `ReplayInput` (2.1): frame *i* on the *i*-th poll, independent of `sim_frame`. Keep that counter for moves too.
- Game (1.6, 2.1): every route into FIGHT goes through `Game._set_flow_state` → `_begin_fight()` (seed). Player reset uses the same flow change via `Main.apply_flow_state` (D-S22-5).
- Pause (1.7): `Game.set_paused` is the only writer of `SimClock.paused`. Deferred from 1.7: "Held gameplay actions are not released on pause; handle with the player controller (Epic 2)" → addressed by D-S22-7.
- Deferred from 2.1 review: `InputBuffer` growth during freezes (not relevant to movement; movement is not buffered). LiveInput above 60 Hz (H3). Both still open.
- Test baseline: 220/220 GUT tests, 29 scripts, `check_guards.sh` OK (2.1 completion notes).

### Git intelligence (recent commits)

- `0b057fa` Story 2.1: sim clock, input source, buffer, recorder, F11, seed plumbing, guards. This branch's baseline.
- `f3da78d` docs: defer itch.io deploy and browser smoke (sprint and deferred-work updates).
- `2273d1d` Story 1.7: `Game.set_paused` as single writer, `pause_toggled` on `EventBus`, Pause screen in its own CanvasLayer.
- `094c1a8` Story 1.6: `DebugKeys` gate, placeholder flow with debug jumps.
- `7032444` Story 1.5: Arena layout, `Arena.play_area()`, `Arena.clamp_to_play_area()` (already the bounds clamp; reuse it).
- Pattern: each story adds small files, extends existing tests, leaves `check_guards.sh` green, records design calls and human checks in the story file.

### Project Structure Notes

- New: `game/src/core/def.gd`, `game/src/player/player.gd`, `game/src/player/player_def.gd`, `game/src/presentation/player_view.gd`, `game/data/player/player_def.tres`, `game/tests/unit/test_data_validation.gd`, `game/tests/unit/test_player_movement.gd` (each `.uid` once Godot imports it).
- Modified: `game/src/input/input_source.gd`, `game/src/input/live_input.gd`, `game/src/input/replay_input.gd`, `game/src/core/sim_context.gd`, `game/src/autoloads/sim_clock.gd`, `game/src/debug/input_recorder.gd`, `game/src/arena/arena.gd`, `game/src/main/main.gd`, `game/tests/unit/test_sim_clock.gd`, `game/tests/unit/test_input_recorder.gd`, `game/tests/replays/test_replays.gd`.
- `src/player/` is empty today (no `.gitkeep`); the first file in it is `player.gd`. `data/player/` is empty; the first file is `player_def.tres`. `test_folder_tree.gd` already requires both folders.
- Conflicts: none found. `Arena.play_area()` and `Arena.clamp_to_play_area()` exist and are the clamp to reuse.

### Testing Requirements

- GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Static guards: `bash game/tools/check_guards.sh` from the repo root.
- Pure logic with no scene tree: `Player` (with a `SimContext` or a stub `InputSource`), `PlayerDef.validate`, recorder and replay.
- Float comparisons use a tolerance (e.g. 0.0001) except the replay test, which asserts bit-identical equality between two runs of the same code.
- Don't rely on real key events in GUT. Movement is driven by a stub `InputSource` or direct `SimContext.move_dir`.
- Draw code (`PlayerView`) is not unit-tested; it is covered by the human checks.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.2 H1] Debug build, F2 (FIGHT) then hold each of the 8 directions: the `@` with its `>o` companion moves smoothly, faces the last direction, and stays inside the arena. Confirm the companion placement reads well (D-S22-8).
- [ ] [2.2 H2] Walk into the outer tree ring: the player stands on it (D-S22-2). If it should be a wall, flip the clamp (C3) and record the choice.
- [ ] [2.2 H3] Web (`?debug`, Chrome and Firefox): WASD and arrow keys both move; opposing keys cancel; pausing with Esc mid-move and resuming continues the same velocity (D-S22-7).

## Dev Agent Record

### Agent Model Used

Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended).

### Debug Log References

- Dev: Claude Opus 5.5 (claude-opus-5-5) via gds-dev-story (unattended), 2026-11-07.
- First full run: `test_player_movement.gd` failed to parse (`Vector2.get()` does not exist); switched to index access `v[axis]`.
- Corner-slide test started too far from the wall (503.3 < 504 after 4 frames); moved the start to x = 503.
- Headless boot (`--quit-after 60`) reported "2 ObjectDB instances leaked / input_recorder.gd still in use" once `Player` referenced `Arena` while `Arena` owned a `Player` (script cycle). Fixed by injecting the bounds rect (see design call below); boot is clean again.

### Completion Notes List

- Implemented all tasks A1-E6. `Def` base + `PlayerDef` + `data/player/player_def.tres` (GDD values, script referenced by uid); `test_data_validation.gd` scans `res://data/` recursively.
- Input plumbing: `InputSource.move_for_frame()`, `LiveInput` (sign of `Input.get_axis`, opposing keys cancel), `ReplayInput` v2 moves (v1 → zero moves; bad entries → one `Log.error`, zero), `SimContext.move_dir`, `SimClock` polls the move right after the presses (also during hit-stop/Breakpoint, never while paused), `SimClock.unregister_system`, `InputRecorder` format v2 with `moves`.
- `Player` (SimPhase.PLAYER): linear `move_toward` ramp (v_max/4 accel, v_max/3 decel), normalised diagonals, facing = last non-zero sanitized direction, clamp with into-wall velocity zeroed, `reset_for_fight`, `set_active`.
- `PlayerView` (presentation): `@` at 2x centred on the rounded sim position; `>o` behind the player, opposite to facing, clamped inside the play area.
- FIGHT wiring: `Main.apply_flow_state` calls `arena.enter_fight()` in FIGHT and `arena.leave_fight()` otherwise.
- D4: the placeholder FIGHT text lives under `Screens`, which is added after the Arena, so it still draws on top of the arena and the player; no change to `PlaceholderScreen`.
- [design call] Bounds injected, not read from `Arena`: `Player._init(def, bounds_px)`; `Arena.player_bounds()` = `play_area().grow(-TILE_PX / 2)` (centre in [8, 504] x [8, 280]) is the single source of the bounds. Calling `Arena.clamp_to_play_area` from `player/` created an Arena<->Player script cycle that leaked at exit. `Arena.clamp_to_play_area` is unchanged; the player clamps with `Vector2.clamp` on the injected rect. To make the tree ring a wall (H2), change `Arena.PLAYER_EDGE_INSET_PX` to `TILE_PX * 1.5`.
- [design call] `PlayerView` is attached under the Arena by `Main._build_layers`, not by `Arena._ready` as D2 says: `arena/` is a sim folder and must not reference `presentation/`. Coordinates stay arena-local and it hides with the arena.
- [design call] The Arena registers the player in `_enter_tree` (not `_ready`) so it pairs with the `_exit_tree` unregister if the arena is ever re-parented; the `Player` is created as a field initializer so Main can hand it to `PlayerView` right after `add_child`.
- [design call] `ReplayInput` keeps a separate move poll counter that advances in lockstep with the press counter (SimClock calls both once per polled frame); same "entry i on the i-th poll" semantics, and robust if a caller polls only one.
- [design call] Duck placement (D-S22-8): duck centre = player centre - facing * (1.5 tiles, 1 tile), so the two-glyph `>o` sits right next to the `@` cell; clamped inside the play area. `>o` text is not mirrored by facing. Confirm in H1.
- Tests: 262/262 GUT tests, 32 scripts (baseline 220/29; +42 tests: test_player_movement 20, test_data_validation 6, test_arena_player 6, test_sim_clock +6, test_input_recorder +3, test_replays +1). `bash game/tools/check_guards.sh`: OK. Headless boot: no leaks or errors.
- Human checks H1-H3 (Dev Notes) are open for Tiziano; they do not block review.

### File List

- game/src/core/def.gd (new)
- game/src/core/def.gd.uid (new)
- game/src/player/player_def.gd (new)
- game/src/player/player_def.gd.uid (new)
- game/src/player/player.gd (new)
- game/src/player/player.gd.uid (new)
- game/src/presentation/player_view.gd (new)
- game/src/presentation/player_view.gd.uid (new)
- game/data/player/player_def.tres (new)
- game/tests/unit/test_data_validation.gd (new)
- game/tests/unit/test_data_validation.gd.uid (new)
- game/tests/unit/test_player_movement.gd (new)
- game/tests/unit/test_player_movement.gd.uid (new)
- game/tests/unit/test_arena_player.gd (new)
- game/tests/unit/test_arena_player.gd.uid (new)
- game/src/input/input_source.gd (modified)
- game/src/input/live_input.gd (modified)
- game/src/input/replay_input.gd (modified)
- game/src/core/sim_context.gd (modified)
- game/src/autoloads/sim_clock.gd (modified)
- game/src/debug/input_recorder.gd (modified)
- game/src/arena/arena.gd (modified)
- game/src/main/main.gd (modified)
- game/tests/unit/test_sim_clock.gd (modified)
- game/tests/unit/test_input_recorder.gd (modified)
- game/tests/replays/test_replays.gd (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/2-2-player-movement-and-facing.md (modified)

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S22-1 to D-S22-10 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): PlayerDef + Def base, held-direction input (InputSource/SimContext/SimClock, recorder format v2), Player movement system, PlayerView, FIGHT wiring, tests (262/262). Status review.

### Review Findings

- [x] [Review][Patch] PlayerDef.validate accepted NaN/inf speed and hurtbox [player_def.gd] — fixed (is_finite)
- [x] [Review][Patch] SimClock.register_system could double-register a system (double-speed tick) [sim_clock.gd] — fixed (dedupe)
- [x] [Review][Patch] LiveInput.move_for_frame spammed errors when a move action is missing from the InputMap [live_input.gd] — fixed (has_action guard)
- [x] [Review][Patch] PlayerView showed the previous fight's frame for one frame on re-entry [arena.gd] — fixed (queue_redraw in enter_fight)
- [x] [Review][Patch] Overlong SimClock header comment [sim_clock.gd] — fixed
- [x] [Review][Defer] [design call] F11 recording started mid-fight does not capture player pos/vel/facing — deferred, same known limitation as RNG state; exact replay needs F11 at fight start
- [x] [Review][Defer] Float determinism native vs wasm for Vector2 move_toward/normalized — deferred, same-binary replays only for now
- [x] [Review][Defer] ReplayInput does not validate moves length vs frames, no replay version gate (v1 plays with zero movement) — deferred, dev-only recordings
- [x] [Review][Defer] Duck jumps when facing flips 180 degrees, no render interpolation — deferred, cosmetic, judge in human check H1
- Dismissed (noise): apply_flow_state re-entry (only called on state change; pause is a separate path), separate replay move counter (lockstep by design), reverse-ramp 8 frames (intended Euclidean step), weak/test-style nitpicks, assert(false) null-def branch, Acceptance Auditor deviations (all documented design calls).
