---
baseline_commit: c0f1f34d62854ce1f83441cac6e2128be2b69982
---

# Story 2.4: Shift Juice

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default; the implementer follows them or records a change in Completion Notes. -->

## Story

As a player,
I want every shift to slide, click and flash instantly,
so that shifting feels great and I want to do it constantly (Pillar 4).

**Requirements:** FR28 (shift juice), FR63 (Must SFX placeholders: shift click); GDD "Hit Feedback" table (Shift row: 0 frames, slide over 6 frames with overshoot bounce, key-click SFX, weapon inverts 4 frames); NFR8 (ink/bg palette only).
**Epic 2 window:** Nov 8-10. **Depends on:** Story 2.3 (`Register`, `EventBus.register_shifted`, `RegisterPanel`), Story 2.2 (`PlayerView` draws the `@`), Story 1.4 (`AudioManager` unlock gate, SFX bus), Story 1.7 (pause/focus-loss semantics).

## Acceptance Criteria

1. **Shift feedback on the same frame.** Given a shift, when `EventBus.register_shifted` is emitted, then on that same frame the HUD register starts a 6-frame slide with an overshoot bounce (presentation only), the player's `@` glyph inverts for 4 frames, and a mechanical key-click SFX plays.
2. **Distinct click per direction.** The click for `<<` (direction -1) is `shift_left.wav` and for `>>` (direction +1) is `shift_right.wav`. Placeholder sounds are acceptable; the final SFX pass is Epic 7 (7.2).
3. **Rapid shifts restart.** Given rapid shifts (e.g. 3 within 6 frames), when the slide is still running, then each new shift restarts the slide toward the latest state; the text shown always matches the live `Register` (no lag, no desync). The click plays once per shift.
4. **Hit-stop and Breakpoint do not stop the HUD.** Given hit-stop (or Breakpoint, verified in 4.3), when a shift is shown, then the HUD animation advances in `_process` independently of the simulation: `SimClock.sim_frame` is frozen during hit-stop, and that does not freeze the slide or the inversion.
5. **Juice never writes simulation state.** The juice code only reads the signal arguments and the injected presentation nodes. No `Register`, `InputBuffer`, `SimClock` or `Player` writer is called from presentation code.

## Scope Boundaries

- In: shift juice only (slide, weapon inversion, click SFX, placeholder WAVs, the presentation director wiring).
- Out: hit feedback (hit-stop table, particles, shake, log lines: Story 2.8), ScreenFX/dither shader (Epic 7 / 2.8), final SFX (7.2), pooled SFX players (7.2), Breakpoint shifting (4.3), ATTACK/DASH glyphs (2.5). No change to `Register`, `InputBuffer`, `SimClock` or `Player` behaviour.

## Tasks / Subtasks

### Group A: Pure juice model (AC: 1, 3, 4)

- [x] Create `game/src/presentation/shift_juice.gd` (`class_name ShiftJuice`, `extends RefCounted`). Pure state, no node, no scene tree (see D-S24-1, D-S24-2).
  - [x] `on_shift(direction: int, now: int) -> void`: stores `direction` and `start = now`; a second call restarts (AC3).
  - [x] `slide_offset_px(now: int) -> int`: `0` once `now - start >= SLIDE_FRAMES`; otherwise `-direction * SLIDE_PX[now - start]`.
  - [x] `is_inverted(now: int) -> bool`: true for `now - start` in `0..INVERT_FRAMES-1`.
  - [x] `click_path(direction: int) -> String`: `res://assets/audio/sfx/shift_left.wav` for -1, `shift_right.wav` for +1.
  - [x] `reset() -> void`: clears the state (no slide, no inversion).
- [x] Constants: `SLIDE_FRAMES := 6`, `SLIDE_PX := [8, 5, 2, -1, 1, 0]` (length `SLIDE_FRAMES`), `INVERT_FRAMES := 4`. Use `Const` if `Const` already holds presentation timings; otherwise keep them on `ShiftJuice`, named as above.

### Group B: Placeholder SFX (AC: 1, 2)

- [x] Create `game/tools/gen_shift_sfx.py` (stdlib only, mirrors `game/tools/gen_glyph_font.py`): writes `game/assets/audio/sfx/shift_left.wav` (down-sweep 1200 Hz to 800 Hz) and `shift_right.wav` (up-sweep 800 Hz to 1200 Hz), 40 ms, 22050 Hz, mono, 16-bit, short linear fade-out (no click at the end). Run from repo root: `python3 game/tools/gen_shift_sfx.py`.
- [x] Commit the two generated `.wav` files (the `.gitkeep` stays). Let Godot import them (`.import` files are created by the editor/headless import as for the other assets; commit them with the WAVs if the repo tracks `.import` files for other audio).
- [x] `game/src/autoloads/audio_manager.gd`: add `play_sfx(stream: AudioStream) -> void` next to `play_test_sfx`. It uses the same unlock gate (`_warn_locked_once` before unlock), the `SFX` bus, and one `AudioStreamPlayer` (created lazily, named `ShiftSfx`) whose `stream` is set and `play()` called on each click. A rapid second click restarts the first (accepted; pooling is 7.2).

### Group C: Presentation director (AC: 1, 3, 4, 5)

- [x] Create `game/src/presentation/juice_director.gd` (`class_name JuiceDirector`, `extends Node`). It is the presentation listener for shift juice (architecture "JuiceDirector"; hit feedback joins in 2.8).
  - [x] `_ready()`: `EventBus.register_shifted.connect(_on_register_shifted)`; `_exit_tree()`: disconnect (guard with `is_connected`), so re-instancing Main in tests never double-connects.
  - [x] `_on_register_shifted(direction, _window, _ring, _source)`: `juice.on_shift(direction, now())`; `AudioManager.play_sfx(load(juice.click_path(direction)))` (preload the two streams in the director; no `load()` per shift); `_apply()`.
  - [x] `_process(_delta)`: `_apply()` only while a shift is live (`juice` has a start and `now - start < SLIDE_FRAMES`) or the inversion is live, then clear it. Keep the work tiny: no allocation per frame.
  - [x] `_apply()`: sets `register_panel.slide_px = juice.slide_offset_px(now())` and `player_view.inverted = juice.is_inverted(now())`, then queues redraw on both.
  - [x] `now() -> int`: `Engine.get_physics_frames()` (D-S24-1). Never `SimClock.sim_frame` or `poll_frame`.
  - [x] `reset()`: `juice.reset()`, panel slide 0, player not inverted; called by `Main.apply_flow_state` on every flow change so no slide or inversion carries across screens.
- [x] `game/src/ui/hud/register_panel.gd`: add `var slide_px: int = 0` and apply it as a horizontal offset to every cell it draws (`draw_set_transform(Vector2(slide_px, 0))` or equivalent), clipped to the REGISTER inner area (D-S24-3). With `slide_px == 0` the output is identical to 2.3 (existing tests unchanged). The `plan()` function and its cells are not changed.
- [x] `game/src/presentation/player_view.gd`: add `var inverted: bool = false`. In `_draw`, when `inverted`, draw the `@` as an INK cell with a BG glyph (the same pattern as `RegisterPanel` INVERTED: `draw_rect` in `Palette.INK`, glyph in `Palette.BG`). The duck `>o` is not inverted (D-S24-4). Only INK and BG are used.
- [x] `game/src/main/main.gd`: in `_build_layers()`, create the `JuiceDirector` (name `JuiceDirector`), set its `register_panel = hud.register_panel` and `player_view = player_view`, and add it to the tree (under Main, not under the arena: the arena is a sim-adjacent folder, and the director does not need its transform). In `apply_flow_state()`, call the director's `reset()`.

### Group D: Tests and guards (AC: all)

- [x] `game/tests/unit/test_shift_juice.gd` (pure, no scene tree):
  - [x] slide: `slide_offset_px(start + k)` equals `-direction * SLIDE_PX[k]` for k in 0..5 and `0` from k = 6; both directions (sign flips with direction).
  - [x] overshoot: for `>>` the offset is positive at k = 3 (past rest), and returns to 0 at k = 5.
  - [x] inversion: true at k = 0..3, false at k = 4 and later (AC1: 4 frames).
  - [x] rapid shifts (AC3): shifts at start 0, 2 and 4 (directions -1, +1, +1): at `now = 4` the state reflects the last shift only (direction +1, slide restarted at 4, `slide_offset_px(4) == -SLIDE_PX[0]`, `slide_offset_px(9) == -SLIDE_PX[5] == 0`), and the inversion window restarted at 4.
  - [x] hit-stop independence (AC4): the output depends only on the `now` value passed in. Test: `on_shift(+1, 100)`, then query at 101, 102, 103 with no other input; the same numbers as without any SimClock call. Add a headless test that calls `SimClock.request_hitstop(9)` and ticks a few frames while the juice is queried with the engine frame value, and asserts the offset sequence is unchanged (sim frozen, juice moves).
  - [x] click paths: `click_path(-1)` ends with `shift_left.wav`, `click_path(1)` with `shift_right.wav`; both files exist (`ResourceLoader.exists`) and load as `AudioStreamWAV` or `AudioStream`.
  - [x] `reset()` clears slide and inversion.
- [x] `game/tests/unit/test_audio_manager.gd` (extend): `play_sfx` before unlock does not play and warns once; after `unlock()` it plays on the SFX bus (use a stub stream; check `playing`).
- [x] `game/tests/unit/test_juice_director.gd` (new, small): with a real `RegisterPanel` and `PlayerView` attached, emitting `EventBus.register_shifted(-1, Vector2i(...), PackedInt32Array([...]), &"player")` sets the panel's `slide_px` and the view's `inverted` after one `_apply()` call; `reset()` clears both. Clean up the node and the connection in `after_each`.
- [x] Source guard (AC5): in `test_shift_juice.gd`, read `shift_juice.gd` and `juice_director.gd` as text and assert no call to `.shift(`, `set_fight_start(`, `.insert(`, `set_active(`, `.ring =` and no reference to `SimClock`, `InputBuffer` or `Player` (the director may name `SimClock` only in a comment).
- [x] `test_glyph_palette.gd`: add `res://src/presentation/player_view.gd` to `SOURCES` (its inversion draws with `Palette.INK`/`Palette.BG` constants).
- [x] `test_main_layers.gd` / `test_hud_layout.gd`: update only if they assert an exact child count or order under Main (the director adds one child). Do not change the `LAYER_ORDER` contract.
- [x] Run GUT and the static guards (see Testing Requirements). Baseline: 317/317 after 2.3 review.

## Dev Notes

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] D-S24-1 Presentation clock.** The juice advances on `Engine.get_physics_frames()`, which is the engine's 60 Hz physics counter. It is not gated by `SimClock` (pause, Breakpoint, hit-stop), so hit-stop does not freeze the HUD (AC4, GDD "Hit Feedback": shift is 0 frames of gameplay cost; architecture "HUD slide continues during hit-stop and Breakpoint"). `ShiftJuice` takes `now` as an argument so tests are deterministic and never read the engine. Pause (Esc) does not stop the engine's physics counter in this design; if the slide must freeze under the pause overlay, record a change, but the default is to let it finish (at most 6 frames).
- **[design call] D-S24-2 Frame table, not a Tween.** The architecture and project-context allow a Tween in presentation, but a Tween runs in seconds, not exact frames, and cannot be asserted headless. The spec is the integer table `SLIDE_PX = [8, 5, 2, -1, 1, 0]` (6 frames, last two frames are the overshoot and the settle), scaled by `-direction`. At 1x the panel moves in whole pixels, so no sub-pixel rendering. Visual result: slides in from the side of travel, overshoots by 1 px, settles.
- **[design call] D-S24-3 Clip to the REGISTER box.** The slide moves the panel contents up to 8 px, which would draw cells over the box border at col 0 or the gap at col 12. Clip the panel's drawing to its inner area (cols 1-10, rows 3-20, i.e. `Rect2(8, 24, 80, 144)` px at 1x, relative to the panel origin). Preferred method: a clipping parent (Godot `clip_children`), checked against the Godot 4.7 docs (`/godotengine/godot-docs/__branch__4.7`) before use. Fallback if clipping is awkward: use `draw_rect` with `Palette.BG` over the one-cell gutters after drawing the slid content, and draw the box border back on top (the border is a Hud frame glyph; check `hud_frame.gd`). Record which one was used.
- **[design call] D-S24-4 "Weapon glyph" = the `@`.** No weapon glyph exists until ATTACK (2.5). The only player glyph that stands for the weapon-bearing player is the `@` in `PlayerView`. Invert the `@` for 4 frames. The duck `>o` is not inverted. Story 2.5 may move the inversion to the slash glyph; record it there.
- **[design call] D-S24-5 Placeholder clicks generated, not sampled.** No jsfxr or sfx sources are in the repo (`game/assets/audio/sfx/` is empty). Generate `shift_left.wav` and `shift_right.wav` with a committed stdlib script (`game/tools/gen_shift_sfx.py`, same convention as `gen_glyph_font.py`), so they are reproducible, CC0 by construction (own code), and distinct (down vs up sweep). Final SFX pass is 7.2. If the dev prefers no binary in git, generating them in code like `AudioManager.make_blip()` is acceptable, but the file names in the AC must still be honoured as stream resources.
- **[design call] D-S24-6 File layout.** Pure model in `src/presentation/shift_juice.gd`; wiring in `src/presentation/juice_director.gd` (a Node, the architecture's JuiceDirector, shift handlers only); panel and `@` get a single presentation field each (`slide_px`, `inverted`). The sim folders are not touched: no new file under `src/register/`, `src/input/`, `src/arena/`, `src/player/`.
- **[design call] D-S24-7 Restart semantics.** A new shift sets `start = now` and the new direction. The displayed text is always the live ring from `Register` (the panel draws `plan(register.ring)` each frame), so only the offset animates; a restart never shows a stale state. Three shifts within 6 frames therefore show the latest state at once, with the slide re-timed from the last one.
- **[design call] D-S24-8 Click per shift.** Every applied shift plays a click, including rapid ones; the second click cuts the first (single `AudioStreamPlayer`). Pooling is 7.2.
- **[design call] D-S24-9 Reset on flow change.** `Main.apply_flow_state` calls `JuiceDirector.reset()` so a slide or inversion never carries into INTRO, HARVEST or the next fight. Shifts only happen in FIGHT (2.3 D-S23-11), so this is belt and braces.

### Architecture guardrails (must follow)

- Presentation reads the signal arguments and its own state. It never calls `Register.shift`, `set_fight_start`, `insert`, `set_active`, never writes `ring`, never calls `SimClock.request_hitstop`, never touches `InputBuffer` (AD-05, project-context "Presentation is read-only").
- No `await`, no `Timer`, no `create_tween` in `src/register`, `src/input`, `src/player`, `src/arena`. The new presentation code may use `_process` (allowed, architecture: "Presentation (`_process`) animates independently").
- Typing: every variable, parameter and return is typed. `StringName` ids (`&"shift_left"`). `Log` only (`Log.debug(&"juice", ...)` at most once per shift, never per frame).
- Palette: `Palette.INK` and `Palette.BG` only in glyph and rect drawing (`test_glyph_palette.gd`). No `Color(...)` or `Color.X` literal.
- Signals: no new signal. Use `EventBus.register_shifted` (declared in 2.3). Never a `Dictionary` payload.
- Script cycles leak at exit (2.2 lesson): `JuiceDirector` holds references to `RegisterPanel` and `PlayerView` (set by Main), but neither holds the director. `ShiftJuice` is `RefCounted` and references nothing.
- Integer frames only in the juice model (`now`, `start`, offsets in int px). The engine frame counter is an int.

### Previous story intelligence (2.1, 2.2, 2.3)

- `EventBus.register_shifted(direction: int, window: Vector2i, ring: PackedInt32Array, source: StringName)` is emitted once per applied shift from `Register.shift()`, after `ring` is rotated. The juice consumes it; it never changes the ring.
- `Register` (2.3) is a `SimSystem` in phase SHIFTS, ticked only by `SimClock`. Shifts apply in the world tick. During hit-stop the buffer holds presses (8 frames, poll-frame time base, D-S23-2); during Breakpoint shifts are applied immediately (2.3 D-S23-12, Story 4.3). The juice runs off the engine counter, so it is independent of both.
- `RegisterPanel` (2.3) is a `Node2D` under `Hud` (a `CanvasLayer`), injected with the register by Main, redraws every frame while `register.active` (D-S23-9). It has `plan(ring, owned_cap)` (pure), `_draw` executes it, and a checker texture for greyed and faded cells. Its layout (D-S23-8) and its existing tests (`test_register_panel.gd`, 14 tests) must keep passing with `slide_px == 0`.
- `PlayerView` (2.2) is a child of `Arena` (an arena-local `Node2D`), draws the `@` and `>o` at 2x via `GlyphFont.draw_at`, and has `player_top_left()` and `duck_top_left()` as pure statics. `_process` redraws while `player.active`. The inversion must follow the same redraw rule.
- 2.2 review: a `PlayerView` one-frame stale draw on re-entry was fixed in `Arena._redraw_player_view`. Do the same for the director's panel and view if a slide is live when FIGHT is entered.
- `AudioManager` (1.4, 1.7): unlock gate, `SFX` bus, `play_test_sfx()` with a lazily created `AudioStreamPlayer`; `Log.warn` once on play before unlock. `set_master_muted` is separate (mute is a Master bus flag, so the click is muted too).
- Deferred items that touch this story (from `_bmad-output/implementation-artifacts/deferred-work.md`): "Hit-stop/Breakpoint longer than 8 frames drops all buffered input" (2.3, design call, judge by feel: check in H3); "RegisterPanel redraws every frame while active" (perf only; the slide adds no cost beyond a few draws); "Greyed and faded cell styles look identical" (2.3 H1); "Register `ring` is a public var" (the juice must not write it).
- Test baseline after 2.3 review: GUT 317/317 across 36 scripts; `bash game/tools/check_guards.sh` OK.

### Git intelligence (recent commits)

- `c0f1f34` Story 2.3: Register ring, shift and HUD panel (`register.gd`, `register_panel.gd`, `register_system`, `EventBus.register_shifted`, FIGHT wiring in `Arena` and `Main`).
- `d8b748f` Story 2.2: player movement, `PlayerView`, held-direction input (format v2 recorder).
- `0b057fa` Story 2.1: sim clock, input source, buffer, recorder, F11, guards.
- Pattern: each story adds small files, extends existing tests, keeps `check_guards.sh` green, records design calls and human checks in the story file.

### Latest technical information

- No new engine features. Godot 4.7.2: `Engine.get_physics_frames()` (int), `Node.queue_redraw()`, `draw_set_transform()` (or `position`), `draw_rect()`, `AudioStreamPlayer.stream`/`bus`/`play()`, `AudioStreamWAV` (16-bit, mono, `loop_mode = LOOP_DISABLED`), `EventBus` signals with `connect`/`is_connected`/`disconnect`. Check method names against `/godotengine/godot-docs/__branch__4.7` (project-context) before writing a clipping method (D-S24-3).
- `clip_children` is a `CanvasItem` property; confirm its enum name and whether it clips the node's own drawing in 4.7 before relying on it.
- No web research needed: the design is local.

### Project Context Rules

- Godot project root is `game/`. Files go under `game/src/presentation/`, `game/src/ui/hud/`, `game/src/autoloads/`, `game/tools/`, `game/assets/audio/sfx/`, `game/tests/unit/`.
- `project-context.md` (`_bmad-output/project-context.md`): "Presentation is read-only"; "Only `SimClock` calls `tick(ctx)`"; "`await` and Tweens are allowed only in presentation/UI code"; "Signals: declare only in `event_bus.gd`"; "Names: files `snake_case`, `class_name` PascalCase".
- Debug tools stay behind `Debug.enabled`. The shift juice is player-facing and is always on.

### Project Structure Notes

- New: `game/src/presentation/shift_juice.gd` (+ `.uid`), `game/src/presentation/juice_director.gd` (+ `.uid`), `game/tools/gen_shift_sfx.py`, `game/assets/audio/sfx/shift_left.wav`, `game/assets/audio/sfx/shift_right.wav`, `game/tests/unit/test_shift_juice.gd` (+ `.uid`), `game/tests/unit/test_juice_director.gd` (+ `.uid`).
- Modified: `game/src/autoloads/audio_manager.gd`, `game/src/ui/hud/register_panel.gd`, `game/src/presentation/player_view.gd`, `game/src/main/main.gd`, `game/tests/unit/test_audio_manager.gd`, `game/tests/unit/test_glyph_palette.gd`, possibly `game/tests/unit/test_main_layers.gd`.
- Conflicts: none found. `src/presentation/` already holds `player_view.gd` (2.2), and the architecture names `juice_director.gd` there. `hud_frame.gd` is the box border owner (see D-S24-3).

### Testing Requirements

- GUT headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (run `godot --headless --path game --import` first in a fresh worktree; the WAVs must be imported before the audio tests load them).
- Static guards: `bash game/tools/check_guards.sh` from the repo root.
- Pure logic with no scene tree: `ShiftJuice`. Node-level: `JuiceDirector` with real `RegisterPanel` and `PlayerView` instances, the signal emitted via `EventBus`, cleaned up in `after_each`.
- Do not rely on real key events in GUT. Shifts come from `EventBus.register_shifted.emit(...)` or `Register.shift()` on a test register.
- Draw output is not unit-tested beyond the pure parts and the source guards; the visual check is H1 and H2.

### Human Checks (for Tiziano; recorded in Completion Notes; do not block `review`)

- [ ] [2.4 H1] Debug build, F2 (FIGHT): press Q and E. The register slides in from the side of travel, with a 1-px overshoot that settles in 6 frames, clipped to the REGISTER box (no cell over the frame border). Check in Chrome and Firefox (D-S24-2, D-S24-3).
- [ ] [2.4 H2] The `@` inverts for about 4 frames on each shift, and the duck `>o` stays normal. The inversion reads clearly at 2x (D-S24-4).
- [ ] [2.4 H3] Tap Q/E three times fast: the register text is always the latest state, the slide restarts each time, and each shift clicks. Hear `shift_left.wav` (down) and `shift_right.wav` (up) as different sounds (placeholder, D-S24-5, D-S24-7).
- [ ] [2.4 H4] Hit-stop (once a debug or real hit exists, 2.8; before then, skip): the slide and inversion keep running during a hit-stop while the world stays frozen (D-S24-1). Breakpoint is verified in 4.3.
- [ ] [2.4 H5] Release build (no `?debug`): the same behaviour as H1-H3 with the title's audio unlock done first (click plays only after unlock).

### Review Findings

- [x] [Review][Patch] Slide direction not normalised: `on_shift` now stores `signi(direction)` [game/src/presentation/shift_juice.gd] (fixed, test added)
- [x] [Review][Patch] Director `_apply` null-checked but not `is_instance_valid` for freed panel/view [game/src/presentation/juice_director.gd] (fixed)
- [x] [Review][Patch] No test that every `plan()` cell lies inside `CLIP_RECT`, so "identical at rest" was unproven [game/tests/unit/test_juice_director.gd] (fixed, test added)
- [x] [Review][Defer] Physics-frame clock: a render hitch of 4+ physics ticks can skip slide frame 0 or the whole inversion [game/src/presentation/juice_director.gd] - deferred, rare, <=6 frames
- [x] [Review][Defer] `clip_children` under gl_compatibility on web unverified, no BG-gutter fallback [game/src/ui/hud/register_panel.gd] - deferred to H1
- [x] [Review][Defer] [design call] Rapid alternate shifts snap the offset to +-8 px (restart, no blending), as D-S24-7 specifies [game/src/presentation/shift_juice.gd] - kept
- [x] [Review][Defer] Click dropped while audio is locked (debug jump keys never unlock) [game/src/autoloads/audio_manager.gd] - deferred, expected gate
- [x] [Review][Defer] Click/inversion ignore signal `source` and pause; single shared SFX player cuts overlapping SFX [game/src/presentation/juice_director.gd, audio_manager.gd] - deferred to Epic 3 (source) and Story 7.2 (pooling)
- [x] [Review][Defer] Hit-stop test uses a synthetic frame counter and source guard covers only two files [game/tests/unit] - deferred; real check is H4 (Story 2.8)

Dismissed as noise (about 12): pause concerns (the director runs on engine frames and pause is `SimClock.paused`, so the slide just finishes), `slide_px` setter before `_init`, ADPCM import, tonal click, per-shift string formatting, `_enter_tree` ordering (director built in `_build_layers`), WAV determinism, process notes.

## Dev Agent Record

### Agent Model Used

Story created by Claude Haiku 5.5 (claude-haiku-5-5), via gds-create-story (unattended).
Implemented by Claude Opus 5.5 (claude-opus-5-5), via gds-dev-story (unattended).

### Debug Log References

- Fresh worktree: `godot --headless --path game --import` run first (imports the two WAVs).
- First full GUT run: 336/337; `test_exit_tree_disconnects` failed because `_ready` runs only once, so a director removed and re-added to the tree never reconnected. Fixed by connecting in `_enter_tree` (symmetric with `_exit_tree`).
- Final: GUT 337/337 across 37 scripts (5370 asserts; baseline 317/317, +20 tests). `bash game/tools/check_guards.sh`: OK. The `[ERROR]` log lines in the run are the existing negative-path tests of 2.1/2.3.

### Completion Notes List

- Group A: `ShiftJuice` (RefCounted, pure) with `SLIDE_FRAMES = 6`, `SLIDE_PX = [8, 5, 2, -1, 1, 0]`, `INVERT_FRAMES = 4` kept on the class (`Const` holds no presentation timings). Added `is_live(now)` (slide or inversion still running) so the director's `_process` knows when to stop; `click_path` is static.
- Group B: `game/tools/gen_shift_sfx.py` (stdlib `wave`) writes 40 ms, 22050 Hz, mono, 16-bit sweeps (left 1200->800 Hz, right 800->1200 Hz) with a 25% linear fade-out; deterministic. WAVs and their `.import` files are added (the repo tracks `.import` for fonts). `AudioManager.play_sfx(stream)`: unlock gate + one-time warn, `SFX` bus, one lazy `ShiftSfx` player, a new call cuts the previous one (D-S24-8).
- Group C: `JuiceDirector` preloads both clicks (`click_stream(direction)`, no `load()` per shift), runs on `Engine.get_physics_frames()` (D-S24-1), applies only while live, `reset()` called from `Main.apply_flow_state` (D-S24-9). Added under Main after `Screens` so the `LAYER_ORDER` child-index contract is untouched; no layer test needed changes.
- [design call] D-S24-3 clipping method: `clip_children` (checked against the Godot 4.7 docs via ctx7: `CLIP_CHILDREN_ONLY` = the node's own drawing is the mask and is not drawn; children are clipped). `RegisterPanel` now sets `clip_children = CLIP_CHILDREN_ONLY`, draws an opaque `CLIP_RECT = Rect2(8, 24, 80, 144)` as the mask, and draws its cells through a child `Content` Node2D (via its `draw` signal) whose `position.x = slide_px`. `slide_px` is a property whose setter moves `Content` and queues its redraw. `plan()` is unchanged; at `slide_px == 0` all cells lie inside the mask, so the output equals 2.3. The BG-gutter fallback was not needed. Renderer support for clip_children under `gl_compatibility` on web is covered by H1.
- [design call] Director connects in `_enter_tree` instead of `_ready` (spec said `_ready`), so a remove/re-add of the node reconnects; `_exit_tree` disconnects, guarded by `is_connected`.
- [design call] Pause (Esc) does not freeze the slide (D-S24-1 default kept: at most 6 frames).
- `PlayerView.inverted`: the `@` draws as an INK 16x16 rect with a BG glyph; the duck is untouched (D-S24-4). `player_view.gd` added to both palette checks in `test_glyph_palette.gd`.
- Tests: `test_shift_juice.gd` (12: tables, slide both directions, sign, overshoot, 4-frame inversion, rapid restarts, now-only output, hit-stop with a real SimClock instance frozen while the juice advances, click files load as AudioStream and map to distinct preloads, reset, AC5 source guard); `test_juice_director.gd` (6: connect, slide + inversion on emit and restart, reset, settles after real physics frames, exit-tree disconnect/reconnect, panel at rest + clip mode); `test_audio_manager.gd` +2 for `play_sfx`.
- Human checks for Tiziano (do not block review): 2.4 H1-H5 as listed in Dev Notes. H1 also confirms that `clip_children` clips correctly in the web (Compatibility) build; if it does not, switch to the D-S24-3 fallback.

### File List

- game/src/presentation/shift_juice.gd (new) + .uid
- game/src/presentation/juice_director.gd (new) + .uid
- game/tools/gen_shift_sfx.py (new)
- game/assets/audio/sfx/shift_left.wav (new) + shift_left.wav.import
- game/assets/audio/sfx/shift_right.wav (new) + shift_right.wav.import
- game/src/autoloads/audio_manager.gd (modified)
- game/src/ui/hud/register_panel.gd (modified)
- game/src/presentation/player_view.gd (modified)
- game/src/main/main.gd (modified)
- game/tests/unit/test_shift_juice.gd (new) + .uid
- game/tests/unit/test_juice_director.gd (new) + .uid
- game/tests/unit/test_audio_manager.gd (modified)
- game/tests/unit/test_glyph_palette.gd (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/2-4-shift-juice.md (this file)

## Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status ready-for-dev. Design calls D-S24-1 to D-S24-9 recorded.
- 2026-11-07: Implemented by gds-dev-story (unattended): ShiftJuice model, JuiceDirector, RegisterPanel slide with clip_children mask, PlayerView inversion, AudioManager.play_sfx, generated placeholder clicks, 20 new tests. GUT 337/337, guards OK. Status review.
- 2026-11-07: Code review (3 parallel layers): 3 patches applied, 6 deferred, ~12 dismissed. GUT 339/339, guards OK. Status done.
