---
baseline_commit: 1d7ab68
---

# Story 2.9: Player Damage, Death and Instant Retry

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. This is the last story of Epic 2. -->

## Story

As a player,
I want to die cleanly and be back in the fight within 2 seconds,
so that failure is cheap and I keep trying.

**Requirements:** FR2 (5 HP, hurtbox, post-hit invulnerability), FR49 (death screen and retry), NFR5 (retry in ≤ 2 s, no added input latency); GDD "Win/Loss Conditions", "Hit feedback" (Player hit row), D-011, D-049 (b)(c); AD-01 (hit-stop is sim state), AD-05 (presentation listens, never writes), AD-08 (`Game` FSM with DEAD, `RunState` snapshot on FIGHT enter, `retry()` restores it), I-5 (`RunState.deaths_on_boss`).
**Epic 2 window:** Nov 8–10. **Depends on:** 2.1 (`SimClock`, `request_hitstop`, `sim_frame`, `poll_frame`, `begin_fight`), 2.2 (`Player`, `PlayerDef` with `max_hp`, `invuln_frames`, `hurtbox_tiles`), 2.3 (`Register.set_fight_start`, `fight_start_for_boss`), 2.5 (`ActionStateMachine.invulnerable()`, `reset_for_fight`, cooldown reset), 2.6 (`LinkState.close`), 2.7 (`CombatResolver`, `PracticeTarget`, `DebugKeys.practice_requested`), 2.8 (`HitFeedback`, `CameraShakeDriver`, `LogPanel`, `JuiceDirector`, the Main layer wiring).
**Unblocks:** Epic 3 (boss attacks and contact call the same `PlayerHealth` hit path; the death and retry flow is the one bosses use), Epic 2 retrospective and the Epic 2 Definition of Done (browser checks are deferred, see `deferred-work.md`).

## Acceptance Criteria

1. **Given** the player is hit by a source (the debug damage key now; boss attacks and contact in Epic 3) **And** the hit lands outside invulnerability
   **When** it resolves
   **Then** HP drops by 1; the HP readout shows `hp: 0b11111` → `hp: 0b01111` → … (5 bits at full, one fewer per hit); the sim requests 4 frames of hit-stop (`HitFeedback.PLAYER_HITSTOP`); the camera shakes 3 px for 4 frames (`CameraShake`, arena camera only); the log panel appends `WARN: hp--`; `EventBus.player_damaged(hp)` is emitted; and the player is invulnerable for 60 frames (`PlayerDef.invuln_frames`) with the `@` blinking.

2. **Given** the player is inside dash invulnerability (`ActionStateMachine.invulnerable()` is true on the current action frame) or inside post-hit invulnerability
   **When** a hit source fires
   **Then** the hit is ignored: no HP change, no hit-stop, no shake, no log line, no `player_damaged` signal.

3. **Given** HP reaches 0
   **When** the lethal hit resolves
   **Then** `Game` enters `DEAD` (through `Game` only), `RunState.deaths_on_boss` increments by 1, `EventBus.player_died(boss_id, deaths_on_boss)` is emitted, the DEAD screen shows `Process exited with code 1`, and no further hits are applied while dead.

4. **Given** the DEAD screen
   **When** I make a new key press or click **and** it is made at least 20 sim frames after the death frame
   **Then** the fight restarts from the `RunState` snapshot (AC 6) and the restart happens on that press (no delay, well inside the 2-second budget)
   **And** presses made before the 20-frame gate do nothing and do not restart the fight
   **And** a key held through the moment of death never counts (only fresh, non-echo press events count; Esc, modifier keys and F-keys never count, as on the title).

5. **Given** a retry
   **When** the fight restarts
   **Then** the player has full HP (`PlayerDef.max_hp`), no post-hit invulnerability, and reset cooldowns; the link and any Echo memory are cleared (Echo memory is Epic 4: the hook is called, nothing is stored yet); `rng` is reseeded from a new fight seed; the boss is at its fight-start state (boss HP is Epic 3: nothing to restore yet, recorded in Dev Notes).

6. **Given** the register was shifted during the fight
   **When** I retry
   **Then** the register equals the snapshot captured on FIGHT enter (the fight-start set), not the shifted ring
   **And** `tests/integration/test_retry_snapshot.gd` verifies that a register shifted mid-fight is restored on retry, and that a retry does not re-capture the snapshot.

7. **Given** the run's boss changes (Intro → Fight 1, Harvest → next Fight, a debug jump to a boss)
   **When** the new boss's FIGHT starts
   **Then** `deaths_on_boss` resets to 0; a retry does not reset it (the 3rd-death hint in Epic 4 reads it).

8. **Given** a debug build (`Debug.enabled`) and FIGHT
   **When** I press F6
   **Then** one hit is queued on the player (the debug damage key); F6 does nothing in other flow states and in release builds (`DebugKeys` is not added without the gate).

9. **Given** the `Process exited` DEAD screen and the HUD
   **When** DEAD is shown
   **Then** the arena and register HUD are hidden, the log panel keeps the lines of the fight that just ended until the retry (it clears on the next FIGHT entry), and Esc does not pause in DEAD (DEAD is not a pausable state).

10. **Given** the code is reviewed
    **Then** presentation never writes HP, invulnerability or death state (it reads `PlayerHealth` and `Game`, and calls only `queue_hit` and `Game.retry`), `tools/check_guards.sh` passes, every duration is an `int` frame count, and no `Timer`, `await` or `create_tween` appears in sim code.

## Scope Boundaries

- **In:** the HP model (`PlayerHealth`), the hit pipeline and its feedback, the DEAD flow, the retry snapshot, the death and retry tests, the debug damage key, the HP readout, the DEAD screen.
- **Out (later stories):** boss attacks and contact damage (Epic 3; the hit path is built so they call the same `queue_hit`/`apply` pipeline), boss HP restore (Epic 3), Echo memory (Epic 4), the 3rd-death duck hint (Epic 4, reads `player_died`), the Intro and the real fight screens (Epic 6), save and resume (Epic 7), the crit and resisted hit log forms (Epic 3).

## Tasks / Subtasks

- [x] **Group A: Signals and data (AC: 1, 3, 7)**
  - [x] A1. `EventBus`: add `signal player_damaged(hp: int)` and `signal player_died(boss: StringName, deaths_on_boss: int)` with `@warning_ignore("unused_signal")`, past tense, typed args (project-context rule).
  - [x] A2. `RunState`: add `deaths_on_boss: int = 0`, `fight_start_ring: PackedInt32Array` (the snapshot), and `start_boss(index: int)` that sets `boss_index` and resets `deaths_on_boss` to 0. Every place that sets a new boss index (`Game.finish_intro`, `Game.advance` HARVEST → FIGHT, `Game.debug_jump`) goes through `start_boss`; a retry never does.
  - [x] A3. `HitFeedback`: add `const PLAYER_HITSTOP := 4` (GDD "Player hit"). Pure, no node.
  - [x] A4. `CameraShake`: keep the combo schedule (2 px, 6 frames) as the default and add an amplitude-and-frames variant used by the player hit (3 px, 4 frames, D-S29-6). Pure and static; `CameraShakeDriver.start` takes the schedule.

- [x] **Group B: PlayerHealth sim system (AC: 1, 2, 3, 5)**
  - [x] B1. New `game/src/player/player_health.gd`, `class_name PlayerHealth extends SimSystem`, `phase = SimPhase.COMBAT`, registered by `Arena._enter_tree` **after** `combat` (same phase, registration order). Fields: `def: PlayerDef`, `hp: int`, `invuln_left: int`, `dead: bool`, `active: bool`, `_pending: bool`, `_actions: ActionStateMachine` (injected). No boss id here: `Game` owns the boss mapping.
  - [x] B2. `tick(ctx)`: return unless `active`; if `invuln_left > 0`, decrement it; if `_pending`, clear it and call `apply_hit()`. Sim-only, no `delta`.
  - [x] B3. `apply_hit()`: ignored when `dead` or `invuln_left > 0` or `_actions.invulnerable()` (dash frames, AC 2). Otherwise `hp -= 1`, `invuln_left = def.invuln_frames`, `SimClock.request_hitstop(HitFeedback.PLAYER_HITSTOP)`, `Log.debug(&"combat", "player hit hp=%d" % hp)`, `EventBus.player_damaged.emit(hp)`. When `hp == 0`: set `dead = true` and stop accepting hits immediately (the death itself is raised by Game, D-S29-2).
  - [x] B4. `queue_hit()`: sets `_pending` (the only entry point from presentation; a request, not a state write). `reset_for_fight()`: `hp = def.max_hp`, `invuln_left = 0`, `dead = false`, `_pending = false`. `set_active(on)`.
  - [x] B5. Pure statics for tests: `hp_text(hp: int, max_hp: int) -> String` (`"hp: 0b11111"` at 5/5, `"hp: 0b01111"` at 4/5, `"hp: 0b00000"` at 0; zero-padded to `max_hp` bits, low bits = remaining HP) and `blink_hidden(invuln_left: int) -> bool` (hidden on alternate blocks of 4 frames while `invuln_left > 0`).
  - [x] B6. `Arena`: own `health: PlayerHealth = PlayerHealth.new(PLAYER_DEF, actions)`; `enter_fight` calls `health.reset_for_fight()` and `health.set_active(true)`; `leave_fight` sets it inactive; `_exit_tree` unregisters it. `enter_fight` takes the fight-start ring from its caller (AC 6) instead of computing it.

- [x] **Group C: Game flow and snapshot (AC: 3, 4, 5, 6, 7)**
  - [x] C1. `Game._ready`: connect `EventBus.player_damaged` to `on_player_damaged(hp)`; `hp <= 0` calls `record_death(SimClock.sim_frame)`. Tests call the methods directly (no tree).
  - [x] C2. `record_death(frame)`: only from FIGHT (ignored otherwise); `run.deaths_on_boss += 1`; `death_frame = frame`; `_set_flow_state(DEAD)`; `EventBus.player_died.emit(BOSS_IDS[run.boss_index], run.deaths_on_boss)`. `BOSS_IDS = [&"infinite_loop", &"null_pointer", &"segfault"]`.
  - [x] C3. Snapshot: in `_set_flow_state`, when `to == FIGHT` and `from != DEAD`, set `run.fight_start_ring = Register.fight_start_for_boss(run.boss_index)` **before** `_begin_fight` and before `flow_state_changed` is emitted. A retry (`from == DEAD`) never re-captures.
  - [x] C4. `static func retry_open(death_frame: int, frame: int) -> bool`: `death_frame >= 0 and frame - death_frame >= RETRY_DELAY_FRAMES` (`const RETRY_DELAY_FRAMES := 20`). `retry(frame) -> bool`: false unless `flow_state == DEAD` and `retry_open(death_frame, frame)`; then `_set_flow_state(FIGHT)`, then `SimClock.swallow_presses_next_poll()` (D-S29-12). Clears `death_frame` on success.
  - [x] C5. `Main.apply_flow_state`: the arena's fight-start ring comes from `Game.run.fight_start_ring` (not `Register.fight_start_for_boss`); `hud.log_panel.clear()` runs only when entering FIGHT (not DEAD); `_make_screen(DEAD)` returns the new `DeadScreen`.
  - [x] C6. `SimClock`: add `swallow_presses_next_poll()`: the next `tick()` that polls drops that tick's presses (movement is still read). `begin_fight` does not clear it. Used only by retry.

- [x] **Group D: Presentation (AC: 1, 4, 8, 9, 10)**
  - [x] D1. `LogPanel`: also connect `EventBus.player_damaged`; append `WARN: hp--` (`LogPanel.line_for_player_hit()`, pure). Same connect/disconnect pattern as `hit_landed`.
  - [x] D2. `CameraShakeDriver`: connect `EventBus.player_damaged` and start the player-hit schedule (3 px, 4 frames). The combo schedule is unchanged.
  - [x] D3. `PlayerView`: skip drawing the `@` while `PlayerHealth.blink_hidden(invuln_left)` (the duck is not blinked); `Main` injects the health reference.
  - [x] D4. HP readout: draw `PlayerHealth.hp_text(hp, max_hp)` at 1x in the register panel's left column (cols 0–11) on a row the panel does not use (verify against `RegisterPanel`'s rows; default row 20 between the preview and the duck, see D-S29-8). Presentation reads `hp` only.
  - [x] D5. New `game/src/ui/screens/dead/dead_screen.gd` (`class_name DeadScreen extends Node2D`, mirrors `PlaceholderScreen` drawing): one text line `Process exited with code 1`, centred on the same text grid. `_unhandled_input`: a fresh non-echo key press that is not Esc, a modifier or an F-key, or a left-button press, calls `Game.retry(SimClock.sim_frame)` and consumes the event. Pure `static func is_retry_press(event)` for tests (same rules as `PlaceholderScreen.is_advance`; also accept `physical_keycode` when `keycode == 0`, the 1.6 deferral).
  - [x] D6. `DebugKeys`: F6 (no modifiers) queues one hit on `player_health` when `Game.flow_state == FIGHT`; injected by Main like `frame_overlay`; null means F6 does nothing. `DebugKeys` is not referenced by release code.

- [x] **Group E: Tests (AC: 1–9)**
  - [x] E1. `tests/unit/test_player_health.gd`: lethal sequence 5 → 0 (five hits spaced past invulnerability); invulnerability blocks a hit at 59 frames and admits it at 60; dash invulnerability (fake `ActionStateMachine` stub or the real FSM on a dash frame 1–8) blocks; dead ignores hits; `hp_text` at 5, 4, 0; `blink_hidden` alternates. Uses `SimContext` and no tree; hitstop request observed via a stub or `SimClock` with `tick` called directly.
  - [x] E2. `tests/unit/test_game_flow.gd` additions (Story 2.9 section): `retry_open` boundary (19 false, 20 true, death_frame -1 false); `record_death` increments and emits `player_died` with the boss id; `retry` refused outside DEAD and before the gate; a retry after the gate returns to FIGHT; `deaths_on_boss` resets on `start_boss` and not on retry; the snapshot is captured on the first FIGHT entry only.
  - [x] E3. `tests/integration/test_retry_snapshot.gd`: enter FIGHT with the boss 0 fight-start set [D, A]; shift the register (`Register.shift` via the public method) so the ring is [A, D]; trigger the lethal hit; retry past the gate; assert the register is [D, A] again, HP is 5, cooldowns are empty, the FSM is unlocked, and `RunState.fight_start_ring` is still [D, A] (a retry does not re-capture it).
  - [x] E4. `tests/unit/test_log_panel.gd`: `WARN: hp--` line appended on `player_damaged`; `test_camera_shake.gd`: the 3 px / 4-frame schedule; `test_dead_screen.gd`: `is_retry_press` for press, echo, Esc, Shift, F5, mouse and keycode-0 cases; `test_sim_clock` (or `test_sim_context`): `swallow_presses_next_poll` drops one poll's presses only.
  - [x] E5. Existing suites green: `test_damage_calc`, `test_combat_resolver`, `test_practice_target`, `test_action_fsm`, `test_replays`, `test_data_validation` (the `PlayerDef` validation already covers `max_hp` and `invuln_frames`).

- [x] **Group F: Guards and wiring (AC: 10)**
  - [x] F1. `check_guards.sh`: no change needed for sim (`PlayerHealth` uses `SimClock.request_hitstop` from sim code, which is allowed; presentation never calls it). Add to the presentation guard: `\bhp\s*(=|-=|\+=)` and `invuln_left\s*=` and `\.dead\s*=` must not appear in `presentation/`, `ui/`, `debug/` (except `debug_keys.gd` calling `queue_hit`).
  - [x] F2. Run `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` and `bash game/tools/check_guards.sh` from the repo root.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S29-1 Hit pipeline lives in `PlayerHealth`.** A sim `SimSystem` in the COMBAT phase, after `CombatResolver`. It owns `hp`, `invuln_left`, `dead`, and a one-slot pending hit request. `queue_hit()` is the only entry from presentation (debug key now; boss attacks and contact in Epic 3 call the same path inside the sim). Reason: HP is sim state (AD-01), and the sim must see invulnerability on the same frame it resolves.
- **[design call] D-S29-2 Death is raised by `Game`, not by the sim.** `PlayerHealth` never changes flow. It emits `EventBus.player_damaged(hp)`; `Game` listens and, at `hp == 0`, calls `record_death`, which owns `deaths_on_boss`, the DEAD transition and `player_died`. The sim marks `dead` immediately so no second hit resolves in the same tick. Flow change inside the COMBAT phase is safe: `leave_fight` only sets flags and never adds or removes systems, and it runs after `CombatResolver` has finished the frame's hits.
- **[design call] D-S29-3 Retry gate: 20 sim frames, on `SimClock.sim_frame`.** `sim_frame` keeps advancing in DEAD (only pause and Breakpoint freeze it, and DEAD is not pausable), so `death_frame` and the press frame share one clock. Fresh non-echo presses only; Esc, modifiers and F-keys are excluded as on the title. Restart happens on that press with no further delay, which is well inside the 2 s budget.
- **[design call] D-S29-4 Snapshot = fight-start set on FIGHT enter.** `RunState.fight_start_ring` is `Register.fight_start_for_boss(boss_index)` captured in `_set_flow_state` before `flow_state_changed`. Every route into FIGHT except a retry captures it (intro, harvest, debug jump). Reason: the ring is never shifted before the first FIGHT frame, so the fight-start set is exactly that snapshot; Epic 3 can later store a richer snapshot (boss state) in the same place.
- **[design call] D-S29-5 Full heal and reset on retry come from the existing FIGHT entry.** `Arena.enter_fight` already resets the player, the register, the action FSM (cooldowns, link) and clears the input buffer; 2.9 adds `health.reset_for_fight()` there. `_begin_fight` already reseeds `rng` from a new wall-clock seed on every FIGHT entry, including retry.
- **[design call] D-S29-6 Player hit feedback values.** Hit-stop 4 frames (GDD table; `HitFeedback.PLAYER_HITSTOP`). Shake 3 px for 4 frames on the arena camera (the GDD gives 3 px without a duration; 4 frames matches the hit-stop it accompanies, and shakes count physics frames like the combo shake, D-S28-5). Invulnerability 60 frames from `PlayerDef.invuln_frames`, which counts down on sim frames (frozen in hit-stop and pause, consistent with the sim). Blink: `@` hidden on alternate 4-frame blocks while invulnerable; the duck does not blink.
- **[design call] D-S29-7 Hits during hit-stop are frozen.** A hit that lands on the same tick as a dash's invulnerable frame is ignored; invulnerability and the blink freeze during hit-stop and pause, same as every other sim counter. No hit is queued while paused (`SimClock.tick` returns before polling).
- **[design call] D-S29-8 HP readout placement.** The top bar is the boss HP placeholder (`void fightPlaceholder() // hp ---`, Epic 3 fills it), so the player HP goes in the register panel's left column. Use the first row in cols 0–11, rows 2–21, not used by `RegisterPanel` (the panel's rows are `HEX_ROW` 3, `BYTE_ROW` 5, `LABEL_ROW` 6, previews 8–9 and 17–18, window 12–14; the implementer checks the cooldown rows in the panel's cell list before choosing). Default row 20 if free. Record the row in Completion Notes. The text is `hp: 0b…` at 1x, eleven characters, so it fits cols 0–11.
- **[design call] D-S29-9 Log line.** `WARN: hp--` exactly, appended by `LogPanel` from `player_damaged`. No damage number, no frame stamp (same rule as D-S28-4). A `Log.debug` line keeps the developer's stamp.
- **[design call] D-S29-10 DEAD screen content and visibility.** One line, `Process exited with code 1`, on the placeholder text grid; no prompt line, because the gate is silent and the retry is instant after 20 frames. The arena and register HUD are hidden in DEAD (`Main` shows them only in FIGHT, unchanged). The log panel keeps the last lines until the next FIGHT entry (the player sees what hit them); `Main` clears it only on FIGHT.
- **[design call] D-S29-11 Debug damage key is F6.** F1–F5, F9, F10, F11 and Shift+F2 are taken; F6 is free and FIGHT-only. Debug only, injected through `DebugKeys` (Main adds it only with `Debug.enabled`).
- **[design call] D-S29-12 The retry press must not fire an action.** The press that restarts the fight is also polled by `LiveInput` on the next physics tick, after `begin_fight` has cleared the buffer. `SimClock.swallow_presses_next_poll()` drops that one poll's presses. Verify in H3; if a legitimate press gets eaten in practice, narrow it to the press's own `action` only.
- **[design call] D-S29-13 Fight-start contents that do not exist yet.** Boss HP restore (no boss until Epic 3) and Echo memory clear (Epic 4) are hooks in `enter_fight` and in the `RunState` snapshot notes, not implementations. Do not invent placeholder values for them.
- **[design call] D-S29-14 Shift and debug jump do not reset deaths.** `deaths_on_boss` resets only on `start_boss` (a new boss index), so F3 from F2 in a debug session resets the count, while a retry keeps it. Matches I-5 and the 3rd-death hint (Epic 4).

### Existing code this story touches (verified at baseline 1d7ab68)

- `game/src/autoloads/game.gd`: `FlowState` with `DEAD` already in the enum; `advance()` warns in DEAD; `_set_flow_state` unpauses, calls `_begin_fight` for FIGHT, then emits `flow_state_changed`; `debug_jump`, `finish_intro` and `advance` set `run.boss_index`.
- `game/src/autoloads/event_bus.gd`: four signals today (`flow_state_changed`, `pause_toggled`, `register_shifted`, `hit_landed`); add `player_damaged` and `player_died`.
- `game/src/autoloads/sim_clock.gd`: `request_hitstop` (max per tick), `begin_fight(seed)` clears buffer and hit-stop, `tick()` gates pause, then Breakpoint, then hit-stop, then systems; `sim_frame` advances only when systems tick.
- `game/src/arena/arena.gd`: owns `player`, `register`, `actions`, `combat`; `enter_fight(fight_start, with_practice)`; `leave_fight()`; `_enter_tree`/`_exit_tree` register the four systems. Register order is the COMBAT ordering; `health` goes after `combat`.
- `game/src/main/main.gd`: `apply_flow_state` frees the old screen, clears juice, particles, camera shake and log, shows arena and HUD only in FIGHT, calls `enter_fight(Register.fight_start_for_boss(boss_index), wants_practice())`; `_make_screen` returns null for DEAD (2.9 adds `DeadScreen`).
- `game/src/player/player_def.gd` and `data/player/player_def.tres`: `max_hp = 5`, `invuln_frames = 60`, `hurtbox_tiles = 0.6` already exist and validate.
- `game/src/player/action_state_machine.gd`: `invulnerable()` (dash frames), `reset_for_fight()` (cooldowns, link, unlock), `set_active(false)` (finish, close link, unlock).
- `game/src/debug/debug_keys.gd`: `JUMPS` has F1–F5; `handle_key` handles F11, F9, F10, Shift+F2; F6 is free.
- `game/src/ui/hud/log_panel.gd`: connects `hit_landed` in `_enter_tree`; `line_for_damage` is the pure line builder.
- `game/src/presentation/camera_shake.gd`: `SHAKE_PX = 2`, `SHAKE_FRAMES = 6`, `offset_for(frames_left)`; `CameraShakeDriver` owns the arena camera.
- `game/src/ui/hud/hud.gd`: `TOP_BAR` is the boss placeholder (`hp ---`), not the player; `REGISTER := Rect2i(0, 2, 12, 20)`.
- `game/tests/unit/test_game_flow.gd` is the style reference (GUT, `autofree(GameScript.new())`, `Debug.enabled` saved and restored).

### Architecture guardrails (must follow)

- Only `SimClock` calls `tick`; all durations are `int` frames; no `Timer`, `await`, `create_tween` or `get_ticks_*` in sim code (`check_guards.sh`).
- Signals are declared only in `event_bus.gd`, past tense, typed args, no `Dictionary` payloads.
- Presentation never writes sim state. The only presentation-side call into the sim is `PlayerHealth.queue_hit()`, a request consumed by the sim on its next tick.
- Flow changes go through `Game` methods (`record_death`, `retry`, `debug_jump`). No screen writes `flow_state`.
- Simulation folders (`player/`, `combat/`, `arena/`) do not reference `ui/` or `presentation/`. `PlayerHealth` may reference `HitFeedback` (combat/) and `ActionStateMachine` (player/).
- Single writer for damage stays `DamageCalc`; player damage is 1 HP per hit, not a `DamageCalc` value (GDD D-011), so `PlayerHealth` is the single writer of `hp`.
- Simulation runs without a scene tree in tests: `PlayerHealth` takes its `PlayerDef` and `ActionStateMachine` by injection.

### Previous story intelligence (2.7 and 2.8, plus the deferred log)

- 2.8 added `HitFeedback` (pure hit-stop precedence, `hitstop_for`), `ParticlePool`, `CameraShakeDriver` (combo shake through `EventBus.hit_landed`), `LogPanel` (driven by `hit_landed`, pure `line_for_damage`), `ScreenFX`, `JuiceDirector` (sole writer of ScreenFX), and `PerfOverlay`. 2.9 reuses the same pattern: `PLAYER_HITSTOP` in `HitFeedback`, the shake schedule in `CameraShake`, the log line in `LogPanel`, the pure `hp_text` for the readout. The hit-stop guard (`request_hitstop` only in sim code) still holds.
- 2.7: `DebugKeys.practice_requested` survives until another jump key, so a retry keeps the practice target. Keep it: a retry must not clear it. Deferred (2.7): `PracticeTargetView._process` redraws every frame; leave it.
- 2.5: the FSM owns the movement lock; `set_active(false)` and `reset_for_fight` unlock. A death mid-dash therefore leaves the player unlocked on DEAD. Verified by `leave_fight` → `actions.set_active(false)`; add an assertion in E3.
- 2.3 deferred: hit-stop longer than 8 frames drops buffered input; player hit is 4, under the window. The InputBuffer grows while frozen (2.1 deferred), bounded by the 8-frame expiry once the sim runs again.
- 2.1 deferred: replays are same-binary only; a retry reseeds `rng`, so replays that span a retry depend on F11 starting at fight entry (known limitation, not changed).
- 1.7 deferred: "Held gameplay actions are not released on pause; handle with the player controller (Epic 2)." A key held through death must not carry into the new fight: `SimClock.begin_fight` clears the buffer, and the held-key check reads fresh press events only (AC 4). Verify in H3.
- 1.6 deferred: `PlaceholderScreen.is_advance` uses `keycode` only (web events can have `keycode 0`); `DeadScreen.is_retry_press` checks `physical_keycode` when `keycode == 0`.
- 1.6 deferred: old and new screen can share a node name within a frame; `DeadScreen` is named `DeadScreen` and nothing looks screens up by path.
- 2.4 deferred: presentation ignores `register_shifted` source and `SimClock.paused`; not changed here.

### Git intelligence (last commit 1d7ab68, 2.8)

- Files created or changed by 2.8: `hit_feedback.gd`, `particle_pool.gd`, `camera_shake.gd`, `camera_shake_driver.gd`, `screen_fx.gd(shader)`, `log_panel.gd`, `perf_overlay.gd`, `main.gd` (layer wiring), `arena.gd`, `practice_target_view.gd`, plus their GUT tests. Pattern: presentation nodes connected in `_enter_tree` and disconnected in `_exit_tree`, injected by `Main`, pure static helpers for testable strings and numbers.
- Main's `_build_layers` order is the AD-07 render order; 2.9 adds a `DeadScreen` through `_make_screen`, not a new layer.

### Latest technical information

- Godot 4.7.2 (pinned), GDScript, Compatibility renderer, web export. No new engine API is needed: `Camera2D.offset`, `Input` events (`InputEventKey.echo`, `physical_keycode`), `EventBus` signals and `Node` connect/disconnect are the same as in 2.8.
- No web research was run for this story: no library is added.

### Project Context Rules

- Godot project root is `game/`. New files: `game/src/player/player_health.gd`, `game/src/ui/screens/dead/dead_screen.gd`; tests `game/tests/unit/test_player_health.gd`, `game/tests/unit/test_dead_screen.gd`, `game/tests/integration/test_retry_snapshot.gd`.
- `project-context.md`: "Retry restores the fight-start `RunState`: register (temporary bits removed), full HP, Echo memory and link cleared, `rng` reseeded"; "Every fight start (after Harvest, on resume, on retry) restores full HP and resets all cooldowns. The DEAD screen accepts only a new press made ≥ 20 frames after death."
- GDD D-049 (c): the DEAD screen accepts only a **new** press made ≥ 20 frames after death; a held key cannot restart instantly.
- Palette: ink `#E8E8E8`, bg `#101014`; red only for warnings (none in 2.9).

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.9 H1] Debug build, FIGHT (Shift+F2 for the practice target, or F2): press F6 once. HP readout goes `hp: 0b11111` → `hp: 0b01111`; 4-frame hit-stop, a 3 px shake and `WARN: hp--` in the log; the `@` blinks for about 1 s. Note the feel and the row used for the readout (D-S29-6, D-S29-8).
- [ ] [2.9 H2] Press F6 five times with at least 60 frames between presses (the blink ends). The fifth hit shows the `Process exited with code 1` screen. Press a key 5 frames later: nothing happens. Press after about 20 frames: the fight restarts instantly, HP is full, the register is the fight-start set, and the practice target is still there when Shift+F2 started the fight (D-S29-3, D-S27-3).
- [ ] [2.9 H3] Retry press does not fire an attack or shift: hold J during death and release it, then retry with a press that is not J; no slash starts on the retried fight's first frame. Also a key held through the death does not restart the fight (D-S29-12, AC 4).
- [ ] [2.9 H4] Dash invulnerability: during a Dash (D, then J or K as Dash), press F6 on the dash's first 8 frames: no HP change and no `WARN` line; on frame 9 or later, it counts (AC 2).
- [ ] [2.9 H5] Timing in Chrome and Firefox (`?debug` iframe URL, deferred with the browser checks in `deferred-work.md`): death to restart is under 2 s measured by eye (NFR5).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.9] (ACs, FR2, FR49, NFR5)
- [Source: _bmad-output/planning-artifacts/epics.md#FR2, FR49, FR52, NFR5, AD-08, I-5] (player hurtbox, 5 HP, invulnerability, death and retry, flow states, snapshot)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Win/Loss Conditions, Hit feedback table, HUD Layout (D-047)] (Process exited screen, retry rule, player hit values, HP text)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-011, D-049] (5 HP, instant retry, full heal between fights, DEAD press rule)
- [Source: _bmad-output/game-architecture.md#AD-01, AD-05, AD-08; Flow state machine / retry; RunState snapshot] (sim/presentation split, FSM, snapshot on FIGHT enter)
- [Source: _bmad-output/project-context.md] (retry and DEAD rules, hit-stop rule, signal rules, guard rules)
- [Source: _bmad-output/implementation-artifacts/2-8-hit-feedback-hit-stop-particles-and-log-lines.md#Design calls] (D-S28-1, D-S28-4, D-S28-5, D-S28-12)
- [Source: _bmad-output/implementation-artifacts/2-7-combat-resolver-damage-calc-and-practice-target.md] (D-S27-3 practice request, D-S27-4 serial)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (1.6, 1.7, 2.1, 2.3, 2.4, 2.5, 2.7, 2.8 deferrals touching this story; itch.io and browser checks deferred)

## Dev Agent Record

### Agent Model Used

claude-opus-5-5 (gds-dev-story, unattended)

### Debug Log References

- First full GUT run looped on parse errors: the fresh worktree's class cache did not know the new `class_name`s (`HpReadout`, `DeadScreen`, `PlayerHealth`). A second `--headless --import` fixed it.
- `test_arena_player::test_main_resets_register_on_every_fight_entry` failed once: the new integration test mutated the autoload `Game.run` it had saved. The test now swaps in a fresh `RunState` and restores the saved one.
- Final: GUT 587/587 passing (54 scripts, 7913 asserts); `bash game/tools/check_guards.sh` OK.

### Completion Notes List

- Implemented every task, Groups A to F. `PlayerHealth` (COMBAT phase, registered after `combat`) is the single writer of `hp`, `invuln_left` and `dead`. Presentation only calls `queue_hit()` (F6) and `Game.retry()` (DeadScreen). `Game` raises the death from `player_damaged(0)`, owns `deaths_on_boss`, the 20-frame retry gate and the snapshot. `SimClock.swallow_presses_next_poll()` stops the retry press from firing an action.
- [design call] **HP readout placement changes D-S29-8.** `hp: 0b11111` is 11 characters, but the REGISTER box interior is only 10 columns (cols 1–10; cols 0 and 11 are the border). Row 20 would also collide with the GDD's cooldown rows (17–19 and below). The readout is a new `HpReadout` node (ui/hud, added by Main under the HUD). It sits on the top bar (row 0), right-aligned to cols 69–79, opposite the boss signature and HP bar, so it shows only in FIGHT like the HUD.
- [design call] **Snapshot capture uses an explicit `_retrying` flag, not `from != DEAD` (changes C3).** With the story's rule, a debug jump out of DEAD (for example F3 while dead on boss 0) would keep boss 0's snapshot. Now every FIGHT entry captures the snapshot except `Game.retry()`.
- [design call] `Main.fight_start_ring(run, boss_index)` returns `Game.run.fight_start_ring` when its boss matches. Otherwise it falls back to `Register.fight_start_for_boss`, which covers direct `apply_flow_state` calls in tests.
- [design call] F6 is ignored while `SimClock.paused` (D-S29-7: no hit is queued during pause) and with any modifier.
- [design call] Blink: the `@` is hidden on the first 4-frame block of invulnerability, so the hit reads at once, then on every other block. `invuln_left` counts down on sim frames, so it freezes in hit-stop and pause.
- [design call] The lethal hit's 3 px shake still plays for 4 frames over the DEAD text, because `camera_shake.reset()` runs on the DEAD transition before the driver hears `player_damaged`. This is harmless and reads as a death jolt. DEAD has no prompt line (D-S29-10).
- Followed as written: D-S29-1 to D-S29-7 and D-S29-9 to D-S29-14. Boss HP restore (Epic 3) and the Echo memory clear (Epic 4) are documented hooks in `Arena.enter_fight` and `RunState`, not implementations.
- Human checks H1 to H5 are still open for Tiziano. The HP readout now sits top-right on row 0 (H1).

### File List

- game/src/player/player_health.gd (new)
- game/src/ui/hud/hp_readout.gd (new)
- game/src/ui/screens/dead/dead_screen.gd (new)
- game/src/autoloads/event_bus.gd
- game/src/autoloads/game.gd
- game/src/autoloads/sim_clock.gd
- game/src/core/run_state.gd
- game/src/combat/hit_feedback.gd
- game/src/arena/arena.gd
- game/src/main/main.gd
- game/src/presentation/camera_shake.gd
- game/src/presentation/camera_shake_driver.gd
- game/src/presentation/player_view.gd
- game/src/ui/hud/log_panel.gd
- game/src/debug/debug_keys.gd
- game/tools/check_guards.sh
- game/tests/unit/test_player_health.gd (new)
- game/tests/unit/test_dead_screen.gd (new)
- game/tests/integration/test_retry_snapshot.gd (new)
- game/tests/unit/test_game_flow.gd
- game/tests/unit/test_log_panel.gd
- game/tests/unit/test_camera_shake.gd
- game/tests/unit/test_sim_clock.gd
- game/tests/unit/test_main_layers.gd
- game/tests/unit/test_debug_keys.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-11-09: Story created (gds-create-story, unattended). Status ready-for-dev.
- 2026-11-09: Implemented (gds-dev-story): PlayerHealth, death and retry flow, DEAD screen, HP readout, F6 debug damage, guards, tests (587/587). Status review.

### Review Findings

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel subagents). 3 patch, 7 defer, 8 dismissed.

- [x] [Review][Patch] `record_death` set `death_frame` after the DEAD transition, so `flow_state_changed` listeners saw -1 [game/src/autoloads/game.gd]
- [x] [Review][Patch] `SimClock.tick` used `presses.clear()` on the source's own array; now `presses = []` [game/src/autoloads/sim_clock.gd]
- [x] [Review][Patch] Retry while paused (focus lost on DEAD) left a stale swallow flag that ate the first real press; swallow only when not paused [game/src/autoloads/game.gd]
- [x] [Review][Defer] [design call] Log panel is hidden in DEAD (it lives under the HUD), so "see what hit you" is only in memory — deferred: judge in H-checks; show the log layer in DEAD if it reads badly
- [x] [Review][Defer] Death transition runs mid-tick inside the sim loop and the lethal hit's 4-frame hit-stop runs on DEAD — deferred, works via per-system `active` flags
- [x] [Review][Defer] Retry reseeds RNG from wall clock; seed is not in the snapshot — deferred, revisit with boss patterns (Epic 3)
- [x] [Review][Defer] Guard regex evadable (`hp :=`, `set(&"hp")`); tests read private state and restore autoload state by hand — deferred
- [x] [Review][Defer] HpReadout polls in `_process`; `cell_for` has no COLS clamp — deferred, cosmetic
- Dismissed: lethal-hit shake over DEAD (existing [design call], death jolt), retry mash/click gate (D-049 c by design), 20-frame gate starts after hit-stop (within NFR5), HP readout placement and snapshot rule (recorded design calls), F6 pause guard (D-S29-7), DEAD without `record_death` (debug cannot jump to DEAD), invuln order (tested at boundary).
