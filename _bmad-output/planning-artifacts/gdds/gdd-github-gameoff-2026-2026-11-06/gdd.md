---
title: "The Debugger 0x03: Wild Shift"
game_type: action-platformer  # canonical id; actual form: Top-Down Action Boss Rush (no platforming)
secondary_game_type: fighting  # frame data, combo and defense conventions
platforms: [web-html5]
created: 2026-11-06
updated: 2026-11-06
status: final
version: 1.1
sources:
  - _bmad-output/planning-artifacts/briefs/brief-github-gameoff-2026-2026-11-06/brief.md
  - _bmad-output/planning-artifacts/briefs/brief-github-gameoff-2026-2026-11-06/addendum.md
  - _bmad-output/brainstorming-session-2026-11-06.md
---

# The Debugger 0x03: Wild Shift - Game Design Document

**Author:** Tiziano
**Game Type:** Top-Down Action Boss Rush (canonical `action-platformer` with `fighting` conventions; no platforming)
**Target Platform(s):** Web (HTML5, desktop browsers) on itch.io
**Jam:** GitHub Game Off 2026 — theme **SHIFT** — submission deadline 2026-12-01 13:37 PST

> **Facilitation note.** Tiziano delegated the open design decisions to the facilitator on 2026-11-06. Every value not taken from the brief started as a facilitator proposal, logged in `decision-log.md`; Tiziano reviewed the GDD in the Finalize pass (D-028 to D-043) and it is accepted as v1.0. v1.1 applies the implementation-readiness decisions D-045 to D-049. All numbers are first-pass tuning targets, to be re-tuned after the Infinite Loop MVP playtest (Nov 14).

---

## Executive Summary

### Core Concept

A present-day developer and their rubber duck are pulled into a fantasy RPG whose monsters are literal software bugs. The developer sees the code beneath the fantasy world.

Their weapon is a **bit register**: a ring of ability bits the player rotates left (`<<`) or right (`>>`) in real time.
- The two leftmost slots form the **active window**. Those two bits are the player's two action buttons.
- Pressing the two buttons in order fires that window's **combo**.

Three bosses — **Infinite Loop**, **Null Pointer**, **Segfault** — are fought in one arena. Each defeated bug drops a new bit into the register, which changes which combos exist.

**Core fantasy:** *you are the debugger who sees the code beneath the fantasy world, and you rewire your weapon bit by bit mid-fight to squash monstrous bugs.*

**Target experience:**
- The "I read it, I shifted, it worked" rush of adapting in real time.
- A grin at every programming joke that lands as game design.
- 10–15 minutes, finishable in one sitting.

### Target Audience

- **Primary:** Game Off and itch.io jam players and raters. Many are programmers. They play 5–15 minutes in a browser, rate dozens of entries, and decide within ~30 s whether to keep playing.
- **Secondary:** fans of short boss-rush games (Titan Souls, Furi).
- **Design consequences:**
  - The shift is taught within 30 s of the first click on the title screen (the ≤ 8 s intro included).
  - Nothing to install.
  - A full run takes ≤ 15 min.
  - Retry after death takes ≤ 2 s.

### Unique Selling Points (USPs)

1. **The theme is the combat verb.** Shift is the real-time loadout switch that the whole fight depends on. It is not a puzzle operation and not a world toggle. Most bit-shift entries are puzzlers (the official theme post suggests that reading); this one is action combat.
2. **Bugs that behave like their bugs.** Each boss's moveset is its software failure.
3. **1-bit, code-as-fantasy presentation.** A fantasy hunting ground is rendered as text glyphs and framed by a debugger HUD; damage shows up as `console.log` lines.

No moat is claimed. The "developer vs bugs" premise exists in other itch.io games (Game is Full of Bugs, HackeRPG, The Bugger, Coding Nightmares). The differentiators are execution, feel, readability and jokes.

### References

| Reference | Take | Leave |
|---|---|---|
| Monster Hunter Rise | Weighty, frantic hunt feel: reading a monster's patterns and punishing its recovery; weighty, committed hits (expressed here as hit-stop and recovery frames) | The grind, the scale, multiplayer |
| Titan Souls / Furi | A single-arena boss focus; a short, intense run | Furi's long multi-phase duels; Titan Souls' one-hit death |
| Magicka | Element combos from adjacent inputs | Free-form spell input (we use fixed register positions) |
| The Witcher (Witcher senses) | Watch: a scan that reveals what is hidden | — |

**Feel target:** a weighty, frantic hunt.
- Movement is fast and responsive: 7 tiles/s, 0-frame shift.
- The hunt is frantic: 60–120-frame gaps between boss attacks keep the player reading, shifting and repositioning.
- Hits are weighty: 3–8 frames of hit-stop, committed recovery frames, and the punish-the-recovery rhythm.

---

## Goals and Context

### Project Goals

1. Submit a complete, playable web build to GitHub Game Off 2026. The target is **2026-11-29 12:00 PST**, giving ≥ 49 h of buffer before the deadline.
2. Score strongly in **Theme** and **Innovation** by making SHIFT the core combat verb, and in **Gameplay** through hit feel.
   - **Graphics:** a cover GIF and screenshots that show the 1-bit glyph style and a shift moment.
   - **Audio:** the expected weakest category. Mitigation: a distinct sound for each shift direction and a glyph-glitch sound for each boss.
3. Ship a game a first-time player finishes in 10–15 minutes.
4. Validate a workflow of a solo director plus AI-written code. AI use is disclosed in the README and on the itch.io page.

### Background and Rationale

- **Team:** one developer (Tiziano: director, designer, playtester). AI writes 100% of the code. About 3.5 weeks of calendar time.
- **Engine:** Godot 4 with GDScript, the Compatibility renderer and a single-threaded web export. The web build is kept working from day 1.
- **Scope:** a boss rush in a single arena keeps scope small: one environment, three hand-authored encounters, no level-content pipeline.
- **Art:** the 1-bit / ASCII style makes characters, particles, environment and HUD the same asset type (glyphs).
- **Build order:** Infinite Loop end-to-end first, playtested before any other boss is built.

---

## Core Gameplay

### Game Pillars

1. **The shift is the fight.** No boss can be beaten with a single static loadout (brief). Damage spikes only once the boss is **Patched** by completing its phase's weak window (a combo, or a no-combo pair): Patched hits deal ×1.5. **Unpatched hits are halved (×0.5)**: the bug resists until it is reproduced and patched. Each phase changes the weak window, so every phase requires a shift. In every boss, at least one phase has a weak window that deals no damage, so cashing in Patched also requires a shift.
   - *Steers:* reject any mechanic that lets the player stop shifting, and any damage source that bypasses the ×0.5 outside Patched. Every boss phase's weak window is a different window from the previous phase's.
2. **Readable at a glance.** The player always knows what is active and what each shift will do.
   - The HUD shows the active window, its combo, and previews of the windows that `<<` and `>>` would produce.
   - Every boss attack has a visible and audible tell of ≥ 20 frames.
   - *Steers:* no off-screen attacks and no damage without a tell. The two-colour palette is kept even when it costs spectacle; red is the single exception and is reserved for warnings.
3. **Bugs behave like their bugs.** A boss's moveset is derived from its software failure, not from generic monster archetypes.
   - *Steers:* cut any attack that can't be explained as the bug's behaviour.
4. **Every shift feels great.** A shift is instant (0 frames of lockout) and always gets slide, click and flash feedback.
   - *Steers:* shift juice is a Must and comes before extra content.

### Core Gameplay Loop

1. **Read.** Watch the boss's tells. Optionally hold **Watch** to reveal the current weak window, the next attack and hidden entities.
2. **Shift.** Rotate the register until the weak window is active. Optionally trigger **Breakpoint** to shift with time frozen.
3. **Patch.** Complete the current phase's weak window (a combo, or a no-combo pair). The boss is **Patched** for 3 s.
4. **Strike / Evade.** Shift to your best damage window and punish, at ×1.5 crit damage while Patched (unpatched hits only chip at ×0.5). Evade with whatever evasive bit is active.
5. **Harvest.** The defeated bug drops a bit, which is inserted into the register.
6. **Next bug.** The new bit creates new windows and combos, and the next boss demands them.

**Cadence:**
- **Micro-loop** (Read → Shift → Patch → Strike): every 3–10 s within a fight.
- **Macro-loop** (Harvest → Next bug): three times per run.

### Win/Loss Conditions

- **Win (fight):** boss HP reaches 0.
- **Win (game):** defeat Segfault. The ending plays (see Level Types).
- **Loss (fight):** player HP reaches 0.
  - The screen shows `Process exited with code 1`.
  - Any new key press or click, made at least 20 frames after death (so a key held at the moment of death doesn't count), restarts the same fight within 2 s, with full player HP, full boss HP, and the register as it was at the start of that fight.
- **No game-over and no lives.** Progress (the highest boss reached) persists between browser sessions when storage is available.

---

## Game Mechanics

### Primary Mechanics

All timings assume a 60 FPS simulation. 1 tile = 16 px at the 640×360 base resolution. Frame data is written as startup / active / recovery (S/A/R); CD = cooldown.

#### Movement

| Parameter | Value |
|---|---|
| Walk speed | 7 tiles/s |
| Acceleration / deceleration | Full speed in 4 frames; stop in 3 frames |
| Facing / aim | 8 directions, set by the last movement direction. Attacks fire in the facing direction |
| Player hurtbox | Circle, 0.6 tiles in diameter (the sprite is 1 tile) |
| Player HP | 5, shown as `hp: 0b11111` |
| Damage taken | 1 HP per hit, from any attack or contact |
| Post-hit invulnerability | 60 frames (1.0 s), sprite blinking |

#### The Register

- **Layout.** The register is a **ring** of bits. The HUD shows a full byte: the low nibble is the playable register (4 slots), and the high nibble is greyed out and labelled `reserved`.
- **Owned bits only.** The ring length equals the number of owned bits (2 → 3 → 4). Unowned slots show a greyed `0` and are skipped by rotation. **No dead state** is possible: every rotation puts two owned bits in the active window.
- **Active window.** The 2 leftmost owned slots: slot 1 = **Action 1** (J), slot 2 = **Action 2** (K).
- **Shift `<<` (Q)** rotates the ring left by one slot; **shift `>>` (E)** rotates it right by one slot.
- **Shift timing.** A shift takes 0 frames and is allowed at any time, including during an action's recovery. It affects the next action input. Shift inputs are buffered for 8 frames during hit-stop.
- **Shift preview (Pillar 2).** The window and combo name that `<<` and `>>` would produce are shown, faded, to the left and right of the active window. A window with no combo shows its two bit glyphs only.
- **Bit insertion.** A harvested bit is appended to the right of the last owned slot.
  - The fight-start registers are **`[D, A]`** for Boss 1, `[A, D, L]` for Boss 2 and `[A, D, L, N]` for Boss 3.
  - Boss 1 starts at `[D, A]` so that the tutorial's required first shift produces `[A, D]` (Dash Strike).

#### Bits (solo actions)

| Bit | Glyph | Source | Solo action | S/A/R (frames) | Damage | Other |
|---|---|---|---|---|---|---|
| **ATTACK** | `A` | Duck, at start | **Slash:** 120° arc, 1.5-tile range. Pressing again in the last 8 frames of recovery chains up to 3 hits | 6 / 4 / 12 | 10 / 10 / 15 | — |
| **DASH** | `D` | Duck, at start | **Dash:** 4 tiles in the facing direction | 0 / 10 / 6 | — | Invulnerable on frames 1–8; CD 24 frames |
| **LOOP** | `L` | Infinite Loop drop | **Echo:** re-executes the last *solo bit action* performed (not a combo, not Echo itself, not an action cancelled during its startup) at your current position. Echo of a whiffed action still executes. If no action has been performed yet, it does nothing and goes on no cooldown | As the echoed action | 70% of the echoed action, rounded half up (10 → 7, 15 → 11) | CD 90 frames (1.5 s) |
| **NULL** | `N` | Null Pointer drop | **Null Dodge:** intangible for the active frames; move speed ×0.5 during it | 0 / 30 / 8 | — | CD 120 frames. **Clean Catch:** if an attack passes through you, your next damaging action deals ×1.5, on top of the boss's damage state (×2.25 Patched, ×0.75 unpatched) |

#### Combos

- **Trigger.** Press Action 2 during Action 1's active frames, or within **18 frames** after they end. Action 2 is **replaced** by the window's combo.
  - Combos are **ordered**: `[A, D]` (A→D) fires Dash Strike, while `[D, A]` (D→A) has no combo.
  - The replaced action's bit cooldown applies as normal.
- **Data-driven.** Each combo is defined by its ordered window, so post-jam windows can be added without changing the rules.
- **Resolution rules (D-045).**
  - Any shift closes the link: K after a shift performs the new window's solo action.
  - If a combo's second bit is on cooldown, the press stays buffered for 8 frames and is then dropped (no partial execution).
  - The ATTACK chain continues only with the button that started it and resets on any shift.
- **Count.** **4 combos**, as in the brief: one for each adjacent pair of the full ring A→D→L→N→A. The growing ring also exposes two windows with **no combo** — D→A (Boss 1) and L→A (Boss 2). In those windows J then K simply performs the two solo actions.

| Window | Combo | Exists in | Replaces | S/A/R | Invulnerability | Damage | Effect |
|---|---|---|---|---|---|---|---|
| A→D | **Dash Strike** | All fights | the dash | 0 / 12 / 8 | Frames 1–10 | 20 per target | Dash 5 tiles, damaging everything passed through |
| D→L | **Echo Dash** | Bosses 2–3 | the Echo | 0 / 10 / 6 | Continuous from the first dash through frame 10 (no gap) | — | Second dash of 4 tiles, redirectable |
| L→N | **Ghost Echo** | Boss 3 | the Null Dodge | 0 / 30 / 8 | Intangible for 30 frames | — | Leaves an intangible decoy at the start point for 120 frames. Bosses target the decoy |
| N→A | **Dereference** | Boss 3 | the slash | 2 / 8 / 14 | Stays intangible through its active frames | 30 (×1.5 with Clean Catch) | Piercing thrust of 3 tiles. **Must be pressed during Null Dodge's active frames** |

#### Weak Window and Patched

- Each boss phase has one **weak window**, an ordered pair.
- **No-combo weak windows.** A weak window can be a pair with no combo (D→A, L→A). It is completed by performing both solo actions in order: Action 2 input during Action 1's active frames or ≤ 18 frames after them (same as the combo trigger); if pressed during Action 1 it is buffered and executes when Action 1 ends. Action 2 must affect the boss. It applies Patched but uses the solo actions' normal damage and hit-stop (no combo effect).
- **Applying Patched.** Completing the phase's weak window (a combo, or a no-combo pair) so that it *affects the boss* applies **Patched** for **180 frames (3 s)**. "Affects the boss" means:
  - a damaging combo hits it;
  - a no-combo pair's Action 2 hits it;
  - Echo Dash passes through its hurtbox;
  - the boss strikes the Ghost Echo decoy.
- **Damage states.** Every player hit on a boss uses the boss's current state. Damage values in the Bits and Combos tables are base values.

| State | Multiplier | With Clean Catch (×1.5 on top) | Example: slash 10 / Dash Strike 20 | Feedback |
|---|---|---|---|---|
| **Unpatched** (default) | ×0.5 — the bug "resists" until it is reproduced and patched | ×0.75 | 5 / 10 | Resisted: `console.log("-5") // resisted` in 50% dither, smaller damage glyphs, half the particles, a dull thud SFX |
| **Patched** (180 frames) | ×1.5 (Crit) | ×2.25 | 15 / 30 | Crit: logged in CAPS (`CRITICAL: 15 dmg`), colour inversion, Patched chime on application |

- **Patched boss:** all player damage ×1.5 (Crit). The Patching hit itself counts as Patched.
- **Unpatched boss:** all player damage ×0.5. Chip damage is possible but slow: the same hit deals 3× more while Patched.
- **Rounding.** Multipliers (Echo 70%, damage state, Clean Catch) multiply together, and the result rounds half up once (22.5 → 23; unpatched slash 15 → 7.5 → 8; Patched Echo of 15 → 15.75 → 16).
- **Practice target:** it is not a boss and takes base damage (×1), so frame and combo data can be checked on it.
- **Duration and visibility.** Re-applying Patched refreshes its duration. A `// patched` tag and a countdown bar appear above the boss. The `// patched` tag and countdown bar stay visible while the boss is invisible (Null Pointer), so they double as a position hint.

#### Skills (not register bits)

| Skill | Input | Effect | Duration | CD | Unlocked |
|---|---|---|---|---|---|
| **Breakpoint** | Space | Freezes the simulation while shifting stays allowed. Screen dithered to 50% ink, a red breakpoint dot and line, muffled audio. The duck may say its hint template line (see Duck) | Up to 120 frames real-time (2.0 s); ends early on any action input | 12 s, counted in simulation frames from when Breakpoint ends | After Boss 1 (taught at the start of Boss 2; the first use is free) |
| **Watch** | Hold R | Reveals hidden entities (Null Pointer, decoys). Highlights the current weak window on the HUD. Shows the next attack's name above the boss and the boss's bits: the bit it will drop plus its weak window, as a bit label | While held | None | Start of Boss 2 |

- While Watch is held: move speed ×0.5 and no actions.

#### Hit Feedback ("juice")

**Hit-stop precedence:** Crit (8 frames) > the combo's own value > unpatched hit (3 frames).

| Event | Hit-stop | Feedback |
|---|---|---|
| Unpatched hit (resisted, ×0.5) | 3 frames | Half the usual glyph particles; smaller damage glyphs; `console.log("-5") // resisted` in 50% dither in the log panel; a dull thud SFX. Readable as "no real damage" (Pillar 2) |
| Combo hit | 6 frames (Dash Strike), 8 (Dereference) | As the hit for the boss's state (resisted or crit), plus a 2-px screen shake for 6 frames |
| Crit (Patched) | 8 frames | The log line is in CAPS; 1 frame of full-screen colour inversion |
| Shift | 0 | The HUD register slides over 6 frames with an overshoot bounce; a mechanical key-click SFX; the weapon inverts for 4 frames |
| Patched applied | 4 frames | `// patched` tag; a rising chime |
| Player hit | 4 frames | `WARN: hp--`; a 3-px screen shake; 60 frames of invulnerability blink |
| Boss at 66% / 33% HP | — | Glyph jitter amplitude rises in steps |
| Boss defeated | 20 frames | Glyphs reassemble into the boss's **fixed line** (see Boss Design); a duck squeak |

### Controls and Input

| Action | Keyboard (default) | Gamepad (Should) |
|---|---|---|
| Move | WASD (arrow keys as an alternative) | Left stick / D-pad |
| Action 1 (slot 1) | J | X / Square |
| Action 2 (slot 2) | K | A / Cross |
| Shift `<<` | Q | LB / L1 |
| Shift `>>` | E | RB / R1 |
| Breakpoint | Space | RT / R2 |
| Watch (hold) | R | Y / Triangle |
| Pause | Esc | Start |

- The Shift keys are **not** used, because of Windows Sticky Keys and browser shortcut conflicts.
- **Input buffer:** 8 frames for actions and shifts.
- **Remapping:** out of scope for v1.0. The pause screen shows the controls.
- **Press-to-start:** the title screen requires a key press or click before any audio plays (browser autoplay policy). Every input unlocks audio.
  - **Option hotkeys (D-048):** `[N]` new run (shown only when a save exists), `[P]` practice (Should), `[B]` debug build (Should), `[F]` fullscreen. An option hotkey, or a click on its label, acts on that option only.
  - **Any other key or click** starts the run, or continues it at the highest boss reached. That input starts the 30-s first-shift clock (Gameplay Metrics) and leads straight into the ≤ 8 s intro.
  - Gamepad: Start starts or continues; Select starts a new run.
- **Pause screen:** lists the controls, plus `[Esc]` resume, `[F]` fullscreen, `[B]` debug build (Should) and `[M]` mute (Should; mutes the Master bus and persists).

---

## Top-Down Action Boss Rush Specific Design

This section uses the `fighting` genre guide's structure for frame data, combos, defense, arena and practice mode, and the `action-platformer` guide's structure for abilities. It adds a **Boss Design** subsection. The platforming and PvP subsections of those guides do not apply.

### Movement and Combat Feel

- **Frame data:** see the Bits and Combos tables.
- **Cancels:** every player action can be cancelled into DASH or Null Dodge during its recovery.
- **Hitbox conventions:**
  - Player hurtboxes are smaller than the sprite.
  - Boss hitboxes match their glyph cells exactly.
  - Telegraphed areas of effect are drawn at their exact final size during the tell.
- **Contact damage:** touching a boss body deals 1 HP. Dash and dodge invulnerability let the player pass through bodies.

### Combo System

- **Structure:** two-step ordered links only. No juggles, wall bounces or combo scaling. The 3-hit ATTACK chain is the only same-bit chain.
- **Optimal pattern:** shift to the weak window → Patch → shift to the best damage window → punish before Patched expires → evade. Hitting an unpatched boss is ×0.5 chip damage, so the pattern pays 3× per hit. Combos cost no resource; cooldowns are the only gate.
- **Teaching:** the HUD shows the active combo's name and a `J→K` glyph. The duck names the first combo (Dash Strike) during Boss 1.

### Defensive Mechanics

| Option | Source | Invulnerability | Cost |
|---|---|---|---|
| DASH | Bit | Frames 1–8 | CD 24 frames; it must be in the active window |
| Dash Strike | Combo A→D | Frames 1–10 | DASH cooldown |
| Echo Dash | Combo D→L | Continuous over both dashes | LOOP cooldown |
| Null Dodge | Bit | 30 frames | CD 120 frames; slower movement |
| Ghost Echo | Combo L→N | 30 frames, plus a 120-frame decoy | NULL cooldown |
| Walking | Always | — | — |

- There is no block and no parry. Because evasion depends on the active window, a defensive shift is part of every Read → Shift decision.
- **Walking evasion:** walking (7 tiles/s) avoids every attack whose tell is ≥ 40 frames, with one exception: **Constrict** must be escaped with an invulnerable move.
- **Window `[L, A]`** (Boss 2) has no evasive bit, except Echo when the last solo action was DASH. That is a deliberate risk window.

### Arena Design

- **One arena: "The Clearing"** (labelled `stack frame 0x03`).
  - A fantasy hunting ground rendered in glyphs: trees `♣`, grass `"`, rocks `o`, a stream of `~`.
  - It is framed by the IDE HUD: the register panel on the left, the log panel at the bottom, and line numbers down the left edge.
  - The world is the fantasy RPG; the HUD is the debugger's view of it.
- **Size and boundaries:** 32 × 18 tiles of play area with solid walls (the tree line) and no wall interactions. Scenery is decorative only, with no collision inside the play area.
- **Per-boss dressing:** a code comment hangs in the sky and margin lines change; collision never changes.
  - Infinite Loop: `// TODO: this should terminate`
  - Null Pointer: `// FIXME: who owns this pointer?`
  - Segfault: `// HACK: do not read past this line`
- **Interactive element:** only Segfault's **corrupted tiles**.

### Player Abilities and Unlocks

| Point in the run | Register at fight start | Windows | New skill |
|---|---|---|---|
| Boss 1 | `[D, A]` | A→D (Dash Strike); D→A (no combo) | — |
| Boss 2 | `[A, D, L]` | A→D (Dash Strike), D→L (Echo Dash); L→A (no combo) | Breakpoint, Watch |
| Boss 3 | `[A, D, L, N]` | A→D, D→L, L→N, N→A (all 4 combos) | — |
| Ending | The `reserved` nibble lights up `1111`: a full byte | — | — |

### Practice Target

- A `/* test */` training dummy with infinite HP and no attacks.
- It is used for development tuning (Epic 2) and offered to players from the title screen as a **Should**.
- It shows a per-hit damage log and a frame counter.

### Boss Design

**Shared rules:**
- Each boss has HP, phases at fixed HP thresholds, and an attack pool per phase.
- The next attack is picked at random from the pool, never the same attack 3 times in a row.
- There is a fixed **gap** of idle frames between attacks.
- Every attack has a tell, active frames and a recovery during which the boss is open to punishment.
- **Audible tells (D-049):** each boss has one tell cue that plays at the start of every tell; SIGSEGV uses its own alarm instead.
- **Targeting (D-049):** attacks aim at the arena's current target, which is the player or, while one is live, a Ghost Echo decoy.
- A phase change resets the boss's speed ramp, plays a 60-frame glitch-roar, and gives no damage window.

#### Boss 1 — Infinite Loop (tutorial)

- **Form:** a closed ring of 24 `{ }` segments, 1 tile each (radius ≈ 3.8 tiles). The head is biting its own tail.
  - The ring spins in place, so segments flow around the circle, and drifts toward the player at 2 tiles/s.
  - An iteration counter `i = 0` floats above it.
- **Bug behaviour:** it never stops, and it speeds up every iteration.
  - The junction where head meets tail is the **loop condition**, a `;` glyph that travels around the ring at spin speed.
  - Once per lap, as `i++` ticks, the `;` **opens for 90 frames**. The open `;` is the only damageable point. (Phase 3 uses a fixed alternating timer instead; see Nested Loop.)
- **Spin speed:** 8 tiles/s (one lap ≈ 3 s), +5% per lap, capped at 12 tiles/s.
- **HP:** 400. **Drop:** LOOP.
- **Fixed line on defeat:** `for (i = 0; i < n; i++) { }`
- **Damage arithmetic:** a Patched Dash Strike (30) plus a follow-up slash (15) gives ≈ 45 damage per successful opening, so ≈ 9 successful openings are needed. One opening every ≈ 3 s, with ~50% success, gives ≈ 60–120 s. In phase 2 the Patching D→A deals only the slash (15 crit), so the shift to A→D for the Patched Dash Strike is where the damage is; the phase-2 HP band (132 HP) may take 1–2 extra openings — re-tune at the Nov 14 playtest. Skipping the Patch costs dearly: an unpatched Dash Strike into the `;` deals 10 (×0.5), so a phase-2 opening without the D→A shift is worth 10 instead of 45.

| Phase | HP | Weak window | Gap |
|---|---|---|---|
| 1 | 100–66% | A→D (Dash Strike through the open `;`). The start register `[D, A]` forces the first shift | 120 frames |
| 2 | 66–33% | **D→A** (no combo): dash, then slash into the open `;`. Patching costs a shift back to `[D, A]`, and cashing in with Dash Strike costs another | 90 frames |
| 3 | 33–0% | Outer ring's `;`: **A→D** (Dash Strike). Inner ring's `;`: **D→A** (dash → slash). Switching rings means switching windows | 60 frames |

| Attack | Phases | Tell | Active | Recovery | Notes |
|---|---|---|---|---|---|
| **Head Rush** | 1–3 | 30 frames (`!` over the head) | 40 frames (the head uncoils and charges 10 tiles) | 45 frames (the `;` stays open) | — |
| **Constrict** | 2–3 | 40 frames (the final ring outline is drawn) | 60 frames (it re-centres on the player and shrinks to a 2-tile radius) | 120 frames (`;` open) | Escape with an invulnerable move through the body |
| **Nested Loop** | 3 (once, at phase start) | 40 frames (the body flashes) | Rest of the phase: it splits into an outer ring (16 segments, radius ≈ 2.5 tiles) and an inner ring (8 segments, radius ≈ 1.3 tiles), 1 tile per segment. The inner ring spins at 1.5× the outer ring's speed, capped at the global 12 tiles/s (so it sits at the cap for the whole phase) | — | Each ring has its own `;`. Because lap times at these speeds are shorter than the 90-frame opening, phase 3 uses a fixed timer: one opening every 3 s, **alternating rings** (outer, inner, outer…), each lasting 90 frames. At most one `;` is open at a time, and the next one is always known; `i++` ticks on each opening |
| **`;` Spit** | 3 | 20 frames (the `;` glows) | A projectile at 6 tiles/s, once every 6 s | — | — |

- **Tutorial beats (duck; lines T1–T4 in the Duck line budget):**
  1. "Q and E shift your bits. Only the two on the left are live; the rest are in code review." Appears as soon as control starts; the ring stays still until the first shift.
  2. "See the semicolon? It's always the semicolon. Hit it when it opens."
  3. "J then K: Dash Strike. Two bits, one commit."
  4. At phase 2: "It refactored itself. Have you tried shifting it off and on again?"


#### Boss 2 — Null Pointer

- **Form:** a ghost made of `null` glyphs. It is **invisible** except:
  - during an attack's active and recovery frames;
  - while Watch is held;
  - during a 10-frame flicker when it is hit;
  - for 60 frames after Echo Dash passes through it.
- **Bug behaviour:** it points at nothing.
  - **Locating it:** a column of 3–5 falling `null` glyphs drifts under it, and a looping hum is panned by its position.
  - **Whiff penalty (`NullPointerException`):** an ATTACK slash that hits nothing while the boss is within 4 tiles stuns the player for 20 frames.
- **Idle movement:** invisible drift at 4 tiles/s.
- **HP:** 700. **Drop:** NULL.
- **Fixed line on defeat:** `if (ptr != null) ptr.deref();`
- **Damage arithmetic:** a Patched cycle is worth ≈ 45 (phase 1: Echo Dash Patches for 0, then `>>` to A→D for a Patched Dash Strike 30 plus a slash 15; phase 2: the Patching Dash Strike 30 plus a slash 15), so ≈ 16 cycles. With one attack every ≈ 3 s and ~50% success, plus time spent locating the invisible boss, that gives ≈ 110–150 s. Unpatched chip (Dash Strike 10, slash 5) is not counted; it shortens the fight by ≤ 10%.

| Phase | HP | Weak window | Gap |
|---|---|---|---|
| 1 | 100–50% | D→L (Echo Dash through it, which reveals it for 60 frames → shift to A→D to punish) | 90 frames |
| 2 | 50–0% | A→D (Dash Strike through it; the only other combo in the 3-bit ring) | 60 frames |

| Attack | Phases | Tell | Active | Recovery |
|---|---|---|---|---|
| **Pointer Grab** | 1–2 | 40 frames (a `*` appears behind the player) | 10 frames (grab, 1 HP) | 60 frames (visible) |
| **Null Rain** | 1–2 | 45 frames (5 marked 2×2 areas) | 20 frames | 40 frames (visible) |
| **Dangling Pointers** | 2 | 30 frames (two `null` flickers) | Spawns 2 decoy ghosts, re-cast every 15 s | 30 frames |

- **Decoys:**
  - Only the real ghost hums and shows in Watch.
  - Hitting a decoy dispels it and never causes the whiff stun.
- **Breakpoint tutorial:** at fight start the duck says "Space: Breakpoint. Time stops, you shift. Finally, a debugger that works." The first use has no cooldown.
- **Watch tutorial:** at fight start, after the Breakpoint line, the duck says "Hold R. Pointers point *somewhere*."

#### Boss 3 — Segfault (final)

- **Form:** a glitch dragon made of `▓▒░#@!` glyphs, about 6 × 4 tiles. It stays in the top third of the arena and moves at 2 tiles/s.
- **Bug behaviour:** it reads and writes memory it shouldn't.
  - It corrupts arena tiles.
  - It **shifts the player's register**.
- **HP:** 1000. **Drop:** none; its defeat triggers the ending.
- **Fixed line on defeat:** `if (idx < len) buf[idx] = val;`
- **Damage arithmetic:** phase 1: Echo Dash Patches for 0, then `>>` to A→D for Dash Strike 30 plus a slash 15 ≈ 45. Phase 2: the Patching Dereference 45 (68 with Clean Catch), then `<<` to A→D for Dash Strike 30 ≈ 75. Phase 3: Ghost Echo Patches for 0, then `<<` to N→A for Dereference 45 (68 with Clean Catch) ≈ 45. Averaging ≈ 55 per Patched cycle gives ≈ 18 cycles. With one attack every ≈ 3.5 s and ~50% success, plus SIGSEGV recoveries and hazard time, that gives ≈ 140–190 s against the 150–210 s target. Unpatched chip (Dash Strike 10, Dereference 15) is not counted.

| Phase | HP | Weak window | Gap |
|---|---|---|---|
| 1 | 100–66% | D→L (Echo Dash through the claw during its recovery) | 90 frames |
| 2 | 66–33% | N→A (Dereference) | 75 frames |
| 3 | 33–0% | L→N (Ghost Echo; Patched when it strikes the decoy → `<<` to N→A (or two shifts to A→D) and punish) | 60 frames |

| Attack | Phases | Tell | Active | Recovery |
|---|---|---|---|---|
| **Access Violation** | 1–3 | 30 frames (the claw's arc is drawn) | 12 frames (6-tile sweep) | 50 frames |
| **Corrupt Memory** | 1–3 | 60 frames (8–12 tiles marked `░`) | 240 frames (`▓` hazard, 1 HP on entry) | 40 frames |
| **SIGSEGV** | 2–3 | 60 frames (the HUD flashes red with `SIGSEGV incoming` and a rising alarm) | 1 frame (the player's register is rotated by 2 slots) | 90 frames, guaranteed ("dumping core"); 150 frames if Breakpoint is cut |
| **Core Dump** | 3 | 60 frames (a checkerboard is marked; safe tiles visible) | 180 frames | 60 frames |
| **Reserved Write** *(cut-ladder #1)* | 3 | 45 frames (the `reserved` nibble flashes) | 600 frames: a garbage bit `?` is inserted into the ring. Its solo action and combos are NOP | 30 frames |

- **Fairness rules:**
  - SIGSEGV is always telegraphed for 60 frames and always followed by its recovery.
  - SIGSEGV never overlaps another attack's active frames.
  - With Breakpoint available, its 12 s cooldown guarantees a calm fix at least once per SIGSEGV cycle.

### Duck (hint system)

- **Format (D-046):** one-line text bubbles with a squeak SFX on open. The text is revealed with a typewriter effect, synced to a mumble-speech gibberish voice (the designer's own library). There is no recorded voice acting. If the voice is unavailable, the text shows silently.
- **Budget:** **10 hand-written lines in total** (within the brief's 5–10 and the designer's 8–10 target). The hint template counts as one line.
- **Hint template:** `"Quack. Weak window: {X→Y}."`, filled with the current phase's weak window (e.g. "Quack. Weak window: D→A."). It is used by both hint triggers:
  - Breakpoint activation (at most once per phase);
  - the 3rd death on the same boss.
  - In Boss 1 phase 3 it names the window of the ring whose `;` opens next (outer → A→D, inner → D→A).
- **Tone:** comedic and deadpan, rubber-duck-debugging humour. Tutorial lines are jokes that still instruct.

| # | Trigger | Line |
|---|---|---|
| 1 | Intro, panel 3 (hands over ATTACK and DASH) | "Quack. Explain the bug to me. Use these." |
| 2 | T1 — Boss 1 start | "Q and E shift your bits. Only the two on the left are live; the rest are in code review." |
| 3 | T2 — first `;` approach | "See the semicolon? It's always the semicolon. Hit it when it opens." |
| 4 | T3 — Dash Strike | "J then K: Dash Strike. Two bits, one commit." |
| 5 | T4 — Boss 1 phase 2 | "It refactored itself. Have you tried shifting it off and on again?" |
| 6 | Boss 2 start — Breakpoint tutorial | "Space: Breakpoint. Time stops, you shift. Finally, a debugger that works." |
| 7 | Boss 2 start — Watch tutorial | "Hold R. Pointers point *somewhere*." |
| 8 | Harvest (shared by both harvests) | "Bug squashed. It dropped a bit: new windows, new combos." |
| 9 | Ending | "Quack. Works on your machine now." |
| 10 | Hint template (Breakpoint, 3rd death) | "Quack. Weak window: {X→Y}." |

---

## Progression and Balance

### Player Progression

- **Horizontal only:** new bits (new windows and combos) and two skills. No stats, levels or upgrades. Damage values are fixed for the whole run.
- **"Numbers go up":** filling the register (`0b0011` → `0b0111` → `0b1111`) is the visible payoff of the hunt. The HUD shows the register's byte value (`0x03` → `0x07` → `0x0F`; `0xFF` at the ending).
- **Replay value:** mastery (fewer hits taken, faster clears) and bit-order experimentation, as in the brief; player-chosen bit order is post-jam. Confirmed by the designer (2026-11-06). A clear-time and hits-taken summary on the ending screen is a stretch goal.

### Difficulty Curve

| Fight | Boss HP | Damage per Patched cycle | Patched cycles to kill | Estimated TTK | Target clear time (first success) | Expected attempts (first-time player) |
|---|---|---|---|---|---|---|
| Infinite Loop | 400 | ≈ 45 | ≈ 9 | ≈ 60–120 s | 60–120 s | 1–2 |
| Null Pointer | 700 | ≈ 45 | ≈ 16 | ≈ 110–150 s | 120–150 s | 2–3 |
| Segfault | 1000 | ≈ 55 | ≈ 18 | ≈ 140–190 s | 150–210 s | 2–4 |

- **Damage states drive the curve:** unpatched hits deal ×0.5 and Patched hits ×1.5, so a player who never Patches deals a third of the damage per hit and cannot finish within the targets. The estimates count Patched damage only (see each boss's damage arithmetic).
- **Total target:** 10–15 minutes, deaths included.
- **Tuning levers, in order:** boss HP → tell length → recovery length → attack gap → player HP. The ×0.5 / ×1.5 damage-state multipliers are not tuning levers (they enforce Pillar 1).
- **Tuning status:** all HP, damage and timing values in this document are first-pass. They are re-tuned after the Nov 14 MVP playtest.
- **Assist option (Should): "Debug build"** toggle on the title and pause screens. It sets player HP to 8, halves Breakpoint's cooldown to 6 s and stretches tells ×1.5. It does **not** change the ×0.5 unpatched multiplier: the assist eases survival, not the shift. It is labelled neutrally and carries no penalty.

### Economy and Resources

- No currency.
- **Bounded resources:** player HP (5) and the cooldowns (DASH 0.4 s, LOOP 1.5 s, NULL 2.0 s, Breakpoint 12 s).
- Full HP is restored and all cooldowns are reset whenever a fight starts: after Harvest, on resume and on retry.

---

## Level Design Framework

### Level Types

| Screen | Content | Length |
|---|---|---|
| **Intro** | Three glyph panels: (1) the developer at a desk at 2 a.m., stuck on a bug; (2) they squeeze the rubber duck and it quacks; (3) the screen tears into glyphs and they land in The Clearing. The duck hands over ATTACK and DASH (duck line 1) | **≤ 8 s** (about 2.5 s per panel); skippable from its first frame with any key or click (the title-screen input that started it does not count as a skip) |
| **Fight** | The Clearing, per Boss Design | — |
| **Harvest** (between fights) | The bug's glyphs reassemble into its fixed line; the bit flies into the register; the HUD shows the new windows; the shared harvest duck line (line 8, the same after Boss 1 and Boss 2) | ≤ 8 s; skippable after 2 s |
| **Ending** | The reserved nibble lights up `1111`; the developer is back at the desk; the duck sits on the desk; the bug is fixed (the commit message reads `fix: wild shift`); duck line 9; credits | ≤ 30 s |

### Level Progression

- **Sequence:** Intro → Infinite Loop → Null Pointer → Segfault → Ending. There is no level select in v1.0.
- **Save points:** the start of each fight. The run resumes at the highest boss reached when storage is available.

---

## Art and Audio Direction

### Art Style

- **World:** a fantasy RPG seen through a debugger's eyes. The world is drawn as text glyphs (trees, grass, monsters made of characters) and is always framed by IDE chrome. The debugger sees the bits beneath everything.
- **Palette:** 1-bit, two colours: ink `#E8E8E8` on near-black `#101014`.
  - Colour inversion and 50% dither are the only additional states.
  - **One accent, red `#FF4040`,** is reserved for warnings: the Breakpoint line and dot, and SIGSEGV. Nothing else may use it.
- **Glyphs (D-047):** everything is a glyph from one 8×8 CP437-style monospace pixel font (CC0 or OFL): the player (`@` with a `>o` duck companion), the bosses, the particles, the environment and the HUD.
  - World glyphs are drawn at 2× on the 16-px tile grid.
  - HUD text is drawn at 1× on an 8-px grid (80 × 45 cells).
  - Both are integer scales, so everything stays pixel-perfect.
- **HUD:** an IDE debugger layout.
  - The register panel shows 8 bits, with the upper nibble labelled `reserved`, plus the shift previews and the register's byte value in hex (e.g. `0x03`).
  - Line numbers run down the left; a log panel at the bottom (crits in CAPS; resisted unpatched hits in 50% dither with a `// resisted` suffix).
  - Each boss is named as a function signature, e.g. `void infiniteLoop() // hp 400`.

#### HUD Layout (D-047)

The layout uses 8-px HUD cells: 80 columns × 45 rows at the 640×360 base. The arena is 512×288 px at cells (16, 2)–(79, 37).

```
cols 0..11 register/duck | 12 | 13..15 line no. | 16..79 arena (32×18 tiles)
row 0   │ void infiniteLoop() // hp 400   [████████████░░░░]     (top bar)
row 1   │ // TODO: this should terminate                         (sky comment)
row 2   reg  0x03     01 ┌──────────────────────────────────────┐
row 4   0000 00DA     02 │                                      │
row 5   rsvd          03 │                                      │
row 7   << A D        04 │          The Clearing                │
row 8    Dash Strike  05 │          (world glyphs at 2×)        │
row 10  [D A]         06 │                                      │
row 11   (no combo)   07 │                                      │
row 12   J→K          08 │                                      │
row 14  >> A D        09 │                                      │
row 15   Dash Strike  10 │                                      │
row 17  cd D ■■□□     11 │                                      │
row 18  cd L ■■■■     12 │                                      │
row 19  brk  ■□□□     13 │                                      │
row 22  >o            14 │                                      │
row 23  "Q and E      15 │                                      │
row 24  shift your    16 │                                      │
row ..  bits..."      17 │                                      │
row 37                18 └──────────────────────────────────────┘
row 38  ── console ────────────────────────────────────────────────
row 39..44  console.log("-5") // resisted   ·   CRITICAL: 15 dmg   (6 lines)
```

- **Register panel** (cols 0–11): the hex value; the 8 bits as `reserved` nibble + playable nibble (unowned slots shown as a greyed `0`); the `<<` preview **above** the active window and the `>>` preview **below** it, faded, each showing its combo name or "(no combo)"; the active window, inverted, with its combo name and `J→K`; then the cooldowns. Combo names are ≤ 11 characters.
- **Line numbers** (cols 13–15): one per tile row (`01`–`18`).
- **Duck bubble** (cols 0–11, rows 22–37): the `>o` duck with its line word-wrapped at 12 columns.
- **Top bar:** the boss signature and HP bar (row 0) and the sky comment (row 1).
- **Log panel** (rows 38–44): 6 lines, 80 columns.
- The `// patched` tag, its countdown bar and the Watch labels are drawn in the world, above the boss.
- **Damage states:** bosses glitch harder at 66% and 33% HP. On death their glyphs reassemble into their fixed line.

### Audio and Music

- **SFX** (from sfxr/jsfxr): about 20 sounds. The **Must** sounds are the shift click (distinct for `<<` and `>>`), the hit and its dull resisted (unpatched) thud, the Patched chime, the duck squeak and the SIGSEGV alarm. Each boss also has its own glyph-glitch sound.
- **Music** (chiptune, made in BeepBox; all tracks loop):
  - **4 tracks:** title and intro, Boss 1, Boss 2, Boss 3.
  - **3 pre-rendered glitch variants** (bit-crushed or pitch-shifted), one per boss. Each boss crossfades to its variant at phase 3.
  - **1 pre-rendered muffled (low-pass) loop** for Breakpoint, shared by all fights.
  - No live audio effects: the web audio mode used (see Technical Specifications) does not support them.
- **Licences:** CC0 preferred; CC-BY accepted with credits; no NC or ND. Credits go in the README and on the itch.io page.

---

## Technical Specifications

### Performance Requirements

- **Frame rate:** 60 FPS sustained in Chrome and Firefox (latest) on a 2020-era mid-range laptop with integrated graphics, at 1280×720 in the browser. It is measured over the Segfault phase 3 fight, the peak particle and corrupted-tile load. A 2020-era mid-range laptop is the representative jam-player machine (confirmed by the designer, 2026-11-06).
- **Particles:** ≤ 300 glyph particles live at any time.
- **Load:** the title screen is interactive in ≤ 10 s on a 50 Mbps connection with a cold cache.
- **Input latency:** no added frames beyond the browser and engine baseline. Shift feedback appears on the input frame.

### Platform-Specific Details

- **Engine and build:**
  - Godot 4 with GDScript.
  - Compatibility renderer (WebGL2).
  - Single-threaded web export, so no SharedArrayBuffer or COOP/COEP headers are needed.
  - Web audio in **Sample** playback mode, for low latency. It does not support live audio effects, hence the pre-rendered variants.
- **Hosting:** an itch.io HTML5 embed. The source lives in a public GitHub repo, as the jam rules require.
- **Resolution:** a 640×360 base, integer-scaled (pixel-perfect) to the window. Fullscreen (the `[F]` hotkey or a click on its label) is triggered from an input event. The itch.io embed is 1280×720, so the default view is a 2× integer scale and the 1× HUD text is drawn at 16 screen px.
- **Browsers:** Chrome and Firefox are fully supported. Safari must be playable; its WebGL2 quirks are accepted if they are cosmetic. Mobile is not supported.
- **Storage:**
  - Progress saves via browser storage. If storage fails (for example, inside an iframe), the game falls back to no persistence silently.
  - Tab or focus loss triggers auto-pause.
- **Deployment:** every epic ends with an upload to an itch.io draft page.

### Asset Requirements

| Asset | Count / budget |
|---|---|
| Fonts | 1 monospace pixel font (CC0 or OFL) |
| Boss glyph layouts | 3 bosses, plus 2 decoys, the garbage bit and the dummy |
| Environment | 1 Clearing layout and 3 comment dressings |
| Intro / ending panels | 3 + 1 |
| SFX | About 20 |
| Music | 4 loops, 3 glitch variants and 1 Breakpoint loop |
| Text | 10 duck lines (the hint template counts as one), 3 fixed lines and 3 comments |
| Build size | Web build ≤ 30 MB uncompressed. Use a stripped export template if the default exceeds it |

---

## Development Epics

### Epic Structure

| # | Epic | Delivers | Window |
|---|---|---|---|
| 1 | Web Foundation | Web export on an itch.io draft page; title screen with press-to-start; arena and HUD shell; scene-flow placeholders; pause | Nov 6–7 |
| 2 | Player Core & Register | Movement; the register ring, Q/E shift with full juice and previews; ATTACK and DASH; the combo engine with Dash Strike; player HP, death and retry; the practice target | Nov 8–10 |
| 3 | Infinite Loop (MVP) | Boss framework (phases, weak window, Patched, crits); Boss 1; duck tutorial; harvest screen; LOOP drop. **MVP playtest gate: Nov 14** | Nov 11–14 |
| 4 | LOOP Combos & Breakpoint | Echo; Echo Dash; Breakpoint | Nov 15–17 |
| 5 | Null Pointer & Watch | Boss 2; Watch; the NULL bit and Clean Catch | Nov 18–21 |
| 6 | Segfault, Intro & Ending | Ghost Echo, Dereference, Boss 3, the intro and ending screens, all game text | Nov 22–25 |
| 7 | Audio, Polish & Submission | Music and SFX; the assist toggle; save/resume; gamepad (Should); practice target on the title screen (Should); browser tests; itch.io page; submission by Nov 29 12:00 PST | Nov 26–29 |

- **Sequencing:** epics are strictly sequential, with non-overlapping windows, and each one ends with a web deploy.
- **Overruns:** if an epic overruns by > 1 day, apply the cut ladder (Out of Scope).
- **Boss 1 fallback:** if Epic 3 is late, ship Boss 1 with phases 1–2 only.
- **Stories:** detailed stories are in `epics.md`.

---

## Success Metrics

### Technical Metrics

- 60 FPS sustained in Chrome and Firefox (see Performance Requirements); no crashes in Safari over a full run.
- The title screen is interactive in ≤ 10 s on 50 Mbps; the web build is ≤ 30 MB.
- Zero blocking bugs across 3 consecutive full runs before submission.
- Submitted by 2026-11-29 12:00 PST, ≥ 49 h before the deadline.

### Gameplay Metrics

Measured on 3–5 playtesters plus Tiziano:

- **First shift:** within **30 s** of the first click (or key) on the title screen, by observation. The clock includes the ≤ 8 s intro, whether watched or skipped.
- **First Patch:** ≥ 80% Patch Infinite Loop with Dash Strike at least once without any prompt beyond the duck's lines.
- **Boss 1 clear:** ≥ 80% of first-time players clear it within 3 attempts.
- **Full run:** 10–15 min for first-time players.
- **Shift feel:** rated ≥ 4/5 on average.
- **Theme proxy:** ≥ 50% mention the shift or the register unprompted in post-play comments.
- **Jam outcome (aspirational):** top 25% in Theme and Innovation.

---

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Theme-reading competition:** bit-shift puzzlers are the obvious reading of SHIFT | Lower Innovation and Theme scores | The itch.io page leads with the action-combat use of the shift: the cover GIF is a shift into a Dash Strike crit, and the first line of the page says "shift your weapon's bits mid-fight" |
| **Name collision** with "The Debugger" (antonion-games) on itch.io | Discoverability and confusion | The title is kept by decision. The suffix "0x03: Wild Shift" disambiguates, and the itch.io page uses the full title |
| **Segfault feels unfair** (register corruption) | Frustration at the final boss | The fairness rules; a 150-frame recovery if Breakpoint is cut |
| **Web-build pitfalls** (load size, Safari WebGL2, storage in iframes, background tabs) | A broken first impression | Deploy from day 1; a browser matrix test in Epic 7; silent storage fallback; auto-pause |
| **Schedule slip** (solo, 3.5 weeks) | An incomplete game | MVP gate on Nov 14; the cut ladder; the Boss 1 fallback; submission ≥ 49 h early |
| **Feel cannot be generated, only tuned** (AI-written code reaches functional, not juicy) | Low Gameplay score; Pillar 4 missed | Nov 14 MVP playtest gate; tuning story 3.7; feel targets in References |

---

## Out of Scope

**Cut ladder for v1.0, applied in order if the schedule slips:**

1. Segfault's **Reserved Write** (the garbage bit; touching the `reserved` nibble).
2. **Watch.** Replaced by stronger tells: Null Pointer flickers for 20 frames every 2 s, and decoys never hum. The weak window is then no longer highlighted on the HUD: players read it from the boss's tells, the duck's Breakpoint hint (while Breakpoint survives cut #3) and the duck's 3rd-death hint.
3. **Breakpoint.** SIGSEGV's recovery rises to 150 frames.
4. The **Segfault** boss itself.
   - The ending plays right after Null Pointer is defeated, and NULL is never dropped.
   - The Null Dodge bit, Clean Catch, Ghost Echo and Dereference are cut.

**Deferred to post-jam:**
- Player-chosen bit insertion order (enabling non-adjacent windows such as A→L and D→N).
- The **Lunge** (D→A) and **Recursion** (L→A) combos, cut from v1.0 to keep the brief's 4 combos. Candidates post-jam.
- The Fix vs Exploit moral choice.
- The Circular Dependency boss and the wider bestiary: Memory Leak, Race Condition, Stack Overflow, Off-by-One, Heisenbug.
- The debug-probe grappling hook, and the Step Over dodge.
- Control remapping, and a level/boss select.
- Mobile and touch support.
- Desktop builds (optional; only if time remains after submission).
- Live audio effects, localisation (English only) and leaderboards.

**Rejected:**
- An 8-slot register with "noise" bits. The 4-slot nibble was kept for readability.
- Using the Shift keys for shifting.

---

## Assumptions and Dependencies

### Dependencies

- Godot 4's web export works on itch.io with the single-threaded template.
- BeepBox, jsfxr and a CC0 or OFL pixel font are available.
- itch.io and GitHub are available at submission time.
- 3–5 playtesters are available by Nov 14 (MVP gate) and Nov 27 (full run).

### Assumptions Index

Both assumptions were confirmed by the designer on 2026-11-06 (D-030):

- **Confirmed:** replay value comes from mastery and bit-order experimentation (from the brief); bit-order choice is post-jam — Progression and Balance → Player Progression.
- **Confirmed:** a 2020-era mid-range laptop is a representative jam-player machine — Technical Specifications → Performance Requirements.

### Notes for Designer

- None open. (Boss 1 shift-forcing resolved by D-033.)
