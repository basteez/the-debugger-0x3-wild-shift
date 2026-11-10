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
- Plain F6 / Shift+F6 / Shift+F3 may be intercepted by browsers (address bar, find-previous); add to the H3 manual web check and have fallback keys ready.
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
- Strict beat order means T4 never fires if Dash Strike was never the active window (tutorial soft-lock only, by design D-S36-7); consider letting later triggers supersede earlier beats in playtest 3.9.
- Beats dropped by the `MAX_PENDING` cap are lost for the run (`requested` already advanced); unreachable with one beat per poll. Debug FIGHT->FIGHT jump does not clear the bubble nor reset `requested`.
- `VoiceService.say` raw text: no empty/ASCII/12-col checks (only the catalogue is validated); double spaces desync the joined-text index; raw text equal to a known id resolves to the catalogue.
- Layering: `DuckLineDef` (data) depends on `DuckBubble` constants and `wrap`; `DuckDirector.poll()` is not gated on `SimClock.paused`; `>o` glyph is hidden between lines (D-S36-4, confirm in H9); `AudioManager` missing from the isolation guard pattern (voice_service is scanned instead).
