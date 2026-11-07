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
