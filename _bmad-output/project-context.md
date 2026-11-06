---
project_name: 'github-gameoff-2026'
user_name: 'Tiziano'
date: '2026-11-06'
sections_completed: ['technology_stack', 'engine_rules', 'performance_rules', 'organization_rules', 'testing_rules', 'platform_rules', 'anti_patterns']
existing_patterns_found: 0
status: 'complete'
rule_count: 54
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing game code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Godot 4.7.2-stable** — pinned for the whole jam; do not upgrade. GDScript only (no C#: unsupported on web).
- Renderer **Compatibility** (WebGL2). Web export: **Thread Support off**, **Extensions Support on** (dlink template). Web audio playback type: **Sample**.
- **mumble-speech** Godot addon (GDExtension, web + desktop; first release including basteez/mumble-speech#32, exact version pinned in `addons/mumble_speech`). Access only via `VoiceService`.
- **GUT 9.6.1** for tests (fallback gdUnit4 6.x if GUT fails on 4.7.2).
- Godot docs: use Context7 `/godotengine/godot-docs/__branch__4.7` — APIs differ from Godot 3 and from older 4.x tutorials.
- Source of truth: `_bmad-output/game-architecture.md` (AD-xx decisions, NP-x patterns). GDD: `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`.

## Critical Implementation Rules

### Engine-Specific Rules

- **Only `SimClock` calls `tick(ctx)`.** Gameplay code never uses `_process`/`_physics_process`, `delta`, `Timer` nodes, `await`, `create_tween()` or `Engine.time_scale`. All gameplay durations are `int` frames at 60 Hz (`*_frames`).
- `SceneTree.paused` is **not** used for gameplay pause; use `SimClock.paused`. Hit-stop: `SimClock.request_hitstop(frames)` (max per tick wins). Gate order: pause > Breakpoint > hit-stop; register shifts apply during Breakpoint.
- **No `Area2D`/`PhysicsBody2D`/`CharacterBody2D` for gameplay.** Hits are shape math (`HitCircle`, `HitArc`, `HitCapsule`) in `CombatResolver`. Arena walls = position clamp.
- Signals: declare **only** in `src/autoloads/event_bus.gd`, past tense, typed args, no `Dictionary` payloads. Simulation emits; presentation listens. Presentation never writes sim state; flow changes go through `Game` methods.
- Boss attacks never touch `Player`/`Register`: push `PlayerEffects` commands (`RotateRegister`, `InsertTemporaryBit`).
- State machines: `enum` + `match` + int counters stored as fields. No node-per-state machines.
- Data: typed `Resource` `*Def` classes in `data/**/*.tres`, **read-only at runtime**. Mutable state lives in separate objects (`DamageState`, `Cooldowns`, `RunState`). Assist mode scales values at read time.
- Glyphs are drawn with `draw_char`/`draw_string` in `_draw()` (call `queue_redraw()`); no `Label` per glyph, no sprites.
- One 8×8 CP437-style font: world glyphs at **2×** (16-px tiles), HUD text at **1×** on an 8-px grid (80×45 cells). HUD regions follow the GDD's HUD Layout wireframe (D-047); never place HUD elements off that grid.
- Static typing everywhere (`untyped_declaration` = error). Use `StringName` literals for ids (`&"dash_strike"`).

### Performance Rules

- 60 FPS on a 2020 integrated-GPU laptop in the browser; worst case Segfault phase 3. Check with the F10 perf overlay.
- No allocation of frequent entities inside `tick()`: particles (pool 300), `;` projectiles (16), corrupted tiles (fixed grid), log lines (ring buffer) use fixed-capacity packed arrays. Pool full → drop silently.
- Only bosses, decoys and screens are instanced (`PackedScene.instantiate()`), once per fight/screen.
- All assets are `preload()`ed; no runtime `load()` or threaded loading.
- Never log per frame; `Log.debug` only on events.
- Web build ≤ 30 MB uncompressed.

### Code Organization Rules

- Godot project root is **`game/`** (`res://` = `game/`). Never put game files at the repo root.
- Domain-first: `src/<domain>/` (`register`, `player`, `combat`, `bosses/<boss>`, `skills/<skill>`, `ui/hud`, …); data mirrors it in `data/<domain>/`; raw files in `assets/`.
- Simulation folders (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.
- Cuttable modules (`skills/watch`, `skills/breakpoint`, `bosses/segfault`, `reserved_write.gd`) are leaves: registered at startup if `FeatureFlags` allows; never referenced by class from core code.
- Boss-specific code stays in its boss folder; promote to `bosses/framework/` only when ≥ 2 bosses use it.
- Single writers: damage → `DamageCalc.compute()` (multiply all factors, round half up **once**: `floori(x + 0.5)`); Patched → `WeakWindowTracker`; register → `Register` methods; J/K → `ActionResolver`.
- Names: files `snake_case`; `class_name` PascalCase; resources `*_def.gd`; frame fields `_frames`; tile fields `_tiles` / `_tiles_s`; constants `UPPER_SNAKE`. No magic numbers: balance in `.tres`, invariants in `Const`.
- Logging: `Log.error/warn/info/debug(&"tag", msg)` only; no bare `print`.
- Errors: `assert()` + `Log.error` for programmer/data errors, then return a safe default; environment failures (storage, audio, voice, fullscreen) → `Log.warn` once and degrade silently. Never show errors to the player.

### Testing Rules

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- `tests/unit/test_<subject>.gd` for pure logic (register, combo table, `ActionResolver`, `DamageCalc`, input buffer, boss controller); `tests/integration/` for flow and retry; `tests/replays/` for recorded input replays.
- Use the GDD's worked numbers as test cases (e.g. unpatched slash 15 → 8; Patched Echo of 15 → 16; Echo 10 → 7; `[D,A]` J→K = dash then slash; `[A,D]` = Dash Strike).
- Simulation code must run without a scene tree or renderer: build systems from defs plus a `SimContext` in tests.
- Determinism: all randomness from `SimContext.rng` (seeded at fight start); no global `randi()`/`randf()`. Input only through `InputSource` (`LiveInput`/`ReplayInput`).
- `test_data_validation.gd` loads every `.tres` under `res://data/` and asserts `validate()` returns no messages.

### Platform & Build Rules

- Web is the only target. No audio before the first user input (title press-to-start).
- Sample mode: **no AudioEffects, no reverb/doppler, no `AudioStreamGenerator`**. Glitch and muffled music are pre-rendered files; crossfade = two players + volume. Positional audio is unreliable: Null Pointer's hum falls back to `playback_type = Stream` on that node only.
- Fullscreen only inside an input-event handler. `user://` (IndexedDB) can fail in iframes: `SaveService` degrades silently.
- Tab/focus loss (`NOTIFICATION_APPLICATION_FOCUS_OUT`) → `Game` pauses; resume only on explicit input.
- Input: `InputMap` actions only (keyboard + gamepad); never Shift keys (Sticky Keys/browser conflicts). Buffer 8 frames.
- Debug tools (F1–F11, overlays, recorder) only when `OS.is_debug_build()` or the URL has `?debug`. Export excludes `addons/gut`, `tests/`, `tools/` and the GoPeak runtime addon.
- 640×360 base, stretch `viewport`, scale mode `integer`, texture filter Nearest. Palette: ink `#E8E8E8`, bg `#101014`; red `#FF4040` **only** for warnings (Breakpoint, SIGSEGV).

### Critical Don't-Miss Rules

- **Any shift closes the combo link**; the combo is always the one shown on the HUD for the current window (NP-1).
- **Ordered combos:** `[A,D]` → Dash Strike, `[D,A]` → no combo (two solo actions, can still be a weak window). Look up by ordered pair, never a sorted pair.
- Link window = first action's ACTIVE frames + 18 frames; a K press in J's startup is evaluated when ACTIVE starts. Dereference only during Null Dodge's ACTIVE frames.
- A combo whose second bit is on cooldown stays buffered 8 frames, then is dropped (no partial execution).
- **Patched is applied before the patching hit's damage** (that hit is already ×1.5). Unpatched hits are ×0.5, including combos. The practice target is always ×1 and never Patched.
- Echo stores the exact last solo `ActionDef` (not combos, not Echo, not garbage NOP, not actions cancelled in startup); empty memory → no action and no cooldown.
- SIGSEGV is `exclusive`: never overlaps another attack's or hazard's ACTIVE frames; recovery 150 frames if `FeatureFlags.breakpoint` is off.
- Breakpoint counts real frames (≤ 120) and ends on any action press (the press executes on the first unfrozen tick); its cooldown starts at the end and counts sim frames.
- Retry restores the fight-start `RunState`: register (temporary bits removed), full HP, Echo memory and link cleared, `rng` reseeded.
- Every boss attack needs a tell of ≥ 20 frames **and** a non-empty `tell_sfx` (the boss's tell cue); no off-screen or untelegraphed damage (Pillar 2).
- Boss attacks aim only via `ctx.target_position()` (player, or a live Ghost Echo decoy); never read the player position directly.
- Every fight start (after Harvest, on resume, on retry) restores full HP and resets all cooldowns. The DEAD screen accepts only a new press made ≥ 20 frames after death.
- Godot 3 syntax is wrong here: `@export`/`@onready`, `signal.connect(callable)`, `await` (not `yield`). `await` and Tweens are allowed **only** in presentation/UI code (HUD slide, screens, crossfades), never in simulation.

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any game code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-11-06
