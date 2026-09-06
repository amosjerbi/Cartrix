#!/bin/sh

set -u
export XDG_RUNTIME_DIR=/run/0-runtime-dir
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock

# RetroArch can take several seconds to create its Wayland window. Keep
# checking until it exists, then force the same fullscreen state for every
# platform/core launch.
i=1
while [ "$i" -le 40 ]; do
    if swaymsg -t get_tree 2>/dev/null | grep -q '"app_id": "com.libretro.RetroArch"'; then
        n=1
        while [ "$n" -le 20 ]; do
            swaymsg '[app_id="com.libretro.RetroArch"] fullscreen enable' >/dev/null 2>&1 || true
            swaymsg '[app_id="com.libretro.RetroArch"] focus' >/dev/null 2>&1 || true
            sleep 0.25
            n=$((n + 1))
        done
        # Keep monitoring the game so exiting it restores a responsive
        # EmulationStation workspace instead of leaving focus in a dead split.
        while swaymsg -t get_tree 2>/dev/null | grep -q '"app_id": "com.libretro.RetroArch"'; do
            sleep 0.5
        done
        swaymsg '[app_id="emulationstation"] fullscreen enable' >/dev/null 2>&1 || true
        swaymsg '[app_id="emulationstation"] focus' >/dev/null 2>&1 || true
        exit 0
    fi
    sleep 0.25
    i=$((i + 1))
done

exit 1
