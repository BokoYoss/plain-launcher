#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

out=output/portmaster
port="$out/plainlauncher"
[ -f "$port/plainlauncher.pck" ] || { echo "Export the Linux PortMaster preset first"; exit 1; }

cp portmaster/PlainLauncher.sh "$out/Plain Launcher.sh"
cp portmaster/plainlauncher/* "$port/"
rm -rf "$port/licenses"
mkdir -p "$port/licenses"
cp LICENSE "$port/licenses/LICENSE.PlainLauncher.txt"
for font in launcher_configs/COMMON/fonts/*/; do
  cp "$font/OFL.txt" "$port/licenses/LICENSE.$(basename "$font").txt"
done

rm -f output/PlainLauncher-portmaster.zip
(cd "$out" && zip -qr ../PlainLauncher-portmaster.zip "Plain Launcher.sh" plainlauncher)
echo "output/PlainLauncher-portmaster.zip"
