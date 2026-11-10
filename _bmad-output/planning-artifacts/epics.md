---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md
  - _bmad-output/game-architecture.md
  - _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md
  - _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md
  - _bmad-output/project-context.md
---

# The Debugger 0x03: Wild Shift (github-gameoff-2026) - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for The Debugger 0x03: Wild Shift, decomposing the requirements from the GDD and the Game Architecture into implementable stories. There is no separate UX design document; HUD and screen requirements come from the GDD and are listed as FRs.

## Requirements Inventory

### Functional Requirements

**Player movement and health**

- FR1: The player moves in 8 directions at 7 tiles/s, reaching full speed in 4 frames and stopping in 3 frames, with WASD and the arrow keys as an alternative. Facing is set by the last movement direction, and attacks fire in the facing direction.
- FR2: The player has a 0.6-tile circular hurtbox (1-tile sprite) and 5 HP shown as `hp: 0b11111`. Every boss attack or contact deals 1 HP and is followed by 60 frames of invulnerability with a blinking sprite.
- FR3: The play area is 32 × 18 tiles with solid tree-line walls (a position clamp). Touching a boss body deals 1 HP; dash and dodge invulnerability let the player pass through bodies.

**Register**

- FR4: The register is a ring of owned bits only (2 → 3 → 4). The HUD shows a full byte: the low nibble is the playable register, the high nibble is greyed out and labelled `reserved`. Unowned slots show a greyed `0` and are skipped by rotation, so no dead window is possible.
- FR5: The active window is the 2 leftmost owned slots: slot 1 = Action 1 (J), slot 2 = Action 2 (K).
- FR6: Q shifts `<<` (rotate left one slot) and E shifts `>>` (rotate right one slot). A shift takes 0 frames, is allowed at any time (including during recovery), affects the next action input, and is buffered for 8 frames during hit-stop.
- FR7: The HUD shows, faded, the window and combo name that `<<` and `>>` would produce, to the left and right of the active window. A window with no combo shows its two bit glyphs only.
- FR8: A harvested bit is appended to the right of the last owned slot. Fight-start registers are `[D, A]` (Boss 1), `[A, D, L]` (Boss 2) and `[A, D, L, N]` (Boss 3).
- FR9: The HUD shows the register's byte value in hex (`0x03` → `0x07` → `0x0F`; `0xFF` at the ending).

**Bits (solo actions)**

- FR10: ATTACK (`A`) — Slash: 120° arc, 1.5-tile range, 6/4/12 frames, damage 10/10/15. Pressing again in the last 8 frames of recovery chains up to 3 hits.
- FR11: DASH (`D`) — Dash: 4 tiles in the facing direction, 0/10/6 frames, invulnerable on frames 1–8, 24-frame cooldown.
- FR12: LOOP (`L`) — Echo: re-executes the last solo bit action performed (not a combo, not Echo) at the player's current position, at 70% damage rounded half up (10 → 7, 15 → 11). Echo of a whiffed action still executes. With no prior action it does nothing and triggers no cooldown. Cooldown 90 frames.
- FR13: NULL (`N`) — Null Dodge: intangible for 30 active frames (0/30/8), move speed ×0.5, cooldown 120 frames. Clean Catch: if an attack passes through the player during it, the next damaging action deals ×1.5 on top of the boss's damage state.
- FR14: Every player action can be cancelled into DASH or Null Dodge during its recovery.

**Combos**

- FR15: A combo triggers when Action 2 is pressed during Action 1's active frames or within 18 frames after them; Action 2 is replaced by the window's combo. Combos are ordered and looked up by ordered window from data; the replaced action's bit cooldown applies as normal.
- FR16: Dash Strike (A→D): 0/12/8 frames, invulnerable on frames 1–10, a 5-tile dash dealing 20 to every target passed through.
- FR17: Echo Dash (D→L): a second, redirectable 4-tile dash, 0/10/6 frames, with continuous invulnerability from the first dash through frame 10 (no gap).
- FR18: Ghost Echo (L→N): 30 frames of intangibility (0/30/8) and an intangible decoy left at the start point for 120 frames. Bosses target the decoy.
- FR19: Dereference (N→A): a 3-tile piercing thrust, 2/8/14 frames, 30 damage (×1.5 with Clean Catch), staying intangible through its active frames. It must be pressed during Null Dodge's active frames.
- FR20: Windows with no combo (D→A, L→A): J then K performs both solo actions. If K is pressed during J, it is buffered and executes when J ends.

**Weak window, Patched and damage**

- FR21: Each boss phase has one weak window (an ordered pair, combo or no-combo). Completing it so that it affects the boss applies Patched for 180 frames. "Affects the boss" means: a damaging combo hits it; a no-combo pair's Action 2 hits it; Echo Dash passes through its hurtbox; the boss strikes the Ghost Echo decoy. Re-applying refreshes the duration, and the Patching hit itself counts as Patched.
- FR22: Damage states: Unpatched ×0.5 (default), Patched ×1.5 (crit), Clean Catch ×1.5 on top of either (×0.75 / ×2.25). All multipliers (Echo 70%, damage state, Clean Catch) multiply together and the result rounds half up once. The practice target always takes base damage (×1) and is never Patched.
- FR23: While Patched, a `// patched` tag and a countdown bar float above the boss, and stay visible while the boss is invisible. Applying Patched plays a rising chime.

**Skills**

- FR24: Breakpoint (Space): freezes the simulation for up to 120 real frames while shifting stays allowed; ends early on any action input; 12 s cooldown. The screen dithers to 50% ink with a red breakpoint dot and line, and audio switches to the muffled loop. Unlocked after Boss 1; the first use is free. It cannot be chained, and its cooldown is shown on the HUD.
- FR25: Watch (hold R): reveals hidden entities (Null Pointer, decoys), highlights the current weak window on the HUD, shows the next attack's name above the boss and the boss's bits (drop bit + weak window). While held: move speed ×0.5 and no actions. Available from Boss 2.

**Hit feedback (juice)**

- FR26: Hit-stop values and precedence: crit 8 > the combo's own value (Dash Strike 6, Dereference 8) > unpatched hit 3; Patched applied 4; player hit 4; boss defeated 20; shift 0.
- FR27: Hit feedback per state. Resisted (unpatched): half the glyph particles, smaller damage glyphs, a dithered `console.log("-5") // resisted` log line and a dull thud. Crit (Patched): log line in CAPS (`CRITICAL: 15 dmg`) and 1 frame of full-screen colour inversion. Combo hit: plus a 2-px shake for 6 frames. Player hit: `WARN: hp--`, a 3-px shake and the invulnerability blink.
- FR28: Shift juice: the HUD register slides over 6 frames with an overshoot bounce, a mechanical key-click SFX (distinct for `<<` and `>>`) plays, and the weapon inverts for 4 frames. Feedback starts on the input frame.
- FR29: Boss glyph jitter rises in steps at 66% and 33% HP. On defeat, the boss's glyphs reassemble into its fixed line and the duck squeaks.

**Boss framework**

- FR30: Each boss has HP, phases at fixed HP thresholds and an attack pool per phase. The next attack is random from the pool, never the same attack 3 times in a row, separated by a fixed gap. Each attack has tell, active and recovery states. A phase change resets the speed ramp, plays a 60-frame glitch-roar and gives no damage window.
- FR31: Every boss attack has a visible and audible tell of ≥ 20 frames (audible = the boss's tell cue at tell start; SIGSEGV uses its alarm; D-049). Attacks aim only at the arena's current target (the player, or a live Ghost Echo decoy). Telegraphed areas are drawn at their exact final size; boss hitboxes match their glyph cells; no attack comes from off-screen.
- FR32: The HUD names each boss as a function signature, e.g. `void infiniteLoop() // hp 400`.

**Boss 1 — Infinite Loop**

- FR33: Body: a closed ring of 24 `{ }` segments (radius ≈ 3.8 tiles) spinning in place and drifting toward the player at 2 tiles/s, with an `i = 0` counter above it. A `;` (the loop condition) travels around the ring and opens for 90 frames once per lap as `i++` ticks; the open `;` is the only damageable point. Spin 8 tiles/s (+5% per lap, capped at 12 tiles/s). HP 400; drops LOOP; fixed line `for (i = 0; i < n; i++) { }`. The ring stays still until the player's first shift.
- FR34: Phases: P1 (100–66%) weak window A→D, gap 120; P2 (66–33%) weak window D→A (no combo), gap 90; P3 (33–0%) outer ring `;` A→D and inner ring `;` D→A, gap 60.
- FR35: Attacks: Head Rush (P1–3; tell 30, active 40, a 10-tile charge, recovery 45 with `;` open); Constrict (P2–3; tell 40 with the final outline drawn, active 60 re-centring on the player and shrinking to a 2-tile radius, recovery 120 with `;` open; must be escaped with an invulnerable move); `;` Spit (P3; tell 20, a 6 tiles/s projectile every 6 s).
- FR36: Nested Loop (P3, once at phase start; tell 40): splits into an outer ring (16 segments, radius ≈ 2.5) and an inner ring (8 segments, radius ≈ 1.3), with inner spin at 1.5× the outer, capped at 12 tiles/s. In P3 the `;` openings follow a fixed timer: one every 3 s, alternating outer/inner, 90 frames each, at most one open at a time; `i++` ticks on each opening.

**Boss 2 — Null Pointer**

- FR37: Body: a ghost of `null` glyphs, invisible except during attack active/recovery frames, while Watch is held, during a 10-frame flicker when hit, and for 60 frames after Echo Dash passes through it. A column of 3–5 falling `null` glyphs drifts under it, and a looping hum is panned by its position. Invisible idle drift at 4 tiles/s. HP 700; drops NULL; fixed line `if (ptr != null) ptr.deref();`.
- FR38: `NullPointerException`: an ATTACK slash that hits nothing while the boss is within 4 tiles stuns the player for 20 frames. Hitting a decoy dispels it and never stuns.
- FR39: Phases: P1 (100–50%) weak window D→L, gap 90; P2 (50–0%) weak window A→D, gap 60. Attacks: Pointer Grab (P1–2; tell 40 with a `*` behind the player, active 10, recovery 60 visible); Null Rain (P1–2; tell 45 with 5 marked 2×2 areas, active 20, recovery 40 visible); Dangling Pointers (P2; tell 30, spawns 2 decoy ghosts re-cast every 15 s, recovery 30). Only the real ghost hums and shows in Watch.

**Boss 3 — Segfault**

- FR40: Body: a glitch dragon of `▓▒░#@!` glyphs, ≈ 6 × 4 tiles, staying in the top third of the arena and moving at 2 tiles/s. HP 1000; no drop; its defeat triggers the ending; fixed line `if (idx < len) buf[idx] = val;`.
- FR41: Phases: P1 (100–66%) weak window D→L, gap 90; P2 (66–33%) N→A, gap 75; P3 (33–0%) L→N, gap 60.
- FR42: Attacks: Access Violation (P1–3; tell 30 with the claw arc drawn, active 12, a 6-tile sweep, recovery 50); Corrupt Memory (P1–3; tell 60 with 8–12 tiles marked `░`, active 240 as `▓` hazard dealing 1 HP on entry, recovery 40); Core Dump (P3; tell 60 with a checkerboard marked and safe tiles visible, active 180, recovery 60).
- FR43: SIGSEGV (P2–3): 60-frame tell (HUD flashes red with `SIGSEGV incoming` and a rising alarm), then the player's register is rotated by 2 slots, then a guaranteed 90-frame recovery ("dumping core"; 150 frames if Breakpoint is cut). It is always telegraphed, always followed by its recovery and never overlaps another attack's active frames.
- FR44: *(Cut ladder #1)* Reserved Write (P3): 45-frame tell (the `reserved` nibble flashes), then a garbage bit `?` is inserted into the ring for 600 frames; its solo action and combos are NOP; recovery 30.

**Duck (hint system)**

- FR45: The duck speaks in one-line text bubbles with a squeak on open and a typewriter reveal synced to a mumble-speech gibberish voice (D-046; text shows silently if the voice is unavailable). There are exactly 10 hand-written lines, each with a trigger, per the GDD Duck table (intro; T1–T4 tutorial beats; Boss 2 Breakpoint and Watch tutorials; one shared harvest line; ending; the hint template).
- FR46: The hint template `"Quack. Weak window: {X→Y}."` is filled with the current phase's weak window. It fires on Breakpoint activation (at most once per phase) and on the 3rd death against the same boss. In Boss 1 phase 3 it names the window of the ring whose `;` opens next.

**Flow, screens and persistence**

- FR47: Title screen with press-to-start. No audio plays before the first input; every input unlocks audio. Option hotkeys (`[N]` new run when a save exists, `[P]` practice, `[B]` debug build, `[F]` fullscreen) and clicks on option labels act on that option only; any other key or click starts (or continues) the run, starts the 30-s first-shift clock and leads straight into the Intro without skipping it (D-048).
- FR48: Intro: three glyph panels (developer at a desk at 2 a.m.; squeezing the duck; the screen tearing into glyphs and landing in The Clearing, with duck line 1), ≤ 8 s in total, skippable from its first frame with any key or click.
- FR49: Death: when player HP reaches 0 the screen shows `Process exited with code 1`; any new key press or click made ≥ 20 frames after death restarts the same fight within 2 s with full player HP, full boss HP and the register as it was at the start of that fight. No game-over and no lives.
- FR50: Harvest: the defeated bug's glyphs reassemble into its fixed line, the bit flies into the register, the HUD shows the new windows, and the shared harvest duck line plays. ≤ 8 s, skippable after 2 s.
- FR51: Ending: the reserved nibble lights up `1111`, the developer is back at the desk with the duck, the commit message reads `fix: wild shift`, duck line 9 plays, then credits. ≤ 30 s. *(Stretch: clear-time and hits-taken summary.)*
- FR52: Run sequence: Intro → Infinite Loop → Null Pointer → Segfault → Ending, no level select; full HP restored and cooldowns reset whenever a fight starts (after Harvest, on resume, on retry).
- FR53: The highest boss reached is saved at fight start and the run resumes there across browser sessions when storage is available; on storage failure the game silently runs without persistence.
- FR54: Esc opens a pause screen that shows the controls and the options `[Esc]` resume, `[F]` fullscreen, `[B]` debug build (Should) and `[M]` mute (Should; Master bus, persisted). Tab or focus loss auto-pauses; play resumes only on an explicit input.
- FR55: A fullscreen option (`[F]` hotkey or click on its label) on the title and pause screens triggers fullscreen from an input event. The itch.io embed is 1280×720 (2× integer scale).

**Arena and HUD**

- FR56: The Clearing (labelled `stack frame 0x03`): a fantasy hunting ground drawn in glyphs (trees `♣`, grass `"`, rocks `o`, a stream of `~`), decorative only, with a per-boss sky comment (`// TODO: this should terminate`, `// FIXME: who owns this pointer?`, `// HACK: do not read past this line`). Collision never changes.
- FR57: IDE HUD laid out per the GDD's HUD Layout wireframe (D-047: HUD text at 1× on an 8-px grid, 80×45 cells; world glyphs at 2×): register panel on the left (8 bits with `reserved` nibble, shift previews, hex value, active combo name and a `J→K` glyph, cooldowns), log panel at the bottom (crits in CAPS, resisted lines dithered with `// resisted`), line numbers down the left edge, boss signature header.

**Options, practice and input**

- FR58: Controls: Move WASD/arrows, Action 1 J, Action 2 K, Shift `<<` Q, Shift `>>` E, Breakpoint Space, Watch hold R, Pause Esc. The Shift keys are never used. Input buffer of 8 frames for actions and shifts. No remapping.
- FR59: Practice target `/* test */`: infinite HP, no attacks, per-hit damage log and frame counter, base damage. Used for development tuning; *(Should)* offered to players from the title screen.
- FR60: *(Should)* "Debug build" assist toggle on the title and pause screens: player HP 8, Breakpoint cooldown 6 s, tells ×1.5. It does not change the ×0.5 unpatched multiplier, is labelled neutrally and carries no penalty.
- FR61: *(Should)* Gamepad support per the GDD mapping (left stick/D-pad, X/Square, A/Cross, LB/L1, RB/R1, RT/R2, Y/Triangle, Start).

**Audio**

- FR62: Music (BeepBox chiptune, looping): 4 tracks (title + intro, Boss 1, Boss 2, Boss 3), 3 pre-rendered glitch variants each crossfaded in at that boss's phase 3, and 1 pre-rendered muffled loop for Breakpoint. No live audio effects.
- FR63: About 20 SFX (jsfxr). Must: shift click distinct per direction, hit, resisted thud, Patched chime, duck squeak, SIGSEGV alarm; plus one glyph-glitch sound per boss.

**Release**

- FR64: itch.io page leading with action combat: cover GIF of a shift into a Dash Strike crit, the line "shift your weapon's bits mid-fight", the full title, controls, AI-use disclosure and asset credits. README with the same disclosure and credits. Public GitHub repo. Submitted to Game Off.

### NonFunctional Requirements

- NFR1: Performance — 60 FPS sustained in Chrome and Firefox (latest) on a 2020-era mid-range laptop with integrated graphics at 1280×720, measured over Segfault phase 3.
- NFR2: Performance — at most 300 glyph particles live at any time.
- NFR3: Load — title screen interactive in ≤ 10 s on a 50 Mbps connection with a cold cache.
- NFR4: Build size — web build ≤ 32 MB uncompressed (raised from 30 MB on 2026-11-10, see deferred-work.md) (stripped export template if needed).
- NFR5: Responsiveness — no added input latency beyond the browser/engine baseline; 0-frame shift with feedback on the input frame; retry after death in ≤ 2 s.
- NFR6: Display — 640×360 base resolution, integer-scaled (pixel-perfect), Nearest filtering.
- NFR7: Compatibility — Chrome and Firefox fully supported; Safari playable (cosmetic WebGL2 quirks accepted); no mobile; no crash in Safari over a full run.
- NFR8: Readability (Pillar 2) — 1-bit palette ink `#E8E8E8` on `#101014`; inversion and 50% dither are the only extra states; red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV); one monospace pixel font on a 16-px grid; no damage without a tell.
- NFR9: Session length — a first-time full run takes 10–15 minutes including deaths; per-boss first-clear targets 60–120 s / 120–150 s / 150–210 s.
- NFR10: Onboarding — the first shift happens within 30 s of the first title-screen input, intro included.
- NFR11: Reliability — zero blocking bugs across 3 consecutive full runs before submission; the game never shows an error to the player.
- NFR12: Robustness — environment failures (storage blocked in iframes, audio not unlocked, voice unavailable, fullscreen refused) degrade silently.
- NFR13: Tunability — all HP, damage and timing values are first-pass, data-driven and re-tuned after the Nov 14 playtest. The ×0.5 / ×1.5 multipliers are not tuning levers. Tuning order: boss HP → tell → recovery → gap → player HP.
- NFR14: Playtest targets — ≥ 80% Patch Infinite Loop with Dash Strike unprompted; ≥ 80% clear Boss 1 within 3 attempts; shift feel ≥ 4/5; ≥ 50% mention the shift/register unprompted.
- NFR15: Licensing — assets CC0 preferred, CC-BY accepted with credits, no NC/ND; credits in README and on itch.io.
- NFR16: Schedule — epics strictly sequential with non-overlapping windows; every epic ends with a web build on the itch.io draft page and a Chrome/Firefox smoke test; MVP playtest gate Nov 14 (≥ 3 people); submission by 2026-11-29 12:00 PST; cut ladder applied if an epic overruns by > 1 day; Boss 1 fallback = phases 1–2 only.
- NFR17: Localisation — English only.

### Additional Requirements

**Project setup (no starter template → Epic 1 Story 1)**

- Create an empty Godot **4.7.2-stable** project in `game/` (`res://` = `game/`): Compatibility renderer; viewport 640×360, stretch `viewport`, aspect `keep`, scale mode `integer`; physics ticks 60; default texture filter Nearest; web audio playback `Sample`; `untyped_declaration` warning = error.
- "Web" export preset: Thread Support off, Extensions Support on (non-threaded dlink template, required by mumble-speech), VRAM compression desktop only; exclude `addons/gut`, `tests/`, `tools/` and the GoPeak runtime addon.
- Domain-first folder structure per the architecture (`src/<domain>`, `data/<domain>`, `assets/`, `tests/{unit,integration,replays}`, `tools/`).
- Autoload stubs: `EventBus`, `SimClock`, `Game`, `Log`, `Debug`, `AudioManager`, `VoiceService`, `SaveService`; persistent `main.tscn` (Arena + HUD).
- Deployment to the itch.io draft page with `butler`; CI on GitHub Actions running GUT headless and the web export.
- Day-1 smoke tests: web export on Chrome/Firefox/Safari and build size; `AudioStreamPlayer2D` panning in Sample mode (fallback: `playback_type = Stream` on the hum node only); GUT 9.6.1 on Godot 4.7.2 headless (fallback gdUnit4 6.x) (I-7).
- Optional dev tooling: GoPeak MCP (`npx -y gopeak`) and editor/runtime addons; Context7 for Godot 4.7 docs.

**Simulation core**

- AD-01 `SimClock`: one fixed 60 Hz `tick()` from `_physics_process`; fixed order Input → shifts → actions → player → boss/hazards → PlayerEffects → CombatResolver → timers. Gates: pause > Breakpoint > hit-stop. Register shifts apply during Breakpoint; buffered during hit-stop. Hit-stop via `SimClock.request_hitstop(frames)` (max per tick wins). Only `SimClock` calls `tick()`; no `delta`, `Timer`, `await`, Tweens or `Engine.time_scale` in simulation.
- `InputSource` abstraction (`LiveInput`, `ReplayInput`) and an `InputBuffer` (8-frame press lifetime, consumed once).
- AD-02/AD-03 data: typed `Resource` defs saved as `.tres` — `ActionDef`, `BitDef`, `ComboDef`, `ComboTable`, `BossDef`, `PhaseDef`, `AttackDef`, player def, `FeatureFlags`, debug config. Defs read-only at runtime; each implements `validate()`; a GUT test validates every `.tres` under `res://data/`. Global catalogues preloaded in `Defs`.
- NP-1 `ActionResolver` (pure) as the only J/K resolution path, with `LinkState`, `ActionStateMachine` (IDLE/MOVE, STARTUP, ACTIVE, RECOVERY, STUNNED, WATCHING) and `Cooldowns`. Design calls: any shift closes the link; a combo whose second bit is on cooldown stays buffered 8 frames then drops; the ATTACK chain continues with the same button that started it and resets on shift; same-frame J+K resolves J first.
- AD-04 hit detection: custom shapes (`HitCircle`, `HitArc`, `HitCapsule`) resolved by a single `CombatResolver` inside `tick()`; no `Area2D`/physics bodies for gameplay; walls are a clamp.
- `DamageCalc.compute()` is the only producer of damage numbers (multiply all factors, `floori(x + 0.5)` once).
- NP-4 `WeakWindowTracker` is the only writer of Patched; interactions `HIT`, `PASS_THROUGH`, `DECOY_STRUCK`; Patched is applied before the patching hit's damage; the boss provides `current_weak_window()` dynamically.
- NP-5 `EchoMemory`: stores the exact last solo `ActionDef` (not combos, Echo, NOP, or actions cancelled in startup); cleared on fight start and retry.
- NP-2 Breakpoint: counts real frames (≤ 120); the ending action executes on the first unfrozen tick; cooldown starts at the end and counts sim frames (720; 360 with assist); remaining hit-stop resumes afterwards.
- NP-3 boss → player effects: bosses push `PlayerEffects` commands (`RotateRegister`, `InsertTemporaryBit`) applied at one fixed tick point; `AttackDef.exclusive` for SIGSEGV; `recovery_if_no_breakpoint`.
- AD-06 boss framework: `BossController` base + one `BossAttack` script per attack (`on_tell/on_active/on_recovery`), per-boss body node, `ArenaContext`; enum + `match` FSMs with int counters.
- Determinism: one seeded `RandomNumberGenerator` in `SimContext.rng`, reseeded at fight start; no global `randi()/randf()`.
- Pools allocated at fight start, no allocation in `tick()`: particles 300, `;` projectiles 16, corrupted tiles as a 32×18 grid, log lines as a ring buffer. Pool full → drop silently.

**Flow, state and persistence**

- AD-08: persistent `Main` scene; `Game` autoload FSM (TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING); bosses/screens instanced and freed; `RunState` snapshot on FIGHT enter, `retry()` restores it (register without temporary bits, full HP, Echo memory and link cleared, rng reseeded); `RunState.deaths_on_boss` for the 3rd-death hint.
- Pause uses `SimClock.paused` (not `SceneTree.paused`); `Game` handles Esc and `NOTIFICATION_APPLICATION_FOCUS_OUT`.
- AD-10 `SaveService`: `ConfigFile` at `user://save.cfg` with `version`, `highest_boss`, `assist`; write on fight start and assist toggle; read at boot; any failure → in-memory only.
- AD-13: preload all assets at boot; no runtime `load()`.

**Presentation**

- AD-05 typed `EventBus` (all signals declared only in `event_bus.gd`, past tense, typed args); presentation is read-only; flow requests go through `Game` methods.
- AD-07 rendering: glyphs via `draw_char`/`draw_string` in `_draw()`; one pooled particle node with a single `_draw`; one full-screen `ScreenFX` shader (`invert`, `dither`) driven only by `JuiceDirector`; shake via `Camera2D.offset`; `Palette` constants; layers Arena → Entities → Particles → HUD → ScreenFX.
- AD-09 `AudioManager`: buses Master → Music/SFX/Voice, no bus effects; two music players crossfaded; pooled SFX players; requests via EventBus; nothing plays before the first input.
- AD-14 duck voice: `VoiceService` wraps mumble-speech (runtime on web via GDExtension; release pinned before Epic 3, I-6) driving a `MumbleTypewriter` in `DuckBubble`; squeak on bubble open; hint template rendered at runtime. Contingency: pre-render backend (EditorScript renders the known clips). Credit mumble-speech in README and itch.io.

**Cut ladder, tooling and quality**

- AD-12 `FeatureFlags` (`reserved_write`, `watch`, `breakpoint`, `segfault`); cuttable modules are leaf folders registered at startup and never referenced by class from core code; GDD fallbacks (stronger Null Pointer tells, SIGSEGV 150-frame recovery, ending after Null Pointer) read the flags.
- Logging via `Log` autoload only: `[f=<sim_frame>][LEVEL][tag] msg`; no per-frame logging; no bare `print`.
- Error handling: `assert` + `Log.error` + safe default for data errors; `Log.warn` once + silent fallback for environment errors.
- Debug tools (only in debug builds or with `?debug`): F1–F5 jump to screens, F6 kill boss / Shift+F6 next phase, F7 invincibility, F8 grant next bit, F9 frame overlay, F10 perf overlay, F11 input recording; recordings replay bit-identically in GUT (`tests/replays/`).
- Testing: GUT unit tests for register, combo table, `ActionResolver`, `DamageCalc`, input buffer, action FSM, boss controller, data validation; integration tests for fight flow and retry snapshot; GDD worked numbers as test cases. Simulation runs headless without a scene tree.
- CI checks: grep for `Timer.new`/`await` under simulation folders and bare `print`.
- Naming conventions per architecture (`snake_case` files, `*_def.gd`, `_frames`/`_tiles` suffixes, `StringName` ids, `BitId` enum).

**Design calls confirmed by the designer (GDD D-045, D-046, v1.1)**

- Any shift closes the combo link; cooldown-blocked combo buffered 8 frames then dropped; ATTACK chain continues with the same button and resets on shift; Breakpoint cooldown starts at its end in sim frames; Echo ignores actions cancelled in startup; duck voice = squeak + mumble-speech voice with typewriter reveal (GDD delta).

### UX Design Requirements

No UX design document exists for this project. The HUD cell layout is the GDD's Art Style → HUD Layout wireframe (D-047); title and pause interaction is GDD D-048. HUD, screen and feedback requirements are taken from the GDD and captured as FR4–FR9, FR23, FR26–FR29, FR32, FR47–FR51, FR54–FR57.

### FR Coverage Map

- FR1: Epic 2 — 8-direction movement and facing
- FR2: Epic 2 — player hurtbox, 5 HP, post-hit invulnerability
- FR3: Epic 2 — arena clamp, contact damage (boss bodies exercised from Epic 3)
- FR4: Epic 2 — owned-bit ring, reserved nibble
- FR5: Epic 2 — active window → J/K
- FR6: Epic 2 — Q/E shift, 0 frames, hit-stop buffering
- FR7: Epic 2 — shift previews
- FR8: Epic 2 (fight-start registers) / Epic 3 (harvest insertion)
- FR9: Epic 2 — register hex value
- FR10: Epic 2 — ATTACK slash and 3-hit chain
- FR11: Epic 2 — DASH
- FR12: Epic 4 — LOOP / Echo
- FR13: Epic 5 — NULL / Null Dodge and Clean Catch
- FR14: Epic 2 — cancels into DASH / Null Dodge
- FR15: Epic 2 — combo engine and link window
- FR16: Epic 2 — Dash Strike
- FR17: Epic 4 — Echo Dash
- FR18: Epic 6 — Ghost Echo
- FR19: Epic 6 — Dereference
- FR20: Epic 2 — no-combo windows
- FR21: Epic 3 — weak window → Patched (Echo Dash and decoy cases completed in Epics 4 and 6)
- FR22: Epic 2 (DamageCalc, ×1 practice target) / Epic 3 (Unpatched/Patched states; Clean Catch factor wired in Epic 5)
- FR23: Epic 3 — Patched tag, bar, chime
- FR24: Epic 4 — Breakpoint (free first use and tutorial line in Epic 5)
- FR25: Epic 5 — Watch
- FR26: Epic 2 — hit-stop table and precedence
- FR27: Epic 2 (hit/combo/player-hit feedback) / Epic 3 (resisted vs crit)
- FR28: Epic 2 — shift juice
- FR29: Epic 3 — boss jitter and defeat reassembly
- FR30: Epic 3 — boss framework
- FR31: Epic 3 — tell rules (applies to every boss thereafter)
- FR32: Epic 3 — boss signature header
- FR33: Epic 3 — Infinite Loop body
- FR34: Epic 3 — Infinite Loop phases
- FR35: Epic 3 — Head Rush, Constrict, `;` Spit
- FR36: Epic 3 — Nested Loop and phase-3 timer
- FR37: Epic 5 — Null Pointer body
- FR38: Epic 5 — NullPointerException whiff stun
- FR39: Epic 5 — Null Pointer phases and attacks
- FR40: Epic 6 — Segfault body
- FR41: Epic 6 — Segfault phases
- FR42: Epic 6 — Access Violation, Corrupt Memory, Core Dump
- FR43: Epic 6 — SIGSEGV and fairness rules
- FR44: Epic 6 — Reserved Write (cut ladder #1)
- FR45: Epic 3 (duck system, lines 2–5 and 8) / Epic 5 (lines 6–7) / Epic 6 (lines 1, 9; full 10-line audit)
- FR46: Epic 4 — hint template and both triggers
- FR47: Epic 1 — title press-to-start
- FR48: Epic 6 — Intro panels
- FR49: Epic 2 — death screen and ≤ 2 s retry
- FR50: Epic 3 — Harvest screen
- FR51: Epic 6 — Ending
- FR52: Epic 1 (placeholder flow) / filled by Epics 3–6
- FR53: Epic 7 — save and resume
- FR54: Epic 1 — pause and auto-pause
- FR55: Epic 7 — fullscreen button
- FR56: Epic 1 — The Clearing layout (per-boss sky comments added with each boss)
- FR57: Epic 1 (HUD shell) / Epic 2 (register panel, log panel) / Epic 3 (boss header)
- FR58: Epic 2 — keyboard controls and input buffer (InputMap created in Epic 1)
- FR59: Epic 2 (dev practice target) / Epic 7 (title-screen access, Should)
- FR60: Epic 7 — assist toggle (Should)
- FR61: Epic 7 — gamepad (Should)
- FR62: Epic 7 — music
- FR63: Epic 2–3 (Must SFX placeholders) / Epic 7 (full SFX pass)
- FR64: Epic 7 — itch.io page, README, submission

NFRs: NFR6, NFR12, NFR16 are set up in Epic 1 and enforced at every epic's deploy; NFR5, NFR8, NFR13 are established in Epic 2; NFR10 and NFR14 are measured at the Epic 3 MVP playtest; NFR1–NFR4, NFR7, NFR9, NFR11, NFR15, NFR17 are verified and closed in Epic 7.

## Epic List

**Definition of Done (every epic):** all its stories meet their ACs; GUT and CI green; a release web build deployed with `butler` to the itch.io draft page; smoke-tested in Chrome and Firefox (title → the epic's new content) with build size recorded in the story notes. (NFR16)

### Epic 1: Web Foundation (Nov 6–7)
The player opens the game on the itch.io draft page: a title screen with press-to-start (which unlocks audio), The Clearing arena inside the IDE HUD frame, placeholder scene flow, and pause/auto-pause. Dev foundation: Godot 4.7.2 project, Web preset, autoload stubs, GUT + CI, butler deploy, debug screen keys, day-1 smoke tests.
**FRs covered:** FR47, FR52 (placeholders), FR54, FR56, FR57 (shell)

### Epic 2: Player Core & Register (Nov 8–10)
In an empty arena, the player moves, rotates the register with full shift juice, slashes (3-hit chain), dashes and fires Dash Strike; takes damage, dies and retries in ≤ 2 s; and checks frame data and damage on the practice target.
**FRs covered:** FR1–FR7, FR8 (fight-start registers), FR9, FR10, FR11, FR14, FR15, FR16, FR20, FR22 (base), FR26, FR27 (base), FR28, FR49, FR58, FR59 (dev), FR63 (Must SFX placeholders)

### Epic 3: Infinite Loop (MVP) (Nov 11–14)
A complete vertical slice: the player beats a three-phase Infinite Loop, learns Patched and the ×0.5/×1.5 damage states from the voiced duck tutorial, sees the Harvest and receives LOOP. MVP playtest gate on Nov 14; fallback ships phases 1–2 only.
**FRs covered:** FR8 (insertion), FR21, FR22, FR23, FR27 (states), FR29–FR36, FR45 (lines 2–5, 8), FR50, FR57 (boss header)

### Epic 4: LOOP Combos & Breakpoint (Nov 15–17)
With the 3-bit ring, the player uses Echo and Echo Dash, freezes time with Breakpoint to shift calmly, and gets the "Weak window" hint from Breakpoint and on the 3rd death.
**FRs covered:** FR12, FR17, FR24, FR46

### Epic 5: Null Pointer & Watch (Nov 18–21)
The player hunts an invisible boss using Watch, sound and the `null` trail, avoids decoys and the whiff stun, and earns NULL (Null Dodge + Clean Catch).
**FRs covered:** FR13, FR25, FR37, FR38, FR39, FR45 (lines 6–7)

### Epic 6: Segfault, Intro & Ending (Nov 22–25)
A complete framed run from Intro to Ending: Ghost Echo and Dereference, the final boss with corrupted tiles, SIGSEGV and Reserved Write (cut #1), and all game text.
**FRs covered:** FR18, FR19, FR40–FR44, FR45 (complete), FR48, FR51

### Epic 7: Audio, Polish & Submission (Nov 26–29)
A jam-ready release, submitted: music and the full SFX pass, save/resume, assist toggle, fullscreen, (Should) gamepad and title-screen practice target, browser matrix and performance check, itch.io page and README; submitted by Nov 29 12:00 PST.
**FRs covered:** FR53, FR55, FR59 (title), FR60, FR61, FR62, FR63 (full pass), FR64

## Epic 1: Web Foundation

The player opens the game on the itch.io draft page: a title screen with press-to-start (which unlocks audio), The Clearing arena inside the IDE HUD frame, placeholder scene flow, and pause/auto-pause. Every later epic builds on this running web build. Window: Nov 6–7.

### Story 1.1: Godot Project Skeleton with Pixel-Perfect 60 Hz Setup

As a developer,
I want an empty Godot 4.7.2 project configured exactly as the architecture prescribes,
So that every later story starts from the same pixel-perfect, fixed-60 Hz, statically typed foundation.

**Requirements:** NFR6; Additional: project setup (no starter template)

**Acceptance Criteria:**

**Given** a fresh clone of the repo
**When** I open `game/project.godot` in Godot 4.7.2-stable
**Then** the project uses the Compatibility renderer, viewport 640×360, stretch mode `viewport`, aspect `keep`, scale mode `integer`, default texture filter Nearest, physics ticks 60 and web audio playback type `Sample`
**And** the `untyped_declaration` warning is set to error

**Given** the project
**When** I inspect the file tree
**Then** the domain-first folders from the architecture's Directory Structure exist under `game/` (`src/<domain>`, `data/<domain>`, `assets/`, `tests/{unit,integration,replays}`, `tools/`)
**And** `src/core/const.gd` (`class_name Const`: `TILE_PX = 16`, `SIM_HZ = 60`, base resolution, arena 32×18, `tiles_per_s_to_px_per_frame()`) and `src/core/palette.gd` (`INK #E8E8E8`, `BG #101014`, `WARN #FF4040`) exist

**Given** the project
**When** it boots
**Then** the autoloads `Log`, `EventBus`, `SimClock`, `Game`, `Debug`, `AudioManager`, `VoiceService` and `SaveService` are registered as typed stubs, and a persistent `main.tscn` is the main scene
**And** `Log` prints `[f=<sim_frame>][LEVEL][tag] msg` and is the only logging path (no bare `print`)
**And** `SimClock` increments `sim_frame` once per `_physics_process` and exposes `paused`

**Given** the game runs in a 1280×720 window
**When** I look at a test glyph drawn with the palette
**Then** pixels are crisp at 2× integer scale and the frame rate is 60 FPS

### Story 1.2: Test Framework and CI Pipeline

As a developer,
I want headless unit tests and a CI pipeline from day one,
So that AI-written frame logic is verified automatically on every push (I-7).

**Requirements:** Additional: testing (AD-11, I-7), CI checks

**Acceptance Criteria:**

**Given** GUT 9.6.1 installed in `game/addons/gut/`
**When** I run `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
**Then** a sample test in `tests/unit/` passes and the command exits 0
**And** if GUT fails on Godot 4.7.2, gdUnit4 6.x is installed instead and the fallback is recorded in the story notes and `project-context.md`

**Given** a push to GitHub
**When** the GitHub Actions workflow in `.github/workflows/` runs
**Then** it runs the tests headless with Godot 4.7.2 and performs a Web export, failing the build on any test failure or export error
**And** it fails if `Timer.new` or `await` appears under the simulation folders (`src/{input,register,player,combat,bosses,skills,arena}`) or a bare `print(` appears anywhere in `src/`

**Given** a failing test
**When** CI runs
**Then** the run is marked failed with the failing test name in the log

### Story 1.3: Web Export and itch.io Draft Deploy

As a developer,
I want a working web build on an itch.io draft page from day one,
So that web pitfalls surface immediately and every epic can end with a deploy.

**Requirements:** NFR4, NFR7, NFR16; Additional: web preset, day-1 smoke tests

**Acceptance Criteria:**

**Given** the "Web" export preset
**When** I inspect it
**Then** Thread Support is off, Extensions Support is on, VRAM compression is desktop-only, and `addons/gut`, `tests/`, `tools/` and any GoPeak runtime addon are excluded

**Given** a release Web export
**When** I upload it to the itch.io draft page with `butler` (command documented in README)
**Then** the build loads and shows the main scene in Chrome, Firefox and Safari (latest)
**And** the uncompressed build is ≤ 32 MB and its size is recorded in the story notes
**And** no SharedArrayBuffer/COOP/COEP headers are required

**Given** the deployed build
**When** I run the audio smoke test (a test `AudioStreamPlayer2D` panned left and right after a click)
**Then** the result of positional panning in Sample mode is recorded per browser; if it fails, the note states that Null Pointer's hum node will use `playback_type = Stream` (AD-09)

**Given** a mumble-speech release that includes basteez/mumble-speech#32 exists
**When** a test line is spoken in the deployed build after a click
**Then** the result in Chrome, Firefox and Safari and the build-size delta are recorded (I-6); if no release exists yet, that is recorded and the check moves to Story 3.7

**Given** the itch.io draft page
**When** I configure the embed
**Then** the viewport is 1280×720 (2× integer scale) with the fullscreen button enabled

### Story 1.4: Title Screen with Press-to-Start and Audio Unlock

As a player,
I want a title screen that starts the game on my first key press or click,
So that nothing blares before I interact and I move straight into the game.

**Requirements:** FR47

**Acceptance Criteria:**

**Given** the game has loaded
**When** the title screen appears
**Then** it shows the full title "The Debugger 0x03: Wild Shift" in the glyph font and a "press any key" prompt, and no audio plays

**Given** the title screen
**When** I press any key or click that is not an option hotkey (`N`, `P`, `B`, `F`) or a click on an option label
**Then** `Game` transitions TITLE → INTRO (emitting `EventBus.flow_state_changed`), `AudioManager` is unlocked and a test SFX plays on the `SFX` bus
**And** `Game` records the sim frame of this first input as the start of the 30-s first-shift clock (logged with `Log.info(&"flow", ...)`)
**And** that same input does not count as a skip of the Intro placeholder

**Given** the title screen
**When** I press an option hotkey or click an option label
**Then** audio is unlocked but the game does not start; options with no implementation yet are hidden and their keys start the game as normal keys do (options appear in 7.3, 7.4, 7.6, 7.7 — D-048)

**Given** `AudioManager`
**When** it initialises
**Then** buses `Master` → `Music`, `SFX`, `Voice` exist with no bus effects, and any play request before unlock is ignored with a single `Log.warn`

### Story 1.5: The Clearing Arena and IDE HUD Frame

As a player,
I want to see the fantasy clearing drawn in glyphs inside a debugger's IDE frame,
So that the code-as-fantasy look is clear from the first screen.

**Requirements:** FR56, FR57 (shell), NFR8

**Acceptance Criteria:**

**Given** the FIGHT placeholder screen
**When** the arena is drawn
**Then** a 32×18-tile play area at 16 px per tile shows trees `♣` as the boundary tree line, grass `"`, rocks `o` and a stream of `~`, labelled `stack frame 0x03`, all drawn with `draw_char`/`draw_string` in `_draw()` using one 8×8 CP437-style monospace pixel font at 2× (CC0/OFL, licence file in `assets/fonts/`; D-047)
**And** only the two palette colours are used

**Given** the HUD (`CanvasLayer`)
**When** it is shown
**Then** HUD text is drawn at 1× on an 8-px grid (80×45 cells) and the regions match the GDD HUD Layout wireframe exactly: arena at cells (16,2)–(79,37); top bar row 0 (boss signature + HP bar) and row 1 (sky comment); register panel cols 0–11 rows 2–21; duck bubble cols 0–11 rows 22–37; line numbers `01`–`18` in cols 13–15, one per tile row; log panel rows 38–44 (a header plus 6 lines)
**And** a debug grid overlay (F9) shows the cell grid so later stories can check placement
**And** the render layers are ordered Arena → Entities → Particles → HUD → ScreenFX (AD-07)

**Given** the arena
**When** a position outside the play area is passed to the arena's clamp function
**Then** it returns the nearest position inside the 32×18 rectangle (scenery has no collision)

### Story 1.6: Placeholder Scene Flow with Debug Jump Keys

As a developer,
I want the whole run sequence wired with placeholders and jump keys,
So that each screen can be reached and tested before its content exists.

**Requirements:** FR52; Additional: debug tools

**Acceptance Criteria:**

**Given** `Game`'s flow state machine (enum + `match`; TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING)
**When** I advance through placeholders with any key
**Then** the sequence is Title → Intro → Fight 1 → Harvest → Fight 2 → Harvest → Fight 3 → Ending, with `RunState.boss_index` tracking the current fight
**And** each placeholder screen shows its name and the boss index
**And** the Intro placeholder lasts ≤ 8 s and is skippable, so the Epic 3 first-shift metric (30 s, intro included) is representative

**Given** a debug build or the URL contains `?debug`
**When** I press F1–F5
**Then** the game jumps to Title / Fight 1 / Fight 2 / Fight 3 / Ending respectively
**And** in a release web build without `?debug` the keys do nothing and no debug node is instanced

**Given** a screen is left
**When** `Game` exits that state
**Then** its instanced scene is freed and the persistent `Main` (arena + HUD) remains

### Story 1.7: Pause Screen and Auto-Pause on Focus Loss

As a player,
I want the game to pause on Esc or when I switch tabs, showing the controls,
So that I never lose a fight to a background tab and can always check the keys.

**Requirements:** FR54, FR58 (InputMap)

**Acceptance Criteria:**

**Given** the `InputMap`
**When** I inspect it
**Then** actions exist for move (WASD + arrows), `action_1` (J), `action_2` (K), `shift_left` (Q), `shift_right` (E), `breakpoint` (Space), `watch` (R), `pause` (Esc), and no action is bound to the Shift keys

**Given** a fight
**When** I press Esc
**Then** `Game` sets `SimClock.paused = true` (not `SceneTree.paused`) and shows the pause screen listing all controls from the GDD table and the options `[Esc]` resume and `[M]` mute (`[F]` and `[B]` appear with 7.7 and 7.4)
**And** pressing Esc again or a "resume" input resumes play

**Given** the pause screen
**When** I press `M` or click its label
**Then** the `Master` bus is muted or unmuted, and the setting is kept for the session (persisted from 7.3) (D-048, Should)

**Given** a fight
**When** the browser tab or window loses focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`)
**Then** the game pauses and stays paused after focus returns until an explicit input
**And** `sim_frame` does not advance while paused

## Epic 2: Player Core & Register

In an empty arena, the player moves, rotates the register with full shift juice, slashes (3-hit chain), dashes and fires Dash Strike; takes damage, dies and retries in ≤ 2 s; and checks frame data and damage on the practice target. Goal: the shift feels great before any boss exists. Window: Nov 8–10.

### Story 2.1: Deterministic Sim Clock, Input Buffer and Replays

As a developer,
I want a fixed 60 Hz simulation tick fed by a buffered, replayable input source,
So that all frame data is exact, testable headless and reproducible from recordings (AD-01).

**Requirements:** FR6 (buffering), FR58 (buffer), NFR5; Additional: AD-01, determinism, input replay

**Acceptance Criteria:**

**Given** `SimClock`
**When** a physics frame runs
**Then** it polls the `InputSource` into the `InputBuffer`, evaluates gates in order paused > breakpoint (hook, inactive) > hit-stop, and otherwise ticks registered `SimSystem`s in the fixed order Input → shifts → actions → player → boss/hazards → PlayerEffects → CombatResolver → timers, then increments `sim_frame`
**And** `request_hitstop(frames)` keeps the maximum request within a tick; while hit-stop frames remain the world does not tick and the counter decrements once per physics frame

**Given** the `InputBuffer`
**When** a press is pushed at frame f
**Then** it is available until frame f + 8 and can be consumed at most once; unconsumed presses expire silently
**And** unit tests in `tests/unit/test_input_buffer.gd` cover expiry, single consumption and ordering

**Given** `SimContext`
**When** a fight starts
**Then** it carries one seeded `RandomNumberGenerator`, reseeded at fight start, and no simulation code uses global `randi()`/`randf()`

**Given** a debug build
**When** I press F11, play, and press F11 again
**Then** per-frame input is recorded to `user://replay_*.json` (printed to the console on web)
**And** `ReplayInput` replays it so a GUT test in `tests/replays/` reproduces the same final `sim_frame` state bit-identically

### Story 2.2: Player Movement and Facing

As a player,
I want fast, responsive 8-direction movement,
So that I can reposition instantly around the arena.

**Requirements:** FR1, FR3 (clamp)

**Acceptance Criteria:**

**Given** `data/player/player_def.tres` (speed 7 tiles/s, accel 4 frames, decel 3 frames, HP 5, post-hit invulnerability 60 frames, hurtbox 0.6 tiles)
**When** the game loads
**Then** the def's `validate()` returns no messages, and `tests/unit/test_data_validation.gd` loads every `.tres` under `res://data/` and asserts all `validate()` calls are empty

**Given** the player `@` (with `>o` duck companion) in the arena
**When** I hold a direction with WASD or the arrow keys
**Then** the player reaches 7 tiles/s (converted once via `Const.tiles_per_s_to_px_per_frame`) in 4 frames and stops within 3 frames of release, in 8 directions
**And** facing is set to the last movement direction and persists while idle

**Given** the player at the arena edge
**When** I keep moving outward
**Then** the position is clamped inside the 32×18 play area (no physics bodies are used)

**Given** movement code
**When** I review it
**Then** it runs only inside `tick()` with integer-frame logic and no `delta`

### Story 2.3: Register Ring, Shift and HUD Panel

As a player,
I want to rotate my bit register with Q and E and always see what each shift will give me,
So that I can read and rewire my weapon at a glance (Pillar 2).

**Requirements:** FR4, FR5, FR6, FR7, FR8, FR9

**Acceptance Criteria:**

**Given** `Register` with owned bits `[D, A]`
**When** I press Q (`<<`) or E (`>>`)
**Then** the ring of owned bits rotates one slot left or right in 0 frames, the active window is the 2 leftmost owned slots, and `EventBus.register_shifted(direction, window, register, &"player")` is emitted
**And** unowned slots are skipped, so every rotation yields two owned bits (no dead state)

**Given** a shift input during hit-stop
**When** hit-stop ends within 8 frames
**Then** the buffered shift is applied; if hit-stop lasts longer it expires

**Given** the register
**When** `insert(bit)` and `set_fight_start(bits)` are called
**Then** inserted bits are appended to the right of the last owned slot, and `[D, A]`, `[A, D, L]`, `[A, D, L, N]` can be set as fight-start registers
**And** `byte_value()` returns `0x03`, `0x07`, `0x0F` for 2, 3, 4 owned bits
**And** unit tests in `tests/unit/test_register.gd` cover rotation for 2/3/4 bits, previews and byte values

**Given** the HUD register panel
**When** the register changes
**Then** it shows 8 bits: the low nibble with owned bit glyphs (unowned as greyed `0`), the high nibble greyed and labelled `reserved`, the hex byte value, the active window highlighted, and faded previews of the `<<` and `>>` windows on either side showing their two bit glyphs (combo names are added in Story 2.6)
**And** the panel only reads state via `EventBus`/getters and never writes the register

### Story 2.4: Shift Juice

As a player,
I want every shift to slide, click and flash instantly,
So that shifting feels great and I want to do it constantly (Pillar 4).

**Requirements:** FR28, FR63 (placeholders)

**Acceptance Criteria:**

**Given** a shift
**When** `register_shifted` is emitted
**Then** on the same frame the HUD register starts a 6-frame slide with an overshoot bounce (presentation tween), the player's weapon glyph inverts for 4 frames, and a mechanical key-click SFX plays
**And** the click SFX is distinct for `<<` (`shift_left.wav`) and `>>` (`shift_right.wav`) — placeholder jsfxr sounds are acceptable, final pass in Epic 7

**Given** rapid shifts (e.g. 3 within 6 frames)
**When** the slide animation is still running
**Then** each new shift restarts the slide toward the latest state without lag or desync with the actual register

**Given** hit-stop or Breakpoint
**When** a shift is shown
**Then** the HUD animation continues in `_process` independently of the simulation (hit-stop verified here; Breakpoint verified in 4.3)
**And** no simulation state is written by the juice code

### Story 2.5: Action State Machine with ATTACK and DASH

As a player,
I want a 3-hit slash and an invulnerable dash on my active bits,
So that I have weighty attacks and an escape from the very first fight.

**Requirements:** FR10, FR11, FR14

**Acceptance Criteria:**

**Given** the geometry classes `HitCircle`, `HitArc` and `HitCapsule` in `src/combat/shapes/` (used by `ActionDef.hit_shape`) and `ActionDef` and `BitDef` resources (`bit_attack.tres`, `bit_dash.tres`, `slash_1..3.tres`, `dash.tres`) with `validate()`
**When** they load
**Then** Slash is 6/4/12 frames, 120° arc, 1.5-tile range, damage 10/10/15; Dash is 0/10/6 frames, 4 tiles, invulnerable on frames 1–8, cooldown 24 frames

**Given** the player `ActionStateMachine` (IDLE/MOVE, STARTUP, ACTIVE, RECOVERY, STUNNED, WATCHING as enum + counters) and the pure `ActionResolver`
**When** I press J or K with `A` or `D` in that slot
**Then** that slot's solo action starts with its exact frame data, facing the current direction, and its bit cooldown starts
**And** J/K are resolved only by `ActionResolver`; a press on a bit on cooldown stays buffered for 8 frames, then is dropped

**Given** a slash in its last 8 recovery frames
**When** I press the same button that started it and that slot still holds `A`
**Then** the chain continues to hit 2, then hit 3 (no hit 4); a shift resets the chain

**Given** any action in RECOVERY
**When** I press the slot holding DASH
**Then** the recovery is cancelled into the dash (cancel rule also accepts Null Dodge, used from Epic 5)

**Given** a debug build
**When** I press F9
**Then** a frame overlay shows sim frame, player FSM state and frame in state, cooldowns, and the player hurtbox and active hit shapes (the link window is added in Story 2.6)

**Given** `tests/unit/test_action_fsm.gd`
**When** it runs
**Then** it verifies S/A/R counts, dash invulnerability frames 1–8, cooldown blocking, chain timing and cancel-into-dash

### Story 2.6: Ordered Combo Engine and Dash Strike

As a player,
I want J then K on my active window to fire that window's combo,
So that the order of my bits matters and shifting unlocks new moves (Pillar 1).

**Requirements:** FR7 (combo names), FR15, FR16, FR20

**Acceptance Criteria:**

**Given** `ComboDef` and `combo_table.tres` keyed by ordered pair, with Dash Strike (A→D): 0/12/8 frames, invulnerable frames 1–10, 5-tile dash, 20 damage per target passed through
**When** the active window is `[A, D]` and I press K during Slash's active frames or within 18 frames after them
**Then** K is replaced by Dash Strike and DASH's cooldown applies
**And** a K pressed during J's startup is evaluated when J's active frames begin

**Given** the active window `[D, A]` (no combo)
**When** I press J then K within the link window
**Then** I get a dash followed by a slash flagged `link_second = true`; if K is pressed while the dash cannot be cancelled, it stays buffered and executes when the dash ends

**Given** a link is open
**When** I shift before pressing K
**Then** the link closes and K performs the new window's solo action (design call NP-1 #1)

**Given** a combo whose second bit is on cooldown
**When** I press K in the link window
**Then** the press stays buffered for 8 frames and is then dropped, with no partial execution (design call NP-1 #2)

**Given** J and K pressed on the same frame
**When** resolved
**Then** J resolves first and K is evaluated on the next tick against the newly opened link

**Given** the HUD
**When** the active window has a combo
**Then** the register panel shows the combo name and a `J→K` glyph, the `<<`/`>>` previews show combo names where a combo exists, and the F9 overlay shows the link window

**Given** `tests/unit/test_combo_table.gd` and `test_action_resolver.gd`
**When** they run
**Then** they cover: `[A,D]` → Dash Strike, `[D,A]` → dash then slash, lookup is ordered (never sorted), shift between J and K, cooldown block, link timing at 18 and 19 frames

### Story 2.7: Combat Resolver, Damage Calc and Practice Target

As a developer and designer,
I want hits resolved by shape math and checked on a training dummy,
So that I can verify every frame-data and damage number on screen.

**Requirements:** FR22 (base), FR59 (dev)

**Acceptance Criteria:**

**Given** the shapes from Story 2.5 and a single `CombatResolver` run inside `tick()`
**When** a player action's hit shape overlaps a target hurtbox during active frames
**Then** a hit is registered once per action per target (Dash Strike hits every target its capsule crosses), without any `Area2D`/physics body

**Given** `DamageCalc.compute(base, state_mult, clean_catch, echo_scale)`
**When** called
**Then** it multiplies all factors and rounds half up once (`floori(x + 0.5)`)
**And** `tests/unit/test_damage_calc.gd` asserts the GDD examples: 15 × 0.5 = 8; 10 × 0.7 = 7; 15 × 0.7 = 11; 15 × 0.7 × 1.5 = 16; 20 × 1.5 = 30; 20 × 0.5 = 10; 30 × 1.5 × 1.5 = 68

**Given** the practice target `/* test */` (infinite HP, no attacks)
**When** I hit it
**Then** it takes base damage (×1, never Patched), shows a per-hit damage log and a frame counter, and `EventBus.hit_landed` is emitted
**And** it is reachable in debug builds (debug key or F-key jump)

### Story 2.8: Hit Feedback — Hit-stop, Particles and Log Lines

As a player,
I want every hit to stop, burst and log,
So that hits feel weighty and readable.

**Requirements:** FR26, FR27 (base), NFR2

**Acceptance Criteria:**

**Given** a hit on the practice target
**When** it lands
**Then** `CombatResolver` requests hit-stop by precedence (crit 8 > combo's own value — Dash Strike 6, Dereference 8 > normal/unpatched 3), using the maximum within the tick
**And** glyph particles burst from the hit point from a fixed 300-slot `ParticlePool` (drawn in one `_draw`, frozen with the sim, dropped silently when full)
**And** the log panel appends `console.log("-<dmg>")` from a ring buffer

**Given** a combo hit
**When** it lands
**Then** a 2-px screen shake for 6 frames is applied via `Camera2D.offset`

**Given** the `ScreenFX` CanvasLayer shader with `invert` and `dither` uniforms
**When** `JuiceDirector` requests a 1-frame inversion or a dither level
**Then** the full screen inverts or dithers, and only `JuiceDirector` drives it

**Given** a debug build
**When** I press F10
**Then** a perf overlay shows FPS, frame time, live particles and draw calls

**Given** the juice code
**When** reviewed
**Then** presentation never sets hit-stop or writes sim state; hit-stop is simulation state only

### Story 2.9: Player Damage, Death and Instant Retry

As a player,
I want to die cleanly and be back in the fight within 2 seconds,
So that failure is cheap and I keep trying.

**Requirements:** FR2, FR49, NFR5

**Acceptance Criteria:**

**Given** the player takes a hit (from a debug damage key or any boss attack/contact later)
**When** it lands outside invulnerability
**Then** HP drops by 1 (shown as `hp: 0b11111` → `0b01111`…), 4 frames of hit-stop, a 3-px shake, a `WARN: hp--` log line, `EventBus.player_damaged(hp)`, and 60 frames of invulnerability with a blinking sprite
**And** dash invulnerability frames ignore the hit

**Given** HP reaches 0
**When** the player dies
**Then** `Game` enters DEAD, the screen shows `Process exited with code 1`, `RunState.deaths_on_boss` increments and `EventBus.player_died(boss, deaths)` is emitted

**Given** the DEAD screen
**When** I make a new key press or click ≥ 20 frames after death (a key held through death never counts)
**Then** within 2 s the same fight restarts from the `RunState` snapshot captured on FIGHT enter: full HP, the fight-start register, link and Echo memory cleared, cooldowns reset, `rng` reseeded
**And** `tests/integration/test_retry_snapshot.gd` verifies that a register shifted mid-fight is restored on retry

## Epic 3: Infinite Loop (MVP)

A complete vertical slice: the player beats a three-phase Infinite Loop, learns Patched and the ×0.5/×1.5 damage states from the voiced duck tutorial, sees the Harvest and receives LOOP. MVP playtest gate on Nov 14 (≥ 3 people); if the epic is late, ship phases 1–2 only. Window: Nov 11–14.

### Story 3.1: Reusable Boss Framework

As a player,
I want bosses that telegraph, attack, recover and change phase predictably,
So that I can read and punish them like a hunter.

**Requirements:** FR3 (contact), FR29 (jitter), FR30, FR31, FR32

**Acceptance Criteria:**

**Given** `BossDef` (`name_signature`, `max_hp`, `phases`, `drop_bit`, `fixed_line`), `PhaseDef` (`hp_threshold`, `weak_window`, `gap_frames`, `attack_pool`) and `AttackDef` (`id`, `tell`, `active`, `recovery`, `exclusive`, `recovery_if_no_breakpoint`, `script`) resources with `validate()`
**When** a `BossController` runs with a test boss
**Then** it cycles GAP → TELL → ACTIVE → RECOVERY using the phase's `gap_frames`, calling the attack script's `on_tell/on_active/on_recovery` hooks with an `ArenaContext`
**And** the next attack is picked with `SimContext.rng` from the current phase's pool and never the same attack 3 times in a row

**Given** boss HP crosses a phase threshold
**When** the phase changes
**Then** a 60-frame ROAR state plays (glitch-roar event, no damage window, attacks stop), the speed-ramp hook is reset and `EventBus.boss_phase_changed(phase)` is emitted
**And** boss glyph jitter amplitude rises in steps at 66% and 33% HP

**Given** every `AttackDef`
**When** data validation runs
**Then** any attack with a tell < 20 frames, or with an empty `tell_sfx`, fails `validate()` (Pillar 2: visible and audible tells; D-049)
**And** the boss's tell cue plays on the `SFX` bus at every tell start (placeholder sound acceptable until 7.2)

**Given** `ArenaContext`
**When** an attack needs an aim point
**Then** it reads only `ctx.target_position()`, which returns the player position (or a live decoy's from Story 6.1); a test confirms attacks follow an injected target
**And** every attack's tell and spawn positions lie inside the 32×18 arena (no off-screen attacks)

**Given** the boss's body hurtboxes
**When** the player overlaps them outside invulnerability
**Then** the player takes 1 HP contact damage

**Given** a boss fight
**When** it starts
**Then** the HUD boss header shows its function signature (e.g. `void infiniteLoop() // hp 400`) with live HP
**And** in debug builds F6 kills the boss and Shift+F6 skips to the next phase

**Given** `tests/unit/test_boss_controller.gd`
**When** it runs
**Then** it verifies state timings, the no-triple-repeat rule over 1000 seeded picks, phase thresholds and the roar

### Story 3.2: Weak Window, Patched and Damage States

As a player,
I want hits to be resisted until I patch the bug with the right window,
So that shifting is the way to deal real damage (Pillar 1).

**Requirements:** FR21, FR22, FR23, FR27 (states), FR63 (placeholders)

**Acceptance Criteria:**

**Given** a boss in phase with weak window A→D
**When** Dash Strike from window `[A, D]` hits it
**Then** `WeakWindowTracker` (the only Patched writer) applies Patched for 180 frames before damage is computed, so that hit is already ×1.5 (Dash Strike 20 → 30), and `EventBus.patched_applied` is emitted with 4 frames of hit-stop

**Given** a weak window D→A (no combo)
**When** I dash then slash from `[D, A]` within the link and the slash (`link_second`) hits the boss
**Then** Patched is applied and the slash deals 15 (10 × 1.5) with normal slash hit-stop

**Given** an unpatched boss
**When** any player hit lands
**Then** damage is ×0.5 via `DamageCalc` (slash 15 → 8, Dash Strike 20 → 10), with half the particles, smaller damage glyphs, a dithered `console.log("-8") // resisted` line and a dull thud (placeholder SFX)

**Given** a Patched boss
**When** any player hit lands
**Then** damage is ×1.5, the log line is in CAPS (`CRITICAL: 15 dmg`), 8 frames of hit-stop and 1 frame of full-screen inversion
**And** re-applying Patched refreshes the 180 frames

**Given** Patched is active
**When** the boss is drawn
**Then** a `// patched` tag and countdown bar float above it and a rising chime (placeholder) plays on application

**Given** `BossInteraction` kinds `HIT`, `PASS_THROUGH`, `DECOY_STRUCK`
**When** unit tests run
**Then** all four "affects the boss" cases complete the weak window (PASS_THROUGH and DECOY_STRUCK via stubbed interactions), a wrong window never patches, and the practice target is never patched

### Story 3.3: Infinite Loop Body and Loop Condition

As a player,
I want to face a spinning ring of braces whose semicolon is the only weak point,
So that the bug behaves like an infinite loop (Pillar 3).

**Requirements:** FR33, FR34

**Acceptance Criteria:**

**Given** the Infinite Loop fight starts with the register `[D, A]`
**When** the boss spawns
**Then** it is a closed ring of 24 `{ }` segments (1 tile each, radius ≈ 3.8 tiles) with an `i = 0` counter above it, and it stays still until the player's first shift
**And** the sky comment reads `// TODO: this should terminate`

**Given** the ring is active
**When** time passes
**Then** it spins in place at 8 tiles/s (one lap ≈ 3 s), +5% per lap capped at 12 tiles/s, and drifts toward the player at 2 tiles/s
**And** a `;` glyph travels with the spin and opens for 90 frames once per lap as `i++` ticks

**Given** the `;` is open
**When** a player hit overlaps it
**Then** damage is applied; hits anywhere else on the ring deal no damage (segments are contact hazards only)

**Given** `boss_def.tres` for Infinite Loop
**When** loaded
**Then** HP 400, `drop_bit = BitId.L` (an enum value, no `BitDef` needed yet), fixed line `for (i = 0; i < n; i++) { }`, phases P1 100–66% weak A→D gap 120, P2 66–33% weak D→A gap 90, P3 33–0% gap 60

### Story 3.4: Head Rush and Constrict

As a player,
I want the loop to lunge and squeeze in telegraphed ways,
So that I read its tells and punish the open semicolon.

**Requirements:** FR35

**Acceptance Criteria:**

**Given** phases 1–3
**When** Head Rush is chosen
**Then** a 30-frame tell shows `!` over the head, the head uncoils and charges 10 tiles over 40 active frames, and the `;` stays open during the 45-frame recovery

**Given** phases 2–3
**When** Constrict is chosen
**Then** a 40-frame tell draws the final ring outline at exact size, over 60 active frames the ring re-centres on the player and shrinks to a 2-tile radius, and the `;` is open during the 120-frame recovery
**And** walking out cannot escape Constrict, but an invulnerable move (dash, Dash Strike) through the body can

**Given** both attacks
**When** they have hitboxes
**Then** the hitboxes match the glyph cells exactly and all timings come from `attack_*.tres`

### Story 3.5: Nested Loop, Semicolon Spit and Phase 3

As a player,
I want phase 3 to split the loop into two rings with alternating weak points,
So that switching rings means switching windows.

**Requirements:** FR35 (`;` Spit), FR36

**Acceptance Criteria:**

**Given** phase 3 begins
**When** Nested Loop fires (once, 40-frame tell with the body flashing)
**Then** the boss splits into an outer ring (16 segments, radius ≈ 2.5 tiles) and an inner ring (8 segments, radius ≈ 1.3 tiles), with inner spin at 1.5× the outer, capped at 12 tiles/s

**Given** phase 3
**When** openings occur
**Then** a fixed timer opens one `;` every 3 s, alternating outer, inner, outer…, each for 90 frames; at most one `;` is open at a time and `i++` ticks on each opening
**And** `current_weak_window()` returns A→D when the outer `;` is open or opens next, and D→A for the inner

**Given** phase 3
**When** `;` Spit fires (every 6 s)
**Then** the `;` glows for a 20-frame tell, then a projectile flies at 6 tiles/s from a 16-slot pool

**Given** the epic fallback
**When** phase 3 must be cut
**Then** removing phase 3 from `boss_def.tres` yields a working 2-phase fight with no code change

### Story 3.6: Duck Bubble and Tutorial Beats

As a new player,
I want the rubber duck to teach me the shift with jokes,
So that I learn the register within 30 seconds without a manual.

**Requirements:** FR45 (lines 2–5)

**Acceptance Criteria:**

**Given** `DuckBubble` in the HUD duck region (cols 0–11, rows 22–37; D-047)
**When** a line is requested via `VoiceService.say(line_id_or_text)` (text-only backend in this story)
**Then** the `>o` duck shows the line word-wrapped at 12 columns with a typewriter reveal and a squeak SFX on bubble open

**Given** `data/duck/duck_lines.tres` and `DuckDirector` listening to `EventBus`
**When** the Infinite Loop fight starts and control begins
**Then** T1 "Q and E shift your bits. Only the two on the left are live; the rest are in code review." appears immediately
**And** T2 "See the semicolon? It's always the semicolon. Hit it when it opens." appears on the first `;` approach
**And** T3 "J then K: Dash Strike. Two bits, one commit." appears when Dash Strike becomes the active combo
**And** T4 "It refactored itself. Have you tried shifting it off and on again?" appears at phase 2

### Story 3.7: Duck Voice (mumble-speech)

As a player,
I want the duck to babble its lines in a silly voice,
So that the hint system has personality.

**Requirements:** FR45 (voice); Additional: AD-14, I-6. Not MVP-blocking: may slip past the Nov 14 gate (D-046).

**Acceptance Criteria:**

**Given** mumble-speech pinned to the first release including basteez/mumble-speech#32 (I-6)
**When** the web build runs in Chrome, Firefox and Safari
**Then** `VoiceService.say()` plays the duck voice on the `Voice` bus and drives the `MumbleTypewriter` in `DuckBubble` so the reveal is synced to the voice
**And** if the web GDExtension is not usable, `VoiceService` switches to the pre-render backend (`tools/render_duck_lines.gd`) with no other code changes, and the choice is recorded

**Given** a voice failure at runtime
**When** a line is requested
**Then** the text still shows silently (Story 3.6 behaviour) and a single `Log.warn` is written

### Story 3.8: Boss Defeat and Harvest

As a player,
I want the defeated bug to collapse into its fixed code and drop a new bit,
So that every victory visibly upgrades my weapon.

**Requirements:** FR8 (insertion), FR29 (defeat), FR45 (line 8), FR50

**Acceptance Criteria:**

**Given** boss HP reaches 0
**When** the boss is defeated
**Then** 20 frames of hit-stop, the glyphs reassemble into the fixed line `for (i = 0; i < n; i++) { }`, the duck squeaks and `EventBus.boss_defeated` is emitted

**Given** the defeat animation ends
**When** `Game` enters HARVEST
**Then** `bit_loop.tres` is created (glyph `L`, solo action `ActionDef.NOP` until Story 4.1 replaces it with Echo), the LOOP bit flies into the register, the register becomes the Boss 2 fight-start `[A, D, L]` (`0x07`), the HUD shows the new windows, and the shared harvest line "Bug squashed. It dropped a bit: new windows, new combos." plays
**And** the screen lasts ≤ 8 s and can be skipped with any input after 2 s, then the next fight starts with full player HP and all cooldowns reset (D-049)

**Given** a debug build
**When** I press F8
**Then** the next bit whose `BitDef` exists is granted (Boss 2 loadout now; Boss 3 loadout once NULL exists in Epic 5) without a fight

### Story 3.9: MVP Playtest and Tuning Pass

As the director,
I want the Infinite Loop slice playtested and tuned by Nov 14,
So that the core loop is proven before building more content.

**Requirements:** NFR10, NFR13, NFR14, NFR16 (MVP gate)

**Acceptance Criteria:**

**Given** the Epic 3 build deployed to the itch.io draft page
**When** ≥ 3 playtesters play from the title screen without help beyond the duck
**Then** for each tester I record: time from first title input to first shift (target ≤ 30 s), whether they Patched with Dash Strike unprompted (target ≥ 80%), attempts to clear (target ≥ 80% within 3), clear time (target 60–120 s), shift-feel rating (target ≥ 4/5) and whether resisted hits read as "patch first"

**Given** the findings
**When** tuning
**Then** values change only in `.tres` in the order boss HP → tell → recovery → gap → player HP, and the ×0.5/×1.5 multipliers are not changed
**And** findings and changes are logged in `_bmad-output/implementation-artifacts/playtest-mvp.md`

**Given** the Nov 14 gate
**When** phase 3 is not stable
**Then** the fallback (phases 1–2) is applied and recorded

## Epic 4: LOOP Combos & Breakpoint

With the 3-bit ring, the player uses Echo and Echo Dash, freezes time with Breakpoint to shift calmly, and gets the "Weak window" hint from Breakpoint and on the 3rd death. Window: Nov 15–17.

### Story 4.1: LOOP Bit — Echo

As a player,
I want LOOP to replay my last move from where I stand,
So that I can double up attacks and escapes.

**Requirements:** FR12

**Acceptance Criteria:**

**Given** `bit_loop.tres` (its NOP placeholder from Story 3.8 replaced) and `echo.tres` (cooldown 90 frames)
**When** I press the slot holding `L`
**Then** `EchoMemory.last` (the exact last solo bit `ActionDef`, e.g. `slash_3`) is re-executed at my current position and facing with `damage_scale = 0.7`, using its own frame data, invulnerability and intangibility
**And** whiffed actions still count as "last"; combos, Echo itself, NOP and actions cancelled during startup are never stored (design call NP-5)

**Given** an empty Echo memory
**When** I press LOOP
**Then** nothing happens and no cooldown starts

**Given** unit tests
**When** they run
**Then** Echo of slash 15 deals 11 to the practice target, Echo of slash 10 deals 7, Echo of DASH produces a second dash, and memory is cleared on fight start and retry

### Story 4.2: Echo Dash Combo

As a player,
I want D then L to chain two invulnerable dashes,
So that I can pass through a boss and reveal or patch it.

**Requirements:** FR17, FR21 (pass-through)

**Acceptance Criteria:**

**Given** the window `[D, L]`
**When** I press K during the dash's active frames or within 18 frames after
**Then** Echo Dash fires: a second 4-tile dash (0/10/6) redirectable to my current input direction, with invulnerability continuous from the first dash through Echo Dash's frame 10 (no vulnerable gap), and LOOP's cooldown applies

**Given** Echo Dash's capsule crosses a boss hurtbox
**When** `CombatResolver` runs
**Then** a `PASS_THROUGH` interaction with window D→L is emitted, completing a D→L weak window (verified with a test boss)
**And** Echo Dash deals no damage

### Story 4.3: Breakpoint Skill

As a player,
I want to freeze time and shift calmly,
So that I always have a safety valve when the fight overwhelms me.

**Requirements:** FR24; Additional: AD-12, NP-2

**Acceptance Criteria:**

**Given** `FeatureFlags` (`data/config/feature_flags.tres`: `reserved_write`, `watch`, `breakpoint`, `segfault`) and `BreakpointSkill` in `src/skills/breakpoint/`, registered at startup only if `breakpoint` is on and never referenced by class from core code
**When** Breakpoint is unlocked (after Boss 1, from `RunState`) and I press Space with cooldown 0
**Then** the simulation freezes while register shifts still apply immediately, for up to 120 real frames
**And** the first use is free

**Given** Breakpoint is active
**When** I press J or K
**Then** Breakpoint ends and that action executes on the first unfrozen tick
**And** remaining hit-stop frames from before Breakpoint resume afterwards; pause takes priority over Breakpoint

**Given** Breakpoint ends
**When** the cooldown starts
**Then** it lasts 720 sim frames (12 s) counted from the end (design call NP-2), Breakpoint cannot be chained, and the HUD shows the cooldown

**Given** `breakpoint_started` / `breakpoint_ended`
**When** emitted
**Then** the screen dithers to 50% ink with a red `#FF4040` breakpoint dot and line, and music switches to the muffled loop (placeholder until Epic 7)

**Given** `FeatureFlags.breakpoint = false`
**When** the game runs
**Then** Space does nothing, no Breakpoint HUD appears and nothing else breaks

### Story 4.4: Duck Hint Template

As a stuck player,
I want the duck to tell me the current weak window,
So that I'm never lost for more than a few attempts.

**Requirements:** FR46

**Acceptance Criteria:**

**Given** the template line "Quack. Weak window: {X→Y}."
**When** Breakpoint activates
**Then** `DuckDirector` says the template filled with `boss.current_weak_window()` at most once per boss phase

**Given** `EventBus.player_died(boss, deaths_on_boss)`
**When** `deaths_on_boss` reaches 3 for the same boss
**Then** the template line is said at the start of the retry

**Given** Infinite Loop phase 3
**When** the hint fires
**Then** it names the window of the ring whose `;` is open or opens next (outer → A→D, inner → D→A)

**Given** a test over every phase of Infinite Loop
**When** the hint is rendered
**Then** the window text matches each phase's weak window

## Epic 5: Null Pointer & Watch

The player hunts an invisible boss using Watch, sound and the `null` trail, avoids decoys and the whiff stun, and earns NULL (Null Dodge + Clean Catch). Window: Nov 18–21.

### Story 5.1: Null Pointer Body and Locating Cues

As a player,
I want to track an invisible ghost by its trail and hum,
So that the bug feels like a pointer to nothing (Pillar 3).

**Requirements:** FR23 (tag on invisible boss), FR37, FR39 (phases)

**Acceptance Criteria:**

**Given** the Null Pointer fight starts with `[A, D, L]`
**When** the boss spawns
**Then** it is a ghost of `null` glyphs that drifts invisibly at 4 tiles/s, with a column of 3–5 falling `null` glyphs drifting under it and a looping hum panned by its position (on `AudioStreamPlayer2D`, or `playback_type = Stream` if the Epic 1 smoke test failed)
**And** the sky comment reads `// FIXME: who owns this pointer?`

**Given** the ghost is invisible
**When** an attack is in active or recovery frames, I hit it (10-frame flicker), or Echo Dash passes through it (60 frames)
**Then** it becomes visible for that duration
**And** while Patched, its `// patched` tag and bar stay visible as a position hint

**Given** `boss_def.tres` for Null Pointer
**When** loaded
**Then** HP 700, `drop_bit = BitId.N` (an enum value; `bit_null.tres` arrives in Story 5.5), fixed line `if (ptr != null) ptr.deref();`, P1 100–50% weak D→L gap 90, P2 50–0% weak A→D gap 60

**Given** the locating cues
**When** the boss moves
**Then** the hum's pan follows its x position and the `null` trail follows its position every tick (verified in a test); "locatable by sound alone and by sight alone" is checked in the Story 7.8 playtest

### Story 5.2: Pointer Grab and Null Rain

As a player,
I want the ghost's attacks to reveal it,
So that dodging gives me the chance to strike back.

**Requirements:** FR39

**Acceptance Criteria:**

**Given** phases 1–2
**When** Pointer Grab is chosen
**Then** a `*` appears behind the player for a 40-frame tell, the grab is active for 10 frames dealing 1 HP, and the ghost is visible for the 60-frame recovery

**Given** phases 1–2
**When** Null Rain is chosen
**Then** 5 marked 2×2 areas are drawn at exact size for a 45-frame tell, they are active for 20 frames, and the ghost is visible for the 40-frame recovery

**Given** a visible-recovery window
**When** I Echo Dash through it in P1, or Dash Strike it in P2
**Then** the weak window is completed and Patched is applied

### Story 5.3: Dangling Pointers and NullPointerException

As a player,
I want decoy ghosts and a penalty for blind swings,
So that I must locate the real pointer before attacking.

**Requirements:** FR38, FR39

**Acceptance Criteria:**

**Given** phase 2
**When** Dangling Pointers is chosen
**Then** two `null` flickers tell for 30 frames, then 2 decoy ghosts spawn (instanced, ≤ 3 total), re-cast every 15 s, with a 30-frame recovery
**And** decoys never hum; only the real ghost hums

**Given** a decoy
**When** a player hit touches it
**Then** it is dispelled and never causes a whiff stun

**Given** an ATTACK slash that hits nothing
**When** the real boss is within 4 tiles
**Then** the player enters STUNNED for 20 frames and the log shows `NullPointerException`
**And** slashes that miss with the boss farther than 4 tiles, or non-slash actions, never stun

### Story 5.4: Watch Skill

As a player,
I want to hold R to see what's hidden and what's coming,
So that I can read the fight even against an invisible bug.

**Requirements:** FR25; Additional: cut ladder #2

**Acceptance Criteria:**

**Given** `WatchSkill` in `src/skills/watch/`, registered only if `FeatureFlags.watch` is on, available from Boss 2
**When** I hold R
**Then** hidden entities (the real ghost, decoys marked as decoys, Ghost Echo decoys later) are revealed, the current weak window is highlighted on the HUD, the next attack's name is shown above the boss, and the boss's bits (drop bit and weak window as a bit label) are shown
**And** while held, move speed is ×0.5 and J/K actions are blocked (FSM WATCHING)

**Given** `FeatureFlags.watch = false` (cut ladder #2)
**When** the Null Pointer fight runs
**Then** R does nothing, the ghost flickers visible for 20 frames every 2 s, and decoys never hum, with no other code change

### Story 5.5: NULL Bit — Null Dodge and Clean Catch

As a player,
I want a long intangible dodge that rewards perfect reads,
So that I can pass through attacks and strike harder.

**Requirements:** FR13, FR14, FR22 (Clean Catch)

**Acceptance Criteria:**

**Given** `bit_null.tres` and `null_dodge.tres` (0/30/8, cooldown 120)
**When** I press the slot holding `N`
**Then** I am intangible for the 30 active frames with move speed ×0.5, and recovery of other actions can be cancelled into it

**Given** a boss attack's hitbox passes through me during Null Dodge
**When** my next damaging action hits
**Then** it deals ×1.5 on top of the damage state (×2.25 Patched, ×0.75 unpatched) via `DamageCalc`, and Clean Catch is consumed

**Given** unit tests
**When** they run
**Then** Clean Catch slash 10 deals 15 Patched / 8 unpatched (7.5 → 8), and Echo of Null Dodge can also trigger Clean Catch

### Story 5.6: Null Pointer Tutorials, Defeat and NULL Harvest

As a player,
I want the duck to introduce my new skills and the fight to end with a new bit,
So that Boss 2 is a complete, guided fight.

**Requirements:** FR45 (lines 6–7), FR50; Additional: cut ladder #4

**Acceptance Criteria:**

**Given** the Null Pointer fight starts
**When** control begins
**Then** the duck says "Space: Breakpoint. Time stops, you shift. Finally, a debugger that works." then "Hold R. Pointers point *somewhere*." (the latter only if Watch is enabled)
**And** Breakpoint is available immediately (free first use, implemented in Story 4.3)

**Given** Null Pointer is defeated
**When** the defeat sequence plays
**Then** its glyphs reassemble into `if (ptr != null) ptr.deref();`, the Harvest screen inserts NULL so the Boss 3 fight-start register is `[A, D, L, N]` (`0x0F`), and the shared harvest line plays

**Given** `FeatureFlags.segfault = false` (cut ladder #4)
**When** Null Pointer is defeated
**Then** NULL is not dropped and the Ending plays directly

## Epic 6: Segfault, Intro & Ending

A complete framed run from Intro to Ending: Ghost Echo and Dereference, the final boss with corrupted tiles, SIGSEGV and Reserved Write (cut #1), and all game text. Window: Nov 22–25.

### Story 6.1: Ghost Echo Combo

As a player,
I want L then N to leave a decoy that bosses attack,
So that I can bait a boss and patch it.

**Requirements:** FR18, FR21 (decoy struck)

**Acceptance Criteria:**

**Given** the window `[L, N]`
**When** I press K in the link window
**Then** Ghost Echo fires: I am intangible for 30 frames (0/30/8) and an intangible decoy carrying window L→N stays at my start point for 120 frames; NULL's cooldown applies

**Given** a live decoy
**When** a boss chooses a target
**Then** it targets the decoy instead of the player
**And** when a boss attack hitbox overlaps the decoy, a `DECOY_STRUCK` interaction completes an L→N weak window

### Story 6.2: Dereference Combo

As a player,
I want N then A to thrust from inside my dodge,
So that a perfect dodge turns into my strongest hit.

**Requirements:** FR19

**Acceptance Criteria:**

**Given** the window `[N, A]` and Null Dodge in its active frames
**When** I press K
**Then** Dereference fires: a 3-tile piercing thrust (2/8/14), 30 base damage, staying intangible through its active frames, with 8 frames of hit-stop on hit

**Given** Null Dodge is not in its active frames
**When** I press K in the link window
**Then** K performs ATTACK's solo slash instead (`requires_first_active`)

**Given** tests
**When** they run
**Then** Patched Dereference deals 45 and Patched Dereference with Clean Catch deals 68

### Story 6.3: Segfault Body and Access Violation

As a player,
I want a glitch dragon that claws across the arena,
So that the final bug feels big and dangerous.

**Requirements:** FR40, FR41, FR42; Additional: cut ladder #4

**Acceptance Criteria:**

**Given** `src/bosses/segfault/` registered only if `FeatureFlags.segfault` is on
**When** the fight starts with `[A, D, L, N]`
**Then** a ≈ 6×4-tile dragon of `▓▒░#@!` glyphs stays in the top third of the arena moving at 2 tiles/s, and the sky comment reads `// HACK: do not read past this line`

**Given** `boss_def.tres` for Segfault
**When** loaded
**Then** HP 1000, no drop, fixed line `if (idx < len) buf[idx] = val;`, P1 100–66% weak D→L gap 90, P2 66–33% weak N→A gap 75, P3 33–0% weak L→N gap 60

**Given** phases 1–3
**When** Access Violation is chosen
**Then** the claw's arc is drawn for a 30-frame tell, a 6-tile sweep is active for 12 frames, and the 50-frame recovery is punishable (Echo Dash through the claw Patches in P1)

**Given** Segfault is defeated
**When** the defeat plays
**Then** glyphs reassemble into its fixed line and `Game` goes to ENDING (no Harvest)

### Story 6.4: Corrupted Tiles — Corrupt Memory and Core Dump

As a player,
I want the dragon to corrupt the arena floor in readable patterns,
So that positioning matters in the final fight.

**Requirements:** FR42, NFR1

**Acceptance Criteria:**

**Given** a fixed 32×18 corrupted-tile grid allocated at fight start
**When** Corrupt Memory is chosen (P1–3)
**Then** 8–12 tiles are marked `░` for a 60-frame tell, become `▓` hazards for 240 frames dealing 1 HP on entry, then a 40-frame recovery

**Given** phase 3
**When** Core Dump is chosen
**Then** a checkerboard is marked with safe tiles visible for a 60-frame tell, active for 180 frames, recovery 60

**Given** Segfault phase 3 with maximum hazards and particles
**When** measured with the F10 overlay in Chrome
**Then** the frame rate stays at 60 FPS on the dev machine (final check on target hardware in Epic 7)

### Story 6.5: SIGSEGV — Register Corruption

As a player,
I want the final boss to scramble my register with fair warning,
So that the theme turns against me without feeling cheap.

**Requirements:** FR43; Additional: NP-3

**Acceptance Criteria:**

**Given** phases 2–3
**When** SIGSEGV is chosen
**Then** a 60-frame tell flashes the HUD red (`#FF4040`) with `SIGSEGV incoming` and a rising alarm
**And** on its single active frame the attack pushes `PlayerEffects.RotateRegister(2)`, applied at the fixed tick point: the register rotates 2 slots, the link closes and `register_shifted(..., &"sigsegv")` is emitted
**And** a guaranteed 90-frame "dumping core" recovery follows (150 frames if `FeatureFlags.breakpoint` is off)

**Given** `AttackDef.exclusive = true`
**When** the `BossController` schedules SIGSEGV
**Then** it only starts when no other attack or hazard is in its active frames and blocks new attacks until its recovery ends

**Given** 10 seeded test runs of phases 2–3
**When** a GUT test checks every SIGSEGV
**Then** none overlaps another attack's or hazard's active frames and each is followed by its full recovery

### Story 6.6: Reserved Write (Cut Ladder #1)

As a player,
I want the boss to write a garbage bit into my reserved memory,
So that the final phase twists the register one more time.

**Requirements:** FR44; Additional: cut ladder #1

**Acceptance Criteria:**

**Given** `reserved_write.gd` registered only if `FeatureFlags.reserved_write` is on
**When** Reserved Write is chosen in P3
**Then** the `reserved` nibble flashes for a 45-frame tell, then `PlayerEffects.InsertTemporaryBit(GARBAGE, 600)` appends `?` to the ring for 600 frames; its solo action is NOP and every pair containing it has no combo; recovery 30

**Given** the garbage bit expires or the player retries
**When** it is removed
**Then** the register recomputes its window and emits `register_changed`, and retry restores the fight-start register without it

**Given** `FeatureFlags.reserved_write = false`
**When** Segfault runs
**Then** Reserved Write is absent from the pool and stories 6.1–6.5 work unchanged

### Story 6.7: Intro Sequence

As a new player,
I want a quick comic intro that drops me into the fight,
So that I get the premise in seconds and start playing.

**Requirements:** FR45 (line 1), FR48

**Acceptance Criteria:**

**Given** the title input
**When** the Intro starts
**Then** three glyph panels play (≈ 2.5 s each, ≤ 8 s total): the developer at a desk at 2 a.m.; squeezing the duck, which quacks; the screen tearing into glyphs and landing in The Clearing, where the duck hands over ATTACK and DASH with "Quack. Explain the bug to me. Use these."

**Given** the Intro
**When** I press any key or click from its first frame
**Then** it skips straight to Fight 1; the title-screen input that started it never counts as a skip

### Story 6.8: Ending Sequence

As a player who beat Segfault,
I want an ending that completes the register and sends me home,
So that the run closes with a payoff.

**Requirements:** FR45 (line 9), FR51

**Acceptance Criteria:**

**Given** Segfault (or, with cut #4, Null Pointer) is defeated
**When** the Ending plays
**Then** the reserved nibble lights up `1111` (`0xFF`), the developer is back at the desk with the duck, the commit message reads `fix: wild shift`, the duck says "Quack. Works on your machine now.", and credits roll, all in ≤ 30 s
**And** credits include the font, audio and mumble-speech licences

**Given** time allows (stretch)
**When** the Ending shows
**Then** a clear-time and hits-taken summary is displayed

### Story 6.9: Game Text Audit

As the director,
I want every line of game text in data and verified against the GDD,
So that the duck line budget and all jokes ship exactly as designed.

**Requirements:** FR45, FR56 (sky comments)

**Acceptance Criteria:**

**Given** `data/duck/duck_lines.tres` and `data/text/{fixed_lines,sky_comments}.tres`
**When** a GUT test runs
**Then** there are exactly 10 duck lines matching the GDD Duck table (intro; T1–T4; Breakpoint tutorial; Watch tutorial; shared harvest; ending; hint template), 3 fixed lines and 3 sky comments
**And** every duck line has a trigger that fires in a full run (verified by a scripted full-run replay or checklist)
**And** no game text is hard-coded in scripts

## Epic 7: Audio, Polish & Submission

A jam-ready release, submitted: music and the full SFX pass, save/resume, assist toggle, fullscreen, (Should) gamepad and title-screen practice target, browser matrix and performance check, itch.io page and README; submitted by Nov 29 12:00 PST. Window: Nov 26–29.

### Story 7.1: Music and Crossfades

As a player,
I want chiptune music that glitches as each bug gets desperate,
So that the audio raises the tension of each fight.

**Requirements:** FR62

**Acceptance Criteria:**

**Given** BeepBox loops in `assets/audio/music/` (`title.ogg`, `boss_1..3.ogg`, `boss_1..3_glitch.ogg`, `breakpoint_muffled.ogg`) under CC0/own licence
**When** the flow advances
**Then** the title/intro track plays after the first input and each boss has its track, crossfaded by `AudioManager.crossfade_to(track, frames)` on two players

**Given** a boss reaches phase 3
**When** `boss_phase_changed(3)` is emitted
**Then** the music crossfades to that boss's pre-rendered glitch variant in sync

**Given** Breakpoint starts or ends
**When** the events fire
**Then** music crossfades to and from the muffled loop, with no live audio effects anywhere

### Story 7.2: Final SFX Pass

As a player,
I want distinct, punchy sounds for every key event,
So that I can play partly by ear.

**Requirements:** FR63

**Acceptance Criteria:**

**Given** about 20 jsfxr SFX in `assets/audio/sfx/`
**When** the corresponding events fire
**Then** all Must sounds are final: `shift_left`, `shift_right` (distinct), hit, `hit_resisted` thud, Patched chime, duck squeak, SIGSEGV alarm; plus one glyph-glitch sound per boss, the Null Pointer hum, player hit, phase roar and defeat
**And** the three boss tell cues (one per boss) are final and every `AttackDef.tell_sfx` points to one (D-049)
**And** SFX play through a pooled player set on the `SFX` bus; the shift click's play request is issued on the input frame (verified in the `Log`/F9 overlay) in Chrome and Firefox

### Story 7.3: Save and Resume

As a returning player,
I want to resume at the highest boss I reached,
So that closing the tab doesn't cost me my progress.

**Requirements:** FR53, NFR12

**Acceptance Criteria:**

**Given** `SaveService`
**When** a fight starts or the assist toggle changes
**Then** `user://save.cfg` is written with `version`, `highest_boss`, `assist` (default false until 7.4) and `muted`

**Given** a save with `highest_boss = 2`
**When** I start the game from the title
**Then** the run resumes at Boss 2 (after the Intro or skipping it) with the Boss 2 fight-start register, full HP and reset cooldowns

**Given** a save with `highest_boss > 1`
**When** the title shows
**Then** `[N] new run` is shown; pressing `N` (or Select on a gamepad, or clicking it) resets `highest_boss` to 1 and starts a new run from the Intro (D-048)

**Given** storage fails (itch.io iframe, private mode)
**When** reading or writing
**Then** a single `Log.warn` is written, the game runs without persistence and the player sees nothing

### Story 7.4: "Debug Build" Assist Toggle (Should)

As a player who finds it too hard,
I want an assist option that eases survival,
So that I can finish the run without losing the shift challenge.

**Requirements:** FR60

**Acceptance Criteria:**

**Given** the title and pause screens
**When** I toggle "Debug build" with `[B]` or by clicking its label
**Then** player HP becomes 8, Breakpoint cooldown 360 frames (6 s) and every boss tell ×1.5 (scaled at read time, `.tres` untouched)
**And** the ×0.5 unpatched and ×1.5 Patched multipliers are unchanged
**And** the label is neutral, there is no penalty, and the setting persists via `SaveService`

### Story 7.5: Gamepad Support (Should)

As a player with a controller,
I want to play the whole run on a gamepad,
So that I can play the way I prefer.

**Requirements:** FR61

**Acceptance Criteria:**

**Given** the `InputMap`
**When** a gamepad is connected in Chrome
**Then** left stick/D-pad move, X/Square = Action 1, A/Cross = Action 2, LB/L1 = `<<`, RB/R1 = `>>`, RT/R2 = Breakpoint, Y/Triangle = Watch, Start = pause
**And** a full run can be completed on a gamepad

### Story 7.6: Practice Target from the Title Screen (Should)

As a player,
I want to try combos on a training dummy from the title screen,
So that I can learn the frame data without pressure.

**Requirements:** FR59

**Acceptance Criteria:**

**Given** the title screen
**When** I press `[P]` or click "practice"
**Then** the `/* test */` dummy loads in The Clearing with base damage, per-hit log and frame counter, and the register can be set to any owned loadout reached so far (or the full `[A, D, L, N]`)
**And** Esc returns to the title

### Story 7.7: Fullscreen, Browser Matrix and Performance

As a jam player,
I want the game to run smoothly in my browser, fullscreen if I like,
So that my first impression isn't a broken build.

**Requirements:** FR55, NFR1, NFR2, NFR3, NFR4, NFR7

**Acceptance Criteria:**

**Given** the title and pause screens
**When** I press `[F]` or click the fullscreen label
**Then** fullscreen is requested inside the input-event handler; if refused, the game stays windowed silently

**Given** the release build on the itch.io draft page
**When** tested in Chrome, Firefox and Safari (latest)
**Then** a full run has no crash in any of them; Safari issues are only cosmetic
**And** the title is interactive in ≤ 10 s on 50 Mbps with a cold cache, and the build is ≤ 32 MB

**Given** a 2020-era mid-range laptop with integrated graphics at 1280×720
**When** Segfault phase 3 is played in Chrome and Firefox
**Then** 60 FPS is sustained and live particles never exceed 300

### Story 7.8: Full-Run Playtest and Final Tuning

As the director,
I want the complete run playtested and tuned,
So that it takes a first-time player 10–15 minutes and feels fair.

**Requirements:** NFR9, NFR11, NFR13, NFR14

**Acceptance Criteria:**

**Given** the full build
**When** ≥ 3 first-time playtesters play a full run
**Then** the Gameplay Metrics are recorded (plus: Null Pointer locatable by sound alone and by sight alone): first shift ≤ 30 s, full run 10–15 min, per-boss clear times (60–120 / 120–150 / 150–210 s), shift feel ≥ 4/5, ≥ 50% mention the shift unprompted
**And** tuning changes only `.tres` values in the GDD order, and findings are logged in `_bmad-output/implementation-artifacts/playtest-full.md`

**Given** the final build
**When** 3 consecutive full runs are played
**Then** there are zero blocking bugs

### Story 7.9: itch.io Page, README and Submission

As the director,
I want a page that sells the shift and a compliant repo,
So that raters understand the game in 30 seconds and the entry is valid.

**Requirements:** FR64, NFR15, NFR17

**Acceptance Criteria:**

**Given** the itch.io page
**When** published
**Then** it uses the full title "The Debugger 0x03: Wild Shift", leads with a cover GIF of a shift into a Dash Strike crit and the line "shift your weapon's bits mid-fight", lists the controls, discloses AI use, and credits all assets (font, audio, mumble-speech) with their licences (CC0/CC-BY/OFL/MIT only, no NC/ND)
**And** screenshots show the 1-bit glyph style and a shift moment

**Given** the GitHub repo
**When** made public
**Then** the README contains the same AI disclosure and credits plus how to run and build

**Given** the jam
**When** the entry is submitted to GitHub Game Off 2026
**Then** it is submitted by 2026-11-29 12:00 PST (≥ 49 h before the deadline)
