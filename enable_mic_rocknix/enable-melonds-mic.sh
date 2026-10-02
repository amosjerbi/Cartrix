#!/bin/sh
# Enable the built-in microphone for standalone melonDS on ROCKNIX RGDS.
set -eu

if ! command -v pactl >/dev/null 2>&1; then
    echo "pactl is required (run this on the ROCKNIX device)." >&2
    exit 1
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
config_dir="${MELONDS_CONFIG_DIR:-/storage/.config/melonDS}"
mic_device="${MELONDS_MIC_DEVICE:-Built-in Audio Microphone}"

# Source IDs change across boots; select the physical capture source by name.
mic_source=$(pactl list short sources | awk '
    $2 ~ /^alsa_input/ && $2 ~ /Mic/ { print $2; exit }
')
if [ -z "$mic_source" ]; then
    mic_source=$(pactl list short sources | awk '
        $2 ~ /^alsa_input/ && $2 !~ /\.monitor$/ { print $2; exit }
    ')
fi
if [ -z "$mic_source" ]; then
    echo "No physical microphone source was found." >&2
    exit 1
fi

pactl set-default-source "$mic_source"

# Move a currently running melonDS recording stream without restarting the game.
pactl list source-outputs | awk '
    /^Source Output #[0-9]+/ { id = substr($3, 2) }
    /application.name = "melonDS"/ && id != "" { print id }
' | while IFS= read -r stream_id; do
    pactl move-source-output "$stream_id" "$mic_source"
done

mkdir -p "$config_dir"
ini="$config_dir/melonDS.ini"
toml="$config_dir/melonDS.toml"

if [ ! -f "$ini" ] && [ -f /usr/config/melonDS/melonDS.ini ]; then
    cp /usr/config/melonDS/melonDS.ini "$ini"
fi
if [ ! -f "$ini" ] && [ ! -f "$toml" ]; then
    echo "No melonDS config or packaged default was found on this ROCKNIX build." >&2
    exit 1
fi

if [ -f "$ini" ]; then
    [ -f "$ini.before-mic-setup" ] || cp -p "$ini" "$ini.before-mic-setup"
    if grep -q '^MicInputType=' "$ini"; then
        sed -i 's/^MicInputType=.*/MicInputType=1/' "$ini"
    else
        printf '\nMicInputType=1\n' >> "$ini"
    fi
    if grep -q '^MicDevice=' "$ini"; then
        sed -i "s/^MicDevice=.*/MicDevice=$mic_device/" "$ini"
    else
        printf 'MicDevice=%s\n' "$mic_device" >> "$ini"
    fi
fi

if [ -f "$toml" ]; then
    [ -f "$toml.before-mic-setup" ] || cp -p "$toml" "$toml.before-mic-setup"
    tmp=$(mktemp "$config_dir/.melonds-mic.XXXXXX")
    awk -v device="$mic_device" '
        /^\[/ {
            if (in_mic && !saw_device) print "Device = \"" device "\""
            if (in_mic && !saw_type) print "InputType = 1"
            in_mic = ($0 == "[Mic]")
            if (in_mic) { saw_mic = 1; saw_device = 0; saw_type = 0 }
        }
        in_mic && /^Device = / { print "Device = \"" device "\""; saw_device = 1; next }
        in_mic && /^InputType = / { print "InputType = 1"; saw_type = 1; next }
        { print }
        END {
            if (in_mic && !saw_device) print "Device = \"" device "\""
            if (in_mic && !saw_type) print "InputType = 1"
            if (!saw_mic) {
                print "\n[Mic]"
                print "Device = \"" device "\""
                print "InputType = 1"
            }
        }
    ' "$toml" > "$tmp"
    cat "$tmp" > "$toml"
    rm -f "$tmp"
fi

echo "melonDS microphone: $mic_device"
echo "PipeWire source: $mic_source"
echo "Default source: $(pactl get-default-source)"
if pidof melonDS >/dev/null 2>&1; then
    echo "melonDS is running. Run this script again after quitting to retain its saved settings."
fi
