# Cartrix Launcher

A LÖVE-based game carousel for ROCKNIX. It presents platforms as tinted,
opaque 3D cartridge models and displays scraped game artwork on the selected
model and in the cover strip below it. The original neutral cartridge gray is
kept in the renderer as `#9EA3AD`.

The launcher supports Game Boy, Game Boy Color, NES, SNES, N64, GBA, DS, Game
Gear, Genesis, Switch, Vita, PSP, PSX, and 3DS when scraped ROM data is
available. Platforms without scraped data are hidden.

## Project layout

```text
Cartrix Launcher.sh         # launcher; stays at the ports root
Cartrix Launcher/
├── main.lua                # carousel UI, input, rendering, and launching
├── conf.lua                # LÖVE configuration
├── scan-scrapes.sh         # scans ROM artwork and builds label manifests
├── fullscreen-retroarch.sh # restores fullscreen/focus after launching a game
├── models/                 # OBJ cartridge models and attribution files
└── labels/                 # platform artwork and generated scan labels
```

On the device, the corresponding paths are:

```text
'/roms/ports/Cartrix Launcher.sh'
/roms/ports/Cartrix Launcher/
```

## Controls

| Input | Action |
| --- | --- |
| L / R shoulder | Switch platform |
| D-pad left / right | Select a scraped game cover |
| Left analog stick | Rotate the selected 3D model |
| X | Toggle 1.7× zoom on the selected cartridge |
| A | Launch the selected ROM |
| Y | Scan all platform ROM folders for new scraped artwork |
| Start | Exit the carousel |

Keyboard controls provide equivalent navigation where available: arrow keys
change covers, `R`/`L` switch platforms, `X` zooms, `Y`/`S` scans, Enter or
Space launches a game, and Escape exits.

## Scraped artwork

`scan-scrapes.sh` searches these ROCKNIX ROM roots:

```text
/roms
/storage/roms
/storage/games-internal/roms
```

For each platform it searches `images/` for `*-thumb.png`, `*-image.png`, and
`*-marquee.png`, removes duplicates, and creates up to 24 entries in
`labels/<platform>/`. Each platform also receives a `scan-index.txt` manifest
that maps the generated artwork to its ROM path.

The scan runs at startup and can be run again with Y after new artwork or ROMs
are added.

## Running on ROCKNIX

Launch the port with:

```sh
'/roms/ports/Cartrix Launcher.sh'
```

The launcher locates the available LÖVE runtime, starts the application from
`/roms/ports/Cartrix Launcher`, and writes its log to:

```text
/tmp/rocknix-3d-carousel/carousel.log
```

Selecting a cover launches it through ROCKNIX's `runemu.sh` with the platform's
RetroArch core. The fullscreen helper restores RetroArch focus and returns
focus to EmulationStation after the game exits.

## Model and sticker conventions

Models are loaded from `models/clean/` without runtime decimation when their
platform configuration sets `noDecimate = true`. An OBJ may include an object
named `Sticker`; its faces are treated as the artwork surface. If that layer
has no UV coordinates, the launcher generates planar UVs from the sticker's
local bounds so scraped covers still map correctly.

To add a platform:

1. Add its OBJ under `Cartrix Launcher/models/clean/`.
2. Add the platform configuration, tint, orientation, and label settings in
   `Cartrix Launcher/main.lua`.
3. Add or scan artwork with Y.
4. Deploy the updated `Cartrix Launcher/` directory and root
   `Cartrix Launcher.sh` to `/roms/ports/`.

## Credits
Used 3D models from https://www.patreon.com/SocketLauncher/posts/socket-0-3-2-166847366
