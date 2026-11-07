---
baseline_commit: d8b748f3f763370540dd1267ee20636ae89a2a26
---

# Story 2.3: Register Ring, Shift and HUD Panel

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. -->

## Story

As a player,
I want to rotate my bit register with Q and E and always see what each shift will give me,
so that I can read and rewire my weapon at a glance (Pillar 2).

**Requirements:** FR4, FR5, FR6, FR7, FR8 (fight-start registers; harvest insertion is Epic 3), FR9; GDD "The Register"; GFR5, GFR6, GFR7, GFR8, GFR9, GFR10; NFR8 (ink/bg palette only, 16-px grid, dither as the only extra state).
**Epic 2 window:** Nov 8-10. **Depends on:** Story 2.1 (SimClock, InputBuffer, LiveInput shift actions, recorder), Story 2.2 (Arena and Main FIGHT wiring, Player), Story 1.5 (HUD frame with the `reg` box), Story 1.6 (FIGHT flow).

## Acceptance Criteria

1. **Ring and shift.** Given a `Register` owning `[D, A]` in ring order, when I press Q (`<<`, direction -1) or E (`>>`, direction +1), then the ring of owned bits rotates one slot in that direction in 0 frames, the active window is the two leftmost owned slots, and `EventBus.register_shifted(direction, window, register, &"player")` is emitted once per applied shift.
2. **Owned bits only.** Given 2, 3 or 4 owned bits, rotation in both directions only moves owned bits; the active window always holds two owned bits; no state exists where an unowned slot is in the window.
3. **Shift input timing.** Q maps to `shift_left` and E to `shift_right`, both through the 8-frame `InputBuffer`. A buffered shift is applied in the same physics frame as the press (0 frames), oldest first across both shift actions.
4. **Hit-stop buffering.** A shift pressed during hit-stop stays buffered. If hit-stop ends within 8 frames it is applied on the first unfrozen tick; if hit-stop lasts longer, the press expires and is never applied. Pause keeps Story 2.1 behaviour (nothing is polled).
5. **Insert and fight start.** `insert(bit)` appends the bit to the right of the last owned slot. `set_fight_start(bits)` accepts `[D, A]`, `[A, D, L]` and `[A, D, L, N]`. Any other set (size outside 2..4, duplicate bit, unknown bit id) is rejected with `Log.error` and leaves the register unchanged.
6. **Byte value.** `byte_value()` returns `0x03`, `0x07`, `0x0F` for 2, 3, 4 owned bits.
7. **Previews.** `preview(direction)` returns the window that a shift in that direction would produce, without changing the register. The HUD shows the `<<` and `>>` previews faded, with bit glyphs only (combo names are Story 2.6).
8. **HUD register panel.** When the register changes, the panel shows the hex byte value; 8 bit cells (high nibble greyed and labelled `reserved`; low nibble with owned bit glyphs in window-first order, unowned slots as a greyed `0`); the active window inverted with `J→K`; the faded `<<` preview above it and the faded `>>` preview below it. The panel only reads `Register` getters and never writes the register. Cell layout per D-S23-8.
9. **FIGHT wiring.** Every route into FIGHT (intro, harvest, debug jump) resets the register to the fight-start set for the current boss index, and the panel reflects it. Boss 1 starts at `[D, A]`.
10. **Guards and tests.** The full GUT suite passes, `bash game/tools/check_guards.sh` passes, the palette and font guard tests still pass (the new panel file is added to the palette guard's source list), and the HUD draw-order assertion in `test_hud_layout.gd` still holds (the register panel draws before `GridOverlay`).

## Scope Boundaries

- **In:** `Register` (ring model, shift, insert, fight-start, byte value, previews) as a `SimSystem` in the SHIFTS phase; the shift time base fix for hit-stop buffering (A2); `InputBuffer.consume_oldest`; `register_shifted` declared on `EventBus`; the HUD register panel (plan + draw); FIGHT wiring in `Arena` and `Main`; tests.
- **Out (later stories):** combo names, the combo window highlight and `ComboTable` (2.6); J/K resolution and actions (2.5); the shift juice (6-frame HUD slide, key clicks, 4-frame weapon inversion) (2.4); Breakpoint live shifting (4.3; the register stays outside the gate, so 4.3 only has to lift the Breakpoint freeze for it); harvest insertion (3.8); register snapshot restore on retry (2.9; this story only resets to fight-start on every FIGHT entry); cooldown rows in the panel (2.5 and later); `0xFF` at the ending (6.8); `BitDef` and `ComboDef` data resources (introduced when solo actions need data, 2.5 and 2.6); `register_changed` signal (Epic 3, insertion and expiry).

## Tasks / Subtasks

### Group A: Input and buffer plumbing (AC: 3, 4)

- [x] A1. `game/src/input/input_buffer.gd`: add `func consume_oldest(actions: Array[StringName], frame: int) -> StringName`. Returns the oldest live, unconsumed press whose action is in `actions`, consumes it, or `&""` when none. Keep `consume()` unchanged. (AC: 3, 4)
- [x] A2. `game/src/autoloads/sim_clock.gd`: add `var poll_frame: int = 0`, incremented once per non-paused `tick()` before the gates (so hit-stop and Breakpoint frames age buffered presses). Presses are pushed and pruned with `poll_frame`, not `sim_frame`. Set `ctx.poll_frame` next to `ctx.move_dir`. `sim_frame` keeps its meaning (world ticks only). (AC: 4; D-S23-2)
- [x] A3. Check that `test_sim_clock.gd`, `test_input_buffer.gd` and `test_replays.gd` still pass with the new time base (replays are poll-indexed, so the recorded format is unchanged). (AC: 10)

### Group B: Register model (AC: 1, 2, 3, 5, 6, 7)

- [x] B1. Add `game/src/register/register.gd` (`class_name Register`, `extends SimSystem`, `phase = SimPhase.SHIFTS`). Constructor takes the `InputBuffer` (`Register.new(buffer)`). `enum Bit { ATTACK = 1, DASH = 2, LOOP = 3, NULL_BIT = 4 }`. Glyph map: `ATTACK` `A`, `DASH` `D`, `LOOP` `L`, `NULL_BIT` `N`. State: `ring: PackedInt32Array` (owned bits in ring order, length 2..4), `active: bool = false`. (AC: 1, 2; D-S23-1, D-S23-5)
- [x] B2. `shift(direction: int) -> void` (-1 `<<`, +1 `>>`): rotate `ring` by one slot using index operations (for example `append(ring[0])` then `remove_at(0)` for left). Then emit `EventBus.register_shifted(direction, active_window(), ring.duplicate(), &"player")`. A ring shorter than 2 is a no-op with `Log.error`. (AC: 1, 2)
- [x] B3. `tick(ctx: SimContext)`: return when not `active`. Otherwise loop `buffer.consume_oldest([&"shift_left", &"shift_right"], ctx.poll_frame)` and apply each result (`shift_left` → -1, `shift_right` → +1) until it returns `&""`. (AC: 3, 4)
- [x] B4. `set_active(on: bool)`, `active_window() -> Vector2i` (`Vector2i(ring[0], ring[1])`), `preview(direction: int) -> Vector2i` (the window of a rotated copy; never mutates `ring`), `owned_count() -> int`, `byte_value() -> int` (`(1 << owned_count()) - 1`), `static glyph_of(bit: int) -> String`. (AC: 6, 7)
- [x] B5. `set_fight_start(bits: PackedInt32Array) -> bool`: validates size 2..4, unique ids, and ids in `Bit`; on success replaces `ring` with a copy and returns true; on failure logs `Log.error(&"register", ...)`, leaves `ring` unchanged and returns false. (AC: 5)
- [x] B6. `insert(bit: int) -> bool`: appends to the right of the last owned slot. Rejects an unknown id, a duplicate, or a full register (size 4) with `Log.error`. (AC: 5)
- [x] B7. `static fight_start_for_boss(boss_index: int) -> PackedInt32Array`: `0` → `[D, A]`, `1` → `[A, D, L]`, `2` → `[A, D, L, N]`, any other index → `[D, A]` with `Log.warn`. Constants only, no data file. (AC: 5, 9; D-S23-6)

### Group C: HUD register panel (AC: 7, 8, 10)

- [x] C1. Add `game/src/ui/hud/register_panel.gd` (`class_name RegisterPanel`, `extends Node2D`). Holds `register: Register` (injected, null-safe). A pure static `plan(ring: PackedInt32Array, owned_cap: int) -> Array[RegisterPanelCell]` (or an equivalent typed structure) returns every cell to draw: position (cell), text, and style (`ink`, `greyed`, `faded`, `inverted`). The plan is the only place that decides content. (AC: 8; D-S23-8)
- [x] C2. `_draw()` only executes the plan. Text via `GlyphFont.draw_cell` with `Palette.INK` or `Palette.BG` only. `greyed` and `faded` cells use the 50% checker dither (D-S23-7). `inverted` draws an INK-filled cell with BG glyphs. No new colours, and no `Palette.WARN`. (AC: 8, 10)
- [x] C3. Redraw: `_process` calls `queue_redraw()` while the panel is visible (same pattern as `PlayerView`). Presentation only; never writes `Register`. (AC: 8)
- [x] C4. `game/src/ui/hud/hud.tscn`: add a `RegisterPanel` node between `Frame` and `GridOverlay` (GridOverlay stays last). `Hud` exposes the panel (`@onready var register_panel`) so Main can inject the register. (AC: 10)

### Group D: FIGHT wiring (AC: 3, 9)

- [x] D1. `game/src/arena/arena.gd`: owns `var register: Register = Register.new(SimClock.buffer)` (field initializer, like `player`). `_enter_tree` registers both `player` and `register` with `SimClock`; `_exit_tree` unregisters both. `enter_fight(fight_start: PackedInt32Array)` resets the player (as now), calls `register.set_fight_start(fight_start)`, and sets `register.set_active(true)`. `leave_fight()` deactivates both. (AC: 9; D-S23-4, D-S23-11)
- [x] D2. `game/src/main/main.gd`: `_build_layers` passes `arena.register` to `hud.register_panel`. `apply_flow_state` calls `arena.enter_fight(Register.fight_start_for_boss(boss_index))` in FIGHT. Update the callers of `enter_fight` (grep `enter_fight` in `game/`). (AC: 9)
- [x] D3. Confirm the placeholder FIGHT text (`PlaceholderScreen`) still draws on top of the HUD panel area; no change expected. Record a one-line note in Completion Notes. (AC: —)

### Group E: Tests and guards (AC: 1-10)

- [x] E1. `game/tests/unit/test_register.gd` (no scene tree):
  - `[D, A]` `<<` gives `[A, D]`, window `(A, D)`; `>>` from `[D, A]` gives `[A, D]`; `[A, D, L]` `<<` gives `[D, L, A]` (window `(D, L)`) and `>>` gives `[L, A, D]` (window `(L, A)`); four-bit rings checked the same way; after a full cycle the ring is back to its start.
  - `shift()` emits `register_shifted` once with the right direction, window and ring (`watch_signals(EventBus)`).
  - `preview(-1)` and `preview(+1)` equal the window produced by actually shifting, and the ring is unchanged afterwards.
  - `insert` appends; full register and duplicate are rejected; `set_fight_start` accepts the three listed sets and rejects bad sets, leaving `ring` unchanged.
  - `byte_value()` is `0x03`, `0x07`, `0x0F` for 2, 3, 4 bits.
- [x] E2. `game/tests/unit/test_register_system.gd`: a `SimClock.new()` with a stub `InputSource` (presses per poll frame) and a `Register` on its buffer:
  - a `shift_left` press at poll f with no hit-stop applies on that tick (0 frames);
  - hit-stop of 3 frames, then the press applies on the first unfrozen tick;
  - hit-stop of 9 frames, then the press is gone and no shift happens;
  - `shift_left` then `shift_right` pressed in one window apply in press order;
  - an inactive register ignores buffered shifts;
  - paused `SimClock` polls nothing and applies nothing.
- [x] E3. `game/tests/unit/test_input_buffer.gd` (extend): `consume_oldest` returns the oldest live press across two actions, consumes it once, skips expired entries, returns `&""` when nothing matches.
- [x] E4. `game/tests/unit/test_register_panel.gd`: the pure `plan()` for 2, 3 and 4 owned bits: 8 bit cells on the 8-cell byte row; high nibble `greyed` and the label `reserved`; owned glyphs in window-first order; unowned slots `greyed` `0`; hex text `0x03` / `0x07` / `0x0F`; the window cells `inverted`; `<<` and `>>` preview cells `faded` on their rows; every cell inside the REGISTER box interior (cols 1-10, rows 3-20); and calling `plan()` leaves the register ring unchanged.
- [x] E5. `game/tests/unit/test_arena_player.gd` (extend): `enter_fight([D, A])` resets the register to `[D, A]` after shifts and re-entry; `leave_fight` deactivates the register; `fight_start_for_boss` returns the three sets and the Boss 1 default.
- [x] E6. `game/tests/unit/test_glyph_palette.gd`: add `res://src/ui/hud/register_panel.gd` to `SOURCES` and the draw-colour list if its draw calls match the regex. `test_hud_layout.gd`: the GridOverlay-last assertion must still hold.
- [x] E7. Run the full GUT suite headless and `bash game/tools/check_guards.sh` from the repo root. Both green. Record the test count in Completion Notes (baseline 262/262 across 32 scripts from 2.2).
- [x] E8. Run `godot --headless --path game --import` so the new `.gd` files get `.uid` files; leave them for the commit step (no commit unless asked).

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S23-1 Ring model.** The register stores only owned bits, in ring order, as a `PackedInt32Array` of length 2..4. Rotation is a rotation of that array, so unowned slots never exist in the model and rotation skips them by construction. The active window is `ring[0]` and `ring[1]`. `<<` moves the leftmost bit to the right end; `>>` moves the rightmost bit to the left end. Check against GDD: `[D, A]` `<<` gives `[A, D]`, which is Dash Strike, the tutorial's first shift.
- **[design call] D-S23-2 Shift time base.** `SimClock` advances `sim_frame` only on world ticks, so during hit-stop it is frozen. A press stamped with `sim_frame` would never expire during hit-stop, which breaks "if hit-stop lasts longer it expires". Fix: `SimClock.poll_frame` counts every non-paused physics frame (including hit-stop and Breakpoint) and buffers use it. `SimContext.poll_frame` carries it to systems. `sim_frame` keeps its meaning. Replays are unaffected because `ReplayInput` is indexed by poll count.
- **[design call] D-S23-3 Oldest-first across shift actions.** `InputBuffer.consume(action, frame)` searches one action at a time, so two shift actions cannot be ordered by it. `consume_oldest(actions, frame)` returns the oldest live entry across the given actions. The register applies shifts in press order.
- **[design call] D-S23-4 Register is a SimSystem.** `Register extends SimSystem` in phase SHIFTS, so the first system to tick in each frame applies shifts before `Player`. It receives the buffer by injection, so it has no dependency on `SimClock` internals. Registration and unregistration mirror `Player` (D-S22-10).
- **[design call] D-S23-5 Bit ids and glyphs.** Bit ids are small ints (`Register.Bit`) because they travel in the `register_shifted` signal and in recordings. Glyphs live in a static map in `register.gd`. There is no `BitDef` resource yet: the data files arrive with solo actions (2.5) and combos (2.6), as the architecture plans. Balance data (cooldowns, damage) stays out of this story.
- **[design call] D-S23-6 Fight-start sets.** `Register.fight_start_for_boss(index)` returns the GDD sets as constants (Boss 1 `[D, A]`, Boss 2 `[A, D, L]`, Boss 3 `[A, D, L, N]`). Only Boss 1 is reachable in Epic 2, but the table is tested now. Unknown indices fall back to Boss 1 with `Log.warn`.
- **[design call] D-S23-7 Greyed and faded without grey.** NFR8 allows only ink and background (`Palette.INK`, `Palette.BG`), and `test_glyph_palette.gd` enforces that. So "greyed" (unowned `0`, high nibble, `reserved` label) and "faded" (previews) are drawn as the glyph with a 50% checker of `Palette.BG` pixels over its cell, which is the dither state NFR8 allows. Inversion (INK fill, BG glyphs) marks the active window. Human check H1 confirms this reads correctly; if it does not, the fallback is to drop the checker and rely on position alone.
- **[design call] D-S23-8 Panel layout (cell rows, inner area cols 1-10, rows 3-20).** Inside the REGISTER box, which is cols 0-11 and rows 2-21:
  - row 3: hex byte value, `0x03`, INK;
  - row 8: the 8-bit byte, cols 1-8: high nibble cols 1-4 as greyed `0`s, low nibble cols 5-8 with owned glyphs in window-first order and greyed `0` for unowned slots;
  - row 9: the label `reserved` (cols 1-8), greyed;
  - row 11: the `<<` preview, faded, as `<< ` plus its two glyphs;
  - row 12: the active window, inverted, cols 1-10;
  - row 13: `J→K`, INK;
  - row 14: the `>>` preview, faded.
  - Rows 16-20 stay empty for the combo name (2.6) and cooldowns (2.5). The panel never draws on rows 0-2 or the box border.
  - Window-first order means the nibble is shown starting at the active window, followed by the remaining owned bits in ring order, then the unowned slots. This keeps the window at the left of the nibble after each rotation. Byte value and the window are unaffected by this display choice.
- **[design call] D-S23-9 Panel reads, never writes.** `RegisterPanel` holds a `Register` reference injected by Main, as `PlayerView` holds `Player`. It reads only `ring` through getters (`owned_count`, `active_window`, `preview`, `byte_value`) and redraws every frame while visible, which costs nothing because the HUD is hidden outside FIGHT. Shift juice (2.4) will add a slide on top of this.
- **[design call] D-S23-10 Panel placement.** `RegisterPanel` is a child of the `Hud` CanvasLayer, between `Frame` and `GridOverlay`. It draws over the frame's register box, so it does not touch the frame's `reg` title or borders.
- **[design call] D-S23-11 Shifts only in FIGHT.** `Register.active` follows the arena's FIGHT state, like `Player.active`. Shift presses on the title, intro or harvest are still buffered by `SimClock` (the buffer is shared), but the register ignores them, and `begin_fight` clears the buffer, so nothing carries over into the next fight.
- **[design call] D-S23-12 Buffer vs. Breakpoint.** Breakpoint is not in this story. The register is ticked in the SHIFTS phase, which runs only when the world ticks. Story 4.3 will need to let shifts run during the Breakpoint freeze (architecture NP-2). Nothing in this story blocks that.

### Architecture guardrails (must follow)

- Only `SimClock` calls `tick()`. No `_process`/`_physics_process` in gameplay code, no `Timer`, no `await`, no Tweens, no `Engine.time_scale`, no `delta`, no global `randi()`/`randf()` (AD-01, project-context).
- Integer frames only (`*_frames`, `poll_frame`, `sim_frame`). The register is integer state (no floats).
- Sim folders (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not reference `ui`, `presentation`, `AudioManager` or `VoiceService`. `EventBus` is allowed: sim emits, presentation listens (AD-05). `RegisterPanel` lives in `src/ui/hud/`, never in `register/`.
- Only `LiveInput` reads `Input` (guard in `check_guards.sh`). The register reads buffered presses from `InputBuffer` only.
- Single writer for the register: `Register` methods only (architecture "Register mutation"). Boss effects are out of scope here, but the methods must stay the only writers.
- Script cycles leak at exit (2.2 lesson): `Register` must not reference `Arena`, `Hud`, `Main` or `RegisterPanel`. Arena and Main hold it; the panel gets it injected.
- Typing: every variable, parameter and return is typed. `StringName` literals for ids (`&"shift_left"`).
- Logging: `Log.error/warn/info/debug(&"tag", msg)` only; tag `&"register"` for register events and `&"input"` for buffer changes. Never log per frame.
- Palette: `Palette.INK` and `Palette.BG` only in glyph drawing (`test_glyph_palette.gd`). HUD text at 1x on the 8-px cell grid (`GlyphFont.draw_cell`, scale 1).
- Signals: declare only in `src/autoloads/event_bus.gd`, past tense, typed args, no `Dictionary` payloads.

### Previous story intelligence (2.1 and 2.2)

- `SimClock` (2.1, 2.2): `tick()` order is pause gate (no poll) → poll presses into `buffer` → poll move into `ctx.move_dir` → recorder hook → Breakpoint gate → hit-stop → systems by phase → hit-stop apply → `sim_frame += 1`. `poll_frame` goes right after the paused gate (A2), so it counts hit-stop frames too.
- `LiveInput` (2.1) already buffers `shift_left` and `shift_right` (`BUFFERED_ACTIONS`). No input-side change is needed for Q and E.
- `InputBuffer` (2.1): 8-frame lifetime is inclusive (`frame - pushed <= 8`). Keep it. `consume_oldest` must use the same liveness rule.
- `InputRecorder` (2.2, format v2): shift presses are already in `frames`, so replays of shifts work without format changes.
- `Player` (2.2): `Arena` owns it, `Arena._enter_tree` registers it, `_exit_tree` unregisters, `Main` adds `PlayerView`, and `apply_flow_state` calls `enter_fight` / `leave_fight`. Follow exactly that pattern for `Register`.
- 2.2 review fixed a `PlayerView` one-frame stale draw on re-entry (`Arena._redraw_player_view`). Do the same for the register panel when `enter_fight` runs (the panel redraws every frame, so this is a note, not extra work).
- 2.2 design call D-S22-10: `SimClock.unregister_system` exists and is idempotent. Reuse it.
- Test baseline from 2.2: 262/262 GUT tests across 32 scripts; `check_guards.sh` OK.

### Git intelligence (recent commits)

- `d8b748f` Story 2.2: player movement, FIGHT wiring, `PlayerView`, held-direction input (format v2 recorder).
- `0b057fa` Story 2.1: sim clock, input source, buffer, recorder, F11, seed plumbing, guards.
- `f3da78d` docs: defer itch.io deploy and browser smoke.
- Pattern: each story adds small files, extends existing tests, keeps `check_guards.sh` green, records design calls and human checks in the story file.

### Latest technical information

- No new engine features. The story uses Godot 4.7.2 `PackedInt32Array` (`append`, `remove_at`, `insert`, `duplicate`), `Array[StringName]`, `Vector2i`, `EventBus` signals and `draw_rect`. If a method name is in doubt, check `/godotengine/godot-docs/__branch__4.7` (project-context) before writing it; `PackedInt32Array` has no `pop_front` / `push_front`, so use index operations.
- No web research needed for the design; the glyph font already covers `<<`, `>>`, `→`, `0`-`9`, `A`, `D`, `L`, `N`, `░` and `█` (`test_font_coverage.gd`).

### Project Context Rules

- Godot project root is `game/`. Files go under `game/src/register/`, `game/src/ui/hud/`, `game/tests/unit/`.
- `project-context.md` (`_bmad-output/project-context.md`): "Single writers: register → `Register` methods"; "Names: files `snake_case`, `class_name` PascalCase, frame fields `_frames`"; "No magic numbers: balance in `.tres`, invariants in `Const`" (the fight-start sets are rules from the GDD, recorded as constants with a test; they are not tuning values).
- Debug tools stay behind `Debug.enabled`. The register panel is always drawn in FIGHT (it is player-facing HUD).

### Project Structure Notes

- New: `game/src/register/register.gd` (+ `.uid`), `game/src/ui/hud/register_panel.gd` (+ `.uid`), `game/tests/unit/test_register.gd`, `game/tests/unit/test_register_system.gd`, `game/tests/unit/test_register_panel.gd` (each with `.uid` once imported). `game/src/register/` currently holds only `.gitkeep`.
- Modified: `game/src/input/input_buffer.gd`, `game/src/autoloads/sim_clock.gd`, `game/src/core/sim_context.gd` (`poll_frame`), `game/src/autoloads/event_bus.gd` (`register_shifted`), `game/src/arena/arena.gd`, `game/src/main/main.gd`, `game/src/ui/hud/hud.tscn`, `game/src/ui/hud/hud.gd` (panel reference), `game/tests/unit/test_input_buffer.gd`, `game/tests/unit/test_sim_clock.gd` (if assertions use `sim_frame` for buffer timing), `game/tests/unit/test_arena_player.gd`, `game/tests/unit/test_glyph_palette.gd`.
- Conflicts: none. `Hud.REGISTER` already names the panel cells (cols 0-11, rows 2-21), and `Hud.box_rows` already draws the box. `GlyphFont.draw_cell` and `Palette` cover all drawing.

### Testing Requirements

- GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- Static guards: `bash game/tools/check_guards.sh` from the repo root.
- Pure logic with no scene tree: `Register`, `InputBuffer`, `RegisterPanel.plan`. `SimClock.new()` with a stub `InputSource` for hit-stop and pause cases (as in 2.2 E3).
- Do not rely on real key events in GUT. Shift presses come from a stub `InputSource` or direct `InputBuffer.push`.
- Draw code (`RegisterPanel._draw`, the dither) is not unit-tested beyond the plan; it is covered by the human checks.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.3 H1] Debug build, F2 (FIGHT): Q and E rotate the register; the hex value, the 8-bit byte, the inverted window, the faded `<<` and `>>` previews and `J→K` are readable at 1x in Chrome and Firefox. Confirm the checker-dither greyed and faded cells read as "less" (D-S23-7, D-S23-8).
- [ ] [2.3 H2] Q/E feel instant on the frame the key goes down (0-frame shift, no visible lag). Shift juice is 2.4, so this check is about latency only.
- [ ] [2.3 H3] Debug jump out of FIGHT and back in (F2 twice, or the debug keys): the register is back to `[D, A]` and the panel shows `0x03`.

### Review Findings

Layers run as parallel subagents: Blind Hunter, Edge Case Hunter, Acceptance Auditor. 0 decision_needed, 6 patch (all fixed), 11 defer, ~14 dismissed as noise.

- [x] [Review][Patch] Shift loop ignored `active` changes made by `register_shifted` listeners [game/src/register/register.gd:42] (now `while active and ...`, test added)
- [x] [Review][Patch] `Arena.enter_fight` ignored `set_fight_start` rejection [game/src/arena/arena.gd:69] (falls back to Boss 1 set)
- [x] [Review][Patch] Stale Q/E presses could carry into a fight if `begin_fight` is bypassed [game/src/arena/arena.gd:70] (buffer cleared in `enter_fight`) [design call]
- [x] [Review][Patch] `RegisterPanel.plan` unvalidated `owned_cap` [game/src/ui/hud/register_panel.gd:80] (clamped)
- [x] [Review][Patch] AC4 wording vs age-based expiry untested for a late press [game/tests/unit/test_register_system.gd] (test added: press at poll 1 in a 9-frame hit-stop applies; expiry is by age)
- [x] [Review][Patch] No test for listener deactivating the register mid-loop [game/tests/unit/test_register_system.gd]
- [x] [Review][Defer] Hit-stop/Breakpoint longer than 8 frames drops all buffered input, not only shifts (D-S23-2 consequence) [game/src/autoloads/sim_clock.gd] — deferred, design call, judge by feel
- [x] [Review][Defer] RegisterPanel redraws and rebuilds the plan every frame while active; redraw on `register_shifted` instead [game/src/ui/hud/register_panel.gd] — deferred, perf only
- [x] [Review][Defer] Replay hash uses absolute `ctx.poll_frame`; `begin_fight` does not reset it [game/src/autoloads/sim_clock.gd] — deferred, same-session replays only
- [x] [Review][Defer] `_systems` mutated during tick iteration if a listener unregisters a system [game/src/autoloads/sim_clock.gd:59] — deferred, no such listener exists yet

Other deferred items are in deferred-work.md.

## Dev Agent Record

### Agent Model Used

Story created by Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended). Implemented by Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story (unattended).

### Debug Log References

- Fresh worktree: `godot --headless --path game --import` run first (no `.godot/` cache). Baseline before changes: 262/262 tests, 32 scripts.
- First run of `test_register.gd`: typed-array helper params (`Array[int]`) rejected untyped literals; helpers switched to untyped `Array`. `assert_push_error(int)` is deprecated in GUT 9.6, switched to `assert_push_error_count`.
- Headless boot smoke (`--quit-after 60`): no errors or warnings.

### Completion Notes List

- **D-S23-2 verified against the code before applying.** In 2.1's `SimClock.tick()` presses were pushed with `sim_frame`, which does not advance during hit-stop or Breakpoint. A press made during a 9-frame hit-stop was therefore still "age 0" when the world resumed and would have been applied, contradicting AC4. Fix applied: `SimClock.poll_frame` counts every non-paused polled frame; presses are pushed with it; `ctx.poll_frame` carries the value of the frame being ticked. Implementation detail: `ctx.poll_frame` is set to the current `poll_frame`, then `poll_frame` is incremented right after the poll/recorder and before the gates (same post-increment convention as `sim_frame`, so the first poll is frame 0 and no existing 0-based test changed meaning). `sim_frame` is unchanged. Replays are unaffected (recorder format unchanged; `ReplayInput` is poll-indexed).
- 2.1 tests updated for the new time base: `test_input_buffered_during_hitstop` now consumes at the poll frames (1, 2) and asserts that the `sim_frame` stamp no longer applies; `test_presses_buffered_at_current_sim_frame` renamed `..._poll_frame`; `test_replays.gd` `HashSystem` consumes with `ctx.poll_frame` (with `sim_frame` the replay still matched bit for bit, but presses after the first hit-stop would silently never be consumed). Three new `SimClock` tests cover `poll_frame` counting (hit-stop and Breakpoint count, pause does not), `ctx.poll_frame` values, and expiry in a 9-frame hit-stop.
- `InputBuffer.consume_oldest(actions, frame)` added (same liveness rule as `consume`); `consume` unchanged.
- `Register` (`src/register/register.gd`): ring model per D-S23-1, SHIFTS-phase `SimSystem`, buffer injected. Pure statics `rotated()` and `window_of()` are shared by `preview()` and the panel plan. `register_shifted(direction, window, ring, source)` declared on `EventBus` (the third arg is named `ring` rather than `register` to avoid shadowing the class name).
- [design call] `shift()` rejects a direction other than -1/+1 with `Log.error` (no signal). AC1 only defines -1 and +1.
- [design call] `insert()` checks "full register" before "duplicate". With only four bit ids a full register always owns every id, so the opposite order would make the full-register rejection unreachable; the result (rejected, unchanged) is the same either way.
- [design call] Errors use `Log.error` without `assert()` (project-context says assert + Log.error) because AC5 requires the rejection to be testable headless; an `assert(false)` would abort debug test runs.
- `RegisterPanel` (`src/ui/hud/register_panel.gd`): pure static `plan(ring, owned_cap = 4) -> Array[RegisterPanel.Cell]` (inner class `Cell`: cell, text, style). Layout per D-S23-8. [design call] Column alignment inside the box: previews are `<< J K` / `>> J K` with the J glyph at col 4 and K at col 6; the inverted window bar spans cols 1-10 with its glyphs at cols 4 and 6; `J→K` sits at cols 4-6, so J and K line up vertically across the three rows. [design call] The byte row shows owned glyphs in plain INK (the inversion marks only the row-12 window, as listed in D-S23-8).
- [design call] Dither (D-S23-7) is an 8x8 `ImageTexture` built once at runtime from `Palette.BG` pixels on `(x + y)` even and transparent elsewhere, drawn tiled over greyed/faded runs (`draw_texture_rect(..., tile = true)`): one draw call per run instead of 32 `draw_rect` per cell. No colour literals, so the palette guard holds. Greyed and faded currently look identical; the names are kept for 2.4/2.6.
- [design call] Panel redraw gate is `register != null and register.active` (mirrors `PlayerView`'s `player.active`), which is true exactly in FIGHT, when the HUD is visible.
- FIGHT wiring: `Arena` owns `register = Register.new(SimClock.buffer)`, registers/unregisters it with the player; `enter_fight(fight_start)` resets and activates it; `leave_fight()` deactivates it. `Main._build_layers` injects `arena.register` into `hud.register_panel`; `apply_flow_state` passes `Register.fight_start_for_boss(boss_index)`. The only other caller of `enter_fight` was `test_arena_player.gd`, updated.
- D3: the FIGHT placeholder text is centred (2x, about x 224-416 px, y 152-200) and the register panel occupies x 8-88 px, so they never overlap. The placeholder sits on canvas layer 0, below the HUD layer, but nothing of it is covered. No change made.
- Tests: new `test_register.gd` (18), `test_register_system.gd` (9), `test_register_panel.gd` (14, incl. a headless draw smoke test and a source check that the panel never calls register writers); extended `test_input_buffer.gd` (+5), `test_sim_clock.gd` (+3), `test_arena_player.gd` (+4), `test_hud_layout.gd` (panel between Frame and GridOverlay; GridOverlay still last), `test_glyph_palette.gd` (panel in `SOURCES` and in the draw-colour list).
- **Results: GUT 315/315 passing across 35 scripts (baseline 262/32), 5074 asserts. `bash game/tools/check_guards.sh`: OK.**
- E8: `.uid` files generated for the five new scripts; left uncommitted (no commit asked).
- Human checks H1-H3 (below in Dev Notes) are open for Tiziano; they do not block review.

### File List

- `game/src/input/input_buffer.gd` (modified)
- `game/src/autoloads/sim_clock.gd` (modified)
- `game/src/core/sim_context.gd` (modified)
- `game/src/autoloads/event_bus.gd` (modified)
- `game/src/register/register.gd` (new)
- `game/src/register/register.gd.uid` (new)
- `game/src/ui/hud/register_panel.gd` (new)
- `game/src/ui/hud/register_panel.gd.uid` (new)
- `game/src/ui/hud/hud.gd` (modified)
- `game/src/ui/hud/hud.tscn` (modified)
- `game/src/arena/arena.gd` (modified)
- `game/src/main/main.gd` (modified)
- `game/tests/unit/test_register.gd` (new)
- `game/tests/unit/test_register.gd.uid` (new)
- `game/tests/unit/test_register_system.gd` (new)
- `game/tests/unit/test_register_system.gd.uid` (new)
- `game/tests/unit/test_register_panel.gd` (new)
- `game/tests/unit/test_register_panel.gd.uid` (new)
- `game/tests/unit/test_input_buffer.gd` (modified)
- `game/tests/unit/test_sim_clock.gd` (modified)
- `game/tests/unit/test_arena_player.gd` (modified)
- `game/tests/unit/test_glyph_palette.gd` (modified)
- `game/tests/unit/test_hud_layout.gd` (modified)
- `game/tests/replays/test_replays.gd` (modified)
- `_bmad-output/implementation-artifacts/2-3-register-ring-shift-and-hud-panel.md` (story record)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S23-1 to D-S23-12 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): Register ring + SHIFTS system, poll_frame buffer time base (D-S23-2), InputBuffer.consume_oldest, register_shifted signal, HUD RegisterPanel, FIGHT wiring, tests (315/315). Status review.
- 2026-11-07: Code review (gds-code-review, 3 parallel layers): 6 patches applied, 11 deferred. Tests 317/317. Status done.
