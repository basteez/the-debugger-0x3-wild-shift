---
baseline_commit: 7e2b1be
---

# Story 3.1: Reusable Boss Framework

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. This story is large and is deliberately NOT split (sprint-status note). Scope is ordered into task groups A-H; ship groups in order and stop at a green build after each group if time runs short. -->

## Story

As a player,
I want bosses that telegraph, attack, recover and change phase predictably,
so that I can read and punish them like a hunter.

**Requirements:** FR3 (contact), FR29 (jitter), FR30 (phases, pools, gap, tell/active/recovery, roar), FR31 (tell rules), FR32 (signature header); GDD "Boss Design" (shared rules, Audible tells D-049, Targeting D-049); AD-06 (`BossController` + one `BossAttack` script per attack, `ArenaContext`, enum + `match` FSM with int counters); NP-3 (bosses push `PlayerEffects`, never call `Player`/`Register`); AD-01 (sim frames only, `BOSS_HAZARDS` phase); AD-05 (presentation listens, never writes); Pillar 2 (visible and audible tells).
**Epic 3 window:** Nov 11–14 (MVP gate Nov 14). **Depends on:** 2.1 (`SimClock`, `SimContext.rng`, `begin_fight`), 2.2/2.5 (`Player.position_px`, `ActionStateMachine`), 2.7 (`DamageCalc`, `HitShape`/`HitCircle`), 2.8 (`EventBus`-driven presentation, `Hud`), 2.9 (`PlayerHealth.queue_hit`, `Arena.enter_fight` reset hooks, `DebugKeys`, `RunState`).
**Unblocks:** 3.2 (weak window, Patched, damage states on this FSM), 3.3 (Infinite Loop body and attacks), 3.8 (Harvest reads `boss_defeated`), and every later boss.

## Acceptance Criteria

1. **Given** the data resources `BossDef` (`name_signature`, `max_hp`, `phases`, `drop_bit`, `fixed_line`, plus `body_radius_tiles`, D-S31-12), `PhaseDef` (`hp_threshold`, `weak_window`, `gap_frames`, `attack_pool`) and `AttackDef` (`id`, `tell`, `active`, `recovery`, `exclusive`, `recovery_if_no_breakpoint`, `script`, plus `tell_sfx`, D-S31-7) **When** `validate()` runs on each def **Then** it returns no messages for a valid def, and reports every rule in D-S31-4 and D-S31-7 (phase thresholds, pool of at least two distinct attacks, tell ≥ 20 frames, non-empty `tell_sfx`, unique ids, script is a `BossAttack`).

2. **Given** a `BossController` running a test boss in a fight
   **When** it ticks
   **Then** it cycles GAP → TELL → ACTIVE → RECOVERY with the phase's `gap_frames` and the attack's `tell`, `active` and `recovery` frames (D-S31-5), calling `on_tell` at TELL entry, `on_active` on every ACTIVE tick and `on_recovery` at RECOVERY entry, each with an `ArenaContext`
   **And** the next attack is drawn with `SimContext.rng` from the current phase's pool and is never the same attack 3 times in a row (D-S31-6).

3. **Given** boss HP crosses a phase threshold
   **When** the phase changes
   **Then** a 60-frame ROAR state runs (boss glitch-roar event emitted, attacks stop, no attack starts), the speed-ramp hook `_on_phase_reset()` is called, and `EventBus.boss_phase_changed(phase)` is emitted (D-S31-8)
   **And** the glyph jitter level rises in steps at 66% and 33% HP (D-S31-9).

4. **Given** an attack starts its tell
   **When** the TELL state begins
   **Then** `EventBus.boss_tell_started(attack_id, tell_sfx)` is emitted and the tell cue plays on the SFX bus (placeholder blip until 7.2, D-S31-16).

5. **Given** `ArenaContext`
   **When** an attack needs an aim point
   **Then** it reads only `ctx.target_position()`, which returns the injected target source (default: the player's `position_px`; the Ghost Echo decoy plugs in at 6.1). A test injects a fixed target and confirms the attack aims there
   **And** every tell and spawn position the framework test boss declares lies inside the 32×18 play area (`Arena.play_area()`), checked by a test helper (no off-screen attacks).

6. **Given** the boss body hurtbox (a circle, D-S31-12)
   **When** the player overlaps it outside invulnerability
   **Then** the contact goes through `PlayerHealth.queue_hit()` and the player takes 1 HP through the existing hit pipeline (hit-stop, shake, log, `player_damaged`)
   **And** while the player is invulnerable (post-hit or dash) the contact does nothing.

7. **Given** a boss fight starts
   **When** the HUD top bar is drawn
   **Then** it shows `void <name_signature>() // hp <hp>` with live HP (`EventBus.boss_hp_changed`), replacing the `fightPlaceholder` text only while a boss is present (D-S31-14)
   **And** in debug builds (`Debug.enabled`, FIGHT with the test boss) **F6 kills the boss** (emits `boss_defeated`, no flow change until 3.8) and **Shift+F6 skips to the next phase**; the 2.9 player-hit debug key moves to Ctrl+F6 (D-S31-2).

8. **Given** a fight start or a retry
   **When** the fight begins
   **Then** the boss has full HP, phase 1, the GAP state, an empty pick history and no pending contact; its cached attack scripts persist (no allocation in `tick()`); `rng` is reseeded by the existing `begin_fight` path
   **And** the test boss exists only after an explicit debug request (Shift+F3), so release play and the replay tests are unchanged (D-S31-3).

9. **Given** the tests
   **When** `tests/unit/test_boss_controller.gd` runs headless
   **Then** it verifies state timings, the no-triple-repeat rule over 1000 seeded picks, phase thresholds (including a multi-phase jump in one tick), the roar length and hook, jitter steps, `validate()` rules, target injection, contact damage and the arena-bounds helper.
   **And** `test_data_validation.gd` covers the new defs, `test_hud_layout.gd` and `test_debug_keys.gd` are updated for D-S31-2 and D-S31-14, and the existing GUT suite and replays stay green.

10. **Given** the code is reviewed
    **Then** boss HP, phase and FSM state are written only by `BossController`; presentation (`BossView`, HUD header, AudioManager) reads them and listens to `EventBus`; no `Timer`, `await`, `create_tween`, `delta` or global RNG appears under `src/bosses/`; `game/tools/check_guards.sh` passes; every duration is an `int` frame count; balance numbers live in `.tres`.

## Scope Boundaries

- **In:** the three defs with `validate()`, the `BossController` FSM and its phase/roar/jitter/pick rules, `BossAttack` base, `ArenaContext`, a minimal `PlayerEffects` queue slot (no command types), the body contact, the test boss (data + two trivial attack scripts), arena and fight-start wiring, the HUD boss header, the debug keys (F6, Shift+F6, Shift+F3, Ctrl+F6), the EventBus signals, the tell cue, and the tests.
- **Out (later stories):** the real Infinite Loop body, phases and attacks (3.3–3.5), player-to-boss damage, weak window, Patched and damage states (3.2), `PlayerEffects` command types `RotateRegister`/`InsertTemporaryBit` (6.5/6.6), `exclusive` and `recovery_if_no_breakpoint` behaviour (6.5, 4.3), decoy targeting (6.1), boss-defeat flow and Harvest (3.8), the duck bubble (3.6), final SFX and music (7.1/7.2), boss HP in the save file (7.3).
- **Not a refactor:** Epic 2 behaviour (player, register, combat resolver, HP pipeline) is unchanged except the debug key move and the header text.

## Tasks / Subtasks

- [x] **Group A: Data defs and signals (AC: 1, 4, 7)**
  - [x] A1. `EventBus` (`src/autoloads/event_bus.gd`, the only place signals are declared): add `boss_hp_changed(hp: int, max_hp: int)`, `boss_phase_changed(phase: int)`, `boss_tell_started(attack_id: StringName, tell_sfx: StringName)`, `boss_defeated(boss: StringName)`, and `boss_roar_started(phase: int)`. `@warning_ignore("unused_signal")`, past tense, typed args, doc comments with the story number.
  - [x] A2. New `game/src/bosses/framework/boss_def.gd` (`class_name BossDef extends Def`), `phase_def.gd` (`PhaseDef extends Def`), `attack_def.gd` (`AttackDef extends Def`). Each `*_def.gd` implements `validate() -> PackedStringArray` per D-S31-4 and D-S31-7. Fields typed: `boss_id: StringName` (the `boss_defeated` id), `phases: Array[PhaseDef]`, `attack_pool: Array[AttackDef]`, `weak_window: Vector2i` (ordered bit pair, unused until 3.2), `script: Script`, `tell_sfx: StringName`, `drop_bit: int`, `body_radius_tiles: float`.
  - [x] A3. New `game/src/bosses/framework/boss_attack.gd` (`class_name BossAttack extends RefCounted`): virtual `on_tell(ctx: ArenaContext)`, `on_active(ctx: ArenaContext)`, `on_recovery(ctx: ArenaContext)`, all no-ops by default. Attacks hold no node and no state across fights unless they keep it in fields reset by `reset()`.
  - [x] A4. Extend `game/tests/unit/test_data_validation.gd` only through the glob (it already asserts every `.tres` under `res://data/` validates); add the new test boss data in group G.

- [x] **Group B: Arena context and effect slot (AC: 5, 10)**
  - [x] B1. New `game/src/bosses/framework/arena_context.gd` (`class_name ArenaContext extends RefCounted`): `target_source: Callable` (default set by Arena to `func() -> Vector2: return player.position_px`), `target_position() -> Vector2`, `player_effects: PlayerEffects`, and the static pure helper `inside_play_area(p: Vector2) -> bool` (uses `Arena.play_area()`). Attacks read the aim point only through `target_position()`; no `Player` reference is held.
  - [x] B2. New `game/src/bosses/framework/player_effects.gd` (`class_name PlayerEffects extends RefCounted`): `push(command)` and `apply_all()`, which drains the queue; in 3.1 the queue must stay empty (no command types yet). Its tick slot is `SimSystem.SimPhase.PLAYER_EFFECTS` (D-S31-11). Keep it minimal; NP-3 commands arrive with 6.5.

- [x] **Group C: BossController FSM (AC: 2, 3, 6, 8)**
  - [x] C1. New `game/src/bosses/framework/boss_controller.gd` (`class_name BossController extends SimSystem`), `phase = SimPhase.BOSS_HAZARDS`. Fields: `def: BossDef`, `body_center_px: Vector2`, `hp: int`, `phase_index: int`, `state: BossState` enum `{GAP, TELL, ACTIVE, RECOVERY, ROAR, DEFEATED}`, `frames_left: int`, `current: AttackDef`, `pick_history` (two ints of attack index, -1 = none), `active: bool`, cached `_attacks: Array[BossAttack]` built at `setup()`. No `_process`, no `Timer`, no `await`.
  - [x] C2. `tick(ctx)`: return unless `active`. Decrement `frames_left`; on reaching 0 transition per D-S31-5. GAP → TELL picks the next attack (C3) and emits `boss_tell_started`; TELL → ACTIVE; ACTIVE → RECOVERY; RECOVERY → GAP with the phase's `gap_frames`. Call hooks at the entries listed in AC 2. Then run contact (C5).
  - [x] C3. `pick_next(rng)`: uniform draw from `phase.attack_pool`; if the candidate equals the previous two picks, redraw from the pool minus that attack. Pure given the rng. Pick history persists across phases, cleared on `reset_for_fight()` (D-S31-6).
  - [x] C4. Phase handling: `phase_for_hp(hp, max_hp, phases) -> int` (pure, static). A phase starts when `hp * 100 <= hp_threshold * max_hp`; crossing several thresholds in one tick jumps to the latest phase with one roar. On a change: state ROAR for 60 frames, drop the current attack (its ACTIVE hooks stop; `on_recovery` is not called), call `_on_phase_reset()` (virtual no-op), emit `boss_roar_started` and `boss_phase_changed`.
  - [x] C5. Contact (AC 6): each sim tick while `active` and state is not DEFEATED, if the player's `position_px` lies within `body_radius_tiles` of `body_center_px` (circle test via `HitCircle` math, no physics body), call `health.queue_hit()`. `PlayerHealth` decides invulnerability. Contact stays live during ROAR (body contact is not an attack; D-S31-8).
  - [x] C6. Damage and death: `take_hit(damage: int)` (the 3.2 entry point; in 3.1 only tests and debug keys call it) lowers `hp` by `damage` clamped to 0, emits `boss_hp_changed` and runs the phase check. At hp 0: state DEFEATED, `active = false`, emit `boss_defeated(def.boss_id)` once. `debug_kill()` and `debug_skip_phase()` are thin wrappers used only by DebugKeys (AC 7).
  - [x] C7. `jitter_level() -> int` (pure): 0 above 66%, 1 at or below 66%, 2 at or below 33% (D-S31-9). Emitted by `boss_hp_changed` consumers, read by BossView.
  - [x] C8. `setup(p_def: BossDef, p_health: PlayerHealth, p_arena: ArenaContext)` builds the attack cache and validates the def (on failure: `assert` + `Log.error`, then the boss stays inactive, per project error rules). `reset_for_fight()` restores full HP, phase 0, GAP with `frames_left = first phase gap_frames`, empty history, `active = true`, no pending contact.

- [x] **Group D: Arena and flow wiring (AC: 5, 8)**
  - [x] D1. `game/src/arena/arena.gd`: add `var boss: BossController = null` and `var arena_context: ArenaContext`. Register the boss in `_enter_tree` as `SimClock.register_system(boss)` after `health` (COMBAT phase order is fine, BOSS_HAZARDS sorts earlier) and unregister in `_exit_tree`. Build `ArenaContext` in `_init` or field init with `target_source` bound to `player.position_px`.
  - [x] D2. `Arena.enter_fight(fight_start, with_practice := false, with_test_boss := false)`: when `with_test_boss` it instances the test boss (`BossController.setup` + `reset_for_fight`) and sets `boss.active = true`; otherwise `boss = null` and `arena.boss` is unregistered. `leave_fight()` deactivates it. Keep `enter_fight`'s existing signature working (default false).
  - [x] D3. `Main` (`src/main/main.gd`): pass the Shift+F3 flag through `apply_flow_state` the same way `practice_requested` flows today (`DebugKeys` sets it; `Main` reads it on FIGHT entry). A retry keeps the flag, as the practice target does.
  - [x] D4. Presentation attach: `BossView` (new `game/src/presentation/boss_view.gd`, a `Node2D` in the Entities layer, added by Main beside `PlayerView`). It draws the boss's `name_signature` as a glyph line at `body_center_px` via `GlyphFont.draw_cell`/`draw_string`-style helpers already used by Arena, offset by `jitter_level()` (presentation-only: offset = `jitter_level * sign(sin(sim_frame))` px). It reads state, never writes it.

- [x] **Group E: Presentation and HUD (AC: 3, 4, 7)**
  - [x] E1. `game/src/ui/hud/hud.gd`: keep `TOP_BAR` as the placeholder fallback; add a pure `static func boss_header(signature: String, hp: int) -> String` returning `void <signature>() // hp <hp>` and the HUD top bar uses it while a boss is registered (subscribe to `boss_hp_changed` and `boss_defeated`; the header shows `hp 0` after defeat). Update `tests/unit/test_hud_layout.gd` only where it pins the placeholder string.
  - [x] E2. `game/src/autoloads/audio_manager.gd`: on `EventBus.boss_tell_started` play the procedural `make_blip()` through `play_sfx` (placeholder, D-S31-16). Pooled SFX stays a 7.2 item. Presentation only; no sim reads.
  - [x] E3. Glitch-roar placeholder: `boss_roar_started` makes `BossView` flash the boss line for the ROAR (visual only, no sound asset). The sim does not wait on it.

- [x] **Group F: Debug keys (AC: 7, 8)**
  - [x] F1. `game/src/debug/debug_keys.gd`: F6 (no modifiers, FIGHT, not paused, boss present) calls `boss.debug_kill()`; Shift+F6 calls `boss.debug_skip_phase()`; Shift+F3 sets `test_boss_requested = true` and jumps to FIGHT boss 0 (like Shift+F2 for the practice target). Ctrl+F6 queues the player-hit debug hit that 2.9 put on F6 (`player_health.queue_hit()`). All debug only (`DebugKeys` is absent in release).
  - [x] F2. `tests/unit/test_debug_keys.gd`: update the 2.9 F6 block to Ctrl+F6 (AC8 2.9 wording stays true for the player hit); add cases for F6 kill, Shift+F6 phase skip, Shift+F3 flag, and that F6 does nothing without a boss.

- [x] **Group G: Test boss content and tests (AC: 1, 2, 5, 9)**
  - [x] G1. Test boss data under `game/data/bosses/test_boss/`: `boss_def.tres` (`name_signature = "testBoss"`, `max_hp = 20` for quick manual kills, `body_radius_tiles = 1.0`, two phases with `hp_threshold` 100 and 50 and `gap_frames` 40 and 30, `fixed_line` placeholder), `attack_pulse.tres` and `attack_sweep.tres` (`tell` 20 and 30, `active` 10 and 20, `recovery` 15, `tell_sfx = &"tell_test"`). Balance numbers in `.tres` only.
  - [x] G2. Attack scripts under `game/src/bosses/test_boss/attacks/`: `pulse.gd` and `sweep.gd` (`extends BossAttack`), which only aim at `ctx.target_position()` in `on_tell` and count their hook calls in fields. They deal no damage in 3.1; they exist to exercise the framework. Boss-specific code stays in its boss folder (architecture boundary 5).
  - [x] G3. `game/tests/unit/test_boss_controller.gd`: state timings for GAP/TELL/ACTIVE/RECOVERY with exact tick counts; hooks called at the right entries; no-triple-repeat over 1000 seeded picks from a seeded `SimContext`; `phase_for_hp` at 100/66/33/0 and a multi-phase jump; roar of exactly 60 ticks with attacks stopped and `_on_phase_reset` called; jitter levels at 67/66/34/33; `validate()` failures (tell 19, empty `tell_sfx`, pool of one, unordered thresholds, duplicate ids); target injection; `inside_play_area` for every declared position; contact 1 HP and no damage while invulnerable (use `PlayerHealth` with a fake `ActionStateMachine` or the real one, as 2.9 tests do); `boss_defeated` emitted once.
  - [x] G4. `game/tests/unit/test_data_validation.gd` keeps passing with the new `.tres` files (the glob covers them).

- [x] **Group H: Verification (AC: 9, 10)**
  - [x] H1. Run GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. All Epic 1–2 tests and replays stay green (replays fold `ctx.rng.randi()`, so the test boss must not run there: D-S31-3).
  - [x] H2. Run `bash game/tools/check_guards.sh` from the repo root and fix every violation in `src/bosses/`.
  - [x] H3. Update `_bmad-output/implementation-artifacts/sprint-status.yaml` only through the normal dev-story flow (`3-1` → `review` when done). Do not change epic status here.
  - [ ] H4. Human checks (Completion Notes, do not block `review`; pending Tiziano): see the list under Dev Notes.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S31-1 One story, ordered groups.** Not split (sprint-status note; splitting renumbers 3.2–3.9 across GDD, architecture and epics). Groups A–H are the order of work; A–C alone give a testable framework with no visible change.
- **[design call] D-S31-2 F6 is boss kill, the 2.9 player-hit key moves to Ctrl+F6.** The epics AC and the architecture's debug table give F6 to "kill boss" and Shift+F6 to "next phase". The 2.9 key (D-S29-11) becomes Ctrl+F6. Chosen over F7 because the architecture reserves F7 for invincibility. Verify Ctrl+F6 in the browser (H4). Ctrl is already excluded by the `DebugKeys` modifier checks.
- **[design call] D-S31-3 The test boss is opt-in (Shift+F3).** `BossController` draws from `SimContext.rng`, and `tests/replays/test_replays.gd` folds `ctx.rng.randi()` into its hash. A boss active in a default FIGHT would change every replay. Shift+F3 mirrors Shift+F2 (practice target, D-S27-3). Release builds never see DebugKeys, so the test boss never runs in release.
- **[design call] D-S31-4 Phase thresholds are integer percent.** `PhaseDef.hp_threshold: int` is the HP percent at which the phase starts (100, 66, 33 for Boss 1). Compare with integers (`hp * 100 <= hp_threshold * max_hp`) to avoid float drift at the boundary. `validate()` requires the first phase at 100, strictly decreasing thresholds, and at least one phase. A tick that crosses several thresholds enters the latest one with a single roar.
- **[design call] D-S31-5 Timing semantics.** A state entered with N frames lasts exactly N ticks and transitions on the tick its counter reaches 0. GAP uses the phase's `gap_frames`; TELL uses `AttackDef.tell`; ACTIVE uses `active`; RECOVERY uses `recovery`; ROAR is 60. Hooks: `on_tell` on TELL entry, `on_active` on every ACTIVE tick (attacks that move frame by frame need that), `on_recovery` on RECOVERY entry. Tests assert exact counts so the rule cannot drift.
- **[design call] D-S31-6 No-triple-repeat rule.** Draw uniformly from the pool with `SimContext.rng`; if the candidate matches the previous two picks, draw again from the pool minus that attack. This never loops and always succeeds with ≥ 2 distinct attacks, which is why `validate()` requires a pool of at least two. History spans phases and resets on `reset_for_fight()` only.
- **[design call] D-S31-7 AttackDef validation and the one added field.** The AC names `tell_sfx` without listing it on `AttackDef`; it is added (`StringName`, non-empty). Rules: `tell >= 20`, `active >= 1`, `recovery >= 0`, unique non-empty `id` within the boss, `script` is a `BossAttack` subclass. `exclusive` and `recovery_if_no_breakpoint` are stored but have no behaviour until 6.5 and 4.3.
- **[design call] D-S31-8 ROAR.** Attacks stop and no new attack starts for 60 ticks. Body contact stays live (contact is not an attack). The speed-ramp reset is the virtual `_on_phase_reset()` on `BossController`; the framework base does nothing, and the test boss counts calls so the hook is verified. The roar is not a weak window; the "no damage window" wording is satisfied because the boss is not hittable in 3.1 (see D-S31-13).
- **[design call] D-S31-9 Jitter levels.** `jitter_level()`: 0 above 66%, 1 at or below 66%, 2 at or below 33%. Presentation maps level to pixels (0, 1, 2) with an offset from `sin(sim_frame)` so it is deterministic and never touches the sim RNG.
- **[design call] D-S31-10 Targeting source.** `ArenaContext.target_source` is a `Callable` that defaults to the player position. Attacks and tests never read `Player` directly; the decoy in 6.1 replaces the callable.
- **[design call] D-S31-11 PlayerEffects is a slot, not a feature.** The NP-3 queue is added so the tick order (`BOSS_HAZARDS → PLAYER_EFFECTS → COMBAT`) exists. It has `push` and a drain with no command types. `RotateRegister` and `InsertTemporaryBit` arrive with 6.5/6.6. The `register_shifted` source parameter in the deferred log stays deferred for the same reason.
- **[design call] D-S31-12 Body hurtbox and contact.** One circle per boss: `body_center_px` (set by the boss's body node in later stories) and `BossDef.body_radius_tiles`. Circle math via `HitCircle` rules, no `Area2D` (ADR-02). Several body circles are a 3.3 concern, out of scope here.
- **[design call] D-S31-13 The boss is not hittable in 3.1.** Player-to-boss damage needs the weak window and Patched (3.2). In 3.1 boss HP moves only through `take_hit` (tests), `debug_kill` and `debug_skip_phase`. `CombatResolver` keeps its practice-target list. `DamageCalc.compute` is not called by the boss in 3.1, so the deferred "asserts when Epic 3 passes real multipliers" item remains open for 3.2.
- **[design call] D-S31-14 HUD header.** `void <name_signature>() // hp <hp>` while a boss is registered; the old `fightPlaceholder` line otherwise (practice target fights, debug jumps without the test boss). After defeat the header shows `hp 0` until the next FIGHT (Harvest, 3.8, decides what replaces it).
- **[design call] D-S31-15 Signal payloads.** `boss_phase_changed(phase: int)` matches the AC literally. The other new signals omit a boss id because only one boss is in a fight; `boss_defeated(boss: StringName)` keeps the id because Harvest (3.8) and the 3rd-death hint (4.x) map it to a boss index.
- **[design call] D-S31-16 Placeholder tell cue.** `AudioManager` plays `make_blip()` on `boss_tell_started`. No new audio asset is added here; 7.2 replaces it with the real per-boss tell cue. `tell_sfx` is recorded in the event so 7.2 can map ids to streams.
- **[design call] D-S31-17 Test boss content and scope.** `data/bosses/test_boss/` and `src/bosses/test_boss/` hold the only boss content in 3.1, labelled as the framework's test fixture. Infinite Loop data stays for 3.3. The test boss attacks deal no damage.
- **[design call] D-S31-18 No allocation in tick.** Attack scripts are instanced once in `setup()`; pick history is two ints; the contact test allocates nothing. Pools (`Arena`, `ParticlePool`) are untouched.
- **[design call] D-S31-19 Death is not a flow change.** `boss_defeated` is emitted and the boss goes DEFEATED; `Game` does not react until Harvest (3.8). The fight keeps running with the boss inactive. Debug F6 is the only trigger in 3.1.

### Existing code this story touches (verified at baseline 7e2b1be)

- `game/src/autoloads/event_bus.gd`: typed signals; add the new ones here only.
- `game/src/core/sim_system.gd`: `SimPhase { SHIFTS, ACTIONS, PLAYER, BOSS_HAZARDS, PLAYER_EFFECTS, COMBAT, TIMERS }`. `BOSS_HAZARDS` and `PLAYER_EFFECTS` already exist.
- `game/src/core/sim_context.gd`: `rng` (seeded by `reseed`), `move_dir`, `poll_frame`.
- `game/src/core/sim_clock.gd`: `register_system`/`unregister_system` (stable by phase), `begin_fight`, `request_hitstop`, `paused`.
- `game/src/core/def.gd`: base for `validate()`. Tests in `test_data_validation.gd` load every `.tres` under `res://data/`.
- `game/src/combat/shapes/hit_circle.gd`, `hit_shape.gd`: circle overlap math to reuse for contact.
- `game/src/player/player_health.gd`: `queue_hit()` is the single hit entry; `apply_hit()` checks `dead`, `invuln_left` and `ActionStateMachine.invulnerable()`.
- `game/src/player/player.gd`: `position_px`.
- `game/src/arena/arena.gd`: `_enter_tree`/`_exit_tree` system registration, `enter_fight(fight_start, with_practice)`, `leave_fight()`, `play_area()`, `PLAYER_DEF` preload.
- `game/src/main/main.gd`: layers, `DebugKeys` attach (debug only), `practice_requested` flow to `enter_fight`.
- `game/src/debug/debug_keys.gd`: F6 damage key (2.9), Shift+F2 practice (2.7), `JUMPS` map, `handle_key`.
- `game/src/ui/hud/hud.gd`: `TOP_BAR` constant (placeholder pinned by `tests/unit/test_hud_layout.gd`).
- `game/src/autoloads/audio_manager.gd`: `play_sfx(stream)`, `make_blip()`.
- `game/src/autoloads/game.gd`: `boss_id(index)`, `BOSS_IDS`, `LAST_BOSS_INDEX` (3.8 uses them); unchanged in 3.1.
- `game/src/core/run_state.gd`: `start_boss`, `deaths_on_boss`, `fight_start_ring`; unchanged in 3.1.
- `game/tools/check_guards.sh`: sim dirs include `bosses`; presentation dirs `presentation ui debug`.

### Architecture guardrails (must follow)

- AD-06: `BossController` (base) + `BossAttack` script per attack, timings in `AttackDef.tres`; enum + `match` FSM with int counters stored as fields; no node-per-state.
- NP-3: bosses push `PlayerEffects`; they never call `Player` or `Register` methods (`ArenaContext` gives no player reference).
- ADR-02 / AD-04: no `Area2D`/physics bodies for gameplay; contact is shape math.
- AD-01: only `SimClock` calls `tick()`; no `delta`, `Timer`, `await`, Tweens or `Engine.time_scale` in `src/bosses/`.
- Determinism: all boss randomness from `SimContext.rng`; `rng` is reseeded by `begin_fight`. Replays stay bit-identical only if the test boss is off (D-S31-3).
- Pillar 2: every attack's tell ≥ 20 frames plus a non-empty `tell_sfx`; no off-screen or untelegraphed damage; attacks aim only through `ctx.target_position()`.
- Single writers: boss HP and phase → `BossController`; damage numbers → `DamageCalc.compute()` (not used by the boss in 3.1, D-S31-13); HP and invulnerability → `PlayerHealth`.
- Event rules: signals only in `event_bus.gd`, past tense, typed args, no `Dictionary` payloads; presentation never writes sim state.
- Naming: `boss_def.gd`, `phase_def.gd`, `attack_def.gd`, `boss_attack.gd`, `boss_controller.gd`, `arena_context.gd`, `player_effects.gd`; frame fields `_frames`; `StringName` ids (`&"test_pulse"`).
- Error rules: `assert()` + `Log.error` for data errors (e.g. a def that fails `validate()` in `setup`), then a safe default (boss inactive); no `push_error` popups.
- Logging: `Log.debug` only on events (state entry, hit, phase change); never per tick.

### Previous story intelligence (2.7, 2.8, 2.9 and the deferred log)

- **Pure static helpers + thin node glue** is the pattern that made Epic 2 testable (`DamageCalc.compute`, `HitFeedback.hitstop_for`, `PlayerHealth.hp_text`, `Hud.box_rows`). Keep `phase_for_hp`, `jitter_level`, `boss_header` and `inside_play_area` pure and static; test them without a scene tree.
- **Story 2.9 hit path:** `PlayerHealth.queue_hit()` is the only entry from outside the sim; `apply_hit()` decides. Boss contact must call it, never write `hp` or `invuln_left` (the 2.9 guard regex checks presentation, and 3.1 keeps that).
- **Story 2.9 retry:** `Arena.enter_fight` is the single place that resets player, register, FSM, health and practice target. The boss reset goes there too (AC 8). Do not add a second reset path.
- **Story 2.9 D-S29-13** says boss HP restore is a hook in `enter_fight`; this story implements it for the test boss only.
- **Story 2.7 D-S27-3:** `DebugKeys.practice_requested` survives until another jump key; Shift+F3's test-boss flag follows the same lifetime. Deferred item: it persists into later FIGHT entries in debug builds. Keep the same behaviour and record it.
- **Story 2.7 deferred:** `CombatResolver` hard-codes `&"practice_target"` in `hit_landed`; a boss hit goes through `take_hit` in 3.1 (no `hit_landed`), so this stays deferred to 3.2.
- **Story 2.8 deferred:** `JuiceDirector` effects run from `_process`; the boss's visible roar is presentation-only and must not depend on the sim frame being skipped.
- **Story 2.8 deferred:** `Hud` `ARENA` rect is cols 16–79; the boss header sits in the existing top bar. The header string must fit 80 columns (it does).
- **Deferred from 2.1 and 2.9:** the replay RNG state is not stored in the fight-start snapshot, and retry reseeds from the wall clock. Boss patterns are therefore not replay-stable across retries in debug builds. Accept for 3.1, note for the 3.9 playtest tooling.
- **Deferred from 2.3:** `register_shifted` source is hard-coded `&"player"`. Stays deferred (D-S31-11).
- **Deferred from 2.4 and 2.8:** click and inversion ignore the source and `SimClock.paused`; gate on `&"player"` when boss shifts arrive (not in 3.1).

### Git intelligence (last commits 7e2b1be, d3b2519, f2f09dc)

- `7e2b1be` Fix: opaque background for the F9 frame overlay (#19); `d3b2519` FIGHT placeholder no longer advances on any key (#18). Recent fixes touch `debug/`, `ui/` and `main/`; expect HUD and DebugKeys tests to be the regression surface.
- `f2f09dc` Story 2.9 added `PlayerHealth`, the DEAD flow and `DebugKeys` F6. Its test file `tests/unit/test_debug_keys.gd` contains the F6 block that D-S31-2 moves.
- Epic 2 used one story file per story and a PR per story (PR-only workflow; main protected).

### Latest technical information

- Godot 4.7.2-stable is pinned for the jam; GDScript only; typed `Resource` exports, `Array[T]` typed arrays and `Callable` are all standard in 4.7. No new library or version is introduced, so no external research was needed for this story.
- GUT 9.6.1 is the test framework (headless CLI as above). Context7 `/godotengine/godot-docs/__branch__4.7` is the reference if an API doubt comes up (project-context rule).

### Project Context Rules

- Only `SimClock` calls `tick()`; no `_process`, `_physics_process`, `delta`, `Timer`, `await` or Tweens in sim code (`src/bosses/`). Presentation (`BossView`, HUD header, AudioManager) may use `_process` and Tweens if needed, never for sim state.
- Signals only in `src/autoloads/event_bus.gd`; past tense; typed args.
- Data: `*Def` typed resources in `data/**/*.tres`, read-only at runtime; balance numbers in `.tres`; invariants in `Const`.
- Boss-specific code stays in `src/bosses/<boss>/`; shared framework code in `src/bosses/framework/` (promoted when ≥ 2 bosses use it, so keep the test boss code in its own folder).
- Test layout: `tests/unit/test_boss_controller.gd`; `test_data_validation.gd` loads every `res://data/` `.tres`.
- Debug tools only when `Debug.enabled` (F-keys, `DebugKeys`); release export excludes `tests/`, `tools/`, GUT.
- Static typing everywhere (`untyped_declaration` is an error). `StringName` ids (`&"test_pulse"`).
- Godot 3 syntax is wrong: `@export`/`@onready`, `signal.connect(callable)`, `await` (not `yield`).

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- **H1 (Chrome, Firefox):** `?debug`, Shift+F3, the test boss shows `void testBoss() // hp 20`; the header drops with HP; the tell cue blip plays at each tell; the roar flashes; contact costs 1 HP with invulnerability blink.
- **H2:** F6 kills the boss and the header reads `hp 0`; Shift+F6 skips to phase 2 (one roar); Ctrl+F6 queues a player hit (D-S31-2); none of these work in release (no `?debug`).
- **H3:** the browser does not eat Ctrl+F6 (Firefox and Chrome). If it does, pick another key and record it.
- **H4:** a release build (no `?debug`) shows no boss header and no test boss; Shift+F3 does nothing.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1: Reusable Boss Framework]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements, Simulation core and Presentation (AD-06, NP-3, Determinism, Debug tools, Testing)]
- [Source: _bmad-output/planning-artifacts/epics.md#FR Coverage Map, FR3, FR29–FR32]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss Design (shared rules, Boss 1 table, Audible tells D-049, Targeting D-049)]
- [Source: _bmad-output/game-architecture.md#Boss Framework (AD-06), #NP-3, #Project Structure (src/bosses/framework), #Consistency Rules]
- [Source: _bmad-output/project-context.md#Critical Implementation Rules, #Testing Rules]
- [Source: _bmad-output/implementation-artifacts/2-9-player-damage-death-and-instant-retry.md#Dev Notes (D-S29-1, D-S29-11, D-S29-13)]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-2-3, story-2-7, story-2-8, story-2-9]
- [Source: _bmad-output/implementation-readiness-report-2026-11-06.md (large stories 2.1, 2.6, 3.1 not split)]

## Dev Agent Record

### Agent Model Used

claude opus (Claude Opus 5.5, `claude-opus-5-5`), unattended epic pipeline

### Debug Log References

- Baseline GUT at 7e2b1be: 590/590 passing.
- First full run after groups A-G: 588/590; the two failures were the expected 2.9 F6 cases in `test_debug_keys.gd` (Shift+F3 now maps, F6 no longer queues the player hit). Updated per F2.
- `test_setup_rejects_an_invalid_def` first failed on GUT's "Unexpected Errors" (the `Log.error` push_error); fixed with `assert_push_error`, the pattern `test_register.gd` uses.
- Final: GUT 634/634 passing (56 scripts, 11165 asserts, includes `tests/replays/test_replays.gd` and `tests/integration/test_retry_snapshot.gd`), no SCRIPT ERROR / Parse Error in import or run; `bash game/tools/check_guards.sh` -> `check_guards: OK`.
- Commands: `godot --headless --path game --import`, then `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`, then `bash game/tools/check_guards.sh` (local binary `/Applications/Godot.app/Contents/MacOS/Godot`, 4.7.2.stable).

### Completion Notes List

- **Group A:** five new `EventBus` signals (`boss_hp_changed`, `boss_phase_changed`, `boss_tell_started`, `boss_roar_started`, `boss_defeated`). `BossDef`, `PhaseDef`, `AttackDef` (all `extends Def`) with `validate()` covering D-S31-4 and D-S31-7, plus `BossAttack` (hooks, `reset()`, `declared_positions()`).
- **Group B:** `ArenaContext` (`target_source`, `player_source`, `player_effects`, static `inside_play_area`) and `PlayerEffects` (a `SimSystem` in `PLAYER_EFFECTS` with `push` / `apply_all` / `clear`; it stays empty in 3.1).
- **Group C:** `BossController` (`BOSS_HAZARDS`): enum + `match` FSM with int counters, timing per D-S31-5, the no-triple-repeat pick per D-S31-6 (precomputed per-phase index pools, two-int history), `phase_for_hp` with integer math and a single roar on a multi-phase jump, a 60-tick ROAR that drops the attack without `on_recovery`, the `_on_phase_reset()` hook, `jitter_for_hp`, body contact through `PlayerHealth.queue_hit()` (live during ROAR, off when DEFEATED), `take_hit`, a single `boss_defeated` emit, and the `debug_kill` / `debug_skip_phase` wrappers. Attack scripts are instanced once in `setup()`. `tick()` allocates nothing.
- **Group D:** `Arena` owns `arena_context` (aim and contact default to `player.position_px`), registers `PlayerEffects` all the time and the boss only while one exists. `enter_fight(..., with_test_boss)` builds the controller once, keeps it across retries, resets it every fight. `leave_fight` deactivates it. `Main.wants_test_boss()` mirrors `wants_practice()`, and `_attach_boss()` passes the boss to `BossView` and the HUD.
- **Group E:** `Hud.boss_header()`, `Hud.top_bar_text()`, `Hud.set_boss()`. `HudFrame` draws `top_bar_text()` and redraws on `boss_hp_changed` / `boss_defeated`. `AudioManager` plays a cached `make_blip()` on every `boss_tell_started`. `BossView` draws the signature line with the jitter offset, a `!` during TELL, and an inverted flash during ROAR.
- **Group F:** F6 kills the boss, Shift+F6 skips to the next phase, Ctrl+F6 queues the player hit (moved from F6), and Shift+F3 sets `test_boss_requested` and jumps to FIGHT 0. Any other jump clears the flag, and a retry keeps it (same lifetime as `practice_requested`, so it still carries into later FIGHT entries in debug builds, as noted for 2.7).
- **Group G:** `data/bosses/test_boss/` (`boss_def.tres`, `attack_pulse.tres`, `attack_sweep.tres`, with the values from G1) and `src/bosses/test_boss/attacks/` (`pulse.gd`, `sweep.gd`: they aim through `ctx.target_position()`, count their hooks and deal no damage). `tests/unit/test_boss_controller.gd` has 37 tests covering every item in G3. `test_debug_keys.gd` has 6 new tests and updates the 2.9 F6 block to Ctrl+F6. `test_hud_layout.gd` gets the header test (the placeholder pin is unchanged), and `test_font_coverage.gd` adds the header, the signature and the `!`. `test_data_validation.gd` is unchanged; its glob picks up the three new `.tres` files.
- **Group H:** GUT, replays and guards are green (see Debug Log). sprint-status `3-1` is set to `review`.
- **Setup error path:** `BossController.setup` uses `Log.error` and returns false with the boss inactive. It does not call `assert()`, because a failing `assert` stops debug runs and the tests exercise this path on purpose. A def that fails `validate()` is still caught at authoring time by `test_data_validation.gd`.
- **Deferred items still open (unchanged by 3.1):** `CombatResolver` hard-codes `&"practice_target"` (3.2). The `DamageCalc` real-multiplier assert is not exercised (3.2). The `register_shifted` source is still hard-coded (6.5). Boss patterns are not replay-stable across debug retries, because retry reseeds from the wall clock (3.9 tooling).

**New design calls made during implementation (unattended):**

- **[design call] D-S31-20 `AttackDef.attack_script`, not `script`.** `script` is the built-in `Object` property and cannot be redeclared on a `Resource`, so the field is named `attack_script`. `validate()` walks `get_base_script()` to confirm the script is a `BossAttack`.
- **[design call] D-S31-21 Two sources on `ArenaContext`.** `target_source` is the aim point and is the one the decoy replaces in 6.1. `player_source` is the real player position, used only for body contact, so a decoy never moves the contact check. Both are `Callable`s; no `Player` reference is held (NP-3).
- **[design call] D-S31-22 `PlayerEffects` is a `SimSystem` that the Arena always registers.** It sits in `PLAYER_EFFECTS` and has a no-op drain with no RNG, so replays and fights without a boss are unchanged.
- **[design call] D-S31-23 `BossView` is a child of the Arena, next to `PlayerView`, not of the `Entities` layer node.** This keeps it in arena-local coordinates like `PlayerView`, and `LAYER_ORDER` is untouched.
- **[design call] D-S31-24 `BossAttack.declared_positions(ctx)`.** This virtual lists every tell and spawn point, so the arena-bounds test (AC 5) checks the real attack code for in-area, edge and far off-screen targets. The test attacks clamp their aim into the play area.
- **[design call] D-S31-25 Test boss body at `Arena.TEST_BOSS_PX`.** It is 5 tiles above spawn, set by the Arena, because no body node exists before 3.3. Contact is a point-in-circle test on the player centre within `body_radius_tiles` (C5 wording); the player hurtbox radius is not added.
- **[design call] D-S31-26 `recovery = 0`.** `on_recovery` is still called at the end of ACTIVE and the boss goes straight to GAP, so every completed attack gets exactly one `on_recovery`.
- **[design call] D-S31-27 Visible tell placeholder.** `BossView` draws `!` over the boss during TELL (Pillar 2 visible tell). The ROAR flash reads `state` / `frames_left` (FLASH_BLOCK 6) instead of a timer, so it is deterministic and presentation-only.

**Human checks (for Tiziano, do not block review):** H1-H4 from Dev Notes are not run (no browser in the unattended pipeline). Ctrl+F6 in Firefox and Chrome (H3) is the item most likely to need a key change.

### File List

- `_bmad-output/implementation-artifacts/3-1-reusable-boss-framework.md` (modified: tasks, Dev Agent Record, status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified: 3-1 -> review)
- `game/src/autoloads/event_bus.gd` (modified)
- `game/src/autoloads/audio_manager.gd` (modified)
- `game/src/arena/arena.gd` (modified)
- `game/src/main/main.gd` (modified)
- `game/src/debug/debug_keys.gd` (modified)
- `game/src/ui/hud/hud.gd` (modified)
- `game/src/ui/hud/hud_frame.gd` (modified)
- `game/src/bosses/framework/boss_def.gd` (+ `.uid`) (new)
- `game/src/bosses/framework/phase_def.gd` (+ `.uid`) (new)
- `game/src/bosses/framework/attack_def.gd` (+ `.uid`) (new)
- `game/src/bosses/framework/boss_attack.gd` (+ `.uid`) (new)
- `game/src/bosses/framework/boss_controller.gd` (+ `.uid`) (new)
- `game/src/bosses/framework/arena_context.gd` (+ `.uid`) (new)
- `game/src/bosses/framework/player_effects.gd` (+ `.uid`) (new)
- `game/src/bosses/test_boss/attacks/pulse.gd` (+ `.uid`) (new)
- `game/src/bosses/test_boss/attacks/sweep.gd` (+ `.uid`) (new)
- `game/src/presentation/boss_view.gd` (+ `.uid`) (new)
- `game/data/bosses/test_boss/boss_def.tres` (new)
- `game/data/bosses/test_boss/attack_pulse.tres` (new)
- `game/data/bosses/test_boss/attack_sweep.tres` (new)
- `game/tests/unit/test_boss_controller.gd` (+ `.uid`) (new)
- `game/tests/unit/test_debug_keys.gd` (modified)
- `game/tests/unit/test_hud_layout.gd` (modified)
- `game/tests/unit/test_font_coverage.gd` (modified)

### Change Log

- 2026-11-09: Story 3.1 implemented (groups A-H): boss framework (defs, FSM, ArenaContext, PlayerEffects slot), test boss, arena/Main wiring, HUD header, tell cue, boss debug keys (F6, Shift+F6, Shift+F3; player hit moved to Ctrl+F6), tests. GUT 634/634, check_guards OK. Status -> review.

### Review Findings

Code review (2026-11-09): Blind Hunter, Edge Case Hunter, Acceptance Auditor ran in parallel. 0 decision_needed, 4 patch (fixed), 9 defer, rest dismissed as noise or documented design calls.

- [x] [Review][Patch] Attack cut by a phase change or defeat got no cleanup hook; added `BossAttack.on_cancel`, called from `_change_phase` and `_defeat` [boss_controller.gd, boss_attack.gd]
- [x] [Review][Patch] `debug_skip_phase` could kill the boss (floor threshold 0) and returned true without a change; target clamped to 1 HP, returns whether the phase changed [boss_controller.gd]
- [x] [Review][Patch] `Log.debug` string formatting allocated per state change in release; guarded by `Debug.enabled` [boss_controller.gd]
- [x] [Review][Patch] Tell blip was built lazily inside the sim tick (web hitch); built in `_ready` [audio_manager.gd]
- [x] [Review][Defer] take_hit ignores `active` / pre-reset state [boss_controller.gd] — deferred, latent until 3.2
- [x] [Review][Defer] Contact radius vs drawn body size [boss_controller.gd] — deferred, revisit with Boss 1 art
- [x] [Review][Defer] AC5 off-screen guarantee is per-attack clamping [pulse.gd, sweep.gd] — deferred
- [x] [Review][Defer] F6/Shift+F6/Shift+F3 browser interception — deferred to human checks
- [x] [Review][Defer] `ArenaContext.player_position()` bypass by convention (D-S31-21) — deferred
- [x] [Review][Defer] Test boss load failure silent, ships in release behind `Debug.enabled` — deferred
- [x] [Review][Defer] PlayerEffects silent drop, validate gaps — deferred
- [x] [Review][Defer] Missing tests for several FSM and presentation paths — deferred
- [x] [Review][Defer] Subtle jitter, `_attach_boss` guards — deferred

Dismissed: epic-3 `in-progress` in sprint-status (normal on first story start), `AttackDef.script` rename, BossView parent, no `assert` in setup (all recorded design calls), unverifiable "missing" items that exist (`Arena.clamp_to_play_area`, `$Frame`), cyclic class_name concern.
