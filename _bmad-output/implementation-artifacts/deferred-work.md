# Deferred: itch.io deploy & browser smoke (decided 2026-11-07 by Tiziano)

Tiziano decided on 2026-11-07 that everything involving the itch.io page, the first deploy and real-browser checks is done LATER. Each item is tagged with its source story.

**Status 2026-11-10:** itch.io page, secrets and the first deploys are DONE, and the Chrome (macOS) smoke is done (see "Results 2026-11-10" below). Firefox and Safari are still pending for every browser item, so Epic 1 stays `in-progress`.

**Epic 1 Definition of Done is BLOCKED on this section.** The DoD requires a release web build deployed with `butler` to the itch.io draft page and a Chrome/Firefox smoke test. Epic 1 stays `in-progress` in `sprint-status.yaml` until the checklist below is cleared.

**Open question (needs Tiziano):** the submission deadline differs between files. `README.md` says 2026-12-01 13:37 PST; `epics.md` (NFR16, Epic 7) and the `sprint-status.yaml` header say 2026-11-29 12:00 PST. Confirm the right date, then fix whichever file is wrong.

## Checklist

### itch.io setup and first deploy (HUMAN)
- [x] [1.3 H1] Create the itch.io draft page (HTML, played in browser, 1280x720 viewport, fullscreen button on, SharedArrayBuffer off, Draft/Restricted). (Done 2026-11-10: https://basteez.itch.io/wild-shift, draft.)
- [x] [1.3 H2] Add the `BUTLER_API_KEY` secret and the `ITCH_TARGET` variable (`<user>/<slug>`) in the repo settings. (Done 2026-11-10: `BUTLER_API_KEY` secret set, `ITCH_TARGET=basteez/wild-shift`.)
- [x] [1.3 H3] First manual deploy: Actions, CI, Run workflow on `main` (or `butler push` by hand). Check the `butler version` and `butler push --help` output in the log (butler pin 15.32.0, flags and sha256 are verified only here). Decide the 48.5 MB stock-template size waiver first (CI still exports with the stock template). (Done 2026-11-10: manual run on `main` succeeded, butler 15.32.0, channel `html5`. Run 42786062282 = Epic 2 build, 27.24 MiB; run 42787839468 = Epic 3 build, 28.17 MiB; latest run 42841220490 after fixes #29/#30, 28.17 MiB.)
- [ ] [1.3 H4] Chrome, Firefox and Safari smoke: glyph boots with no console errors; `?debug&smoke=audio` (click, then L/R audible, or "fails" and the hum falls back to `playback_type = Stream`); size shown on itch.io and transfer size in DevTools; embed viewport and fullscreen behaviour. (Chrome ✅ 2026-11-10; Firefox/Safari pending. Chrome: boots fine, only itch noise in the console (Permissions-Policy browsing-topics, html-callback blocked by ad-blocker) plus benign "AudioContext was not allowed to start" warnings before the first gesture. `?debug&smoke=audio` result was not recorded. Fullscreen bug found and fixed, see "Results 2026-11-10".)

### Browser checks on the deployed build (HUMAN)
- [ ] [1.4 H1] Audio unlock per browser (Chrome, Firefox, Safari): silent until first key or click, test blip audible after the first click and not before; note the result per browser. Also verify the AudioContext state (1.4 review deferral). (Chrome ✅ 2026-11-10: silent until first input, then unlocks; Firefox/Safari pending.)
- [x] [1.4 H3] NFR3: title reaches a playable state in 10 s or less on a throttled 50 Mbps connection, cold cache. (Chrome 2026-11-10: title opens fast; Network with cache disabled on the direct iframe URL shows 12.3 MB transferred / 32.9 MB resources (itch compresses), about 2 s at 50 Mbps, well within 10 s. Not re-measured on Firefox/Safari.)
- [x] [1.3 / 1.6 H2] Get the `?debug` iframe URL (`https://html.itch.zone/html/<id>/index.html` from the game iframe `src`) and open it directly with `?debug` appended; the itch.io page query never reaches the iframe. (Done 2026-11-10: confirmed, `?debug` on the itch page does not reach the iframe; `https://html.itch.zone/html/<id>/index.html?debug` works.)
- [ ] [1.6 H2] On that URL in Chrome and Firefox: F1-F5 jump between screens, and F5 does not reload the page. Release URL (no `debug`): F1-F5 do nothing. Also note F1/F11/F12 browser defaults and Firefox/Safari F-key behaviour. (Chrome ✅ 2026-11-10; Firefox/Safari pending. Chrome macOS: F1-F5 work on the direct `?debug` URL (needs fn+F-key), F5 does not reload the page, on the release URL the F-keys do nothing.)
- [ ] [1.7 H2] On the direct `?debug` URL in Chrome and Firefox: Esc pauses and resumes in INTRO and FIGHT; M mutes; pause on tab switch and on window blur to another app (headless Chrome could not emulate blur); Esc in browser fullscreen (the browser eats the first Esc, a second is needed; record observed behaviour). (Not covered by the Chrome smoke except the fullscreen Esc case: Esc in itch fullscreen exits fullscreen and auto-pauses; the resume left keyboard focus on the itch parent page, fixed by PRs #29 and #30, verified in Chrome after the #30 deploy. Firefox fullscreen behaviour pending. Rest of H2 still open.)
- [ ] [1.7 H3] Release build (no `debug`): Esc and M on the title.
- [x] [1.6 H3 / 1.7] Record the release web build size as shown on itch.io (local export: 28,447,262 bytes, budget 30,000,000). (Done 2026-11-10: Epic 3 build deployed at 28.17 MiB, about 29.54 MB, under the 30,000,000-byte budget; Epic 2 build was 27.24 MiB.)
- [ ] [1.5 H1] Real-browser visual check of `?debug&smoke=arena` (Chrome and Firefox): arena layout, HUD grid alignment, F9 overlay. (Not itch-specific; listed here because it needs the deployed or hosted build.)

### Not itch-related, still open for Tiziano
- [ ] [1.5 H2] Confirm the CC0 licence of the self-authored pixel font.

## Results 2026-11-10: first itch.io deploy and Chrome smoke (Tiziano, macOS Chrome)

- Deploy pipeline works: Actions, CI, Run workflow on `main` pushes to `basteez/wild-shift` channel `html5` (butler 15.32.0). Runs: 42786062282 (Epic 2, 27.24 MiB), 42787839468 (Epic 3, 28.17 MiB, about 29.54 MB, under the 30,000,000-byte budget), 42841220490 (after fixes #29/#30, 28.17 MiB).
- Debug URL: use the direct iframe URL `https://html.itch.zone/html/<id>/index.html?debug`; debug F-keys need fn on macOS, and on the release URL they do nothing.
- Chrome real game flow OK: title, intro, Fight 1 with the Infinite Loop, attacks, damage, death/retry and the duck beats. Boss debug keys F6, Shift+F6, F8 work.
- Bug found and fixed: Esc in itch fullscreen exits fullscreen and auto-pauses; resuming left keyboard focus on the itch parent page. PR #29 (P or click resumes) and PR #30 (click refocuses the iframe via `window.focus()`); verified in Chrome after the #30 deploy.
- Still NOT verified: Firefox and Safari (all items), Ctrl+F6 on macOS, Firefox fullscreen behaviour. Duck voice tuning by ear is acceptable for now.
- Open (unchanged): submission deadline mismatch between `README.md` and `epics.md`.

## Decision 2026-11-10: web build budget raised to 32 MB (NFR4)

- Tiziano decided on 2026-11-10 to raise the NFR4 web build budget from 30 MB to 32 MB (32,000,000 decimal bytes, uncompressed). Updated in `ci.yml` (`WEB_SIZE_BUDGET_BYTES`), `game/tools/smoke_web.sh`, and the planning and architecture docs.
- Reason: the CI web build is 29,651,804 bytes (about 348 KB headroom) after Epic 4, and Epics 5 to 7 (two bosses, music) are still to come.
- NFR3 is unaffected: the real compressed download from itch.io is about 12.3 MB, and the itch.io limit is far higher.
- Historical records (story files, devlogs, the readiness report) keep the 30 MB figure.

## Open for the 3.9 playtest: new UX finding (2026-11-10)

- [x] [3.9 UX] The Infinite Loop stays still until the first register shift (D-S33-6) and nothing tells the player that Q/E starts the fight. (Closed in Story 4.4: clearer T1 line plus a sim-side 300-tick auto-start, D-S44-1/D-S44-2. GDD Duck row 2 and the Boss 1 note still need the "or 5 s" edit after the playtest.)

## mumble-speech web support: UNBLOCKED by v0.3.0 (2026-11-07)

Story 1.3 AC9 / I-6 ("mumble-speech web check, moved to 3.7") is UNBLOCKED. Tiziano released mumble-speech v0.3.0 on 2026-11-07, which closes basteez/mumble-speech#32. The Godot addon zip (`mumble-speech-godot-0.3.0.zip`, 3.9 MB) now ships `mumble_godot.wasm`. It works for Godot 4.3+ web exports with Extensions Support ON and Thread Support OFF (our preset), and there is also a threads build. Known issue: Firefox and Safari are not yet verified by hand. Do NOT vendor the addon now; that is Story 3.7's job. Checks for Story 3.7:
- [x] [3.7 / 1.3 I-6] Vendor `addons/mumble_speech` from the v0.3.0 zip and verify it against `SHA256SUMS.txt`. (Story 3.7: SHA-256 OK, vendored in `game/addons/mumble_speech/`.)
- [x] [3.7 / 1.3 I-6] Confirm the stripped web template (`game/tools/build_web_template.sh`) still loads GDExtension side modules; CI uses the dlink/extensions template. (Story 3.7: yes, no module re-enabled; headless Chrome `?debug&smoke=voice` speaks T1 on the MUMBLE backend.)
- [x] [3.7 / 1.3 I-6] Re-measure the web export against the 30,000,000-byte budget (currently about 28.45 MB, so the addon's wasm must fit). (Story 3.7: local release export 29,461,134 bytes, +1,013,872; headroom 538,866.)
- [ ] [3.7 / 1.3 I-6] Smoke-test the duck voice in Chrome, Firefox and Safari. (Headless Chrome done in 3.7; real Chrome, Firefox and Safari are the 3.7 HUMAN checks H1-H5.) (Chrome ✅ 2026-11-10: `?debug&smoke=voice` reports `backend MUMBLE`, the mumble-speech wasm loads, audio unlocks then speech starts; Firefox/Safari pending.)

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
  - [x] Covered by Story 4.3: buffer bound over a 119-poll Breakpoint with key mashing is asserted (AC 15).
- A recording started before FIGHT entry (or mid-fight) does not hold the RNG state reached; exact replay needs F11 right at fight start (already a known limitation in the story notes). Revisit with 2.2+.
- LiveInput `is_action_just_pressed` at display rates above 60 Hz is unverified headlessly (human check H3, fallback: `_unhandled_input` queue).
- Recording `seed` is stored as a JSON number: exact up to 2^53, ample for `get_ticks_usec`.

## Deferred from: code review of story-2.2 (2026-11-07)

- [design call] F11 recording started mid-fight does not capture player position/velocity/facing (same limitation as RNG state); exact replay needs F11 right at fight start. Revisit if replays become a shipped feature.
- Float determinism of Vector2 `move_toward`/`normalized` across native vs wasm is unverified; replays are same-binary only. Quantise to fixed point if cross-platform replays are needed.
- ReplayInput does not validate `moves` length against `frames` and has no version gate: truncated moves or v1 files play with silent zero movement.
- Duck position jumps on a 180-degree facing flip and presentation has no interpolation (cosmetic); judge in human check H1.

## Deferred from: code review of story-2-3 (2026-11-07)

- [design call] Hit-stop/Breakpoint longer than 8 frames drops all buffered input (attacks, dashes too), not only shifts, since the buffer clock is `poll_frame` (D-S23-2). Judge by feel; widen the buffer window if needed.
- RegisterPanel rebuilds ~20 Cells and redraws every frame while active; switch to redraw on `register_shifted` / flow change if web perf needs it.
- Replay hash uses absolute `ctx.poll_frame`; `begin_fight` does not reset it, so a replay started in a different clock state hashes differently. Recorder does not store poll_frame.
- `SimClock._systems` can be mutated during tick iteration (unregister from a `register_shifted` listener); iterate over a duplicate when such a listener appears.
- `register_shifted` source is hard-coded `&"player"`; add a `source` parameter to `shift` with boss effects (Epic 3).
- `Register.insert` vs buffered shifts ordering in the same tick is undefined (harvest, Story 3.8).
- Checker texture is a static cache, not rebuilt on palette change or lost web GL context.
- Greyed and faded cell styles look identical; differentiate if H1 finds them unclear.
- `Arena.register` binds `SimClock.buffer` at field init; breaks if SimClock ever replaces its buffer.
- `test_panel_never_writes_the_register` regex misses aliased writes (smoke guard only).
- Register `ring` is a public var (single-writer rule is convention); make read-only if misuse appears.

## Deferred from: code review of story-2-4-shift-juice (2026-11-07)

- Physics-frame presentation clock: a render hitch of 4+ physics ticks can skip slide frame 0 or make the inversion invisible; count `_process` frames or clamp start if seen on web.
- `clip_children` under gl_compatibility on web is unverified (H1); fallback is drawing BG strips over the border and col-12 gap.
- [design call] Rapid alternate shifts restart the slide with a snap to +-8 px (D-S24-7); blend from the current offset if it feels bad.
- Click is dropped while audio is locked (debug jump keys skip the title press); call `AudioManager.unlock()` from debug keys if QA needs the sound.
- Click and inversion ignore the `register_shifted` source and `SimClock.paused`; gate on `&"player"` when boss shifts arrive (Epic 3).
- `AudioManager.play_sfx` uses one shared player, so overlapping SFX cut each other; pool in Story 7.2.
- Hit-stop test uses a synthetic frame counter and the AC5 source guard covers only two files; ~~real hit-stop check is H4 (Story 2.8)~~ RESOLVED in code by Story 2.8 (real hit-stop on every hit; the in-browser feel check is Story 2.8 H4, which also closes this 2.4 H4).

## Deferred from: code review of story-2-5-action-state-machine-with-attack-and-dash (2026-11-07)

- Player lock state (`locked`, `locked_velocity_px`) is owned by the FSM; `Player.set_active(false)` / `reset_for_fight` do not clear it. Make Player self-resetting if a second caller appears.
- [design call] Post-dash velocity cap (D-S25-15) drops speed abruptly on unlock; blend through the ramp if H1 finds the dash stops dead.
- `dash.tres` `cancel_into = [DASH]` is unreachable (cooldown 24 > total 16); drop it or lower the cooldown if a dash chain is wanted.
- ~~`HitArc` returns false for a zero facing while `HitCapsule` collapses to a circle; unify in Story 2.7.~~ RESOLVED in Story 2.7 (D-S27-1: `overlaps` and `contains` both collapse to a circle; capsule zero facing now explicit).
- FrameOverlay: stale after leaving FIGHT, added below Entities/Particles layers, treats `hurtbox_tiles` as a diameter; revisit with the hit resolver (2.7).
- `ActionDef.validate` does not check that `cancel_into` bits have a solo action, or `hit_shape`/`base_damage` consistency; `HitShape` subclasses have no validation.
- Cleanup: dead `chain_slot`, `_chain` hard-codes ATTACK and `CHAIN_WINDOW_FRAMES` is not data, ~~`resolve` takes 9 positional args~~ (RESOLVED in Story 2.7: `ResolveInput`), ActionRequest/ActionResolver reference each other.
- Missing: "cooldown block" debug log, Arena FSM integration test, pause/hit-stop and shift-during-dash FSM tests, `FrameOverlay._draw` tests.

## Deferred from: code review of story-2-6-ordered-combo-engine-and-dash-strike (2026-11-07)

- [design call] An unheld buffered K press survives a shift and can run as the new window's solo action; consume it on shift close if H1 feels wrong.
- [design call] The link can close for one tick between chain hits (hit 2 frame 7 vs hit 1 count k=19) and reopen, losing a held K; extend the count on chain start if seen.
- F9 overlay `left N` reads 18 before the count starts (J ACTIVE); pass `counting` and show `-`.
- `LinkOp.DROP` branch is unreachable in play (cooldown on the target cannot start mid-link); `LinkState.held_key`/`held_slot` are never read. Remove or test when another action touches the target cooldown.
- `ComboDef.validate`: check `second` has a solo def, `action.cooldown_frames == 0`, no word longer than 10 chars ("Dereference" is cut to "Dereferenc" on the panel; fix in Story 6.2), and J startup + 1 <= 8 (buffered K stays live until the link opens).
- `ComboTable` index is lazy and never invalidated; the pair key packs `first*256+second` (use `Vector2i`).
- ~~`resolve` has 11 positional args~~ (RESOLVED in Story 2.7: `ResolveInput`); `format_lines` still has 10 args (two adjacent bools); introduce a context object. `combos == null` silently falls back to `Defs.COMBOS`.
- FSM boundary tests call `before_each()` mid-test and fold two scenarios in one; split them. DROP/hit-stop/pause-with-held-press have no FSM test.

## Deferred from: code review of story-2-7-combat-resolver-damage-calc-and-practice-target (2026-11-07)

- [design call] `DebugKeys.practice_requested` survives until another jump key, so any later FIGHT entry in a debug build (retry, new run after death) keeps the dummy; clear it on a TITLE flow change if that surprises (D-S27-3).
- `DamageCalc.compute` returns 0 for negative input and does not enforce the 5 percent granularity (`to_pct` rounds silently); 64-bit overflow only with absurd bases. Add asserts when Epic 3 passes real multipliers.
- `HitArc.overlaps` is exact for the tested geometries but has no test for the outer-corner case or a half-angle above 90 degrees (concave sector); add if an arc wider than 180 degrees is ever authored.
- `CombatResolver`: `player` is injected but unused; `hit_landed` id is hard-coded `&"practice_target"` (take it from the target in Epic 3); `hits_for` does not dedupe a target listed twice; `Log.debug` formats even when logging is off.
- `ResolveInput` is allocated every tick (RefCounted, cheap); reuse one instance if a profile on web shows GC churn. `PracticeTargetView._process` redraws every frame; drive from `hit_landed` if it matters.
- Missing tests: several targets hit in one tick, facing up/down anchors, `DamageCalc` with non-multiple-of-5 multipliers, `FrameOverlay` target drawing.

## Deferred from: code review of story-2-8-hit-feedback-hit-stop-particles-and-log-lines (2026-11-09)

- 2.7 temporary arena readout: RESOLVED in Story 2.8 (removed; LogPanel shows hits).
- `JuiceDirector` effects run from `_process`: a 1-frame inversion or the 6-frame shake start can be skipped when one render frame spans 2+ physics ticks (web hitch); shake offset and inversion stay applied while paused mid-effect. Cosmetic; revisit if H1/H2 show it.
- ScreenFX shader: dither checker assumes the viewport equals `Const.BASE_RES`; invert maps every non-palette pixel (red warning lines, Epic 3/4) to INK or BG. `JuiceDirector.reset()` clears dither on each fight entry; revisit with Breakpoint (Epic 4).
  - [x] Covered by Story 4.3: the shader exempts Palette.WARN (red dot and line) from dither and invert; real-GPU/web check still pending as a human check.
- Solo hits ignore `ActionDef.hitstop_frames` by design (D-S28-1); generalise or document with crit/Patched states (Epic 3). "Max wins" resolver test cannot fail because one action per tick; pure `HitFeedback` test covers it.
- Guards: hit-stop regex is evadable (`set`/`call`, `main/`); nothing enforces "only JuiceDirector calls ScreenFX setters" or "sim never reads ParticlePool".
- Camera2D shake also jitters Particles and PerfOverlay; no explicit `make_current`/limits (boss camera, later). Burst particles read as a clump during hit-stop [design call: judge by feel in H1].
- PerfOverlay: "frame" is `TIME_PROCESS` only; F10 may be captured by browser menus (Firefox/Linux); hidden outside FIGHT. Debug only.
- Micro-costs: ParticlePool scans 300 slots without a free-list; `LogPanel.lines()` allocates per `_draw`. Test-only accessors on production nodes; `CameraShakeDriver` PREDELETE camera cleanup is brittle.
- Missing tests: LogPanel/PerfOverlay `_draw`, AC8 through the director's `_process`. Hit-stop 6 plus queued input leaves 2 frames of buffer slack (see the 2.3 note above).

## Deferred from: code review of story-2-9-player-damage-death-and-instant-retry (2026-11-09)

- [design call] Log panel is hidden in DEAD (HUD child); lines are kept but not drawn. Judge in human checks; show the log layer in DEAD if the player cannot tell what hit them.
- Death transition runs synchronously mid-tick (leave_fight inside the SimClock loop) and the lethal hit's 4-frame hit-stop runs on the DEAD screen. Works via per-system `active` flags; consider deferring death to end of tick.
- Retry reseeds the RNG from the wall clock; the seed is not part of the fight-start snapshot. Revisit with seeded boss patterns (Epic 3).
- Guard regex for AC10 is evadable (`hp := x`, `set(&"hp", ...)`); tests peek private state (`_pending`, `_swallow_presses`) and restore SimClock state by hand.
- `HpReadout` redraws every `_process`; `cell_for` assumes `Hud.COLS >= text.length()`.


## Deferred from: code review of story-3-1-reusable-boss-framework (2026-11-09)

- `BossController.take_hit` ignores `active` and the pre-reset state (hp is 0 before `reset_for_fight`, so an early hit emits `boss_defeated`; after `leave_fight` a hit still mutates HP). Guard when 3.2 wires player damage.
- Body contact is a centre-point-in-circle test (D-S31-25) and the 16 px test-boss radius is smaller than the drawn 128 px glyph; tie radius to the drawn size / player hurtbox when Boss 1 art lands (3.3) [design call].
- AC5 off-screen safety is enforced by each attack clamping itself; the test checks `declared_positions()` which is a separate method from the real positions. A framework-level clamp or position-reporting hook would be stronger.
- Plain F6 / Shift+F6 / Shift+F3 may be intercepted by browsers (address bar, find-previous); add to the H3 manual web check and have fallback keys ready. (Chrome macOS 2026-11-10: F6, Shift+F6 and F8 work on the direct `?debug` URL; Ctrl+F6 on macOS unconfirmed; Firefox/Safari pending.)
- `ArenaContext.player_position()` (D-S31-21) lets any attack bypass the decoy-aware `target_position()` by convention only; split it off or add a guard before 3.4.
- `Arena._set_test_boss` failure leaves `test_boss_requested` set and gives no in-game hint; test boss code and .tres ship in release (gated by `Debug.enabled`); `load()` is synchronous at fight entry.
- `PlayerEffects.apply_all` silently drops pushed commands until command types exist; `BossDef.validate` does not check `weak_window` or name width (3.2).
- Missing tests: ROAR cutting TELL/RECOVERY, contact through full tick, SimClock registration on re-entry, HUD redraw from `boss_hp_changed`, AudioManager tell cue.
- Jitter amplitude is subtle (1-2 px); judge by feel. `Main._attach_boss` does not guard `boss_view`/`hud` and a stale boss stays attached after `leave_fight`.

## Deferred from: code review of story-3.2 (2026-11-09)

- Hit/patch cues share the single ShiftSfx AudioStreamPlayer; overlapping cues truncate each other (tell blip vs thud, chime vs thud). Give hit cues their own player.
- Patched tag/bar can overlap the TELL mark row and has no top-edge clamp; revisit with art (3.3).
- Damage number counts presentation frames, not sim frames; BossView/AudioManager connections lack `_exit_tree` disconnect; LogPanel `_dithered` not reset on `clear()`; hard-coded tick numbers and `LOG_LINES` in tests are brittle; `DamageState.multiplier` falls back to BASE silently.
- A multi-tick action overlapping a boss during ROAR is not marked consumed and could land after ROAR if an action outlasted 60 ticks.

## Deferred from: code review of story-3.3 (2026-11-09)

- Ring contact/`;` hits use float trig and `move_toward`; replays may diverge across native/wasm. Consider integer/fixed-point segment positions or quantising before hit tests; the replay test only proves same-process determinism.
- Start gate keys on `Register.shift_serial` changing; when non-player shifts (Echo, Epic 6) exist, gate on player-sourced shifts only and use "greater than".
- Spawn (clamped y 4.32) plus drift may put a segment on the player almost immediately and the ring is a solid wall to non-invulnerable crossing; fast dashes can tunnel between tick endpoints. Judge in G1 playtest, tune in .tres.
- Defeat leaves the ring stopped with no exit from FIGHT until Harvest/flow (3.8); D-S33-11 makes this visible in all builds.
- Tests hard-code pixel offsets (7.9, 8.5, 11.9) assuming TILE_PX 16, and read private `_pending` / `_pending_hitstop`.
- `RingDef.validate` hard-codes GDD constants; ring_def.tres is preloaded, not linked from boss_def.tres, and not validated at runtime; `body_radius_tiles` hand-synced with segments/TAU.
- `PhaseDef.validate` skips the 2-attack rule for any empty pool (not only the Infinite Loop); add per-boss opt-in.
- `Arena._set_boss`: null `load()` result and failed setup give no log; boss reuse keeps old `body_center_px`.
- Patched tag/bar stack can overlap the ring top and the `;`; revisit with art.


## Deferred from: code review of story-3.4 (2026-11-09)

- Constrict is escapable by hugging a wall/corner: the ring centre is clamped inward (radius + inset), so a player at the edge can sit outside the disc; also the live chase can leave the tell outline (D-S34-21). Playtest (G1), then decide: clamp to play area only.
- Constrict RECOVERY: radius snaps 2 -> 3.82 tiles and re-clamps the centre in one tick; segments can appear on a wall-hugging player without a tell. Ease or skip contact for the first recovery ticks.
- Last tick of Head Rush (10000 mtiles) and Constrict (2000 mtiles) is never contact-checked (D-S34-25); effective reach 9750 / 2030. Tests assert the end value on state, not contact. Head Rush `step_mtiles` uses integer division; validate that charge*1000 % active == 0 if retuned.
- Run seed from `Time.get_ticks_usec()` is low-entropy on web; `fight_seed_for` masks `p_run_seed & 0x7FFFFFFF` so 0x7FFFFFFF collides with 0 mod M; `fight_attempt` also counts debug-jump FIGHT entries.
- Head Rush aim inside the ring flips direction (charges inward); aim == centre falls back inconsistently. Untested.
- Test gaps: no positive control for dash-invulnerability tests; head-hit test does not watch hit_landed/Patched/hit-stop; `test_a_new_run_takes_a_new_run_seed` never asserts a nonzero new seed; Constrict ACTIVE positions not in `declared_positions` (AC 13); debug-jump FIGHT entry untested for seed; isolation guard is textual only (no Time/OS/shuffle bans, `#` in strings); hard-coded 7.9/8.5 px offsets and private `_pending` reads.
- Float geometry (`normalized`, `move_toward`, `from_angle`) feeds hashed state; native vs wasm divergence not covered (same as 3.3).


## Deferred from: code review of story-3.5 (2026-11-09)

- Spit projectile is not consumed by contact: it overlaps the player ~10 ticks and re-queues a hit each tick (PlayerHealth i-frames absorb it, but a second hit lands when they end). Decide in playtest 3.9: free the slot on hit.
- The Nested Loop TELL blink hides the ring but `touches_player` still hurts (D-S35-22); dim/outline instead of hiding, or gate contact.
- A timed `;` opening fired in GAP (60 ticks) is cut by the next TELL (`_on_attack_started`), so the 90-tick window is truncated; and recovery/timed openings alternate in lockstep (recovery inner, timed outer) in real fights (D-S35-24). Playtest 3.9: consider delaying the pick while a `;` is open or alternating the kinds independently.
- Spit float-derived state (`normalized`, `roundi`) feeds the hash (native vs wasm drift, as 3.3/3.4); `step_for` per-axis rounding gives 100 to 141 mtiles diagonal speed and a zero step for a tiny `spit_tps`; Spit origin is read one tick before the ring moves.
- Minor: Constrict ACTIVE declared positions omit the inner ring; `RingDef.validate` hard-codes 16/8/150 and does not cross-check the opening period against attack recoveries; AC 6 inner window derived from the phase window (D-S35-19); `_pick_candidates` allocates per pick; replay has no Spit-contact assertion; swept-segment test for fast non-invulnerable dashes.


## Deferred from: code review of story-3.6 (2026-11-09)

- 3.7 voice seam: add a stop/finish path (hold timer starts only after `is_done()`, so a voice that stops early hangs the bubble until FIGHT exit); call `VoiceService.stop()` on `clear()`/flow exit; decide typewriter-vs-voice ownership (`driven_externally`) before the `duck_line_requested` emit; let the squeak be suppressed while a voice speaks.
- [x] ~~Strict beat order means T4 never fires if Dash Strike was never the active window~~ (Closed in Story 4.4: per-beat triggers, D-S44-3/D-S44-10. Residual: T3 has a transient trigger, see the 4.4 review section.)
- [x] ~~Beats dropped by the `MAX_PENDING` cap are lost for the run~~ (Closed in Story 4.4: `DuckBubble.has_room()` gates the director, a due line waits, D-S44-4.) Still open: debug FIGHT->FIGHT jump does not clear the bubble nor reset `requested`.
- `VoiceService.say` raw text: no empty/ASCII/12-col checks (only the catalogue is validated); double spaces desync the joined-text index; raw text equal to a known id resolves to the catalogue.
- Layering: `DuckLineDef` (data) depends on `DuckBubble` constants and `wrap`; `DuckDirector.poll()` pause gate (closed in Story 4.4, D-S44-9); `>o` glyph is hidden between lines (D-S36-4, confirm in H9); `AudioManager` missing from the isolation guard pattern (voice_service is scanned instead).


## Deferred from: dev of story-3.7 (2026-11-09)

- [ ] [3.7 H1-H5] Human checks: Chrome, Firefox, Safari speak T1 after a click with the reveal in step and the squeak before the voice; no `crossOriginIsolated` needed; pitch/speed of `duck_voice.tres` (pitch 6.0, speed 20.0, set without listening) and `SQUEAK_LEAD_S` 0.15 by ear; Esc mid-line cuts the voice and the text finishes silently. (Chrome partly ✅ 2026-11-10: real flow title, intro, Fight 1 with the duck beats OK and the voice speaks on the MUMBLE backend; duck voice tuning by ear judged "per ora va bene così", acceptable for now, so revisit only if the playtest says otherwise. Firefox/Safari pending; Esc-mid-line not recorded.)
- Pre-existing (not from 3.7): the 1.7 smoke run `SMOKE_QUERY="?debug" SMOKE_KEYS="F2 Escape Escape" SMOKE_EXPECT="pause off"` fails on a `console.error` from `[audio] play ignored before unlock` (Log.warn -> push_warning), because the F2 debug jump enters FIGHT before any unlock and the 3.6 duck squeak (or a shift click) plays. Either unlock on the F2 key press or drop the warn to debug.
- The pre-rendered clips (`assets/audio/duck/*.wav`, about 276 KB imported QOA) ship in the web build even when MUMBLE works there; they are the AUTO fallback. Exclude them with an export filter only if the size budget gets tight (the VoiceService `CLIPS` preload must then become a guarded load).
- The duck voice speaks letters only: punctuation and spaces after the last spoken letter show at `duck_line_finished` (up to 250 ms + 1 frame late on web Sample mode, per the addon docs).
- `render_duck_lines.gd` prints a "Failed to compile depended scripts" line from `DuckLineDef -> DuckBubble -> autoloads` when run with `-s`; the render still works. Re-run it whenever `duck_lines.tres` or `duck_voice.tres` changes (`test_duck_voice_data.gd` fails when a clip no longer matches its line).

## Deferred from: code review of story-3.7 (2026-11-09)

- Stale events: `VoiceService` guards only on `_speaking`, so a late `finished` / `character_spoken` from a stopped line could hit the next line (and a same-id restart can match the old `finished(false)`); add a per-line serial to the signals.
- PRERENDER reveal/finish follow wall time, not `get_playback_position()`; web start latency can clip the tail via `_on_finished` -> `stop()`.
- If `MumbleSpeaker.say` silently produces nothing (suspended AudioContext), only the watchdog (`len/cps + 3` s) recovers; consider a no-first-character fallback to the timer.
- `use_speaker` does not free or disconnect a previous speaker (tests that swap in the fake leave the real speaker child when the addon loads).
- `CLIPS` is preloaded even on MUMBLE; `test_voice_service` FakeSpeaker has no signals so `use_speaker` signal wiring is only covered by the real-addon test; `DuckBubble._voice_line` is write-only.

## Deferred from: code review of story-3.8 (2026-11-10)

- Dying inside the 80-frame defeat window (D-S38-3) discards the kill: retry restarts the boss at full HP and no bit is granted; decide at the MVP playtest (3.9).
- Release build: FIGHT 2/3 have no boss and no exit until Epic 5/6; the run dead-ends there.
- An F11 recording left running through FIGHT -> HARVEST -> FIGHT does not reproduce fight 2 (new seed, HARVEST idle frames); stop or segment the recorder on the flow change.
- Test hygiene: defeat hit-stop leaks across suites (test_camera_shake, others); suites poke private `SimClock._pending_hitstop`; add a shared reset helper.
- `Game.finish_harvest` has no bounds check on `boss_index + 1` and does not enforce the 2 s skip gate (only the screen does).
- `Hud.set_duck_only(false)` force-shows every HUD child; `is_duck_only` is inferred from `frame.visible`.
- HarvestScreen: physics-frame flight vs sim-frame skip/cap diverge under hit-stop; bit flight starts at screen top-centre not the boss position; reassembly segments mapped to space cells vanish.
- Test gaps: HarvestScreen `_unhandled_input` (key/click/modifier), F8 warn path, Main-level ENDING route after Fight 3, HP reset on the 480-frame cap path. F8 does not emit `boss_defeated`.

## Deferred from: code review of story-4-1-loop-bit-echo (2026-11-10)

- Echo as K `link_second` on a boss: no end-to-end test of weak-window completion (D-S41-6/D-S41-11); add with the 4.2 Echo Dash combo tests. Story 3.8's D-S38-6 (LOOP is NOP) is resolved by 4.1.
- Echoed def with `cancel_into` can cancel into other bits, and an Echo run opens a link on (L, y); intended, untested; cover in 4.2.
- EchoMemory holds a reference to a shared ActionDef resource; revisit if Epic 5/6 mutates defs at runtime.
- An echoed hit re-applies the original def's Patched/boss interactions at 70% damage; not pinned by a test.
- `ActionDef.echoable` defaults to true (opt-out); new boss/garbage defs must set it deliberately.

## Deferred from: code review of story-4-2-echo-dash-combo (2026-11-10)

- PASS_THROUGH marks the boss hit on the first overlap even if the weak window does not match; a later phase/window change in the same dash cannot Patch (one chance per action).
- The Echo Dash capsule is evaluated from `action_origin_px` along the full 4 tiles, not the player's clamped path (wall/corner redirects still pass through a boss within the unclamped capsule).
- A redirect does not update `Player.facing`; sprite flip and the next action's captured facing may disagree with the dash direction.
- A K press refused by the gap_free rule is silently dropped (log only); consider a UI/SFX cue if playtest shows confusion.
- `ComboDef._solo_action` uses `load()` + `.call` on Defs (preload-cycle workaround); verify in a Web export.
- Echo Dash's single `combo` start log is not asserted; `test_combo_def_validation_additions` mutates the shared `Defs.SLASH_1` (restored before the assert).

## Deferred from: code review of story-4-3-breakpoint-skill (2026-11-10)

- Breakpoint can start during the boss DEFEATED animation (can_start ignores boss state); it delays HARVEST by up to about 2 s and burns the cooldown on a dead boss. Cosmetic/pacing; gate it from Arena if playtest shows it. (Hint side closed in Story 4.4: no hint while DEFEATED. The delay/cooldown burn itself stays open.)
- The start poll counts as frozen poll 1, so the world freezes for 119 ticks, not 120 (D-S43-16, "at most 120"). Confirm with the GDD owner whether 120 frozen frames is meant.
- Readout text is `brk READY` / `brk 12s` (GDD HUD label), AC 10 wording says `READY` / seconds only; amend the AC text.
- Spec/AC 1 field name `breakpoint` is `breakpoint_enabled` in code (reserved word, D-S43-17); later stories (6.5, 7.4) must use the new name.
- The ending J/K press sits in the buffer if hit-stop is pending on the end poll; hit-stop of 8+ frames drops it (D-S43-12 accepted).
- Flag-off full suite is a manual run (flip `feature_flags.tres`); only `test_shipped_flags_are_all_on_and_valid` fails by design. No CI matrix job for it.
- Arena builds then drops a BreakpointSkill when Main injects a flag-off resource differing from Defs.FEATURE_FLAGS (not reachable in shipped play).
- ScreenFX exemption uses an exact match (epsilon 0.002) on screen_texture; anti-aliased dot rim or sRGB differences on the Web Compatibility renderer may dither the rim. Human check in browser; fallback: draw_rect dot or a wider threshold.
- check_guards leaf rule: does not cover BreakpointReadout (in ui/hud), .tscn/.tres references, or trailing `#` comments on code lines.
- `_gate.set(&"breakpoint_gate_active")` on an untyped Object is silent if renamed or null; replay test hashes no player position; wiring test reads private `_systems`; assorted weak/tautological tests; `breakpoint_music_events` counter merges started and ended.


## Deferred from: code review of story-4.4 (2026-11-10)

- A queued Breakpoint hint stores the window at queue time and can be said later (full bubble) when the phase or the phase-3 ring has moved on. Resolve at pop time or drop on phase change if the playtest shows it.
- The Breakpoint hint is once per (boss, phase) (D-S44-5), so in Infinite Loop phase 3 the inner-ring window is not hinted after the outer one. Add the window to the key if the playtest wants it.
- T3 (Dash Strike) has a transient trigger: if the window passes while the bubble has no room or the game is paused and T4 then fires, T3 is skipped for good; `requested` survives retries so a retry never re-teaches it. Latch trigger observations if the playtest shows it.
- ~~Null Pointer and Segfault have no BossDef yet: the AC 2 per-phase hint test picks them up when the defs land (Epic 5).~~ RESOLVED for Null Pointer in Story 5.1 (`boss_def.tres` lands; the per-phase hint test covers it). Segfault still pending (Story 5.x).
- Hit-stop is not covered by a nudge test (pause and Breakpoint are, in `test_start_nudge.gd`); the `test_a_shift_at_tick_10_starts_at_10` tail assertion (`iteration >= 1`) is near-vacuous; `test_third_death_through_the_real_game_flow` sets the flow state by hand after the retry.
- The `→` in hint text is sent to the mumble voice (letters only, probed silent in 4.4); confirm by ear in the browser (human check).
- Pending hints are dropped when the flow leaves FIGHT (D-S44-12) and the Breakpoint record is marked at queue time, a recorded departure from the AC 9 wording.

## Deferred from: code review of story-5.1 (2026-11-11)

- Fight 2 (Null Pointer) ships as an unattackable, mostly invisible damage sponge in release builds until Stories 5.2 (attacks) and 5.4 (Watch) land.
- ROAR (phase 1 to 2) keeps the ghost hidden; decide in the playtest whether the roar should show the body.
- `reset_for_fight` clears `watch_held` although the key may still be held across a retry; Story 5.4 should re-sync Watch state from input.
- Drift continues while Watch is held (AC 10 wording vs D-S51-7); revisit with 5.4.
- `BossDef.validate` does not bound `body_radius_tiles` (>= 9 inverts the drift bounds); data-only risk.
- Every BossView builds a NullPointerHum (the 22k-sample loop is generated once, static); create lazily if the web build shows a hitch.
- Test weaknesses: the Patched-stack-while-hidden test ends on `is_inside_tree()`; the hum play/stop path is not exercised headless (audio locked); the drift tolerance is 1%.
- `hint_d_l` `char_times` copy `hint_d_a` (same line length); confirm the typewriter sync by ear in the browser. `duck_clips.tres` ids were re-serialised by the editor.

## Deferred from: code review of story-5.2 (2026-11-11)

- Null Rain areas clamp independently near walls, so fewer than 5 distinct areas can result; tune in playtest.
- Pointer Grab centre is clamped at walls; "any step forward escapes" is untested there.
- Story 5.2 integration tests: recovery-window timing depends on the seeded attack pick (not pinned); visibility assertion ORs reveal timers; player HP topped up each tick (no real death path).
- "Body never touches the player" test is tautological (`touches_player` is `attack_hazard_hit`).
- Phase-2 `gap_frames` (60) assertion was dropped from the rewritten Story 5.1 body test.
- With `invuln_frames` 0 the attacks could queue a hit per ACTIVE tick; add a one-hit latch if invulnerability is retuned.
- AC 13 covers `declared_positions` on 4 facings only; `BossView` glyph/outline drawing has no test.
- `tell_pointer_grab` / `tell_null_rain` sfx ids are not registered with audio (silent cue).
- Phase 1 and phase 2 share the same attack pool (D-S52-6); phase escalation is thin.

## Deferred from: code review of story-5.3 (2026-11-11)

- The dispel flash is wiped when the dispelling hit also crosses a phase threshold or kills the boss (D-S53-7 clears flashes); hit-stop shows with no flash. Cosmetic.
- No unit test for a chain slash (`SLASH_2`/`SLASH_3`) whiffing; `is_attack_slash` covers it in code only.
- Tell marks are empty for the first TELL frame (spots planned on the next tick).
- `_tick_stun` drains J/K presses on the last stunned tick too (input feels 21 frames).
- Whiff range is measured from the player centre at the last ACTIVE frame, the hit shape from the action origin; equal while slashes lock movement. Unify if a slash ever moves the player.
- Decoy spacing (4 tiles from the body) is checked at plan time; the body drifts during TELL, so a decoy can spawn slightly closer. Tune in playtest.
- Test weaknesses: `test_a_real_slash_dispels_a_decoy_without_a_stun` ends on a tautological `boss.hp <= hp`; the integration re-cast test removes decoys itself at the cap.

## Deferred from: code review of story-5.4 (2026-11-11)

- Pause leaves the Watch gate and the overlay held until the first poll after resume (no poll runs while paused). Cosmetic.
- A dash carried out of Watch can exceed half top speed for about accel_frames, and the halved speed also halves the decel step. Tune in playtest.
- The ghost reveal only updates on live body ticks, so it lags the overlay during hit-stop or a Breakpoint freeze (design call).
- HUD weak-window marks skip bits the player does not own; the next-attack line shows the raw attack id (D-S54-14, D-S54-17). Add a display name to AttackDef when polishing.
- `Arena.set_watch_enabled(true)` mid-fight leaves the skill out of the fight until the next enter_fight (tests / debug only).
- Source-grep guard tests (`contains("watch")`) in test_watch_effects.gd and test_watch_readouts.gd are fragile against harmless edits.

## Deferred from: code review of story-5.5 (2026-11-11)

- One tick with several damaging hits (boss plus practice targets) applies the single Clean Catch charge to all of them; harmless in the boss fight (one damaging target).
- Clean Catch has no expiry; it survives whiffs, stuns and phase changes until the next damaging hit or fight reset (D-S55-5). Revisit in playtest.
- A hit inside the 60-frame post-hit blink does not arm Clean Catch even during the dodge's invulnerable frames (D-S55-14). Tune in playtest.
- Echo of Null Dodge has no end-to-end test against a live boss attack.
- No dedicated tests for F8 on Fight 2 granting nothing extra, or the Dash-Null-Dash-Null chain cap.
