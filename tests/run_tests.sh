#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp project.godot "$tmp/project.godot"

if [ ! -f .godot/global_script_class_cache.cfg ] || [ -n "$(find scenes tests -name '*.gd' -newer .godot/global_script_class_cache.cfg | head -1)" ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
fi

XDG_DATA_HOME="$tmp/data" PLAIN_LAUNCHER_COMMANDS=0 "$GODOT" --headless --path . -s tests/test_runner.gd 2>&1 | tee "$tmp/out.log"
status=${PIPESTATUS[0]}

if ! cmp -s project.godot "$tmp/project.godot"; then
	cp "$tmp/project.godot" project.godot
	echo "NOTE: restored project.godot after Godot rewrote it"
fi

if sed -n '/=== TESTS START ===/,$p' "$tmp/out.log" | grep -q "SCRIPT ERROR"; then
	echo "FAIL: script errors during tests (see above)"
	status=1
fi
exit $status
