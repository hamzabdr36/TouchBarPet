# TouchBarPet

A tiny pixel kitten that lives on your MacBook's Touch Bar. It wanders around, naps when you step away, purrs when you tap it and dashes off when you start typing fast.

Built for **[Pock](https://pock.app)**, the free, open-source Touch Bar manager for macOS. TouchBarPet doesn't change Pock itself. It's a widget that installs into Pock's widget folder and appears on the Touch Bar next to Pock's built-in widgets. In Pock it shows up as **Cat**.

**Author:** Hamza Badar ([@hamzabdr36](https://github.com/hamzabdr36))

![The kitten walking, purring, hopping, dashing and napping on the Touch Bar](docs/demo.gif)

On a real Touch Bar, purring after a tap, next to Pock's other widgets:

![Screenshot of the Touch Bar with the kitten purring between Pock's status and Dock widgets](docs/touchbar.png)

## What it does

- **Walks and runs** along the Touch Bar on its own, with a mood that changes over time.
- **Naps when you're away.** After a short idle time it closes its eyes and dozes off with little "z"s, then wakes up when you come back.
- **Reacts to touch.** Tap it and it purrs with hearts. Double-tap and it hops. Tap an empty spot and it walks over. Drag your finger and it follows.
- **Notices typing.** Type fast and it swats, then dashes off.
- **Has its own settings page inside Pock:** nap delay, personality (lazy, normal, playful), walking speed, and which reactions to show.
- **Stays light.** It only redraws when the picture changes, and stops completely when the Touch Bar isn't showing it.

## Requirements

- A MacBook Pro with a Touch Bar
- [Pock](https://pock.app) 0.9
- Xcode Command Line Tools (`xcode-select --install`). Full Xcode isn't needed.

## Get the cat sprites

This project doesn't include the artwork. Download the free **Cat 2D Pixel Art** pack by **Mattz Art** from:

**https://xzany.itch.io/cat-2d-pixel-art**

Put the downloaded zip (`FREE_Cat 2D Pixel Art.zip` or `FULL_Cat 2D Pixel Art.zip`) next to `build.sh`. The build script also checks your Downloads folder. If you've already extracted it, point the script at the `Sprites` folder instead:

```sh
CAT_SPRITES="/path/to/Sprites" ./build.sh --install
```

## Build and install

```sh
./build.sh --install
```

This builds `Cat.pock`, backs up your Pock preferences to `backups/`, installs the widget, adds it to your Touch Bar between Status and the Dock, and relaunches Pock.

To build without installing, run `./build.sh`. To remove the widget, run:

```sh
./build.sh --uninstall
```

The script finds Pock in `/Applications`, `~/Applications` or `~/Downloads`. If yours is somewhere else, set `POCK_APP=/path/to/Pock.app`.

## Settings

Click the Pock icon in the menu bar, then choose **Widgets → Manage widgets…** and select **Cat**.

| Setting | Options |
|---|---|
| Nap after I'm idle for | 15 s to 5 min, or Never (default 45 s) |
| Personality | Lazy, Normal, Playful |
| Walking speed | 50%–150% |
| Reactions | Swat and dash when typing fast, hearts when tapped, "z"s while napping |

Changes apply right away.

## How it works

- **Swift, AppKit and Core Graphics**, compiled with `swiftc`. The widget is a bundle that Pock loads through its `PKWidget` API, and the settings page uses `PKWidgetPreferences`.
- **Pixel-perfect drawing.** Each sprite pixel is drawn as exactly one point, with interpolation turned off, so the kitten stays crisp.
- **A small behavior state machine** (`CatBrain.swift`) picks what the cat does next from weighted choices that depend on its energy and personality.
- **Idle detection** uses `CGEventSource.secondsSinceLastEventType`, so no extra permissions are needed.
- **Closed eyes** for blinking, purring and napping are generated at load time by finding the eye pixels in the idle frames and recoloring them.

| File | Purpose |
|---|---|
| `Sources/CatWidget.swift` | Widget entry point for Pock |
| `Sources/CatView.swift` | Drawing, timer and Touch Bar touches |
| `Sources/CatBrain.swift` | Behavior state machine |
| `Sources/CatSprites.swift` | Loads and slices the sprite sheets, makes the closed-eye frames |
| `Sources/CatSettings.swift` | Settings stored in Pock's preferences |
| `Sources/CatPreferences.swift` | The settings page shown in Pock |

## Credits

- **Cat sprites:** "Cat 2D Pixel Art" by Mattz Art (free version), https://xzany.itch.io/cat-2d-pixel-art. Used and lightly modified (closed-eye frames) under the artist's license. The sprites aren't included in this repository.
- **Pock and PockKit** by Pierluigi Galdi and contributors, MIT license. Two PockKit interface files are included in `vendor/pockkit` to compile against Pock's widget API.

## License

The source code is released under the MIT license; see [LICENSE](LICENSE). The cat artwork isn't covered by it and keeps its own license.

This project isn't affiliated with Pock or Apple. Touch Bar and MacBook are trademarks of Apple Inc.
