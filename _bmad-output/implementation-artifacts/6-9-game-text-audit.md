---
baseline_commit: story/6-8-ending-sequence (stacked on 6.1–6.8)
---
# Story 6.9: Game Text Audit

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Judgment calls are marked [design call] with the chosen default (D-S69-n); the implementer follows them or records a change in Completion Notes. Scope: the final text audit of Epic 6 (the last story of the epic). Every GDD text item is checked against its data and its trigger; the three shared text resources (data/text/fixed_lines.tres, data/text/sky_comments.tres, data/text/screen_text.tres) are created; narrative strings still hard-coded in scripts move to data; the GDD drift found by the audit is resolved; a GUT audit test pins the whole text budget. NOT in scope: new lines beyond the 10-line budget (D-039 is full), the audio credit source (`audio: TBD` stays until 7.1/7.2/7.9), the voice tuning by ear, the Chrome/Firefox/Safari human checks (recorded as pending in Group E, not faked). -->

## Story

As the director,
I want every line of game text in data and verified against the GDD,
so that the duck line budget and all jokes ship exactly as designed.

**Requirements:** FR45 (exactly 10 hand-written duck lines, each with a trigger), FR56 (sky comments). Additional: GDD "Duck (hint system)" (budget and tone), GDD "Asset Requirements" (Text row: 10 duck lines with the hint template counted once, 3 fixed lines, 3 comments), NFR17 (English only), GDD D-039. Window: Nov 22–25 (Epic 6). Last story of Epic 6: the Epic 6 Definition of Done (NFR16) applies to this story's closing build (see Group E).

Depends on: 3.6/3.7 (duck line catalogue, `VoiceService`, `render_duck_lines.gd`), 3.8 (HARVEST screen and `harvest_shared`), 4.4 (hint template and the T1 rewrite, D-S44-2), 5.6 (`n1_breakpoint`, `n2_hold_r`, `null_pointer` fixed line), 6.7 (`intro_handover`, `IntroScreen` captions), 6.8 (`ending` line and `data/ending/ending_text.tres`, which states that 6.9 owns `data/text/`).

## Acceptance Criteria

**Duck lines (GDD Duck table, FR45)**

1. **Given** `game/data/duck/duck_lines.tres`, **When** the audit test runs, **Then** the hand-written lines are exactly the GDD Duck table rows: intro (row 1), T1–T4 (rows 2–5), Breakpoint tutorial (row 6), Watch tutorial (row 7), shared harvest (row 8), ending (row 9), and the hint template (row 10). Each row's text equals the GDD string, except where D-S69-3 (T1) records the agreed change.
2. **And** the budget is counted by `DuckLinesDef` rules: 9 hand-written entries plus the hint template counted once (the five per-window `hint_*` entries are fills of that one template, D-S69-4). The total is 10 and must not grow. The existing `test_duck_lines.gd` budget assertions stay green.
3. **And** every hint window that occurs in any boss phase (derived from `Defs` boss data in the test, not hard-coded) has a `hint_*` entry whose text is the template filled with that window (`Quack. Weak window: X→Y.`). No window is missing and no extra `hint_*` entry exists.
4. **And** every duck line has a trigger that fires in a full run. The trigger table in Dev Notes maps each line to its trigger and to the test (or Group E check) that proves it fires. Each line is reachable in the run order Intro → Infinite Loop → Null Pointer → Segfault → Ending (with the Segfault cut, Ending follows Null Pointer, and line 9 still fires).
5. **And** every duck line is ASCII (or the hint arrow `→`, D-S44-10), within `DuckBubble.WRAP_WIDTH` and `DuckBubble.MAX_LINES`, and validates (`DuckLineDef.validate()` returns empty).

**Fixed lines and sky comments (GDD Boss Design and Art Style, FR56)**

6. **Given** the three bosses, **When** the audit runs, **Then** `game/data/text/fixed_lines.tres` (new, class `TextFixedLines`, `game/src/ui/text/text_fixed_lines.gd`) holds exactly 3 entries, one per boss: `infinite_loop` `for (i = 0; i < n; i++) { }`, `null_pointer` `if (ptr != null) ptr.deref();`, `segfault` `if (idx < len) buf[idx] = val;`. Each equals the GDD string and equals that boss's `BossDef.fixed_line` (D-S69-2).
7. **And** `game/data/text/sky_comments.tres` (new, class `TextSkyComments`, `game/src/ui/text/text_sky_comments.gd`) holds exactly 3 comments: the default `// TODO: this should terminate` (Infinite Loop and every fight without a per-boss comment), `// FIXME: who owns this pointer?` (Null Pointer), `// HACK: do not read past this line` (Segfault). Each equals the GDD string.
8. **And** `Hud` no longer holds these strings as constants (`SKY`, `SKY_NULL_POINTER`, `SKY_SEGFAULT` are read from `sky_comments.tres`). The HUD sky row shows the same text as before for every boss (test: the HUD text equals the data for each boss id and for no boss).
9. **And** the harvest fallback `// bug fixed` (used only when a boss has an empty `fixed_line`) moves into `fixed_lines.tres` as the `fallback` field, not counted in the 3 (D-S69-7). No behaviour changes in shipped content.

**Narrative screen text**

10. **Given** the narrative strings of the screens (title line, the "press any key" prompt, the three intro caption pairs, the DEAD line), **When** the audit runs, **Then** they live in `game/data/text/screen_text.tres` (new, class `TextScreenText`, `game/src/ui/text/text_screen_text.gd`, `extends Def`, with `validate()`). The screens read them from the resource. The intro captions keep their panel grouping (3 panels, 2 + 2 + 1 rows).
11. **And** `ending_text.tres` (6.8) is not moved: it is already data. Its `prompt` and the `ending` duck line are checked by the audit, not duplicated into `screen_text.tres`.
12. **And** the classification of every string literal in `game/src` that looks like prose is recorded in the audit inventory in Dev Notes. Each entry is one of: `data` (moved to data in this story), `chrome` (HUD labels, pause-menu key labels, log/console templates, debug strings, the warning tell `SIGSEGV incoming`, the register and breakpoint labels; stays in code by D-S69-1), or `fixed-text` (the sim constants of the GDD such as fight tags). No prose literal is unclassified.
13. **And** a GUT test (`tests/unit/test_text_audit.gd`) fails if a `data`-class string reappears as a literal in its former script (checked by exact-string search of the listed script files, with the allowlist in the test). The test is not regex over the whole tree (deferred "brittle source-regex tests").

**Glyph and text rules**

14. **And** every character used in `data/text/*.tres` and in `data/ending/ending_text.tres` is in the glyph font (`test_font_coverage.gd` extended to the new resources). NFR17: English only.
15. **And** `game/tools/check_guards.sh` passes. No change to sim code: nothing under `game/src/{input,register,player,combat,bosses,skills,arena}` is edited by this story.

**Drift fixes and documentation**

16. **Given** the audit found that the shipped T1 line differs from the GDD Duck row 2 and the GDD tutorial beat 1 (D-S44-2 rewrote T1 after the 2026-11-10 playtest; the GDD was not updated, see the 4.4 note), **When** the story closes, **Then** the GDD Duck table row 2 and the tutorial beat 1 read the shipped T1 text, and the test pins that text (D-S69-3). The GDD edit is a doc change only.
17. **And** `game/data/duck/duck_clips.tres` is not re-rendered unless a line text changes. If a text changes, re-render with `tools/render_duck_lines.gd` and confirm the diff is only the changed clip (deferred 6.8 note on the renumbered sub-resource ids).
18. **And** the audit writes a short table in the story's Completion Notes: every GDD text row with its data entry, its trigger, its test, and PASS or FAIL. Any FAIL is fixed or listed as an open question for the director.

## Tasks / Subtasks

### Group A: Audit and inventory (AC: 12, 18)
- [x] A1. Grep `game/src` for prose literals (string literals with spaces or lowercase words). Fill the inventory table (Dev Notes) with each hit, its file, and its class (`data`, `chrome`, `fixed-text`). Do not change code yet.
- [x] A2. Confirm the GDD table against `duck_lines.tres` line by line (AC 1–3). Confirm the hint windows against the phase `weak_window` values in `data/bosses/*/boss_def.tres`.
- [x] A3. Confirm each duck line's trigger in code (`DuckDirector`, `IntroScreen`, `HarvestScreen`, `EndingScreen`, `Game.route_after_defeat`, the Breakpoint and Watch skills). Record the result in the trigger table.

### Group B: Data resources (AC: 6, 7, 9, 10, 14)
- [x] B1. Create `game/src/ui/text/text_fixed_lines.gd` (`class_name TextFixedLines`, `extends Def`, `@export` `entries` (dictionary of boss id to line) and `fallback: String`, `validate()` returns empty when every entry is non-empty and there are exactly 3 entries) and `game/data/text/fixed_lines.tres`.
- [x] B2. Create `game/src/ui/text/text_sky_comments.gd` (`class_name TextSkyComments`, `extends Def`, `@export` `default_comment`, `null_pointer`, `segfault`, `validate()`) and `game/data/text/sky_comments.tres`.
- [x] B3. Create `game/src/ui/text/text_screen_text.gd` (`class_name TextScreenText`, `extends Def`, `@export` `title`, `prompt`, `intro_captions` (three PackedStringArray panels), `dead_line`, `validate()` returns empty for non-empty fields and 3 intro panels) and `game/data/text/screen_text.tres`.
- [x] B4. Add the three resources to the data validation test (`test_data_validation.gd`) the same way the other `Def` resources are covered.
- [x] B5. Load the resources in the owning code path, not as autoloads: `Hud` (sky), `HarvestScreen` (fallback), `TitleScreen` (title, prompt), `IntroScreen` (captions), `DeadScreen` (line), `PlaceholderScreen` and `HarvestScreen` (prompt). Keep the load in one place per screen (a `preload` of the `.tres`).

### Group C: Move strings out of scripts (AC: 8, 9, 10, 12, 13)
- [x] C1. `game/src/ui/hud/hud.gd`: remove `SKY`, `SKY_NULL_POINTER`, `SKY_SEGFAULT` constants and read them from `sky_comments.tres`. Keep `Hud.SKY` as a read-only accessor (`hud_frame.gd` calls `Hud.SKY`).
- [x] C2. `game/src/ui/screens/harvest/harvest_screen.gd`: `FIXED_FALLBACK` and `PROMPT_TEXT` read from data.
- [x] C3. `game/src/ui/screens/title/title_screen.gd`: `TITLE_TEXT`, `PROMPT_TEXT` from `screen_text.tres`.
- [x] C4. `game/src/ui/screens/intro/intro_screen.gd`: `CAPTION_1..3` from `screen_text.tres`. The panel timing and the `intro_handover` id stay in code.
- [x] C5. `game/src/ui/screens/dead/dead_screen.gd`: `TEXT` from `screen_text.tres`.
- [x] C6. `game/src/ui/screens/placeholder/placeholder_screen.gd`: the `PROMPT_TEXT` (if still present) from `screen_text.tres`. The FIGHT placeholder label stays (it is a debug label, `chrome`).
- [x] C7. Do not change `ending_screen.gd` text (already data, 6.8).

### Group D: Drift and GDD (AC: 1, 16, 17)
- [x] D1. Apply D-S69-3: the GDD Duck table row 2 and the tutorial beat 1 read the shipped T1 text ("Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review."). The data entry `t1_shift` is unchanged.
- [x] D2. Update `test_duck_lines.gd` `GDD` dictionary for `t1_shift` to the shipped wording, and add a comment pointing to D-S44-2 and this story.
- [x] D3. If any other audit row FAILs, fix the data (not the GDD) unless the design call says otherwise, and record it.

### Group E: Tests and checks (AC: 1–5, 13–15, 18)
- [x] E1. `tests/unit/test_text_audit.gd` (new, GUT): the GDD table (AC 1), the budget (AC 2), hint windows derived from `Defs` (AC 3), the fixed lines and sky comments (AC 6–7), the sky accessor equals the data for each boss id and for no boss (AC 8), the fallback (AC 9), the screen-text validation and the caption grouping (AC 10), and the literal-reappearance check with its allowlist (AC 13).
- [x] E2. `tests/integration/test_text_triggers.gd` (new, GUT): drives the real flow through `Main` and asserts that each duck line id is requested at least once in a run that uses the Segfault path (intro, Fight 1, Fight 2 with a Breakpoint, Fight 2 with a Watch, harvest, Fight 3, ending) or in a run with the Segfault cut (Null Pointer last). Use the existing `test_intro_flow.gd`, `test_harvest_flow.gd` and `test_ending_flow.gd` helpers. Where a trigger needs a player action that the helpers cannot send (the 3rd death hint), the test uses the existing retry snapshot path (`test_retry_snapshot.gd` helpers) and says so in a comment.
- [x] E3. Extend `test_font_coverage.gd` to the three new resources and `ending_text.tres`.
- [x] E4. Run the full GUT suite and `bash game/tools/check_guards.sh` from the worktree root. Run `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tools/render_duck_lines.gd` only if a line text changed (not expected: D-S69-3 changes the GDD, not the data).

### Group F: Human checks (recorded, not automated)
- [ ] F1. Read the whole game text once in a Chrome build (title, intro, each fight's sky row and fixed line on defeat, the duck bubble for each line, the harvest, the ending credits). Record any typo or tone problem in Completion Notes. Do not change copy without the director.
- [ ] F2. Epic 6 DoD (NFR16): release web build deployed with `butler` to the itch.io draft page; Chrome and Firefox smoke (title → Epic 6 content: intro, Ghost Echo/Dereference, Segfault, ending); build size recorded in Completion Notes against NFR4 (32 MB). Firefox and Safari checks from earlier epics remain open in deferred-work.md.

## Dev Notes

### Design calls (D-S69-n)

- **D-S69-1 [design call] What counts as game text.** The audit's "game text" is: duck lines, fixed lines, sky comments, and the narrative screen text (title line, press-any-key prompts, intro captions, DEAD line, the harvest fallback). Those move to data. UI chrome (HUD labels, register and breakpoint labels, pause-menu key labels, console/log line templates with parameters such as `CRITICAL: %d dmg`, the `SIGSEGV incoming` warning tell, debug labels) stays in code, because it is formatting tied to layout and state, and it is listed in the inventory as `chrome`. Director can reclassify.
- **D-S69-2 [design call] Fixed lines: data is the audited source; the boss keeps its field.** `BossDef.fixed_line` stays (the boss wiring and `HarvestScreen.setup` read it). `fixed_lines.tres` is the audited list. A test asserts the two agree, so there is no drift and no code change to the boss path.
- **D-S69-3 [design call] T1 drift: shipped text wins.** The shipped T1 (D-S44-2, the coordinator's wording after the 2026-11-10 playtest) replaces the GDD's old T1 wording in Duck row 2 and tutorial beat 1. The GDD is the document that is out of date, not the playtested line. Default: update the GDD (doc only). Alternative (director): revert the data to the GDD sentence; the test then pins the old text.
- **D-S69-4 [design call] Budget counting.** The GDD says 10 hand-written lines and "the hint template counts as one". The data has five pre-filled `hint_*` entries (one per window that occurs in a phase), each rendered as a clip. They are counted as one template for the budget (`budget_count` already does this and the test asserts 10). No new line is added.
- **D-S69-5 [design call] Trigger proof is a test plus a table, not a scripted full-run recording.** A recorded full-run replay (`tests/replays/`) would need a new input recording of the whole run. The audit uses the integration test (E2) for the flow and the trigger table below for the rest. A full-run replay is a stretch, and it is not required for the AC.
- **D-S69-6 [design call] `screen_text.tres` is one shared resource.** Title, prompt, captions and DEAD line are one resource (`TextScreenText`), not one per screen, so the audit reads one file. `ending_text.tres` stays separate (6.8 D-S68-8).
- **D-S69-7 [design call] The harvest fallback is data.** `// bug fixed` is only shown when a boss has no fixed line. It moves to `fixed_lines.tres` as `fallback` so no prose literal remains in `harvest_screen.gd`. It is not one of the 3 GDD fixed lines and the audit does not count it.

### Duck line trigger table (AC 4, to be confirmed in A3)

| # | Line id | Text (shipped) | Trigger | Proved by |
|---|---|---|---|---|
| 1 | `intro_handover` | Quack. Explain the bug to me. Use these. | Intro panel 3 | `test_intro_flow.gd`, E2 |
| 2 | `t1_shift` | Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review. | Infinite Loop start (control starts) | `test_start_nudge.gd`, E2 |
| 3 | `t2_semicolon` | See the semicolon? It's always the semicolon. Hit it when it opens. | First `;` approach, Boss 1 | `test_duck_director.gd`, E2 |
| 4 | `t3_dash_strike` | J then K: Dash Strike. Two bits, one commit. | Dash Strike active in Boss 1 | `test_duck_director.gd`, E2 |
| 5 | `t4_phase_two` | It refactored itself. Have you tried shifting it off and on again? | Boss 1 phase 2 | `test_duck_director.gd`, E2 |
| 6 | `n1_breakpoint` | Space: Breakpoint. Time stops, you shift. Finally, a debugger that works. | Boss 2 start (Breakpoint tutorial; not when cut #3) | `test_breakpoint_replay.gd`, E2 |
| 7 | `n2_hold_r` | Hold R. Pointers point *somewhere*. | Boss 2 start after line 6 (Watch tutorial; not when cut #2) | `test_duck_director.gd`, E2 |
| 8 | `harvest_shared` | Bug squashed. It dropped a bit: new windows, new combos. | Harvest after each boss | `test_harvest_flow.gd`, E2 |
| 9 | `ending` | Quack. Works on your machine now. | Ending frame 300 | `test_ending_flow.gd`, E2 |
| 10 | `hint_*` (template) | Quack. Weak window: X→Y. | Breakpoint activation (once per phase) or 3rd death on the same boss | `test_duck_hint.gd`, E2 |

Note: lines 6 and 7 are tied to cut ladder #3 and #2 (Breakpoint and Watch). The tests prove they fire with the flags on (shipped config). The Breakpoint line currently plays when `breakpoint_enabled` is off (deferred-work N1 item): record it as a known deviation in Completion Notes, do not fix in this story.

### Text inventory (AC 12; A1 fills and extends this table)

| Area | String(s) | File | Class | Action |
|---|---|---|---|---|
| Duck lines | the 14 `duck_lines.tres` entries | `data/duck/duck_lines.tres` | data | audited; T1 text kept (D-S69-3), no other change expected |
| Fixed lines | 3 boss lines | `data/bosses/*/boss_def.tres` | data | mirrored in `data/text/fixed_lines.tres` (D-S69-2) |
| Fixed fallback | `// bug fixed` | `src/ui/screens/harvest/harvest_screen.gd:26` | data | moved to `fixed_lines.tres` (C2) |
| Sky comments | `// TODO: this should terminate`, `// FIXME: who owns this pointer?`, `// HACK: do not read past this line` | `src/ui/hud/hud.gd:19-24` | data | moved to `sky_comments.tres` (C1) |
| Title | `The Debugger 0x03: Wild Shift` | `src/ui/screens/title/title_screen.gd:8` | data | moved to `screen_text.tres` (C3) |
| Prompt | `press any key` | `title_screen.gd:9`, `harvest_screen.gd:25` (placeholder and ending use it too, ending via `ending_text.tres`) | data | moved to `screen_text.tres` (C2, C3, C6) |
| Intro captions | `2 a.m.`, `stuck on a bug`, `squeeze`, `QUACK`, `The Clearing` | `src/ui/screens/intro/intro_screen.gd:32-34` | data | moved to `screen_text.tres` (C4) |
| DEAD line | `Process exited with code 1` | `src/ui/screens/dead/dead_screen.gd:9` | data | moved to `screen_text.tres` (C5) |
| Ending text | caption, commit, credits, prompt | `data/ending/ending_text.tres` | data | already data (6.8); audited |
| HUD chrome | `void fightPlaceholder() // hp ---`, `reg`, `── console ──`, `brk`, `READY`, `reserved`, `hp: ...` | `src/ui/hud/*.gd` | chrome | stays (D-S69-1) |
| Log templates | `console.log("-%d")`, `CRITICAL: %d dmg`, `WARN: hp--` | `src/ui/hud/log_panel.gd:88-96` | chrome | stays (D-S69-1) |
| Warning tell | `SIGSEGV incoming` | `src/ui/hud/hud.gd:27` | chrome | stays (D-S69-1) |
| Pause labels | `PAUSED`, `MOVE WASD ARROWS`, `[ESC / P / CLICK] RESUME`, `[M] MUTE ON` | `src/ui/screens/pause/pause_screen.gd` | chrome | stays (D-S69-1) |
| FIGHT label | `FIGHT %d`, `boss index %d` | `src/ui/screens/placeholder/placeholder_screen.gd:38` | chrome (debug) | stays |

A1 must extend this table with every other hit of the grep (prose literals in `src/` that are not listed above). Any new hit is classified before the story closes.

### Current state of the code (read before editing)

- `game/data/duck/duck_lines.tres`: 14 entries after 6.8. The T1 entry is the shipped D-S44-2 text. The `test_duck_lines.gd` asserts 14 entries, GDD text for T1–T4 and the ending, and `budget_count` = 10 (hint template once).
- `game/data/text/`: an empty folder. 6.8 explicitly left the shared text files to 6.9.
- `game/data/ending/ending_text.tres`: ending text is already data (6.8), including `audio: TBD`. That placeholder is a known item for 7.1/7.2/7.9 (deferred-work.md "Audio credit line"), not a 6.9 fix.
- `game/data/bosses/{infinite_loop,null_pointer,segfault}/boss_def.tres`: `fixed_line` fields match the GDD strings exactly.
- `game/src/ui/hud/hud.gd`: `SKY`, `SKY_NULL_POINTER`, `SKY_SEGFAULT` are constants; `sky_text()` picks one per boss id (D-S51-4).
- `game/src/ui/duck/duck_hint.gd`: `PREFIX := "Quack. Weak window: "` is the template implementation; the template text itself is not in data beyond the five `hint_*` entries. Keep it, and check it against the GDD string in the audit.
- The GDD (`_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`): Duck table at lines ~445–456, Duck tutorial beats at ~368–372, Breakpoint/Watch tutorial at ~404–405, Text budget at ~610, Art Style sky comment at ~533 and ~559. Use these as the references for the audit table.

### Previous story intelligence

- 6.8 (done): the ending screen pattern (pure static helpers, `_exit_tree` voice stop, duck line requested once through `EventBus.duck_line_requested`). The ending text is data with a `validate()`; mirror that for the three new resources. 6.8 notes the duck budget is full at 10: do not add a line.
- 6.7 (done): `IntroScreen` caption constants are the thing this story moves (C4). Its `skip_allowed` rule and `intro_handover` id stay.
- 6.6 and 6.5: cut ladder (`FeatureFlags`); text under a cut must still validate, because the audit runs with flags on and off (AC 5 and E2 note).
- 4.4 (D-S44-2): T1 text was rewritten by the coordinator; the GDD was not updated. This is the drift in AC 16.
- 3.7 deferred: render script prints "Failed to compile depended scripts" (harmless); re-render only when a line text changes.
- deferred-work.md: "brittle source-regex tests" (AC 13 uses exact-string search with an allowlist, not regex); "PlaceholderScreen assertion (breaks in Story 6.8)" already fixed in 6.8.
- deferred-work.md, duck: "Breakpoint line still plays when `breakpoint_enabled` is off (cut #3)" (N1). Known deviation: record in Completion Notes, do not fix here.
- deferred-work.md, duck: "`->` in hint text is sent to the mumble voice (letters only)": the arrow `→` is allowed by `DuckLineDef` (D-S44-10). Do not change the arrow.

### Architecture and rules that bind this story

- Text is data, not code (GDD/NFR and this story's AC 13). New resources are `Def` subclasses with `validate()`, like `EndingText` and the duck defs.
- Presentation only: nothing here touches the sim. `game/tools/check_guards.sh` must pass (AC 15).
- ASCII for duck lines (`DuckLineDef`), glyph-font coverage for everything drawn (`test_font_coverage.gd`). The arrow `→` in `hint_*` is the one allowed non-ASCII glyph (D-S44-10).
- English only (NFR17). Tone: deadpan, rubber-duck humour; tutorial lines are jokes that still instruct (GDD Duck "Tone"). The audit does not rewrite jokes; it checks them against the GDD.
- Autoload/`Game` state is not read by the text resources.

### Testing standards

- GUT, run from the worktree root (`game/` addon). New tests: `tests/unit/test_text_audit.gd`, `tests/integration/test_text_triggers.gd`. Extend `test_duck_lines.gd` (T1 GDD text), `test_font_coverage.gd`, `test_data_validation.gd`.
- Deterministic: use the sim frame helpers and the existing flow tests; no `await`, no `Timer` in tests that assert timing (use the existing helpers).
- Run the full suite and the guard script before closing (E4).

### Project Context Rules

- Rules from project-context and the GDD module config: English output for documents (`document_output_language: English`); the story is written in English. Communication with the director is Italian (`communication_language`).
- No new library, no new addon, no new asset. Godot 4.7 with the GL Compatibility renderer (`game/project.godot`).
- Commit only on the story branch as usual (PR-only workflow); this story does not commit by itself.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.9]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Duck (hint system)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Asset Requirements]
- [Source: _bmad-output/implementation-artifacts/6-8-ending-sequence.md#Dev Notes, D-S68-8, D-039]
- [Source: _bmad-output/implementation-artifacts/4-4-duck-hint-template.md#D-S44-1, D-S44-2]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Audio credit line, render script, brittle tests]

## Dev Agent Record

### Agent Model Used

Claude (gds-create-story, unattended pipeline run, 2026-11-12); implemented by Claude Opus 5.5 (gds-dev-story, unattended, 2026-11-12)

### Debug Log References

### Completion Notes List

- Implemented the three shared text resources (`TextFixedLines`, `TextSkyComments`, `TextScreenText`, all `extends Def` with `validate()` and `all_text()`) in `game/src/ui/text/` and `game/data/text/`. The screens preload the `.tres` once (a `const` per script) and expose the former constant names as read-only static getters (`Hud.SKY`, `Hud.SKY_NULL_POINTER`, `Hud.SKY_SEGFAULT`, `TitleScreen.TITLE_TEXT`/`PROMPT_TEXT`, `HarvestScreen.PROMPT_TEXT`/`FIXED_FALLBACK`, `DeadScreen.TEXT`), so `hud_frame.gd` and the existing tests are unchanged. `IntroScreen.caption_for` reads the panels from `screen_text.tres` (CAPTION_1..3 removed; timing and `intro_handover` stay in code). No visible text changed; no sim code edited (check_guards OK).
- C6: `placeholder_screen.gd` holds no prompt literal (only the FIGHT debug label, `chrome`): nothing to move. C7: `ending_screen.gd` untouched.
- D1 (D-S69-3, coordinator decision): GDD Duck row 2 and Boss 1 tutorial beat 1 now read the shipped T1 text (doc only). D2: `test_duck_lines.gd` already pinned the shipped T1; a comment now points to D-S44-2 and D-S69-3. D3: no other FAIL. AC 17: no line text changed, so `duck_clips.tres` was not re-rendered.
- E1 `tests/unit/test_text_audit.gd` (13 tests): GDD duck table, budget 10, hint windows derived from the three `boss_def.tres` through `DuckHint.windows_of`, bubble fit/ASCII, fixed lines vs GDD and vs `BossDef.fixed_line`, sky comments and the HUD accessor per boss id and no boss, fallback, Def validation failures, screen text and the 2 + 2 + 1 caption grouping, ending text audited in place, and the literal-reappearance check (exact quoted-string search of 7 listed scripts, allowlist `MOVED_LITERALS`; not a tree-wide regex).
- E2 `tests/integration/test_text_triggers.gd` (2 tests): real Main/Game/SimClock run Title -> Intro (line 1) -> Fight 1 (T1 at control start, T2 at the first `;` reached by ticking, T3 after a real shift to [A, D], T4 after `debug_skip_phase`) -> Harvest (line 8) -> Fight 2 (lines 6, 7, then a Breakpoint hint) -> Harvest -> Fight 3 (3rd-death hint through the retry route) -> Ending (line 9); and the Segfault-cut run (Null Pointer last, 3rd-death hint there, line 9 still fires). Seams stated in the header: the director's bubble is detached (no queue waits), the director is polled by hand, the Breakpoint hint uses the `EventBus.breakpoint_started` signal the real skill emits. Determinism: the run seed is fixed (`RUN_SEED`) right after the title press, since `Game._begin_fight` would otherwise seed from the clock; the test restores the AudioManager unlock state (otherwise later bubble tests leak).
- E3: `test_font_coverage.gd` covers `all_text()` of the three new resources and `ending_text.tres`. B4: `test_data_validation.gd` asserts the three text resources are found by the scan and are Defs (the scan validates them).
- E4: full headless GUT suite as in CI (`-gdir=res://tests -ginclude_subdirs`, unit + integration + replay): 1587 tests, 140239 asserts, "All tests passed!", no failure markers, no pending/risky. `bash game/tools/check_guards.sh`: OK. Import: no script/parse errors.
- Deferred N1 (Breakpoint duck line plays when cut #3 is off): NOT fixed. It is not a text move: gating N1 needs N2 decoupled from N1 in `DuckDirector.due_null_pointer_beat` (5.6 spec says the Breakpoint line always plays), so it stays in deferred-work.md as a known deviation.

**Text audit table (AC 18)**

| GDD text item | Data entry | Trigger | Test | Result |
|---|---|---|---|---|
| Duck 1 intro | `duck_lines.tres` `intro_handover` | Intro panel 3 | test_text_audit, test_intro_flow, test_text_triggers | PASS |
| Duck 2 T1 | `t1_shift` (shipped D-S44-2 text; GDD synced) | Fight 1 control start | test_text_audit, test_duck_lines, test_text_triggers | PASS (drift fixed in GDD) |
| Duck 3 T2 | `t2_semicolon` | first `;` (iteration >= 1) | test_text_audit, test_duck_director, test_text_triggers | PASS |
| Duck 4 T3 | `t3_dash_strike` | Dash Strike window active | test_text_audit, test_duck_director, test_text_triggers | PASS |
| Duck 5 T4 | `t4_phase_two` | Boss 1 phase 2 | test_text_audit, test_duck_director, test_text_triggers | PASS |
| Duck 6 Breakpoint | `n1_breakpoint` | Boss 2 start (plays even with cut #3, deferred N1) | test_text_audit, test_duck_director, test_text_triggers | PASS (known deviation N1) |
| Duck 7 Watch | `n2_hold_r` | Boss 2 start after line 6, Watch on | test_text_audit, test_duck_director, test_text_triggers | PASS |
| Duck 8 harvest | `harvest_shared` | each Harvest | test_text_audit, test_harvest_flow, test_text_triggers | PASS |
| Duck 9 ending | `ending` | Ending frame 300 (both run paths) | test_text_audit, test_ending_flow, test_text_triggers | PASS |
| Duck 10 hint template | `DuckHint.PREFIX` + 5 `hint_*` = every boss window | Breakpoint (once per phase), 3rd death | test_text_audit, test_duck_hint, test_text_triggers | PASS |
| Budget | 9 + template = 10 | - | test_text_audit, test_duck_lines | PASS |
| Fixed line Infinite Loop | `fixed_lines.tres` `infinite_loop` = BossDef | defeat / Harvest | test_text_audit | PASS |
| Fixed line Null Pointer | `null_pointer` = BossDef | defeat / Harvest | test_text_audit | PASS |
| Fixed line Segfault | `segfault` = BossDef | defeat (Ending follows) | test_text_audit | PASS |
| Sky default | `sky_comments.tres` `default_comment` | Infinite Loop / no boss | test_text_audit, test_hud_layout | PASS |
| Sky Null Pointer | `null_pointer` | Fight 2 | test_text_audit, test_null_pointer_fight | PASS |
| Sky Segfault | `segfault` | Fight 3 | test_text_audit, test_debug_keys | PASS |
| Title / prompt / intro captions / DEAD line | `screen_text.tres` | Title, Harvest, Intro, DEAD | test_text_audit, test_title_font, test_dead_screen, test_intro_screen | PASS |
| Ending text (caption, commit, credits, prompt) | `ending_text.tres` (6.8) | Ending | test_text_audit, test_ending_screen, test_font_coverage | PASS (`audio: TBD` stays for 7.x) |

**Prose literal inventory, extension of the Dev Notes table (AC 12, A1)** — every other prose-like literal found by the grep of `game/src`:

| String(s) | File | Class |
|---|---|---|
| `Quack. Weak window: `, `→` (template implementation, checked against GDD row 10) | `src/ui/duck/duck_hint.gd` | fixed-text |
| `PAUSED`, `ACTION 1 J`, `ACTION 2 K`, `SHIFT Q E`, `BREAKPOINT SPACE`, `WATCH R`, `[M] MUTE OFF` | `src/ui/screens/pause/pause_screen.gd` | chrome |
| `void %s() // hp %d` (boss header), `reg`, box glyphs | `src/ui/hud/hud.gd` | chrome |
| `hp: 0b` | `src/player/player_health.gd` | chrome |
| `stack frame 0x03` (arena label), arena layout rows | `src/arena/arena.gd` | fixed-text |
| `i = %d` (Infinite Loop counter) | `src/presentation/boss_view.gd` | fixed-text |
| `/* test */` (practice target) | `src/presentation/practice_target_view.gd` | chrome |
| `NEXT: `, `drop %s  weak %s %s` (Watch readouts) | `src/skills/watch/watch_overlay.gd` | chrome |
| `fight left` (skill stop reasons), `cancel`/`start` | `src/skills/*`, `src/player/action_state_machine.gd` | chrome (debug/log) |
| frame/perf overlay rows, smoke-scene labels (`click to hear the duck`, `speaking`, `voice did not start`, `click to start the audio pan test`) | `src/debug/*` | chrome (debug) |
| voice/log warnings, JS snippets, `<raw>`, `<no id>` | `src/autoloads/*`, `src/bosses/framework/attack_def.gd` | chrome (log) |
| `CLEAR`/`HITS` labels, credits, `fix: wild shift`, prompt | `src/ui/screens/ending/ending_text.gd` (defaults only; shipped values in `ending_text.tres`) | data (6.8) |

- Human checks (Group F) pending and unticked: F1 (Chrome read-through of all game text) and F2 (Epic 6 butler deploy to the itch draft, Chrome/Firefox smoke, build size vs NFR4). Firefox/Safari items from earlier epics remain open in deferred-work.md.
- Design calls: D-S69-1..7 followed as written (coordinator confirmed D-S69-3 shipped-text-wins and the chrome/data split). New small call: the former constant names are kept as read-only static getters rather than removed, so callers (`hud_frame.gd`, existing tests) keep working without reading the resources themselves. The extended inventory lives here in Completion Notes because Dev Notes is not an editable section for the dev workflow.

### File List

- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` (T1 row 2 and tutorial beat 1)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/6-9-game-text-audit.md`
- `game/src/ui/text/text_fixed_lines.gd` (new)
- `game/src/ui/text/text_sky_comments.gd` (new)
- `game/src/ui/text/text_screen_text.gd` (new)
- `game/src/ui/text/*.gd.uid` (new, generated by import)
- `game/data/text/fixed_lines.tres` (new)
- `game/data/text/sky_comments.tres` (new)
- `game/data/text/screen_text.tres` (new)
- `game/src/ui/hud/hud.gd`
- `game/src/ui/screens/harvest/harvest_screen.gd`
- `game/src/ui/screens/title/title_screen.gd`
- `game/src/ui/screens/intro/intro_screen.gd`
- `game/src/ui/screens/dead/dead_screen.gd`
- `game/tests/unit/test_text_audit.gd` (new, + `.uid`)
- `game/tests/integration/test_text_triggers.gd` (new, + `.uid`)
- `game/tests/unit/test_font_coverage.gd`
- `game/tests/unit/test_data_validation.gd`
- `game/tests/unit/test_duck_lines.gd`

## Change Log

- 2026-11-12: Story 6.9 implemented. Shared text resources in `data/text/` (fixed lines, sky comments, screen text); HUD and screens read them; GDD T1 synced to the shipped line (D-S69-3); audit and trigger tests added; Group F human checks pending.
