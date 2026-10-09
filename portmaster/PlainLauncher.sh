#!/bin/bash
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi
source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR=/$directory/ports/plainlauncher
CONFDIR="$GAMEDIR/conf"
LAUNCH_FILE="$GAMEDIR/next_launch.sh"
godot_runtime="godot_4.6.3"
godot_executable="godot463.$DEVICE_ARCH"
weston_runtime="weston_pkg_0.2"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
mkdir -p "$CONFDIR"

first_existing() {
  for candidate in "$@"; do
    if [ -e "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
}

RETROARCH_BIN=$(command -v retroarch)
[ -z "$RETROARCH_BIN" ] && RETROARCH_BIN=$(first_existing /usr/local/bin/retroarch /usr/bin/retroarch /opt/retroarch/bin/retroarch)

RETROARCH_CONFIG=$(first_existing \
  /run/muos/storage/info/config/retroarch.cfg \
  /home/ark/.config/retroarch/retroarch.cfg \
  /storage/.config/retroarch/retroarch.cfg \
  /userdata/system/configs/retroarch/retroarchcustom.cfg \
  /userdata/system/.config/retroarch/retroarch.cfg \
  "$HOME/.config/retroarch/retroarch.cfg")

RETROARCH_CORES=""
if [ -d /mnt/mmc/MUOS/core ]; then
  RETROARCH_CORES=/mnt/mmc/MUOS/core
elif [ -n "$RETROARCH_CONFIG" ]; then
  configured=$(sed -n 's/^libretro_directory *= *"\(.*\)"/\1/p' "$RETROARCH_CONFIG" | head -1)
  configured="${configured/#\~/$HOME}"
  [ -d "$configured" ] && RETROARCH_CORES="$configured"
fi
[ -z "$RETROARCH_CORES" ] && RETROARCH_CORES=$(first_existing \
  /home/ark/.config/retroarch/cores /storage/.config/retroarch/cores /tmp/cores /usr/lib/libretro "$HOME/.config/retroarch/cores")

ROMS_DIRS=""
for candidate in "/$directory/ROMS" /roms /roms2 /storage/roms /userdata/roms /mnt/sdcard/ROMS /mnt/mmc/ROMS "/$directory"; do
  [ -d "$candidate" ] || continue
  resolved=$(readlink -f "$candidate")
  case ":$ROMS_DIRS:" in
    *":$resolved:"*) ;;
    *) ROMS_DIRS="$ROMS_DIRS:$resolved" ;;
  esac
done
ROMS_DIRS="${ROMS_DIRS#:}"

ART_DIR=$(first_existing /run/muos/storage/info/catalogue)

APPS_DIRS=""
for candidate in "$controlfolder" /mnt/mmc/MUOS/application /opt/system/Tools; do
  [ -d "$candidate" ] && APPS_DIRS="$APPS_DIRS:$candidate"
done
APPS_DIRS="${APPS_DIRS#:}"

echo "CFW: $CFW_NAME"
echo "RetroArch: $RETROARCH_BIN, config: $RETROARCH_CONFIG, cores: $RETROARCH_CORES"
echo "ROMs: $ROMS_DIRS"

for rt in "$weston_runtime" "$godot_runtime"; do
  if [ ! -f "$controlfolder/libs/${rt}.squashfs" ]; then
    pm_message "Missing the ${rt} runtime. Reinstall Plain Launcher from PortMaster with Wi-Fi on."
    sleep 5
    exit 1
  fi
done

weston_dir=/tmp/weston
godot_dir=/tmp/godot
$ESUDO mkdir -p "$weston_dir" "$godot_dir"
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$weston_dir" 2>/dev/null
  $ESUDO umount "$godot_dir" 2>/dev/null
fi
$ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "$weston_dir"
$ESUDO mount "$controlfolder/libs/${godot_runtime}.squashfs" "$godot_dir"

controller_env=""
if [ "$CFW_NAME" = "muOS" ] || [ "${CFW_NAME,,}" = "knulli" ]; then
  controller_env="SDL_GAMECONTROLLERCONFIG=19000000010000000100000000010000,ANBERNIC-keys-godot,a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:b9,righttrigger:b10,back:b6,start:b7,guide:b11,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,platform:Linux,"
fi

cd "$GAMEDIR"
while true; do
  rm -f "$LAUNCH_FILE"
  $GPTOKEYB "$godot_executable" &
  $ESUDO env "$weston_dir/westonwrap.sh" headless noop kiosk crusty_x11egl \
    env $controller_env XDG_DATA_HOME="$CONFDIR" \
    PLAIN_LAUNCHER_COMMANDS=1 PLAIN_LAUNCHER_PLATFORM=portmaster PLAIN_LAUNCHER_SYNC_LOADING=1 PLAIN_LAUNCHER_CFW="$CFW_NAME" PLAIN_LAUNCHER_ESUDO="${ESUDO%% *}" \
    PLAIN_LAUNCHER_ROOT="$GAMEDIR/PlainLauncher" PLAIN_LAUNCHER_ROMS="$ROMS_DIRS" PLAIN_LAUNCHER_ART="$ART_DIR" PLAIN_LAUNCHER_APPS_PATHS="$APPS_DIRS" \
    PLAIN_LAUNCHER_LAUNCH_FILE="$LAUNCH_FILE" PLAIN_LAUNCHER_OVERRIDE="$GAMEDIR/override.cfg" RETROARCH_BIN="$RETROARCH_BIN" RETROARCH_CONFIG="$RETROARCH_CONFIG" RETROARCH_CORES="$RETROARCH_CORES" \
    "$godot_dir/$godot_executable" --resolution "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" -f \
    --rendering-driver opengl3_es --audio-driver ALSA --main-pack "$GAMEDIR/plainlauncher.pck"
  $ESUDO "$weston_dir/westonwrap.sh" cleanup
  pm_gptokeyb_finish
  [ -f "$LAUNCH_FILE" ] || break
  echo "Launching: $(cat "$LAUNCH_FILE")"
  bash "$LAUNCH_FILE"
done

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$weston_dir"
  $ESUDO umount "$godot_dir"
fi
pm_finish
