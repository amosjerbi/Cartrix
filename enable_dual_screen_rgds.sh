#!/bin/bash

MODE="${1:-}"

# Cartrix needs panel placement and power, but no frontend replacement or
# compositor restart (which would terminate the port that invoked us).
if [ "$MODE" = "--cartrix" ]; then
    set -u
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
    if [ -z "${SWAYSOCK:-}" ]; then
        for socket in "$XDG_RUNTIME_DIR"/sway-ipc*.sock; do
            if [ -S "$socket" ]; then export SWAYSOCK="$socket"; break; fi
        done
    fi
    # Right after boot, output activation and the first Sway IPC commands can
    # race compositor initialization. Repeat the idempotent panel setup and do
    # not turn a temporary IPC miss into a failed port launch.
    for attempt in 1 2 3; do
        swaymsg 'output DSI-2 power on' >/dev/null 2>&1 || true
        swaymsg 'output DSI-1 power on' >/dev/null 2>&1 || true
        swaymsg 'output DSI-2 pos 0 0' >/dev/null 2>&1 || true
        swaymsg 'output DSI-1 pos 640 0' >/dev/null 2>&1 || true
        sleep 0.2
    done
    swaymsg '[app_id="emulationstation"] fullscreen disable' >/dev/null 2>&1 || true
    for placement in 'floating enable' 'fullscreen disable' 'border none' 'resize set width 1280 height 480' 'move container to workspace 1' 'move absolute position 0 0' 'focus'; do
        swaymsg "for_window [title=\"ROCKNIX 3D Carousel\"] $placement" >/dev/null 2>&1 || true
    done
    exit 0
fi

# When bind-mounted as ROCKNIX's frontend launcher, only start EmulationStation.
# A bind-mounted script may retain its backing path in $0, so also recognize a
# no-argument invocation made directly by systemd. The scheduled --apply unit
# must continue into the activation logic even though systemd launches it too.
if [ "$MODE" != "--apply" ] && { [ "$0" = "/usr/bin/start_es.sh" ] || [ "$PPID" -eq 1 ]; }; then
    . /usr/bin/es_settings
    exec emulationstation --log-path /var/log --no-splash \
        --resolution 1280 480 \
        --screensize 1280 480 \
        --screenoffset 0 0
fi

set -eu

# The Ports entry can be resumed automatically when essway returns. If this
# exact script is already installed as the launcher, activation is complete;
# do not schedule another compositor restart. A newer Ports copy will differ
# from the installed launcher and will still be applied normally.
if [ "$MODE" != "--apply" ] && \
   grep -q ' /usr/bin/start_es.sh ' /proc/mounts && \
   cmp -s "$0" /usr/bin/start_es.sh; then
    echo "Dual-screen mode is already active."
    exit 0
fi

# Run activation in a transient system unit so restarting essway cannot kill
# the setup halfway through. Use one fixed, collectable unit to prevent repeated
# button presses from queueing several delayed frontend restarts. Keep this
# launcher alive until the restart begins so a game cannot start in between.
if [ "$MODE" != "--apply" ] && command -v systemd-run >/dev/null 2>&1; then
    SCRIPT_PATH="$(readlink -f "$0")"
    ACTIVATION_UNIT="focus-dual-screen-enable"
    if ! systemctl is-active --quiet "${ACTIVATION_UNIT}.timer" && \
       ! systemctl is-active --quiet "${ACTIVATION_UNIT}.service"; then
        systemd-run --quiet --collect \
            --unit="$ACTIVATION_UNIT" \
            --on-active=1s \
            --timer-property=AccuracySec=100ms \
            "$SCRIPT_PATH" --apply
    fi
    echo "Dual-screen activation started. Please wait for EmulationStation to return..."
    sleep 4
    exit 0
fi

THEME_PATH=""
for candidate in \
    /roms/themes/focus-es-rgds2 \
    /roms/themes/focus-es-rgds \
    /storage/roms/themes/focus-es-rgds \
    /storage/.config/emulationstation/themes/focus-es-rgds \
    /roms/themes/focus-es2 \
    /roms/themes/focus-es \
    /storage/roms/themes/focus-es2 \
    /storage/roms/themes/focus-es \
    /storage/.config/emulationstation/themes/focus-es2 \
    /storage/.config/emulationstation/themes/focus-es; do
    if [ -d "$candidate" ]; then
        THEME_PATH="$candidate"
        break
    fi
done

if [ -z "$THEME_PATH" ]; then
    echo "ERROR: Focus was not found in a ROCKNIX theme directory."
    exit 1
fi

SCRIPT_DIR="${THEME_PATH}/scripts"
if [ ! -d "$SCRIPT_DIR" ]; then
    if [ -d "${THEME_PATH}/0_Ports_scripts" ]; then
        SCRIPT_DIR="${THEME_PATH}/0_Ports_scripts"
    else
        mkdir -p "$SCRIPT_DIR"
    fi
fi

LAUNCHER_SCRIPT="${SCRIPT_DIR}/enable_dual_screen_rgds.sh"
# A clean theme install may contain only the theme and packaged binary. Install
# or refresh the launcher copy from the Ports script that is currently applying
# the setup, so no separate installer or pre-created script directory is needed.
if [ ! -f "$LAUNCHER_SCRIPT" ] || ! cmp -s "$0" "$LAUNCHER_SCRIPT"; then
    cp "$0" "$LAUNCHER_SCRIPT"
fi

CUSTOM_ES="${THEME_PATH}/bin/emulationstation-rgds"

# The running frontend keeps the bind-mounted executable busy. ROCKNIX uses
# KillMode=process for essway, so a normal stop leaves the Ports/runemu children
# alive; those children can relaunch this script indefinitely. The --apply
# process runs in its own transient unit, so kill the complete old essway cgroup
# before replacing mounts, then start one clean frontend at the end.
if systemctl is-active --quiet essway; then
    systemctl kill --kill-whom=all --signal=SIGKILL essway || true
    systemctl stop essway || true
fi
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -x emulationstation >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done

if grep -q ' /usr/bin/emulationstation ' /proc/mounts; then
    umount /usr/bin/emulationstation
fi
if [ -f "$CUSTOM_ES" ]; then
    chmod +x "$CUSTOM_ES"
    mount --bind "$CUSTOM_ES" /usr/bin/emulationstation
fi

chmod +x "$LAUNCHER_SCRIPT"
if grep -q ' /usr/bin/start_es.sh ' /proc/mounts; then
    umount /usr/bin/start_es.sh
fi
mount --bind "$LAUNCHER_SCRIPT" /usr/bin/start_es.sh

SWAY_CONFIG=/storage/.config/sway/config
if [ -f "$SWAY_CONFIG" ] && [ ! -f "${SWAY_CONFIG}.before-focus-dual-screen" ]; then
    cp "$SWAY_CONFIG" "${SWAY_CONFIG}.before-focus-dual-screen"
fi

cat >"$SWAY_CONFIG" <<'EOF'
seat * hide_cursor 1000
default_border none
exec_always mako
output DSI-2 transform 0
output DSI-2 pos 0 0
output DSI-1 pos 640 0
exec_always swaymsg 'output DSI-2 power on'
exec_always swaymsg 'output DSI-1 power on'
output DSI-2 bg #000000 solid_color
output DSI-2 allow_tearing yes
output DSI-2 max_render_time off
for_window [title=".*(Secondary|\[w2\]|Sub|Bottom|Screen 2|GamePad).*"] move window to output DSI-1
# Normal games belong on the top display; lowerdeck owns the bottom display.
# vertical-check runs afterward and may override this for vertical/dual-screen
# cores that intentionally span both panels.
for_window [title="RetroArch.*"] move container to output DSI-2, fullscreen enable, exec /usr/bin/vertical-check
for_window [app_id="lowerdeck"] floating enable, fullscreen enable, move window to output DSI-1
no_focus [app_id="lowerdeck"]
exec_always swaymsg '[app_id="emulationstation"]' seat seat0 attach "0:0:wlr_virtual_keyboard_v1"
exec_always swaymsg '[app_id="emulationstation"]' seat seat1 attach "0:0:wlr_virtual_keyboard_v1"
for_window [title=".*(Secondary|\[w2\]|Sub|Bottom|Screen 2|GamePad).*"] output DSI-1 power on
for_window [app_id="drastic"] floating enable, move window to output DSI-2, fullscreen disable, border none, resize set width 1280 height 480, move absolute position 0 0, focus
for_window [app_id="drastic"] floating enable, fullscreen disable, border none, resize set width 1280 height 480, move absolute position 0 0, focus
for_window [app_id="drastic"] input "1046:911:Goodix_Capacitive_TouchScreen" map_to_output DSI-2
# Cartrix is a single LÖVE surface spanning the two 640x480 panels. Keep it
# floating at the logical canvas origin so Sway does not constrain it to DSI-2.
for_window [title="ROCKNIX 3D Carousel"] floating enable, fullscreen disable, border none, resize set width 1280 height 480, move absolute position 0 0, focus
# Apply placement when the frontend window is created. An exec_always command
# runs before essway starts EmulationStation after boot and therefore matches
# nothing, allowing Sway to fullscreen the 1280-wide surface onto one output.
for_window [app_id="emulationstation"] floating enable, fullscreen disable, resize set width 1280 height 480, move absolute position 0 0, focus
exec_always swaymsg '[app_id="emulationstation"]' seat seat1 attach "1046:911:Goodix_Capacitive_TouchScreen"
exec_always swaymsg '[app_id="emulationstation"]' seat seat1 fallback yes
EOF

ES_SETTINGS=/storage/.config/emulationstation/es_settings.cfg
set_string_setting() {
    setting="$1"
    value="$2"
    if grep -q "<string name=\"${setting}\"" "$ES_SETTINGS" 2>/dev/null; then
        sed -i "s|<string name=\"${setting}\" value=\"[^\"]*\" />|<string name=\"${setting}\" value=\"${value}\" />|" "$ES_SETTINGS"
    else
        sed -i "s|</config>|\t<string name=\"${setting}\" value=\"${value}\" />\n</config>|" "$ES_SETTINGS"
    fi
}

set_string_setting FullScreenMenu true
set_string_setting GameTransitionStyle fade
set_string_setting ThemeSet "$(basename "$THEME_PATH")"

# Recreate the compositor so both DRM outputs are initialized together. Hot
# power switching while the dual-screen ES surface exists can wedge RK3566 VOP.
systemctl stop essway
systemctl restart sway
systemctl start essway
