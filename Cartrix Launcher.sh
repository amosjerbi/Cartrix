#!/bin/sh

set -u

PORTS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR="$PORTS_DIR/Cartrix Launcher"
cd "$APP_DIR" || exit 1

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
exec "$LOVE_BIN" "$APP_DIR" >"$LOG_DIR/carousel.log" 2>&1
