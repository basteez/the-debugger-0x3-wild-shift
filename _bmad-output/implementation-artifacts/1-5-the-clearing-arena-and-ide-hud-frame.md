---
baseline_commit: 3646204
---

# Story 1.5: The Clearing Arena and IDE HUD Frame

Status: review

## Story

As a player,
I want to see the fantasy clearing drawn in glyphs inside a debugger's IDE frame,
so that the code-as-fantasy look is clear from the first screen.

**Requirements:** FR56, FR57 (shell), NFR8; D-047 (font and HUD grid); D-048 (title, carried over from 1.4 DC1); NFR15 (font licence).

## Acceptance Criteria

**AC1: Arena glyph layout (epics)**
Given the FIGHT placeholder screen (the arena is instanced by `Main`; see DC9 for how it is shown before 1.6),
When the arena is drawn,
Then a 32×18-tile play area at 16 px per tile shows trees `♣` as the boundary tree line, grass `"`, rocks `o` and a stream of `~`, labelled `stack frame 0x03`,
And all of it is drawn with `draw_char`/`draw_string` in `_draw()` using one 8×8 CP437-style monospace pixel font at 2× (CC0 or OFL, licence file in `game/assets/fonts/`; D-047),
And only the two palette colours `Palette.INK` and `Palette.BG` are used.

**AC2: HUD frame (epics)**
Given the HUD (`CanvasLayer`),
When it is shown,
Then HUD text is drawn at 1× on an 8-px grid (80×45 cells),
And the regions match the GDD HUD Layout wireframe exactly: arena at cells (16,2)–(79,37); top bar row 0 (boss signature + HP bar) and row 1 (sky comment); register panel cols 0–11 rows 2–21; duck bubble cols 0–11 rows 22–37; line numbers `01`–`18` in cols 13–15, one per tile row; log panel rows 38–44 (a header plus 6 lines),
And a debug grid overlay (F9) shows the cell grid so later stories can check placement,
And the render layers are ordered Arena → Entities → Particles → HUD → ScreenFX (AD-07).

**AC3: Clamp function (epics)**
Given the arena,
When a position outside the play area is passed to the arena's clamp function,
Then it returns the nearest position inside the 32×18 rectangle (scenery has no collision).

**AC4: Title uses the pixel font (carried from 1.4 DC1 / D-047)** `[design call]` DC2
Given the title screen,
When it is shown,
Then the title `The Debugger 0x03: Wild Shift` and the prompt `press any key` are drawn with the same pixel font at 2× (no fallback font remains in `title_screen.gd`),
And the 1.4 behaviour (AC1–AC4 of Story 1.4: silence before input, first-input start, option hotkeys, bus gate) is unchanged.

**AC5: Font coverage and licence** `[design call]` DC1
Given the vendored font,
When a GUT test checks every glyph used by the arena, HUD frame and title (see Task 1.4 for the exact set),
Then the font contains each one (`Font.has_char`), and `game/assets/fonts/` holds the font file plus its licence text file naming the font, version, upstream URL and licence (CC0 or OFL only).

## Scope Boundaries

- **In scope:** the pixel font asset and licence file; the arena (layout, `_draw`, clamp, `stack frame 0x03` label); the HUD `CanvasLayer` frame (regions, top bar and sky-comment placeholders, line numbers, log header and empty lines, panel borders); the F9 grid overlay; the render layer tree in `Main`; the title switch to the pixel font; GUT tests; the `?debug&smoke=arena` browser check hook.
- **Out of scope:** register panel contents, shift previews and cooldowns (2.3); the duck bubble text and typewriter (3.6); log lines and CRIT formatting (2.8); boss header HP bar values (3.1+); particles and ScreenFX shader (2.4, 1.7 and later; the nodes exist empty); the F1–F5 jump keys, the `Debug` autoload and the `?debug` helper (1.6); FIGHT and INTRO screens (1.6); pause (1.7); any template change (see DC12); credits in README (7.9 owns the full credits list; see DC1).
- **Not touched:** `_bmad`, `.claude` (symlinks, gitignored); the 1.3 audio smoke scene; the 1.4 bus layout and `AudioManager` unlock logic; CI workflow and `check_guards.sh` rules; `Game` flow states.

## Tasks / Subtasks

- [x] Task 1: Pixel font asset and licence (AC: 5, 4)
  - [x] 1.1 Choose one 8×8 CP437-style monospace pixel font whose own licence file is CC0 or OFL. Verify the licence from the upstream licence text, not from memory. Reject CC-BY-SA, GPL, NC/ND and any font with unclear terms (NFR15). Record the choice in Completion Notes (name, version, upstream URL, SHA-256 of the file). `[design call]` DC1
  - [x] 1.2 Add the font under `game/assets/fonts/` (e.g. `<fontname>.ttf` or a BMFont `.fnt` + PNG atlas; either is fine, see DC11) and its licence text as `game/assets/fonts/<fontname>-LICENSE.txt`. Do not commit the font's documentation tree, only the font file and the licence.
  - [x] 1.3 Import settings: nearest filtering (`default_texture_filter=0` is already in `project.godot`), hinting none, antialiasing none, so glyphs stay crisp at 2×.
  - [x] 1.4 Coverage: the GUT test `game/tests/unit/test_font_coverage.gd` loads the font and asserts `has_char` for every codepoint used by the arena and HUD frame (`♣ " o ~ ┌ ┐ └ ┘ ├ ┤ ─ │ ■ □ ░ █`, digits, the letters and punctuation in the HUD placeholder strings, `stack frame 0x03`) and by the title (`The Debugger 0x03: Wild Shift`, `press any key`). Derive the set from the code's constants (`Arena.LAYOUT`, `Hud` text constants, title text) rather than a hand-written list, so the test cannot drift.
  - [x] 1.5 `project.godot` and `tests/unit/test_folder_tree.gd` need no change (`res://assets/fonts` already exists).

- [x] Task 2: Font drawing helper (AC: 1, 4)
  - [x] 2.1 Create `game/src/presentation/glyph_font.gd` (`class_name GlyphFont`, `extends RefCounted`), static only: loads nothing at runtime (AD-13: preload the font with `const FONT := preload("res://assets/fonts/<fontname>...")`), exposes `GlyphFont.CELL := 8`, `GlyphFont.font() -> Font`, and `draw_cell(canvas: CanvasItem, cell: Vector2i, text: String, color: Color, scale: int)` that draws at pixel position `cell * 8 * scale` (2× for the arena, 1× for the HUD) with `draw_string`/`draw_char` using the font size that gives an 8-px cell at 1× (verify the exact size mechanism in the chosen font; record it in Completion Notes).
  - [x] 2.2 Only `Palette.INK` and `Palette.BG` may be passed as colours. The helper does not accept any other colour; the GUT test checks the constants (Task 6.2).

- [x] Task 3: Arena (AC: 1, 3)
  - [x] 3.1 Create `game/src/arena/arena.gd` (`class_name Arena`, `extends Node2D`) with `const TILES := Vector2i(32, 18)`, `const TILE_PX := Const.TILE_PX`, `const ORIGIN_CELL := Vector2i(16, 2)` (arena cells (16,2)–(79,37) at 8 px each: 64×36 cells = 512×288 px at 1×, drawn at 2× tiles).
  - [x] 3.2 Layout as a `const` `PackedStringArray` of 18 rows × 32 characters (`LAYOUT`), so it is data in one place. Rules: the outer ring is `♣` (boundary tree line); the interior is `"` grass; a meandering `~` stream crosses the clearing from left to right (at least one `~` in every interior column from 1 to 30 in rows 7–10 or so, keep it connected); scattered `o` rocks, at least 6, not on the stream; the label `stack frame 0x03` is written on the top row (row 0), starting at column 2, overwriting trees, with `♣` still on both sides (DC5). Add a GUT test that asserts the row/column counts, the ring, the label and that the glyph set is within `{♣, ", o, ~, space, label chars}`.
  - [x] 3.3 `_draw()` draws each non-space cell with `GlyphFont.draw_cell(self, Vector2i(col, row), ch, Palette.INK, 2)` (16-px tile pitch), in the cell's position at `Vector2(col, row) * 16` in arena-local space. `Palette.BG` is the clear colour behind the arena (the title's BG clear). `queue_redraw()` is called once in `_ready()`; no `_process` redraws.
  - [x] 3.4 `static func clamp_to_play_area(p: Vector2) -> Vector2`: clamps to `Rect2(Vector2.ZERO, Vector2(TILES) * TILE_PX)` (pixels in arena-local space, `max` edge inclusive), so `(-5, 300)` → `(0, 288)`. Pure static, no node, no scene tree. `[design call]` DC4
  - [x] 3.5 No collision shapes, no `Area2D`/`PhysicsBody2D` (project-context rule). Arena may not reference `ui`, `presentation`, `AudioManager` or `VoiceService` (architecture simulation-folder rule). `GlyphFont` lives in `presentation/` and is used by the arena `_draw()`; this is the only presentation reference, and it is drawing-only. If the guard review objects, move `GlyphFont` to `src/core/glyph_font.gd` instead (it depends only on the font and `Palette`). `[design call]` DC4a (preferred: `src/core/` so no sim folder references presentation)

- [x] Task 4: HUD frame (AC: 2, 1)
  - [x] 4.1 Create `game/src/ui/hud/hud.gd` (`class_name Hud`, `extends CanvasLayer`, `layer = 10`) and `game/src/ui/hud/hud.tscn` (root Hud with a child `Frame` Node2D whose `_draw` does all HUD text). Layout from AC2 in cell coordinates, 1×, 8 px per cell: row 0 top bar (placeholder `void fightPlaceholder() // hp ---` starting col 0, no HP bar yet), row 1 sky comment placeholder `// TODO: this should terminate`, register panel frame cols 0–11 rows 2–21 (box-drawing border, title `reg` on row 2), duck bubble frame cols 0–11 rows 22–37 (box-drawing border), line numbers `01`–`18` in cols 13–14 (col 15 is a `│` separator on rows 2–37), one per arena tile row (DC6), log panel rows 38–44 (row 38 header `── console ───…` across cols 0–79, rows 39–44 empty for now). No box border around the arena: the tree ring is its boundary.
  - [x] 4.2 The HUD text constants (`TOP_BAR`, `SKY`, `REG_TITLE`, `LOG_HEADER`, `LINE_NO`) live in `hud.gd` as `const` values so the GUT test checks them against the layout. No HP bar, no register bits and no log lines yet (2.3, 2.8, 3.1 own those).
  - [x] 4.3 Region helper: `static func region_of(cell: Vector2i) -> StringName` returning `&"top_bar"`, `&"sky"`, `&"register"`, `&"duck"`, `&"arena"`, `&"line_numbers"`, `&"log"`, `&"gap"` for each cell per AC2 (col 12 is the `gap` column, `gap` also covers any cell not listed). Used by the test and by later stories to place elements on the grid.
  - [x] 4.4 Debug grid overlay: a `GridOverlay` Node2D child of the HUD (drawn last in the HUD) that draws 1-px lines at every 8-px cell boundary (80×45) and a brighter line every 16 px in `Palette.INK` at 50% alpha only when visible. Toggled by `F9` (`InputMap` action `debug_grid`, physical key `KEY_F9`, added to `project.godot [input]`). The toggle works only when `OS.is_debug_build()` or the URL contains `debug` (project-context debug rule, same check as the 1.6 `Debug` helper). Default hidden. `[design call]` DC7 (architecture lists F9 as a frame overlay; 1.5 uses F9 for the grid as the epic says; 1.6 or 10.x may move the frame overlay to another key).
  - [x] 4.5 Frame and text drawing use `GlyphFont.draw_cell(self, cell, text, Palette.INK, 1)`; no `Label`/`RichTextLabel` (project-context rule: no Label per glyph).

- [x] Task 5: Main integration and render layers (AC: 2, 1)
  - [x] 5.1 `game/src/main/main.gd`: keep the 1.3 smoke gate and the 1.4 title. Add the render layers as children of `Main` in this order (AD-07): `Arena` (Node2D, from `arena.tscn` or built in code, default z), `Entities` (empty Node2D), `Particles` (empty Node2D), `Hud` (CanvasLayer `layer = 10`), `ScreenFX` (empty CanvasLayer `layer = 20`, shader added in a later story). Create them in `_ready()`, all hidden except the arena and HUD when the arena is shown.
  - [x] 5.2 Visibility (DC9): the arena and HUD are added but `visible = false` at boot. They become visible when the arena view is requested: (a) the `?debug&smoke=arena` URL on web (same parsing helper as `wants_audio_smoke`, a second static helper `wants_arena_smoke(search: String) -> bool`), or (b) a `Game.flow_state == FIGHT` placeholder once 1.6 exists. Story 1.5 implements (a) only; (b) is wired by 1.6.
  - [x] 5.3 Test: `tests/unit/test_main_layers.gd` instances `main.tscn`, checks the child order and the `CanvasLayer.layer` values (`Hud` 10 < `ScreenFX` 20), and that the `Arena` and `Hud` nodes exist and are hidden at boot.

- [x] Task 6: Title pixel font (AC: 4)
  - [x] 6.1 `game/src/ui/screens/title/title_screen.gd`: replace `ThemeDB.fallback_font` with `GlyphFont` (`draw_cell`-style for 2× centred text, or `draw_string` with the same font at 2× size). Title centred on the 640 px base; the title is 29 characters = 29 × 16 px = 464 px, fits. Prompt: 16 characters at 2× centred below. Keep `TITLE_BASELINE_Y`/`PROMPT_BASELINE_Y` on an 8-px grid (multiples of 8). Keep `Palette.INK` on the `BG` clear colour.
  - [x] 6.2 The GUT test in `tests/unit/test_title_input.gd` (or a new `test_title_font.gd`) asserts that `title_screen.gd` no longer references `ThemeDB.fallback_font` (source-text check acceptable) and the text constants are unchanged.

- [x] Task 7: GUT tests (AC: 1, 2, 3, 5)
  - [x] 7.1 `tests/unit/test_arena_layout.gd`: rows = 18, cols = 32 for every row; ring is `♣`; label at row 0 col 2–17; grass present; rocks ≥ 6 and none on `~`; set of glyphs ⊆ allowed set; `clamp_to_play_area` cases: inside unchanged, left/top/right/bottom/corner outside clamped (and `(512, 288)` stays), negative values clamp to 0.
  - [x] 7.2 `tests/unit/test_hud_layout.gd`: `region_of` returns the AC2 regions at the corner and edge cells listed in AC2 (e.g. (0,0) top_bar, (0,1) sky, (0,2) register, (11,21) register, (0,22) duck, (11,37) duck, (13,2) line_numbers, (16,2) arena, (79,37) arena, (16,38) log, (79,44) log, (12,5) gap); the line number strings are `01`…`18`; `TOP_BAR` and `SKY` strings fit in 80 columns.
  - [x] 7.3 `tests/unit/test_glyph_palette.gd`: every colour passed through `GlyphFont` and used by `Arena`/`Hud`/`TitleScreen` is `Palette.INK` or `Palette.BG` (check the constants; no other `Color(` literal in these three files, by source grep).
  - [x] 7.4 `tests/unit/test_grid_overlay.gd`: the F9 action exists in `InputMap` and is bound to `KEY_F9`; the overlay is hidden by default; the gating function returns false in a release build without `debug` in the URL (test the pure helper, not `OS`).
  - [x] 7.5 Keep the existing tests green (GUT 73/73 at the start of this story; the 1.4 AC4 bus test and title input tests must keep passing).

- [x] Task 8: Verification (AC: all, release size)
  - [x] 8.1 `godot --headless --path game --import` then the GUT command from project-context; record the pass count.
  - [x] 8.2 `bash game/tools/check_guards.sh` passes (no `await`, `Timer`, `create_timer`, `print` in sim folders; `Arena` uses none of them).
  - [x] 8.3 Release web export: `build/web/` size in bytes recorded in Completion Notes against the 30 000 000 budget and the 1.4 baseline 28,406,474. Expect a few kilobytes more, not megabytes. `bash game/tools/smoke_web.sh` passes.
  - [x] 8.4 Local windowed check (dev may run `godot --path game` or the `run` skill): the arena and HUD render at the expected positions with `?debug&smoke=arena` in the web build, and F9 toggles the grid. Save the screenshot path in Completion Notes. Full browser visual sign-off is a HUMAN step (H1).
  - [x] 8.5 No change to the web template, `export_presets.cfg`, `.github/workflows/ci.yml` or the README.

## Dev Notes

### Architecture guardrails (must follow)

- **Simulation folders** (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not reference `ui`, `presentation`, `AudioManager` or `VoiceService`. Arena `_draw()` is presentation-only but lives in `src/arena/` per architecture (`arena.gd` listed with "Clearing glyph layout, bounds clamp, sky comment"). See DC4a for the glyph helper location.
- **Rendering (AD-07):** glyphs via `draw_char`/`draw_string` in `_draw()`; no `Label` per glyph; no sprites for glyphs. Layers `Arena → Entities → Particles → HUD → ScreenFX`. `Palette` constants only (`INK #E8E8E8`, `BG #101014`, `WARN #FF4040` reserved; this story uses INK and BG only).
- **Font scale (D-047 / architecture Rendering):** one 8×8 CP437-style font; world glyphs at 2× on 16-px tiles; HUD text at 1× on an 8-px grid (80×45 cells); integer scales only.
- **Flow (AD-08):** `Main` is the persistent root with arena + HUD; screens are instanced and freed; `Game` owns flow state. Story 1.5 does not change flow states.
- **Assets (AD-13):** preload, no runtime `load()`.
- **Debug (project-context):** debug tools only when `OS.is_debug_build()` or the URL has `?debug`. The F9 grid obeys this.
- **Logging:** `Log` autoload only; no bare `print`.
- **Testing:** GUT headless; pure logic tested without a renderer (`Arena.clamp_to_play_area`, `Hud.region_of`, layout constants).
- **Naming:** `snake_case` files, `class_name` PascalCase, `const` UPPER_SNAKE, `StringName` ids (`&"arena"`).

### Previous story intelligence (1.1–1.4)

- **1.4 (title, done):** `Main` (`game/src/main/main.gd`) opens the title unless `wants_audio_smoke(_web_location_search())` is true. The same pattern (a static URL-query helper, a second gate) is the template for `wants_arena_smoke` (DC9). `TitleScreen` is a `Node2D` drawing text in `_draw()` with `ThemeDB.fallback_font`; the 1.4 Dev Notes state the pixel font and its licence arrive in 1.5 (DC1 of 1.4). The title is removed from the tree on start (`queue_free`).
- **1.4 deferred items relevant here:** none block 1.5. The Story 1.4 note "Single SFX player restarts on rapid play" and "label_rects canvas vs viewport" stay deferred.
- **1.3 deferred:** "Stripped template disables svg, noise, mbedtls, websocket, zip, text_server_adv; re-enable when a story needs them" (see DC12: no module needed here).
- **1.4 size baseline:** web build 28,406,474 bytes (budget 30,000,000). The 1.4 Dev Agent Record notes the stripped template and CI size step already exist.
- **1.2:** GUT 9.6.1 vendored; folder-tree test already requires `res://assets/fonts`; `check_guards.sh` exists.
- **Git:** recent commits are `feat(...)` for code, `docs(story)` for story files and `fix(ui)` for review fixes. Use the same style: `feat(arena): ...`, `feat(ui): ...`, `docs(story): ...`.

### Project structure notes

- New files (per architecture tree): `game/assets/fonts/<font>` + `<font>-LICENSE.txt`; `game/src/arena/arena.gd`; `game/src/ui/hud/hud.gd`, `hud.tscn`; `game/src/presentation/glyph_font.gd` (or `src/core/glyph_font.gd`, DC4a); `game/src/main/main.gd` (modified); `game/src/ui/screens/title/title_screen.gd` (modified); `game/project.godot` (`[input]` gains `debug_grid`); tests as in Task 7.
- Architecture file names are `arena.gd` and `ui/hud/hud.tscn`; the architecture also lists `register_panel.gd`, `log_panel.gd`, `line_numbers.gd` etc. Those are later stories' files; 1.5 may draw line numbers and frame text in `hud.gd` and leave the panel scripts for 2.3 and 2.8.
- Conflict noted: architecture lists F9 as a frame overlay; the epic says the F9 grid overlay. This story follows the epic (DC7).

### Project context rules (from `_bmad-output/project-context.md`)

- Glyphs with `draw_char`/`draw_string` in `_draw()`, call `queue_redraw()`; no `Label` per glyph, no sprites.
- One 8×8 font; world 2×, HUD 1× on an 8-px grid; never place HUD elements off the grid.
- Simulation folders must not reference `ui`, `presentation`, `AudioManager`, `VoiceService`.
- Debug tools only with `OS.is_debug_build()` or `?debug`; export excludes `addons/gut`, `tests/`, `tools/`.
- No `Area2D`/`PhysicsBody2D`/`CharacterBody2D`; arena walls = position clamp.
- `await` and Tweens only in presentation/UI, never in simulation.

### Design calls (recorded during unattended create; implementer must follow or record a change)

- **[design call] DC1 Font choice and licence.** Use one 8×8 CP437-style monospace font whose own licence is CC0 or OFL, verified from its licence text. Reject CC-BY-SA, GPL, NC/ND and unclear licences (NFR15). Record name, version, URL and SHA-256 in Completion Notes. Credits: the font credit goes into the licence text file now; the README credit list is completed in 7.9 (the epics already list font credits there). If no licence-clean 8×8 CP437 font can be obtained in the dev session, the story is blocked; record the blocker and keep the fallback font for the title (do not ship an unlicensed font).
- **[design call] DC2 Title on pixel font.** The title and prompt switch to the pixel font at 2× (16-px cells), closing the 1.4 DC1 deferral. Title width 29 × 16 = 464 px fits the 640 base. `ThemeDB.fallback_font` is removed from `title_screen.gd`.
- **[design call] DC3 Scale mechanism.** Integer 2× is achieved by the font size that renders an 8-px cell at 1× scaled by 2 (or the equivalent in the chosen font format). Nearest filtering, no hinting, no antialiasing. Verified by a windowed screenshot (8.4), not assumed.
- **[design call] DC4 Clamp in pixels.** `Arena.clamp_to_play_area` works in arena-local pixels (1 tile = 16 px, bounds 512×288), matching `Const.TILE_PX`. Max edge inclusive.
- **[design call] DC4a Glyph helper location.** `GlyphFont` lives in `src/presentation/` by default. If the guard or reviewer objects to `arena/` referencing `presentation/`, move it to `src/core/glyph_font.gd` (it depends only on the font and `Palette`). Pick one and record it; do not add cross-folder dependencies from sim code beyond the helper.
- **[design call] DC5 Layout and label.** The arena is a fixed 32×18 `LAYOUT` constant: ring of `♣`, grass `"`, a connected `~` stream, at least 6 `o` rocks, and the label `stack frame 0x03` on row 0 from column 2 (overwriting trees, `♣` kept on both sides). The exact positions are the implementer's choice inside these rules.
- **[design call] DC6 Line numbers.** The arena occupies HUD rows 2–37 (36 cells) and 18 tile rows, so each tile row is 2 HUD cells tall (16 px = 2 × 8 px). Line number `NN` for tile row r (1-based) is drawn at cols 13–14 on HUD row `2 + 2·(r−1)`, the upper cell of its band; the lower cell of each band is blank in cols 13–14. Col 15 holds the `│` separator on rows 2–37.
- **[design call] DC7 F9 grid overlay.** F9 toggles a cell grid overlay (8-px cells) gated by `OS.is_debug_build()` or `?debug`; default hidden. Architecture's F9 "frame overlay" is a later decision (1.6 owns the debug table; the F-key assignment can move if needed).
- **[design call] DC8 Empty layers.** `Entities`, `Particles` and `ScreenFX` exist as empty nodes in 1.5 so the layer order is testable. ScreenFX shader and particle drawing are later stories (2.4/2.8 and 1.7 or later).
- **[design call] DC9 Visibility of the arena before 1.6.** The arena and HUD are added hidden at boot and shown only with `?debug&smoke=arena` on web (a 1.3-style smoke gate). The FIGHT placeholder that shows them normally is a 1.6 deliverable. GUT tests instance the arena and HUD directly.
- **[design call] DC10 HUD placeholder text.** Only static placeholder text exists in 1.5 (top bar `void fightPlaceholder() // hp ---`, sky `// TODO: this should terminate`, `reg`, `console` header). No HP values, no register bits, no log lines: those are 2.3, 2.8 and 3.1.
- **[design call] DC11 Font format.** Either a TTF (the template keeps `freetype`, which is not in the stripped list) or a BMFont `.fnt` + PNG atlas (core formats). Choose the one that stays crisp at 2× with `draw_string`/`draw_char`; record the choice. Prefer the one that needs no template change.
- **[design call] DC12 Template and size.** No template change. `build_web_template.sh` disables modules that a TTF or BMFont path does not need (freetype and core image formats stay on). If the export fails to load the font in the web build, re-enable the minimal module in the template script and record the byte cost (the 30 MB budget is the gate). Expect the export to stay about 28.4 MB.

### References

- Epics: `_bmad-output/planning-artifacts/epics.md` → Epic 1, Story 1.5 (lines 435–458); FR57 (line 118); NFR8 (line 145); NFR15 (line 152); AD-07, AD-08, AD-13 (lines 178–194).
- GDD HUD Layout (D-047): `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md` → Art Style → HUD Layout (lines 526–560).
- Decision log D-047 and D-048: `_bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md`.
- Architecture: `_bmad-output/game-architecture.md` → Rendering (AD-07), Scene structure (AD-08), Project structure (lines 412–505).
- Project context: `_bmad-output/project-context.md` (lines 33–79).
- Story 1.4 (title, DCs): `_bmad-output/implementation-artifacts/1-4-title-screen-with-press-to-start-and-audio-unlock.md`.
- Template build: `game/tools/build_web_template.sh`; guards: `game/tools/check_guards.sh`.
- Readiness report (glyph font and D-047 risk): `_bmad-output/planning-artifacts/implementation-readiness-report-2026-11-06.md` (lines 130, 287, 422).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, unattended

### Debug Log References

- Font candidate check: Press Start 2P 3.000 (google/fonts `ofl/pressstart2p`, OFL 1.1 read from its `OFL.txt`) covers ASCII and U+2663 but lacks U+2500–U+2524, U+25A0/U+25A1, U+2591, U+2588 (checked with fontTools `getBestCmap`). Rejected; coordinator fallback taken (original font).
- `gen_glyph_font.py` is deterministic: two runs give identical SHA-256 for `.fnt` and `.png`.
- Font probe (Godot 4.7.2): `fixed_size=8`, `fixed_size_scale_mode=1` (integer only), height 8 at size 8 and 16 at size 16, ascent 7 at size 8, `antialiasing=0`, `hinting=0`.
- GUT (CI-equivalent script: import, GUT log markers, `All tests passed!`, guards): 111/111 tests, 2135 asserts; `check_guards: OK`.
- Desktop windowed screenshots (Godot 4.7.2, 640×360 viewport): pixel census of title and arena shots finds exactly two colours, (16,16,20) BG and (232,232,232) INK: no antialiasing at 1× or 2×.
- Web: release export with the stripped template (`build_web_template.sh` work folder, `godot.web.template_release.wasm32.nothreads.dlink.zip`, set via a temporary `custom_template/release`, preset reverted). `smoke_web.sh` PASS for no query, `?debug&smoke=arena` (expects `arena smoke view opened`) and `?debug&smoke=audio` (click).

### Completion Notes List

- Story created unattended by gds-create-story on 2026-11-07. Design calls DC1–DC12 recorded above; the implementer records any deviation.
- HUMAN steps (Tiziano), still open: [ ] H1 real-browser visual check of `?debug&smoke=arena` (Chrome and Firefox): arena layout, HUD grid alignment, F9 overlay (in a release build the URL must contain `debug`). [ ] H2 confirm the font's licence text (`game/assets/fonts/wildshift8-LICENSE.txt`: original font, CC0 1.0 by Tiziano Basile) and that you agree to dedicate the glyph bitmaps to CC0.
- **Font (DC1, coordinator fallback path):** no licence-clean 8×8 CP437 font with the box-drawing set was found quickly (Press Start 2P, OFL, lacks box drawing and blocks; the Ultimate Oldschool PC fonts are CC BY-SA, rejected). `[design call]` An original font, **Wildshift8 1.0**, was authored for the project as a BMFont generated by the committed script `game/tools/gen_glyph_font.py` (standard-library Python, deterministic). 109 glyphs: printable ASCII 0x20–0x7E, `♣ → ─ │ ┌ ┐ └ ┘ ├ ┤ ■ □ ░ █`. Licence: CC0 1.0 (dedication by the author, full CC0 legal code verbatim from https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt) in `game/assets/fonts/wildshift8-LICENSE.txt`; upstream URL https://github.com/basteez/the-debugger-0x3-wild-shift. SHA-256: `wildshift8.fnt` 85996f422b8ddbae5d2a9a727085b343f57e1807ec10b4b827ce1b319d505ca4, `wildshift8_0.png` ef311ff4e3310a033c0c4fc1223d401658df0cc0e626077283359cc115b6d374. `→` added because the GDD HUD uses `J→K` (2.3); no other extra glyphs.
- **Format (DC11):** BMFont text `.fnt` + 128×56 RGBA PNG atlas, core importer `font_data_bmfont`, no freetype needed, no template change (DC12). Import option `scaling_mode=1` (integer only) so font size 16 renders exact 2× glyphs.
- **Size mechanism (DC3):** `GlyphFont.size_for(scale) = 8 * scale`; the bitmap font has `fixed_size=8` and integer scaling. Text is drawn with `draw_string` at baseline `top + FONT.get_ascent(size)` (ascent 7 at 1×, 14 at 2×). Verified by screenshots, not assumed.
- **DC4a:** `[design call]` `GlyphFont` lives in `src/core/glyph_font.gd` (the preferred option): `arena/` references only `core/` (`GlyphFont`, `Palette`, `Const`), never `ui`/`presentation`.
- **DC2 title:** `[design call]` the 1.4 `TITLE_BASELINE_Y/PROMPT_BASELINE_Y/*_FONT_SIZE` constants became `TEXT_SCALE := 2`, `TITLE_TOP_Y := 160`, `PROMPT_TOP_Y := 208` (top of the 16-px glyph row, so the row sits on the 8-px grid; a baseline value would be 8k+14). x is centred and snapped to the grid: title x = 88 (464 px wide), prompt x = 216 (13 glyphs, 208 px; the story text said 16 characters, the string has 13).
- **DC5 layout:** stream meanders rows 7–10 with a doubled `~` at each step so it stays 4-connected; 9 rocks; grass on a sparse diagonal pattern (spaces between) so the clearing reads as open ground. Label `stack frame 0x03` at row 0, cols 2–17.
- **HUD (DC6, DC10):** register box `┌─reg──────┐` on row 2 (title inside the top border), duck box rows 22–37, line numbers at cols 13–14 on rows 2,4,…,36, `│` separator at col 15 rows 2–37, `── console ───…` header (80 cols) on row 38. No border around the arena (tree ring). `Hud.region_of`, `Hud.line_no_row`, `Hud.box_rows` are static and tested.
- **F9 grid (DC7):** `[design call]` the grid is drawn at 25% INK alpha per 8-px line and 50% every 16 px (story said INK at 50%; the faint/strong split makes the tile grid readable). Toggle only when the HUD is visible and `Hud.grid_toggle_allowed(OS.is_debug_build(), search)` (pure, tested).
- **URL query:** `[design call]` the 1.3 query parsing moved into `src/core/url_query.gd` (`UrlQuery.has_debug/has_smoke/web_search`) so Main's two smoke gates and the HUD's F9 gate share one parser; `Main.wants_audio_smoke` keeps its behaviour (1.3 tests unchanged and green), `Main.wants_arena_smoke` added.
- **Layers (DC8, DC9):** `Main._build_layers()` adds `Arena`, `Entities`, `Particles` (Node2D), `Hud` (layer 10), `ScreenFX` (CanvasLayer 20) before the title; arena and HUD hidden at boot, shown by `show_arena(true)` behind `?debug&smoke=arena`.
- **Tests:** 7 new GUT files (38 tests): `test_font_coverage` (glyph set derived from `Arena.LAYOUT`, `Hud` constants and box rows, title text), `test_arena_layout`, `test_hud_layout`, `test_glyph_palette`, `test_grid_overlay`, `test_main_layers`, `test_title_font`. Total 111/111 (73 before).
- **Size record:** `build/web` 28,425,026 bytes (budget 30,000,000; 1.4 baseline 28,406,474; +18,552). Files: index.side.wasm 25,414,775; index.wasm 1,600,314; index.js 1,314,483; index.pck 40,648; rest < 25 kB.
- **Screenshots (8.4):** desktop `shot_title.png`, `shot_arena.png`, `shot_grid.png` (F9 grid on) and headless Chrome `web_arena.png` (`?debug&smoke=arena`, 1280×720 = 2× integer scale), saved in the dev session scratchpad (not committed). Arena, HUD regions and grid line up with the 8-px cells.
- **Observation:** the font's caps fill rows 0–6, so rows 0 and 1 of the HUD (top bar and sky) sit with no gap between them. This is how 8×8 CP437 fonts behave; it can be revisited when 3.1 fills the top bar.
- **Not changed:** web template, `export_presets.cfg`, `.github/workflows/ci.yml`, README, `check_guards.sh`, `Game` flow states.

### File List

- _bmad-output/implementation-artifacts/1-5-the-clearing-arena-and-ide-hud-frame.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: status → review)
- game/tools/gen_glyph_font.py (new)
- game/assets/fonts/wildshift8.fnt (new, generated)
- game/assets/fonts/wildshift8.fnt.import (new)
- game/assets/fonts/wildshift8_0.png (new, generated)
- game/assets/fonts/wildshift8_0.png.import (new)
- game/assets/fonts/wildshift8-LICENSE.txt (new)
- game/src/core/glyph_font.gd (new) + .uid
- game/src/core/url_query.gd (new) + .uid
- game/src/arena/arena.gd (new) + .uid
- game/src/ui/hud/hud.gd (new) + .uid
- game/src/ui/hud/hud.tscn (new)
- game/src/ui/hud/hud_frame.gd (new) + .uid
- game/src/ui/hud/grid_overlay.gd (new) + .uid
- game/src/main/main.gd (modified)
- game/src/ui/screens/title/title_screen.gd (modified)
- game/project.godot (modified: `[input]` gains `debug_grid` on F9)
- game/tests/unit/test_font_coverage.gd (new) + .uid
- game/tests/unit/test_arena_layout.gd (new) + .uid
- game/tests/unit/test_hud_layout.gd (new) + .uid
- game/tests/unit/test_glyph_palette.gd (new) + .uid
- game/tests/unit/test_grid_overlay.gd (new) + .uid
- game/tests/unit/test_main_layers.gd (new) + .uid
- game/tests/unit/test_title_font.gd (new) + .uid

### Change Log

- 2026-11-07: Story created by gds-create-story (unattended). Status → ready-for-dev. Design calls DC1–DC12 recorded.
- 2026-11-07: Story implemented by gds-dev-story (unattended). Original CC0 font Wildshift8 (generated BMFont), GlyphFont helper, Arena layout and clamp, HUD frame with F9 grid, render layers in Main, title on the pixel font; 38 new GUT tests (111/111). Web build 28,425,026 bytes. Status → review.
