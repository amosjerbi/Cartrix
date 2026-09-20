<p align="center">
  <img src="/cartrix-gg.png" alt="gg" width="320" />
  &nbsp;&nbsp;&nbsp;
  <img src="/cartrix-sms.png" alt="genesis" width="320" />
</p>

# Cartrix

Cartrix is a LÖVE 3D game carousel for ROCKNIX. On the Anbernic RG DS it spans both 640×480 displays with one borderless 1280×480 window. Select a game to see its cartridge or disc, artwork, screenshot, and play metadata, then press A to launch it.

## Supported Platforms in launcher

- Dreamcast
- Gamegear
- Gameboy
- Gameboy Color
- Gameboy Advance
- Genesis
- Master System
- N64
- NDS
- Neo Geo
- SNES
- Switch (Don't see it how it'd run on Rocknix XD)

## Current release

- The upper display shows a 3D model and game title. The lower display shows `MAIN STORY`, `PLAYED TIME`, and a screenshot. Both displays share the pale blue dotted background.
- Scraped cover art appears on the model's sticker layer. Games without scraped art receive a generated platform label. The model shells have subtle material texture, and embedded OBJ material colors are rendered where available.
- Dreamcast and Saturn use the same disc mesh with separate ROM libraries and artwork. Their printed front labels sit on a circular sticker layer. The back is smooth silver with a soft, shifting reflection.
- Pressing A on a Dreamcast or Saturn game spins the disc one full turn before it drops through the lower edge and launches. Other models retain the cartridge flip and insertion animation.
- The carousel can launch indexed games through ROCKNIX. The launcher keeps its process scope alive during gameplay and restores EmulationStation when Cartrix exits.

## Install on the RG DS

Unpack `Cartrix-rgds-launch.zip` into `/roms/ports/`. The archive contains:

```text
/roms/ports/
├── Cartrix.sh
├── enable_dual_screen_rgds.sh
└── Cartrix/
    ├── conf.lua
    ├── main.lua
    ├── scan-scrapes.sh
    ├── fullscreen-drastic.sh
    ├── fullscreen-retroarch.sh
    ├── models/
    ├── logos/
    └── textures/
```

Make the launcher and helper scripts executable if your unzip tool did not preserve permissions:

```sh
chmod +x /roms/ports/Cartrix.sh /roms/ports/enable_dual_screen_rgds.sh
chmod +x /roms/ports/Cartrix/*.sh
```

Launch **Cartrix** from EmulationStation's Ports menu. Its `gamelist.xml` entry should point to `./Cartrix.sh`. The launcher configures both screens, places the LÖVE window across them, and restores the normal frontend layout on exit. It tolerates display setup races after boot and retries one transient LÖVE startup failure.

### Requirements

- ROCKNIX with a working Sway/Wayland session.
- LÖVE 11.x. `Cartrix.sh` searches common ROCKNIX and PortMaster locations, including `/storage/roms/ports/PortMaster/runtimes/love_11.5/love.aarch64`.
- ROMs in ROCKNIX's platform folders. Emulator cores and any required BIOS files must already be configured for the games you want to launch.

## ROMs and artwork

On the first launch, Cartrix scans the ROM library. Press **Y** after adding games or scraping new images. You can also run `/roms/ports/Cartrix/scan-scrapes.sh` directly.

The scan writes data under `Cartrix/labels/<platform>/` and `Cartrix/screenshots/<platform>/`:

- `rom-index.txt` lists ROM paths.
- `scan-XX.png` contains scraped cover art for model labels. The scanner keeps up to 24 images per platform.
- `screen-XX.png` contains scraped screenshots for the lower display.

The scanner looks in the platform's `images` directory for ROCKNIX `-thumb.png`, `-image.png`, and `-marquee.png` artwork. If a game has no cover image, Cartrix shows a platform label on its model. If it has no screenshot, the lower display uses its cover or fallback label.

Dreamcast ROMs belong in `roms/dreamcast`; Saturn ROMs belong in `roms/saturn`. Their platform groups appear when the scan finds ROMs. The configured libretro cores are Flycast for Dreamcast and YabaSanshiro for Saturn.

## Controls

| Control | Action |
| --- | --- |
| D-pad Left / Right | Select a game |
| L / R | Change platform |
| A | Launch the selected game |
| B or Start | Exit Cartrix |
| X | Toggle model zoom |
| Y | Rescan ROMs and artwork |
| Left stick | Rotate the selected model |

Keyboard controls include Left/Right, L/R, Enter/Space to launch, Escape/Backspace to exit, X to zoom, and Y or S to rescan. Cartrix ignores the initial launch button press briefly so it does not immediately exit when opened from EmulationStation.

## Models and display

The package includes OBJ meshes for Game Boy, Game Boy Color, NES, SNES, Nintendo 64, Game Boy Advance, Game Gear, Genesis, Nintendo DS, Switch, Neo Geo, and the shared Dreamcast/Saturn disc. Additional platform entries in `main.lua` require their corresponding optional OBJ files.

The upper screen contains the carousel, platform logo, and selected-game title. The lower screen contains metadata and a screenshot. The dotted background is cached as a canvas, so drawing it on both displays does not rebuild every dot each frame.

Game Boy cartridges use the same gray body color as Game Boy Color cartridges; titles containing `Zelda` use the gold treatment. Zoom is capped to keep large models inside the display.

## Troubleshooting

Check these device logs when a scan, launch, or display handoff fails:

```text
/tmp/rocknix-3d-carousel/carousel.log
/tmp/rocknix-carousel-scan.log
/tmp/rocknix-carousel-launch.log
/var/log/es_launch_stdout.log
/var/log/es_launch_stderr.log
```

The carousel log records startup timing, exit reason, and LÖVE's exit status. `Cartrix.sh` closes an older matching Cartrix process before starting a new session so overlapping windows do not persist after an interrupted launch.

## Credits

The 3D models were sourced from [Thingiverse](https://www.thingiverse.com/).
