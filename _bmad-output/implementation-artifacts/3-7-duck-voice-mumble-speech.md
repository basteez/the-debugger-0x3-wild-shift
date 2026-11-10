---
baseline_commit: 8d4272d
---

# Story 3.7: Duck Voice (mumble-speech)

Status: done

<!-- Created unattended by gds-create-story. Open design questions are marked [design call] with the chosen default (D-S37-n); the implementer follows them or records a change in Completion Notes. Scope: the duck's spoken voice on top of the 3.6 seams (VoiceService.say / _speak / stop, TypewriterReveal.set_revealed, DuckBubble), the vendored mumble-speech v0.3.0 Godot addon, the web-template and size checks deferred from Story 1.3 (I-6), and the pre-render contingency. NOT MVP-blocking (D-046): if this slips past the Nov 14 gate the text-only bubble from 3.6 ships. -->

## Story

As a player,
I want the duck to babble its lines in a silly voice,
so that the hint system has personality.

**Requirements:** FR45 (voice, D-046); AD-14 (VoiceService wraps mumble-speech; pre-render contingency); ADR-05 (depend on mumble-speech at runtime behind VoiceService); I-6 (web check moved here from 1.3 AC9); NFR4 (web build ≤ 30 000 000 bytes); NFR15 (credit mumble-speech, MIT or Apache-2.0); AD-05 (presentation reads, never writes); D-039 (ten duck lines, this story voices the four T1 to T4 lines and every later line through the same seam).

## Acceptance Criteria

**Given** mumble-speech pinned to the v0.3.0 Godot addon (`mumble-speech-godot-0.3.0.zip`, SHA-256 `2adb6b5d9a399a20660c6b24bd810ea51b8b9b433317da02ed31394441e09f18`, checked against `SHA256SUMS.txt` from the same release)
**When** `addons/mumble_speech/` is vendored into `game/addons/mumble_speech/` (only that folder; no other platform binaries are referenced by the web export)
**Then** `game/addons/mumble_speech/` matches the zip byte for byte, the pinned version `0.3.0` and the source tag `godot/v0.3.0` are recorded in the README credits and in the Completion Notes, and `project-context.md` "Technology Stack" still reads correctly

**Given** the web export with Thread Support off and Extensions Support on (the stripped dlink template from Story 1.3, `game/tools/build_web_template.sh`)
**When** `bash game/tools/smoke_web.sh` runs and a `?debug&smoke=voice` scene speaks T1 after a click
**Then** `mumble_godot.wasm` is served with `application/wasm` and HTTP 200, `MumbleSpeaker` instantiates, the headless Chrome run has no `ERROR` console line or wasm load error, and the Completion Notes record the export as "side module loads: yes" (or the failure and the fallback taken)

**Given** the web build size measured against the budget
**When** the release export is built with the addon and the stripped template
**Then** the total is recorded in bytes next to the baseline 28 447 262 (latest record in `deferred-work.md`), the delta is written in Completion Notes, and the total is ≤ 30 000 000 bytes; if it is not, the size gate in D-S37-9 applies (the web build falls back to pre-render and the wasm is excluded), and no waiver is requested silently

**Given** a duck line is requested through `VoiceService.say(line)` on the mumble backend (the backend is picked by D-S37-2)
**When** the line starts
**Then** the speech plays on the `Voice` bus through one `MumbleSpeaker` child of `VoiceService`, `EventBus.duck_character_spoken(char_index)` is emitted for each spoken character, and `DuckBubble` sets the reveal with `TypewriterReveal.set_revealed(char_index + 1)` so the text and the voice stay in step
**And** the bubble's own 30 characters per second timer does not drive the reveal while the voice is speaking (`driven_externally`)

**Given** a voice line that ends (naturally or by `stop()`)
**When** `EventBus.duck_line_finished(line_id, completed)` is emitted
**Then** the bubble reveals the rest of the text (completed or cut), starts the hold countdown (`2.0 s + 0.05 s × length`, as in 3.6) and never waits on a voice that will not finish; a line cut by `stop()` shows its remaining text silently

**Given** a line is shown on the bubble
**When** the flow leaves FIGHT (`DuckBubble.clear()`) or `SimClock.paused` becomes true
**Then** `VoiceService.stop()` is called, the speech cuts at once, and no late `duck_character_spoken` or `duck_line_finished` can revive or re-hold a cleared bubble
**And** on resume after a pause the remaining text finishes silently with the 3.6 timer (D-S37-7)

**Given** the squeak on bubble open (3.6, D-S36-6)
**When** a line starts
**Then** the squeak plays first, and the voice starts after `SQUEAK_LEAD_S` (D-S37-6), so the two never overlap

**Given** a voice failure at runtime or at boot (no `MumbleSpeaker` class, the `MumbleVoice` resource does not load, a speak call errors)
**When** a line is requested
**Then** the text still shows silently with the 3.6 behaviour and a single `Log.warn(&"voice", ...)` is written for the whole run (not per line)

**Given** the pre-render contingency (AD-14)
**When** the mumble backend is not usable on the web build (the fallback chosen in D-S37-8 or D-S37-9)
**Then** `VoiceService` plays the pre-rendered clip of the line from `data/duck/duck_clips.tres` on the `Voice` bus with its recorded per-character timings, with no other code change than the backend choice constant, and the choice is recorded in Completion Notes

**Given** voice is presentation only (AD-05, D-S36-9)
**When** any test or replay runs
**Then** the existing replay and determinism tests pass unedited, no duck or voice code calls the `SimContext` RNG, `tick()` or any sim mutator, and `MumbleSpeaker`, `MumbleVoice` and `Mumble` names appear only in `voice_service.gd`, `data/duck/duck_voice.tres`, `data/duck/duck_clips.tres` and `tools/` (the isolation guard extends the 3.6 rule)

**Given** the Firefox and Safari checks (the epic AC; mumble-speech 0.3.0 notes say these are not verified upstream)
**When** a human runs the web build in each browser
**Then** the results are recorded as HUMAN items (section "Human checks" below) and the story does not claim them; the dev records only the headless Chrome result

## Tasks / Subtasks

### Group A: Vendor and pin the addon

- [x] A1. Download `mumble-speech-godot-0.3.0.zip` and `SHA256SUMS.txt` from `github.com/basteez/mumble-speech/releases/tag/v0.3.0` into a new empty directory under the session scratchpad. Run `sha256sum -c SHA256SUMS.txt` there and require `OK` for the godot zip. (AC 1)
- [x] A2. List the zip with `unzip -l` before extracting; extract only `addons/mumble_speech/` into `game/addons/mumble_speech/` (never into the repo root, never the Windows, mac or Linux libraries that the web export does not load; keep them if the folder is one unit, and record the decision). (AC 1)
- [x] A3. Check the addon's `.gdextension` file for the `web.debug`/`web.release` entries and confirm the non-threaded `mumble_godot.wasm` is the one the export loads (the threads build `mumble_godot.threads.wasm` must not be picked; `Thread Support` stays off). (AC 1, AC 2)
- [x] A4. Add the MIT/Apache-2.0 credit for mumble-speech to `README.md` credits and to the itch.io page text (Epic 7 owns the page; the README line is this story's). (NFR15)
- [x] A5. Record in Completion Notes the zip SHA-256, the file list with byte sizes of `addons/mumble_speech/` web files, and the GUT run result on a desktop Godot (the addon must not break the existing 114+ GUT tests).

### Group B: Template, smoke and size (I-6)

- [x] B1. Confirm the stripped template (`game/tools/build_web_template.sh`, disabled modules list) still loads GDExtension side modules: the release export with `custom_template/release` pointed to the local stripped zip (not committed) boots and loads `mumble_godot.wasm`. If the template needs a module re-enabled (for example `websocket`, `zip`, `mbedtls` as the 1.3 deferral notes), re-enable it in the script, record the byte cost, and keep the script's cache key in CI in step. (AC 2)
- [x] B2. Add a `?debug&smoke=voice` scene behind the same `Debug` gate and `smoke=` pattern as the 1.3 audio and 1.5 arena smoke scenes. It creates the `MumbleSpeaker` through `VoiceService` only, speaks T1 after a click and logs `voice smoke: spoke N chars` on the first `duck_character_spoken` and `voice smoke: finished` on `duck_line_finished`. Extend `game/tools/smoke_web.sh` with `SMOKE_QUERY='?debug&smoke=voice' SMOKE_CLICK=1 SMOKE_EXPECT='voice smoke: finished'`. (AC 2)
- [x] B3. Measure the release web export (addon + stripped template) with `find build/web -type f -exec wc -c {} + | tail -1` and write the size table (file, bytes, total) to Completion Notes. Compare against 28 447 262 and the 30 000 000 budget. (AC 3)
- [x] B4. Decide D-S37-9 from the B3 number and write the decision (see Dev Notes "Size gate"). (AC 3)

### Group C: Signals and the mumble backend in VoiceService

- [x] C1. `game/src/autoloads/event_bus.gd`: add two typed, past-tense signals (the only signals allowed, project rule): `duck_character_spoken(char_index: int)` and `duck_line_finished(line_id: StringName, completed: bool)`. Keep `duck_line_requested` unchanged. (D-S37-1)
- [x] C2. `game/src/autoloads/voice_service.gd` (keeps the `say()` / `stop()` / `_speak()` public API from 3.6): add `const BACKEND := Backend.AUTO` with `enum Backend { TEXT, MUMBLE, PRERENDER, AUTO }` (D-S37-2). `AUTO` resolves once in `_ready()` to MUMBLE when `ClassDB.class_exists(&"MumbleSpeaker")` and the speaker instantiates, else PRERENDER when the clips resource loads and holds the requested id, else TEXT, with one `Log.warn` for any downgrade. (AC 4, AC 7, AC 8)
- [x] C3. Create the speaker with `ClassDB.instantiate(&"MumbleSpeaker")` as a child node named `MumbleSpeaker`, `bus = &"Voice"`, `volume_db = 0.0`, and the `MumbleVoice` loaded from `data/duck/duck_voice.tres` (D-S37-3). Connect its `character_spoken` and `finished` signals to private `_on_character_spoken(i)` and `_on_finished()` methods, which re-emit through EventBus only. VoiceService declares no signal of its own. (AC 4, AC 5)
- [x] C4. `_speak(line_id, text)`: MUMBLE calls `speaker.call(&"say", text)` (empty text is never spoken, the docs say so), and sets `_active_id`/`_active_text`. `stop()`: calls `speaker.call(&"stop")` if speaking, clears `_active_id`, emits `duck_line_finished(id, false)` once. Track the active line so a late `finished` from a stopped line is ignored (the speaker is reused). (AC 5, AC 6)
- [x] C5. Use `call()` for every GDExtension method and property access in VoiceService (no static type annotation to `MumbleSpeaker`, `MumbleVoice` or `Mumble`), so the script parses when the addon is absent. Keep `Log.debug(&"voice", ...)` on each say and `Log.warn` only once per run (AC 7).
- [x] C6. Gate on the audio lock: while `AudioManager` is locked (before the title press), `say()` still emits the EventBus line (the text shows) but does not call `speak`; the bubble then uses the timer (no voice events come). Use the existing AudioManager unlock state, not a new flag. (Dev Notes "Audio lock")

### Group D: DuckBubble voice wiring

- [x] D1. `game/src/ui/duck/duck_bubble.gd`: connect `EventBus.duck_character_spoken` and `EventBus.duck_line_finished` in `_enter_tree` and disconnect in `_exit_tree` (3.6 pattern). The handler for `duck_character_spoken` sets `_reveal.set_revealed(char_index + 1)` only when the bubble is showing and the id matches the showing line; it sets `_voice_speaking = true`. (AC 4)
- [x] D2. `duck_line_finished(_, completed)`: if the bubble is showing, reveal the rest (`set_revealed(length)` when completed, or hand the timer back with `driven_externally = false` when cut), set `_voice_speaking = false`, and start the hold countdown from the full reveal. Ignore it when not showing (cleared bubble). (AC 5)
- [x] D3. Squeak then voice: on line start, `AudioManager.play_squeak()` runs first, a `_squeak_left_s` countdown of `SQUEAK_LEAD_S` (0.15 s) runs in `step(delta)`, and only then `VoiceService.speak_pending()` (a public method that calls `_speak` for the line on the bubble's current text, or nothing) runs. Text-only and PRERENDER lines use the same lead. (AC 6, D-S37-6)
- [x] D4. `step(delta)`: return while `SimClock.paused`, and on the first paused frame while `_voice_speaking` call `VoiceService.stop()` (D-S37-7). `clear()`: set `_showing = false` first, then `VoiceService.stop()`, so the stop-emitted `duck_line_finished` is ignored (AC 6). (AC 6)
- [x] D5. Keep the 3.6 public surface (`say` path, `wrap`, `TypewriterReveal` API, `MAX_PENDING`, hold constants, `line_cells`). Do not change `DuckDirector`. (AC 4 to 6)

### Group E: Voice data

- [x] E1. `game/data/duck/duck_voice.tres`: a `MumbleVoice` resource, `style = BEEP` (the high-pitch squeaky choice; the GDD allows BEEP or GRUNT, and the epic says "tuned in Epic 3"), `pitch` and `speed` set by ear in the editor and recorded in Completion Notes, `variation` at the addon default, `seed` fixed to one constant integer (D-S37-10). (AC 4, AC 10)
- [x] E2. Do not create the duck voice in code. Do not reference `MumbleVoice` from any data file other than `duck_voice.tres`. (AC 10)
- [x] E3. Credit line text for the README and the itch.io page: "Voice: mumble-speech by basteez (MIT/Apache-2.0)". (A4)

### Group F: Pre-render contingency

- [x] F1. `game/tools/render_duck_lines.gd` (`@tool` EditorScript, excluded from export by the existing `tools/*` filter): for each `DuckLineDef` in `data/duck/duck_lines.tres`, call `Mumble.render(text, voice, 48000)` with the `duck_voice.tres` resource, check for an `error` key, write `assets/audio/duck/<id>.wav` with `Mumble.encode_wav(samples, 48000)` and keep the events for the timings. (AC 8)
- [x] F2. `game/data/duck/duck_clips.tres`: a `DuckClipsDef` resource (typed `Resource` with `entries: Array[DuckClipDef]`, each `id`, `stream: AudioStreamWAV` preloaded, `char_times: PackedFloat32Array` derived from the render events). `DuckClipDef.validate()` follows the `DuckLineDef` pattern (no empty clip, `char_times` count equals the line length). (AC 8)
- [x] F3. PRERENDER playback in VoiceService: plays the clip on a `PrerenderPlayer` (`AudioStreamPlayer`, bus `Voice`), and drives the same `_on_character_spoken`-style events from a presentation `_process` that reads `get_playback_position()` against `char_times`. It emits the same EventBus signals as MUMBLE (so DuckBubble is unchanged). (AC 8)
- [x] F4. The Mumble event schema and `char_times` derivation are read from the 0.3.0 docs and the addon's own `.gd`/doc comments at implementation time. If the events are not per-character times, derive them as `duration * (i + 1) / length` and note the approximation. (Dev Notes "Unverified API details")

### Group G: Tests and guards

- [x] G1. `tests/unit/test_voice_service.gd` with a `FakeSpeaker` (a plain `Object` with `say`, `stop`, `is_speaking`, and a `_emit_char(i)` / `_emit_finished()` helper that calls the VoiceService callbacks, not the GDExtension): backend resolution (MUMBLE, PRERENDER and TEXT paths with a stubbed class check), `say` emits once, `stop` emits `duck_line_finished(id, false)` once, a late `finished` after `stop` is ignored, empty text is never spoken. (AC 4, AC 5, AC 7)
- [x] G2. `tests/unit/test_duck_bubble.gd` additions (pure where possible): `set_revealed` via `duck_character_spoken` sets the count to `i + 1`, the timer is off while `driven_externally`, `duck_line_finished(completed=false)` hands the timer back, hold starts only after the finished event, `clear()` before the finished event leaves no hold running, pause calls stop once. Use the 3.6 `step(delta)` entry, no frames. (AC 4, AC 5, AC 6)
- [x] G3. `tests/unit/test_duck_voice_data.gd`: `duck_voice.tres` and `duck_clips.tres` load (or the test is skipped with a logged reason when the addon is absent, so the suite stays green on a machine without the GDExtension), `DuckClipDef.validate()` is empty for every entry. (AC 10)
- [x] G4. Extend `tests/unit/test_duck_isolation.gd`: `MumbleSpeaker|MumbleVoice|Mumble\.|mumble_speech` appears only in the allowed files (`voice_service.gd`, `duck_voice.tres`, `duck_clips.tres`, `tools/`, the addon folder itself). Add `res://src/{input,register,player,combat,bosses,skills,arena}` to the rule for `duck_character_spoken|duck_line_finished` (none outside `src/ui/duck/` and `src/autoloads/`). Keep it textual (3.4 precedent). (AC 10)
- [x] G5. Run the full GUT suite headless (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), `bash game/tools/check_guards.sh`, the release export, `bash game/tools/smoke_web.sh` (plain boot and `?debug&smoke=voice`). Record all results. (AC 2, AC 10)

### Group H: Human checks (not gates for this story)

<!-- Left open on purpose: HUMAN items, recorded in deferred-work.md "Deferred from: dev of story-3.7". -->

- [ ] H1. Chrome, Firefox and Safari: the release build speaks T1 after a click; the reveal follows the voice; the squeak plays before the voice; no console errors. (epic AC; mumble-speech 0.3.0 notes: Firefox and Safari not verified upstream)
- [ ] H2. Check that `crossOriginIsolated` is not required (threads off) and that the audio starts after the first click on each browser.
- [ ] H3. Listen on desktop and web: pitch and speed of the duck voice (E1) and the squeak-to-voice lead (D3); adjust in the .tres and the const, record the values.
- [ ] H4. Pause (Esc) mid-line and resume: the voice stops at once and the text finishes silently (D4).
- [ ] H5. If the web build fell back to PRERENDER (D-S37-8/9), listen to one clip per line and confirm the timings look right.

## Dev Notes

### Decisions taken for this story (D-S37-n)

- **[design call] D-S37-1 Speech signals on EventBus.** `EventBus.duck_character_spoken(char_index: int)` and `EventBus.duck_line_finished(line_id: StringName, completed: bool)`. VoiceService declares no signal (project rule and the 3.6 D-S36-2 plan). The epic's `character_spoken` and `finished` names map to these two.
- **[design call] D-S37-2 Backend choice is one const.** `VoiceService.BACKEND := Backend.AUTO` resolves once at `_ready()`: MUMBLE if the class exists and the speaker instantiates, else PRERENDER if the clips load, else TEXT. Forcing a backend (for the size fallback or a bad web run) is a one-word change to the const, which is what "no other code changes" means in the epic.
- **[design call] D-S37-3 GDExtension access only through `call()` in VoiceService.** The addon's classes are never named statically outside `voice_service.gd`. If the wasm does not load, the class names are simply unknown at runtime and the script still parses. This keeps the 3.6 text path alive.
- **[design call] D-S37-4 Reveal follows the voice index.** `set_revealed(char_index + 1)`. The docs say indices are code point indices of Godot's `String`; line text is printable ASCII (validated in 3.6), so code point index equals the text index used by TypewriterReveal (the joined text with single spaces, D-S36-16). Verify on the first desktop run (G2 test uses a fake index).
- **[design call] D-S37-5 Hold waits for the voice's end, not a timer.** The hold countdown starts at `duck_line_finished`. A line the voice never finishes is cut by the watchdog: if no `duck_line_finished` arrives within `length / 30 + 3.0` s of the start (the 3.6 timing plus slack), VoiceService calls `stop()`. This closes the 3.6 deferred hang.
- **[design call] D-S37-6 Squeak first, then voice.** `SQUEAK_LEAD_S := 0.15` (presentation constant, D-S36-13). The squeak is the bubble-open cue; the voice starts after it. Not suppressed, because the squeak is the open cue the GDD names (D-046).
- **[design call] D-S37-7 Pause cuts speech; the text finishes silently.** A pause calls `VoiceService.stop()` once. The voice's clock is wall time in Sample mode, so resuming it mid-line would desync the reveal. The remaining text uses the 3.6 timer after resume. Judged by ear in H4.
- **[design call] D-S37-8 Web fallback decision is taken at the first web check.** If `mumble_godot.wasm` does not load in headless Chrome after B1, the web build uses PRERENDER (`BACKEND` forced to PRERENDER for the web export) and the addon's `*.wasm` is excluded by an export filter. Desktop keeps MUMBLE. Recorded in Completion Notes.
- **[design call] D-S37-9 Size gate.** Headroom to the 30 000 000 budget is about 1 552 738 bytes (28 447 262 baseline). If the release web build with the addon exceeds 30 000 000 bytes, the web export uses PRERENDER and excludes `addons/mumble_speech/**/*.wasm` (the addon stays on desktop). No waiver is requested, because the fallback meets the budget. If the pre-rendered clips also push the build over, they are compressed (WAV at 22 050 Hz mono) and the story notes the byte cost. Recorded in Completion Notes.
- **[design call] D-S37-10 Fixed voice seed.** `MumbleVoice.seed` is a constant in `duck_voice.tres`, so each line sounds the same on every play and across runs. The voice never uses `SimContext.rng` or any sim-visible randomness (D-S36-9, AD-05).
- **[design call] D-S37-11 Audio lock.** Before the title press the speaker is not called (AudioManager is locked and Sample mode would be silent anyway). The text shows with the timer. The line is not queued for later voice playback.
- **[design call] D-S37-12 Single warning.** One `Log.warn(&"voice", ...)` for the run on any voice failure (downgrade or runtime error). Per-line messages go to `Log.debug`.

### Architecture and rules that bind this story

- Simulation folders (`input`, `register`, `player`, `combat`, `bosses`, `skills`, `arena`) must not reference `ui`, `AudioManager`, `VoiceService`, the duck classes or the addon (architecture rule 1; the G4 guard). Voice is presentation only (AD-05).
- Third-party addons are accessed only through VoiceService (architecture rule 8; `gameplay never calls MumbleSpeaker directly`). The tools folder may use `Mumble.render` (EditorScript, not exported).
- Signals are declared only in `event_bus.gd`, past tense, typed args, no Dictionary payloads (AD-05). `await` and Tweens are allowed only in presentation (the squeak lead can be a `step(delta)` countdown instead, which keeps the 3.6 test style).
- No `Timer` nodes in gameplay. Presentation `_process` is allowed in `src/ui/duck/` and must read `SimClock.paused` only.
- Web: no audio before the first input; Sample playback mode; no `AudioEffects` on the Voice bus (project-context "Platform & Build Rules"). Browsers keep audio suspended until a user gesture (addon docs).
- Use the classes on the main thread only (addon docs).
- Preloading: assets are `preload()`ed; no runtime `load()` of clips except the one `duck_clips.tres` preload.

### Addon facts (mumble-speech 0.3.0, from the release notes and the Godot binding docs at mumble-speech.github.io/bindings/godot)

- Release asset: `mumble-speech-godot-0.3.0.zip` (3.9 MB, Windows x64, macOS universal, Linux x64, Web with or without threads). `SHA256SUMS.txt` is attached to the release.
- Web: `mumble_godot.wasm` (no threads, our export) and `mumble_godot.threads.wasm`. An export includes only one of them. Needs Godot 4.3+, Extensions Support on, Thread Support off (our preset already matches).
- Classes: `MumbleVoice` (Resource: `style` BEEP/GRUNT/ALPHABET, `pitch`, `speed`, `variation`, `seed`); `MumbleSpeaker` (Node: properties `voice`, `bus`, `volume_db`; methods `say(text)`, `speak_character(text) -> float`, `reset()`, `stop()`, `is_speaking()`, `render_stream(text) -> AudioStreamWAV`; signals `character_spoken(char_index)`, `finished`; synthesizes at 48 000 Hz); `MumbleTypewriter` (Node: `label`, `speaker`, `type_text`, `skip`, `is_typing`, `finished`). Not used here (the typewriter is ours, TypewriterReveal, so the 3.6 bubble stays the one reveal owner). `Mumble` (static: `render(text, voice, sample_rate)`, `encode_wav(samples, sample_rate)`).
- Web Sample mode: `character_spoken` and `finished` follow elapsed time since `say()` (up to 100 ms + one frame late for the character, up to 250 ms + one frame for finished). Stream mode: up to 500 ms + one frame late for characters. Our reveal therefore has a small lag on web; acceptable for a bubble.
- Empty lines are not played. Do not play an empty `render_stream` on the web.
- Known limits from the docs: Firefox and desktop Safari are checked by hand, not in CI; size increase of the dlink template is "TBD" upstream (measured here, B3).

### Unverified API details (check at implementation, do not guess)

- The exact payload of `Mumble.render`'s `events` array (per-character times or indices) and of the `character_spoken` index base. The docs say "code point indices". Read the addon's `.gd` wrapper and any doc comments in the zip at implementation time (A2 extract) and record the answer in Completion Notes.
- Whether `MumbleSpeaker` needs `add_child` before `say()` on web (it is a Node; assume yes and test in B2).
- Whether `stop()` emits `finished` (assume no; C4 emits `duck_line_finished(id, false)` itself). Test on desktop and record.

### Audio lock

- `AudioManager.unlock()` is called on the title press (1.4). Before that, `play_squeak()` and `play_sfx` warn once and do nothing. The voice follows the same rule: no speak call before unlock (D-S37-11).

### Size gate

- Baseline local export: 28 447 262 bytes (`deferred-work.md`, the 1.x series). Budget 30 000 000 bytes. Headroom about 1 552 738 bytes.
- Expected addon cost: the `mumble_godot.wasm` for web is unknown until A2 (the release zip is 3.9 MB for all platforms). Measure in B3, decide by D-S37-9.

### Project Structure Notes

- New: `game/addons/mumble_speech/` (vendored, from the zip, A1 to A2); `game/data/duck/duck_voice.tres` (MumbleVoice); `game/data/duck/duck_clips.tres` and `DuckClipDef` (pre-render, F2); `game/assets/audio/duck/*.wav` (pre-render, only if F is used); `game/tools/render_duck_lines.gd` (F1); `game/tests/unit/test_voice_service.gd`, `test_duck_voice_data.gd`.
- Changed: `game/src/autoloads/event_bus.gd` (two signals); `game/src/autoloads/voice_service.gd` (backend, speaker, stop, watchdog); `game/src/ui/duck/duck_bubble.gd` (voice wiring, squeak lead, pause, clear); `game/tests/unit/test_duck_bubble.gd`, `test_duck_isolation.gd`; `game/tools/smoke_web.sh` and the smoke scene (B2); `game/export_presets.cfg` (only the D-S37-8/9 export filter, if used); `README.md` (credit).
- Not changed: `DuckDirector`, `DuckLineDef`, `DuckLinesDef`, `data/duck/duck_lines.tres` (the lines and beats stay as 3.6 wrote them), any simulation folder, `build_web_template.sh` (unless B1 needs a module).

### Previous story intelligence (3.6, status done)

- `VoiceService.say(line) -> String` resolves an id or raw text, logs `Log.debug(&"voice", ...)`, emits `EventBus.duck_line_requested(line_id, text)` once, calls `_speak(line_id, text)` (no-op in 3.6), returns the text. `stop()` is a no-op. These are the 3.7 seams; keep the public names.
- `TypewriterReveal`: `set_line`, `advance`, `set_revealed(n)` (sets `driven_externally = true`; the timer stops), `is_done`, static `visible_chars`. `set_line` resets `driven_externally`.
- `DuckBubble`: connects in `_enter_tree`, disconnects in `_exit_tree`; `step(delta)` returns while `SimClock.paused`; `MAX_PENDING` 4; hold `2.0 + 0.05 × length`; `CHARS_PER_S` 30; squeak via `AudioManager.play_squeak()` on each line start; the bubble redraws when the reveal count is set externally.
- Deferred from the 3.6 review that this story closes: (1) no stop/finish path (hold starts only after `is_done()`), closed by D-S37-5 and D2; (2) `VoiceService.stop()` on `clear()`, closed by D4; (3) typewriter vs voice ownership (`driven_externally`), closed by D-S37-4 and D1; (4) squeak suppression while the voice speaks, closed by D-S37-6 (lead instead of suppression, so the open cue stays).
- Still deferred, not this story: `DuckDirector.poll()` is not gated on `SimClock.paused`; strict-order T3/T4 soft-lock; raw `say` text validation (no empty, ASCII or 12-column check); `>o` glyph hidden between lines. Keep them in `deferred-work.md`.

### Git intelligence

- Branch `story/3-7-duck-voice-mumble-speech` is stacked on Stories 3.1 to 3.6 (HEAD `8d4272d`). Story 3.6 (`baseline_commit f025f9b`) was the last duck change; its files are the ones listed under Project Structure Notes.

### Testing standards

- GUT, headless. Pure logic in `tests/unit/`; no frames; no `await`; `Timer`s not used. Tests may use `FakeSpeaker`; the real addon is exercised only by the smoke scene and the human checks.
- The suite must stay green on a machine without the GDExtension (G3 skip path).
- Replay and determinism tests pass unedited (D-S36-9).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.7: Duck Voice (mumble-speech)]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3 AC9 (I-6, moved to 3.7)]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements, Duck Voice and Web export preset]
- [Source: _bmad-output/game-architecture.md#AD-05, AD-09, AD-14, ADR-05, I-6, Project Structure (src/ui/duck, data/duck, tools), rules 1 and 8]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md#Duck (hint system), Format (D-046)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/decision-log.md#D-039, D-046, D-047]
- [Source: _bmad-output/implementation-artifacts/3-6-duck-bubble-and-tutorial-beats.md#Acceptance Criteria, Group C, D-S36-2, D-S36-6, D-S36-7, D-S36-9, D-S36-11, D-S36-16, Review notes]
- [Source: _bmad-output/implementation-artifacts/1-3-web-export-and-itch-io-draft-deploy.md#AC9, DC4, DC7, Task 3]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred: itch.io deploy & browser smoke; mumble-speech web support: UNBLOCKED; Deferred from code review of story-3.6]
- [Source: _bmad-output/project-context.md#Technology Stack, Platform & Build Rules, Critical Don't-Miss Rules]
- [Source: https://github.com/basteez/mumble-speech/releases/tag/v0.3.0 (assets, SHA-256 list, known issues)]
- [Source: https://mumble-speech.github.io/bindings/godot (classes, web requirements, limitations)]

## Human checks

- H1 to H5 in Group H. These are not gates for `done`, but they must be recorded before the build goes to itch.io, the same way 1.3 and 1.7 record theirs in `deferred-work.md`.

## Dev Agent Record

### Agent Model Used

claude opus (Claude Opus 5.5, `claude-opus-5-5`), unattended epic pipeline, dev phase.

### Debug Log References

- Release download: `gh release download v0.3.0 -R basteez/mumble-speech` into an empty scratch dir; `shasum -a 256 -c SHA256SUMS.txt` gives `mumble-speech-godot-0.3.0.zip: OK` (SHA-256 `2adb6b5d9a399a20660c6b24bd810ea51b8b9b433317da02ed31394441e09f18`, equal to the pinned value).
- API probe (desktop, Godot 4.7.2, real addon) and a VoiceService end-to-end probe (`speak_pending` + `stop` on the autoload): see "Open API questions" below.
- GUT (desktop, addon loaded): 69 scripts, 898/898 passing, 32 198 asserts. GUT with the addon NOT loaded (`.godot/extension_list.cfg` moved aside): 896 passing + 2 pending (the two addon-only checks skip), 0 failing; AUTO falls back to PRERENDER with one `Log.warn`.
- `bash game/tools/check_guards.sh`: OK.
- Release web export with the local stripped template (`custom_template/release` set only for the export, then restored; not committed): no script or export errors.
- `bash game/tools/smoke_web.sh` (plain boot): PASS. `SMOKE_QUERY='?debug&smoke=voice' SMOKE_CLICK=1 SMOKE_EXPECT='voice smoke: finished'`: PASS (log: `backend MUMBLE`, `voice smoke: speak started on MUMBLE`, `spoke 1 chars`, `finished t1_shift completed=true`).
- `SMOKE_QUERY="?debug" SMOKE_KEYS="F2 Escape Escape" SMOKE_EXPECT="pause off"` (1.7 regression run): FAIL on a `console.error` from `[audio] play ignored before unlock`. Not from this story: the F2 jump enters FIGHT before the audio unlock, and the 3.6 squeak / shift click warns. Logged in deferred-work.md.

### Completion Notes List

**Pin (AC 1, A1-A5).** mumble-speech Godot addon `0.3.0`, release `v0.3.0`, source tag `godot/v0.3.0` (the tag exists upstream). Zip SHA-256 `2adb6b5d9a399a20660c6b24bd810ea51b8b9b433317da02ed31394441e09f18`, checked against `SHA256SUMS.txt` (OK). Only `addons/mumble_speech/` was extracted into `game/addons/mumble_speech/`; `diff -r` against the zip contents is empty. The whole folder is kept as one unit (desktop libraries included, so the desktop build and CI on Linux load the addon); the web export copies only `mumble_godot.wasm`. The one extra file is `mumble_speech.gdextension.uid`, the sidecar Godot 4.7 writes on import (committed like the other `.uid` files). README credit added ("Voice: mumble-speech by basteez (MIT/Apache-2.0)"); the itch.io page text is Epic 7's. `project-context.md` "Technology Stack" still reads correctly (v0.3.0, access only through VoiceService); not edited.

Web files of the addon: `bin/mumble_godot.wasm` 521 676 bytes (the export's), `bin/mumble_godot.threads.wasm` 525 440 bytes (never exported: Thread Support off). `.gdextension` has `web.debug.wasm32` / `web.release.wasm32` -> `mumble_godot.wasm` and `web.*.threads.wasm32` -> the threads build; the exported `index.html` lists `"gdextensionLibs":["mumble_godot.wasm"]`, and `smoke_web.sh` now fails if a threads library is listed.

**Web (AC 2, B1-B2).** Side module loads: **yes**. The stripped dlink template from `build_web_template.sh` (Godot 4.7.2, no module re-enabled, script unchanged) boots, prints `Initialize godot-rust`, `MumbleSpeaker` instantiates (`backend MUMBLE`) and T1 is spoken to the end in headless Chrome. `mumble_godot.wasm` is served `HTTP/1.0 200 OK`, `application/wasm` (new check in `smoke_web.sh` for every `gdextensionLibs` entry). No `ERROR` console line, no wasm load error.

**Size (AC 3, B3-B4).** Release export, addon + stripped template:

| File | Bytes |
|---|---|
| index.side.wasm | 25 414 775 |
| index.wasm | 1 600 314 |
| index.js | 1 314 483 |
| index.pck | 555 060 |
| mumble_godot.wasm | 521 676 |
| index.png | 21 443 |
| index.apple-touch-icon.png | 11 944 |
| index.audio.worklet.js | 7 298 |
| index.icon.png | 5 700 |
| index.html | 5 468 |
| index.audio.position.worklet.js | 2 973 |
| **Total** | **29 461 134** |

Baseline 28 447 262 -> 29 461 134: delta **+1 013 872** bytes (the wasm 521 676, the pck grows by the clips ~276 KB QOA and the 3.x code). Budget 30 000 000: headroom 538 866. **D-S37-9 decision: under budget, the web build keeps MUMBLE, no wasm exclusion, no waiver.** (Before the clips and the new code, addon only: 29 167 798.)

**Open API questions, answered by running the addon (F4, Dev Notes "Unverified API details").**
- `character_spoken(char_index)`: 0-based code point index into the `say()` text, emitted **for letters only** (spaces and punctuation have no event): "Hi, ab c!" gives 0, 1, 4, 5, 7. So `set_revealed(char_index + 1)` (D-S37-4) holds; trailing punctuation shows at `finished`.
- `Mumble.render(text, voice, rate)` returns `{samples: PackedFloat32Array, duration: float, events: Array}`; each event is `{char_index, char_count, start, duration, style, variant}` (start/duration in seconds), letters only. No `error` key on an empty text (duration 0, no events). `Mumble.encode_wav(samples, rate)` returns the WAV bytes.
- `MumbleSpeaker` must be in the scene tree before `say()` (outside the tree: "Playback can only happen when a node is inside the scene tree" and every event fires at once). VoiceService adds it as its child.
- `stop()` does **not** emit `finished`, and no `character_spoken` follows it; VoiceService emits `duck_line_finished(id, false)` itself (once).
- `say()` while speaking replaces the line without a `finished` for the first one (VoiceService stops the old line first, so it gets its `finished(false)`).
- `say("")` emits `finished` with no characters; VoiceService never calls it with empty text.
- `MumbleVoice` defaults: style BEEP (0), pitch 0.0 (-12..12), speed 15.0 (5..30), variation 0.0, seed 0.

**Voice (AC 4-7, C1-C6, D1-D5).** Two EventBus signals (D-S37-1). VoiceService: `BACKEND := Backend.AUTO`, resolved once in `_ready()` (pure `resolve_backend`), one `MumbleSpeaker` child on `Voice` with `duck_voice.tres`, all addon access through `ClassDB` / `call()` / `set()`. `say()` no longer starts the voice: DuckBubble calls the new `speak_pending(id, text)` after the squeak lead (D3), so a queued line never cuts the one speaking. `stop()` emits `finished(id, false)` once; late speaker events after a stop are ignored; the watchdog cuts a line that never ends. Audio lock: `can_speak()` is false before `AudioManager.unlock()` (the text shows on the 3.6 timer). One `Log.warn` per run for a downgrade or a runtime failure. DuckBubble: voiced lines freeze the reveal during the 0.15 s lead, the voice drives it, the hold starts at `duck_line_finished`; a cut line goes back to the timer from where the voice left it (`TypewriterReveal.release()`, a new method); `clear()` hides first, then stops; a pause stops once and the text finishes silently after resume. `DuckDirector` unchanged.

**Voice data (E1-E3).** `duck_voice.tres`: BEEP, pitch 6.0, speed 20.0, variation 0.0 (addon default), seed 20261101. Pitch and speed were set without listening (unattended run); tuning by ear is H3.

**Pre-render (AC 8, F1-F4).** `tools/render_duck_lines.gd` (run headless, two passes with an import between, D-S37-14) rendered the four lines at 48 000 Hz into `assets/audio/duck/<id>.wav` (4.575 s, 3.625 s, 2.425 s, 3.425 s; imported QOA, ~276 KB total) and wrote `duck_clips.tres` (`DuckClipsDef` / `DuckClipDef`). `char_times` are exact, from the render events (not the `duration * (i + 1) / length` approximation): a character shows when the first spoken letter at or after it starts, the same as the live backend. PRERENDER drives the events from wall time since play (not `get_playback_position()`, which Sample mode on web does not report reliably), on a `PrerenderPlayer` on `Voice`. Not used on the web build (MUMBLE works); forcing it is the one-word `BACKEND` change.

**Presentation only (AC 10, G4).** Replays and determinism tests pass unedited. The isolation test now also checks that `MumbleSpeaker|MumbleVoice|MumbleTypewriter|Mumble.|mumble_speech` appears in `src/` and `data/` only in `voice_service.gd`, `duck_voice.tres` and `duck_clips.tres` (`duck_clips.tres` actually has none), and that the voice signals appear only in `src/ui/duck/`, `src/autoloads/` and the voice smoke scene (the smoke must listen to them, B2). The sim-folder rule gains `duck_character_spoken` and `DuckClip(s)Def`.

**Firefox / Safari (AC 9).** Not claimed; only headless Chrome was run. H1-H5 are open and recorded in deferred-work.md.

**Design calls made during dev:**
- [design call] D-S37-13 Watchdog uses the voice's own speed: `length / MumbleVoice.speed + 3.0 s` (falls back to 30 chars/s), not the story's `length / 30 + 3.0`. At the addon's speeds (5 to 30 chars/s) the 30 chars/s formula would cut normal lines (T1 at 20 chars/s takes 4.6 s; at 15 chars/s it would be within 0.1 s of the 30 chars/s watchdog).
- [design call] D-S37-14 The render tool is a `SceneTree` script run with `godot --headless -s` (two passes, `--import` in between) instead of an `@tool EditorScript`, so it is reproducible from the command line. It prints directly (tools code, outside `src/`, no autoloads in `-s` scripts) and joins words with single spaces instead of calling `DuckBubble.wrap` (same text, D-S36-16).
- [design call] D-S37-15 `say()` only emits; the voice starts from `VoiceService.speak_pending(id, text)` called by DuckBubble after the squeak lead (the 3.6 `_speak` call in `say()` moved there), so lines queued in the bubble never cut the line being spoken. `speak_pending` returns whether the voice started; on false the bubble keeps its timer.
- [design call] D-S37-16 A voiced line shows nothing during the squeak lead (the reveal is held at 0 so the voice index never moves it backwards); unvoiced lines (TEXT, audio locked) keep the exact 3.6 timing from the first frame, so the 3.6 tests stand unchanged.
- [design call] D-S37-17 The hold countdown does not run while the voice speaks, even when the letters already revealed the whole line (D-S37-5 strictly: the hold starts at `duck_line_finished`).
- [design call] D-S37-18 The pre-rendered clips stay in the web build as the AUTO fallback (~276 KB) although MUMBLE works there; excluding them is deferred to a size squeeze.
- [design call] D-S37-19 `test_data_validation.gd` skips `duck_voice.tres` when the `MumbleVoice` class is not loaded, so the suite stays green without the GDExtension (G3).

### File List

New:
- game/addons/mumble_speech/ (vendored: LICENSE-MIT, LICENSE-APACHE, README.md, mumble_speech.gdextension, mumble_speech.gdextension.uid, bin/mumble_godot.wasm, bin/mumble_godot.threads.wasm, bin/mumble_godot.dll, bin/libmumble_godot.so, bin/libmumble_godot.dylib)
- game/assets/audio/duck/t1_shift.wav (+ .import)
- game/assets/audio/duck/t2_semicolon.wav (+ .import)
- game/assets/audio/duck/t3_dash_strike.wav (+ .import)
- game/assets/audio/duck/t4_phase_two.wav (+ .import)
- game/data/duck/duck_voice.tres
- game/data/duck/duck_clips.tres
- game/src/ui/duck/duck_clip_def.gd (+ .uid)
- game/src/ui/duck/duck_clips_def.gd (+ .uid)
- game/src/debug/smoke_voice/smoke_voice.gd (+ .uid)
- game/src/debug/smoke_voice/smoke_voice.tscn
- game/tools/render_duck_lines.gd (+ .uid)
- game/tests/unit/test_duck_voice_data.gd (+ .uid)
- game/tests/unit/test_smoke_voice.gd (+ .uid)

Modified:
- game/src/autoloads/event_bus.gd
- game/src/autoloads/voice_service.gd
- game/src/ui/duck/duck_bubble.gd
- game/src/ui/duck/typewriter_reveal.gd
- game/src/main/main.gd
- game/tools/smoke_web.sh
- game/tests/unit/test_voice_service.gd
- game/tests/unit/test_duck_bubble.gd
- game/tests/unit/test_duck_isolation.gd
- game/tests/unit/test_data_validation.gd
- README.md
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/3-7-duck-voice-mumble-speech.md

Not changed: game/export_presets.cfg (no D-S37-8/9 filter needed), game/tools/build_web_template.sh, DuckDirector, DuckLineDef, DuckLinesDef, duck_lines.tres, any simulation folder.

### Change Log

- 2026-11-09: Story 3.7 implemented (claude opus): mumble-speech 0.3.0 vendored and verified; VoiceService MUMBLE / PRERENDER / TEXT backends behind one const; duck voice signals on EventBus; DuckBubble voice wiring (squeak lead, voice-driven reveal, hold at finish, stop on clear and pause); pre-render tool and clips; voice smoke scene and smoke_web side-module check; web build 29 461 134 bytes, side module loads in headless Chrome. Status -> review.


### Review Notes (gds-code-review, 2026-11-09)

Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (parallel). Acceptance audit: all ACs met, no undone tasks.
CI compatibility: the addon ships `libmumble_godot.so` (linux x86_64), so CI's `--import` registers the extension and the MumbleSpeaker path runs on CI; the only `pending()` branches (addon missing, AudioManager already unlocked) did not trigger in a full local run (898/898, 0 pending, which matters because CI fails on pending). Binaries total about 14 MB, none gitignored (`*.zip` is ignored but the addon ships no zip). `.godot/` is gitignored and was regenerated by `--import`; nothing tracked is affected. The sim never references voice code (isolation tests, no sim listener of the voice signals).
Patched: (1) DuckBubble set `_voice_speaking` after `speak_pending` returned, so a voice finishing synchronously (no letters) left the bubble waiting forever; (2) VoiceService.step null-deref if a listener calls stop() during an emit (PRERENDER); (3) character events could shrink the reveal (now `maxi`); (4) `say("")` requested an empty bubble.
Deferred (deferred-work.md): per-line token for stale events after stop(); prerender timing from playback position; shorter watchdog when `say` yields nothing; `use_speaker` re-entry cleanup; CLIPS preload when MUMBLE; test fake has no signals; dead `_voice_line` var.
Dismissed: smoke_voice cosmetic items, unrecorded minor spec deviations (char handler has no id in the signal).
