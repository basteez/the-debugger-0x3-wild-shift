---
baseline_commit: 0e33688
---

# Story 9.8: Readability Leftovers

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from main 0e33688 in worktree gameoff-wt/9-8 (branch story/9-8-readability-leftovers, which includes Story 9.7 #77). Sources: the coordinator brief `gameoff-wt/s98/brief.md` (approved decisions D-S98-1..4), Story 9.7 (`9-7-arena-readability.md`, format model and the D-S97 context), the deferred-work section "Story 9.7" (`deferred-work.md`), Epic 9 in epics.md (Story 9.8, after 9.7), NFR8 / FR27 / FR57 (epics.md), the GDD (`gdd.md`), decision log D-054 (new row D-055 is the docs task). Nothing was committed. Design calls are marked [design call]: D-S98-1..4 approved by Tiziano through the brief ("fai tu"), D-S98-5..8 are dev-level calls recorded here. -->

## Story

As a player,
I want the frame label to stay readable under the tree ring, the log lines to read at 1x, the boss header never to collide with the HP readout, and the cheap 9.7 leftovers I can see to be fixed,
so that the last readability gaps from the first playtest are closed before submission.

**Requirements:** the 9.7 review and playtest follow-up (brief `gameoff-wt/s98/brief.md`); DC4a (`src/arena/` names no `ui/` or `presentation/` class); NFR8 (1-bit palette; log lines go plain INK, no new dither state); D-S33-7 (drift clamp unchanged); FR27 and FR57 wording; decision log D-055. Story 9.7 is the one this continues: its D-S97-3 halo, its D-S97-13 plain-INK sky row and its deferred-work "Story 9.7" section.

## Acceptance Criteria

1. **Label under the halo (D-S98-1).** **Given** a `stack frame 0x03` label cell (arena row 0, the 16 label glyphs in `Arena.LAYOUT`) whose centre lies within an actor halo of Story 9.7 (24 px of the player centre, boss body radius + 20 px of the boss body centre, 32 px of the practice target, 24 px of a live Ghost Echo decoy) **When** the arena is drawn **Then** that label cell is not drawn. The same predicate (`Arena.in_halo`, same four radii, inclusive) decides it for every actor; no new radius is added for the label.

2. **Label outside the halo (D-S98-1).** **Given** a label cell outside every halo **When** the arena is drawn **Then** it is drawn in full INK exactly as before, with no dither rect over it (the label is not scenery; NFR8 dither states unchanged).

3. **Trees are never hidden (D-S98-1).** **Given** a tree ring `♣` cell inside any actor halo, including the arena row 0 cells beside the label **When** the arena is drawn **Then** it is still drawn in full INK. The halo rule hides only the label and scenery cells (grass, rock, water).

4. **Ring and label clash resolved without the sim (D-S98-1, D-S33-7).** **Given** the Infinite Loop ring drifted onto arena row 0 over the label **When** the frame is drawn **Then** the label cells under the ring's halo are not drawn, so the ring and the label no longer render as one mush of full-INK glyphs. **And** no file under `game/src/bosses/`, `game/src/sim/` or the drift clamp changes (diff check in Task 9); replays are unchanged.

5. **Log lines are plain INK (D-S98-2).** **Given** a resisted hit (`console.log("-N") // resisted`) or a miss (`// miss: ";" is closed` / `// miss: aim for the ";"`) in the console log **When** the log is drawn at 1x **Then** the line is drawn in plain `Palette.INK` with no `Dither.checker()` rect, in the log panel, the tutorial's right block (AC 8 of 9.7) and anywhere else the log is shown. The line text is unchanged (`// resisted`, `// miss` already say what the line is).

6. **Dither state removed from the log (D-S98-2).** **Given** the log ring **When** a line is appended, in any state (base, resisted, crit, miss, player hit) **Then** no line carries a dithered flag: `LogPanel.dithered_lines()` returns all false for every shown line, and `append_line`'s dithered argument is removed or ignored. The 50% checker stays for the register panel's greyed cells and the Breakpoint screen dither (FR24, NFR8 unchanged).

7. **Docs follow the plain-INK rule (D-S98-2).** **Given** the planning files **When** this story closes **Then** FR27 (`epics.md` line ~67: "a dithered `console.log("-5") // resisted` log line"), FR57 (`epics.md` line ~118: "resisted lines dithered"), NFR8 (`epics.md` line ~145: the list of extra states, which no longer includes log lines) and the GDD wording that says these lines are dithered (`gdd.md` lines ~211, ~235, ~241 and ~534) say plain INK. Historical story acceptance criteria (Epic 3 and Epic 8 story text, decision rows D-051 and earlier) stay as written.

8. **Header never meets the HP readout (D-S98-3).** **Given** every boss definition in `game/data/bosses/*/boss_def.tres` (tutorial dummy, infinite loop, null pointer, segfault, test boss) drawn at its max HP, and the player's max HP for both the normal (`PlayerDef.max_hp`, 5) and the assist variant (`PlayerHealth.ASSIST_MAX_HP`, 8) **When** the row 0 header (`void <signature>() // hp N`) and the HP readout (`hp: 0b` plus max HP bits) are laid out on the 80-column row **Then** the header's last column is at least one column before the readout's first column. The worst case today is `void tutorialDummy() // hp 999` (30 columns) against a 14-column readout, so the test is expected to pass; if it does not, the fix is one place in `Hud.boss_header` or `HpReadout.cell_for` and the test stays.

9. **Practice readout at 2 columns (9.7 review item, D-S98-4).** **Given** a practice run **When** the console header readout is drawn **Then** its last visible glyph is at column 77 (two empty columns at 78 and 79). The padding space that `PracticeFrameCounter.header_text` adds on each side no longer shifts the visible text; the BG backing covers the text and its one-cell pad, clipped to column 79.

10. **Long words and tall prompts (9.7 review items, D-S98-4).** **Given** any tutorial prompt wrapped by `TutorialConsole.wrap_prompt` into the 56-column right block **When** it is wrapped **Then** (a) no line is wider than 56 columns, (b) no glyph is drawn past column 79 even for a single word longer than 56 columns (the word is broken at 56), and (c) every prompt of every tutorial step, for both keyboard and pad hint variants, wraps to at most 3 lines, so at least 3 log lines still show under it. A prompt that would exceed 3 lines fails the test and its text is shortened in `data/text/` (D-S98-7: no truncation with `...`).

11. **Hidden-set refresh (9.7 review perf item, D-S98-4, only if trivial).** **Given** the arena's hidden-cell set is unchanged from the previous frame **When** `refresh_hidden_cells()` runs **Then** it queues no redraw and stores no new array, and the per-cell membership test in `_draw()` is not a linear `PackedInt32Array.has` (a bool mask or a set built only on change). The draw result is identical to the 9.7 behaviour (test: `hidden_cells()` and drawn cells unchanged for the same actors). If the change is not trivial, the item stays open and AC 11 is recorded as deferred in Dev Agent Record.

12. **Deferred annotations (D-S98-4).** **Given** `deferred-work.md` section "Story 9.7" **When** the story closes **Then** every 9.7 item this story handles carries the text "Resolved in Story 9.8" (the practice padding, the long-word and 6+-line prompt tests, the header vs readout test, the hidden-set perf item if AC 11 is taken). The duck-bubble cut word (`th`, `O`) item is annotated "not a bug: typewriter reveal (D-046)". The duck-bubble wrap into columns 0-11 stays open. The `/* test */` halo item stays open. The sky descender row item (D-S98-6) stays open.

13. **Duck cut-word is not a bug (D-S98-4).** **Given** a screenshot of the duck bubble showing a cut word (`th`, `O`) **When** the bubble is drawn during the typewriter reveal **Then** no code changes: the reveal (D-046) is mid-line. The one check is that the fully revealed bubble text is the full hint, verified in the web build (AC 19).

14. **DC4a (D-S98-1, NFR).** **Given** the change set **When** `game/src/arena/` is scanned **Then** no file there references `presentation/` or `ui/` (paths or class names); `game/tools/check_guards.sh` and the existing DC4a guard in `test_arena_readability.gd` pass. The label halo reads only `Arena` data and the actors already passed in.

15. **Glyph palette (NFR8).** **Given** the log and the label after this story **When** `test_glyph_palette.gd` runs **Then** every log and label glyph colour is `Palette.INK` or `Palette.BG` (`GlyphFont.is_allowed_color`), and no new dither texture is created for them.

16. **Export-safe defaults.** **Given** any new `@export` Packed*Array default **When** it is declared **Then** it is `PackedStringArray()` (or the typed equivalent), never `[]`; `tests/unit/test_export_defaults.gd` passes.

17. **Tests added and updated.** **Given** the suite **When** it runs **Then** the tests named in the dev notes exist and pass: label halo at the four radii (inclusive, outside), trees never hidden, label never dithered, log lines plain INK (no dithered flag, existing `test_resisted_lines_are_dithered` in `test_log_panel.gd` rewritten), header vs readout over all boss defs and both player max HPs, practice readout cell at column 77, prompt wrap limits (AC 10), hidden-set refresh (AC 11). Tests assert geometry and data only (no pixel reads in headless).

18. **Change-set verification.** **Given** the change set **When** it is verified **Then** the full GUT suite passes as CI runs it (`--headless --import` first), `game/tools/check_guards.sh` passes, the shuffled order passes, and any test that depends on boss attack picks seeds the RNG.

19. **Exported web build check (mandatory).** **Given** the change set **When** the story is called done **Then** a real exported web build was looked at (steps in Task 8): the tutorial (both pages, log lines in the right block in plain INK), practice (the console header readout), fight 0 with the Infinite Loop ring near row 0 (label halo, the ring and the label), and row 0 at 1280x720 (header and readout); screenshot paths are recorded in the Dev Agent Record, and one human glance note (H-S98-1) is left for Tiziano.

20. **Docs (D-055).** **Given** the planning files **When** this story closes **Then** decision-log row D-055 exists after D-054 (Story 9.8: the design calls D-S98-1..8, the plain-INK log rule, the label halo, the header check, the 9.7 leftovers handled and left open), the GDD HUD/art wording matches AC 7, and epics.md Story 9.8 and the Epic 9 intro are present (done at story creation; verify at dev end).

21. **Status bookkeeping.** **Given** the story **When** its status changes **Then** it is set with the Edit tool (never `sed -i`), `review` only at dev end, and `sprint-status.yaml` carries `9-8-readability-leftovers` with the same status.

## Tasks / Subtasks

- [x] Task 1: label under the halo (AC: 1, 2, 3, 4, 14)
  - [x] 1.1 In `game/src/arena/arena.gd` add a pure `static func is_halo_cell(ch: String) -> bool` (scenery or the label cell) or extend `is_scenery` into a `hideable` test. Label cells are identified by their layout position (arena row 0, cols `LABEL_COL` to `LABEL_COL + LABEL.length() - 1`), not by glyph, because the label glyphs are letters. Trees stay excluded.
  - [x] 1.2 `hidden_cells_for` / `_scenery_cells()` (lines ~461 and ~501) include the label cells in the candidate list. The dither still applies only to grass, rock and water (`is_scenery`); label cells that are not hidden draw full INK with no dither rect.
  - [x] 1.3 `_draw()` (line ~416): the hideable check uses the new predicate; trees and a visible label draw as today.
  - [x] 1.4 Confirm `grep -rn "presentation\|ui/" game/src/arena` returns nothing new.

- [x] Task 2: plain-INK log lines (AC: 5, 6, 7, 15)
  - [x] 2.1 `game/src/ui/hud/log_panel.gd`: remove the `_dithered` ring and `dithered` argument (lines ~24, ~56, ~79, ~138-148, ~152-158). `_draw()` draws every line with `Palette.INK` and no `Dither.checker()` rect. `block_rows()` drops the `dithered` key.
  - [x] 2.2 `line_for_damage` / `line_for_miss` (lines ~94-111) keep their text; `_on_hit_missed` (line ~175) calls `append_line(line)`; `_on_hit_landed` drops the `true` flag wherever it is passed.
  - [x] 2.3 Grep `dithered` and `checker` in `game/src` and `game/tests`; keep `Dither.checker()` for the register panel (`register_panel.gd` line ~123, `checker_texture()` line ~263) and the Breakpoint screen.
  - [x] 2.4 Docs (AC 7): `_bmad-output/planning-artifacts/epics.md` FR27 (line ~67), FR57 (line ~118), NFR8 (line ~145); `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` lines ~211, ~235, ~241, ~534. Do not edit historical story text (Epic 3 AC line ~852, Epic 8 stories, D-051, D-054).

- [x] Task 3: header vs readout check (AC: 8)
  - [x] 3.1 Add `test_boss_header_clears_hp_readout` to `game/tests/unit/test_hud_layout.gd`: for each `data/bosses/*/boss_def.tres` (load via the same loader the other tests use, or a fixed list of the five paths), header = `Hud.boss_header(def.name_signature, def.max_hp)`, readout = `PlayerHealth.hp_text(max, max)` for max in {`PlayerDef.max_hp`, `PlayerHealth.ASSIST_MAX_HP`}; assert `header.length() < HpReadout.cell_for(readout).x`.
  - [x] 3.2 If it fails, fix in one place (the header text or `HpReadout.cell_for`), record it in Dev Agent Record. Expected: passes (worst 30 columns against 66).

- [x] Task 4: practice readout at 2 columns (AC: 9)
  - [x] 4.1 `game/src/presentation/practice_frame_counter.gd`: `header_text` (line ~44) returns the unpadded `lines_for` joined with `GAP`; the backing (`backing_rect`, line ~56) pads one cell each side and is clipped at column 79; `header_cell` (line ~51) right-aligns the visible text at `Hud.COLS - RIGHT_MARGIN`. Update `test_practice_flow.gd` / `test_arena_readability.gd` expectations that read the padded string.
  - [x] 4.2 Test: the drawn text's last column is 77 (`header_cell(text).x + text.length() - 1 == 77`).

- [x] Task 5: prompt wrap limits (AC: 10)
  - [x] 5.1 `game/src/ui/hud/tutorial_console.gd` `wrap_prompt` (line ~29) uses `DuckBubble.wrap` (`game/src/ui/duck/duck_bubble.gd` line ~271). Add the hard break for a single word longer than the width (in `TutorialConsole` only, not in `DuckBubble`, so the duck is unchanged).
  - [x] 5.2 Test over every tutorial step's prompt for both keyboard and pad hint variants (the step text lives in `game/data/text/` and the tutorial steps in `tutorial_screen.gd` / `tutorial_checklist_view.gd`; enumerate the real steps, do not hard-code a count): at most 3 lines, each at most 56 columns. Add a synthetic 60-character word test: no column past 79.
  - [x] 5.3 If a real prompt exceeds 3 lines, shorten its text in `data/text/` (the text is audited: ASCII, the 64-column tutorial prompt limit from the 9.7 dev notes), do not raise the line cap.

- [x] Task 6: hidden-set refresh, only if trivial (AC: 11)
  - [x] 6.1 `Arena.refresh_hidden_cells()` (line ~487): compare first, store only on change (already the case); replace `_hidden.has` (line ~425) with a bool mask built on change (`PackedByteArray` of `LAYOUT` size, or a `Dictionary`).
  - [x] 6.2 Test: unchanged actors give the same drawn set and no redraw; a changed actor redraws once.
  - [x] 6.3 Measure on the web build (Task 8): if no difference is visible, keep the change (it is small) and say so; if the change is not trivial, leave the item open and write that in Dev Agent Record.

- [x] Task 7: deferred-work and the one "not a bug" note (AC: 12, 13)
  - [x] 7.1 `_bmad-output/implementation-artifacts/deferred-work.md` section "Story 9.7 (Arena readability, 2026-11-17, playtest-driven)" (line ~665): append "**Resolved in Story 9.8** (D-S98-n)" to the handled items (practice padding, prompt long-word and 6+-line tests, header vs HP readout test, hidden-set perf if taken).
  - [x] 7.2 Annotate the cut-word item (the "`th`" line) "not a bug: typewriter reveal (D-046)". Leave the duck-bubble wrap item open (it is a different item: wrap into columns 0-11).
  - [x] 7.3 Use the Edit tool, never `sed -i`.

- [x] Task 8: exported web build check, mandatory (AC: 19)
  - [x] 8.1 `rm -rf game/.godot/exported`, then `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --export-debug "Web" /Users/tizianobasile/workspace/me/gameoff-wt/s98/scratch/web/index.html`.
  - [x] 8.2 Serve: `python3 -m http.server 8765 --bind 127.0.0.1` from `/Users/tizianobasile/workspace/me/gameoff-wt/s98/scratch/web/`. Stop it after use.
  - [x] 8.3 Capture with `.claude/skills/devlog/scripts/capture.js` (its header documents the steps format; `npm i --prefix /Users/tizianobasile/workspace/me/gameoff-wt/s98/scratch/pw playwright-core@1.56`, run with `NODE_PATH=/Users/tizianobasile/workspace/me/gameoff-wt/s98/scratch/pw/node_modules node ...`). ffmpeg is available for crops.
  - [x] 8.4 `?debug` keys: F2 Infinite Loop, F3 Null Pointer, F4 Segfault, Shift+F2 practice target. A fresh profile lands in the tutorial after two Enter presses past the intro (wait 4000, Enter, wait 2500, Enter). The title-menu practice (not Shift+F2) sets `Game.practice_run`.
  - [x] 8.5 Read and record the paths of: the tutorial (both pages, log lines in plain INK), practice (header readout at column 77), fight 0 (label under the ring halo), row 0 at 1280x720 (header and readout, crop). Read every screenshot before claiming done.
  - [x] 8.6 Leave H-S98-1 (Tiziano's glance on his browser) open in the Dev Agent Record.

- [x] Task 9: tests, guards, docs bookkeeping (AC: 17, 18, 20, 21)
  - [x] 9.1 Tests per AC 17; `tests/support/isolation.gd` (TestIsolation) for new tests; seed the RNG in any test that depends on boss attack picks.
  - [x] 9.2 Run the GUT suite the CI way and `game/tools/check_guards.sh`; record counts.
  - [x] 9.3 Decision log: add row **D-055** after the D-054 row in `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md` (same format as D-054, date 2026-11-17, source "Story 9.8 (gds-dev-story)").
  - [x] 9.4 Diff check: `git diff --stat main -- game/src/bosses game/src/sim` is empty (D-S33-7, replays).
  - [x] 9.5 At dev end: Status with the Edit tool (`review`), `sprint-status.yaml` `9-8-readability-leftovers: review`.

## Dev Notes

### Verified facts (read on 2026-11-17, main 0e33688; re-verify line numbers before editing)

- `game/src/arena/arena.gd`: `WATER := "="` (line 15, 9.7), `TREE := "♣"` (12), `LABEL := "stack frame 0x03"` (16), `LABEL_COL := 2` (17), `ORIGIN_CELL := Vector2i(16, 2)` (10). `LAYOUT` at line 61; row 0 is `♣♣stack frame 0x03♣♣♣♣♣♣♣♣♣♣♣♣♣♣` (the label sits on arena row 0, cols 2-17, under the top tree line). `_hidden: PackedInt32Array` (line 130), `_process` (412) calls `refresh_hidden_cells()`, `_draw()` (416) hides scenery whose index is in `_hidden` (line 425), `is_scenery` (~436: grass, rock, water only), `cell_index` (~441), `cell_centre_px` (~446), `in_halo` (452), `hidden_cells_for` (461), `current_hidden_cells` (473), `refresh_hidden_cells` (487), `hidden_cells()` (497), `_scenery_cells()` (~501). Dither draw at line ~429 via `Dither.scenery()`.
- `game/src/core/dither.gd`: `checker()` (line 29, 50% BG checker, used by RegisterPanel and LogPanel), `scenery()` (75%, 9.7). Pure `checker_paints` / `scenery_paints` live here too.
- `game/src/ui/hud/register_panel.gd`: `checker_texture()` at line 263 returns `Dither.checker()`; used at line ~123 for greyed cells. Keep.
- `game/src/ui/hud/log_panel.gd`: `_dithered` (24), `_init` (27-30), `_enter_tree` / `_exit_tree` (33, 44), `append_line(text, dithered = false)` (56), `dithered_lines()` (79), `clear()` (86), `line_for_damage` (94), `line_for_player_hit` (105), `line_for_miss` (110: `// miss: ";" is closed` / `// miss: aim for the ";"`), `line_cell` (115), `set_block` (121), `reset_block` (134), `block_rows()` (140, returns `{cell, text, dithered}`), `_draw()` (152; the checker rect is at line 158), `_on_hit_missed` (175: `append_line(line_for_miss(closed), true)`).
- `game/src/ui/hud/tutorial_console.gd`: `CURSOR := ">"`, `CURSOR_COL := 0`, `CHECKLIST_COL := 2`, `PROMPT_COL := 24`, `PROMPT_WIDTH := Hud.COLS - PROMPT_COL` (56); `wrap_prompt` (29) = `DuckBubble.wrap(" ".join(prompt), PROMPT_WIDTH)`.
- `game/src/ui/duck/duck_bubble.gd`: `static func wrap(text, width)` (271), splits on spaces; does not split a word longer than the width (the 9.7 review item).
- `game/src/ui/hud/hud.gd`: `TOP_BAR` (18), `top_bar_text()` (117), `boss_header(signature, p_hp)` (200): `"void %s() // hp %d"`, `sky_text()` (125), `sky_for_context` (140), `warning_tell_on` (150).
- `game/src/ui/hud/hud_frame.gd`: title bar in INK, `draw_rect(title_bar_rect(), Palette.INK)` then `GlyphFont.draw_at(... Palette.BG ...)` (row 0); sky row plain INK (9.7 D-S97-13).
- `game/src/ui/hud/hp_readout.gd`: `SCALE := 1`, `ROW := 0`, `COLOR := Palette.BG`, `current_text()` (`PlayerHealth.hp_text`), `cell_for(text)` (`Vector2i(Hud.COLS - text.length(), ROW)`), `top_left_for` (9.7 title offset).
- `game/src/player/player_health.gd`: `ASSIST_MAX_HP := 8` (line 13), `max_hp_for(def, assist)` (96), `hp_text(p_hp, max_hp)` (103: `"hp: 0b" + bits`). `game/src/player/player_def.gd` `max_hp = 5` (`data/player/player_def.tres` line 10).
- `game/src/bosses/framework/boss_def.gd`: `NAME_SIGNATURE_MAX := 16` (line 21). Boss defs and max HP: `data/bosses/tutorial_dummy/boss_def.tres` (`tutorialDummy`, 999), `data/bosses/infinite_loop/boss_def.tres` (`infiniteLoop`, 400), `data/bosses/null_pointer/boss_def.tres` (`nullPointer`, 700), `data/bosses/segfault/boss_def.tres` (`segfault`, 1000), `data/bosses/test_boss/boss_def.tres` (`testBoss`, 20). Worst header: `void tutorialDummy() // hp 999`, 30 columns; readout at assist max is `hp: 0b` + 8 bits = 14 columns, starting at column 66.
- `game/src/presentation/practice_frame_counter.gd`: `header_text(frames)` (44) returns `" %s%s%s " % [parts[0], GAP, parts[1]]`: the one-space pad on each side is the cause of the 3-column edge (9.7 review item). `header_cell(text)` (51) = `Vector2i(maxi(0, Hud.COLS - RIGHT_MARGIN - text.length()), Hud.LOG.position.y)`; `backing_rect(text)` (56); `_draw()` (60) draws the BG backing and the INK text at `TEXT_SCALE`.
- Tests that exist: `game/tests/unit/test_arena_readability.gd` (15 tests from 9.7, including the DC4a scan and the halo radii), `test_log_panel.gd` (`test_resisted_lines_are_dithered` at line 102, to be rewritten), `test_hud_layout.gd` (log rows 39-44 at line 109), `test_tutorial_screen.gd`, `test_glyph_palette.gd`, `test_arena_layout.gd`, `test_practice_flow.gd`, `test_practice_target.gd`, `test_export_defaults.gd`.

### Design calls

- **[design call] D-S98-1 Ring vs label (approved).** The Infinite Loop ring can drift onto arena row 0 and draw over the `stack frame 0x03` label (both full INK, unreadable). The 9.7 actor halo extends to the label glyph cells: a label cell inside an actor's halo is not drawn. Trees are always drawn. The drift clamp (D-S33-7) is NOT changed. The label is hidden by the same `in_halo` predicate and the same radii (24, boss + 20, 32, 24).
- **[design call] D-S98-2 Dithered log lines become plain INK (approved).** Resisted hits and misses are drawn in plain INK in the console. At 1x the 50% checker made them unreadable (the same finding as D-S97-13 for the sky row). The line text already says what the line is. FR27, FR57, NFR8 and the GDD wording are updated.
- **[design call] D-S98-3 Header vs HP readout (approved).** Test over all boss defs at max HP (and both player max HPs). Fix only if they overlap.
- **[design call] D-S98-4 Small 9.7 review leftovers (approved).** Fix the cheap ones the player can see (practice readout at 2 columns, long words and 6+-line prompts, the hidden-set perf item if trivial). Mark each handled item "Resolved in Story 9.8". Leave the rest open. The duck cut-word is annotated "not a bug: typewriter reveal (D-046)".
- **[design call] D-S98-5 (dev) Label identity.** The label cells are found by layout position (arena row 0, `LABEL_COL` to the end of `LABEL`), not by glyph value, so the tree glyphs never match.
- **[design call] D-S98-6 (dev) Sky descender row stays open.** The 9.7 review item (the sky comment's descender lands on row 2's first pixel row, y = 16) is a pixel-layout change under D-S97-14; it is not a cheap fix and needs the web build to judge. Left open; it goes to H-S98-1.
- **[design call] D-S98-7 (dev) Prompt overflow.** A prompt is never cut with `...`. If a real prompt needs more than 3 lines, its text is shortened in `data/text/` (AC 10, Task 5.3). The cap of 3 lines keeps at least 3 log lines visible.
- **[design call] D-S98-8 (dev) Hidden-set perf.** Done only if it is a small change (a bool mask built on change). Otherwise left open and recorded.

### Architecture and rule constraints

- **DC4a:** `src/arena/` must not reference `presentation/` or `ui/`. The label halo uses `Arena` data and the actor positions already read by `current_hidden_cells()`.
- **AD-07 (rendering):** glyphs via `draw_char` / `draw_string` in `_draw()`; no `Label` per glyph; layers Arena, Entities, Particles, HUD, ScreenFX (`main.gd` `LAYER_ORDER`, order test). The dither is a texture rect over a cell.
- **NFR8 (readability):** palette INK `#E8E8E8` on BG `#101014`; inversion, the 50% dither (register cells, Breakpoint) and the 75% scenery dither are the only extra states; the log lines are plain INK after this story; red `#FF4040` only for warnings.
- **Simulation rule (AD-01 / 2.x):** halo and hiding are presentation only. No sim state changes; replays unchanged. D-S33-7: the drift clamp is not touched.
- **Export rule:** `@export var x: PackedStringArray = []` exports empty in the web build. Use `PackedStringArray()`.
- **Keep 60 fps:** no per-frame full redraw of the scenery (9.7 AC 4 still holds).

### Engineering rules (coordinator brief, verbatim)

- Godot: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). GUT the CI way (`.github/workflows/ci.yml`), `game/tools/check_guards.sh`. New tests use `tests/support/isolation.gd`. Seed RNG for boss-attack-dependent tests.
- Status changes with the Edit tool, not `sed -i`. Keep DC4a (`src/arena/` names no ui/ or presentation/ class).
- **Look at a real exported web build before calling it done**: `rm -rf game/.godot/exported` first, then export `--export-debug "Web"` to `/Users/tizianobasile/workspace/me/gameoff-wt/s98/scratch/web/index.html`, serve with `python3 -m http.server 8765 --bind 127.0.0.1`, capture with `.claude/skills/devlog/scripts/capture.js` (header documents steps; `npm i --prefix <scratch>/pw playwright-core@1.56`, run with `NODE_PATH=<scratch>/pw/node_modules node ...`). `?debug`: F2 Infinite Loop, F3 Null Pointer, F4 Segfault, Shift+F2 practice target. ffmpeg is available for crops. Stop the server afterwards.

### How to run the suite (CI way)

- `cd` to the worktree; `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import` first, then the GUT command from `.github/workflows/ci.yml` (around line 91): `"$GODOT_BIN" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`, and check the log for failure markers as CI does. Shuffled order: `WILDSHIFT_GUT_ORDER=shuffle:<seed>`. Record the counts.

### Out of scope (stays open in deferred-work.md "Story 9.7")

- The duck bubble wraps into columns 0-11 under the register box (rows 22-37).
- The `/* test */` label of the practice target is wider than its 32-px halo.
- The sky comment's descender row on y = 16 (D-S98-6).
- The crit-inversion frame on row 0 in a web capture (H-S97-1, human).

### Project Structure Notes

- No new source files expected. Possible new test: none beyond the existing `test_arena_readability.gd`, `test_log_panel.gd`, `test_hud_layout.gd`, `test_tutorial_screen.gd`, `test_practice_flow.gd`.
- Touched source (expected): `game/src/arena/arena.gd`, `game/src/ui/hud/log_panel.gd`, `game/src/ui/hud/tutorial_console.gd`, `game/src/presentation/practice_frame_counter.gd`, `game/src/ui/hud/hp_readout.gd` and `hud.gd` only if AC 8 fails, `game/data/text/` only if AC 10 needs it.
- Docs: `_bmad-output/planning-artifacts/epics.md` (FR27, FR57, NFR8), `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` (lines ~211, ~235, ~241, ~534), `decision-log.md` (row D-055), `_bmad-output/implementation-artifacts/deferred-work.md` ("Story 9.7" section), `_bmad-output/implementation-artifacts/sprint-status.yaml`.

### Open questions (defaults chosen, no elicitation)

1. Label hiding: a per-cell predicate in `Arena` (D-S98-5) rather than a separate label node. Default: the predicate.
2. Long words: broken at 56 columns in `TutorialConsole` only (`DuckBubble` unchanged). Default: yes.
3. Hidden-set perf: taken only if trivial (D-S98-8).

### References

- [Source: gameoff-wt/s98/brief.md] (decisions D-S98-1..4, engineering rules, export procedure)
- [Source: _bmad-output/implementation-artifacts/9-7-arena-readability.md] (format model; D-S97-3 halo, D-S97-13 plain sky row, D-S97-14 tell clearance)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 9.8: Readability Leftovers] and FR27 (line ~67), FR57 (line ~118), NFR8 (line ~145)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md, section "Story 9.7"] (the review and dev items this story handles or leaves open)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md, row D-054; new row D-055]

## Project Context Rules

- Main is protected: work on `story/9-8-readability-leftovers` in the worktree `gameoff-wt/9-8`; PR base `main`; never commit to main; no force push; no `gh pr merge`. Do not commit during the story run unless the user asks.
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). Guards: `game/tools/check_guards.sh`.
- Set story status with the Edit tool. Never use the Fable model.
- Every new user-facing string that lives in a `.tres` is audited text (ASCII, <= 80 columns for sky comments, <= 64 columns for prompts at 1x in the tutorial).
- Arena is a simulation folder: it may not reference `ui`, `presentation`, `AudioManager` or `VoiceService`.

## Dev Agent Record

### Agent Model Used

Claude (gds-create-story, unattended, 2026-11-17); implementation: Claude Opus (gds-dev-story, unattended, 2026-11-17).

### Debug Log References

- Baseline suite on 0e33688 (CI way, `--import` first): 132 scripts, 1956 tests, 1956 passing, All tests passed.
- After the change: 132 scripts, **1962 tests, 1962 passing**, 153193 asserts, All tests passed; shuffled order (`WILDSHIFT_GUT_ORDER=shuffle:20261129`, as CI): 1962/1962 passing. No failure markers in either log. `game/tools/check_guards.sh`: OK.
- `grep -rn "presentation\|ui/" game/src/arena`: nothing. `git diff --stat main -- game/src/bosses game/src/sim`: empty (D-S33-7, replays unchanged).
- Web build: `rm -rf game/.godot/exported`, `--export-debug "Web"` to `gameoff-wt/s98/scratch/web/index.html`, served on 127.0.0.1:8765, captured with a copy of `.claude/skills/devlog/scripts/capture.js` that also logs the browser console (no page errors). Server stopped. A `Process exited with code 1` frame in one run is the in-game DEAD screen (the player died to the ring), not a crash.

### Completion Notes List

- Story created unattended (comprehensive developer guide created). No elicitation.
- AC 1-4, 14 (D-S98-1, D-S98-5): `Arena.is_label_cell(cell)` (row 0, cols 2-17, by position). The hideable candidates (`_scenery_cells`) now include the label cells, so `hidden_cells_for` hides a label cell inside any halo with the same `in_halo` predicate and radii; `_draw` skips a hidden scenery or label cell, the dither still applies only to grass/rock/water, trees are never candidates. Tests: `test_trees_are_never_hidden`, `test_label_cells_by_position`, `test_label_cell_under_each_halo_radius` (four radii, inclusive and +0.5 px), `test_ring_on_row_0_hides_the_label_under_it` (real InfiniteLoopBody on row 0).
- AC 5-7, 15 (D-S98-2): `LogPanel` has no dither state: the `_dithered` ring, `append_line`'s `dithered` argument, `dithered_lines()` and the `dithered` key of `block_rows()` are removed; `_draw` draws every line in `Palette.INK`, no `Dither.checker()` rect. `RegisterPanel.checker_texture()` and Breakpoint keep the 50% checker. Tests: `test_resisted_and_miss_lines_are_plain_ink` (replaces `test_resisted_lines_are_dithered`), `test_miss_signal_appends_one_plain_line`. Docs: FR27, FR57, NFR8 (epics.md), GDD lines ~211, ~235, ~241, ~526, ~534.
- **[design call] D-S98-9 (dev) Remove, not ignore, the log dither API.** AC 6 allowed "removed or ignored"; `dithered_lines()` and the argument are removed (no caller left, no dead always-false API). The tests assert `not has_method("dithered_lines")`.
- AC 8 (D-S98-3): `test_boss_header_clears_hp_readout` in `test_hud_layout.gd` walks `res://data/bosses/*/boss_def.tres` (5 defs) and checks the header length against the readout column for max HP 5 and `ASSIST_MAX_HP` 8. It passes as expected (worst 30 columns vs column 66): no code change.
- AC 9 (D-S98-4): `PracticeFrameCounter.header_text` has no pad spaces; `BACKING_PAD := 1` cell each side in `backing_rect`, clipped to `Hud.COLS`. Test: last visible glyph on column 77, backing one cell wider each side, inside column 79.
- AC 10 (D-S98-4, D-S98-7): `TutorialConsole.wrap_prompt` breaks a line longer than 56 columns every 56 columns (the duck's `DuckBubble.wrap` is unchanged). New `test_prompt_wrap_breaks_a_word_wider_than_the_block`; the existing every-step, both-devices test already asserts 1-3 lines of at most 56 columns (so at least 3 log lines remain). No prompt text needed shortening.
- AC 11 (D-S98-8, taken: trivial): `refresh_hidden_cells()` compares the actor inputs (player, boss centre and radius, practice target, decoy) with the last ones and returns early when none changed (no array built); on a changed set it rebuilds `_hidden_mask` (PackedByteArray, one byte per layout cell) and `_draw` uses `is_hidden(cell)` (O(1)). Hidden set identical to 9.7. Test: `test_unchanged_actors_skip_the_recompute_and_mask_matches`. Not profiled: no frame-time measurement was taken; no visible difference in the web build captures. Kept because it is small and removes the per-frame array and the linear lookup.
- AC 12, 13: deferred-work "Story 9.7" items annotated "Resolved in Story 9.8" (prompt wrap, practice padding, hidden-set perf, header vs readout); the cut-word part annotated "not a bug: typewriter reveal (D-046)"; the duck wrap into columns 0-11, the `/* test */` halo and the sky descender row (D-S98-6) stay open. The fully revealed duck bubble shows the whole hint (`...the rest are in code review.`) in the web build.
- AC 16: no new `@export`. AC 20: decision-log row D-055 added after D-054; epics.md Story 9.8 and the Epic 9 intro present.
- Docs-only (coordinator): Tiziano's Firefox test of the web build on 2026-11-17 ("looked OK") recorded as a **general Firefox smoke pass** (not the specific H-S7x / per-item browser checks) in the `epic-1` comment of `sprint-status.yaml` and in deferred-work.md "Deferred: itch.io deploy & browser smoke" (status update paragraph and the [1.3 H4] item). Safari still pending; Epic 1 stays in-progress.
- AC 19, web build screenshots (read by eye; nothing wrong found):
  - `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/infinite-loop-ring-over-label-2.png` and crop `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/infinite-loop-ring-over-label-crop.png`: the ring on arena row 0, `stack fra` drawn, the label cells under the ring halo not drawn, ring glyphs readable, trees intact; `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/infinite-loop-ring-over-label.png` (ring and player on row 0).
  - `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/console-resisted-and-miss-plain-ink.png` (crop `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/console-resisted-miss-crop.png`): `console.log("-5") // resisted` and `// miss: aim for the ";"` in plain INK; `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/console-miss-lines-plain-ink.png` adds `// miss: ";" is closed`.
  - `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/boss-headers-row0-crop.png` (row 0 of F2 infiniteLoop 400, F3 nullPointer 700, F4 segfault 1000, Shift+F3 testBoss 20, Shift+F2 fightPlaceholder), full frames `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/02-hdr-f2.png` .. `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/06-hdr-shiftf2.png`; `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/tutorial-log-resisted-plain-ink.png` shows `void tutorialDummy() // hp 999` with the readout. Header and readout far apart.
  - `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/practice-readout.png` and crop `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/practice-readout-crop.png` (title-menu practice): `... [ESC / L3] title`, one BG cell, then the rule on column 79.
  - `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/tutorial-log-resisted-plain-ink.png` (crop `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/tutorial-log-crop.png`): tutorial right block, 3-line prompt and three plain-INK resisted lines under it; `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/tutorial-prompt.png`; `/Users/tizianobasile/workspace/me/gameoff-wt/s98/final/duck-bubble-fully-revealed.png`.
  - Not captured: the assist (8-bit) readout in a web frame (covered by the AC 8 test) and the crit-inversion frame (H-S97-1, open).
- H-S98-1 (open, Tiziano, real browser): open the tutorial (both pages), practice and fight 0 in the web build at 1280x720; confirm the label stays readable under the ring, the log lines read in plain INK, and the header and readout sit apart; also judge the sky descender row (D-S98-6).

### File List

- `_bmad-output/implementation-artifacts/9-8-readability-leftovers.md` (new, this story)
- `_bmad-output/implementation-artifacts/7-9-itch-io-page-readme-and-submission.md` (H-S79-5 done, submitted by Tiziano 2026-11-17)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (`9-8-readability-leftovers: done`; epic-1 Firefox general smoke)
- `_bmad-output/implementation-artifacts/deferred-work.md` (Firefox general smoke; Story 9.7 section annotations)
- `_bmad-output/planning-artifacts/epics.md` (Story 9.8 section, Epic 9 intro; FR27, FR57, NFR8)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` (plain-INK log lines, label halo)
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md` (D-055)
- `game/src/arena/arena.gd`
- `game/src/ui/hud/log_panel.gd`
- `game/src/ui/hud/tutorial_console.gd`
- `game/src/presentation/practice_frame_counter.gd`
- `game/tests/unit/test_arena_readability.gd`
- `game/tests/unit/test_log_panel.gd`
- `game/tests/unit/test_semicolon_readability.gd`
- `game/tests/unit/test_tutorial_screen.gd`
- `game/tests/unit/test_hud_layout.gd`

### Review Findings (gds-code-review, 2026-11-17)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). Acceptance Auditor: no AC violations. Patched: the `_halo_inputs` comment overstated "no per-frame array" (the 5-element inputs Array is still built per frame). Deferred (low, recorded in deferred-work.md "Review 9.8"): hard-break tail costs an extra line / no hyphen; practice backing pad cell can touch the `console` title at column 12; NaN input defeats the change check; `_hidden_mask` not pre-sized when the first set is empty (safe via bounds check); source-grep tests are brittle; header test relies on DirAccess over res://data/bosses; label vanishes whenever the player is near row 0 (intended D-S98-1). Rejected: arena-reset staleness (`_hidden` is only written in `refresh_hidden_cells`), removed log API callers (none remain).

### Change Log

- 2026-11-17: Story 9.8 created (gds-create-story, unattended); status ready-for-dev.
- 2026-11-17: Implemented (gds-dev-story): label under the actor halo, plain-INK log lines, header vs readout test, practice readout at column 77, prompt hard break, hidden-set mask; docs D-055, FR27/FR57/NFR8, GDD; Firefox general smoke recorded. Suite 1962/1962 (CI and shuffled), guards OK, web build checked. Status review.
- 2026-11-17: Code review (3 layers): 1 comment patch, low items deferred; H-S79-5 recorded. Status done.
