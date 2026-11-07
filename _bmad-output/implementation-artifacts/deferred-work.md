# Deferred: itch.io deploy & browser smoke (decided 2026-11-07 by Tiziano)

Tiziano decided on 2026-11-07 that everything involving the itch.io page, the first deploy and real-browser checks is done LATER. Each item is tagged with its source story. Nothing here is done yet.

**Epic 1 Definition of Done is BLOCKED on this section.** The DoD requires a release web build deployed with `butler` to the itch.io draft page and a Chrome/Firefox smoke test. Epic 1 stays `in-progress` in `sprint-status.yaml` until the checklist below is cleared.

**Open question (needs Tiziano):** the submission deadline differs between files. `README.md` says 2026-12-01 13:37 PST; `epics.md` (NFR16, Epic 7) and the `sprint-status.yaml` header say 2026-11-29 12:00 PST. Confirm the right date, then fix whichever file is wrong.

## Checklist

### itch.io setup and first deploy (HUMAN)
- [ ] [1.3 H1] Create the itch.io draft page (HTML, played in browser, 1280x720 viewport, fullscreen button on, SharedArrayBuffer off, Draft/Restricted).
- [ ] [1.3 H2] Add the `BUTLER_API_KEY` secret and the `ITCH_TARGET` variable (`<user>/<slug>`) in the repo settings.
- [ ] [1.3 H3] First manual deploy: Actions, CI, Run workflow on `main` (or `butler push` by hand). Check the `butler version` and `butler push --help` output in the log (butler pin 15.32.0, flags and sha256 are verified only here). Decide the 48.5 MB stock-template size waiver first (CI still exports with the stock template).
- [ ] [1.3 H4] Chrome, Firefox and Safari smoke: glyph boots with no console errors; `?debug&smoke=audio` (click, then L/R audible, or "fails" and the hum falls back to `playback_type = Stream`); size shown on itch.io and transfer size in DevTools; embed viewport and fullscreen behaviour.

### Browser checks on the deployed build (HUMAN)
- [ ] [1.4 H1] Audio unlock per browser (Chrome, Firefox, Safari): silent until first key or click, test blip audible after the first click and not before; note the result per browser. Also verify the AudioContext state (1.4 review deferral).
- [ ] [1.4 H3] NFR3: title reaches a playable state in 10 s or less on a throttled 50 Mbps connection, cold cache.
- [ ] [1.3 / 1.6 H2] Get the `?debug` iframe URL (`https://html.itch.zone/html/<id>/index.html` from the game iframe `src`) and open it directly with `?debug` appended; the itch.io page query never reaches the iframe.
- [ ] [1.6 H2] On that URL in Chrome and Firefox: F1-F5 jump between screens, and F5 does not reload the page. Release URL (no `debug`): F1-F5 do nothing. Also note F1/F11/F12 browser defaults and Firefox/Safari F-key behaviour.
- [ ] [1.7 H2] On the direct `?debug` URL in Chrome and Firefox: Esc pauses and resumes in INTRO and FIGHT; M mutes; pause on tab switch and on window blur to another app (headless Chrome could not emulate blur); Esc in browser fullscreen (the browser eats the first Esc, a second is needed; record observed behaviour).
- [ ] [1.7 H3] Release build (no `debug`): Esc and M on the title.
- [ ] [1.6 H3 / 1.7] Record the release web build size as shown on itch.io (local export: 28,447,262 bytes, budget 30,000,000).
- [ ] [1.5 H1] Real-browser visual check of `?debug&smoke=arena` (Chrome and Firefox): arena layout, HUD grid alignment, F9 overlay. (Not itch-specific; listed here because it needs the deployed or hosted build.)

### Not itch-related, still open for Tiziano
- [ ] [1.5 H2] Confirm the CC0 licence of the self-authored pixel font.

## mumble-speech web support: UNBLOCKED by v0.3.0 (2026-11-07)

Story 1.3 AC9 / I-6 ("mumble-speech web check, moved to 3.7") is UNBLOCKED. Tiziano released mumble-speech v0.3.0 on 2026-11-07, which closes basteez/mumble-speech#32. The Godot addon zip (`mumble-speech-godot-0.3.0.zip`, 3.9 MB) now ships `mumble_godot.wasm`. It works for Godot 4.3+ web exports with Extensions Support ON and Thread Support OFF (our preset), and there is also a threads build. Known issue: Firefox and Safari are not yet verified by hand. Do NOT vendor the addon now; that is Story 3.7's job. Checks for Story 3.7:
- [ ] [3.7 / 1.3 I-6] Vendor `addons/mumble_speech` from the v0.3.0 zip and verify it against `SHA256SUMS.txt`.
- [ ] [3.7 / 1.3 I-6] Confirm the stripped web template (`game/tools/build_web_template.sh`) still loads GDExtension side modules; CI uses the dlink/extensions template.
- [ ] [3.7 / 1.3 I-6] Re-measure the web export against the 30,000,000-byte budget (currently about 28.45 MB, so the addon's wasm must fit).
- [ ] [3.7 / 1.3 I-6] Smoke-test the duck voice in Chrome, Firefox and Safari.

---

## Deferred from: code review of story-1.1 (2026-11-06)

- Log.error prints and also calls push_error (double line in editor); intentional per DC6.
- No committed tests for Story 1.1 checks; port the throwaway verification into GUT in Story 1.2.

## Deferred from: code review of story-1.2 (2026-11-06)

- Guard: no `delta` check in sim folders; silently skips missing SIM_DIRS (make strict once all exist).
- Log tests do not cover wiring of `debug()`/`info()` to the helpers.
- Default-valued project settings in test_project_settings cannot fail if the key is deleted.
- Explicit VRAM keys in export_presets.cfg (Story 1.3 owns).
- CI: actions pinned by tag, checksums from same release, failure-marker greps over whole logs, narrow export error regex, cache key not tied to install script, no `.gutconfig.json`, no log/build artifact upload.
- GUT 9.6.1 vendored; 9.7.1 available.

## Deferred from: code review of story-1.3 (2026-11-07)

- Stripped template disables svg, noise, mbedtls, websocket, zip, text_server_adv; re-enable in `game/tools/build_web_template.sh` when a story needs them.
- Audio smoke `?debug&smoke=audio` is unreachable through the itch.io iframe unless the iframe URL is opened directly.
- smoke_web.sh Chrome launch robustness (root `--no-sandbox`, partial DevToolsActivePort), Node 22+ requirement.
- butler install layout, flags and pinned sha256 verified only at the first real deploy (H3).
- Actions pinned by tag rather than SHA.

## Deferred from: code review of story-1.4 (2026-11-07)

- AudioManager.unlock() only sets a flag; no AudioContext verification or re-lock after focus loss (check in H1).
- ScreenTouch not handled; relies on emulated mouse.
- TitleScreen.label_rects canvas vs viewport coordinates once options become visible (7.x).
- Modified option keys (Shift+N) resolve to START due to exact_match; decide in 7.x.
- Game.first_input_frame not reset on re-entering TITLE; start_run_from_title returns nothing.
- Tests: bus_count == 4 exact assertion and AudioManager._unlocked cleanup are order-fragile.
- Single SFX player restarts on rapid play_test_sfx; do not copy into pooled SFX (7.2).
- default_bus_layout.tres has no explicit Master; flow_state_changed uses int instead of the enum.

## Deferred from: code review of story-1.5 (2026-11-07)

- Arena is a Node2D while the HUD is a CanvasLayer: a future Camera2D or screen shake desyncs them (Epic 7).
- Glyph atlas has no padding; relies on nearest filter and integer stretch.
- F9 on the title screen counts as "press any key" (pre-existing 1.4 behaviour).
- Brittle source-regex tests, hand-written FRAME_GLYPHS, advisory colour guard, unused Hud.box_rows mid row, redundant _web_location_search wrapper, duplicated HUD_LAYER, per-glyph draw_string in Arena._draw, BMFont channel flags.
- Font is self-authored (DC1 fallback); H2 CC0 confirmation by Tiziano still open.

## Deferred from: code review of story-1.6 (2026-11-07)

- `Game.advance()` in INTRO ignores `can_skip_intro` (spec Task 2.2 mandates it); revisit with the real Intro (Epic 5).
- Old and new screen can share a node name within a frame (`remove_child` breaks `TitleScreen`'s `get_viewport()` call); nothing looks screens up by path.
- Duplicate flow log lines per transition (specific line plus `_set_flow_state` line).
- Tests mutate shared autoloads and the global EventBus; each restores what it changes, but order dependence is possible.
- `?debug` is not visible inside the itch.io iframe (DC2, direct-URL route documented, human step).
- DebugKeys present on the `?debug&smoke=audio` page without a flow listener.
- `PlaceholderScreen.is_advance`/`TitleScreen.classify` use `keycode` only (web events with keycode 0).
- F1/F11/F12 browser defaults and Firefox/Safari F-key behaviour not smoke-covered (headless Chrome F1-F5 `defaultPrevented` true).

## Deferred from: code review of story-1.7 (2026-11-07)

- Debug keys F1-F5 while paused clear the pause (DC5); intended for a debug tool.
- Only SimClock.paused is paused: tweens, timers, AnimationPlayers and particles keep running; gameplay must read SimClock.paused.
- Held gameplay actions are not released on pause; handle with the player controller (Epic 2).
- Esc priority: Game._input runs after later nodes' _input (reverse tree order) and ui_cancel shares Esc; correct spec DC2/DC15 wording and add a modal-open rule when a menu appears in FIGHT.
- smoke_web tab switch only logs the hidden state; add an assertion if flaky.
- Esc in browser fullscreen is eaten by the browser (second Esc needed).
- window.blur also fires for iframe/devtools/alert focus moves (spurious pause, acceptable).
- Doc nits: mute label direction wording in completion notes; DC9 text lacks the WM_WINDOW_FOCUS_OUT addition.

## Deferred from: code review of story-2-1 (2026-11-07)

- InputBuffer grows while the world is frozen (hit-stop/Breakpoint keep sim_frame fixed, so nothing expires); bounded by key presses, fine until a long Breakpoint with key mashing. Revisit with 4.3.
- A recording started before FIGHT entry (or mid-fight) does not hold the RNG state reached; exact replay needs F11 right at fight start (already a known limitation in the story notes). Revisit with 2.2+.
- LiveInput `is_action_just_pressed` at display rates above 60 Hz is unverified headlessly (human check H3, fallback: `_unhandled_input` queue).
- Recording `seed` is stored as a JSON number: exact up to 2^53, ample for `get_ticks_usec`.

## Deferred from: code review of story-2.2 (2026-11-07)

- [design call] F11 recording started mid-fight does not capture player position/velocity/facing (same limitation as RNG state); exact replay needs F11 right at fight start. Revisit if replays become a shipped feature.
- Float determinism of Vector2 `move_toward`/`normalized` across native vs wasm is unverified; replays are same-binary only. Quantise to fixed point if cross-platform replays are needed.
- ReplayInput does not validate `moves` length against `frames` and has no version gate: truncated moves or v1 files play with silent zero movement.
- Duck position jumps on a 180-degree facing flip and presentation has no interpolation (cosmetic); judge in human check H1.
