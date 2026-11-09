---
baseline_commit: 783dc74
---

# Story 2.5: Action State Machine with ATTACK and DASH

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. -->

## Story

As a player,
I want a 3-hit slash and an invulnerable dash on my active bits,
so that I have weighty attacks and an escape from the very first fight.

**Requirements:** FR10 (ATTACK slash and 3-hit chain), FR11 (DASH), FR14 (cancel into DASH / Null Dodge during recovery); GFR11, GFR12, GFR4; architecture AD-02 (`ActionDef`, `BitDef`), NP-1 (`ActionResolver` is the only J/K path; `ActionStateMachine`; `Cooldowns`); GDD "Bits (solo actions)", "Controls and Input", "The Register" (resolution rules D-045).
**Epic 2 window:** Nov 8-10. **Depends on:** Story 2.1 (`SimClock`, `InputBuffer` with 8-frame lifetime, `poll_frame`), Story 2.2 (`Player`, facing, arena clamp), Story 2.3 (`Register`, `active_window()`, `EventBus.register_shifted`, `RegisterPanel`), Story 2.4 (`PlayerView` inversion, `JuiceDirector`).
**Unblocks:** Story 2.6 (link window and combos on top of this FSM), 2.7 (hit resolution uses the shapes and the active frames), 2.9 (damage checks `invulnerable()`).

## Acceptance Criteria

1. **Geometry and data load.** Given `HitCircle`, `HitArc` and `HitCapsule` in `src/combat/shapes/` (used by `ActionDef.hit_shape`), and `ActionDef` / `BitDef` resources (`data/bits/bit_attack.tres`, `data/bits/bit_dash.tres`, `data/actions/slash_1..3.tres`, `data/actions/dash.tres`) with `validate()` returning no messages. Slash is S/A/R 6/4/12 frames, a 120-degree arc, 1.5-tile range, damage 10/10/15. Dash is S/A/R 0/10/6 frames, 4 tiles, invulnerable on action frames 1-8, cooldown 24 frames. `test_data_validation.gd` covers the new `.tres` files without edits.
2. **Press starts the solo action.** Given the register window (`ring[0]` = J = `action_1`, `ring[1]` = K = `action_2`), when I press J or K while that slot holds A or D, then that slot's solo action starts on the press tick with its exact frame data, facing the player's current facing, and its bit cooldown starts. Only `ActionResolver` turns J/K into actions.
3. **Cooldown blocks and buffers.** A press on a bit whose cooldown is running is not consumed; it stays in the 8-frame buffer and is dropped when it expires. When the cooldown ends within those 8 frames, the press fires.
4. **Slash chain.** Given a slash in its last 8 recovery frames (action frames 15-22), when I press the same button that started it and that slot still holds A, then the chain continues to hit 2 and then hit 3 (damage 10, then 15), and hit 3 cannot chain to a hit 4. A shift resets the chain.
5. **Cancel into dash.** Given any action in RECOVERY, when I press the slot holding DASH and DASH is off cooldown, then the recovery is cancelled and the dash starts on that tick. The cancel list is data (`ActionDef.cancel_into`), so Null Dodge can be added in Epic 5 without changing the rules.
6. **Dash invulnerability.** Given a dash, when it runs, then `invulnerable()` is true on action frames 1-8 and false from frame 9. (No damage reads it in this story.)
7. **Debug overlay.** Given a debug build, when I press F9, then a frame overlay shows sim frame, player FSM state, frame in state, cooldowns, `invulnerable`, the player hurtbox, and the active hit shape while ACTIVE. (The link window is added in Story 2.6.)
8. **Tests.** `tests/unit/test_action_fsm.gd` verifies S/A/R frame counts, dash invulnerability frames 1-8, cooldown blocking, chain timing and cancel-into-dash. All GUT tests pass, and `check_guards.sh` is green.

## Scope Boundaries

- In: `ActionDef`, `BitDef`, the four hit shapes, `Cooldowns`, the pure `ActionResolver`, the `ActionStateMachine` (a `SimSystem` in the ACTIONS phase), player movement lock during actions, a shift serial on `Register`, the F9 frame overlay, the data files, the tests.
- Out: the link window, combo table and Dash Strike (2.6); no-combo J-then-K pairs and their buffering (2.6); hit detection, damage, hit-stop and log lines (2.7, 2.8); HP, invulnerability use and death (2.9); Echo, Null Dodge, STUNNED and WATCHING behaviour (Epics 4-6). The `STUNNED` and `WATCHING` enum values exist and are never entered in this story.
- No change to `SimClock` tick order, `InputBuffer` behaviour, the Register ring rules, `PlayerView` or the juice code, except the additions listed under Project Structure Notes.

## Tasks / Subtasks

### Group A: Geometry and data (AC: 1)

- [x] Create `game/src/combat/shapes/hit_shape.gd` (`class_name HitShape`, `extends Resource`): a base with `contains(origin: Vector2, facing: Vector2, point: Vector2) -> bool` (all arguments in arena-local pixels, `facing` a unit vector), default false. Pure, no node.
  - [x] `hit_circle.gd` (`HitCircle`): `radius_tiles: float`. Contains if the distance from `origin` is at most the radius in pixels (`Const.TILE_PX`).
  - [x] `hit_arc.gd` (`HitArc`): `radius_tiles: float`, `angle_deg: float` (full angle, 120 for the slash). Contains if the distance is at most the radius and the angle between `facing` and the point direction is at most `angle_deg / 2`. A point at the origin counts as inside.
  - [x] `hit_capsule.gd` (`HitCapsule`): `length_tiles: float`, `radius_tiles: float`, a segment from `origin` along `facing` with a round end. Implemented and unit-tested, not used by any action in this story.
- [x] Create `game/src/register/bit_def.gd` (`class_name BitDef`, `extends Def`): `@export var id: int` (a `Register.Bit` value), `@export var glyph: String`, `@export var solo_action: ActionDef`. `validate()`: id is a known bit (`Register.is_bit`), glyph is one character, solo_action is not null.
- [x] Create `game/src/player/action_def.gd` (`class_name ActionDef`, `extends Def`):
  - `@export var id: StringName`
  - `@export var startup_frames: int`, `active_frames: int`, `recovery_frames: int` (ints, S/A/R)
  - `@export var invuln_from: int`, `invuln_to: int` (action frames, 1-based inclusive; both 0 = none)
  - `@export var hit_shape: HitShape` (null for DASH)
  - `@export var base_damage: int`
  - `@export var cooldown_frames: int` (0 = none)
  - `@export var move_tiles: float` (distance moved in the facing direction across the ACTIVE frames; 0 = stationary)
  - `@export var cancel_into: PackedInt32Array` (bit ids this action may be cancelled into during RECOVERY; `[Register.Bit.DASH]` by default)
  - `@export var chain_next: ActionDef` (the next hit of an ATTACK chain; null = end of chain)
  - Derived: `total_frames() -> int` = S + A + R.
  - `validate()`: all frame counts >= 0; `active_frames >= 1`; `recovery_frames >= 0`; `base_damage >= 0`; invuln range is either (0, 0) or `1 <= from <= to <= total_frames()`; `move_tiles >= 0`; a non-null `hit_shape` requires `active_frames >= 1`.
- [x] Create `game/src/core/defs.gd` (`class_name Defs`): static preloads of the bit and action resources, and `static func bit(id: int) -> BitDef` (ATTACK and DASH only in this story; null otherwise). Architecture: "Global catalogues are preloaded once in `src/core/defs.gd`".
- [x] Create the data: `game/data/bits/bit_attack.tres` (id ATTACK, glyph `A`, solo `slash_1`), `game/data/bits/bit_dash.tres` (id DASH, glyph `D`, solo `dash`), `game/data/actions/slash_1.tres`, `slash_2.tres`, `slash_3.tres` (S/A/R 6/4/12, arc 120 deg, radius 1.5 tiles, damage 10 / 10 / 15, cooldown 0, `chain_next` slash_2 / slash_3 / none, `cancel_into` [DASH]), `game/data/actions/dash.tres` (S/A/R 0/10/6, invuln 1-8, move 4 tiles, cooldown 24, no hit shape, `cancel_into` [DASH]).

### Group B: Pure logic (AC: 2, 3, 4, 5, 6)

- [x] Create `game/src/player/cooldowns.gd` (`class_name Cooldowns`, `extends RefCounted`): remaining frames per bit id. `start(bit: int, frames: int)`, `ready(bit: int) -> bool` (true when remaining is 0), `tick()` (decrements every non-zero entry by one), `reset()`, `remaining(bit: int) -> int` for the overlay.
- [x] Create `game/src/player/action_resolver.gd` (`class_name ActionResolver`, `extends RefCounted`): a static, pure function. Inputs: the `InputBuffer`, the poll frame, the active window (`Vector2i`), the current action state (the FSM's last executed action frame, the running `ActionDef` or null, the chain record, the shift serial), the `Cooldowns`. Output: an `ActionRequest` (a small `RefCounted` with `def: ActionDef`, `bit: int`, `slot: int`, `key: StringName`, `chain: bool`, `cancel: bool`) or null. It consumes the buffered press only when it returns a request. Rules, in order (see Dev Notes, frame model):
  1. Chain: if a chain is alive (no shift since its start, and the last executed frame of the running slash is in 15-22), and the press is the chain's key (`action_1` or `action_2`), and that slot still holds A, and `chain_next` is not null, then a request for `chain_next` with `chain = true`. Chain presses do not check cooldown (ATTACK has none).
  2. Cancel: if the running action is in RECOVERY (last executed frame in `startup+active+1 .. total`, including the final frame), and the press is on a slot whose bit is in the running action's `cancel_into`, and that bit's cooldown is ready, then a request with `cancel = true`.
  3. Solo: if no action is running or the running action has finished (last executed frame == total), then for J (slot 1) and then K (slot 2), a press whose slot bit has an action (`Defs.bit(bit).solo_action`) and whose cooldown is ready gives a request. J is checked first when both are buffered (rule 8 of NP-1).
  4. Otherwise nothing: the press is left buffered.
- [x] Create `game/src/player/action_request.gd` only if the resolver needs it as a separate file (the dev may keep it as an inner class).

### Group C: Action state machine and wiring (AC: 2-6)

- [x] Create `game/src/player/action_state_machine.gd` (`class_name ActionStateMachine`, `extends SimSystem`, phase `ACTIONS`). Constructor takes the shared `InputBuffer`, the `Player` and the `Register`. Fields (plain data, snapshot-friendly):
  - `enum ActionState { IDLE_MOVE, STARTUP, ACTIVE, RECOVERY, STUNNED, WATCHING }` (STUNNED and WATCHING are declared, never entered here).
  - `state: ActionState`, `action: ActionDef` (running or null), `action_frame: int` (last executed frame, 0 when none), `facing: Vector2i` (captured at start), `chain_key: StringName`, `chain_slot: int`, `chain_serial: int` (`-1` = no chain), `cooldowns: Cooldowns`, `active: bool`.
  - `tick(ctx)`: only when `active`. Order in one tick: (1) `cooldowns.tick()`; (2) `ActionResolver` with the buffer and `ctx.poll_frame`; a request starts a new action (action frame 1 executes this tick, cooldown starts, chain record updated, `Player` locked as below); (3) otherwise, if an action is running: if `action_frame == total`, the action finishes (state IDLE_MOVE, no frame executes); else `action_frame += 1`, and that frame executes this tick; (4) set `state` from the executing frame; (5) update the `Player` movement lock and the invulnerability flag for the executing frame.
  - `invulnerable() -> bool`: the executing frame is inside the action's invuln range.
  - `reset_for_fight()`: state IDLE_MOVE, no action, cooldowns cleared, chain cleared, `Player` unlocked (D-049 b: cooldowns reset at every fight start).
  - `set_active(on: bool)`: on in FIGHT, off elsewhere; turning off unlocks the `Player`.
- [x] `game/src/player/player.gd`: add a movement lock. `lock_movement(velocity_px: Vector2)` sets the lock and the forced velocity; `unlock_movement()` clears it. While locked, `tick()` takes `velocity_px` = the forced velocity, moves the position and clamps as usual, and does not change `facing`. Unlocked behaviour is unchanged (2.2 tests stay green).
  - Movement rules (D-S25-6): slash STARTUP and ACTIVE lock with zero velocity; dash ACTIVE locks with `move_tiles * TILE_PX / active_frames` px per frame in the captured facing; every other state is unlocked (RECOVERY moves normally and decelerates through the normal ramp).
- [x] `game/src/register/register.gd`: add `var shift_serial: int = 0`, incremented in `shift()` after a successful rotation. This is the only change to register behaviour, and it is read-only for other systems. (D-S25-2.)
- [x] `game/src/arena/arena.gd`: own the `ActionStateMachine` (`actions`), built from `SimClock.buffer`, `player` and `register` (construct after those fields, in declaration order or in `_init`; the dev verifies GDScript member order). `_enter_tree` registers it with `SimClock`, `_exit_tree` unregisters it. `enter_fight` calls `actions.reset_for_fight()` and `actions.set_active(true)`; `leave_fight` calls `actions.set_active(false)`. Player and register behaviour otherwise unchanged.

### Group D: Frame overlay and F9 (AC: 7)

- [x] Create `game/src/debug/frame_overlay.gd` (`class_name FrameOverlay`, `extends Node2D`), a child of `Arena` added by Main only when `Debug.enabled`, like `PlayerView`. Hidden by default. Draws, in arena-local pixels: the player hurtbox circle (`PlayerDef.hurtbox_tiles`, diameter, centred on `player.position_px`), and while the FSM is ACTIVE the action's hit shape at the player's position with the captured facing (Palette.INK outlines or dots; `Palette.INK` and `Palette.BG` only). Text lines at the top-left of the play area at 1x through `GlyphFont`: `sim_frame`, state name, frame in state, `J`/`K` cooldowns, `invulnerable`. A pure `static func format_lines(...) -> PackedStringArray` is unit-tested.
  - Read-only: it reads the FSM, the player and `SimClock.sim_frame`; it never writes sim state.
- [x] `game/src/debug/debug_keys.gd`: F9 (no modifiers, fresh press) toggles the frame overlay's visibility. The overlay reference is set by Main. Debug gate only (the node exists only when `Debug.enabled`).
- [x] Move the 1.5 debug grid from F9 to **Shift+F9** (D-S25-11): edit `game/project.godot` `debug_grid` to a Shift+F9 key event, and update `tests/unit/test_grid_overlay.gd` (`test_debug_grid_action_bound_to_f9` now checks F9 with `shift_pressed`). Verify Godot's modifier matching in the InputMap so plain F9 does not toggle the grid.
- [x] `game/src/main/main.gd`: in `_build_layers`, when `Debug.enabled`, add a `FrameOverlay` under the arena (after `PlayerView`), set its `player`/`actions` references, and pass it to `DebugKeys`.

### Group E: Tests (AC: all)

- [x] `game/tests/unit/test_hit_shapes.gd`: circle inside/outside; arc at 0, +59, +61, -59 and 180 degrees, and range boundary; capsule along facing with round ends; origin point counts as inside for circle and arc.
- [x] `game/tests/unit/test_cooldowns.gd`: start, ready, tick to zero, reset, independent bits.
- [x] `game/tests/unit/test_action_resolver.gd` (pure, with a real `InputBuffer`): solo press on A and D; slot order J before K when both buffered; press on a cooled-down bit left buffered, fires when ready within 8 frames, dropped after; chain rules (window 15-22, wrong key rejected, slot no longer A rejected, shift serial changed rejected); cancel rules (RECOVERY only, DASH only, cooldown blocks).
- [x] `game/tests/unit/test_action_fsm.gd` (real `SimClock` instance not in the tree, or the FSM ticked directly with a `SimContext` whose `poll_frame` is set; `after_each` frees nodes):
  - [x] S/A/R counts: slash runs 22 ticks: STARTUP x6, ACTIVE x4, RECOVERY x12; dash runs 16 ticks: ACTIVE x10, RECOVERY x6; next press after the last recovery frame starts on the following tick.
  - [x] Facing captured at press and held through the action; `Player` locked during slash STARTUP/ACTIVE (zero velocity) and unlocked in RECOVERY.
  - [x] Dash moves 4 tiles in 10 ticks (total displacement 64 px) in the captured facing, clamped at the arena bounds.
  - [x] Dash invulnerability: true on ticks 1-8 of the dash, false on 9 and later; false for slash.
  - [x] Cooldown blocking: second dash press at ticks 1-23 after the first is not consumed; at tick 24 it fires (the press pushed within the 8-frame window before the cooldown ends fires on the first ready tick).
  - [x] Chain timing: slash pressed at tick 0; press pushed at tick 6 expires before frame 15 and does not chain; press pushed at tick 7 chains on tick 15 (hit 2 starts with frame 1 on that tick); hit 2 chains to hit 3 under the same rule; hit 3 never chains; a shift between hit 1 and 2 cancels the chain.
  - [x] Cancel into dash: `[A, D]` (K = dash): slash on J at tick 0, K pressed at tick 12 starts the dash on tick 12; `[D, A]` (J = dash) and cancel of a slash's STARTUP is refused.
  - [x] `reset_for_fight()` clears state, cooldowns and chain, and unlocks the `Player`.
- [x] `game/tests/unit/test_frame_overlay.gd` (or inside `test_action_fsm.gd`): `format_lines` output for a sample state.
- [x] Update `game/tests/unit/test_debug_keys.gd`: F9 is no longer ignored (it toggles the overlay, debug gate only); Shift+F9 is ignored.
- [x] Update `game/tests/unit/test_player_movement.gd`: the lock API (locked velocity, facing unchanged, unlocked behaviour unchanged).
- [x] `game/tests/unit/test_register_system.gd` or `test_register.gd`: `shift_serial` increments on each applied shift and not on rejected ones.
- [x] Run GUT and the static guards (Testing Requirements). Baseline after 2.4 review: GUT 339/339 across 37 scripts; `bash game/tools/check_guards.sh` OK.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S25-1 Frame model.** One action frame executes per world tick. A press that starts an action executes its frame 1 on the press tick. An action with S+A+R frames occupies exactly S+A+R ticks; the next action can start on the tick after its last frame. The FSM keeps `action_frame` = the last executed frame. Derived states: `frame <= S` is STARTUP, `frame <= S+A` is ACTIVE, else RECOVERY (S=0 means no STARTUP frames, so dash frame 1 is ACTIVE). Invulnerability uses the executing frame.
  - Worked example, slash pressed on tick T: frames 1-22 execute on T..T+21. At tick T+15 the previous executed frame is 15, so a chain press resolved there starts hit 2 on T+15, replacing the remaining recovery. A press pushed on T+6 expires (8 frames) before T+15 and does not chain; one pushed on T+7 is still live on T+15 and chains there.
- **[design call] D-S25-2 Chain reset on shift.** `Register.shift_serial` increments on every applied shift. The chain record stores the serial at its start; a different serial kills the chain. A ring of two bits can return to the same window after two shifts, so the window itself is not used as the test.
- **[design call] D-S25-3 Buffered chain and cancel presses.** The 8-frame buffer applies to chain and cancel presses too. A press made a few frames before the window opens is accepted when the window opens, if it is still live. This is the same leniency as every other buffered press. Early presses outside the window that expire are dropped.
- **[design call] D-S25-4 Cooldown timing.** A bit's cooldown starts on the tick its action starts and counts sim frames (decremented at the start of the ACTIONS phase). `ready` is true once `cooldown_frames` have passed since the start, so dash is ready at tick start+24. Cancelling into dash starts the dash cooldown the same way. ATTACK has no cooldown, so chain hits never wait.
- **[design call] D-S25-5 Cancel rule scope.** Cancel is allowed from any RECOVERY frame, including the last one, and only into the bits in the running action's `cancel_into` (DASH now; Null Dodge in Epic 5). The cancelled action's remaining recovery is discarded. A cancel press is not a chain press, even when the chain key is the dash key.
- **[design call] D-S25-6 Movement during actions.** Slash locks the player in place during STARTUP and ACTIVE (the GDD gives no movement rule; walking evasion belongs to RECOVERY). Dash moves the player at a constant speed along the captured facing across its ACTIVE frames, then the normal decel ramp takes over in RECOVERY. The `@` may not turn during an action.
- **[design call] D-S25-7 Cross-link (J then K) left to 2.6.** In 2.5 a K press while J is in STARTUP, ACTIVE or non-cancellable RECOVERY is not consumed; it stays in the 8-frame buffer and expires if J does not end soon. The GDD rule "a no-combo pair executes when Action 1 ends" and the link window belong to Story 2.6, which owns the link state. (The GDD's "if pressed during Action 1 it is buffered and executes when Action 1 ends" conflicts with the fixed 8-frame lifetime for long actions; 2.6 decides.)
- **[design call] D-S25-8 Bits without an action.** L and N (and any slot whose bit has no `solo_action` in this story) do nothing on J or K. The press is not consumed and expires. This keeps the register ring and HUD working for the later bits.
- **[design call] D-S25-9 Simultaneous buffered presses.** When J and K are both available in the same tick, J is resolved first (NP-1 rule 8). The other press waits in the buffer.
- **[design call] D-S25-10 Hit shapes are geometry only.** The shapes know nothing about damage or targets; `contains` is a pure function of origin, facing and point. The slash arc is 120 degrees total (60 to each side of facing) with a 1.5-tile radius; the arc contains the origin point.
- **[design call] D-S25-11 F9 belongs to the frame overlay.** The architecture's debug key table and the epics put the frame overlay on F9 (2.5 AC, the planned F6-F10 set). The 1.5 grid was bound to F9 as an interim choice. The grid moves to Shift+F9 so F9 can be the frame overlay. The grid's default visibility, gate and toggle behaviour do not change, and `test_grid_overlay.gd` is updated for the new binding. Tiziano can rebind it if preferred.
- **[design call] D-S25-12 No attack visual in 2.5.** Pressing J/K makes no new glyph or effect: the `@` and the F9 overlay are the only feedback. Hit feedback (flash, particles, log lines) is Story 2.8, and the slash's own presentation waits for it. A visible slash before 2.8 would be an extra scope call for Tiziano.
- **[design call] D-S25-13 Inversion stays on the `@`.** D-S24-4 said 2.5 might move the 4-frame inversion to the slash glyph. No slash glyph exists yet (D-S25-12), so the `@` inversion from 2.4 is unchanged. Revisit with 2.8.
- **[design call] D-S25-14 Chain data.** The ATTACK chain is data (`slash_1.chain_next = slash_2`, `slash_2.chain_next = slash_3`, `slash_3.chain_next = null`) rather than a hard-coded length, so the chain's length is set by the `.tres` files. The three hits share frame data as the epic states; damage differs.

### Architecture guardrails (must follow)

- `ActionResolver` is the only code that turns J/K into actions (NP-1). It is a pure static function over its inputs. The FSM calls it; nothing else starts an action.
- Simulation folders (`player/`, `combat/`, `register/`, `arena/`) must not reference `ui/`, `presentation/`, `AudioManager` or `VoiceService`. `FrameOverlay` lives in `src/debug/` (not a sim folder) and reads sim state only.
- Integer frames only: `*_frames` fields, action frames as `int`, `ctx.poll_frame` for buffer time. No `delta`, `Timer`, `await`, `create_tween`, `get_ticks_*`. Only `SimClock` calls `tick()` on the FSM, through `SimSystem`.
- Phase: `ActionStateMachine.phase = SimPhase.ACTIONS` (after SHIFTS, before PLAYER, so a shift applies before the press is resolved and the player is locked before it moves).
- Defs are read-only at runtime. Mutable state lives on `Cooldowns`, the FSM and the `Player`.
- Single writers: `Register` methods own the ring (`shift_serial` is written only in `shift()`); `Player` movement and the new lock API are the only writers of position; the FSM is the only writer of action state.
- Typing: every variable, parameter and return is typed; `StringName` for ids (`&"action_1"`, `&"action_2"`); `Log.debug(&"action", ...)` only on events (start, chain, cancel, cooldown block once per press), never per frame.
- Palette: `Palette.INK` and `Palette.BG` only in drawing (test_glyph_palette guard). Overlay text uses `GlyphFont` at 1x.
- Script cycles leak at exit (2.2 lesson): the FSM holds `Player` and `Register` references; `Arena` owns them; neither holds the FSM.

### Frame table

| Action | S | A | R | Total | Frames | Invuln | Cancel | Cooldown |
|---|---|---|---|---|---|---|---|---|
| slash_1 / slash_2 / slash_3 | 6 | 4 | 12 | 22 | STARTUP 1-6, ACTIVE 7-10, RECOVERY 11-22 | none | DASH | none |
| chain window (hit 1 or 2) | | | | | last executed frame 15-22 | | | |
| dash | 0 | 10 | 6 | 16 | ACTIVE 1-10, RECOVERY 11-16 | 1-8 | DASH | 24 |

Dash distance: 4 tiles = 64 px over 10 frames = 6.4 px per frame in the captured facing (`move_tiles * TILE_PX / active_frames`, computed from data, not typed in).

### Previous story intelligence (2.1-2.4)

- `SimClock.tick()` order: pause gate, poll input into `InputBuffer` stamped with `poll_frame`, set `ctx.move_dir` and `ctx.poll_frame`, `poll_frame += 1`, Breakpoint gate, hit-stop gate, tick systems by phase, `sim_frame += 1`. The FSM relies on this order; during hit-stop the buffer ages through `poll_frame`, and a press can expire during a long hit-stop (2.3 design call D-S23-2).
- `InputBuffer.consume(action, frame)` takes an action name and a frame and is consumed at most once; `consume_oldest` exists for shifts. A press is live for `frame - pushed <= 8`.
- `LiveInput.BUFFERED_ACTIONS` already includes `action_1` and `action_2`; `project.godot` binds them to J (74) and K (75).
- `Register` (2.3): a `SimSystem` in SHIFTS; `active_window()` is `Vector2i(ring[0], ring[1])`; `Bit` enum `ATTACK=1, DASH=2, LOOP=3, NULL_BIT=4`; `shift()` emits `register_shifted` once. The fight-start set for Boss 1 is `[D, A]`, so J is dash and K is slash at the start.
- `Player` (2.2): `position_px`, `velocity_px`, `facing` (`Vector2i` in 8 directions), `bounds_px`, `active`, `tick(ctx)` returns early when inactive. `PlayerDef` carries `hurtbox_tiles = 0.6` (used by the overlay).
- `Arena` (2.2, 2.3): `enter_fight` resets the player and register, clears `SimClock.buffer`, activates both; `leave_fight` deactivates. `_enter_tree` and `_exit_tree` register and unregister the systems so re-instancing Main never double-ticks.
- `JuiceDirector` and `PlayerView` (2.4): presentation only; they read `player.position_px` and `facing`. `PlayerView` redraws while the player is active; the overlay must use the same redraw rule.
- Debug keys (1.6, 2.1): `DebugKeys` handles F1-F5 and F11 in `_input`, debug gate only; `test_debug_keys.gd` asserts F9 is ignored today. This story changes that test on purpose (D-S25-11).
- Deferred items that touch this story (`deferred-work.md`): "Held gameplay actions are not released on pause; handle with the player controller (Epic 2)" (1.7): the FSM and the movement lock tick only under `SimClock`, so pause freezes an action in place; the buffered presses are kept by the gate, and the held-action release is handled by the movement lock and the FSM reset on fight exit. "Only SimClock.paused is paused: tweens, timers ... keep running; gameplay must read SimClock.paused" (1.7): the FSM never reads wall time. "[design call] Hit-stop/Breakpoint longer than 8 frames drops all buffered input" (2.3): this story keeps the rule; check by feel in H3. "`SimClock._systems` can be mutated during tick iteration" (2.3): the FSM does not unregister itself during a tick.
- Test baseline after 2.4 review: GUT 339/339 across 37 scripts; `check_guards.sh` OK.

### Git intelligence (recent commits)

- `783dc74` Story 2.4: shift juice (`ShiftJuice`, `JuiceDirector`, `AudioManager.play_sfx`, clip mask on the register panel, `PlayerView.inverted`).
- `c0f1f34` Story 2.3: register ring, shift and HUD panel (`Register`, `RegisterPanel`, `EventBus.register_shifted`, FIGHT wiring in `Arena` and `Main`).
- `d8b748f` Story 2.2: player movement, `PlayerView`, held-direction input.
- `0b057fa` Story 2.1: sim clock, input source, buffer, recorder, F11, guards.
- Pattern: each story adds small files, extends existing tests, keeps `check_guards.sh` green, records design calls and human checks in the story file.

### Latest technical information

- No new engine features. Godot 4.7.2 GDScript: `Resource` subclasses with `@export` (for `ActionDef`, `BitDef`, `HitShape`), `PackedInt32Array` exports, typed arrays, `Node2D.draw_*` and `queue_redraw()`. Confirm exact method names against `/godotengine/godot-docs/__branch__4.7` (project-context) before use; no web research was run for this story.
- `InputEventKey` modifier matching for `debug_grid` (Shift+F9): verify in the editor/headless run that plain F9 does not match a Shift event.

### Project Context Rules

- Godot project root is `game/`. Files go under `game/src/player/`, `game/src/combat/shapes/`, `game/src/register/`, `game/src/core/`, `game/src/debug/`, `game/data/actions/`, `game/data/bits/`, `game/tests/unit/`.
- `project-context.md` (`_bmad-output/project-context.md`): "Only `SimClock` calls `tick(ctx)`"; "No `Area2D`/`PhysicsBody2D` for gameplay. Hits are shape math"; "State machines: enum + match + int counters stored as fields"; "Data: typed `Resource` `*Def` classes in `data/**/*.tres`, read-only at runtime"; "Signals: declare only in `event_bus.gd`"; "Never log per frame".
- Critical don't-miss rules that apply now: ordered combos are looked up by ordered pair (2.6); a combo whose second bit is cooled down stays buffered 8 frames then drops (2.6, same rule the solo press already follows here); Patched and damage are out of scope.

### Project Structure Notes

- New: `game/src/combat/shapes/hit_shape.gd`, `hit_circle.gd`, `hit_arc.gd`, `hit_capsule.gd` (+ `.uid` on import); `game/src/register/bit_def.gd`; `game/src/player/action_def.gd`, `action_state_machine.gd`, `action_resolver.gd`, `cooldowns.gd` (+ optional `action_request.gd`); `game/src/core/defs.gd`; `game/src/debug/frame_overlay.gd`; `game/data/bits/bit_attack.tres`, `bit_dash.tres`; `game/data/actions/slash_1.tres`, `slash_2.tres`, `slash_3.tres`, `dash.tres`; tests `test_hit_shapes.gd`, `test_cooldowns.gd`, `test_action_resolver.gd`, `test_action_fsm.gd`, `test_frame_overlay.gd` (or merged).
- Modified: `game/src/player/player.gd` (movement lock API), `game/src/register/register.gd` (`shift_serial`), `game/src/arena/arena.gd` (owns and wires the FSM), `game/src/debug/debug_keys.gd` (F9), `game/src/main/main.gd` (overlay under debug), `game/project.godot` (grid to Shift+F9), `game/tests/unit/test_grid_overlay.gd`, `test_debug_keys.gd`, `test_player_movement.gd`, `test_register.gd` or `test_register_system.gd`, `_bmad-output/implementation-artifacts/sprint-status.yaml`.
- Conflicts: none with the architecture's listed paths. The architecture's `src/player/player.scn`/`.tscn` is not needed; `Player` stays a `SimSystem` with no node.

### Testing Requirements

- GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Run `godot --headless --path game --import` first in a fresh worktree so new `.tres` and `.gd` UIDs are generated.
- Static guards: `bash game/tools/check_guards.sh` from the repo root.
- Simulation code is tested without a scene tree: `ActionResolver` with a real `InputBuffer`; `ActionStateMachine` ticked directly with a `SimContext` whose `poll_frame` is set (or a real `SimClock` not in the tree with a scripted `InputSource`, as in `test_register_system.gd`); `Player` with a `PlayerDef` and a bounds rect. Free every node or `RefCounted` you create in `after_each`.
- Do not rely on real key events in GUT. Presses come from `buffer.push(&"action_1", frame)` or a scripted input source.
- The data validation test covers the new `.tres` files automatically; keep every new def's `validate()` empty.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.5 H1] Debug build, F2 (FIGHT). With the register `[D, A]`: J dashes, K slashes. The dash moves about 4 tiles in a fraction of a second, with no sideways drift; the `@` does not turn mid-dash. Judge the feel in Chrome and Firefox.
- [ ] [2.5 H2] Press K repeatedly: the slash chains 1 to 2 to 3 when pressed in the late recovery; a fourth press does not chain. Press Q or E between hits: the chain resets (D-S25-2). Note the chain timing feel (D-S25-1, D-S25-3).
- [ ] [2.5 H3] Press J during a dash's recovery: a dash cannot cancel into a new dash (its 24-frame cooldown outlasts its 16 frames); the press waits and starts a fresh dash once the cooldown is over (D-S25-4, D-S25-5).
- [ ] [2.5 H4] F9 overlay: state, frame in state, cooldown counters, `invulnerable` 1-8 on dash, the hurtbox circle and the slash arc during ACTIVE. Shift+F9 still toggles the grid.
- [ ] [2.5 H5] Release build (no `?debug`): F9 does nothing; J and K still work after the title's audio unlock.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.5] (ACs, FR10/11/14)
- [Source: _bmad-output/planning-artifacts/epics.md#FR10-FR17] (frame data for slash and dash, chain, cancel, combo trigger)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Bits (solo actions)] (S/A/R, damage, cooldowns)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Combos] (link window; resolution rules D-045)
- [Source: _bmad-output/game-architecture.md#NP-1] (ActionResolver, ActionStateMachine, Cooldowns, data flow and resolution rules)
- [Source: _bmad-output/game-architecture.md#Actions & Combos (AD-02)] (ActionDef, BitDef fields)
- [Source: _bmad-output/game-architecture.md#Notes for Designer] (design calls 1-3 apply here)
- [Source: _bmad-output/game-architecture.md#Debug Tools] (F9 frame overlay in the planned F-key set)
- [Source: _bmad-output/project-context.md] (engine, data, state machine and testing rules)
- [Source: _bmad-output/implementation-artifacts/2-4-shift-juice.md] (format reference and D-S24-4 forward note)

### Review Findings

Code review 2026-11-07 (Blind Hunter, Edge Case Hunter, Acceptance Auditor as parallel subagents). Acceptance Auditor: no AC violations. 7 patch (all fixed), 8 defer, 11 dismissed. [design call] no decision_needed items.

- [x] [Review][Patch] FSM state survives `set_active(false)` (ghost dash invulnerability, stale overlay) [action_state_machine.gd:set_active]
- [x] [Review][Patch] Final-frame tick treated as a cancel, so K could outrank J (NP-1 rule 8) [action_resolver.gd:resolve]
- [x] [Review][Patch] `Cooldowns.start(bit, 0)` erased a running cooldown [action_state_machine.gd:_start]
- [x] [Review][Patch] `ActionDef.validate` accepted `chain_next` cycles [action_def.gd:validate]
- [x] [Review][Patch] F9 consumed when no overlay exists [debug_keys.gd:handle_key]
- [x] [Review][Patch] H3 described an unreachable dash-into-dash cancel; reworded [story H3]
- [x] [Review][Patch] Tests added for the above (set_active clear, chain cycle, F9 no overlay, last-frame solo)
- [x] [Review][Defer] Player lock state has two owners; Player.set_active/reset_for_fight do not clear it [player.gd] - deferred, safe while the FSM is the only caller
- [x] [Review][Defer] Post-dash velocity cap drops 6.4 to ~1.9 px/frame in one tick (D-S25-15) - deferred, judge in H1
- [x] [Review][Defer] Dash `cancel_into` DASH is dead data (cooldown 24 > total 16) [dash.tres] - deferred, harmless
- [x] [Review][Defer] `HitArc`/`HitCapsule` disagree on zero facing - deferred, FSM never yields zero
- [x] [Review][Defer] Overlay stale after leaving FIGHT, draws under later layers, hurtbox diameter vs radius [frame_overlay.gd] - deferred to Story 2.7
- [x] [Review][Defer] `validate` does not check `cancel_into` has a solo action or shape/damage consistency - deferred
- [x] [Review][Defer] Dead `chain_slot`, hard-coded ATTACK in `_chain`, 9-arg `resolve`, ActionRequest/ActionResolver cycle - deferred cleanup
- [x] [Review][Defer] Missing "cooldown block" debug log, Arena FSM integration and shift-during-dash tests - deferred

## Dev Agent Record

### Agent Model Used

Story created by Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended). Implemented by Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story (unattended).

### Debug Log References

- Fresh worktree: `godot --headless --path game --import` before the first GUT run.
- First full run: 398/399; `test_shift_serial_counts_applied_shifts` tripped GUT's unexpected `push_error` from the rejected `shift(0)`; fixed with `assert_push_error` (same as `test_bad_direction_is_rejected`).
- Headless boot of Main for 120 frames: no errors or warnings.

### Completion Notes List

- Implementation plan: geometry and data first (`HitShape` family, `ActionDef`, `BitDef`, `Defs`, six `.tres`), then the pure pieces (`Cooldowns`, `ActionResolver` + `ActionRequest`), then the `ActionStateMachine` (ACTIONS phase) with the `Player` movement lock, `Register.shift_serial` and the `Arena` wiring, then the F9 `FrameOverlay` and the Shift+F9 grid move.
- Frame model follows D-S25-1 exactly: frame 1 executes on the press tick; the resolver sees the last executed frame, so a slash chains on ticks 15-22 after its press, the cancel window is the last executed frame 11-22, and the next action can start on the tick after the last frame (tested with dash then slash on tick 16).
- `ActionResolver` never peeks: each rule checks its conditions first and calls `InputBuffer.consume` only when the request would be returned, so blocked presses stay buffered without any `InputBuffer` change. Chain window is generic: the last `CHAIN_WINDOW_FRAMES = 8` recovery frames.
- `ActionRequest` is its own file (`src/player/action_request.gd`) so tests and the FSM can type it.
- `Arena.actions` is declared after `player` and `register` (GDScript initialises members in declaration order) and is registered between them; SimClock sorts by phase anyway.
- `Log.debug(&"action", ...)` on start, chain and cancel only. The "cooldown block once per press" debug line was not added: it would need a buffer peek, and the story forbids `InputBuffer` changes.
- `FrameOverlay` draws the hurtbox (diameter `hurtbox_tiles`), the active hit shape (arc, circle or capsule outlines) and four ASCII lines at 1x through `GlyphFont`, INK only. Added to `test_glyph_palette.gd`'s source list. `DebugKeys` toggles it on plain F9 (any modifier is ignored); the grid action is now Shift+F9, and a test checks `InputMap.event_is_action` does not match plain F9.
- [design call] D-S25-15 Post-dash slide: `Player.unlock_movement()` caps the carried velocity at walking top speed (7 tiles/s). Without the cap the 6.4 px/frame dash speed decelerates through the 3-frame walk ramp for ~10 frames and slides ~2 extra tiles after every dash. With the cap the slide is about 2.5 px. Revisit by feel in H1.
- [design call] D-S25-16 Action facing = `Player.facing` at the press tick (the facing from the previous world tick, since PLAYER ticks after ACTIONS). A direction pressed on the exact same frame as J/K does not turn the action. Judge in H1; an alternative is to use `ctx.move_dir` when non-zero.
- [design call] D-S25-17 After hit 3 (or any chain end) a fresh J press in the old window simply starts a new `slash_1` once the action ends; a shift mid-chain also falls back to a fresh `slash_1` after the current hit ends (not a chain).
- Tests: GUT 399/399 across 42 scripts (baseline 339/37; +60 tests: `test_hit_shapes` 6, `test_cooldowns` 5, `test_action_resolver` 15, `test_action_fsm` 22, `test_frame_overlay` 4, plus additions to `test_debug_keys`, `test_grid_overlay`, `test_player_movement`, `test_register`). `bash game/tools/check_guards.sh`: OK.
- Human checks H1-H5 (Dev Notes) are open for Tiziano; they do not block `review`.

### File List

New:
- game/src/combat/shapes/hit_shape.gd (+ .uid)
- game/src/combat/shapes/hit_circle.gd (+ .uid)
- game/src/combat/shapes/hit_arc.gd (+ .uid)
- game/src/combat/shapes/hit_capsule.gd (+ .uid)
- game/src/register/bit_def.gd (+ .uid)
- game/src/player/action_def.gd (+ .uid)
- game/src/player/action_request.gd (+ .uid)
- game/src/player/action_resolver.gd (+ .uid)
- game/src/player/action_state_machine.gd (+ .uid)
- game/src/player/cooldowns.gd (+ .uid)
- game/src/core/defs.gd (+ .uid)
- game/src/debug/frame_overlay.gd (+ .uid)
- game/data/bits/bit_attack.tres
- game/data/bits/bit_dash.tres
- game/data/actions/slash_1.tres
- game/data/actions/slash_2.tres
- game/data/actions/slash_3.tres
- game/data/actions/dash.tres
- game/tests/unit/test_hit_shapes.gd (+ .uid)
- game/tests/unit/test_cooldowns.gd (+ .uid)
- game/tests/unit/test_action_resolver.gd (+ .uid)
- game/tests/unit/test_action_fsm.gd (+ .uid)
- game/tests/unit/test_frame_overlay.gd (+ .uid)

Modified:
- game/src/player/player.gd
- game/src/register/register.gd
- game/src/arena/arena.gd
- game/src/debug/debug_keys.gd
- game/src/main/main.gd
- game/src/ui/hud/grid_overlay.gd (comment only: Shift+F9)
- game/project.godot
- game/tests/unit/test_debug_keys.gd
- game/tests/unit/test_grid_overlay.gd
- game/tests/unit/test_glyph_palette.gd
- game/tests/unit/test_player_movement.gd
- game/tests/unit/test_register.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/2-5-action-state-machine-with-attack-and-dash.md

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S25-1 to D-S25-14 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): hit shapes, ActionDef/BitDef/Defs and data, Cooldowns, ActionResolver, ActionStateMachine, Player movement lock, Register.shift_serial, F9 frame overlay (grid to Shift+F9), tests. GUT 399/399, guards OK. Design calls D-S25-15 to D-S25-17 added. Status review.
- 2026-11-07: Code review (3 parallel layers): 7 patches applied, 8 deferred, 11 dismissed. GUT 402/402, guards OK. Status done.
