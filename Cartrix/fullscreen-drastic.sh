#!/bin/sh

set -u
export XDG_RUNTIME_DIR=/run/0-runtime-dir
export SWAYSOCK=/run/0-runtime-dir/sway-ipc.0.sock

# DraStic restores its own remembered 640x480 geometry shortly after mapping.
# Reassert the RG DS two-panel canvas long enough to win that startup race.
i=1
while [ "$i" -le 40 ]; do
    if swaymsg -t get_tree 2>/dev/null | grep -q '"app_id": "drastic"'; then
        n=1
        while [ "$n" -le 40 ]; do
            swaymsg '[app_id="drastic"] floating enable' >/dev/null 2>&1 || true
            swaymsg '[app_id="drastic"] fullscreen disable' >/dev/null 2>&1 || true
            swaymsg '[app_id="drastic"] border none' >/dev/null 2>&1 || true
            swaymsg '[app_id="drastic"] resize set width 1280 height 480' >/dev/null 2>&1 || true
            swaymsg '[app_id="drastic"] move absolute position 0 0' >/dev/null 2>&1 || true
            swaymsg '[app_id="drastic"] focus' >/dev/null 2>&1 || true
            sleep 0.25
            n=$((n + 1))
        done
        exit 0
    fi
    sleep 0.25
    i=$((i + 1))
done

exit 1
