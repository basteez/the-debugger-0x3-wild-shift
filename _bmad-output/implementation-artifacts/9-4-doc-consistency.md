---
baseline_commit: d368a86
---

# Story 9.4: Doc Consistency

Status: done

<!-- Created unattended by gds-create-story (2026-11-17), from story/9-3 HEAD d368a86 (stacked; PR base story/9-3-run-and-assist-clarity). Sources: Epic 9 in epics.md (Story 9.4 ACs), the brief epic9-brief.md (story 4) and the triage epic9-triage.md (gameoff-wt/, its "9-3-doc-consistency" proposal, now 9.4). deferred-work.md items 9/39, 123, 500 plus the bookkeeping of every RESOLVED row. Docs only. Nothing was committed. The create phase made no doc edits: the worktree is clean at d368a86 apart from this file and the sprint-status 9-4 status line. -->

## Story

As a reader of the repo or the planning files,
I want one submission deadline stated the same way everywhere, the GDD in sync with the shipped Epic 8 and 9 player-facing behaviour, and the deferred-work backlog closed out accurately,
so that nobody plans against the wrong date and the docs describe the game that ships.

**Requirements:** deferred-work.md 9/39 (header and results, strict DO), 123 (1.7 review, doc nits), 500 (6.9 review, GDD HUD mock-up); triage 9-3; bookkeeping of every triage RESOLVED row.

## Acceptance Criteria

1. **Given** README, the GDD, the planning epics (and its GDD copy), the sprint-status header and game-architecture **When** they state the submission deadline **Then** each states the same phrase: "internal submission target Nov 29 12:00 PST; official Game Off cutoff Dec 1 13:37 PST" (or the agreed short form, identical across files). No file gives Dec 1 13:37 as the only deadline or Nov 29 12:00 as the only deadline (9/39).
2. **Given** the historical records (story files, devlogs, the 1-3 story review notes, the brief and addendum, decision-log D-016 and D-025) **When** this story closes **Then** they are left as written (history). Only active, forward-facing docs change.
3. **Given** the GDD HUD mock-up (gdd.md, the duck bubble block under "HUD Layout") **When** it is synced **Then** it shows the shipped T1 text "Q or E shifts your bits. Go on, shift. It's waiting. Only the two on the left are live; the rest are in code review." word-wrapped at 12 columns, matching the Duck table and `game/data/duck/duck_lines.tres` (500).
4. **Given** the 1-7 story file's DC9 design call and its mute-label completion note **When** they are corrected **Then** the mute wording matches `pause_screen.gd` (`[M] MUTE ON` while muted, `[M] MUTE OFF` otherwise) and the DC9 note mentions the `NOTIFICATION_WM_WINDOW_FOCUS_OUT` canvas-blur path that shipped (123).
5. **Given** the GDD describes the title, pause and tutorial systems **When** it is checked against Epics 8 and 9 **Then** it states: the `[N]` two-press confirmation (`PRESS N AGAIN: WIPE PROGRESS`, 1.5 s, a click or pad Select works the same); the title entry gate (30 sim frames after a tutorial replay, an ending or a practice leave; boot title never gated); the pause `: NEXT ATTEMPT` suffix on the `[B]` row; that the assist applies from the next attempt. The tutorial replay, skip, P-pauses, and the `;` hurt circle of 1.0 tile are already in the GDD and are only verified, not duplicated.
6. **Given** README.md **When** it lists the title options **Then** the table has the `[T]` tutorial replay row (keyboard T, no pad button), the `[N]` row says it needs a second press, and the play-options paragraph notes the half-second title gate after a tutorial replay, ending or practice leave.
7. **Given** deferred-work.md **When** this story closes **Then** every triage RESOLVED row (70) carries "Resolved (verified 2026-11-17 by Epic 9 triage: <evidence>)" after its original text, original text kept, no line deleted. Items 9/39, 123 and 500 carry "Resolved in Story 9.4" notes. HUMAN and DO items for other stories are not ticked. The font CC0 lines (1.5 H2 and item 101) get a note only and stay open (HUMAN).
8. **Given** the game text under `game/` **When** it is audited for dates **Then** no in-game string carries a deadline or date (grep verified 2026-11-17), so no code change is made. A later date found in game text would be noted here as a finding, not silently fixed.
9. **Given** sprint-status.yaml **When** this story is created and implemented **Then** the 9-4 key reads `ready-for-dev` now (set with the Edit tool) and `done` only after code review. The header deadline comment matches AC 1. No new Epic 9 entry is needed in epics.md: its Epic 9 section and the 9.4 ACs already exist.
10. **Given** the decision log **When** this story closes **Then** a D-053 row records the 9.4 design calls (deadline wording, GDD sync scope, deferred bookkeeping rule), next to D-052.
11. **Given** the change set **When** it is verified **Then** `git diff --stat` touches only the docs listed in Tasks (no file under `game/`), `grep` finds no active doc that gives a single deadline, and the GUT suite and `game/tools/check_guards.sh` are unaffected (run once anyway, per the brief's process rules, if the environment allows).

## Tasks / Subtasks

- [x] Task 1: deadline wording (AC 1, 2)
  - [x] 1.1 `README.md` line 30 (Status): replace "The submission deadline is **2026-12-01 13:37 PST**." with the agreed phrase.
  - [x] 1.2 `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`: header line 21 (Jam), Goals item 1 (line 84), Epic 7 row in the epics table (line 637, "submission by Nov 29 12:00 PST"), Success Criteria "Submitted by 2026-11-29 12:00 PST, ≥ 49 h before the deadline." (line 653).
  - [x] 1.3 `_bmad-output/planning-artifacts/epics.md`: NFR16 (line 153), Epic 7 goal (lines 314 and 1471, "submitted by Nov 29 12:00 PST."), Story 7.9 AC (line 1646, "submitted by 2026-11-29 12:00 PST (≥ 49 h before the deadline)").
  - [x] 1.4 `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md`: Epic 7 goal (line 111) and the 7.8 table cell (line 123).
  - [x] 1.5 `_bmad-output/implementation-artifacts/sprint-status.yaml`: header line 52 ("SUBMISSION DEADLINE: 2026-11-29 12:00 PST.") and the Epic 7 comment (line 160, "SUBMIT by Nov 29 12:00 PST").
  - [x] 1.6 `_bmad-output/game-architecture.md` line 52 (team line, "submission target 2026-11-29 12:00 PST").
  - [x] 1.7 `_bmad-output/implementation-artifacts/deferred-work.md` line 599 (H-S79-5 human item): same phrase.
  - [x] 1.8 Leave history alone: devlog-04 (line 9 and 53), devlog-03, brief.md and addendum.md, 1-3 story notes (lines 305, 383), decision-log D-016 and D-025.
- [x] Task 2: GDD sync for Epics 8 and 9 (AC 3, 5)
  - [x] 2.1 Option hotkeys paragraph (line 262): `[N]` row now "shown only when a save is past the first boss and the run is not completed" (matches `title_screen.gd` line 253: `highest_boss > 1 and not completed`), two-press confirm `PRESS N AGAIN: WIPE PROGRESS` for 90 sim frames (1.5 s).
  - [x] 2.2 Press-to-start: add a bullet "Title entry gate (Story 9.1, D-S91-1)" before the Gamepad line (30 sim frames, `TITLE_ENTRY_GATE_FRAMES`, boot title never gated). Gamepad line: Select confirms `[N]` as well (pad Select is the option action, same path).
  - [x] 2.3 Pause screen bullet (line 265): the `[B]` row adds `: NEXT ATTEMPT` while the assist change waits (Story 9.3, D-S93-3).
  - [x] 2.4 Assist option paragraph (line 491): applies from the next attempt, never mid-fight (D-S74-1); pause row text `[B] DEBUG BUILD ON: NEXT ATTEMPT` (or OFF).
  - [x] 2.5 Tutorial "Replay" sentence (line 337): "no pad button" (D-S82-13).
  - [x] 2.6 HUD mock-up block (between "### HUD Layout" and "- **Register panel**", the code block around lines 540-564): replace the old "Q and E / shift your / bits..." rows with the wrapped shipped T1 text, 12 columns per row (rows 23 to 32), keeping the arena frame and the `18 └` bottom row (deferred 500).
  - [x] 2.7 Verify, do not duplicate: `;` hurt circle 1.0 tile (around line 359), miss lines (line 241, matches `log_panel.gd:106`), tutorial skip and P pauses (line 337).
- [x] Task 3: README (AC 6)
  - [x] 3.1 Status line: same phrase as 1.1.
  - [x] 3.2 Options table: N row "press N again, or click the row again" and pad "Select / Back, then again"; add row "Tutorial replay (the guided test suite, then back to the title) | Title | T | none".
  - [x] 3.3 Paragraph after the options table: title gate note (half a second after a tutorial replay, an ending or a practice run returns to the title).
- [x] Task 4: story 1-7 wording (AC 4, deferred 123)
  - [x] 4.1 DC9 design call (line 81): add a pointer to the "DC9 resolved" note that names the WM_WINDOW_FOCUS_OUT path.
  - [x] 4.2 Review defer at line 237: append the shipped mute wording and "Resolved in Story 9.4 (D-S94-4)".
- [x] Task 5: deferred-work.md bookkeeping (AC 7, 8)
  - [x] 5.1 Annotate every triage RESOLVED row (70). Line numbers are for the current file (640 lines). Each row is matched on its text, and the script asserts the match. Evidence per row is the triage "Evidence / reason" text, shortened. The full mapping is in the triage table, so the dev agent can re-derive it from there.
  - [x] 5.2 Items 9 (open question), 39 (results), 123 and 500 get "Resolved in Story 9.4 (D-S94-n)" notes.
  - [x] 5.3 Font CC0 (lines 30 and 101): note only, stays HUMAN.
  - [x] 5.4 No line deleted; no tick on any HUMAN item.
- [x] Task 6: decision log and sprint status (AC 9, 10)
  - [x] 6.1 `gdds/.../decision-log.md`: add D-053 row after D-052 (4 columns: ID, date 2026-11-17, decision, source "Story 9.4 (gds-create-story / dev-story)").
  - [x] 6.2 sprint-status.yaml: `9-4-doc-consistency: ready-for-dev` (Edit tool). Set to `review` then `done` only per the epic pipeline (not in this story's create phase).
- [x] Task 7: verification (AC 8, 11)
  - [x] 7.1 `grep` for the old single-date strings in active docs (README, GDD, planning epics and its copy, sprint-status, game-architecture): no active line states only "2026-12-01 13:37" or only "2026-11-29 12:00" as the deadline.
  - [x] 7.2 `grep -rn -E "2026|Nov 29|Dec 1" game/` returns no deadline text.
  - [x] 7.3 `git diff --stat`: docs only, nothing under `game/`. Do not commit (brief: review phase commits).

## Dev Notes

### Verified facts (read on 2026-11-17, branch story/9-4 on d368a86)

- Deadline mentions that must change (active docs): README.md:30; gdd.md:21, 84, 637, 653; planning epics.md:153, 314, 1471, 1646; gdds/.../epics.md:111, 123; sprint-status.yaml:52, 160; game-architecture.md:52; deferred-work.md:9 (open question), 39 (results), 599 (H-S79-5).
- Already correct and already in the Epic 9 section of epics.md: the 9.4 ACs (lines ~1845-1860).
- `title_screen.gd`: `[N]` available when `highest_boss > 1 and not completed` (line 253); `NEW_RUN_CONFIRM_FRAMES = 90` (line 77); pad Select is the option action of `new_run` (pad mapping, `project.godot [input]`).
- `game.gd`: `TITLE_ENTRY_GATE_FRAMES = 30` (line 33); the gate arms on any non-TITLE to TITLE entry (line 726); the boot title is never gated.
- `pause_screen.gd`: `MUTE_ON_TEXT = "[M] MUTE ON"` is shown while muted (line 119); `ASSIST_PENDING_SUFFIX = ": NEXT ATTEMPT"` (line 49).
- `log_panel.gd:106`: miss lines `// miss: ";" is closed` / `// miss: aim for the ";"` (matches GDD line 241).
- `duck_lines.tres:14` and GDD Duck row 2 (line 459) and tutorial beat 1 (line 379): the shipped T1 text is already the wording in these three places. Only the HUD mock-up (around lines 540-564) is stale.
- Game text: no deadline or date string under `game/src`, `game/data` or `game/assets` (grep 2026 finds only a duck seed, a font licence date and an author line).
- `README.md:137` and the font LICENSE declare CC0 for the font. Tiziano's confirmation is still HUMAN (triage 1.5 H2, item 101).
- `devlog-04.md:9` and `:53` state "deadline 2026-11-29". Devlogs are published posts; they stay as written.

### Design calls (Story 9.4)

- **[design call] D-S94-1 (9/39): one wording for both dates.** Default: "internal submission target Nov 29 12:00 PST; official Game Off cutoff Dec 1 13:37 PST", with the short form "Nov 29 12:00 PST" for the target and "Dec 1 13:37 PST" for the cutoff in tables. The epics 9.4 AC asks for "the same words" in each file, so the phrase is copied, not paraphrased. Dates stay in the 12-hour PST form the files already use.
- **[design call] D-S94-2 (500): HUD mock-up shows the shipped T1 wording,** word-wrapped at 12 columns as the duck bubble does. The mock is not a spec of the line budget, so no row count is enforced.
- **[design call] D-S94-3 (AC 5): GDD gets only what is missing.** The tutorial, skip, P-pauses, `;` hurt circle (1.0 tile, D-051) and miss lines were already present, so they are verified, not repeated. Added: `[N]` two-press, title entry gate, pause `: NEXT ATTEMPT`, assist applies from the next attempt.
- **[design call] D-S94-4 (123): wording follows the code, not the old notes.** The mute row text is `[M] MUTE ON` while muted, which is the reverse of what "ON" might suggest to a reader, so the completion note states it explicitly. The DC9 pointer names the canvas-blur path.
- **[design call] D-S94-5 (deferred bookkeeping): RESOLVED rows get a dated annotation, never a deletion.** HUMAN and DO rows owned by other stories are not ticked. The triage verdict is the source; the code was re-checked by the triage on 2026-11-17.
- **[design call] D-S94-6 (AC 8): no game text change.** No in-game string carries a date, so the brief's "if a doc string inside game text is the wrong date, note it" has nothing to note.

### Open questions (defaults chosen, no elicitation)

- **O1 (font CC0 line):** the brief expects "likely just a tick", but the triage marks it HUMAN, and only Tiziano can confirm the licence choice. Default: note added, not ticked (D-S94-5).
- **O2 (historical docs):** devlog-04, the brief and addendum, the 1-3 story notes and decision-log D-016 and D-025 say Nov 29 or Dec 1 in their own context. Default: left as written, since rewriting history would misdate them. Revisit only if Tiziano wants them corrected.
- **O3 (two epics files):** planning-artifacts/epics.md is the one the brief names, but a copy exists under gdds/gdd-.../epics.md. Default: both get the same deadline phrase, so neither contradicts the other.
- **O4 ([N] availability wording):** D-048 says "shown only when a save exists", but the code shows it only past Boss 1 and not after a completed run (Story 9.3). Default: the GDD states the code's rule, and D-048 is not rewritten.
- **O5 (pad confirm):** the GDD says pad Select confirms `[N]`. The code routes pad Select through the same option action as N. Default: documented as such; no pad test added (docs-only story).
- **O6 (D-053 decision-log row):** the brief asks for a decision-log entry per epic, and D-052 already covers the deadline rule. Default: a short D-053 row for the 9.4 calls only.

### Testing

- Docs only. No GUT or CI change expected. Run `game/tools/check_guards.sh` once if the environment allows (it reads only `game/`), and the full GUT suite as CI does if time allows, per the brief's process rules.
- Verification is by grep (Task 7) and a read-through of each changed section.

### Project Structure Notes

- Changes are limited to: `README.md`, `_bmad-output/game-architecture.md`, `_bmad-output/planning-artifacts/epics.md`, `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/{gdd.md,epics.md,decision-log.md}`, `_bmad-output/implementation-artifacts/{deferred-work.md,sprint-status.yaml,1-7-pause-screen-and-auto-pause-on-focus-loss.md,9-4-doc-consistency.md}`.
- No file under `game/` changes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md, "Epic 9: Deferred Work Burn-down", Story 9.4 ACs]
- [Source: gameoff-wt/epic9-brief.md, "Stories" item 4]
- [Source: gameoff-wt/epic9-triage.md, "9-3-doc-consistency" proposal and per-item table rows 9, 39, 123, 500 and the RESOLVED rows]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md, lines 9, 39, 123, 500, 599]
- [Source: game/src/autoloads/game.gd, TITLE_ENTRY_GATE_FRAMES, title entry gate]
- [Source: game/src/ui/screens/title/title_screen.gd, NEW_RUN_CONFIRM_FRAMES, `new_run` availability]
- [Source: game/src/ui/screens/pause/pause_screen.gd, MUTE_ON_TEXT, ASSIST_PENDING_SUFFIX]

## Project Context Rules

- Docs only. Main is protected: work on branch `story/9-4-doc-consistency`, stacked on `story/9-3-run-and-assist-clarity`. Never commit to main.
- Set story status with the Edit tool (not sed -i, not scripts).
- Never use the Fable model.
- Keep the tone and language of each file (English docs; `README.md` and GDD are English).

## Dev Agent Record

### Agent Model Used

claude-haiku-5-5 (create-story phase, unattended); claude-opus-5-5 (dev-story phase, unattended)

### Debug Log References

- Triage read: `epic9-triage.md` 495 lines; RESOLVED rows counted at 70 (summary table matches).
- Deadline grep over active docs: README.md:30, gdd.md:21/84/637/653, planning epics.md:153/314/1471/1646, gdds epics.md:111/123, sprint-status.yaml:52/160, game-architecture.md:52, deferred-work.md:9/39/599.
- Draft edit and annotation scripts were run in the create phase to check that every match is unique, then reverted so that the dev phase makes the edits. They live in the session scratchpad (`.../scratchpad/apply94.py` and `.../scratchpad/annotate94.py`) and may be cleared; the Tasks list is the authoritative change set.

### Completion Notes List

- Story created unattended (no elicitation). ACs follow the Story 9.4 entry in epics.md and the brief; AC 5 to AC 11 add the GDD Epic 8 and 9 sync, the README, the deferred bookkeeping, the decision-log row and the verification.
- Create-phase edits were reverted; the worktree is clean at d368a86 apart from this story file and the sprint-status 9-4 line.
- Design calls D-S94-1 to D-S94-6 and open questions O1 to O6 are above, with defaults chosen.
- Dev phase (claude-opus-5-5, unattended, 2026-11-17): coordinator accepted D-S94-1..6 and defaults O1-O6.
- Task 1: every active doc now carries both dates (internal target Nov 29 12:00 PST; official Game Off cutoff Dec 1 13:37 PST). History left as written (devlogs, brief/addendum, 1-3 notes, D-016, D-025). Grep check: the only remaining single-date mention in an active doc is the Epic 9 window line in planning epics.md ("Window line now reads "started 2026-11-17" (coordinator fix), so no single-date mention remains.
- Task 2: GDD gets `[N]` two-press with the code's availability rule (`highest_boss > 1 and not completed`, NEW_RUN_CONFIRM_FRAMES 90), the title entry gate (TITLE_ENTRY_GATE_FRAMES 30, boot title never gated), pause `: NEXT ATTEMPT`, assist from the next attempt, `[T]` no pad button. HUD mock-up duck bubble now shows the shipped T1 text wrapped greedily at 12 columns, 11 rows (rows 23-33, no quotes, as `DuckBubble.wrap` draws it); the story estimated rows 23-32, but D-S94-2 enforces no row count. `;` hurt circle, miss lines, skip and P-pauses verified present, not duplicated.
- Task 3/4: README status, options table (`[N]` second press, `[T]` row) and the title-gate sentence; 1-7 story DC9 pointer and mute wording (`[M] MUTE ON` while muted, matches pause_screen.gd:41/119).
- Task 5: deferred-work.md 77 lines annotated, 0 deleted (640 lines before and after): 70 triage RESOLVED rows, items 9/39/123/500 with "Resolved in Story 9.4", font CC0 lines 30 and 101 note only (stay HUMAN, unticked), H-S79-5 wording. Spot-check of 17 RESOLVED claims against the current code (37, 43, 55, 65, 90, 105, 146, 161, 212, 219, 271, 341, 485, 488, 507, 559, 566): all resolved in substance. Items 559 and 566 cited `Main.shows_fight_placeholder`, which no longer exists (PR #65 retired the label; placeholder_screen.gd is text-free), so their evidence text was reworded to that; no RESOLVED claim failed.
- Task 6: decision-log D-053 row added after D-052. Sprint status 9-4 set in-progress then review (Edit tool).
- Task 7: no date or deadline in game text (grep finds only the duck voice seed and the font LICENSE date/author line). `git diff --stat`: docs only, nothing under `game/`. `game/tools/check_guards.sh` OK. Full GUT like CI (`--headless --import` first, 0 script/parse errors): 1905/1905 passing, 150558 asserts, "All tests passed!", no failure markers.
- Helper scripts: the create-phase `apply94.py` was used minus its HUD regex block (hand-edited instead, its line-number layout was off) and minus the sprint-status line (already set); `annotate94.py` used as is, then the two 559/566 evidence strings corrected.

### File List

- `_bmad-output/implementation-artifacts/9-4-doc-consistency.md` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/1-7-pause-screen-and-auto-pause-on-focus-loss.md`
- `_bmad-output/planning-artifacts/epics.md`
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md`
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/epics.md`
- `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md`
- `_bmad-output/game-architecture.md`
- `README.md`

### Change Log

- 2026-11-17: story created (ready-for-dev), unattended create-story run.
- 2026-11-17: dev-story complete (docs only): deadline wording, GDD Epic 8/9 sync and HUD mock-up, README options, 1-7 wording, deferred-work bookkeeping (77 annotations), D-053; status review.

### Review Findings (2026-11-17, gds-code-review: Blind Hunter, Edge Case Hunter, Acceptance Auditor)

| # | Finding | Disposition |
|---|---------|-------------|
| 1 | HUD mock-up arena row labels uneven (GDD) | Fixed: labels re-spaced 14..18 |
| 2 | Epic 9 window said "proposed Nov 25-28" | Fixed (coordinator): epics.md and D-052 now say "started 2026-11-17" |
| 3 | README title-gate sentence was a comma splice | Fixed |
| 4 | "Open (unchanged) ... Resolved" self-contradiction (deferred-work line 39) | Fixed: relabelled historical, fragile "line 9" pointer replaced |
| 5 | Three "Resolved (verified)" rows overclaim (ScreenFX dither/BASE_RES, label_rects coords, Esc in fullscreen) | Annotated "partially verified only"; remain deferred (no code change in a docs-only story) |
| 6 | "marked [x]" wording on rows that were already [x]; informational rows counted in the 70; D-052 count mix of items and lines | Deferred: cosmetic, history preserved |
| 7 | GDD "Duck row 2 / or 5 s" edit; 1-7 DC9 body only carries a pointer | Deferred: low, covered by existing pointers |
| 8 | Title gate also arms on any non-TITLE to TITLE transition (docs list a subset); GDD 1.5 s N arm not in README | Deferred: doc is a correct subset |
| 9 | Dec 1 13:37 PST is the official time, flagged for a human to re-check | Deferred: HUMAN |

Verified OK: docs-only diff, no deleted history in deferred-work.md (76/77 pure appends, one intentional rewording), all deadline mentions consistent, [N]/[T]/title gate/NEXT ATTEMPT match title_screen.gd, pause_screen.gd, game.gd, about 22 of 25 sampled Resolved rows accurate. check_guards OK; full GUT 1905 passing.
