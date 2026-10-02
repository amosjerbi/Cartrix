#!/bin/sh
# Install the live microphone bridge for the ROCKNIX RGDS DraStic build.
set -eu

drastic_dir=${DRASTIC_DIR:-/storage/.config/drastic}
binary=$drastic_dir/drastic.bin
launcher=$drastic_dir/drastic
backup=$drastic_dir/drastic.pre-live-mic
library=$drastic_dir/drastic-live-mic.so
expected_sha=d54980a36c5e0b5cc46868bf25acd5d33b4c5337334fd0c417255a36942feb95

if [ "${1:-}" = --restore ]; then
    if [ ! -f "$backup" ]; then
        echo "No original DraStic launcher backup at $backup" >&2
        exit 1
    fi
    cp "$backup" "$launcher"
    chmod +x "$launcher"
    echo "Restored $launcher; restart DraStic to apply."
    exit 0
fi
if [ "$#" -ne 0 ]; then
    echo "Usage: $0 [--restore]" >&2
    exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root on the ROCKNIX RGDS." >&2
    exit 1
fi
if [ ! -f "$binary" ] || [ ! -f "$launcher" ]; then
    echo "DraStic is not installed at $drastic_dir. Launch it once, then retry." >&2
    exit 1
fi
actual_sha=$(sha256sum "$binary" | cut -d ' ' -f 1)
if [ "$actual_sha" != "$expected_sha" ]; then
    echo "Unsupported DraStic binary ($actual_sha). No files changed." >&2
    exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ ! -f "$script_dir/drastic-live-mic.so" ]; then
    echo "Place drastic-live-mic.so beside this script." >&2
    exit 1
fi
if [ ! -f "$backup" ]; then
    cp "$launcher" "$backup"
fi
cp "$script_dir/drastic-live-mic.so" "$library"

temp_launcher=$drastic_dir/.drastic-live-mic-launcher.$$
trap 'rm -f "$temp_launcher"' EXIT HUP INT TERM
cat > "$temp_launcher" <<'EOF'
#!/bin/sh
export SDL_VIDEO_WAYLAND_WMCLASS=drastic
export DSHOOK_MIC_THRESH=
mic_preload=/storage/.config/drastic/drastic-live-mic.so
if [ -f /usr/lib/libdrastouch.so ]; then
    mic_preload=/usr/lib/libdrastouch.so:$mic_preload
fi
if [ -f /storage/.config/drastic/librgdsmenu.so ]; then
    mic_preload=$mic_preload:/storage/.config/drastic/librgdsmenu.so
fi
export LD_PRELOAD=$mic_preload
exec /storage/.config/drastic/drastic.bin "$@"
EOF
chmod +x "$temp_launcher"
mv "$temp_launcher" "$launcher"
trap - EXIT HUP INT TERM
echo "Installed live mic bridge. Restart DraStic to apply."
