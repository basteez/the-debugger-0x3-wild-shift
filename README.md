# The Debugger 0x03: Wild Shift

> Shift your weapon's bits mid-fight to squash monstrous bugs.

A top-down action boss rush made for **[GitHub Game Off 2026](https://itch.io/jam/game-off-2026)** (theme: **SHIFT**).

A present-day developer and their rubber duck are pulled into a fantasy RPG whose monsters are literal software bugs. Your weapon is a **bit register**: a ring of ability bits you rotate left (`<<`) or right (`>>`) in real time. The two leftmost bits form the **active window** — they are your two action buttons, and pressing them in order fires that window's combo.

Three bosses — **Infinite Loop**, **Null Pointer** and **Segfault** — each behave like the bug they're named after. Every defeated bug drops a new bit into the register and changes which combos exist.

- 🎮 Plays in the browser (HTML5), no install
- ⏱️ A full run takes 10–15 minutes
- 🖥️ 1-bit, code-as-fantasy look: text glyphs, a debugger HUD, damage as `console.log` lines

> **Status:** in development — the jam submission deadline is **2026-12-01 13:37 PST**. A playable build will be linked here and on itch.io.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | Left stick / D-pad |
| Action 1 (slot 1) | J | X / Square |
| Action 2 (slot 2) | K | A / Cross |
| Shift `<<` | Q | LB / L1 |
| Shift `>>` | E | RB / R1 |
| Breakpoint | Space | RT / R2 |
| Watch (hold) | R | Y / Triangle |
| Pause | Esc | Start |

## Tech

- [Godot 4.7.2](https://godotengine.org/) (GDScript, Compatibility renderer, web export)
- [mumble-speech](https://github.com/basteez/mumble-speech) for the rubber duck's voice
- [GUT](https://github.com/bitwes/Gut) for tests

The Godot project lives in `game/` (created in the first implementation story). Open `game/project.godot` with Godot 4.7.2.

## Repository layout

| Path | Contents |
|---|---|
| `game/` | Godot project (source, data, assets, tests) |
| `_bmad-output/` | Design docs produced with the [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD): game brief, GDD, architecture, epics, sprint status |

## Contributing

`main` is protected: all changes go through pull requests.

## License

Code is released under the [MIT License](LICENSE).
