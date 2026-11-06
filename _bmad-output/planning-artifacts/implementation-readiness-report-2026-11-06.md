---
stepsCompleted: [1, 2, 3, 4, 5, 6]
documentsIncluded:
  gdd: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md
  gddSupporting:
    - _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md
    - _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md
  architecture: _bmad-output/game-architecture.md
  projectContext: _bmad-output/project-context.md
  epics: _bmad-output/planning-artifacts/epics.md
  ux: null
---

# Implementation Readiness Assessment Report

**Date:** 2026-11-06
**Project:** github-gameoff-2026

## Document Inventory

| Type | File | Size | Modified |
|---|---|---|---|
| GDD | `planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` | 47 KB | 2026-11-06 19:45 |
| GDD decision log | `planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md` | 15 KB | 2026-11-06 19:45 |
| GDD high-level epics (reference only) | `planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md` | 11 KB | 2026-11-06 19:45 |
| Architecture | `_bmad-output/game-architecture.md` | 64 KB | 2026-11-06 20:54 |
| Project context | `_bmad-output/project-context.md` | 9 KB | 2026-11-06 21:04 |
| Epics & Stories (authoritative) | `planning-artifacts/epics.md` | 93 KB | 2026-11-06 21:23 |
| UX | — (none; HUD/screen requirements in GDD, listed as FRs in epics.md) | — | — |

**Resolutions:** The two `epics.md` files are not duplicates. `planning-artifacts/epics.md` is authoritative; the GDD-folder version is the high-level source used for traceability. There is no UX document, and that was intentional.

## GDD Analysis

Source: `gdd.md` v1.0 (status: final), plus `decision-log.md` (D-001–D-044) and the GDD-folder `epics.md` (high-level stories). The GDD has no numbered requirements. The list below is an **independent extraction** made for this assessment, and its prefixes are `GFR`/`GNFR` so they don't collide with the FR numbering in `planning-artifacts/epics.md`.

### Functional Requirements

**Player and movement**
- GFR1: The player moves in 8 directions at 7 tiles/s, reaching full speed in 4 frames and stopping in 3. WASD is the default, with arrow keys as an alternative. Facing comes from the last move, and attacks fire in the facing direction.
- GFR2: The player hurtbox is a 0.6-tile circle and HP is 5 (`hp: 0b11111`). Each hit or contact deals 1 HP and is followed by 60 frames of invulnerability with a blink.
- GFR3: The play area is 32×18 tiles with solid tree-line walls. Boss contact deals 1 HP, and dash/dodge invulnerability passes through bodies.
- GFR4: Every action can be cancelled into DASH or Null Dodge during its recovery.

**Register**
- GFR5: The register is a ring of owned bits only (2→3→4) and can't reach a dead state. The HUD shows a full byte, with the high nibble greyed and labelled `reserved` and unowned slots shown as a greyed `0`.
- GFR6: The active window is the 2 leftmost owned slots (J = slot 1, K = slot 2).
- GFR7: Q rotates `<<` and E rotates `>>`. A shift takes 0 frames, is allowed at any time (including recovery) and affects the next action. Shift inputs are buffered 8 frames during hit-stop.
- GFR8: Shift previews show the window and combo name that each shift would produce, faded. A no-combo window shows only its bit glyphs.
- GFR9: A harvested bit is appended to the right. Fight-start registers are `[D,A]`, `[A,D,L]` and `[A,D,L,N]`.
- GFR10: The HUD shows the register's byte value in hex (`0x03`→`0x07`→`0x0F`, and `0xFF` at the ending).

**Bits**
- GFR11: ATTACK slash: 120° arc, 1.5-tile range, S/A/R 6/4/12, damage 10/10/15. A 3-hit chain is made by pressing in the last 8 frames of recovery.
- GFR12: DASH: 4 tiles, S/A/R 0/10/6, invulnerable on frames 1–8, CD 24 frames.
- GFR13: LOOP Echo re-executes the last solo bit action (not combos, not itself) at the current position for 70% damage, rounded half up. A whiffed action is still echoed. With no prior action it does nothing and costs no CD. CD 90 frames.
- GFR14: NULL Null Dodge: intangible for 30 active frames (S/A/R 0/30/8), ×0.5 move speed, CD 120 frames. Clean Catch: if an attack passes through the player, their next damaging action deals ×1.5, stacking with the boss's damage state.

**Combos**
- GFR15: Combo trigger: Action 2 pressed during Action 1's active frames or within 18 frames after them. Action 2 is replaced by the combo. Combos are ordered, the replaced bit's CD applies, and the combo table is data-driven.
- GFR16: There are exactly 4 combos. Dash Strike (A→D): 0/12/8, i-frames 1–10, 20 damage per target, 5-tile dash. Echo Dash (D→L): 0/10/6, invulnerable with no gap, 4-tile redirectable second dash. Ghost Echo (L→N): 0/30/8, intangible, leaves a 120-frame decoy that bosses target. Dereference (N→A): 2/8/14, stays intangible, 30 damage, 3-tile piercing thrust, only during Null Dodge's active frames.
- GFR17: No-combo windows (D→A, L→A) perform the two solo actions. Action 2 is buffered if pressed during Action 1.

**Weak window, Patched, damage**
- GFR18: Each boss phase has one weak window (an ordered pair, with or without a combo). Completing it so that it "affects the boss" applies Patched for 180 frames. The four cases are: a damaging combo hits; a no-combo pair's Action 2 hits; Echo Dash passes through the hurtbox; the boss strikes the Ghost Echo decoy. Re-applying refreshes the duration.
- GFR19: Damage states: Unpatched ×0.5, Patched ×1.5, Clean Catch ×1.5 on top. Multipliers combine and round half up once. The Patching hit counts as Patched.
- GFR20: Resisted (unpatched) feedback: a dithered `console.log("-N") // resisted` line, smaller damage glyphs, half the particles and a dull thud. Crit feedback: a CAPS log line, 1 frame of colour inversion and a Patched chime.
- GFR21: A `// patched` tag and countdown bar sit above the boss and stay visible while the boss is invisible.
- GFR22: The practice target takes base damage (×1) and shows a damage log and a frame counter. It has infinite HP and no attacks.

**Skills**
- GFR23: Breakpoint (Space) freezes the simulation for up to 120 frames of real time while still allowing shifts. It ends on any action input and has a 12 s CD. Feedback is a dithered screen, a red dot and line, and the muffled loop. It unlocks after Boss 1, and the first use is free.
- GFR24: Watch (hold R) reveals hidden entities, highlights the weak window, and shows the next attack's name and the boss's bits (drop plus weak window). While held: ×0.5 move speed and no actions. It is available from Boss 2.

**Hit feedback (juice)**
- GFR25: Hit-stop: Crit 8 > combo-specific (Dash Strike 6, Dereference 8) > unpatched 3. Player hit: 4. Patched applied: 4. Boss defeated: 20. A combo hit adds a 2-px shake for 6 frames, and a player hit adds a 3-px shake and the `WARN: hp--` log line.
- GFR26: Shift juice: a 6-frame HUD slide with overshoot bounce, a key-click SFX (distinct for `<<` and `>>`) and a 4-frame weapon inversion, with feedback on the input frame.
- GFR27: Bosses' glyph jitter rises in steps at 66% and 33% HP.

**Controls and input**
- GFR28: The full keyboard map is J/K/Q/E/Space/R/Esc, with no Shift keys. All actions and shifts have an 8-frame input buffer. The pause screen shows the controls, and remapping is out of scope.
- GFR29 (Should): Gamepad mapping per the GDD's Controls table.
- GFR30: Press-to-start: no audio before the first input. That input starts the 30-s clock and leads into the intro without skipping it.

**Boss framework**
- GFR31: Bosses have HP, phase thresholds and per-phase attack pools. Picks are random, with no attack 3 times in a row. A fixed gap separates attacks, and every attack has tell, active and recovery states. A phase change resets the speed ramp and plays a 60-frame glitch-roar with no damage window.
- GFR32: Every attack has a visible and audible tell of ≥ 20 frames, and AoEs are drawn at their final size during the tell. There are no off-screen attacks.
- GFR33: Defeat plays 20 frames of hit-stop, reassembles the glyphs into the boss's fixed line and plays a duck squeak.
- GFR34: Bosses are named on the HUD as function signatures (e.g. `void infiniteLoop() // hp 400`).

**Boss 1 — Infinite Loop**
- GFR35: The body is a 24-segment ring (radius ≈ 3.8) that spins at 8 tiles/s, +5% per lap, capped at 12, and drifts at 2 tiles/s. An `i` counter is shown. Its `;` opens for 90 frames once per lap and is the only damageable point. HP 400; drops LOOP.
- GFR36: Weak windows by phase: P1 (100–66%) A→D, gap 120. P2 (66–33%) D→A, gap 90. P3 (33–0%) outer A→D / inner D→A, gap 60.
- GFR37: Attacks: Head Rush (30/40/45, `;` open), Constrict (40/60/120, must be escaped with an invulnerable move), Nested Loop (P3 once: outer ring of 16 segments, inner ring of 8, inner speed 1.5× capped at 12, a fixed 3 s timer alternating ring openings of 90 frames each, at most one open at a time) and `;` Spit (tell 20, 6 tiles/s, every 6 s).
- GFR38: The tutorial starts at `[D,A]`, and the ring stays still until the first shift. Duck beats T1–T4 play at their triggers.
- GFR39 (fallback): if Epic 3 is late, Boss 1 ships with phases 1–2 only.

**Boss 2 — Null Pointer**
- GFR40: The boss is invisible except during active and recovery frames, while Watch is held, during a 10-frame hit flicker and for 60 frames after Echo Dash. It is located by a falling `null` trail and a positional hum. It drifts at 4 tiles/s. HP 700; drops NULL.
- GFR41: NullPointerException: a slash that whiffs while the boss is within 4 tiles stuns the player for 20 frames. Hitting a decoy dispels it and never stuns.
- GFR42: Weak windows: P1 D→L (gap 90), P2 A→D (gap 60). Attacks: Pointer Grab (40/10/60), Null Rain (45/20/40, 5 areas of 2×2) and Dangling Pointers (P2, 30, 2 decoys re-cast every 15 s, recovery 30). Only the real boss hums and shows in Watch.

**Boss 3 — Segfault**
- GFR43: The body is a 6×4 glitch dragon that stays in the top third and moves at 2 tiles/s. HP 1000; no drop.
- GFR44: Weak windows: P1 D→L (gap 90), P2 N→A (gap 75), P3 L→N (gap 60).
- GFR45: Attacks: Access Violation (30/12/50, 6-tile sweep), Corrupt Memory (60 tell on 8–12 `░` tiles → 240 frames of `▓` hazard that deals 1 HP on entry → 40 recovery), SIGSEGV (60-frame red HUD tell plus alarm → register rotated by 2 → a guaranteed 90-frame recovery, or 150 if Breakpoint is cut), Core Dump (60/180/60, checkerboard with safe tiles visible) and Reserved Write (cut-ladder #1: the `?` garbage NOP bit for 600 frames while the reserved nibble flashes).
- GFR46: Fairness: SIGSEGV is always telegraphed, always recovers and never overlaps another attack's active frames.
- GFR47: Corrupted tiles are the only interactive element in the arena.

**Duck**
- GFR48: Exactly 10 lines, shown as one-line bubbles with a squeak and no voice. Each line has the trigger listed in the Duck table.
- GFR49: Hint template "Quack. Weak window: {X→Y}." It triggers on Breakpoint (at most once per phase) and on the 3rd death on the same boss. In Boss 1 P3 it names the window of the next `;`.

**Flow and screens**
- GFR50: Sequence: Title → Intro → Infinite Loop → Harvest → Null Pointer → Harvest → Segfault → Ending. There is no level select.
- GFR51: Intro: 3 glyph panels, ≤ 8 s, skippable from its first frame (the title input doesn't count). The duck hands over A and D (line 1).
- GFR52: Harvest: fixed line, the bit flying into the register, the new windows shown and duck line 8. ≤ 8 s, skippable after 2 s.
- GFR53: Ending: the reserved nibble shows `1111`, then the desk, the duck, `fix: wild shift`, duck line 9 and credits. ≤ 30 s.
- GFR54: Death shows `Process exited with code 1`. Any input retries the same fight in ≤ 2 s with full player and boss HP and the register as it was at fight start. There are no lives and no game-over.
- GFR55: Save/resume at the highest boss reached, with a silent fallback when storage fails. Full HP is restored between fights.
- GFR56: Auto-pause on tab or focus loss, and an Esc pause screen that shows the controls.
- GFR57 (Should): a "Debug build" assist toggle on the title and pause screens: HP 8, Breakpoint CD 6 s, tells ×1.5, and the ×0.5 unpatched multiplier unchanged.
- GFR58 (Should): the practice target is reachable from the title screen.
- GFR59: A fullscreen button that triggers fullscreen from an input event.

**Arena and presentation**
- GFR60: The Clearing (`stack frame 0x03`) has glyph trees, grass, rocks and a stream, framed by the IDE HUD (register panel left, log panel bottom, line numbers). Scenery has no collision.
- GFR61: Per-boss sky comments (3) change, and collision never does.
- GFR62: 1-bit palette `#E8E8E8` on `#101014`, with inversion and 50% dither as the only extra states. Red `#FF4040` is used only for warnings (Breakpoint, SIGSEGV).
- GFR63: One monospace pixel font on a 16-px grid. The player is `@` with a `>o` duck.

**Audio**
- GFR64: About 20 jsfxr SFX. The Musts are the shift clicks (`<<` and `>>` distinct), the hit, the resisted thud, the Patched chime, the duck squeak, the SIGSEGV alarm and a glyph-glitch sound for each boss.
- GFR65: Music: 4 BeepBox loops, 3 pre-rendered glitch variants that crossfade at phase 3, and 1 muffled Breakpoint loop. No live effects.

**Release**
- GFR66: An itch.io page that leads with the action-combat shift: a cover GIF of a shift into a Dash Strike crit, the line "shift your weapon's bits mid-fight", controls, AI disclosure and credits. A README with the same disclosure and credits. A public GitHub repo.

Total GFRs: 66 (Should: GFR29, GFR57, GFR58; fallback: GFR39).

### Non-Functional Requirements

- GNFR1 (Performance): 60 FPS sustained in Chrome and Firefox on a 2020 mid-range laptop with integrated graphics, at 1280×720, measured during Segfault phase 3.
- GNFR2 (Performance): ≤ 300 live glyph particles.
- GNFR3 (Load): the title screen is interactive in ≤ 10 s on 50 Mbps with a cold cache.
- GNFR4 (Latency): no added input frames, and shift feedback appears on the input frame.
- GNFR5 (Build): the web build is ≤ 30 MB uncompressed (a stripped template if needed).
- GNFR6 (Platform): Godot 4 + GDScript, Compatibility renderer (WebGL2), single-threaded web export with no SharedArrayBuffer/COOP/COEP, and Sample audio playback.
- GNFR7 (Rendering): 640×360 base, integer-scaled and pixel-perfect.
- GNFR8 (Browsers): Chrome and Firefox fully supported. Safari playable, with no crash over a full run and cosmetic quirks accepted. Mobile is not supported.
- GNFR9 (Reliability): storage failure falls back silently. Zero blocking bugs across 3 consecutive full runs.
- GNFR10 (Simulation): logic runs at a fixed 60 FPS, and all timings are in frames.
- GNFR11 (Usability): the shift is taught within 30 s of the first title click, and retry takes ≤ 2 s.
- GNFR12 (Readability): every attack has a tell of ≥ 20 frames, and walking escapes every tell of ≥ 40 frames except Constrict.
- GNFR13 (Schedule): 7 strictly sequential epics, each ending with an itch.io draft deploy and a Chrome/Firefox smoke test. MVP gate on Nov 14 with ≥ 3 playtesters. Submission by 2026-11-29 12:00 PST.
- GNFR14 (Licensing): assets are CC0 or CC-BY with credits (no NC/ND), and the font is CC0 or OFL.
- GNFR15 (Compliance): AI use is disclosed in the README and on the itch.io page. Public source repo, per the jam rules.
- GNFR16 (Gameplay metrics): first Patch for ≥ 80% of players; Boss 1 cleared by ≥ 80% of players within 3 attempts; a full run of 10–15 min; shift feel rated ≥ 4/5; ≥ 50% of players mention the shift unprompted.

Total GNFRs: 16

### Additional Requirements

- **Cut ladder, applied in order:** (1) Reserved Write → (2) Watch, replaced by Null Pointer flickering for 20 frames every 2 s and decoys that don't hum → (3) Breakpoint, with SIGSEGV's recovery raised to 150 → (4) Segfault, with the ending after Null Pointer and no NULL drop. Each cut has to be removable without breaking the rest.
- **Tuning:** all numbers are first-pass and are re-tuned after the Nov 14 playtest. The ×0.5 and ×1.5 multipliers are **not** tuning levers. The lever order is boss HP → tell → recovery → gap → player HP.
- **Pillar steers:** no damage source may bypass ×0.5 outside Patched, and each phase's weak window must differ from the previous phase's.
- **Assets:** 1 font, the glyph layouts (3 bosses, 2 decoys, the garbage bit, the dummy), 1 arena and 3 dressings, 3+1 panels, about 20 SFX, 4+3+1 music tracks, and the text (10 duck lines, 3 fixed lines, 3 comments).
- **Dependencies:** the Godot single-threaded web template on itch.io, BeepBox, jsfxr, the font, and playtesters available by Nov 14 and Nov 27.

### GDD Completeness Assessment

- **Strong:** the GDD is v1.0 final. Every mechanic has frame-level data, every boss has phase, attack and damage arithmetic, and the decision log records 44 resolved decisions with superseded entries marked and no open designer notes. Requirements are quantified and testable.
- **Minor gaps or ambiguities to watch in coverage:**
  - (a) Boss 3's per-boss glyph-glitch SFX and Boss 1's `;` Spit details (projectile damage and recovery) aren't given in frames.
  - (b) Constrict says "escape with an invulnerable move", but the GDD doesn't define what happens if the player is caught (presumably 1 HP).
  - (c) Corrupted-tile timing appears as `░` 60 → `▓` 240 in the Corrupt Memory row but is split across tell and active columns. It is consistent.
  - (d) The fullscreen button's placement isn't specified.
  - (e) "Progress persists" doesn't say whether the assist toggle setting persists too.

## Epic Coverage Validation

`epics.md` has its own inventory of 64 FRs and 17 NFRs, plus an explicit FR Coverage Map (every FR1–FR64 is mapped to an epic). Each story lists its `Requirements:`. Below, each independently extracted GFR from step 2 is traced to the stories whose **acceptance criteria** actually implement it, so a claim in the map alone doesn't count.

### Coverage Matrix

| GFR | Requirement (short) | Epics FR | Story (AC) | Status |
|---|---|---|---|---|
| GFR1 | 8-dir movement 7 t/s, accel/decel, facing | FR1 | 2.2 | ✓ |
| GFR2 | Hurtbox, 5 HP, 1 dmg, 60f i-frames | FR2 | 2.2 (def), 2.9 | ✓ |
| GFR3 | 32×18 clamp, contact damage, pass-through | FR3 | 1.5, 2.2, 3.1, 2.9 | ✓ |
| GFR4 | Cancel into DASH / Null Dodge | FR14 | 2.5, 5.5 | ✓ |
| GFR5 | Owned-bit ring, reserved nibble | FR4 | 2.3 | ✓ |
| GFR6 | Active window J/K | FR5 | 2.3 | ✓ |
| GFR7 | Q/E 0-frame shift, 8f hit-stop buffer | FR6 | 2.1, 2.3 | ✓ |
| GFR8 | Shift previews (names / glyphs) | FR7 | 2.3, 2.6 | ✓ |
| GFR9 | Append insertion, fight-start registers | FR8 | 2.3, 3.7, 5.6 | ✓ |
| GFR10 | Hex byte value incl. `0xFF` | FR9 | 2.3, 6.8 | ✓ |
| GFR11 | ATTACK slash + 3-hit chain | FR10 | 2.5 | ✓ |
| GFR12 | DASH | FR11 | 2.5 | ✓ |
| GFR13 | LOOP Echo | FR12 | 4.1 | ✓ |
| GFR14 | Null Dodge + Clean Catch | FR13 | 5.5 | ✓ |
| GFR15 | Combo trigger / ordered / data-driven | FR15 | 2.6 | ✓ |
| GFR16 | 4 combos' frame data | FR16–19 | 2.6, 4.2, 6.1, 6.2 | ✓ |
| GFR17 | No-combo windows + buffering | FR20 | 2.6 | ✓ |
| GFR18 | Weak window → Patched (4 cases), refresh | FR21 | 3.2, 4.2, 6.1 | ✓ |
| GFR19 | Damage states, rounding | FR22 | 2.7, 3.2, 5.5 | ✓ |
| GFR20 | Resisted / crit feedback | FR27 | 3.2 | ✓ |
| GFR21 | `// patched` tag/bar, visible when invisible | FR23 | 3.2, 5.1 | ✓ |
| GFR22 | Practice target base damage | FR22, FR59 | 2.7 | ✓ |
| GFR23 | Breakpoint | FR24 | 4.3, 5.6 | ✓ |
| GFR24 | Watch | FR25 | 5.4 | ✓ |
| GFR25 | Hit-stop table and shakes | FR26, FR27 | 2.8, 2.9, 3.2, 3.7, 6.2 | ✓ |
| GFR26 | Shift juice | FR28 | 2.4 | ✓ |
| GFR27 | Jitter at 66% / 33% | FR29 | 3.1 | ✓ |
| GFR28 | Keyboard map, no Shift keys, 8f buffer | FR58 | 1.7, 2.1 | ✓ |
| GFR29 | Gamepad (Should) | FR61 | 7.5 | ✓ |
| GFR30 | Press-to-start, audio unlock, 30-s clock | FR47 | 1.4 | ✓ |
| GFR31 | Boss framework | FR30 | 3.1 | ✓ |
| GFR32 | Tells ≥ 20f **visible and audible**; exact-size AoE; no off-screen | FR31 | 3.1 (≥ 20f validate), 3.4, 5.2, 6.4 (exact size) | ⚠️ **Partial**: no story AC requires an *audible* tell per attack, and 7.2's SFX list has no tell cues. "No off-screen attacks" has no AC |
| GFR33 | Defeat: 20f, fixed line, squeak | FR29 | 3.7, 5.6, 6.3 | ✓ |
| GFR34 | Boss signature header | FR32 | 3.1 | ✓ |
| GFR35 | Infinite Loop body | FR33 | 3.3 | ✓ |
| GFR36 | Infinite Loop phases | FR34 | 3.3, 3.5 | ✓ |
| GFR37 | Head Rush, Constrict, Nested Loop, `;` Spit | FR35, FR36 | 3.4, 3.5 | ✓ |
| GFR38 | `[D,A]` start, still until first shift, T1–T4 | FR33, FR45 | 3.3, 3.6 | ✓ |
| GFR39 | Boss 1 fallback (P1–2) | NFR16 | 3.5, 3.8 | ✓ |
| GFR40 | Null Pointer body / visibility / cues | FR37 | 5.1 | ✓ |
| GFR41 | NullPointerException, decoys never stun | FR38 | 5.3 | ✓ |
| GFR42 | NP phases and attacks | FR39 | 5.1, 5.2, 5.3 | ✓ |
| GFR43 | Segfault body | FR40 | 6.3 | ✓ |
| GFR44 | Segfault phases | FR41 | 6.3 | ✓ |
| GFR45 | Segfault attacks | FR42–44 | 6.3, 6.4, 6.5, 6.6 | ✓ |
| GFR46 | SIGSEGV fairness | FR43 | 6.5 | ✓ |
| GFR47 | Corrupted tiles only interactive element | FR42 | 6.4 | ✓ |
| GFR48 | 10 duck lines, text bubble + squeak, **no voice acting** | FR45 | 3.6, 5.6, 6.7, 6.8, 6.9 | ⚠️ Covered, but 3.6 adds a mumble-speech **voice** (AD-14). That's a delta from the GDD's "No voice acting" (see below) |
| GFR49 | Hint template + triggers | FR46 | 4.4 | ✓ |
| GFR50 | Run sequence, no level select | FR52 | 1.6, 3.7, 5.6, 6.3 | ✓ |
| GFR51 | Intro ≤ 8 s, skippable | FR48 | 6.7 | ✓ |
| GFR52 | Harvest ≤ 8 s, skip after 2 s | FR50 | 3.7, 5.6 | ✓ |
| GFR53 | Ending ≤ 30 s | FR51 | 6.8 | ✓ |
| GFR54 | Death screen, ≤ 2 s retry, snapshot | FR49 | 2.9 | ✓ |
| GFR55 | Save/resume, silent fallback, **full HP between fights** | FR52, FR53 | 7.3 | ⚠️ **Partial**: no AC states that HP is restored to full when a new fight starts after Harvest (2.9 covers only retry) |
| GFR56 | Auto-pause, Esc pause with controls | FR54 | 1.7 | ✓ |
| GFR57 | Assist toggle (Should) | FR60 | 7.4 | ✓ |
| GFR58 | Practice target on title (Should) | FR59 | 7.6 | ✓ |
| GFR59 | Fullscreen button | FR55 | 7.7 | ✓ |
| GFR60 | The Clearing + IDE HUD | FR56, FR57 | 1.5 | ✓ |
| GFR61 | Per-boss sky comments | FR56 | 3.3, 5.1, 6.3, 6.9 | ✓ |
| GFR62 | Palette, red only for warnings | NFR8 | 1.1, 1.5, 4.3, 6.5 | ✓ |
| GFR63 | Font 16-px grid, `@` + `>o` | NFR8 | 1.5, 2.2 | ✓ |
| GFR64 | SFX Musts + per-boss glitch | FR63 | 2.4, 3.2, 7.2 | ✓ |
| GFR65 | Music 4+3+1, crossfades | FR62 | 4.3 (placeholder), 7.1 | ✓ |
| GFR66 | itch.io page, README, repo | FR64 | 7.9 | ✓ |

**NFRs:** all 16 GNFRs map to epics NFR1–NFR17 and to verifying stories: 1.1, 1.3, 2.1, 2.8, 3.8, 6.4, 7.7, 7.8 and 7.9. GNFR13's "every epic ends with an itch.io deploy and a Chrome/Firefox smoke test" is stated as an epic-level rule, but no per-epic story or Definition of Done carries it (see step 5).

### Missing Requirements

There are no critical misses: every GDD requirement has an implementation path.

**High priority (partial coverage)**
- **GFR32: audible tells.** The GDD (Pillar 2) requires every boss attack to have a visible **and audible** tell of ≥ 20 frames. Only SIGSEGV's alarm and the Null Pointer hum are specified. *Recommendation:* add an AC to 3.1 (an `AttackDef.tell_sfx` field, validated as non-empty) and list the tell cues in 7.2. Also add an AC for "no off-screen attacks" (spawns or tells inside the 32×18 view).
- **GFR55: full HP between fights.** *Recommendation:* add an AC to 3.7 or 1.6 stating that entering FIGHT after Harvest resets player HP to max (5, or 8 with assist) and resets cooldowns.

**In epics but not in the GDD (needs designer sign-off)**
- **Duck voice (AD-14, mumble-speech) in Story 3.6.** The GDD's Duck section says "No voice acting". The epics list it among the "design calls pending designer confirmation" as a GDD delta. *Recommendation:* confirm it and update the GDD (D-045), or drop it to text + squeak only.
- **The six architecture design calls** (any shift closes the link; a cooldown-blocked combo is buffered then dropped; the chain continues with the same button and resets on shift; Breakpoint CD counts from its end in sim frames; Echo ignores startup-cancelled actions; the duck voice) are implemented in stories 2.5, 2.6, 4.1, 4.3 and 3.6, but they're still marked "pending designer confirmation".
- Small extras that are fine and add value: debug F-keys, replays, CI, the test framework, and tells ×1.5 applied at read time.

### Coverage Statistics

- Total GDD FRs (independent extraction): 66
- Fully covered: 64
- Partially covered: 2 (GFR32, GFR55)
- Not covered: 0
- Coverage: **97% full / 100% with a path**
- Epics' own FR Coverage Map: 64/64 FRs mapped, and each one is traced to at least one story's `Requirements:` line

## UX Alignment Assessment

### UX Document Status

**Not found, by design.** The game is player-facing with a heavy HUD and 7 screens (Title, Intro, Fight, Dead, Harvest, Ending, Pause), so UX is clearly implied. The GDD covers it in Art Style → HUD, Controls, Level Types and Hit Feedback. `epics.md` turns it into FRs (FR4–FR9, FR23, FR26–FR29, FR32, FR47–FR51, FR54–FR57). The architecture supports every HUD and screen element: `src/ui/hud/` (register panel, log panel, boss header, Patched tag, cooldowns, line numbers), `src/ui/screens/` (title, intro, harvest, dead, ending, pause), `DuckBubble`, `ScreenFX` and the one-way EventBus. Performance and responsiveness (60 Hz tick, feedback on the input frame, HUD animating in `_process` during hit-stop and Breakpoint) are explicitly designed for.

### Alignment Issues

1. **HUD layout budget is unspecified and probably doesn't fit as written (High).** The base resolution is 640×360 and the play area is 32×18 tiles × 16 px = 512×288, which leaves a **128-px left column** and a **72-px bottom strip**. At a 16-px glyph grid, that left column is **8 characters wide**, and it has to hold all of these: line numbers, an 8-bit register, faded `<<`/`>>` previews *to the left and right* of the active window, combo names (e.g. "Dash Strike" is 11 chars), the `J→K` glyph, the hex value and the cooldowns. The bottom strip (4.5 rows) has to hold the log panel, and the boss header and sky comment need space too. No document gives pixel or cell positions. Story 1.5 only says "matches the GDD layout". *Recommendation:* add a HUD cell-layout spec (an ASCII wireframe) to Story 1.5, or decide on a smaller HUD glyph size or an overlaid HUD. The GDD says "one monospace pixel font on a 16-px grid", so a HUD font size change would need a decision.
2. **Press-to-start conflicts with the title-screen controls (High).** The title screen starts the game on **any key or click** (FR47, Story 1.4). It also has to host a **fullscreen button** (7.7), the **assist toggle** (7.4, Should) and a **practice** entry (7.6, Should). Clicking any of those would count as "any click" and start the run. *Recommendation:* define the title interaction: the first input only unlocks audio and shows a menu (Start / Practice / Assist / Fullscreen), or "any key except the clickable buttons". Note that the GDD's 30-s clock starts on that first input.
3. **No "New run" once a save exists (Medium).** Story 7.3 always resumes at the highest boss reached. The GDD has no level select (fine), but a player who wants to replay from Boss 1 (mastery replay value, GDD Progression) can't without clearing storage. *Recommendation:* add "Continue / New run" to the title screen when `highest_boss > 1`.
4. **Pause-screen interaction model is undefined (Low).** Pause has to show the controls and also host the assist toggle and the fullscreen button, but nothing says whether these are mouse-clicked or keyboard- or gamepad-navigable (relevant to 7.5 gamepad, Should). *Recommendation:* specify keyboard and gamepad focus navigation for the menu items.
5. **Duck voice delta (Medium, also in step 3).** The GDD says "No voice acting", while the architecture (AD-14) and Story 3.6 add a mumble-speech voice with typewriter reveal. It's listed as pending designer confirmation.

### Warnings

- ⚠️ There's no dedicated UX document. That's acceptable for a jam-scale project, because the GDD + FRs + architecture carry the requirements. But issues 1–2 are exactly the kind of gap a lightweight UX pass (a HUD wireframe plus a screen-interaction table) would catch. A short wireframe added to Story 1.5 is enough; a full UX document isn't needed.
- ⚠️ **No audio volume/mute control** anywhere. The architecture mentions "volume if added". Jam raters often play with other tabs open. *Suggestion:* a Should-level mute toggle on the pause screen (M key).
- ⚠️ **Accidental restart on the DEAD screen.** "Any input restarts" means a key held during death (e.g. the movement key) could restart instantly. *Suggestion:* only accept a *new* press after a short delay (e.g. 20 frames), still within ≤ 2 s.

## Epic Quality Review

Scope: 7 epics and 52 stories (E1 7, E2 9, E3 8, E4 4, E5 6, E6 9, E7 9), all in "As a / I want / So that" form with Given/When/Then ACs and a `Requirements:` trace line.

### Epic Structure

| Epic | Player value | Independent (uses only earlier epics) | Verdict |
|---|---|---|---|
| 1 Web Foundation | Borderline title, but the goal is player-facing: the game opens on itch.io with a title, arena and pause. 1.1–1.3 are developer stories, which is justified for a greenfield web jam (no starter template; the GDD requires a deploy from day 1) | ✓ | 🟡 Acceptable. Consider renaming it to "Playable Shell on itch.io" |
| 2 Player Core & Register | ✓ "the shift feels great in an empty arena" | ✓ | ✓ |
| 3 Infinite Loop (MVP) | ✓ a complete vertical slice | ✓ (Echo Dash and decoy Patched cases stubbed and tested via `BossInteraction`) | ✓ |
| 4 LOOP Combos & Breakpoint | ✓ | ✓ (verified against the Boss 1 / test boss; Fight 2 is still a placeholder) | ✓ |
| 5 Null Pointer & Watch | ✓ | ✓ | ✓ |
| 6 Segfault, Intro & Ending | ✓ | ✓ | ✓ |
| 7 Audio, Polish & Submission | ✓ | ✓ | ✓ |

There are no technical-milestone epics and no epic requires a later epic. Cut-ladder items are behind `FeatureFlags` and each has an "off" AC (4.3, 5.4, 5.6, 6.3, 6.6), which is excellent.

### Dependency Analysis

**No blocking forward dependencies were found.** All forward mentions are explicitly deferred, and the current story can still be completed and tested without them:
- 2.3 previews: "combo names are added in Story 2.6" (within the epic, deferred) ✓
- 2.5: "cancel rule also accepts Null Dodge, used from Epic 5" ✓
- 3.2: PASS_THROUGH and DECOY_STRUCK are verified with stubs; the real sources are 4.2 and 6.1 ✓
- 3.7: `bit_loop.tres` is created with a NOP solo action, and 4.1 replaces it ✓ (good just-in-time data creation)
- 5.4: "Ghost Echo decoys later" ✓
- 5.6: cut #4 plays "the Ending" directly. The Ending is a 1.6 placeholder until 6.8 ✓

**Hidden dependency to make explicit:**
- **6.1 Ghost Echo: "bosses target the decoy".** This needs a boss-side *target provider* (e.g. `ArenaContext.target_position()`) that every attack uses instead of reading the player position directly. Story 3.1 (framework) doesn't establish one, so the Boss 1–2 attacks built in Epics 3–5 will probably read the player position directly, and 6.1 will need a retrofit. *Fix:* add an AC to 3.1 stating that attacks get their target only through `ArenaContext`.

### Story Quality Findings

#### 🔴 Critical Violations

None.

#### 🟠 Major Issues

1. **Design calls still "pending designer confirmation" (6 items, architecture → Notes for Designer).** Stories 2.5, 2.6, 4.1, 4.3 and 3.6 already implement them as ACs: any shift closes the link; a cooldown-blocked combo is buffered then dropped; the chain continues with the same button; Breakpoint CD counts from its end; Echo ignores actions cancelled in startup; the duck voice. Epic 2 starts **Nov 8**. *Fix:* Tiziano confirms or overrides them, the decisions are logged as D-045+ in the GDD decision log, and the "pending" label is removed from `epics.md`.
2. **Story 3.6 is oversized, and an external dependency sits on the MVP critical path.** It bundles the duck bubble, the mumble-speech web GDExtension (I-6, experimental gdext wasm, issue #32), a fallback pre-render backend and the tutorial beats T1–T4, all inside the 4-day MVP epic. *Fix:* split it into **3.6a Duck bubble + text tutorial beats** (MVP-critical) and **3.6b Duck voice (VoiceService + backend choice)**, which can slip without blocking the Nov 14 gate. Also run the I-6 smoke test in Epic 1 or 2, not "before Epic 3".
3. **The per-epic "deploy + smoke test" rule isn't carried by any story.** GNFR13/NFR16 require every epic to end with an itch.io draft deploy and a Chrome/Firefox smoke test. Only 1.3 does it. *Fix:* add a standard Definition of Done in sprint planning (or a closing AC in each epic) that says "build deployed with butler to the draft page; smoke-tested in Chrome + Firefox; size recorded".
4. **Schedule density vs the 2026-11-06 start.** Today is Nov 6 (evening). Epic 1 has 7 stories in a Nov 6–7 window, and implementation-artifacts is empty. Epic 2 has 9 stories in 3 days, Epic 6 has 9 in 4 days, and Epic 7 has 9 in 4 days, including composing 8 music tracks, the full-run playtest (playtesters needed by Nov 27) and submission. In total that's 52 stories in 23 days. *Fix:* in sprint planning, mark the Shoulds (7.4, 7.5, 7.6) and the stretch goals (the 6.8 summary) as droppable first. Consider starting the music (7.1) in parallel during Epics 5–6, since it's composed outside code and doesn't depend on them.
5. **Several large stories.** 2.1 (sim clock + input buffer + RNG + replay recording/playback + replay test), 3.1 (the entire boss framework + data validation + contact damage + HUD header + debug keys) and 2.6 (combo engine + 5 design-call behaviours + HUD + tests) are each a day or more of work. *Fix (optional):* split the replay record/playback in 2.1 into its own story. Keep 3.1 whole but timebox it.

#### 🟡 Minor Concerns

- **The MVP metric uses a placeholder Intro.** 3.8 measures the "first shift ≤ 30 s from the title input, intro included" metric, but the real Intro arrives only in 6.7. *Fix:* make the 1.6 placeholder Intro ≤ 8 s (or ~8 s of filler) so the Nov 14 measurement is representative.
- **The free first Breakpoint is specified twice** (4.3 AC and 5.6 AC). Keep it in one story (4.3) and reference it from 5.6.
- **The schema is defined up front.** The `ActionStateMachine` enum includes STUNNED and WATCHING in 2.5 (used in Epic 5), and `AttackDef` has `exclusive` and `recovery_if_no_breakpoint` in 3.1 (used in Epic 6). These are low-cost and harmless, but they deviate from just-in-time creation.
- **Vague or subjective ACs:** 7.2 says "no audible latency on the shift click" (it could be made measurable, e.g. "SFX starts on the input frame, verified via the F9 overlay/log"). 5.1 says "can be located by sound only / by sight only", which is a playtest observation and should be moved to the 3.8/7.8 playtest checklists.
- **2.4** asserts HUD behaviour during Breakpoint, which doesn't exist until 4.3. That part of the AC is only testable later. Mark it "(verified in 4.3)".
- **Story numbering drifts between the architecture and the epics.** The architecture cites "story 1.6" for pause (it's 1.7 in epics) and "Epic 1.5" for debug keys (it's 1.6). Update the architecture references so dev agents aren't misled.
- **7.3 writes an `assist` key** before 7.4 creates the toggle. It's harmless (default false), but note it in 7.3.

### Special Checks

- **Starter template:** the architecture says no template (an empty Godot 4.7.2 project). Story 1.1 is the project-setup story with the full configuration ✓
- **Greenfield setup:** project setup (1.1), test framework + CI (1.2) and the build/deploy pipeline (1.3) all come early ✓ The day-1 smoke tests (panning, GUT) are in 1.2 and 1.3 ✓

### Best Practices Compliance

| Check | E1 | E2 | E3 | E4 | E5 | E6 | E7 |
|---|---|---|---|---|---|---|---|
| Player value | 🟡 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Independent | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Stories sized | ✓ | 🟠 (2.1, 2.6) | 🟠 (3.1, 3.6) | ✓ | ✓ | ✓ | 🟠 (density) |
| No forward deps | ✓ | ✓ | 🟡 (3.1 target provider) | ✓ | ✓ | ✓ | ✓ |
| Data when needed | ✓ | 🟡 | 🟡 | ✓ | ✓ | ✓ | ✓ |
| Clear ACs | ✓ | ✓ | ✓ | ✓ | 🟡 (5.1) | ✓ | 🟡 (7.2) |
| FR traceability | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Overall:** the epics are of high quality. They are unusually precise, test-driven and trace to FRs and architecture decisions, and the cut ladder is engineered rather than just promised. No structural defects block implementation. The major items are decisions and splits that can be made in under an hour.

## Summary and Recommendations

### Overall Readiness Status

**NEEDS WORK, but light.** Epic 1 can start now (except Story 1.5, which should wait for the HUD layout decision). The planning set is strong: the GDD is v1.0 final and fully quantified, the architecture has passed validation, and the epics are precise, test-driven and trace back to the GDD. Every GDD requirement has an implementation path (64/66 fully covered, 2 partially). Nothing structural is broken. What's left is a short list of **decisions** and **story edits**, and they should be made before the stories that depend on them are created.

### Critical Issues Requiring Immediate Action

None are blocking on their own, but these four have deadlines:

1. **Confirm the 6 architecture design calls** (link closes on shift; cooldown-blocked combo buffered then dropped; chain on the same button; Breakpoint CD from its end; Echo ignores startup-cancelled actions; duck voice vs the GDD's "no voice acting"). → **Before Epic 2 (Nov 8).** Log them as D-045+ and update the GDD for the voice delta.
2. **Decide the HUD layout.** In a 128-px (8-glyph) left column and a 72-px bottom strip at 16-px glyphs, the register + previews + combo name + hex + cooldowns + line numbers don't fit as specified. → **Before Story 1.5.** Add an ASCII cell wireframe to 1.5, or decide on a HUD glyph size or an overlay.
3. **Define the title-screen interaction.** "Any key or click starts the game" conflicts with the fullscreen button, the assist toggle and the practice entry on the same screen. Also add Continue / New run when a save exists. → **Before Story 1.4** (resolving it in 7.x is acceptable only if 1.4 stays a pure "press to start").
4. **Split Story 3.6** into 3.6a (bubble + text tutorial, MVP-critical) and 3.6b (mumble-speech voice), and run the I-6 web smoke test early. → **Before Epic 3 (Nov 11).**

### Recommended Next Steps

1. **Decide now (≈ 30 min):** items 1–3 above. Tiziano has delegated design calls before ("fai tu"), so the facilitator can propose them and Tiziano approves in a batch.
2. **Patch `epics.md` (≈ 30 min):**
   - add the audible-tell AC (`AttackDef.tell_sfx`) and the target-provider AC to 3.1;
   - add the full-HP-between-fights AC to 3.7;
   - split 3.6;
   - make the 1.6 placeholder Intro ≤ 8 s;
   - de-duplicate the free first Breakpoint;
   - tighten the 7.2 and 5.1 ACs;
   - remove the "pending" label once item 1 is done.
3. **Sprint planning (`gds-sprint-planning`):** add a per-epic Definition of Done ("deployed with butler to the itch.io draft + Chrome/Firefox smoke + size recorded"), mark 7.4, 7.5, 7.6 and the 6.8 summary as first-to-drop, and consider starting the music (7.1) in parallel during Epics 5–6.
4. **Optional quality-of-life additions** (Should): a mute toggle on pause, a ~20-frame new-press guard on the DEAD screen, and keyboard/gamepad focus navigation for menu items.
5. **Fix the story-number drift** in `game-architecture.md` (pause 1.6 → 1.7, debug keys 1.5 → 1.6).

### Final Note

This assessment found **21 issues across 3 categories**: requirements coverage (2 partial), UX alignment (6) and epic/story quality (13, including the pending design calls). None of them are critical defects. Four have near-term deadlines (Nov 7–11). Fix those, and the project is ready for Phase 4. The other findings can be handled during sprint planning or left as they are.

---

**Assessor:** Game Producer / Scrum Master (gds-check-implementation-readiness)
**Date:** 2026-11-06

---

## Resolution Log (applied 2026-11-06, after the assessment)

Tiziano approved the batch of recommended resolutions ("ok"). Each one is logged as a **[design call]** in the GDD decision log, so it can be overridden later.

| Finding | Resolution | Where |
|---|---|---|
| 6 pending architecture design calls | Confirmed as specified | GDD D-045, D-046; GDD v1.1 (Combos → Resolution rules, Echo, Breakpoint CD, Duck format); architecture Notes for Designer marked confirmed; epics "Design calls confirmed" |
| Duck voice vs "no voice acting" | Mumble voice accepted, and non-blocking for the MVP | D-046; Story 3.6 split → 3.6 (bubble + text) and **3.7 (voice)**; old 3.7 → **3.8**, old 3.8 → **3.9**; I-6 check pulled into Story 1.3 |
| HUD layout doesn't fit | One 8×8 CP437 font: world at 2×, HUD at 1× on an 8-px grid (80×45 cells); GDD wireframe; vertical register panel with the `<<` preview above and the `>>` preview below; duck bubble in the left column | D-047; GDD Art Style → HUD Layout; Story 1.5 ACs; architecture AD-07; project-context |
| Title press-to-start conflict, no new run, pause model, no mute | Option hotkeys (`N`/`P`/`B`/`F`; pause `Esc`/`F`/`B`/`M`); any other input starts; Continue / New run when a save exists; mute (Should) | D-048; GDD Controls; FR47, FR54, FR55; Stories 1.4, 1.7, 7.3, 7.4, 7.6, 7.7 |
| GFR32 audible tells / no off-screen | One tell cue per boss; `tell_sfx` validated; tells and spawns inside the arena | D-049a; Story 3.1, 7.2; FR31 |
| GFR55 full HP between fights | Full HP and cooldown reset at every fight start | D-049b; FR52; Stories 3.8, 7.3 |
| DEAD-screen accidental restart | Only a new press ≥ 20 frames after death counts | D-049c; FR49; Story 2.9 |
| Ghost Echo needs target abstraction | `ctx.target_position()` from Story 3.1 | D-049d; architecture NP-3 components; Story 3.1 |
| Per-epic deploy rule not carried | Definition of Done for every epic | epics.md → Epic List |
| Placeholder intro skews the MVP metric | Placeholder Intro ≤ 8 s | Story 1.6 |
| Free first Breakpoint specified twice | Kept in 4.3; 5.6 references it | Stories 4.3, 5.6 |
| Vague ACs (5.1, 7.2), 2.4 Breakpoint AC, 7.3 `assist` key | Made measurable / moved to the 7.8 playtest / annotated | Stories 2.4, 5.1, 7.2, 7.3, 7.8 |
| Story-number drift in architecture | Fixed (pause 1.7, debug keys 1.6) | game-architecture.md |
| itch.io embed scale | 1280×720 embed (2×) | GDD Platform; Story 1.3 |

**Still open (sprint planning):** the schedule density (mark 7.4, 7.5, 7.6 and the 6.8 summary as first to drop; start the music early) and the optional splitting of the large stories 2.1, 2.6 and 3.1.

**Updated status:** **READY** for Phase 4. The decision-type and story-edit findings are all resolved. What's left is a sprint-planning concern.

A backup of `epics.md` from before these edits is in the session scratchpad (`epics.before-readiness.md`).
