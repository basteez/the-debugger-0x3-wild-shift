# The Debugger 0x03: Wild Shift

> Shift your weapon's bits mid-fight to squash monstrous bugs.

A top-down action boss rush made for **[GitHub Game Off 2026](https://itch.io/jam/game-off-2026)** (theme: **SHIFT**).

A present-day developer and their rubber duck are pulled into a fantasy RPG whose monsters are literal software bugs. Your weapon is a **bit register**: a ring of ability bits you rotate left (`<<`) or right (`>>`) in real time. The two leftmost bits form the **active window** — they are your two action buttons, and pressing them in order fires that window's combo.

Three bosses — **Infinite Loop**, **Null Pointer** and **Segfault** — each behave like the bug they're named after. Every defeated bug drops a new bit into the register and changes which combos exist.

- 🎮 Plays in the browser (HTML5), no install
- ⏱️ A full run takes 10–15 minutes
- 🖥️ 1-bit, code-as-fantasy look: text glyphs, a debugger HUD, damage as `console.log` lines

> **Status:** jam entry for GitHub Game Off 2026, in final polish. The submission deadline is **2026-12-01 13:37 PST**. The music in the current build is placeholder loops until the final tracks land.

## Controls

### Play

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | Left stick / D-pad |
| Action 1 (slot 1) | J | X / Square |
| Action 2 (slot 2) | K | A / Cross |
| Shift `<<` | Q | LB / L1 |
| Shift `>>` | E | RB / R1 |
| Breakpoint | Space | RT / R2 (trigger) |
| Watch (hold) | R | Y / Triangle |
| Pause / resume | Esc / P | Start |

In the browser, click the game once before playing: browsers only start audio after a click or a key press, and a gamepad press may not count, so click once to enable audio if you play on a pad.

### Title and pause options

Every option can also be clicked.

| Option | Where | Keyboard | Gamepad |
|---|---|---|---|
| New run (shown once a save is past the first boss) | Title | N | Select / Back |
| Practice (the `/* test */` dummy, no save) | Title | P | L3 (left stick click) |
| Debug build (assist on/off) | Title, pause | B | B / Circle |
| Fullscreen on/off | Title, pause | F | R3 (right stick click) |
| Mute on/off | Pause | M | Select / Back |

In practice, L (pad: Select) cycles the loadout and Esc (pad: L3) goes back to the title. Any other key or button on the title starts the run (with a save past Boss 1 it resumes at the saved boss).

## Run and build

You need [Godot 4.7.2](https://godotengine.org/) (the standard build, not .NET). The commands below call it `godot`; on macOS the binary is usually `/Applications/Godot.app/Contents/MacOS/Godot`. Run them from the repository root.

```bash
# Open the project in the editor, or run it
godot --editor --path game
godot --path game

# Unit tests (GUT, headless; the same command CI runs)
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Static guards
bash game/tools/check_guards.sh

# Web export (release) into build/web
mkdir -p build/web
godot --headless --path game --export-release "Web" ../build/web/index.html

# Size budget (32 MB) and local smoke test of the export
bash game/tools/check_build_size.sh build/web
bash game/tools/smoke_web.sh
```

The Web export needs a Web export template. CI builds a stripped template from source with `game/tools/build_web_template.sh` (see the script header to use it locally); an export with the stock template works but is over the 32 MB budget, so `check_build_size.sh` fails on it.

The asset generators are plain scripts: `python3 game/tools/gen_glyph_font.py` (font), `python3 game/tools/gen_sfx.py` (sound effects), `game/tools/generate_placeholder_music.py` (placeholder music, needs `numpy` and `soundfile`, see its header) and `game/tools/render_duck_lines.gd` (duck voice clips, see its header).

## Tech

- [Godot 4.7.2](https://godotengine.org/) (GDScript, Compatibility renderer, web export)
- [mumble-speech](https://github.com/basteez/mumble-speech) for the rubber duck's voice
- [GUT](https://github.com/bitwes/Gut) for tests

The Godot project lives in `game/`. Open `game/project.godot` with Godot 4.7.2.

## Repository layout

| Path | Contents |
|---|---|
| `game/` | Godot project (source, data, assets, tests) |
| `_bmad-output/` | Design docs produced with the [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD): game brief, GDD, architecture, epics, sprint status |

## Deploying a draft build (itch.io)

Draft builds go to the itch.io page with [butler](https://itch.io/docs/butler/) on the `html5` channel. The deploy is **manual**: in GitHub, Actions → CI → Run workflow on `main` (`workflow_dispatch`). Pushes and pull requests never deploy. The `deploy-itch-draft` job uploads the Web build from the same run and needs two repository settings:

| Setting | Kind | Value |
|---|---|---|
| `BUTLER_API_KEY` | Actions secret | an itch.io API key (itch.io account settings → API keys) |
| `ITCH_TARGET` | Actions variable | `<itch-user>/<game-slug>` |

If either is missing, the job is skipped with a notice. To deploy by hand from a local release export (`butler login` first, or `BUTLER_API_KEY` in the environment):

```bash
mkdir -p build/web
godot --headless --path game --export-release "Web" ../build/web/index.html
butler push build/web <itch-user>/<game-slug>:html5 --userversion "$(git rev-parse HEAD)"
```

Check a local export before uploading with `bash game/tools/smoke_web.sh` (serves `build/web` and loads it in headless Chrome when available).

## Contributing

`main` is protected: all changes go through pull requests.

## AI use

The code and the documentation of this game were written with an AI coding assistant (Claude, by Anthropic), under the direction of Tiziano Basile, who set the design, made the calls and reviewed the result. No generative image, music or voice model made any asset: the glyph font is bitmap data in an in-repo script (`game/tools/gen_glyph_font.py`), the sound effects and the placeholder music loops are synthesised by in-repo scripts (`game/tools/gen_sfx.py`, `game/tools/generate_placeholder_music.py`), and the rubber duck's voice is made by mumble-speech, Tiziano Basile's own library (live, or as pre-rendered clips made with it). The final music tracks are being made by Tiziano Basile in BeepBox.

## Credits

| What | Credit | Licence |
|---|---|---|
| Font | Wildshift8, 8x8 bitmap font made for this game by Tiziano Basile (generated by `game/tools/gen_glyph_font.py`) | CC0 1.0 (`game/assets/fonts/wildshift8-LICENSE.txt`) |
| Sound effects | Synthesised in this repository by `game/tools/gen_sfx.py` (no third-party samples) | CC0 |
| Music | Music by Tiziano Basile (BeepBox). **Placeholder** loops until the final tracks land: the current build ships loops generated by `game/tools/generate_placeholder_music.py` | Placeholder loops: CC0 |
| Duck voice | [mumble-speech](https://github.com/basteez/mumble-speech) by Tiziano Basile (`basteez/mumble-speech`), his own library; Godot addon 0.3.0, vendored unchanged in `game/addons/mumble_speech/` with both licence files | MIT or Apache-2.0 (dual) |
| Code | Tiziano Basile, written with AI assistance (see AI use) | MIT ([LICENSE](https://github.com/basteez/the-debugger-0x3-wild-shift/blob/main/LICENSE)) |
| Engine | [Godot Engine](https://godotengine.org/) 4.7.2 | MIT |
| Tests (development only, not in the web build) | [GUT](https://github.com/bitwes/Gut) 9.6.1 by Tom "Butch" Wesley | MIT |

## License

Code is released under the [MIT License](LICENSE).
