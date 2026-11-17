---
baseline_commit: 5da7435
---

# Story 9.7: Arena Readability

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from main 5da7435 in worktree gameoff-wt/9-7 (branch story/9-7-arena-readability). Sources: the coordinator brief `gameoff-wt/s97/brief.md` (approved decisions D-S97-1..8), the approved throwaway prototype `gameoff-wt/s97/prototype.diff` (reference only, do NOT apply as-is), screenshots `before-tutorial.png`, `before-practice.png`, `02-tut1.png`, `03-tut2.png`, `04-segfault.png`, `05-fight0b.png`, `top.png` in the same folder; Epic 9 in epics.md (Story 9.7, line ~1916); NFR8 and AD-07 (epics.md, game-architecture.md); decision log D-054. Nothing was committed. Design calls are marked [design call] D-S97-n. -->

## Story

As a player,
I want the player, the bosses and the in-arena text to stand out from the scenery, and the top two rows to read clearly,
so that I can always tell what is mine and what is the fight.

**Requirements:** playtest feedback 2026-11-17 (`before-tutorial.png`, `before-practice.png`: the text, the `@` and the bosses blend into the full-INK scenery glyphs); NFR8 (1-bit palette; a 75% scenery dither is added as an extra state); AD-07 (render layers, `draw_char` / `draw_string` only); DC4a (`src/arena/` references no `ui/` or `presentation/`); epics.md Story 9.7 (line ~1916); decision log D-054. Not a deferred-work item: the one deferred row it creates is the duck-bubble wrap (deferred-work.md, "Story 9.7").

## Acceptance Criteria

1. **Scenery dither (D-S97-1).** **Given** the scenery glyphs grass `"`, rock `o` and water **When** the arena is drawn **Then** each is drawn with a 75% BG dither (in base-pixel space one INK pixel is kept per 2x2 block, `x % 2 == 0 and y % 2 == 0`), the tree ring `♣` and the `stack frame 0x03` label stay full INK, and the dither texture builder lives in `src/core/` (GlyphFont or a new core helper), not in `presentation/` or `ui/`.

2. **Water glyph (D-S97-2).** **Given** the font `assets/fonts/wildshift8.fnt` (112 glyphs, no `≈`) **When** the arena layout is read **Then** `Arena.WATER` is `=` and no `~` remains in `Arena.LAYOUT`, in any test, or in any doc that names the water glyph (grep the tree to confirm).

3. **Actor halo (D-S97-3).** **Given** a scenery cell (grass, rock or water) whose centre is within 24 px of the player centre, within `boss.body_radius_px() + 20` px of `boss.body_center_px`, within 32 px of the practice target, or within 24 px of a live Ghost Echo decoy **When** the arena is drawn **Then** that cell is not drawn. Trees and the label are never hidden.

4. **Frame cost (D-S97-3, rule "Keep 60 fps").** **Given** the hidden-cell set is recomputed each frame (576 cells, cheap) **When** the set is unchanged from the previous frame **Then** the arena does not call `queue_redraw()`; it redraws only when the set changes. No per-frame full redraw of the scenery and no `_process` that queues a redraw unconditionally (the prototype's `_process` does this and must not ship).

5. **DC4a (D-S97-3).** **Given** the change set **When** `src/arena/` is scanned **Then** no file under it references `presentation/` or `ui/` (identifiers or paths), and the dither builder used by Arena and RegisterPanel is in `src/core/`. A guard test or the existing architecture guard checks it.

6. **Tutorial checklist in the console, left block (D-S97-4).** **Given** the tutorial is open **When** the checklist is drawn **Then** the six test rows sit in the console's left block (HUD rows 39-44, console lines 0-5), the `>` cursor at column 0 on the current row and the rows at column 2, and no checklist text is drawn inside the arena.

7. **Tutorial prompt in the console, right block (D-S97-4).** **Given** the current prompt **When** it is drawn **Then** it starts at HUD column 24 and is word-wrapped to the 56 remaining columns (the prototype ran line 1 off the screen; that must not recur), and it never extends past column 79.

8. **Tutorial log lines (D-S97-4).** **Given** the tutorial is open **When** log lines exist **Then** they show in the right block under the prompt rows, as many as fit, and the log panel's normal full-width behaviour returns when the tutorial closes.

9. **Tutorial hints and completion rows (D-S97-4).** **Given** the tutorial hints and the completion rows (`ALL TESTS PASSED.`, `deploying to production...`) **When** they are drawn **Then** the skip and pause hints stay in the arena's top-right with backing, and the 2x completion rows stay in the arena bottom band, with the spawn and dummy clearance of Story 9.1 (618b) kept.

10. **Practice readout on the console header (D-S97-5).** **Given** a practice run **When** the HUD draws **Then** `frames N` and the practice key hint sit on HUD row 38 (the `── console ──` rule), right-aligned two columns from the edge, with a BG backing over the rule, and nothing practice-related is drawn in the arena (PracticeFrameCounter stops drawing its text in the arena; its frame logic is kept).

11. **Row 0 title bar (D-S97-6).** **Given** a fight is on **When** row 0 is drawn **Then** it is a full-width INK bar (80 cells) with BG text: the boss signature (`void x() // hp N`) on the left and the player HpReadout on the bar (HpReadout draws in BG).

12. **Row 0 under effects (D-S97-6).** **Given** the one-frame full-screen crit inversion and the Breakpoint dither **When** they run **Then** row 0 is still readable; ScreenFX acting on the whole screen is accepted (checked on the web build, see AC 20).

13. **Row-0 clipping fixed at the root (D-S97-7).** **Given** the exported web build at 1280x720 **When** row 0 is viewed **Then** its glyphs are fully visible (not shifted up, top not clipped) and the cause is recorded with evidence in the Dev Agent Record: either a real bug, fixed, or a capture artefact, shown by evidence (the capture method, the canvas rect and the pixel check). `top.png` is the reference.

14. **Row 1 clearance (D-S97-7).** **Given** the same web build **When** row 1 and the register panel are drawn **Then** row 1 no longer crowds the `reg` box top.

15. **Sky row (D-S97-8, D-S97-13, D-S97-14).** **Given** row 1 with a normal sky comment **When** it is drawn **Then** it is plain INK (D-S97-13, not dithered), and the inverted warning tell (Story 6.5, D-S65-8) keeps at least 1 px of BG under the title bar and shows all its glyphs (D-S97-14).

16. **Sky comments (D-S97-8).** **Given** the tutorial is open **When** row 1 shows its comment **Then** it reads `// TODO: write the tests first`; **and given** a practice run **Then** it reads `// sandbox: nothing here ships`; every other fight keeps today's text. Both lines are ASCII, at most 80 characters, and live in `data/text/sky_comments.tres` (`TextSkyComments`), and `validate()` / `all_text()` cover them.

17. **Export-safe defaults (D-S97-8).** **Given** any new `@export` Packed*Array default **When** it is declared **Then** it is `PackedStringArray()` (or the typed equivalent), never `[]`, and `tests/unit/test_export_defaults.gd` passes.

18. **Tests updated and added.** **Given** the Story 8.2 / 9.1 tests that assert checklist and prompt positions inside the play area **When** the suite runs **Then** they assert the new console layout; new tests cover AC 1-5, 10-11, 15-16 (pure geometry and data; no pixel reads in headless).

19. **Change-set verification.** **Given** the change set **When** it is verified **Then** the full GUT suite passes as CI runs it (`--headless --import` first), `game/tools/check_guards.sh` passes, and tests that depend on boss attack picks seed the RNG.

20. **Exported web build check (mandatory).** **Given** the change set **When** the story is called done **Then** a real exported web build was looked at (steps in Task 8): the tutorial (both pages), practice, fight 0, the segfault sky tell, and row 0 at 1280x720; screenshot paths are recorded in the Dev Agent Record, and one human glance note (H-S97-1) is left for Tiziano.

21. **Docs (D-S97-1, D-054).** **Given** the planning files **When** this story closes **Then** NFR8 names the 75% scenery dither, the GDD art/palette and HUD sections match the shipped layout, the decision-log row D-054 is present, and deferred-work.md holds the duck-bubble wrap item (all already written at story creation; verify at dev end).

22. **Status bookkeeping.** **Given** the story **When** its status changes **Then** it is set with the Edit tool (never `sed -i`), and `sprint-status.yaml` carries `9-7-arena-readability` with the same status.

## Tasks / Subtasks

- [x] Task 1: dither texture in core and the water glyph (AC: 1, 2, 5)
  - [x] 1.1 Add the 75% BG dither texture builder to `game/src/core/` (a static `dither_texture()` on `GlyphFont`, or a new small core helper). Build it once (static cache). Pattern: one INK (transparent) pixel per 2x2 block, `x % 2 == 0 and y % 2 == 0`, BG elsewhere. The prototype used an 8x8 texture over the 16-px tile (`proto_dither()` in `arena.gd`), which gives the reference look (`02-tut1.png`).
  - [x] 1.2 Move the 50% checker (`RegisterPanel.checker_texture()`, `game/src/ui/hud/register_panel.gd` ~line 266) to the same core place, or keep it and let both call one core builder. RegisterPanel behaviour and its tests stay identical.
  - [x] 1.3 `Arena.WATER` `"~"` -> `"="`; replace every `~` in `Arena.LAYOUT` (lines 53-70 of `arena.gd`). Grep `~` in `game/tests` and `_bmad-output` (a test or doc may name the glyph; only fix references to the water glyph, not unrelated text).

- [x] Task 2: halo and scenery hiding in the arena (AC: 3, 4, 5)
  - [x] 2.1 In `game/src/arena/arena.gd` add a pure static `scenery_hidden(cell_centre, player_px, boss_centre, boss_radius, practice_px, decoy_px) -> bool` (or equivalent) with the four radii 24 / boss radius + 20 / 32 / 24. Trees and the label return false before the halo test.
  - [x] 2.2 `_draw()` draws scenery (GRASS, ROCK, WATER) with `GlyphFont.draw_cell(... Palette.INK ...)` then the dither rect over the cell, only when not hidden; trees and the label draw as today.
  - [x] 2.3 Keep the last hidden-cell set (a `PackedInt32Array` or `Dictionary`) in the Arena; in `_process` (or the existing per-frame hook) recompute it and call `queue_redraw()` only when it changes. Do not copy the prototype's unconditional `_process` redraw.
  - [x] 2.4 Confirm `src/arena/` has no reference to `ui/` or `presentation/` after the change (`grep -rn "presentation\|ui/" game/src/arena`).

- [x] Task 3: tutorial checklist and prompt in the console (AC: 6, 7, 8, 9)
  - [x] 3.1 Move the checklist rows, the cursor and the prompt out of `TutorialChecklistView` (`game/src/presentation/tutorial_checklist_view.gd`) into a HUD-side node drawn next to `LogPanel` (`game/src/ui/hud/log_panel.gd`). Preferred shape (brief): a console/tutorial node on the HUD CanvasLayer, fed by `TutorialScreen` (`game/src/ui/screens/tutorial/tutorial_screen.gd`) through main.gd wiring. No static vars shared across nodes (the prototype's `LogPanel.proto_tutorial` / `proto_rows` must not ship).
  - [x] 3.2 Left block: lines 0-5 = HUD rows 39-44 (`Hud.LOG` is `Rect2i(0, 38, 80, 7)`, lines start at row 39). Rows at col 2, cursor `>` at col 0 on the current row.
  - [x] 3.3 Right block: prompt from col 24, word-wrap to 56 columns (use the existing word-wrap helpers in `tutorial_checklist_view.gd` / `register_panel.gd` where they fit; add a test on the widest prompt line). Log lines under the prompt rows, as many as fit (the last lines, newest at the bottom).
  - [x] 3.4 Keep the skip and pause hints top-right of the arena with backing, and the completion rows (`done_lines()`) in the arena bottom band, clear of the spawn and the dummy (Story 9.1, 618b). Positions change only where AC 6-8 require.
  - [x] 3.5 `LogPanel` gets a proper "right block" layout (a column origin and a line limit passed in or set by the HUD), not static vars.

- [x] Task 4: practice readout on the console header and the top bar (AC: 10, 11, 12)
  - [x] 4.1 `game/src/presentation/practice_frame_counter.gd`: stop drawing the text in the arena (keep `lines_for`, `frames_since`, `_process`, `set_active`). The text goes to HUD row 38: the counter's lines (`frames N`, the key hint) are drawn by `HudFrame` (`game/src/ui/hud/hud_frame.gd`) right-aligned 2 columns from the edge (cell x = `Hud.COLS - 2 - text.length()`), with a BG `draw_rect` backing under the text. Only when `Game.practice_run`.
  - [x] 4.2 `HudFrame._draw()`: row 0 becomes a full-width INK `draw_rect` (`Hud.COLS * GlyphFont.CELL` wide, one cell tall), text in BG (`hud.top_bar_text()` or `Hud.TOP_BAR`).
  - [x] 4.3 `game/src/ui/hud/hp_readout.gd`: draw the HP text in BG on the bar (`Palette.BG`), position unchanged. Its `cell_for` test stays green.
  - [x] 4.4 Check AC 12: during the one-frame crit inversion and Breakpoint dither the bar stays readable (ScreenFX acts on the whole screen; accepted). Note the result in the Dev Agent Record.

- [x] Task 5: row-0 clipping and row-1 crowding (AC: 13, 14)
  - [x] 5.1 Reproduce: export the web build (Task 6 steps), capture at 1280x720 (`top.png` shows the bug). Record the canvas CSS rect and `devicePixelRatio`, and a row-0 crop at native size.
  - [x] 5.2 Test these hypotheses in order and record the evidence for each (the brief says the font metrics look right: lineHeight 8, base 7, yoffset 0):
    - (a) baseline: `GlyphFont.draw_at` puts the baseline at `top + FONT.get_ascent(size)`; at size 8 check the value the engine returns; a wrong ascent shifts every row, not only row 0, so compare row 1 and row 2 in the same capture.
    - (b) canvas size / offset in the web template (`game/export` template or the exported `index.html`, canvas margins, letterboxing of `scale_mode="integer"` at 1280x720: the canvas offset can be fractional, so a top row may be clipped by the canvas edge).
    - (c) capture artefact: the Playwright screenshot (`capture.js`) crop or resize, or a DPR mismatch. Check by a DOM / canvas readback at the same size, not by eye.
  - [x] 5.3 Fix the real cause (one place). If it is an artefact, say so with the evidence and change nothing in the game (AC 13 allows that verdict).
  - [x] 5.4 Row 1 vs the `reg` box: after 5.3, check the crowding; fix by layout only (HUD constants in `hud.gd`), keeping the register rect `Rect2i(0, 2, 12, 20)`. Update `test_hud_layout.gd` if a constant moves.

- [x] Task 6: sky comments (AC: 15, 16, 17)
  - [x] 6.1 `data/text/sky_comments.tres`: add `tutorial` and `practice` String fields (`TextSkyComments` in `game/src/ui/text/text_sky_comments.gd`), with the two texts from AC 16. Extend `all_text()` so validation and the font-coverage audit cover them. Keep `@export` defaults as `""` (String) and any array as `PackedStringArray()`.
  - [x] 6.2 `game/src/ui/hud/hud.gd`: `Hud.sky_for` / `Hud.sky_text()` choose the tutorial or practice line when the fight context says so (the tutorial and practice states are known to main.gd / Hud; pick the smallest wiring and document it). Keep `SKY`, `SKY_NULL_POINTER`, `SKY_SEGFAULT` working.
  - [x] 6.3 `hud_frame.gd`: row 1 normal comment is drawn in plain INK (D-S97-13, the checker was dropped); the `warning_tell_on` branch (inverted ink run) is unchanged.

- [x] Task 7: tests (AC: 2, 5, 15, 16, 17, 18, 19)
  - [x] 7.1 Update `game/tests/unit/test_tutorial_screen.gd` tests that assert the checklist inside the play area (`test_every_row_fits_the_play_area_and_clears_the_dummy`, `test_hint_rows_and_hold_bar_clear_the_checklist`, `test_checklist_backings_overlap_neighbours_so_draw_is_two_pass`, `test_hint_rows_clear_the_frame_title`, `test_completion_rows_clear_the_spawn_and_the_dummy`, `test_view_draws_only_while_fed`) to the console layout; keep the hint and completion assertions that still apply.
  - [x] 7.2 `game/tests/unit/test_arena_layout.gd` and `test_glyph_palette.gd`: water is `=`; no `~` in LAYOUT; the dither colours are only INK / BG (`GlyphFont.is_allowed_color`).
  - [x] 7.3 New `game/tests/unit/test_arena_readability.gd` (use `tests/support/isolation.gd` TestIsolation): halo predicate at the four radii (inside, on, outside), trees and label never hidden, decoy absent means no decoy radius, practice target only when present; the hidden-set diff triggers redraw only on change (count `queue_redraw` via a seam or compare the set).
  - [x] 7.4 `test_hud_layout.gd` / `test_log_panel.gd`: console left block rows 39-44, prompt from col 24 wrapped to 56, row 0 bar cells and HpReadout colour BG, practice readout row 38 right-aligned.
  - [x] 7.5 `test_sky_comments` (audit) and `test_export_defaults.gd`: the new strings are ASCII, <= 80 columns, and the source scan finds no `= []` Packed default.
  - [x] 7.6 Seed the RNG in any new test that depends on boss attack picks (none expected for the geometry tests).
  - [x] 7.7 Run the GUT suite the CI way (below) and `game/tools/check_guards.sh`; record counts in the Dev Agent Record.

- [x] Task 8: exported web build check, mandatory (AC: 13, 14, 20)
  - [x] 8.1 `rm -rf game/.godot/exported` (a stale converted `.res` once emptied the tutorial checklist), then export: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --export-debug "Web" <scratch>/web/index.html`.
  - [x] 8.2 Serve: `python3 -m http.server 8765 --bind 127.0.0.1` from the export folder. Stop the server after use.
  - [x] 8.3 Capture with `.claude/skills/devlog/scripts/capture.js` (its header documents the steps format; needs `npm i --prefix <scratch>/pw playwright-core@1.56`, run with `NODE_PATH=<scratch>/pw/node_modules node ...`). Scratch dir: `/Users/tizianobasile/workspace/me/gameoff-wt/s97/scratch/`.
  - [x] 8.4 `?debug` keys: F2/F3/F4 fights 0/1/2, Shift+F2 practice target. A fresh profile lands in the tutorial after two Enter presses past the intro (wait 4000, Enter, wait 2500, Enter). The title-menu practice (not Shift+F2) is what sets `Game.practice_run`.
  - [x] 8.5 Look at, and record the paths of: the tutorial (two pages), practice, fight 0 (scenery halo around `@`), fight 1 or the segfault page (sky tell), and row 0 at 1280x720 (crop). Read the screenshots before claiming done.
  - [x] 8.6 Leave human check H-S97-1 (Tiziano's glance at the same pages on his browser) open in the Dev Agent Record.

- [x] Task 9: bookkeeping (AC: 21, 22)
  - [x] 9.1 Verify the doc edits made at story creation (epics.md NFR8 and Epic 9 intro, GDD art/palette and HUD sections, decision-log D-054, deferred-work.md "Story 9.7", sprint-status line).
  - [x] 9.2 At dev end: set Status with the Edit tool (`review` only at dev end, per the epic workflow); sprint-status to match.

## Dev Notes

### Verified facts (read on 2026-11-17, main 5da7435; re-verify line numbers before editing)

- `game/src/arena/arena.gd` (420 lines): `const WATER := "~"` (line 15), `const GRASS := "\""`, `ROCK := "o"`, `TREE := "♣"`, `LABEL := "stack frame 0x03"`, `LABEL_COL := 2`, `ORIGIN_CELL := Vector2i(16, 2)`, `GLYPH_SCALE := 2` (tile 16 px). `LAYOUT` at lines 53-70 (32x18 tiles). `PRACTICE_TARGET_PX` (arena-local), `SPAWN_PX`, `TUTORIAL_DUMMY_PX`. `_draw()` at line 397 draws every non-space cell with `GlyphFont.draw_cell(self, Vector2i(col, row), ch, Palette.INK, GLYPH_SCALE)`. `_ready()` (line 392) sets `position = ORIGIN_CELL * CELL` and calls `queue_redraw()` once. `aim_point()` (line 378) already reads the live decoy (`ghost_echo.decoy.is_live()`, `position_px`). Player: `player.position_px`. Boss: `boss.body_center_px`, `boss.body_radius_px()`, `boss` is null outside a fight. `play_area()` is 512x288 (DC4).
- `game/src/core/glyph_font.gd`: `CELL := 8`; `draw_cell`, `draw_at` (baseline = `top.y + FONT.get_ascent(size)`), `cell_to_px`, `text_width`, `is_allowed_color` (INK or BG only, else logged and drawn INK). Lives in `core/` (DC4a, Story 1.5 design call; `arena/` may use it).
- `game/src/ui/hud/hud.gd` (217 lines): `COLS := 80`, `ROWS := 45`, `REGISTER := Rect2i(0, 2, 12, 20)`, `DUCK := Rect2i(0, 22, 12, 16)`, `LINE_NUMBERS := Rect2i(13, 2, 3, 36)`, `ARENA := Rect2i(16, 2, 64, 36)`, `LOG := Rect2i(0, 38, 80, 7)` (row 38 header, rows 39-44 six lines), `LOG_LINES := 6`, `TOP_BAR := "void fightPlaceholder() // hp ---"`, `SKY` / `SKY_NULL_POINTER` / `SKY_SEGFAULT` (static vars reading `SKY_COMMENTS`, line 20-33), `WARNING_TELL_TEXT := "SIGSEGV incoming"`, `top_bar_text()` (line 93), `sky_text()` (line 101), `warning_tell_on(b)` (line 109), `LOG_HEADER` (the `── console ──` rule, line 40), `boss_header(signature, hp)` (line 159), `grid_toggle_allowed` (debug grid).
- `game/src/ui/hud/hud_frame.gd` (41 lines): draws row 0 via `_text(Vector2i(0,0), hud.top_bar_text())` (line 15) with INK at 1x; the warning tell inverted run; the `│` separator at `Hud.SEPARATOR_COL` (15); `_text(Hud.LOG.position, Hud.LOG_HEADER)`. `_text()` = `GlyphFont.draw_cell(self, cell, text, Palette.INK, SCALE)`, `SCALE := 1`.
- `game/src/ui/hud/hp_readout.gd` (38 lines): `current_text()`, `cell_for(text)`, `_draw()` draws INK at `SCALE`. It sits on the HUD (`hud.add_child(hp_readout)` in main.gd line ~178).
- `game/src/ui/hud/log_panel.gd` (139 lines): `SCALE := 1`; `line_cell(index)` = `Vector2i(Hud.LOG.position.x, Hud.LOG.position.y + 1 + index)`; `_draw()` (line 114) draws the ring lines and the dithered `// miss` lines (`RegisterPanel.checker_texture()`, rect per line). `_enter_tree` / `_exit_tree` connect EventBus signals.
- `game/src/ui/hud/register_panel.gd` (274 lines): `checker_texture()` (line 266, static `_checker`), 8x8 50% BG checker. Used by greyed/faded cells (`_draw_content`, line 126) and by LogPanel's dithered lines.
- `game/src/presentation/tutorial_checklist_view.gd` (180 lines): static layout helpers (`row_top_left(i)`, `prompt_top_left`, `hint_row_top_left`, `done_top_left`, `hint_area`, `backing_rect`, `fits_play_area`), `show_state(lines, current, prompt, hints, hold, done)`, `text_rows()` (line 143; the list `_draw` consumes), `_draw()` (line 169). `TEST_SCALE`, `PROMPT_SCALE`, `CURSOR` constants. This node is a child of the arena (`arena.add_child(tutorial_view)`, main.gd line 122).
- `game/src/presentation/practice_frame_counter.gd` (53 lines): `lines_for(frames)` -> 2 lines (`frames N` and the key hint), `frames_since(start, frame)`, `row_top_left(centre, text, i)`, `_draw()` (line 48) draws in the arena; `active` set by `set_active`. Node added at main.gd line ~151.
- `game/src/presentation/player_view.gd` (60 lines) and `game/src/presentation/boss_view.gd` (660 lines): the `@` and boss glyphs. They draw above the arena (Entities layer). They need no change unless a glyph colour or a halo cue is added (none planned).
- `game/src/presentation/screen_fx.gd` (47 lines) and its shader: `base_size = Vector2(Const.BASE_RES)`; invert keeps INK/BG only; dither checker; drives the whole-screen crit inversion and Breakpoint dither. Read-only from this story.
- `game/src/ui/screens/tutorial/tutorial_screen.gd` (247 lines): feeds steps from the arena and calls `TutorialChecklistView.show_state` / `clear`. The new console node is fed from here as well.
- `game/src/main/main.gd` (501 lines): `LAYER_ORDER` (Arena, Entities, Particles, Hud, Pause, ScreenFX; AD-07 order test exists), `hud` at line ~171, `hp_readout` at ~178, `border` at ~226, `pause_layer` at ~182, `fx` CanvasLayer at ~186 (ScreenFX), `screens` at ~195, `practice_counter` at ~151.
- `game/src/ui/text/text_sky_comments.gd` (29 lines): `TextSkyComments` (`class_name`, `extends Def`), exports `default_comment`, `null_pointer`, `segfault` (all `String`), `MAX_CHARS := 80`, `validate()`, `all_text()`.
- `data/text/sky_comments.tres`: `default_comment = "// TODO: this should terminate"`, `null_pointer = "// FIXME: who owns this pointer?"`, `segfault = "// HACK: do not read past this line"`.
- Current prototype behaviour, for reference only (`gameoff-wt/s97/prototype.diff`): `arena.gd` `_process` queue_redraw (do not ship), `proto_dither()` 8x8 texture over the 16-px tile, `_proto_in_halo()`, `LogPanel.proto_tutorial` / `proto_rows` static vars (do not ship), `HudFrame._process` queue_redraw (do not ship), `PracticeFrameCounter._draw` emptied, `HpReadout` in BG, the console header practice readout. The prototype's line 1 prompt overflowed; the wrap rule (AC 7) fixes it.

### Design calls (Story 9.7, approved by Tiziano through the coordinator brief)

- **[design call] D-S97-1 Scenery dither 75%.** Grass, rock and water are drawn with a 75% BG dither (one INK pixel kept per 2x2 block, base-pixel space, base 640x360). Tiziano judged the 50% checker too weak. Trees and the label stay full INK. NFR8 gains the 75% scenery dither (done at creation).
- **[design call] D-S97-2 Water `~` -> `=`.** The font has no `≈`. Every `~` in `Arena.LAYOUT` and any reference to the water glyph changes.
- **[design call] D-S97-3 Actor halo.** A scenery cell is hidden within 24 px of the player centre, within boss radius + 20 px of the boss body centre, within 32 px of the practice target, and within 24 px of a live Ghost Echo decoy. Recomputed each frame, redraw only on change. DC4a holds: the dither builder lives in `src/core/`.
- **[design call] D-S97-4 Tutorial text in the console.** Checklist (six rows, `>` cursor at column 0, rows at column 2) in console lines 0-5 (HUD rows 39-44, left block). Current prompt in the right block from column 24, word-wrapped to 56 columns. Log lines under the prompt in the right block. Skip and pause hints stay top-right in the arena with backing; the 2x completion rows stay in the arena bottom band. The HUD side draws the text (CanvasLayer), fed by the TUTORIAL screen; LogPanel gets a real right-block layout, not static vars.
- **[design call] D-S97-5 Practice readout on the console header.** `frames N` and the practice key hint on HUD row 38, right-aligned 2 columns from the edge, BG backing over the rule. Nothing in the arena.
- **[design call] D-S97-6 Row 0 is an inverted title bar.** Full-width INK bar, BG text: boss signature and the player HpReadout. Checked during the one-frame full-screen crit inversion and the Breakpoint dither; ScreenFX acting on the whole screen is accepted.
- **[design call] D-S97-7 Row-0 clipping.** In the web build at 1280x720 the row-0 glyphs look shifted up and their top is clipped (`top.png`; also in Tiziano's original screenshot), and row 1 crowds the `reg` box. Font metrics look right. Find the real cause (baseline from `FONT.get_ascent`, canvas size or offset in the web template, stretch) and fix it so row 0 is fully visible in the exported web build. If it is a capture artefact, say so with evidence.
- **[design call] D-S97-8 Sky comment (row 1).** (Dither part superseded by D-S97-13.) Tutorial: `// TODO: write the tests first`. Practice: `// sandbox: nothing here ships`. Today both show the Infinite Loop line through `default_comment`.
- **[design call] D-S97-9 (dev) PracticeFrameCounter is a HUD child.** The counter node (presentation/) keeps its frame logic and now lives on the HUD (Main: `hud.add_child(practice_counter)`), drawing `header_text()` on row 38 over a BG backing; HudFrame does not redraw every frame for it (the counter already redraws itself while active).
- **[design call] D-S97-10 (dev) The prompt is one paragraph.** `TutorialConsole.wrap_prompt` joins the step's one or two prompt rows and word-wraps them to 56 columns (`DuckBubble.wrap`): every step fits in 1-3 lines, so at least 3 log lines always show under it.
- **[design call] D-S97-11 (dev) Rows 0-1 pixel layout (the D-S97-7 fix).** The font has no leading (caps start on the cell's top pixel row, row 7 is the descender), so the title bar is 9 px tall (row 0 plus one pixel), its text and the HpReadout are drawn 1 px down (an INK row above the caps, descenders inside the bar); the sky row text is 1 px down; the SIGSEGV tell rect is cap height (7 px) so it never paints row 2's first pixel row. (The 9-px bar and the 1-px text offset are superseded by D-S97-14.) (`01`, the arena tree ring and label on the layer below). Constants `Hud.TITLE_BAR_PX`, `TITLE_TEXT_DY`, `SKY_TEXT_DY`, `TELL_HEIGHT_PX`.
- **[design call] D-S97-13 (coordinator, supersedes the dither part of D-S97-8 and D-S97-12) Sky comment is plain INK.** In the exported build the 1x text under the 50% checker was unreadable. The sky comment on row 1 is drawn in plain INK, not dithered; the per-context tutorial/practice comments stay. `Dither.checker` loses its odd phase.
- **[design call] D-S97-14 (coordinator, supersedes the layout of D-S97-11) SIGSEGV tell clearance.** At least 1 px of BG between the row-0 title bar and the inverted tell rect, and every tell glyph fully visible, without covering row 2. Exact numbers (16 px for rows 0-1): title bar 8 px (`Hud.TITLE_BAR_PX` 8, `TITLE_TEXT_DY` 0, the whole 8-px glyph cell inside the bar), BG gap on pixel row y = 8, sky text and tell rect from y = 9 (`SKY_TEXT_DY` 1), tell rect 7 px tall (y 9..15, `TELL_HEIGHT_PX` 7), ending on row 2's top edge. A lowercase `g` needs an 8th glyph row that does not fit, so the tell text is all caps: `SIGSEGV INCOMING` (`Hud.WARNING_TELL_TEXT`). The INK margin above the title caps (D-S97-11) is given up for it.
- **[design call] D-S97-12 (dev) Sky dither phase. SUPERSEDED by D-S97-13 (the dither is gone).** The 1-px `/` strokes have a single x + y parity, and the default checker phase erased every `//` of the sky comments in the web build; the sky row uses `Dither.checker(true)` (the other phase), which keeps them.
- **Out of scope (deferred, deferred-work.md "Story 9.7"):** the duck bubble wraps into the narrow columns 0-11 under the register box, and one hint is cut ("the rest are in code review" shows as "th").

### Architecture and rule constraints

- **DC4a:** `src/arena/` must not reference `presentation/` or `ui/`. `GlyphFont` and the dither builder live in `src/core/glyph_font.gd` (or a new core helper). The 1-5 story chose `core/` for exactly this reason.
- **AD-07 (rendering):** glyphs via `draw_char` / `draw_string` in `_draw()`; no `Label` per glyph; no sprites for glyphs. Layers `Arena -> Entities -> Particles -> HUD -> ScreenFX` (main.gd `LAYER_ORDER`, order test). The dither is a texture rect over a cell, the one allowed extra; ScreenFX stays driven only by `JuiceDirector`. Shake via `Camera2D.offset`. `Palette` constants only.
- **NFR8 (readability):** palette INK `#E8E8E8` on BG `#101014`; inversion, the 50% dither and now the 75% scenery dither are the only extra states; red `#FF4040` only for warnings (Breakpoint, SIGSEGV); one 8x8 monospace pixel font on a 16-px grid (HUD at 1x on the 8-px grid, world at 2x). `test_glyph_palette.gd` enforces INK/BG for glyphs.
- **Simulation rule (AD-01 / 2.x):** halo and hiding are presentation only. No sim state changes; replays are unchanged.
- **Export rule:** `@export var x: PackedStringArray = []` exports empty in the web build (hotfix note, `test_export_defaults.gd`). Use `PackedStringArray()`.

### Engineering rules (coordinator brief, verbatim)

- `godot` is not on PATH: `/Applications/Godot.app/Contents/MacOS/Godot`. Tests: GUT (see README / CI in .github/workflows/ci.yml for the exact command). Guards: `game/tools/check_guards.sh`.
- New tests use `tests/support/isolation.gd` (TestIsolation). Seed RNG in tests that depend on boss attack picks.
- Set the story status with the Edit tool, not `sed -i`.
- **You must look at a real exported web build** before calling it done (headless GUT cannot see export bugs). Before exporting run `rm -rf game/.godot/exported` (a stale converted .res once emptied the tutorial checklist). Export: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --export-debug "Web" <scratch>/web/index.html`; serve with `python3 -m http.server 8765 --bind 127.0.0.1` from that folder; capture with `.claude/skills/devlog/scripts/capture.js` (header documents the steps format; needs `npm i --prefix <scratch>/pw playwright-core@1.56`, run with `NODE_PATH=<scratch>/pw/node_modules node ...`). `?debug` keys: F2/F3/F4 fights 0/1/2, Shift+F2 practice target. A fresh profile lands in the tutorial after two Enter presses past the intro (see steps in the prototype session: wait 4000, Enter, wait 2500, Enter). The title-menu practice (not Shift+F2) is what sets Game.practice_run. Use the scratch dir `/Users/tizianobasile/workspace/me/gameoff-wt/s97/scratch/` and stop the server after.
- Keep 60 fps: no per-frame full redraw of the scenery.

### How to run the suite (CI way)

- `cd` to the worktree; `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import` first, then the GUT command from `.github/workflows/ci.yml` (line ~91): `"$GODOT_BIN" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`, and check the log for failure markers as CI does. Shuffled order: `WILDSHIFT_GUT_ORDER=shuffle:<seed>` (Story 9.5). Record the counts.

### Test changes and guards

- Position tests in `test_tutorial_screen.gd` (lines ~150-270) assert the checklist inside `Arena.play_area()`; after AC 6-8 the checklist is outside the arena, so those assertions move to the console rectangles (rows 39-44, cols 0-79).
- `test_export_defaults.gd` scans `res://src` and `res://data`; the new `tutorial` and `practice` strings are plain `String` exports and pass, but any new Packed default must be `PackedStringArray()`.
- `test_log_panel.gd`: the miss and damage lines keep their existing assertions; the right-block layout is additive.

### Project Structure Notes

- Likely new files: `game/tests/unit/test_arena_readability.gd` (+ `.uid` on first run). A new core helper, if chosen, is `game/src/core/dither.gd` (+ `.uid`). No new files under `_bmad/` or `.claude/`.
- Touched source (expected): `game/src/arena/arena.gd`, `game/src/core/glyph_font.gd` (or new core helper), `game/src/ui/hud/{hud.gd,hud_frame.gd,log_panel.gd,hp_readout.gd,register_panel.gd}`, `game/src/presentation/{tutorial_checklist_view.gd,practice_frame_counter.gd}` (`player_view.gd` and `boss_view.gd` only if a glyph cue is needed), `game/src/ui/screens/tutorial/tutorial_screen.gd`, `game/src/main/main.gd` (wiring), `game/src/ui/text/text_sky_comments.gd`, `game/data/text/sky_comments.tres` (paths relative to the repo root; the game project is `game/`).

### Open questions (defaults chosen, no elicitation)

1. Tutorial console node: a new HUD child (`ConsoleTutorial`-style) vs LogPanel owning both blocks. Default: a separate HUD-side node next to LogPanel, fed by TutorialScreen (brief preference).
2. Sky comment selection for tutorial and practice: default: a context flag Hud reads (the tutorial and practice state live in main.gd / Game); keep the three existing static accessors.
3. Row-0 root cause: unknown until Task 5. Default: fix the real cause in one place; if the cause is a capture artefact, change nothing in the game and record the evidence.
4. Scenery hide radius uses the boss body radius from `boss.body_radius_px()`; no change to boss hurtbox or the sim.

### References

- [Source: gameoff-wt/s97/brief.md] (decisions D-S97-1..8, engineering rules, export procedure)
- [Source: gameoff-wt/s97/prototype.diff] (reference only; do not apply as-is)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 9.7: Arena Readability] (line ~1916) and NFR8 (line ~145), AD-07 (line ~194)
- [Source: _bmad-output/game-architecture.md#Rendering (AD-07)] (line ~239)
- [Source: _bmad-output/implementation-artifacts/1-5-the-clearing-arena-and-ide-hud-frame.md] (DC4a, the `core/` placement of GlyphFont)
- [Source: _bmad-output/implementation-artifacts/8-2-guided-tutorial-test-suite.md and 9-1-input-grace-and-tutorial-polish.md] (checklist and hint rules this story moves)
- [Source: _bmad-output/implementation-artifacts/6-5-sigsegv-register-corruption.md] (D-S65-8 warning tell)
- [Source: _bmad-output/implementation-artifacts/9-6-save-and-pad-robustness.md] (format reference)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md, row D-054]

## Project Context Rules

- Main is protected: work on `story/9-7-arena-readability` in the worktree `gameoff-wt/9-7`; PR base `main`; never commit to main; no force push; no `gh pr merge`.
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). Guards: `game/tools/check_guards.sh`.
- Set story status with the Edit tool. Never use the Fable model.
- Every new user-facing string that lives in a `.tres` is audited text (ASCII, <= 80 columns for sky comments, <= 64 columns for prompts at 1x in the tutorial).
- Arena is a simulation folder: it may not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.

## Dev Agent Record

### Agent Model Used

Claude (gds-create-story, unattended, 2026-11-17); implementation: Claude Opus (gds-dev-story, unattended, 2026-11-17)

### Debug Log References

- Baseline suite on 5da7435: 1939 passing. Final: 1956 tests, 1956 passing, 152163 asserts, "All tests passed", no CI failure marker; shuffled order (`WILDSHIFT_GUT_ORDER=shuffle:977`) 1956/1956; `game/tools/check_guards.sh` OK; import log clean.
- Web build: `rm -rf game/.godot/exported`, `--export-debug "Web"` to `gameoff-wt/s97/scratch/web/`, served on 127.0.0.1:8765 (stopped after), captured with a copy of the devlog `capture.js` plus a canvas-geometry step (`gameoff-wt/s97/scratch/tools/cap.js`).

### Implementation Plan

- Core: `src/core/dither.gd` (`Dither.checker(odd)`, `Dither.scenery()`, pure `checker_paints` / `scenery_paints`); `RegisterPanel.checker_texture()` returns `Dither.checker()` (same texture, tests unchanged).
- Arena: water `=`; scenery (grass, rock, water) drawn INK then the 75% dither rect over the 16-px tile; halo helpers `in_halo`, `hidden_cells_for` (pure, row-major indices over a static scenery index), `current_hidden_cells()` reads the player, boss body, practice target and live decoy; `_process` calls `refresh_hidden_cells()`, which queues a redraw only when the set changed. No ui/ or presentation/ reference (guard test scans class names of both folders, code only).
- HUD: `HudFrame` draws the 8-px INK title bar with BG text, the sky row in plain INK (D-S97-13), the tell cap-height; `HpReadout` BG; `PracticeFrameCounter` on the HUD, right-aligned on row 38 with a BG backing; `Hud.sky_context` + `Hud.sky_for_context` (Main sets it with `sky_context_for(in_tutorial, practice_fight)`); `TextSkyComments.tutorial` / `practice` (String exports, in `all_text()`).
- Tutorial: new `src/ui/hud/tutorial_console.gd` (HUD child, fed by TutorialScreen with the checklist, the cursor and the prompt; redraws only on change) drives `LogPanel.set_block(24, prompt_lines, 6 - prompt_lines)` / `reset_block()`; `TutorialChecklistView` keeps only the hints (top-right, backed) and the 2x completion rows (`show_state(hints, hold, done)`).

### Completion Notes List

- Story created unattended (ultimate context engine analysis completed, comprehensive developer guide created). No elicitation.
- All ACs implemented. New tests: `test_arena_readability.gd` (14 tests: dither patterns, shared checker, DC4a scan, water glyph, halo radii inclusive/exclusive, trees and label never hidden, live actors incl. practice target, redraw only on change, title bar and HP readout, rows 0-1 pixel layout, practice header, practice counter on the HUD, sky comments and contexts, sky dither and its slash-keeping phase). `test_tutorial_screen.gd`: the in-arena checklist/prompt position tests replaced by console-layout tests (left block rows 39-44, prompt from col 24 wrapped to 56, never past col 79, no word lost), log right block and its reset, the screen feeding the console and clearing it, hints/completion only in the arena view. `test_glyph_palette.gd` covers the new sources.
- **D-S97-7 finding (root cause, evidence).** Not an engine baseline, canvas offset or stretch bug: (a) the font metrics in the engine are ascent 7 / descent 1 / height 8 at size 8 and the glyph offset is (0, -7), so `top + ascent` puts the glyph top exactly on the cell top, for every row alike; (b) in the exported web build at 1280x720 the canvas is at (0,0), 1280x720 CSS and backing store, `devicePixelRatio` 1, body margin 0 (exact 2x integer scale, no letterbox); (c) a per-pixel-row probe of the screenshot shows every glyph pixel row of row 0 present (rows 0-13 at 2x before the fix). The cause is the font art itself: 75 of the 112 glyphs start on the cell's top pixel row and row 7 is the descender, so there is no leading. Row-0 text therefore sat flush against the canvas top (it read as "shifted up, top clipped"; in a non-integer screenshot such as the 1024x576 `before-tutorial.png` the first pixel row can also lose half its height), and the prototype's 8-px inverted bar ended right on the sky row's cap tops, fusing them ("row 1 crowds"). Fixed by D-S97-11: after the fix the probe shows an INK margin row above the caps (screen rows 0-1), glyph rows at 2-15, the descender row inside the bar (16-17), the sky text from row 18 (`final/11-top-two-rows-4x.png`).
- AC 12 (effects): the Breakpoint dither was captured (`final/09-...`): the bar becomes a checkered INK bar and its BG text reads like the rest of the screen. The one-frame crit inversion was not caught in a capture; the ScreenFX shader swaps INK and BG over the whole screen, so the bar turns BG with INK text (accepted by D-S97-6).
- Web check observations fixed during the story: the default checker phase erased every `//` of the sky comments (D-S97-12); the 8-px sky dither rect would have painted BG over the arena's tree-ring tops on row 2 (now cap height, D-S97-11). Remaining low items (tell reads as a tab of the bar, `g` tail of the tell cut, dotted 1x sky text, `/* test */` wider than its halo) are in deferred-work.md "Story 9.7" for H-S97-1.
- Screenshots (exported web build, 1280x720, DPR 1), in `gameoff-wt/s97/final/`: `01-tutorial-page1.png`, `02-tutorial-page3-wrapped-prompt.png`, `03-tutorial-log-right-block.png` (log lines under the prompt, dithered resisted line and CRITICAL), `04-practice-title-menu.png` (title [P] practice, Game.practice_run), `05-practice-console-header-crop.png`, `06-fight0-infinite-loop.png` (F2, halo around `@` and inside the loop), `07-segfault.png` (F4), `08-segfault-sigsegv-tell.png` (Shift+F6 phase 2, tell on row 1), `09-segfault-breakpoint-dither.png`, `10-top-two-rows-1280.png`, `11-top-two-rows-4x.png`, `12-top-two-rows-sigsegv-tell-4x.png`.
- **H-S97-1 (open, Tiziano, real browser):** open the tutorial (both pages), practice and fight 0 in the web build at 1280x720; confirm the actors stand out, the console text reads, row 0 is fully visible, and judge the dotted sky comment and the SIGSEGV tell joined to the title bar.

### File List

- `_bmad-output/implementation-artifacts/9-7-arena-readability.md` (new, this story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (`9-7-arena-readability: review`)
- `_bmad-output/implementation-artifacts/deferred-work.md` ("Story 9.7" items)
- `_bmad-output/planning-artifacts/epics.md` (Story 9.7 section, Epic 9 intro, NFR8, FR56 and Story 1.5 AC water glyph)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md` (D-054, D-S97-1..12)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` (art/palette, Clearing water, tutorial and HUD sections)
- `game/src/core/dither.gd` (+ `.uid`, new)
- `game/src/ui/hud/tutorial_console.gd` (+ `.uid`, new)
- `game/src/arena/arena.gd`
- `game/src/main/main.gd`
- `game/src/presentation/practice_frame_counter.gd`
- `game/src/presentation/tutorial_checklist_view.gd`
- `game/src/ui/hud/hp_readout.gd`
- `game/src/ui/hud/hud.gd`
- `game/src/ui/hud/hud_frame.gd`
- `game/src/ui/hud/log_panel.gd`
- `game/src/ui/hud/register_panel.gd`
- `game/src/ui/screens/tutorial/tutorial_screen.gd`
- `game/src/ui/text/text_sky_comments.gd`
- `game/data/text/sky_comments.tres`
- `game/tests/unit/test_arena_readability.gd` (+ `.uid`, new)
- `game/tests/unit/test_tutorial_screen.gd`
- `game/tests/unit/test_glyph_palette.gd`

### Change Log

- 2026-11-17: Story 9.7 implemented (D-S97-1..8 as approved, dev design calls D-S97-9..12); suite 1956/1956, guards OK, web build checked; status review.
