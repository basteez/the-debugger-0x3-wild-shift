---
baseline_commit: story/6-7-intro-sequence (stacked on 6.6)
---
# Story 6.8: Ending Sequence

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Judgment calls are marked [design call] with the chosen default (D-S68-n); the implementer follows them or records a change in Completion Notes. Scope: the real Ending screen (one desk panel, the reserved nibble lighting to 0xFF, the commit message beat, duck line 9, credits), the leave gate on Game (advance() ENDING branch no longer resets unconditionally), the stretch clear-time and hits-taken card behind FeatureFlags.ending_summary (CUT FIRST), the ending text as data, the duck line data and its rendered clip, and the tests. NOT in scope: the final audio credits (7.1/7.2 fill them), the game text audit (6.9 counts the duck budget and the fixed lines), the title/ending music track (7.1), the Chrome and Firefox human checks (recorded as pending, not automated), any change to the sim or Register. -->

## Story

As a player who beat Segfault,
I want an ending that completes the register and sends me home,
so that the run closes with a payoff.

**Requirements:** FR45 (line 9), FR51 (the ending, ≤ 30 s; stretch: clear-time and hits-taken summary). Additional: GDD cut ladder #4 (with the Segfault cut, the Ending plays right after Null Pointer and NULL is never dropped), GDD D-039 (duck budget 10; this story brings the count to 10). Window: Nov 22–25 (Epic 6). Depends on: 1.6 (scene flow, `Game` FSM, `PlaceholderScreen` ENDING branch, debug jump to ENDING), 2.x/3.x (`Register.byte_value`, HUD), 3.7 (`VoiceService.say`, `VoiceService.stop`, pre-rendered clips, `tools/render_duck_lines.gd`), 3.8 (`Game.finish_defeat` route to ENDING, `HarvestScreen` as the pattern for a dedicated screen), 5.6 (`Game.route_after_defeat` sends the last fight to ENDING; `FeatureFlags.segfault` cut), 6.6 (`FeatureFlags` cut-ladder pattern, `reserved` nibble tell), 6.7 (`IntroScreen` as the pattern for a sim-frame timeline screen with a skip gate, `intro_handover` line, duck-only HUD, `DuckBubble` clear on `from == INTRO`).

## Acceptance Criteria

**Entry and screen**

1. **Given** the last fight is defeated (Segfault, or Null Pointer with cut #4) and its defeat animation ends, **When** `Game.finish_defeat` routes it, **Then** the flow goes to ENDING through the existing `route_after_defeat` (no change to the route, no bit is dropped). `Game` records `ending_start_frame = SimClock.sim_frame` when ENDING is entered.
2. **And** `Main._make_screen` builds the new `EndingScreen` (`class_name EndingScreen`, `game/src/ui/screens/ending/ending_screen.gd`, `name = &"EndingScreen"`) for ENDING. `PlaceholderScreen` no longer serves ENDING: its ENDING row and branch are removed and its class doc is updated. After this story `PlaceholderScreen` serves FIGHT only.
3. **And** the HUD is shown in ENDING in duck-only mode (`hud.visible` true, `hud.set_duck_only(true)`), so the duck bubble carries line 9. The arena stays hidden (`arena.visible` false). No boss and no register HUD are drawn.

**Timeline (sim frames since `ending_start_frame`, 60 Hz)**

4. **Given** ENDING, **When** the sim advances, **Then** the beats play in this order: (a) frames 0–29: the desk panel fades in (the developer back at the desk, the duck on the desk); (b) frames 30, 45, 60, 75: the four cells of the `reserved` nibble light one at a time, and from frame 75 the screen shows `0xFF`; (c) frames 90–299: the commit beat, `fix: wild shift` typed at 20 characters per second by `TypewriterReveal`; (d) frame 300: duck line 9 is requested once; (e) credits block visible from frame 360 (or 540 when the summary card is shown, AC 11); (f) the timeline holds at frame 900 (`Game.ENDING_HOLD_FRAMES = 900`, 30 s), the cap of the whole ending.
5. **And** no beat reads a frame past 900, and the ending never times out to TITLE by itself: it holds on the credits until the player leaves it (AC 6).
6. **Given** ENDING, **When** the player presses any key (not a modifier, not Esc, not a function key) or left-clicks, **Then** `Game.finish_ending(frame, true)` moves to TITLE, and only when `Game.can_leave_ending(frame)` is true: frame > `ending_start_frame + 60` (`ENDING_LEAVE_GATE_FRAMES = 60`). The input that ended the last fight never counts. The existing ENDING → TITLE reset (new `RunState`, `first_input_frame = -1`, `intro_start_frame = -1`) runs there and nowhere else.
7. **And** `Game.advance()` in ENDING goes through the same gate (`if can_leave_ending(SimClock.sim_frame): finish_ending(SimClock.sim_frame, true)`). It no longer resets the run unconditionally (same fix as 6.7 AC 7 for INTRO). The debug F-key path (`debug_jump`) is unchanged.
8. **And** ENDING joins `Game.PAUSABLE_STATES` (D-S68-6): Esc pauses it, the timeline freezes, and `finish_ending` refuses while paused (DC4). A focus loss pauses it like the other pausable states.

**Duck line 9 and voice**

9. **Given** frame 300 of ENDING, **When** the timeline reaches it, **Then** `VoiceService.say(&"ending")` is requested once per ending (latched on the screen), and the duck bubble shows "Quack. Works on your machine now." with the voice through the normal path (text silent if the voice is unavailable, FR45). Nothing requests it again, and a leave before frame 300 means it is never requested.
10. **And** `VoiceService.stop()` runs in `EndingScreen._exit_tree`, so leaving the ending (TITLE) never leaves a voice speaking (deferred 3.7 flow-exit item, same as 6.7 B5).
11. **And** the line is data: `game/data/duck/duck_lines.tres` gains the entry `ending` with that exact text, placed after `harvest_shared` (GDD order: line 9 comes after the shared harvest line 8, before the hint template), and `game/data/duck/duck_clips.tres` is re-rendered with `tools/render_duck_lines.gd` so the PRERENDER clip matches (`test_duck_voice_data` green). The diff of `duck_clips.tres` is only the new entry.

**Commit beat, credits and summary**

12. **Given** the commit beat, **When** `fix: wild shift` is typed, **Then** it is drawn as a git-log row (ink only, GlyphFont) with a blinking cursor (presentation only, the blink never affects the timeline).
13. **Given** the credits block, **When** it is visible, **Then** it lists, from the ending text data (AC 16): the font (Wildshift8 by Tiziano Basile), the voice (mumble-speech by basteez, MIT / Apache-2.0), the code licence (MIT), and an audio line that is a placeholder until the final audio sources exist (see Open questions; 7.1/7.2 replace it). The credits fit the 640×360 base without clipping and use only characters in the glyph font.
14. **[STRETCH, first to drop] Given** `FeatureFlags.ending_summary` is on (shipped on), **When** the summary is due (frames 360–539), **Then** a card shows `CLEAR m:ss` and `HITS n` and the credits start at frame 540. Clear time is the sim frames from the first FIGHT entry of the run (Fight 1) to `ending_start_frame`, excluding pause and the Intro, divided by 60 and floored to whole seconds. Hits is the number of landed hits on the player across the whole run, retries included (`Game.on_player_damaged`).
15. **And** the stats live in `Game` (a small stats record that a retry does not restore, unlike `RunState`), are copied into a snapshot on ENDING entry, and are cleared at ENDING → TITLE.
16. **And** a run with any debug jump (F1–F5, DC6) shows no card: `Game` flags `run_debug_jumped` in `debug_jump`, and the credits start at frame 360 for such a run. Its time and hits are not shown because the run is not a clear.
17. **And** with `FeatureFlags.ending_summary = false` there is no card and no stats record is drawn; the credits start at 360 and the ending timeline is otherwise identical. Cutting the card = set the flag off and delete the card code and its test; the ending still passes AC 1–13 and 15–16 without it.

**Text, colour and sim rules**

18. **And** all game text of the ending (the commit message, the credit lines, the captions "the next morning" and "0xFF", the prompt "press any key") lives in `game/data/ending/ending_text.tres` (a new `EndingText` resource with a `validate()` method, `game/src/ui/screens/ending/ending_text.gd`). No game text is a string literal in `ending_screen.gd` (6.9 rule). Debug log lines are excluded.
19. **And** the ending is ink only. Red `#FF4040` stays reserved for warnings (Breakpoint, SIGSEGV); the lit nibble uses `Palette.INK`.
20. **And** the ending reads `Game`, `SimClock`, `Register` (`byte_value()` is not used for the nibble: the `0xFF` is a presentation constant of the ending, D-S68-9) and `Defs`. It never writes flow state, the register, the arena, the boss or the player, and adds no input to the sim input buffer. The sim does not read the ending. Guards (`game/tools/check_guards.sh`) pass.

## Tasks / Subtasks

### Group A: Data and duck line (AC: 9, 11, 13, 18)
- [x] A1. Add `ending` to `game/data/duck/duck_lines.tres` (`DuckLineDef`, text exactly as AC 9), after `harvest_shared`.
- [x] A2. Create `game/data/ending/ending_text.tres` (`EndingText`, `game/src/ui/screens/ending/ending_text.gd`, `extends Def`, with `validate()` returning the empty array when the commit message is non-empty and at least one credit line exists): `commit_message = "fix: wild shift"`, the captions, the prompt, the credit lines (AC 13). Add it to the data validation test the same way the other `Def` resources are covered (`test_data_validation`).
- [x] A3. Re-render the clips: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/render_duck_lines.gd` (run from the worktree root; Godot is not on PATH). The known "Failed to compile depended scripts" line is harmless (deferred 3.7). Confirm `data/duck/duck_clips.tres` now has `ending` and only that entry is new.
- [x] A4. Update `tests/unit/test_duck_lines.gd`: entries 13 → 14, the GDD table check includes line 9, `budget_count` 9 → 10 (D-039 budget of 10 is now full; the 6.9 audit must not exceed it). Update `tests/unit/test_duck_bubble.gd` and `test_duck_director.gd` where they index the list by position (6.7 shifted the list by one; check again).

### Group B: Ending screen (AC: 4, 5, 9, 10, 12, 13, 19, 20)
- [x] B1. Create `game/src/ui/screens/ending/ending_screen.gd` (`class_name EndingScreen`, `extends Node2D`) with the static pure helpers: `beat_at(frames: int) -> int` (the beat index of the timeline above), `nibble_cells_lit(frames: int) -> int` (0 to 4), `typed_chars(frames: int) -> int` (the commit beat, via `TypewriterReveal.visible_chars`), `credits_start_frame(summary_on: bool) -> int`, `summary_visible(frames, summary_flag, debug_jumped) -> bool`, `format_clear(frames: int) -> String` (`m:ss`, floored).
- [x] B2. `_physics_process`: `Game.finish_ending(SimClock.sim_frame)` is not called from the poll (the hold is the end of the ending, not a cap); the poll only latches the duck line at frame 300 and logs the beat changes (`Log.info(&"flow", ...)` once per beat, no log per frame). The presentation frame counter drives only the blink and the typewriter reveal, never the beat.
- [x] B3. `_unhandled_input`: a skip event (any key not a modifier, not Esc, not an F-key; or a left click) when `Game.can_leave_ending(SimClock.sim_frame)` → `set_input_as_handled()`, then `Game.finish_ending(SimClock.sim_frame, true)`. Pressing during pause does nothing (`finish_ending` refuses). Reuse `PlaceholderScreen.is_advance` and `IntroScreen.skip_allowed`'s rule (`is_advance` and not `Game.is_pause_press`), do not weaken it.
- [x] B4. `_exit_tree`: `VoiceService.stop()`.
- [x] B5. Draw: the desk panel (a simple `draw_rect` backing in `Palette.BG`, the developer and the duck as GlyphFont glyphs in `Palette.INK`, centred on the 8-px grid), the nibble cells (4 cells in the register's reserved nibble position, lit cells drawn filled), the `0xFF` caption, the commit row, the summary card (B7) and the credits block. Text comes from `EndingText` only (AC 18).
- [x] B6. Duck line request at frame 300: `VoiceService.say(&"ending")`, latched once. Null-safe with no `Game` autoload state; the request goes through the HUD bubble the same way the Intro does (`EventBus.duck_line_requested`, see 6.7 C2 note).
- [x] B7. [STRETCH, cut first] Summary card: reads the snapshot `Game.ending_summary` (AC 14–17) and draws `CLEAR` and `HITS` lines through `format_clear` and the hit count. Behind `FeatureFlags.ending_summary`: when the flag is off the card and its draw code are never reached.

### Group C: Game and wiring (AC: 1, 2, 3, 6, 7, 8, 14, 15, 16, 17)
- [x] C1. `game/src/autoloads/game.gd`: `const ENDING_HOLD_FRAMES := 900`, `const ENDING_LEAVE_GATE_FRAMES := 60`; `var ending_start_frame := -1`; `can_leave_ending(frame) -> bool` (pure: frame > ending_start_frame + gate, and ENDING); `finish_ending(frame, skip_requested) -> bool` (refuses while paused or not in ENDING or before the gate; else the existing ENDING → TITLE reset and `_set_flow_state(TITLE)`); `advance()` ENDING branch goes through the gate (AC 7).
- [x] C2. `PAUSABLE_STATES` gains `ENDING` (AC 8). Check the focus-loss pause path still behaves for INTRO and FIGHT (`_set_flow_state` line `if _focus_lost and to in PAUSABLE_STATES`).
- [x] C3. Stats (AC 14–16): `Game` keeps `ending_stats` (fight-1 start frame, hit count, `run_debug_jumped` flag). The fight-1 start frame is set on the first FIGHT entry of a run (not on retries); `on_player_damaged` increments the hit count (every landed hit, the lethal one included); `debug_jump` sets `run_debug_jumped`. `_set_flow_state(ENDING)` copies a snapshot (`ending_summary = {clear_frames, hits, debug_jumped}`) and the ENDING → TITLE reset clears it. Feature flag `FeatureFlags.ending_summary` (default true in `data/config/feature_flags.tres`, wired like the other cut flags, AD-12) is read once at startup by the wiring code, never inside the sim.
- [x] C4. `game/src/main/main.gd` `_make_screen`: `ENDING` → `EndingScreen.new()` (with `name = &"EndingScreen"`); `FIGHT` stays on `PlaceholderScreen`. `apply_flow_state`: `hud.visible = in_fight or harvest or intro or ending`, `hud.set_duck_only(harvest or intro or ending)`; `arena.visible` stays `in_fight`.
- [x] C5. `game/src/ui/screens/placeholder/placeholder_screen.gd`: remove the ENDING row in `lines_for`, the ENDING handling in `_unhandled_input` and `_physics_process` and the class doc mention of 6.8. Keep FIGHT byte-identical.

### Group D: Tests (AC: all)
- [x] D1. `tests/unit/test_ending_screen.gd` (new, GUT): `beat_at` boundaries (0, 29, 30, 75, 90, 299, 300, 360, 539, 540, 900); `nibble_cells_lit` (0 at 29, 1 at 30, 2 at 45, 3 at 60, 4 at 75); `typed_chars` reaches 15 and stops; `format_clear` (0 → `0:00`, 59 → `0:00`, 60 → `0:01`, 3599 → `0:59`, 215940 frames → `59:59`); `summary_visible` (flag on, not debug → true; flag off → false; debug jump → false); skip rule (modifiers, Esc, F-keys, echo, key-up rejected; left click accepted); no beat past 900.
- [x] D2. `tests/unit/test_game_flow.gd`: `can_leave_ending` false at `ending_start_frame + 60`, true at +61; `finish_ending` refuses on the defeat frame, refuses while paused, and resets the run on success; `advance()` in ENDING does not reset before the gate; ENDING is pausable and a paused ending neither leaves nor advances; the stats snapshot is taken on ENDING entry and survives a retry of the fight before it.
- [x] D3. `tests/unit/test_duck_lines.gd` (A4) and `test_duck_voice_data.gd` (the `ending` clip present and matching).
- [x] D4. Integration `tests/integration/test_ending_flow.gd` (new): Fight 3 (Segfault, `segfault` flag on) defeated → ENDING with the arena hidden and the HUD duck-only → the line requested once at frame 300 and not before → leave after the gate → TITLE with a fresh run. Closes the deferred 5.6 "Main-level ENDING route after Fight 3" item. Second case: the Null Pointer as the last fight with `FeatureFlags.segfault` off goes to ENDING and plays the same beats (cut #4 path).
- [x] D5. Flag and debug paths: `ending_summary` off → no card, credits at 360; a run with a debug jump → no card; both through the real `Main` flow.
- [x] D6. `test_font_coverage.gd`: every character used in `ending_text.tres` (commit message, captions, credit lines, prompt) is in the glyph font.
- [x] D7. Update the brittle tests that assumed a `PlaceholderScreen` in ENDING (`test_main_layers.gd`, `test_placeholder_fight_keys.gd`, `test_placeholder_screen.gd` if present; deferred "PlaceholderScreen assertion (breaks in Story 6.8)").
- [x] D8. Run the full GUT suite and `bash game/tools/check_guards.sh` from the worktree root. Test the flag-on and flag-off configurations (the shipped config is flag-on).

### Group S: Stretch summary (AC: 14–17). CUT FIRST
- [x] S1. Implement B7, C3 (stats part) and the D5 flag/debug cases. If the schedule slips, set `FeatureFlags.ending_summary` to false, remove the card code and its tests, and note the cut in Completion Notes. The ending must pass without it (AC 17).

### Group E: Human checks (recorded, not automated)
- [ ] E1. Chrome (and Firefox/Safari when available): the Segfault defeat leads to the desk panel; the nibble lights to `0xFF`; `fix: wild shift` types; the duck line plays on the MUMBLE backend at frame 300; the whole ending is ≤ 30 s; the credits read at the 640×360 base; Esc pauses and freezes the timeline; a key after 1 s returns to TITLE. Record the result in Completion Notes; do not fake it in a test.

## Dev Notes

### Design context (what 6.8 must respect)

- GDD Ending row: the reserved nibble lights `1111`; the developer is back at the desk; the duck sits on the desk; the commit message reads `fix: wild shift`; duck line 9; credits; ≤ 30 s. The Ending is one panel (GDD Asset table: Intro / ending panels 3 + 1).
- GDD Duck row 9: "Quack. Works on your machine now." (exact text).
- GDD Level Progression: Intro → Infinite Loop → Null Pointer → Segfault → Ending. With the Segfault cut (ladder #4) the Ending plays right after Null Pointer and NULL is never dropped (already routed by `route_after_defeat`, Story 5.6).
- GDD Licences: CC0 preferred; CC-BY accepted with credits; credits go in the README and on the itch.io page. The in-game credits mirror the README Credits section (font, audio, mumble-speech).
- GDD stretch: a clear-time and hits-taken summary on the ending screen (Replay value). This is the first-to-drop item in sprint-status.yaml.
- Tone: deadpan. The commit message and the line are the joke; no extra text.

### Current state of the code (read before editing)

- `game/src/autoloads/game.gd`: `FlowState` enum (TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING); `route_after_defeat(index, segfault_on)` sends the last fight to ENDING; `advance()` ENDING branch is currently an unconditional `run = RunState.new()`, `first_input_frame = -1`, `intro_start_frame = -1`, `_set_flow_state(TITLE)`. It must be gated (AC 7). `PAUSABLE_STATES = [INTRO, FIGHT]` today. `debug_jump` allows ENDING (F-keys). `_set_flow_state` sets `harvest_start_frame`, runs `_begin_fight` on FIGHT, emits `flow_state_changed`.
- `game/src/ui/screens/placeholder/placeholder_screen.gd`: ENDING row `["ENDING", PROMPT_TEXT]` (`PROMPT_TEXT = "press any key"`) and the ENDING advance; to be removed for ENDING only.
- `game/src/main/main.gd`: `_make_screen` sends `FIGHT, ENDING` to `PlaceholderScreen` (line ~406); `apply_flow_state` shows the HUD for `in_fight or harvest or intro`, duck-only for harvest and intro. The ENDING needs both the HUD and duck-only mode for its bubble (the HUD is the only place the bubble lives).
- `game/src/ui/screens/intro/intro_screen.gd` (6.7): the pattern to mirror: pure static helpers, a Callable seam for the squeak and the voice, `poll` for the latches, `try_skip` for the gated skip, `_exit_tree` for `VoiceService.stop()`.
- `game/src/ui/duck/typewriter_reveal.gd`: `TypewriterReveal` (`set_line`, `advance`, `visible_chars`, `is_done`) for the commit beat.
- `game/src/register/register.gd`: `MAX_BITS = 4` owned bits fill the low nibble (`0x0F`); the high nibble is reserved. `byte_value()` is owned-only. The ending lights the reserved nibble as a presentation of the ending only (D-S68-9); the sim register is not changed.
- `game/src/core/feature_flags.gd`: cut-ladder bools (`reserved_write`, `watch`, `breakpoint_enabled`, `segfault`), read once at startup by the wiring code. `ending_summary` joins them (C3).
- `game/data/duck/duck_lines.tres`: 13 entries after 6.7 (`intro_handover` first; then t1–t4, `harvest_shared`, five hint windows, `n1_breakpoint`, `n2_hold_r`). `ending` goes between `harvest_shared` and the hint entries.
- `game/data/text/`: exists as an empty folder (6.9 creates the shared text files). Ending text lives in `data/ending/ending_text.tres` (A2); do not create `data/text/fixed_lines.tres` here (6.9 owns it).
- `README.md` Credits section lists mumble-speech (MIT / Apache-2.0) and GUT (MIT); the font licence file is `game/assets/fonts/wildshift8-LICENSE.txt` (author Tiziano Basile).
- Still to verify in code: whether `SimClock.sim_frame` advances while the flow is DEAD (affects clear time; D-S68-4 counts whatever the sim counts), and that `_set_flow_state` for ENDING does not start a fight.

### Design calls (D-S68-n)

- **D-S68-1 [design call] One screen, one timeline.** The ending is one `Node2D` screen on a 900-frame timeline (AC 4), not a scene sequence. The hold at 900 is the end of the ending (30 s); the ending waits there for the player and never times out to TITLE by itself (AC 5).
- **D-S68-2 [design call] Commit beat typed with the existing `TypewriterReveal`.** 20 characters per second, 15 characters: about 0.75 s. No new text-reveal code.
- **D-S68-3 [design call] The summary is stretch behind a feature flag.** `FeatureFlags.ending_summary`, shipped on, cut first. It follows the AD-12 cut-ladder pattern so it can be dropped without touching the ending.
- **D-S68-4 [design call] Clear time and hits definition.** Clear time = sim frames from the first FIGHT entry of the run (Fight 1) to the ENDING entry, pause excluded (sim frames freeze while paused), Intro excluded (it is skippable and not gameplay), harvests and deaths included. Hits = every landed hit on the player across the whole run, retries included, so the card reflects the effort of the run, not the last attempt.
- **D-S68-5 [design call] Debug-jumped runs show no card.** A run that used F-key jumps is not a clear; the card is hidden (AC 16).
- **D-S68-6 [design call] ENDING is pausable.** Esc pauses it and the timeline freezes, consistent with INTRO and FIGHT. This is the only change to `PAUSABLE_STATES`.
- **D-S68-7 [design call] Leave gate of 60 frames, then any key returns to TITLE.** The input that ended the last fight cannot leave the ending (AC 6), the same rule as the Intro title input (6.7 AC 5). Skip and leave are the same action. The credits are readable: the screen holds until the player leaves.
- **D-S68-8 [design call] Ending text is data.** `data/ending/ending_text.tres` holds the commit message, the captions, the prompt and the credit lines, so the 6.9 audit can check them without reading scripts (AC 18). This is a new resource, not a `data/text/` file, to keep 6.9's files untouched.
- **D-S68-9 [design call] The `0xFF` is a presentation constant.** The reserved nibble lighting is drawn by the screen; the sim register is not changed (no new bit, no reserved write at the ending). This keeps the register invariants of 6.6 intact (AC 20).
- **D-S68-10 [design call] Credits are one static block, not a scroll.** The GDD says "credits" with no motion spec; a static block reads better at 640×360 and needs no timing data. Revisit only if the 7.8 playtest says the block is too dense.

### Architecture and rules that bind this story

- AD-08: only `Game` writes `flow_state`; screens call `Game.finish_ending` and never set state.
- AD-05 / presentation rule: the screen reads `Game`, `SimClock`, `Register` and `Defs`, never writes sim state. The sim does not read the ending.
- AD-12: cut-ladder flags are read once at startup by the wiring code, never inside the sim; a module that is off is never constructed.
- DC4: nothing moves while paused; the timeline uses sim frames (`SimClock.sim_frame`) since `Game.ending_start_frame`.
- D-039: the duck budget is 10 (the hint template counts once). This story takes it to 10 (AC 11); the 6.9 audit must not exceed it.
- Guards (`game/tools/check_guards.sh`): the presentation folder must not write `flow_state`; the ending must not call `SimClock.tick` or input-buffer APIs. Run the guard after the change.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style used in 6.6 and 6.7.

### Previous story intelligence

- 6.7 (done): `IntroScreen` is the template (pure helpers, Callable seams for audio and voice, sim-frame timeline, gated skip through `Game`, `VoiceService.stop()` in `_exit_tree`, duck-only HUD, `DuckBubble` clear on `from == INTRO`). The ENDING needs the same bubble clear: check `DuckBubble._on_flow_state_changed` clears on FIGHT → ENDING and on ENDING → TITLE; add `from == ENDING` if it does not.
- 6.7 also showed the duck line list shifts when a line is inserted in the middle: tests that assume an index break. Re-check `test_duck_bubble.gd` and `test_duck_director.gd` for position-based assumptions.
- 6.6 (done): `FeatureFlags` cut-ladder pattern (`reserved_write`); the `reserved` nibble tell is the visual language the ending reuses for `0xFF`; Dev Agent Record format is the model.
- 5.6 (done): `route_after_defeat` and `drops_bit` with `segfault_enabled`; the Null Pointer last-fight route is already in place and tested in `test_harvest_flow`.
- 3.8 (done): `HarvestScreen` shows the bubble on entry with `set_duck_only(true)`; the ending requests at frame 300, long after entry, so no defer is needed (note in Completion Notes if the bubble clears later).
- 3.7 (done): every changed duck line needs `render_duck_lines.gd`; `test_duck_voice_data.gd` fails when a clip does not match. Easy to forget: run A3.
- 1.6 (done): `PlaceholderScreen` ENDING row and the ENDING debug-jump path; `Game.advance()` ENDING branch is the code this story gates.

### Deferred work relevant to 6.8 (from `_bmad-output/implementation-artifacts/deferred-work.md`)

- **Closed here:** "Main-level ENDING route after Fight 3 stays open until the Segfault fight exists, Epic 6" (5.6 test gap; D4 covers it).
- **Closed here:** "Brittle tests: ... PlaceholderScreen assertion (breaks in Story 6.8)" (D7).
- **Closed here if reached:** 3.7 "call `VoiceService.stop()` on flow exit" for the ENDING exit (B4).
- **New, to record in deferred-work.md on completion:** `Game.advance()` ENDING branch reset was unconditional (fixed by C1/AC 7, same pattern as the INTRO fix in 6.7).
- **Left open:** 1.5 H2 "Confirm the CC0 licence of the self-authored pixel font" (credits line wording in AC 13 must match the answer; the line uses the author name only until then).
- **Left open:** 3.7 "`duck_clips.tres` sub-resource ids were regenerated by an editor resave" (A3 rewrites the file; check the diff is only the new entry).

### Git intelligence

- Branch `story/6-8-ending-sequence` stacked on 6.1–6.7 (last: `f35833d Story 6.7: Intro sequence`). Story pattern: data, pure logic as static helpers, the screen as a presentation node, `Main` as the only wiring point, tests per AC, guard run.

### Latest technical information

- Godot 4.7.2-stable (pinned; do not upgrade), GUT 9.6.1, GDScript 2 only. `Node2D` `_draw` with `GlyphFont.draw_at` as the placeholder and the Intro do. No new APIs or external libraries: the ending uses only existing autoloads (`Game`, `SimClock`, `VoiceService`, `EventBus`, `Log`), `Register` (read-only), `Palette`, `GlyphFont`, `TypewriterReveal`, `Defs`.

### Project Context Rules

- Read-only defs at runtime; per-screen state (the beat latches, the blink, the typewriter) lives on the screen and is freed with it (the screen is replaced on every flow change, `apply_flow_state`).
- Integer sim state; floats for presentation only (D-S33-2). The blink and the typewriter are presentation.
- Red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV). The ending is ink only.
- No game text as a string literal in scripts (6.9 rule): all text comes from `ending_text.tres` and `duck_lines.tres`.

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (Godot is not on PATH; use the full path). Run it from the worktree root.
- Guards: `bash game/tools/check_guards.sh` from the worktree root.
- Use the GDD numbers as cases: the timeline beats (300 for the line, 900 for the hold), the nibble cells (4), the leave gate (60 frames), the duck count (14 entries, budget 10), the commit text (15 characters).
- The Chrome check (timeline, nibble, commit beat, duck voice, pause, leave) is a human check; record it in Completion Notes as pending, do not fake it in a test.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.8: Ending Sequence] (ACs, FR45 line 9, FR51)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.9: Game Text Audit] (duck budget and text rules the ending must respect)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] (Ending row in the screens table; Duck table row 9; Level Progression; Licences; Asset table ending panel; cut ladder #4; the stretch summary in Replay value)
- [Source: _bmad-output/implementation-artifacts/6-7-intro-sequence.md] (IntroScreen pattern, the skip gate, duck-only HUD, `VoiceService.stop()` on exit)
- [Source: _bmad-output/implementation-artifacts/5-6-null-pointer-tutorials-defeat-and-null-harvest.md] (route to ENDING with segfault cut; NULL never dropped)
- [Source: _bmad-output/implementation-artifacts/3-8-boss-defeat-and-harvest.md] (finish_defeat route, duck-only HUD pattern)
- [Source: _bmad-output/implementation-artifacts/3-7-duck-voice-mumble-speech.md] (render tool, clip matching, `VoiceService.say` and `stop`)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (items listed above)

## Open questions (not blocking)

- Audio credits: the final sources for SFX and music are not chosen (7.1, 7.2). The credits block carries a placeholder audio line until then; 7.9 must replace it before submission. Who gets credited is a designer decision (GDD Licences: CC0 preferred, CC-BY needs credit).
- Font licence: the CC0 confirmation for Wildshift8 is still open (deferred 1.5 H2); the credits line names the author only until it is closed.
- Whether the summary should count the Intro in clear time (D-S68-4 says no). Revisit if the 7.8 playtest reads the clear time as too short or too long.
- Whether the ending should auto-return to TITLE after the hold (D-S68-7 says no, the player leaves). Decide after the Chrome check (E1).
- Whether the reserved-nibble lighting should be shown in the real register HUD instead of a presentation of the ending (D-S68-9 says presentation only, no sim change).

## Dev Agent Record

### Agent Model Used

Claude Opus (gds-dev-story, unattended pipeline, 2026-11-12).

### Debug Log References

- Full GUT suite (unit + integration + replay, CI command): 1572/1572 passed, `---- All tests passed! ----`, no failure markers. Same result with `ending_summary = false` in `feature_flags.tres` (flag-off configuration; reverted to the shipped `true`).
- `bash game/tools/check_guards.sh`: OK.
- `render_duck_lines.gd` (wav, `--import`, tres): only `ending.wav` is new (the other WAVs are byte-identical). The tool re-saves `duck_clips.tres` with renumbered sub-resource ids, so the generated `ending` clip (same `char_times`) was spliced into the committed file by hand: the diff is only the new entry (A3).
- The first `ScreenFX` instance in a process reports a headless shader engine error; `test_ending_flow.gd` absorbs it in `before_all` (its tests build Main inside the test, not in `before_each`).

### Completion Notes List

- Ending implemented as specified: `EndingScreen` (pure static timeline helpers, line latch at 300, gated leave, `VoiceService.stop()` on exit), `EndingText` data resource, duck line 9, `Game` leave gate / `finish_ending` / ENDING pausable / run stats, `Main` wiring (duck-only HUD, flag read at screen build), `PlaceholderScreen` FIGHT only.
- Coordinator decisions applied: GDD checked (Ending row, Duck row 9, `0xFF` at the ending) and agrees with the story; clear time excludes the Intro and pauses; ENDING never auto-returns to TITLE; audio credit stays the placeholder `audio: TBD`; the stretch summary is fully behind `FeatureFlags.ending_summary` and the suite passes with it off.
- Stats live in a new `RunStats` record (`src/core/run_stats.gd`, `Game.stats`), not in `RunState`: a retry never touches it. It is reset on title start, ENDING -> TITLE and a debug jump to TITLE. Hits count only while FIGHT.
- [design call] D-S68-11: the commit row is `c0ffee1 fix: wild shift` (hash shown at once, message typed, `_` cursor blinking every 30 presentation frames); the desk art is two glyph rows (`@` developer, `>o` duck, a `=` desk); the caption is "the next morning". All in `ending_text.tres` for the 6.9 audit.
- [design call] D-S68-12: the summary card appears at 360 and stays on screen with the credits (it is not removed at 540); the credits still start at 540 when the card is shown. Lit reserved cells are drawn inverted (INK cell, BG glyph), the RegisterPanel style; the owned nibble is drawn full (`0xFF` is a presentation constant, D-S68-9, also on the cut #4 path).
- [design call] D-S68-14 (coordinator): clear time is the sim-frame clock (`SimClock.sim_frame`), so hit-stop and Breakpoint frames are excluded along with pause; D-S68-11..13 accepted.
- [design call] D-S68-13: the F8 debug bit grant also flags the run as debug-jumped (no card), like F1-F5.
- `EndingScreen._exit_tree` stops the voice unless the flow is FIGHT (a debug jump into a fight may start its own line that frame; same review finding as 6.7).
- `PlaceholderScreen` keeps an empty `_unhandled_input` (documented) so FIGHT never consumes input; `PROMPT_TEXT` and the ENDING row/advance are removed.
- Story D1 lists `format_clear(3599) -> 59:59`; `format_clear` takes sim frames (AC 14), so 3599 frames is `0:59` and `59:59` is tested at 215940 frames.
- DuckBubble already clears on FIGHT -> ENDING and ENDING -> TITLE (`to != FIGHT`); no change needed. Line 9 is requested at frame 300, long after the entry clear.
- E1 (Chrome / Firefox human check) is pending, not automated; recorded in deferred-work.md.

### File List

- game/src/ui/screens/ending/ending_screen.gd (new)
- game/src/ui/screens/ending/ending_text.gd (new)
- game/src/core/run_stats.gd (new)
- game/data/ending/ending_text.tres (new)
- game/assets/audio/duck/ending.wav (new)
- game/assets/audio/duck/ending.wav.import (new)
- *.gd.uid files Godot generated for the new scripts and tests (ending_screen, ending_text, run_stats, test_ending_screen, test_ending_flow) (new)
- game/data/duck/duck_lines.tres
- game/data/duck/duck_clips.tres
- game/data/config/feature_flags.tres
- game/src/core/feature_flags.gd
- game/src/autoloads/game.gd
- game/src/main/main.gd
- game/src/ui/screens/placeholder/placeholder_screen.gd
- game/tests/unit/test_ending_screen.gd (new)
- game/tests/integration/test_ending_flow.gd (new)
- game/tests/unit/test_game_flow.gd
- game/tests/unit/test_pause.gd
- game/tests/unit/test_duck_lines.gd
- game/tests/unit/test_duck_bubble.gd
- game/tests/unit/test_main_layers.gd
- game/tests/unit/test_font_coverage.gd
- game/tests/integration/test_harvest_flow.gd
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/6-8-ending-sequence.md

### Change Log

- 2026-11-12: Story 6.8 implemented (Ending screen, duck line 9, leave gate, ENDING pausable, stretch clear-time/hits card behind `FeatureFlags.ending_summary`). Status -> review.
- 2026-11-12: Code review (3 layers) done; bubble clears on from == ENDING; D-S68-11..14 accepted; D1 amended. Status -> done.
