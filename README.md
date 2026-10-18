# MacBook Pro 2017 Linux Driver

One installer that makes a **15" MacBook Pro 2017 (MacBookPro14,3, T1 chip)** usable with Linux:
Touch Bar, speakers, suspend on lid close, USB-C after sleep, microphone, Bluetooth headset mic,
5 GHz Wi-Fi and a clean boot screen. All drivers are built with DKMS, so they survive kernel updates
(within the supported kernel series).

> 🇩🇪 Deutsche Anleitung: [README.de.md](README.de.md)

## Status

| Feature | Status | Component |
|---|---|---|
| Lid close → sleep, wakes up again | ✅ s2idle (S3 "deep" hangs on this model) | `suspend` |
| USB-C devices after sleep | ✅ | `thunderbolt-resume` |
| Touch Bar (ESC, media keys, Fn → F1–F12, dimming) | ✅ also after sleep | `ibridge` + `touchbar` |
| FaceTime camera, ambient light sensor | ✅ | `ibridge` + `touchbar` |
| Internal speakers | ✅ (amp gain reduced for safety) | `audio` |
| Headphone jack | ✅ (stock driver) | – |
| Internal microphone | ✅ ~20 dB louder + noise filter | `mic` |
| Bluetooth audio | ✅ (see tip below) | – |
| Bluetooth headset microphone | ✅ CVSD (mSBC delivers silence on this chip) | `bluetooth` |
| Wi-Fi 5 GHz | ✅ no more drop to 2.4 GHz | `wifi-regdom` |
| ISO (German etc.) keyboard layout | ✅ optional | `keyboard-iso` |
| Boot screen without flicker | ✅ | `boot-splash` |
| Touchpad palm clicks while typing | ✅ optional | `touchpad` |
| Touch ID | ❌ not possible with these drivers |
| Wired (3.5 mm) headset microphone | ❌ driver limitation (fix in progress, not included) |
| Custom Touch Bar graphics | ❌ needs a different T1 mode (not included) |

### Tested on

- **MacBookPro14,3** (15", 2017, Radeon Pro 555/560 + Intel HD 630, T1)
- **Ubuntu 26.04 LTS**, kernel **7.0.0-38-generic**, GNOME (Wayland), PipeWire 1.6

Every fix was developed and verified on this machine. The installer that packages them is new –
if something goes wrong, please open an issue (with `./install.sh --check` and `journalctl -b -k`).

Requirements: **Ubuntu 26.04** (or an Ubuntu-based system with apt, dracut and update-grub) on the
7.0 kernel series. The speaker driver additionally builds against Ubuntu's own kernel source.
Other models (MacBookPro14,1 / 14,2) are **untested**: the installer only offers components whose
hardware it actually detects.

## Install

Before you start:
- `ls /boot/efi/EFI/APPLE` must list files – that is the T1 firmware. If the Ubuntu installer wiped
  the EFI partition, Touch Bar and camera cannot work until macOS restores it.
- Secure Boot: not supported on these Macs anyway; DKMS modules are unsigned.

```bash
sudo apt update && sudo apt install -y git       # or: GitHub "Code > Download ZIP"
git clone https://github.com/Akaya1001/Macbook-Pro-2017-Linux-Driver.git
cd Macbook-Pro-2017-Linux-Driver
./install.sh --list            # what applies to your Mac
sudo ./install.sh              # asks for every component (recommended ones default to "yes")
```

Then **reboot**.

Other ways to run it:

```bash
sudo ./install.sh --yes                  # all recommended components, no questions
sudo ./install.sh --dry-run              # show what would be done, change nothing
sudo ./install.sh --only touchbar,audio  # only selected components (required ones are added)
sudo ./install.sh --country AT           # Wi-Fi country (otherwise you are asked; --yes needs it)
sudo ./install.sh --iso-keyboard         # also fix the ISO keyboard (^ and < swapped)
./install.sh --check                     # what is installed
sudo ./uninstall.sh                      # remove what the installer added (restores replaced files)
```

`uninstall.sh` keeps the firmware backup in `/var/backups/mbp2017-linux` and does not change the
power profile back. To update later: `git pull` and run `sudo ./install.sh` again.

If you already set up some of these fixes by hand (older guides, earlier versions), the installer
lists the clashing files and stops – move them away first.

Run it with `sudo` from your normal desktop account – some components (microphone, Bluetooth,
touchpad) change settings of that user.

## Components

| Component | What it does |
|---|---|
| `firmware-backup` | Saves `EFI/APPLE` (the T1 firmware) to `/var/backups/mbp2017-linux/`. **Copy it somewhere safe** – if the EFI partition is wiped, the Touch Bar/camera are gone for good, and another Mac's copy does not work. |
| `suspend` | `MemorySleepMode=s2idle`, PCI power pinning (`90-mbp-pm.rules`), lid → suspend. |
| `thunderbolt-resume` | systemd sleep hook that unbinds the `thunderbolt` driver before s2idle. Otherwise the driver puts the Alpine Ridge router into "LC sleep", from which it never wakes in s2idle – USB-C stays dead until reboot. Side effect: Thunderbolt docks/eGPUs re-enumerate after every sleep. |
| `ibridge` | Stops usbmuxd's udev rule from de-configuring the T1 iBridge (`05ac:8600`) and forces USB configuration 1. iPhone support stays. |
| `touchbar` | DKMS module `apple-t1-touchbar` (apple-ibridge, apple-ib-tb, apple-ib-als), blacklists `hid_sensor_hub` (it would grab the Touch Bar interface), bind service + resume hook. |
| `audio` | DKMS module `snd-hda-cs8409-apple` ([davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)), built against the Ubuntu kernel source of your exact kernel (downloaded automatically, ~190 MB once per kernel). Speaker amp gain lowered from 0x01 to 0x30 (−24 dB). |
| `mic` | PipeWire virtual microphone "Microphone (boosted + noise filter)": +24 dB gain, WebRTC noise suppression, echo cancellation, auto gain control. |
| `bluetooth` | Disables mSBC so Bluetooth headsets use CVSD for the microphone. |
| `wifi-regdom` | Fixed regulatory domain (`cfg80211 ieee80211_regdom=XX`). You are asked for your country (suggested from the current regulatory domain or time zone); with `--yes` pass `--country XX`, otherwise this step is skipped. |
| `keyboard-iso` | `applespi.iso_layout=1` (optional – only for ISO keyboards). |
| `boot-splash` | amdgpu in the initramfs, Plymouth waits for amdgpu, and a small dracut module switches the backlight off while amdgpu re-initialises the panel (the takeover flicker itself cannot be avoided on Polaris). |
| `touchpad` | Right-click area bottom-right, tap-to-click off (optional). |
| `kernel-pin` | Switches Ubuntu's HWE kernel meta package to `linux-generic` so you stay on the 7.0 series the speaker patches are made for. If a newer non-7.0 kernel is already installed, boot the 7.0 one from GRUB's *Advanced options*. |
| `power-profile` | Sets the power profile to "balanced" (optional). |

## Good to know

- **Bluetooth audio stutters?** Close *Settings → Bluetooth*. While it is open the adapter scans
  continuously, and this single-radio chip then has no air time for the music. Connect/disconnect
  via the quick-settings menu instead. `tools/bt-audio-rate.sh` measures it (healthy: steady ~45 kB/s).
- **Speakers:** there is no hardware volume limit and no crossover – keep bass-heavy music below
  ~70 %.
- **After a kernel update:** run `dkms status` – both drivers should show `installed` for the new
  kernel. The speaker driver only builds for 7.0.0-* kernels (see `kernel-pin`); each new 7.0
  kernel downloads its matching Ubuntu kernel source once (~190 MB).
- **Emergency (system does not boot properly):** in the GRUB menu press `e`, add
  `module_blacklist=snd_hda_codec_cs8409,apple_ibridge,apple_ib_tb,apple_ib_als` to the line
  starting with `linux`, boot with Ctrl+X, then run `sudo ./uninstall.sh`.
- **Never** run `powertop --auto-tune` and do not enable `powertop.service` (it re-runs auto-tune) –
  it undoes the power pinning and breaks resume/Touch Bar. With TLP, keep runtime PM off for PCI
  bridges/Thunderbolt and put `05ac:8600` on the USB denylist.
- Do not install other T1 Touch Bar drivers (macbook12-spi-driver, t1bridge, …) at the same time.

## Diagnostic tools

| Script | Purpose |
|---|---|
| `tools/mic-test.sh` | Records 5 s and prints speech/noise level of the default microphone. |
| `tools/bt-audio-rate.sh` | Measures the Bluetooth A2DP send rate while music plays. |
| `tools/bt-headset-mic-test.sh <MAC>` | Tests a Bluetooth headset microphone (HFP). |

## What was fixed in the drivers

The Touch Bar driver is based on Ronald Tschalär's apple-ibridge/apple-ib-tb/apple-ib-als
(via [parport0/mbp-t1-touchbar-driver](https://github.com/parport0/mbp-t1-touchbar-driver)) with these
fixes (`drivers/apple-t1-touchbar/patches/`, already applied to the sources):

| Patch | Fix |
|---|---|
| P1 | Skip the ACPI `SOCW` power method on MacBookPro13,x/14,x (hard-freezes the 14,3) – ported from AJ-dev-i60/t1-touchbar |
| P2 | Fix a kernel NULL-pointer crash in the ambient light sensor when a report arrives during probe |
| P3 | Add the threaded IRQ handler the IIO trigger needs (kernel warning on 7.0) |
| P4 | Touch Bar now comes back after normal (non-reset) resume; fix input-handler list corruption on re-bind; forward PM callbacks to all sub-devices |
| P5 | Balance the runtime-PM reference after re-bind/resume; fix an error path that returned a bogus pointer |

The speaker driver is [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
at commit `89b22ff`, packaged for DKMS and built strictly against the matching Ubuntu kernel
source (building against the kernel.org 7.0 tarball crashes because Ubuntu's `struct hda_multi_out`
differs).

## Credits

- Ronald Tschalär – original T1 iBridge/Touch Bar/ALS drivers
- [parport0/mbp-t1-touchbar-driver](https://github.com/parport0/mbp-t1-touchbar-driver) – port to recent kernels (base, commit `6d62f38`)
- [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) – kernel-7 port; the `skip_acpi_power` SOCW skip (P1) and the sub-device NULL check (P4) are taken from its `apple-ib-drv/apple-ibridge.c` (GPL-2.0)
- [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) – CS8409 Apple audio
- [Dunedan/mbp-2016-linux](https://github.com/Dunedan/mbp-2016-linux) – the reference for these Macs
- [@orospakr](https://github.com/orospakr) – identified the Alpine Ridge "LC sleep" mechanism on a MacBookPro14,1 ([omacom/omarchy#9899](https://github.com/omacom/omarchy/pull/9899)); [omacom/omarchy-pkgs#596](https://github.com/omacom/omarchy-pkgs/pull/596) – confirmed it for s2idle on the MacBookPro14,3

Put together on a MacBookPro14,3 with the help of Claude Code.

## License

GPL-2.0 (see [LICENSE](LICENSE)), like the drivers it contains.
No warranty – this touches kernel modules, initramfs and boot configuration. Keep the firmware backup.
