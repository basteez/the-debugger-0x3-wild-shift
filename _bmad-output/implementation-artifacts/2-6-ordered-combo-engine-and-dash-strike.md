---
baseline_commit: ece5926
---

# Story 2.6: Ordered Combo Engine and Dash Strike

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. Large story, intentionally not split (sprint-status design call): work in the task groups below, in order. -->

## Story

As a player,
I want J then K on my active window to fire that window's combo,
so that the order of my bits matters and shifting unlocks new moves (Pillar 1).

**Requirements:** FR7 (combo names in the HUD previews), FR15 (combo trigger and link window), FR16 (Dash Strike), FR20 (no-combo windows perform both solo actions); GFR11, GFR12, GFR4; architecture AD-02 (`ComboDef`, `ComboTable`), NP-1 (`ActionResolver` rules 2, 4-6, 8; `LinkState`; data flow step 3); GDD "Combos", "Bits (solo actions)", "The Register" (resolution rules D-045).
**Epic 2 window:** Nov 8-10. **Depends on:** Story 2.1 (`SimClock`, `InputBuffer` with 8-frame lifetime, `poll_frame`), 2.2 (`Player`, facing, arena clamp), 2.3 (`Register`, `active_window()`, `shift_serial`-style shift signal, `RegisterPanel`), 2.4 (`PlayerView`, `JuiceDirector`), 2.5 (`ActionDef`, `BitDef`, `Defs`, `ActionResolver`, `ActionStateMachine`, `Cooldowns`, `FrameOverlay`, `HitCapsule`/`HitArc`).
**Unblocks:** Story 2.7 (hit resolution uses the combo's shape, damage and `link_second`), 2.8 (hit feedback for combo hits), 4.2 (Echo Dash uses the same combo table), 6.2 (Dereference adds `requires_first_active`).

## Acceptance Criteria

1. **Combo data and ordered lookup.** Given `ComboDef` and `ComboTable` (`data/combos/combo_table.tres`, read through `Defs.COMBOS`) with Dash Strike (A→D): S/A/R 0/12/8 frames, invulnerable on action frames 1-10, a 5-tile dash, 20 damage per target passed through. `get_combo(A, D)` returns Dash Strike; `get_combo(D, A)` returns null; lookup is by ordered pair and never sorted. `validate()` returns no messages for every shipped combo; `test_data_validation.gd` covers the new `.tres` files without edits.

2. **Combo trigger.** Given the active window `[A, D]` (J = A, K = D), when I press K during Slash's active frames or within 18 frames after them, then K is replaced by Dash Strike and DASH's cooldown applies (24 frames, the replaced solo action's cooldown). A K press made during J's startup is evaluated when J's active frames begin.

3. **No-combo window.** Given the active window `[D, A]` (no combo), when I press J then K within the link window, then I get the dash followed by a slash flagged `link_second = true`. If K is pressed while the dash cannot be cancelled, it stays held and executes when the dash ends (if the link is still open).

4. **Shift closes the link.** Given a link is open, when I shift before pressing K, then the link closes and K performs the new window's solo action (NP-1 #1). A K press held before the shift is discarded, not executed.

5. **Cooldown block.** Given a combo whose second bit is on cooldown, when I press K in the link window, then the press stays buffered for 8 frames and is then dropped, with no partial execution (NP-1 #2, D-045).

6. **Same-frame J and K.** Given J and K pressed on the same frame, when resolved, then J resolves first and K is evaluated on the next tick against the newly opened link (NP-1 #8).

7. **Link timing.** The link opens on the tick J's first ACTIVE frame executes and stays open through J's ACTIVE frames and for 18 ticks after J's last ACTIVE frame. A K press accepted at 18 ticks after the last ACTIVE frame and refused at 19 (tested for slash and dash).

8. **HUD.** When the active window has a combo, the register panel shows the combo name and the `J→K` glyph on the window. The `<<` and `>>` previews show the combo name where a combo exists and only the two bit glyphs where none exists (FR7). The F9 frame overlay shows the link state (open or closed, window pair, frames left, held K press or none).

9. **Tests.** `tests/unit/test_combo_table.gd` and `tests/unit/test_action_resolver.gd` (extended) and the FSM tests cover: `[A,D]` → Dash Strike, `[D,A]` → dash then slash, ordered lookup (never sorted), shift between J and K, cooldown block and 8-frame drop, link timing at 18 and 19 ticks, same-frame J+K. `bash game/tools/check_guards.sh` stays OK.

## Scope Boundaries

- **In:** `ComboDef`, `ComboTable`, `Dash Strike` data, the link state, the K-follow-up rules in `ActionResolver`, combo starts in `ActionStateMachine`, the HUD combo names and the F9 link lines, unit tests.
- **Out (later stories):** damage, hit detection and targets for any hit, including Dash Strike's damage over its path (2.7); hit-stop and hit visuals (2.8); Echo Dash, Ghost Echo, Dereference and their bits (4.2, 6.1, 6.2; only the `ComboTable` entries they need are added there); `requires_first_active` on `ComboDef` (6.2); the Duck naming Dash Strike (3.6); the `link_second` effect on weak windows (2.7 and boss epics).
- **Not changed:** the 8-frame `InputBuffer` lifetime and its API; `Register` ring rules and the shift signal; the 2.5 solo, chain and cancel rules except where stated below.

## Tasks / Subtasks

### Group A: Combo data (AC: 1, 9)

- [x] A1. `game/src/register/combo_def.gd`: `class_name ComboDef extends Def`. Fields: `first: int` and `second: int` (`Register.Bit`), `action: ActionDef`, `display_name: String`. `validate()`: both bits are `Register.is_bit`, `first != second`, `action != null` and `action.validate()` empty, `display_name` 1-11 characters (GDD combo-name limit).
- [x] A2. `game/src/register/combo_table.gd`: `class_name ComboTable extends Def`. `@export var combos: Array[ComboDef]`. `get_combo(first: int, second: int) -> ComboDef` (null = no combo). Index built once on first lookup, never mutated afterwards. `validate()`: each combo validates; no duplicate ordered pair.
- [x] A3. `game/data/actions/dash_strike.tres` (`ActionDef`, id `&"dash_strike"`): startup 0, active 12, recovery 8, `invuln_from = 1`, `invuln_to = 10`, `move_tiles = 5.0`, `base_damage = 20`, `hit_shape` = `HitCapsule` (length 5.0 tiles, radius 0.75, [design call] D-S26-2), `cooldown_frames = 0` (the second bit's cooldown applies, D-S26-3), `cancel_into` empty (D-S26-2).
- [x] A4. `game/data/combos/combo_table.tres` (`ComboTable`) and `game/data/combos/dash_strike.tres` (`ComboDef`: first ATTACK, second DASH, display name "Dash Strike", action = `dash_strike.tres`).
- [x] A5. `Defs` gains `const COMBOS: ComboTable = preload("res://data/combos/combo_table.tres")`. The FSM reads combos through `Defs.COMBOS` (a parameter is also acceptable if the tests need a stub).

### Group B: Link state (AC: 2, 4, 6, 7)

- [x] B1. `game/src/player/link_state.gd` (`class_name LinkState extends RefCounted`): `pair: Vector2i`, `serial: int` (shift serial at open), `frames_left: int`, `open_flag` (or a derived `is_open()`), and the held K press: `held: bool`, `held_key: StringName`, `held_slot: int`, `held_frame: int` (the frame it was pushed). Plain data; written only by the FSM. [design call] D-S26-4: owned by the FSM, not `Player` (arch NP-1 says `Player`); the FSM is the only writer of action state and the overlay reads it from there.
- [x] B2. Open: on the tick a slot-0 (J) action's first ACTIVE frame executes, `pair = window`, `serial = shift_serial`. Every ATTACK chain hit reopens it (D-S26-9). Count: the link stays open while J's ACTIVE frames run; the count of 18 starts on the tick the last ACTIVE frame executes (k = 0), and the link is open at k = 0..18 and closed from k = 19 (AC7). Decrement once per FSM tick, like `Cooldowns`, never by wall time.
- [x] B3. Close: on any applied shift (`shift_serial` differs from `serial`), on `set_active(false)`, on `reset_for_fight()`, and when the count runs out. A close discards a held press (D-S26-7).
- [x] B4. Ownership of a held press: when the link is open, the window equals `pair`, a K press is live in the buffer, and the press cannot start yet (see C2), the FSM consumes it from `InputBuffer` (`consume`) and stores it in `held_*`. The held press keeps its original `held_frame`. It is no longer in the buffer, so the 8-frame lifetime does not apply to it (D-S26-5).

### Group C: Resolver and FSM (AC: 2-6)

- [x] C1. `ActionRequest` gains `combo: ComboDef` (null = none) and `link_second: bool`. Existing constructor call sites keep working (default args).
- [x] C2. `ActionResolver` link rule, checked after the chain rule and before the cancel and solo rules. For K (slot 1) while the link is open and `window == pair`:
  1. Target = `combos.get_combo(window.x, window.y)`; if null, target = K's solo action with `link_second = true`.
  2. If the target bit (for a combo: the second bit) is on cooldown: a held press is dropped once 8 frames have passed since its `held_frame` (AC5); an unheld press is left in the buffer and expires normally (no partial execution).
  3. Startable when (a) no action runs, or (b) the running action is in RECOVERY and its `cancel_into` contains the target's bit (D-S26-5). If startable: start the target (combo or solo), clear the hold, consume the press. Else: hold it (consume from the buffer if not held yet) and return null.
  4. A K press is not held while J is idle and the link is closed; those cases stay on the 2.5 solo rules.
- [x] C3. A held press is evaluated first on each tick, before new buffered K presses (oldest first). Same-frame J+K (AC6): J resolves first (2.5 rule kept); K sees the link on the next tick.
- [x] C4. `ActionStateMachine._start`: a combo start sets `action` to the combo's `ActionDef`, starts the cooldown of the second bit with the replaced solo action's `cooldown_frames` (DASH 24) (AC2, D-S26-3), and logs `Log.debug(&"action", "combo %s" % name)` once per start (never per frame). A `link_second` start logs once with its action id.
- [x] C5. The 2.5 chain rule, cancel rule and solo rule are unchanged. A J chain hit (hit 2 or 3) reopens the link (B2), so a K press in the link of hit 2 uses the same rules.
- [x] C6. The resolver stays a pure static function over its inputs. The 9-argument `resolve` is already flagged for cleanup (2.5 deferred); a small parameter object is acceptable if it reads cleaner, but no node, no time and no signal is introduced into `ActionResolver`.

### Group D: HUD (AC: 8)

- [x] D1. `RegisterPanel.plan` (pure static) gets the combo lookup (a `ComboTable` argument with `Defs.COMBOS` as the default, or an equivalent injection). The active window row shows the combo name in rows 16-20 (reserved in 2.3) and keeps the existing `J→K` label on row 13.
- [x] D2. The `<<` and `>>` preview rows show the combo name where a combo exists and the two bit glyphs where none exists (no "(no combo)" text, D-S26-10).
- [x] D3. Check `GlyphFont` covers `→` (the existing `JK_LABEL` already uses it, so it should). If it does not, use `J>K` and record the change.

### Group E: Frame overlay (AC: 8)

- [x] E1. The F9 overlay adds link lines: `link open` or `link closed`, `pair X Y` (glyphs), `left N` (frames left in the count), and `held K` or `held -`. The existing four lines are unchanged. `format_lines` stays pure and ASCII-only (test_font_coverage); its signature changes with the new fields, and `test_frame_overlay.gd` is updated.

### Group F: Tests (AC: 9)

- [x] F1. `tests/unit/test_combo_table.gd` (new): `[A,D]` → Dash Strike; `[D,A]` → null; reversed lookup null; unknown pair null; duplicate pair rejected by `validate()`; combo name length rule; `dash_strike.tres` invulnerable frames 1-10 and 12 active frames; hit shape contains a point 4 tiles ahead and not one behind.
- [x] F2. `tests/unit/test_action_resolver.gd` (extended): K follow-up combo start during slash ACTIVE is held; starts on the first RECOVERY frame; no-combo `[D,A]` K is held during dash and starts on the tick after the dash ends; cooldown block drops a held press after 8 frames; shift discards a held press; same-frame J+K.
- [x] F3. `tests/unit/test_action_fsm.gd` (extended): link opens on slash frame 7 and closes at tick k = 19 after frame 10 (accepted at 18, refused at 19); the same for dash; Dash Strike start sets DASH cooldown to 24; combo start from the window `[A,D]` after a shift between J and K gives the new window's solo action; `reset_for_fight` and `set_active(false)` clear the link and hold; `link_second` flag on the no-combo path.
- [x] F4. Register panel tests (`tests/unit/test_register_panel.gd`): combo name and `J→K` on the `[A,D]` window; previews show names for `[A,D]`'s neighbours that have a combo; no name where none exists.
- [x] F5. `tests/unit/test_frame_overlay.gd`: updated `format_lines` output with the link fields.
- [x] F6. Full run: GUT green, `check_guards.sh` OK, Main boots headless for 120 frames without errors.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S26-1 Combo data layout.** `ComboDef` and `ComboTable` as in NP-1 and AD-02 (`Defs.COMBOS`). A combo's `action` is a normal `ActionDef`; its cooldown is not stored on the combo (D-S26-3).
- **[design call] D-S26-2 Dash Strike shape and cancels.** `hit_shape` is a `HitCapsule` of 5 tiles and radius 0.75 tiles along the captured facing, so the sweep covers the whole dash path and a little of the width of the `@`. 2.7 turns this into damage and targets. `cancel_into` is empty: Dash Strike ends in a recovery that cannot be cancelled into a dash (the dash cooldown outlasts the 20 frames). Judge the shape by feel in H2.
- **[design call] D-S26-3 Combo cooldown.** The second bit's cooldown applies, using the replaced solo action's `cooldown_frames` (DASH 24). The combo's own `cooldown_frames` is 0. This matches "the replaced action's bit cooldown applies as normal" (GDD, FR15).
- **[design call] D-S26-4 Link state owner.** `LinkState` is owned by the `ActionStateMachine` instead of `Player` (NP-1 says `Player`). The FSM is the only writer of action state; the overlay and the HUD read it from the FSM. Any later move to `Player` is a refactor with no behaviour change.
- **[design call] D-S26-5 Held link presses and timing.** A K press that cannot start yet (J in STARTUP, ACTIVE, or a non-cancellable RECOVERY) is held by the link, not dropped at 8 frames. It fires at the first tick it is startable: for slash, that is RECOVERY frame 11 (slash `cancel_into` includes DASH). For the no-combo pair, it is the first tick after the dash ends (dash `cancel_into` excludes ATTACK). Holding only while the link is open keeps the 18-frame rule as the bound. This replaces the 2.5 "not consumed, expires after 8 frames" rule for link presses only (D-S25-7 left the call to 2.6). The alternative, starting Dash Strike at J's first ACTIVE frame, would cut the slash's ACTIVE frames 2-4 short and was rejected. The combo *identity* is still decided at the first ACTIVE frame (AC2: "evaluated when J's active frames begin"), while the *start* waits for cancel eligibility.
- **[design call] D-S26-6 Press during J's startup before the link opens.** A K press during J's STARTUP (before the link opens) is not held; it stays in the 8-frame buffer and is evaluated when J's first ACTIVE frame opens the link if still live. Slash startup is 6 frames, so a press at tick 0 is live through tick 8; this is safe for all 2.6 data. Any future startup longer than 7 frames must revisit this.
- **[design call] D-S26-7 Shift and held presses.** A shift closes the link and discards a held K press (it is consumed, nothing executes). A K press made after the shift performs the new window's solo action (AC4). Choosing "execute after shift" would contradict NP-1 #1.
- **[design call] D-S26-8 Cooldown on a held combo.** A held press whose target bit is on cooldown is dropped 8 frames after its `held_frame`, the D-045 rule (AC5). It does not wait for the cooldown to end.
- **[design call] D-S26-9 Chain hits reopen the link.** Each ATTACK chain hit's ACTIVE start reopens the link with the current window pair and serial. The chain record (2.5) is unchanged.
- **[design call] D-S26-10 No-combo preview text.** FR7 and GDD "Register" say a window with no combo shows its two bit glyphs only. The GDD layout note (register panel, "(no combo)") conflicts with that; this story follows FR7 and the GDD rule text, so no "(no combo)" text is drawn.
- **[design call] D-S26-11 No combo beyond Dash Strike.** Echo Dash (D→L), Ghost Echo (L→N) and Dereference (N→A) are not added. Their bits do not exist yet (LOOP and NULL_BIT have no defs), and their stories own them. `get_combo` returns null for their pairs.
- **[design call] D-S26-12 Fallback for an unknown combo name glyph.** If the HUD arrow glyph is missing from `GlyphFont`, use `J>K` (D3). Record in Completion Notes.

### Frame table (2.6 additions; 2.5 table unchanged)

| Action | S | A | R | Total | Invuln | Cancel into | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| dash_strike (A→D, replaces K) | 0 | 12 | 8 | 20 | frames 1-10 | none | DASH 24 (second bit) | 5 tiles over 12 active frames (5 × 16 px / 12 ≈ 6.7 px per frame; TILE_PX = 16), `dash_velocity` from data |
| Link (after J's last ACTIVE frame) | | | | | | | | open for k = 0..18 ticks; k = 19 closed |

Example, slash `[A, D]`: J pressed at tick 0. Frames 1-22 execute on ticks 0-21. Link opens on tick 6 (frame 7). Last active frame 10 on tick 9 (k = 0 is tick 9). A K press that is held from tick 6 starts Dash Strike on tick 11 (D-S26-5 design call: the first RECOVERY frame executes once, then the cancel replaces it). A K press at tick 27 is accepted (k = 18); at tick 28 it is refused (k = 19).

Example, dash `[D, A]`: J (dash) on tick 0, active frames 1-10 on ticks 0-9, link open through k = 18 (tick 27). A K press at tick 3 is held; the dash ends on tick 15 (frame 16) and the slash starts on tick 16 with `link_second = true`.

### Architecture guardrails (must follow)

- `ActionResolver` is the only code that turns J/K into actions (NP-1). It stays a pure static function. `ActionStateMachine` is the only caller and the only writer of action state.
- Simulation folders (`player/`, `combat/`, `register/`, `arena/`) must not reference `ui/`, `presentation/`, `AudioManager` or `VoiceService`. `FrameOverlay` and `RegisterPanel` read sim state only.
- Integer frames only: `*_frames` fields, action frames and link counts as `int`, `ctx.poll_frame` for buffer time. No `delta`, `Timer`, `await`, `create_tween`, `get_ticks_*`.
- Defs are read-only at runtime. Mutable state lives on `Cooldowns`, `LinkState`, the FSM and `Player`. The combo index cache is built once and never mutated afterwards.
- Single writers: `Register` owns the ring and `shift_serial`; `Player` owns position; the FSM owns action and link state.
- Typing: every variable, parameter and return is typed; `StringName` for ids; `Log.debug(&"action", ...)` only on events (open, start, held, drop, close), never per frame.
- Palette: `Palette.INK` and `Palette.BG` only in drawing (test_glyph_palette guard). Overlay text ASCII at 1x through `GlyphFont`.
- Script cycles leak at exit (2.2 lesson): the FSM holds `Player` and `Register`; `Arena` owns them; `LinkState` holds no node or FSM reference.

### Previous story intelligence (2.1-2.5)

- `SimClock.tick()` order: pause gate, poll input into `InputBuffer` stamped with `poll_frame`, `ctx.move_dir`, `poll_frame += 1`, Breakpoint gate, hit-stop gate, tick systems by phase (SHIFTS, ACTIONS, PLAYER), `sim_frame += 1`. The FSM and link count tick only under SimClock, so pause and hit-stop freeze them too.
- 2.5 `ActionResolver` rule (D-S25-7, D-S25-8, D-S25-9): J resolved first; a K press while J is in STARTUP, ACTIVE or non-cancellable RECOVERY is not consumed in 2.5. 2.6 changes this only for link presses (D-S26-5).
- 2.5 `ActionDef.validate()` already rejects `chain_next` cycles. Keep every new def's `validate()` empty for shipped data.
- 2.5 review deferred items that touch this story: "Dash `cancel_into` DASH is dead data (cooldown 24 > total 16)" (dash.tres; leave, harmless); "Missing cooldown block debug log, Arena FSM integration test, pause/hit-stop and shift-during-dash FSM tests" (the shift-between-J-and-K and cooldown-drop tests in F2/F3 cover part of this); "Player lock state has two owners" (keep the FSM as the only caller).
- 2.5 review deferred items this story may close if touched: the 9-argument `resolve` and the `ActionRequest`/`ActionResolver` cycle (C6), the hard-coded ATTACK in `_chain`, and the dead `chain_slot`.
- 2.3 deferred: "Hit-stop/Breakpoint longer than 8 frames drops all buffered input". 2.6 keeps the rule; a held press is not in the buffer and so is not dropped by the 8-frame rule during hit-stop, but its link count still freezes correctly. Check in H3.
- 2.3 HUD: rows 16-20 are reserved for the combo name (2.6); the panel never draws on rows 0-2 or the box border.

### Git intelligence (recent commits)

- `ece5926` Story 2.5: action state machine, hit shapes, `Defs`, `FrameOverlay`, `Register.shift_serial`, F9 overlay, Shift+F9 grid. Pattern: each story adds small files, extends existing tests, keeps `check_guards.sh` green, records design calls and human checks in the story file.
- `783dc74` Story 2.4 and `c0f1f34` Story 2.3: juice and register ring with HUD panel (the combo-name rows were left for 2.6).

### Latest technical information

- No new engine features. Godot 4.7.2 GDScript: `Resource` subclasses with `@export`, typed arrays of resources, `Dictionary` index built lazily, `Node2D.draw_*` and `queue_redraw()`. Confirm exact method names against the existing code before use (`Geometry2D`, `Vector2.normalized`, `Array[ComboDef]`).
- No external library is added. No web research was run for this story.

### Project Context Rules

- Godot project root is `game/`. Files: `game/src/register/` (`combo_def.gd`, `combo_table.gd`), `game/src/player/` (`link_state.gd`), `game/data/combos/`, `game/data/actions/dash_strike.tres`, `game/tests/unit/`.
- `_bmad-output/project-context.md`: "Only `SimClock` calls `tick(ctx)`"; "No `Area2D`/`PhysicsBody2D` for gameplay. Hits are shape math"; "State machines: enum + match + int counters stored as fields"; "Data: typed `Resource` `*Def` classes in `data/**/*.tres`, read-only at runtime"; "Signals: declare only in `event_bus.gd`"; "Never log per frame"; "Ordered combos: look up by ordered pair, never a sorted pair"; "A combo whose second bit is on cooldown stays buffered 8 frames, then is dropped".

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.6 H1] Debug build, F2 (FIGHT), register `[A, D]` (use Q/E to shift from `[D, A]`). Press J then K: the slash swings, then Dash Strike starts one tick after the first recovery frame and covers about 5 tiles. Check the feel in Chrome and Firefox (D-S26-5).
- [ ] [2.6 H2] Dash Strike shape: walk a target-free arena line; the capsule covers the dash path and a little of the width of the `@` (D-S26-2). Note whether the 0.75-tile radius feels right for 2.7.
- [ ] [2.6 H3] Press K during the dash on `[D, A]`: the slash waits for the dash to end (no drift, no double). Shift during the link, then press K: K does the new window's solo action (AC4). Press K in the link while DASH is cooling down: nothing executes after 8 frames (AC5).
- [ ] [2.6 H4] F9 overlay: link open/closed, pair, frames left counting down from 18 after J's last active frame, held K. HUD: `[A, D]` shows `Dash Strike` and `J→K`; previews show names only where a combo exists (D-S26-10).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.6] (ACs, FR7, FR15, FR16, FR20)
- [Source: _bmad-output/planning-artifacts/epics.md#FR15-FR20] (combo trigger, link window, Dash Strike data, no-combo windows)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Combos] (trigger, resolution rules D-045, Dash Strike row)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#The Register] (preview rule, no-combo previews)
- [Source: _bmad-output/game-architecture.md#NP-1] (ActionResolver rules 1-8, data flow, LinkState)
- [Source: _bmad-output/game-architecture.md#Actions & Combos (AD-02)] (ComboDef, ComboTable fields)
- [Source: _bmad-output/game-architecture.md#Notes for Designer] (NP-1 #1-#3 confirmed design calls)
- [Source: _bmad-output/implementation-artifacts/2-5-action-state-machine-with-attack-and-dash.md] (D-S25-1 to D-S25-17, frame model, review deferrals)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (2.3, 2.5 deferrals)

### Review Findings

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor, run as three parallel subagents. 0 decision_needed, 7 patch (all fixed), 12 defer, about 8 dismissed or merged as noise.

- [x] [Review][Patch] Shift during J's STARTUP opened the link on the new window; the link now opens only if the shift serial is unchanged since J started [action_state_machine.gd:_update_link] (blind+edge)
- [x] [Review][Patch] Link stayed uncounted forever if J ended before its last ACTIVE frame; `_finish` now starts the count [action_state_machine.gd:_finish] (edge)
- [x] [Review][Patch] A K HOLD/DROP or a link K start pre-empted J on the same tick (rule 8, AC6); J now resolves first, K stays buffered [action_resolver.gd:resolve] (blind+edge+auditor)
- [x] [Review][Patch] `test_same_frame_j_and_k_resolves_j_first` closed the link, so it tested nothing; the link now stays open (it caught the bug above) [test_action_resolver.gd]
- [x] [Review][Patch] Two new FSM tests: shift during startup, `_finish` during ACTIVE [test_action_fsm.gd]
- [x] [Review][Patch] `wrap_name(name)` shadowed the Node `name` property; renamed `combo_name` [register_panel.gd]
- [x] [Review][Patch] Story text said Dash Strike starts on tick 10 / first recovery frame; now tick 11 everywhere (D-S26-5) [story file]
- [x] [Review][Defer] [design call] Unheld buffered K is not discarded on shift; it can run as the new window's solo action (known edge) -- deferred
- [x] [Review][Defer] [design call] Link can close for a tick between chain hits and reopen; held K lost in the gap -- deferred
- [x] [Review][Defer] `left N` overlay shows 18 before the count starts -- deferred
- [x] [Review][Defer] DROP branch unreachable in play; `held_key`/`held_slot` unused -- deferred
- [x] [Review][Defer] ComboDef.validate gaps (second's solo def, single word > 10 chars e.g. "Dereference" truncates, startup <= 7); `wrap_name` truncation -- deferred
- [x] [Review][Defer] ComboTable lazy index, `first*256+second` key, 11-arg `resolve`/10-arg `format_lines`, mid-test `before_each()` calls -- deferred

## Dev Agent Record

### Agent Model Used

Story created by Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended).
Implemented by Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story (unattended).

### Debug Log References

- Fresh worktree: `godot --headless --import` needed before GUT so new `class_name`s (`LinkState`, `ComboDef`, `ComboTable`) register.
- 2.5 test `test_cancel_slash_recovery_into_dash` failed as expected once the link existed: on `[A, D]` K in slash RECOVERY is now Dash Strike (GDD). Rewritten on `[D, A]` with a K slash cancelled by J's dash (the link is closed because only J actions open it).
- Full GUT run: 43 scripts, 442/442 tests, 6435 asserts. `bash game/tools/check_guards.sh`: OK. `godot --headless --quit-after 120` on Main: no errors.

### Completion Notes List

**Implemented**
- Group A: `ComboDef` (bits, action, 1-11 char name), `ComboTable` (ordered key `first * 256 + second`, index built once on first lookup, duplicate pairs rejected by `validate()`), `dash_strike.tres` (0/12/8, invuln 1-10, 5 tiles, 20 dmg, `HitCapsule` 5 x 0.75, cooldown 0, no cancels), `combo_table.tres` + `combos/dash_strike.tres`, `Defs.DASH_STRIKE` and `Defs.COMBOS`. `test_data_validation.gd` picks the new files up unchanged.
- Group B: `LinkState` (open/reopen, `start_count`, per-tick `tick()`, hold, close). Owned and written only by the FSM (D-S26-4 kept).
- Group C: `ActionRequest` gains `combo`, `link_second`, and a `LinkOp` (HOLD/DROP) instruction form with `def == null`, so the resolver stays pure and the FSM stays the only writer of the link. `ActionResolver.resolve` gains two optional args (`link`, `combos`); the link rule runs after the chain rule; while the link owns K (open, same serial, same window) the cancel and solo rules skip K but still resolve J. FSM: `_age_link` (shift close, count) before resolve, `_update_link` (open on a J action's first ACTIVE frame, count from its last) after the frame executes; combo starts apply the replaced solo cooldown (DASH 24) to the second bit; events logged once (`combo Dash Strike`, `link_second slash_1`, `link open A D`, `link holds K`, `link drops K`, `link closed`). FSM also exposes `combo`, `link_second` and `action_slot` of the running action for 2.7.
- Group D: `RegisterPanel.plan(ring, owned_cap, combos = Defs.COMBOS)` draws the window's combo name (INK) and each preview's name (FADED) under its glyph row; no text where there is no combo (D-S26-10). `→` is covered by the font (D3 passes; `JK_LABEL` and combo names added to `test_font_coverage`).
- Group E: F9 overlay adds `link open|closed`, `pair X Y` (`- -` when closed), `left N`, `held K|-`. `format_lines` stays pure and ASCII.
- `InputBuffer.consume_pushed_frame()` added (additive; `consume()` now delegates to it, lifetime and existing API unchanged) so a held press keeps its push frame.

**Design calls and deviations**
- [design call] D-S26-13 One link, one K follow-up: starting a combo or a `link_second` action closes the link. Otherwise a second K inside the same 18-tick link on `[D, A]` would fire another `link_second` slash.
- [design call] D-S26-14 Register panel re-spaced. The REGISTER interior is 10 cells wide but GDD names reach 11 characters ("Dash Strike", "Dereference"), so the planned single-row preview names could not fit. Names now word-wrap on two rows of 10 cells under their glyph row: hex row 3, byte row 5 (was 8), `reserved` row 6 (was 9), `<<` glyphs row 8 + name rows 9-10, window row 12, `J→K` row 13 (unchanged), window name rows 14-15, `>>` glyphs row 17 + name rows 18-19. Row 20 stays free. **Follow-up for 6.2:** "Dereference" is a single 11-letter word and is cut to "Dereferenc"; rename it or widen the layout then. The cooldown rows the GDD wireframe shows (2.5 and later) no longer have room in this box; a later story must compact (e.g. one name row) if they are added here.
- [design call] Combo start tick: the story example says a held K starts Dash Strike on tick 10. Under the unchanged 2.5 cancel rule the first RECOVERY frame (11) executes once and the cancel replaces frame 12, so it starts on **tick 11**. Changing that would change the 2.5 cancel rule, which this story says to keep.
- [design call] Link timing: the link opens after frame 7 executes (end of tick 6), so presses are evaluated against it from tick 7; the count is k = 0 on tick 9 and presses are accepted through tick 27 (k = 18) and refused on tick 28 (k = 19), for slash and dash. A K pressed on tick 6 is still live on tick 7, so nothing is lost.
- [design call] A HOLD instruction uses the tick: J is not resolved on that tick and waits in the buffer (1 tick). A held press whose target is on cooldown and older than 8 frames returns DROP the same way.
- D-S26-1 to D-S26-12 checked against the GDD and NP-1 and followed. D-S26-5 differs from the architecture snippet (which starts the combo at once, cutting J's ACTIVE frames); the story's choice keeps J's hit intact and is kept.
- C6: the 9-argument `resolve` grew to 11 (two optional); no parameter object yet. The 2.5 deferred cleanup stays open.
- Known edge: an on-cooldown K press left in the buffer (not held) falls back to the solo rules if the link closes while the press is still live. It needs the cooldown to end in the same few frames the link closes, so it was left as is.

**Human checks (for Tiziano; do not block review):** H1-H4 in Dev Notes are unchanged. Note for H1: Dash Strike starts on the tick after the slash's first recovery frame. Note for H4: the combo names now sit on two rows (`Dash` / `Strike`) under each glyph row.

### File List

- game/src/register/combo_def.gd (new)
- game/src/register/combo_table.gd (new)
- game/src/player/link_state.gd (new)
- game/data/actions/dash_strike.tres (new)
- game/data/combos/combo_table.tres (new)
- game/data/combos/dash_strike.tres (new)
- game/tests/unit/test_combo_table.gd (new)
- game/src/core/defs.gd
- game/src/input/input_buffer.gd
- game/src/player/action_request.gd
- game/src/player/action_resolver.gd
- game/src/player/action_state_machine.gd
- game/src/ui/hud/register_panel.gd
- game/src/debug/frame_overlay.gd
- game/tests/unit/test_action_fsm.gd
- game/tests/unit/test_action_resolver.gd
- game/tests/unit/test_frame_overlay.gd
- game/tests/unit/test_register_panel.gd
- game/tests/unit/test_font_coverage.gd
- game/tests/unit/test_input_buffer.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- (also the Godot-generated `.gd.uid` files next to the new scripts)

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S26-1 to D-S26-12 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): combo data and ordered table, LinkState, link rule in ActionResolver, combo / link_second starts in the FSM, HUD combo names (re-spaced panel), F9 link lines, tests (442/442). Status review.
