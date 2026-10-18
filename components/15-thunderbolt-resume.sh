# shellcheck shell=bash
NAME=thunderbolt-resume
DESC="USB-C ports keep working after sleep (unbind thunderbolt from Alpine Ridge before s2idle)"
DEFAULT=y
REQUIRES=suspend
comp_applicable() { lspci -d 8086:15d2 2>/dev/null | grep -c . >/dev/null || { echo "no Alpine Ridge 4C NHI (8086:15d2)"; return 1; }; }
comp_install() {
    install_file "$NAME" "$REPO/files/system-sleep/mbp-tb-s2idle" /usr/lib/systemd/system-sleep/mbp-tb-s2idle 755
}
comp_check() { [ -x /usr/lib/systemd/system-sleep/mbp-tb-s2idle ]; }
comp_uninstall() { :; }
