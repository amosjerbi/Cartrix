#!/bin/sh

set -u
export XDG_RUNTIME_DIR=/run/0-runtime-dir
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock

restore_frontend() {
    swaymsg 'seat seat0 attach 18507:4353:retrogame_joypad' >/dev/null 2>&1 || true
    swaymsg 'seat seat1 attach 1046:911:Goodix_Capacitive_TouchScreen' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] move container to workspace 1' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] floating disable' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] fullscreen enable' >/dev/null 2>&1 || true
    swaymsg 'workspace 1' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] focus' >/dev/null 2>&1 || true
}

# RetroArch can take several seconds to create its Wayland window. Keep
# checking until it exists, then force the same fullscreen state for every
# platform/core launch.
i=1
while [ "$i" -le 40 ]; do
    if pgrep -x retroarch >/dev/null 2>&1 || swaymsg -t get_tree 2>/dev/null | grep -q 'RetroArch'; then
        n=1
        while [ "$n" -le 20 ]; do
            swaymsg '[app_id="com.libretro.RetroArch"] fullscreen enable' >/dev/null 2>&1 || true
            swaymsg '[app_id="com.libretro.RetroArch"] focus' >/dev/null 2>&1 || true
            swaymsg '[app_id="retroarch"] fullscreen enable' >/dev/null 2>&1 || true
            swaymsg '[app_id="retroarch"] focus' >/dev/null 2>&1 || true
            swaymsg '[title="RetroArch.*"] fullscreen enable' >/dev/null 2>&1 || true
            swaymsg '[title="RetroArch.*"] focus' >/dev/null 2>&1 || true
            sleep 0.25
            n=$((n + 1))
        done
        # Keep monitoring the game so exiting it restores a responsive
        # EmulationStation workspace instead of leaving focus in a dead split.
        while pgrep -x retroarch >/dev/null 2>&1 || swaymsg -t get_tree 2>/dev/null | grep -q 'RetroArch'; do
            sleep 0.5
        done
        restore_frontend
        exit 0
    fi
    sleep 0.25
    i=$((i + 1))
done

# If runemu fails before creating RetroArch, Cartrix has still exited and the
# frontend still needs its controller seat and focus restored.
restore_frontend
exit 1
