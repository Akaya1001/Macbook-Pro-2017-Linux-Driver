# shellcheck shell=bash
NAME=audio
DESC="Internal speakers (CS8409 + MAX98706 amps) – davidjo/snd_hda_macbookpro, amp gain reduced for safety"
DEFAULT=y
PKG=snd-hda-cs8409-apple
PKGVER=0.2.89b22ff
codec_subsys() { grep -h 'Subsystem Id' /proc/asound/card*/codec#* 2>/dev/null | awk '{print $3}'; }
comp_applicable() {
    codec_subsys | grep -cx 0x106b3900 >/dev/null || { echo "only tested on MacBookPro14,3 (codec subsystem 0x106b3900)"; return 1; }
    is_ubuntu || { echo "needs Ubuntu (builds against the matching Ubuntu linux-source package)"; return 1; }
    [[ $KVER == 7.0.0-* ]] || { echo "patches target the 7.0 kernel series (running $KVER)"; return 1; }
}
comp_install() {
    apt_install dkms build-essential "linux-headers-$KVER"
    dkms_install_pkg "$NAME" "$PKG" "$PKGVER" "$REPO/drivers/snd-hda-cs8409-apple" running+newest
    record_path "$NAME" /var/cache/snd-hda-cs8409-apple
    warn "speakers: there is no hardware volume limit – keep the volume moderate (< ~70 % for bass-heavy music)"
    need_reboot
}
comp_check() { dkms status "$PKG/$PKGVER" 2>/dev/null | grep -c "$KVER.*installed" >/dev/null; }
comp_uninstall() { dkms_remove_pkg "$PKG" "$PKGVER"; need_reboot; }
