# Plain Launcher
Plain Launcher is an Android emulation frontend and app launcher written in Godot.

### Features
- Designed from the ground up for controllers. In fact, you need a controller to use this frontend!
- Minimalist interface with just titles and boxarts
- Android home launcher support, launch a game then return with a home button on your device
- Add and remove favorite games with the press of a button
- Support for internal storage and removable storage such as SD Cards (external card support only on Android 11+ currently)
- Customizable background and foreground colors
- No need to import or scan files, just put them at the directory and they show up.

### Instructions
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

### Building
1. Requires the addon [plain-launcher-android-plugin](https://github.com/BokoYoss/plain-launcher-android-plugin) and add the addon to `addons/`. This has been automated for windows users with `setup-plugin.bat`

### Credits
Font is [Rubik](https://fonts.google.com/specimen/Rubik) from Google fonts, licensed under the SIL Open Font License.

Color picker palette is [Duel](https://lospec.com/palette-list/duel) by [Arilyn](https://twitter.com/ArilynArt)

Aesthetic inspiration from the Linux frontend [MinUI](https://github.com/shauninman/MinUI) by shauniman

