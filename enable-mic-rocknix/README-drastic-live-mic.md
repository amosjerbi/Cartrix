# DraStic live microphone on ROCKNIX RGDS

This bundle enables the RGDS built-in microphone in DraStic's emulated DS microphone. Brain Age Colors recognized most or all spoken colors in a live test on the RGDS at 192.168.0.105.

The bridge targets the ROCKNIX DraStic AArch64 binary with SHA-256 `d54980a36c5e0b5cc46868bf25acd5d33b4c5337334fd0c417255a36942feb95` (Build ID `7a5e0e5fc6e52e6e8f5499c3d4d667ef51db0748`). The installer checks the binary before changing anything. Different DraStic builds need a separately verified hook.

## Install on another RGDS

1. Start DraStic once on the target unit, then close it.
2. Copy `install-drastic-live-mic.sh` and `drastic-live-mic.so` together to `/storage/bin/` on the target unit.
3. On the target unit, run `sh /storage/bin/install-drastic-live-mic.sh` as root.
4. Start Brain Age in DraStic and test Colors.

The installer backs up the original launcher as `/storage/.config/drastic/drastic.pre-live-mic`. To remove the hook, close DraStic and run `sh /storage/bin/install-drastic-live-mic.sh --restore`.

The source is `drastic-live-mic.c`. The bridge is experimental because it patches a function in a proprietary binary at runtime. The version check prevents applying that patch to an unverified binary.
