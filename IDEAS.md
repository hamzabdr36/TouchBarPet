# Ideas for later

## A desktop home for the cat

**Status:** saved for later (2026-11-20). Nothing is built yet.

### Concept
The kitten can leave the Touch Bar and live in a small home on the desktop, then come back.
The Cat widget already runs inside Pock, so it can open the home as a borderless window itself.
No new app and no extra permissions are needed.

- **Send home:** the kitten does its running-jump animation off the Touch Bar, up into the home.
- **While it's away:** the cat's spot on the Touch Bar shows a tiny house icon.
- **Call back:** it jumps down from the home onto the Touch Bar.

### Decided
- **Send home:** press and hold the cat on the Touch Bar for about 0.5 s.
- **Call back:** tap the house icon on the Touch Bar.

### Still to decide: home style
| Style | What it is | Notes |
|---|---|---|
| **Cozy room** (recommended) | A small window (about 230×170 pt) with a bed, food bowl, yarn ball and a window that shows day or night from the clock | Lightest, and the most alive: the cat walks and naps in bed |
| Free roam | The cat walks along the bottom of the screen in a small moving window and naps on a cushion in the corner | A bit more CPU and GPU; it passes over other windows |
| Cardboard box | An open box on the desktop; the cat peeks out and naps inside | Smallest; no walking |
| Desktop shelf | A wooden shelf above the Dock with a plant | Fixed spot |
| Menu-bar nook | A cat icon in the menu bar that drops down a small home | Hidden until clicked |
| Both | Cozy room plus free roam, chosen in the Cat settings | |

### Optional extras
- More ways to move the cat: a keyboard shortcut (for example ⌃⌥C), napping at home automatically while
  you're idle, double-clicking or right-clicking in the home, a Pock menu item.
- Drag the home anywhere and have it remember its position.
- Keep the home behind windows (like a desktop widget) or on top of them.
- Day/night window that follows the clock, with more naps late at night.
- Sizes at 2×, 3× or 4× only, so the pixel art stays crisp.
- Clicks pass through everywhere except the cat. Hide during full-screen apps and screen sharing.
- Later: a food bowl to fill, a yarn ball to chase, unlockable toys.
- A "Home" section in the Cat settings page (style, size, behind or on top).

### Performance (estimates, to be measured once built)
Measured baseline (2026-11-20): Pock uses about 2% of one core with the Touch Bar cat running.

| | CPU while walking | CPU while napping | GPU |
|---|---|---|---|
| Cozy room (static room, only the cat redraws) | about 0.3–1% | under 0.2% | about 0% |
| Free roam (small cat-sized moving window) | about 0.5–1.5% | under 0.2% | about 1–2% |
| Never do this: a full-screen transparent window redrawn every frame | about 3–8% | about 1–3% | about 5–15% |

Either way, the Touch Bar cat stops drawing while it's away (0%), and nothing draws while the home
is hidden or the Mac is asleep.

### Implementation sketch
- `CatHomeWindow` (NSPanel: borderless, transparent, non-activating, level `.normal`, or desktop level
  for "behind windows") owned by `CatWidget`.
- Reuse `CatSprites` (draw at 3×) and `CatBrain` (a "home" mode with its own bounds and a bed position).
- `CatView`: on a 0.5 s hold, start the leap and hand the cat to the home window. While away, draw the
  house icon and treat a tap on it as "call back".
- Save the home's position and style in Pock's defaults (`Cat.home.*` keys).
