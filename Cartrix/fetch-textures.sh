#!/bin/sh
# Cartrix: download ScreenScraper cartridge/disc labels and game screenshots,
# then build all image and ROM indexes under labels/<platform>/ in one pass.
#
# Usage: ./fetch-textures.sh [platform ...]   (default: all platforms below)
# Needs: curl and jq (md5sum/md5 optional).
set -eu

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CARTRIX_DIR="$APP_DIR"

# For a private local test, paste your credentials between the single quotes.
# Do not commit or share this file after filling these in. Environment variables
# with the same names also work and take precedence over the placeholders.
SS_DEVID=${SS_DEVID:-'PASTE_DEVELOPER_ID_HERE'}
SS_DEVPASS=${SS_DEVPASS:-'PASTE_DEVELOPER_PASSWORD_HERE'}
SS_USER=${SS_USER:-'PASTE_SCREENSCRAPER_USERNAME_HERE'}
SS_PASS=${SS_PASS:-'PASTE_SCREENSCRAPER_PASSWORD_HERE'}

case "$SS_DEVID:$SS_DEVPASS:$SS_USER:$SS_PASS" in
    *PASTE_*_HERE*)
        echo "Fill in the four ScreenScraper credentials near the top of $0" >&2
        exit 1
        ;;
esac
[ -d "$CARTRIX_DIR" ] || { echo "Missing Cartrix directory: $CARTRIX_DIR" >&2; exit 1; }

for tool in curl jq; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Missing tool: $tool" >&2; exit 1; }
done
if command -v md5sum >/dev/null 2>&1; then
    md5_of() { md5sum "$1" | cut -d' ' -f1; }
elif command -v md5 >/dev/null 2>&1; then
    md5_of() { md5 -q "$1"; }
else
    md5_of() { echo ""; }
fi

SOFTNAME="Cartrix"
API="https://api.screenscraper.fr/api2/jeuInfos.php"
REGIONS="wor us eu ss jp"   # preferred order; falls back to any region
DELAY=2                     # seconds between requests (free accounts are throttled)
MAX_FAILS=30                # stop after this many misses in a row (guards against quota/ban)

# Set ROMS_ROOT to test against a local folder (e.g. ROMS_ROOT=$PWD/testroms).
ROOT=${ROMS_ROOT:-}
if [ -z "$ROOT" ]; then
    for candidate in /storage/roms /roms; do
        [ -d "$candidate" ] && { ROOT=$candidate; break; }
    done
fi
[ -n "$ROOT" ] || { echo "No ROM root found" >&2; exit 1; }

# Platform folder -> ScreenScraper systemeid. Verify against ScreenScraper's
# systemesListe.php if a platform never matches.
system_id() {
    case "$1" in
        genesis|megadrive) echo 1 ;;
        mastersystem) echo 2 ;;
        nes) echo 3 ;;
        snes) echo 4 ;;
        gb) echo 9 ;;
        gbc) echo 10 ;;
        gba) echo 12 ;;
        n64) echo 14 ;;
        nds) echo 15 ;;
        3ds) echo 17 ;;
        gamegear) echo 21 ;;
        saturn) echo 22 ;;
        dreamcast) echo 23 ;;
        psx) echo 57 ;;
        psp) echo 61 ;;
        vita) echo 62 ;;
        neogeo) echo 142 ;;
        switch) echo 225 ;;
        *) echo "" ;;
    esac
}

if [ "$#" -gt 0 ]; then
    PLATFORMS="$*"
else
    PLATFORMS="gb gbc nes snes n64 gba nds switch psx 3ds gamegear mastersystem genesis dreamcast saturn neogeo"
fi

TMP=$(mktemp -d "$APP_DIR/.tex-work.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

is_png() {
    signature=$(od -An -tx1 -N8 "$1" 2>/dev/null | tr -d ' \n')
    [ "$signature" = "89504e470d0a1a0a" ]
}

# Ask ScreenScraper about one ROM; print the best URL for the requested media.
lookup() {
    sysid=$1; file=$2; size=$3; md5=$4; media_type=$5
    if [ -n "$md5" ]; then
        set -- --data-urlencode "md5=$md5" --data-urlencode "romtaille=$size"
    else
        set --
    fi
    curl -fsS -m 30 -G "$API" \
        --data-urlencode "devid=$SS_DEVID" \
        --data-urlencode "devpassword=$SS_DEVPASS" \
        --data-urlencode "softname=$SOFTNAME" \
        --data-urlencode "ssid=$SS_USER" \
        --data-urlencode "sspassword=$SS_PASS" \
        --data-urlencode "output=json" \
        --data-urlencode "systemeid=$sysid" \
        --data-urlencode "romtype=rom" \
        --data-urlencode "romnom=$file" \
        "$@" 2>/dev/null \
    | jq -r --arg regs "$REGIONS" --arg media_type "$media_type" '
        [.response.jeu.medias[]? | select(.type == $media_type)] as $m
        | ($regs | split(" ")) as $r
        | ([ $r[] as $x | $m[] | select(.region == $x) ] + $m)[0].url // empty
      ' 2>/dev/null || true
}

download_media() {
    sysid=$1; file=$2; size=$3; md5=$4; media_type=$5; target=$6
    url=$(lookup "$sysid" "$file" "$size" "$md5" "$media_type")
    if [ -z "$url" ] && [ -n "$md5" ]; then
        sleep "$DELAY"
        url=$(lookup "$sysid" "$file" "$size" "" "$media_type")
    fi
    [ -n "$url" ] || return 1

    url=$(printf '%s' "$url" | sed -E 's/([?&])(devid|devpassword|softname|ssid|sspassword)=[^&]*/\1/g; s/\?&+/?/; s/&&+/\&/g; s/[?&]$//')
    tmp="$TMP/dl.png"
    curl -fsS -m 60 -G -o "$tmp" "$url" \
        --data-urlencode "devid=$SS_DEVID" \
        --data-urlencode "devpassword=$SS_DEVPASS" \
        --data-urlencode "softname=$SOFTNAME" \
        --data-urlencode "ssid=$SS_USER" \
        --data-urlencode "sspassword=$SS_PASS" 2>/dev/null \
        && [ -s "$tmp" ] && is_png "$tmp" || return 1
    mv -f "$tmp" "$target"
}

fails=0
for platform in $PLATFORMS; do
    sysid=$(system_id "$platform")
    [ -n "$sysid" ] || { echo "skip $platform (no system id)"; continue; }
    src="$ROOT/$platform"
    [ -d "$src" ] || continue
    out="$CARTRIX_DIR/labels/$platform"
    mkdir -p "$out"
    echo "== $platform"

    for rom in "$src"/*; do
        [ -f "$rom" ] || continue
        file=${rom##*/}
        lower=$(printf '%s' "$file" | tr 'A-Z' 'a-z')
        case "$lower" in
            .*|*.srm|*.png|*.jpg|*.jpeg|*.webp|*.xml|*.txt|*.pdf|*.tmp|*.cfg|*.state*) continue ;;
        esac
        base=${file%.*}
        size=$(wc -c < "$rom" | tr -d ' ')
        md5=""
        # Hashing big files on a handheld is slow; only hash small/medium ROMs.
        if [ "$size" -gt 0 ] && [ "$size" -le 268435456 ]; then
            md5=$(md5_of "$rom" 2>/dev/null | tr 'a-z' 'A-Z')
        fi

        label_target="$out/$base-cartridge.png"
        if [ ! -s "$label_target" ]; then
            if download_media "$sysid" "$file" "$size" "$md5" support-texture "$label_target"; then
                echo "  label: $base"
            else
                echo "  no label: $file"
            fi
            sleep "$DELAY"
        fi

        screen_target="$out/$base-image.png"
        if [ ! -s "$screen_target" ]; then
            if download_media "$sysid" "$file" "$size" "$md5" ss "$screen_target"; then
                echo "  screenshot: $base"
            else
                echo "  no screenshot: $file"
            fi
            sleep "$DELAY"
        fi
    done
done

# Build the indexes consumed by main.lua. Cartridge textures have first
# priority; existing scraper thumbnails/covers/marquees remain fallbacks.
mkdir -p "$CARTRIX_DIR/labels"
for platform in $PLATFORMS; do
    src="$ROOT/$platform"
    [ -d "$src" ] || continue
    out="$CARTRIX_DIR/labels/$platform"
    screenshot_dir="$out"
    mkdir -p "$out"

    all_files="$TMP/$platform.all"
    rom_files="$TMP/$platform.roms"
    { find "$src" -type f ! -path '*/.focus-3d/*' -print; find "$out" -type f -print; } | sort -u > "$all_files"
    awk -v platform="$platform" '
        platform == "nds" && tolower($0) !~ /\.(nds|zip|7z)$/ { next }
        /\/images\// || /\/videos\// || /\/manuals\// || /\/.focus-3d\// { next }
        tolower($0) ~ /\.(srm|png|jpg|jpeg|webp|xml|txt|pdf|tmp|cfg)$/ { next }
        { n=split($0,a,"/"); if (a[n] !~ /^\./) print }
    ' "$all_files" > "$rom_files"

    : > "$out/rom-index.txt"
    while IFS= read -r rom; do printf '%s\n' "$rom" >> "$out/rom-index.txt"; done < "$rom_files"

    : > "$out/scan-index.txt"
    wanted_art="$TMP/$platform.art-wanted"; seen_art="$TMP/$platform.art-seen"
    : > "$wanted_art"; : > "$seen_art"
    index=1
    for suffix in '-cartridge.png' '-thumb.png' '-image.png' '-marquee.png'; do
        while IFS= read -r file; do
            [ "$index" -le 24 ] || break
            case "${file##*/}" in *"$suffix") ;; *) continue ;; esac
            base=${file##*/}; key=${base%$suffix}
            grep -Fqx "$key" "$seen_art" && continue
            printf '%s\n' "$key" >> "$seen_art"
            target=$(printf '%s/scan-%02d.png' "$out" "$index")
            if [ ! -f "$target" ] || ! cmp -s "$file" "$target"; then cp -f "$file" "$target"; fi
            printf '%s\n' "$target" >> "$wanted_art"
            rom=$(awk -v key="$key" 'BEGIN{IGNORECASE=1} {n=split($0,a,"/"); name=a[n]; sub(/\.[^.]*$/, "", name); if(name==key){print; exit}}' "$rom_files")
            printf 'scan-%02d.png|%s\n' "$index" "$rom" >> "$out/scan-index.txt"
            index=$((index + 1))
        done < "$all_files"
    done
    for old in "$out"/scan-*.png; do
        [ -f "$old" ] || continue
        grep -Fqx "$old" "$wanted_art" || rm -f "$old"
    done

    : > "$screenshot_dir/screenshot-index.txt"
    wanted_screens="$TMP/$platform.screen-wanted"; seen_screens="$TMP/$platform.screen-seen"
    : > "$wanted_screens"; : > "$seen_screens"
    screenshot_index=1
    while IFS= read -r file; do
        [ "$screenshot_index" -le 24 ] || break
        case "${file##*/}" in *-image.png) ;; *) continue ;; esac
        base=${file##*/}; key=${base%-image.png}
        grep -Fqx "$key" "$seen_screens" && continue
        printf '%s\n' "$key" >> "$seen_screens"
        target=$(printf '%s/screen-%02d.png' "$screenshot_dir" "$screenshot_index")
        if [ ! -f "$target" ] || ! cmp -s "$file" "$target"; then cp -f "$file" "$target"; fi
        printf '%s\n' "$target" >> "$wanted_screens"
        rom=$(awk -v key="$key" 'BEGIN{IGNORECASE=1} {n=split($0,a,"/"); name=a[n]; sub(/\.[^.]*$/, "", name); if(name==key){print; exit}}' "$rom_files")
        printf 'screen-%02d.png|%s\n' "$screenshot_index" "$rom" >> "$screenshot_dir/screenshot-index.txt"
        screenshot_index=$((screenshot_index + 1))
    done < "$all_files"
    for old in "$screenshot_dir"/screen-*.png; do
        [ -f "$old" ] || continue
        grep -Fqx "$old" "$wanted_screens" || rm -f "$old"
    done
done

echo "Done. Press Y in Cartrix to reload the new support-texture labels."
exit 0
