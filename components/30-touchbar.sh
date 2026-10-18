# shellcheck shell=bash
NAME=touchbar
DESC="Touch Bar driver (ESC + media keys, Fn -> F1-F12, dimming, ambient light sensor) via DKMS"
DEFAULT=y
REQUIRES=ibridge
PKG=apple-t1-touchbar
PKGVER=0.3
comp_applicable() { has_t1 || { echo "no Apple T1 iBridge (05ac:8600)"; return 1; }; }
comp_install() {
    apt_install dkms build-essential "linux-headers-$KVER"
    dkms_install_pkg "$NAME" "$PKG" "$PKGVER" "$REPO/drivers/apple-t1-touchbar" all
    install_file "$NAME" "$REPO/files/modprobe.d/mbp-t1-touchbar.conf"     /etc/modprobe.d/mbp-t1-touchbar.conf
    install_file "$NAME" "$REPO/files/modprobe.d/mbp-t1-no-sensorhub.conf" /etc/modprobe.d/mbp-t1-no-sensorhub.conf
    install_file "$NAME" "$REPO/files/sbin/mbp-t1-touchbar-bind"           /usr/local/sbin/mbp-t1-touchbar-bind 755
    install_file "$NAME" "$REPO/files/systemd/mbp-t1-touchbar-bind.service" /etc/systemd/system/mbp-t1-touchbar-bind.service
    install_file "$NAME" "$REPO/files/system-sleep/mbp-t1-touchbar"        /usr/lib/systemd/system-sleep/mbp-t1-touchbar 755
    run systemctl daemon-reload
    run systemctl enable mbp-t1-touchbar-bind.service
    rebuild_initramfs        # the hid_sensor_* blacklist must also apply in the initramfs
    need_reboot
}
comp_check() { dkms status "$PKG/$PKGVER" 2>/dev/null | grep -c "$KVER.*installed" >/dev/null && [ -f /etc/modprobe.d/mbp-t1-touchbar.conf ]; }
comp_uninstall() {
    run systemctl disable mbp-t1-touchbar-bind.service 2>/dev/null || true
    dkms_remove_pkg "$PKG" "$PKGVER"
    UNINSTALL_REBUILD_INITRAMFS=1
    need_reboot
}
