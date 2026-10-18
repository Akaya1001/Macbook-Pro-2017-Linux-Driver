# shellcheck shell=bash
NAME=bluetooth
DESC="Bluetooth headset microphone: use CVSD (mSBC gives only silence on this chip)"
DEFAULT=y
comp_applicable() {
    [ -n "$TARGET_USER" ] || { echo "run via sudo from your desktop user"; return 1; }
    ls /sys/bus/serial/drivers/hci_uart_bcm/ 2>/dev/null | grep -c serial >/dev/null || { echo "no Broadcom UART Bluetooth (hci_uart_bcm)"; return 1; }
}
comp_install() {
    write_user_file "$NAME" .config/wireplumber/wireplumber.conf.d/51-mbp-bluez-no-msbc.conf < "$REPO/files/user/51-mbp-bluez-no-msbc.conf"
    as_user systemctl --user restart wireplumber || true
    info "tip: keep Settings > Bluetooth closed while listening – its continuous device scan makes audio stutter"
}
comp_check() { [ -n "$TARGET_HOME" ] && [ -f "$TARGET_HOME/.config/wireplumber/wireplumber.conf.d/51-mbp-bluez-no-msbc.conf" ]; }
comp_uninstall() { UNINSTALL_RESTART_PIPEWIRE=1; }
