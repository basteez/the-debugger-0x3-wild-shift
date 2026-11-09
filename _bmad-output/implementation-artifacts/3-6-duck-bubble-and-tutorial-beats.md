---
baseline_commit: f025f9b
---

# Story 3.6: Duck Bubble and Tutorial Beats

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S36-n); the implementer follows them or records a change in Completion Notes. Scope: the duck's text bubble, the VoiceService text-only seam and tutorial beats T1 to T4. The duck VOICE (mumble-speech, MumbleTypewriter, character_spoken) is Story 3.7 and must plug into the seams defined here without changing the bubble's public API. -->

## Story

As a new player,
I want the rubber duck to teach me the shift with jokes,
so that I learn the register within 30 seconds without a manual.

**Requirements:** FR45 (lines 2 to 5: tutorial beats T1 to T4); AD-14 (text-only backend in this story; the voice is 3.7); D-046 (squeak on bubble open, typewriter reveal); D-039 and the duck line budget (T1 to T4 are four of the ten lines); D-040 (first 30 s, measured from the first title click); D-047 (duck bubble cells); AD-05 (presentation reads, never writes); NP-3 (no boss or sim code touches the duck).

## Acceptance Criteria

**Given** `DuckBubble` in the HUD duck region (cols 0–11, rows 22–37, D-047)
**When** a line is requested through `VoiceService.say(line)` (text-only backend)
**Then** the `>o` duck is drawn at cell (0, 22) and the line is word-wrapped at 12 columns, starting on row 23, with a typewriter reveal and a squeak on bubble open
**And** no bubble glyph is drawn outside cols 0–11 or rows 23–37, and the bubble draws only while the HUD is visible (FIGHT)

**Given** the wrap rule (pure `DuckBubble.wrap(text, 12)`)
**When** the four tutorial lines are wrapped
**Then** each line fits 12 columns, no word is split, and each wrapped text is at most 15 lines (rows 23 to 37)

**Given** the typewriter reveal (pure `TypewriterReveal`)
**When** a line is shown for `t` seconds at 30 characters per second
**Then** the revealed count is `min(length, floor(t × 30))`, the line is fully revealed after `length / 30` seconds, and the reveal does not advance while `SimClock.paused` is true

**Given** a line starts showing (the bubble opens or the next queued line starts)
**When** the audio is unlocked
**Then** exactly one squeak plays on the SFX bus through its own player (not the ShiftSfx player), and a locked audio state produces no error (AudioManager's single warning at most)

**Given** `VoiceService.say(line)` with a known line id (`t1_shift`, …) or raw text (the hint template in later stories)
**When** it is called
**Then** a known id resolves to its `DuckLinesDef` text, raw text passes through unchanged, and exactly one `EventBus.duck_line_requested(line_id, text)` is emitted (line id `&""` for raw text); the call returns the resolved text

**Given** `data/duck/duck_lines.tres` (`DuckLinesDef`, typed `DuckLineDef` entries)
**When** `test_data_validation` and `test_duck_lines` run
**Then** `validate()` is empty, the ids are unique, all text is ASCII, and the four entries equal the GDD strings exactly:
- `t1_shift`: "Q and E shift your bits. Only the two on the left are live; the rest are in code review."
- `t2_semicolon`: "See the semicolon? It's always the semicolon. Hit it when it opens."
- `t3_dash_strike`: "J then K: Dash Strike. Two bits, one commit."
- `t4_phase_two`: "It refactored itself. Have you tried shifting it off and on again?"

**Given** a FIGHT of the Infinite Loop (`boss_id` `infinite_loop`, boss 0, not practice, not the framework test boss)
**When** the first presentation frame of the fight runs
**Then** T1 is requested immediately (`DuckDirector`, control starts, D-040)

**Given** the Infinite Loop is in FIGHT after T1
**When** its first `;` opens (`InfiniteLoopBody.iteration` reaches 1, the first spinning tick after the first shift, D-S33-19)
**Then** T2 is requested

**Given** the register window is `[ATTACK, DASH]` and its combo is Dash Strike (`combo.action == Defs.DASH_STRIKE`)
**When** that window first becomes active
**Then** T3 is requested

**Given** the Infinite Loop reaches phase index 1 (GDD phase 2, the 66 to 33% band)
**When** the phase changes
**Then** T4 is requested

**Given** the beats
**When** they are requested
**Then** they fire strictly in order (T1 before T2 before T3 before T4), each at most once per run; a later beat waits until the earlier one has been requested, and `due_beat()` is pure and returns the index of the next due beat or -1

**Given** a new run (`Game.flow_state` changes to TITLE)
**When** the beat record is reset
**Then** all four beats may fire again in the next run

**Given** the fight ends (any flow state other than FIGHT, for example DEAD or HARVEST)
**When** the flow changes
**Then** the bubble clears (its queue is dropped and nothing draws) and beats already requested do not repeat on retry (a retry does not replay T1)

**Given** a bubble with a line showing and more lines queued
**When** a line's hold time ends
**Then** the next queued line starts (FIFO); at most 4 lines are pending, and a request beyond that is dropped with one `Log.debug`

**Given** the replay and determinism suite
**When** `tests/replays/test_replays.gd` and `tests/integration/test_infinite_loop_replay.gd` run
**Then** they pass unchanged, with no new RNG draw, no `SimContext` use and no `tick()` change; the bubble and director never write sim state (AD-05)

**Given** the sim folders (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`)
**When** a guard test scans them
**Then** none references `DuckBubble`, `DuckDirector`, `DuckLines`, `VoiceService` or `AudioManager` (extending the existing isolation rule), and `src/ui/duck/` never calls `SimClock.tick` or `Register`/`Player` mutators

**Given** the HUD frame
**When** the FIGHT screen draws
**Then** the old duck box border is no longer drawn (the bubble owns cols 0–11, D-S36-4), the register box and all other HUD regions are unchanged, and `test_hud_layout` and `test_font_coverage` pass with the bubble's text included

**Given** `EventBus`
**When** this story is merged
**Then** the only new signal is `duck_line_requested(line_id: StringName, text: String)` (listed in the architecture's initial set; no emitter in sim code), declared in `event_bus.gd` only

**Given** `tests/unit/test_duck_bubble.gd`, `test_duck_lines.gd`, `test_voice_service.gd`, `test_duck_director.gd`
**When** they run
**Then** they verify the wrap rule and the four strings, the reveal arithmetic and pause freeze, the queue order and cap, the id/raw resolution, `due_beat` for every ordering case, and the reset and retry rules

## Scope Boundaries

- **In:** `DuckBubble` (HUD node, wrap, typewriter, squeak, queue, `>o`), `TypewriterReveal` (pure reveal seam for 3.7), `VoiceService` text-only backend and `say()`, `DuckLinesDef` / `DuckLineDef` and `data/duck/duck_lines.tres` with T1 to T4, `DuckDirector` (beat triggers), `due_beat()`, one `EventBus` signal, one AudioManager squeak player, the HudFrame duck box removal, tests and guards.
- **Out (3.7):** mumble-speech addon vendoring and `MumbleSpeaker`/`MumbleVoice`/`MumbleTypewriter`, the `Voice` bus usage, the pre-render contingency, `character_spoken` and `finished` signals, the voice failure `Log.warn`. Do not vendor `addons/mumble_speech` here.
- **Out (later stories):** the intro duck line (Epic 6, 6.6), Breakpoint and Watch tutorial lines (4.4, 5.5, 5.1), the hint template (4.4), Harvest and ending lines (3.8, 6.8), the sky comments and fixed lines (6.9), the 3rd-death hint (5.x, RunState.deaths_on_boss), the Patched and hit cue player split beyond the squeak (7.2).
- **Out (sim):** no beat changes any boss, register or player value; no hit-stop; no Breakpoint.

## Tasks / Subtasks

### Group A: Data and line definitions

- [x] A1. `src/ui/duck/duck_line_def.gd`: `class_name DuckLineDef extends Def`; `@export var id: StringName`, `@export var text: String`. `validate()`: id non-empty, text non-empty, ASCII only, no word longer than 12 characters, wrapped line count ≤ 15.
- [x] A2. `src/ui/duck/duck_lines_def.gd`: `class_name DuckLinesDef extends Def`; `@export var entries: Array[DuckLineDef]`. `validate()`: ids unique; `find(id) -> DuckLineDef` (null when absent). Every entry's `validate()` messages are forwarded.
- [x] A3. `data/duck/duck_lines.tres` with exactly T1 to T4 (ids and strings as in AC 6). Lines 1, 6 to 10 of the duck budget are NOT added here.
- [x] A4. `data/duck/duck_voice.tres` is NOT created here (3.7).

### Group B: Pure helpers (no scene, no RNG)

- [x] B1. `DuckBubble.wrap(text: String, width: int = 12) -> PackedStringArray` (static): greedy word wrap on single spaces, no word split, a word longer than `width` is a validation error (A1), not a runtime split.
- [x] B2. `TypewriterReveal` (`src/ui/duck/typewriter_reveal.gd`, `class_name`, `extends RefCounted`): fields `length`, `chars_per_second: float = 30.0`, `elapsed_s`, `revealed` (int). Methods: `set_line(length: int)`, `advance(delta_s: float)`, `set_revealed(n: int)` (the 3.7 seam: a voice sets the count directly and the timer stops driving it), `is_done() -> bool`. Static pure `visible_chars(elapsed_s, cps, length) -> int = min(length, floori(elapsed_s × cps))`.
- [x] B3. `DuckDirector.due_beat(requested: int, in_fight: bool, boss_id: StringName, iteration: int, window_is_dash_strike: bool, phase_index: int) -> int` (static): returns `requested` (the index of the next beat) when its trigger holds, else -1; `requested >= 4` → -1. Triggers: 0 (T1) `in_fight and boss_id == &"infinite_loop"`; 1 (T2) `iteration >= 1`; 2 (T3) `window_is_dash_strike`; 3 (T4) `phase_index >= 1`. Beats 1 to 3 also require the boss to be infinite_loop (the boss is a precondition in the caller; keep the function pure and test it).

### Group C: VoiceService text-only backend

- [x] C1. `EventBus`: add `signal duck_line_requested(line_id: StringName, text: String)` with the `@warning_ignore("unused_signal")` pattern and a `##` doc line (Story 3.6, AD-14).
- [x] C2. `src/autoloads/voice_service.gd` (keep the autoload name and order): `extends Node`, `const LINES := preload("res://data/duck/duck_lines.tres")`. `func say(line: String) -> String`: a known id resolves to its text (line_id = id); otherwise the raw text (line_id `&""`); emits `EventBus.duck_line_requested` once; returns the resolved text. Log only `Log.debug(&"voice", ...)`.
- [x] C3. Backend seam (text-only in 3.6): a private `_speak(line_id, text)` that does nothing beyond the emit. 3.7 replaces the body with the mumble backend; `stop()` is provided (no-op in 3.6) so the bubble can cut speech later. Do not add signals to `VoiceService` (project rule: signals only in `event_bus.gd`).

### Group D: Audio

- [x] D1. `AudioManager`: `func play_squeak() -> void` plays `make_blip()` on a lazily created `AudioStreamPlayer` named `DuckSqueak` on the SFX bus. Ignored before unlock (same warn-once rule as `play_sfx`). A static cache of the stream (`_squeak_stream`) avoids re-making it per line.
- [x] D2. Do not change `play_sfx` or `ShiftSfx`; the squeak never shares that player.

### Group E: DuckBubble (HUD node)

- [x] E1. `src/ui/duck/duck_bubble.gd`: `class_name DuckBubble extends Node2D`. Child of the `Hud` in `src/ui/hud/hud.tscn` (LogPanel pattern, no new `.tscn`, D-S36-10). Connects `EventBus.duck_line_requested` and `EventBus.flow_state_changed` in `_enter_tree` and disconnects in `_exit_tree` (the 3.2 deferred pattern, not the 3.1 gap).
- [x] E2. State: `_queue: Array[String]` (text), `_queue_ids` (parallel), `_current_lines: PackedStringArray`, `_reveal: TypewriterReveal`, `_hold_s: float`, `_showing: bool`. Constants: `MAX_PENDING := 4`, `HOLD_BASE_S := 2.0`, `HOLD_PER_CHAR_S := 0.05`, `CHARS_PER_S := 30.0` (presentation constants, not gameplay balance, D-S36-13).
- [x] E3. `_process(delta)`: return when `SimClock.paused`; advance the reveal; after full reveal count down the hold; when the hold ends start the next queued line or hide. A line start calls `AudioManager.play_squeak()` once.
- [x] E4. `_draw()`: `>o` at HUD cell (0, 22) via `GlyphFont.draw_cell`; the wrapped lines from row 23 at 1x INK, each line cut to its revealed count, cells within cols 0–11 and rows 23–37. Call `queue_redraw()` on every reveal step while showing.
- [x] E5. `clear()`: empties the queue and hides. Called on `flow_state_changed` whenever `to != Game.FlowState.FIGHT`.
- [x] E6. `TypewriterReveal` is the only place the reveal count is stored; `set_revealed` is public for 3.7 (AC 11 seam).

### Group F: DuckDirector and Main attachment

- [x] F1. `src/ui/duck/duck_director.gd`: `class_name DuckDirector extends Node`. Fields: `arena: Arena` (set by Main), `requested: int = 0`. `_process`: reads `Game.flow_state`, `arena.boss` (as `InfiniteLoopBody` for `iteration`), `arena.register.active_window()` and `Defs.COMBOS.get_combo(w.x, w.y)` (`.action == Defs.DASH_STRIKE` for T3), and the boss `phase_index`; calls `due_beat`; on a non-negative result calls `VoiceService.say(id)` with `DUCK_IDS[beat]` and increments `requested`. Reads only (AD-05).
- [x] F2. `flow_state_changed`: on `to == TITLE` set `requested = 0`. Nothing else is written. Retry (DEAD to FIGHT) keeps `requested`.
- [x] F3. `src/main/main.gd`: create `DuckDirector` after `JuiceDirector` in `_build_layers()`, name `DuckDirector`, set `arena`, `add_child`. Main is the attach point (presentation rule, as `JuiceDirector`).
- [x] F4. `DUCK_IDS: Array[StringName] = [&"t1_shift", &"t2_semicolon", &"t3_dash_strike", &"t4_phase_two"]` lives in `duck_director.gd`.

### Group G: HUD frame

- [x] G1. `src/ui/hud/hud_frame.gd`: stop drawing `_box(Hud.DUCK)` (D-S36-4). `Hud.box_rows(Hud.DUCK)` stays (its test is pure). The register box and the rest of the frame are unchanged.
- [x] G2. `hud.tscn`: add a `DuckBubble` Node2D child of `Hud` (after `LogPanel`, before `GridOverlay`), script `res://src/ui/duck/duck_bubble.gd`.

### Group H: Tests and guards

- [x] H1. `tests/unit/test_duck_bubble.gd`: wrap of each T line (line count, every line ≤ 12, rejoin equals the input words), `wrap` never splits, `TypewriterReveal` arithmetic (0, partial, full, clamp), `set_revealed` overrides, queue FIFO order, `MAX_PENDING` cap, `clear()`, the `>o` cell and that no cell outside the region is drawn (use `cells_for_line` if a pure helper is added; prefer a pure `line_cells(line_index, text) -> Array[Vector2i]` helper for the test).
- [x] H2. `tests/unit/test_duck_lines.gd`: the four strings exactly (AC 6), unique ids, ASCII, every `validate()` empty, and the DuckLinesDef find/absent behaviour.
- [x] H3. `tests/unit/test_voice_service.gd`: `say(id)` returns the GDD text and emits `duck_line_requested(id, text)`; `say(raw)` emits `&""`; one emit per call; `stop()` is a no-op. Use a GUT signal watcher on EventBus.
- [x] H4. `tests/unit/test_duck_director.gd`: `due_beat` for every case: T1 without the boss, with the test boss (`test_boss` id), with boss_index other than 0 (caller precondition documented); T2 before and after `iteration` 1; T3 with the wrong window and with `[D,A]`; T4 at phase 0 and 1; "requested = 4 → -1"; ordering: T3 is not due while requested is 1.
- [x] H5. Extend `tests/unit/test_font_coverage.gd` with the four duck lines and the `>o` glyph (`texts.append_array(DuckLinesDef texts)`).
- [x] H6. Update `tests/unit/test_hud_layout.gd`: the frame no longer draws the DUCK box (a `Hud` frame test reads the draw calls or asserts the constant; keep the `box_rows` width test).
- [x] H7. Guard test `tests/unit/test_duck_isolation.gd`: textual scan of `res://src/{input,register,player,combat,bosses,skills,arena}` for `DuckBubble|DuckDirector|DuckLines|duck_line|VoiceService|play_squeak` (none), and of `res://src/ui/duck/` for `tick(`, `SimContext`, `.rng`, `Register`/`Player` writers (none). Keep the rule textual, as the 3.4 guard.
- [x] H8. Run the full GUT suite headless (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`). The replay tests must pass WITHOUT edits to their expectations (AC 10). If a replay hash changes, the bubble leaked into the sim: fix the leak, not the hash.
- [ ] H9. Manual check (not a gate here): on `?debug` and in the editor, FIGHT 1 shows T1 at once and T2+T3 after the first shift; the squeak plays on each line; the bubble freezes on F-key pause and resumes.

### Group I: Finish

- [x] I1. Dev Agent Record: list every `[design call]` taken (or record a change), the test counts, and the replay check result.
- [x] I2. `sprint-status.yaml`: `3-6-duck-bubble-and-tutorial-beats` to `review` after the code review (the create phase sets `ready-for-dev`).

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S36-1 One story, ordered groups.** Not split (the epic keeps 3.6 as one unit with 3.7 separate). Groups A to C alone give a tested data and text seam; D to F give the visible bubble and the beats; G to H the layout and the guards.
- **[design call] D-S36-2 Text-only VoiceService through the architecture's signal.** `VoiceService.say(line) -> String` resolves the text and emits `EventBus.duck_line_requested(line_id, text)`, the signal the architecture lists in its initial set. VoiceService declares no signal itself (project rule). 3.7 adds the speech signals to `EventBus` (`duck_character_spoken`, `duck_line_finished`), not to VoiceService.
- **[design call] D-S36-3 Data holds only T1 to T4.** The other six duck lines arrive with their stories (the budget is ten lines in total, D-039). The `DuckLinesDef` grows by entries, not by code. Ids are stable snake_case keys so tests and later beats refer to them.
- **[design call] D-S36-4 Bubble width and the duck box.** The AC says "word-wrapped at 12 columns" in the duck region cols 0–11 (D-047). The 1.5 HUD draws a box at those cols, whose interior is 10 columns, so a 12-wide wrap cannot sit inside it. Default: the bubble owns cols 0–11 without a border; `HudFrame` stops drawing the DUCK box. The GDD wireframe shows the duck area without a border. If a border is wanted later, the wrap becomes 10 wide (a one-constant change, the tests read the constant).
- **[design call] D-S36-5 Typewriter and hold timing.** 30 characters per second (about 33 ms per character, the typewriter feel the GDD asks for). Each line holds for `2.0 s + 0.05 s × length` after the full reveal. T1 (88 characters) therefore shows for about 3 s to reveal and about 6.4 s to hold. At most 4 lines are pending; a fifth request is dropped with `Log.debug`. Queued lines start in FIFO order.
- **[design call] D-S36-6 Squeak: placeholder on its own player.** The squeak is `AudioManager.make_blip()` (the same placeholder the boss tell uses, D-S31-16) played on a separate `DuckSqueak` player. The real jsfxr squeak arrives in 7.2. It plays at every line start (each bubble open), not only the first line of a run. The shared-player issue (3.2 deferred) is folded for the squeak only; the hit and Patched cue split stays deferred to 7.2.
- **[design call] D-S36-7 Beat triggers are polled reads of sim state.** `DuckDirector` reads `Game.flow_state`, the boss and the register each presentation frame and calls the pure `due_beat()`. No new EventBus signal is needed, and no sim code knows the duck exists. Trigger definitions: T1 at FIGHT of the Infinite Loop; T2 at `InfiniteLoopBody.iteration` 1 (the first `;` opening, which is the first spinning tick after the first shift, D-S33-19); T3 when the active window is `[ATTACK, DASH]` and its combo is Dash Strike; T4 at `phase_index` 1. Beats fire in order, so T2 is always requested before T3 even though both can become due on the first shift.
- **[design call] D-S36-8 Clear on leaving FIGHT.** The bubble clears when the flow leaves FIGHT (DEAD, HARVEST, ENDING, TITLE). Requested lines that never showed are dropped, not re-queued. A beat counts as requested once; a retry does not replay T1 (the 3rd-death hint is a later story, and its own rule).
- **[design call] D-S36-9 Replay and determinism.** The duck layer is presentation only: no RNG, no `SimContext`, no `tick`, no write to sim state. The existing replay tests must pass unedited. The beats read state after the sim tick, so they cannot change a replay hash.
- **[design call] D-S36-10 Nodes, not scenes.** `DuckBubble` is a child of `Hud` in `hud.tscn` (the LogPanel pattern); `DuckDirector` is attached by Main (the JuiceDirector pattern). The architecture's `duck_bubble.tscn` is not created: the bubble is a `Node2D` with `_draw`, and a scene would only hold a script.
- **[design call] D-S36-11 Voice-ready seam.** The bubble's reveal count lives in `TypewriterReveal`. In 3.6 the timer drives it; 3.7 calls `set_revealed(n)` from `duck_character_spoken` and the bubble draws the same way. `VoiceService.say` is the only entry point for any speech, so 3.7 swaps the backend without touching `DuckBubble` or `DuckDirector`.
- **[design call] D-S36-12 Pause freezes the bubble.** `_process` returns while `SimClock.paused` (Esc, focus loss). The hold countdown and the reveal both stop, so the player never misses a line to a pause.
- **[design call] D-S36-13 Presentation constants live in the scene code.** The typewriter speed, hold times and pending cap are presentation feel, not balance (the balance-in-`.tres` rule covers gameplay numbers). They are `const` in `duck_bubble.gd` and `typewriter_reveal.gd`, named, and the tests use the constants.

### Existing code this story touches (verified at baseline f025f9b)

- `game/src/autoloads/event_bus.gd`: add `duck_line_requested` only (C1). The file has 45 lines and the pattern is one `@warning_ignore("unused_signal")` plus a doc line per signal.
- `game/src/autoloads/voice_service.gd`: a one-line stub (`extends Node`, comment "Stub until its owning story"). Keep the name and autoload order (`test_autoloads.gd` checks them).
- `game/src/autoloads/audio_manager.gd`: `make_blip()` exists (line ~156); `play_sfx` uses the lazily created `_shift_player`, `_warn_locked_once()` and `_unlocked`. Add `play_squeak()` beside `play_sfx`.
- `game/src/autoloads/game.gd`: `FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }`; `_set_flow_state` emits `flow_state_changed(from, to)` before the Main listener runs `apply_flow_state` (which calls `arena.enter_fight`). `DuckDirector` reads the arena on `_process`, so the order of listeners does not matter.
- `game/src/main/main.gd`: `_build_layers()` builds `juice_director` after the layers; add the `DuckDirector` the same way. `apply_flow_state` already calls `hud.log_panel.clear()` on FIGHT; the bubble clears itself on `flow_state_changed` instead.
- `game/src/ui/hud/hud.gd`: `Hud.DUCK := Rect2i(0, 22, 12, 16)`, `Hud.box_rows`, `region_of` (`&"duck"`). Keep the constants; the bubble uses `Hud.DUCK.position` and the 12-column width.
- `game/src/ui/hud/hud_frame.gd`: `_draw` calls `_box(Hud.DUCK)` (remove only that line, G1).
- `game/src/ui/hud/hud.tscn`: children `Frame`, `RegisterPanel`, `LogPanel`, `GridOverlay`; add `DuckBubble` after `LogPanel`.
- `game/src/ui/hud/log_panel.gd`: the model for a HUD Node2D that listens to EventBus in `_enter_tree`, draws with `GlyphFont.draw_cell(self, cell, text, Palette.INK, SCALE)` and uses HUD cells.
- `game/src/presentation/player_view.gd`: `DUCK_GLYPH := ">o"`; the arena duck is unchanged.
- `game/src/bosses/infinite_loop/infinite_loop_body.gd`: `iteration` (line ~54, incremented at each opening), `phase_index` is on `BossController` (`game/src/bosses/framework/boss_controller.gd`, line ~24), `boss_def.boss_id` (`&"infinite_loop"` in `data/bosses/infinite_loop/boss_def.tres`).
- `game/src/register/register.gd`: `Register.Bit { ATTACK = 1, DASH = 2, ... }`, `active_window() -> Vector2i` (the two leftmost bits: `[ATTACK, DASH]` is Dash Strike).
- `game/src/register/combo_table.gd`: `get_combo(first, second) -> ComboDef` (ordered). `ComboDef` has `first`, `second`, `action: ActionDef`, `display_name`; it has NO `id` field, so compare `combo.action == Defs.DASH_STRIKE` (`game/src/core/defs.gd`).
- `game/src/core/glyph_font.gd`: `draw_cell(canvas, cell, text, color, scale)`, `cell_to_px`, `text_width`. Font: `game/assets/fonts/wildshift8.fnt` (8 px cells, CP437-style). `tests/unit/test_font_coverage.gd` builds the set of drawn glyphs; add the bubble text to it.
- `game/src/core/def.gd`: `class_name Def extends Resource` with `validate() -> PackedStringArray`; `test_data_validation.gd` loads every `res://data/**/*.tres` and asserts an empty `validate()`.
- `game/data/duck/`: exists and is empty (`.gitkeep`). `game/src/ui/duck/`: exists and is empty (`.gitkeep`). Both are in `test_folder_tree.gd`.

### Wrap check (computed at story creation, Python `textwrap` at width 12, to be re-checked by `DuckBubble.wrap`)

- T1: 8 lines, longest 12 ("Q and E" / "shift your" / "bits. Only" / "the two on" / "the left are" / "live; the" / "rest are in" / "code review."). Fits rows 23 to 30.
- T2: 7 lines, longest 11 ("semicolon?" and "semicolon."). Fits.
- T3: 4 lines, longest 12 ("Dash Strike."). Fits.
- T4: 7 lines, longest 12 ("shifting it"). Fits.
- Every word is at most 10 characters ("refactored"), so the A1 word-length rule passes for all four.

Note: `textwrap` breaks on hyphens and long words by default; `DuckBubble.wrap` must split only on spaces, and the numbers above assume that. Recheck with the implementation's own function in H1.

### Architecture guardrails (must follow)

- AD-05 and the project-context rule: presentation reads, never writes. `DuckBubble`, `DuckDirector` and `VoiceService` hold no sim reference that they mutate.
- Simulation folders must not reference `ui`, `presentation`, `AudioManager`, `VoiceService` or the duck classes (architecture rule 1; the guard in H7 makes it executable).
- Signals only in `event_bus.gd`, past tense, typed args (`duck_line_requested` is the only addition).
- No `delta`-driven logic in `src/bosses/`, `src/combat/`, `src/register/`, `src/player/`, `src/arena/`. The presentation `_process` in `src/ui/duck/` is allowed (presentation, D-S36-12), but it must never drive anything the sim reads.
- Static typing everywhere; `StringName` ids; GDScript 2.0; `await` and Tweens are not needed here (the timers are plain float counters).
- Logging: `Log.debug(&"voice", ...)` for requests; `Log.warn` only for environment failure (none in 3.6); no per-frame logs.
- Font: every glyph drawn must be in the vendored font (ASCII only for the duck lines; `test_font_coverage` enforces it).
- Balance and invariants: the duck lines are data (`data/duck/duck_lines.tres`), validated in `DuckLinesDef.validate()`.

### Previous story intelligence (3.1 to 3.5 and their reviews)

- 3.1 (`D-S31-27`, `D-S31-16`): the visible tell and the placeholder cues are `AudioManager.make_blip()`; the same placeholder is the squeak (D-S36-6).
- 3.1 deferred: `BossView`/`AudioManager` connections lack `_exit_tree` disconnects. The new nodes must disconnect in `_exit_tree` (E1), so the new code does not repeat it.
- 3.2 deferred: "Hit/patch cues share the single ShiftSfx AudioStreamPlayer; overlapping cues truncate each other. Give hit cues their own player." 3.6 folds this for the squeak only (D-S36-6, D2); the hit cue split stays open for 7.2.
- 3.3 D-S33-19 and D-S33-6: the first `;` opens at the first spinning tick, which follows the first shift; the ring is still until then. This is the basis of T2 (D-S36-7).
- 3.4 D-S34-23: no attack before the loop starts (`started`) matches the tutorial beat "the ring stays still until the first shift". T1 is requested at FIGHT start, before any shift.
- 3.5 review: "Log.debug on events only (split, opening, Spit fire, pool-full skip); never per tick." The duck follows the same rule.
- 2.8 `LogPanel` and 2.4 `JuiceDirector`: the presentation listener patterns (`_enter_tree` connect, `_exit_tree` disconnect; Main attaches; `reset()` on flow change).
- 2.9 D-S29-10: DEAD keeps the log lines; the bubble is different: it clears on leaving FIGHT (D-S36-8). Say so in Completion Notes.

### Git intelligence

- `f025f9b` (3.5) is the tip; the branch stacks 3.1 to 3.5. The 3.5 change set is the template for test names and the "Created unattended" header.
- The 2.8 and 2.9 changes show the pattern for a HUD node plus a Main attach and a `_exit_tree` disconnect.

### Latest technical information

- Godot 4.7.2-stable (pinned, project-context rule), GDScript only, no new library, no addon. Presentation uses `_process(delta)` (allowed in `src/ui/`), `Node2D._draw` with `queue_redraw()`, `GlyphFont.draw_cell`. Context7 `/godotengine/godot-docs/__branch__4.7` for any API doubt.
- `AudioStreamPlayer` on the SFX bus, created lazily, as `play_sfx` does; no `AudioEffects` (Sample mode).
- GUT 9.6.1 headless CLI as in 3.1 to 3.5.

### Project Context Rules

- Only `SimClock` calls `tick()`. Presentation may use `_process` and `await` (`src/ui/`), never in sim folders.
- Signals only in `src/autoloads/event_bus.gd`.
- Data: `Def` subclasses under `src/ui/duck/` (`DuckLineDef`, `DuckLinesDef`), instanced data in `data/duck/duck_lines.tres`; validated by `test_data_validation.gd`.
- Names: `duck_bubble.gd`, `duck_director.gd`, `duck_lines_def.gd`, `duck_line_def.gd`, `typewriter_reveal.gd`, `voice_service.gd`; ids `t1_shift` etc.
- Web: no audio before the first input (the squeak is silent until unlock, which the title press guarantees before FIGHT); Sample mode; no `AudioEffects`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.6: Duck Bubble and Tutorial Beats]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.7: Duck Voice (mumble-speech)] (the seam this story must leave open)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Boss 1 — Infinite Loop (tutorial), Duck (hint system), HUD Layout (D-047)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-039, D-040, D-046, D-047]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md] (its table calls the duck beats "3.5"; the planning `epics.md` numbering, 3.6, is authoritative here)
- [Source: _bmad-output/game-architecture.md#AD-05, AD-14, ADR-03, ADR-05, Duck Voice (AD-14), Project Structure (src/ui/duck, data/duck)]
- [Source: _bmad-output/project-context.md#Critical Implementation Rules, Code Organization Rules]
- [Source: _bmad-output/implementation-artifacts/3-1 to 3-5 story files, Design calls and Review Notes]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of story-3.2, story-3.1; story-2-8 (Log/HUD notes)]

## Dev Agent Record

### Agent Model Used

claude opus (Claude Opus 5.5, `claude-opus-5-5`), unattended epic pipeline, implementation phase.

### Debug Log References

- First import: `Parse Error: Too few arguments for "wrap()"`. Inside `DuckBubble`, a bare `wrap(text, 12)` resolves to the global `@GlobalScope.wrap(value, min, max)`. Fixed by calling `DuckBubble.wrap(...)` explicitly inside the class (the public API name from B1 is kept).
- Baseline suite before the tests were added: 804/804 passing with the code changes in place (no regressions from the HUD/Main wiring).
- Final: GUT 854/854 passing (67 scripts, 31921 asserts), `---- All tests passed! ----`, no `SCRIPT ERROR` / `Parse Error`; `bash game/tools/check_guards.sh` → `check_guards: OK`.
- Replays: `tests/replays/test_replays.gd` and `tests/integration/test_infinite_loop_replay.gd` pass unedited (no file under `tests/replays/` or `tests/integration/` touched).

### Completion Notes List

- **Data (A1-A4):** `DuckLineDef` (id, text; validate: non-empty, printable ASCII, no word > `DuckBubble.WRAP_WIDTH`, ≤ `DuckBubble.MAX_LINES` wrapped lines) and `DuckLinesDef` (entries, `find(id)`, unique ids, forwards entry messages). `data/duck/duck_lines.tres` holds exactly T1-T4 as inline sub-resources with the GDD strings. No `duck_voice.tres` (3.7).
- **Pure helpers (B1-B3):** `DuckBubble.wrap` (greedy, spaces only, never splits, runs of spaces collapse), `TypewriterReveal` (`set_line`, `advance`, `set_revealed`, `is_done`, static `visible_chars` with a 1e-6 epsilon so a line is full at exactly `length / 30` s), `DuckDirector.due_beat`. Wrap counts match the story's Python check: T1 8, T2 7, T3 4, T4 7 lines.
- **VoiceService (C1-C3):** `EventBus.duck_line_requested(line_id, text)` is the only new signal. `say(line)` resolves an id or passes raw text (id `&""`), logs `Log.debug(&"voice", ...)`, emits once, calls the `_speak` seam (no-op), returns the text; `stop()` is a no-op. No signal on VoiceService (tested).
- **Audio (D1-D2):** `AudioManager.play_squeak()` on a lazily created `DuckSqueak` player (SFX bus), static `_squeak_stream` cache of `make_blip()`, warn-once before unlock. `play_sfx`/`ShiftSfx` untouched.
- **DuckBubble (E1-E6):** HUD child after `LogPanel` in `hud.tscn`; `_enter_tree`/`_exit_tree` connect/disconnect; `>o` at (0, 22); wrapped text from row 23 at 1x INK, each line cut to the revealed count (the reveal counts the joined text, one break char between wrapped lines, so 3.7's spoken index maps 1:1); `step(delta)` (the `_process` body, testable) returns while `SimClock.paused`; hold = 2.0 + 0.05 × length; FIFO queue, `MAX_PENDING` 4 with `Log.debug` on drop; squeak on every line start; `clear()` on any flow state other than FIGHT. Exposed as `Hud.duck_bubble`.
- **DuckDirector (F1-F4):** attached by Main after JuiceDirector with the arena; `poll()` (the `_process` body) reads flow state, `arena.boss` (`boss_id`, `phase_index`, `InfiniteLoopBody.iteration`) and `arena.register.active_window()` + `Defs.COMBOS` (`action == Defs.DASH_STRIKE`); at most one beat per frame; `requested` resets only on TITLE.
- **HUD (G1-G2):** `HudFrame` no longer draws the DUCK box; `Hud.box_rows(Hud.DUCK)` and its test stay.
- **Tests (H1-H7):** new `test_duck_bubble.gd` (20), `test_duck_lines.gd` (6), `test_voice_service.gd` (6), `test_duck_director.gd` (12, incl. a poll run on a real `Arena` with the Infinite Loop through T1→T4, test boss, TITLE reset and retry), `test_duck_isolation.gd` (5, textual guard both ways, with self-tests of the patterns). Extended `test_font_coverage.gd` (duck glyph + wrapped lines) and `test_hud_layout.gd` (DuckBubble child order, frame no longer draws the DUCK box).
- **H9 manual check:** not run (no human in this unattended phase; the task says it is not a gate); its box is left unchecked for the reviewer or playtest.
- **D-S29-10 vs D-S36-8:** DEAD keeps the console log lines (2.9), but the duck bubble clears on leaving FIGHT, DEAD included (3.6). Intentional difference.
- **Design calls taken during implementation:**
  - [design call] D-S36-14 `MAX_PENDING` counts queued lines only, not the line showing: with one line up, four more may wait; the sixth request is dropped.
  - [design call] D-S36-15 `due_beat()` checks `in_fight` and `boss_id == &"infinite_loop"` for every beat (not only T1), so the purity covers the precondition; the caller passes `&""` when there is no boss (practice, bosses 1-2 today).
  - [design call] D-S36-16 The typewriter reveals the wrapped text joined with single spaces (each line break counts as one character), matching the original text index for 3.7's `set_revealed(n)`.
  - [design call] D-S36-17 `DuckBubble.step(delta)` and `DuckDirector.poll()` hold the `_process` bodies so tests drive them without frames; the director requests at most one beat per frame.
  - [design call] D-S36-18 The duck isolation guard also scans `voice_service.gd` (it must not touch the sim either) and allows only `SimClock.paused` reads in `src/ui/duck/`.
- All story design calls D-S36-1 to D-S36-13 followed as written.

### File List

- game/src/ui/duck/duck_line_def.gd (new)
- game/src/ui/duck/duck_line_def.gd.uid (new)
- game/src/ui/duck/duck_lines_def.gd (new)
- game/src/ui/duck/duck_lines_def.gd.uid (new)
- game/src/ui/duck/typewriter_reveal.gd (new)
- game/src/ui/duck/typewriter_reveal.gd.uid (new)
- game/src/ui/duck/duck_bubble.gd (new)
- game/src/ui/duck/duck_bubble.gd.uid (new)
- game/src/ui/duck/duck_director.gd (new)
- game/src/ui/duck/duck_director.gd.uid (new)
- game/data/duck/duck_lines.tres (new)
- game/src/autoloads/event_bus.gd (modified)
- game/src/autoloads/voice_service.gd (modified)
- game/src/autoloads/audio_manager.gd (modified)
- game/src/main/main.gd (modified)
- game/src/ui/hud/hud.gd (modified)
- game/src/ui/hud/hud.tscn (modified)
- game/src/ui/hud/hud_frame.gd (modified)
- game/tests/unit/test_duck_bubble.gd (new) + .uid
- game/tests/unit/test_duck_lines.gd (new) + .uid
- game/tests/unit/test_voice_service.gd (new) + .uid
- game/tests/unit/test_duck_director.gd (new) + .uid
- game/tests/unit/test_duck_isolation.gd (new) + .uid
- game/tests/unit/test_font_coverage.gd (modified)
- game/tests/unit/test_hud_layout.gd (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/3-6-duck-bubble-and-tutorial-beats.md (this story)

### Change Log

- 2026-11-09: Story 3.6 implemented (duck bubble, typewriter, squeak, VoiceService text-only backend, DuckLinesDef T1-T4, DuckDirector beats, HUD duck box removed, tests and isolation guard). Status → review.
- 2026-11-09: Code review (Blind Hunter, Edge Case Hunter, Acceptance Auditor in parallel). Fixed: bubble now redraws when the reveal count is set externally (3.7 voice seam); vacuous squeak test replaced. Deferred (see deferred-work.md): 3.7 stop/finish/ownership seam, strict-order T3/T4 soft-lock, raw `say` validation, layering nits. Dismissed: wrap shadowing (builds and guards clean), T3 frame sampling (register window is held state), T1 not replayed after early death (D-S36-8 by design), test hygiene nits. Sim isolation verified. Status → done.
