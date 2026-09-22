# ROCKNIX EmulationStation Support-Texture Fix

This directory contains a custom ROCKNIX/RG DS `emulationstation` binary with a fix for ScreenScraper **support textures** (cartridge labels).

The stock UI displayed the **SUPPORT TEXTURE** switch, but changing it did not affect the setting read by the scraper. The UI stored `ScrapeCartridge` in `SystemConf`, while ScreenScraper read it from `Settings`. As a result, support texture downloads remained disabled even when the switch appeared enabled.

## Install directly on the device

Copy `screenscraper-advanced.sh` and the complete `screenscraper-advanced`
directory to the same location on the ROCKNIX device. The resulting layout
must be:

```text
screenscraper-advanced.sh
screenscraper-advanced/
├── emulationstation
└── emulationstation.sha256
```

Do not launch this version from the Ports menu. Stopping `essway.service` also
terminates scripts launched by that service. Run the installer through SSH so
it remains alive while EmulationStation restarts.

From a computer on the same network, connect to the device:

```sh
ssh root@192.168.0.105
```

Enter the device password when prompted. The default ROCKNIX password is
`rocknix`.

After the SSH prompt appears, run this exact command:

```sh
sh /storage/roms/ports/screenscraper-advanced.sh
```

Wait for `EmulationStation patch installed successfully.` before closing the
SSH session. Then verify each part of the installation with these individually
copyable commands:

```sh
systemctl is-enabled emulationstation-custom.service
```

Expected result: `enabled`.

```sh
systemctl is-active emulationstation-custom.service
```

Expected result: `active`.

```sh
systemctl is-active essway.service
```

Expected result: `active`.

```sh
sha256sum /usr/bin/emulationstation
```

Expected checksum:

```text
ec11dc6bc29138a9d0b89b608d7e2566d36d829012e2a44765730687ce643773
```

Finally, confirm that EmulationStation has a running process:

```sh
pidof emulationstation
```

This should print a numeric process ID. Leave the SSH session with:

```sh
exit
```

The script verifies the device architecture and checksum, retains the prior
custom build as
`emulationstation.previous`, installs the persistent systemd bind mount, and
restarts the device's EmulationStation service. It works for both first-time
installation and later updates.

## Source fix

Edit:

```text
es-app/src/guis/GuiScraperStart.cpp
```

Change:

```cpp
addSwitch(_("SUPPORT TEXTURE"), "ScrapeCartridge", false);
```

to:

```cpp
addSwitch(_("SUPPORT TEXTURE"), "ScrapeCartridge", true);
```

The final argument selects the configuration store:

- `false`: `SystemConf` (incorrect for this option)
- `true`: `Settings` (the store read by `ScreenScraper.cpp`)

The fix used here is commit [`1e42f2932`](https://github.com/amosjerbi/emulationstation-next/commit/1e42f293214e0c30669cad29310def391694a24d).

## Build the ROCKNIX aarch64 binary

The repository includes this GitHub Actions workflow:

```text
.github/workflows/build-rocknix-rgds.yml
```

Push the source fix and dispatch the workflow:

```sh
git add es-app/src/guis/GuiScraperStart.cpp
git commit -m "Fix support texture scraper setting"
git push origin master

gh workflow run build-rocknix-rgds.yml \
  --repo OWNER/emulationstation-next \
  --ref master
```

ROCKNIX cross-compilation can take a long time, potentially hours. When it completes, download the `emulationstation-rocknix-rgds-aarch64` artifact and extract it. It should contain:

```text
emulationstation
emulationstation.sha256
```

Verify the artifact before installing it:

```sh
cd /path/to/emulationstation-rocknix-rgds-aarch64
shasum -a 256 emulationstation
cat emulationstation.sha256
file emulationstation
```

The hashes must match, and `file` must report an ARM aarch64 ELF executable.


## Connect to the ROCKNIX device

Replace `DEVICE_IP` below with the device address:

```sh
export DEVICE_IP=192.168.0.105
ssh root@"$DEVICE_IP"
```

If the device was reflashed and SSH reports that its host key changed, first verify that the fingerprint belongs to the device, then remove the obsolete entry and reconnect:

```sh
ssh-keygen -R "$DEVICE_IP"
ssh -o StrictHostKeyChecking=accept-new root@"$DEVICE_IP"
```

ROCKNIX may use password authentication. `sshpass` can be used for unattended commands, but normal `ssh`/`scp` prompts are safer because they do not place the password in shell history.

## Why a bind mount is required

On ROCKNIX, `/usr/bin/emulationstation` is stored in the read-only squashfs root filesystem. It cannot be replaced directly. Store the custom executable under `/storage`, then bind-mount it over the stock path.

Copy the binary to a staging path:

```sh
scp emulationstation root@"$DEVICE_IP":/storage/.config/emulationstation/emulationstation.next
```

Set permissions and verify the copied file:

```sh
ssh root@"$DEVICE_IP" '
  chmod 755 /storage/.config/emulationstation/emulationstation.next
  sha256sum /storage/.config/emulationstation/emulationstation.next
'
```

Compare that checksum with `emulationstation.sha256` before continuing.

## Test for the current boot only

The following bind mount is temporary and disappears after reboot:

```sh
ssh root@"$DEVICE_IP" '
  systemctl stop essway.service
  mount --bind \
    /storage/.config/emulationstation/emulationstation.next \
    /usr/bin/emulationstation
  systemctl start essway.service
'
```

Verify it:

```sh
ssh root@"$DEVICE_IP" '
  systemctl is-active essway.service
  sha256sum /usr/bin/emulationstation
  pidof emulationstation
'
```

## Make the patch survive reboot

ROCKNIX loads custom systemd units from `/storage/.config/system.d`. Create this local file as `emulationstation-custom.service`:

```ini
[Unit]
Description=Install persistent custom EmulationStation binary
RequiresMountsFor=/storage/.config/emulationstation/emulationstation.new
Before=essway.service emustation.service

[Service]
Type=oneshot
ExecStart=/bin/mount --bind /storage/.config/emulationstation/emulationstation.new /usr/bin/emulationstation
ExecStop=/bin/umount /usr/bin/emulationstation
RemainAfterExit=yes

[Install]
WantedBy=rocknix.target
```

Install and enable it:

```sh
scp emulationstation-custom.service \
  root@"$DEVICE_IP":/storage/.config/system.d/emulationstation-custom.service

ssh root@"$DEVICE_IP" '
  set -e
  mv /storage/.config/emulationstation/emulationstation.next \
     /storage/.config/emulationstation/emulationstation.new
  chmod 755 /storage/.config/emulationstation/emulationstation.new
  systemctl daemon-reload
  systemctl enable emulationstation-custom.service
  sync
  systemctl reboot
'
```

Rebooting avoids stacking a persistent bind mount on top of a temporary test mount.

After the device returns, verify persistence:

```sh
ssh root@"$DEVICE_IP" '
  systemctl is-enabled emulationstation-custom.service
  systemctl is-active emulationstation-custom.service essway.service
  sha256sum /usr/bin/emulationstation
  pidof emulationstation
'
```

## Update an existing persistent installation

When the persistent service is already installed, stage the new binary as `emulationstation.next`, verify its checksum, and replace the active stored binary safely:

```sh
scp emulationstation root@"$DEVICE_IP":/storage/.config/emulationstation/emulationstation.next

ssh root@"$DEVICE_IP" '
  set -e
  chmod 755 /storage/.config/emulationstation/emulationstation.next
  sha256sum /storage/.config/emulationstation/emulationstation.next

  systemctl stop essway.service
  systemctl stop emulationstation-custom.service

  mv /storage/.config/emulationstation/emulationstation.new \
     /storage/.config/emulationstation/emulationstation.previous
  mv /storage/.config/emulationstation/emulationstation.next \
     /storage/.config/emulationstation/emulationstation.new

  systemctl start emulationstation-custom.service
  systemctl start essway.service
'
```

Verify the live checksum afterward:

```sh
ssh root@"$DEVICE_IP" '
  systemctl is-active emulationstation-custom.service essway.service
  sha256sum /usr/bin/emulationstation
  pidof emulationstation
'
```

## Required scraper options

Open the scraper configuration in EmulationStation and use:

```text
SCRAPER                     SCREENSCRAPER
GAMES TO SCRAPE FOR         ALL
IGNORE RECENTLY SCRAPED     ALL
SUPPORT TEXTURE             ENABLED
```

Then start the scrape for the desired system.

For Game Gear, successful support textures are stored alongside the other scraped images:

```text
/storage/roms/gamegear/images/<ROM filename>-cartridge.png
```

The same directory may be visible over an attached or network-mounted ROM volume as:

```text
/Volumes/games-roms/gamegear/images/<ROM filename>-cartridge.png
```

Examples of other scraper output suffixes are `-image.png`, `-thumb.png`, and `-marquee.png`. The support texture uses `-cartridge.png`.

Not every ScreenScraper game entry necessarily has `support-texture` media. If only particular games are missing the file, confirm that those games have support-texture artwork on ScreenScraper and check EmulationStation's scraper log.

## Roll back

If an update fails and `emulationstation.previous` exists:

```sh
ssh root@"$DEVICE_IP" '
  set -e
  systemctl stop essway.service
  systemctl stop emulationstation-custom.service
  mv /storage/.config/emulationstation/emulationstation.new \
     /storage/.config/emulationstation/emulationstation.failed
  mv /storage/.config/emulationstation/emulationstation.previous \
     /storage/.config/emulationstation/emulationstation.new
  systemctl start emulationstation-custom.service
  systemctl start essway.service
'
```

To return entirely to the stock binary:

```sh
ssh root@"$DEVICE_IP" '
  systemctl stop essway.service
  systemctl disable --now emulationstation-custom.service
  systemctl start essway.service
'
```

The stock executable remains untouched inside the read-only ROCKNIX image.
