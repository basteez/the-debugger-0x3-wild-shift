# Addendum — Game Brief: The Debugger 0x03: Wild Shift

## Market & Reference Research (2026-11-06, web research digest)

### Comparable titles
- **Game is Full of Bugs** (Steam) — programmer vs bug enemies; weapon cycles a deck-like magazine of crafted bullets. Closest commercial analogue. https://store.steampowered.com/app/2868030
- **The Debugger** (itch.io demo, antonion-games) — developer trapped in his own game fighting bugs. Same premise; **name collision risk** with "The Debugger 0x03". https://antonion-games.itch.io/the-debugger
- **The Bugger** — 1-bit isometric RPG, bugs escaping a computer.
- **HackeRPG**, **Coding Nightmares** (itch.io) — dev-vs-bugs shooters; premise is common, so the differentiator must be the register mechanic.
- Unverified/from memory: Mega Man Battle Network (viruses, real-time chip loadouts), Hack 'n' Slash (Double Fine).
- Rotation/combo systems (from memory): DMC style switching, Magicka (adjacent element combos), Noita (visible wand sequence).
- Boss rush / 1-bit: Titan Souls, Furi, Furi Demake – The Chain (jam-scale single boss), ASCII Wars (ASCII shmup boss rush), Secrets of the Tundra. No 1-bit/ASCII top-down melee boss rush found — niche appears open.

### Game Off context
- 2026 (14th edition): deadline Dec 1 2026 13:37 PST; voting until Jan 1 2027; public GitHub repo + itch.io submission; AI allowed with disclosure; categories Overall, Gameplay, Graphics, Audio, Innovation, Theme. **The official blog itself suggests "bits" and "a programming puzzler using bitwise shifts"** → bit-shift interpretation is endorsed but not rare; expect competition on the same reading. https://github.blog/open-source/gaming/game-off-2026-the-theme-is-shift/
- 2025 "WAVES": 700+ entries; 6/10 top in Godot; winners = one mechanic, polished.
- 2024 "SECRETS": 500+ entries; Overall: Trail of Secrets (Godot, minimalist); Innovation: Shaki Shaki Island.

### Godot 4 web export pitfalls (for architecture)
- Keep single-threaded export (default since 4.3); threads need COOP/COEP, itch.io SAB support experimental, breaks on Safari/Firefox Android.
- Audio: Sample mode = low latency but no AudioEffects (affects planned bit-crush/pitch-shift glitch on boss music) → pre-render glitched tracks or accept Stream-mode latency. Browser requires user gesture before audio → "press to start" screen.
- Compatibility renderer (WebGL2) only; Safari WebGL2 quirks; GDScript only (no C# web export).
- itch.io no on-the-fly compression → large .wasm/.pck; consider stripped custom export template.
- Fullscreen only from input event; IndexedDB saves can fail in iframes/private mode; background tabs pause.
- Unverified: binding `<<`/`>>` to Shift keys may trigger Windows Sticky Keys (5× Shift) and clash with browser shortcuts.
