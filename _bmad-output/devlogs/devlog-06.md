---
devlog: 6
title: "Devlog #6: I couldn't find my own @ (turning the background down)"
date: 2026-11-17
covers: 5fe7041..2663f95   # Devlog #5 record (#76), Story 9.7 arena readability (#77)
itch_url: TBD (filled on itch, not yet published)
blog_pr: https://github.com/basteez/basteez.github.io/pull/21
blog_url: https://bstz.it/p/wild-shift-devlog-6/
next_up: "Second playtest round, browser check (Chrome/Firefox/Safari), real music, jam submission (internal Nov 29 12:00 PST, official Dec 1 13:37 PST)"
images: [before: tutorial blends into scenery, after: dithered scenery + tutorial in console, Segfault SIGSEGV INCOMING tell under the title bar]
---

Small devlog, one bug: **I couldn't find my own player.** I was looking at screenshots of the tutorial and kept losing the `@` in the grass. When everything on screen is the same white glyph on the same black background, the player, the bosses, the tutorial text and the scenery all shout at the same volume. So this update turns the background down.

%%IMG1%%
*Before: the `@`, the dummy, the checklist and the hints all blend into the grass.*

## Turning the background down

The game uses two colours, ink and near-black, and that isn't changing. What I can change is how much ink each thing gets.

- **The scenery is dithered.** Grass, rocks and water now keep one pixel in four. They read as texture, and everything drawn in full ink (you, the bosses, the tree ring around the arena) comes forward on its own.
- **Water is `=` now.** The old `~` turned into a row of slashes once it was dithered, which looked like rain. `=` dithers into a calm double line, and it's also very much a programming language.
- **Actors get some room.** Grass never grows right next to you or a boss: the ground around every actor is cleared, so nothing touches their outline.

%%IMG2%%
*After: the tutorial lives in the console, and the arena only has what you need to fight.*

## Text goes where text belongs

The tutorial checklist (`[PASS] test_move`…) was drawn in big letters right on the battlefield. But it's literally the output of a test runner, so now it runs where test runners print: in the **console** under the arena. The checklist sits on the left, the current instruction on the right, and your hits (`console.log("-10")`, `CRITICAL: 30 dmg`) scroll under it. The practice mode's frame counter moved there too.

## The top bar

The two lines at the top of the screen were easy to miss, and it turned out there was a reason: the pixel font has no space above its capitals, so the first row sat flush against the edge of the screen and looked cut off. The boss signature and your `hp: 0b11111` are now an inverted title bar, like an IDE tab. The comment under it got a line for each mode too, so the tutorial says `// TODO: write the tests first`.

%%IMG3%%
*Segfault's `SIGSEGV INCOMING` warning now gets its own inverted strip under the title bar.*

## How it's made

Same as before: I direct and playtest, AI agents (Claude) write the code from specs I approve with the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD), and every story is a pull request with a code review and automated tests (**132 test files** now). This one started as a quick prototype that I could look at before anything was planned, and two rounds of "still too busy" later it became a story. Lesson from the last devlog applied: every step was checked in the exported web build, not just in the tests. That's how the sky comment got un-dithered again: at 1x, dithered text simply turns into dots.

Everything is public in the [GitHub repo](https://github.com/basteez/the-debugger-0x3-wild-shift).

## Next up

Still the same list, now with a calmer screen: a second round of playtests, the browser check (Chrome, Firefox, Safari), real music to replace my placeholder loops, and the jam submission (my target is November 29, Game Off closes December 1). The new build is live on this page. If you lose the `@` again, tell me.

Thanks for reading!
