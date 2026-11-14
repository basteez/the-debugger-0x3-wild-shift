---
baseline_commit: 3ba6de2
---
# Story 7.9: itch.io Page, README and Submission

Status: review

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with a default (D-S79-n); the implementer follows them or records a change in Completion Notes. Scope is the REPO side: README, the in-game credit line, and an itch.io page copy draft committed to the repo. The cover GIF, the screenshots, the itch.io page edit and the jam submission are HUMAN steps (Tiziano): they are listed as pending human ACs H-S79-1..5 and are NOT done by this story. On dev completion the status becomes `review` with those ACs pending (deferred-work.md). -->

## Story

As the director,
I want a README, an itch.io page copy and in-game credits that match and are licence-clean,
so that raters understand the game in 30 seconds and the jam entry is valid.

**Requirements:** FR64, NFR15, NFR17. GDD Epic 7 row 7.8 (the itch page), AC text in `_bmad-output/planning-artifacts/epics.md` Story 7.9.

**Depends on:** 7.8 (harness and `[metrics]` lines: no gameplay change here), 7.1 (music placeholders and their README), 7.2 (SFX generator, CC0 by construction), 7.5 (gamepad bindings and the Web Audio unlock note), 7.7 (fullscreen and debug options on the title and pause screens), 7.6 (practice option), 7.4 (debug build assist option), 6.8 (ending credits screen).

## Acceptance Criteria

1. **Given** the repo, **when** the README is read, **then** it shows the full title "The Debugger 0x03: Wild Shift", the pitch line "shift your weapon's bits mid-fight", a one-paragraph description, and the Status line no longer says the game is only planned.
2. **Given** the README, **when** a reader looks for controls, **then** a table lists every keyboard and gamepad binding for play (move, action 1, action 2, shift `<<`, shift `>>`, Breakpoint, Watch, pause) and a second table lists the title and pause options (New run, Practice, Debug build, Fullscreen, Mute), each taken from `game/project.godot` input map and the title/pause screens (not from memory).
3. **Given** the README, **when** it is read, **then** it contains the AI-use disclosure (same wording as the itch copy, AC 6) and a credits section listing every asset with its licence: font (Wildshift8, CC0 1.0, own work), SFX (generated in-repo by `game/tools/gen_sfx.py`, CC0 by construction), placeholder music (generated in-repo by `game/tools/generate_placeholder_music.py`, CC0 by construction, marked PLACEHOLDER), mumble-speech (Tiziano Basile's OWN library, MIT and Apache-2.0, vendored with both licence files), GUT (MIT, dev only, not exported), Godot Engine (MIT).
4. **Given** the mumble-speech credit, **when** it appears in README, itch copy or in-game credits, **then** it is credited as Tiziano Basile's own library (`basteez/mumble-speech`), never as third-party "courtesy of", "thanks to" or "by a community author".
5. **Given** the README, **when** a developer reads "how to run and build", **then** it gives: the Godot version (4.7.2), how to open and run the project (`godot --path game`), how to run the GUT suite headless (the same command CI uses, see `.github/workflows/ci.yml` line ~91), how to run `game/tools/check_guards.sh` and `game/tools/check_build_size.sh`, and how to export the Web build and smoke-test it (`game/tools/smoke_web.sh`). The existing "Deploying a draft build" section stays and stays accurate.
6. **Given** the itch copy draft, **when** it is read, **then** it lives in the repo at `_bmad-output/implementation-artifacts/itch-page-copy.md` and contains: the full title, the pitch line, a short description (<= 120 words, English), a placeholder marker `[COVER GIF: to capture]` where the cover GIF goes (shift into a Dash Strike crit), the controls summary, the AI-use disclosure (identical wording to the README), the credits with licences, and the line "click once to enable audio if you play on a pad". It states the jam, the theme SHIFT and the 10–15 minute run length.
7. **Given** the in-game ending credits, **when** the Ending credits are shown, **then** the `audio:` credit line in `game/data/ending/ending_text.tres` no longer reads `audio: TBD`; it names what is in the build (SFX and placeholder music generated in-repo, CC0). The `voice:` line credits mumble-speech as Tiziano Basile's own library (`voice: mumble-speech by Tiziano Basile (MIT / Apache-2.0)`). Any test that pins these strings is updated in the same commit; no other ending text changes.
8. **Given** the repo, **when** the change is checked, **then** `check_guards.sh` passes, the GUT suite passes headless, and a grep for `TBD` in `game/data/` and `_bmad-output/implementation-artifacts/itch-page-copy.md` finds only the intentional `[COVER GIF: to capture]` marker (no `TBD` left in the credits).
9. **Given** the placeholder music, **when** the music README is read, **then** it stays accurate: its "Licence line for the real tracks" section is kept (it is the template the itch and README credits will use once BeepBox tracks land) and the README in the music folder is not otherwise changed.
10. **Given** the story is done by the agent, **then** it changes no gameplay value, no `.tres` tuning value, no SFX or music file, and no test outside the credit-string assertion.

### Human pending ACs (NOT done by the dev agent; Tiziano)

- **H-S79-1** Cover GIF: record a short GIF of a shift into a Dash Strike crit (leads the itch page; under ~8 MB, <= 15 s). Save it outside the build, then decide where it lives (`docs/media/` or itch only). Replace the `[COVER GIF: to capture]` marker in the itch copy.
- **H-S79-2** Screenshots: 3 to 5 screenshots from the release web build (`?debug` off) showing the 1-bit glyph look and a shift moment. Include at least one HUD shot with the register visible.
- **H-S79-3** Edit the itch.io page (basteez.itch.io, game id 5332990): paste the approved copy from `itch-page-copy.md`, upload the cover GIF and screenshots, check the controls and credits render. Note: the pad works only if the itch iframe grants the Gamepad API; if H-S75-4 shows it does not, the copy must say the pad works only on the direct `html.itch.zone` URL (add the line before publishing).
- **H-S79-4** Confirm the AI-use wording (README and itch copy) is what Tiziano wants to publish. Confirm the tool naming and the "no generative image or sound model" claim are accurate.
- **H-S79-5** Submit the entry to GitHub Game Off 2026 by 2026-11-29 12:00 PST (>= 49 h before the deadline 2026-12-01 13:37 PST). The repo is already public (verified with `gh repo view`, public since 2026-11-06); only the jam submission remains (`main` stays protected, PR-only).

## Tasks / Subtasks

- [x] Task 1: README (AC: 1, 2, 3, 4, 5)
  - [x] 1.1 Update the status line (remove "in development" only if the game is final: keep "in development" otherwise, but describe the jam entry).
  - [x] 1.2 Rebuild the Controls section from `game/project.godot` input actions (`move_*`, `action_1`, `action_2`, `shift_left`, `shift_right`, `breakpoint`, `watch`, `pause`, `mute`, `title_option_*`) and from the title and pause screen code. Add the title/pause options table.
  - [x] 1.3 Add the AI-use disclosure section and the credits section (replacing the current short Credits block). Keep the MIT License section.
  - [x] 1.4 Add "Run and build" section (AC 5). Keep "Repository layout" and "Deploying a draft build (itch.io)".
- [x] Task 2: itch page copy draft (AC: 6)
  - [x] 2.1 Create `_bmad-output/implementation-artifacts/itch-page-copy.md` (English, document output language). No marketing exaggeration; describe what the game does.
  - [x] 2.2 Put the AI-use disclosure, credits and controls there using the same wording as the README.
- [x] Task 3: in-game credits (AC: 7, 8)
  - [x] 3.1 Edit `game/data/ending/ending_text.tres` `credit_lines`: replace `audio: TBD`, change the `voice:` line to Tiziano's own library.
  - [x] 3.2 Check `game/tests/unit/test_ending_screen.gd` and `game/src/ui/screens/ending/` for any pinned string and update it if needed.
- [x] Task 4: verify (AC: 8, 10)
  - [x] 4.1 Run GUT headless and `game/tools/check_guards.sh`.
  - [x] 4.2 Grep for `TBD` and for `courtesy` in the repo outside `_bmad` and `.godot`.
  - [x] 4.3 Confirm no file under `game/assets/` or any `.tres` tuning value changed (`git diff --stat`).

## Dev Notes

### What already exists (read before writing)

- `README.md` (repo root): has title, pitch, controls table (keyboard and gamepad), tech, deploy section, a short Credits block (mumble-speech "by basteez (MIT/Apache-2.0)" and GUT) and a License section. The Controls table must be checked against the input map: Select (button 4) is New run on the title and mute in the input map; Start (6) is pause; R3 (8) is Fullscreen on the title; L3 (7) is Practice on the title; B (button 1) is Debug build on the title; RT is Breakpoint as the axis 5 (see 7.5 notes). Verify before copying.
- `LICENSE`: MIT, Tiziano Basile, 2026.
- `game/assets/fonts/wildshift8-LICENSE.txt`: Wildshift8 is CC0 1.0, original work, author Tiziano Basile.
- `game/addons/mumble_speech/LICENSE-MIT` and `LICENSE-APACHE`: vendored, copyright Tiziano Basile (2026). Dual MIT / Apache-2.0.
- `game/addons/gut/LICENSE.md`: GUT, MIT (dev only; excluded from export).
- `game/assets/audio/sfx/README.md`: all 15 SFX generated by `game/tools/gen_sfx.py` (stdlib only), CC0 by construction, status final pending H-S72-2.
- `game/assets/audio/music/README.md`: all 8 music files are PLACEHOLDERS generated by `game/tools/generate_placeholder_music.py`, CC0 by construction. Its last section already fixes the licence-line template for real tracks: `Music: <title>, by <author>, made with BeepBox (beepbox.co), <licence>.` Do not change the music README beyond what AC 9 allows.
- `game/data/ending/ending_text.tres` line 17: `credit_lines = PackedStringArray("font: Wildshift8 by Tiziano Basile", "voice: mumble-speech by basteez (MIT / Apache-2.0)", "code: MIT License", "audio: TBD")`. The `voice:` line must change to Tiziano's own library (AC 4 and 7).
- `_bmad-output/game-architecture.md` line ~420 names the README content: "AI disclosure, credits (mumble-speech, font, audio), how to run".
- `_bmad-output/planning-artifacts/briefs/.../brief.md` line 75: "The code is written 100% by AI. AI use is disclosed in the README and on the itch.io page." This is the source fact for the disclosure. Jam addendum: "AI allowed with disclosure".
- `_bmad-output/devlogs/devlog-02.md` line 31 describes mumble-speech as "a small library of mine" (the tone to match).
- `_bmad-output/implementation-artifacts/deferred-work.md` line ~550: "click once to enable audio if you play on a pad" is the approved itch copy line (coordinator decision 2026-11-14). Line ~551: if the itch iframe blocks the pad (H-S75-4), the copy must say the pad works only on the direct `html.itch.zone` URL.

### AI-use disclosure wording [design call D-S79-1]

Default wording (the dev uses it in README and itch copy, identical text; H-S79-4 confirms):

> **AI use.** The code for this game was written with AI coding assistance (Claude, by Anthropic), directed, reviewed and playtested by Tiziano Basile. The game design, the level and balance decisions, the sound-effect recipes and the copy are Tiziano's. No generative image or sound model made any art or audio asset: the glyph font is drawn by a script, the sound effects are synthesised by a script, and the placeholder music is generated by a script. The duck voice is made by mumble-speech, a text-to-speech-style library by Tiziano Basile.

Keep it factual. If a claim cannot be verified from the repo, leave it out and list it in Completion Notes.

### Credits block [design call D-S79-2]

Use one table or list in README and itch copy with identical entries:

- Font: Wildshift8, by Tiziano Basile, CC0 1.0 (own work). `game/assets/fonts/wildshift8-LICENSE.txt`.
- Sound effects: generated in this repository by `game/tools/gen_sfx.py`, by Tiziano Basile, CC0 (no third-party samples).
- Music: placeholder loops generated by `game/tools/generate_placeholder_music.py`, CC0. Real BeepBox tracks to follow (see the music README licence line template). Say "placeholder" explicitly.
- Voice: mumble-speech by Tiziano Basile (basteez), his own library, MIT or Apache-2.0 (dual). Vendored unchanged in `game/addons/mumble_speech/`.
- Code: MIT License (`LICENSE`).
- Tests (dev only): GUT by bitwes (Butch Wesley), MIT. Not shipped in the web export.
- Engine: Godot Engine 4.7.2, MIT.

Do not add any attribution that is not in the repo (no "thanks to" for a non-listed person).

### In-game credit line [design call D-S79-3]

Replace `audio: TBD` with: `audio: SFX and placeholder music, generated in-repo (CC0)`. Keep the line short enough to fit the ending credits screen at phone width (check the existing lines; the longest existing line is the voice line). When the BeepBox tracks land (a future change, not this story) the line changes to the music licence line from the music README.

### Controls section [design call D-S79-4]

Build the table from the input map. Two tables: (a) play, (b) title and pause options. Keep the existing play-table row order. Write the Breakpoint gamepad cell as `RT / R2 (trigger)`. Write the pause row as `Esc / Start`. Do not invent a binding that the code does not have.

### Run and build section [design call D-S79-5]

- Open: `godot --path game` (Godot 4.7.2).
- Test: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (same as CI).
- Guards: `bash game/tools/check_guards.sh`.
- Build: the existing `godot --headless --path game --export-release "Web" ../build/web/index.html` line from the deploy section; note that the Web export template must be installed (CI builds it from source; locally see `game/tools/build_web_template.sh`).
- Size: `bash game/tools/check_build_size.sh build/web` (32 MB limit).
- Smoke: `bash game/tools/smoke_web.sh`.
- Paths on macOS: `godot` is not on PATH for this developer; the README can say "Godot 4.7.2 (on macOS: /Applications/Godot.app/Contents/MacOS/Godot)". Keep the README generic otherwise.

### itch copy file [design call D-S79-6]

Path: `_bmad-output/implementation-artifacts/itch-page-copy.md`. Sections in this order: title and pitch line; cover GIF marker; description (<= 120 words); controls summary (link to the README table, not a full copy); run length and platform (browser, no install); AI use (same as README); credits (same as README); "click once to enable audio if you play on a pad"; jam line (Game Off 2026, theme SHIFT). Mark the file as draft for H-S79-3.

### Things NOT to do

- Do not commit: the coordinator commits.
- Do not touch `_bmad/`, `.claude/`, or the main checkout.
- Do not add a cover GIF or screenshot file, and do not add image links to files that do not exist (a broken README image is worse than none).
- Do not change `main`; the story branch is stacked on `story/7-8-full-run-playtest-and-final-tuning`.
- Do not use `sed -i` on macOS; use the Edit tool for sprint-status and story edits.

### Project Structure Notes

- README and LICENSE stay at the repo root. The itch copy lives beside `playtest-full.md` in `_bmad-output/implementation-artifacts/`.
- The in-game credit line lives in data (`game/data/ending/ending_text.tres`), not in code.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.9] (ACs, FR64, NFR15, NFR17)
- [Source: _bmad-output/planning-artifacts/epics.md line 134, FR64] (cover GIF, line, controls, AI disclosure, asset credits)
- [Source: _bmad-output/planning-artifacts/briefs/brief-github-gameoff-2026-2026-11-06/brief.md line 75] (AI use disclosed in README and itch)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md ~lines 488, 507, 516, 550, 551] (audio TBD until 7.9; pad audio unlock copy line; itch iframe note)
- [Source: game/assets/audio/music/README.md] (licence line template)
- [Source: game/assets/audio/sfx/README.md] (SFX CC0 by construction)
- [Source: game/assets/fonts/wildshift8-LICENSE.txt] (font licence)
- [Source: game/addons/mumble_speech/LICENSE-MIT, LICENSE-APACHE] (voice licence)

### Project Context Rules

- Godot 4.7.2, GDScript, Compatibility renderer, Web export. English documents and copy.
- Edit sprint-status and story files with the Edit tool.
- Commit only by the coordinator.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, pipeline run 2026-11-14.

### Debug Log References

- Fresh worktree: GUT failed to load (`DuckLinesDef` not found) until `godot --headless --path game --import` ran once; not a code issue.
- RED: `test_ending_text_data` failed on the new credit assertions (old `basteez` voice line, `audio: TBD`). GREEN after the `.tres` edit.
- The AC 7 voice line `voice: mumble-speech by Tiziano Basile (MIT / Apache-2.0)` is 57 chars; `EndingText.MAX_CREDIT_CHARS` is 56 and the centred line must start at x >= 96. It failed `validate()` and the layout assert, see the design call below.
- Full GUT suite: 121 scripts, 1771/1771 tests passing, 145778 asserts, exit 0. `game/tools/check_guards.sh`: OK.
- AC 8 greps: no `TBD` in `game/data/` or `itch-page-copy.md`; no `courtesy` outside historical story files (3-7 story file and this story's Dev Notes quote the old `by basteez` wording; left as history).

### Completion Notes List

- README: status line (jam entry in final polish, placeholder music noted), Controls rebuilt from `game/project.godot` `[input]` and the title / pause / practice code (Play table + Title and pause options table, click-to-enable-audio note), new "Run and build" section (open, run, GUT command identical to CI, guards, Web export, `check_build_size.sh`, `smoke_web.sh`, template note, asset generators), "AI use" section, Credits table with licences. "Repository layout", "Deploying a draft build (itch.io)", "Contributing" and "License" kept unchanged. Tech section: dropped "(created in the first implementation story)", now stale.
- itch copy draft: `_bmad-output/implementation-artifacts/itch-page-copy.md`, sections in D-S79-6 order, description 97 words, `[COVER GIF: to capture]` marker, controls summary linking the README tables, the line "click once to enable audio if you play on a pad", 10 to 15 minute run, browser, jam + theme SHIFT, iframe pad line kept as a pre-publish note (H-S75-4). AI use and Credits sections are byte-identical to the README (checked by script).
- In-game credits: `audio: SFX, placeholder music, made in-repo (CC0)` and `voice: mumble-speech by Tiziano Basile (MIT/Apache-2.0)`; font and code lines unchanged; still 4 lines. `test_ending_text_data` pins both new strings and asserts no `TBD`.
- Music README: only the last line (which said the in-game credit "stays `audio: TBD`") was updated so it stays accurate (AC 9); the licence-line template is kept.
- No gameplay value, tuning `.tres` value, SFX or music file changed (AC 10): `git diff --stat` shows only README.md, music README.md, ending_text.tres (credit_lines), test_ending_screen.gd, sprint-status.yaml, plus the two new docs.
- [design call] D-S79-1 changed: the AI-use wording keeps only facts verifiable from the repo, per coordinator. Dropped "the game design, level and balance decisions, the sound-effect recipes and the copy are Tiziano's" (the SFX recipes, font bitmaps and copy were written in AI-assisted sessions, so the repo cannot show that split) and "playtested" (the 7.8 playtest is pending). Says: code and docs written with Claude under Tiziano's direction; no generative image/music/voice model; font = bitmap data in `gen_glyph_font.py`; SFX and placeholder loops synthesised by in-repo scripts; duck voice from mumble-speech at runtime (the pre-rendered duck clips in `assets/audio/duck/` are rendered from mumble-speech by `tools/render_duck_lines.gd`); final music being made by Tiziano in BeepBox. To confirm in H-S79-4.
- [design call] Music credit per coordinator: "Music by Tiziano Basile (BeepBox). Placeholder loops until the final tracks land", plus that the current build ships the script-generated loops (CC0). The licence of the final BeepBox tracks is not stated anywhere (no `TBD` literal written): Tiziano must choose it and fill the music README template line.
- [design call] D-S79-3 changed: the prescribed `audio: SFX and placeholder music, generated in-repo (CC0)` is 57 chars (> 56); used `audio: SFX, placeholder music, made in-repo (CC0)` (49).
- [design call] AC 7 voice line changed: `(MIT / Apache-2.0)` -> `(MIT/Apache-2.0)` so the line is 55 chars and fits the 56-column / x >= 96 credits layout.
- [design call] D-S79-4 changed: the pause row reads `Esc / P` (keyboard), not `Esc` only, because the `pause` action also binds P (D-FIX-FS-1); the Debug build and Fullscreen rows show "Title, pause"; Mute is pause-only (M / Select). Practice controls (L / Select loadout, Esc / L3 back) added as a note, taken from `game.gd`.
- [design call] The Code credit links LICENSE by its full GitHub URL in both files so the identical credits block also works on itch.io (the repo is already public).
- [design call] Credits list GUT as version 9.6.1 by Tom "Butch" Wesley (from `addons/gut/plugin.cfg` and `LICENSE.md`), excluded from export by `export_presets.cfg`.

### File List

- README.md (modified)
- _bmad-output/implementation-artifacts/itch-page-copy.md (new)
- _bmad-output/implementation-artifacts/7-9-itch-io-page-readme-and-submission.md (modified: status, tasks, Dev Agent Record)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 7-9 -> review)
- game/data/ending/ending_text.tres (modified: credit_lines)
- game/tests/unit/test_ending_screen.gd (modified: credit-string assertions)
- game/assets/audio/music/README.md (modified: last line only)
- _bmad-output/implementation-artifacts/deferred-work.md (modified: Story 7.9 human checks and music licence note)

### Change Log

- 2026-11-14: Story 7.9 dev: README (controls, run and build, AI use, credits), itch page copy draft, in-game credit lines, music README credit note. Status -> review; human ACs H-S79-1..5 pending.

## Human Pending Checklist (Tiziano)

- [ ] H-S79-1 Cover GIF of a shift into a Dash Strike crit (<= 15 s, <= 8 MB), replace the `[COVER GIF: to capture]` marker.
- [ ] H-S79-2 3 to 5 screenshots from the release web build (`?debug` off): 1-bit glyph look, a shift moment, HUD with the register visible.
- [ ] H-S79-3 Edit the itch page (game id 5332990): paste approved copy from `itch-page-copy.md`, upload GIF and screenshots, check controls and credits render; apply the iframe pad line if H-S75-4 shows the pad is blocked.
- [ ] H-S79-4 Confirm the AI-use wording and the "no generative image or sound model" claim.
- [ ] H-S79-5 Submit to GitHub Game Off 2026 by 2026-11-29 12:00 PST.
- [design call, revised] Design call 6: the repo is ALREADY public (verified 2026-11-14), so no visibility step; H-S79-5 is the jam submission only.
- Code review (gds-code-review, 2026-11-14): fixed voice wording (live or pre-rendered clips) and title-resume note; rest deferred or dismissed (see deferred-work.md). GUT 1771/1771, check_guards OK.
