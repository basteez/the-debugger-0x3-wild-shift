# Playtest: full run (Story 7.8)

Harness for the human full-run playtest (Story 7.8, NFR9, NFR11, NFR13, NFR14, GDD Success Metrics >
Gameplay Metrics). Authored empty by the dev agent (D-S78-10): Tiziano / the facilitator fill the result
cells after each session. Human checks H-S78-1..4 are tracked in `deferred-work.md`.

## 1. Protocol

- **Testers**: first-time players only. Never the director, and never anyone who has already seen the build.
  Target: at least 3 testers by Nov 27 (H-S78-1).
- **Build**: the release web build (CI artifact or the itch page), with no `?debug` in the URL. Record the
  commit hash and the URL in the tester section.
- **Start**: every full run starts fresh with `[N]` new run (or a cleared save), so `full_run_s` covers the whole
  run. A resumed run's `full_run_s` only covers the bosses after resuming: do not use it in the aggregate.
  The tester starts at the title screen. No help beyond the duck; the facilitator gives no hints
  during play. Skipping the Intro is allowed.
- **Metrics**: open the browser devtools console (F12) before the run. The game prints `[metrics]` lines
  (`Log.info`, also in release builds). Paste them verbatim into the tester section at the end of the run:

  ```
  [f=<frame>][INFO][metrics] first_shift_s=12.4
  [f=<frame>][INFO][metrics] boss 1 cleared_s=87.3 deaths=2 assist=false
  [f=<frame>][INFO][metrics] run full_run_s=742.9 hits=31 assist=false debug_jumped=false bosses=[1:87.3/2, 2:131.0/1, 3:176.2/3]
  ```

  - `first_shift_s`: seconds from the first title input (Intro included, GDD D-040) to the first player
    shift in a fight. Only the first shift of a run is logged. A run resumed from the save has no Intro and
    still logs it from the resume input.
  - `boss N cleared_s`: seconds from the first FIGHT entry of boss N to its finished defeat, all retries
    included; HARVEST before and after is excluded. `deaths` = deaths on that boss in this run.
  - `run full_run_s`: seconds from the first title input to the Ending. Pauses are excluded everywhere
    (sim frames stop while paused). `bosses=[index:clear_s/deaths, ...]` lists cleared bosses only.
  - Practice runs (title `[P]`) never print `[metrics]` lines.
- **Attempts** per boss = deaths on that boss + 1 (the clearing attempt) (D-S78-9).
- **After the run**, ask in this order (do not lead): 1) "What did you think of the game?" (note whether the
  shift is mentioned unprompted, with a quote); 2) "How did the shift feel, 1 to 5?".
- **Null Pointer checks** (D-S78-7, H-S78-2), a facilitator observation per tester:
  - Sound alone: headphones on, screen covered during a Null Pointer phase; ask the tester to point to
    where the boss is. Yes / no plus a quote.
  - Sight alone: mute with `[M]`; ask the same. Yes / no plus a quote.
- **Excluded from the aggregate** (D-S78-6): runs with `assist=true` or `debug_jumped=true`. Record them in
  their own tester section anyway (assist sessions still feed the H-S74-2 fair-tells check).

## 2. Metric table

Filled from the aggregate (section 4).

| Metric | Target | Result | Pass / Fail | Notes |
|---|---|---|---|---|
| First shift | <= 30 s | | | |
| Full run | 600-900 s (10-15 min) | | | |
| Boss 1 (Infinite Loop) clear | 60-120 s | | | |
| Boss 2 (Null Pointer) clear | 120-150 s | | | |
| Boss 3 (Segfault) clear | 150-210 s | | | |
| Shift feel | >= 4/5 (mean) | | | |
| Shift mentioned unprompted | >= 50% of testers | | | |
| Null Pointer locatable by sound alone | n/N (report) | | | |
| Null Pointer locatable by sight alone | n/N (report) | | | |
| First Patch with Dash Strike | >= 80% of testers | | | |
| Boss 1 cleared within 3 attempts | >= 80% of testers | | | |
| 3 consecutive full runs, zero blocking bugs | 0 blocking bugs | | | see section 6 |

## 3. Per-tester sections

### Tester 1

| Field | Value |
|---|---|
| Date | |
| Facilitator | |
| Build (commit hash / itch URL or CI artifact; `?debug` absent) | |
| Browser / platform | |
| Input device (keyboard / Xbox pad / PS pad) | |
| Assist (on / off) | |
| Debug-jumped (`debug_jumped=` in the run line) | |
| Counted in the aggregate? (no if assist on or debug-jumped, D-S78-6) | |
| First shift (s, `first_shift_s`) | |
| Full run (s, `full_run_s`) | |
| Boss 1 Infinite Loop: clear s / deaths / attempts | |
| Boss 2 Null Pointer: clear s / deaths / attempts | |
| Boss 3 Segfault: clear s / deaths / attempts | |
| First Patch with Dash Strike (yes / no) | |
| Boss 1 cleared within 3 attempts (yes / no) | |
| Shift feel (1-5, asked after the run) | |
| Shift mentioned unprompted (yes / no + quote) | |
| Null Pointer locatable by sound alone (yes / no + quote) | |
| Null Pointer locatable by sight alone (yes / no + quote) | |
| Blocking bugs (none / list) | |

Notes:

-

Pasted `[metrics]` lines (verbatim, from the devtools console):

```
```

### Tester 2

| Field | Value |
|---|---|
| Date | |
| Facilitator | |
| Build (commit hash / itch URL or CI artifact; `?debug` absent) | |
| Browser / platform | |
| Input device (keyboard / Xbox pad / PS pad) | |
| Assist (on / off) | |
| Debug-jumped (`debug_jumped=` in the run line) | |
| Counted in the aggregate? (no if assist on or debug-jumped, D-S78-6) | |
| First shift (s, `first_shift_s`) | |
| Full run (s, `full_run_s`) | |
| Boss 1 Infinite Loop: clear s / deaths / attempts | |
| Boss 2 Null Pointer: clear s / deaths / attempts | |
| Boss 3 Segfault: clear s / deaths / attempts | |
| First Patch with Dash Strike (yes / no) | |
| Boss 1 cleared within 3 attempts (yes / no) | |
| Shift feel (1-5, asked after the run) | |
| Shift mentioned unprompted (yes / no + quote) | |
| Null Pointer locatable by sound alone (yes / no + quote) | |
| Null Pointer locatable by sight alone (yes / no + quote) | |
| Blocking bugs (none / list) | |

Notes:

-

Pasted `[metrics]` lines (verbatim, from the devtools console):

```
```

### Tester 3

| Field | Value |
|---|---|
| Date | |
| Facilitator | |
| Build (commit hash / itch URL or CI artifact; `?debug` absent) | |
| Browser / platform | |
| Input device (keyboard / Xbox pad / PS pad) | |
| Assist (on / off) | |
| Debug-jumped (`debug_jumped=` in the run line) | |
| Counted in the aggregate? (no if assist on or debug-jumped, D-S78-6) | |
| First shift (s, `first_shift_s`) | |
| Full run (s, `full_run_s`) | |
| Boss 1 Infinite Loop: clear s / deaths / attempts | |
| Boss 2 Null Pointer: clear s / deaths / attempts | |
| Boss 3 Segfault: clear s / deaths / attempts | |
| First Patch with Dash Strike (yes / no) | |
| Boss 1 cleared within 3 attempts (yes / no) | |
| Shift feel (1-5, asked after the run) | |
| Shift mentioned unprompted (yes / no + quote) | |
| Null Pointer locatable by sound alone (yes / no + quote) | |
| Null Pointer locatable by sight alone (yes / no + quote) | |
| Blocking bugs (none / list) | |

Notes:

-

Pasted `[metrics]` lines (verbatim, from the devtools console):

```
```

### Tester 4 (spare)

| Field | Value |
|---|---|
| Date | |
| Facilitator | |
| Build (commit hash / itch URL or CI artifact; `?debug` absent) | |
| Browser / platform | |
| Input device (keyboard / Xbox pad / PS pad) | |
| Assist (on / off) | |
| Debug-jumped (`debug_jumped=` in the run line) | |
| Counted in the aggregate? (no if assist on or debug-jumped, D-S78-6) | |
| First shift (s, `first_shift_s`) | |
| Full run (s, `full_run_s`) | |
| Boss 1 Infinite Loop: clear s / deaths / attempts | |
| Boss 2 Null Pointer: clear s / deaths / attempts | |
| Boss 3 Segfault: clear s / deaths / attempts | |
| First Patch with Dash Strike (yes / no) | |
| Boss 1 cleared within 3 attempts (yes / no) | |
| Shift feel (1-5, asked after the run) | |
| Shift mentioned unprompted (yes / no + quote) | |
| Null Pointer locatable by sound alone (yes / no + quote) | |
| Null Pointer locatable by sight alone (yes / no + quote) | |
| Blocking bugs (none / list) | |

Notes:

-

Pasted `[metrics]` lines (verbatim, from the devtools console):

```
```

### Tester 5 (spare)

| Field | Value |
|---|---|
| Date | |
| Facilitator | |
| Build (commit hash / itch URL or CI artifact; `?debug` absent) | |
| Browser / platform | |
| Input device (keyboard / Xbox pad / PS pad) | |
| Assist (on / off) | |
| Debug-jumped (`debug_jumped=` in the run line) | |
| Counted in the aggregate? (no if assist on or debug-jumped, D-S78-6) | |
| First shift (s, `first_shift_s`) | |
| Full run (s, `full_run_s`) | |
| Boss 1 Infinite Loop: clear s / deaths / attempts | |
| Boss 2 Null Pointer: clear s / deaths / attempts | |
| Boss 3 Segfault: clear s / deaths / attempts | |
| First Patch with Dash Strike (yes / no) | |
| Boss 1 cleared within 3 attempts (yes / no) | |
| Shift feel (1-5, asked after the run) | |
| Shift mentioned unprompted (yes / no + quote) | |
| Null Pointer locatable by sound alone (yes / no + quote) | |
| Null Pointer locatable by sight alone (yes / no + quote) | |
| Blocking bugs (none / list) | |

Notes:

-

Pasted `[metrics]` lines (verbatim, from the devtools console):

```
```

## 4. Aggregate

Computed from the counted sessions only (no assist, no debug jump).

| Metric | T1 | T2 | T3 | T4 | T5 | Mean / share |
|---|---|---|---|---|---|---|
| First shift (s) | | | | | | |
| Full run (s) | | | | | | |
| Boss 1 clear (s) | | | | | | |
| Boss 2 clear (s) | | | | | | |
| Boss 3 clear (s) | | | | | | |
| Boss 1 deaths | | | | | | |
| Boss 2 deaths | | | | | | |
| Boss 3 deaths | | | | | | |
| Shift feel (/5) | | | | | | |
| Shift mentioned unprompted | | | | | | |
| Null Pointer by sound alone | | | | | | |
| Null Pointer by sight alone | | | | | | |
| First Patch with Dash Strike | | | | | | |
| Boss 1 within 3 attempts | | | | | | |

## 5. Tuning log

Applied only after the sessions (H-S78-4), only in `.tres` files under `game/data/`, in GDD order: bosses in
order (Infinite Loop, Null Pointer, Segfault), and within each boss the NFR13 knob order (boss HP, tell,
recovery, gap); player HP last. The x0.5 / x1.5 multipliers are never changed. Each change links its
evidence (metric row + tester / session). After the pass: `check_build_size.sh`, `check_guards.sh` and GUT
re-run.

| # | Boss / stage | File (game/data/...) | Key | Old | New | Reason (metric row + session) | Applied by | Date |
|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | |
| 2 | | | | | | | | |
| 3 | | | | | | | | |

## 6. Final runs

Three consecutive full runs on the final build (after tuning), zero blocking bugs (H-S78-3).

| Run | Date | Build (commit / URL) | Outcome (Ending reached? `full_run_s`) | Blocking bugs (none / list) |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

## 7. Open issues

Non-blocking findings carried to 7.9 or the fallback list.

-
