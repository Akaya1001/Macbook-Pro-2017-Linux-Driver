# shellcheck shell=bash
NAME=keyboard-iso
DESC="ISO (e.g. German) keyboard: swap ^ and < back to the right keys (applespi.iso_layout=1)"
DEFAULT=n   # only for ISO keyboards – test: does the key left of '1' type '<'? then you need this
comp_applicable() { [ -d /sys/module/applespi ] || { echo "applespi keyboard driver not loaded"; return 1; }; }
comp_install() {
    write_file "$NAME" /etc/default/grub.d/91-mbp-applespi-iso.cfg <<'X'
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT applespi.iso_layout=1"
X
    run update-grub
    [ "$DRY_RUN" = 1 ] || echo 1 > /sys/module/applespi/parameters/iso_layout
    ok "active now and after reboots"
}
comp_check() { [ -f /etc/default/grub.d/91-mbp-applespi-iso.cfg ]; }
comp_uninstall() { UNINSTALL_UPDATE_GRUB=1; [ "$DRY_RUN" = 1 ] || echo 0 > /sys/module/applespi/parameters/iso_layout 2>/dev/null || true; }
