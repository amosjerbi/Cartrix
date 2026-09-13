# Cartrix

Cartrix is a LÖVE-based 3D cartridge carousel for ROCKNIX. On the Anbernic RG DS it uses one borderless 1280×480 window spanning both 640×480 displays. Cartrix is currently a library browser; it does not launch games.

## Display layout

- Upper display: centered 3D cartridge carousel, selected-game title, platform logo, and L/R platform hints.
- Lower display, left: `MAIN STORY` and `PLAYED TIME` values read from the ROM platform's `gamelist.xml`.
- Lower display, right: selected-game screenshot, falling back to its cover when no screenshot is available.
- Lower display, bottom: Start/Exit, X/Zoom, and Y/Scan instructions.

`Cartrix.sh` powers both panels, waits for the LÖVE window, and reapplies its floating 1280×480 placement after ROCKNIX finishes its own launch-time display changes. On exit it restores EmulationStation fullscreen on the upper panel and powers off the lower panel.

## Folder layout

Install the launcher under:

```text
/roms/ports/
├── Cartrix.sh
├── enable_dual_screen_rgds.sh
└── Cartrix/
    ├── conf.lua
    ├── main.lua
    ├── models/
    ├── labels/
    ├── screenshots/
    └── logos/
```

Make both launch scripts executable:

```sh
chmod +x "/roms/ports/Cartrix.sh"
chmod +x "/roms/ports/enable_dual_screen_rgds.sh"
```

`enable_dual_screen_rgds.sh` installs the persistent RG DS display configuration. Its Cartrix mode can also configure the panels without restarting Sway. The launcher invokes that mode automatically, so the helper does not need to be run separately before each Cartrix session.

The resulting Sway configuration includes a rule equivalent to:

```text
for_window [title="ROCKNIX 3D Carousel"] floating enable, fullscreen disable, border none, resize set width 1280 height 480, move absolute position 0 0, focus
```

The launch path tolerates Sway startup races after a reboot and retries one transient LÖVE/Mali initialization failure before the library becomes ready.

## Runtime requirements

- ROCKNIX on the target device.
- LÖVE 11.x, normally the PortMaster runtime at:

  ```text
  /storage/roms/ports/PortMaster/runtimes/love_11.5/love.aarch64
  ```

- A working Sway/Wayland session.

`Cartrix.sh` searches common ROCKNIX and PortMaster LÖVE locations automatically.

## Artwork

Press Y inside Cartrix after adding ROMs or scraping new artwork. To run the same scan manually:

```sh
"/roms/ports/Cartrix/scan-scrapes.sh"
```

Artwork is separated by purpose:

- `labels/<platform>/scan-XX.png`: cover art used on the 3D cartridge.
- `screenshots/<platform>/screen-XX.png`: scraped screenshots used only on the lower display.
- `logos/png/<platform>.png`: proportionally fitted platform logos shown above the upper carousel.

Screenshots are read from ROCKNIX `*-image.png` artwork. When no screenshot exists, the lower display falls back to the selected cartridge cover.

## Controls

- Left / Right or D-pad Left / Right: select a game.
- L / R shoulder buttons: change platform.
- X: toggle cartridge zoom.
- Y: rescan ROMs and scraped artwork, then refresh the carousel.
- Start or Escape: exit.

Launch-time Start events are ignored briefly so the button press used in EmulationStation cannot immediately close Cartrix.

## Supported platforms

The carousel defines cartridge/disc presentations for:

Game Boy, Game Boy Color, NES, SNES, PAL SNES, Nintendo 64, Game Boy Advance, Game Gear, Sega Genesis, Nintendo DS, Nintendo Switch, PlayStation Vita, PSP/UMD, PlayStation, Nintendo 3DS, and Neo Geo.

Game Boy cartridges use the same gray body color as Game Boy Color cartridges. Titles containing `Zelda` retain the gold cartridge treatment. Zoom is capped consistently across platforms to keep large models inside the display.

## Launching

From EmulationStation, open Ports and launch `Cartrix`. The `gamelist.xml` entry should point to `./Cartrix.sh`. No separate wake script, emulator wrapper, or display-activation step is required.

For troubleshooting, inspect:

```text
/tmp/rocknix-3d-carousel/carousel.log
/tmp/rocknix-carousel-scan.log
/var/log/es_launch_stdout.log
/var/log/es_launch_stderr.log
```

The carousel log records launch attempts, startup timing, exit reason, and LÖVE's exit status. `Cartrix.sh` automatically removes an older matching Cartrix process before starting a new session, preventing overlapping windows after an interrupted launch.

## Credits
For all the 3D models - https://www.thingiverse.com/
