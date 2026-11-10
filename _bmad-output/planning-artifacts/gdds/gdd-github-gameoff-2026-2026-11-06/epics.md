---
title: "The Debugger 0x03: Wild Shift — Development Epics"
gdd: gdd.md
created: 2026-11-06
updated: 2026-11-06
version: 1.0
---

# Development Epics — The Debugger 0x03: Wild Shift

## Ground Rules

- Epics run strictly in sequence, in day windows that don't overlap.
- Every epic ends with a **web build uploaded to the itch.io draft page** and a smoke test in Chrome and Firefox.
- Stories here are high-level. `gds-create-epics-and-stories` refines them after the architecture work.
- **Cut ladder:** if any epic overruns its window by more than 1 day, apply the next cut from the GDD's Out of Scope section.
- **Pillar key:** P1 = The shift is the fight · P2 = Readable at a glance · P3 = Bugs behave like their bugs · P4 = Every shift feels great.

---

## Epic 1 — Web Foundation (Nov 6–7)

**Goal:** the project runs in the browser on itch.io before any gameplay exists.
**Pillars:** enables all four.

| ID | Story | Acceptance |
|---|---|---|
| 1.1 | Project setup: 640×360 base, integer scaling, 60 FPS simulation | Runs at 60 FPS with crisp pixels at 1280×720 |
| 1.2 | Web export (single-threaded, Sample audio mode) uploaded to an itch.io draft page | Loads in Chrome, Firefox and Safari; build ≤ 32 MB (raised from 30 MB on 2026-11-10) |
| 1.3 | Title screen with press-to-start (any key or click), which unlocks audio and leads into the Intro. This first input starts the 30-s first-shift clock (Gameplay Metrics) | No audio before the first input; a test SFX plays after it; the same input that starts the game does not skip the Intro |
| 1.4 | Arena shell: The Clearing, 32×18 play area, tree-line walls, IDE HUD frame (register panel, log panel, line numbers) | Layout matches the GDD's Arena Design |
| 1.5 | Scene flow with placeholders: Title → Intro → Fight 1 → Harvest → Fight 2 → Harvest → Fight 3 → Ending | Each screen is reachable with a debug key |
| 1.6 | Auto-pause on tab or focus loss; Esc pause screen that shows the controls | Switching tabs pauses the game; play stays paused until the next input |

## Epic 2 — Player Core & Register (Nov 8–10)

**Goal:** the shift feels great in an empty arena.
**Pillars:** P1, P2, P4.

| ID | Story | Acceptance |
|---|---|---|
| 2.1 | 8-direction movement (7 tiles/s, 4-frame acceleration, 3-frame stop), facing, arrow-key alternative | Values match the GDD |
| 2.2 | Register ring of owned bits: Q = `<<`, E = `>>`, active window = 2 leftmost slots, reserved nibble shown, shift previews | Rotation skips unowned slots; no dead state; previews match the result of Q/E; the HUD shows the register's byte value (e.g. `0x03`) |
| 2.3 | Shift juice: 6-frame slide with bounce, key-click SFX, 4-frame weapon inversion | Feedback appears on the input frame; playtesters rate it ≥ 4/5 |
| 2.4 | ATTACK (3-hit chain) and DASH (invulnerable on frames 1–8, 24-frame cooldown) | Frame data matches the GDD's Bits table |
| 2.5 | Combo engine: ordered windows as data, link window (Action 1's active frames + 18 frames), Dash Strike (A→D); windows with no combo (D→A, L→A) perform the two solo actions | Each combo fires only from its window order; D→A performs dash then slash; frame data matches the GDD's Combos table |
| 2.6 | Hit feedback: hit-stop table and precedence, glyph particles, `console.log` damage lines | Normal, combo and crit hit-stop values match the GDD |
| 2.7 | Player HP of 5 (`0b11111`), 60-frame invulnerability after a hit, `Process exited with code 1` screen, retry in ≤ 2 s | Retry restores the register to its state at fight start |
| 2.8 | Practice target `/* test */`: infinite HP, damage log, frame counter; takes base damage (damage-state multipliers apply to bosses only) | Combo damage and frame data can be verified on screen |

## Epic 3 — Infinite Loop (MVP) (Nov 11–14)

**Goal:** a complete vertical slice.
**MVP gate (Nov 14):** a playtest with at least 3 people.
**Fallback:** if the epic is late, ship phases 1–2 only.
**Pillars:** P1, P2, P3.

| ID | Story | Acceptance |
|---|---|---|
| 3.1 | Boss framework: HP, phase thresholds, attack pool with no triple repeats, gap between attacks, tell/active/recovery states, 60-frame phase-change roar | Reusable by Bosses 2 and 3 |
| 3.2 | Weak window and damage states: 180-frame Patched state applied by the weak window (combo, or a no-combo pair performed in order within the 18-frame link) affecting the boss; tag and countdown bar; refresh on re-apply. **Unpatched ×0.5** (resisted: dithered `// resisted` log line, smaller damage glyphs, half particles, dull thud) and **Patched ×1.5** (CAPS crit log); Clean Catch ×1.5 on top of either; multipliers combine and round half up once | All "affects the boss" cases are testable, including the D→A no-combo pair (Echo Dash and decoy cases stubbed). An unpatched slash deals 5 (15 → 8) and logs `// resisted`; a Patched slash deals 15; an unpatched Dash Strike deals 10, a Patched one 30 |
| 3.3 | Infinite Loop body: 24-segment closed ring, spin, drift at 2 tiles/s, contact damage, `i++` counter, `;` open for 90 frames once per lap | Lap ≈ 3 s at 8 tiles/s; +5% speed per lap, capped at 12 tiles/s |
| 3.4 | Attacks: Head Rush, Constrict, Nested Loop (outer ring 16 segments, radius ≈ 2.5 tiles; inner ring 8 segments, radius ≈ 1.3 tiles; inner spin 1.5× capped at 12 tiles/s; `;` openings alternate rings every 3 s, 90 frames each), `;` Spit; per-phase weak windows (P1 A→D; P2 D→A no-combo; P3 outer `;` A→D, inner `;` D→A) | Tell, active and recovery frames and gaps match the GDD tables; no ring exceeds 12 tiles/s; at most one `;` is open at a time |
| 3.5 | Duck tutorial beats 1–4 (duck lines T1–T4); the fight starts at `[D, A]`; the ring stays still until the first shift | First shift within 30 s of the first click on the title screen (intro included) for every playtester |
| 3.6 | Defeat: glyphs reassemble into the fixed line, duck squeak, Harvest screen with the shared harvest duck line, LOOP inserted | Harvest lasts ≤ 8 s and can be skipped after 2 s |
| 3.7 | MVP playtest and tuning pass. Boss HP is re-tuned with the ×0.5 unpatched / ×1.5 Patched multipliers in place; the multipliers are not tuning levers. Check that playtesters read resisted hits as "patch first" | Findings logged; values tuned against the Difficulty Curve (Boss 1 ≈ 9 Patched openings, 60–120 s) |

## Epic 4 — LOOP Combos & Breakpoint (Nov 15–17)

**Goal:** the 3-bit ring and the time-freeze safety valve.
**Pillars:** P1, P4.

| ID | Story | Acceptance |
|---|---|---|
| 4.1 | LOOP bit, Echo: re-executes the last solo bit action at 70% (rounded half up); 90-frame cooldown; cannot echo combos or itself | Echo of a 15-damage hit deals 11; Echo of DASH produces a second dash |
| 4.2 | Echo Dash (D→L) | Frame data and invulnerability match the GDD; Echo Dash has no vulnerability gap |
| 4.3 | Breakpoint: freeze up to 2.0 s, shifting allowed, ends on an action, 12 s cooldown; dithered screen, red line, muffled loop | Cannot be chained; cooldown visible on the HUD |
| 4.4 | Duck hint template "Quack. Weak window: {X→Y}." used by both hint triggers: Breakpoint (once per phase) and the 3rd death against the same boss (trigger logic). In Boss 1 phase 3 it names the window of the ring whose `;` opens next | The template fills the current weak window correctly in every phase |

## Epic 5 — Null Pointer & Watch (Nov 18–21)

**Goal:** Boss 2 and the Watch skill.
**Pillars:** P1, P2, P3.

| ID | Story | Acceptance |
|---|---|---|
| 5.1 | Watch (hold R): reveals hidden entities, highlights the weak window, shows the next attack's name and the boss's bits; ×0.5 move speed; no actions while held | Works on Null Pointer and its decoys; the duck's Watch tutorial line ("Hold R. Pointers point *somewhere*.") plays at fight start |
| 5.2 | Null Pointer body: invisible, falling `null` trail, positional hum, flicker on hit | Locatable by sound alone and by sight alone |
| 5.3 | `NullPointerException` whiff stun (20 frames, boss within 4 tiles) | Hitting a decoy never stuns |
| 5.4 | Attacks: Pointer Grab, Null Rain, Dangling Pointers; weak windows D→L and A→D | Tell, active and recovery frames and gaps match the GDD tables |
| 5.5 | Free first Breakpoint and the duck's Breakpoint tutorial line | — |
| 5.6 | Defeat, fixed line, Harvest, NULL inserted; Null Dodge bit with Clean Catch | Clean Catch gives ×1.5 on top of the damage state: ×2.25 Patched, ×0.75 unpatched |

## Epic 6 — Segfault, Intro & Ending (Nov 22–25)

**Goal:** the final boss and a complete, framed run.
**Pillars:** P1, P2, P3.

| ID | Story | Acceptance |
|---|---|---|
| 6.1 | Ghost Echo (L→N, 120-frame decoy that bosses target) and Dereference (N→A, only during Null Dodge's active frames) | Patched is applied when the boss strikes the decoy |
| 6.2 | Segfault body (6×4 glyphs, 2 tiles/s); Access Violation | — |
| 6.3 | Corrupted tiles (`░` for 60 frames → `▓` for 240 frames); Corrupt Memory; Core Dump | Safe tiles are visible during the tell |
| 6.4 | SIGSEGV: 60-frame tell → register rotated by 2 → guaranteed 90-frame recovery; never overlaps another attack | Fairness rules hold across 10 test runs |
| 6.5 | *(Cut ladder #1)* Reserved Write: garbage bit `?` for 600 frames; reserved nibble flashes | Can be removed without affecting 6.1–6.4 |
| 6.6 | Intro (3 glyph panels, ≤ 8 s, skippable from its first frame with any key or click) and Ending (`1111`, desk, duck, `fix: wild shift`, credits) | Both are reachable in a full run; the Intro never exceeds 8 s; a skip on the Intro's first frame goes straight to Fight 1; the title input itself does not skip it |
| 6.7 | All game text: exactly 10 duck lines per the GDD's Duck table (intro; tutorial T1–T4; Breakpoint tutorial; Watch tutorial; one shared harvest line; ending; the hint template, counted once), 3 fixed lines, 3 sky comments | Every trigger is covered; the duck line count is 10 |

## Epic 7 — Audio, Polish & Submission (Nov 26–29)

**Goal:** a jam-ready release, submitted by **Nov 29 12:00 PST**.
**Pillars:** P2, P4.

| ID | Story | Acceptance |
|---|---|---|
| 7.1 | Music: 4 BeepBox loops, 3 pre-rendered glitch variants with a crossfade at phase 3, and 1 muffled Breakpoint loop | No live audio effects needed |
| 7.2 | SFX pass (~20 sounds, made with jsfxr) | Shift click, hit, resisted (unpatched) thud, Patched chime, squeak and SIGSEGV alarm all present |
| 7.3 | Save and resume at the highest boss reached, with a silent fallback | Works on itch.io; no crash when storage is blocked |
| 7.4 | "Debug build" assist toggle (HP 8, Breakpoint cooldown 6 s, tells ×1.5); the ×0.5 unpatched multiplier is unchanged | Available from the title and pause screens |
| 7.5 | *(Should)* Gamepad support per the GDD mapping; practice target reachable from the title screen | Full run completable on a gamepad in Chrome |
| 7.6 | Full-run playtest (≥ 3 people) and final tuning | Gameplay Metrics checked |
| 7.7 | Browser matrix test (Chrome, Firefox, Safari) and fullscreen button | Technical Metrics checked |
| 7.8 | itch.io page that leads with action combat: cover GIF of a shift into a Dash Strike crit, the line "shift your weapon's bits mid-fight", controls, AI disclosure and asset credits. README with the same AI disclosure and credits. Public GitHub repo | Submitted to Game Off by Nov 29 12:00 PST |
