# MacBook Pro 2017 Linux-Treiber

Ein Installer, der ein **15" MacBook Pro 2017 (MacBookPro14,3, T1-Chip)** unter Linux voll nutzbar macht:
Touch Bar, Lautsprecher, Schlafmodus beim Zuklappen, USB-C nach dem Aufwachen, Mikrofon,
Bluetooth-Headset-Mikro, 5-GHz-WLAN und ein sauberes Boot-Bild. Die Treiber werden per DKMS gebaut
und überstehen damit Kernel-Updates (innerhalb der Kernelreihe 7.0).

> 🇬🇧 English: [README.md](README.md)

## Was funktioniert

| Funktion | Stand | Komponente |
|---|---|---|
| Zuklappen → Schlafen, wacht wieder auf | ✅ s2idle (S3 „deep“ hängt auf diesem Modell) | `suspend` |
| USB-C-Geräte nach dem Aufwachen | ✅ | `thunderbolt-resume` |
| Touch Bar (ESC, Medientasten, Fn → F1–F12, Dimmen) | ✅ auch nach dem Schlafen | `ibridge` + `touchbar` |
| FaceTime-Kamera, Umgebungslichtsensor | ✅ | `ibridge` + `touchbar` |
| Interne Lautsprecher | ✅ (Verstärkung zur Sicherheit reduziert) | `audio` |
| Kopfhörerbuchse | ✅ (Standardtreiber) | – |
| Internes Mikrofon | ✅ ~20 dB lauter + Rauschfilter | `mic` |
| Bluetooth-Audio | ✅ (siehe Tipp unten) | – |
| Bluetooth-Headset-Mikrofon | ✅ CVSD (mSBC liefert auf diesem Chip nur Stille) | `bluetooth` |
| WLAN 5 GHz | ✅ kein Zurückfallen auf 2,4 GHz mehr | `wifi-regdom` |
| Deutsche (ISO-)Tastatur | ✅ optional | `keyboard-iso` |
| Boot-Bild ohne Flackern | ✅ | `boot-splash` |
| Touchpad: keine Handballen-Klicks beim Tippen | ✅ optional | `touchpad` |
| Touch ID | ❌ mit diesen Treibern nicht möglich |
| Kabel-Headset-Mikrofon (Klinke) | ❌ Treiber-Einschränkung (Fix in Arbeit, nicht enthalten) |
| Eigene Grafiken auf der Touch Bar | ❌ braucht einen anderen T1-Modus (nicht enthalten) |

**Getestet auf:** MacBookPro14,3 mit Ubuntu 26.04 LTS, Kernel 7.0.0-38-generic, GNOME (Wayland).
Alle Fixes wurden auf diesem Mac entwickelt und geprüft; der Installer, der sie bündelt, ist neu –
bei Problemen bitte ein Issue öffnen (mit `./install.sh --check` und `journalctl -b -k`).

**Voraussetzungen:** Ubuntu 26.04 (oder ein Ubuntu-basiertes System mit apt, dracut und update-grub)
mit Kernelreihe 7.0. Andere Modelle (14,1 / 14,2) sind **ungetestet**; der Installer bietet nur
Komponenten an, deren Hardware er tatsächlich erkennt.

## Installation

Vorher prüfen:
- `ls /boot/efi/EFI/APPLE` muss Dateien zeigen (T1-Firmware). Hat der Ubuntu-Installer die
  EFI-Partition gelöscht, funktionieren Touch Bar und Kamera erst wieder, wenn macOS sie herstellt.

```bash
sudo apt update && sudo apt install -y git       # oder bei GitHub „Code > Download ZIP“
git clone https://github.com/Akaya1001/Macbook-Pro-2017-Linux-Driver.git
cd Macbook-Pro-2017-Linux-Driver
./install.sh --list            # was passt zu meinem Mac?
sudo ./install.sh              # fragt jede Komponente einzeln ab (empfohlene stehen auf „Ja“)
```

Danach **neu starten**.

Weitere Varianten:

```bash
sudo ./install.sh --yes                  # alle empfohlenen Komponenten ohne Nachfragen
sudo ./install.sh --dry-run              # nur anzeigen, was passieren würde
sudo ./install.sh --only touchbar,audio  # nur bestimmte Komponenten (benötigte kommen automatisch dazu)
sudo ./install.sh --country DE           # WLAN-Land (sonst wird gefragt; bei --yes nötig)
sudo ./install.sh --iso-keyboard         # deutsche Tastatur: ^ und < richtig belegen
./install.sh --check                     # was ist installiert?
sudo ./uninstall.sh                      # Installiertes entfernen (ersetzte Dateien werden wiederhergestellt)
```

Das Firmware-Backup bleibt bei der Deinstallation erhalten. Aktualisieren: `git pull`, dann erneut
`sudo ./install.sh`. Wer Teile schon von Hand eingerichtet hat, bekommt die kollidierenden Dateien
angezeigt und muss sie vorher wegräumen.

Bitte mit `sudo` aus dem **normalen Benutzerkonto** starten. Einige Komponenten (Mikrofon, Bluetooth,
Touchpad) ändern Einstellungen dieses Benutzers.

## Gut zu wissen

- **Bluetooth-Ton stottert?** Das Fenster *Einstellungen → Bluetooth* schließen. Solange es offen ist,
  sucht der Chip ständig nach Geräten und hat keine Sendezeit für die Musik. Verbinden und Trennen
  über das Schnellmenü oben rechts.
- **Lautsprecher:** Es gibt keine Hardware-Lautstärkegrenze und keine Frequenzweiche. Basslastige
  Musik besser unter ~70 %.
- **Nach Kernel-Updates:** `dkms status` prüfen, beide Treiber sollten „installed“ zeigen. Der
  Lautsprecher-Treiber baut nur für 7.0.0-*-Kernel – die Komponente `kernel-pin` (ersetzt den
  HWE-Kernel durch `linux-generic`) hält dich auf dieser Reihe.
- **Notfall (System startet nicht richtig):** Im GRUB-Menü `e` drücken, an die Zeile mit `linux`
  `module_blacklist=snd_hda_codec_cs8409,apple_ibridge,apple_ib_tb,apple_ib_als` anhängen, mit Strg+X
  starten, dann `sudo ./uninstall.sh`.
- **Firmware-Backup** (`/var/backups/mbp2017-linux/`) unbedingt extern sichern – ohne diese Dateien
  sind Touch Bar und Kamera dauerhaft weg, und die Kopie eines anderen Macs funktioniert nicht.
- **Niemals** `powertop --auto-tune` ausführen und `powertop.service` nicht aktivieren – das hebt
  die Stromspar-Sperren auf. Mit TLP: Runtime-PM für PCI-Brücken/Thunderbolt aus, `05ac:8600` auf
  die USB-Denylist.
- Keine anderen T1-Touch-Bar-Treiber parallel installieren.

Details zu jeder Komponente, den Treiber-Patches und den Credits stehen im [englischen README](README.md).

## Lizenz

GPL-2.0, wie die enthaltenen Treiber. Ohne Gewähr.
