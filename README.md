# Plain Launcher

Plain Launcher is a minimal emulation frontend and app launcher built in Godot. It's made for Android handhelds with physical buttons, but it works on your phone too if you are so inclined.

![Example Menu](https://github.com/BokoYoss/plain-launcher/blob/main/screenshots/Screenshot_20231225-024047.png)

## Features

- Built for controllers, with full touch support too.
- Cover art that shows up instantly while you scroll.
- No scanning or importing- put your games in the right folder and they're there. ES-DE folder layouts work out of the box.
- Cover art scraping from ScreenScraper or SteamGridDB.
- Recent, Favorites, and hiding anything you don't want to see.
- Launches Android apps too, so it works as your home launcher.
- PC games through GameNative.
- Pick your font, colors, text size, cover size, and which side the cover goes on.

**Plain Launcher doesn't come with any games or emulators- you'll have to get those yourself. It's just a frontend.**

## Supported systems

NES, SNES, N64, GB, GBC, GBA, NDS, N3DS, PlayStation, PS2, PSP, Genesis, Sega CD, Saturn, Dreamcast, GameCube, Wii, Neo Geo, PC Engine, Arcade, Master System, Neo Geo Pocket, Switch, DOOM, Quake, and PC games through GameNative.

## Supported emulators

RetroArch, DuckStation, PPSSPP, AetherSX2/NetherSX2, Dolphin, Mupen64Plus, Citra/Azahar, Drastic, melonDS, Yabause, Flycast, Redream, Eden, GameNative, and more. You can add your own too- see [Emulators](#emulators).

## Setup

On first launch, pick your confirm button and where Plain Launcher should live (internal storage or an SD card). It creates this:

```
PlainLauncher/
├── Games/GBA/My Game.gba
├── Imgs/GBA/My Game.png
└── Config/GBA/
```

### Games

Put games in `Games/<SYSTEM>/`. Common folders from other frontends (like ES-DE's `ROMs/<system>`) are checked too, and you can add more from a system's options.

### Cover art

Put `.png` images in `Imgs/<SYSTEM>/`, named the same as the game without its extension: `Games/GBA/Apotris (USA).gba` → `Imgs/GBA/Apotris (USA).png`. Android apps use their package name instead, like `Imgs/ANDROID/org.videolan.vlc.png`.

Or open a game's options and use **Find cover art** to scrape it, search the web, or pick an image from your files. Scraping needs a ScreenScraper login or a SteamGridDB key under Settings → Scraper.

### PC games through GameNative

GameNative can export your installed games straight into Plain Launcher. In GameNative, go to Settings → Interface → Frontend Sync and point each store at its folder:

| GameNative store | Folder |
|---|---|
| Steam | `Games/STEAM` |
| Epic Games | `Games/EPIC` |
| GOG | `Games/GOG` |
| Amazon Games | `Games/AMAZON` |
| Custom Games | `Games/PCGAMES` |

No Frontend Sync in your GameNative? Make the file yourself: `Games/STEAM/<Game name>.steam` with the Steam app ID inside (the number in the game's store URL).

## Controls

| Action | Button | Touch |
|---|---|---|
| Confirm | South face (swappable) | On-screen A, or tap the selected row |
| Back | East face (swappable) | On-screen B, or drag left |
| Settings | Start | |
| Options | Select, or hold Confirm | Touch and hold |
| Favorite | X | |

Touching the screen brings up A and B buttons in the corner. Tapping a row selects it. Options works on systems, games, and apps. In any menu, X puts a setting back to its default. Touch can be turned off under Settings → Controls.

## Configuration

### Per-game and per-system settings

Set the emulator, core, and file extensions from a system's or game's options. They're saved to `Config/<SYSTEM>/config.json` and `Config/<SYSTEM>/games/`.

### Names

Use **Custom name** in a game's or system's options to rename it. These are saved to `Config/<SYSTEM>/alias.json` (or `Config/COMMON/alias.json` for systems), so you can also edit them by hand:

```json
{
  "smb": "Super Mario Bros.",
  "smb3": "Super Mario Bros. 3"
}
```

Names leave out the extension and anything in parentheses or brackets, so `smb3 (USA).nes` is just `smb3`.

### Emulators

Each emulator is a JSON file describing the Android intent that launches it:

```json
{
	"action": "android.intent.action.VIEW",
	"componentPackage": "com.example.emu",
	"componentClass": "com.example.emu.EmulatorActivity",
	"data": "{game}",
	"systems": ["GBA", "GBC"]
}
```

`systems` is where it shows up as an option. Optional fields are `data`, `providedFile` (a path shared as a `content://` URI), `type`, `categories`, `flags` (like `FLAG_ACTIVITY_CLEAR_TASK`), and `extras`. Extras take their type from the JSON (`"text"`, `true`, `3`, `1.5`, `["a", "b"]`), or use `{"type": "int", "value": "{game_contents}"}` when a token needs a type. Types are `string`, `int`, `long`, `float`, `double`, `bool`, `uri`, and `string_array`.

| Token | Becomes |
|---|---|
| `{game}` | Full path to the game |
| `{game_uri}` | `content://` URI the emulator can read |
| `{game_saf}` | Storage Access Framework URI for the game |
| `{filename}` / `{basename}` | File name with and without extension |
| `{game_dir}` | Folder the game is in |
| `{game_contents}` | Text inside the game file (first 4 KB), like a Steam app ID |
| `{core}` | RetroArch core for the system or game |
| `{package}` | The emulator's package name |
| `{data_dir}` | `/data/user/<user>/<package>` |
| `{external_storage}` | `/storage/emulated/<user>` |

`{game_saf}` only works if the emulator was given that exact folder in its own folder picker- `ROMs/nds` and `Roms/NDS` count as different. Use `{game}` or `providedFile` when you can.

Built-in emulators come from the app and update with it. Your own go in `Config/COMMON/intents_custom/`- add one under Settings → Launchers → Custom launchers, or copy a built-in from Built-in launchers and tweak it.

### Switching games

Android won't let one app close another, so whether a new game replaces the running one is up to the emulator.

- RetroArch 1.22.0 and newer switch games on their own. If you keep getting the old game back, update RetroArch.
- Settings → Launchers → **Exit RetroArch on focus loss** makes RetroArch quit whenever you leave it. You can't resume, but every launch starts fresh.
- For other emulators, quit the game in the emulator (or swipe it away in recent apps) before picking the next one.

## Building

1. Build [plain-launcher-android-plugin](https://github.com/BokoYoss/plain-launcher-android-plugin) into `addons/` with `setup-plugin.sh` (Linux) or `setup-plugin.bat` (Windows). It needs JDK 17.
2. Open the project in Godot 4.
3. Export for Android with the included preset.

For ScreenScraper in your own builds, copy `secrets.example.json` to `secrets.json` (it's gitignored) and fill in your dev credentials. Without it, ScreenScraper just shows as unavailable.

## Credits

- Fonts are from Google Fonts under the Open Font License. Licenses are in Settings → Credits → Fonts.
- The [Duel](https://lospec.com/palette-list/duel) palette is by [Arilyn](https://lospec.com/arilynart).
- System images are from Evan Amos- check out the awesome [Vanamo Online Game Museum](https://commons.wikimedia.org/wiki/User:Evan-Amos).
