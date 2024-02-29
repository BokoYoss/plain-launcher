# Plain Launcher
Plain Launcher is an Android emulation frontend and app launcher written in Godot.

![Example Menu](https://github.com/BokoYoss/plain-launcher/blob/main/screenshots/Screenshot_20231225-024047.png)

### Features
- Controller support as primary means of navigation. Touch control is fully supported as well.
- Cover art for games, displaying instantly on scroll. No need to wait for covers to load... in theory.
- Adding games is as easy as adding/removing your game files in the right place- no need to scan or import.
- Add/remove favorites with the tap of a button
- Hide/unhide anything with the tap of a button (You can always go to Settings->Visual->Show Hidden if you accidentally hide something you didn't want to)
- Visual settings for palette selection, font selection, cover borders, drop shadows, and more!
- Full support for launching Android applications (you could use this as your primary launcher on your phone, if you were so inclined, but it is intended for Android-based handhelds)
- Per-system and per-game emulation configuration for setting cores or apps.
- Support for launching Retroarch (multiple versions), PPSSPP, AetherSX2, Dolphin, and more coming soon!
- Look up and download cover art easily from the menu!
- Configure game storage paths on a per-system basis

 ![Example color picker](https://github.com/BokoYoss/plain-launcher/blob/main/screenshots/Screenshot_20231225-024111.png)
 
### Instructions

#### Storage
1. After starting the app, you will be prompted to set what button is Confirm on your controller ("X" styled south face button vs. "A" styled east face button). You can always swap this in settings later.
2. Next, you need to set a home directory for Plain Launcher. You can choose to use internal storage, try an external card, or pick somewhere else (this last option is not as well-tested as the first two, which are recommended). After choosing a location, Plain Launcher will set up Imgs, Games and Config directories. If you selected on-device or removable storage, these will be under a top-level PlainLauncher directory.
3. Populate the Games directory and Imgs directory with your game backups. The directories should be self-explanatory. Image files must be `.png` and match the file name of your game *without the extension*. For example, you might configure your games and images like so:

```
PlainLauncher/
 >Imgs/
  >GB/
   >Blue Bayou.png
 >Games/
  >GB/
   >Blue Bayou.gb
```

#### Controller bindings
- Confirm: Right face button for "N" style controls, bottom face button for "X" style controls.
- Back: Bottom face button for "N" style controls, right face button for "X" style controls.
- Pressing "Back" in the "Systems" menu takes you to Plain Launcher settings.
- Options: Hold Confirm and release
- In the "Systems" menu, this will take you to options for that specific game system
- In the games or android menu, this will take you to per-game options
- Toggle favorite: Start
- Cycle size: LB
- Cycle cover art size: RB
- Cycle cover border: L3
- Cycle drop shadow: R3

#### Touch controls
- Confirm: Tap anywhere
- Back: Drag from right to left and release
- Scroll once: Swipe up or down anywhere
- Scroll multiple: Drag up or down and hold position
- Options: Drag right and release

#### Cover Art

- You can search for cover art online from a game's options menu.
- Cover art isn't just for games- you can add it to Android or System items as well!
- Art needs to be a png file
- Art should be named the same as the game file it is associated with, without the game file extension. For example, if I have the game file PlainLauncher/Games/GBA/Apotris (USA).gba, I would put the matching artwork in PlainLauncher/Imgs/GBA/Apotris (USA).png


### Building
1. Requires the addon [plain-launcher-android-plugin](https://github.com/BokoYoss/plain-launcher-android-plugin) and add the addon to `addons/`. This has been automated for windows users with `setup-plugin.bat`

### Credits

- All fonts are from Google fonts, licensed under the Open Font License. See in-game licenses under Settings->Credits->Fonts
- [Duel](https://lospec.com/palette-list/duel) color palette for the color picker was created by [Arilyn](https://lospec.com/arilynart) on Lospec.
- Included system images are from Evan Amos- check out the awesome [Vanamo Online Game Museum](https://commons.wikimedia.org/wiki/User:Evan-Amos)

