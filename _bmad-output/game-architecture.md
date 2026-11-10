---
title: 'Game Architecture'
project: 'github-gameoff-2026'
date: '2026-11-06'
author: 'Tiziano'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Godot 4.7.2'
platform: 'Web (HTML5)'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md'
epics: '_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md'
brief: '_bmad-output/planning-artifacts/briefs/brief-github-gameoff-2026-2026-11-06/brief.md'
---

# Game Architecture

## Executive Summary

**The Debugger 0x03: Wild Shift** architecture is designed for Godot 4.7.2 (GDScript, Compatibility renderer) targeting the web (HTML5, non-threaded export) on itch.io.

**Key Architectural Decisions:**

- A custom `SimClock` runs all gameplay as a deterministic 60 Hz frame tick, gated by pause > Breakpoint > hit-stop, with the register live during Breakpoint (AD-01, NP-2).
- Actions, combos and boss attacks are frame-based state machines driven by typed `.tres` data; J/K resolution goes through one pure `ActionResolver` (AD-02, AD-03, NP-1).
- Hit detection is custom shape math in a single `CombatResolver`, which also applies Patched before damage (AD-04, NP-4).
- Simulation talks to presentation one way through a typed `EventBus`; juice, HUD, audio and the mumble-speech duck voice never write game state (AD-05, AD-14).
- Cut-ladder features are isolated modules behind `FeatureFlags` (AD-12).

**Project Structure:** hybrid, domain-first organization (`game/src/<domain>`, `game/data/<domain>`) with 18 core systems.

**Implementation Patterns:** 5 novel + 4 standard patterns and 14 consistency rules ensuring AI agent consistency.

**Ready for:** Epic implementation phase

---

## Project Context

### Game Overview

**The Debugger 0x03: Wild Shift** - a top-down action boss rush for GitHub Game Off 2026 (theme SHIFT). A developer fights three software-bug bosses (Infinite Loop, Null Pointer, Segfault) in one arena, using a ring-shaped bit register rotated in real time (`<<` / `>>`); the two leftmost bits are the two action buttons, and ordered pairs fire combos.

### Technical Scope

**Platform:** Web (HTML5, desktop browsers) via itch.io embed; Chrome/Firefox full support, Safari playable; no mobile
**Engine (pre-decided in brief/GDD):** Godot 4, GDScript, Compatibility renderer (WebGL2), single-threaded web export, Sample audio mode
**Genre:** Top-Down Action Boss Rush (fighting-game frame-data conventions, no platforming)
**Project Level:** Medium — small content scope (1 arena, 3 bosses), high precision/feel requirements
**Team:** solo director; 100% AI-written code; ~3.5 weeks (submission target 2026-11-29 12:00 PST)

### Core Systems

| System | Complexity | GDD Reference |
|---|---|---|
| Fixed-step 60 FPS simulation, frame-based timers | Medium | Game Mechanics (all timings in frames) |
| Input: 8-frame buffer, link window, buffering during hit-stop | Medium | Controls and Input; Combos |
| Bit register ring (owned bits, rotation, previews, insertion, byte value) | Medium | The Register |
| Action system: S/A/R frame data, invulnerability, cooldowns, cancels, 3-hit chain | High | Bits; Combos; Movement and Combat Feel |
| Data-driven ordered combo engine (+ no-combo pairs, Echo, Clean Catch) | High | Combos; Weak Window and Patched |
| Damage pipeline (Unpatched ×0.5 / Patched ×1.5 / Clean Catch ×1.5, round half up once) | Medium | Weak Window and Patched |
| Boss framework (HP, phases, attack pools, tell/active/recovery, gap, phase roar) | High | Boss Design — Shared rules |
| Boss-specific behaviours (ring segments + travelling `;`, invisibility/decoys, corrupted tiles, register-shifting SIGSEGV) | High | Boss 1–3 |
| Time control (hit-stop, Breakpoint freeze with shifting allowed, pause, focus-loss auto-pause) | High | Skills; Hit Feedback |
| Hit feedback / juice (hit-stop precedence, glyph particles ≤ 300, shake, inversion, dither) | Medium | Hit Feedback |
| Glyph rendering (monospace pixel font, 16-px grid, 1-bit palette + red accent, inversion/dither) | Medium | Art Style |
| IDE HUD (register panel + previews, log panel, boss signature, Patched tag/bar, cooldowns) | Medium | Art Style — HUD |
| Watch reveal layer (hidden entities, weak window, next attack) | Low | Skills |
| Duck hint system (10 lines, template, triggers) | Low | Duck |
| Scene flow (Title → Intro → Fight ×3 / Harvest → Ending; ≤ 2 s retry) | Low | Level Types; Win/Loss |
| Audio (Sample mode, pre-rendered variants, crossfades, positional hum, press-to-start unlock) | Medium | Audio and Music |
| Persistence (highest boss reached; silent fallback) | Low | Storage |
| Practice target / debug tooling (damage log, frame counter, debug scene keys) | Low | Practice Target; story 1.6 |

### Technical Requirements

- **Frame rate:** 60 FPS sustained in Chrome/Firefox on a 2020 mid-range laptop (integrated GPU) at 1280×720, measured at Segfault phase 3
- **Resolution:** 640×360 base, integer (pixel-perfect) scaling; fullscreen from an input event
- **Particles:** ≤ 300 live glyph particles
- **Load:** title interactive ≤ 10 s on 50 Mbps cold cache; web build ≤ 32 MB uncompressed (raised from 30 MB on 2026-11-10, see deferred-work.md)
- **Input latency:** no added frames; shift feedback on the input frame; 0-frame shift
- **Determinism:** all gameplay timings are expressed in 60 Hz simulation frames
- **Audio:** Sample playback mode (no live effects); no audio before first user gesture
- **Storage:** browser storage, silent fallback when blocked (iframe/private mode)
- **Networking:** none (single-player, offline)

### Complexity Drivers

**High complexity:**
- Frame-exact action/combo timing (S/A/R, 18-frame link, 8-frame buffer, invulnerability windows) must be deterministic and testable
- Time-control layering: hit-stop, Breakpoint (simulation frozen, register shifting allowed), pause — all must compose without desyncing timers
- Boss framework that is reusable yet supports very different bodies (segmented spinning ring, invisible ghost + decoys, large dragon + tile hazards)

**Novel concepts (need custom patterns):**
- Ordered combos derived from a rotating register (combos as data keyed by ordered window)
- Breakpoint: frozen simulation with live register manipulation
- Boss attacks mutating player state (SIGSEGV rotates the register; Reserved Write inserts a garbage bit)
- Echo: re-executing the last solo action at 70% from the current position

### Technical Risks

- **Web export pitfalls:** Safari WebGL2 quirks, build size on itch.io (no on-the-fly compression), storage failing in iframes, background-tab throttling
- **Feel is tuned, not generated:** AI-written code tends to reach "functional"; tunables must be data-driven and hot-editable for fast iteration before the Nov 14 playtest
- **AI-agent consistency:** 100% AI-written code across 7 sequential epics requires strict conventions (frame-based timing, signal/event naming, data resource formats)
- **Schedule:** ~3.5 weeks solo; architecture must support the cut ladder (Reserved Write, Watch, Breakpoint, Segfault removable without ripple)
- **Audio latency/variants:** Sample mode forbids live effects; crossfade between pre-rendered tracks must stay in sync

## Engine & Framework

### Selected Engine

**Godot Engine** v4.7.2-stable (pinned for the whole jam; GDScript only)

**Rationale:** Pre-decided in brief and GDD and confirmed: first-class 2D, free, small web export, GDScript-only web support aligns with the stack, proven at Game Off (6/10 top 2025 entries in Godot). Compatibility renderer (WebGL2) and single-threaded export avoid SharedArrayBuffer/COOP/COEP on itch.io. Version pinned to avoid mid-jam engine/export-template drift.

### Project Initialization

No starter template. Create an empty Godot 4.7.2 project and configure:

- Renderer: Compatibility
- Display: viewport 640×360, stretch mode `viewport`, aspect `keep`, scale mode `integer`
- Physics ticks per second: 60; `physics/common/max_physics_steps_per_frame` default
- Default texture filter: Nearest
- Web export preset: single-threaded (Thread Support off), Extensions Support on (non-threaded dlink template, required by the mumble-speech GDExtension — see AD-14), VRAM compression for desktop only
- Audio: web playback mode `Sample`

Rationale for no template: the UI is a glyph-based IDE HUD that no menu template matches; scene flow is linear and short; owning all code keeps AI-agent conventions uniform.

### Engine-Provided Architecture

| Component | Solution | Notes |
|---|---|---|
| Rendering | Compatibility renderer (WebGL2), CanvasItem 2D | Glyphs via a bitmap/pixel font; Nearest filtering; integer scaling |
| Physics / collision | Godot 2D physics: `Area2D` + shapes for hit/hurtboxes | Used for overlap detection only; movement is kinematic (`CharacterBody2D` or manual) |
| Audio | `AudioStreamPlayer` / `AudioStreamPlayer2D`, bus layout | Sample playback mode on web: no live effects |
| Input | `InputMap` actions; keyboard + gamepad | Custom buffer layer on top (8 frames) |
| Scene management | `PackedScene` + `SceneTree.change_scene_to_*` / autoload-managed swap | Linear flow |
| Build system | Godot export presets (Web) | Stripped custom export template only if > 32 MB |
| Persistence | `FileAccess` on `user://` (IndexedDB on web) | Silent fallback on failure |
| Debug tooling | Remote debugger, Monitors, `print` | Plus in-game debug keys |

### Remaining Architectural Decisions

1. Simulation timing model (fixed 60 Hz tick, frame counters, hit-stop / Breakpoint / pause layering)
2. Game-state and entity architecture (autoloads, node composition, state machines)
3. Data model for tunables (bits, combos, actions, boss attacks as `Resource`s)
4. Input buffering and combo resolution
5. Hit/hurtbox and damage pipeline
6. Boss framework and attack scripting
7. Event/communication pattern (signals, event bus)
8. Rendering of glyphs, particles and screen effects (inversion, dither)
9. Audio architecture (buses, crossfades, positional hum)
10. Scene flow, retry and persistence
11. Testing approach (unit tests for frame logic; e.g. GUT/gdUnit4)
12. Cut-ladder modularity (features removable without ripple)

### AI Tooling (MCP)

| MCP | Repo | Purpose | Install |
|---|---|---|---|
| GoPeak | HaD0Yun/Gopeak-godot-mcp | Run project, edit scenes/scripts, LSP diagnostics, screenshots, input injection, runtime inspection | `npx -y gopeak`; set `GODOT_PATH`; enable `godot_mcp_editor` / `godot_mcp_runtime` addons (verify README) |
| Context7 | upstash/context7 (`ctx7` CLI) | Current Godot 4.7 API docs | Already in use |

## Architectural Decisions

### Decision Summary

| # | Category | Decision | Version | Rationale |
|---|---|---|---|---|
| AD-01 | Simulation timing | Custom `SimClock` autoload: one fixed 60 Hz `tick()` driven from `_physics_process`; all gameplay timers are integer frame counters; hit-stop / Breakpoint / pause gate the tick | Godot 4.7.2 | GDD is specified in frames; Breakpoint must freeze the world while register shifts stay live; deterministic, headless-testable |
| AD-02 | Actions & frame data | Per-actor frame-based state machine; actions are `ActionDef` data (S/A/R, invuln ranges, hit shape, damage, cooldown, cancel rules); combos are a table keyed by ordered window | — | Fighting-game convention; no sprite animations to drive timing; data-driven combos per GDD |
| AD-03 | Tunable data | Typed custom `Resource` classes saved as `.tres` | — | Typed, Inspector-editable, editor-validated; fast re-tuning after Nov 14 playtest |
| AD-04 | Hit detection | Custom geometry (circle, arc, capsule/segment) resolved inside `tick()` by a single `CombatResolver`; no Godot physics bodies for gameplay | — | Same-frame results, unaffected by freezes, deterministic, testable |
| AD-05 | Communication | Direct ordered calls inside the simulation; typed `EventBus` autoload for sim → presentation; presentation never mutates game state | — | One-way data flow keeps juice/HUD/audio decoupled and safe for AI agents |
| AD-06 | Boss framework | `BossController` base (HP, phases, pool w/ no triple repeat, gap, weak window, Patched) + one `BossAttack` script per attack (`on_tell/on_active/on_recovery`) with timings in `AttackDef.tres`; per-boss body node | — | Reuse across 3 very different bosses without a behaviour-tree dependency |
| AD-07 | Rendering | Glyphs drawn via `draw_char`/`draw_string` in `_draw()`; one pooled particle node (fixed 300) with a single `_draw`; one full-screen CanvasItem shader for inversion/dither; shake via `Camera2D.offset` | Compatibility renderer | Few draw calls on WebGL2; palette effects centralised |
| AD-08 | Scene structure & flow | Persistent `Main` scene (Arena + HUD); `Game` autoload state machine (TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING); bosses/screens instanced and freed; retry restores a `RunState` snapshot | — | Instant (≤ 2 s) retry with register restore; no scene reload |
| AD-09 | Audio | `AudioManager` autoload; buses Master/Music/SFX; two music players crossfaded by Tween; pooled SFX players; requests via EventBus; Sample playback default; Null Pointer hum on `AudioStreamPlayer2D`, falls back to `Stream` playback on that node only if web panning fails | Godot 4.7 Sample mode | Low-latency shift click (P4); docs state positional audio unreliable in Sample mode |
| AD-10 | Persistence | `SaveService` autoload writing a `ConfigFile` to `user://save.cfg` (`version`, `highest_boss`, `assist`); all failures swallowed silently | — | IndexedDB-backed on web; GDD requires silent fallback |
| AD-11 | Testing | GUT for unit tests of sim logic, run headless from CLI | GUT 9.6.1 (verify on 4.7 in Epic 1; fallback gdUnit4 6.x) | Frame logic is the riskiest code and is fully AI-written |
| AD-12 | Cut ladder | `FeatureFlags` resource (`reserved_write`, `watch`, `breakpoint`, `segfault`); each cuttable feature isolated in its own module, never referenced directly by core code; GDD fallbacks read the flags | — | Cuts under deadline without ripple |
| AD-13 | Asset loading | Preload everything at boot (`preload()`); no async loading | — | Tiny asset set (1 font, ~20 SFX, 8 music loops); avoids hitches |
| AD-14 | Duck voice | mumble-speech (own library) Godot addon used **at runtime on all platforms**, including web, per basteez/mumble-speech#32 (web GDExtension, non-threaded). Wrapped by a `VoiceService` (`say(line_id_or_text)`, signals `character_spoken(i)`, `finished`) driving a `MumbleTypewriter` in the duck bubble. Web export enables *Extensions Support* (dlink, non-threaded template) | mumble-speech ≥ 0.3 (first release with #32) | Own library; runtime text supports the hint template directly; interface isolates the dependency |

### State Management

**Approach:** Layered — global flow state machine + simulation state + presentation.

- **`Game` (autoload, flow FSM):** `TITLE → INTRO → FIGHT ⇄ DEAD → HARVEST → FIGHT … → ENDING`. Owns `RunState` (current boss index, register contents at fight start, assist flag). Only `Game` changes flow state.
- **Simulation state:** lives in plain objects owned by the Arena (Player, Register, Boss, hazards). Mutated only inside `tick()` (and the register's shift handler — see Simulation Timing).
- **`RunState` snapshot:** captured on `FIGHT` enter; `retry()` rebuilds player and boss from it (full HP, register as at fight start). `RunState.deaths_on_boss: int` is incremented on death and reset when a new boss starts; `DuckDirector` reads it from `EventBus.player_died` for the 3rd-death hint.
- **Pause:** `Game` handles Esc and `NOTIFICATION_APPLICATION_FOCUS_OUT` (tab/focus loss), sets `SimClock.paused = true` and instances `ui/screens/pause`; play resumes only on an explicit input.
- **Fullscreen:** `[F]` hotkey or click on its label on the title and pause screens (GDD D-048); calls `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN)` inside the input-event handler (browser requirement).

### Simulation Timing (AD-01)

- `SimClock` (autoload) runs in `_physics_process` (physics ticks = 60) and, each frame, calls in fixed order: `Input sampling → Register → Player → Boss/hazards → CombatResolver → timers`.
- **Gates** (evaluated in priority order): `paused` (Esc / focus loss) > `breakpoint_active` > `hitstop_frames > 0`. When gated, the world does not tick.
- **Register is outside the gate:** shift input is processed every physics frame even during Breakpoint; during hit-stop shifts are buffered (8 frames) per GDD.
- **Breakpoint duration** counts real frames (not sim frames), max 120, ends on any action input.
- **Hit-stop is simulation state:** `CombatResolver` and `BossController` call `SimClock.request_hitstop(frames)`; within one tick the maximum request wins (this realises the GDD precedence crit 8 > combo > unpatched 3). Presentation (`JuiceDirector`) never sets hit-stop; it only drives shake, inversion and particles.
- All durations are `int` frames. `delta` is never used for gameplay; tiles/s are converted to px/frame constants (`speed_tiles_s * 16 / 60`).
- Presentation (`_process`) animates independently (HUD slide continues during hit-stop and Breakpoint); particles freeze with the sim by default.

### Actions & Combos (AD-02)

- `ActionDef` (Resource): `id`, `startup`, `active`, `recovery`, `invuln_from`, `invuln_to`, `intangible`, `hit_shape`, `base_damage`, `hitstop`, `cooldown`, `move` (distance/speed), `cancelable_into` (DASH, NULL_DODGE).
- `BitDef`: `id` (`A`, `D`, `L`, `N`, `?`), `glyph`, `solo_action: ActionDef`.
- `ComboDef`: `first: BitId`, `second: BitId`, `action: ActionDef`, optional `requires_first_active` (Dereference).
- `ComboTable`: lookup by ordered pair; missing pair = no combo (perform both solo actions).
- Player `ActionStateMachine` states: `IDLE/MOVE`, `STARTUP`, `ACTIVE`, `RECOVERY`, `STUNNED`, `WATCHING`; link window and 8-frame input buffer handled by `InputBuffer`.
- Echo stores `last_solo_action: ActionDef` and re-executes it at ×0.7 from current position.

### Damage & Hit Detection (AD-04)

- Shapes: `HitCircle`, `HitArc` (center, radius, facing, angle), `HitCapsule` (swept dash path). Hurtboxes: circles (player 0.6 tiles; boss glyph cells).
- `CombatResolver.resolve()` runs once per tick: player hits → boss/decoys/dummy; boss hits → player/decoy; applies invulnerability/intangibility.
- `DamageCalc.compute(base, boss_state, clean_catch, echo)` multiplies all factors and rounds half up once (`floori(x + 0.5)`); pure static function, unit-tested against GDD examples.
- "Affects the boss" outcomes reported by the resolver (hit, pass-through, decoy struck) feed `WeakWindowTracker` → Patched.

### Data Persistence

**Save System:** Local `ConfigFile` at `user://save.cfg` via `SaveService`; keys `version:int`, `highest_boss:int`, `assist:bool`. Write on fight start and assist toggle; read at boot. Any error → in-memory only, no UI.

### Asset Management

**Loading Strategy:** Preload all at boot. Assets: one monospace pixel font, SFX `.wav`, music `.ogg` loops, `MumbleVoice` resources. No streaming, no threaded loading.

### Boss Framework (AD-06)

- `BossDef` (Resource): `name_signature`, `max_hp`, `phases: Array[PhaseDef]`, `drop_bit`, `fixed_line`.
- `PhaseDef`: `hp_threshold`, `weak_window` (ordered pair), `gap_frames`, `attack_pool: Array[AttackDef]`.
- `AttackDef`: `id`, `tell`, `active`, `recovery`, `script: Script` (a `BossAttack` subclass).
- `BossController`: picks next attack (no 3 in a row), runs `GAP → TELL → ACTIVE → RECOVERY`, handles phase change (60-frame roar, speed ramp reset), damage state, death → `EventBus.boss_defeated`.
- Boss bodies (`InfiniteLoopBody`, `NullPointerBody`, `SegfaultBody`) own geometry/hurtboxes and expose hooks the attacks call.

### Rendering (AD-07)

- Layers: `Arena` (Node2D, world glyphs) → `Entities` → `Particles` → `HUD` (CanvasLayer) → `ScreenFX` (CanvasLayer, full-screen shader).
- Font scale (GDD D-047): one 8×8 CP437-style font; world glyphs drawn at 2× (16-px tiles), HUD text at 1× on an 8-px grid (80×45 cells); HUD cell layout per the GDD's Art Style → HUD Layout wireframe.
- Palette constants in one `Palette` script: `INK #E8E8E8`, `BG #101014`, `WARN #FF4040` (warnings only).
- `ScreenFX` shader uniforms: `invert: bool`, `dither: float`; driven only by `JuiceDirector` reacting to EventBus.

### Audio (AD-09)

- Buses: `Master` → `Music`, `SFX`, `Voice`. No bus effects (Sample mode).
- Music: `MusicA`/`MusicB` players; `crossfade_to(track, frames)`; glitch variants and Breakpoint loop are separate pre-rendered files.
- Audio unlock: nothing plays until `Game` leaves `TITLE` via first input.
- Day-1 web smoke test of `AudioStreamPlayer2D` panning; fallback = set that node's `playback_type` to Stream.

### Duck Voice (AD-14)

- `VoiceService` (autoload) owns a `MumbleSpeaker` on the `Voice` bus and one `MumbleVoice` resource for the duck (style `BEEP` or `GRUNT`, high pitch — tuned in Epic 3).
- `DuckBubble` (HUD) uses `MumbleTypewriter` bound to its `Label` and the speaker; the squeak SFX plays on bubble open.
- Hint template lines are rendered from text at runtime (`"Quack. Weak window: %s." % window`).
- Web export preset: *Extensions Support* enabled (non-threaded dlink template). Build-size and Safari checks happen in the Epic 1 web smoke test.
- **Contingency:** if the web GDExtension is not usable by Epic 3, `VoiceService` switches to a pre-render backend (EditorScript renders the 14 known clips + per-character timings with `Mumble.render`); no other code changes.
- **GDD delta — accepted (GDD D-046, v1.1):** the duck moves from "bubble + squeak SFX" to "squeak on open + mumble voice synced with a typewriter reveal". Credit mumble-speech (MIT/Apache-2.0) in README and itch.io page.

### Architecture Decision Records

**ADR-01 — Custom SimClock over Godot time scaling.** Context: Breakpoint freezes the world while the register stays interactive; hit-stop has precedence rules; all timings are frames. `Engine.time_scale`/`SceneTree.paused` would also freeze input handling and mix seconds with frames. Decision: single clock with gates. Consequence: every gameplay system implements `tick()` and must not use `_physics_process`, `Timer` or `delta` for gameplay.

**ADR-02 — Custom geometry over Area2D.** Context: Area2D overlaps update with the physics server (one-frame latency) and do not respect custom freezes. Decision: shape math in `CombatResolver`. Consequence: no physics bodies/areas for gameplay; walls are a clamp to the 32×18 rectangle.

**ADR-03 — One-way sim → presentation via EventBus.** Context: juice, HUD, audio and log are many consumers of few events, and are where feel is tuned. Decision: sim emits typed events; consumers never write sim state. Consequence: juice can be retuned or removed without touching gameplay.

**ADR-04 — Feature flags for the cut ladder.** Context: schedule risk with a predefined cut order. Decision: `FeatureFlags` resource + isolated modules. Consequence: core code queries flags, never imports cuttable modules directly.

**ADR-05 — mumble-speech at runtime behind VoiceService.** Context: the designer owns mumble-speech and is adding web GDExtension support (basteez/mumble-speech#32). Decision: depend on it at runtime on web, isolated behind `VoiceService`, with a pre-render contingency. Consequence: web export uses the dlink (Extensions Support) template; mumble-speech release must be pinned before Epic 3.

## Cross-cutting Concerns

These patterns apply to ALL systems and must be followed by every implementation.

### Error Handling

**Strategy:** Assert for programmer/data errors; silent graceful degradation for environment errors. The player never sees an error and the game never stops for one.

**Error Levels:**

| Class | Examples | Handling |
|---|---|---|
| **Programmer / data error** | Missing `ComboDef`, `ActionDef` with `startup < 0`, unknown `line_id`, invalid state transition | `assert(cond, msg)` + `Log.error()`; crashes in debug builds, no-op in release (assert is stripped) — code after it must still return a safe default |
| **Environment error** | Storage blocked, audio not unlocked, GDExtension/voice unavailable, fullscreen refused | `Log.warn()` once, fall back to a safe default (no persistence, silent line, windowed), continue |
| **Never** | — | No `push_error` popups, no error screens, no pausing because of an error |

**Example:**

```gdscript
func get_combo(first: BitId, second: BitId) -> ComboDef:
	var combo: ComboDef = _table.get(_key(first, second))
	return combo  # null is valid: a no-combo window

func load_action(id: StringName) -> ActionDef:
	var def := _actions.get(id) as ActionDef
	assert(def != null, "ActionDef missing: %s" % id)
	if def == null:
		Log.error(&"data", "ActionDef missing: %s" % id)
		return ActionDef.NOP
	return def

func save() -> void:
	var err := _cfg.save(SAVE_PATH)
	if err != OK:
		Log.warn(&"save", "save failed (%s); persistence disabled" % error_string(err))
		_enabled = false
```

Data validation: every `*Def` resource implements `validate() -> PackedStringArray`; a GUT test loads all `.tres` under `res://data/` and asserts no messages.

### Logging

**Format:** plain text, `[f=<sim_frame>][<LEVEL>][<tag>] <message>`
**Destination:** Godot output (editor) / browser console (web) via `print` / `push_warning`. No files, no remote services.

**Log Levels:**

| Level | Use | Enabled |
|---|---|---|
| `ERROR` | Programmer/data errors (paired with `assert`) | Always |
| `WARN` | Environment fallbacks (storage, audio, voice) | Always |
| `INFO` | Flow milestones: state changes, fight start/end, phase change, save | Always |
| `DEBUG` | Per-event detail: combo fired, Patched applied, attack chosen | Debug builds or `?debug` |

Rules:
- Tags are short `StringName`s per system: `&"flow"`, `&"sim"`, `&"combat"`, `&"boss"`, `&"register"`, `&"audio"`, `&"voice"`, `&"save"`, `&"data"`.
- Nothing above `DEBUG` inside `tick()` except errors; never log per-frame.
- The in-game **log panel** (`console.log("-5") // resisted`) is gameplay presentation driven by EventBus, **not** `Log`.

**Example:**

```gdscript
Log.info(&"flow", "FIGHT start boss=%d register=%s" % [idx, register])
Log.debug(&"combat", "combo %s hit boss dmg=%d state=%s" % [combo.id, dmg, state])
# → [f=4312][DEBUG][combat] combo dash_strike hit boss dmg=30 state=PATCHED
```

### Configuration

**Approach:** four separate layers; no magic numbers in gameplay code.

| Layer | Where | Contents | Who changes it |
|---|---|---|---|
| Constants | `scripts/core/const.gd` (`class_name Const`) | `TILE_PX = 16`, `SIM_HZ = 60`, `BASE_RES`, arena size, palette | Never (architecture) |
| Balance | `data/**/*.tres` (AD-03) | HP, damage, frame data, gaps, tells, speeds, multipliers | Designer / tuning stories |
| Player settings | `SaveService` (`user://save.cfg`) | `assist`, `highest_boss`, (volume if added) | Player |
| Flags | `data/config/feature_flags.tres`, `data/config/debug_config.tres` | Cut-ladder flags (AD-12); debug toggles | Director |

Speeds are authored in tiles/s and frame counts in the `.tres`; conversion to px/frame happens once in `Const.tiles_per_s_to_px_per_frame()`.

### Event System

**Pattern:** typed, synchronous `EventBus` autoload (AD-05). Simulation emits; presentation (HUD, LogPanel, JuiceDirector, AudioManager, VoiceService, DuckBubble) listens. Listeners never call back into the simulation; flow changes go through `Game` methods.

**Event Naming:** `snake_case`, past tense, subject first; typed parameters; no `Dictionary` payloads.

**Example:**

```gdscript
# scripts/autoloads/event_bus.gd
extends Node
signal register_shifted(direction: int, window: Vector2i, register: PackedInt32Array, cause: StringName)  # cause: &"player" | &"sigsegv"
signal register_changed(window: Vector2i, register: PackedInt32Array)  # bit inserted/expired
signal breakpoint_started
signal breakpoint_ended
signal player_died(boss: StringName, deaths_on_boss: int)
signal action_started(actor: StringName, action_id: StringName)
signal hit_landed(target: StringName, damage: int, state: int, is_combo: bool, pos: Vector2)
signal patched_applied(boss: StringName, frames: int)
signal player_damaged(hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss: StringName)
signal duck_line_requested(line_id: StringName, text: String)
signal flow_state_changed(from: int, to: int)

# emitter (simulation)
EventBus.hit_landed.emit(&"boss", dmg, boss.damage_state, true, hit_pos)

# listener (presentation)
func _ready() -> void:
	EventBus.hit_landed.connect(_on_hit_landed)
```

The list above is the initial set. All signals live in `event_bus.gd`; adding one is an architecture-level change noted in the story.

### Debug Tools

**Available Tools:**

| Key | Tool |
|---|---|
| F1–F5 | Jump to Title / Fight 1 / Fight 2 / Fight 3 / Ending (story 1.6) |
| F6 | Kill current boss · Shift+F6: next phase |
| F7 | Toggle player invincibility |
| F8 | Grant next bit (cycle register to Boss 2 / Boss 3 loadout) |
| F9 | **Frame overlay:** sim frame, player/boss FSM state + frame in state, link window, cooldowns, hit/hurtboxes drawn |
| F10 | **Perf overlay:** FPS, frame time, live particles, draw calls (`Performance` monitors) |
| F11 | Start/stop **input recording** (per-frame input to `user://replay_*.json`; printed to console on web) |

- **Input replay:** `InputSource` interface with `LiveInput` and `ReplayInput`; `SimClock` reads only from `InputSource`, so a recording replays bit-identically in a GUT test (`tests/replays/`). Used for bug repro and boss regression tests.
- All debug UI lives under `scenes/debug/` and is instanced only when debug is enabled; none of it is referenced by gameplay code.

**Activation:** `Debug.enabled = OS.is_debug_build() or _url_has_debug_param()` (web: `JavaScriptBridge.eval("location.search")` contains `debug`). Release itch.io build without `?debug` has no debug tools.

## Project Structure

### Organization Pattern

**Pattern:** Hybrid, domain-first. Code and scenes are grouped by game domain; tunable data lives in `data/` mirroring the domains; raw imported assets live in `assets/` by type.

**Rationale:** an AI agent working on one story touches one domain folder; cut-ladder modules (Segfault, Watch, Breakpoint, Reserved Write) are whole folders that can be removed; data stays in one place for tuning passes.

### Directory Structure

```
github-gameoff-2026/
├── README.md                     # AI disclosure, credits (mumble-speech, font, audio), how to run
├── LICENSE
├── .github/workflows/            # CI: GUT headless + web export
├── _bmad/ · _bmad-output/ · docs/   # planning (not part of the Godot project)
└── game/                         # Godot project root (res://)
    ├── project.godot
    ├── export_presets.cfg        # "Web" preset: no threads, Extensions Support on
    ├── addons/
    │   ├── gut/                  # GUT 9.x (dev only, excluded from export)
    │   └── mumble_speech/        # mumble-speech GDExtension (desktop + web)
    ├── assets/                   # raw imported files only, no logic
    │   ├── fonts/                # monospace pixel font (+ licence file)
    │   ├── audio/
    │   │   ├── music/            # title, boss_1..3, boss_1..3_glitch, breakpoint_muffled (.ogg)
    │   │   └── sfx/              # shift_left, shift_right, hit, hit_resisted, patched, squeak, sigsegv_alarm… (.wav)
    │   └── shaders/              # screen_fx.gdshader
    ├── data/                     # all tunable .tres (AD-03), mirrors domains
    │   ├── config/               # feature_flags.tres, debug_config.tres
    │   ├── player/               # player_def.tres (speed, HP, iframes)
    │   ├── bits/                 # bit_attack.tres, bit_dash.tres, bit_loop.tres, bit_null.tres, bit_garbage.tres
    │   ├── actions/              # slash_1..3, dash, echo, null_dodge, dash_strike, echo_dash, ghost_echo, dereference
    │   ├── combos/               # combo_table.tres
    │   ├── bosses/
    │   │   ├── infinite_loop/    # boss_def.tres, phase_*.tres, attack_*.tres
    │   │   ├── null_pointer/
    │   │   └── segfault/
    │   ├── duck/                 # duck_voice.tres (MumbleVoice), duck_lines.tres
    │   └── text/                 # fixed_lines.tres, sky_comments.tres
    ├── src/
    │   ├── autoloads/            # event_bus.gd, sim_clock.gd, game.gd, audio_manager.gd,
    │   │                         # voice_service.gd, save_service.gd, log.gd, debug.gd
    │   ├── core/                 # const.gd, palette.gd, run_state.gd, feature_flags.gd, defs (base Resource classes)
    │   ├── input/                # input_source.gd, live_input.gd, replay_input.gd, input_buffer.gd
    │   ├── register/             # register.gd, bit_def.gd, combo_def.gd, combo_table.gd
    │   ├── player/               # player.gd, action_state_machine.gd, action_def.gd, echo_memory.gd, player.tscn
    │   ├── combat/               # combat_resolver.gd, damage_calc.gd, shapes/ (hit_circle, hit_arc, hit_capsule),
    │   │                         # weak_window_tracker.gd, damage_state.gd
    │   ├── skills/
    │   │   ├── breakpoint/       # breakpoint_skill.gd  (cut #3)
    │   │   └── watch/            # watch_skill.gd       (cut #2)
    │   ├── bosses/
    │   │   ├── framework/        # boss_controller.gd, boss_def.gd, phase_def.gd, attack_def.gd, boss_attack.gd, decoy.gd
    │   │   ├── infinite_loop/    # infinite_loop_body.gd, attacks/ (head_rush, constrict, nested_loop, semicolon_spit), infinite_loop.tscn
    │   │   ├── null_pointer/     # null_pointer_body.gd, attacks/ (pointer_grab, null_rain, dangling_pointers), null_pointer.tscn
    │   │   ├── segfault/         # (cut #4) segfault_body.gd, corrupted_tiles.gd, attacks/ (access_violation, corrupt_memory, sigsegv, core_dump, reserved_write[cut #1]), segfault.tscn
    │   │   └── practice_target/  # practice_target.gd, practice_target.tscn
    │   ├── arena/                # arena.gd, arena.tscn (Clearing glyph layout, bounds clamp, sky comment)
    │   ├── presentation/         # glyph_drawer.gd, particle_pool.gd, juice_director.gd, screen_fx.gd, camera_shake.gd
    │   ├── ui/
    │   │   ├── hud/              # hud.tscn, register_panel.gd, log_panel.gd, boss_header.gd, patched_tag.gd, cooldowns.gd, line_numbers.gd
    │   │   ├── duck/             # duck_bubble.gd, duck_bubble.tscn, duck_director.gd (triggers)
    │   │   └── screens/          # title, intro, harvest, dead (Process exited), ending, pause (.gd + .tscn)
    │   ├── main/                 # main.tscn, main.gd (persistent root)
    │   └── debug/                # debug_keys.gd, frame_overlay.gd, perf_overlay.gd, input_recorder.gd (+ .tscn)
    ├── tools/                    # EditorScripts: validate_data.gd, render_duck_lines.gd (voice contingency)
    └── tests/
        ├── unit/                 # test_register.gd, test_combo_table.gd, test_damage_calc.gd, test_input_buffer.gd, test_action_fsm.gd, test_boss_controller.gd, test_data_validation.gd
        ├── integration/          # test_fight_flow.gd, test_retry_snapshot.gd
        └── replays/              # recorded input .json + test_replays.gd
```

### System Location Mapping

| System | Location | Responsibility |
|---|---|---|
| Sim clock / gates | `src/autoloads/sim_clock.gd` | Fixed tick order; pause > Breakpoint > hit-stop gating |
| Flow state machine / retry | `src/autoloads/game.gd`, `src/core/run_state.gd` | TITLE…ENDING; snapshot & restore |
| Event bus | `src/autoloads/event_bus.gd` | All typed signals (sole definition point) |
| Input & buffer | `src/input/` | `InputSource` abstraction, 8-frame buffer, link window |
| Register | `src/register/register.gd` | Owned-bit ring, shift, active window, previews, insertion, byte value |
| Combos | `src/register/combo_table.gd` + `data/combos/` | Ordered-pair lookup |
| Player actions | `src/player/` + `data/actions/` | Frame FSM, movement, iframes, cooldowns, cancels, Echo |
| Hit detection | `src/combat/combat_resolver.gd`, `src/combat/shapes/` | Shape overlap per tick |
| Damage & Patched | `src/combat/damage_calc.gd`, `weak_window_tracker.gd`, `damage_state.gd` | Multipliers, rounding, Patched timer, Clean Catch |
| Boss framework | `src/bosses/framework/` | HP, phases, pools, gap/tell/active/recovery, phase roar |
| Boss N | `src/bosses/<boss>/` + `data/bosses/<boss>/` | Body geometry, attacks |
| Skills | `src/skills/breakpoint/`, `src/skills/watch/` | Cuttable skill modules |
| Arena | `src/arena/` | Layout, bounds clamp, per-boss dressing |
| Rendering / juice | `src/presentation/` | Glyph drawing, particles (pool 300), shake, inversion/dither |
| HUD | `src/ui/hud/` | Register panel + previews, log panel, boss header, Patched tag |
| Duck | `src/ui/duck/` + `src/autoloads/voice_service.gd` + `data/duck/` | Triggers, bubble, typewriter, mumble voice |
| Screens | `src/ui/screens/` | Title, Intro, Harvest, Dead, Ending, Pause |
| Audio | `src/autoloads/audio_manager.gd` | Buses, crossfade, SFX pool, hum |
| Save | `src/autoloads/save_service.gd` | ConfigFile, silent fallback |
| Logging / debug | `src/autoloads/log.gd`, `debug.gd`, `src/debug/` | Dev log, debug keys, overlays, recorder |
| Constants & palette | `src/core/const.gd`, `palette.gd` | Immutable values |
| Tests | `tests/` | GUT unit, integration, replay |

### Naming Conventions

#### Files
- All files and folders `snake_case`: `combat_resolver.gd`, `infinite_loop.tscn`, `attack_head_rush.tres`.
- A scene and its root script share a basename in the same folder: `player.tscn` + `player.gd`.
- Resource class scripts end in `_def.gd` (`action_def.gd`); their instances are named by content (`dash_strike.tres`).
- Boss attack scripts: `src/bosses/<boss>/attacks/<attack_name>.gd`; matching data `data/bosses/<boss>/attack_<attack_name>.tres`.
- Tests: `tests/<kind>/test_<subject>.gd`.

#### Code Elements

| Element | Convention | Example |
|---|---|---|
| Class (`class_name`) | PascalCase | `CombatResolver`, `ActionDef` |
| Autoload name | PascalCase | `EventBus`, `SimClock`, `Game`, `Log` |
| Functions / variables | snake_case, statically typed | `func resolve_hits() -> void`, `var hitstop_frames: int` |
| Private members | `_` prefix | `_link_frames_left` |
| Constants | UPPER_SNAKE_CASE | `const LINK_WINDOW_FRAMES := 18` |
| Enums | PascalCase type, UPPER_SNAKE values | `enum DamageState { UNPATCHED, PATCHED }` |
| Signals | snake_case, past tense | `register_shifted`, `boss_defeated` |
| Frame counts | suffix `_frames` | `startup_frames`, `gap_frames` |
| Tile-based values | suffix `_tiles` / `_tiles_s` | `range_tiles`, `speed_tiles_s` |
| IDs | `StringName` literals, snake_case | `&"dash_strike"`, `&"infinite_loop"` |
| Bits | `BitId` enum `A, D, L, N, GARBAGE` | `BitId.A` |

#### Game Assets
- Music: `<context>[_variant].ogg` → `boss_2.ogg`, `boss_2_glitch.ogg`, `breakpoint_muffled.ogg`.
- SFX: `<event>[_detail].wav` → `shift_left.wav`, `hit_resisted.wav`, `glitch_segfault.wav`.
- Every third-party asset folder carries a `LICENSE`/`CREDITS.txt`.

### Architectural Boundaries

1. **Simulation vs presentation:** `src/{input,register,player,combat,bosses,skills,arena}` are simulation; they must not reference `src/ui`, `src/presentation`, `AudioManager` or `VoiceService`. They communicate outward only via `EventBus`.
2. **Presentation is read-only:** `src/ui`, `src/presentation`, audio and voice listen to `EventBus` and may read sim state, never write it. Flow requests go through `Game` methods.
3. **Only `SimClock` calls `tick()`.** No gameplay code in `_process`/`_physics_process`, no `Timer` nodes, no `await` in simulation code.
4. **Cuttable modules are leaves:** nothing outside `src/skills/watch/`, `src/skills/breakpoint/`, `src/bosses/segfault/` and `reserved_write.gd` references them by class; they are registered at startup if their `FeatureFlags` entry is on.
5. **Boss-specific code stays in its boss folder;** shared behaviour is promoted to `src/bosses/framework/` only when used by ≥ 2 bosses.
6. **Data never contains logic** (no scripts in `.tres` except the `AttackDef.script` reference); **code never contains balance numbers** (read from `.tres`).
7. **Debug code** lives in `src/debug/` and `addons/gut/`; both are excluded from the release export or gated by `Debug.enabled`.
8. **Third-party addons** (`gut`, `mumble_speech`) are accessed only through our wrappers (`VoiceService`); gameplay never calls `MumbleSpeaker` directly.

## Implementation Patterns

These patterns ensure consistent implementation across all AI agents. Items marked **[design call]** resolve edge cases the GDD does not specify; they were decided by the architecture facilitator on 2026-11-06 and are listed for designer review in the Validation section.

### Novel Patterns

#### NP-1 — Register Window → Action Resolution

**Purpose:** decide, every tick, what a J/K press does given the register, the link window, cooldowns, cancels and the combo table.

**Components:**

| Component | Location | Responsibility |
|---|---|---|
| `InputBuffer` | `src/input/input_buffer.gd` | Stores presses (`ACTION_1`, `ACTION_2`, `SHIFT_L`, `SHIFT_R`, `DODGE`…) stamped with sim frame; each press lives 8 frames, consumed at most once |
| `Register` | `src/register/register.gd` | Owned-bit ring; `shift(dir)`, `active_window() -> Vector2i` (bit ids of slot 1, slot 2), `preview(dir)` |
| `ComboTable` | `src/register/combo_table.gd` | `get_combo(first, second) -> ComboDef` (null = no combo) |
| `LinkState` | field of `Player` | `pair: Vector2i`, `first_active_left: int`, `frames_left: int`, `open: bool` |
| `ActionResolver` | `src/player/action_resolver.gd` | **Pure** function: `(buffer, register, link, fsm, cooldowns) -> ActionRequest` |
| `ActionStateMachine` | `src/player/action_state_machine.gd` | Executes requests; owns STARTUP/ACTIVE/RECOVERY counters, cancels, chain |

**Data Flow (one tick, fixed order):**

```
LiveInput/ReplayInput ─► InputBuffer.push(presses, frame)
1. Shifts:  for each buffered SHIFT (oldest first): Register.shift(dir); LinkState.close()  → EventBus.register_shifted
            (during hit-stop shifts stay buffered; during Breakpoint they apply immediately — see NP-2)
2. Actions: req = ActionResolver.resolve(...)  → ActionStateMachine.start(req) or keep buffered
3. ActionStateMachine.tick() → on ACTIVE start of a slot-1 action: LinkState.open(pair = active_window)
```

**Resolution rules (ActionResolver):**

1. **Action 1 (J)** → solo action of `window.x`, if the FSM is IDLE/MOVE, or in RECOVERY and the action is cancel-eligible (DASH, NULL_DODGE), or it continues the ATTACK chain.
2. **Action 2 (K) while `LinkState.open`** and `Register.active_window() == LinkState.pair`:
   - combo exists → request the combo's action (replaces K's solo action); K's bit cooldown is applied.
   - `ComboDef.requires_first_active` (Dereference) → valid only while the first action is in ACTIVE (`first_active_left > 0`); otherwise falls to rule 3.
   - no combo → request K's solo action flagged `link_second = true` (counts for no-combo weak windows, NP-4). If J is still ACTIVE/RECOVERY and not cancelable, the press stays buffered and fires when J ends (GDD).
3. **Action 2 (K) otherwise** → K's solo action, with the same availability rules as rule 1.
4. **Link window** = first action's ACTIVE frames + 18 frames after; a K press buffered during J's STARTUP is evaluated when ACTIVE begins.
5. **[design call] Any shift closes the link.** The combo is always the one shown on the HUD for the current window; shifting between J and K yields K's solo action of the new window.
6. **[design call] Cooldown blocks:** if the requested action's bit (for a combo: the second bit) is on cooldown, the press stays buffered (8 frames) and is then dropped. No partial execution.
7. **ATTACK chain:** pressing the *same button* that started the current slash during the last 8 recovery frames continues the chain (hit 2, then 3), as long as that slot still holds `A`. Works from slot 1 or slot 2. A shift resets the chain.
8. **Same-frame J+K:** J is resolved first, K is buffered (evaluated next tick against the newly opened link).

**State:** `LinkState` and the FSM are plain data on `Player`, included in the debug frame overlay; `RunState` restore resets them.

**Implementation Guide:**

```gdscript
# src/player/action_resolver.gd
class_name ActionResolver
extends RefCounted

static func resolve(buf: InputBuffer, reg: Register, link: LinkState,
		fsm: ActionStateMachine, cds: Cooldowns, combos: ComboTable) -> ActionRequest:
	var window: Vector2i = reg.active_window()
	if buf.has(&"action_2") and link.open and window == link.pair:
		var combo: ComboDef = combos.get_combo(window.x, window.y)
		if combo != null and (not combo.requires_first_active or link.first_active_left > 0):
			if cds.ready(window.y):
				buf.consume(&"action_2")
				return ActionRequest.combo(combo, window)
			return ActionRequest.NONE  # stays buffered (rule 6)
		if fsm.can_start(Bits.solo(window.y)):
			buf.consume(&"action_2")
			return ActionRequest.solo(window.y, 2, true, window)  # link_second
		return ActionRequest.NONE
	for slot in [1, 2]:
		var key: StringName = &"action_1" if slot == 1 else &"action_2"
		var bit: int = window.x if slot == 1 else window.y
		if buf.has(key) and cds.ready(bit) and fsm.can_start(Bits.solo(bit), key):
			buf.consume(key)
			return ActionRequest.solo(bit, slot, false, window)
	return ActionRequest.NONE
```

**Usage:** the only code path that turns J/K into actions. Unit-tested per GDD example (`[D,A]` → dash then slash; `[A,D]` → Dash Strike; shift between J and K; cooldown block; Dereference outside Null Dodge).

#### NP-2 — Breakpoint Freeze (frozen world, live register)

**Purpose:** freeze the simulation for up to 120 real frames while the player keeps shifting, layered correctly with pause and hit-stop.

**Components:** `SimClock` (gates), `BreakpointSkill` (`src/skills/breakpoint/`, cuttable), `Register`, `InputBuffer`, presentation listeners.

**Data Flow (`SimClock._physics_process`, every physics frame):**

```
read input → InputBuffer
if paused:                         return            # nothing advances, Breakpoint timer included
if breakpoint.active:
    apply buffered SHIFTs now      # register is live
    breakpoint.real_frames_left -= 1
    if action press buffered or real_frames_left == 0: breakpoint.end()   # action stays buffered
    return                         # world frozen, hit-stop counter untouched
if hitstop_frames > 0:  hitstop_frames -= 1; return   # shifts stay buffered (8 frames)
world tick (NP-1 order) ; sim_frame += 1
```

**Rules:**
- Priority: **pause > Breakpoint > hit-stop**. A Breakpoint started during hit-stop preserves the remaining hit-stop frames, which resume afterwards.
- Activation (Space) is evaluated in the same pre-gate section; requires `FeatureFlags.breakpoint`, unlocked, `cooldown_left == 0` (first use free).
- **[design call]** The 12 s cooldown (720 frames; 360 with assist) starts when Breakpoint **ends** and counts **sim frames**.
- The action that ends Breakpoint executes on the first unfrozen tick (it is the buffered press).
- Events: `breakpoint_started`, `breakpoint_ended` → ScreenFX dither + red line, AudioManager switches to the muffled loop, DuckDirector may fire the hint (once per phase).
- `sim_frame` does not advance while frozen; `Log` uses `sim_frame`, and the debug overlay shows the real frame count too.

**Implementation Guide:**

```gdscript
# src/autoloads/sim_clock.gd (excerpt)
func _physics_process(_d: float) -> void:
	input_source.poll_into(buffer, sim_frame)
	if paused:
		return
	if breakpoint != null and breakpoint.active:
		register_system.apply_buffered_shifts(buffer)
		breakpoint.tick_real(buffer)
		return
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return
	_tick_world()
	sim_frame += 1
```

#### NP-3 — Boss → Player State Mutation (SIGSEGV, Reserved Write)

**Purpose:** let boss attacks change player-owned state (register rotation, garbage bit) without bosses referencing the player directly, keeping fairness rules enforceable.

**Components:** `ArenaContext` (passed to every `BossAttack`; attacks read their aim point only via `ctx.target_position()`, which returns a live Ghost Echo decoy's position if one exists, else the player's — GDD D-049), `PlayerEffects` command queue, `Register` (supports temporary bits), `BossController` scheduler.

**Data Flow:**

```
BossAttack.on_active(ctx) → ctx.player_effects.push(RotateRegister.new(2))
tick order: … Boss/hazards → PlayerEffects.apply_all() → CombatResolver …
apply: Register.rotate(n) ; LinkState.close() ; EventBus.register_shifted.emit(dir, window, reg, &"sigsegv")
```

**Rules:**
- Bosses never call `Player`/`Register` methods; they only push effects. Effects are applied at one fixed point in the tick.
- `RotateRegister(n)` rotates `n` slots left (sign = direction) and closes the link (same rule as NP-1).
- `InsertTemporaryBit(GARBAGE, 600)`: the register appends `?` with an expiry counter; its solo action is `ActionDef.NOP` and `ComboTable` returns null for any pair containing it. On expiry the bit is removed and the window recomputed; event `register_changed`.
- **Exclusivity:** `AttackDef.exclusive = true` (SIGSEGV) → the `BossController` only starts it when no other attack or hazard is in ACTIVE and blocks new attacks until its recovery ends. Recovery = `AttackDef.recovery` (90) or `recovery_if_no_breakpoint` (150) when `FeatureFlags.breakpoint` is off.
- `RunState` restore removes temporary bits and restores the fight-start register.

**Implementation Guide:**

```gdscript
# src/bosses/segfault/attacks/sigsegv.gd
extends BossAttack

func on_active(ctx: ArenaContext) -> void:
	ctx.player_effects.push(PlayerEffects.RotateRegister.new(2))
```

#### NP-4 — Weak Window → Patched (boss interactions)

**Purpose:** detect that the current phase's weak window "affected the boss" in all four GDD cases and apply Patched before that hit's damage.

**Components:** `ActionRequest.window_pair` / `link_second`, `CombatResolver` (emits `BossInteraction`s), `WeakWindowTracker`, `DamageState`, `Decoy` (carries the creating window).

**Interaction kinds:**

| Kind | Produced when | Carries |
|---|---|---|
| `HIT` | a damaging player action overlaps a boss hurtbox | action's `window_pair`, `is_combo`, `link_second` |
| `PASS_THROUGH` | an Echo Dash capsule crosses a boss hurtbox | `window_pair` (D→L) |
| `DECOY_STRUCK` | a boss attack's hitbox overlaps a Ghost Echo decoy | decoy's `window_pair` (L→N) |

**Rule:** an interaction **completes the weak window** if `interaction.window_pair == boss.current_weak_window()` and it is a combo, or a `link_second` solo action (no-combo pair), or a `PASS_THROUGH`/`DECOY_STRUCK`. The boss decides `current_weak_window()` dynamically (Infinite Loop phase 3 returns the window of the ring whose `;` is open or opens next).

**Order inside `CombatResolver.resolve()`:** collect interactions → `WeakWindowTracker.process()` (apply/refresh Patched = 180 frames, emit `patched_applied`) → compute damage with the **post-patch** state (the patching hit counts as Patched) → emit `hit_landed`. Practice target: interactions are logged, never patched, multiplier ×1.

```gdscript
# src/combat/weak_window_tracker.gd (excerpt)
func process(interactions: Array[BossInteraction], boss: BossController) -> void:
	var weak: Vector2i = boss.current_weak_window()
	for it in interactions:
		if it.window_pair == weak and it.completes_window():
			boss.damage_state.apply_patched(PATCHED_FRAMES)
			EventBus.patched_applied.emit(boss.id, PATCHED_FRAMES)
			return
```

#### NP-5 — Echo Memory

**Purpose:** LOOP's Echo re-executes the last solo bit action at 70% damage from the current position.

**Rules:**
- `EchoMemory.last` is set when a **solo bit action** starts (its exact `ActionDef`, e.g. `slash_3`, `dash`, `null_dodge`), whiffed or not. Not set by combos, Echo itself, NOP (garbage) or a cancelled-in-startup action **[design call]**.
- Echo creates an `ActionRequest` with that `ActionDef`, `damage_scale = 0.7`, the player's current position and facing; frame data, iframes and intangibility are those of the echoed action (Echo of Null Dodge can trigger Clean Catch).
- Empty memory → no action, **no cooldown**. Otherwise LOOP's 90-frame cooldown applies.
- Echoed hits are not combos and carry `link_second` only if Echo was the K of a no-combo pair (L→A is J=Echo, so never).
- Memory is cleared on fight start and retry.
- `DamageCalc` multiplies `damage_scale` with the other factors and rounds once (10 → 7, 15 → 11).

```gdscript
func on_solo_started(def: ActionDef) -> void:
	if def.is_echoable:
		_last = def
```

### Communication Patterns

**Pattern:** ordered direct calls inside the simulation (`SimClock` → systems, via `tick(ctx)`), typed `EventBus` signals outward, command objects (`PlayerEffects`) for boss → player effects. Presentation never writes simulation state.

```gdscript
# simulation system contract
class_name SimSystem
extends RefCounted
func tick(ctx: SimContext) -> void:
	pass

# boss attack → effect (never a direct call)
ctx.player_effects.push(PlayerEffects.RotateRegister.new(2))

# simulation → presentation
EventBus.patched_applied.emit(boss.id, 180)
```

### Entity Patterns

**Creation:**
- **Pooled data entities** (fixed capacity, allocated at fight start, no `new`/`free` during `tick()`): particles (300, owned by `ParticlePool`), projectiles (`;` Spit, 16), corrupted tiles (32×18 grid array), log lines (ring buffer).
- **Scene instancing** (`PackedScene.instantiate()` once per fight or screen): boss scenes, decoys (≤ 3), screens, practice target. Freed by `Game` on state exit.

```gdscript
# src/presentation/particle_pool.gd (excerpt)
const CAPACITY := 300
var _alive: PackedByteArray
var _pos: PackedVector2Array
var _glyph: PackedInt32Array
var _life: PackedInt32Array

func spawn(p: Vector2, glyph: int, life_frames: int) -> void:
	var i := _alive.find(0)
	if i == -1:
		return  # pool full: drop silently
	_alive[i] = 1; _pos[i] = p; _glyph[i] = glyph; _life[i] = life_frames
```

### State Patterns

**Pattern:** enum + `match` finite state machines with integer frame counters, stored as plain fields (snapshot-friendly, deterministic). No node-per-state machines; no `await`.

```gdscript
enum Phase { GAP, TELL, ACTIVE, RECOVERY, ROAR }
var _phase: Phase = Phase.GAP
var _frames_left: int = 0

func tick(ctx: SimContext) -> void:
	_frames_left -= 1
	match _phase:
		Phase.GAP:
			if _frames_left <= 0: _enter(Phase.TELL, _attack.def.tell)
		Phase.TELL:
			if _frames_left <= 0: _enter(Phase.ACTIVE, _attack.def.active)
		Phase.ACTIVE:
			_attack.on_active_tick(ctx)
			if _frames_left <= 0: _enter(Phase.RECOVERY, _attack.def.recovery)
		Phase.RECOVERY:
			if _frames_left <= 0: _enter(Phase.GAP, _phase_def.gap_frames)

func _enter(p: Phase, frames: int) -> void:
	_phase = p
	_frames_left = frames
```

Flow-level state (`Game`) uses the same pattern with `enter/exit` handlers.

### Data Patterns

**Access:** typed `*Def` resources referenced by `@export` on the owning scene/resource (e.g. `BossController.def: BossDef`). Global catalogues (bits, actions, combos) are preloaded once in `src/core/defs.gd` (`class_name Defs`, static `const` preloads). Defs are **read-only at runtime**; mutable runtime state lives in separate objects (`DamageState`, `Cooldowns`, `RunState`).

```gdscript
# src/core/defs.gd
class_name Defs
const COMBOS: ComboTable = preload("res://data/combos/combo_table.tres")
const BIT_ATTACK: BitDef = preload("res://data/bits/bit_attack.tres")

# usage
var combo := Defs.COMBOS.get_combo(BitId.A, BitId.D)

# assist mode: scale at read time, never mutate the .tres
var tell := roundi(def.tell * (1.5 if Game.run.assist else 1.0))
```

### Consistency Rules

| Pattern | Convention | Enforcement |
|---|---|---|
| Time | Integer frames only; `_frames` suffix; no `delta`, `Timer`, `await` in sim | Code review; grep check in CI for `Timer.new`/`await` under sim folders |
| Tick order | Input → shifts → actions → player → boss/hazards → PlayerEffects → CombatResolver → timers | Only `SimClock` calls `tick()` |
| Randomness | One seeded `RandomNumberGenerator` in `SimContext.rng`, reseeded at fight start; no `randi()`/`randf()` globals | Needed for deterministic replays |
| Damage | Only `DamageCalc.compute()` produces damage numbers; round half up once | Unit tests on GDD examples |
| Patched | Only `WeakWindowTracker` applies Patched | Single writer |
| Register mutation | Only via `Register` methods, from NP-1 shifts or NP-3 effects | Single writer |
| Events | Declared only in `event_bus.gd`; past tense; typed args | Review |
| Data | Balance values only in `.tres`; defs read-only at runtime | `validate_data` test |
| Positions | Sim positions in pixels (`Vector2`, 16 px = 1 tile) on the 640×360 base; authoring in tiles | `Const` helpers |
| Collision | No `Area2D`/`PhysicsBody2D` for gameplay | Review |
| Pools | No allocation of frequent entities during `tick()` | Perf overlay |
| Cuttable features | Accessed through `FeatureFlags` + registration; never referenced by class from core | Boundary rule 4 |
| Logging | `Log.<level>(tag, msg)` only; no bare `print` | grep check |
| Typing | Static types on every var, param and return | `untyped_declaration` warning set to error in project settings |

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
|---|---|---|
| Decision Compatibility | PASS (after fixes) | I-1 hit-stop ownership and I-2 EventBus signatures resolved |
| GDD Coverage | PASS (after fixes) | 18/18 core systems; pause/focus loss, fullscreen and death counter mapped (I-3…I-5) |
| Pattern Completeness | PASS | Entity creation, communication, state, error handling, data access, events — all with examples |
| Epic Mapping | PASS | Epics 1–7 mapped to folders and patterns |
| Document Completeness | PASS | No placeholders; executive summary and Development Environment added in Step 9 |

### Coverage Report

**Systems Covered:** 18/18
**Patterns Defined:** 5 novel (NP-1…NP-5) + 4 standard (communication, entity, state, data) + 14 consistency rules
**Decisions Made:** 14 (AD-01…AD-14), 5 ADRs

### Issues Resolved

- **I-1** Hit-stop is simulation state set via `SimClock.request_hitstop()` (max per tick); presentation never sets it.
- **I-2** `register_shifted` gains `cause: StringName`; `register_changed`, `breakpoint_started`, `breakpoint_ended`, `player_died` declared.
- **I-3** Pause and focus-loss auto-pause owned by `Game` (story 1.7).
- **I-4** Fullscreen button on title/pause screens, called from the input handler (story 7.7).
- **I-5** `RunState.deaths_on_boss` for the 3rd-death duck hint.

### Open Actions Before / During Implementation

| # | Action | When |
|---|---|---|
| I-6 | **Status: #32 resolved in mumble-speech v0.3.0 (2026-11-07); Firefox and Safari not yet hand-verified.** mumble-speech web GDExtension (basteez/mumble-speech#32) is built on gdext's experimental wasm support: pin the release and pass the web smoke test (Chrome, Firefox, Safari; build size) as early as possible (Epic 1 story 1.3 if released); the voice is its own story (3.7) and never blocks the MVP; otherwise switch `VoiceService` to the pre-render backend | Epic 1–3 |
| I-7 | Verify GUT 9.6.1 on Godot 4.7.2 headless; fall back to gdUnit4 6.x | Epic 1 |
| — | Day-1 web smoke test of `AudioStreamPlayer2D` panning in Sample mode (AD-09) | Epic 1 |

### Notes for Designer

Design calls made during architecture — **all confirmed on 2026-11-06 (GDD D-045, D-046; GDD v1.1)**:

1. **NP-1** Any shift closes the link: K after a shift performs the new window's solo action.
2. **NP-1** A combo whose second bit is on cooldown stays buffered 8 frames, then is dropped.
3. **NP-1** The ATTACK chain continues with the same button that started it (slot 1 or 2); a shift resets it.
4. **NP-2** Breakpoint's 12 s cooldown starts when Breakpoint ends and counts simulation frames.
5. **NP-5** Echo does not remember actions cancelled during startup.
6. **AD-14** Duck voice: squeak on bubble open + mumble-speech voice synced with a typewriter reveal (GDD said "bubble + squeak SFX, no voice acting").

### Validation Date

2026-11-06

## Development Environment

### Prerequisites

- Godot **4.7.2-stable** (standard build) + matching **Web export templates** (including the dlink / Extensions Support template)
- mumble-speech Godot addon with web support (first release including basteez/mumble-speech#32 = v0.3.0, released 2026-11-07; pin exact version)
- GUT 9.x addon (verify on 4.7.2; fallback gdUnit4 6.x)
- Node.js 18+ (for the GoPeak MCP via `npx`)
- Git + GitHub CLI; itch.io account with `butler` for uploads to the draft page
- Assets: one CC0/OFL monospace pixel font; BeepBox (music); jsfxr (SFX)

### AI Tooling (MCP Servers)

The following MCP servers were selected during architecture to enhance AI-assisted development:

| MCP Server | Purpose | Install Type |
|---|---|---|
| GoPeak (`HaD0Yun/Gopeak-godot-mcp`) | Run the project, edit scenes/scripts, LSP diagnostics, screenshots, input injection, runtime scene-tree inspection | Node.js MCP via `npx`, plus `godot_mcp_editor` / `godot_mcp_runtime` addons |
| Context7 (`ctx7` CLI) | Current Godot 4.7 API docs (`/godotengine/godot-docs/__branch__4.7`) | Already installed |

**Setup:**

```bash
claude mcp add gopeak -e GODOT_PATH="/Applications/Godot.app/Contents/MacOS/Godot" -e GOPEAK_TOOL_PROFILE=compact -- npx -y gopeak
```

Then copy/enable the GoPeak editor/runtime addons in `game/addons/` per its README (verify names, ports and requirements there; keep the runtime addon out of the release export).

These give your AI assistant direct access to Godot for scene inspection, asset queries, and context-aware code generation.

### Setup Commands

```bash
# from the repo root
mkdir -p game && cd game
# create project.godot via the Godot editor (Project Manager → New Project → path: game/, renderer: Compatibility)
mkdir -p addons assets/{fonts,audio/music,audio/sfx,shaders} \
  data/{config,player,bits,actions,combos,bosses/{infinite_loop,null_pointer,segfault},duck,text} \
  src/{autoloads,core,input,register,player,combat/shapes,skills/{breakpoint,watch},bosses/{framework,infinite_loop/attacks,null_pointer/attacks,segfault/attacks,practice_target},arena,presentation,ui/{hud,duck,screens},main,debug} \
  tools tests/{unit,integration,replays}
# install addons into game/addons/: gut, mumble_speech (release zip), GoPeak addons
# run tests headless
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
# web export
godot --headless --path game --export-release "Web" ../build/web/index.html
```

### First Steps

1. Create the Godot 4.7.2 project in `game/` with the Project Initialization settings (640×360, integer scaling, Nearest, 60 physics ticks, Compatibility, web Sample audio, `untyped_declaration` = error).
2. Configure the "Web" export preset (no threads, Extensions Support on, exclude `addons/gut`, `tests/`, `tools/`, GoPeak runtime) and upload an empty build to the itch.io draft page (Epic 1.2) — run the I-6/I-7/audio smoke tests.
3. Configure MCP servers (if selected) per the AI Tooling instructions above.
4. Create the autoloads (`EventBus`, `SimClock`, `Game`, `Log`, `Debug`, `AudioManager`, `VoiceService`, `SaveService`) as stubs and the persistent `main.tscn`, then start Epic 1 stories.
