---
devlog: 5
title: "Devlog #5: Someone else played it (a tutorial, a fairer ; and a backlog burn-down)"
date: 2026-11-17
covers: 3e16343..5fe7041   # README theme, debug label + flaky test fixes (#64-#66), Epic 8 (#67-#68), Epic 9 (#69-#74), tutorial export hotfix (#75)
itch_url: https://basteez.itch.io/wild-shift/devlog/1786585/devlog-5-someone-else-played-it-a-tutorial-a-fairer-and-a-backlog-burn-down
blog_pr: https://github.com/basteez/basteez.github.io/pull/20
blog_url: https://bstz.it/p/wild-shift-devlog-5/
next_up: "Second playtest round with the tutorial, browser check (Chrome/Firefox/Safari), finding real music (Tiziano can't compose; placeholders still in), jam submission (internal Nov 29 12:00 PST, official Dec 1 13:37 PST)"
images: [tutorial checklist halfway, open semicolon on the Infinite Loop, all tests passed]
---

The first person who isn't me played **The Debugger 0x03: Wild Shift**, and the bug report was short: *"I can't work out what to do."* Fair. A debugger that needs a debugger isn't a great look. So this devlog is about the oldest fix in the book: watching someone use your thing and then rewriting it.

## The playtest (Epic 8)

The first external playtester got further than the bug report suggests. Eventually they worked out that the highlighted `;` wasn't a floppy disk, and they even got the boss to say `// patched` a couple of times. They just didn't know how. After reading the instructions on this page, the next questions were the right ones: *is it vulnerable after it fires? when the `;` is highlighted? do I have to hit it from the inside?*

Two problems hid behind those questions:

- **Nothing taught the controls one at a time.** The duck's tutorial lines showed up in a small bubble *during* the first boss fight, while a spinning loop was trying to eat you. Reading while dodging is not onboarding.
- **The weak spot was hard to read and hard to hit.** The Infinite Loop's `;` is its only weak point, and it was a single inverted character on a ring that spins faster every lap. Missing it gave no feedback at all.

## A tutorial that runs like a test suite

Before Boss 1 there is now a short tutorial, framed as the only thing a programmer trusts: a test suite. You stand in The Clearing next to a training dummy, `{;}`, that never fights back. A checklist sits in the middle of the screen, and each line flips from `[ ]` to `[PASS]` when you actually do the thing:

- `test_move`: walk around.
- `test_actions`: J runs the left live bit, K the right one. A is a slash, D is a dash.
- `test_shift`: Q and E rotate the register until the live bits read `A D`.
- `test_combo`: J then K, fast. That's Dash Strike.
- `test_patch`: dash through the dummy's `;` while it's lit. `// patched`.
- `test_crit`: hit it again while it's patched and watch the damage triple.

When all six pass: `ALL TESTS PASSED.` / `deploying to production...`, and the real fight starts. It only runs on your first run. You can skip it by holding Esc or Backspace, and replay it any time from the title with **[T]**. If you play on a gamepad, the prompts show pad buttons instead of keys.

![](tutorial-checklist.png)
*The tutorial checklist, halfway through the suite.*

![](tutorial-passed.png)
*All six tests passed. Next stop: production.*

## Hitting the `;`

- **A bigger target.** The `;` hitbox is now twice as wide (1 tile instead of half a tile). If you're close enough to look right, you're close enough to count.
- **A clear "open" signal.** While the `;` is open, a marker points at it from inside the ring and a small bar counts down the frames you have left. Closed, it's just a plain glyph.
- **Misses talk back.** Hit the body instead of the `;` and the log tells you why: `// miss: ";" is closed` or `// miss: aim for the ";"`. The answer to "do I have to hit it from the inside?" is now on screen: no, you have to hit the `;`, from any side, while it's open.

![](open-semicolon.png)
*The open `;` (the inverted cell on the left of the ring), with its marker pointing at it from inside.*

## Paying off the backlog (Epic 9)

Every code review in this project writes down what it decided not to fix. After eight epics that list had grown to about 400 lines, so I had all of them checked against the current code. Most were already fixed by later work, needed a human (me, with a browser), or weren't worth it before the deadline. The handful that were real became six small stories:

- **No more accidental starts.** Coming back to the title from the tutorial, the ending or practice, the game ignores input for half a second, so a mashed key doesn't throw you into a new run.
- **[N] asks twice.** Starting a new run now takes a second press (`PRESS N AGAIN: WIPE PROGRESS`). And once you've beaten the game, the title starts a fresh run instead of dropping you back in front of the final boss.
- **Honest assist.** Toggling **[B] debug build** mid-fight now says `NEXT ATTEMPT`, because that's when it applies.
- **Unplug, pause.** If your gamepad disconnects mid-fight, the game pauses instead of letting you die.
- **A tougher save.** If one value in the save file is broken, only that value resets. The rest of your progress survives.
- **Quieter misses.** No miss messages while the loop is blinking out of existence, or for Echo replays.

## How it's made

Same as before: I direct and playtest, AI agents (Claude) write the code from specs I approve with the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD), and every story is a pull request with a code review and automated tests. This time the playtest feedback went straight into new stories: the two Epic 8 stories went from a Slack message to a deployed build on the same day. The suite went from 121 to **131 test files**, and CI now also runs the tests in a shuffled order, which immediately caught a test that only passed because of the order it ran in.

One more bug report came from the screenshots for this very post: in the exported web build the tutorial checklist was invisible. Every test passed, because the tests read the text file directly, while the export quietly emptied three lists of strings on the way into the build. It's fixed, and a new test now scans the code for the pattern that caused it. Lesson re-learned: the build you ship is the only build that counts.

Everything is public in the [GitHub repo](https://github.com/basteez/the-debugger-0x3-wild-shift).

## Next up

More people playing it: a second round of playtests with the tutorial in place, and the browser check (Chrome, Firefox, Safari). Then the music. Confession: I can't compose, and the loops you hear now are still placeholders, so finding real music for three bosses is the next puzzle. Then the jam submission: my internal deadline is November 29, and Game Off itself closes on December 1. The current build is playable on this page, and if you get stuck, that's a bug report I want.

Thanks for reading!
