# Plain Launcher

Plain Launcher is a minimal emulation frontend and app launcher built in Godot. It is primarly designed for Android-based handhelds with physical buttons, but can work on your phone if you are so inclined.

![Example Menu](https://github.com/BokoYoss/plain-launcher/blob/main/screenshots/Screenshot_20231225-024047.png)

## Features

- **Controller-friendly navigation** with full touch support
- **Instant cover art** — images display as you scroll
- **Zero-import game library** — just drop files in the right folder, no scanning needed. Out-of-the-box support for common directory structures like ES-DE.
- **Automatic cover art scraping** via ScreenScraper or SteamGridDB
- **Recent games** — a built-in Recent system tracks your play history
- **Custom display names** via alias files. Common aliases (i.e. for Arcade files) are included out of the box.
- **Full Android app launching** — usable as a home launcher.
- **Extensive visual customization** — color palette, font, cover size/position/opacity/border, drop shadows, title style, margins, and more

## Supported Systems

NES, SNES, N64, GB, GBC, GBA, NDS, N3DS, PlayStation, PS2, PSP, Genesis, Sega CD, Saturn, Dreamcast, GameCube, Wii, Neo Geo, PC Engine, Arcade, Master System, Neo Geo Pocket, Switch, DOOM, Quake

## Supported Emulators

RetroArch (standard, 64-bit, 32-bit), DuckStation, PPSSPP, PPSSPP Gold, AetherSX2, Dolphin, Mupen64Plus (and AE, FZ, FZ Pro variants), Citra, Drastic, Yabause, Flycast, Redream, Azahar, Eden, Skyline, and more

**Note that Plain Launcher does not provide any game files or emulators itself- you'll have to get those on your own. Plain Launcher is merely a frontend.**

---

## Setup

### 1. First launch

On first launch you'll be asked to choose your confirm button layout (south-face vs east-face style). You can change this later under Settings → Controls.

Then set a home directory. You can pick the internal storage of your devices or an external storage path. Plain Launcher will create the following structure there:

```
PlainLauncher/
├── Games/
│   └── GBA/
│       └── My Game.gba
├── Imgs/
│   └── GBA/
│       └── My Game.png
└── Config/
	└── GBA/
		└── config.json
```

### 2. Adding games

Place game files in `PlainLauncher/Games/<SYSTEM>/`. Plain Launcher picks them up automatically.

You can also add additional file paths for games, and Plain Launcher comes with some common ones enabled that follow the format of other launchers. For example- you should be able to keep your ES-DE directory setup as-is and have Plain Launcher pick it up!

### 3. Cover art

Place cover art in `Imgs/<SYSTEM>/`. Images must be `.png` and named to match the game file without its extension.

**Example:** `Games/GBA/Apotris (USA).gba` → `Imgs/GBA/Apotris (USA).png`

Cover art works for Android apps and system entries too, not just games.

## Cover Art Scraping

From any game or system's options menu, select **Scrape artwork** (single game) or **Scrape all artwork** (whole system). You'll be asked which backend to use:

- **ScreenScraper** — matches by filename against the ScreenScraper database
- **SteamGridDB** — searches by game name; useful for games not in ScreenScraper

Set your credentials under **Settings → Scraper** before scraping.

Alternatively, you can look up cover art via the browser with the **Look for cover art..** option- for those boxarts that fail to scrape!
---

## Controls

### Controller

| Action | Button |
|--------|--------|
| Confirm | South face button (configurable) |
| Back | East face button (configurable) |
| Options | North face button / hold Confirm |
| Toggle favorite | Start |

- **Back** from the Systems screen opens Settings
- **Options** on a system folder opens system-level settings
- **Options** on a game opens per-game settings

### Touch

| Action | Gesture |
|--------|---------|
| Confirm | Tap |
| Back | Drag left and release |
| Scroll | Swipe or drag up/down |
| Options | Drag right and release |

---

## Configuration

### Per-game and per-system settings

Open the options menu on any game or system to configure the emulator, core, and file extension used to launch it. Settings are saved to `Config/<SYSTEM>/config.json`.

### Custom display names (aliases)

Create `Config/<SYSTEM>/alias.json` to map filenames to display names:

```json
{
  "smb.nes": "Super Mario Bros.",
  "smb3.nes": "Super Mario Bros. 3"
}
```

`Config/COMMON/alias.json` applies to the systems list itself.

### Additional art paths

From a system's options menu, set an **Additional art path** to look up cover images from a second directory when none is found in the default `Imgs/<SYSTEM>/` location.

### Additional game paths

From a system's options menu, add extra directories to merge into the game list alongside the default `Games/<SYSTEM>/` folder. By default, common paths for other frontends are included.

---

## Building

1. Install the [plain-launcher-android-plugin](https://github.com/BokoYoss/plain-launcher-android-plugin) into `addons/`. Windows users can run `setup-plugin.bat` to do this automatically.
2. Open the project in Godot 4.
3. Export for Android using the included export preset.

### Developer secrets

To use the ScreenScraper API during development, create `secrets.json` in the project root (gitignored):

```json
{
  "SS_DEVID": "your_devid",
  "SS_DEVPASS": "your_devpassword",
  "SS_SOFT_NAME": "your_software_name"
}
```

See `secrets.example.json` for the template. Without this file the app runs normally — ScreenScraper will simply show as unavailable.

---

## Credits

- Fonts from [Google Fonts](https://fonts.google.com/), licensed under the Open Font License. See in-app licenses under Settings → Credits → Fonts.
- [Duel](https://lospec.com/palette-list/duel) color palette by [Arilyn](https://lospec.com/arilynart) on Lospec.
- System images by Evan Amos — [Vanamo Online Game Museum](https://commons.wikimedia.org/wiki/User:Evan-Amos).
