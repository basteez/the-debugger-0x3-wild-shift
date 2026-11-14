---
baseline_commit: main (41247c1)
---
# Story 7.1: Music and Crossfades

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-14). Judgment calls are marked [design call] with the chosen default (D-S71-n); the implementer follows them or records a change in Completion Notes. Scope: the full music plumbing (two music players, crossfade, track-per-context, phase-3 glitch variant, Breakpoint muffled loop) with GENERATED PLACEHOLDER loops at the final asset paths. Tiziano drops in the real BeepBox tracks later with no code change. NOT in scope: the real music (human composition), the SFX pass (7.2), any live audio effect (Sample mode forbids them), the audio credit line (`audio: TBD` stays until 7.9). -->

## Story

As a player,
I want chiptune music that glitches as each bug gets desperate,
so that the audio raises the tension of each fight.

**Requirements:** FR62. Additional: AD-09 (AudioManager, Music bus, two crossfaded players, Sample playback), GDD "Audio and Music" (4 tracks, 3 glitch variants, 1 muffled Breakpoint loop, no live effects), project-context Platform & Build Rules (no audio before first input; Sample mode; glitch and muffled music are pre-rendered files; crossfade = two players + volume). Window: Nov 26–29 (Epic 7); the track drop-in by Tiziano is a HUMAN task that can start in Epics 5–6.

Depends on: 1.4 (audio unlock on title input), 3.1 (`boss_phase_changed`, `boss_tell_started`), 4.3 (`breakpoint_started` / `breakpoint_ended` and the placeholder handlers in `AudioManager`), 6.7/6.8 (INTRO and ENDING flow states that must carry music).

## Acceptance Criteria

**Track plumbing and title/boss tracks (FR62, AD-09)**

1. **Given** the music files in `game/assets/audio/music/` at the final names (`title.ogg`, `boss_1.ogg`, `boss_2.ogg`, `boss_3.ogg`, `boss_1_glitch.ogg`, `boss_2_glitch.ogg`, `boss_3_glitch.ogg`, `breakpoint_muffled.ogg`), **When** the flow advances, **Then** the title track starts on the first input (`AudioManager.unlock()`, nothing earlier) and continues through INTRO, and each boss's track plays in its FIGHT.
2. **And** every track change goes through `AudioManager.crossfade_to(track: AudioStream, frames: int)`, which uses two `AudioStreamPlayer` nodes on the `Music` bus (`MusicA`, `MusicB`), alternating, with a volume crossfade. The old player is stopped and freed or idled after the fade; at most two music players exist at any time.
3. **And** all music streams are loaded with `preload()` (project-context: no runtime `load()`), and each `.ogg` has loop enabled in its import settings so the loop plays seamlessly.
4. **And** the sim does not know about audio: no `AudioManager`, `Tween` or `AudioStreamPlayer` reference is added under `src/{input,register,player,combat,bosses,skills,arena}`; `check_guards.sh` stays green.

**Phase-3 glitch variant (FR62, GDD Audio)**

5. **Given** a boss reaches its third phase, **When** `boss_phase_changed` is emitted with the 0-based phase index 2 (`[design call] D-S71-1`), **Then** the music crossfades to that boss's `_glitch` variant, in sync with the base track's playback position.
6. **And** a boss whose def has fewer than three phases (the Boss 1 phase-3 cut, D-S35 fallback) never emits index 2 and keeps its base track: no code change is needed for the cut.
7. **And** on a new fight (including a retry), the boss's base track restarts from the beginning and the glitch variant is not carried over.

**Breakpoint muffled loop (GDD Breakpoint, FR24)**

8. **Given** `breakpoint_started` fires, **When** the event is handled, **Then** the music crossfades to `breakpoint_muffled.ogg` (the same muffled loop for all fights); **And** given `breakpoint_ended`, **Then** the music crossfades back to the track the current context wants (base or glitch) at the same playback position.
9. **And** a phase-3 change while Breakpoint is active does not switch the music; the glitch variant is applied when Breakpoint ends (single desired-track rule, D-S71-7).

**Flow states (design calls, D-S71-3 to D-S71-5)**

10. **Given** the flow enters HARVEST, **Then** the music fades to silence over 30 frames; **Given** the flow enters ENDING, **Then** the title track plays from the start.
11. **And** the mapping from context to track is a single pure function (`desired_track(...)`, static, no audio playback) that the unit tests cover completely: TITLE/INTRO, FIGHT x 3 bosses x base/glitch, Breakpoint over any of them, HARVEST, ENDING, DEAD (keeps the fight track).

**No live effects and no regressions**

12. **Given** the Music bus, **Then** it has no `AudioEffect` (existing `test_no_bus_effects` stays green); no reverb, low-pass or pitch effect is used for the muffled loop, which is a pre-rendered file.
13. **And** before `unlock()`, no music player plays and any request logs the existing warn-once message (same rule as SFX).
14. **And** the existing SFX behaviour (shift click, thud, chime, squeak, tell blip, defeat squeak) is unchanged; the Breakpoint placeholder log lines are replaced by the real music switch, keeping the `breakpoint_music_events` counter used by tests.

**Placeholder tracks (brief decision, marked in repo)**

15. **Given** no BeepBox tracks exist yet, **Then** the eight files above are placeholder loops generated by a committed script (`game/tools/`), deterministic (no RNG, same bytes on every run), each with the same length and tempo within its family so the variants stay in sync: the base loops are simple chiptune patterns, each `_glitch` is a bit-crushed/pitch-shifted copy of its base, `breakpoint_muffled.ogg` is a low-passed copy of a shared pattern.
16. **And** every placeholder is marked as a placeholder: a `game/assets/audio/music/README.md` lists the eight files, their status (PLACEHOLDER), the licence line for the real tracks, and the replacement rule (same file name, same loop length, re-import). `_bmad-output/implementation-artifacts/deferred-work.md` gets a Story 7.1 entry with the same list.
17. **And** a GUT test asserts that each of the eight paths exists and loads as `AudioStreamOggVorbis` with `loop` enabled, so a missing or mis-imported real track fails CI.

**Human checks (recorded, not automated; not faked)**

H1. Chrome: title track after the first press, boss 1–3 tracks, glitch switch at phase 3 sounds in step with the base track, Breakpoint mutes and returns in step, no click at crossfades.
H2. Firefox and Safari: same checks (the Sample-mode audio path is the risk).
H3. Tiziano: drop one real BeepBox `.ogg` over a placeholder with the same name, re-import, confirm it plays with no code change.

## Tasks / Subtasks

### Group A: Placeholder assets (AC: 15, 16, 17)

- [x] A1 Write `game/tools/generate_placeholder_music.*` (GDScript run headless or Python, pick the one that can encode Ogg Vorbis, see Dev Notes "Encoder"). Output the eight `.ogg` files at the final paths. Deterministic. (AC 15)
- [x] A2 Create the eight `.ogg` files and their `.ogg.import` files with loop enabled. Verify Godot imports them headless. (AC 3, 15)
- [x] A3 Write `game/assets/audio/music/README.md` (PLACEHOLDER status, file list, replacement rule, licence line for real tracks). (AC 16)

### Group B: AudioManager music (AC: 2, 3, 4, 10, 11, 13)

- [x] B1 Add `MusicA` / `MusicB` players on bus `Music`, `crossfade_to(track, frames)` with a Tween on `volume_db` (linear fade in seconds = frames / 60). Stop and free or idle the old player when the fade ends. (AC 2)
- [x] B2 Add `desired_track(context) -> AudioStream` (static, pure) and the context state: flow state, boss index, glitch flag, breakpoint flag. (AC 11)
- [x] B3 Preload the eight streams as constants (no runtime `load()`). (AC 3)
- [x] B4 Subscribe to `flow_state_changed`, `boss_phase_changed` and the existing `breakpoint_started` / `breakpoint_ended` handlers; replace their placeholder bodies with the desired-track update. Keep `breakpoint_music_events`. (AC 8, 9, 14)
- [x] B5 Play the title track in `unlock()` (first input only). Refuse all music requests before unlock with the existing warn-once rule. (AC 1, 13)
- [x] B6 Remove the "placeholder until 7.1" comments in `audio_manager.gd` header and the Breakpoint handlers. (AC 14)

### Group C: Wiring (AC: 1, 5, 6, 7, 10)

- [x] C1 Read the boss index for the fight from `Game` (read-only; presentation may read sim state, AD-05). Map boss index 0/1/2 to `boss_1`/`boss_2`/`boss_3` and their glitch variants. (AC 1, 5, 7)
- [x] C2 On FIGHT entry, restart the boss base track from 0 (a 0-frame cut, D-S71-4); on DEAD, keep the current track. (AC 7)
- [x] C3 On HARVEST, fade to silence over 30 frames; on ENDING, crossfade to the title track. (AC 10)

### Group D: Tests (AC: 1–17)

- [x] D1 Extend `game/tests/unit/test_audio_manager.gd` (or add `test_music_director.gd`): desired-track table (AC 11), two-player and Music-bus checks (AC 2, 12), pre-unlock silence (AC 13), phase index 2 only (AC 5, 6), Breakpoint round trip returns to the same track (AC 8, 9), HARVEST silence and ENDING title (AC 10).
- [x] D2 Add the asset test: eight paths exist, load as `AudioStreamOggVorbis`, loop on (AC 17). Also check that base and glitch/muffled share the same length (`get_length()`) within their family (AC 15).
- [x] D3 Run the full GUT suite headless and `check_guards.sh`. Record the results in Completion Notes.

### Group E: Docs and human checks (AC: 16, H1–H3)

- [x] E1 Add the Story 7.1 entry to `deferred-work.md` (placeholder list, H1–H3 pending, encoder note).
- [x] E2 Record H1–H3 as pending in Completion Notes. Do not mark them done.

## Dev Notes

### Design calls (D-S71-n)

- **D-S71-1 (phase index).** The AC text says `boss_phase_changed(3)`, but `EventBus.boss_phase_changed` is documented as the 0-based phase index. "Phase 3" in the GDD is the third phase, so the glitch fires on index **2**. Record this in Completion Notes.
- **D-S71-2 (track mapping).** Boss index 0 = Infinite Loop = `boss_1`; 1 = Null Pointer = `boss_2`; 2 = Segfault = `boss_3` (the order of `Game.BOSS_IDS`, and the architecture's `boss_2.ogg` example).
- **D-S71-3 (title track).** The title track starts on `unlock()` and keeps playing through INTRO. Its first crossfade is to `boss_1` when FIGHT boss 0 starts.
- **D-S71-4 (restart).** Every FIGHT entry (first start and retry) restarts the boss base track from position 0 with a cut (`frames = 0`). DEAD keeps the current track playing.
- **D-S71-5 (HARVEST / ENDING).** HARVEST fades to silence (30 frames) so the squeak and the harvest text are heard clean. ENDING plays the title track from the start (60 frames).
- **D-S71-6 (fade lengths).** Flow changes and boss changes: 60 frames. Phase-3 glitch: 30 frames. Breakpoint in and out: 12 frames (Breakpoint is at most 120 frames and must feel immediate).
- **D-S71-7 (single desired-track rule).** Music state is a function of (flow state, boss index, phase >= 2, breakpoint active). A phase-3 change during Breakpoint only updates the flag; the crossfade happens when Breakpoint ends. This avoids double crossfades.
- **D-S71-8 (sync).** The incoming player starts at the outgoing player's `get_playback_position()` (modulo the track length), so the glitch and muffled variants keep the bar position. This requires equal length and tempo inside each family. The generator and the test (D2) enforce it. Real BeepBox exports must keep the same bar count and BPM, recorded in the README.
- **D-S71-9 (placeholder sound).** Simple chiptune: square/triangle arpeggio plus bass in 4 bars, one tempo per family. Glitch = bit-crushed (e.g. 4-bit quantise) plus a +2 semitone shift via resampling; muffled = one-pole low-pass at about 600 Hz applied in the generator. It only needs to make the switches audible for H1, not to be good music.

### Encoder (open question, blocks A1/A2 if unresolved)

No `ffmpeg`, `oggenc` or `sox` is installed on the dev machine; Python has no `numpy` or `soundfile`. Options, in order: (1) `brew install ffmpeg` and generate WAV then `ffmpeg -c:a libvorbis`; (2) `pip install soundfile` (bundles libsndfile with Vorbis write support) in a throwaway venv; (3) a committed pure-GDScript Vorbis writer is NOT acceptable (too large for this story). If neither (1) nor (2) is allowed, stop at A1 and report to Tiziano. The generator script itself must be committed, so the placeholders can be regenerated.

### Current state of the code (read before editing)

- `game/src/autoloads/audio_manager.gd`: `unlock()`, SFX helpers (`play_sfx`, `play_squeak`), placeholder blips built in `_ready`, `on_breakpoint_started` / `on_breakpoint_ended` only log and count (`breakpoint_music_events`). `_shift_player` and `_squeak_player` are the SFX players; music players must be separate and must not reuse them.
- `game/default_bus_layout.tres`: buses `Master`, `Music`, `SFX`, `Voice` exist, no effects.
- `game/src/autoloads/event_bus.gd`: `flow_state_changed(from, to)`, `boss_phase_changed(phase)`, `breakpoint_started()`, `breakpoint_ended()`, `boss_defeated(boss)` are declared. Do not add signals here unless needed; if a new one is needed, it goes in `event_bus.gd` only (project rule).
- `game/src/autoloads/game.gd`: `enum FlowState { TITLE, INTRO, FIGHT, DEAD, HARVEST, ENDING }`, `BOSS_IDS` by boss index, `run.boss_index`.
- `game/src/bosses/framework/boss_controller.gd`: emits `boss_phase_changed(phase_index)` at each phase change (line ~300), `phase_index` starts at 0.
- `game/src/ui/screens/title/title_screen.gd` (line ~100): calls `AudioManager.unlock()` on the first input, then `Game.start_run_from_title`.
- `game/assets/audio/music/` contains only `.gitkeep`. `game/assets/audio/sfx/` has the shift WAVs.
- Tests: `game/tests/unit/test_audio_manager.gd` (bus, mute, unlock, SFX, buses, no effects). `test_smoke_audio.gd` exists.

### Previous story intelligence

- 3.1 review lesson: audio streams are built in `_ready`, never inside the sim tick. Keep the same rule: no stream creation or preload work inside `_process`/tick.
- 2.4 and 3.6 lesson: SFX use their own players; a new play cuts the previous one on that player. Music must not share a player with SFX.
- 6.8 note: the ENDING credit line is `audio: TBD` in `data/ending/ending_text.tres`; 7.1/7.2 choose the sources, 7.9 replaces the line before submission. Do not change it in this story; record the sources in the README (A3) for 7.9.
- 4.3 and 5.4 pattern: the Breakpoint and Watch events are emitted once per start/end from the sim, and presentation listens. Keep the same once-per-event contract in the handlers.

### Architecture and rules that bind this story

- AD-09: `AudioManager` autoload; buses Master/Music/SFX(/Voice); two music players crossfaded; requests via EventBus; Sample playback; no bus effects.
- Presentation is read-only towards the sim: `AudioManager` may read `Game` state, never write it.
- `await` and Tweens are allowed only in presentation (AudioManager is presentation). `create_tween()` is fine here, never in the sim.
- Static typing everywhere; `StringName` ids; `Log.info/debug/warn(&"audio", ...)` only; no bare `print`; no magic numbers (fade frames as named constants).
- Environment failure (audio not unlocked, stream missing) logs `Log.warn` once and continues silent.

### Testing standards

- GUT, headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (Godot at `/Applications/Godot.app/Contents/MacOS/Godot`).
- Pure logic (`desired_track`) in unit tests with no scene tree. Crossfade and player counts in unit tests with a bare `AudioManager` node.
- No RNG in this story: the generator is deterministic and tests need no seed. If a test ever uses randomness, seed it (brief).

### Project Context Rules

- Godot 4.7.2, GDScript only, Sample audio mode, no live effects, no audio before the first input.
- Music is pre-rendered; crossfade = two players + volume.
- Files `snake_case`; constants `UPPER_SNAKE`; no magic numbers.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.1: Music and Crossfades]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Audio and Music]
- [Source: _bmad-output/game-architecture.md#Audio (AD-09)] and AD-09 row in the decision table
- [Source: _bmad-output/project-context.md#Platform & Build Rules]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (7.1 entry added in E1)

## Dev Agent Record

### Agent Model Used

Claude Opus (gds-dev-story, pipeline, 2026-11-14).

### Debug Log References

### Completion Notes List

- Coordinator decisions applied: D-S71-1 (glitch on 0-based phase index 2, `GLITCH_PHASE_INDEX`), D-S71-2 (boss index 0/1/2 = `boss_1/2/3`), D-S71-5 (HARVEST fades to silence over 30 frames, ENDING plays the title from 0). D-S71-3/4/6/7/8/9 followed as written, with the refinements below.
- Encoder: Python venv in the session scratchpad with `numpy` + `soundfile` (libsndfile 1.2.2, Vorbis). Nothing installed system-wide. The dependency and the venv recipe are documented in the generator header and in the music README.
- A1/A2: `game/tools/generate_placeholder_music.py` writes the eight loops (mono 22050 Hz, 120 BPM, 4 bars = 176400 frames = 8.0 s each). Two runs produce byte-identical files (verified with `shasum`). libsndfile picks a random Ogg serial, so the script rewrites every page's serial to a constant and recomputes the page CRCs. `.ogg.import` files have `loop=true`; imported headless.
- [design call] Glitch pitch shift: the +2 semitones is applied at synthesis (same note timing) instead of resampling, because resampling would shorten the loop and break the bar sync (D-S71-8). Then 4-bit quantise + 1/4 sample-and-hold. Muffled = the `shared` pattern through a one-pole low-pass at 600 Hz, run twice over the loop so the filter state wraps seamlessly.
- [design call] All eight loops share one length (8.0 s), so the muffled loop is in step with every boss family. Import `bpm`/`beat_count` left at 0 so a real track with another BPM is not truncated by the import settings.
- B1: `crossfade_to(track, frames, sync := true)`: two players `MusicA`/`MusicB` on bus `Music`, created on the first music request after unlock (so nothing exists at boot), alternating; `volume_linear` tween (frames / 60 s); outgoing player stopped by a tween callback at the end of its fade; `frames = 0` is a cut. A null track fades to silence. [design call] Extra `sync` parameter: true starts the incoming track at the outgoing `get_playback_position()` modulo its length (D-S71-8); false starts from 0 (FIGHT entry, ENDING).
- B2: `static func desired_track(flow, boss_index, glitch, breakpoint_active) -> AudioStream` (pure; null = silence). [design call] Breakpoint only overrides in FIGHT; DEAD always wants the fight track (base or glitch), so a death during Breakpoint returns to the fight track instead of staying muffled. Out-of-range boss index = silence.
- B4/C1-C3: `_on_flow_state_changed` reads `Game.run.boss_index` (read-only) and calls `on_music_flow_changed(from, to, boss_index)`. FIGHT entry resets glitch and breakpoint flags and restarts the base track from 0. [design call] Reconciling D-S71-3/4/6: a retry (DEAD -> FIGHT) is a 0-frame cut; any other FIGHT entry (INTRO -> FIGHT, HARVEST -> FIGHT, debug jump) starts the boss track from 0 with a 60-frame fade-in/crossfade. `boss_phase_changed` connected to `on_boss_phase_changed`; Breakpoint handlers keep `breakpoint_music_events` and now switch the music (12 frames). A phase-3 change during Breakpoint only updates the flag (no switch) and the glitch applies at Breakpoint end.
- B5: `unlock()` starts the title (0-frame start). [design call] Before unlock, context changes from EventBus update the music state silently (no warn, so flow changes in headless tests do not spam); an explicit `crossfade_to` before unlock is refused with the existing warn-once rule (AC 13).
- B6: the "placeholder until 7.1" comments and log lines are gone; the header documents the music.
- Existing tests touched (no behaviour change for SFX): `test_audio_manager.gd` and `test_duck_bubble.gd` counted all AudioManager children after `unlock()`; they now count SFX players only, since unlock adds `MusicA`/`MusicB`.
- AC 4: no sim folder touched; `check_guards.sh` OK. AC 12: no bus effect added (`test_no_bus_effects` green).
- D3 results: full GUT suite 1611/1611 passing (140732 asserts), `test_music_director.gd` 24 tests; `check_guards.sh`: OK.
- Placeholder size: about 580 KB for the eight files (relevant to the 7.7 build-size check).
- [design call] APPROVED by coordinator (2026-11-14): retry (DEAD -> FIGHT) = 0-frame cut, every other FIGHT entry = 60-frame crossfade. The same-length-per-family test is kept; the constraint is stated in `assets/audio/music/README.md`.
- Code review (gds-code-review, 3 parallel layers): fixed `boss_phase_changed` outside FIGHT switching music during DEAD/HARVEST, zero-length stream position, null-unsafe cast in `test_duck_bubble.gd`, flaky 0.1 s position tolerances (now 0.25 s), README same-length constraint. Deferred: rapid A-B-A switch cutting a still-audible fade-out; web Sample-mode `get_playback_position()` reliability (H2); AC 13 silent latch of EventBus requests before unlock (documented design call). Dismissed: `Game.run` null (never null), tree-pause interference (no pausing in src), Python generator nits, `.import` files (present, in the PR).
- Human checks PENDING (not done, not faked): H1 Chrome, H2 Firefox and Safari, H3 real-track drop-in by Tiziano. Recorded in `deferred-work.md`.

### File List

- game/src/autoloads/audio_manager.gd (modified)
- game/tests/unit/test_audio_manager.gd (modified)
- game/tests/unit/test_duck_bubble.gd (modified)
- game/tests/unit/test_music_director.gd (new)
- game/tests/unit/test_music_director.gd.uid (new)
- game/tools/generate_placeholder_music.py (new)
- game/assets/audio/music/README.md (new)
- game/assets/audio/music/title.ogg, title.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/boss_1.ogg, boss_1.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/boss_2.ogg, boss_2.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/boss_3.ogg, boss_3.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/boss_1_glitch.ogg, boss_1_glitch.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/boss_2_glitch.ogg, boss_2_glitch.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/boss_3_glitch.ogg, boss_3_glitch.ogg.import (new, PLACEHOLDER)
- game/assets/audio/music/breakpoint_muffled.ogg, breakpoint_muffled.ogg.import (new, PLACEHOLDER)
- _bmad-output/implementation-artifacts/deferred-work.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/7-1-music-and-crossfades.md (this file)

## Change Log

- 2026-11-14: Story created unattended by gds-create-story (pipeline). Status ready-for-dev.
- 2026-11-14: Implemented by gds-dev-story (pipeline): music plumbing in AudioManager (two crossfaded players, desired_track, phase-3 glitch, Breakpoint muffled loop, HARVEST silence, ENDING title), deterministic placeholder generator and eight PLACEHOLDER loops, music README, tests. Human checks H1–H3 pending. Status review.
