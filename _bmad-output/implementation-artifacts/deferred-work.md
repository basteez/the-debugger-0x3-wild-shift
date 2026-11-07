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
