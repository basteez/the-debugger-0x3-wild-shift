---
baseline_commit: 816c1b7
---

# Story 2.8: Hit Feedback — Hit-stop, Particles and Log Lines

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. -->

## Story

As a player,
I want every hit to stop, burst and log,
so that hits feel weighty and readable.

**Requirements:** FR26 (hit-stop table and precedence), FR27 (base: combo hit shake, hit feedback), NFR2 (at most 300 live glyph particles); FR57 (log panel rows 38–44, HUD); AD-01 (hit-stop is simulation state via `SimClock.request_hitstop`, max per tick wins); AD-05 (presentation listens to `EventBus`, never calls back into sim); AD-07 (`ParticlePool` of 300, one `_draw`; `ScreenFX` shader with `invert` and `dither` driven only by `JuiceDirector`; shake via `Camera2D.offset`); GDD "Hit feedback" table and "Hit-stop precedence".
**Epic 2 window:** Nov 8–10. **Depends on:** Story 2.1 (`SimClock`, `request_hitstop`, `poll_frame`), 2.3 (`RegisterPanel`, 8-frame buffer), 2.4 (`JuiceDirector`, `ShiftJuice`, physics-frame presentation clock, H4 deferral), 2.5 (`ActionDef`, `ActionStateMachine`), 2.6 (`ComboDef`, Dash Strike, `actions.combo`), 2.7 (`CombatResolver`, `PracticeTarget`, `hit_landed`, the temporary arena readout this story removes).
**Unblocks:** Epic 3 (crit and Patched feedback, boss hit-stop, `ScreenFX` inversion for crit), Story 2.9 (player-hit feedback reuses the shake, log and hit-stop plumbing), Story 2.4 H4 (hit-stop check of the HUD slide and inversion).

## Acceptance Criteria

1. **Hit-stop request.** Given a player hit that lands on the practice target, when `CombatResolver` resolves it, then it requests hit-stop through `SimClock.request_hitstop(frames)` with the value of the hit's precedence: a combo hit uses the combo action's `hitstop_frames` (Dash Strike 6); a solo hit uses the normal value 3. Within one tick only the maximum request counts (the `SimClock` rule). A tick with no hit requests nothing. Presentation never requests hit-stop (checked by a source guard).
2. **Glyph particles.** Given a hit that lands, when it is shown, then glyph particles burst from the hit point from a fixed 300-slot `ParticlePool` (a combo hit bursts more particles than a solo hit). The pool is drawn in one `_draw` call, its particles advance only on simulation frames (they freeze with hit-stop, pause and Breakpoint), and a spawn into a full pool is dropped silently. `live_count()` reports the live particles for the F10 overlay.
3. **Log lines.** Given a hit that lands, when the log panel updates, then it appends `console.log("-<dmg>")` (for example `console.log("-10")`) to a fixed ring buffer of 6 lines drawn in HUD rows 39–44 under the existing `── console ──` header, newest at the bottom. The 2.7 arena readout (`hits N`, `f=<frame> …` lines) is removed.
4. **Combo shake.** Given a combo hit, when it lands, then a 2-px screen shake for 6 frames is applied to the arena via `Camera2D.offset`, counted on physics frames (D-S28-5). A solo hit does not shake. The HUD is unaffected by the shake.
5. **ScreenFX.** Given the `ScreenFX` CanvasLayer shader with `invert` and `dither` uniforms, when `JuiceDirector` requests a 1-frame inversion or sets a dither level, then the full screen inverts or dithers, and only `JuiceDirector` writes those uniforms. Gameplay in 2.8 requests neither (crit inversion is Epic 3; Breakpoint dither is Epic 4); the request API is covered by tests.
6. **Perf overlay.** Given a debug build (`Debug.enabled`), when I press F10, then a perf overlay shows FPS, frame time, live particles and draw calls. Without the debug gate the overlay and the key do not exist.
7. **Purity.** Given the juice code, when reviewed by guard and tests, then presentation never sets hit-stop or writes sim state (`SimClock.hitstop_frames`, `request_hitstop`, `ParticlePool` is presentation-owned and never read by sim), and hit-stop is simulation state only.
8. **HUD continues through hit-stop (2.4 H4, automated part).** Given a hit-stop, when a register shift slides the panel during it, then the slide advances on engine physics frames while `SimClock.hitstop_frames > 0` (the slide does not read the sim clock). The real-browser check stays a human check (H4 below).
9. **Guards and tests.** `bash game/tools/check_guards.sh` prints OK. New tests `test_hit_feedback.gd`, `test_particle_pool.gd`, `test_log_panel.gd`, `test_camera_shake.gd`, `test_perf_overlay.gd` are added; `test_combat_resolver.gd`, `test_juice_director.gd`, `test_debug_keys.gd`, `test_practice_target.gd`, `test_glyph_palette.gd`, `test_font_coverage.gd` and `test_hud_layout.gd` are extended or updated for the removed readout. Full GUT run is green, and Main boots headless for 120 frames without errors.

## Scope Boundaries

- **In:** hit-stop precedence and request from `CombatResolver`, `ActionDef.hitstop_frames`, `ParticlePool` and its view, `LogPanel` in the HUD, combo shake (`CameraShake` schedule and the Camera2D), `ScreenFX` shader and node, `JuiceDirector` inversion and dither API, F10 `PerfOverlay`, removal of the 2.7 readout, tests and guards.
- **Out (later stories):** crit hit-stop 8 and the crit log line in CAPS, Patched hit-stop 4, resisted (unpatched) hits (half particles, dither, `// resisted`), crit inversion, damage states (Epic 3); player hit feedback (`WARN: hp--`, 3-px shake, 4 frames of hit-stop: 2.9); boss defeated hit-stop 20 (3.8); Breakpoint dither and red line (Epic 4); Dereference hit-stop 8 data (6.2); pooled SFX (7.2); `ScreenFX` Breakpoint muffling (Epic 4).
- **Not changed:** 2.5 frame data and cancel rules, 2.6 combo and link rules, 2.7 hit shapes and `DamageCalc`, the 8-frame `InputBuffer`, `SimClock` gates and `request_hitstop` semantics, `Register`, `Player` movement, `JuiceDirector`'s slide and invert behaviour for shifts.

## Tasks / Subtasks

### Group A: Hit-stop precedence (AC: 1, 7)

- [x] A1. `ActionDef`: add `@export var hitstop_frames: int = 3` (the normal and unpatched value; documented in the field comment). Set `game/data/actions/dash_strike.tres` to `6`. Solo actions keep the default. `ActionDef.validate` checks `hitstop_frames >= 0`.
- [x] A2. `game/src/combat/hit_feedback.gd` (`class_name HitFeedback`, RefCounted, static only): `hitstop_for(is_combo: bool, action_hitstop: int) -> int` returns `NORMAL_HITSTOP` (3) for a solo hit and `maxi(NORMAL_HITSTOP, action_hitstop)` for a combo hit. Pure: no node, no `SimClock`. Crit (8) is reserved for Epic 3 and is not a parameter yet (D-S28-1).
- [x] A3. `CombatResolver.tick`: track the max `hitstop_for` over this tick's hits, and call `SimClock.request_hitstop(frames)` once after the hit loop when at least one hit landed. The resolver stays injectable; tests check the value through `HitFeedback` and an integration test through `SimClock`.

### Group B: ParticlePool (AC: 2, 7)

- [x] B1. `game/src/presentation/particle_pool.gd` (`class_name ParticlePool extends Node2D`): a fixed 300-slot array allocated once (`CAPACITY := 300`). Each slot holds position, velocity, age, lifetime, glyph index (`PackedVector2Array`, `PackedFloat32Array` or `PackedInt32Array`; no per-spawn allocation). `spawn(at: Vector2, count: int) -> int` returns how many were placed; a full pool drops the rest silently. `live_count() -> int`.
- [x] B2. Advance on simulation frames only: `_process` compares `SimClock.sim_frame` with the last stepped value and steps every live particle once per new sim frame (velocity, age, expiry). Particles therefore freeze with hit-stop, pause and Breakpoint. `_process` calls `queue_redraw()` while any particle is live (D-S28-3).
- [x] B3. `_draw`: one loop over live slots drawing `GlyphFont.draw_cell`-equivalent glyphs (or `GlyphFont.draw_at`) in `Palette.INK` only. Glyph set ASCII `* + ' . x` (font coverage is tested). No `Label`, no sprite.
- [x] B4. Spawn source: `EventBus.hit_landed` connected in `_enter_tree` (disconnected in `_exit_tree`, same pattern as `JuiceDirector`). Burst count 12 for a solo hit and 20 for a combo hit (D-S28-2). The burst point is the signal's `pos` (arena-local); the node is positioned at the arena origin so the points line up. Randomness uses a presentation-owned `RandomNumberGenerator`, never `SimContext.rng` (D-S28-3).

### Group C: LogPanel (AC: 3)

- [x] C1. `game/src/ui/hud/log_panel.gd` (`class_name LogPanel extends Control`, or a Node2D placed in `hud.tscn` under the Hud CanvasLayer): a ring of `Hud.LOG_LINES` (6) strings, `append_line(text)`, `lines() -> PackedStringArray` (oldest first, newest last), `static func line_for_damage(damage: int) -> String` returning `console.log("-%d")`. ASCII only. Draws the lines at the `Hud.LOG` rect below the header row, one per row, in `Palette.INK`. Presentation only.
- [x] C2. Subscribe to `EventBus.hit_landed` (same connect and disconnect pattern). Its handler appends `line_for_damage(damage)`; it does not read sim state beyond the signal arguments.
- [x] C3. `hud.tscn` and `hud.gd`: add the `LogPanel` child and an `@onready var log_panel`. `Hud.LOG_LINES` stays the single source of the line count. The header in `hud_frame.gd` is unchanged.
- [x] C4. Remove the 2.7 readout from `PracticeTargetView`: delete `READOUT_HITS`, `readout_lines`, `readout_top_left`, `hit_line` and the readout drawing. The `/* test */` label and the hurtbox overlay stay. `PracticeTarget.records()` stays (it is tested, and the debug overlay may use it), and the `f=` frame stamp lives on in the `[f=…]` prefix of the `Log.debug(&"combat", …)` line (D-S28-10).

### Group D: Combo shake (AC: 4)

- [x] D1. `game/src/presentation/camera_shake.gd` (`class_name CameraShake`, RefCounted, static pure schedule): `SHAKE_PX := 2`, `SHAKE_FRAMES := 6`; `offset_for(frames_left: int) -> Vector2` returns an alternating ±2 px offset on the x axis for `frames_left` in 1..6 and `Vector2.ZERO` otherwise. Its test pins the schedule.
- [x] D2. The shake owner is a presentation node `CameraShakeDriver` attached to the arena through Main (`arena/` may not reference `presentation/`). It owns a `Camera2D` child of the Arena, placed so that the offset-zero view matches today's framing exactly. It listens to `EventBus.hit_landed` and starts the shake only when the signal's `is_combo` argument is true. It counts physics frames (`Engine.get_physics_frames()`), not `SimClock`, so the shake plays during the hit-stop it accompanies (D-S28-5).
- [x] D3. No shake on solo hits. A new combo hit restarts the 6-frame schedule; the schedule is not tied to pause (it counts physics frames only).

### Group E: ScreenFX and JuiceDirector (AC: 5, 8)

- [x] E1. `game/src/presentation/screen_fx.gdshader` (`shader_type canvas_item`, Compatibility renderer): `uniform bool invert = false;`, `uniform float dither = 0.0;`, `uniform vec4 ink_colour` and `bg_colour` set from `Palette` by the node (no colour literals in the shader beyond the defaults, which match `Palette`). It reads `hint_screen_texture`. Invert swaps INK and BG by luminance threshold, so the output stays two-colour (D-S28-6). Dither (`dither` 0..1): on checkerboard pixels with `(x + y) % 2 == 0`, output BG when `dither >= 0.5`.
- [x] E2. `game/src/presentation/screen_fx.gd` (`class_name ScreenFX extends ColorRect`): full-rect, `mouse_filter = MOUSE_FILTER_IGNORE`, material with the shader. Methods `set_invert(on: bool)` and `set_dither(level: float)`; they write the shader uniforms only. Main adds it to the existing `ScreenFX` CanvasLayer (already in `_build_layers`).
- [x] E3. `JuiceDirector`: add `request_invert(frames: int = 1)` (sets an inversion counter counted in physics frames through `now()`, and `_live = true`), `set_dither(level: float)` (clamped to 0..1), and a `screen_fx: ScreenFX` injected field (null-safe, like the other injected nodes). Its `_process` drives `screen_fx` only. The existing slide and `@` inversion stay as they are. Presentation never requests hit-stop.
- [x] E4. Automated part of 2.4 H4 (AC 8): `ShiftJuice` is pure and takes an explicit `now` frame. The test drives `JuiceDirector.now()` through an injected clock or the pure `ShiftJuice` API while `SimClock.hitstop_frames > 0` (set directly in the test) and asserts the slide offset advances. Real-browser check stays H4.

### Group F: Perf overlay (AC: 6)

- [x] F1. `game/src/debug/perf_overlay.gd` (`class_name PerfOverlay extends Node2D`, debug only): `static func lines(fps: float, frame_ms: float, live_particles: int, draw_calls: int) -> PackedStringArray` (pure, ASCII, e.g. `fps 60`, `frame 16.7 ms`, `particles 42/300`, `draw calls 37`). `_draw` renders them at 1x in `Palette.INK` on a `Palette.BG` rect, at the top-right of the play area. Values come from `Engine.get_frames_per_second()`, `Performance` process time, `ParticlePool.live_count()` and `RenderingServer.get_rendering_info(...)` for the draw calls (verify the constant names at dev time; D-S28-7).
- [x] F2. `debug/debug_keys.gd`: add `F10` toggles the perf overlay (`const PERF_KEY := KEY_F10`, the same pattern as F9). `Main` creates the overlay under `Debug.enabled` only and gives it the particle pool. Release builds have neither the key nor the node.

### Group G: Wiring and tests (AC: 9)

- [x] G1. `Main._build_layers`: add `ParticlePool` in the existing `Particles` layer (positioned at the arena origin), `ScreenFX` in the existing `ScreenFX` layer, the `CameraShakeDriver` (with its Camera2D under the Arena), `LogPanel` through `hud.tscn`, and `PerfOverlay` under the debug gate. Keep `LAYER_ORDER` unchanged.
- [x] G2. `test_hit_feedback.gd`: solo 3, combo 6 for Dash Strike, max wins, a combo with 0 frames still gives 3.
- [x] G3. `test_combat_resolver.gd` (extended): a Dash Strike hit requests 6 and a slash hit requests 3 (use a `SimClock` integration test: `hitstop_frames` after the tick, then freeze check); a tick with no hit requests nothing; a double hit in one tick uses the max.
- [x] G4. `test_particle_pool.gd`: capacity 300, a full pool drops silently, `live_count`, particles do not step when `sim_frame` does not change, expiry, spawn does not allocate (count of slots unchanged).
- [x] G5. `test_log_panel.gd`: ring keeps the newest 6 in order, `line_for_damage(10) == "console.log(\"-10\")"`, ASCII only, the hit signal appends.
- [x] G6. `test_camera_shake.gd`: the schedule (6 frames, ±2 px, zero outside), no shake for solo hits (driver test with a fake event).
- [x] G7. `test_perf_overlay.gd`: `lines` formatting and ASCII; the F10 key maps and release gate in `test_debug_keys.gd`.
- [x] G8. `test_juice_director.gd` / `test_shift_juice.gd` (extended): inversion request for 1 frame, dither clamp, the slide advancing with `SimClock.hitstop_frames > 0`.
- [x] G9. Update `test_glyph_palette.gd` (source list gains the new presentation and HUD files; drawn colours are `Palette.INK` or `Palette.BG`), `test_font_coverage.gd` (drop the readout strings; add the log and perf strings and the particle glyphs), `test_hud_layout.gd` (log rows 39–44 hold the lines).
- [x] G10. Verification: `godot --headless --path game --import` once in the fresh worktree (new `class_name`s and the shader), then full GUT, then `bash game/tools/check_guards.sh` from the repo root, then Main headless for 120 frames with no errors. Record the test count and guard output in Completion Notes.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S28-1 Hit-stop values and precedence.** Solo or normal hit: 3 frames (GDD "unpatched hit", the value the practice target gets because it is never Patched). Combo hit: the combo action's own value, Dash Strike 6 (`ActionDef.hitstop_frames`). The rule is `max(3, combo value)`, and `SimClock` keeps the max within a tick. Crit 8 (Epic 3), Patched 4, player hit 4 (2.9) and boss defeated 20 (3.8) are not produced by 2.8, so they are not parameters yet; adding a state parameter is the Epic 3 change, and the precedence test documents the ladder.
- **[design call] D-S28-2 Burst sizes.** 12 particles per solo hit, 20 per combo hit. Lifetime 14 sim frames. Spawn points at the hit point (`pos`). These are feel numbers; judge in H2.
- **[design call] D-S28-3 Particle clock.** Particles step on simulation frames (new `sim_frame` values), so they freeze with hit-stop, pause and Breakpoint as the epic requires ("frozen with the sim"). Only the drawing runs per process frame. Particle randomness is presentation-only, so it cannot desync the sim, and it is not replay-relevant.
- **[design call] D-S28-4 Log line text.** The log line is exactly `console.log("-<dmg>")`. No frame stamp, no `[f=]` prefix (the debug `Log.debug` line keeps the stamp for developers). The crit `CRITICAL:` and resisted `// resisted` forms are Epic 3.
- **[design call] D-S28-5 Shake clock.** The 6-frame combo shake counts physics frames (the presentation clock of 2.4), so it plays during the 6-frame hit-stop it accompanies, which is the point of a shake on a freeze. It is applied to `Camera2D.offset` of an arena camera only; the HUD (a CanvasLayer) does not move, which is the desync noted in 1.5 and accepted until Epic 7.
- **[design call] D-S28-6 Inversion keeps two colours.** The inversion swaps INK and BG by luminance threshold, not `1 - colour`, so the output stays inside the 1-bit palette (NFR8). Dither is the checkerboard that `RegisterPanel` already uses (D-S23-7), so both effects read the same.
- **[design call] D-S28-7 Perf overlay numbers.** FPS from `Engine.get_frames_per_second()`, frame time from the process-time monitor, draw calls from `RenderingServer.get_rendering_info`. If a constant is missing under the Compatibility renderer on web, show `-` for that value and log a warning once (environment failure rule, not a crash).
- **[design call] D-S28-8 Log panel size and retention.** Six lines (the HUD's `LOG_LINES`), oldest scrolls off. Only hits are logged in 2.8.
- **[design call] D-S28-9 Remove the 2.7 readout.** The readout was a temporary stand-in (D-S27-8) for this panel. Removing it means the practice target shows its label and hurtbox only, and the log panel shows the damage per hit.
- **[design call] D-S28-10 Frame counter.** The 2.7 AC4 "frame counter" is now the `[f=…]` stamp on the debug `Log.debug(&"combat", …)` line (visible in the browser console under `?debug`). The arena no longer shows it.
- **[design call] D-S28-11 Input buffer during hit-stop.** Unchanged. A 6-frame Dash Strike hit-stop is within the 8-frame buffer. Dereference's 8 (Epic 6) sits at the buffer limit; the 2.3 deferral already tracks this, and 2.8 does not change the buffer.
- **[design call] D-S28-12 Hit-stop from a sim system only.** `CombatResolver` is the only requester in 2.8. Presentation gets a source guard (no `request_hitstop` and no `hitstop_frames` writes under `presentation/`, `ui/`, `debug/`).

### Existing code this story touches (verified at baseline 816c1b7)

- `SimClock` already has `hitstop_frames`, `_pending_hitstop`, `request_hitstop(frames)` (max per tick) and gates pause, Breakpoint then hit-stop. Nothing calls `request_hitstop` yet; 2.8 adds the first caller.
- `EventBus.hit_landed(target, damage, state, is_combo, pos)` is emitted by `CombatResolver` (2.7). `state` is `DamageCalc.STATE_BASE` (0).
- `Main` already creates the empty `Particles` Node2D layer, the empty `ScreenFX` CanvasLayer (layer 20), and the `JuiceDirector` with its register panel and player view injections.
- `Hud` has `LOG := Rect2i(0, 38, 80, 7)` and `LOG_LINES := 6`; `HudFrame` draws the `── console ──` header. The log lines are not drawn yet.
- `PracticeTargetView` draws the label and the 2.7 readout (`readout_lines`, `hit_line`, `READOUT_HITS`). Remove only the readout parts.
- `ActionDef` has no hit-stop field. Dash Strike's action resource is `game/data/actions/dash_strike.tres`; its combo entry is `game/data/combos/dash_strike.tres`, referenced by `game/data/combos/combo_table.tres`.
- No `.gdshader` exists in the project yet; the shader is new.
- Debug keys: F1–F5, F9 overlay, F11 recorder, Shift+F2 practice. F10 is free.
- `game/tools/check_guards.sh` forbids `Timer.new`, `await`, `create_timer`, `get_ticks_*`, `create_tween` and `Engine.time_scale` in sim folders, global RNG in sim, and direct `print`. Presentation code may use `Engine.get_physics_frames()` and `RandomNumberGenerator`.

### Architecture guardrails (must follow)

- Hit-stop is simulation state: `SimClock.request_hitstop(frames)` from `CombatResolver`; the max within a tick wins; presentation never sets it (AD-01, I-1, project-context).
- Presentation listens to `EventBus` and never calls back into the sim (AD-05). `ParticlePool`, `LogPanel`, `CameraShakeDriver`, `ScreenFX` and `PerfOverlay` only read signal arguments or sim state read-only.
- Pools: particles 300 allocated once; log lines a fixed ring. No allocation in `tick()` and no per-frame allocation in `_draw` beyond what the existing code already does.
- Glyph drawing: `draw_cell` or `draw_at` in `_draw`, `queue_redraw()` on change; `Palette.INK` and `Palette.BG` only; ASCII text at 1x through `GlyphFont`.
- `Log.debug` on events only (a hit line), never per frame. No bare `print`.
- Signals are declared only in `event_bus.gd`; this story adds none (it uses `hit_landed`).
- Typing: every variable, parameter and return is typed; `StringName` for ids.
- Shader colours follow `Palette`; no colour literals in drawing code (the `test_glyph_palette.gd` regex applies to `.gd` files).

### Previous story intelligence (2.4 to 2.7)

- 2.4: `JuiceDirector` clocks on `Engine.get_physics_frames()`, so the slide and the inversion keep running through hit-stop (D-S24-1). 2.4 H4 is deferred to this story: "Hit-stop: the slide and inversion keep running during a hit-stop while the world stays frozen". The automated part is AC 8; the real check is H4.
- 2.4 deferred: "Click and inversion ignore the `register_shifted` source and `SimClock.paused`; gate on `&"player"` when boss shifts arrive (Epic 3)". Not in this story. Note only.
- 2.4 deferred: "Physics-frame presentation clock: a render hitch of 4+ physics ticks can skip slide frame 0". The shake and the inversion use the same clock; the same risk applies. Accepted until a web trace says otherwise.
- 2.7: `hit_landed` is emitted once per hit inside the COMBAT tick; it is the only hit-feedback signal. The 2.7 readout was explicitly a stand-in until 2.8 (D-S27-8).
- 2.7 deferred: "`PracticeTargetView._process` redraws every frame; drive from `hit_landed` if it matters." The particle view redraws while particles are live, which is the same pattern; measure with F10.
- 2.7 deferred: "`CombatResolver`: `player` is injected but unused; `hit_landed` id is hard-coded `&"practice_target"`." Leave as is.
- 2.3 deferred: "Hit-stop longer than 8 frames drops all buffered input (attacks, dashes too)." Dash Strike's 6 is within the window; keep as H1 feel check.
- 2.1 deferred: "InputBuffer grows while the world is frozen." Hit-stop lengthens the freeze, but only by 3–6 frames per hit; no change here.

### Latest technical information

- Godot 4.7.2 (pinned), Compatibility renderer, web export. `shader_type canvas_item` with `hint_screen_texture` is supported in Compatibility. `Camera2D.offset` is a plain property. `RenderingServer.get_rendering_info` and `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME` must be checked against the 4.7 API at dev time (D-S28-7); if absent in Compatibility, use the fallback in D-S28-7.
- No web research was run for this story; the risky API points are listed above for verification.

### Project Context Rules

- Godot project root is `game/`. New files: `game/src/combat/hit_feedback.gd`, `game/src/presentation/particle_pool.gd`, `game/src/presentation/camera_shake.gd`, `game/src/presentation/screen_fx.gd`, `game/src/presentation/screen_fx.gdshader`, `game/src/ui/hud/log_panel.gd`, `game/src/debug/perf_overlay.gd`; tests `game/tests/unit/test_hit_feedback.gd`, `test_particle_pool.gd`, `test_log_panel.gd`, `test_camera_shake.gd`, `test_perf_overlay.gd`.
- `project-context.md`: "Hit-stop: `SimClock.request_hitstop(frames)` (max per tick wins)"; "The in-game log panel is gameplay presentation driven by EventBus, not `Log`"; "particles (pool 300) … log lines (ring buffer) use fixed-capacity packed arrays. Pool full → drop silently"; "Check with the F10 perf overlay".
- Palette: ink `#E8E8E8`, bg `#101014`; red only for warnings (not used in 2.8).

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.8 H1] Debug build, practice target (Shift+F2), Chrome and Firefox: a solo slash hit freezes for 3 frames and Dash Strike for 6; both feel weighty and not laggy. Note the feel and whether 6 reads right (D-S28-1, D-S28-11).
- [ ] [2.8 H2] Particles: a solo hit bursts about 12 glyphs and a combo hit about 20; they read clearly in INK, do not cover the `@` or the target label for long, and freeze during hit-stop (D-S28-2, D-S28-3). Note the F10 `particles` count.
- [ ] [2.8 H3] Log panel: each hit appends `console.log("-10")` (slash) or `console.log("-20")` (Dash Strike) in rows 39–44, newest at the bottom, aligned to the HUD grid (`?debug`, Shift+F9 shows the grid). The 2.7 arena readout is gone.
- [ ] [2.8 H4] (closes 2.4 H4) Hit-stop with a shift: press Q or E during the Dash Strike hit-stop. The register slide and the `@` inversion keep running while the arena is frozen, and the shift applies after hit-stop (within the 8-frame buffer).
- [ ] [2.8 H5] Combo shake: 2 px for about 6 frames on Dash Strike, nothing on solo hits; not nauseating. F10 numbers (fps, frame time, draw calls) are plausible on the local laptop and note the web numbers.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.8] (ACs, FR26, FR27, NFR2)
- [Source: _bmad-output/planning-artifacts/epics.md#FR26, FR27, FR57, NFR2, NFR8] (hit-stop table and precedence, feedback per state, log panel, particle cap, palette)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Hit feedback] (hit-stop table, shake 2 px for 6 frames on combo hits, log panel)
- [Source: _bmad-output/game-architecture.md#AD-01, AD-05, AD-07] (hit-stop as sim state, EventBus listeners, ScreenFX and ParticlePool)
- [Source: _bmad-output/game-architecture.md#Pools, Presentation layers, Debug tools (F10)] (300 particles, log ring, layer order, perf overlay)
- [Source: _bmad-output/implementation-artifacts/2-7-combat-resolver-damage-calc-and-practice-target.md] (D-S27-8 readout stand-in, D-S27-12 hit-stop deferred to 2.8, hit_landed contract)
- [Source: _bmad-output/implementation-artifacts/2-4-shift-juice.md] (D-S24-1 physics-frame presentation clock, H4 deferral)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (2.3, 2.4, 2.7 deferrals that touch hit-stop and the readout)

### Review Findings

Code review (gds-code-review, 2026-11-09): Blind Hunter, Edge Case Hunter and Acceptance Auditor ran as three parallel subagents. 8 patch (applied), 0 decision_needed, 14 defer, about 20 dismissed as noise.

- [x] [Review][Patch] ScreenFX shown for dither 0 < level < 0.5 although the shader draws nothing, wasting a screen copy [screen_fx.gd:_update_visible]
- [x] [Review][Patch] `ActionDef.validate` accepts `hitstop_frames` > 8, which would drop every buffered input (InputBuffer window) [action_def.gd:validate]
- [x] [Review][Patch] `LogPanel.line_for_damage` prints `--5` for negative damage; clamp at 0 [log_panel.gd:line_for_damage]
- [x] [Review][Patch] PerfOverlay never logged the one-time warning for unavailable draw calls (D-S28-7) [perf_overlay.gd:refresh]
- [x] [Review][Patch] PerfOverlay refreshed while hidden by the arena (uses `visible`, not `is_visible_in_tree`) [perf_overlay.gd:_process]
- [x] [Review][Patch] `ParticlePool.clear()` did not resync `_stepped_frame` [particle_pool.gd:clear]
- [x] [Review][Patch] Tests added: low dither keeps ScreenFX hidden; negative damage line [test_juice_director.gd, test_log_panel.gd]
- [x] [Review][Defer] 1-frame inversion (and 6-frame shake start) can be skipped when a render frame spans 2+ physics ticks (web hitch); `_process`-driven by design [juice_director.gd] - deferred, accepted hitch risk (same as slide)
- [x] [Review][Defer] Shake offset / inversion stay applied while the tree is paused mid-effect [camera_shake_driver.gd, juice_director.gd] - deferred, cosmetic
- [x] [Review][Defer] Dither checker assumes viewport equals `Const.BASE_RES`; invert snaps non-palette pixels (red lines in Epic 3/4) [screen_fx.gdshader] - deferred until Epic 4
- [x] [Review][Defer] `JuiceDirector.reset()` clears dither on every fight entry; revisit when Breakpoint sets a persistent dither [juice_director.gd] - deferred, Epic 4
- [x] [Review][Defer] Solo hits ignore `ActionDef.hitstop_frames` (only combo hits read it, by design D-S28-1); document or generalise with crit/Patched in Epic 3 [hit_feedback.gd] - deferred
- [x] [Review][Defer] "Max wins within a tick" resolver test cannot fail (one action per tick); pure `HitFeedback` test covers the max [test_combat_resolver.gd] - deferred
- [x] [Review][Defer] Hit-stop guard regex is evadable (`set`/`call`, `main/`), no guard that only JuiceDirector calls ScreenFX setters or that sim never reads ParticlePool [check_guards.sh] - deferred
- [x] [Review][Defer] Camera2D shake also jitters Particles and PerfOverlay (arena children); no explicit `make_current`/limits [camera_shake_driver.gd] - deferred, revisit with a boss camera
- [x] [Review][Defer] PerfOverlay: "frame" is `TIME_PROCESS` only, F10 may be eaten by browser menus (Firefox/Linux), overlay hidden outside FIGHT [perf_overlay.gd, debug_keys.gd] - deferred, debug-only
- [x] [Review][Defer] Burst particles show as one clump during hit-stop (steps on sim_frame); judge by feel in H1 [particle_pool.gd] - deferred, [design call]
- [x] [Review][Defer] ParticlePool/LogPanel micro-costs: 300-slot scans without a free-list, `lines()` allocates per `_draw` [particle_pool.gd, log_panel.gd] - deferred
- [x] [Review][Defer] Test-only accessors on production nodes; `CameraShakeDriver` PREDELETE camera cleanup is brittle [various] - deferred
- [x] [Review][Defer] `ScreenFX.set_*` also toggles visibility (E2 says uniforms only); recorded design call, harmless [screen_fx.gd] - deferred
- [x] [Review][Defer] No draw-level tests for LogPanel/PerfOverlay `_draw`; AC8 test drives ShiftJuice, not the director's `_process` [tests] - deferred
- [x] [Review][Defer] Hit-stop 6 plus queued input leaves 2 frames of buffer slack (2.3 deferral made likelier) [input_buffer] - deferred

## Dev Agent Record

### Agent Model Used

Story created by Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended).

Implemented by Claude Opus 5.5 (claude-opus-5-5) via gds-dev-story (unattended).

### Debug Log References

- Godot 4.7.2 API checked with ctx7 (`/websites/godotengine_en/4.7`) and a headless probe: `Performance.TIME_PROCESS` (1), `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (13), `Viewport.RENDER_INFO_TYPE_CANVAS` (2), `Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME` (2). The 4.7 docs say `RenderingServer.get_rendering_info` counts only 3D draw calls.
- Windowed smoke test (Compatibility, Metal): the shader compiles; inversion and dither render two-colour; practice fight shows particles, six log lines and F10 numbers (`fps 60`, `draw calls 37-39`). No errors.

### Completion Notes List

- Verification (G10): headless `--import`, then full GUT **540/540 tests passed** (7672 asserts, 51 scripts, 0 orphans; baseline was 489). `bash game/tools/check_guards.sh` prints `check_guards: OK`. Main headless `--quit-after 120` boots with no errors.
- A: `ActionDef.hitstop_frames` (default 3, validated >= 0), Dash Strike 6. `HitFeedback.hitstop_for` is pure. `CombatResolver.tick` requests hit-stop once per tick (the max over its hits), only when something was hit. Integration test through the autoload `SimClock`: a slash hit freezes the world for 3 frames.
- B: `ParticlePool` uses 300 slots in packed arrays allocated once. Spawning reuses slots and a full pool drops the rest silently. Particles step per new `SimClock.sim_frame` and draw in one `_draw` in INK. Bursts are 12 (solo) and 20 (combo), with presentation RNG.
- C: `LogPanel` (Node2D in `hud.tscn`, `Hud.log_panel`) is a ring of `Hud.LOG_LINES` drawn in rows 39-44. The 2.7 readout is removed from `PracticeTargetView`, including its per-frame `_process` redraw. Main redraws the label when the target is attached, which closes the 2.7 deferral.
- D: `CameraShake` is a pure schedule (alternating +-2 px on x for 6 frames). `CameraShakeDriver` owns a `Camera2D` with `ANCHOR_MODE_FIXED_TOP_LEFT` under the Arena, placed at the canvas origin so offset zero equals the old framing (tested). It counts physics frames.
- E: `screen_fx.gdshader` and `ScreenFX` (ColorRect in the ScreenFX layer). `JuiceDirector.request_invert(frames)`, `set_dither(level)` and an injected `screen_fx`. AC8 test: the register slide advances while `SimClock.hitstop_frames > 0` and `sim_frame` is frozen.
- F: `PerfOverlay` (F10, debug only) and `DebugKeys.PERF_KEY`.
- Guard: `check_guards.sh` now rejects `request_hitstop(` and `hitstop_frames` writes under `presentation/`, `ui/` and `debug/` (D-S28-12). A planted violation file was used to check that the guard fires.
- [design call] Draw calls come from the root viewport's canvas render info, not `RenderingServer.get_rendering_info`. Reason: the 4.7 docs say the latter counts only 3D draw calls, so it would always read 0 here. A value of 0 or less shows as `-` (D-S28-7 fallback).
- [design call] `ScreenFX` hides itself while neither invert nor dither is on, so normal play pays no full-screen screen-texture copy. The shader's checker uses base-resolution pixels (`SCREEN_UV * 640x360`), not window pixels, so it matches the RegisterPanel dither at any browser scale. The colour uniforms have no `source_color` hint, so the Palette values pass through unconverted.
- [design call] The log panel fills top-down like a console (row 39 first) and scrolls once full; the newest line is always the last one.
- [design call] On every flow change (each fight entry), Main clears the particles, the shake and the log lines next to `juice_director.reset()`, so a retry starts with a clean console.
- [design call] Particles draw at 1x (8-px glyphs) centred on their position; at 2x a 20-glyph burst would cover the target label. Speed is 1.5-3.5 px per sim frame with 0.85 drag. A particle spawned in the hit tick steps once when that tick ends, then freezes for the hit-stop, so the burst reads as frozen, slightly open.
- [design call] `CameraShakeDriver` is a child of Main added after the layers (like `JuiceDirector`), so `LAYER_ORDER` and the first-six-children test stay unchanged. The PerfOverlay is a child of the Arena (top-right of the play area), so it shows only in FIGHT.
- Every other design call (D-S28-1 to D-S28-12) was followed as written. On review they match the GDD hit-stop table and precedence, AD-01, AD-05 and AD-07.
- Human checks H1-H5 stay open for Tiziano (real browser feel, web F10 numbers, H4 shift during hit-stop). They do not block review.

### File List

- game/data/actions/dash_strike.tres (modified)
- game/src/player/action_def.gd (modified)
- game/src/combat/hit_feedback.gd (new)
- game/src/combat/combat_resolver.gd (modified)
- game/src/presentation/particle_pool.gd (new)
- game/src/presentation/camera_shake.gd (new)
- game/src/presentation/camera_shake_driver.gd (new)
- game/src/presentation/screen_fx.gd (new)
- game/src/presentation/screen_fx.gdshader (new)
- game/src/presentation/juice_director.gd (modified)
- game/src/presentation/practice_target_view.gd (modified)
- game/src/ui/hud/log_panel.gd (new)
- game/src/ui/hud/hud.gd (modified)
- game/src/ui/hud/hud.tscn (modified)
- game/src/debug/perf_overlay.gd (new)
- game/src/debug/debug_keys.gd (modified)
- game/src/main/main.gd (modified)
- game/tools/check_guards.sh (modified)
- game/tests/unit/test_hit_feedback.gd (new)
- game/tests/unit/test_particle_pool.gd (new)
- game/tests/unit/test_log_panel.gd (new)
- game/tests/unit/test_camera_shake.gd (new)
- game/tests/unit/test_perf_overlay.gd (new)
- game/tests/unit/test_combat_resolver.gd (modified)
- game/tests/unit/test_juice_director.gd (modified)
- game/tests/unit/test_debug_keys.gd (modified)
- game/tests/unit/test_practice_target.gd (modified)
- game/tests/unit/test_glyph_palette.gd (modified)
- game/tests/unit/test_font_coverage.gd (modified)
- game/tests/unit/test_hud_layout.gd (modified)
- the `.gd.uid` / `.gdshader.uid` sidecars of every new file (generated by the import)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S28-1 to D-S28-12 recorded.
- 2026-11-09: Implemented by gds-dev-story: hit-stop precedence and request, ParticlePool, LogPanel (2.7 readout removed), combo camera shake, ScreenFX shader and JuiceDirector API, F10 perf overlay, presentation hit-stop guard. 540/540 GUT, guards OK. Status review.
- 2026-11-09: Code review done (3 parallel layers): 7 patches applied (dither visibility, hitstop_frames <= 8 validation, damage clamp, perf overlay warn/visibility, pool clear resync, 2 tests), 14 deferred. Status done. Tests 542/542, guards OK.
