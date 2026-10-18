# shellcheck shell=bash
NAME=ibridge
DESC="Enable the T1 iBridge (needed for Touch Bar, FaceTime camera, ambient light sensor)"
DEFAULT=y
comp_applicable() { has_t1 || { echo "no Apple T1 iBridge (05ac:8600)"; return 1; }; }
comp_install() {
    local sys=/usr/lib/udev/rules.d/39-usbmuxd.rules
    # usbmuxd's rule de-configures the iBridge (bConfigurationValue=0). Override it with a
    # copy that no longer matches 05ac:8600 – iPhone support (05ac:12xx) stays intact.
    if [ -f "$sys" ] && grep -q '5ac/8600' "$sys"; then
        sed 's#|5ac/8600/\*##' "$sys" | write_file "$NAME" /etc/udev/rules.d/39-usbmuxd.rules
        warn "/etc/udev/rules.d/39-usbmuxd.rules overrides the packaged rule; re-run this installer after usbmuxd updates"
    else
        info "usbmuxd rule does not touch the iBridge – nothing to override"
    fi
    install_file "$NAME" "$REPO/files/udev/99-mbp-ibridge.rules" /etc/udev/rules.d/99-mbp-ibridge.rules
    run udevadm control --reload
    need_reboot
}
comp_check() {
    [ -f /etc/udev/rules.d/99-mbp-ibridge.rules ] || return 1
    local d; for d in /sys/bus/usb/devices/*; do
        [ "$(cat "$d/idProduct" 2>/dev/null)" = 8600 ] && [ "$(cat "$d/idVendor" 2>/dev/null)" = 05ac ] && { [ "$(cat "$d/bConfigurationValue" 2>/dev/null)" = 1 ]; return; }
    done; return 1
}
comp_uninstall() { run udevadm control --reload; need_reboot; }
