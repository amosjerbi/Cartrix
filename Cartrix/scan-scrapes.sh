#!/bin/sh

# Build Cartrix indexes from one inventory per platform. ROCKNIX exposes the
# same ROM storage through several aliases, so roots are deduplicated first.
set -eu

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$APP_DIR/labels" "$APP_DIR/screenshots"
WORK_DIR=$(mktemp -d "$APP_DIR/.scan-work.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

ROOTS_FILE="$WORK_DIR/roots"
: > "$ROOTS_FILE"
seen_roots=""
for candidate in /roms /storage/roms /storage/games-internal/roms; do
    [ -d "$candidate" ] || continue
    root=$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")
    identity=$(stat -c '%d:%i' "$root" 2>/dev/null || printf '%s' "$root")
    case " $seen_roots " in *" $identity "*) continue ;; esac
    seen_roots="$seen_roots $identity"
    printf '%s\n' "$root" >> "$ROOTS_FILE"
done

PLATFORMS_FILE="$WORK_DIR/platforms"
printf '%s\n' gb gbc nes snes n64 gba nds switch vita psp psx 3ds gamegear genesis > "$PLATFORMS_FILE"
while IFS= read -r root; do
    for image_dir in "$root"/*/images; do
        [ -d "$image_dir" ] || continue
        basename "$(dirname "$image_dir")" >> "$PLATFORMS_FILE"
    done
done < "$ROOTS_FILE"
sort -u "$PLATFORMS_FILE" -o "$PLATFORMS_FILE"

copy_if_changed() {
    if [ ! -f "$2" ] || ! cmp -s "$1" "$2"; then cp -f "$1" "$2"; fi
}

while IFS= read -r platform; do
    out="$APP_DIR/labels/$platform"
    screenshot_dir="$APP_DIR/screenshots/$platform"
    mkdir -p "$out" "$screenshot_dir"
    all_files="$WORK_DIR/$platform.all"
    rom_files="$WORK_DIR/$platform.roms"
    : > "$all_files"
    while IFS= read -r root; do
        source="$root/$platform"
        [ -d "$source" ] || continue
        find "$source" -type f ! -path '*/.focus-3d/*' -print >> "$all_files"
    done < "$ROOTS_FILE"
    sort -u "$all_files" -o "$all_files"

    awk -v platform="$platform" '
        platform == "nds" && tolower($0) !~ /\.(nds|zip|7z)$/ { next }
        /\/images\// || /\/videos\// || /\/manuals\// || /\/.focus-3d\// { next }
        tolower($0) ~ /\.(srm|png|jpg|jpeg|webp|xml|txt|pdf|tmp)$/ { next }
        { n=split($0,a,"/"); if (a[n] !~ /^\./) print }
    ' "$all_files" | sort -u > "$rom_files"

    : > "$out/scan-index.txt"
    : > "$out/rom-index.txt"
    seen_names="$WORK_DIR/$platform.rom-seen"
    : > "$seen_names"
    while IFS= read -r rom; do
        name=${rom##*/}
        grep -Fqx "$name" "$seen_names" && continue
        printf '%s\n' "$name" >> "$seen_names"
        printf '%s\n' "$rom" >> "$out/rom-index.txt"
    done < "$rom_files"

    seen_art="$WORK_DIR/$platform.art-seen"
    wanted_art="$WORK_DIR/$platform.art-wanted"
    : > "$seen_art"; : > "$wanted_art"
    index=1
    for suffix in '-thumb.png' '-image.png' '-marquee.png'; do
        while IFS= read -r file; do
            [ "$index" -le 24 ] || break
            case "${file##*/}" in *"$suffix") ;; *) continue ;; esac
            base=${file##*/}; key=${base%$suffix}
            grep -Fqx "$key" "$seen_art" && continue
            printf '%s\n' "$key" >> "$seen_art"
            target=$(printf '%s/scan-%02d.png' "$out" "$index")
            copy_if_changed "$file" "$target"
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
    wanted_screens="$WORK_DIR/$platform.screen-wanted"
    seen_screens="$WORK_DIR/$platform.screen-seen"
    : > "$wanted_screens"; : > "$seen_screens"
    screenshot_index=1
    while IFS= read -r file; do
        [ "$screenshot_index" -le 24 ] || break
        case "${file##*/}" in *-image.png) ;; *) continue ;; esac
        base=${file##*/}; key=${base%-image.png}
        grep -Fqx "$key" "$seen_screens" && continue
        printf '%s\n' "$key" >> "$seen_screens"
        target=$(printf '%s/screen-%02d.png' "$screenshot_dir" "$screenshot_index")
        copy_if_changed "$file" "$target"
        printf '%s\n' "$target" >> "$wanted_screens"
        rom=$(awk -v key="$key" 'BEGIN{IGNORECASE=1} {n=split($0,a,"/"); name=a[n]; sub(/\.[^.]*$/, "", name); if(name==key){print; exit}}' "$rom_files")
        printf 'screen-%02d.png|%s\n' "$screenshot_index" "$rom" >> "$screenshot_dir/screenshot-index.txt"
        screenshot_index=$((screenshot_index + 1))
    done < "$all_files"
    for old in "$screenshot_dir"/screen-*.png; do
        [ -f "$old" ] || continue
        grep -Fqx "$old" "$wanted_screens" || rm -f "$old"
    done
done < "$PLATFORMS_FILE"

exit 0
