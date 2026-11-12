---
baseline_commit: b4ce2d0
---
# Story 6.6: Reserved Write (Cut Ladder #1)

Status: done

<!-- Created unattended by gds-create-story (pipeline, 2026-11-12). Open design questions are marked [design call] with the chosen default (D-S66-n); the implementer follows them or records a change in Completion Notes. Scope: the Reserved Write attack (P3 only, 45-frame tell, 600-frame garbage bit `?`, 30-frame recovery), the first temporary register insertion through the PlayerEffects queue (InsertTemporaryBit), its expiry and removal, the reserved-nibble tell, the flag-off path (FeatureFlags.reserved_write), the guard and the tests. NOT in scope: intro and ending screens (6.7/6.8), the game text audit (6.9), final art and sound (7.x), the Chrome human checks (recorded as pending, not automated). -->

## Story

As a player,
I want the boss to write a garbage bit into my reserved memory,
so that the final phase twists the register one more time.

**Requirements:** FR44 (Reserved Write, cut-ladder #1). Additional: NP-3 (boss-to-player effects through the PlayerEffects queue, applied at the fixed tick point), AD-12 (`FeatureFlags.reserved_write`, cut #1, the first boss cut). Window: Nov 22–25 (Epic 6). Depends on: 2.3 (Register ring, `insert`, `set_fight_start`), 2.6 (LinkState, combo table), 3.1 (`BossController` FSM, `PlayerEffects` slot), 3.8 (harvest `insert`), 5.5 (`Defs.bit` / BitDef for the NULL bit, the solo-action lookup), 6.5 (`PlayerEffects.RotateRegister`, `bind`, `Register.rotate`, `exclusive`, the `warning_tell()` presentation pattern, the Segfault leaf), 6.4 (the phase 3 pool shape). Depends on the cut ladder in `data/config/feature_flags.tres` (`reserved_write = true` shipped).

## Acceptance Criteria

**Pool, data and flag**

1. **Given** `game/data/bosses/segfault/boss_def.tres`, **When** loaded, **Then** phases 1 and 2 are unchanged (`[attack_access_violation, attack_corrupt_memory]` and `[... + attack_sigsegv]`), and phase 3's `attack_pool` is `[attack_access_violation, attack_corrupt_memory, attack_core_dump, attack_sigsegv, attack_reserved_write]`. Reserved Write appears in no phase before 3. HP 1000, drop 0, the fixed line, the per-phase weak windows and gaps, and the thresholds (100 / 66 / 33) are unchanged; `BossDef.validate()` returns no problems.
2. **And** `attack_reserved_write.tres` has `id = &"reserved_write"`, `tell = 45`, `active = 600`, `recovery = 30`, `exclusive = true` ([design call] D-S66-2), `recovery_if_no_breakpoint = 0` (the default; no Breakpoint-dependent change), a non-empty `tell_sfx` (`tell_reserved_write`, data only, D-S66-9) and an `attack_script` under `src/bosses/segfault/attacks/`.
3. **Given** `FeatureFlags.reserved_write = false` (`Defs.FEATURE_FLAGS.reserved_write`, read once at startup), **When** the Segfault fight starts, **Then** the `reserved_write` entry is dropped from the pool before any BossAttack instance is built (no `ReservedWrite` object exists), phase 3 is `[access_violation, corrupt_memory, core_dump, sigsegv]`, and stories 6.1–6.5 behave exactly as before (the 6.5 test suite is green with the flag off).

**Tell and presentation**

4. **Given** Reserved Write is chosen in phase 3, **When** its TELL runs (45 frames), **Then** the register panel's `reserved` nibble flashes (inverts, ink on background, toggling every 8 frames, [design call] D-S66-8) for the whole tell, and the attack reports it through `warning_tell()`-style method `reserved_tell()` (no class-name detection, AD-05). No register change, no garbage bit and no damage happens during the tell. `Palette.WARN` (red) is not used: the GDD reserves red for Breakpoint and SIGSEGV only.
5. **And** presentation never writes sim state (AD-05): the flash reads the attack's getter, and no HUD source uses a colour outside INK/BG (`test_glyph_palette` stays green).

**Effect**

6. **Given** Reserved Write reaches its ACTIVE frame, **When** `on_active` runs, **Then** it pushes exactly one `PlayerEffects.InsertTemporaryBit(PlayerEffects.GARBAGE_BIT, 600)` command behind a `fired` latch (the 6.5 pattern). The command is applied in the PLAYER_EFFECTS phase of that tick, after SHIFTS and before COMBAT.
7. **And** applying the command appends the garbage bit `?` (`Register.Bit.GARBAGE`, id 5) to the right end of the ring (the ring is the owned bits plus one temporary slot, D-S66-3), recomputes the active window, emits `EventBus.register_changed` once with cause `&"garbage_in"`, and leaves `shift_serial` unchanged (the ATTACK chain is not reset by a boss effect, the 6.5 rule). The LinkState is closed (NP-1), as for any register change by an effect.
8. **And** the `?` bit has solo action NOP (`data/actions/nop.tres`) and every pair containing it has no combo (`ComboTable.get_combo` returns null for every pair with id 5, checked in both orders). Pressing J or K on a window containing `?` runs the NOP action and nothing else.
9. **And** the garbage bit is never offered by harvest: `Register.insert(GARBAGE)` is rejected with `Log.error` and the fight-start set (`set_fight_start`) rejects id 5. The ring is at most `MAX_BITS + 1` = 5 slots, and only while the temporary bit is present.
10. **And** `on_active` is idempotent within the attack (the `fired` latch, cleared by `reset()`, `on_cancel` and `on_recovery` according to the 6.5 rule). A second call in the same attack queues nothing.
11. **And** the attack files never name `Register`, `Player`, `PlayerHealth`, `LinkState`, `rng` or `Defs` (`test_attack_isolation` stays green); the attack reaches the bit id only through `PlayerEffects.GARBAGE_BIT`. The command class lives in `src/bosses/framework/player_effects.gd`, outside the leaf folder.

**Expiry, cut, defeat and retry**

12. **Given** the garbage bit has been present for exactly 600 PLAYER_EFFECTS ticks counted from its application tick, **When** the tick that ends its lifetime runs, **Then** the bit is removed by `Register` (ring back to the owned bits, window recomputed), `EventBus.register_changed` is emitted once with cause `&"garbage_out"`, and the LinkState is closed. The removal happens in the PLAYER_EFFECTS phase (the same phase as insertion). The owned bits and their order are unchanged by the insertion-and-removal pair.
13. **And** a phase change or defeat that cuts Reserved Write during TELL or ACTIVE runs `on_cancel`: it clears the latch and ends any live garbage bit at once (`PlayerEffects.end_temporary(GARBAGE_BIT)`, [design call] D-S66-6), with `register_changed(cause &"garbage_out")` emitted; `on_recovery` does not run.
14. **And** a defeat during RECOVERY needs no action beyond the normal DEFEATED path (the bit has already expired); after DEFEATED the ring shows the owned bits only (no `?`).
15. **And** a retry (`reset_for_fight` / `enter_fight` with the fight-start set) leaves the PlayerEffects queue and the temporary-bit list empty, and the Register ring equals the fight-start set again (no garbage bit carries over). `Register.set_fight_start` is the retry restore and it removes any temporary slot.

**Fairness and determinism**

16. **Given** 10 seeded runs of phase 3 (GUT, fixed seeds), **When** each Reserved Write is checked, **Then** it never overlaps another attack's ACTIVE frames (serial FSM and `exclusive`), is followed by its full 30-frame RECOVERY, and has exactly one 45-frame TELL before it; the garbage bit is present for exactly the 600 ticks of AC 12 each time.
17. **And** Reserved Write draws no RNG; the same seed gives the same pick sequence and the same register timeline on every run (replay determinism, 2.1). The insertion and removal are fixed (`?` appended to the right end; removal by the same rule).
18. **And** `game/tools/check_guards.sh` prints OK; its Segfault leaf rule also names `ReservedWrite` (the class name of `attacks/reserved_write.gd`) so it cannot leak outside `src/bosses/segfault/` (D-S66-10).
19. **And** the GUT suite (headless, `-gexit`) passes with the flag on and with the flag off (the flag-off case is a test, AC 3). Chrome check of the phase 3 Reserved Write (the `reserved` nibble flash, the `?` in the ring, the expiry) is recorded in Completion Notes as a human check. It is not automated and does not block this story.

## Tasks / Subtasks

### Group A: Data (AC: 1, 2, 8)
- [x] Add `game/data/bosses/segfault/attack_reserved_write.tres` (AttackDef: id, tell 45, active 600, recovery 30, exclusive true, tell_sfx `tell_reserved_write`, attack_script).
- [x] Add `game/data/bits/bit_garbage.tres` (BitDef: id 5, glyph `?`, `solo_action` = `data/actions/nop.tres`). Wire it into `Defs.bit()` (`Register.Bit.GARBAGE` case) and keep `Defs.bit()` for ids 1–4 unchanged.
- [x] Update `boss_def.tres` phase 3 pool: `+ attack_reserved_write` (AC 1). Keep thresholds, windows and gaps.
- [x] Extend the data validation test: pool membership (phase 3 only), `exclusive`, recovery values, `bit_garbage.tres` validates.

### Group B: Register (AC: 7, 8, 9, 12, 15)
- [x] `game/src/register/register.gd`: add `GARBAGE := 5` to `enum Bit` and to `GLYPHS` (`"?"`). `is_bit(GARBAGE)` is true; `insert()` and `set_fight_start()` reject it (AC 9).
- [x] Add `insert_temporary(bit: int) -> bool`: appends to the right end when the ring holds at most `MAX_BITS` owned slots and no temporary slot is present; sets a `temporary: int` flag/slot (one temporary slot at a time). Emits `register_changed` with cause `&"garbage_in"` (the caller passes the cause).
- [x] Add `remove_temporary() -> bool`: removes the temporary slot wherever it sits in the ring (AC 12 keeps the owned order), recomputes the window, emits `register_changed` with cause `&"garbage_out"`.
- [x] `set_fight_start` clears any temporary slot (retry restore, AC 15).
- [x] `rotate` / `shift` / `preview` / `active_window` work on a ring of 5 slots (the ring-size guards use `MIN_BITS`, not `MAX_BITS`, so they stay correct; check every `MAX_BITS` use).
- [x] `game/src/core/event_bus.gd` (the only signal declarations): add `signal register_changed(window: Vector2i, ring: PackedInt32Array, cause: StringName)` with `@warning_ignore("unused_signal")`.

### Group C: Effect queue (AC: 6, 12, 13)
- [x] `game/src/bosses/framework/player_effects.gd`: add `const GARBAGE_BIT := Register.Bit.GARBAGE`; add `class InsertTemporaryBit` (`bit`, `frames`, `apply(register, link)` → `register.insert_temporary(bit)`, close the link, and register the live entry with the queue so it expires after `frames` ticks).
- [x] Expiry: the queue tracks live temporary entries with a remaining-frame counter, decremented once per PLAYER_EFFECTS tick; at zero it calls `register.remove_temporary()` and closes the link (AC 12). Counting starts at the application tick (AC 12: exactly 600 ticks present).
- [x] Add `end_temporary(bit: int)` (ends the live entry now, used by `on_cancel`, AC 13) and make `clear()` also end live temporary entries (fight start, retry, defeat) with the register kept consistent: `clear()` must not leave a `?` in the ring.
- [x] Deferred item from 6.5 (`deferred-work.md`, "PlayerEffects dispatches by `has_method`"): introduce a `PlayerCommand` base class (RefCounted, `apply(register, link)`) and type the queue on it, if it parses under Godot 4.7.2 without a cycle. If it does not parse, keep the duck-typed dispatch and record the reason in Completion Notes ([design call] D-S66-4).
- [x] `bind()` stays as is; unbound pushes keep the 6.5 error-and-drop rule.

### Group D: Reserved Write attack (AC: 4, 6, 10, 11, 13)
- [x] `game/src/bosses/segfault/attacks/reserved_write.gd` (`class_name ReservedWrite`, `extends BossAttack`): `on_tell` rearms the `fired` latch and sets the reserved flag; `on_active` pushes `PlayerEffects.InsertTemporaryBit.new(PlayerEffects.GARBAGE_BIT, 600)` once (the latch); `on_recovery` clears the flag; `on_cancel` clears the flag and calls `ctx.player_effects.end_temporary(PlayerEffects.GARBAGE_BIT)`; `reserved_tell()` returns true while the TELL of this attack runs (AD-05 getter, same shape as 6.5 `warning_tell()`). `declared_positions` empty, `hazard_hit` false (no ground hazard).
- [x] No RNG, no `Register`, `Player`, `LinkState` or `Defs` names (AC 11).

### Group E: Controller and flag wiring (AC: 3, 16)
- [x] `game/src/bosses/framework/boss_controller.gd` (or the Arena wiring that builds the pool): when `Defs.FEATURE_FLAGS.reserved_write` is false, skip any pool entry with `id == &"reserved_write"` before attacks are instantiated. Follow the Breakpoint / Watch "registered only if on" pattern (`Arena` reads the flag once, as it does for `breakpoint_enabled` and `watch_enabled`).
- [x] `reset_for_fight` already clears the PlayerEffects queue (6.5); verify it also ends the temporary bit (AC 15).

### Group F: Presentation (AC: 4, 5)
- [x] `game/src/ui/hud/register_panel.gd`: while the boss reports `reserved_tell()` (detected by method, no class name), draw the `reserved` label and nibble inverted on the 8-frame toggle. Ink and background only.
- [x] While the garbage bit is present, the panel shows the ring's temporary slot as `?` (D-S66-3, D-S66-7). The window highlight and the `<<` / `>>` previews come from the Register, not the panel.
- [x] Verify the `?` and `reserved` glyphs exist in `wildshift8` (`test_font_coverage`; printable ASCII covers `?`).

### Group G: Guard (AC: 18)
- [x] `game/tools/check_guards.sh`: add `ReservedWrite` to the Segfault leaf rule regex (outside `src/bosses/segfault/`). `InsertTemporaryBit` and `GARBAGE_BIT` are framework names and are not added.

### Group H: Tests (AC: 1–19)
- [x] `game/tests/unit/test_reserved_write.gd`: 45 / 600 / 30 timings; P3-only pool; one insertion per attack; latch; cut during TELL and during ACTIVE removes the bit and fires no recovery; retry restore; 10 seeded runs of phase 3 (no overlap, full recovery, one tell, bit present exactly 600 ticks).
- [x] `game/tests/unit/test_player_effects.gd` (extend): InsertTemporaryBit applies once in PLAYER_EFFECTS; expiry at 600 ticks; `end_temporary` and `clear()` leave no `?`; unbound drop still logs.
- [x] `game/tests/unit/test_register.gd` (extend): insert_temporary on 2-, 3- and 4-bit rings (the 4-bit ring reaches 5 slots); window after insert and remove; rotate and shift on a 5-slot ring; `insert()` and `set_fight_start()` reject GARBAGE; `register_changed` causes `garbage_in` / `garbage_out`.
- [x] `game/tests/unit/test_combo_table.gd` (extend): every pair with id 5 (both orders) has no combo.
- [x] `game/tests/unit/test_boss_fallback.gd` (extend): flag off drops `reserved_write` from P3 and builds no `ReservedWrite`; 6.3 / 6.4 / 6.5 cases stay green.
- [x] `test_data_validation` and `test_font_coverage` extended as in Group A and F.
- [x] Run the full GUT suite headless (flag on and the flag-off case) and `bash game/tools/check_guards.sh`.

## Dev Notes

### Design context (what 6.6 must respect)

- The framework (`BossController`, 3.1) owns the FSM, pools, the no-triple-repeat rule, the weak window, Patched and defeat. Reserved Write adds only its TELL / ACTIVE / RECOVERY hooks and one queued effect, the same shape as SIGSEGV (6.5).
- NP-3: bosses never call `Player` or `Register`; they push effects. Effects apply at one fixed point, `PLAYER_EFFECTS` (after `BOSS_HAZARDS`, before `COMBAT`). The temporary-bit expiry runs in the same phase, so the register changes only at that point.
- GDD (Boss 3 table, line ~429): Reserved Write is phase 3 only, 45-frame tell (the `reserved` nibble flashes), 600 frames with the garbage bit `?` inserted, its solo action and combos are NOP, recovery 30. GDD cut ladder #1 (line ~676): this is the first cut, so with the flag off the game is the 6.5 game in P3.
- GDD colour rule (line ~516): red is reserved for the Breakpoint line and SIGSEGV. Reserved Write uses ink only.
- Garbage bit is a boss effect, not a bit the player owns: it is never harvested, never in `fight_start_for_boss`, and never persists past the fight.

### Current state of the code (read before editing)

- `game/src/bosses/framework/player_effects.gd` (`class_name PlayerEffects`, `extends SimSystem`): `RotateRegister` (6.5), `bind`, `is_bound`, `push`, `apply_all` (duck-typed `has_method(&"apply")`), `pending`, `clear`. Header says 6.6 adds `InsertTemporaryBit`.
- `game/src/register/register.gd` (`class_name Register`): `enum Bit { ATTACK = 1, DASH = 2, LOOP = 3, NULL_BIT = 4 }`, `MIN_BITS 2`, `MAX_BITS 4`, `GLYPHS`, `ring`, `shift`, `rotate(n, source)` (6.5, emits `register_shifted`, `shift_serial` untouched), `insert` (harvest, rejects a full ring), `set_fight_start` (2..4 owned, rejects unknown and duplicates), `fight_start_for_boss` (Boss 3 = `[A, D, L, N]`, 4 bits, so the garbage slot makes 5 in phase 3), `rotated` / `window_of` static helpers.
- `game/src/core/defs.gd`: `bit(id)` matches ids 1–4 to `BIT_*` consts; `solo_action(id)`. `Defs.FEATURE_FLAGS` preloads `data/config/feature_flags.tres`.
- `game/src/core/feature_flags.gd`: `reserved_write` is already declared (default true, cut #1 comment already says "Story 6.6"). Read once in `main.gd` / `arena.gd` like `breakpoint_enabled` and `watch_enabled`.
- `game/src/arena/arena.gd`: `ctx.player_effects.bind(register, actions.link)` in `_make_arena_context` (6.5). `arena.gd:167` clears `player_effects` on enter. `register.set_fight_start` on each fight start (retry restore path).
- `game/src/bosses/framework/boss_controller.gd`: `reset_for_fight` clears the queue (line ~121); `effective_recovery` uses `recovery_if_no_breakpoint` only when > 0 (so the 0 default is safe here); `can_start` is the 6.5 exclusive check.
- `game/data/actions/nop.tres` exists (the NOP action for the garbage solo).
- `game/src/bosses/segfault/attacks/sigsegv.gd`: the template for the latch, the `warning_tell()` getter, `on_cancel` / `reset` clearing.
- `game/src/ui/hud/register_panel.gd`: 8 cells, reserved nibble first, then the owned window (`RESERVED_LABEL`, `LEFT_COL`, `LABEL_ROW`).
- `game/src/bosses/segfault/`: `segfault_body.gd`, `corrupted_tiles.gd`, `attacks/access_violation.gd`, `attacks/corrupt_memory.gd`, `attacks/core_dump.gd`, `attacks/sigsegv.gd`. No `reserved_write.gd` yet.
- `game/tools/check_guards.sh`: the Segfault leaf rule names `SegfaultBody|CorruptedTiles|CorruptMemory|CoreDump|Sigsegv`.

### Design calls (D-S66-n)

- **[design call] D-S66-1 Pool.** Phase 3 only: `[access_violation, corrupt_memory, core_dump, sigsegv, reserved_write]`, uniform pick (framework rule). P1–P2 unchanged. The GDD table is the source (Reserved Write P3 only).
- **[design call] D-S66-2 ACTIVE is the 600-frame window, exclusive.** The GDD table gives Active 600 frames, so `active = 600` in data; `on_active` pushes once (latch), the effect lives for 600 ticks. `exclusive = true` so no future parallel attack can overlap the garbage window (the serial FSM already guarantees it, the 6.5 check covers it). Recovery 30. The boss does nothing visible for 600 frames by design (the player's problem is the `?`).
- **[design call] D-S66-3 The garbage slot is a temporary fifth slot.** Phase 3 starts with 4 owned bits, so the garbage bit makes the ring 5 slots while present. The ring holds at most one temporary slot and at most `MAX_BITS + 1` slots in total. `MAX_BITS` (4) keeps its meaning for harvest and fight-start, which both reject a temporary slot. Alternative (rejected): overwrite the rightmost owned bit, which would change player state beyond "inserted" in the spec.
- **[design call] D-S66-4 PlayerCommand base.** Attempt the deferred 6.5 refactor (typed `PlayerCommand` base) only if it parses in Godot 4.7.2; otherwise keep duck typing and record why. Behaviour does not depend on the choice.
- **[design call] D-S66-5 Solo NOP.** The `?` bit uses the existing `data/actions/nop.tres` (no hitbox, no damage, its own frames as defined there). A press on a window containing `?` costs that action's frames; no combo, no link, no cooldown beyond the NOP def. Verify `ActionDef.validate()` accepts the NOP as the BitDef solo action.
- **[design call] D-S66-6 Cut and defeat remove the garbage.** A phase change or defeat during TELL or ACTIVE ends the temporary bit at once (`end_temporary`), so the DEFEATED state and the harvest screen show the owned bits only. The 6.5 rule (defeat leaves the Register as it was at the cut) is not applied to this effect, because the garbage bit is not owned and must not persist.
- **[design call] D-S66-7 Panel shows the temporary slot.** While `?` is present the register panel shows it as the last cell of the `reserved` nibble, in ring order, so the player reads it as "the boss wrote into my reserved memory". The window and previews come from the Register; the panel only draws. Dev may adjust the cell layout if the 8-cell panel cannot show five slots cleanly; record the choice.
- **[design call] D-S66-8 Reserved tell is ink-only inversion.** The `reserved` nibble inverts (ink background, background ink) on an 8-frame toggle during the 45-frame TELL. No red, no border, no line text (the GDD asks only for the flash). Game text, if any, is 6.9.
- **[design call] D-S66-9 Tell SFX are data-only.** `tell_reserved_write` is a non-empty id, not registered with audio (D-S64-8 / D-S65-9 pattern); the Epic 7 audio pass (7.2) maps it.
- **[design call] D-S66-10 Guard names.** The Segfault leaf rule adds `ReservedWrite`. `InsertTemporaryBit` and `GARBAGE_BIT` are framework names and stay out of the leaf rule (same as `RotateRegister`).
- **[design call] D-S66-11 `register_changed` is a new signal.** The epics AC names `register_changed` but the EventBus has none; add it with the signature in Group B (window, ring, cause). `register_shifted` stays for rotations and player shifts.

### Architecture and rules that bind this story

- AD-06 / AD-12: attack and its data in `src/bosses/segfault/` and `data/bosses/segfault/`; core code loads by path only; leaf rule enforced by `check_guards.sh`; `FeatureFlags.reserved_write` read once at startup.
- NP-1 / NP-3: any register change by an effect closes the link; bosses push effects and never mutate the player or Register; effects apply at the fixed PLAYER_EFFECTS tick point, and the expiry runs there too.
- AD-01: durations are int sim frames; no `delta`, no `Timer`, no `await`, no `create_tween` in sim.
- AD-05: presentation reads the attack getter (`reserved_tell()`) and the Register ring; it never writes sim state.
- Determinism: SimContext RNG only; Reserved Write draws nothing; no global `randi()`.
- Red `#FF4040` only for warnings (Breakpoint, SIGSEGV); not used here.
- `test_attack_isolation` forbids `Register`, `Player`, `PlayerHealth`, `rng`, `rand*(`, `Arena.` in `attacks/`. Use `PlayerEffects.GARBAGE_BIT` in the attack, not `Register.Bit.GARBAGE`.

### Previous story intelligence

- 6.5 (done): `PlayerEffects.RotateRegister`, `bind`, `Register.rotate`, `exclusive` check in `BossController.can_start`, `warning_tell()` pattern in `Hud.warning_tell_on`, `WarningBorder`, the `fired` latch rearmed at TELL entry and kept through RECOVERY. Deferred and relevant here: "PlayerEffects dispatches by has_method ... PlayerCommand base class would fail at parse time (do with 6.6 Reserved Write)"; "Commands pushed before bind are dropped"; "a virtual BossAttack.warning_tell() default false would be tidier" (optional here: add it when `reserved_tell()` is added, if it keeps presentation duck-typing simple); "PlayerEffects dispatches by has_method on Array[RefCounted]".
- 6.4 (done): tile grid and tile attacks; pool shape; data-only tell SFX (D-S64-8); the `·` glyph added through `gen_glyph_font.py` (check `?` and `reserved` glyph coverage the same way); deferred: `touches_player` and tile latch (not used by 6.6).
- 6.3 (done): `SegfaultBody`, `boss_def_path_for(..., segfault_on)`, the leaf guard; the deferred `AccessViolation` guard gap stays open (not touched here).
- 6.1 / 6.2 (done): the combo table and decoy paths; 6.6 relies on `ComboTable.get_combo` returning null for unknown ids; verify, do not assume.
- 5.5 / 5.6 (done): NULL bit BitDef pattern (`data/bits/bit_null.tres`, `Defs.bit` match case); harvest `insert` path (Story 3.8) that must keep rejecting GARBAGE.
- 4.3 (done): `recovery_if_no_breakpoint` (0 = always `recovery`); Reserved Write leaves it at 0.
- 2.5 / 2.6 (done): `shift_serial` resets the ATTACK chain (not used by effects); LinkState close on register change.

### Git intelligence

- Branch `story/6-6-reserved-write-cut-ladder-1` at `b4ce2d0` (sprint status mark for 6.5), stacked on `721d813` (6.5 implementation), `a91f130` (6.4), and earlier 6.1–6.3. Story pattern: data, pure logic in the leaf folder, framework command queue, presentation by method, guard, tests.

### Latest technical information

- Godot 4.7.2-stable (pinned; do not upgrade), GUT 9.6.1, GDScript 2 only. Typed arrays and `signal` only in `EventBus`. `PackedInt32Array` for the ring (already in use). No new APIs needed.

### Project Context Rules

- Read-only defs at runtime; per-fight state (the `fired` latch, the reserved flag, the live temporary-bit counter) lives in the attack or the PlayerEffects queue and is cleared by `reset()` / `on_cancel()` / `clear()`.
- Integer sim state; floats for presentation only (D-S33-2).
- Tells ≥ 20 frames (45 here); `tell_sfx` non-empty; ids unique.
- Red `#FF4040` is reserved for warnings (Breakpoint, SIGSEGV). Reserved Write is ink only.
- Documents in English; code comments follow the `Story X.Y (DECISION-ID)` style.

### Testing standards

- GUT, headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (Godot is not on PATH; use the full path).
- Use the GDD numbers as cases: tell 45; active 600; recovery 30; garbage bit present exactly 600 ticks; 10 seeded runs of phase 3; pool phase 3 only.
- Guards: `bash game/tools/check_guards.sh` (run from the worktree root).
- The Chrome check of the reserved nibble flash and the `?` slot is a human check; record it in Completion Notes, do not fake it in a test.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.6: Reserved Write (Cut Ladder #1)] (ACs, FR44, cut ladder #1)
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements] (AD-12, FeatureFlags, leaf folders; line ~200 and ~1083 for the flag and the Breakpoint wiring pattern)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-github-gameoff-2026-2026-11-06/gdd.md] (Boss 3 attack table, Reserved Write row ~429; register section ~160–175; colour rule ~516; cut ladder ~674–680)
- [Source: _bmad-output/implementation-artifacts/6-5-sigsegv-register-corruption.md] (D-S65-n, PlayerEffects, `bind`, `exclusive`, `warning_tell`)
- [Source: _bmad-output/implementation-artifacts/6-4-corrupted-tiles-corrupt-memory-and-core-dump.md] (D-S64-n, pool shape, data-only tell SFX, glyph additions)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (6.5 section: PlayerCommand base, has_method dispatch, virtual warning_tell)

## Open questions (not blocking)

- D-S66-2: ACTIVE = 600 (GDD table) versus ACTIVE = 1 with the lifetime on the effect (epics wording). Default is 600; both give the same register timeline. Confirm in the 7.8 playtest that a 10-second passive boss window reads well.
- D-S66-3 / D-S66-7: whether a 5th temporary slot reads clearly on the 8-cell panel; the alternative is a dedicated `?` cell. Decide with the Chrome check.
- D-S66-5: NOP timing (the existing `nop.tres` frames) may feel like a dropped input in playtest; tune in 7.8.
- D-S66-6: removing the garbage on defeat is the default; if the 7.8 playtest wants it to persist into the DEFEATED screen, change it there.
- The Chrome check of the reserved nibble flash, the `?` slot and the expiry is pending until a human runs it.

## Dev Agent Record

### Agent Model Used

Claude Opus (gds-dev-story, unattended pipeline, 2026-11-12)

### Debug Log References

- Baseline before changes: 1470/1470 GUT tests green.
- Final (flag on): 1516/1516 green (unit + integration + replay), `check_guards: OK`.
- Flag off (`reserved_write = false` in `data/config/feature_flags.tres`, restored after): 1514/1516; the only 2 failures are `test_feature_flags` asserting the shipped flags are all on (expected); every 6.1–6.5 test and the Segfault fight tests are green.

### Completion Notes List

- GDD check (coordinator rule: GDD / architecture authoritative): the GDD colour rule (red `#FF4040` only for Breakpoint and SIGSEGV) and the Boss 3 table (P3, tell 45 with the `reserved` nibble flashing, 600 frames of `?`, NOP solo and combos, recovery 30) match the story; no design call contradicted them. The flash is ink-only inversion; `Hud.warning_tell_on` stays false during the Reserved Write tell (tested), so the `WarningBorder` red border never shows.
- Architecture notes: the architecture sketches `register_changed(window, register)` and "the register appends `?` with an expiry counter". Implemented per the story: the signal also carries `cause` (D-S66-11) and the expiry counter lives in `PlayerEffects` (the Register only holds the temporary slot), so both insertion and expiry happen in the PLAYER_EFFECTS phase. `EventBus` is `src/autoloads/event_bus.gd` (the story said `src/core/`).
- D-S66-2 (open question, ACTIVE model): kept ACTIVE = 600 (GDD table). It is deterministic and needs no special case: `on_active` pushes once on the first ACTIVE tick (applied that tick), the bit is present exactly 600 ticks and ends on the first RECOVERY tick (PLAYER_EFFECTS, before COMBAT), so the serial FSM and `exclusive` cover the whole garbage window.
- D-S66-3: `Register.temporary` (one slot), `insert_temporary` / `remove_temporary`, `MAX_SLOTS = 5`, `is_ownable()`; `insert()` and `set_fight_start()` reject GARBAGE (and `insert()` refuses while a temporary slot exists); `set_fight_start` clears the slot; `owned_count()` / `byte_value()` count owned bits only. `shift_serial` untouched by insert/remove.
- D-S66-4: the `PlayerCommand` base (`src/bosses/framework/player_command.gd`, `apply(register, link) -> bool`) parses under Godot 4.7.2; the queue is typed `Array[PlayerCommand]` and the `has_method` dispatch is gone (deferred 6.5 item resolved). The 3.1 test that pushed bare `RefCounted` now pushes `PlayerCommand.new()`.
- D-S66-6 (garbage removed on cut and on defeat): `ReservedWrite.on_cancel` calls `PlayerEffects.end_temporary(GARBAGE_BIT)`, which also drops a queued insertion; `PlayerEffects.clear()` (fight start, retry, `reset_for_fight`) ends a live bit too. Phase 3 is the last phase, so in a real fight only a defeat can cut Reserved Write.
- D-S66-7 amended (5 slots on the 8-cell panel, verified in tests): no overflow. A 5-slot ring is drawn in ring order starting one cell left (`RegisterPanel.first_slot_index`), so ring slot 0 takes the last cell of the reserved nibble and `?` sits at its ring position (right end after insertion); hex shows `0x1F`. The `?` is therefore not pinned to the reserved cell as the story wording suggested; ring order keeps the window / previews readable. Confirm in the Chrome check.
- D-S66-8: `Hud.reserved_tell_on` / `reserved_flash_on` (by method, AD-05) with `RESERVED_FLASH_FRAMES = 8`; Main injects `RegisterPanel.reserved_flash_source`; `plan(..., reserved_flash)` inverts the `reserved` label and the 4 reserved-nibble cells.
- AC 3 flag wiring: `Arena.reserved_write_enabled` (read once), `Arena.excluded_attack_ids()` → `BossController.excluded_attack_ids`, skipped in `setup()` before any script is instanced (the shared BossDef is never modified); `Main` calls `set_reserved_write_enabled` at startup; flipping the flag rebuilds the boss on the next fight entry.
- Echo: NOP is `echoable = false`, so a `?` press never becomes Echo's memory (architecture rule).
- Human check pending (not automated, does not block): Chrome check of the phase 3 Reserved Write (the `reserved` nibble flash, the `?` in the ring, the expiry).

### File List

- game/data/bits/bit_garbage.tres (new)
- game/data/bosses/segfault/attack_reserved_write.tres (new)
- game/data/bosses/segfault/boss_def.tres
- game/src/bosses/framework/player_command.gd (new, + .uid)
- game/src/bosses/framework/player_effects.gd
- game/src/bosses/framework/boss_controller.gd
- game/src/bosses/segfault/attacks/reserved_write.gd (new, + .uid)
- game/src/register/register.gd
- game/src/core/defs.gd
- game/src/autoloads/event_bus.gd
- game/src/arena/arena.gd
- game/src/main/main.gd
- game/src/ui/hud/hud.gd
- game/src/ui/hud/register_panel.gd
- game/tools/check_guards.sh
- game/tests/unit/test_reserved_write.gd (new, + .uid)
- game/tests/unit/test_player_effects.gd
- game/tests/unit/test_register.gd
- game/tests/unit/test_register_panel.gd
- game/tests/unit/test_combo_table.gd
- game/tests/unit/test_boss_fallback.gd
- game/tests/unit/test_boss_controller.gd
- game/tests/unit/test_core_dump.gd
- game/tests/unit/test_data_validation.gd
- game/tests/unit/test_font_coverage.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-11-12: Story 6.6 implemented: Reserved Write (P3, 45/600/30, exclusive), garbage bit `?` as a temporary ring slot via `PlayerEffects.InsertTemporaryBit` with expiry in PLAYER_EFFECTS, `register_changed` signal, `PlayerCommand` base, reserved-nibble flash, flag-off pool cut, leaf guard, tests. Status → review.
