---
baseline_commit: story/6-7-intro-sequence (stacked on 6.6)
---
# Story 6.7: Intro Sequence

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Judgment calls are marked [design call] with the chosen default (D-S67-n); the implementer follows them or records a change in Completion Notes. Scope: the real Intro screen (three glyph panels, ≤ 8 s, skippable from its first frame), its duck line 1 (the hand-over), the squeak on panel 2, the skip gate on Game.advance, the flow wiring in Main, the duck line data and its rendered clip, and the tests. NOT in scope: the title/intro music track (7.1, no music is played here), final glyph art and SFX (7.x), the Ending (6.8), the game text audit (6.9, which counts the duck budget), the Chrome and Firefox human checks (recorded as pending, not automated). -->

## Story

As a new player,
I want a quick comic intro that drops me into the fight,
so that I get the premise in seconds and start playing.

**Requirements:** FR45 (line 1: the duck's intro line), FR48 (Intro panels, ≤ 8 s, skippable). Additional: NFR10 (first shift within 30 s of the first title input, intro included), D-040 (Intro ≤ 8 s, skippable from its first frame, the title input never counts as a skip), D-048 (any other key or click on the title starts the run and leads straight into the Intro). Window: Nov 22–25 (Epic 6). Depends on: 1.4 (title, audio unlock), 1.6 (scene flow, `Game` FSM, `PlaceholderScreen` INTRO branch, `INTRO_MAX_FRAMES`), 1.7 (pause in INTRO, `PAUSABLE_STATES`), 3.6 (`DuckBubble`, squeak), 3.7 (`VoiceService.say`, pre-rendered clips), 3.8 (`HarvestScreen` as the pattern for a non-placeholder screen, duck-only HUD). The Intro does not depend on any boss story.

## Acceptance Criteria

**Panels and timing**

1. **Given** the title input (`Game.start_run_from_title`), **When** `INTRO` starts, **Then** three glyph panels play in order, each `PANEL_FRAMES = 150` sim frames (2.5 s at 60 Hz): panel 1 the developer at a desk at 2 a.m.; panel 2 squeezing the duck, which quacks; panel 3 the screen tearing into glyphs and landing in The Clearing. Panels are driven by sim frames since `Game.intro_start_frame`, so a pause freezes them.
2. **And** the Intro never lasts longer than `Game.INTRO_MAX_FRAMES` (480 sim frames, 8 s): after panel 3 (frame 450) it holds 30 frames, then `Game.finish_intro` moves to FIGHT 1 through the existing cap. The constant and its test (`test_game_flow`: 480, timed out at 580 from a start of 100) stay unchanged.
3. **And** the Intro draws no HUD frame, no arena and no boss: the arena stays hidden (`arena.visible` false in INTRO). The only HUD element shown is the duck bubble (AC 6).
4. **And** on entry to INTRO the screen plays no music. Audio stays on the existing unlocked path (the title input unlocks audio, D-048); no track is started (7.1 owns the title/intro track).

**Skip**

5. **Given** INTRO, **When** the player presses any key (not a modifier, not Esc, not a function key) or left-clicks from the first frame on, **Then** `Game.finish_intro(frame, true)` moves to FIGHT 1 at once, and the duck bubble and any voice still speaking are cut (`VoiceService.stop()`, the bubble clears on the flow change). The title input that started the Intro never counts: `Game.can_skip_intro(frame)` is false on the frame of `first_input_frame`, and a test proves an input on that frame does not skip.
6. **And** Esc and P are not skips: Esc / P toggle the pause in INTRO (1.7, `Game.handle_pause_input`), and a paused Intro never advances, skips or times out (`finish_intro` refuses while paused, DC4).
7. **And** `Game.advance()` in INTRO no longer starts Fight 1 on its own: it routes through the same skip gate as the screen (`can_skip_intro` plus `finish_intro(frame, true)`), so no caller can skip the Intro on the title frame. This closes the deferred 1.6 item "`Game.advance()` in INTRO ignores `can_skip_intro`".

**Duck line 1 and sound**

8. **Given** panel 3 starts (frame 300 of INTRO), **When** the duck hands over ATTACK and DASH, **Then** the duck bubble shows and speaks `intro_handover` once per run: "Quack. Explain the bug to me. Use these." (GDD Duck row 1, the voice through `VoiceService.say`, text silent if the voice is unavailable, FR45). It is requested once per Intro, never again on a retry, and a skip before frame 300 means it is never requested. A skip during the line cuts it.
9. **And** the duck squeak (`AudioManager.play_squeak()`) plays once at the start of panel 2, the "quack" of the squeeze. No other SFX is added (7.2 owns the final pass).
10. **And** the line is data: `data/duck/duck_lines.tres` gains the entry `intro_handover` with that exact text, and `data/duck/duck_clips.tres` is re-rendered with `tools/render_duck_lines.gd` so the MUMBLE/PRERENDER clip matches (`test_duck_voice_data` green).

**Flow wiring and the placeholder**

11. **Given** `Main` builds the screen for each flow state, **When** the state is INTRO, **Then** `Main` instances the new `IntroScreen` (`class_name IntroScreen`, `game/src/ui/screens/intro/intro_screen.gd`) instead of `PlaceholderScreen`. `PlaceholderScreen` still serves FIGHT and ENDING (6.8 replaces ENDING); its INTRO rows and INTRO branch are removed, and nothing else changes for FIGHT or ENDING.
12. **And** the Intro is never cut by a feature flag (no `FeatureFlags` entry is added) and it does not change the run's sequence (Intro → Fight 1 → ...).
13. **And** the Intro does not touch sim state: it reads `Game` and `SimClock` only, never writes flow state (only `Game` does, through `finish_intro`), and adds no input to the sim input buffer. Replays that start in FIGHT stay byte-identical.

## Tasks / Subtasks

### Group A: Data and duck line (AC: 8, 10)
- [x] A1. Add `intro_handover` to `game/data/duck/duck_lines.tres` (`DuckLineDef`, text exactly as AC 8). Place it first in `entries` (GDD order: intro is line 1).
- [x] A2. Re-render the clips: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/render_duck_lines.gd` (run from the worktree root; Godot is not on PATH). The known "Failed to compile depended scripts" line is harmless (deferred 3.7). Confirm `data/duck/duck_clips.tres` now has `intro_handover`.
- [x] A3. Update `tests/unit/test_duck_lines.gd`: entries 12 → 13, the GDD table check includes line 1, `budget_count` 8 → 9 (the intro line counts once against D-039's budget of 10). The `HARVEST_TEXT`/`NULL_POINTER_LINES` checks are unchanged.

### Group B: Intro screen (AC: 1, 2, 3, 4, 5, 6, 8, 9, 13)
- [x] B1. Create `game/src/ui/screens/intro/intro_screen.gd` (`class_name IntroScreen`, `extends Node2D`) with the static pure helpers: `panel_at(frames_since_start: int) -> int` (0, 1, 2 for the three panels; -1 past the panels), `hold_started(frames_since_start) -> bool`, `skip_allowed(event) -> bool` (reuse `PlaceholderScreen.is_advance`'s rule, or move it to a shared static, D-S67-4).
- [x] B2. `_physics_process`: `Game.finish_intro(SimClock.sim_frame)` as the placeholder does (the cap). Presentation frame counter drives only the glyph tear animation, never the panel index.
- [x] B3. `_unhandled_input`: on a skip event and `Game.can_skip_intro(SimClock.sim_frame)`, `set_input_as_handled()` then `Game.finish_intro(SimClock.sim_frame, true)`. Pressing during pause does nothing (finish_intro refuses).
- [x] B4. On panel 2 start: `AudioManager.play_squeak()` once (latch in the screen). On panel 3 start: `VoiceService.say(&"intro_handover")`, latched once. Request via the HUD bubble: `DuckBubble` is reached the same way `DuckDirector` gets it (`Main` hands it over; see C2).
- [x] B5. `_exit_tree`: `VoiceService.stop()` so a skip or the cap never leaves a voice speaking into FIGHT (deferred 3.7 item "call `VoiceService.stop()` on flow exit"). Verify `VoiceService.stop()` exists (it does at `voice_service.gd:125`).
- [x] B6. Draw the three panels with `GlyphFont` in `Palette.INK` on `Palette.BG` (the placeholder's `draw_rect` backing pattern), centred on the 8-px grid (640x360 base). Panel captions are data-like constants in the screen (D-S67-3); panel 3's "tear" is a presentation-only row-offset jitter of the caption, cleared when the panel ends.
- [x] B7. Add a per-panel `Log.info(&"flow", ...)` line at each panel change (matches the `fight placeholder opened` style), no log in the physics poll.

### Group C: Wiring (AC: 3, 4, 7, 11, 12)
- [x] C1. `game/src/main/main.gd` `_make_screen`: `INTRO` → `IntroScreen.new()`; keep `FIGHT, ENDING` on `PlaceholderScreen`. `apply_flow_state`: `hud.visible = in_fight or harvest or intro`, `hud.set_duck_only(harvest or intro)`. `arena.visible` stays `in_fight` (false in INTRO).
- [x] C2. Hand the HUD's `duck_bubble` to the intro screen when it is built (the same way `DuckDirector` gets `hud.duck_bubble`), so the Intro line goes through the one bubble. Null-safe: no HUD means the line is skipped silently (tests).
- [x] C3. `game/src/autoloads/game.gd` `advance()`: the `FlowState.INTRO` branch becomes `if can_skip_intro(SimClock.sim_frame): finish_intro(SimClock.sim_frame, true)` (no unconditional start). Update the comment (the placeholder comment "Placeholder advance gesture" stays for FIGHT/ENDING).
- [x] C4. `game/src/ui/screens/placeholder/placeholder_screen.gd`: remove the INTRO row in `lines_for`, the INTRO branch in `_unhandled_input` and `_physics_process`, and the class doc line "Replaced by the real screens in 6.7 (Intro)". Keep the FIGHT and ENDING paths byte-identical.

### Group D: Tests (AC: all)
- [x] D1. `tests/unit/test_intro_screen.gd` (new, GUT): `panel_at` boundaries (0, 149, 150, 299, 300, 449, 450 → -1 at the panel end), the 480-frame total (`panel_at` never past 449; the cap is `INTRO_MAX_FRAMES`), skip rule (modifiers, Esc, F-keys, echo, key-up rejected; left click accepted), the title frame rule (`can_skip_intro(first_input_frame)` false, +1 true).
- [x] D2. `tests/unit/test_game_flow.gd`: `advance()` in INTRO does not start FIGHT before the skip gate; with the gate open it does; the title frame does not skip; a paused Intro neither skips nor times out.
- [x] D3. Integration `tests/integration/test_intro_flow.gd` (new): TITLE → INTRO → skip → FIGHT 1 with the arena visible, and TITLE → INTRO → cap → FIGHT 1 with no skip, both via the real `Main` flow (mirror `test_harvest_flow.gd`). Assert the squeak latch fires once and the `intro_handover` request fires once, at panel 3, and a skip before frame 300 never requests it.
- [x] D4. `test_duck_lines.gd` / `test_duck_voice_data.gd` as in A3 (count 13, budget 9, clip present and matching).
- [x] D5. `test_font_coverage.gd`: every character used in the panel captions is in the glyph font (mirror the existing placeholder coverage check; add the intro captions to its corpus if it has one).
- [x] D6. `test_main_layers.gd` / `test_placeholder_fight_keys.gd`: update any assertion that expected a `PlaceholderScreen` in INTRO.
- [x] D7. Run the full GUT suite and `bash game/tools/check_guards.sh` from the worktree root. Flag-on and debug-off are the only configurations to test.

### Group E: Human checks (recorded, not automated)
- [ ] E1. Chrome (and Firefox/Safari when available): the title press shows the three panels, ≤ 8 s total, Esc pauses and freezes the panels, a key or click skips from the first frame, the duck line speaks on panel 3 on the MUMBLE backend, the squeak on panel 2. Record the result in Completion Notes; do not fake it in a test.

## Dev Notes

### Design context (what 6.7 must respect)

- GDD Intro row: three panels, about 2.5 s each, ≤ 8 s; skippable from its first frame with any key or click; the title input does not skip (D-040, D-048). Panel 3 hands over ATTACK and DASH with duck line 1 (GDD Duck table row 1).
- The Intro is counted in the 30-s first-shift clock (NFR10, GDD Gameplay Metrics): it always lasts its full 8 s unless skipped. Do not shorten it below 8 s when unskipped.
- Tone: deadpan. The line is "Quack. Explain the bug to me. Use these." (exact text, the GDD row; the 6.9 audit checks it).
- Colour: ink only. Red `#FF4040` is reserved for Breakpoint and SIGSEGV (GDD colour rule; same rule as 6.6).

### Current state of the code (read before editing)

- `game/src/autoloads/game.gd`: `FlowState` enum; `INTRO_MAX_FRAMES = 480`; `first_input_frame`, `intro_start_frame`; `start_run_from_title`, `can_skip_intro(frame)` (frame > first_input_frame), `intro_timed_out`, `finish_intro(frame, skip_requested)` (refuses when paused or not INTRO), `advance()` (INTRO branch currently starts FIGHT unconditionally: the deferred item this story fixes); `PAUSABLE_STATES = [INTRO, FIGHT]`.
- `game/src/ui/screens/placeholder/placeholder_screen.gd`: the INTRO placeholder ("INTRO" / "press any key"). It owns the skip rule today: `is_advance(event)` (fresh non-echo key press that is not a modifier, Esc or a function key, or a left-button press), the skip call `Game.finish_intro(frame, true)` after `can_skip_intro`, and the cap poll in `_physics_process`. Reuse these rules; do not weaken them.
- `game/src/main/main.gd`: `_make_screen` (INTRO goes to `PlaceholderScreenScript` with FIGHT and ENDING); `apply_flow_state` (`hud.visible = in_fight or harvest`, `hud.set_duck_only(harvest)`, `arena.visible = in_fight`); `duck_director.bubble = hud.duck_bubble` (line 191) is the pattern for handing over the bubble.
- `game/src/ui/screens/harvest/harvest_screen.gd`: the non-placeholder screen pattern (a `Node2D` with `class_name`, requests its duck line through `VoiceService.say`, `GlyphFont` drawing, skip gate through `Game`). It requests on entry, deferred, because the bubble clears on the flow change; the Intro requests at frame 300, long after entry, so no defer is needed (note in Completion Notes if it proves otherwise).
- `game/src/ui/duck/duck_bubble.gd`: clears itself on `flow_state_changed` (line 263); `say` path via `VoiceService`. `DuckLineDef` ids are the `VoiceService` ids.
- `game/src/ui/duck/duck_director.gd`: polls only in FIGHT (`poll()` returns early outside FIGHT). The Intro line is NOT a DuckDirector beat: it is requested by the Intro screen, so `DuckDirector.DUCK_IDS` and its `requested` mask are unchanged.
- `game/src/autoloads/audio_manager.gd`: `play_squeak()` is public (3.6, D-S36-6, own player). No music API is used here (`crossfade_to` is 7.1).
- `game/src/autoloads/voice_service.gd`: `say(line)`, `stop()` (line 125), `is_speaking()`; backends MUMBLE (live) and PRERENDER (clips in `data/duck/duck_clips.tres`, AUTO fallback).
- `game/data/duck/duck_lines.tres`: 12 entries today (t1–t4, harvest_shared, five hint windows, n1_breakpoint, n2_hold_r). No intro line yet.

### Design calls (D-S67-n)

- **D-S67-1 [design call] Intro duration.** The three panels take 450 frames; the screen holds panel 3 for 30 more frames, then the existing 480-frame cap moves the flow to FIGHT. Keeps `INTRO_MAX_FRAMES` and its test unchanged. Alternative (end at 450, change the cap) rejected: it needs a second constant and test changes for 0.5 s.
- **D-S67-2 [design call] Duck line in the Intro uses the HUD bubble, duck-only.** Reuses `hud.set_duck_only(true)` as HARVEST does (3.8, D-S38-16), so the line is the same bubble, the same voice path and the same clear-on-flow-change. The Intro draws no bubble of its own.
- **D-S67-3 [design call] Panel captions are placeholder text.** Panel 1: `2 a.m.` / `stuck on a bug`. Panel 2: `squeeze` / `QUACK`. Panel 3: the arena's glyph tear over `The Clearing`. Final art is 7.x; the 6.9 audit owns the wording. Captions are constants on the screen, not a data file (no new `.tres`).
- **D-S67-4 [design call] Skip rule is the placeholder's rule, moved to a shared static.** `PlaceholderScreen.is_advance` is kept for FIGHT/ENDING; the Intro calls the same function (or a copy in `IntroScreen` if the move is awkward). Esc and P never skip (they pause, AC 6); F-keys (debug jumps) never skip; modifiers never skip; a left click skips. Keep it that way even though the GDD says "any key": Esc is the pause key and cannot skip.
- **D-S67-5 [design call] Squeak on panel 2, not on the line.** The "quack" in panel 2 is the squeak (`play_squeak`, existing, no new asset). The voice line plays only at panel 3, per the GDD table.
- **D-S67-6 [design call] Intro is always skippable, and a skip cuts the voice.** `VoiceService.stop()` in `_exit_tree` (B5), so any exit from INTRO (skip, cap, debug jump, ENDING-to-TITLE is not reachable from INTRO) silences the duck.
- **D-S67-7 [design call] No retry or resume of the Intro.** The Intro runs only from the title input (and `[N]`/new run, which go through `start_run_from_title`). A continue from the highest boss (D-048) goes straight to FIGHT: `Game.start_run_from_title` is called with a run already started, so this story does not change that path. Confirm in Completion Notes that a continue does not replay the Intro. [Note: if `Game` today always routes title → INTRO, leave it; the GDD's "continue at highest boss" is the save/resume story 7.3.]

### Architecture and rules that bind this story

- AD-08: only `Game` writes `flow_state`; screens call `Game.finish_intro` / `Game.advance` and never set state.
- AD-05 / presentation rule: the screen reads `Game`, `SimClock` and `Defs`, never writes the arena, boss, register or player. The sim does not read the Intro.
- DC4: nothing moves while paused; the cap and the panels use sim frames (`SimClock.sim_frame`).
- D-039: the duck line budget is 10 (the hint template counts once). This story adds one counted line (9 after it); the 6.9 audit must not exceed 10.
- Guards (`game/tools/check_guards.sh`): the presentation folder must not write `flow_state`; the Intro must not call `SimClock.tick` or input-buffer APIs. Run the guard after the change.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style used in 6.6.

### Previous story intelligence

- 6.6 (done): the cut-ladder and presentation-by-method pattern; `PlayerCommand` base; the Chrome human check recorded as pending, not automated. The Dev Agent Record format (Debug Log, Completion Notes, File List, Change Log) is the model for this story's record.
- 6.5 (done): `warning_tell()` pattern and `Hud` presentation through methods; not directly used here.
- 3.8 (done): `HarvestScreen` is the model for a dedicated screen with a duck line, skip gate via `Game`, `hud.set_duck_only(true)`, and `VoiceService.say` deferred on entry. The HUD bubble only ever shows the duck line in HARVEST; INTRO does the same.
- 3.7 (done): every new or changed duck line needs `tools/render_duck_lines.gd` re-run, and `test_duck_voice_data.gd` fails when a clip no longer matches its line. Easy to forget: run it (A2).
- 3.6 (done): `DuckBubble` requires a line id in `DuckLinesDef`; squeak on its own player (never the shift SFX player).
- 1.6 (done): `PlaceholderScreen` INTRO branch and the `Game.finish_intro` cap poll are the code this story replaces.
- 1.4 (done): title press starts the run; audio unlock on the same input. The Intro is only reachable after unlock, so no "play ignored before unlock" warning from the squeak.
- 1.7 (done): `PAUSABLE_STATES` includes INTRO; pause on Esc and focus loss.

### Deferred work relevant to 6.7 (from `_bmad-output/implementation-artifacts/deferred-work.md`)

- **Closed here:** "`Game.advance()` in INTRO ignores `can_skip_intro` (spec Task 2.2 mandates it); revisit with the real Intro (Epic 5)." (AC 7, C3.) Mark it resolved in deferred-work.md when the story is done.
- **Closed here if reached:** 3.7 "voice seam: ... call `VoiceService.stop()` on `clear()`/flow exit" (B5 covers the Intro exit only; the bubble's own clear path is untouched).
- **Left open:** 3.7 "`duck_clips.tres` sub-resource ids were regenerated by an editor resave" (re-render in A2 rewrites the file; check the diff is only the new entry).
- **Left open:** 1.4 "Game.first_input_frame not reset on re-entering TITLE" (ENDING → TITLE already resets it; no change).
- **Left open:** 1.4/1.7 "F9 on the title screen counts as press any key" and the 1.7 "Click is dropped while audio is locked" (not reachable from INTRO: audio is unlocked by the title input).
- **Left open:** 3.6 "N1 (Breakpoint) duck line still plays when breakpoint_enabled is off" (not this story).
- **Left open:** 1.6 "Old and new screen can share a node name within a frame" (the Intro gets `name = &"IntroScreen"`, like `TitleScreen`/`DeadScreen`, so tests can find it; the placeholder's `name` change stays for FIGHT/ENDING).

### Git intelligence

- Branch `story/6-7-intro-sequence` stacked on 6.6 (`b985c37 Story 6.6: Reserved Write`), the 6.5 and 6.4 stories below it. Story pattern: data, pure logic as static helpers, the screen as a presentation node, `Main` as the only wiring point, tests per AC, guard run.

### Latest technical information

- Godot 4.7.2-stable (pinned; do not upgrade), GUT 9.6.1, GDScript 2 only. `Node2D` `_draw` with `GlyphFont.draw_at` as the placeholder does. No new APIs needed; no external libraries (the Intro uses only existing autoloads: `Game`, `SimClock`, `VoiceService`, `AudioManager`, `Palette`, `GlyphFont`, `Log`).

### Project Context Rules

- Read-only defs at runtime; per-screen state (the panel latches, the cut flag) lives on the screen and is freed with it (the screen is replaced on every flow change, `apply_flow_state`).
- Integer sim state; floats for presentation only (D-S33-2). The tear jitter is presentation (float or int offset), never sim.
- Red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV). The Intro is ink only.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (Godot is not on PATH; use the full path). Run it from the worktree root.
- Guards: `bash game/tools/check_guards.sh` from the worktree root.
- Use the GDD numbers as cases: panel 150 frames each, 450 total, cap 480, the skip gate at `first_input_frame + 1`, the duck line at frame 300 once.
- The Chrome check (panel timing, skip, Esc freeze, the duck voice and squeak) is a human check; record it in Completion Notes as pending, do not fake it in a test.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.7: Intro Sequence] (ACs, FR48, FR45 line 1)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.9: Game Text Audit] (exact duck line count of 10 and the intro line as part of the audit)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] (Intro screen row ~497; Duck table rows 1 and 9 ~441–455; Title press-to-start ~262; first-shift metric ~649; colour rule)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md] (D-039 duck budget, D-040 first 30 s and skip, D-048 title and pause)
- [Source: _bmad-output/implementation-artifacts/6-6-reserved-write-cut-ladder-1.md] (Dev Notes and Dev Agent Record format)
- [Source: _bmad-output/implementation-artifacts/3-7-duck-voice-mumble-speech.md] (render tool, clip matching, `VoiceService.say`)
- [Source: _bmad-output/implementation-artifacts/3-8-boss-defeat-and-harvest.md] (HarvestScreen pattern, duck-only HUD)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (items listed above)

## Open questions (not blocking)

- D-S67-7: confirm that no route into INTRO exists other than the title press (the continue-at-highest-boss path, D-048, is a save/resume concern for 7.3). If one exists, it must skip INTRO or the Intro must not play; decide in Completion Notes.
- D-S67-1: whether the 0.5 s hold on panel 3 reads as a freeze in the Chrome check; tune the hold, not the cap.
- D-S67-5: whether the panel 2 squeak alone is enough for "which quacks" or the line should also play on panel 2 (the GDD gives the line to panel 3 only).
- The title/intro music track is 7.1; until then the Intro is silent apart from the squeak and the duck voice (the playtest of 7.8 decides whether silence reads well).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended pipeline.

### Debug Log References

- `render_duck_lines.gd` run twice (`-- wav`, `--import`, `-- tres`) as its header says; the known "Failed to compile depended scripts" line appeared and is harmless. Only `intro_handover.wav` is new; the other 12 wavs are byte-identical. `duck_clips.tres` sub-resource ids shifted by position (content unchanged; deferred 3.7 item stays open).
- First full run: 2 failures in `test_duck_bubble.gd` (index-based wrap table and `_texts()[0]` assumed T1 first); fixed by adding the intro row and looking T1 up by id.
- Final: full headless GUT (unit + integration + replays, CI command and marker checks): 1534/1534 passed, "All tests passed", no failure markers. `bash game/tools/check_guards.sh`: OK.

### Completion Notes List

- IntroScreen (`game/src/ui/screens/intro/intro_screen.gd`): pure helpers `panel_at`, `hold_started`, `display_panel`, `skip_allowed`, `caption_for`, `tear_offset`; `poll(frame)` runs the cap first (`Game.finish_intro`), then the panel change with the squeak (panel 2) and `intro_handover` (panel 3) latches; `try_skip(frame)` is the gated skip; `_exit_tree` calls `VoiceService.stop()`. Squeak / line go through Callable seams (defaults `AudioManager.play_squeak`, `VoiceService.say`) for tests. Panels follow sim frames since `Game.intro_start_frame`; the presentation frame counter drives only the panel 3 tear jitter.
- Skip rule (D-S67-4): `IntroScreen.skip_allowed` = `PlaceholderScreen.is_advance` (kept in place, shared) AND not `Game.is_pause_press`, so P is rejected even when called directly (Esc / P are consumed by `Game._input` first anyway).
- C2 deviation (recorded): no bubble reference is handed to the screen. `VoiceService.say` emits `EventBus.duck_line_requested`, which the HUD's one `DuckBubble` already consumes (the HarvestScreen path), so the line goes through the one bubble without new wiring; with no HUD the request reaches no bubble and nothing shows (silent), as C2 asks.
- Bubble clear on INTRO -> FIGHT: `DuckBubble._on_flow_state_changed` did not clear on a `-> FIGHT` change from INTRO (only from HARVEST). Added `from == INTRO`, so a skip or the cap clears the line and stops the voice (AC 5); test added in `test_duck_bubble.gd`.
- Intro line request at frame 300 needs no defer (the bubble's flow-change clear ran at entry, 300 frames earlier), as the Dev Notes predicted.
- `Game.advance()` in INTRO now goes through `can_skip_intro(SimClock.sim_frame)` + `finish_intro(.., true)` (AC 7); deferred-work.md 1.6 item marked resolved. Unit tests that used `advance()` to leave INTRO now leave it through `finish_intro(first_input_frame + 1, true)` (`_skip_intro` helper); new tests cover the gate and the paused case.
- D-S67-7 verified in code: `_set_flow_state(FlowState.INTRO)` is called only in `Game.start_run_from_title`, which is called only by `TitleScreen.handle_input` (any START or hidden-option input, all title options are still hidden); `debug_jump` rejects INTRO; retry / harvest / ending never route to INTRO. No continue path exists yet (7.3), so nothing replays or bypasses the Intro.
- `duck_lines.tres`: `intro_handover` placed first (GDD row 1), so tests that assumed T1 at index 0 / harvest at 4 now offset by one. Budget count 9 of 10 (D-039).
- No music started (7.1), no FeatureFlags entry, no new SFX beyond the existing squeak (the bubble's own squeak on line start also plays on panel 3, existing 3.6 behaviour).
- GDD vs story: no contradiction found (GDD Intro row and Duck row 1 match the story text exactly).
- Human check pending (not automated, does not block): E1 Chrome (and Firefox/Safari when available) check of the three panels, <= 8 s, Esc freeze, key/click skip from the first frame, the duck voice on panel 3 (MUMBLE) and the squeak on panel 2. Open questions D-S67-1 (does the 0.5 s hold read as a freeze) and D-S67-5 (squeak alone enough for "which quacks") are for that check.

### File List

- game/src/ui/screens/intro/intro_screen.gd (new)
- game/src/ui/screens/intro/intro_screen.gd.uid (new)
- game/src/autoloads/game.gd
- game/src/main/main.gd
- game/src/ui/duck/duck_bubble.gd
- game/src/ui/screens/placeholder/placeholder_screen.gd
- game/data/duck/duck_lines.tres
- game/data/duck/duck_clips.tres
- game/assets/audio/duck/intro_handover.wav (new)
- game/assets/audio/duck/intro_handover.wav.import (new)
- game/tests/unit/test_intro_screen.gd (new)
- game/tests/unit/test_intro_screen.gd.uid (new)
- game/tests/integration/test_intro_flow.gd (new)
- game/tests/integration/test_intro_flow.gd.uid (new)
- game/tests/unit/test_duck_lines.gd
- game/tests/unit/test_duck_bubble.gd
- game/tests/unit/test_duck_director.gd
- game/tests/unit/test_font_coverage.gd
- game/tests/unit/test_game_flow.gd
- game/tests/unit/test_main_layers.gd
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/6-7-intro-sequence.md

### Change Log

- 2026-11-12: Story 6.7 implemented: IntroScreen (three panels, squeak, duck line 1, gated skip, cap), duck line `intro_handover` + rendered clip, `Game.advance()` INTRO gate, Main wiring (duck-only HUD in INTRO), placeholder INTRO branch removed, bubble clears on leaving INTRO; tests added/updated. Status -> review.
