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
