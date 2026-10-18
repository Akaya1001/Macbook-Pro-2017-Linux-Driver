# shellcheck shell=bash
NAME=touchpad
DESC="Touchpad: right-click in the bottom-right corner, no tap-to-click (stops palm clicks moving the cursor while typing)"
DEFAULT=n   # personal preference
comp_applicable() { [ -n "$TARGET_USER" ] || { echo "run via sudo from your desktop user"; return 1; }; command -v gsettings >/dev/null || { echo "no GNOME"; return 1; }; }
comp_install() {
    as_user gsettings set org.gnome.desktop.peripherals.touchpad click-method areas
    as_user gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click false
    run mkdir -p "$STATE_DIR"; [ "$DRY_RUN" = 1 ] || touch "$STATE_DIR/touchpad.applied"
}
comp_check() { [ -f "$STATE_DIR/touchpad.applied" ]; }
comp_uninstall() {
    as_user gsettings reset org.gnome.desktop.peripherals.touchpad click-method
    as_user gsettings reset org.gnome.desktop.peripherals.touchpad tap-to-click
    run rm -f "$STATE_DIR/touchpad.applied"
}
