#!/bin/sh

# Collect scraped artwork from every ROCKNIX platform folder into the app's
# label directories. The carousel reloads files named scan-XX.png after this
# script returns.
set -u

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$APP_DIR/labels"

platforms="gb gbc nes snes n64 gba nds switch vita psp psx 3ds gamegear genesis"
for root in /roms /storage/roms /storage/games-internal/roms; do
    for image_dir in "$root"/*/images; do
        [ -d "$image_dir" ] || continue
        platform=$(basename "$(dirname "$image_dir")")
        case " $platforms " in
            *" $platform "*) ;;
            *) platforms="$platforms $platform" ;;
        esac
    done
done

for platform in $platforms; do
    out="$APP_DIR/labels/$platform"
    mkdir -p "$out"
    rm -f "$out"/scan-*.png
    : > "$out/scan-index.txt"
    seen="$out/.scan-seen"
    : > "$seen"
    index=1
    for suffix in '-thumb.png' '-image.png' '-marquee.png'; do
        for root in /roms /storage/roms /storage/games-internal/roms; do
            source="$root/$platform"
            [ -d "$source" ] || continue
            find "$source" -type f ! -path '*/.focus-3d/*' -iname "*$suffix" -print | sort > "$out/.scan-files"
            while IFS= read -r file; do
                [ "$index" -le 24 ] || break
                base=$(basename "$file")
                key=${base%$suffix}
                grep -Fqx "$key" "$seen" && continue
                printf '%s\n' "$key" >> "$seen"
                target=$(printf '%s/scan-%02d.png' "$out" "$index")
                cp -f "$file" "$target" 2>/dev/null || continue
                rom=$(find "$root/$platform" -type f \
                    ! -path '*/images/*' ! -path '*/.focus-3d/*' \
                    ! -iname '*.srm' ! -iname '*.png' ! -iname '*.jpg' \
                    ! -iname '*.xml' ! -iname '*.txt' ! -iname '*.pdf' \
                    -iname "$key.*" -print -quit 2>/dev/null)
                printf 'scan-%02d.png|%s\n' "$index" "$rom" >> "$out/scan-index.txt"
                index=$((index + 1))
            done < "$out/.scan-files"
        done
    done
    : > "$out/rom-index.txt"
    rom_seen="$out/.rom-seen"
    : > "$rom_seen"
    for root in /roms /storage/roms /storage/games-internal/roms; do
        source="$root/$platform"
        [ -d "$source" ] || continue
        find "$source" -type f \
            ! -path '*/images/*' ! -path '*/videos/*' ! -path '*/manuals/*' ! -path '*/.focus-3d/*' \
            ! -iname '*.srm' ! -iname '*.png' ! -iname '*.jpg' \
            ! -iname '*.jpeg' ! -iname '*.webp' ! -iname '*.xml' \
            ! -iname '*.txt' ! -iname '*.pdf' ! -iname '*.tmp' \
            ! -name '._*' ! -name '.*' -print | sort | while IFS= read -r file; do
                base=$(basename "$file")
                grep -Fqx "$base" "$rom_seen" && continue
                printf '%s\n' "$base" >> "$rom_seen"
                printf '%s\n' "$file" >> "$out/rom-index.txt"
            done
    done
    rm -f "$seen" "$out/.scan-files" "$rom_seen"
done

exit 0
