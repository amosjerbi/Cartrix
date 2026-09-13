#!/bin/sh

set -u

PORTS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR="$PORTS_DIR/Cartrix"
cd "$APP_DIR" || exit 1

# ROCKNIX launches ports from the active Wayland session, but a manual launch
# or some EmulationStation entry points may omit the session runtime variable.
# Restore the device's standard runtime directory so SDL/LÖVE can create its
# graphics window instead of appearing to hang on startup.
if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d /var/run/0-runtime-dir ]; then
    XDG_RUNTIME_DIR=/var/run/0-runtime-dir
    export XDG_RUNTIME_DIR
fi
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/tmp}/wayland-1" ]; then
    WAYLAND_DISPLAY=wayland-1
    export WAYLAND_DISPLAY
fi
if [ -z "${SWAYSOCK:-}" ]; then
    for socket in "${XDG_RUNTIME_DIR:-/tmp}"/sway-ipc*.sock; do
        if [ -S "$socket" ]; then
            SWAYSOCK="$socket"
            export SWAYSOCK
            break
        fi
    done
fi

# Configure both RG DS panels before creating the LÖVE window.
if [ -f "$PORTS_DIR/enable_dual_screen_rgds.sh" ] && [ -e /proc/device-tree/model ] && \
   grep -q 'Anbernic RG DS' /proc/device-tree/model; then
    # Sway may still be settling when a port is selected immediately after
    # boot. Display placement is best-effort and must never prevent LÖVE from
    # starting; the launcher repeats final window placement below.
    bash "$PORTS_DIR/enable_dual_screen_rgds.sh" --cartrix || \
        echo "ROCKNIX 3D Carousel: display setup was incomplete; continuing" >&2
fi

LOVE_BIN=""
for candidate in \
    "${LOVE_BIN:-}" \
    /usr/bin/love \
    /usr/local/bin/love \
    /opt/love/love \
    /storage/roms/ports/PortMaster/runtimes/love_11.5/love.aarch64 \
    /storage/games-internal/roms/ports/PortMaster/runtimes/love_11.5/love.aarch64 \
    /storage/roms/ports/love/love \
    /storage/roms/ports/Love2D/love \
    /storage/roms/ports/fetcher/love \
    /storage/games-internal/roms/ports/fetcher/love \
    /storage/.config/emulationstation/scripts/love; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        LOVE_BIN="$candidate"
        break
    fi
done

if [ -z "$LOVE_BIN" ]; then
    echo "ROCKNIX 3D Carousel: LÖVE runtime not found" >&2
    exit 127
fi

# ROCKNIX's bundled LÖVE binary keeps liblove beside the executable.
# Add that directory without disturbing any existing device runtime paths.
LOVE_DIR="$(dirname "$LOVE_BIN")"
LOVE_LIB_DIR="$LOVE_DIR/libs"
case "$LOVE_BIN" in
    */PortMaster/runtimes/love_11.5/*)
        LOVE_LIB_DIR="$LOVE_DIR/libs.$(uname -m)"
        ;;
esac
if [ -d "$LOVE_LIB_DIR" ]; then
    LD_LIBRARY_PATH="$LOVE_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    LD_LIBRARY_PATH="/usr/lib/compat:$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH
fi

LOG_DIR="${XDG_CACHE_HOME:-/tmp}/rocknix-3d-carousel"
mkdir -p "$LOG_DIR"
# Prevent overlapping LÖVE surfaces after a launcher restart or a delayed
# frontend callback. The current process is still the shell, so every match
# here belongs to an older Cartrix instance.
for old_pid in $(pgrep -f "$LOVE_BIN $APP_DIR" 2>/dev/null || true); do
    kill "$old_pid" 2>/dev/null || true
done
sleep 0.2
CAROUSEL_LOG="$LOG_DIR/carousel.log"
: >"$CAROUSEL_LOG"

restore_frontend() {
    # Return the compositor to ROCKNIX's normal single-screen frontend state.
    # Without this, the lower panel can retain Cartrix's last framebuffer even
    # though LÖVE and runemu have already exited successfully.
    swaymsg 'workspace 1' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] move container to workspace 1' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] floating disable' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] fullscreen enable' >/dev/null 2>&1 || true
    swaymsg '[app_id="emulationstation"] focus' >/dev/null 2>&1 || true
    swaymsg 'output DSI-1 power off' >/dev/null 2>&1 || true
}

attempt=1
while [ "$attempt" -le 2 ]; do
    echo "Launch attempt $attempt" >>"$CAROUSEL_LOG"
    "$LOVE_BIN" "$APP_DIR" >>"$CAROUSEL_LOG" 2>&1 &
    LOVE_PID=$!

    # The port can be launched while the lower display workspace is focused.
    # Place the combined 1280x480 window on the upper workspace and reset its
    # absolute position after LÖVE creates it; the for_window rule alone can
    # miss this timing when the compositor is still switching workspaces.
    i=1
    while [ "$i" -le 40 ]; do
        if swaymsg -t get_tree 2>/dev/null | grep -q '"app_id": "love.aarch64"'; then
            # ROCKNIX may reload its normal frontend rules while runemu starts,
            # after the early helper already enabled both panels. Reassert the
            # dual-screen canvas only once the real LÖVE surface exists.
            swaymsg 'output DSI-2 power on' >/dev/null 2>&1 || true
            swaymsg 'output DSI-1 power on' >/dev/null 2>&1 || true
            swaymsg 'output DSI-2 pos 0 0' >/dev/null 2>&1 || true
            swaymsg 'output DSI-1 pos 640 0' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] move container to workspace 1' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] floating enable' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] fullscreen disable' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] border none' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] resize set width 1280 height 480' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] move absolute position 0 0' >/dev/null 2>&1 || true
            swaymsg 'workspace 1' >/dev/null 2>&1 || true
            swaymsg '[app_id="love.aarch64"] focus' >/dev/null 2>&1 || true
            break
        fi
        if ! kill -0 "$LOVE_PID" 2>/dev/null; then break; fi
        sleep 0.25
        i=$((i + 1))
    done

    wait "$LOVE_PID"
    love_status=$?
    echo "LÖVE exit status: $love_status" >>"$CAROUSEL_LOG"

    # The Mali driver can occasionally reject the first context immediately
    # after a previous Cartrix window closes. Retry only a failed startup; once
    # the library became ready, an exit belongs to the user and must stay final.
    if [ "$attempt" -eq 1 ] && [ "$love_status" -ne 0 ] && \
       ! grep -q '^Startup: library ready' "$CAROUSEL_LOG"; then
        echo "Startup failed before ready; retrying once" >>"$CAROUSEL_LOG"
        sleep 1
        attempt=2
        continue
    fi
    restore_frontend
    exit "$love_status"
done

restore_frontend
exit 1
